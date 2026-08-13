import Foundation
import Cocoa
import Combine

struct WPMPoint: Identifiable {
    let id = UUID()
    let time: Date
    let wpm: Int
}

struct DailyRecord: Identifiable, Codable {
    var id: String { dateString }
    let dateString: String
    var avgWPM: Int
    var peakWPM: Int
    var accuracy: Int
    var totalKeystrokes: Int
}

enum WPMTrend {
    case up, down, flat
}

class KeystrokeMonitor: ObservableObject {
    @Published var hasInputMonitoringPermission: Bool = false
    @Published var isPaused: Bool = false
    @Published var isInactive: Bool = true

    // Menu bar live readout: short rolling window (responsive, not spiky)
    @Published var liveWPM: Int = 0
    @Published var liveCPM: Int = 0
    @Published var trend: WPMTrend = .flat

    // Stats for the currently selected timeframe (Session tab)
    @Published var timeframeWPM: Int = 0
    @Published var timeframeCPM: Int = 0
    @Published var liveAccuracy: Int = 100
    @Published var liveConsistency: Int = 100
    @Published var timeframeHighestWPM: Int = 0
    @Published var timeframeLowestWPM: Int = 999
    @Published var totalWordsToday: Int = 0

    @Published var chartData: [WPMPoint] = []
    @Published var dailyRecords: [String: DailyRecord] = [:]
    @Published var sensitivity: Double = 0.6

    /// Weight given to the newest instantaneous reading when blending with the previous
    /// liveWPM value. Higher = reacts faster to a speed change, but jumpier per keystroke.
    /// This is what the Settings sensitivity slider actually controls now - idle no longer
    /// decays anything, so there's nothing else left for the slider to affect.
    private var blendWeight: Double { 0.3 + sensitivity * 0.65 } // 0.30...0.95

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Raw log of real keystrokes. Everything is derived from this - single source of truth.
    private var keystrokeLog: [(date: Date, isBackspace: Bool)] = []
    private var wpmHistoryForTrend: [Int] = []
    private var updateTimer: AnyCancellable?
    private var chartTickCounter: Int = 0
    private var currentDayString: String = ""

    var currentTimeframeSeconds: Double = 60.0

    private let maxLogAgeSeconds: TimeInterval = 3600 * 6 // covers the longest timeframe (1hr) plus buffer

    init() {
        currentDayString = Self.dateString(for: Date())
        loadDailyRecords()
        checkPermissions()
        if hasInputMonitoringPermission {
            startCoreGraphicsTap()
        }
        startTimers()
    }

    func checkPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        self.hasInputMonitoringPermission = AXIsProcessTrustedWithOptions(options)
    }

    func startCoreGraphicsTap() {
        checkPermissions()
        guard hasInputMonitoringPermission else { return }
        if eventTap != nil { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // we only observe, never need to consume/modify keystrokes
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // macOS kills taps under load - re-enable instead of silently going dead
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                if type == .keyDown {
                    monitor.handleKeyEvent(event)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func handleKeyEvent(_ event: CGEvent) {
        // THE FIX for 1500 WPM: ignore autorepeat. Holding a key down fires keydown
        // every ~30ms, which any interval-based speed calc reads as inhuman typing.
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        if isRepeat { return }

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let isBackspace = (keycode == 51) // kVK_Delete

        DispatchQueue.main.async {
            guard !self.isPaused else { return }
            let now = Date()
            let previousKeyDate = self.keystrokeLog.last?.date
            self.keystrokeLog.append((date: now, isBackspace: isBackspace))
            self.isInactive = false
            self.trimLog(now: now)
            self.updateLiveWPM(now: now, previousKeyDate: previousKeyDate)
            self.recomputeStats(now: now)
        }
    }

    /// Live menu bar readout, driven directly by the interval to the PREVIOUS keystroke -
    /// updates on the very next key you press, not on a decaying average of past keys.
    /// Safe now that autorepeat is filtered (that was the actual source of the 1500 WPM bug,
    /// not interval-based calculation itself).
    private func updateLiveWPM(now: Date, previousKeyDate: Date?) {
        guard let prev = previousKeyDate else {
            liveWPM = 12
            liveCPM = liveWPM * 5
            return
        }
        let interval = now.timeIntervalSince(prev)
        guard interval > 0.02 else { return } // guard against near-zero duplicate event timestamps

        let instantWPM = min(220, Int((60.0 / interval / 5.0).rounded())) // 220 = sane human ceiling, not a smoothing device

        // Light smoothing only - heavily weighted toward the instant reading so a slowdown
        // shows up on THIS keystroke, not several keystrokes later.
        if liveWPM == 0 {
            liveWPM = instantWPM
        } else {
            let w = blendWeight
            liveWPM = Int((Double(liveWPM) * (1.0 - w) + Double(instantWPM) * w).rounded())
        }
        liveCPM = liveWPM * 5
    }

    private func trimLog(now: Date) {
        keystrokeLog.removeAll { now.timeIntervalSince($0.date) > maxLogAgeSeconds }
    }

    /// Recomputes every published stat from the raw log except liveWPM, which is set directly
    /// by updateLiveWPM() on each keystroke and decayed by tick() when idle. Called on every
    /// keystroke and every tick.
    private func recomputeStats(now: Date) {
        wpmHistoryForTrend.append(liveWPM)
        if wpmHistoryForTrend.count > 5 { wpmHistoryForTrend.removeFirst() }
        if let earliest = wpmHistoryForTrend.first, wpmHistoryForTrend.count >= 3 {
            if liveWPM > earliest + 3 { trend = .up }
            else if liveWPM < earliest - 3 { trend = .down }
            else { trend = .flat }
        }

        // --- Session stats: the ACTUAL selected timeframe window (this was missing entirely) ---
        let windowCutoff = now.addingTimeInterval(-currentTimeframeSeconds)
        let windowEvents = keystrokeLog.filter { $0.date >= windowCutoff }
        let windowChars = windowEvents.filter { !$0.isBackspace }.count
        let windowBackspaces = windowEvents.count - windowChars

        if windowEvents.isEmpty {
            self.timeframeWPM = 0
            self.timeframeCPM = 0
        } else {
            // Active time, not wall-clock time: any gap between keystrokes (i.e. you paused)
            // is capped rather than counted in full. Otherwise a 30s pause mid-session drags
            // the average toward 0 even though you never actually typed slower.
            let activeElapsed = activeElapsedSeconds(events: windowEvents, now: now)
            let cappedElapsed = min(currentTimeframeSeconds, activeElapsed)
            let sessionWpmRaw = Double(windowChars) / 5.0 / (cappedElapsed / 60.0)
            self.timeframeWPM = Int(sessionWpmRaw.rounded())
            self.timeframeCPM = self.timeframeWPM * 5
        }

        let totalWindowKeys = windowChars + windowBackspaces
        self.liveAccuracy = totalWindowKeys == 0
            ? 100
            : Int((Double(windowChars) / Double(totalWindowKeys) * 100).rounded())

        if self.timeframeWPM > 0 {
            if self.timeframeWPM > self.timeframeHighestWPM { self.timeframeHighestWPM = self.timeframeWPM }
            if self.timeframeWPM < self.timeframeLowestWPM { self.timeframeLowestWPM = self.timeframeWPM }
        }

        self.liveConsistency = computeConsistency(events: windowEvents, now: now)

        self.totalWordsToday = keystrokeLog
            .filter { Self.dateString(for: $0.date) == currentDayString && !$0.isBackspace }
            .count / 5
    }

    /// Sums actual typing time. Gaps between keystrokes are capped at idleGapCap so one
    /// long within-session pause doesn't wreck the average - but critically, once you've
    /// actually stopped (gap since the LAST keystroke exceeds the cap), we add nothing
    /// further. The number freezes. It does not keep accumulating idle time every tick.
    private func activeElapsedSeconds(events: [(date: Date, isBackspace: Bool)], now: Date, idleGapCap: Double = 2.0) -> Double {
        guard let first = events.first?.date else { return 0 }
        var elapsed = 0.0
        var prev = first
        for e in events.dropFirst() {
            elapsed += min(e.date.timeIntervalSince(prev), idleGapCap)
            prev = e.date
        }
        let tailGap = now.timeIntervalSince(prev)
        if tailGap < idleGapCap {
            elapsed += tailGap // still actively typing - count the live tail
        }
        // else: idle - contribute nothing, freeze at whatever elapsed already is
        return max(1.0, elapsed)
    }

    /// Coefficient-of-variation based consistency: splits the window into 5s buckets,
    /// measures how much speed bounces between buckets. Flat typing = high consistency.
    private func computeConsistency(events: [(date: Date, isBackspace: Bool)], now: Date) -> Int {
        let bucketSize: TimeInterval = 5.0
        guard events.first != nil else { return 100 }
        // Use active elapsed here too - otherwise a long pause creates a run of empty
        // buckets that reads as "inconsistent" when really you just weren't typing.
        let span = max(bucketSize, activeElapsedSeconds(events: events, now: now, idleGapCap: bucketSize))
        let bucketCount = max(1, Int(span / bucketSize))
        var buckets = [Int](repeating: 0, count: bucketCount)
        for e in events where !e.isBackspace {
            let offset = now.timeIntervalSince(e.date)
            let idx = min(bucketCount - 1, max(0, Int(offset / bucketSize)))
            buckets[bucketCount - 1 - idx] += 1
        }
        let wpms = buckets.map { Double($0) / 5.0 / (bucketSize / 60.0) }
        guard wpms.count > 1 else { return 100 }
        let mean = wpms.reduce(0, +) / Double(wpms.count)
        guard mean > 0 else { return 100 }
        let variance = wpms.reduce(0) { $0 + pow($1 - mean, 2) } / Double(wpms.count)
        let cv = sqrt(variance) / mean
        return max(0, min(100, Int((100 - cv * 100).rounded())))
    }

    private let tickInterval: Double = 0.5
    private let inactiveThreshold: Double = 1.2

    func startTimers() {
        updateTimer = Timer.publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard !isPaused else { return }
        let now = Date()
        trimLog(now: now)

        let idleTime = keystrokeLog.last.map { now.timeIntervalSince($0.date) } ?? .infinity
        let currentlyIdle = idleTime > inactiveThreshold

        if currentlyIdle {
            // FROZEN. Nothing recomputes, nothing decays, no chart point is added.
            // liveWPM, timeframeWPM, accuracy, consistency, trend - all hold their exact
            // last value until you type again. This is deliberate: "not typing" produces
            // literally zero new data, of any kind, anywhere in the app.
            isInactive = true
        } else {
            isInactive = false
            recomputeStats(now: now)

            // Chart sampling on a tick counter instead of wall-clock mod. At a 0.5s tick
            // interval, %4 keeps the same ~2s-per-point cadence, and only while active -
            // the graph line simply stops advancing the moment you stop typing.
            chartTickCounter += 1
            if chartTickCounter % 4 == 0 {
                chartData.append(WPMPoint(time: now, wpm: liveWPM))
                if chartData.count > 60 { chartData.removeFirst() }
            }
        }

        rolloverDayIfNeeded(now: now)
    }

    private func rolloverDayIfNeeded(now: Date) {
        let today = Self.dateString(for: now)
        if today != currentDayString {
            saveTodayRecord(dateString: currentDayString)
            currentDayString = today
            timeframeHighestWPM = 0
            timeframeLowestWPM = 999
        } else {
            // Keep today's record fresh so Long Distance / Compare have live data, not just yesterday's.
            saveTodayRecord(dateString: currentDayString)
        }
    }

    private func saveTodayRecord(dateString: String) {
        let dayEvents = keystrokeLog.filter { Self.dateString(for: $0.date) == dateString }
        guard !dayEvents.isEmpty else { return }
        let chars = dayEvents.filter { !$0.isBackspace }.count
        let backspaces = dayEvents.count - chars
        let acc = (chars + backspaces) == 0 ? 100 : Int((Double(chars) / Double(chars + backspaces) * 100).rounded())
        dailyRecords[dateString] = DailyRecord(
            dateString: dateString,
            avgWPM: timeframeWPM,
            peakWPM: timeframeHighestWPM,
            accuracy: acc,
            totalKeystrokes: chars
        )
        persistDailyRecords()
    }

    private func persistDailyRecords() {
        if let data = try? JSONEncoder().encode(dailyRecords) {
            UserDefaults.standard.set(data, forKey: "savedDailyRecords")
        }
    }

    private func loadDailyRecords() {
        if let data = UserDefaults.standard.data(forKey: "savedDailyRecords"),
           let decoded = try? JSONDecoder().decode([String: DailyRecord].self, from: data) {
            dailyRecords = decoded
        }
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused { isInactive = true }
    }

    func updateSensitivity(_ newSensitivity: Double) {
        self.sensitivity = newSensitivity.clamped(to: 0.0...1.0)
    }

    func updateTimeframeStats(timeframeSeconds: Int) {
        self.currentTimeframeSeconds = Double(timeframeSeconds)
        timeframeHighestWPM = 0
        timeframeLowestWPM = 999
        recomputeStats(now: Date())
    }

    func clearAllHistory() {
        dailyRecords.removeAll()
        chartData.removeAll()
        keystrokeLog.removeAll()
        timeframeWPM = 0
        timeframeCPM = 0
        liveWPM = 0
        liveCPM = 0
        timeframeHighestWPM = 0
        timeframeLowestWPM = 999
        totalWordsToday = 0
        UserDefaults.standard.removeObject(forKey: "savedDailyRecords")
    }

    static func dateString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
