# BEV Trajectories — Gallery-TEST

This repo is the **development/staging counterpart** to LeRaffl-Gallery (the public live gallery at leraffl.github.io/LeRaffl-Gallery). Changes are tested here before being merged to the public repo.

## What this project is

An interactive, fully client-side dashboard visualising EV transition dynamics per country:

- **Gallery tab** — browse PNG charts (BEV trajectories, ICE↔BEV transitions, TTM splits, transition-time curves) filtered by country / date / chart type
- **Thresholds tab** — when does a market reach 20 / 50 / 80% BEV share, computed from `params.csv`
- **Durations tab** — how long does a market take to move between share levels (e.g. 20→80%)

All computation runs in the browser. No backend.

## Key files

| File | Purpose |
|------|---------|
| `index.html` | Full UI — Gallery, Thresholds, Durations tabs |
| `manifest.json` | Auto-generated chart list (built by `build_manifest.R`) |
| `params.csv` | Fitted model parameters (v1, v2, t0, baseline year, last data month) per market |
| `images/YYYY-MM/` | PNG exports, served statically |

## Data & model

- Input: monthly new-car registration data (ACEA, KBA, CPCA, Statistik Austria, etc.)
- Model: Weibull-style generalised logistic — `1 - exp(v1 * x^v2)`, fitted via weighted OLS
- Parameters: `v1` (transition intensity), `v2` (transition shape), `t0` (time shift)
- Hard bounds: 0% start, 100% asymptote — intentional; model visibly breaks if data contradicts this
- Charts cover BEV, PHEV, and ICE (ICE = everything that is not BEV or PHEV)
- **Not a forecast** — a best-fit description of the transition as observed today

## Planned features

- `world_interval` plots
- Variant research per country
- Sources tab (URLs tracked in Google Sheets)
