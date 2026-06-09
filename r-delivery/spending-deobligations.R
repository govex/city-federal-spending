# Title: City Federal Spending - Deobligations
# Description: Spread deobligations across years to eliminate negative 
# values in yearly summations of city spending
# Last Edited: 06/05/24


# First we're going to capture all award keys that contain deobligations
award_keys_deobs_all <-
  city_trans_filtered |>
  dplyr::filter(federal_action_obligation < 0) |>
  dplyr::distinct(award_summary_unique_key)

#15,423 unique awards with at least one deobligation

# Capture all awards that have both obligations and deobligations
award_keys_deobs_with_obs <-
  city_trans_filtered |>
  dplyr::filter(award_summary_unique_key %in%
                  award_keys_deobs_all$award_summary_unique_key) |>
  dplyr::filter(federal_action_obligation > 0) |>
  dplyr::distinct(award_summary_unique_key, .keep_all = TRUE) |>
  dplyr::select(award_summary_unique_key)

# 11,412 unique awards with deobligations that have at least one obligation

# Next we'll identify all awards that contain exclusively deobligations
award_keys_deobs_without_obs <-
  award_keys_deobs_all |>
  dplyr::filter(!award_summary_unique_key %in%
                  award_keys_deobs_with_obs$award_summary_unique_key)

# 4,011 unique awards with deobligations that have no obligations

# We'll now count the number of years these awards span since 2017
n_years_deobs_no_ob <- 
  city_trans_filtered |>
  dplyr::filter(award_summary_unique_key %in% 
                  award_keys_deobs_without_obs$award_summary_unique_key) |>
  dplyr::group_by(award_summary_unique_key, city_label) |>
  dplyr::summarize(first = 2017, 
                   last = max(FY),
                   n_years = (last-first)+1) |>
  dplyr::select(award_summary_unique_key, n_years, FY = last, city_label)

# We will now calculate the total amount to subtract from each year for each 
# city for awards which contain exclusively deobligations
deob_without_ob_sub_per_year <-
  city_trans_filtered |>
  dplyr::filter(award_summary_unique_key %in% 
                  award_keys_deobs_without_obs$award_summary_unique_key) |>
  dplyr::group_by(award_summary_unique_key) |>
  # total deob amount for awards with deobs that have no obs
  dplyr::summarise(award_deob_total = sum(federal_action_obligation)) |> 
  # join with n_year data
  dplyr::left_join(n_years_deobs_no_ob, 
                   by = join_by(award_summary_unique_key)) |> 
  # amount to deduct from each year of award to even out deobs across years 
  dplyr::mutate(sub_deob_per_year = award_deob_total/n_years) |> 
  # expand subtractions the number of times they will occur across years
  tidyr::uncount(n_years) |> 
  dplyr::group_by(award_summary_unique_key) |> 
  # update repeated years to reflect each individual yearly subtraction
  dplyr::mutate(FY = FY - (row_number() - 1)) |> 
  dplyr::group_by(city_label, FY) |>
  # summarize amount to subtract from each year to account for deobs with no obs
  dplyr::summarize(sub_deob_per_year.sum = sum(sub_deob_per_year)) 


# Next we'll find all the years over which to spread deobligations 
n_years_obs_deobs_ob <- 
  city_trans_filtered |>
  dplyr::filter(award_summary_unique_key %in% 
                  award_keys_deobs_with_obs$award_summary_unique_key) |>
  dplyr::arrange(award_summary_unique_key) |>
  # distribute deobs across all years for which a positive obligation 
  # occurred for the same award
  dplyr::filter(federal_action_obligation > 0) |> 
  dplyr::group_by(award_summary_unique_key) |> 
  # number of years over which to spread deobs
  dplyr::summarise(n_years = n_distinct(FY)) 

# And calculate the amount to deduct from each year of obligations
award_sub.per_year.deobs_with_obs <- 
  city_trans_filtered |>
  #transactions with awards that have deobs with obs
  dplyr::filter(award_summary_unique_key %in% 
                  award_keys_deobs_with_obs$award_summary_unique_key) |> 
  dplyr::filter(federal_action_obligation < 0) |># deobs
  dplyr::group_by(award_summary_unique_key) |>
  # total deob amount for awards with deobs that have obs
  dplyr::summarise(award_deob_total = sum(federal_action_obligation)) |> 
  # join with n_year data
  dplyr::left_join(n_years_obs_deobs_ob, 
                   by = join_by(award_summary_unique_key)) |> 
  # amount to deduct from each year of award to even out deobs across 
  # action years 
  dplyr::mutate(sub_deob_per_year = award_deob_total/n_years) 

# Next, we'll sum the total spending number for all awards that have deobs & obs
deob_with_ob_total_per_year <-
  city_trans_filtered |>
  #transactions with awards that have deobs with obs
  dplyr::filter(award_summary_unique_key %in% 
                  award_keys_deobs_with_obs$award_summary_unique_key) |> 
  # limit to positive obligations for subtracting deobs to avoid double 
  # subtracting deobs
  dplyr::filter(federal_action_obligation > 0) |> 
  dplyr::group_by(award_summary_unique_key, FY, city_label) |>
  # order by award for easy sanity checking
  dplyr::arrange(award_summary_unique_key) |> 
  # sum all positive obligations for awards that have deobs and obs
  dplyr::summarise(total_pos_obs = sum(federal_action_obligation)) |> 
  # join with deob subtraction data
  dplyr::left_join(award_sub.per_year.deobs_with_obs, 
            by = join_by(award_summary_unique_key)) |> 
  #subtract deobs from pos ob sum by year
  dplyr::mutate(pos_obs_per_year = total_pos_obs/n_years,
                deob_with_ob_new.sum = pos_obs_per_year+sub_deob_per_year, 
                .after = sub_deob_per_year) |> 
  dplyr::group_by(city_label, FY) |>
  # summarize total spending number for all awards that have deobs and obs
  dplyr::summarize(deob_with_ob_per_year.sum = sum(deob_with_ob_new.sum)) |> 
  dplyr::arrange(deob_with_ob_per_year.sum)

# Finally, we add all awards with no deobligations, the sum total of spending 
# for awards with obligations and deobligations, and the sum total of spending 
# for awards with only deobligations
sum_obs <- 
  city_trans_filtered |>
  dplyr::filter(!award_summary_unique_key %in% 
                  award_keys_deobs_all$award_summary_unique_key) |>
  dplyr::group_by(city_label, FY) |>
  dplyr::summarise(no_deobs_per_year.sum = sum(federal_action_obligation)) |>
  dplyr::full_join(deob_with_ob_total_per_year) |>
  dplyr::full_join(deob_without_ob_sub_per_year) |>
  dplyr::mutate(deob_with_ob_per_year.sum = 
                  replace_na(deob_with_ob_per_year.sum, 0)) |>
  dplyr::mutate(sub_deob_per_year.sum = replace_na(sub_deob_per_year.sum, 0)) |>
  dplyr::mutate(no_deobs_per_year.sum = replace_na(no_deobs_per_year.sum, 0)) |>
  dplyr::mutate(total_obs_per_year = 
                  no_deobs_per_year.sum + 
                  deob_with_ob_per_year.sum + 
                  sub_deob_per_year.sum) 

