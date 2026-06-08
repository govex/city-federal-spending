# Title: City Federal Spending - Transaction Filters
# Description: Transaction Filtering using Recipient info
# Author: Derek Crowe
# Last Edited: 06/05/24


# Filter transactions to local government recipients
city_trans_sam.12 <-
  city_trans_sam |>
  dplyr::filter(grepl('12', bus_type_string))


# Filter transactions to exclude local government recipients that also identify
# with the following business type codes
#C7 = County
#2F = U.S. State Government
#OH = State Controlled Institution of Higher Learning
exclude.codes <- c("C7", "2F", "OH")

city_trans_sam.12.ex <-
  city_trans_sam.12 |>
  dplyr::filter(!grepl(paste(exclude.codes, collapse = '|'), bus_type_string))


# To identify false negatives from the exclusion, well also find transactions 
# associated with recipients that don't fit into our conception of city 
# governments
blacklist <-
  c(
    "EG8WAM315LZ5",
    #HOUSING AUTHORITY OF THE COUNTY OF KERN; Bakersfield, CA
    "T81MLLAMG4K9",
    #OKLAHOMA, COUNTY OF
    "KRN3EHZL2VC3",
    #WICHITA AREA METROPOLITAN PLANNING ORGANIZATION
    "EP6MLJ21L3G3",
    #ELECTRICAL SYSTEMS INC, Wichita, KS
    "DTNMMPBN5715",
    #SANTA CLARA CNTY HOUSING AUTH
    "WVPXXNGJHNN5",
    #SOUTHERN CALIFORNIA INTERGOVERNMENTAL TRAINING & DEVELOPMENT CENTER
    "MLB7RPN9DK25",
    #UTAH PERFORMING ARTS CENTER AGENCY
    "W8S7DA41BTV3",
    #SOUTHEAST NEBRASKA DEVELOPEMENT DISTRICT
    "C8F3CY5MLJE8",
    #JACKSON HINDS LIBRARY SYSTEM
    "Y6DVFRLRR2D7",
    #HUNTSVILLE-MADISON COUNTY AIRPORT AUTHORITY
    "CDEZZSTCZTR5",
    #METROPOLITAN TRANSIT AUTHORITY OF HARRIS COUNTY; Houston, TX
    "L666V7ZW6CG3",
    #COLUMBUS-FRANKLIN COUNTY FINANCE AUTHORITY
    "Z3LULQHD94B9",
    #CUYAHOGA COUNTY LAND REUTILIZATION CORPORATION
    "GGZZKEZLFZT1",
    #NATIVE AMERICAN INDIAN CENTER OF CENTRAL OHIO
    "GGZZKEZLFZT1",
    #ILLINOIS INTERNATIONAL PORT DISTRICT
    "ND9STDVJND49",
    #ILLINOIS DEPARTMENT OF EMPLOYMENT SECURITY
    "MUP2NS4H1MV7",
    #IL PUBLIC SAFETY AGENCY NETWRK
    "GVC3E8KNC8N3",
    #CHATTANOOGA - HAMILTON COUNTY AIR POLLUTION CONTROL BUREAU
    "C234L4APDQ89",
    #WEST VIRGINIA STATE AUDITORS OFFICE
    "GJ14HLKXRNR5" #YELLOWSTONE CITY-COUNTY HEALTH
  )

# Function to replace codes with names
replace_codes <- function(code_string, code_df) {
  codes <- strsplit(code_string, "~")[[1]]
  names <- code_df$Name[match(codes, code_df$Code)]
  names <- ifelse(is.na(names), codes, names)  # If code not found, keep original code
  return(paste(names, collapse = "~"))
}


df.bus_types <- readr::read_csv("./data-raw/business_types.csv")

city_trans_sam.12.ex.fneg <-
  city_trans_sam.12 |>
  dplyr::mutate(names = map_chr(bus_type_string, 
                                ~ replace_codes(.x, df.bus_types)),
                .after = recipient_name) |>
  dplyr::filter(grepl(paste(exclude.codes, collapse = '|'), 
                      bus_type_string)) |>
  dplyr::filter(!grepl("OH", bus_type_string)) |>
  dplyr::filter(grepl("(?=.*City)(?=.*County)",
                      names,
                      ignore.case = TRUE,
                      perl = TRUE)) |>
  dplyr::filter(!recipient_uei %in% blacklist)

city_trans_sam.12.ex.pb <-
  city_trans_sam.12.ex |>
  dplyr::bind_rows(city_trans_sam.12.ex.fneg)

 
# Remove zeros from transactions to get a better count,
# Filter place of performance to match state of recipient address

city_trans_filtered <-
  city_trans_sam.12.ex.pb |>
  dplyr::filter(federal_action_obligation != 0) |>
  dplyr::inner_join(
    city_places |>
      dplyr::select(GEOID_20, state, state_code) |>
      dplyr::mutate(state = str_to_upper(state)),
    by = join_by(GEOID_20)) |>
  dplyr::relocate(c(state, primary_place_of_performance_state_name, city_label),
           .after = recipient_name) |>
  dplyr::filter(
    primary_place_of_performance_state_name == state |
      primary_place_of_performance_state_name == state_code |
      is.na(primary_place_of_performance_state_name)) |>
  dplyr::mutate(FY = as.numeric(FY))
