import Foundation
import Combine

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


enum CurrentTimeframe: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case twentyMinutes = 1200
    case oneHour = 3600
    
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 mins"
        case .tenMinutes: return "10 mins"
        case .twentyMinutes: return "20 mins"
        case .oneHour: return "1 hour"
        }
    }
}

enum LongTimeframe: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30
    case ninetyDays = 90
    
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .fourteenDays: return "14 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        }
    }
}

class SettingsStore: ObservableObject {
    @Published var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }
    @Published var showMenuBarWPM: Bool {
        didSet { UserDefaults.standard.set(showMenuBarWPM, forKey: "showMenuBarWPM") }
    }
    @Published var showMenuBarAccuracy: Bool {
        didSet { UserDefaults.standard.set(showMenuBarAccuracy, forKey: "showMenuBarAccuracy") }
    }
    @Published var showTrendEmoji: Bool {
        didSet { UserDefaults.standard.set(showTrendEmoji, forKey: "showTrendEmoji") }
    }
    @Published var currentTimeframe: CurrentTimeframe {
        didSet { UserDefaults.standard.set(currentTimeframe.rawValue, forKey: "currentTimeframe") }
    }
    @Published var longTimeframe: LongTimeframe {
        didSet { UserDefaults.standard.set(longTimeframe.rawValue, forKey: "longTimeframe") }
    }
    @Published var wpmSensitivity: Double {
        didSet { UserDefaults.standard.set(wpmSensitivity, forKey: "wpmSensitivity") }
    }

    init() {
        self.showMenuBarIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.showMenuBarWPM = UserDefaults.standard.object(forKey: "showMenuBarWPM") as? Bool ?? true
        self.showMenuBarAccuracy = UserDefaults.standard.object(forKey: "showMenuBarAccuracy") as? Bool ?? true
        self.showTrendEmoji = UserDefaults.standard.object(forKey: "showTrendEmoji") as? Bool ?? true
        
        let tfRaw = UserDefaults.standard.integer(forKey: "currentTimeframe")
        self.currentTimeframe = CurrentTimeframe(rawValue: tfRaw) ?? .oneMinute
        
        let ltRaw = UserDefaults.standard.integer(forKey: "longTimeframe")
        self.longTimeframe = LongTimeframe(rawValue: ltRaw) ?? .thirtyDays

        let sensRaw = UserDefaults.standard.object(forKey: "wpmSensitivity") as? Double
        self.wpmSensitivity = (sensRaw ?? 0.6).clamped(to: 0.0...1.0)
    }
}
