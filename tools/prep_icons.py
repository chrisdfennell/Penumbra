#!/usr/bin/env python3
"""Copy the source icon SVGs into resources/drawables, normalising them for the
Garmin resource compiler.

For each SVG in assets/icons/ we:
  * strip a leading UTF-8 BOM (the compiler's XML parser is happier without it),
  * bump the <svg> tag's width/height to RASTER_PX so the build rasterises a crisp
    bitmap at roughly the size we draw it (only the FIRST width/height pair, which
    is the <svg> element's - inner <rect> width/height are left untouched).

Run from the project root:  python tools/prep_icons.py
"""

import os
import re
import sys

RASTER_PX = 30

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "icons")
DST = os.path.join(ROOT, "resources", "drawables")

SVG_WH = re.compile(r'width="\d+(?:\.\d+)?" height="\d+(?:\.\d+)?"')


def main():
    if not os.path.isdir(SRC):
        print(f"Source icon dir not found: {SRC}", file=sys.stderr)
        return 1
    os.makedirs(DST, exist_ok=True)

    count = 0
    for name in sorted(os.listdir(SRC)):
        if not name.lower().endswith(".svg"):
            continue
        with open(os.path.join(SRC, name), "r", encoding="utf-8-sig") as fh:
            text = fh.read()
        # Resize only the first (svg-tag) width/height pair.
        text = SVG_WH.sub(f'width="{RASTER_PX}" height="{RASTER_PX}"', text, count=1)
        with open(os.path.join(DST, name), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        count += 1
        print(f"  {name}")

    print(f"Prepared {count} icon(s) -> {DST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
