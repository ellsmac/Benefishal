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
  #this is missing the July 2016 to June 2017 data, need to add in

t_precip_2016_2017 <- read.csv(here("Flood_Data/raw_data", 
                                    "temecula_daily_rainfall_FY2016-17.csv"))

#precip data cleaning
t_precip_part <- t_precip_raw |>
  clean_names()

t_precip_part <- t_precip_part |>
  rename(precip_inches = precipitation_inches,
         month_abb = month)
        #making column names match before joining

t_precip_part <- t_precip_part |>
  mutate(month = match(month_abb, month.abb)) |>
  select(-month_abb)
  #making month values match before joining

t_precip_2016_2017 <- t_precip_2016_2017 |>
  rename(precip_inches = precipitation_in)
  #making column names match before joining

t_precip <- t_precip_part |>
  full_join(t_precip_2016_2017)
  #adding all our precip actuals together!

t_precip <- t_precip |>
  mutate(date_pst = make_date(year, month, day)) |>
  relocate(date_pst, .before = precip_inches)
  #making a date column to match the date format in our flood datasets

t_precip <- t_precip |>
  drop_na(date_pst) |>
  select(precip_inches, date_pst)

write.csv(t_precip, here("Flood_data/clean_data", 
                         "temecula_precip_actuals_2014_2024.csv"))
  #now can ignore the prior code, just read in temecula_precip_actuals_2014_2024 as t_precip
  #to get the right stuff
 
#isolate peak flow for every day, then match precip to that, because precip is daily 

#flood data loading
floods_92 <- read_csv(here("Flood_Data/clean_data", "floods_1992.csv"))

floods_93_94 <- read_csv(here("Flood_Data/clean_data", "floods_1993_1994.csv"))

floods_95_97 <- read_csv(here("Flood_Data/clean_data", "floods_1995_1997.csv"))

floods_98_00 <- read_csv(here("Flood_Data/clean_data", "floods_1998_2000.csv"))

floods_01_03 <- read_csv(here("Flood_Data/clean_data", "floods_2001_2003.csv"))

floods_04_06 <- read_csv(here("Flood_Data/clean_data", "floods_2004_2006.csv"))

floods_07_09 <- read_csv(here("Flood_Data/clean_data", "floods_2007_2009.csv"))

floods_10_12 <- read_csv(here("Flood_Data/clean_data", "floods_2010_2012.csv"))

floods_13_15 <- read_csv(here("Flood_Data/clean_data", "floods_2013_2015.csv"))
  #file doesn't exist because there were no flooding events 

floods_16_18 <- read_csv(here("Flood_Data/clean_data", "floods_2016_2018.csv"))

floods_19_21 <- read_csv(here("Flood_Data/clean_data", "floods_2019_2021.csv"))

floods_22_24 <- read_csv(here("Flood_Data/clean_data", "floods_2022_2024.csv"))

floods_25 <- read_csv(here("Flood_Data/clean_data", "floods_2025.csv"))

#floods data merging
floods <- bind_rows(floods_92, floods_93_94, floods_95_97, floods_98_00,
                    floods_01_03, floods_04_06, floods_07_09, floods_10_12,
                    floods_16_18, floods_19_21, floods_22_24, floods_25)

floods <- floods |>
  select(-...1)

#now want to isolate peak flows for every distinct date in date_pst
floods_daily <- floods |>
  slice_max(cfs_value, by = date_pst, n = 1, with_ties = FALSE)

write.csv(floods_daily, here("Flood_Data/clean_data", "daily_flood_buffer.csv"))
  #saved daily max flows for flood events plus 
  #the max values for the 48hrs before and 72hrs after each flood event

#####
#joining precip to flood data!
flood_precip <- floods_daily |>
  left_join(t_precip, by = "date_pst")













