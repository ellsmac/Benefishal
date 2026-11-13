# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 4, 2026
# Modified: Nov 12, 2026
####################
#goal of this script is to combine our cleaned precip and flood datasets!

#clean enviro
rm(list = ls())

#loading libraries
library(here)
library(tidyverse)

#loading data
floods_daily <- read_csv(here("Flood_Data/clean_data",
                              "daily_flood_buffer.csv"))
                              #loads with annoying "...1" column

t_precip <- read_csv(here("Flood_data/clean_data", 
     "temecula_precip_actuals_2014_2024.csv"))
      #will load with annoying extra column called "...1"

prism_precip <- read_csv(here("Flood_Data/clean_data",
                              "prism_precip_clean.csv"))

#loading in flood events only dataset
flood_events <- read_csv(here("Flood_data/clean_data", "flood_events.csv"))

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

######
#want to create a data frame that has my precip values for days before and after as separate columns

#editing t_precip to join to flood events, making precip before and after flood event columns
t_precip_windows <- t_precip |>
  arrange(date_pst) |>
  mutate(precip_minus2 = lag(precip_inches, 2),
         precip_minus1 = lag(precip_inches, 1),
         precip_day0 = precip_inches,
         precip_plus1 = lead(precip_inches, 1),
         precip_plus2 = lead(precip_inches, 2),
         precip_plus3 = lead(precip_inches, 3))

t_precip_windows <- t_precip_windows |>
  select(-precip_inches) |>
  relocate(precip_day0, .after = date_pst)

#joining floods_daily to t_precip_windows
floods_precip <- floods_daily |>
  left_join(t_precip_windows, by = "date_pst")
  #has lots of NAs in precip columns bc we only have 10 years of actual precip data atm

#saving floods_precip data
write_csv(floods_precip, here("Flood_data/clean_data", "floods_precip.csv"))








