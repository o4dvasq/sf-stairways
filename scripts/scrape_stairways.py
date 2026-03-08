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

BASE_URL    = "https://www.sfstairways.com"
INDEX_URL   = f"{BASE_URL}/stairways"
OUT_FILE    = Path(__file__).parent.parent / "data" / "all_stairways.json"
SLEEP_SITE  = 0.5
SLEEP_NOM   = 1.0

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "sf-stairways-scraper/1.0 (+https://github.com)"})


def fetch(url, timeout=15):
    try:
        r = SESSION.get(url, timeout=timeout)
        r.raise_for_status()
        return r
    except Exception as e:
        print(f"  ⚠ fetch error {url}: {e}")
        return None


def slugify(name: str) -> str:
    slug = name.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug


def extract_coords_from_page(url: str):
    """Return (lat, lng) or (None, None) from a stairway detail page."""
    r = fetch(url)
    if not r:
        return None, None

    html = r.text

    # 1. Google Maps embed ?q= or center= params
    gmap_re = [
        r"maps\.google\.com[^\"']*[?&]q=([-\d.]+),([-\d.]+)",
        r"maps\.google\.com[^\"']*center=([-\d.]+),([-\d.]+)",
        r"google\.com/maps/embed[^\"']*!3d([-\d.]+)!.*?!4d([-\d.]+)",
        r"google\.com/maps[^\"']*@([-\d.]+),([-\d.]+)",
    ]
    for pat in gmap_re:
        m = re.search(pat, html)
        if m:
            return float(m.group(1)), float(m.group(2))

    # 2. JS variables: lat = 37.xxx, lng = -122.xxx
    lat_m = re.search(r"lat\s*[=:]\s*([-\d.]{6,})", html)
    lng_m = re.search(r"l(?:ng|on)\s*[=:]\s*([-\d.]{7,})", html)
    if lat_m and lng_m:
        lat, lng = float(lat_m.group(1)), float(lng_m.group(1))
        if 37.0 < lat < 38.5 and -123.5 < lng < -121.5:
            return lat, lng

    # 3. JSON-LD geo
    for script in BeautifulSoup(html, "html.parser").find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
            geo  = data.get("geo") or {}
            if geo.get("latitude") and geo.get("longitude"):
                return float(geo["latitude"]), float(geo["longitude"])
        except Exception:
            pass

    return None, None


def nominatim_geocode(name: str):
    """Return (lat, lng) or (None, None) from Nominatim."""
    query = f"{name} San Francisco CA"
    url   = f"https://nominatim.openstreetmap.org/search?q={requests.utils.quote(query)}&format=json&limit=1"
    r = fetch(url)
    if not r:
        return None, None
    data = r.json()
    if data:
        return float(data[0]["lat"]), float(data[0]["lon"])
    return None, None


def get_stairway_list():
    """Return list of (name, slug, neighborhood) from the index page."""
    r = fetch(INDEX_URL)
    if not r:
        raise RuntimeError("Could not fetch index page")

    soup  = BeautifulSoup(r.text, "html.parser")
    items = []

    # The site uses various markup; try common patterns
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if "/stairways/" in href and href != "/stairways/":
            slug = href.rstrip("/").split("/")[-1]
            name = a.get_text(strip=True)
            if not name or len(name) < 3:
                continue
            # Try to find neighborhood from surrounding context
            parent = a.find_parent(["li", "div", "article"])
            neighborhood = ""
            if parent:
                small = parent.find(["small", "span", "p"])
                if small and small != a:
                    neighborhood = small.get_text(strip=True)
            items.append({"name": name, "slug": slug, "neighborhood": neighborhood})

    # Deduplicate by slug
    seen = set()
    unique = []
    for item in items:
        if item["slug"] not in seen:
            seen.add(item["slug"])
            unique.append(item)

    return unique


def is_closed(soup: BeautifulSoup, html: str) -> bool:
    keywords = ["closed", "demolished", "removed", "no longer accessible"]
    text = html.lower()
    return any(k in text for k in keywords)


def scrape():
    print("Fetching stairway list…")
    try:
        stairways = get_stairway_list()
    except RuntimeError as e:
        print(f"Error: {e}")
        return

    if not stairways:
        print("No stairways found on index page — check site structure")
        return

    total   = len(stairways)
    results = []

    for i, item in enumerate(stairways, 1):
        slug   = item["slug"]
        name   = item["name"]
        nbhd   = item["neighborhood"]
        url    = f"{BASE_URL}/stairways/{slug}"

        print(f"[{i}/{total}] {name}", end="  ")

        # Fetch detail page
        r = fetch(url)
        time.sleep(SLEEP_SITE)

        if r:
            html = r.text
            soup = BeautifulSoup(html, "html.parser")

            if is_closed(soup, html):
                print("→ CLOSED, skipping")
                results.append({
                    "id": slug, "name": name, "neighborhood": nbhd,
                    "lat": None, "lng": None,
                    "height_ft": None, "closed": True,
                    "geocode_source": None, "source_url": url
                })
                continue

            # Height
            height_ft = None
            ht_m = re.search(r"(\d+)\s*(?:foot|feet|ft|steps? of elevation)", html, re.I)
            if ht_m:
                height_ft = int(ht_m.group(1))

            lat, lng = extract_coords_from_page(url)
            source   = "page"
        else:
            lat, lng, height_ft = None, None, None
            source = None

        if lat is None:
            print("→ trying Nominatim", end="  ")
            lat, lng = nominatim_geocode(name)
            time.sleep(SLEEP_NOM)
            source = "nominatim" if lat is not None else None

        if lat is None:
            print("→ no coords")
        else:
            print(f"→ {lat:.4f}, {lng:.4f} ({source})")

        results.append({
            "id":             slug,
            "name":           name,
            "neighborhood":   nbhd,
            "lat":            lat,
            "lng":            lng,
            "height_ft":      height_ft,
            "closed":         False,
            "geocode_source": source,
            "source_url":     url
        })

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_FILE, "w") as f:
        json.dump(results, f, indent=2)

    resolved = sum(1 for r in results if r["lat"] is not None and not r["closed"])
    closed   = sum(1 for r in results if r["closed"])
    print(f"\nDone — {resolved}/{total} with coords, {closed} closed/skipped")
    print(f"Written to {OUT_FILE}")


if __name__ == "__main__":
    scrape()
