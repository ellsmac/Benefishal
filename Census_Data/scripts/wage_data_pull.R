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
