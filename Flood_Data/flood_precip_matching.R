# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 4, 2025
# Modified: None
####################
#goal of this script is to combine our cleaned precip and flood datasets!

#loading data
floods_daily <- read_csv(here("Flood_Data/clean_data",
                              "daily_flood_buffer.csv"))

t_precip <- read_csv(here("Flood_data/clean_data", 
     "temecula_precip_actuals_2014_2024.csv"))


#####
#joining actual precip to flood data!
flood_precip <- floods_daily |>
  left_join(t_precip, by = "date_pst")