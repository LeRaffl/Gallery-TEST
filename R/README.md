# `R/` — consolidated BEV trajectory pipeline

This is the harmonized replacement for the 63 per-country scripts that used to live in `legacy/country_models/`. One pipeline, parameterized by sheet name, reading from `data/raw/bev_share_acea.xlsx`.

## Run it

```sh
Rscript R/bev_share.R Austria
Rscript R/bev_share.R "Denmark (HDV)"
Rscript R/bev_share.R Türkiye
```

The sheet name must match a tab in `data/raw/bev_share_acea.xlsx`. Variants like `Denmark (HDV)`, `Finland (Private)`, `Netherlands (Used Imports)` are parsed automatically — the parenthesis content becomes the `variant` column in `params.csv` / `weights.csv`.

## What it produces

For one country/variant run:

- `images/<YYYY-MM>/<slug>_<YYYYMMDD>.png`           — BEV trajectory
- `images/<YYYY-MM>/<slug>_ICE_BEV_<YYYYMMDD>.png`   — BEV / ICE / PHEV
- `images/<YYYY-MM>/<slug>_time_<YYYYMMDD>.png`      — transition-time evolution
- `images/<YYYY-MM>/<slug>_ttm_shares_<YYYYMMDD>.png` — trailing-12-months stack
- one upserted row in `params.csv` (keyed on country + variant)
- one upserted row in `weights.csv`

`<slug>` is `austria`, `denmark_hdv`, `tuerkiye`, etc.

The `<YYYY-MM>` folder is derived from the latest data point in the sheet (the pipeline asks the data, not the wall clock).

## Layout

```
R/
├── bev_share.R               # entry point
├── lib/
│   ├── load_data.R           # XLSX read + schema detection + canonical columns
│   ├── model.R               # Weibull-style logistic fit (verbatim from legacy)
│   ├── plots.R               # 4 ggplot builders, parameterized for schema
│   ├── params_io.R           # params.csv / weights.csv read/upsert/write
│   └── captions.R            # social caption + flag PNG loader (graceful fallback)
└── README.md
```

## Schema handling

The sheets in `bev_share_acea.xlsx` aren't all identical. The pipeline detects which fuel-type columns are present and adapts the trajectory math + TTM stack accordingly:

| Country style   | Detected by      | What changes                                                |
|-----------------|------------------|-------------------------------------------------------------|
| Standard (most) | `PETROL`+`DIESEL`+`HEV`+`PHEV` | TTM stack: Other / Petrol / Diesel / HEV / PHEV / BEV   |
| China           | has `EREV`       | EREV folds into the PHEV trajectory line, but renders as its own TTM layer |
| Türkiye         | has `HYBRIDS`    | Single combined Hybrid line; TTM uses `Hybrid TTM`          |
| USA / SK        | has `ICE` (no PETROL/DIESEL split) | TTM stack uses `ICE TTM` instead of Petrol+Diesel |
| Denmark Whole   | missing `Petrol TTM` / `Other TTM` | Those layers are skipped from TTM stack            |

Detection happens automatically in `lib/load_data.R` — no per-country config needed.

## What's *not* in here yet

- **Malaysia** — the source is `storage.data.gov.my/transportation/cars_<year>.parquet`, not the XLSX. A separate loader will plug in here later.
- **GitHub Actions runner** — the pipeline is structured to run from CI but the workflow file isn't wired up yet.

## Comparison with the legacy scripts

The legacy scripts also pushed images and CSVs straight to the live `LeRaffl-Gallery` repo from inside R, staged through iCloud, and round-tripped per-country results via Google Sheets. None of that happens here — the pipeline writes only to the working tree, and a human (or a future GitHub Action) is responsible for committing.

If you need to look at the original scripts for comparison, they live under `legacy/country_models/`.
