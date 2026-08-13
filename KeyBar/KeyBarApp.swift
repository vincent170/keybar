import SwiftUI

@main
struct KeyBarApp: App {
    @StateObject private var monitor = KeystrokeMonitor()
    @StateObject private var settings = SettingsStore()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, settings: settings)
                .onAppear { monitor.updateSensitivity(settings.wpmSensitivity) }
        } label: {
            HStack(spacing: 4) {
                if settings.showMenuBarIcon {
                    Image(systemName: "keyboard")
                }
                
                if settings.showMenuBarWPM {
                    // FIXED: was showing timeframeWPM (an unthrottled instant EMA) here.
                    // liveWPM is the short-rolling-window figure that can't spike to 1500.
                    Text("\(monitor.liveWPM) WPM")
                }
                
                if settings.showMenuBarAccuracy {
                    Text("\(monitor.liveAccuracy)%")
                }
                
                // FIXED: same as above - dead toggle, now wired to monitor.trend.
                if settings.showTrendEmoji && !monitor.isInactive && !monitor.isPaused {
                    Image(systemName: monitor.trend == .up ? "arrow.up" : monitor.trend == .down ? "arrow.down" : "arrow.right")
                        .font(.system(size: 10))
                }
                
                if monitor.isInactive {
                    Image(systemName: "moon.zzz.fill")
                } else if monitor.isPaused {
                    Image(systemName: "pause.fill")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
