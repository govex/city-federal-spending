# Title: City Federal Spending - Recipient Identification
# Description:
# Author: Derek Crowe
# Last Edited: 4/22/24


# Recipient Identification ================================

## Local Requirements ================================

library(DBI)
library(RPostgres)
#library(RODBC)
#library(odbc)
#library(dbplyr)



## Define City ZCTAs ================================

# Filter GEOIDs in ZCTA data by those found in the city_places data

city_zcta_data <- 
  zcta520_place20 |>
  dplyr::filter(GEOID_PLACE_20 %in% city_places$GEOID_20) |>
  dplyr::select(GEOID_PLACE_20, NAMELSAD_PLACE_20, GEOID_ZCTA5_20) |>
  tidyr::drop_na(GEOID_ZCTA5_20)

## Obtain UEIs for recipients within city ZCTAs ================================

# Filter recipient information to get all USA-based
# government entities (2A) that fall within the city ZIPs. We will filter
# business type string later to collect only Local Governments.

recps.2A_zips <- 
  sam_gov |>
  dplyr::filter(phys_address_ZIP %in% city_zcta_data$GEOID_ZCTA5_20, 
                entity_structure == "2A", 
                phys_address_country == "USA") |>
  dplyr::mutate(full_addy = paste(phys_address_01, 
                            phys_address_02,
                            phys_address_city, 
                            phys_address_st, 
                            phys_address_ZIP, 
                            sep = " "), 
                .after = recipient_uei)

# Some info:
# 7544 recipients, 7184 unique UEIs (360 UEIs are duplicated) 


# Will move forward to filtering transactions using unique UEIs 
# before geocoding addresses
recps.2A.dist_zips <- 
  recps.2A_zips |>
  dplyr::distinct(recipient_uei, .keep_all = TRUE)


## Further recipient filtering could also go here, but it came up later and 
## it's now in its own script that's run after sam.gov metadata is merged back 
## into collected transactions data


## Obtain addresses for distinct UEIs that are also in transactions tables =====

# Obtain list of distinct UEIs that are government entities within
# city ZIPs and present in the transactions db
trans_ueis.2A_zips <- 
  trans |>
  purrr::map(~ filter(.x, recipient_uei %in% 
                        !!recps.2A.dist_zips$recipient_uei) |> 
        dplyr::distinct(recipient_uei) |>
        dplyr::collect())


# Get addresses for the UEIs that are in the transactions data

# 4,598 unique UEIs appear in filtered transactions data 
trans.unq_ueis.2A_zips <-  
  trans_ueis.2A_zips |>  
  dplyr::bind_rows() |>  
  dplyr::distinct(recipient_uei)

# Number of unique addresses within the UEIs that are in city ZIPs and
# transaction data
# 4,336
city_trans_addys <- 
  recps.2A.dist_zips |>
  dplyr::filter(recipient_uei %in% 
                  trans.unq_ueis.2A_zips$recipient_uei) |>
  dplyr::distinct(full_addy, .keep_all = TRUE)


# UEIs in city ZIPs that aren't in spending data
recps.2A.dist_zips |>  
  dplyr::filter(!recipient_uei %in% trans.unq_ueis.2A_zips$recipient_uei)
# 2,586 

# Sanity check to see if all the UEIs in the transaction data are in the
# city ZCTAs
trans.unq_ueis.2A_zips |>  
  dplyr::filter(recipient_uei %in% recps.2A.dist_zips$recipient_uei)
# 4,598 (sanity achieved)


## Geocode coarsely-filtered recipients ================================

# With the list of addresses that can be found among all transactions to
# government entities within the city ZIP codes, we will geocode them and
# further filter these by the city geography. Then we will use this final
# list of addresses to filter transactions from the postgres db and
# collect them into R for processing and analysis.

# Three separate services were used to complete geocoding of all addresses:
# Nominatim, Geocodio, and Google. The first two are free, Google is not
# (requires a Google Maps API key set in GOOGLE_MAPS_KEY env var).

# These geocodes were saved after running this to prevent additional 
# hour-long periods of waiting. 

# Path to cached geocode results
cached_latlong <- "./data-processed/latlong_240528.csv"

# Default: skip full geocoding if cached results already exist.
# Set run_geocoding <- TRUE to force a full re-run (Nominatim → Geocodio →
# Google, ~1 hour). Only needed when adding new cities or swapping SAM.gov file.
run_geocoding <- !file.exists(cached_latlong)

if (run_geocoding) {
  source("./r-delivery/spending-geocode.R")
}

# Load saved coords for geocoded recipient addresses
recip_coords_city_zip_trans <-
  readr::read_csv(cached_latlong)

# Check for any new addresses not yet in the cached geocodes
addy_updates <-
  city_trans_addys |>
  dplyr::filter(!full_addy %in% recip_coords_city_zip_trans$full_addy)


## Fine-filtering of recipients using city place geometries ===================


# If there are new addresses, geocode them with Google and append to cache
if (length(addy_updates$full_addy) > 0) {

  library(ggmap)

  addy_updates_coords <-
    addy_updates |>
    dplyr::mutate(full_address = paste0(phys_address_01, ", ",
                                        phys_address_city, ", ",
                                        phys_address_city, ", ",
                                        phys_address_st, ", ",
                                        phys_address_ZIP)) |>
    ggmap::mutate_geocode(full_address) |>
    dplyr::rename(long = lon)

  # Check to make sure it got them all
  na_sum <-
    addy_updates_coords |>
    dplyr::summarise(across(c(lat, long),
                            ~ sum(is.na(.)),
                            .names = "{.col}_na.count")) |>
    dplyr::mutate(na_sum = lat_na.count + long_na.count) |>
    dplyr::pull(na_sum)

  stopifnot(na_sum == 0)

  recip_coords_city_zip_trans <-
    recip_coords_city_zip_trans |>
    bind_rows(addy_updates_coords)

  readr::write_csv(recip_coords_city_zip_trans, cached_latlong)

}

# Convert to sf object, create full address field, select columns for
# intersection with city place geometries
recip_coords_city_zip_trans_sf <-  
  recip_coords_city_zip_trans |>  
  sf::st_as_sf(coords=c("long", "lat"), crs="EPSG:4326") |>  
  sf::st_transform(crs = sf::st_crs(city_places_sf)) |>
  dplyr::select(recipient_uei, full_addy, recipient_name, geometry)


# Intersect city place geometries with geocoded recipient addresses
# This looks like an easy set of commands but was very challenging to get right. 
# Ultimately this post helped a ton: https://gis.stackexchange.com/questions/282750/identify-polygon-containing-point-with-r-sf-package/343477#343477

int <- 
  sf::st_intersects(recip_coords_city_zip_trans_sf$geometry, 
                    city_places_sf |>
                      distinct(geometry))

#replace misses with NAs
int[lengths(int) == 0] <- NA

#Collapse Louisville back into one row

city_places_sf_dsct <- 
  city_places_sf |> 
  dplyr::distinct(city_label, .keep_all = TRUE) 

#index city_labels from places to define the associated city of
#recipient addresses that fall within city place geometries
recip_coords_city_zip_trans_sf$city_label <- 
  city_places_sf_dsct$city_label[unlist(int)]
recip_coords_city_zip_trans$city_label <- 
  city_places_sf_dsct$city_label[unlist(int)]

View(slice_sample(recip_coords_city_zip_trans, n = 100))

## Define list of recipient UEIs within cities ============================

city_ueis <-   
  recip_coords_city_zip_trans_sf |>  
  tidyr::drop_na(city_label) |>  
  dplyr::pull(recipient_uei)

View(slice_sample(recip_coords_city_zip_trans |>
                    dplyr::filter(recipient_uei %in% city_ueis), 
                  n = 100))

## Plot if needed

if (interactive()) {
  source("./r-delivery/spending-figures_plotCity.R")
}

