# Author: E MacLean
# Created: Nov 25, 2026
# Modified: none
####################
#pulling cal adapt data on projected precip

#load libaries
library(zarr) #data is held in Zarr store, need this library to get at it
library(paws.common) #aws access to our cal adapt data...
library(paws.storage) #aws access to our cal adapt data...
library(tidyverse)
library(here)
library(janitor)

#retrieving the data...
  #data source: https://stac-browser.cal-adapt.org/#/collections/wrf-climate-metrics-map/items/wrf-climate-metrics-map-mm4mean-ssp370-gwl-R99pd-d03
  #mean change in 99th percentile precipitation from historical, in mm
delta_mean_precip_raw <- open_zarr("s3://cadcat/wrf/climate-metrics-map/mm4mean/ssp370/gwl/R99pd/d03/")

#data exploration
delta_mean_precip_raw$hierarchy()
  #we're gonna drop the map projection values, we don't need

#reading the data into R
r99pd <- delta_mean_precip_raw[["/R99pd"]]$read() #mean change in 99th percentile precip from historical, mm
gwl <- delta_mean_precip_raw[["/gwl"]]$read() #global warming level, 1.5 degree change, 2, 2.5, 3
y <- delta_mean_precip_raw[["/y"]]$read()
x <- delta_mean_precip_raw[["/x"]]$read()
lat <- delta_mean_precip_raw[["/lat"]]$read()      
lon <- delta_mean_precip_raw[["/lon"]]$read()
landmask <- delta_mean_precip_raw[["/landmask"]]$read()
lakemask <- delta_mean_precip_raw[["/lakemask"]]$read()

#turning the data into a data frame
n_gwl <- length(gwl)

delta_mean_precip <- expand.grid(gwl = gwl, y = y, x = x)
delta_mean_precip$R99pd    <- as.vector(r99pd) ()                    #mean change in 99th percentile precip from historical, mm
delta_mean_precip$lat      <- rep(as.vector(lat),      each = n_gwl) #global warming level, 1.5 degree change, 2, 2.5, 3
delta_mean_precip$lon      <- rep(as.vector(lon),      each = n_gwl)
delta_mean_precip$landmask <- rep(as.vector(landmask), each = n_gwl)
delta_mean_precip$lakemask <- rep(as.vector(lakemask), each = n_gwl)

#cutting down to just the rough lat long we care about
delta_mean_precip_smr <- delta_mean_precip |>
  filter(between(lat, 33.15, 33.35)) |>
  filter(between(lon, -117.20, -117.00))

#saving as csv...
write_csv(delta_mean_precip_smr, here("Detour_cost/raw_data",
                                      "cal_adapt_delta_mean_precip_smr.csv"))


######
#pulling min change in 99th percentile 

#retrieving the data
  #source: https://stac-browser.cal-adapt.org/#/collections/wrf-climate-metrics-map/items/wrf-climate-metrics-map-mm4min-ssp370-gwl-R99pd-d03
  # minimum change in 99th percentile precip from historical, mm

delta_min_raw <- open_zarr("s3://cadcat/wrf/climate-metrics-map/mm4min/ssp370/gwl/R99pd/d03/")

delta_min_raw$hierarchy()
  #same arrays as delta_mean, drop projection again

#reading the data into R
r99pd <- delta_min_raw[["/R99pd"]]$read() #minimum change in 99th percentile precip from historical, mm
gwl <- delta_min_raw[["/gwl"]]$read() #global warming level, 1.5 degree change, 2, 2.5, 3
y <- delta_min_raw[["/y"]]$read()
x <- delta_min_raw[["/x"]]$read()
lat <- delta_min_raw[["/lat"]]$read()      
lon <- delta_min_raw[["/lon"]]$read()
landmask <- delta_min_raw[["/landmask"]]$read()
lakemask <- delta_min_raw[["/lakemask"]]$read()

#checking we've got things in the right order to read in, should be gwl, y, x
  #so need to get 4, 472, 223
dim(r99pd)
  #get 4, 472, 223!

#turning into a data frame
n_gwl <- length(gwl)

delta_min <- expand.grid(gwl = gwl, y = y, x = x)
delta_min$r99pd    <- as.vector(r99pd)                    #minimum change in 99th percentile precip from historical, mm
delta_min$lat      <- rep(as.vector(lat),      each = n_gwl) #global warming level, 1.5 degree change, 2, 2.5, 3
delta_min$lon      <- rep(as.vector(lon),      each = n_gwl)
delta_min$landmask <- rep(as.vector(landmask), each = n_gwl)
delta_min$lakemask <- rep(as.vector(lakemask), each = n_gwl)

#cutting down to just our study area
delta_min_smr <- delta_min |>
  filter(between(lat, 33.15, 33.35)) |>
  filter(between(lon, -117.20, -117.00))

#saving as csv...
write_csv(delta_min_smr, here("Detour_cost/raw_data",
                                      "cal_adapt_delta_min_precip_smr.csv"))















