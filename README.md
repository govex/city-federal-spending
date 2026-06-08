# City Federal Spending

> [!NOTE]
> Pipeline last edited June 2024. Data is current through FY2023.

Pipeline to identify local government recipients in [USASpending.gov](https://usaspending.gov) transaction data and generate a standardized series of annual federal obligation totals per city.

## Overview

The pipeline queries local PostgreSQL databases populated from the USASpending transaction archive, filters to recipients that are confirmed city government entities within each city's geographic bounds, handles deobligations, and outputs annual obligation totals per city for engineering delivery.

For a full narrative of the methodology, see [METHODOLOGY.md](./METHODOLOGY.md).

**No API key is required** for the core pipeline. A Google Maps API key is needed only if re-geocoding recipient addresses from scratch.

## Data Source

**USASpending.gov — Prime Award Transactions**
- Access method: [awardsreport](https://github.com/govex/awardsreport) endpoint (Ben Turse, U.S. Treasury)
- Local storage: PostgreSQL databases `ar_db_17` – `ar_db_23`, one per fiscal year
- Coverage: FY2017–FY2023
- Unit: Transaction-level federal obligations (USD)

## File Structure

```
city-federal-spending/
├── awardsreport/               # awardsreport submodule (govex/awardsreport@govex-stable)
├── data-delivery/              # Output CSVs for engineering
├── data-helpers/               # Reference files and crosswalks
├── data-processed/             # Intermediate data and plots
│   └── plots/
│       ├── city-bounds/        # Per-city recipient geography checks
│       └── city-spending/
│           ├── bars/
│           └── timeline/
├── data-raw/                   # Raw source data
└── r-delivery/                 # Production R scripts
```

All paths in the R scripts are relative to the repo root (`city-federal-spending/`).

## Dependencies

### R Packages

```r
install.packages(c(
  "tidyverse", "glue", "sf", "geojsonsf",
  "DBI", "RPostgres", "tidygeocoder", "ggmap",
  "scales", "viridis", "fs"
))
```

### PostgreSQL

Local PostgreSQL databases are required — one per fiscal year. Install via conda and create one database per year:

```bash
conda create --name awardsreport
conda activate awardsreport
conda install -y -c conda-forge postgresql
initdb -D mylocal_db
pg_ctl -D mylocal_db -l logfile start
createuser --encrypted --pwprompt <db_user>
for year in 17 18 19 20 21 22 23; do
  createdb --owner=<db_user> ar_db_$year
done
```

Then populate each database using the [awardsreport](https://github.com/govex/awardsreport) endpoint (requires Python 3.10):

```bash
cd awardsreport/awardsreport
pip install -r requirements.txt && pip install .
mv .env.example .env        # edit with your DB credentials
alembic upgrade head
python src/awardsreport/setup/seed.py -year 2023
python src/awardsreport/setup/transaction_derivations.py
python src/awardsreport/setup/seed_transactions_table.py
```

Repeat the seed step for each year before running the R pipeline.

### Required Input Files

Three inputs must be in place before running the pipeline. None are downloaded automatically.

**1. SAM.gov entity registry** (`data-raw/SAM_PUBLIC_UTF-8_MONTHLY_V2_*.txt`)

Download the latest monthly Public V2 extract from [sam.gov](https://sam.gov/data-services/Entity%20Registration/Public%20V2?privacy=Public) (requires a SAM.gov account). Place the file in `data-raw/` and update `file_sam_gov` in `spending-config.R` to match the filename. Column positions are identified using the [SAM.gov data dictionary](https://falextracts.s3.amazonaws.com/Data%20Dictionary/Entity%20Information/NOV_2023_Data_Dictionary.pdf).

**2. City boundary GeoJSON files** (`city_places_sf` in config)

One `.geojson` file per city. The path is configured via `path_geojson` in `spending-config.R`. Files for the current city list are included in `data-raw/geojson/places/`. If adding a new city, its boundary file must be present before running.

**3. Geocoded recipient coordinates** (`data-processed/latlong.csv`)

Lat/long coordinates for SAM.gov-registered government entity addresses within the pipeline's city ZCTAs. A baseline is included in the repo. On every run, any addresses in the current SAM.gov file not already in the cache are geocoded with Google and appended automatically — the cache grows over time. The full three-pass geocoder (`spending-geocode.R`) only runs when no cache file exists at all.

## Quick Start

### Configuration

Review `spending-config.R` — key settings:

- `url_places`: (optional) Live Google Sheet URL for city metadata. Fetched at runtime if set; a local snapshot is at `data-raw/city_places.csv`.
- `file_zcta_places`: Path to the 2020 ZCTA–Place crosswalk.
- `path_geojson`: Path to the directory containing city boundary GeoJSON files.

### Run Pipeline

```r
source("spending.R")
```

`spending.R` sources each module in sequence. Two flags control expensive re-runs:

| Flag | File | Default | Re-run when |
|------|------|---------|-------------|
| `run_geocoding` | `spending-recipient_id.R` | `TRUE` | New cities or new SAM.gov file |
| `run_transactions` | `spending-transactions.R` | `FALSE` | New UEIs, cities, or fiscal years |

> **Note:** Re-geocoding takes ~1 hour. Re-collecting transactions takes ~15 minutes.

## Methodology

For each city, the pipeline:

1. Identifies SAM.gov-registered government entities (`entity_structure == "2A"`) with ZIP codes intersecting the city's ZCTAs
2. Geocodes their physical addresses and spatially intersects them against the city's Census place boundary
3. Collects all transactions for confirmed in-boundary recipients from the PostgreSQL databases
4. Filters to local government recipients (business type `12`), excluding counties, state agencies, and other non-city entities — see [METHODOLOGY.md](./METHODOLOGY.md) for full filter logic
5. Redistributes deobligations (negative obligations) evenly across relevant award years to prevent negative annual totals — see [METHODOLOGY.md](./METHODOLOGY.md) for details
6. Summarizes total obligations per city per fiscal year

## Data Schema

### Delivery Output (`data-delivery/govex-spending_YYYY-MM-DD.csv`)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `date` | string | Fiscal year as ISO datetime (Jan 1) | `2021-01-01 00:00:00` |
| `value` | float | Total federal obligations (USD) | `127400000` |
| `place_id` | string | Place identifier | `c-us-md-bal` |
| `category_id` | string | Empty string (reserved) | `` |

Series ID: `federal-spending-obligations`

## Adding a New Fiscal Year

1. Populate a new PostgreSQL database (`ar_db_24`, etc.) using the awardsreport endpoint
2. Add the new year to `years` in `spending-postgres.R`
3. Extend the `case_when` block in `spending-transactions.R` to cover the new fiscal year date range
4. Set `run_transactions <- TRUE` in `spending-transactions.R`
5. Update the SAM.gov entity registry in `data-raw/` if a newer monthly extract is available
6. Run `source("spending.R")`
