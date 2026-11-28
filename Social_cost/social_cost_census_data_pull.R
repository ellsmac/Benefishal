#Author: E MacLean
#Date Created: Nov 28, 2026
#Modified: None
###############
#purpose of this script is to pull census data needed for social cost of bridge closure calcs

#clear enviro
rm(list = ls())

#load libraries
library(here)
library(tidycensus)
library(tidyverse)
library(janitor)

#