# Retrieving SMR Flood Data, USGS Gauge 110443000
# Author: E MacLean
# Created: Nov 2, 2026
# Modified: Nov 3, 2026
####################
# Learning to pull USGS gauge data from our relevant gauge, testing to see if what I pull matches Quinn's pulls

#Install package to get data
install.packages("dataRetrieval")
  #had to add an API to make sure I could get USGS data

#load libraries
library(dataRetrieval)
library(here)
library(tidyverse)
library(janitor)

#SMR at Sandia Creek Drive Bridge
siteNumber <- "USGS-11044300"
smrinfo<- read_waterdata_monitoring_location(siteNumber)
  #data table w/ info about gauge, tells us this gauge uses daylight savings time!
parameterCd <- c("00060", "00011")
  #this is the parameter code for getting discharge in cfs
dataavailable <- read_waterdata_ts_meta(
  monitoring_location_id = siteNumber)
  #row 6 tells us we can get discharge in points, does this mean continuous data?

#Retrieving raw yearly continuous data
raw_1990 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                     parameter_code = parameterCd,
                                     time = c("1990-01-16", "1990-12-31"))
#saving 1990 raw data
write.csv(raw_1990, here("Flood_data/raw_data",
                            "raw_1990_gauge_11044300.csv"))

raw_1991 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                   parameter_code = parameterCd,
                                   time = c("1991-01-01", "1991-12-31"))
#saving raw 1991 data
write.csv(raw_1991, here("Flood_data/raw_data",
                         "raw_1991_gauge_11044300.csv"))

raw_1992 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                                  parameter_code = parameterCd,
                                                  time = c("1992-01-01", "1992-12-31"))
#saving raw 1992 data
write.csv(raw_1992, here("Flood_data/raw_data",
                         "raw_1992_gauge_11044300.csv"))

raw_1993_1994 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                      parameter_code = parameterCd,
                                      time = c("1993-01-01", "1994-12-31"))

#saving raw 1993-4 data
write.csv(raw_1993_1994, here("Flood_data/raw_data",
                         "raw_1993_94_gauge_11044300.csv"))

raw_1995_1997 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("1995-01-01", "1997-12-31"))

#saving raw 1995-97 data
write.csv(raw_1995_1997, here("Flood_data/raw_data",
                              "raw_1995_97_gauge_11044300.csv"))

raw_1998_2000 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("1998-01-01", "2000-12-31"))
    #three years is as big as I can seem to pull at once, and it still takes some time

#saving raw 1998-2000 data
write.csv(raw_1998_2000, here("Flood_data/raw_data",
                              "raw_1998_2000_gauge_11044300.csv"))

raw_2001_2003 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2001-01-01", "2003-12-31"))
#saving raw 2001-2003 data
write.csv(raw_2001_2003, here("Flood_data/raw_data",
                              "raw_2001_2003_gauge_11044300.csv"))

raw_2004_2006 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2004-01-01", "2006-12-31"))

#saving raw 2004-2006 data
write.csv(raw_2004_2006, here("Flood_data/raw_data",
                              "raw_2004_2006_gauge_11044300.csv"))

raw_2007_2009 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2007-01-01", "2009-12-31"))
#saving raw 2007-2009 data
write.csv(raw_2007_2009, here("Flood_data/raw_data",
                              "raw_2007_2009_gauge_11044300.csv"))

raw_2010_2012 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2010-01-01", "2012-12-31"))
#saving raw 2010-2012 data
write.csv(raw_2010_2012, here("Flood_data/raw_data",
                              "raw_2010_2012_gauge_11044300.csv"))

raw_2013_2015 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2013-01-01", "2015-12-31"))
#saving raw 2013-2015 data
write.csv(raw_2013_2015, here("Flood_data/raw_data",
                              "raw_2013_2015_gauge_11044300.csv"))

raw_2016_2018 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2016-01-01", "2018-12-31"))
#saving raw 2016-2018 data
write.csv(raw_2016_2018, here("Flood_data/raw_data",
                              "raw_2016_2018_gauge_11044300.csv"))

raw_2019_2021 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2019-01-01", "2021-12-31"))
#saving raw 2019-2021 data
write.csv(raw_2019_2021, here("Flood_data/raw_data",
                              "raw_2019_2021_gauge_11044300.csv"))

raw_2022_2024 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2022-01-01", "2024-12-31"))
#saving raw 2022-2024 data
write.csv(raw_2022_2024, here("Flood_data/raw_data",
                              "raw_2022_2024_gauge_11044300.csv"))

raw_2025 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2025-01-01", "2025-12-31"))
#saving raw 2025 data
write.csv(raw_2025, here("Flood_data/raw_data",
                              "raw_2025_gauge_11044300.csv"))

###########

#data cleaning, 1990
discharge_1990 <- raw_1990 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#then finding all possible flood rows, pf = possible flood
pf_1990 <- discharge_1990 |>
  filter(cfs_value >= 2300)
  #no floods in this data, max is 230cfs
  ##align gaps in gauge data w/ historical precip to check for potential missing storm events?

#####
#data cleaning, 1991
discharge_1991 <- raw_1991 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#then finding all possible flood rows, pf = possible flood
pf_1991 <- discharge_1991 |>
  filter(cfs_value >=2300)
  #no floods this data, max is 553cfs
  ##align gaps in gauge data w/ historical precip to check for potential missing storm events?

########
#data cleaning, 1992
#can't switch to pst this early on, still need original time for id'ing floods, convert at end
discharge_1992 <- raw_1992 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_1992 <- discharge_1992 |>
  filter(cfs_value >= 2300)
  #68 rows returned where cfs is greater than or equal to 2300

#want to know the peak flood time for each day with a value over 2300, keeping duplicates
pf_1992 <- pf_1992 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1) |>
  ungroup()

#now want to grab all readings from 48hrs before & 72hrs after each reading in pf_1992
#first have to make windows for each flood peak
windows_92 <- pf_1992 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_1992 <- discharge_1992 |>
  semi_join(windows_92, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_1992 <- floods_1992 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_1992, here("Flood_data/clean_data",
                            "floods_1992.csv"))


#####
#finding gaps in gauge readings
#run invidual years then turn into one big df for the whole time scale
#going to have to drop any gaps smaller than 0.5?
#then do time conversion on gap_start & gap_end, then break into gap_date_start, gap_time_start, gap_date_end, gap_time_end
#gaps in 1990
gaps_1990 <- raw_1990 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1990, here("Flood_data/clean_data",
                            "gauge_gaps_1990.csv"))

#gaps 1991
gaps_1991 <- raw_1991 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1991, here("Flood_data/clean_data",
                          "gauge_gaps_1991.csv"))

#gaps 1992
gaps_1992 <- raw_1992 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1992, here("Flood_data/clean_data",
                          "gauge_gaps_1992.csv"))

#gaps 1993-94
gaps_1993_94 <- raw_1993_1994 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1993_94, here("Flood_data/clean_data",
                          "gauge_gaps_1993_1994.csv"))

#gaps 1995-97
gaps_1995_97 <- raw_1995_1997 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1995_97, here("Flood_data/clean_data",
                             "gauge_gaps_1995_1997.csv"))

#gaps 1998-2000
gaps_1998_2000 <- raw_1998_2000 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_1998_2000, here("Flood_data/clean_data",
                             "gauge_gaps_1998_2000.csv"))

#gaps 2001-03
gaps_2001_03 <- raw_2001_2003 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2001_03, here("Flood_data/clean_data",
                             "gauge_gaps_2001_2003.csv"))

#gaps 2004-2006
gaps_2004_06 <- raw_2004_2006 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2004_06, here("Flood_data/clean_data",
                             "gauge_gaps_2004_2006.csv"))

#gaps 2007-2009
gaps_2007_09 <- raw_2007_2009 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2007_09, here("Flood_data/clean_data",
                             "gauge_gaps_2007_2009.csv"))

#gaps 2010-2012
gaps_2010_12 <- raw_2010_2012 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2010_12, here("Flood_data/clean_data",
                             "gauge_gaps_2010_2012.csv"))

#gaps 2013-2015
gaps_2013_15 <- raw_2013_2015 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2013_15, here("Flood_data/clean_data",
                             "gauge_gaps_2013_2015.csv"))

#gaps 2016-2018
gaps_2016_18 <- raw_2016_2018 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2016_18, here("Flood_data/clean_data",
                             "gauge_gaps_2016_2018.csv"))

#gaps 2019-2021
gaps_2019_21 <- raw_2019_2021 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

write.csv(gaps_2019_21, here("Flood_data/clean_data",
                             "gauge_gaps_2019_2021.csv"))

#gaps 2022-2024
gaps_2022_24 <- raw_2022_2024 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

#gaps 2025
gaps_2025 <- raw_2025 |>
  arrange(time) |>
  mutate(
    gap_start = lag(time),
    gap_end   = time,
    gap_total_hours   = as.numeric(difftime(gap_end, gap_start, units = "hours"))
  ) |>
  filter(gap_total_hours > 0.25) |>
  select(gap_start, gap_end, gap_total_hours) |>
  mutate(missing_readings = gap_total_hours * 4 - 1,
         gap_total_days = gap_total_hours / 24) |>
  relocate(gap_total_days, .after = gap_total_hours)

