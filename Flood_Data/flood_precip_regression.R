# Historical Precipiation & Flood Event Data Matching
# Author: E MacLean
# Created: Nov 22, 2026
# Modified: Nov 23, 2026
####################
#goal of this script is to run a regression for our flood and precip data...

#clean enviro
 rm(list = ls())

#load libraries
library(here)
library(tidyverse)
library(ggplot2)

#load data
floods_precip <- read_csv(here("Flood_data/clean_data", "floods_precip.csv"))

floods_prism <- read_csv(here("Flood_data/clean_data", "floods_prism.csv"))

#run a linear regression
#model 1
flood_model1 <- lm(cfs_value ~ precip_day0 + precip_minus1 + precip_minus2 +
                     precip_plus1 + precip_plus2 + precip_plus3,
                   data = floods_precip)
summary(flood_model1)
  #precip day 0 is significant, as is precip one day after

#model 2, w/ prism data
flood_model2 <- lm(cfs_value ~ precip_day0 + precip_minus1 + precip_minus2 +
                     precip_plus1 + precip_plus2 + precip_plus3,
                   data = floods_prism)
summary(flood_model2)
  #precip day of is significant, as is precip minus2 and precip_plus1

###
#what are doing with this info?
#plotting precip values on x, cfs on y, the plotting points for flood days,
#to determine the threshold for flooding based on precip, include only statistically signigicant days
#for prism thats day of, day before two days before, and day after
#for actuals thats day of and day after

#plotting actuals (model 1)
model_1_plot <- ggplot(floods_precip, aes(x = precip_day0, y = cfs_value)) +
  geom_point(data = filter(floods_precip, flood == 1)) +
  geom_smooth(method = "lm") +
  geom_hline(yintercept = 2300, color = "red") + #line for bridge flooding
  theme_bw()
model_1_plot
  
#plotting prism data, flood events + windows
model_2_plot <- ggplot(floods_prism, aes(x = precip_day0, y = cfs_value)) +
  geom_point() +
  geom_smooth(method = "lm") +
  geom_hline(yintercept = 2300, color = "red") + #line for bridge flooding
  theme_bw()
model_2_plot
  #lm intersects our 2300 line now







