# SF Stairways — Photo Upload Enhancement Spec
## Addendum to sf_stairways_map_spec_v3.md

---

## Overview

Add the ability to attach a photo to any walked stairway. Photos are stored on
Cloudinary (free tier). The URL is saved back to `target_list.json` via the
existing GitHub API write flow. No backend required.

---

## Prerequisites (user sets up once)

1. Create free account at cloudinary.com
2. From the Cloudinary dashboard, note:
   - **Cloud Name** (e.g., `abc123xyz`)
3. Create an **unsigned upload preset:**
   - Settings → Upload → Upload Presets → Add upload preset
   - Set "Signing mode" to **Unsigned**
   - Set folder to `sf-stairways`
   - Note the **Preset Name** (e.g., `sf_stairways_unsigned`)
4. Enter both values in the app's ⚙ Settings modal (see below)

No API key or secret needed — unsigned presets are safe for browser use.

---

## Data Schema Change

Add one field to each entry in `target_list.json`:

```json
{
  "id": "lincoln-park-steps",
  "name": "Lincoln Park Steps",
  ...
  "walked": true,
  "date_walked": "2026-03-08",
  "photo_url": null    ← new field; null until photo uploaded, then Cloudinary URL
}
```

When seeding/migrating existing entries, add `"photo_url": null` to all records.

---

## Settings Modal — Add Cloudinary Fields

Extend the existing ⚙ Settings modal with two new fields below the GitHub token:

```
┌─────────────────────────────────────────────────┐
│  ⚙ Settings                                  ✕  │
│                                                 │
│  GitHub Token                                   │
│  [ ghp_xxxxxxxxxxxxxxxxxxxx         ] [👁]      │
│                                                 │
│  ── Photo Storage (Cloudinary) ──               │
│                                                 │
│  Cloud Name:    [ abc123xyz         ]           │
│  Upload Preset: [ sf_stairways_unsigned ]       │
│                                                 │
│  Free account at cloudinary.com                 │
│  Create an unsigned upload preset               │
│  in Settings → Upload → Upload Presets          │
│                                                 │
│  [ Save Settings ]                              │
└─────────────────────────────────────────────────┘
```

Store in localStorage:
- `cloudinary_cloud_name`
- `cloudinary_upload_preset`

---

## Popup Changes

### Walked marker — no photo yet:
```
🟢 Lincoln Park Steps
Lincoln Park
✅ Walked: March 8, 2026
89 steps

[ ✏️ Edit ]  [ 📷 Add Photo ]
```

### Walked marker — photo exists:
```
🟢 Lincoln Park Steps
Lincoln Park
✅ Walked: March 8, 2026
89 steps

[  photo thumbnail — ~200px wide, rounded corners  ]

[ ✏️ Edit ]  [ 📷 Change Photo ]
```

Thumbnail is a plain `<img>` tag with the `photo_url` as src.
Clicking the thumbnail opens the full image in a new tab.

---

## Upload Flow

### Trigger
User taps "📷 Add Photo" or "📷 Change Photo" in the popup.

### Step 1 — Check Cloudinary config
If `cloudinary_cloud_name` or `cloudinary_upload_preset` not set in localStorage:
- Show inline message in popup:
  "Set up Cloudinary in ⚙ Settings first."
- Do not proceed.

### Step 2 — File picker
Open a hidden `<input type="file" accept="image/*" capture="environment">`.
- `capture="environment"` opens rear camera by default on mobile
- Still allows picking from camera roll

### Step 3 — Upload to Cloudinary

```javascript
async function uploadToCloudinary(file) {
  const cloudName = localStorage.getItem('cloudinary_cloud_name');
  const preset    = localStorage.getItem('cloudinary_upload_preset');

  const formData = new FormData();
  formData.append('file', file);
  formData.append('upload_preset', preset);
  formData.append('folder', 'sf-stairways');

  const res = await fetch(
    `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
    { method: 'POST', body: formData }
  );

  const data = await res.json();
  return data.secure_url;   // ← permanent HTTPS URL to the uploaded image
}
```

### Step 4 — Save URL to target_list.json

On successful upload:
1. Set `stairway.photo_url = secure_url` in memory
2. Call existing `saveTargetList()` to write updated JSON to GitHub
3. Re-render popup with thumbnail
4. Show brief success toast: "Photo saved ✅"

### Error handling
- Upload fails → show: "Photo upload failed — check your Cloudinary settings"
- File too large (>10MB) → show: "Photo is too large. Please use a compressed image."
- No internet → show: "No connection — try again when online"

---

## Image Handling Notes

- Cloudinary auto-compresses and serves via CDN — no resizing needed in the app
- Recommended: tell users to use their phone's default camera (already compressed)
- Optional enhancement (not required for v1): append Cloudinary transform params
  to the URL for a resized thumbnail vs full view:
  - Thumbnail: insert `/c_fill,w_400,h_300/` into the URL path
  - Full: use `photo_url` as-is

---

## Config Block Update

Add Cloudinary fields to the CONFIG object at top of index.html:

```javascript
const CONFIG = {
  githubOwner: 'o4dvasq',
  githubRepo:  'sf-stairways',
  dataPath:    'data/target_list.json',
  branch:      'main'
  // Cloudinary config is read from localStorage at runtime, not hardcoded
};
```

---

## Quality Checklist

- [ ] "Add Photo" button only visible on walked markers
- [ ] Cloudinary settings missing → clear inline error, not a broken state
- [ ] File input opens camera on mobile, file picker on desktop
- [ ] Upload progress indication (spinner or "Uploading..." text)
- [ ] Thumbnail renders correctly in popup after save
- [ ] Clicking thumbnail opens full image in new tab
- [ ] "Change Photo" replaces photo_url (old Cloudinary image is orphaned — acceptable)
- [ ] No Cloudinary API secret anywhere in the codebase
- [ ] Works within existing single-file HTML architecture
