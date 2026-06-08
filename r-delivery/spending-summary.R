# Title: City Federal Spending - Summary
# Description: Summarize federal spending to local governments for each city by
# fiscal year, output for engineers, and plot data
# Author: Derek Crowe
# Last Edited: 06/05/24


## Summarize and output for engineers
city_trans_filtered |>
  dplyr::group_by(place_id, FY) |>
  dplyr::summarise(total_obligations = sum(federal_action_obligation)) |>
  dplyr::select(FY, total_obligations, place_id) |>
  dplyr::mutate(category_id = rep("", length(FY)), 
                FY = paste0(FY, "-01-01 00:00:00")) |>
  dplyr::rename(value = total_obligations, 
                date = FY) |>
  readr::write_csv(glue("data-delivery/city-federal-spending_{Sys.Date()}.csv"))
  
## temporary patch to remove all negative values from delivery file
  govex_spending_2024_06_05 |>
    dplyr::mutate(value = case_when(value < 0 ~ NA, 
                                                TRUE ~ value)) |>
    readr::write_csv(glue("data-delivery/city-federal-spending_{Sys.Date()}.csv"))


## Plot 
if (interactive()) {
  source("./r-delivery/spending-figures_plotSpending.R")
}
