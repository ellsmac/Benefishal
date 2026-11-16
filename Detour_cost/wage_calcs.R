# Author: E MacLean
# Created: Nov 16, 2026
# Modified: None
##################
#purpose of this script is to calculate average hourly wage for detour cost calculations

#clear enviro
rm(list = ls())

#load libraries
library(tidyverse)
library(here)
library(janitor)

#load data
income_r24 <- read_csv(here("Census_data/clean_data", 
                            "median_income_riverside_2024.csv"))

income_r19 <- read_csv(here("Census_data/clean_data", 
                            "median_income_riverside_2019.csv"))

income_sd24 <- read_csv(here("Census_data/clean_data", 
                             "median_income_sd_2024.csv"))

income_sd19 <- read_csv(here("Census_data/clean_data", 
                             "median_income_sd_2019.csv"))

hrs_r24 <- read_csv(here("Census_data/clean_data", 
                         "mean_workhrs_riverside_2024.csv"))

hrs_r19 <- read_csv(here("Census_data/clean_data", 
                         "mean_workhrs_riverside_2019.csv"))

hrs_sd24 <- read_csv(here("Census_data/clean_data", 
                          "mean_workhrs_sd_2024.csv"))

hrs_sd19 <- read_csv(here("Census_data/clean_data", 
                          "mean_workhrs_sd_2019.csv"))

#calculating income per hour
  #assuming everyone works 51 weeks a year...
  #multiply hours per week estimates by 51 to get total hours worked per year
  #then divide median annual income by total hours worked per year to get estimate of
  #income per hour

#Starting with Riverside 2024 data
#want to build a new data frame to save, going to have to further clean loaded data to combo everyone

#cleaning data for joining
hrs_r24 <- hrs_r24 |>
  clean_names() |>
  mutate(mean_hrs_yr = estimate*51) |>
  rename(mean_hrs_wk = estimate, 
         mean_hrs_wk_moe = moe)
hrs_r24 <- hrs_r24 |>
  select(-variable)

income_r24 <- income_r24 |>
  clean_names() |>
  rename(med_income = estimate,
         med_income_moe = moe)
income_r24 <- income_r24 |>
  select(-variable)

#joining hrs to income
income_r24 <- income_r24 |>
  full_join(hrs_r24)

#creating new column w/ hourly income for each tract
income_r24 <- income_r24 |>
  mutate(med_hourly_income = med_income/mean_hrs_yr)
  #this is in 2024 adjusted dollars so don't need to do any calibrating!


#creating hourly income estimate for San Diego 2024 data

#cleaning names
hrs_sd24 <- hrs_sd24 |>
  clean_names()|>
  mutate(mean_hrs_yr = estimate*51) |>
  rename(mean_hrs_wk = estimate, 
         mean_hrs_wk_moe = moe) |>
  select(-variable)

income_sd24 <- income_sd24 |>
  clean_names() |>
  rename(med_income = estimate,
         med_income_moe = moe) |>
  select(-variable)

#joining hrs to income
income_sd24 <- income_sd24 |>
  full_join(hrs_sd24)

#creating new column with median hourly income estimate
income_sd24 <- income_sd24 |>
  mutate(med_hourly_income = med_income/mean_hrs_yr)
  #this is in 2024 $ so don't have to do any adjusting/converting 


#creating median hourly income estimate for riverside 2019 data

#cleaning names
hrs_r19 <- hrs_r19 |>
  clean_names()|>
  mutate(mean_hrs_yr = estimate*51) |>
  rename(mean_hrs_wk = estimate, 
         mean_hrs_wk_moe = moe) |>
  select(-variable)

income_r19 <- income_r19 |>
  clean_names() |>
  rename(med_income = estimate,
         med_income_moe = moe) |>
  select(-variable)

#joining hrs to income
income_r19 <- income_r19 |>
  full_join(hrs_r19)

#creating new column with median hourly income estimate
income_r19 <- income_r19 |>
  mutate(med_hourly_income = med_income/mean_hrs_yr)

#now still need to ajdust all those values for inflation into 2024 dollars



#creating median hourly income estimates for Sd 2019 data

#cleaning names
hrs_sd19 <- hrs_sd19 |>
  clean_names()|>
  mutate(mean_hrs_yr = estimate*51) |>
  rename(mean_hrs_wk = estimate, 
         mean_hrs_wk_moe = moe) |>
  select(-variable)

income_sd19 <- income_sd19 |>
  clean_names() |>
  rename(med_income = estimate,
         med_income_moe = moe) |>
  select(-variable)

#joining hours to income
income_sd19 <- income_sd19 |>
  full_join(hrs_sd19)

#creating new column with median hourly income estimate
income_sd19 <- income_sd19 |>
  mutate(med_hourly_income = med_income/mean_hrs_yr)

#adjusting for inflation, using CPI Inflation Calculator from the US Bureau of Labor Stats: https://www.bls.gov/data/inflation_calculator.htm
#there are few enough values for sd_19 that I can do it by hand, then use R to understand how the 
#values are transformed, then apply that transformation to r_19 data?

adjusted_hrly_income <- tibble(
  tract = c(188.01, 189.03, 189.04, 189.05, 189.06, 190.01), 
  med_hourly_income_adj = c(19.70, 16.66, 17.75, 16.29, 17.97, 20.76))
  #used Jan 2019 to Jan 2024 as inputs to calculate these adjusted values

income_sd19 <- income_sd19 |>
  left_join(adjusted_hrly_income, join_by(tract))






