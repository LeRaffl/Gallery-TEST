# scripts/migrate_xlsx_to_csv.R
# One-time migration: read every sheet in data/raw/bev_share_acea.xlsx and
# write a long-format CSV per country/variant under data/markets/<slug>.csv.
#
# Long-format columns:
#   period         "2025M08"           — same YYYYMMM string the XLSX uses
#   interval       "monthly" | "quarterly" | "yearly"
#   year           2025.667            — fractional year (kept for sorting)
#   category       "BEV" | "PHEV" | "HEV" | "EREV" | "HYBRIDS"
#                  | "PETROL" | "DIESEL" | "ICE" | "OTHER" | "TOTAL"
#   registrations  count               — integer (NA-cells skipped)
#   source         "Statistik Austria" — copied from the source row
#
# TTM values are NOT stored — they're recomputed from the monthly counts in
# load_data.R, so the canonical CSV stays minimal and consistent.
#
# Usage:
#   Rscript scripts/migrate_xlsx_to_csv.R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(countrycode)
})

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa) == 1) return(normalizePath(dirname(sub("^--file=", "", fa))))
  normalizePath(".")
}
repo_dir <- normalizePath(file.path(script_dir(), ".."))
xlsx     <- file.path(repo_dir, "data", "raw", "bev_share_acea.xlsx")
out_dir  <- file.path(repo_dir, "data", "markets")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

SKIP_SHEETS <- c(
  "Europeanunion", "Netherlands_HDV(old)", "NewZealand (Legacy)",
  "Georgia (Fleet)", "Netherlands (Fleet)"
)

# Same alias logic as R/lib/captions.R::country_to_flag_slug — duplicated here
# so the script doesn't need to source the rest of the pipeline.
slug_aliases <- c(
  "Türkiye"        = "tuerkiye",
  "South Korea"    = "southkorea",
  "New Zealand"    = "newzealand",
  "United States"  = "usa",
  "USA"            = "usa",
  "United Kingdom" = "uk",
  "UK"             = "uk",
  "Czechia"        = "czechia",
  "Czech Republic" = "czechia"
)

country_to_slug <- function(country) {
  if (country %in% names(slug_aliases)) return(unname(slug_aliases[country]))
  tolower(gsub("\\s+", "", country))
}

# "Denmark (HDV)" → list(country = "Denmark", variant = "HDV", slug = "denmark_hdv")
parse_sheet_name <- function(sheet) {
  if (grepl("\\(", sheet)) {
    country <- trimws(sub("\\s*\\(.*\\)\\s*", "", sheet))
    variant <- sub(".*\\(([^)]+)\\).*", "\\1", sheet)
    slug    <- paste0(country_to_slug(country), "_",
                      tolower(gsub("\\s+", "_", variant)))
  } else {
    country <- sheet
    variant <- "Whole"
    slug    <- country_to_slug(country)
  }
  list(country = country, variant = variant, slug = slug)
}

# Categories we recognize in the source sheets. "OTHERS" is the column name
# used in the XLSX; canonical name in CSV is "OTHER".
SOURCE_CATEGORIES <- c("BEV", "PHEV", "HEV", "EREV", "HYBRIDS",
                       "PETROL", "DIESEL", "ICE", "OTHERS", "TOTAL")

# Map source column name → canonical CSV category name.
canon_category <- function(name) {
  if (name == "OTHERS") return("OTHER")
  name
}

# Convert one sheet's wide rows into long-format tibble of registrations
# (one row per period × category).
sheet_to_long <- function(raw, parsed) {
  # Same hygiene the load_data.R applies: alias OTHER → OTHERS up-front
  if ("OTHER" %in% names(raw) && !"OTHERS" %in% names(raw)) {
    names(raw)[names(raw) == "OTHER"] <- "OTHERS"
  }

  # Drop trailer rows that have neither YYYYMMM nor TOTAL
  has_period <- "YYYYMMM" %in% names(raw)
  has_total  <- "TOTAL"   %in% names(raw)
  if (has_period && has_total) {
    period_bad <- is.na(raw$YYYYMMM) | !nzchar(as.character(raw$YYYYMMM))
    total_bad  <- is.na(suppressWarnings(as.numeric(raw$TOTAL)))
    raw <- raw[!(period_bad & total_bad), , drop = FALSE]
  }

  # Coerce year to numeric (some sheets ship it as <lgl>); reconstruct from
  # YYYYMMM where missing.
  if ("year" %in% names(raw)) raw$year <- suppressWarnings(as.numeric(raw$year))
  if ("year" %in% names(raw) && "YYYYMMM" %in% names(raw)) {
    miss <- is.na(raw$year) & !is.na(raw$YYYYMMM) & nzchar(as.character(raw$YYYYMMM))
    if (any(miss)) {
      yyyy_mm <- strcapture("^(\\d{4})M(\\d{1,2})$", as.character(raw$YYYYMMM[miss]),
                            list(yr = integer(), mo = integer()))
      ok <- !is.na(yyyy_mm$yr) & !is.na(yyyy_mm$mo)
      raw$year[miss] <- ifelse(ok, yyyy_mm$yr - 1 + yyyy_mm$mo / 12, NA_real_)
    }
  }

  # Sanity filter: discard absurd year values (Denmark Whole had 7094, 9855)
  if ("year" %in% names(raw)) {
    bad <- !is.na(raw$year) & (raw$year <= 1990 | raw$year >= 2100)
    raw <- raw[!bad, , drop = FALSE]
  }

  if (nrow(raw) == 0) return(NULL)

  # Source string: take the first non-empty value
  source_str <- if ("Source" %in% names(raw)) {
    s <- raw$Source[!is.na(raw$Source) & nzchar(raw$Source)]
    if (length(s)) as.character(s[1]) else ""
  } else ""

  # Pick the categories actually present in this sheet
  present_cats <- intersect(SOURCE_CATEGORIES, names(raw))

  long <- raw %>%
    select(any_of(c("YYYYMMM", "year", "time_interval", present_cats))) %>%
    pivot_longer(cols = any_of(present_cats),
                 names_to = "category", values_to = "registrations") %>%
    filter(!is.na(registrations)) %>%
    transmute(
      period        = as.character(YYYYMMM),
      interval      = as.character(time_interval),
      year          = as.numeric(year),
      category      = vapply(category, canon_category, character(1)),
      registrations = as.numeric(registrations),
      source        = source_str
    ) %>%
    arrange(year, category)

  long
}

# ---- run ----
all_sheets <- excel_sheets(xlsx)
sheets     <- setdiff(all_sheets, SKIP_SHEETS)

cat(sprintf("Migrating %d sheet(s) from %s → %s\n",
            length(sheets), basename(xlsx), out_dir))

written <- 0
for (sheet in sheets) {
  parsed <- parse_sheet_name(sheet)
  raw <- tryCatch(
    suppressMessages(read_excel(xlsx, sheet = sheet)) %>% as.data.frame(check.names = FALSE),
    error = function(e) NULL
  )
  if (is.null(raw) || nrow(raw) == 0) {
    cat(sprintf("  [skip] %s — could not read or empty\n", sheet)); next
  }
  long <- sheet_to_long(raw, parsed)
  if (is.null(long) || nrow(long) == 0) {
    cat(sprintf("  [skip] %s — no usable rows after cleanup\n", sheet)); next
  }
  out <- file.path(out_dir, paste0(parsed$slug, ".csv"))
  write_csv(long, out, na = "")
  written <- written + 1
  cat(sprintf("  [ok]   %-35s → %s (%d rows)\n",
              sheet, paste0(parsed$slug, ".csv"), nrow(long)))
}

cat(sprintf("\nDone. %d/%d sheet(s) migrated.\n", written, length(sheets)))

# Write a tiny index so run_all.R / future tools can map slug ↔ sheet_name
# without having to re-derive variants, aliases, etc.
index_rows <- list()
for (sheet in sheets) {
  parsed <- parse_sheet_name(sheet)
  csv_path <- file.path(out_dir, paste0(parsed$slug, ".csv"))
  if (!file.exists(csv_path)) next
  long <- suppressMessages(read_csv(csv_path, show_col_types = FALSE,
                                     progress = FALSE))
  src <- {
    s <- long$source[!is.na(long$source) & nzchar(long$source)]
    if (length(s)) as.character(s[1]) else ""
  }
  index_rows[[length(index_rows) + 1]] <- data.frame(
    slug       = parsed$slug,
    sheet_name = sheet,
    country    = parsed$country,
    variant    = parsed$variant,
    rows       = nrow(long),
    source     = src,
    stringsAsFactors = FALSE
  )
}
index <- do.call(rbind, index_rows)
write_csv(index, file.path(out_dir, "_index.csv"), na = "")
cat(sprintf("Index: %s (%d entries)\n",
            file.path(out_dir, "_index.csv"), nrow(index)))
