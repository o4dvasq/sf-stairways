#!/usr/bin/env python3
"""
import_urban_hiker_locations.py

One-time import of Urban Hiker SF stairway locations into all_stairways.json.

Usage:
  python3 scripts/import_urban_hiker_locations.py --dry-run   # report only, no file changes
  python3 scripts/import_urban_hiker_locations.py --apply     # write changes + report

Idempotent: running --apply twice produces the same all_stairways.json.
"""

import json
import math
import re
import argparse
import shutil
from collections import defaultdict
from datetime import date
from difflib import SequenceMatcher


# ---------------------------------------------------------------------------
# New neighborhoods for areas > 800m from any existing centroid.
# Rules are checked in order; first match wins.
# ---------------------------------------------------------------------------
NEW_NEIGHBORHOOD_RULES = [
    {
        "name": "Alcatraz Island",
        "lat_min": 37.824, "lat_max": 37.832,
        "lng_min": -122.428, "lng_max": -122.418,
    },
    {
        "name": "Lands End",
        "lat_min": 37.773, "lat_max": 37.790,
        "lng_min": -122.520, "lng_max": -122.490,
    },
    {
        "name": "Presidio",
        "lat_min": 37.786, "lat_max": 37.812,
        "lng_min": -122.500, "lng_max": -122.444,
    },
    {
        "name": "Golden Gate Park",
        "lat_min": 37.762, "lat_max": 37.775,
        "lng_min": -122.515, "lng_max": -122.452,
    },
    {
        "name": "Fort Mason",
        "lat_min": 37.803, "lat_max": 37.810,
        "lng_min": -122.434, "lng_max": -122.422,
    },
    {
        "name": "Marina",
        "lat_min": 37.797, "lat_max": 37.806,
        "lng_min": -122.447, "lng_max": -122.434,
    },
    {
        "name": "Embarcadero",
        "lat_min": 37.784, "lat_max": 37.800,
        "lng_min": -122.400, "lng_max": -122.382,
    },
    {
        "name": "Downtown",
        "lat_min": 37.784, "lat_max": 37.800,
        "lng_min": -122.418, "lng_max": -122.400,
    },
]

COORD_MATCH_DIST = 800     # meters — primary centroid threshold
RELAXED_DIST = 1500        # meters — fallback threshold
NAME_SIM_THRESHOLD = 0.55  # SequenceMatcher ratio for coord-fill matching

# Generic words that don't identify a specific stairway — excluded from
# the word-overlap sanity check on coord-fill name matching.
_COORD_FILL_STOPWORDS = {
    "street", "avenue", "ave", "lane", "place", "way", "boulevard", "blvd",
    "court", "terrace", "drive", "alley", "path", "walk", "road",
    "north", "south", "east", "west", "upper", "lower",
    "park", "hill", "heights", "valley", "mount", "mountain", "beach",
    "the", "and", "from", "into", "near",
}


def haversine(lat1, lng1, lat2, lng2):
    """Distance in meters between two lat/lng points."""
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def make_id(name, existing_ids):
    """Generate a unique slug ID from a stairway name."""
    slug = name.lower()
    slug = re.sub(r"[^a-z0-9\s-]", "", slug)
    slug = re.sub(r"\s+", "-", slug.strip())
    slug = re.sub(r"-+", "-", slug)
    slug = slug[:60].rstrip("-")

    if slug not in existing_ids:
        return slug

    counter = 2
    while f"{slug}-{counter}" in existing_ids:
        counter += 1
    return f"{slug}-{counter}"


def compute_centroids(stairways):
    """Compute lat/lng centroid for each neighborhood from stairways with coords."""
    buckets = defaultdict(list)
    for s in stairways:
        if s.get("lat") and s.get("lng"):
            buckets[s["neighborhood"]].append((s["lat"], s["lng"]))
    return {
        hood: (
            sum(p[0] for p in pts) / len(pts),
            sum(p[1] for p in pts) / len(pts),
        )
        for hood, pts in buckets.items()
    }


def assign_neighborhood(lat, lng, centroids):
    """
    Assign a neighborhood to a coordinate.
    1. Nearest existing centroid within COORD_MATCH_DIST.
    2. First matching NEW_NEIGHBORHOOD_RULES bounding box.
    3. Nearest existing centroid within RELAXED_DIST.
    4. "Unclassified".
    """
    best_hood, best_dist = None, float("inf")
    for hood, (clat, clng) in centroids.items():
        d = haversine(lat, lng, clat, clng)
        if d < best_dist:
            best_dist = d
            best_hood = hood

    if best_dist <= COORD_MATCH_DIST:
        return best_hood

    for rule in NEW_NEIGHBORHOOD_RULES:
        if (rule["lat_min"] <= lat <= rule["lat_max"] and
                rule["lng_min"] <= lng <= rule["lng_max"]):
            return rule["name"]

    if best_dist <= RELAXED_DIST:
        return best_hood

    return "Unclassified"


def _significant_words(name):
    """
    Return lowercase words from a name that are likely to be location-specific
    (length >= 4, not in the generic stopword list).
    """
    tokens = re.sub(r"[^a-z0-9\s]", " ", name.lower()).split()
    return [t for t in tokens if len(t) >= 4 and t not in _COORD_FILL_STOPWORDS]


def _first_significant_word(name):
    """Return the first significant word from a stairway name, or None."""
    words = _significant_words(name)
    return words[0] if words else None


def _names_share_a_word(our_name, uh_name):
    """
    Return True if the FIRST significant word from our name appears in the UH
    name. Using the first word (usually the street or alley name) as the anchor
    guards against false positives where only a generic street suffix matches.
    """
    first = _first_significant_word(our_name)
    if not first:
        return False
    return first in uh_name.lower()


def find_coord_fills(missing_stairways, uh_all):
    """
    For each of our stairways missing lat/lng, attempt a name-similarity match
    against all UH placemarks. Returns a list of fill dicts for review.

    A match requires both:
      - SequenceMatcher ratio >= NAME_SIM_THRESHOLD
      - At least one significant word from our name appears in the UH name
    """
    fills = []
    for stairway in missing_stairways:
        best_match = None
        best_sim = NAME_SIM_THRESHOLD
        for uh in uh_all:
            sim = SequenceMatcher(None, stairway["name"].lower(), uh["name"].lower()).ratio()
            if sim > best_sim and _names_share_a_word(stairway["name"], uh["name"]):
                best_sim = sim
                best_match = uh
        if best_match:
            fills.append({
                "id": stairway["id"],
                "name": stairway["name"],
                "uh_name": best_match["name"],
                "similarity": round(best_sim, 3),
                "lat": best_match["lat"],
                "lng": best_match["lng"],
            })
    return fills


def build_report(existing, new_entries, coord_fills, neighborhood_counts):
    today = date.today().strftime("%Y-%m-%d")
    lines = [
        "# Urban Hiker SF Import Report",
        f"Generated: {today}",
        "",
        "## Summary",
        f"- Existing stairways: {len(existing)}",
        f"- New stairways added: {len(new_entries)}",
        f"- Coordinate gap fills: {len(coord_fills)}",
        f"- Projected total: {len(existing) + len(new_entries)}",
        "",
        "## Coordinate Gap Fills",
        "",
        "These are our stairways with null lat/lng that matched a UH placemark by name similarity.",
        "Review before accepting — similarity threshold is 0.6, so some matches may be wrong.",
        "",
        "| Our Stairway | UH Match | Similarity | Lat | Lng |",
        "|---|---|---|---|---|",
    ]
    if coord_fills:
        for cf in coord_fills:
            lines.append(
                f"| {cf['name']} | {cf['uh_name']} | {cf['similarity']} "
                f"| {cf['lat']} | {cf['lng']} |"
            )
    else:
        lines.append("_(no name-similarity matches found for missing-coord stairways)_")

    lines += [
        "",
        "## New Stairways by Neighborhood",
        "",
        "| Neighborhood | Count |",
        "|---|---|",
    ]
    for hood, count in sorted(neighborhood_counts.items(), key=lambda x: -x[1]):
        lines.append(f"| {hood} | {count} |")

    lines += [
        "",
        "## All New Stairways",
        "",
        "| Name | Neighborhood | Lat | Lng |",
        "|---|---|---|---|",
    ]
    for entry in new_entries:
        lines.append(
            f"| {entry['name']} | {entry['neighborhood']} "
            f"| {entry['lat']} | {entry['lng']} |"
        )

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Import Urban Hiker SF stairway locations into all_stairways.json"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true",
                       help="Produce import_report.md without modifying any data files")
    group.add_argument("--apply", action="store_true",
                       help="Write backup, apply changes, and produce import_report.md")
    args = parser.parse_args()

    # --- Load inputs ---
    with open("data/all_stairways.json") as f:
        existing = json.load(f)

    with open("data/enrichment_analysis.json") as f:
        analysis = json.load(f)

    with open("data/urban_hiker_parsed.json") as f:
        uh_all = json.load(f)

    # Existing IDs — used for dedup check (idempotency gate)
    original_ids = {s["id"] for s in existing}

    # --- Coordinate gap fills ---
    missing_coord = [s for s in existing if not s.get("lat") or not s.get("lng")]
    coord_fills = find_coord_fills(missing_coord, uh_all)

    # --- Neighborhood centroids from existing stairways ---
    centroids = compute_centroids(existing)

    # --- Build new entries ---
    # Use a working id set that grows as we generate new IDs, to handle dedup.
    working_ids = set(original_ids)
    new_entries = []
    neighborhood_counts = defaultdict(int)
    skipped_already_imported = 0

    for uh in analysis["new_stairways"]:
        # Generate the canonical ID for this UH entry
        candidate_id = make_id(uh["name"], set())  # preview without side effects
        # Check idempotency: if this ID already exists, it was imported in a prior run
        if candidate_id in original_ids:
            skipped_already_imported += 1
            continue
        # Now actually register the ID (handles suffix dedup within this run)
        new_id = make_id(uh["name"], working_ids)
        working_ids.add(new_id)

        hood = assign_neighborhood(uh["lat"], uh["lng"], centroids)
        neighborhood_counts[hood] += 1

        new_entries.append({
            "id": new_id,
            "name": uh["name"],
            "neighborhood": hood,
            "lat": uh["lat"],
            "lng": uh["lng"],
            "height_ft": None,
            "closed": False,
            "geocode_source": "urban_hiker",
            "source_url": None,
        })

    # --- Report ---
    report = build_report(existing, new_entries, coord_fills, neighborhood_counts)
    with open("data/import_report.md", "w") as f:
        f.write(report)
    print("Report written → data/import_report.md")

    print(f"New entries to add:      {len(new_entries)}")
    print(f"Coord fills found:       {len(coord_fills)}")
    print(f"Already imported (skip): {skipped_already_imported}")
    print(f"Projected total:         {len(existing) + len(new_entries)}")

    if args.dry_run:
        print("Dry run complete — no files modified. Use --apply to write changes.")
        return

    # --- Apply ---
    backup_path = f"data/all_stairways_backup_{date.today().strftime('%Y%m%d')}.json"
    shutil.copy2("data/all_stairways.json", backup_path)
    print(f"Backup written → {backup_path}")

    # Apply coord fills (only if still null — idempotent)
    fill_map = {cf["id"]: cf for cf in coord_fills}
    fills_applied = 0
    for s in existing:
        if s["id"] in fill_map and not s.get("lat") and not s.get("lng"):
            cf = fill_map[s["id"]]
            s["lat"] = cf["lat"]
            s["lng"] = cf["lng"]
            s["geocode_source"] = "urban_hiker"
            fills_applied += 1

    merged = existing + new_entries

    with open("data/all_stairways.json", "w") as f:
        json.dump(merged, f, indent=2)

    print(f"Coord fills applied:     {fills_applied}")
    print(f"Written → data/all_stairways.json ({len(merged)} total stairways)")


if __name__ == "__main__":
    main()
