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

        let baseFont = NSFont.menuBarFont(ofSize: 0)
        let boldFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let (main, next) = eventManager.statusBarComponents()

        let result = NSMutableAttributedString(
            string: main,
            attributes: [.font: boldFont]
        )

        if let next {
            result.append(NSAttributedString(
                string: "  →  \(next)",
                attributes: [.font: baseFont]
            ))
        }

        if eventManager.overdueReminders > 0 {
            result.append(NSAttributedString(string: "  ", attributes: [.font: baseFont]))
            let badge = makeBadge(count: eventManager.overdueReminders, color: .systemRed, referenceFont: baseFont)
            result.append(NSAttributedString(attachment: badge))
        }

        if eventManager.undatedReminders > 0 {
            result.append(NSAttributedString(string: "  ", attributes: [.font: baseFont]))
            let badge = makeBadge(count: eventManager.undatedReminders, color: .systemOrange, referenceFont: baseFont)
            result.append(NSAttributedString(attachment: badge))
        }

        button.attributedTitle = result
    }

    private func makeBadge(count: Int, color: NSColor, referenceFont: NSFont) -> NSTextAttachment {
        let label = count > 9 ? "+9" : "\(count)"
        let fontSize = max(referenceFont.pointSize * 0.68, 9)
        let badgeFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: NSColor.white
        ]
        let textSize = (label as NSString).size(withAttributes: attrs)

        let padding: CGFloat = 3.5
        let height = textSize.height + padding
        let width = max(height, textSize.width + padding * 2)

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()
            let textRect = NSRect(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (label as NSString).draw(in: textRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = false

        let attachment = NSTextAttachment()
        attachment.image = image
        let yOffset = (referenceFont.capHeight - height) / 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: width, height: height)
        return attachment
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
