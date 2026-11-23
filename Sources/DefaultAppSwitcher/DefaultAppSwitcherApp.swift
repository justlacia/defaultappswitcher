import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DefaultAppSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup(appState.strings.windowTitle) {
            ContentView(state: appState)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .newItem) {
                Button(appState.strings.refresh) {
                    Task {
                        await appState.reloadAll()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
