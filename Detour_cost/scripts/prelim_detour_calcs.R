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

##calculations

  #original proposal was for this equation: 
  #total cost per year = volume of traffic per day * distance traveled * cost of travel/mile * 365
  #but we have to do...
  #avg volume of traffic per day * distance traveled * VOC * time traveled * avg hourly income * 365
    #above calc also assumes cars have one person in them only, but Cal B/C uses an average vehicle occupancy number
    #that is 1.3 people per car in non-peak general traffic, and 1.15 for general traffic! up to us if we want to use


#step 1: select inputs for equation

#wages from census tracts that contain the 7 block groups
#(tract GEOID = first 11 digits of the block-group GEOID)
bg_detail <- read_csv(here("Detour_cost/clean_data", "bridge_closure_by_bg.csv"))
affected_tracts <- bg_detail |>
  filter(bridge_fastest) |>
  mutate(tract_geoid = substr(bg, 1, 11)) |>
  distinct(tract_geoid) |>
  pull()
affected_tracts

##should be 7 blocks^

wage <- c(
  `2019` = income_r19 |> filter(geoid %in% affected_tracts) |> pull(med_hourly_income_adj) |> mean(na.rm = TRUE),
  `2024` = income_r24 |> filter(geoid %in% affected_tracts) |> pull(med_hourly_income) |> mean(na.rm = TRUE)
)
wage

#VOC: AAA "total" row (fuel + maintenance), $ per mile
voc <- c(
  `2019` = voc_19 |> filter(cost_type == "total") |> pull(usd_24),
  `2024` = voc_24 |> filter(cost_type == "total") |> pull(usd_24)
)
voc

#traffic: check which directions are bridge crossings
table(traffic$direction)
bridge_dirs <- c("nb", "sb")  

adt <- traffic |>
  filter(direction %in% bridge_dirs) |>
  mutate(date = mdy(date), year = year(date)) |>
  group_by(year, date) |>
  summarise(vol = sum(count, na.rm = TRUE), n_int = n(), .groups = "drop") |>
  filter(n_int == max(n_int)) |>          # drop partial count days (start/end of study)
  group_by(year) |>
  summarise(adt = mean(vol), n_days = n())
adt

#ADT = ~1,820 vehicles/day in 2019 (2 days in Aug)
   # = ~1,243 vehicles/day in 2024 (1 day in Oct)

km_to_mi  <- 0.621371
vot_share <- c(0.5, 1.0)     #1 = full hourly wage; 
closure_days <- 1.63
              #Do we want to adjust to Cal B/C?
#check - do we need this value? What is the Cal B/C

#Step 2: run dif scenarios: yr*detour method*num ppl per car
results <- expand_grid(
  year      = c(2019, 2024),
  method    = detour_data$method,
  occupancy = c(1.0, 1.15, 1.3)  #testing ppl/car scenarios based on 
                                #Cal B/C ave for general traffic
) |>
  left_join(detour_data |> select(method, dt_min, dd_km), by = "method") |>
  left_join(adt, by = "year") |>
  mutate(
    wage           = wage[as.character(year)],
    voc            = voc[as.character(year)],
    extra_mi       = dd_km * km_to_mi,
    extra_hr       = dt_min / 60,
    voc_cost_trip  = extra_mi * voc,                               # per vehicle
    time_cost_trip = extra_hr * wage * vot_share * occupancy,      # per person x people in car
    cost_trip      = voc_cost_trip + time_cost_trip,
    cost_day       = adt * cost_trip,
    cost_year      = adt * cost_trip * closure_days #now updated to just our 1.63 days
  )

#3. Results table
#(all 3 count days, 2024 dollars)

adt_pooled <- traffic |>
  filter(direction %in% bridge_dirs) |>
  group_by(date) |>
  summarise(vol = sum(count, na.rm = TRUE), .groups = "drop") |>
  summarise(adt = mean(vol), n_days = n())
adt_pooled   # ~1,628 vehicles/day over 3 days

pooled <- expand_grid(
  method    = detour_data$method,
  occupancy = c(1.0, 1.15, 1.3)
) |>
  left_join(detour_data |> select(method, dt_min, dd_km), by = "method") |>
  mutate(
    adt            = adt_pooled$adt,
    wage           = wage["2024"],  #use ave with 2019
    voc            = voc["2024"],  #use ave with 2019
    extra_mi       = dd_km * km_to_mi,
    extra_hr       = dt_min / 60,
    voc_cost_trip  = extra_mi * voc,
    time_cost_trip = extra_hr * wage * vot_share * occupancy,
    cost_trip      = voc_cost_trip + time_cost_trip,
    cost_day       = adt * cost_trip,
    cost_year      = adt * cost_trip * closure_days
  )

#simplify to easier to read $ values
pooled_simple <- pooled |>
  mutate(method = if_else(grepl("dodgr", method), "dodgr(De_luz_rd)", "OSRM(I-15)")) |>
  group_by(method) |>
  summarise(
    adt               = first(adt),
    cost_trip_central = cost_trip[occupancy == 1.15],
    annual_low        = cost_year[occupancy == 1.0],   #1 person per car
    annual_central    = cost_year[occupancy == 1.15],  #Cal B/C general traffic
    annual_high       = cost_year[occupancy == 1.3],   #Cal B/C off-peak
    .groups = "drop"
  ) |>
  arrange(desc(method == "dodgr(De_luz_rd)"))

pooled_simple |> mutate(across(starts_with("annual"), \(x) scales::dollar(x, accuracy = 1000)))

write_csv(pooled_simple, here("Detour_cost/clean_data", "prelim_detour_costs_usd.csv"))


