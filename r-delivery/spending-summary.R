# Title: City Federal Spending - Summary
# Description: Summarize federal spending to local governments for each city by
# fiscal year, output for engineers, and plot data
# Author: Derek Crowe
# Last Edited: 06/05/24


## Summarize and output for engineers
city_spending_summary <-
  city_trans_filtered |>
  dplyr::group_by(place_id, FY) |>
  dplyr::summarise(total_obligations = sum(federal_action_obligation)) |>
  dplyr::select(FY, total_obligations, place_id) |>
  dplyr::mutate(category_id = rep("", length(FY)),
                FY = paste0(FY, "-01-01 00:00:00")) |>
  dplyr::rename(value = total_obligations,
                date = FY)

# City/years that remain negative after deobligation spreading are set to NA
city_spending_summary |>
  dplyr::mutate(value = dplyr::if_else(value < 0, NA_real_, value)) |>
  readr::write_csv(glue("data-delivery/city-federal-spending_{Sys.Date()}.csv"))


## Plot 
if (interactive()) {
  source("./r-delivery/spending-figures_plotSpending.R")
}
