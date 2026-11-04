# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 2, 2026
# Modified: Nov 3, 2026
####################
# Goal of this script is to combine historical precipitation data w/ log of flood events
# to get an idea of how precip is correlated w/ flooding

#Data Description
  #for flood data we have USGS gauge 110443000 (bridge gauge), flood incidents are
  #any point when gauge reads >2300 cfs
  #for precip data we have actuals from Riverside County Flood Control district
  #for a Temecula gauge, years 2014-2025
  #also have synthetic data from OSU PRISM, specific to our study area from years 1992-2025, but will hold off on that for now

#Library Loading
library(here) #allows pointed file structure, essential for Mac to PC coding
library(tidyverse)
library(janitor)

#Precip data loading
t_precip_raw <- read.csv(here("Flood_Data/raw_data", "Temecula_Rainfall.csv"))
t_precip <- t_precip_raw |>
  clean_names()
  #this is missing the July 2016 to June 2017 data, need to add in

t_precip_2016_2017 <- read.csv(here("Flood_Data/raw_data", 
                                    "temecula_daily_rainfall_FY2016-17.csv"))

#precip data cleaning
t_precip <- t_precip |>
  mutate(month = match(month, month.abb))
  #turning months into numbers to match my 2016-17 data and the gauge data when we merge it










