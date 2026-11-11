#!/usr/bin/env python3
"""List trilema.com posts referenced in monthly indexes but missing from the repo."""

import os
import re
import sys
import glob

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def main():
    year_filter = sys.argv[1] if len(sys.argv) > 1 else None

    # Build set of existing post dirs: year/slug
    existing = set()
    for year in range(2008, 2022):
        ydir = os.path.join(REPO, str(year))
        if not os.path.isdir(ydir):
            continue
        for entry in os.listdir(ydir):
            if re.match(r'^\d{2}$', entry):
                continue
            full = os.path.join(ydir, entry)
            if os.path.isdir(full) and os.path.exists(os.path.join(full, "index.html")):
                existing.add(f"{year}/{entry}")

    # Posts misplaced at root level
    root_slugs = set()
    for entry in os.listdir(REPO):
        if re.match(r'^20\d{2}$', entry):
            continue
        full = os.path.join(REPO, entry)
        if os.path.isdir(full) and os.path.exists(os.path.join(full, "index.html")):
            root_slugs.add(entry)

    # Parse monthly indexes
    pattern = os.path.join(REPO, "20[0-9][0-9]", "[0-9][0-9]", "index.html")
    referenced = set()
    for index_path in sorted(glob.glob(pattern)):
        with open(index_path, encoding="latin-1") as f:
            html = f.read()
        for href in re.findall(r'href="/(20\d{2}/[a-z0-9][a-z0-9_.%-]*[a-z0-9])/?(?:"|#)', html):
            parts = href.split("/")
            if len(parts) == 2 and not re.match(r'^\d{2}$', parts[1]):
                referenced.add(href)

    # Find missing
    for ref in sorted(referenced):
        year, slug = ref.split("/", 1)
        if year_filter and year != year_filter:
            continue
        if ref not in existing and slug not in root_slugs:
            print(ref)

if __name__ == "__main__":
    main()
