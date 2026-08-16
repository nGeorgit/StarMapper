#!/usr/bin/env python3
"""
Builds res://data/stars.json and res://data/constellation_sets/*.json for the Godot project from:
  - HYG star catalog (resources/hyg/hyg/CURRENT/hygdata_v41.csv) -- RA/Dec/mag by HIP number
  - every Stellarium skyculture under resources/stellarium/skycultures/*/index.json
    -- each one's constellation/asterism figures, given as HIP-number polylines

Stellarium's own star catalog (stars/hip_gaia3/*.cat) uses a custom versioned binary
zone format meant for its own renderer, so we sidestep it and use the plain-CSV HYG
catalog instead (same HIP numbering, easy to parse, already capped to naked-eye-plus stars).

One JSON file is written per skyculture to data/constellation_sets/<id>.json, plus a
data/constellation_sets/manifest.json index the game reads to populate the set picker.
ConstellationSets.gd (autoload) loads whichever set is active; StarField.gd cross-references
its "hips" list against each star's "id" to decide which stars must stay visible regardless
of the zoom-driven magnitude cutoff, so no "always visible" flag needs to be baked into
stars.json itself -- that catalog stays completely set-independent.

No constellation *boundary* polygons are shipped in the stellarium repo (IAU boundaries are
compiled into its C++ source, not a data file), so tap hit-testing in-game falls back to
angular distance to the nearest constellation-line star. Good enough for v1.
"""

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HYG_CSV = ROOT / "resources/hyg/hyg/CURRENT/hygdata_v41.csv"
SKYCULTURES_DIR = ROOT / "resources/stellarium/skycultures"
STARS_OUT = ROOT / "data/stars.json"
SETS_OUT_DIR = ROOT / "data/constellation_sets"

FAINTEST_MAG_FOR_RENDER = 6.5  ## naked-eye limit; keeps stars.json small
DEFAULT_SET_ID = "modern_iau"  ## western/IAU 88 -- matches the game's previous single-set default


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


def write_stars_json(catalog: dict[int, dict]) -> None:
    stars = [
        {
            "id": hip,
            "ra": round(s["ra"], 5),
            "dec": round(s["dec"], 5),
            "mag": round(s["mag"], 2),
            "ci": round(s["ci"], 3),
            **({"name": s["name"]} if s["name"] else {}),
        }
        for hip, s in catalog.items()
        if s["mag"] <= FAINTEST_MAG_FOR_RENDER
    ]
    STARS_OUT.write_text(json.dumps(stars, separators=(",", ":")))
    print(f"wrote {STARS_OUT} ({len(stars)}/{len(catalog)} stars, mag <= {FAINTEST_MAG_FOR_RENDER})")


def culture_display_name(culture_dir: Path) -> str:
    desc = culture_dir / "description.md"
    if desc.exists():
        for line in desc.read_text(encoding="utf-8").splitlines():
            if line.startswith("# "):
                return line[2:].strip()
    return culture_dir.name.replace("_", " ").title()


def common_name_for(c: dict) -> str:
    cn = c.get("common_name") or {}
    return cn.get("english") or cn.get("native") or c["id"]


def resolve_point(catalog: dict[int, dict], pt, all_hips: set[int]) -> tuple[float, float] | None:
    """A line point is either a HIP number (int), a literal [ra_deg, dec_deg] pair for
    freeform curves not tied to any cataloged star, or a "DSO:..."/"PL:..." object
    reference we have no catalog for and skip."""
    if isinstance(pt, int):
        star = catalog.get(pt)
        if star is None:
            return None
        all_hips.add(pt)
        return (star["ra"], star["dec"])
    if isinstance(pt, list) and len(pt) == 2:
        return (float(pt[0]), float(pt[1]))
    return None


def write_constellation_set(culture_dir: Path, catalog: dict[int, dict]) -> dict | None:
    index_path = culture_dir / "index.json"
    data = json.loads(index_path.read_text(encoding="utf-8"))
    cons = data.get("constellations", [])
    if not cons:
        return None

    out_cons = []
    all_hips: set[int] = set()
    unresolved = 0

    for c in cons:
        abbr = re.sub(r"^CON \S+ ", "", c["id"])
        segments = []
        for polyline in c["lines"]:
            for pt_a, pt_b in zip(polyline, polyline[1:]):
                a = resolve_point(catalog, pt_a, all_hips)
                b = resolve_point(catalog, pt_b, all_hips)
                if a is None or b is None:
                    unresolved += 1
                    continue
                segments.append([a[0], a[1], b[0], b[1]])
        if not segments:
            continue
        out_cons.append({
            "id": abbr,
            "name": common_name_for(c),
            "segments": [[round(v, 5) for v in seg] for seg in segments],
        })

    if not out_cons:
        return None

    set_id = data["id"]
    out = {
        "id": set_id,
        "hips": sorted(all_hips),
        "constellations": out_cons,
    }
    out_path = SETS_OUT_DIR / f"{set_id}.json"
    out_path.write_text(json.dumps(out, separators=(",", ":")))

    return {
        "id": set_id,
        "name": culture_display_name(culture_dir),
        "region": data.get("region", "World"),
        "count": len(out_cons),
    }


def main() -> None:
    STARS_OUT.parent.mkdir(parents=True, exist_ok=True)
    SETS_OUT_DIR.mkdir(parents=True, exist_ok=True)

    catalog = load_hyg_catalog()
    write_stars_json(catalog)

    manifest = []
    for culture_dir in sorted(SKYCULTURES_DIR.iterdir()):
        if not (culture_dir / "index.json").exists():
            continue
        entry = write_constellation_set(culture_dir, catalog)
        if entry is not None:
            manifest.append(entry)

    if not any(e["id"] == DEFAULT_SET_ID for e in manifest):
        raise SystemExit(f"DEFAULT_SET_ID {DEFAULT_SET_ID!r} not found among parsed sets")

    manifest.sort(key=lambda e: e["name"])
    (SETS_OUT_DIR / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")))
    print(f"wrote {len(manifest)} constellation sets to {SETS_OUT_DIR}/ (default: {DEFAULT_SET_ID})")


if __name__ == "__main__":
    main()
