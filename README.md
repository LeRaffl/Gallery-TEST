# BEV Trajectories - Gallery-TEST

This is the staging repo for the public BEV Gallery. Use this repo to test
data updates, charts, UI changes and deployment before anything is copied to
the production gallery.

## Konzept in 60 Sekunden

- `index.html` is the entire app: static HTML/CSS/JS, no backend for the gallery.
- The canonical source data lives in `data/markets/*.csv`, one long-format CSV per market.
- `R/run_all.R` reads those CSVs, fits the BEV and ICE transition curves, writes charts, `params.csv`, `weights.csv` and post snippets.
- `build_manifest.R` scans `images/` and writes `manifest.json`; the Gallery tab only knows images through that manifest.
- GitHub Actions can scrape ACEA data, run the R pipeline, rebuild `manifest.json`, and deploy GitHub Pages.
- TEST and PROD are separate repos. TEST is for staging; production updates are copied/merged manually later.

## Important Files

| Path | What it is |
| --- | --- |
| `index.html` | Static dashboard: Gallery, Thresholds, Durations, Builder, Fleet, World Map, FAQ, Feedback, Data Submission |
| `data/markets/_index.csv` | Market registry: slug, sheet/display name, country, variant, source |
| `data/markets/<slug>.csv` | Canonical long-format registration data |
| `params.csv` | Generated model parameters, read by Thresholds, Durations and World Map |
| `weights.csv` | Generated market weights, read by Fleet/Builder pieces |
| `images/<YYYY-MM>/` | Generated PNG charts |
| `manifest.json` | Generated image index for the Gallery tab |
| `posts/*.txt` | Generated social-post snippets |
| `R/` | Consolidated R pipeline |
| `scripts/scrape_acea.py` | ACEA PDF scraper |
| `.github/workflows/*.yml` | GitHub Actions automation |
| `legacy/` | Archived old scripts, reference only |

## GitHub Actions

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ACEA scrape` | Manual `workflow_dispatch` | Downloads one monthly ACEA press-release PDF, extracts the by-market power-source table, and upserts ACEA-driven `data/markets/*.csv`. If the default ACEA PDF does not exist yet, the workflow exits successfully with no changes. Use `url` for an explicit PDF source. |
| `R pipeline (BEV trajectories)` | Manual, or push to `data/markets/**.csv` | Runs `R/run_all.R`, rebuilds charts, `params.csv`, `weights.csv`, posts, and `manifest.json`. It commits outputs back only when requested manually or when triggered by a data-file push. |
| `Build manifest` | Push to image/site inputs, or manual | Rebuilds `manifest.json` from generated images and commits it back if needed. |

## Data Format

`data/markets/<slug>.csv` is the source of truth. Do not edit
`params.csv`, `weights.csv` or `manifest.json` by hand unless you are
debugging generated output.

Required columns:

```csv
period,interval,year,category,registrations,source
2026M03,monthly,2025.166667,BEV,4830,https://example.com/source
```

- `period`: external period label, e.g. `2026M03`.
- `interval`: usually `monthly`; quarterly/yearly data also exists.
- `year`: model coordinate, not the pretty display date.
- Monthly formula: `year = (calendar_year - 1) + (month - 1) / 12`.
- Example: `2026M01 -> 2025`, `2026M02 -> 2025.083333`, `2026M03 -> 2025.166667`.
- `category`: uppercase fuel category.
- `registrations`: absolute registrations, not percentages.
- `source`: source string or URL for that row.
- Default passenger-car market variant is `New Cars`; older default-scope
  labels are accepted only as legacy aliases during imports/upserts.

Common categories:

- `BEV`
- `PHEV`
- `EREV`
- `HEV`
- `HYBRIDS`
- `PETROL`
- `DIESEL`
- `FLEXFUEL`
- `PETROL-GAS`
- `ICE`
- `OTHER`
- `TOTAL`

## Model Notes

- Model form: Weibull-style cumulative transition, `1 - exp(v1 * x^v2)`.
- This is not a forecast; it is a best-fit description of the currently observed transition.
- The model is intentionally bounded at 0% and 100%.
- `t0` is the time shift / baseline year used by the fitted curve.
- The fit uses absolute registrations as weights, so tiny volatile periods matter less.
- The R pipeline also fits an ICE decline curve for ICE/BEV transition charts.
- Threshold and duration tables are derived from `params.csv`, not from image files.
- TTM means trailing twelve months; quarterly data falls back to a four-quarter rolling window.

## Data Gotchas

- `params.csv`, `weights.csv`, `manifest.json`, `images/` and `posts/` are generated artifacts.
- A data edit should normally touch only `data/markets/<slug>.csv`; CI then regenerates the rest.
- `TOTAL` should be the official total if available, not necessarily the sum of visible categories.
- If components and `TOTAL` do not match, check whether the source has hidden/other categories.
- Some markets report `PETROL`/`DIESEL`; others only report a single `ICE`.
- China uses `EREV`; the model folds EREV into the PHEV-like trajectory line but keeps a separate TTM layer.
- Türkiye has `HYBRIDS` instead of separate `HEV`/`PHEV` in some source structures.
- Brazil and Sweden report `FLEXFUEL`; Georgia reports `PETROL-GAS`.
- Brazil and Georgia needed residual ICE handling because partial category stacks did not cover the full total.
- New Zealand must be spelled with a space everywhere; `NewZealand` triggers legacy-alias warnings.
- `South Korea`, `UK`, `USA` and `Türkiye` have explicit label/slug exceptions.
- Some old `world_interval` images do not end in `YYYYMMDD`; `build_manifest.R` warns about them but keeps working.
- The `legacy/` scripts may explain historical choices, but they are not maintained and should not be used for updates.

## Usual Workflows

### 1. Public or mobile data submission

- Open the site and go to `Submit Data`.
- Pick an existing market, or choose `New market / variant` for new countries,
  vans, HDV, private/industry slices or other source scopes.
- Enter period and source.
- Enter absolute registration counts.
- Use `Additional category` for source-specific columns such as `FLEXFUEL`.
- The form generates canonical CSV rows and opens a review submission.
- New market submissions include a proposed `_index.csv` row plus the data rows.
- Custom categories land in the CSV; add R/schema handling if they need their
  own model, TTM layer or post wording.
- The submission is public feedback/GitHub-Issue content, so do not put private data in it.
- Current status: the mask creates structured review input; accepting it is still a maintainer step.

### 2. Manual CSV update

- Edit the relevant `data/markets/<slug>.csv`.
- Add one row per category for the new period.
- Keep the category set consistent with that market unless the source really changed schema.
- Do not edit `params.csv`, `weights.csv` or `manifest.json` manually.
- Commit and push the data change.
- GitHub Actions runs `R pipeline`, commits charts/params/weights/posts/manifest back, and Pages deploys.

### 3. ACEA update

- GitHub Actions -> `ACEA scrape`.
- Inputs:
  - `year`: e.g. `2026`
  - `month`: e.g. `3`
  - `include`: optional comma-separated slugs
  - `exclude`: optional comma-separated slugs
  - `url`: optional explicit PDF URL
- The scraper updates ACEA-driven `data/markets/*.csv`.
- The R pipeline starts automatically after the CSV commit.
- If ACEA has not published that month's default PDF yet, the workflow logs a
  skip message and finishes green without committing anything.
- Use the `url` input when ACEA changes the PDF path or when testing a known
  release URL.

Local equivalent:

```sh
python scripts/scrape_acea.py 2026 03
python scripts/scrape_acea.py 2026 03 --include france,germany
python scripts/scrape_acea.py 2026 03 --dry-run
python scripts/scrape_acea.py 2026 03 --missing-ok
```

### 4. Audit legacy XLSX categories

Use this only when comparing against a legacy/raw workbook:

```sh
Rscript scripts/audit_xlsx_csv_categories.R /path/to/bev_share_acea.xlsx
```

It fails if a non-empty XLSX source category is missing from `data/markets/*.csv`.

### 5. Regenerate charts locally

One market:

```sh
Rscript R/bev_share.R Austria
Rscript R/bev_share.R "Denmark (HDV)"
```

Several or all markets:

```sh
Rscript R/run_all.R --skip-fail Brazil Georgia
Rscript R/run_all.R --skip-fail
```

Then rebuild the image manifest:

```sh
Rscript -e "source('build_manifest.R'); build_manifest(root='images', base_url='images/')"
```

### 6. Deployment

- GitHub Pages serves this repo at `https://leraffl.github.io/Gallery-TEST/`.
- TEST Pages is sourced from this TEST repo, not the production repo.
- Merging a tested PR to `main` updates the TEST deployment.
- Production is a separate manual step.

## Pre-Push Sanity Checks

Useful quick checks:

```sh
python3 -m py_compile scripts/scrape_acea.py
Rscript -e "files <- list.files('R', pattern='[.]R$', recursive=TRUE, full.names=TRUE); for (f in files) parse(f); cat('Parsed', length(files), 'R files\n')"
jq empty manifest.json
rg -n "NewZealand|Southkorea|Hdv|Newzealand" params.csv weights.csv manifest.json posts data/markets/_index.csv
```

For UI smoke testing:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Then open `http://127.0.0.1:4173/`.
