# Title: City Federal Spending - Configuration
# Description:
# Author: Derek Crowe
# Last Edited: 4/22/24

# USA Spending Configuration ================================

## Local Requirements ================================

library(geojsonsf)

## Data Import ================================

# ///////////////////////////////////////////////////////////////
# Check links for updates to these files when running this script.
# Update path names if necessary.
# ///////////////////////////////////////////////////////////////

### Sam.gov Entity Registry ================================

# [Sam.gov entity registry file](https://sam.gov/data-services/Entity%20Registration/Public%20V2?privacy=Public)

# This contains all the entities registered with Sam.gov. The data are used by
# USA Spending to define the UEI (unique entity identifier) of each recipient,
# which is the key we will use to link physical addresses and spending data.

# Download the latest monthly Public V2 extract from:
# https://sam.gov/data-services/Entity%20Registration/Public%20V2?privacy=Public
# Place the file in ./data-raw/ and update file_sam_gov below.

# Column positions were identified using the SAM.gov data dictionary:
# https://falextracts.s3.amazonaws.com/Data%20Dictionary/Entity%20Information/NOV_2023_Data_Dictionary.pdf

file_sam_gov <- c("./data-raw/SAM_PUBLIC_UTF-8_MONTHLY_V2_20240303.txt")

sam_gov <-
  readr::read_delim(file_sam_gov,
                    delim = "|",
                    col_names = FALSE) |>
  dplyr::select(c("X1","X4","X12","X13","X16","X17","X18","X19","X20","X21","X22",
                  "X23","X27","X28","X31","X32","X33","X34","X35","X36","X37")) |>
  dplyr::rename(recipient_uei = X1,
                recipient_CAGE = X4,
                recipient_name = X12,
                recipient_dba = X13,
                phys_address_01 = X16,
                phys_address_02 = X17,
                phys_address_city = X18,
                phys_address_st = X19,
                phys_address_ZIP = X20,
                phys_address_ZIP2 = X21,
                phys_address_country = X22,
                phys_address_cong_dist = X23,
                recipient_url = X27,
                entity_structure = X28,
                bus_type_counter = X31,
                bus_type_string = X32,
                primary_NAICS = X33,
                NAICS_code_counter = X34,
                NAICS_code_string = X35,
                PSC_code_counter = X36,
                PSC_code_string = X37)

# Validate column mapping — if SAM.gov changes column order these will fail
# loudly rather than letting wrong data flow through silently.
stopifnot(
  "recipient_uei does not look like UEIs (12 alphanumeric chars) — check column positions" =
    all(grepl("^[A-Z0-9]{12}$", na.omit(sam_gov$recipient_uei))),
  "entity_structure contains unexpected values — check column positions" =
    all(sam_gov$entity_structure %in% c("2A", "2F", "2R", "3I", "CY", "8H", "2L", NA)),
  "phys_address_st values are not 2-character state codes — check column positions" =
    all(nchar(na.omit(sam_gov$phys_address_st)) == 2)
)

### 2020 ZCTA to Incorporated Place Crosswalk ================================

# [ZCTA5 to Incorporated Places Crosswalk](https://www.census.gov/geographies/reference-files/time-series/geo/relationship-files.2020.html#zcta)

# Relationship file from Census that defines all ZCTA codes associated with
# Incorporated Places. Since they are not contiguous, there are codes
# included in this crosswalk that represent very small areas of places.

# This represents the relationship as of the 2020 census update.
# As such, all filtering and querying done in this methodology will defer to
# the 2020 definitions, including the Incorporated Place geographies that
# will be used to filter recipients.

# Of note: the sam.gov recipient information reflects data as of March 2024.
# This means that recipient addresses used will represent 2024 information
# while the geographies used to filter them will represent 2020 information.
# I think this is proper.

# A local copy from March 2024 is stored in the repo at
# ./data-raw/tab20_zcta520_place20_natl.txt

# An explanation file is also included locally at
# ./data-helpers/explanation_tab20_zcta520_place20_natl.pdf

# Set path to ZCTA-Place relationship file
file_zcta_places <- c("./data-raw/tab20_zcta520_place20_natl.txt")

# Import ZCTA-Place relationship file
zcta520_place20 <- readr::read_delim(file_zcta_places)


### City Place metadata ================================

# Contains metadata for cities to be analyzed, including Census GEOIDs used
# to match ZCTAs and place boundary geometries.

# A local snapshot is saved at ./data-raw/city_places.csv

# Import and redefine relevant colnames
city_places <-
  readr::read_csv("./data-raw/city_places.csv",
                  col_select = c(place_id = `SOLE Place ID`,
                                 GEOID_20 = `2020 Census GEOIDs`,
                                 city = `City name`,
                                 state_code = `State Code`,
                                 state = State,
                                 region = `SoLE region`,
                                 pop_21 = `Population 2021`)) |>
  dplyr::mutate(city_label = paste0(city, ", ", state_code), .before = city) |>
  tidyr::separate_longer_delim(GEOID_20, delim = ", ")


### City Place Geometry ================================

# Place geometries will be used to filter geocoded recipient addresses to
# capture only those that fall within the boundaries of each Place.

# Set path to directory containing city boundary GeoJSON files
# GeoJSON files live in this repo at data-raw/geojson/places/ — copy from
# govex-bcai/bcai_private/data/config/geojson/places/ if setting up fresh.
path_geojson <- "./data-raw/geojson/places"

# define file pattern
pattern_geojson <- "*.geojson"

# define list of file names
files_geojson <- list.files(path = path_geojson, pattern = pattern_geojson, full.names = TRUE)

# import geometries, set crs, join with city place metadata
city_places_sf <-
  purrr::map(files_geojson, ~ geojsonsf::geojson_sf(.x)) |>
  dplyr::bind_rows() |>
  sf::st_transform(crs = "EPSG:4269") |>
  dplyr::left_join(city_places, by = join_by(place_id))


