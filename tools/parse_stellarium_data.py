#!/usr/bin/env python3
"""
Builds res://data/stars.json and res://data/constellations.json for the Godot project from:
  - HYG star catalog (resources/hyg/hyg/CURRENT/hygdata_v41.csv) -- RA/Dec/mag by HIP number
  - Stellarium's modern_iau skyculture (resources/stellarium/skycultures/modern_iau/index.json)
    -- the 88 IAU constellations, line figures given as HIP-number polylines

Stellarium's own star catalog (stars/hip_gaia3/*.cat) uses a custom versioned binary
zone format meant for its own renderer, so we sidestep it and use the plain-CSV HYG
catalog instead (same HIP numbering, easy to parse, already capped to naked-eye-plus stars).

No constellation *boundary* polygons are shipped for modern_iau in the stellarium repo
(the IAU boundaries are compiled into its C++ source, not a data file), so tap hit-testing
in-game falls back to angular distance to the nearest constellation-line star. Good enough
for v1; swap in real IAU boundary data later if precision matters.
"""

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HYG_CSV = ROOT / "resources/hyg/hyg/CURRENT/hygdata_v41.csv"
SKYCULTURE_JSON = ROOT / "resources/stellarium/skycultures/modern_iau/index.json"
STARS_OUT = ROOT / "data/stars.json"
CONSTELLATIONS_OUT = ROOT / "data/constellations.json"

FAINTEST_MAG_FOR_RENDER = 6.5  ## naked-eye limit; keeps stars.json small


def load_hyg_catalog() -> dict[int, dict]:
    """Returns {hip_number: {"ra": deg, "dec": deg, "mag": float, "name": str|None}}"""
    catalog: dict[int, dict] = {}
    with open(HYG_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            hip = row["hip"]
            if not hip:
                continue
            ci = row["ci"]
            catalog[int(hip)] = {
                "ra": float(row["ra"]) * 15.0,  # HYG stores RA in decimal hours
                "dec": float(row["dec"]),
                "mag": float(row["mag"]),
                "ci": float(ci) if ci else 0.65,  # B-V color index; 0.65 ~ Sun-like default
                "name": row["proper"] or None,
            }
    return catalog


def collect_constellation_hips() -> set[int]:
    """HIP numbers that appear as a line endpoint in any constellation figure.
    These stay visible at any zoom level even if the dynamic magnitude cutoff
    would otherwise hide them, so a constellation's shape never breaks apart."""
    data = json.loads(SKYCULTURE_JSON.read_text())
    hips: set[int] = set()
    for c in data["constellations"]:
        for polyline in c["lines"]:
            hips.update(polyline)
    return hips


def write_stars_json(catalog: dict[int, dict], constellation_hips: set[int]) -> None:
    stars = [
        {
            "id": hip,
            "ra": round(s["ra"], 5),
            "dec": round(s["dec"], 5),
            "mag": round(s["mag"], 2),
            "ci": round(s["ci"], 3),
            **({"name": s["name"]} if s["name"] else {}),
            **({"con": True} if hip in constellation_hips else {}),
        }
        for hip, s in catalog.items()
        if s["mag"] <= FAINTEST_MAG_FOR_RENDER
    ]
    STARS_OUT.write_text(json.dumps(stars, separators=(",", ":")))
    print(f"wrote {STARS_OUT} ({len(stars)}/{len(catalog)} stars, mag <= {FAINTEST_MAG_FOR_RENDER})")


def write_constellations_json(catalog: dict[int, dict]) -> None:
    data = json.loads(SKYCULTURE_JSON.read_text())
    out = []
    missing_hip = 0

    for c in data["constellations"]:
        abbr = re.sub(r"^CON modern_iau ", "", c["id"])
        segments = []
        for polyline in c["lines"]:
            for hip_a, hip_b in zip(polyline, polyline[1:]):
                star_a = catalog.get(hip_a)
                star_b = catalog.get(hip_b)
                if star_a is None or star_b is None:
                    missing_hip += 1
                    continue
                segments.append([star_a["ra"], star_a["dec"], star_b["ra"], star_b["dec"]])
        out.append({
            "id": abbr,
            "name": c["common_name"]["english"],
            "segments": [[round(v, 5) for v in seg] for seg in segments],
        })

    CONSTELLATIONS_OUT.write_text(json.dumps(out, separators=(",", ":")))
    print(f"wrote {CONSTELLATIONS_OUT} ({len(out)} constellations, {missing_hip} unresolved HIP refs)")


def main() -> None:
    STARS_OUT.parent.mkdir(parents=True, exist_ok=True)
    catalog = load_hyg_catalog()
    constellation_hips = collect_constellation_hips()
    write_stars_json(catalog, constellation_hips)
    write_constellations_json(catalog)


if __name__ == "__main__":
    main()
