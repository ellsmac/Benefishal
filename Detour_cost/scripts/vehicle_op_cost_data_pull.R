# Author: E MacLean
# Created: Nov 18, 2026
# Modified: none
##################
#purpose of this script is to gather AAA vehicle operation costs into csvs
#and adjust for 2024 dollars as needed

#clear enviro
rm(list = ls())

#load libraries
library(tidyverse)
library(here)
library(janitor)

#data
#we're using AAA numbers, published online in PDFs. want just the ntnl average vehicle operating costs (fuel and maintenance per mile)
#link to 2024 driving costs pdf: https://drive.google.com/file/d/1HYrH3CqqtsA82lBg-5NBwUbYS3TjcBzR/view?usp=share_link
#link to 2019 driving costs pdf: https://drive.google.com/file/d/1Ry1Vt1gKI2hQ3yoO9UV2l2nyCRWAlvEF/view?usp=share_link

op_cost_24 <- tibble(
  cost_type = c("fuel", "maintenance"),
  usd_24 = c(0.149, 0.1013)  
)

op_cost_24 <- op_cost_24 |>
  add_row(cost_type = "total", usd_24 = sum(op_cost_24$usd_24))

#saving 2024 vehicle operation costs

write_csv(op_cost_24, here("Detour_cost/clean_data",
                           "AAA_2024_vehicle_op_cost.csv"))

