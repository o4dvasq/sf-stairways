SPEC: Xcode Project Consolidation | Project: sf-stairways | Date: 2026-03-23 | Status: Manual steps (Oscar)

---

## 1. Objective

Move the Xcode project (.xcodeproj) into the Dropbox repo so that the Xcode project and the source files are in the same place. This eliminates the manual "copy files from Dropbox to Desktop" step every time Claude Code edits Swift source.

**After this change:** Claude Code edits files in `~/Dropbox/projects/sf-stairways/ios/SFStairways/` → Oscar opens Xcode → changes are already there → build and run.

## 2. Current State

- **Source of truth:** `~/Dropbox/projects/sf-stairways/ios/SFStairways/` (22 Swift files)
- **Xcode project:** `~/Desktop/SFStairways/` (manually configured .xcodeproj, asset catalog, entitlements, Info.plist)
- **Problem:** These are two separate copies. Every Claude Code edit requires manually dragging files into the Xcode project folder.

## 3. Target State

```
~/Dropbox/projects/sf-stairways/
├── ios/
│   ├── SFStairways.xcodeproj/       ← Xcode project (moved here)
│   └── SFStairways/                 ← Swift source (already here)
│       ├── Models/
│       ├── Views/
│       ├── Services/
│       ├── Resources/
│       ├── Assets.xcassets/          ← moved from Desktop project
│       ├── SFStairways.entitlements  ← moved from Desktop project
│       └── Info.plist                ← if it exists as a separate file
├── index.html
├── data/
├── docs/
└── ...
```

## 4. Migration Steps (Manual — Oscar in Xcode + Finder)

### Step 1: Copy the Xcode project to the repo

Open Finder. Copy the entire `~/Desktop/SFStairways/SFStairways.xcodeproj` folder (it's actually a folder, not a single file) into `~/Dropbox/projects/sf-stairways/ios/`.

Also copy these Xcode-managed files from `~/Desktop/SFStairways/SFStairways/` into `~/Dropbox/projects/sf-stairways/ios/SFStairways/`:
- `Assets.xcassets/` (the whole folder — contains app icon, accent color, etc.)
- `SFStairways.entitlements`
- `Info.plist` (if it exists as a standalone file — some projects use Xcode-generated settings instead)
- `Preview Content/` (if it exists)

### Step 2: Fix file references in Xcode

1. Open `~/Dropbox/projects/sf-stairways/ios/SFStairways.xcodeproj` in Xcode
2. Xcode will likely show red (missing) files in the project navigator because the paths changed
3. For each red file: right-click → "Show File Inspector" → update the path to point to the file in the same `ios/SFStairways/` folder
4. Alternatively: remove all red references, then drag the `ios/SFStairways/` folder back into the project navigator — Xcode will re-add them with correct relative paths
5. Make sure the target membership is correct (all Swift files belong to the SFStairways target)

### Step 3: Verify the build

1. Select your physical device as the target
2. Cmd+B to build
3. Fix any path issues that come up
4. Cmd+R to run on device — verify the app works

### Step 4: Clean up

Once the repo-based project builds and runs correctly:
- Delete `~/Desktop/SFStairways/` (or archive it somewhere as backup first)
- The Dropbox folder is now the only copy

### Step 5: Update .gitignore

Add these to `.gitignore` if not already there (Xcode generates user-specific files that shouldn't be shared):

```
# Xcode
ios/SFStairways.xcodeproj/project.xcworkspace/xcuserdata/
ios/SFStairways.xcodeproj/xcuserdata/
*.xcuserstate
```

## 5. After Migration — New Workflow

1. **Design in Cowork** → spec goes to `docs/specs/`
2. **Claude Code implements** → edits Swift files in `ios/SFStairways/`
3. **Oscar opens Xcode** → project at `~/Dropbox/projects/sf-stairways/ios/SFStairways.xcodeproj`
4. **Build & run** → changes are already there, no copying needed

## 6. Constraints

- This is a manual Xcode task — Claude Code cannot create or modify .xcodeproj files reliably
- Dropbox sync should handle the .xcodeproj fine (it's just XML/plist files), but avoid having Xcode open on two machines simultaneously
- The .xcodeproj will be large-ish in the repo but that's fine for a Dropbox-hosted project

## 7. Acceptance Criteria

- [ ] `SFStairways.xcodeproj` lives at `ios/SFStairways.xcodeproj` in the Dropbox repo
- [ ] All Swift source files reference correctly (no red files in navigator)
- [ ] Asset catalog (Assets.xcassets) is in the repo and contains the app icon
- [ ] Entitlements file is in the repo
- [ ] App builds and runs on physical device from the repo location
- [ ] `~/Desktop/SFStairways/` is deleted or archived
- [ ] `.gitignore` updated with Xcode user data exclusions
- [ ] CLAUDE.md updated to reflect new Xcode project location
