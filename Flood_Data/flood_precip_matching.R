# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 4, 2025
# Modified: None
####################
#goal of this script is to combine our cleaned precip and flood datasets!

#clean enviro
rm(list = ls())

#loading data
floods_daily <- read_csv(here("Flood_Data/clean_data",
                              "daily_flood_buffer.csv"))
                              #loads with annoying "...1" column

t_precip <- read_csv(here("Flood_data/clean_data", 
     "temecula_precip_actuals_2014_2024.csv"))
      #will load with annoying extra column called "...1"

prism_precip <- read_csv(here("Flood_Data/clean_data",
                              "prism_precip_clean.csv"))

#####
#quick data cleaning
floods_daily <- floods_daily |>
  select(-...1)

t_precip <- t_precip |>
  select(-...1)

######
#joining actual precip to flood data!
flood_precip <- floods_daily |>
  left_join(t_precip, by = "date_pst")

#joining prism precip too
flood_precip_prism <- flood_precip |>
  left_join(prism_precip, by = "date_pst") |>
  rename(t_precip_in = precip_inches)








