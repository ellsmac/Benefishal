library(here)
library(dplyr)
library(tidyr)
library(osrm)

df1 <- read.csv(here("Emergency_Response/Incidents_2014_2018_block.csv"))
df2 <- read.csv(here("Emergency_Response/Incidents_2014_2018_xy.csv"))
df_incidents <- df_joined <- bind_cols(df1,df2 %>% select(latitude, longitude))
  
riverside_blocks <- read.csv(here("Census_Data/clean_data/riverside_blocks.csv"))
sd_blocks <- read.csv(here("Census_Data/clean_data/sd_blocks.csv"))
geoids <- c(riverside_blocks$geoid, sd_blocks$geoid)

df_stations <- read.csv(here("Emergency_Response/all_sites.csv"))
stations <- df_stations$dept_sta

df<-df_incidents %>% 
  filter(block_geoid_2010 %in% geoids) %>% 
  filter(dept_sta %in% stations) %>%
  left_join(df_stations, by = "dept_sta")%>%
  drop_na(latitude, longitude, origin_lat,origin_lon)

#df <- split(dfinit, dfinit$block_geoid_2010)
#incident_geoids <- unique(dfinit$block_geoid_2010)

df$osrm_duration <- NA_real_
df$osrm_distance <- NA_real_

for (i in seq_len(nrow(df))) {
  origin <- c(df$origin_lon[i],df$origin_lat[i])
  dest <- c(df$longitude[i],df$latitude[i])
  route <- osrmRoute(src = origin, dst = dest)
  
  df$route_duration[i] <- route$duration
  df$route_distance[i] <- route$distance
}


