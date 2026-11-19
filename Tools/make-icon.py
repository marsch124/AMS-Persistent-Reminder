#!/usr/bin/env python3
"""Builds the AMS Persistent Reminder app icon: a flat calm warm orange tile with a white hand-drawn bell
inside a loop arrow ("it keeps coming back" — his pick 3A, 19 Nov 2026). One 1.9 stroke on the 24-point
grid with round ends, like every AMS icon (bell = the AMS-Icons "bell" mark). The drawing is the SVG below,
drawn by Chrome (headless) so curves are exact. No transparency in the iPhone picture.

Writes App/Resources/Assets.xcassets (AppIcon.appiconset: iPhone 1024 only; AccentColor) and Docs/icon-1024.png.
Run:  python3 Tools/make-icon.py        (needs Pillow)
"""
import json, math, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE_COLOUR = (0xE8, 0x6B, 0x45)
WHITE = (255, 255, 255)
STROKE = 1.9


def bez(p0, c1, c2, p1, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0],
                    u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1]))
    return pts


def arc(cx, cy, r, a0, a1, n=60):
    """Points on a circle from angle a0 to a1 (degrees, y down)."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


# AMS-Icons "bell": M12 3.2v1.8 M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15Z M10 20.5a2 2 0 0 0 4 0
TOP = [(12, 3.2), (12, 5)]
BODY = ([(6, 16.5), (6, 11)] + arc(12, 11, 6, 180, 360) + [(18, 11), (18, 16.5), (19.5, 18.5), (4.5, 18.5), (6, 16.5)])
CLAPPER = arc(12, 20.5, 2, 180, 0)   # small half circle below: (10,20.5) -> (14,20.5)
DY = 12 - (3.2 + 22.5) / 2          # the bell spans y 3.2..22.5: centre it on 12


def draw_glyph(d, size, share, stroke):
    k = size * share / 24.0
    o = size / 2 - 12 * k
    oy = o + DY * k
    w = max(1, round(stroke * k))

    def line(pts):
        xy = [(o + x * k, oy + y * k) for x, y in pts]
        d.line(xy, fill=WHITE, width=w, joint="curve")
        for x, y in xy:   # round ends and joins
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)

    line(TOP)
    line(BODY)
    line(CLAPPER)


BELL = "M12 3.2v1.8 M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15Z M10 20.5a2 2 0 0 0 4 0"
LOOP = "M17 3.34A10 10 0 1 1 7 3.34 M7 3.34l-1.3 2.7 M7 3.34l-3-.3"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def phone_icon():
    """Full square, no transparency: iOS rounds the corners itself. The glyph fills 75 % of the tile."""
    import subprocess, tempfile
    hexc = "#%02X%02X%02X" % TILE_COLOUR
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="-4 -4 32 32" fill="none" '
           f'stroke="#fff" stroke-width="{STROKE}" stroke-linecap="round" stroke-linejoin="round">'
           f'<rect x="-4" y="-4" width="32" height="32" fill="{hexc}" stroke="none"/>'
           f'<g transform="translate(5.3 5.6) scale(0.56)"><path d="{BELL}"/></g><path d="{LOOP}"/></svg>')
    tmp = tempfile.mkdtemp()
    page = os.path.join(tmp, "icon.html")
    with open(page, "w") as f:
        f.write(f'<html><body style="margin:0;background:{hexc}">{svg}</body></html>')
    out = os.path.join(tmp, "icon.png")
    subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--window-size=1024,1024", f"--screenshot={out}", "file://" + page],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return Image.open(out).convert("RGB").resize((1024, 1024), Image.LANCZOS)


def colour(hexs):
    r, g, b = (int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"color-space": "srgb", "components": {"alpha": "1.000", "blue": f"{b:.3f}", "green": f"{g:.3f}", "red": f"{r:.3f}"}}


if __name__ == "__main__":
    cat = os.path.join(ROOT, "App", "Resources", "Assets.xcassets")
    folder = os.path.join(cat, "AppIcon.appiconset")
    accent = os.path.join(cat, "AccentColor.colorset")
    os.makedirs(folder, exist_ok=True)
    os.makedirs(accent, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "Docs"), exist_ok=True)
    with open(os.path.join(cat, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=1)
    with open(os.path.join(accent, "Contents.json"), "w") as f:
        json.dump({"colors": [{"color": colour("F2704B"), "idiom": "universal"},
                              {"appearances": [{"appearance": "luminosity", "value": "dark"}], "color": colour("FF8A65"), "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, f)
    big = phone_icon()
    big.save(os.path.join(folder, "icon-1024.png"))
    big.save(os.path.join(ROOT, "Docs", "icon-1024.png"))
    images = [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=1)
    print("icon written; iPhone picture mode:", Image.open(os.path.join(folder, "icon-1024.png")).mode)
