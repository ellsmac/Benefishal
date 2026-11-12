# Author: E MacLean
# Created: Nov 10, 2026
# Modified: Nov 12, 2026
##################
#purpose of this script is to pull wage and work hours data for detour cost calcs

#clear enviro
rm(list = ls())

#load libraries
library(tidycensus)
library(janitor)
library(tidyverse)

#loading variables for use
vars<- load_variables(2019, "acs1", cache = TRUE)
view(vars)

vars_decennial <- load_variables(2020, "pl")
view(vars_decennial)

#testing pulling median individual income for Riverside County, 2024
income_r24 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "Riverside",
  year = 2024,
  geometry = FALSE)
  #this invidual income only goes to tract level... great

#pulling median individual income for Riverside County, 2019
income_r19 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "Riverside",
  year = 2019,
  geometry = FALSE)
  #different number of observations, than 2024, why? also aren't there more block groups than 1394? what's missing from these?

#pulling median individual income for SD County, 2024
income_sd24 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "San Diego",
  year = 2024,
  geometry = FALSE)
  #2058 observations

#pulling median individual income for SD COunty, 2019
income_sd19 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "San Diego",
  year = 2019,
  geometry = FALSE)
  #1795 observations 

#####
#match these datasets to the relevant tracts for our study area, by geoid!

#loading relevant blocks

f_blocks <- read_csv(here("Census_data/clean_data", "f_blocks.csv"))
sd_blocks <- read_csv(here("Census_data/clean_data", "sd_blocks.csv"))
t_blocks <- read_csv(here("Census_data/clean_data", "t_blocks.csv"))
riverside_blocks <- read_csv(here("Census_data/clean_data", "riverside_blocks.csv"))

#cleaning & combining relevant blocks,
sd_blocks <- sd_blocks |>
  bind_rows(f_blocks) |>
  select(-...1)

riverside_blocks <- riverside_blocks |>
  bind_rows(t_blocks)

#now need to join income to riverside_blocks dataset
#will have to figure out how to match when geoid is longer in blocks dataset than in income
#will also have to rename columns from income datasets so that when added to blocks it's clear what year the values are from














