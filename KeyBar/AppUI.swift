import SwiftUI
import Charts

struct MenuBarView: View {
    @ObservedObject var monitor: KeystrokeMonitor
    @ObservedObject var settings: SettingsStore
    
    @State private var isCurrentExpanded: Bool = true
    @State private var isLongExpanded: Bool = false
    @State private var isCompareExpanded: Bool = false
    @State private var showSettingsView: Bool = false
    
    @State private var selectedChartTime: Date?
    
    @State private var compareDate1 = Date()
    @State private var compareDate2 = Date().addingTimeInterval(-86400)
    
    var body: some View {
        VStack(spacing: 0) {
            if !monitor.hasInputMonitoringPermission {
                PermissionWarningView(monitor: monitor)
                    .padding(20)
            } else if showSettingsView {
                InlineSettingsView(settings: settings, monitor: monitor, isPresented: $showSettingsView)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        
                        // --- HEADER BAR ---
                        HStack {
                            Text("KEYBAR ANALYTICS")
                                .font(.caption2).bold().foregroundColor(.secondary)
                            
                            if monitor.isPaused {
                                Text("• PAUSED")
                                    .font(.caption2).bold()
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            Button(action: { showSettingsView = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                        
                        // --- SECTION 1: CURRENT TIMEFRAME ---
                        DisclosureGroup(isExpanded: $isCurrentExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Timeframe:")
                                        .font(.caption)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { settings.currentTimeframe },
                                        set: { settings.currentTimeframe = $0; monitor.updateTimeframeStats(timeframeSeconds: $0.rawValue) }
                                    )) {
                                        ForEach(CurrentTimeframe.allCases) { tf in
                                            Text(tf.label).tag(tf)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 90)
                                }
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    // FIXED: these now reflect the ACTUAL selected timeframe window,
                                    // not a single global running average.
                                    StatBox(title: "Session WPM", value: "\(monitor.timeframeWPM)", color: .blue)
                                    StatBox(title: "CPM", value: "\(monitor.timeframeCPM)", color: .teal)
                                    StatBox(title: "Accuracy", value: "\(monitor.liveAccuracy)%", color: .green)
                                    StatBox(title: "Consistency", value: "\(monitor.liveConsistency)%", color: .pink)
                                    StatBox(title: "Highest", value: "\(monitor.timeframeHighestWPM)", color: .purple)
                                    StatBox(title: "Lowest", value: monitor.timeframeLowestWPM == 999 ? "-" : "\(monitor.timeframeLowestWPM)", color: .orange)
                                }
                                
                                // CHART
                                if !monitor.chartData.isEmpty {
                                    let maxVal = (monitor.chartData.map(\.wpm).max() ?? 60) + 15
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        if #available(macOS 14.0, *) {
                                            if let selectedTime = selectedChartTime,
                                               let point = monitor.chartData.min(by: { abs($0.time.timeIntervalSince(selectedTime)) < abs($1.time.timeIntervalSince(selectedTime)) }) {
                                                HStack {
                                                    Text("Hover Inspection:")
                                                        .font(.system(size: 10)).bold().foregroundColor(.secondary)
                                                    Text("\(point.wpm) WPM")
                                                        .font(.system(size: 11, weight: .bold)).foregroundColor(.blue)
                                                    Spacer()
                                                    Text(point.time, style: .time)
                                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                                }
                                            } else {
                                                Text("Hover over chart to inspect timeline")
                                                    .font(.system(size: 10)).foregroundColor(.secondary)
                                            }
                                            
                                            Chart(monitor.chartData) { point in
                                                LineMark(
                                                    x: .value("Time", point.time),
                                                    y: .value("WPM", point.wpm)
                                                )
                                                .interpolationMethod(.catmullRom)
                                                .foregroundStyle(Color.blue.gradient)
                                                
                                                if let selectedChartTime {
                                                    RuleMark(x: .value("Selected", selectedChartTime))
                                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                                                }
                                            }
                                            .chartXSelection(value: $selectedChartTime)
                                            .chartYScale(domain: 0...max(80, maxVal))
                                            .frame(height: 110)
                                        } else {
                                            Chart(monitor.chartData) { point in
                                                LineMark(
                                                    x: .value("Time", point.time),
                                                    y: .value("WPM", point.wpm)
                                                )
                                                .interpolationMethod(.catmullRom)
                                                .foregroundStyle(Color.blue.gradient)
                                            }
                                            .chartYScale(domain: 0...max(80, maxVal))
                                            .frame(height: 110)
                                        }
                                    }
                                    .padding(.top, 4)
                                } else {
                                    Text(monitor.isPaused ? "Monitoring is paused." : "Start typing anywhere to generate live graph...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(height: 80)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.primary.opacity(0.04))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("Current Session").font(.headline)
                        }
                        
                        Divider()
                        
                        // --- SECTION 2: LONG DISTANCE ---
                        DisclosureGroup(isExpanded: $isLongExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("History:")
                                        .font(.caption)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { settings.longTimeframe },
                                        set: { settings.longTimeframe = $0 }
                                    )) {
                                        ForEach(LongTimeframe.allCases) { tf in
                                            Text(tf.label).tag(tf)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 100)
                                }
                                
                                let filteredRecords = getFilteredHistory(days: settings.longTimeframe.rawValue)
                                
                                if filteredRecords.isEmpty {
                                    VStack(spacing: 6) {
                                        Image(systemName: "chart.bar.doc.horizontal")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                        Text("No Historical Data Recorded")
                                            .font(.caption).bold()
                                        Text("KeyBar saves your stats daily. Keep typing over coming days to build history!")
                                            .font(.caption2)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.primary.opacity(0.03))
                                    .cornerRadius(8)
                                } else {
                                    let avgWPM = filteredRecords.map(\.avgWPM).reduce(0, +) / filteredRecords.count
                                    let peakWPM = filteredRecords.map(\.peakWPM).max() ?? 0
                                    let avgAcc = filteredRecords.map(\.accuracy).reduce(0, +) / filteredRecords.count
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        StatBox(title: "Avg WPM", value: "\(avgWPM)", color: .blue)
                                        StatBox(title: "Peak WPM", value: "\(peakWPM)", color: .purple)
                                        StatBox(title: "Avg Accuracy", value: "\(avgAcc)%", color: .green)
                                        StatBox(title: "Days Logged", value: "\(filteredRecords.count)", color: .teal)
                                    }
                                    
                                    let chartMax = (filteredRecords.map(\.peakWPM).max() ?? 60) + 15
                                    Chart(filteredRecords) { rec in
                                        BarMark(
                                            x: .value("Date", rec.dateString),
                                            y: .value("Avg WPM", rec.avgWPM)
                                        )
                                        .foregroundStyle(Color.blue.gradient)
                                    }
                                    .chartYScale(domain: 0...max(80, chartMax))
                                    .frame(height: 100)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("Long Distance").font(.headline)
                        }
                        
                        Divider()
                        
                        // --- SECTION 3: PERIOD COMPARISON ---
                        DisclosureGroup(isExpanded: $isCompareExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    DatePicker("", selection: $compareDate1, displayedComponents: .date)
                                        .labelsHidden()
                                    Text("vs").font(.caption).bold()
                                    DatePicker("", selection: $compareDate2, displayedComponents: .date)
                                        .labelsHidden()
                                }
                                
                                let r1 = monitor.dailyRecords[dateString(compareDate1)]
                                let r2 = monitor.dailyRecords[dateString(compareDate2)]
                                
                                if let r1 = r1, let r2 = r2 {
                                    let diffWPM = r1.avgWPM - r2.avgWPM
                                    let diffAcc = r1.accuracy - r2.accuracy
                                    
                                    HStack {
                                        StatBox(title: "WPM Difference", value: "\(diffWPM >= 0 ? "+" : "")\(diffWPM)", color: diffWPM >= 0 ? .green : .red)
                                        StatBox(title: "Accuracy Diff", value: "\(diffAcc >= 0 ? "+" : "")\(diffAcc)%", color: diffAcc >= 0 ? .green : .red)
                                    }
                                } else {
                                    Text("Select two dates with logged activity to view comparison.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.primary.opacity(0.03))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("Compare Periods").font(.headline)
                        }
                        
                        Divider()
                        
                        // --- FOOTER ---
                        HStack {
                            Text("Total Keys Today: \(monitor.totalWordsToday * 5)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: { monitor.togglePause() }) {
                                Text(monitor.isPaused ? "Resume" : "Pause")
                                    .bold()
                                    .foregroundColor(monitor.isPaused ? .green : .orange)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button("Quit KeyBar") {
                                NSApplication.shared.terminate(nil)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 360, height: 490)
    }
    
    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    
    private func getFilteredHistory(days: Int) -> [DailyRecord] {
        let records = Array(monitor.dailyRecords.values)
        return records.sorted { $0.dateString > $1.dateString }.prefix(days).map { $0 }
    }
}

struct InlineSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: KeystrokeMonitor
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("KeyBar Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Menu Bar Display Elements")
                    .font(.caption).bold().foregroundColor(.secondary)
                
                Toggle("Show Keyboard Icon", isOn: $settings.showMenuBarIcon)
                Toggle("Show Live WPM", isOn: $settings.showMenuBarWPM)
                Toggle("Show Accuracy %", isOn: $settings.showMenuBarAccuracy)
                Toggle("Show Trend Emoji (⬆️/⬇️)", isOn: $settings.showTrendEmoji)
            }
            
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Live WPM Sensitivity")
                        .font(.caption).bold().foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(settings.wpmSensitivity * 100))%")
                        .font(.caption).foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { settings.wpmSensitivity },
                        set: { settings.wpmSensitivity = $0; monitor.updateSensitivity($0) }
                    ),
                    in: 0...1
                )

                HStack {
                    Text("Smooth").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("Responsive").font(.caption2).foregroundColor(.secondary)
                }

                Text("Higher reacts faster to speed changes but is jumpier per keystroke. Lower is steadier but lags behind.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Management")
                    .font(.caption).bold().foregroundColor(.secondary)
                
                Button("Clear All Saved History", role: .destructive) {
                    monitor.clearAllHistory()
                }
            }
            
            Spacer()
        }
        .padding(20)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PermissionWarningView: View {
    @ObservedObject var monitor: KeystrokeMonitor
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Input Monitoring Required")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("KeyBar needs Input Monitoring permission to track live typing speed.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Re-check Permission") {
                    // FIXED: startCoreGraphicsTap() now calls checkPermissions() internally first,
                    // so this actually clears the warning screen once you've granted access.
                    monitor.startCoreGraphicsTap()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }
}
