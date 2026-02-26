# MyToday

A macOS menu bar app that shows your next meeting and today's schedule at a glance.

## Features

- **Menu bar title** — Shows the name of your next meeting and how soon it starts (or "NOW" if in progress)
- **Dropdown popover** — Lists all remaining meetings today with times, locations, and meeting links
- **Reminders summary** — Shows count of overdue reminders and reminders without a due date
- **Color coded** — Uses your calendar's color for each event; highlights current meetings in green and upcoming (≤15 min) in orange
- **Auto-refreshes** every 60 seconds

## Setup in Xcode

1. **Create a new Xcode project:**
   - File → New → Project → macOS → App
   - Product Name: `MyToday`
   - Interface: SwiftUI
   - Language: Swift

2. **Add the source files** — Replace/add the generated files with:
   - `MyTodayApp.swift`
   - `EventManager.swift`
   - `ContentView.swift`

3. **Update Info.plist** — Either use the provided `Info.plist` or add these keys manually:
   - `NSCalendarsUsageDescription` — Calendar access reason string
   - `NSRemindersUsageDescription` — Reminders access reason string
   - `LSUIElement` → `YES` (hides the dock icon, makes it a true menu bar app)

4. **Signing & Capabilities:**
   - In your target's Signing & Capabilities tab, make sure your team is selected
   - No special entitlements needed — EventKit access is handled via Info.plist keys

5. **Build & Run** (⌘R)
   - The app will appear in your menu bar
   - macOS will prompt for Calendar and Reminders permissions on first launch

## Requirements

- macOS 13.0+
- Xcode 15+

## Customization

- **Refresh interval**: Change the `60` in `AppDelegate.applicationDidFinishLaunching` to any number of seconds
- **"Soon" threshold**: The orange badge appears when a meeting is ≤15 minutes away; change `15` in `EventRowView`
- **Show all-day events**: Remove `.filter { !$0.isAllDay }` in `EventManager.fetchEvents()` to include them
