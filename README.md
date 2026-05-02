# BEV Trajectories — Gallery-TEST

Development/staging counterpart to `LeRaffl-Gallery`.

## What's in here

- `index.html` — the gallery UI (EN), Gallery / Thresholds / Durations tabs
- `manifest.json` — auto-generated chart index (`build_manifest.R`)
- `params.csv` / `weights.csv` — fitted model parameters per country/variant
- `images/<YYYY-MM>/` — PNG charts, served statically
- `data/raw/bev_share_acea.xlsx` — canonical raw registration data (one sheet per country)
- `R/` — consolidated R pipeline. See `R/README.md`.
- `legacy/` — archived per-country R + shell scripts (reference only, not maintained)

## Generating charts

One country:

```sh
Rscript R/bev_share.R Austria
Rscript R/bev_share.R "Denmark (HDV)"
```

All countries:

```sh
Rscript R/run_all.R --skip-fail
```

This regenerates the four charts per country/variant under `images/<YYYY-MM>/` and upserts the row in `params.csv` + `weights.csv`. The pipeline writes only to the working tree — committing is up to you (or to the GitHub Actions workflow at `.github/workflows/r_pipeline.yml`).

## Refreshing manifest.json

After new images land:

```r
source("build_manifest.R")
build_manifest(root = "images", base_url = "images/")
```

## Hosting

Commit & push. GitHub Pages serves `index.html`; the gallery reads `manifest.json`. The UI filters by **country**, **type**, **period** and has a **Latest only** toggle (shows only the newest per country+type when no month is selected).
