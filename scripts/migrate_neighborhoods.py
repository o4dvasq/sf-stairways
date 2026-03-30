#!/usr/bin/env python3
"""
migrate_neighborhoods.py

Reassigns neighborhood field in all_stairways.json and target_list.json
from the DataSF Analysis Neighborhoods (41 neighborhoods) to the SF 311
Neighborhoods dataset (117 neighborhoods).

Algorithm:
- Stairways with (lat, lng): point-in-polygon test against 311 polygons
  (ray casting). Fallback to nearest centroid if outside all polygons.
- Stairways without coordinates: manual assignment by stairway ID.

Usage:
    python3 scripts/migrate_neighborhoods.py
"""

import json
import math
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

GEOJSON_PATH = os.path.join(REPO_ROOT, "ios/SFStairways/Resources/sf_neighborhoods.geojson")
STAIRWAYS_PATH = os.path.join(REPO_ROOT, "data/all_stairways.json")
TARGET_LIST_PATH = os.path.join(REPO_ROOT, "data/target_list.json")


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

def ray_cast_point_in_ring(lat, lng, ring):
    """Return True if (lat, lng) is inside the polygon ring (list of [lng, lat])."""
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]   # lng, lat
        xj, yj = ring[j][0], ring[j][1]
        if ((yi > lat) != (yj > lat)) and (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside


def point_in_polygon(lat, lng, geometry):
    """Return True if (lat, lng) is inside a GeoJSON Polygon or MultiPolygon geometry."""
    gtype = geometry["type"]
    if gtype == "Polygon":
        rings = geometry["coordinates"]
        # First ring = outer, rest = holes
        if not ray_cast_point_in_ring(lat, lng, rings[0]):
            return False
        for hole in rings[1:]:
            if ray_cast_point_in_ring(lat, lng, hole):
                return False
        return True
    elif gtype == "MultiPolygon":
        for polygon in geometry["coordinates"]:
            rings = polygon
            if ray_cast_point_in_ring(lat, lng, rings[0]):
                ok = True
                for hole in rings[1:]:
                    if ray_cast_point_in_ring(lat, lng, hole):
                        ok = False
                        break
                if ok:
                    return True
        return False
    return False


def compute_centroid(geometry):
    """Compute a simple centroid (average of all polygon vertices)."""
    gtype = geometry["type"]
    coords = []
    if gtype == "Polygon":
        coords = geometry["coordinates"][0]
    elif gtype == "MultiPolygon":
        # Use the largest polygon's outer ring
        largest = max(geometry["coordinates"], key=lambda p: len(p[0]))
        coords = largest[0]
    if not coords:
        return None
    lng = sum(c[0] for c in coords) / len(coords)
    lat = sum(c[1] for c in coords) / len(coords)
    return (lat, lng)


def haversine_km(lat1, lng1, lat2, lng2):
    """Great-circle distance in km between two lat/lng points."""
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = math.sin(d_lat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ---------------------------------------------------------------------------
# Load GeoJSON (SF 311 dataset — property key is "name", not "nhood")
# ---------------------------------------------------------------------------

def load_neighborhoods(geojson_path):
    with open(geojson_path) as f:
        gj = json.load(f)

    neighborhoods = []
    for feature in gj["features"]:
        name = feature["properties"]["name"]
        geometry = feature["geometry"]
        centroid = compute_centroid(geometry)
        neighborhoods.append({
            "name": name,
            "geometry": geometry,
            "centroid": centroid,
        })
    return neighborhoods


def find_neighborhood(lat, lng, neighborhoods):
    """Point-in-polygon lookup. Falls back to nearest centroid."""
    for n in neighborhoods:
        if point_in_polygon(lat, lng, n["geometry"]):
            return n["name"], "pip"

    # Fallback: nearest centroid
    best_name = None
    best_dist = float("inf")
    for n in neighborhoods:
        if n["centroid"] is None:
            continue
        clat, clng = n["centroid"]
        dist = haversine_km(lat, lng, clat, clng)
        if dist < best_dist:
            best_dist = dist
            best_name = n["name"]
    return best_name, f"nearest-centroid ({best_dist:.1f}km)"


# ---------------------------------------------------------------------------
# Manual assignments for the 15 stairways with no coordinates.
# Keyed by stairway ID. Values are SF 311 neighborhood names.
# ---------------------------------------------------------------------------

NO_COORDS_MANUAL = {
    "hudson-avenue-to-hawkins-lane":                    "Bayview",
    "pemberton-place-at-crown-terrace":                 "Upper Market",
    "miguel-street-to-beacon-street":                   "Glen Park",
    "clover-lane-19th-street-to-kite-hill":             "Eureka Valley",
    "acme-alley-corwin-street-to-grand-view-avenue":    "Eureka Valley",
    "moraga-street-east-of-14th-avenue":                "Inner Sunset",
    "ingleside-path":                                   "Ingleside Terraces",
    "kirkham-street-to-5th-avenue":                     "Inner Sunset",
    "lyon-street-between-broadway-and-pacific-avenue":  "Pacific Heights",
    "summit-way-to-gonzalez-drive":                     "Stonestown",
    "summit-way-to-font-boulevard":                     "Stonestown",
    "28th-avenue-south-of-vicente-street":              "Parkside",
    "mariposa-street-west-of-utah-street-north-side":   "Potrero Hill",
    "reno-place":                                       "North Beach",
    "dixie-alley-corbett-avenue-to-burnett-avenue":     "Upper Market",
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def migrate_stairways(stairways, neighborhoods):
    valid_names = {n["name"] for n in neighborhoods}
    results = []
    unassigned = []
    fallback_count = 0
    manual_count = 0
    pip_count = 0

    for s in stairways:
        lat = s.get("lat")
        lng = s.get("lng")
        stairway_id = s.get("id", "")

        if lat is not None and lng is not None:
            new_name, method = find_neighborhood(lat, lng, neighborhoods)
            if method == "pip":
                pip_count += 1
            else:
                fallback_count += 1
                print(f"  FALLBACK ({method}): {stairway_id} → {new_name}")
        else:
            # No coordinates — use manual assignment by stairway ID
            new_name = NO_COORDS_MANUAL.get(stairway_id)
            method = "manual"
            manual_count += 1
            if new_name:
                print(f"  MANUAL (no coords): {stairway_id} → {new_name}")
            else:
                print(f"  WARNING: No manual assignment for id='{stairway_id}'")
                new_name = s.get("neighborhood", "")
                unassigned.append(stairway_id)

        if new_name not in valid_names:
            print(f"  ERROR: '{new_name}' is not a valid 311 neighborhood! (id={stairway_id})")

        updated = dict(s)
        updated["neighborhood"] = new_name
        results.append(updated)

    print(f"\nSummary:")
    print(f"  Point-in-polygon:  {pip_count}")
    print(f"  Centroid fallback: {fallback_count}")
    print(f"  Manual (no coords): {manual_count}")
    print(f"  Unassigned:        {len(unassigned)}")
    if unassigned:
        print(f"  Unassigned IDs:    {unassigned}")

    return results


def main():
    print("Loading GeoJSON (SF 311 Neighborhoods)...")
    neighborhoods = load_neighborhoods(GEOJSON_PATH)
    print(f"  {len(neighborhoods)} neighborhoods loaded")

    # --- Migrate all_stairways.json ---
    print(f"\nLoading {STAIRWAYS_PATH}...")
    with open(STAIRWAYS_PATH) as f:
        stairways = json.load(f)
    print(f"  {len(stairways)} stairways loaded")

    print("\nMigrating stairways...")
    updated_stairways = migrate_stairways(stairways, neighborhoods)

    with open(STAIRWAYS_PATH, "w") as f:
        json.dump(updated_stairways, f, indent=2)
    print(f"\nWrote {len(updated_stairways)} stairways to {STAIRWAYS_PATH}")

    # Verify
    from collections import Counter
    counts = Counter(s["neighborhood"] for s in updated_stairways)
    unique_hoods = sorted(counts)
    print(f"\nNeighborhood distribution ({len(unique_hoods)} unique):")
    for name in unique_hoods:
        print(f"  {name}: {counts[name]}")

    # --- Migrate target_list.json ---
    if os.path.exists(TARGET_LIST_PATH):
        print(f"\nLoading {TARGET_LIST_PATH}...")
        with open(TARGET_LIST_PATH) as f:
            targets = json.load(f)
        print(f"  {len(targets)} targets loaded")
        print("\nMigrating targets...")
        updated_targets = migrate_stairways(targets, neighborhoods)
        with open(TARGET_LIST_PATH, "w") as f:
            json.dump(updated_targets, f, indent=2)
        print(f"Wrote {len(updated_targets)} targets to {TARGET_LIST_PATH}")

    print("\nDone.")


if __name__ == "__main__":
    main()
