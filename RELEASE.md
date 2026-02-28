# Release Process

MyToday uses GitHub Actions to build, sign, notarize, and publish releases as
downloadable DMG files on the GitHub Releases page.

---

## How it works

```
npm run release
     │
     ├─ bumps version in Info.plist
     ├─ commits the change
     ├─ creates an annotated git tag  (vX.Y.Z)
     └─ pushes tag → triggers GitHub Actions "Release" workflow
                           │
                           ├─ imports Developer ID certificate
                           ├─ builds Xcode archive (xcodebuild archive)
                           ├─ exports with Developer ID signing
                           ├─ packages as DMG
                           ├─ notarizes DMG with Apple
                           ├─ staples notarization ticket
                           └─ creates GitHub Release with DMG attached
```

---

## One-time setup

### 1. Developer ID Application certificate

You need an **Apple Developer account** with the "Developer ID Application"
certificate type (for distributing outside the App Store).

1. Open **Keychain Access** on your Mac.
2. Export your *Developer ID Application* certificate as a `.p12` file with a
   strong password.
3. Base64-encode it:
   ```bash
   base64 -i DeveloperIDApplication.p12 | pbcopy
   ```
4. Add to GitHub repository secrets (**Settings → Secrets and variables → Actions**):
   | Secret name | Value |
   |---|---|
   | `APPLE_CERTIFICATE_BASE64` | the base64 string |
   | `APPLE_CERTIFICATE_PASSWORD` | the `.p12` export password |

### 2. App Store Connect API key (for notarization)

Notarization requires credentials. An **App Store Connect API key** is the
recommended approach (no 2FA friction, no app-specific passwords).

1. Go to [App Store Connect → Users & Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Generate a new key with **Developer** role.  Download the `.p8` file
   (you can only download it once).
3. Note the **Key ID** and **Issuer ID** shown in the portal.
4. Base64-encode the key:
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```
5. Add to GitHub repository secrets:
   | Secret name | Value |
   |---|---|
   | `NOTARY_KEY_BASE64` | base64-encoded `.p8` content |
   | `NOTARY_KEY_ID` | Key ID (e.g. `ABCDE12345`) |
   | `NOTARY_ISSUER_ID` | Issuer UUID from the portal |

> `GITHUB_TOKEN` is provided automatically by GitHub Actions — no setup needed.

---

## Releasing — step by step

### Step 1 — check what's changed since the last release

```bash
# See commits since the last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# Example output:
# a3f1c2e feat: show meeting link button in popover
# 9b2d841 fix: reminder count off by one after midnight
# 12ee093 chore: update event colour for declined events
```

This tells you what kind of version bump is appropriate (see
[Versioning convention](#versioning-convention) below).

### Step 2 — preview what will happen (dry run)

```bash
npm run release:dry

# Output:
# Releasing MyToday 1.1.0 (tag: v1.1.0) [DRY RUN]
#
# 1/4  Bumping version in Info.plist…
# [dry-run] /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.1.0" Info.plist
# 2/4  Committing version bump…
# [dry-run] git add Info.plist
# [dry-run] git commit -m "chore: bump version to 1.1.0"
# 3/4  Creating tag v1.1.0…
# [dry-run] git tag -a "v1.1.0" -m "Release v1.1.0"
# 4/4  Pushing to origin…
# [dry-run] git push origin HEAD "v1.1.0"
```

Nothing is modified — use this to confirm the version before committing.

### Step 3 — run the release

```bash
# Option A: interactive (prompts for the version)
npm run release

# Current version is 1.0.0. New version (x.y.z): 1.1.0

# Option B: non-interactive
npm run release -- 1.1.0

# Output:
# Releasing MyToday 1.1.0 (tag: v1.1.0)
#
# 1/4  Bumping version in Info.plist…
# 2/4  Committing version bump…
# 3/4  Creating tag v1.1.0…
# 4/4  Pushing to origin…
# Done! Tag v1.1.0 pushed.
# Follow the release at: https://github.com/chrfalch/MyToday/actions
```

### Step 4 — watch the workflow

Open the link printed above (or go to **Actions → Release** on GitHub).
The workflow takes ~10 minutes — most of that time is Apple's notarization queue.

```
✓ Resolve version tag          (a few seconds)
✓ Select Xcode                 (a few seconds)
✓ Import signing certificate   (~5s)
✓ Set version                  (~2s)
✓ Archive                      (~3 min)
✓ Create DMG                   (~10s)
✓ Notarize DMG                 (~5–10 min — Apple's queue varies)
✓ Generate release notes       (~2s)
✓ Create GitHub Release        (~5s)
✓ Cleanup keychain             (~1s)
```

### Step 5 — verify the release

1. Go to **Releases** on the GitHub repository page.
2. Confirm the new release appears with `MyToday.dmg` attached.
3. Download and mount the DMG, then verify Apple accepted the notarization:
   ```bash
   spctl --assess --type exec -vv /Volumes/MyToday/MyToday.app
   # Expected: source=Notarized Developer ID
   ```

---

## Triggering a release from GitHub Actions UI

If you pushed a tag manually (without using `npm run release`) you can still
kick off the workflow:

1. Go to **Actions → Release** in the GitHub repository.
2. Click **Run workflow** (top-right of the workflow list).
3. Enter the existing tag, e.g. `v1.1.0`.
4. Click **Run workflow**.

> The tag **must already exist** in the repo before using this path.
> Use `scripts/version.sh --marketing 1.1.0 --tag` to create + push it without
> `npm run release`.

---

## Individual scripts

These are used by the workflow but can also be run locally for debugging.

| Script | What it does |
|---|---|
| `scripts/version.sh` | Updates `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` |
| `scripts/archive.sh` | Runs `xcodebuild archive` + `exportArchive` with Developer ID signing |
| `scripts/create-dmg.sh` | Packages `build/export/MyToday.app` into a compressed DMG |
| `scripts/notarize.sh` | Submits to Apple notarization via `xcrun notarytool`, then staples |
| `scripts/build.sh` | Quick local build — no signing, not for distribution |
| `scripts/test.sh` | Runs the Swift package test suite |

**Example: build the DMG locally to test packaging**

```bash
# 1. Build a signed archive (requires your Developer ID cert in your keychain)
bash scripts/archive.sh

# 2. Package it
bash scripts/create-dmg.sh MyToday-test.dmg

# 3. Open it
open build/MyToday-test.dmg
```

---

## Versioning convention

Versions follow **semver** (`MAJOR.MINOR.PATCH`):

| Change | Bump | Example |
|---|---|---|
| Breaking change or big redesign | MAJOR | `1.0.0 → 2.0.0` |
| New user-visible feature | MINOR | `1.0.0 → 1.1.0` |
| Bug fix or small tweak | PATCH | `1.0.0 → 1.0.1` |

Git tags use the `v` prefix: `v1.0.0`, `v1.1.0`, `v1.0.1`, etc.

---

## Release artifacts

Each GitHub Release contains:

- **`MyToday.dmg`** — notarized, Developer-ID–signed macOS disk image with a
  drag-to-Applications installer layout.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `errSecInternalComponent` during import | Certificate password is wrong — check `APPLE_CERTIFICATE_PASSWORD` secret |
| Notarization rejected (invalid signature) | Hardened Runtime must be enabled in Xcode entitlements |
| `xcrun notarytool` timeout | Increase `--timeout` in `scripts/notarize.sh`; Apple's queue can be slow |
| DMG not created | `build/export/MyToday.app` missing — run `scripts/archive.sh` first |
| Tag already exists | `git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z` then re-release |
| Workflow doesn't trigger | Confirm the tag matches `v[0-9]+.[0-9]+.[0-9]+` — letters in the tag won't match |
