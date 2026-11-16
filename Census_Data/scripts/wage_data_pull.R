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

#pulling median individual income for SD County, 2024
income_sd24 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "San Diego",
  year = 2024,
  geometry = FALSE)

#pulling median individual income for SD COunty, 2019
income_sd19 <- get_acs(
  geography = "tract",
  variables = "B07011_001",
  state = "CA",
  county = "San Diego",
  year = 2019,
  geometry = FALSE)
  

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

#######

#now to join everyone...testing with income_r24
#have to extract tract values from income df's so that i have a key to join the tables with

income_r24 <- income_r24 |>
  mutate(tract = str_extract(NAME, "[0-9.]+(?=;)")) |>
  relocate(tract, .after = GEOID) |>
  mutate(tract = as.numeric(tract))

#joining income_r24 to riverside_blocks so we get just the relevant rows for median income

income_r24 <- income_r24 |>
  semi_join(riverside_blocks, join_by(tract))
  #income_r24 is now just our relevant tracts

#saving cleaned median income for 2024 riverside county
write_csv(income_r24, here("Census_data/clean_data", 
                           "median_income_riverside_2024.csv"))

#income_r19
income_r19 <- income_r19 |>
  mutate(tract = str_extract(NAME, "[0-9.]+(?=,)")) |>
  mutate(tract = as.numeric(tract))

#join to riverside_blocks for relevant tracts only
income_r19 <- income_r19 |>
  semi_join(riverside_blocks, join_by(tract))







