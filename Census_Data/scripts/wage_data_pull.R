# Author: E MacLean
# Created: Nov 10, 2026
# Modified: None
##################
#purpose of this script is to pull wage and work hours data for detour cost calcs

#clear enviro
rm(list = ls())

#load libraries
library(tidycensus)
library(janitor)
library(tidyverse)

#loading variables for use
vars<- load_variables(2024, "acs1", cache = TRUE)
view(vars)

vars_decennial <- load_variables(2020, "pl")
view(vars_decennial)

#testing pulling median income for Riverside County, 2024
income_r24 <- get_acs(
  geography = "block_group",
  variables = "B19013_001",
  state = "CA",
  county = "Riverside",
  year = 2024,
  geometry = TRUE)
  #this is good, need to break name column to separate block group and tract to match w/ our list of relevant blocks!
  #and what does MOE stand for? need to look up

#pulling median household income for Riverside County, 2019
income_r19 <- get_acs(
  geography = "block_group",
  variables = "B19013_001",
  state = "CA",
  county = "Riverside",
  year = 2019,
  geometry = TRUE)
  #different number of observations, than 2024, why? also aren't there more block groups than 1394? what's missing from these?

#pulling median income for SD County, 2024
income_sd24 <- get_acs(
  geography = "block_group",
  variables = "B19013_001",
  state = "CA",
  county = "San Diego",
  year = 2024,
  geometry = TRUE)
  #2058 observations

#pulling median income for SD COunty, 2019
income_sd19 <- get_acs(
  geography = "block_group",
  variables = "B19013_001",
  state = "CA",
  county = "San Diego",
  year = 2019,
  geometry = TRUE)
  #1795 observations 






