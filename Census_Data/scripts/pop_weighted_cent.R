
#loading libraries
# Packages (first time only)
# install.packages(c("USpopcenters", "tigris", "sf", "dplyr", "mapview", "osrm"))

library(USpopcenters)
library(tigris)
library(sf)
library(dplyr)
library(mapview)
library(osrm)

options(tigris_use_cache = TRUE)

#load in pop data
study_bg <- block_group2020 |>
  filter(STATEFP == "06", COUNTYFP %in% c("073", "065")) |>  # San Diego, Riverside
  mutate(GEOID = paste0(STATEFP, COUNTYFP, TRACTCE, BLKGRPCE)) |>
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = 4326)

#narrow to fallbrook and temecula
#library(sf); library(dplyr); library(osrm)

#read_zone <- function(path, zone) {
#  st_read(path, quiet = TRUE) |>
 #   st_drop_geometry() |>
  #  transmute(bg_geoid = substr(GEOID20, 1, 12), zone = zone)  # check your column name: GEOID20 / GEOID
#

#zones <- bind_rows(
#  read_zone("fallbrook_blocks.shp", "Fallbrook"),
#  read_zone("temecula_blocks.shp",  "Temecula"),
#  read_zone("sd_blocks.shp",        "SD rural"),
#  read_zone("riverside_blocks_corrected.shp", "Riverside rural")
#) |>
#  distinct(bg_geoid, .keep_all = TRUE)

#study_pts <- study_bg |>
 # inner_join(zones, by = c("GEOID" = "bg_geoid"))


#read in blocks from diff areas
blocks <- bind_rows(
  blocks(state = "CA", county = "San Diego", year = 2020),  #based on 2020 data
  blocks(state = "CA", county = "Riverside", year = 2020)
)
names(blocks)   # look for GEOID20, POP20, INTPTLAT20, INTPTLON20

#Step 2
pl <- places(state = "CA", year = 2020) |>
  filter(NAME %in% c("Fallbrook", "Temecula")) |>
  st_transform(st_crs(blocks))

blk_pts <- blocks |>
  filter(POP20 > 0) |>
  mutate(lon = as.numeric(INTPTLON20), lat = as.numeric(INTPTLAT20)) |>
  st_drop_geometry() |>
  st_as_sf(coords = c("lon", "lat"), crs = 4269)

study_blk <- blk_pts |>
  st_join(pl["NAME"], join = st_within) |>
  rename(zone = NAME)

#check on pop nums in temecula and fallbrook
study_blk |> st_drop_geometry() |> group_by(zone) |> summarise(pop = sum(POP20))

#defining rural areas based on bridge coordinates
#used a 20 km buffer 
bridge <- st_sfc(st_point(c(-117.240839, 33.414445)), crs = 4326) |> #coordinates of the bridge
  st_transform(3310)

bridge_pt <- st_transform(bridge, 4326) |> st_sf()

study_blk <- study_blk |>
  st_transform(3310) |>
  mutate(dist_km = as.numeric(st_distance(geometry, bridge)) / 1000,
         zone = if_else(is.na(zone) & dist_km <= 20, "Rural", zone)) |> #20 km buffer ring
  filter(!is.na(zone))

table(study_blk$zone)

#Plot area
plot(st_geometry(study_blk), col = factor(study_blk$zone), pch = 20, cex = 0.4)
plot(st_geometry(bridge), add = TRUE, col = "red", pch = 8, cex = 2)

#make it interactive
mapviewOptions(basemaps = c("Esri.WorldTopoMap", "OpenStreetMap", "Esri.WorldImagery"))

mapview(study_blk, zcol = "zone", cex = 3, layer.name = "Zone") +
  mapview(st_buffer(bridge, 20000), alpha.regions = 0, color = "red", layer.name = "20 km") +
  mapview(bridge, col.regions = "red", cex = 8, layer.name = "Bridge")


#Create useful centroids
pw_centroids <- study_blk |>
  mutate(bg = substr(GEOID20, 1, 12),
         x = st_coordinates(geometry)[,1], y = st_coordinates(geometry)[,2]) |>
  st_drop_geometry() |>
  group_by(bg, zone) |>
  summarise(pop = sum(POP20), hh = sum(HOUSING20),
            x = sum(POP20 * x) / pop, y = sum(POP20 * y) / pop, .groups = "drop") |>
  st_as_sf(coords = c("x", "y"), crs = 3310) |>
  st_transform(4326)

nrow(pw_centroids)

#filter to centroids that would use the bridge
osrm_retry <- function(src, dst, tries = 3) {
  for (k in seq_len(tries)) {
    res <- tryCatch(osrmTable(src = src, dst = dst)$durations, error = function(e) e)
    if (!inherits(res, "error")) return(res)
    message("Attempt ", k, " failed: ", conditionMessage(res)); Sys.sleep(5)
  }
  stop(res)
}

osrm_table_chunked <- function(src, dst, chunk = 50, pause = 1) {
  src_idx <- split(seq_len(nrow(src)), ceiling(seq_len(nrow(src)) / chunk))
  dst_idx <- split(seq_len(nrow(dst)), ceiling(seq_len(nrow(dst)) / chunk))
  out <- matrix(NA_real_, nrow(src), nrow(dst))
  for (i in src_idx) for (j in dst_idx) {
    out[i, j] <- osrm_retry(src[i, ], dst[j, ])
    Sys.sleep(pause)
  }
  out
}

# 1. Population-weighted center of each town (ordered Fallbrook, Temecula)
xy <- st_coordinates(pw_centroids)
towns <- pw_centroids |>
  st_drop_geometry() |>
  mutate(x = xy[, 1], y = xy[, 2]) |>
  filter(zone %in% c("Fallbrook", "Temecula")) |>
  group_by(zone) |>
  summarise(x = weighted.mean(x, pop), y = weighted.mean(y, pop)) |>
  st_as_sf(coords = c("x", "y"), crs = 4326)

targets <- rbind(towns, st_sf(zone = "Bridge", geometry = st_geometry(bridge_pt)))

# 2. Travel times: every centroid -> Fallbrook, Temecula, bridge (219 x 3)
d <- osrm_table_chunked(pw_centroids, targets)
colnames(d) <- targets$zone

# 3. Bridge -> each town (1 x 2)
br2town <- osrm_retry(targets[targets$zone == "Bridge", ], towns)

# 4. Flag centroids whose trip to the other town goes over the bridge
pw_centroids <- pw_centroids |>
  mutate(
    via_F = d[, "Bridge"] + br2town[1, 1],
    via_T = d[, "Bridge"] + br2town[1, 2],
    bridge_to_F = zone != "Fallbrook" & via_F <= d[, "Fallbrook"] * 1.05,  #5% longer are included 
    bridge_to_T = zone != "Temecula"  & via_T <= d[, "Temecula"]  * 1.05,  #included to capture error
    uses_bridge = bridge_to_F | bridge_to_T
  )

# 5. The cut-down set
bridge_users <- filter(pw_centroids, uses_bridge)
nrow(bridge_users)
sum(bridge_users$pop)

mapview(pw_centroids, zcol = "uses_bridge") + mapview(bridge_pt, col.regions = "red")
#####################

#how many people does this cover? 
pw_centroids |> st_drop_geometry() |> group_by(uses_bridge) |> summarise(pop = sum(pop), hh = sum(hh))

extra_min <- cbind(
  to_F = ifelse(pw_centroids$zone == "Fallbrook", NA, pw_centroids$via_F - d[, "Fallbrook"]),
  to_T = ifelse(pw_centroids$zone == "Temecula",  NA, pw_centroids$via_T - d[, "Temecula"])
)

pw_centroids$min_extra <- apply(extra_min, 1, min, na.rm = TRUE)

  #~5,700
##edit for testing
#How many people are within X extra minutes of a bridge route?
pw_centroids |>
  st_drop_geometry() |>
  mutate(band = cut(min_extra, c(-Inf, 0, 2, 5, 10, Inf),
                    labels = c("bridge fastest", "<2 min", "2–5", "5–10", ">10"))) |>
  group_by(band) |>
  summarise(n_bg = n(), pop = sum(pop), hh = sum(hh))

mapview(pw_centroids, zcol = "min_extra") + mapview(bridge_pt, col.regions = "red")

#how close are other centroids that are not included
pw_centroids$min_extra <- apply(extra_min, 1, min)
hist(pw_centroids$min_extra, breaks = 50)
table(cut(pw_centroids$min_extra, c(-Inf, 1, 3, 5, 10, Inf)))

#shows lower bound is 7 block groups and upper bound is 7 + 211 that might switch to
#bridge if I-15 is congested

##have a range of time values from 7-211

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

##update 11/11/26
  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  
# --- 1. Table function that returns duration AND distance ---
osrm_retry2 <- function(src, dst, tries = 3) {
  for (k in seq_len(tries)) {
    res <- tryCatch(osrmTable(src = src, dst = dst, measure = c("duration", "distance")),
                    error = function(e) e)
    if (!inherits(res, "error")) return(res)
    message("Attempt ", k, " failed: ", conditionMessage(res)); Sys.sleep(5)
  }
  stop(res)
}

osrm_table2 <- function(src, dst, chunk = 50, pause = 1) {
  si <- split(seq_len(nrow(src)), ceiling(seq_len(nrow(src)) / chunk))
  dj <- split(seq_len(nrow(dst)), ceiling(seq_len(nrow(dst)) / chunk))
  dur <- dist <- matrix(NA_real_, nrow(src), nrow(dst), dimnames = list(NULL, dst$zone))
  for (i in si) for (j in dj) {
    r <- osrm_retry2(src[i, ], dst[j, ])
    dur[i, j]  <- r$durations
    dist[i, j] <- r$distances  # already in km
    Sys.sleep(pause)
  }
  list(dur = dur, dist = dist)
}

# --- 2. Detour waypoint (the closed-bridge alternative) ---
detour_pt <- st_sf(zone = "Detour",
                   geometry = st_sfc(st_point(c(-117.1445, 33.4308)), crs = 4326))  # set from map
targets2 <- rbind(targets, detour_pt)

m   <- osrm_table2(pw_centroids, targets2)                                       # centroid -> F, T, Bridge, Detour
hub <- osrm_table2(targets2[targets2$zone %in% c("Bridge", "Detour"), ], towns)  # Bridge/Detour -> towns
rownames(hub$dur) <- rownames(hub$dist) <- c("Bridge", "Detour")

# --- 3. Open vs closed route for each centroid -> other town ---
base <- pw_centroids |> st_drop_geometry() |> select(bg, zone, pop, hh) |> mutate(i = row_number())

od <- bind_rows(
  base |> filter(zone != "Fallbrook") |> mutate(dest = "Fallbrook"),
  base |> filter(zone != "Temecula")  |> mutate(dest = "Temecula")
) |>
  mutate(
    t_direct = m$dur[cbind(i, match(dest, colnames(m$dur)))],
    d_direct = m$dist[cbind(i, match(dest, colnames(m$dist)))],
    t_bridge = m$dur[i, "Bridge"]  + hub$dur["Bridge", dest],
    d_bridge = m$dist[i, "Bridge"] + hub$dist["Bridge", dest],
    t_wp     = m$dur[i, "Detour"]  + hub$dur["Detour", dest],
    d_wp     = m$dist[i, "Detour"] + hub$dist["Detour", dest],
    bridge_fastest = t_bridge <= t_direct * 1.05,
    # closed network: if the fastest route used the bridge, force the detour;
    # otherwise the direct route already avoids it
    t_closed = if_else(bridge_fastest, t_wp, pmin(t_direct, t_wp)),
    d_closed = if_else(bridge_fastest, d_wp, if_else(t_direct <= t_wp, d_direct, d_wp)),
    dt = t_closed - t_bridge,   # extra minutes per one-way trip
    dd = d_closed - d_bridge,   # extra km per one-way trip
    gap = t_bridge - t_direct   # how far the bridge is from being fastest
  )

# keep each centroid's direction where the bridge is most competitive
thresh <- 10   # minutes; matches your 7 + 211 set, adjust as needed
res <- od |>
  group_by(bg) |> slice_min(gap, n = 1, with_ties = FALSE) |> ungroup() |>
  mutate(group = case_when(bridge_fastest ~ "Low: bridge fastest",
                           gap <= thresh  ~ "Add-on: within 10 min",
                           TRUE           ~ "Not affected"))

# --- 4. Summary for the range ---
summ <- function(x) summarise(x,
                              dt_mean = weighted.mean(dt, hh), dt_min = min(dt), dt_max = max(dt),
                              dd_mean = weighted.mean(dd, hh), dd_min = min(dd), dd_max = max(dd),
                              n_bg = n(), pop_total = sum(pop), hh_total = sum(hh))

bind_rows(
  res |> filter(group == "Low: bridge fastest") |> summ() |> mutate(scenario = "Low (7)"),
  res |> filter(group != "Not affected")        |> summ() |> mutate(scenario = "High (7 + 211)")
)
