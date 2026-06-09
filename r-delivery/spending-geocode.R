# Title: City Federal Spending - Address Geocoding
# Description: Standalone script to rebuild the geocode cache (latlong.csv)
#   from scratch using a three-pass approach (Nominatim → Geocodio → Google).
#   Run this manually only if you need to regenerate the cache entirely.
#   Normal pipeline runs handle new addresses incrementally via spending-recipient_id.R.
#   Requires: city_trans_addys and cached_latlong to be defined (run after spending-config.R
#   and spending-recipient_id.R up to the geocoding section).
# Author: Derek Crowe
# Last Edited: 3/29/24

library(tidygeocoder)
library(ggmap)


latlong_1 <-   
  city_trans_addys |>  
  tidygeocoder::geocode(street = phys_address_01, 
                        city = phys_address_city,           
                        state = phys_address_st, 
                        postalcode = phys_address_ZIP,           
                        return_addresses = TRUE, 
                        method = "osm")

#Passing 3,497 addresses to the Nominatim single address geocoder
#Query completed in: 3556.9 seconds

latlong_1 |>  
  dplyr::summarise(across(c(lat, long), ~ sum(is.na(.)), .names = "{.col}_na.count"))

# Nominatim osm missed 880 geocodes
latlong_nas_1 <-   
  latlong_1 |>  
  dplyr::filter(is.na(lat | long)) 

#Let's try geocodio
latlong_2 <-  
  city_trans_addys |>  
  dplyr::filter(phys_address_01 %in% latlong_nas_1$phys_address_01) |>  
  tidygeocoder::geocode(street = phys_address_01, 
                        city = phys_address_city,           
                        state = phys_address_st, 
                        postalcode = phys_address_ZIP,           
                        return_addresses = TRUE, 
                        method = "geocodio") 

latlong_2 |>  
  dplyr::summarise(across(c(lat, long), ~ sum(is.na(.)), .names = "{.col}_na.count"))

#geocodio finds 835 of these 880
latlong_nas_2 <-   
  latlong_2 |>  
  dplyr::filter(is.na(lat | long)) 

latlong_nas_2 |>  
  dplyr::summarise(across(c(lat, long), ~ sum(is.na(.)), .names = "{.col}_na.count"))  

# Use google for last 13

# Google Maps API key — set GOOGLE_MAPS_KEY in .env
ggmap::register_google(key = Sys.getenv("GOOGLE_MAPS_KEY"), write = TRUE)

latlong_3 <-
  city_trans_addys |>
  dplyr::filter(phys_address_01 %in% latlong_nas_2$phys_address_01) |>
  dplyr::mutate(full_address = paste0(phys_address_01, ", ",
                               phys_address_city, ", ",
                               phys_address_st, ", ",
                               phys_address_ZIP)) |>
  ggmap::mutate_geocode(full_address) |>  
  dplyr::rename(long = lon)

latlong_nas_3 <-   
  latlong_3 |>  
  dplyr::filter(is.na(lat | long)) 

latlong_nas_3

latlong_3


# Bind all geocoded addys together, save as a separate object to avoid 
# re-running all the geocoding. 

latlong <-    
  latlong_1 |>  
  dplyr::filter(!is.na(lat)) |>  
  dplyr::bind_rows(latlong_2 |>               
              filter(!is.na(lat))) |>  
  dplyr::bind_rows(latlong_3 |>              
              filter(!is.na(lat))) |>  
  dplyr::filter(phys_address_country == "USA") |>  
  dplyr::select(-c("full_address"))

readr::write_csv(latlong, cached_latlong)
