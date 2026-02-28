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
4. Add to GitHub repository secrets:
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

## Releasing

### From the command line (recommended)

```bash
# Bump, tag and push in one step — triggers the Release workflow
npm run release

# Specify version explicitly
npm run release -- 1.2.3

# Preview what would happen without making any changes
npm run release:dry
```

### From GitHub Actions UI

1. Go to **Actions → Release** in the GitHub repository.
2. Click **Run workflow**.
3. Enter the tag that already exists in the repo (the tag must have been pushed
   first, e.g. via `scripts/version.sh --tag`).

---

## Individual scripts

| Script | Purpose |
|---|---|
| `scripts/version.sh` | Set `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` |
| `scripts/archive.sh` | `xcodebuild archive` + `exportArchive` with Developer ID signing |
| `scripts/create-dmg.sh` | Package `build/export/MyToday.app` into a DMG |
| `scripts/notarize.sh` | Submit to Apple notarization via `xcrun notarytool` and staple |
| `scripts/build.sh` | Quick development build (not for distribution) |
| `scripts/test.sh` | Run Swift package tests |

---

## Versioning convention

Versions follow **semver** (`MAJOR.MINOR.PATCH`):

| Change | Bump |
|---|---|
| Breaking / major new feature | MAJOR |
| New feature, backwards-compatible | MINOR |
| Bug fix | PATCH |

Git tags use the `v` prefix: `v1.0.0`, `v1.2.3`, etc.

---

## Release artifacts

Each GitHub Release contains:

- **`MyToday.dmg`** — notarized, Developer-ID–signed macOS disk image with a
  drag-to-Applications installer layout.

Users can verify the notarization themselves:
```bash
spctl --assess --type exec -vv /Volumes/MyToday/MyToday.app
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `errSecInternalComponent` during import | Ensure the certificate password is correct in `APPLE_CERTIFICATE_PASSWORD` |
| Notarization rejected (invalid signature) | Check that hardened runtime is enabled in Xcode entitlements |
| `xcrun notarytool` timeout | Increase `--timeout` in `scripts/notarize.sh`; Apple can be slow |
| DMG not created | Confirm `build/export/MyToday.app` exists; run `scripts/archive.sh` first |
| Tag already exists | Delete the tag locally and remotely before re-releasing the same version |
