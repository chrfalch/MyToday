import SwiftUI
import EventKit
import Combine
import MyTodayKit

@main
struct MyTodayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventManager = EventManager()
    var settingsManager = CalendarSettingsManager()
    var settingsWindowController: SettingsWindowController?
    var timer: Timer?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        eventManager.settingsManager = settingsManager
        settingsWindowController = SettingsWindowController(
            settingsManager: settingsManager,
            store: eventManager.store
        )

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                eventManager: eventManager,
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
        )
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        eventManager.requestAccess {
            DispatchQueue.main.async {
                self.updateStatusBar()
                self.eventManager.startObservingStoreChanges()
            }
        }

        // Update status bar whenever events or reminders change
        eventManager.$nextEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)
        eventManager.$overdueReminders
            .combineLatest(eventManager.$undatedReminders)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)

        // Refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.eventManager.refresh()
            self.updateStatusBar()
        }
    }

    func openSettings() {
        popover?.performClose(nil)
        settingsWindowController?.showWindow()
    }

    func updateStatusBar() {
        guard let button = statusItem?.button else { return }

        let title = eventManager.statusBarTitle()
        let baseFont = NSFont.menuBarFont(ofSize: 0)
        let result = NSMutableAttributedString(
            string: title,
            attributes: [.font: baseFont]
        )
        // Raise only the leading emoji icon +2pt; leave the rest of the text at baseline
        if !title.isEmpty {
            let emojiRange = (title as NSString).rangeOfComposedCharacterSequence(at: 0)
            result.addAttribute(.baselineOffset, value: 2.0, range: emojiRange)
        }

        let dotFont = NSFont.systemFont(ofSize: 8)
        let dotBaseline = (baseFont.pointSize - dotFont.pointSize) / 2 - 1
        let countFont = NSFont.monospacedDigitSystemFont(ofSize: baseFont.pointSize, weight: .medium)

        if eventManager.overdueReminders > 0 {
            let dot = NSAttributedString(string: "  \u{25CF}", attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: dotFont,
                .baselineOffset: dotBaseline
            ])
            let count = NSAttributedString(string: " \(eventManager.overdueReminders)", attributes: [
                .font: countFont
            ])
            result.append(dot)
            result.append(count)
        }

        if eventManager.undatedReminders > 0 {
            let dot = NSAttributedString(string: "  \u{25CF}", attributes: [
                .foregroundColor: NSColor.systemOrange,
                .font: dotFont,
                .baselineOffset: dotBaseline
            ])
            let count = NSAttributedString(string: " \(eventManager.undatedReminders)", attributes: [
                .font: countFont
            ])
            result.append(dot)
            result.append(count)
        }

        button.attributedTitle = result
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        eventManager.refresh()
        updateStatusBar()
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(sender)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
