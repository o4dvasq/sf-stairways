# SPEC: Neighborhood Rewards (Badges + Discovery Nuggets)
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Future

---

## 1. Objective

Add subtle, joyful moments of discovery throughout the app that reward exploration and keep neighborhoods front and center. Two layers: a badge system for completing all stairways in a neighborhood, and contextual "did you know" nuggets that surface interesting facts as users explore.

---

## 2. Design Philosophy

These features should feel like something you notice on the third or fourth time you use the app, not the first. No modals, no animations that block interaction. A line of text in a muted color, a small badge that appears on a card. The goal is delight, not interruption.

---

## 3. Neighborhood Badges

### Trigger
A user earns a badge when they walk every stairway in a neighborhood (100% completion).

### Where badges appear

- **NeighborhoodCard** (Progress tab): small visual indicator on the card when the neighborhood is fully complete. Could be a checkmark, a filled ring, a subtle color shift, or a small icon. Should feel earned, not flashy.
- **NeighborhoodDetail**: a completion state at the top of the view when all stairways are walked. Something like a quiet "All [X] stairways walked" with a badge icon.
- **MapTab neighborhood polygons**: completed neighborhoods could get a subtle visual distinction (slightly different fill or a small overlay mark at the centroid).

### What badges are NOT
- No gamification system, no points, no levels
- No push notifications
- No leaderboard
- No social sharing of badges (the share card already covers sharing individual walks)

---

## 4. Discovery Nuggets

### What they are
Short, contextual, interesting facts about neighborhoods and stairways. One or two sentences. Things that make you want to go explore.

### Content examples
- "Bernal Heights has 14 stairways, more than any other neighborhood in SF."
- "The Filbert Steps climb 284 feet from Sansome Street to Telegraph Hill, making them the tallest public stairway in San Francisco."
- "Which neighborhood has more stairways, Noe Valley or Pacific Heights?" (Answer revealed on tap or just stated.)
- "Forest Hill has 7 stairways within a half-mile radius. One of the densest stairway clusters in the city."
- "You've now walked stairways in 5 different neighborhoods. 63 to go."
- "The 16th Avenue Tiled Steps took over 2 years and 300 volunteers to complete."

### Where nuggets appear

- **NeighborhoodDetail**: a muted text line below the progress bar or above the stairway list. One fact per neighborhood, rotated or static. This is the primary surface.
- **First walk in a new neighborhood**: after marking a stairway as walked, if it's the user's first walk in that neighborhood, a brief contextual line could appear in the confirmation toast or in the StairwayBottomSheet. "First stairway in Bernal Heights. 13 more to explore."
- **Progress tab**: a rotating nugget at the top of the tab, above the ring. Changes each time the user visits. "You've climbed [X] feet so far. That's higher than [landmark]." or a neighborhood comparison.
- **Empty states**: if a user opens NeighborhoodDetail for a neighborhood they haven't walked yet, a compelling nugget could serve as motivation.

### Where nuggets do NOT appear
- No notifications
- No splash screen or onboarding
- No modals or sheets
- No blocking UI of any kind

---

## 5. Data Considerations

### Badge data
Badge state is derived, not stored. A neighborhood is "complete" when the count of walked stairways equals the total stairway count for that neighborhood. No new SwiftData model needed. The Progress tab already computes this grouping.

### Nugget content
Nuggets need a content source. Options to evaluate during implementation:

- **Static JSON file** bundled with the app (e.g., `neighborhood_facts.json`). Simple, no backend. Content curated manually. Easy to update with app releases.
- **Computed facts** derived from real data: "X has more stairways than Y", "You've walked N neighborhoods", "Total height climbed: X ft". These can be generated dynamically from StairwayStore data.
- **Hybrid**: some facts are static (historical, trivia), some are computed (user progress, comparisons).

The static file approach is the simplest starting point. A JSON array of objects with `neighborhoodName` (optional, null for global facts), `fact` (string), and `type` (neighborhood/comparison/progress/trivia).

---

## 6. Open Questions

- Should the badge have a visual design (icon, illustration) or just be a text/color state change?
- How many nuggets per neighborhood? One is fine to start. Can expand later.
- Should nuggets rotate on each visit or be fixed per neighborhood?
- Are milestone nuggets (5 neighborhoods, 10 neighborhoods, halfway, etc.) worth building, or is that too gamification-adjacent?
- Should there be a "completion" moment for walking all 382 stairways? (Probably yes, but that can be its own thing.)

---

*Captured from design conversation, April 2026. To be refined and promoted to "Ready for Implementation" when prioritized.*
