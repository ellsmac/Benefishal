# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 2, 2026
# Modified: None
####################
# Goal of this script is to combine historical precipitation data w/ log of flood events
# to get an idea of how precip is correlated w/ flooding

# Data Description
  #for flood data we have USGS gauge 110443000 (bridge gauge), flood incidents are
  #any point when gauge reads >2300 cfs
  #for precip data we have actuals from Riverside County Flood Control district
  #for a Temecula gauge, years 2014-2025
  #also have synthetic data from OSU PRISM, specific to our study area from years 1992-2025

#Data Loading
