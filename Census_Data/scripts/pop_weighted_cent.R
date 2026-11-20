
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

  
# --- 1. Table function that returns time and distance ---
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
                   geometry = st_sfc(st_point(c(-117.1445, 33.4308)), crs = 4326))  # set I-15 point from map
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
  ) |> 
  mutate(
    t_open = t_direct,
    d_open = d_direct,
    t_closed = if_else(bridge_fastest, t_wp, t_direct),  # closing a bridge you don't use changes nothing
    d_closed = if_else(bridge_fastest, d_wp, d_direct),
    dt = t_closed - t_open,
    dd = d_closed - d_open,
    gap = t_bridge - t_direct
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


#alternative method update: simulate bridge closure

library(osmdata); library(dodgr)

# --- 1. Get the road network (download once, then reuse the saved file) ---
road_file <- "osm_roads_bridge_area.rds"

if (file.exists(road_file)) {
  roads_raw <- readRDS(road_file)
} else {
  osmdata::set_overpass_url("https://overpass.kumi.systems/api/interpreter")
  
  # Fallbrook, Temecula, the bridge, De Luz, and I-15
  bb <- c(-117.36, 33.33, -117.10, 33.53)
  
  drive_types <- c("motorway", "motorway_link", "trunk", "trunk_link",
                   "primary", "primary_link", "secondary", "secondary_link",
                   "tertiary", "tertiary_link", "unclassified", "residential",
                   "living_street", "service")
  
  roads_raw <- opq(bb, timeout = 300) |>
    add_osm_feature(key = "highway", value = drive_types) |>
    osmdata_sf()
  
  saveRDS(roads_raw, road_file)
}


# --- 2. Build open and bridge-closed networks ---
BRIDGE_OSM_ID <- "847853579"
stopifnot(BRIDGE_OSM_ID %in% roads$osm_id)   # confirm the bridge is in the download

g_open   <- weight_streetnet(roads, wt_profile = "motorcar",
                             type_col = "highway", id_col = "osm_id")
g_closed <- weight_streetnet(filter(roads, osm_id != BRIDGE_OSM_ID), wt_profile = "motorcar",
                             type_col = "highway", id_col = "osm_id")

# --- 3. Route your 7 bridge-fastest centroids to Fallbrook ---
lo_xy <- st_coordinates(pw_centroids[lo$i, ]); colnames(lo_xy) <- c("x", "y")
fb_xy <- st_coordinates(towns[towns$zone == "Fallbrook", ]); colnames(fb_xy) <- c("x", "y")

route <- function(g) tibble(
  min = as.numeric(dodgr_times(g, from = lo_xy, to = fb_xy, shortest = FALSE)) / 60,
  km  = as.numeric(dodgr_dists(g, from = lo_xy, to = fb_xy, shortest = FALSE)) / 1000
)

# --- 4. Compare with the OSRM results ---
cmp <- bind_cols(lo |> select(bg, hh, osrm_dt = dt, osrm_dd = dd),
                 route(g_open)   |> rename(open_min = min, open_km = km),
                 route(g_closed) |> rename(closed_min = min, closed_km = km)) |>
  mutate(dodgr_dt = closed_min - open_min,
         dodgr_dd = closed_km - open_km)
cmp