# Retrieving SMR Flood Data, USGS Gauge 110443000
# Author: E MacLean
# Created: Nov 2, 2026
# Modified: Nov 12, 2026
####################
# Learning to pull USGS gauge data from our relevant gauge, testing to see if what I pull matches Quinn's pulls

# Nov 12 modification note: didn't make a df of just the flood days (no buffer days), have to do that now

#Install package to get data
install.packages("dataRetrieval")
  #had to add an API to make sure I could get USGS data

#load libraries
library(dataRetrieval)
library(here)
library(tidyverse)
library(janitor)

#SMR at Sandia Creek Drive Bridge
# siteNumber <- "USGS-11044300"
# smrinfo<- read_waterdata_monitoring_location(siteNumber)
  #data table w/ info about gauge, tells us this gauge uses daylight savings time!
# parameterCd <- c("00060", "00011")
  #this is the parameter code for getting discharge in cfs
# dataavailable <- read_waterdata_ts_meta(
  # monitoring_location_id = siteNumber)
  #row 6 tells us we can get discharge in points, does this mean continuous data?

#Retrieving raw yearly continuous data
# raw_1990 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                  #   parameter_code = parameterCd,
                                  #   time = c("1990-01-16", "1990-12-31"))
#saving 1990 raw data
# write.csv(raw_1990, here("Flood_data/raw_data",
                         #   "raw_1990_gauge_11044300.csv"))

# raw_1991 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                #   parameter_code = parameterCd,
                                #   time = c("1991-01-01", "1991-12-31"))
#Nov 12, 2026 update

      #saving raw 1991 data
      # write.csv(raw_1991, here("Flood_data/raw_data",
                             #  "raw_1991_gauge_11044300.csv"))
      
      # raw_1992 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                             #           parameter_code = parameterCd,
                                             #           time = c("1992-01-01", "1992-12-31"))
      #saving raw 1992 data
      # write.csv(raw_1992, here("Flood_data/raw_data",
                           #    "raw_1992_gauge_11044300.csv"))

#Read in raw 1992 data
raw_1992 <- read_csv(here("Flood_data/raw_data", "raw_1992_gauge_11044300.csv"))


      #get raw 1993-1994
      # raw_1993_1994 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                       #     parameter_code = parameterCd,
                                       #     time = c("1993-01-01", "1994-12-31"))
      
      #saving raw 1993-4 data
       # write.csv(raw_1993_1994, here("Flood_data/raw_data",
                            #   "raw_1993_94_gauge_11044300.csv"))

#read raw 1993-94 data
raw_1993_1994 <- read_csv(here("Flood_data/raw_data", "raw_1993_94_gauge_11044300.csv"))


      #pulling raw 95-97
      # raw_1995_1997 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                            #     parameter_code = parameterCd,
                                            #     time = c("1995-01-01", "1997-12-31"))
      
      #saving raw 1995-97 data
      #write.csv(raw_1995_1997, here("Flood_data/raw_data",
                               #     "raw_1995_97_gauge_11044300.csv"))

#read raw 195-97 data
raw_1995_1997 <- read_csv(here("Flood_data/raw_data",
                                        "raw_1995_97_gauge_11044300.csv"))

      #pull raw 98-00 data
      #raw_1998_2000 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                        #         parameter_code = parameterCd,
                                        #         time = c("1998-01-01", "2000-12-31"))
          #three years is as big as I can seem to pull at once, and it still takes some time
      
      #saving raw 1998-2000 data
      #write.csv(raw_1998_2000, here("Flood_data/raw_data",
                                   # "raw_1998_2000_gauge_11044300.csv"))
#read raw 98-00 data
raw_1998_2000 <- read_csv(here("Flood_data/raw_data",
                                "raw_1998_2000_gauge_11044300.csv"))

      #pull raw 01-03 data
      # raw_2001_2003 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                             #    parameter_code = parameterCd,
                                              #   time = c("2001-01-01", "2003-12-31"))
      #saving raw 2001-2003 data
      #write.csv(raw_2001_2003, here("Flood_data/raw_data",
                               #     "raw_2001_2003_gauge_11044300.csv"))
#read raw 01-03 data
raw_2001_2003 <- read_csv(here("Flood_data/raw_data",
                         "raw_2001_2003_gauge_11044300.csv"))

      #pull raw 04-06 data
      # raw_2004_2006 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                        #         parameter_code = parameterCd,
                                        #         time = c("2004-01-01", "2006-12-31"))
      
      #saving raw 2004-2006 data
      #write.csv(raw_2004_2006, here("Flood_data/raw_data",
                               #     "raw_2004_2006_gauge_11044300.csv"))
#read raw 04-06 data
raw_2004_2006 <- read_csv(here("Flood_data/raw_data",
                         "raw_2004_2006_gauge_11044300.csv"))

      #pull raw 07-09 data
      #raw_2007_2009 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                            #     parameter_code = parameterCd,
                                             #    time = c("2007-01-01", "2009-12-31"))
      #saving raw 2007-2009 data
      #write.csv(raw_2007_2009, here("Flood_data/raw_data",
                                #    "raw_2007_2009_gauge_11044300.csv"))
#read raw 07-09 data
raw_2007_2009 <- read_csv(here("Flood_data/raw_data",
                       "raw_2007_2009_gauge_11044300.csv"))

      #pull raw 10-12 data
      #raw_2010_2012 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                        #         parameter_code = parameterCd,
                                        #         time = c("2010-01-01", "2012-12-31"))
      #saving raw 2010-2012 data
      #write.csv(raw_2010_2012, here("Flood_data/raw_data",
                              #      "raw_2010_2012_gauge_11044300.csv"))
#read raw 10-12 data
raw_2010_2012 <- read_csv(here("Flood_data/raw_data",
                          "raw_2010_2012_gauge_11044300.csv"))

      #read raw 13-15 data
      #raw_2013_2015 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                            #    parameter_code = parameterCd,
                                            #     time = c("2013-01-01", "2015-12-31"))
      #saving raw 2013-2015 data
      #write.csv(raw_2013_2015, here("Flood_data/raw_data",
                                    "raw_2013_2015_gauge_11044300.csv"))
      #read raw 16-18 data
      #raw_2016_2018 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                         #        parameter_code = parameterCd,
                                         #        time = c("2016-01-01", "2018-12-31"))
      #saving raw 2016-2018 data
      #write.csv(raw_2016_2018, here("Flood_data/raw_data",
                                #    "raw_2016_2018_gauge_11044300.csv"))
#read raw 16-18 data
raw_2016_2018 <- read_csv(here("Flood_data/raw_data",
                        "raw_2016_2018_gauge_11044300.csv"))

      #pull raw 19-21 data
      #raw_2019_2021 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                           #      parameter_code = parameterCd,
                                            #     time = c("2019-01-01", "2021-12-31"))
      #saving raw 2019-2021 data
      #write.csv(raw_2019_2021, here("Flood_data/raw_data",
                              #      "raw_2019_2021_gauge_11044300.csv"))
#read raw 19-21 data
raw_2019_2021 <- read_csv(here("Flood_data/raw_data",
                          "raw_2019_2021_gauge_11044300.csv"))

      #pull raw 22-24 data
      #raw_2022_2024 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                    #             parameter_code = parameterCd,
                                     #            time = c("2022-01-01", "2024-12-31"))
      #saving raw 2022-2024 data
      #write.csv(raw_2022_2024, here("Flood_data/raw_data",
                                #    "raw_2022_2024_gauge_11044300.csv"))
#read raw 22-24 data
raw_2022_2024 <- read_csv(here("Flood_data/raw_data",
                        "raw_2022_2024_gauge_11044300.csv"))

      #pull raw 25 data
      #raw_2025 <- read_waterdata_continuous(monitoring_location_id = siteNumber,
                                         #        parameter_code = parameterCd,
                                          #       time = c("2025-01-01", "2025-12-31"))
      #saving raw 2025 data
      #write.csv(raw_2025, here("Flood_data/raw_data",
                               #     "raw_2025_gauge_11044300.csv"))
#read raw 25 data
raw_2025 <- read_csv(here("Flood_data/raw_data",
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

#want to know the peak flood time for each day with a value over 2300, don't keep duplicates
pf_1992 <- pf_1992 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
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
#cleaning 1993-94 data
discharge_1993_94 <- raw_1993_1994 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_1993_94 <- discharge_1993_94 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_1993_94 <- pf_1993_94 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup()

#now want to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_93_94 <- pf_1993_94 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_1993_94 <- discharge_1993_94 |>
  semi_join(windows_93_94, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_1993_94 <- floods_1993_94 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_1993_94, here("Flood_data/clean_data",
                            "floods_1993_1994.csv"))
#####
#cleaning 1995-97 data
discharge_1995_97 <- raw_1995_1997 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_1995_97 <- discharge_1995_97 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_1995_97 <- pf_1995_97 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup()

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_95_97 <- pf_1995_97 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_1995_97 <- discharge_1995_97 |>
  semi_join(windows_95_97, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_1995_97 <- floods_1995_97 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_1995_97, here("Flood_data/clean_data",
                               "floods_1995_1997.csv"))

#####
#cleaning 1998-2000 data
discharge_1998_00 <- raw_1998_2000 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_1998_00 <- discharge_1998_00 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_1998_00 <- pf_1998_00 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup()

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_98_00 <- pf_1998_00 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_1998_00 <- discharge_1998_00 |>
  semi_join(windows_98_00, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_1998_00 <- floods_1998_00 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_1998_00, here("Flood_data/clean_data",
                               "floods_1998_2000.csv"))

#####
#cleaning 2001-2003 data
discharge_2001_03 <- raw_2001_2003 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2001_03 <- discharge_2001_03 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2001_03 <- pf_2001_03 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_01_03 <- pf_2001_03 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2001_03 <- discharge_2001_03 |>
  semi_join(windows_01_03, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2001_03 <- floods_2001_03 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2001_03, here("Flood_data/clean_data",
                               "floods_2001_2003.csv"))

#####
#cleaning 2004-2006 data
discharge_2004_06 <- raw_2004_2006 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2004_06 <- discharge_2004_06 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2004_06 <- pf_2004_06 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_04_06 <- pf_2004_06 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2004_06 <- discharge_2004_06 |>
  semi_join(windows_04_06, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2004_06 <- floods_2004_06 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2004_06, here("Flood_data/clean_data",
                               "floods_2004_2006.csv"))

#####
#cleaning 2007-2009 data
discharge_2007_09 <- raw_2007_2009 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2007_09 <- discharge_2007_09 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2007_09 <- pf_2007_09 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_07_09 <- pf_2007_09 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2007_09 <- discharge_2007_09 |>
  semi_join(windows_07_09, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2007_09 <- floods_2007_09 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2007_09, here("Flood_data/clean_data",
                               "floods_2007_2009.csv"))

#####
#cleaning 2010-2012 data
discharge_2010_2012 <- raw_2010_2012 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2010_2012 <- discharge_2010_2012 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2010_2012 <- pf_2010_2012 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_10_12 <- pf_2010_2012 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2010_2012 <- discharge_2010_2012 |>
  semi_join(windows_10_12, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2010_2012 <- floods_2010_2012 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2010_2012, here("Flood_data/clean_data",
                               "floods_2010_2012.csv"))

#####
#cleaning 2013-2015 data
discharge_2013_2015 <- raw_2013_2015 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2013_2015 <- discharge_2013_2015 |>
  filter(cfs_value >= 2300)
  #no floods in this dataset

#####
#cleaning 2016-2018 data
discharge_2016_2018 <- raw_2016_2018 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2016_2018 <- discharge_2016_2018 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2016_2018 <- pf_2016_2018 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_16_18 <- pf_2016_2018 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2016_2018 <- discharge_2016_2018 |>
  semi_join(windows_16_18, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2016_2018 <- floods_2016_2018 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2016_2018, here("Flood_data/clean_data",
                                 "floods_2016_2018.csv"))

#####
#cleaning 2019-2021 data
discharge_2019_21 <- raw_2019_2021 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2019_21 <- discharge_2019_21 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2019_21 <- pf_2019_21 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_19_21 <- pf_2019_21 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2019_2021 <- discharge_2019_21 |>
  semi_join(windows_19_21, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2019_2021 <- floods_2019_2021 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2019_2021, here("Flood_data/clean_data",
                                 "floods_2019_2021.csv"))

#####
#cleaning 2022-24 data
discharge_2022_24 <- raw_2022_2024 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2022_24 <- discharge_2022_24 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2022_24 <- pf_2022_24 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_22_24 <- pf_2022_24 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2022_24 <- discharge_2022_24 |>
  semi_join(windows_22_24, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2022_24 <- floods_2022_24 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2022_24, here("Flood_data/clean_data",
                                 "floods_2022_2024.csv"))
#####
#cleaning 2025 data
discharge_2025 <- raw_2025 |>
  dplyr::select(monitoring_location_id, time, value) |>
  rename(gauge_id = monitoring_location_id, 
         cfs_value = value,
         date_time_utc = time)

#looking for possible floods
pf_2025 <- discharge_2025 |>
  filter(cfs_value >= 2300)

#want to know the peak flood time for each day with a value over 2300, no duplicates
pf_2025 <- pf_2025 |>
  group_by(date = as.Date(date_time_utc, tz = "UTC")) |>
  slice_max(cfs_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-date)

#now to grab all readings from 48hrs before & 72hrs after each reading
#first have to make windows for each flood peak
windows_25 <- pf_2025 |>
  transmute(window_start = date_time_utc - 48 * 3600,
            window_end   = date_time_utc + 72 * 3600)

#now to grab the rows that match the windows
floods_2025 <- discharge_2025 |>
  semi_join(windows_25, join_by(between(date_time_utc, window_start, window_end)))

#now can make that dataset clean, splitting time and date from one another
floods_2025 <- floods_2025 |>
  mutate(date_pst = as.Date(date_time_utc, tz = "America/Los_Angeles"),
         time_pst = format(date_time_utc, "%H:%M:%S", tz = "America/Los_Angeles")) |>
  relocate(date_pst, .after = date_time_utc) |>
  relocate(time_pst, .after = date_pst)

#save floods datset!
write.csv(floods_2025, here("Flood_data/clean_data",
                               "floods_2025.csv"))

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

write.csv(gaps_2022_24, here("Flood_data/clean_data",
                             "gauge_gaps_2022_2024.csv"))

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

write.csv(gaps_2025, here("Flood_data/clean_data",
                             "gauge_gaps_2025.csv"))

#adding code to create a df of just my flood dates (aka days where flow exceeds 2300)

flood_events <- bind_rows(pf_1992, pf_1993_94, pf_1995_97, pf_1998_00,
                          pf_2001_03, pf_2004_06, pf_2007_09, pf_2010_2012,
                          pf_2016_2018, pf_2019_21, pf_2022_24, pf_2025)

flood_events <- flood_events |>
  select(-date)







