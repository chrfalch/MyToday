# Contributing & Feature Development

This guide walks through the full lifecycle of a feature — from creating a branch
to getting it merged and included in a release.

---

## Overview

```
main ──────────────────────────────────────────────────── release tag
        │                               │
        └─ feature/my-feature ──── PR ─┘
```

All work happens on feature branches. `main` is always releasable. A release is
triggered by pushing a version tag (see [RELEASE.md](RELEASE.md)).

---

## Workflow: adding a new feature

### 1. Start from a fresh main

```bash
git checkout main
git pull origin main
```

Always branch from an up-to-date `main` to avoid unnecessary merge conflicts.

### 2. Create a feature branch

Name branches with a short prefix describing the type of change:

| Prefix | Use for |
|---|---|
| `feature/` | New user-visible functionality |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, dependency updates, refactoring |

```bash
# New feature
git checkout -b feature/show-location-in-menu-bar

# Bug fix
git checkout -b fix/reminder-count-after-midnight

# Chore / refactor
git checkout -b chore/extract-event-formatter
```

### 3. Make your changes in Xcode

Open `MyToday.xcodeproj` and work normally. A few conventions:

- **App logic** lives in `Sources/MyTodayKit/` (the Swift package library).
  This is where `EventManager`, views, and settings live — and where tests can
  reach it.
- **App entry point / menu bar plumbing** lives in `MyToday/MyTodayApp.swift`.
- **Tests** live in `Tests/MyTodayKitTests/`. Add tests for any logic in
  `MyTodayKit`.

```
Sources/MyTodayKit/
├── EventManager.swift          ← calendar & reminder fetching
├── CalendarSettings.swift      ← user preferences
├── ContentView.swift           ← popover UI
├── SettingsView.swift          ← settings panel
└── SettingsWindowController.swift
```

### 4. Run tests locally

```bash
npm test

# or directly:
bash scripts/test.sh

# Expected output:
# Running tests…
# Test Suite 'All tests' passed at 2025-03-01 14:22:05.123
# All tests passed.
```

Do this before every commit. The CI workflow will also run tests on your PR,
but catching failures locally is faster.

### 5. Build and smoke-test

```bash
npm run build
# Opens → build/Release/MyToday.app
open build/Release/MyToday.app
```

Click through the menu bar popover and check your changes look correct.

### 6. Commit your work

Keep commits small and focused. Write the subject line in the imperative mood:

```bash
# Good — describes what the commit does
git commit -m "feat: show location below meeting title in popover"
git commit -m "fix: reminder count resets incorrectly after midnight"
git commit -m "chore: extract EventFormatter into its own file"

# Avoid — vague or past-tense
git commit -m "updated stuff"
git commit -m "fixed bug"
```

Commit prefix conventions:

| Prefix | Meaning |
|---|---|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `chore:` | Maintenance, no user-visible change |
| `test:` | Test-only changes |
| `docs:` | Documentation only |
| `refactor:` | Code restructure, no behaviour change |

### 7. Push and open a Pull Request

```bash
git push -u origin feature/show-location-in-menu-bar
```

Then open a PR on GitHub. The CI workflow (`.github/workflows/ci.yml`) will
automatically run tests and a Release build on your branch. Both checks must
pass before merging.

**Good PR description template:**

```
## What
Show the meeting location (or Zoom/Teams link) as a subtitle under the
meeting title in the popover list.

## Why
Users frequently switch between rooms and need to glance at location without
opening Calendar.

## How
- Added `locationText` computed property to `EventRowView`
- Falls back to meeting link URL if no physical location is set
- Truncated to 60 chars to avoid layout overflow

## Testing
- [ ] Physical location shows correctly
- [ ] Zoom link shown when no location set
- [ ] No location → subtitle hidden (no empty space)
- [ ] `npm test` passes
```

### 8. After merging

Once your PR is merged to `main`, decide whether to release immediately or
batch it with other changes.

```bash
# Switch back to main and pull the merged result
git checkout main
git pull origin main

# Clean up your local feature branch
git branch -d feature/show-location-in-menu-bar
```

---

## Workflow: fixing a bug

Same as above, but use a `fix/` branch and a `PATCH` version bump when releasing.

```bash
git checkout main && git pull origin main
git checkout -b fix/reminder-count-after-midnight

# ... make changes, test ...

git commit -m "fix: reset reminder cache at midnight not 00:01"
git push -u origin fix/reminder-count-after-midnight
# open PR, merge to main

# Then release as a patch:
npm run release -- 1.0.1
```

---

## Workflow: releasing after one or more merges

After merging one or more features/fixes to `main`, cut a release:

```bash
git checkout main && git pull origin main

# Review what's going into the release
git log $(git describe --tags --abbrev=0)..HEAD --oneline
# a3f1c2e feat: show location in popover
# 9b2d841 fix: reminder count after midnight

# Those are one feature + one fix → MINOR bump
npm run release -- 1.1.0
```

See [RELEASE.md](RELEASE.md) for the full release walkthrough.

---

## Tips

**Keep feature branches short-lived.** Long-running branches drift from `main`
and cause painful merges. Aim to open a PR within a day or two of starting work.

**One concern per PR.** Mixing a feature with a refactor makes review harder.
If you need to refactor first, do it in a separate `chore/` PR.

**Test on a clean build.** Occasionally run `rm -rf build/` before `npm run build`
to catch issues that only appear on a fresh compile.

**Check the CI status before merging.** Both the *Test* and *Build* jobs in CI
must be green. A red build on `main` blocks the next release.
