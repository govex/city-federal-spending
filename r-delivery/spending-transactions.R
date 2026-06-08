# Title: City Federal Spending - Spending Transactions
# Description: Collecting and summarizing spending over time for each city
# Author: Derek Crowe
# Last Edited: 06/05/24

library(fs)

# Collect Transactions ==============================
# Don't run this unless you want to collect all the transactions again. Run this 
# If you have new UEIs, new places, or new years of data. Takes ~15 minutes. 
run_transactions <- FALSE

if (run_transactions) {
  
city_trans <-   
  trans |>  
  purrr::map(~ filter(.x, recipient_uei %in% !!city_ueis) |>         
        collect(), .progress == TRUE) 

city_trans_full <-   
  city_trans |>  
  dplyr::bind_rows()

readr::write_csv(city_trans_full, 
                 glue("./data-processed/city_transactions_{Sys.Date()}.csv"))

}

# Or load the list of transactions last collected  ======================

# Define the directory containing the files
directory.trans <- "./data-processed"

# List all transaction files in the directory
files.trans <- 
  dir_ls(directory.trans) %>%
  str_subset("city_transactions_\\d{4}-\\d{2}-\\d{2}\\.csv")

# Extract the dates from the file names and find the most recent one
most_recent_file.trans <- 
  files.trans %>%
  tibble(file = .) %>%
  mutate(date = str_extract(file, "\\d{4}-\\d{2}-\\d{2}")) %>%
  mutate(date = as.Date(date)) %>%
  arrange(desc(date)) %>%
  slice(1) %>%
  pull(file)

city_trans_full <- 
  read_csv(most_recent_file.trans)

# Define uei to place crosswalk
cross_uei_place <-   
  recip_coords_city_zip_trans |>
  select(recipient_uei, city_label) |>
  drop_na(city_label) |>
  inner_join(city_places |> 
               distinct(city_label, .keep_all = TRUE) |>
               select(-c(city, state_code, state)), 
             by = join_by(city_label)) 
  distinct(recipient_uei, .keep_all = TRUE)

# Combine transaction data with recipient location city_labels and Define 
# Fiscal Years 
city_trans_placed <-   
  city_trans_full |>  
  dplyr::inner_join(cross_uei_place, by = "recipient_uei") |>  
  dplyr::mutate(FY = case_when(action_date_year_month >= "2016-10" & 
                          action_date_year_month <= "2017-9" ~ "2017",                        
                        action_date_year_month >= "2017-10" & 
                          action_date_year_month <= "2018-9" ~ "2018",                        
                        action_date_year_month >= "2018-10" & 
                          action_date_year_month <= "2019-9" ~ "2019",                        
                        action_date_year_month >= "2019-10" & 
                          action_date_year_month <= "2020-9" ~ "2020",                        
                        action_date_year_month >= "2020-10" & 
                          action_date_year_month <= "2021-9" ~ "2021",                        
                        action_date_year_month >= "2021-10" & 
                          action_date_year_month <= "2022-9" ~ "2022",                        
                        action_date_year_month >= "2022-10" & 
                          action_date_year_month <= "2023-9" ~ "2023"),          
         .after = action_date)

sam_gov_reduced <-  
  sam_gov |>  
  dplyr::distinct(recipient_uei, .keep_all = TRUE) |>
  dplyr::select(recipient_uei, entity_structure, bus_type_counter, 
                bus_type_string, primary_NAICS, NAICS_code_counter, 
                NAICS_code_string, PSC_code_counter, PSC_code_string)

city_trans_sam <-  
  city_trans_placed |>  
  dplyr::inner_join(sam_gov_reduced, by = join_by(recipient_uei)) |>
  dplyr::relocate(city_label, .before = primary_place_of_performance_state_name) 

readr::write_csv(city_trans_sam, 
                 glue("data-processed/city_trans_sam_{Sys.Date()}.csv"))


