library(here)
library(dplyr)
library(tidyr)
library(osrm)
library(ggplot2)

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

#for (i in seq_len(nrow(df))) {
#for (i in seq_len(1000)){
#  if (i%%10==0){print(i)}
#  origin <- c(df$origin_lon[i],df$origin_lat[i])
#  dest <- c(df$longitude[i],df$latitude[i])
#  route <- osrmRoute(src = origin, dst = dest)
  
#  df$osrm_duration[i] <- route$duration
#  df$osrm_distance[i] <- route$distance
#}

for (station in unique(df$dept_sta)) {
#for (station in c('05')){
  idx <- which(df$dept_sta == station)
  
  print(station)
  
  if (length(idx) == 0) next
  
  origin <- data.frame(lon = df$origin_lon[idx[1]],lat = df$origin_lat[idx[1]])
  
  destinations <- data.frame(lon = df$longitude[idx],lat = df$latitude[idx])
  
  batches <- split(idx, ceiling(seq_along(idx) / 100))
  
  for (batch in batches) {
    
    destinations <- data.frame(lon = as.numeric(df$longitude[batch]),lat = as.numeric(df$latitude[batch]))
    
    routes_duration <- osrmTable(src = origin,dst = destinations,measure = "duration")
    
    routes_distance <- osrmTable(src = origin,dst = destinations,measure = "distance")
    
    df$osrm_duration[batch] <- as.numeric(routes_duration$durations[1, ])
    df$osrm_distance[batch] <- as.numeric(routes_distance$distances[1, ])
  }
  
}

subdf = df %>% drop_na(osrm_duration,osrm_distance)
ggplot(subdf, aes(x = osrm_duration, y = response_time_min,color = dept_sta)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "black", linetype = "dashed") +
  theme_minimal() +
  labs(x = "Predicted Duration", y = "Actual Response Time")


