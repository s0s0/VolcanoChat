import SwiftUI

@main
struct VolcanoChatbotApp: App {
    @StateObject private var appDelegate = AppDelegate()
    @StateObject private var globalRecordingManager = GlobalRecordingManager.shared
    @StateObject private var globalScreenshotManager = GlobalScreenshotManager.shared

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: ObservableObject {
    private var settingsWindow: NSWindow?

    func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 300))
        window.center()
        window.makeKeyAndOrderFront(nil)

        // 保持窗口引用
        settingsWindow = window
    }
}
