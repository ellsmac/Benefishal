# Author: E MacLean
# Created: Nov 18, 2026
# Modified: Nov 20, 2026
##################
#purpose of this script is to run preliminary detour cost calculations!

#clear enviro
rm(list = ls())

#load libraries
library(here)
library(tidyverse)

#load data

#income data
income_r19 <- read_csv(here("Census_data/clean_data",
                            "hourly_income_riverside_2019.csv"))

income_r24 <- read_csv(here("Census_data/clean_data",
                            "hourly_income_riverside_2024.csv"))

income_sd19 <- read_csv(here("Census_data/clean_data",
                             "hourly_income_sd_2019.csv"))

income_sd24 <- read_csv(here("Census_data/clean_data",
                             "hourly_income_sd_2024.csv"))

#voc data
voc_19 <- read_csv(here("Detour_cost/clean_data",
                        "AAA_2019_vehicle_op_cost.csv"))
voc_24 <- read_csv(here("Detour_cost/clean_data",
                        "AAA_2024_vehicle_op_cost.csv"))

#travel data
detour_data <- read_csv(here("Detour_cost/clean_data", 
                             "detour_estimates.csv"))

#traffic data
traffic <- read_csv(here("traffic_study_data",
                       "traffic_data.csv")) #this is both years combined and cleaned!

#calculations...

  #original proposal was for this equation: 
  #total cost per year = volume of traffic per day * distance traveled * cost of travel/mile * 365
  #but we have to do...
  #avg volume of traffic per day * distance traveled * VOC * time traveled * avg hourly income * 365
    #above calc also assumes cars have one person in them only, but Cal B/C uses an average vehicle occupancy number
    #that is 1.3 people per car in non-peak general traffic, and 1.15 for general traffic! up to us if we want to use








