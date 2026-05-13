# Configuration Inventory — sf-stairways

Last updated: 2026-05-13

---

## Hosting / DNS

| Surface | Value | Notes |
|---|---|---|
| iOS App hosting | Apple App Store (future) / TestFlight (personal) | Not yet published; personal use only |
| CloudKit container | `iCloud.com.o4dvasq.sfstairways` | Sync backend for SwiftData |
| GitHub repo | `https://github.com/o4dvasq/sf-stairways` | Source of record |

---

## Build Steps

| Step | Tool | Notes |
|---|---|---|
| Build | Xcode (iOS 17+, SwiftUI) | Project at `ios/SFStairways.xcodeproj` |
| Deploy (personal) | Xcode → device via USB or TestFlight | No CI/CD workflow |
| Data | `data/all_stairways.json` | 382 SF stairways, committed static asset |

---

## Source Files

| Path | Contents | Notes |
|---|---|---|
| `ios/SFStairways.xcodeproj` | Xcode project | iOS 17+, SwiftUI, SwiftData |
| `ios/SFStairways/` | Swift source | App, views, models, services |
| `data/all_stairways.json` | 382 stairway records | Static JSON; not generated at runtime |
| `index.html` | Deprecated web app | Kept for reference; not maintained |

---

## Local Dev Setup

1. Open `ios/SFStairways.xcodeproj` in Xcode
2. Select a simulator or connected device (iOS 17+)
3. Build and run (⌘R)
4. CloudKit requires iCloud sign-in on the device

---

## Auth Surfaces

| Auth Surface | Type | Notes |
|---|---|---|
| CloudKit / iCloud | Apple account (implicit) | SwiftData + CloudKit; no explicit credentials |

---

### Inference Notes

- No environment variables, secrets, or scheduled jobs. Native iOS app with CloudKit sync.
- The deprecated `index.html` web app has no hosting, no DNS, and is not served anywhere.
- Bundle ID `com.o4dvasq.SFStairways` is from `ios/SFStairways.xcodeproj` project settings.
