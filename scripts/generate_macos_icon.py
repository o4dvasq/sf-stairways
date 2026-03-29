#!/usr/bin/env python3
"""
generate_macos_icon.py — Generate macOS app icon for SFStairways Mac.

Draws a white 3-step stair silhouette on a brandOrange (#E8602C) background
with rounded corners (macOS squircle approximation).

Output: ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset/*.png

Run from project root:
    python3 scripts/generate_macos_icon.py

Requires Pillow:
    pip install Pillow
"""

import os
import math
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)

# Brand colors
BRAND_ORANGE = (0xE8, 0x60, 0x2C, 0xFF)
WHITE = (0xFF, 0xFF, 0xFF, 0xFF)
TRANSPARENT = (0, 0, 0, 0)

OUTPUT_DIR = "ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset"

# (filename, pixel_size) — all required macOS icon sizes
SIZES = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]


def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # Rounded background: corner radius ~20% of icon size (macOS squircle approx)
    radius = max(1, int(size * 0.20))
    draw.rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=radius,
        fill=BRAND_ORANGE,
    )

    # Stair shape: white, with ~17% padding on each side
    pad = max(1, int(size * 0.17))
    sw = size - pad * 2   # stair bounding-box width
    sh = size - pad * 2   # stair bounding-box height
    x0, y0 = float(pad), float(pad)

    sw3 = sw / 3.0
    sh3 = sh / 3.0

    # 3-step ascending stair: bottom-left → top-right
    # Matches StairShape in TeardropPin.swift
    polygon = [
        (x0,           y0 + sh),          # bottom-left
        (x0,           y0 + 2 * sh3),     # up step 1
        (x0 + sw3,     y0 + 2 * sh3),     # right step 1
        (x0 + sw3,     y0 + sh3),         # up step 2
        (x0 + 2 * sw3, y0 + sh3),         # right step 2
        (x0 + 2 * sw3, y0),               # up step 3
        (x0 + sw,      y0),               # right step 3 (top-right)
        (x0 + sw,      y0 + sh),          # bottom-right
    ]
    polygon = [(round(x), round(y)) for x, y in polygon]
    draw.polygon(polygon, fill=WHITE)

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for filename, size in SIZES:
        path = os.path.join(OUTPUT_DIR, filename)
        img = make_icon(size)
        img.save(path, "PNG")
        print(f"  {filename} ({size}x{size}px)")
    print(f"\nDone. Icons written to {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
