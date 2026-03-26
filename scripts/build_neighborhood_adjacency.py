#!/usr/bin/env python3
"""
build_neighborhood_adjacency.py

Generates neighborhood_centroids.json and neighborhood_adjacency.json from
all_stairways.json. These are bundled in the iOS app for the "Around Me" feature.

Neighborhood centroids are computed from the average lat/lng of stairways in
each neighborhood. Adjacency is determined by centroid-to-centroid distance
(neighborhoods whose centroids are within ADJACENCY_THRESHOLD_M apart).

Run from the project root:
    python3 scripts/build_neighborhood_adjacency.py

Output:
    ios/SFStairways/Resources/neighborhood_centroids.json
    ios/SFStairways/Resources/neighborhood_adjacency.json
"""

import json
import math
import os

ADJACENCY_THRESHOLD_M = 2500  # meters between centroids to count as adjacent


def haversine(lat1, lng1, lat2, lng2):
    """Return distance in meters between two lat/lng coordinates."""
    R = 6_371_000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    stairways_path = os.path.join(root, "data", "all_stairways.json")
    out_dir = os.path.join(root, "ios", "SFStairways", "Resources")

    with open(stairways_path) as f:
        stairways = json.load(f)

    # Group stairways by neighborhood (only those with valid coordinates)
    neighborhood_coords: dict[str, list[tuple[float, float]]] = {}
    for s in stairways:
        lat = s.get("lat")
        lng = s.get("lng")
        name = s.get("neighborhood", "").strip()
        if lat is not None and lng is not None and name:
            neighborhood_coords.setdefault(name, []).append((lat, lng))

    # Compute centroid for each neighborhood
    centroids: dict[str, dict] = {}
    for name, coords in neighborhood_coords.items():
        avg_lat = sum(c[0] for c in coords) / len(coords)
        avg_lng = sum(c[1] for c in coords) / len(coords)
        centroids[name] = {"lat": avg_lat, "lng": avg_lng}

    # Compute adjacency by centroid distance
    adjacency: dict[str, list[str]] = {name: [] for name in centroids}
    names = list(centroids.keys())
    for i, n1 in enumerate(names):
        c1 = centroids[n1]
        for n2 in names[i + 1:]:
            c2 = centroids[n2]
            dist = haversine(c1["lat"], c1["lng"], c2["lat"], c2["lng"])
            if dist <= ADJACENCY_THRESHOLD_M:
                adjacency[n1].append(n2)
                adjacency[n2].append(n1)

    # Sort adjacency lists for deterministic output
    adjacency = {k: sorted(v) for k, v in sorted(adjacency.items())}
    centroids = dict(sorted(centroids.items()))

    os.makedirs(out_dir, exist_ok=True)

    centroids_path = os.path.join(out_dir, "neighborhood_centroids.json")
    with open(centroids_path, "w") as f:
        json.dump(centroids, f, indent=2)
    print(f"Wrote {len(centroids)} neighborhood centroids → {centroids_path}")

    adjacency_path = os.path.join(out_dir, "neighborhood_adjacency.json")
    with open(adjacency_path, "w") as f:
        json.dump(adjacency, f, indent=2)
    print(f"Wrote adjacency map ({ADJACENCY_THRESHOLD_M}m threshold) → {adjacency_path}")

    # Print summary
    avg_neighbors = sum(len(v) for v in adjacency.values()) / len(adjacency) if adjacency else 0
    print(f"Average neighbors per neighborhood: {avg_neighbors:.1f}")


if __name__ == "__main__":
    main()
