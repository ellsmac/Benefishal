# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 4, 2026
# Modified: Nov 22, 2026
####################
#goal of this script is to combine our cleaned precip and flood datasets!
#Nov 22 mod is to make a floods/prism dataset for analysis

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

#need pst date and time columns for joining to prism data 
flood_events <- flood_events |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

######
#joining actual precip to flood data!
#floods_precip <- floods_daily |>
 # left_join(t_precip, by = "date_pst")

#joining prism precip too
#flood_precip_prism <- flood_precip |>
#  left_join(prism_precip, by = "date_pst") |>
#  rename(t_precip_in = precip_inches)

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
#write_csv(floods_precip, here("Flood_data/clean_data", "floods_precip.csv"))

#load cleaned floods_precip data

floods_precip <- read_csv(here("Flood_data/clean_data", "floods_precip.csv"))

###
#making prism dataset to match to floods, like t_precip

#creating precip columns for 2 days before and 3 days after
prism_windows <- prism_precip |>
  arrange(date_pst) |>
  mutate(precip_minus2 = lag(prism_precip_in, 2),
         precip_minus1 = lag(prism_precip_in, 1),
         precip_day0 = prism_precip_in,
         precip_plus1 = lead(prism_precip_in, 1),
         precip_plus2 = lead(prism_precip_in, 2),
         precip_plus3 = lead(prism_precip_in, 3))

#need pst date and time columns for joining to prism data 
flood_events <- flood_events |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)
  
#joining to flood events
floods_prism_windows <- floods_daily |>
  left_join(prism_windows, by = "date_pst") 

floods_prism_windows <- floods_prism_windows |>
  select(-prism_precip_in)

floods_prism_windows <- floods_prism_windows |>
  relocate(precip_day0, .after = cfs_value)

#saving as csv
write_csv(floods_prism_windows, here("Flood_data/clean_data",
                                    "floods_prism_windows.csv"))

