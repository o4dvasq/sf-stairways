#!/usr/bin/env python3
"""
SF Stairways scraper — produces data/all_stairways.json
Usage: pip install requests beautifulsoup4 && python scripts/scrape_stairways.py
"""

import json
import re
import time
from pathlib import Path
import requests
from bs4 import BeautifulSoup

BASE_URL   = "https://www.sfstairways.com"
INDEX_URL  = f"{BASE_URL}/stairways"
OUT_FILE   = Path(__file__).parent.parent / "data" / "all_stairways.json"
SLEEP_SITE = 0.5
SLEEP_NOM  = 1.0

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "Mozilla/5.0 (compatible; sf-stairways-scraper/2.0)"})


def fetch(url, timeout=20):
    try:
        r = SESSION.get(url, timeout=timeout)
        r.raise_for_status()
        return r
    except Exception as e:
        print(f"  ⚠ fetch error {url}: {e}")
        return None


def parse_index():
    """
    Returns list of dicts: {name, slug, neighborhood, height_ft, closed}
    The page has 3 <table class="tablesorter listTable"> tables:
      Table 0: active stairways  (cols: Name, Neighborhood, Approx height)
      Table 1: sidewalk stairways (cols: Name, Neighborhood, Approx height)
      Table 2: closed stairways   (cols: Name, Neighborhood, Notes)
    Name cells contain a link whose href is the bare slug (e.g. "arbol-lane").
    """
    r = fetch(INDEX_URL)
    if not r:
        raise RuntimeError("Could not fetch index page")

    soup = BeautifulSoup(r.text, "html.parser")
    tables = soup.find_all("table", class_="tablesorter")
    if not tables:
        raise RuntimeError("No tablesorter tables found on index page")

    items = []
    for table_idx, table in enumerate(tables):
        closed = (table_idx == 2)  # third table is closed stairways
        for row in table.find_all("tr")[1:]:  # skip header row
            cells = row.find_all("td")
            if len(cells) < 2:
                continue

            name_cell = cells[0]
            # The name link href is the slug (no leading slash, no /stairways/ prefix)
            link = name_cell.find("a", href=True)
            if not link:
                continue

            name = link.get_text(strip=True)
            slug = link["href"].strip("/")
            if not name or not slug:
                continue

            neighborhood = cells[1].get_text(strip=True) if len(cells) > 1 else ""

            # Height column exists in tables 0 and 1 only
            height_ft = None
            if not closed and len(cells) > 2:
                ht_text = cells[2].get_text(strip=True)
                ht_m = re.search(r"(\d+)", ht_text)
                if ht_m:
                    height_ft = int(ht_m.group(1))

            items.append({
                "name":        name,
                "slug":        slug,
                "neighborhood": neighborhood,
                "height_ft":   height_ft,
                "closed":      closed,
            })

    return items


def extract_coords_from_detail(url):
    """
    Returns (lat, lng, height_ft) or (None, None, None).
    Coordinates live in the <head> script as:
      initMap(zoom, lat, lng, 'galleryMap', ...)
    """
    r = fetch(url)
    if not r:
        return None, None, None

    html = r.text

    # Primary: initMap(zoom, lat, lng, ...) pattern used on every detail page
    m = re.search(r"initM(?:ap|inimap)\s*\(\s*\d+\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)", html, re.I)
    if m:
        lat, lng = float(m.group(1)), float(m.group(2))
        if 37.0 < lat < 38.5 and -123.5 < lng < -121.5:
            # Also try to grab height from the info list if not already known
            height_ft = None
            ht_m = re.search(r"Height:\s*(\d+)\s*feet", html, re.I)
            if ht_m:
                height_ft = int(ht_m.group(1))
            return lat, lng, height_ft

    # Fallback: any Google Maps embed
    gmap_re = [
        r"maps\.google\.com[^\"']*[?&]q=([-\d.]+),([-\d.]+)",
        r"google\.com/maps[^\"']*@([-\d.]+),([-\d.]+)",
        r"google\.com/maps/embed[^\"']*!3d([-\d.]+)!.*?!4d([-\d.]+)",
    ]
    for pat in gmap_re:
        gm = re.search(pat, html)
        if gm:
            lat, lng = float(gm.group(1)), float(gm.group(2))
            if 37.0 < lat < 38.5 and -123.5 < lng < -121.5:
                return lat, lng, None

    return None, None, None


def nominatim_geocode(name):
    """Returns (lat, lng) or (None, None)."""
    query = f"{name} San Francisco CA"
    url   = (
        "https://nominatim.openstreetmap.org/search"
        f"?q={requests.utils.quote(query)}&format=json&limit=1"
    )
    r = fetch(url)
    if not r:
        return None, None
    data = r.json()
    if data:
        return float(data[0]["lat"]), float(data[0]["lon"])
    return None, None


def scrape():
    print("Fetching stairway index…")
    items = parse_index()
    print(f"Found {len(items)} stairways in index tables\n")

    results = []
    total = len(items)

    for i, item in enumerate(items, 1):
        slug   = item["slug"]
        name   = item["name"]
        nbhd   = item["neighborhood"]
        closed = item["closed"]
        url    = f"{BASE_URL}/stairways/{slug}"

        print(f"[{i}/{total}] {name}", end="  ")

        if closed:
            print("→ CLOSED")
            results.append({
                "id": slug, "name": name, "neighborhood": nbhd,
                "lat": None, "lng": None,
                "height_ft": item["height_ft"], "closed": True,
                "geocode_source": None, "source_url": url,
            })
            time.sleep(SLEEP_SITE)
            continue

        lat, lng, detail_height = extract_coords_from_detail(url)
        time.sleep(SLEEP_SITE)

        # Prefer height from detail page; fall back to index table value
        height_ft = detail_height if detail_height is not None else item["height_ft"]
        source    = "page"

        if lat is None:
            print("→ trying Nominatim", end="  ")
            lat, lng = nominatim_geocode(name)
            time.sleep(SLEEP_NOM)
            source = "nominatim" if lat is not None else None

        if lat is None:
            print("→ no coords")
        else:
            print(f"→ {lat:.5f}, {lng:.5f} ({source})")

        results.append({
            "id":             slug,
            "name":           name,
            "neighborhood":   nbhd,
            "lat":            lat,
            "lng":            lng,
            "height_ft":      height_ft,
            "closed":         False,
            "geocode_source": source,
            "source_url":     url,
        })

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_FILE, "w") as f:
        json.dump(results, f, indent=2)

    resolved = sum(1 for r in results if r["lat"] is not None and not r["closed"])
    closed   = sum(1 for r in results if r["closed"])
    print(f"\nDone — {resolved}/{total} with coords, {closed} closed")
    print(f"Written to {OUT_FILE}")


if __name__ == "__main__":
    scrape()
