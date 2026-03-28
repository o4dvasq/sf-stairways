# NEEDS_REVIEW.md

Items flagged during safe-cleanup that were skipped because they are near-duplicates or require judgment calls beyond mechanical cleanup.

---

## Near-Duplicate: Apple Credential Extraction in AuthManager

**Files:** `ios/SFStairways/Services/AuthManager.swift`

`handleAppleAuthorization(_:)` (line 107) and `authorizationController(didCompleteWithAuthorization:)` (line 164) both extract an Apple identity token using the same three-line guard block and call `signInWithIdToken`. They serve different code paths:

- `handleAppleAuthorization` is called from the SwiftUI `SignInWithAppleButton.onCompletion` closure and also calls `loadProfile()` + updates `signInError`.
- The delegate method is called by `ASAuthorizationController` (the `signInWithApple()` flow) and does neither.

The two flows could be unified if one Apple sign-in approach is chosen and the other removed. Currently both are live.

---

## Near-Duplicate: Thumbnail Generation

**Files:** `ios/SFStairways/Models/WalkPhoto.swift`, `ios/SFStairways/Services/PhotoLikeService.swift`

Both files contain thumbnail generation logic using `UIGraphicsImageRenderer` with `0.7` JPEG compression quality. The implementations differ:

- `WalkPhoto.generateThumbnail`: aspect-ratio-preserving, max-width based (300pt default).
- `PhotoLikeService.generateThumbnail`: square 400×400 with letterboxing (black fill).

Not identical, so not consolidated. A shared `ImageUtils.swift` would be the right home if these diverge further.

---

## Magic Numbers (No Action Taken — Swift/iOS, Not Env Vars)

These hardcoded values are iOS domain constants. `.env` files do not apply to this platform. Extracting them to a `Constants.swift` is a refactor (out of scope for cleanup), but worth doing when the values need to change:

| Value | Location | Meaning |
|-------|----------|---------|
| `150` (meters) | `StairwayDetail.swift`, `StairwayBottomSheet.swift` | Hard mode proximity gate |
| `1500` (meters) | `MapTab.swift` | Around Me filter radius |
| `37.76, -122.44` | `MapTab.swift` | Default SF map center |
| `0.85` | `PhotoService.swift` | Full-size JPEG compression quality |
| `0.7` | `WalkPhoto.swift`, `PhotoLikeService.swift` | Thumbnail JPEG compression quality |
| `300` | `WalkPhoto.swift` | Thumbnail max width (pt) |
| `400` | `PhotoLikeService.swift` | Square thumbnail size (pt) |

---

## Dependencies (N/A)

This is a Swift/iOS project using Swift Package Manager via Xcode. There is no `requirements.txt` or `package.json`. Package dependency auditing must be done in Xcode (Package Dependencies inspector).
