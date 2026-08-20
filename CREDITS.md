# Credits & Data Attribution

StarMapper's code is MIT licensed (see [LICENSE](LICENSE)). The star and
constellation data it ships (`data/stars.json`, `data/constellations.json`)
is built from third-party astronomical catalogs and is licensed separately
under **CC BY-SA 4.0** (see [data/LICENSE](data/LICENSE)) — attribution and
share-alike terms below apply to that data specifically.

## HYG Database

Star positions (RA/Dec), magnitudes, B-V color index, and proper names come
from the **HYG Database v4.1**, compiled by David Nash / AstroNexus, combining
data from the Hipparcos, Yale Bright Star, and Gliese catalogs.

- Source: https://codeberg.org/astronexus/hyg
- License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- File used: `hygdata_v41.csv`

## Stellarium (`modern_iau` skyculture)

Constellation line figures and the 88 official IAU constellation names come
from Stellarium's `modern_iau` skyculture dataset.

- Source: https://github.com/Stellarium/stellarium
  (`skycultures/modern_iau`)
- Skyculture data license: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
  (declared in that skyculture's own `description.md`; distinct from the
  Stellarium *application*, which is GPLv2 — no Stellarium program code is
  used or bundled by StarMapper, only this one skyculture data file)

## Milky Way panorama background (`textures/milkyway_panorama.jpg`)

The all-sky background image is ESO's Milky Way panorama.

- Credit: ESO/S. Brunier
- Source: https://www.eso.org/public/images/eso0932a/
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Split from the original 6000x3000 TIFF into 4 quadrant tiles
  (`textures/milkyway_c{0,1}_r{0,1}.jpg`, 3000x1500 each) so the full source
  resolution can be used without exceeding the ~4096px single-texture
  dimension cap common on Android GPUs. Sampled back together into one sky
  by `shaders/milkyway_sky.gdshader`.

## Culture menu category icons (`assets/culture_icons/`)

The Culture menu groups related skycultures (Chinese, Modern, Arabic, Greek,
Babylonian) behind a single tile, each shown with a small glyph of one
representative constellation from that group, drawn in the same dot-and-line
style the app itself uses on the sky sphere (`ConstellationLines.gd`/
`StarField.gd`). These are generated, not copied artwork -- built by
`tools/generate_culture_icons.py` from each skyculture's own line/star
position data (`data/constellation_sets/<id>.json`), the same data already
shipped and used for gameplay by every culture in the Culture menu. See that
skyculture's own `resources/stellarium/skycultures/<id>/description.md` for
its specific license terms.

## How the data is built

`tools/parse_stellarium_data.py` reads local clones of the two repos above
(`resources/hyg/`, `resources/stellarium/` — not committed, see `.gitignore`)
and regenerates `data/stars.json` + `data/constellations.json`. To rebuild:

```
git clone https://codeberg.org/astronexus/hyg resources/hyg
git clone --depth 1 https://github.com/Stellarium/stellarium resources/stellarium
python3 tools/parse_stellarium_data.py
```

## Attribution notice (required by CC BY-SA 4.0)

If you redistribute or adapt `data/stars.json` or `data/constellations.json`,
include a notice equivalent to:

> Star and constellation data derived from the HYG Database
> (https://codeberg.org/astronexus/hyg) and Stellarium's modern_iau
> skyculture (https://github.com/Stellarium/stellarium), both
> CC BY-SA 4.0, adapted by StarMapper (https://github.com/nGeorgit/StarMapper).
