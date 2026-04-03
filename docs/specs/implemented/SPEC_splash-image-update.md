SPEC: Splash Image Update | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Replace the old cartoon splash image with the new AI-generated illustration that includes text overlay ("SF Stairways" in Instrument Serif, "Climb every stairway in San Francisco" in DM Sans). The new image has been pre-rendered with correct fonts, sizing, and drop shadow.

## 2. Scope

- Swap the splash image asset
- Clean up font files that were dropped into Assets.xcassets (they're not image assets)
- No code changes needed in SplashView.swift (it already uses `Image("splash")` with `.scaledToFill()`)

## 3. Business Rules

- The splash screen should display the new branded illustration on app launch
- Background color remains `.brandOrange` as fallback while image loads

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

The splash screen currently shows `splash_image.jpeg` (old cartoon-style image). Replace with `splash_with_text.png` (new amber-toned stairway illustration with "SF Stairways" title and tagline baked into the image).

## 6. Integration Points

None.

## 7. Constraints

- The new image is 1536x2752 PNG (~7MB). This is fine for a splash asset.
- SplashView.swift requires NO changes. It uses `Image("splash")` which maps to the "splash" imageset.

## 8. Acceptance Criteria

- [ ] `Contents.json` in `splash.imageset` points to `splash_with_text.png` instead of `splash_image.jpeg`
- [ ] Old `splash_image.jpeg` removed from `splash.imageset` (optional, but keeps it clean)
- [ ] `Gemini_Generated_Image_cfnhajcfnhajcfnh.png` removed from `splash.imageset` (raw source, not needed)
- [ ] Font files moved out of `Assets.xcassets/` to a better location (e.g., `ios/SFStairways/Resources/Fonts/`) or removed if not needed by the app at runtime. They were only used for the image render and are NOT used by the iOS app (the app uses system fonts).
- [ ] App launches and displays the new splash image correctly on simulator

## 9. Files Likely Touched

- `ios/SFStairways/Assets.xcassets/splash.imageset/Contents.json` — update filename reference
- `ios/SFStairways/Assets.xcassets/splash.imageset/splash_image.jpeg` — delete
- `ios/SFStairways/Assets.xcassets/splash.imageset/Gemini_Generated_Image_cfnhajcfnhajcfnh.png` — delete
- `ios/SFStairways/Assets.xcassets/InstrumentSerif-Regular.ttf` — move or delete
- `ios/SFStairways/Assets.xcassets/InstrumentSerif-Italic.ttf` — move or delete
- `ios/SFStairways/Assets.xcassets/DMSans-VariableFont_opsz,wght.ttf` — move or delete
- `ios/SFStairways/Assets.xcassets/DMSans-Italic-VariableFont_opsz,wght.ttf` — move or delete

### Implementation detail (one-line change)

Update `Contents.json` to:
```json
{
  "images" : [
    {
      "filename" : "splash_with_text.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```
