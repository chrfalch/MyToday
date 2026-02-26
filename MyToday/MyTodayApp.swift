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

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventManager = EventManager()
    var settingsManager = CalendarSettingsManager()
    var settingsWindowController: SettingsWindowController?
    var timer: Timer?        // 60s — full data refresh
    var displayTimer: Timer? // 15s — status bar text + urgency color update only
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
        popover.delegate = self
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

        // Full data refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.eventManager.refresh()
        }
        // Status bar text + urgency color update every 15 seconds
        // (keeps countdown accurate and catches the ≤5 min / ≤2 min thresholds promptly)
        displayTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            self.updateStatusBar()
        }
    }

    func openSettings() {
        popover?.performClose(nil)
        settingsWindowController?.showWindow()
    }

    /// Per-emoji baseline offset for the menu bar font.
    /// Geometric/filled shapes (🟢) render centred in the em-square and need no lift.
    /// Pictograph emojis (👥 📍 📋 📅) sit slightly low and need +2pt.
    /// Add new cases here whenever a new emoji is introduced to the status bar.
    private func menuBarEmojiOffset(for scalar: Unicode.Scalar) -> CGFloat {
        switch scalar.value {
        case 0x1F7E2: return 0.0   // 🟢  large green circle — geometric, already centred
        default:       return 2.0   // pictographs sit low, lift +2pt
        }
    }

    /// Walks all leading non-ASCII characters (skipping spaces) in `str` and applies
    /// the per-emoji baseline offset, stopping at the first ASCII character.
    private func applyLeadingEmojiOffsets(to str: NSMutableAttributedString) {
        let ns = str.string as NSString
        var pos = 0
        while pos < ns.length {
            let range = ns.rangeOfComposedCharacterSequence(at: pos)
            let substr = ns.substring(with: range)
            if substr == " " { pos += 1; continue }
            guard let scalar = substr.unicodeScalars.first, scalar.value > 0x007F else { break }
            let offset = menuBarEmojiOffset(for: scalar)
            if offset != 0 { str.addAttribute(.baselineOffset, value: offset, range: range) }
            pos = range.location + range.length
        }
    }

    func updateStatusBar() {
        guard let button = statusItem?.button else { return }

        let title = eventManager.statusBarTitle()
        let baseFont = NSFont.menuBarFont(ofSize: 0)

        let urgencyColor: NSColor? = {
            switch eventManager.statusBarUrgency {
            case .soon:     return NSColor.systemOrange
            case .imminent: return NSColor.systemRed
            case .none:     return nil
            }
        }()

        var titleAttrs: [NSAttributedString.Key: Any] = [.font: baseFont]
        if let color = urgencyColor { titleAttrs[.foregroundColor] = color }
        let result = NSMutableAttributedString(string: title, attributes: titleAttrs)
        applyLeadingEmojiOffsets(to: result)

        // If in a current event, show the next upcoming event (≤30 min) dimmed after it
        let now = Date()
        if let current = eventManager.nextEvent, current.startDate <= now, current.endDate > now {
            if let nextItem = eventManager.sortedEvents.first(where: { $0.event.startDate > now }) {
                let mins = Int(nextItem.event.startDate.timeIntervalSince(now) / 60)
                if mins <= 30 {
                    let icon = nextItem.event.eventType.emoji
                    var nextTitle = nextItem.event.title ?? "Event"
                    if nextTitle.count > 14 { nextTitle = String(nextTitle.prefix(14)) + "…" }
                    let dimColor = NSColor.secondaryLabelColor
                    // Build the next-event segment starting with the emoji so the shared
                    // applyLeadingEmojiOffsets helper can handle the offset correctly.
                    let nextCore = NSMutableAttributedString(
                        string: "\(icon) \(nextTitle) in \(mins)m",
                        attributes: [.font: baseFont, .foregroundColor: dimColor]
                    )
                    applyLeadingEmojiOffsets(to: nextCore)
                    let spaces = NSAttributedString(
                        string: "  ",
                        attributes: [.font: baseFont, .foregroundColor: dimColor]
                    )
                    result.append(spaces)
                    result.append(nextCore)
                }
            }
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
                .foregroundColor: NSColor.systemYellow,
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

    // Fired by NSPopover after the popover has fully appeared and laid out
    func popoverDidShow(_ notification: Notification) {
        eventManager.scrollToCurrentEvent.send()
    }
}
