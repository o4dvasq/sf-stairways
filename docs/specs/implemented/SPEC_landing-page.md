# SPEC: Landing Page + Privacy Page
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Create a mobile-first landing page that drives TestFlight beta signups, and a minimal privacy policy page required by Apple for external TestFlight distribution. Both pages are static HTML hosted on GitHub Pages within the existing sf-stairways repo.

---

## 2. Scope

**In scope:**
- New landing page (`index.html` replacement)
- Privacy policy page (`privacy.html`)
- Open Graph / social meta tags for link previews
- Mobile-first responsive design
- Placeholder TestFlight CTA button (URL updated manually once TestFlight is live)

**Out of scope:**
- Email capture or waitlist forms
- Analytics or tracking scripts
- Custom domain setup (handled separately outside the repo)
- Any backend, login, or dynamic content
- The deprecated web app (archived or removed — see Section 4)

---

## 3. Business Rules

1. **Zero friction.** The "Join the Beta" button links directly to a TestFlight public URL. No intermediate steps, no email capture, no Google Form.

2. **Placeholder TestFlight link.** Use `https://testflight.apple.com/join/PLACEHOLDER` as the href. Oscar will update this manually once the TestFlight link is live.

3. **Privacy policy is required.** Apple requires a privacy policy URL for TestFlight external testing. The page must be reachable at `/privacy` (or `/privacy.html`). Content should accurately reflect the app's data practices: local-only SwiftData + iCloud sync, no analytics, no data collection, no third-party services beyond Apple CloudKit and optional Supabase auth.

4. **The deprecated web app (`index.html`) must be preserved.** Move the current `index.html` to `legacy/index.html` (or similar) so the old app remains accessible for reference without conflicting with the new landing page at the root URL.

5. **Brand orange is `#E8602C`.** Use as accent color for buttons and highlights.

6. **Typography should be distinctive.** No Inter, no Roboto, no system-ui defaults. Use a refined serif or curated sans-serif from Google Fonts (or similar CDN). Suggestion: a clean serif like `Instrument Serif` or `Playfair Display` for headlines, paired with a readable sans for body. Final choice is implementation discretion, but it must not look generic.

7. **Photography hero.** The hero section uses a full-bleed background photograph. Use a high-quality placeholder image of San Francisco (Unsplash or similar, free license). Oscar will replace with original photography later. The image should evoke a warm, inviting San Francisco scene — ideally a park, hillside, or neighborhood view. Not a postcard shot of the Golden Gate Bridge.

---

## 4. Data Model / Schema Changes

None. These are static HTML files with no data dependencies.

---

## 5. UI / Interface

### Landing Page (`index.html`)

**Hero section (full viewport height):**
- Full-bleed background photograph (CSS `background-image`, `cover`, centered)
- Semi-transparent dark overlay for text legibility
- Centered content block:
  - App name "SF Stairways" in large serif/display type (white)
  - One-line tagline beneath: "Climb every stairway in San Francisco"
  - "Join the Beta" button — brand orange `#E8602C` background, white text, rounded, links to TestFlight placeholder URL
  - Three-step logo mark if available (optional — can be added later)
- Subtle scroll indicator at bottom (down arrow or similar)

**Below the fold — Features block:**
- Clean section with generous whitespace
- 4–5 feature lines, each with a minimal icon or bullet:
  - 382 stairways mapped across 68 SF neighborhoods
  - Log your walks, add photos, track your progress
  - Around Me mode — discover stairways nearby
  - Your data stays yours — syncs to iCloud, no account required, nothing collected
  - Hard Mode coming soon — you have to actually be there to log it

**Below the fold — Story block:**
- Short personal narrative (2–3 sentences):
  - Built by a 40-year SF resident who wanted to track the stairways he'd walked and discover the ones he hadn't
  - "It's like a passport for SF's hidden vertical streets"
  - Photography focus — each stairway is a photo opportunity, a neighborhood, a story

**Footer:**
- Minimal: "SF Stairways" + year
- Link to privacy policy (`/privacy.html`)

### Privacy Policy Page (`privacy.html`)

Simple, readable page. Same typography as landing page. Content:

- **What the app collects:** Nothing. Walk records, photos, and tags are stored locally on your device using Apple's SwiftData framework.
- **iCloud sync:** If you have iCloud enabled, your data syncs across your Apple devices via Apple CloudKit. This is Apple's infrastructure — SF Stairways does not operate any servers or databases that store your data.
- **Optional account:** Sign in with Apple is available for future features. Authentication is handled by Supabase. No personal data beyond your Apple ID token is stored.
- **Analytics:** None. No tracking pixels, no analytics SDKs, no third-party data collection.
- **Photos:** Photos you take within the app are stored locally on your device. The app also saves photos to your Camera Roll via Apple's Photos framework. No photos are uploaded to any server.
- **Contact:** oscar@avilacapllc.com

### Open Graph Meta Tags

Both pages should include proper `<meta>` OG tags:
- `og:title` — "SF Stairways — Climb every stairway in San Francisco"
- `og:description` — "Track your progress across 382 public stairways in San Francisco. Free beta."
- `og:image` — the hero photograph (or a dedicated OG image if one is created)
- `og:url` — the page URL (placeholder until domain is finalized)
- `twitter:card` — `summary_large_image`

---

## 6. Integration Points

- **GitHub Pages:** The repo already serves static content via GitHub Pages. The new `index.html` replaces the deprecated web app at the root URL.
- **TestFlight:** The CTA button links to a TestFlight public URL (placeholder for now).
- **No APIs, no backend, no JavaScript dependencies** (beyond what's needed for any scroll animations or similar progressive enhancement).

---

## 7. Constraints

- Single HTML file per page (inline CSS, minimal or no JS).
- Mobile-first — the primary audience arrives from tapping a shared link on their phone.
- Fast load — no heavy frameworks, no bundler. Google Fonts CDN is acceptable.
- The hero image should be served from a CDN or included as a reasonable-size file in the repo (keep under 500KB, compressed).
- Must work well on iOS Safari (the primary browser for the target audience).

---

## 8. Acceptance Criteria

- [ ] Landing page loads at the repo's GitHub Pages root URL
- [ ] Hero section is full viewport height with background image, app name, tagline, and CTA button
- [ ] CTA button links to TestFlight placeholder URL
- [ ] Features and Story sections render cleanly below the fold
- [ ] Privacy policy page is accessible at `/privacy.html`
- [ ] Privacy policy content accurately reflects the app's data practices
- [ ] Both pages render well on iPhone (Safari) at 375px–430px width
- [ ] Both pages render acceptably on desktop
- [ ] Open Graph meta tags are present on both pages
- [ ] Typography is distinctive (not system defaults)
- [ ] Brand orange `#E8602C` is used consistently for accent/CTA
- [ ] Old web app is preserved at `legacy/index.html` (or equivalent)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `index.html` — replaced with landing page (old version moved to `legacy/`)
- `privacy.html` — new file at repo root
- `legacy/index.html` — relocated deprecated web app
- Hero image file (e.g., `images/hero.jpg` or similar) — new asset
