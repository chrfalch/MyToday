import AppKit
import SwiftUI
import EventKit

class SettingsWindowController {
    private var window: NSWindow?
    private let settingsManager: CalendarSettingsManager
    private let store: EKEventStore

    init(settingsManager: CalendarSettingsManager, store: EKEventStore) {
        self.settingsManager = settingsManager
        self.store = store
    }

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settingsManager: settingsManager, store: store)
        let hostingController = NSHostingController(rootView: settingsView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = "MyToday Settings"
        win.styleMask = [.titled, .closable, .resizable]
        win.isReleasedWhenClosed = false
        win.setFrameAutosaveName("MyTodaySettings")
        win.center()

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
