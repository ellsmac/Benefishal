# Author: E MacLean
# Created: Nov 10, 2026
# Modified: Nov 16, 2026
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
  #there are only 19 observations in this joined dataframe, meaning there are tracts in
  #riverside_blocsk with no match in income_r19. to see which tracts are missing running the
  #following code...
  riverside_blocks_missing <- riverside_blocks |>
    anti_join(income_r19, join_by(tract))
  #n_distinct(riverside_blocks_missing$tract)
  #[1] 10
    #tells me yes, there are 10 missing tracts, 
  #unique(riverside_blocks_missing$tract)
  #[1] 497.02 432.01 432.02 432.07 432.08 432.96 432.97 432.98 505.01 505.03
    #these are my missing tracts, can see which ones those are on a map here: https://www2.census.gov/geo/maps/DC2020/PL20/st06_ca/censustract_maps/c06065_riverside/DC20CT_C06065.pdf
  #how many people are we missing, with these 10 tracts not included in our median income estimate?
  riverside_blocks_missing <- riverside_blocks_missing |>
  group_by(tract) |>
    summarise(total_pop = sum(population, na.rm = TRUE))
  sum(riverside_blocks_missing$total_pop)
  # [1] 22257
  #so we're missing 22,257 people in our 2019 median individual income estimate compared to the 2024 estimate...
  
#saving cleaned median income for 2019 riverside county
write_csv(income_r19, here("Census_data/clean_data", 
                             "median_income_riverside_2019.csv"))


#now for sd county, 2024
income_sd24 <- income_sd24 |>
  mutate(tract = str_extract(NAME, "[0-9.]+(?=;)")) |>
  mutate(tract = as.numeric(tract))

#join income to relevant blocks
income_sd24 <- income_sd24 |>
  semi_join(sd_blocks, join_by(tract))
  #have income estimates for all tracts!

#saving cleaned median income for 2024 sd county
write_csv(income_sd24, here("Census_data/clean_data", 
                           "median_income_sd_2024.csv"))


#now for sd county, 2019
income_sd19 <- income_sd19 |>
  mutate(tract = str_extract(NAME, "[0-9.]+(?=,)")) |>
  mutate(tract = as.numeric(tract))

#join income to relevant blocks
income_sd19 <- income_sd19 |>
  semi_join(sd_blocks, join_by(tract))
  #only get 6 tracts, not all 8 relevant
  #missing: 188.04 & 188.05
  #how many people missing if we don't have 188.04 & 188.05?
    sd_tracts_pop <- sd_blocks |>
      group_by(tract) |>
      summarise(total_pop = sum(population, na.rm = TRUE))
  #580 people in tract 188.04, 0 in 188.05
    
#saving cleaned median income for 2019 sd county
    write_csv(income_sd19, here("Census_data/clean_data", 
                                "median_income_sd_2019.csv"))
    











