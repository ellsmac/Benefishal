# Retrieving SMR Flood Data, USGS Gauge 110443000
# Author: E MacLean
# Created: Nov 2, 2026
# Modified: None
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

# Raw yearly continuous data
raw_1990 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                     parameter_code = parameterCd,
                                     time = c("1990-01-16", "1990-12-31"))

raw_1991 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                   parameter_code = parameterCd,
                                   time = c("1991-01-01", "1991-12-31"))

raw_1992 <- raw_1991 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                                  parameter_code = parameterCd,
                                                  time = c("1992-01-01", "1992-12-31"))

raw_1993_1994 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                      parameter_code = parameterCd,
                                      time = c("1993-01-01", "1994-12-31"))

raw_1995_1997 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("1995-01-01", "1997-12-31"))

raw_1998_2000 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("1998-01-01", "2000-12-31"))
    #three years is as big as I can seem to pull at once, and it still takes some time

raw_2001_2003 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2001-01-01", "2003-12-31"))

raw_2004_2006 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2004-01-01", "2006-12-31"))

raw_2007_2009 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2007-01-01", "2009-12-31"))

raw_2010_2012 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2010-01-01", "2012-12-31"))

raw_2013_2015 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2013-01-01", "2015-12-31"))

raw_2016_2018 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2016-01-01", "2018-12-31"))

raw_2019_2021 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2019-01-01", "2021-12-31"))

raw_2022_2024 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2022-01-01", "2024-12-31"))

raw_2025 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           parameter_code = parameterCd,
                                           time = c("2025-01-01", "2025-12-31"))

#data cleaning, 1990
discharge_1990 <- raw_1990 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
    time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)
    #this code drops all columns but monitoring_location_id, time, value
    #then renames those columns, breaks time into date and time and converts both to pst
    #sticks those new columns after gauge id, and then drops the original time column

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
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
         time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)

#then finding all possible flood rows, pf = possible flood
pf_1991 <- discharge_1991 |>
  filter(cfs_value >=2300)
  #no floods this data, max is 553cfs
  ##align gaps in gauge data w/ historical precip to check for potential missing storm events?

########
#data cleaning, 1992
discharge_1992 <- raw_1992 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
         time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)

#looking for possible floods
pf_1992 <- discharge_1992 |>
  filter(cfs_value >= 2300)
  #68 rows returned where cfs is greater than or equal to 2300

#but how many distinct dates for floods?
pf_dates_1992 <- sort(unique(pf_1992$date_pst))
  #gives me vector of all dates where cfs is greater than or equal to 2300

#creating a "flood window", a vector w/ flood dates AND seven days before and 1 after each flood date
pf_window_1992 <-unique(rep(pf_dates_1992, each = 15) + -7:1)
  #gives me vector w/ flood dates AND seven days before and 1 after each flood date
  #this is my attempt at catching all of the floods and any info for storm events around flooding

#gauge data for potential flood windows, 1992
floods_1992 <- discharge_1992 |>
  filter(date_pst %in% pf_window_1992)

#####
#data cleaning, 1993 & 1994
discharge_1993_94 <- raw_1993_1994 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
         time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)

#looking for possible floods
pf_1993_94 <- discharge_1993_94 |>
  filter(cfs_value >= 2300)
#possible flood dates
pf_dates_1993_94 <- sort(unique(pf_1993_94$date_pst))
#possible flood date windows
pf_window_1993_94 <-unique(rep(pf_dates_1993_94, each = 15) + -7:1)

#gauge data for potential flood windows, 1993 & 1994
floods_1993_94 <- discharge_1993_94 |>
  filter(date_pst %in% pf_window_1993_94)
  #huge data gap before 01/13/1993!

####
#data cleaning, 1995-1997
discharge_1995_97 <- raw_1995_1997 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
         time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)

#looking for possible floods
pf_1995_97 <- discharge_1995_97 |>
  filter(cfs_value >= 2300)
#possible flood dates
pf_dates_1995_97 <- sort(unique(pf_1995_97$date_pst))
#possible flood date windows
pf_window_1995_97 <-unique(rep(pf_dates_1995_97, each = 15) + -7:1)

#gauge data for potential flood windows, 1995-1997
floods_1995_97 <- discharge_1995_97 |>
  filter(date_pst %in% pf_window_1995_97)

#####
#data cleaning, 1998-2000
discharge_1998_2000 <- raw_1998_2000 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value) |>
  mutate(date_pst = as.Date(time, tz = "America/Los_Angeles"),
         time_pst = format(time, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = gauge_id) |>
  relocate(time_pst, .after = date_pst) |>
  dplyr::select(-time)

#looking for possible floods
pf_1998_2000 <- discharge_1998_2000 |>
  filter(cfs_value >= 2300)
#possible flood dates
pf_dates_1998_2000 <- sort(unique(pf_1998_2000$date_pst))
#possible flood date windows
pf_window_1998_2000 <-unique(rep(pf_dates_1998_2000, each = 15) + -7:1)

#gauge data for potential flood windows, 1998-2000
floods_1998_2000 <- discharge_1998_2000 |>
  filter(date_pst %in% pf_window_1998_2000)


#####
#finding gaps in gauge readings
#run invidual years then turn into one big df for the whole time scale
#going to have to drop any gaps smaller than 0.5
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

