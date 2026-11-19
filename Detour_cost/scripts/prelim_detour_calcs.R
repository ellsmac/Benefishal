# Author: E MacLean
# Created: Nov 18, 2026
# Modified: none
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
  #rachel load osrm data table aquí por favor :)

#traffic data
traffic <- read_csv(here("traffic_study_data",
                       "traffic_data.csv")) #this is both years combined and cleaned!










