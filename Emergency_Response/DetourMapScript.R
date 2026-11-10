# ============================================================================
# SANDIA CREEK BRIDGE EMERGENCY ACCESS STUDY - MASTER SCRIPT
# ============================================================================
# Fresh-session requirement:
#   The object `Incidents_2014_2018_flood_xy` must already be loaded in R.
#   This script creates the remaining inputs, spatial objects, networks,
#   travel-time/distance tables, detour geometry, maps, and output files.
#
# Main scenarios:
#   1. NCFPD Station 1 - normal access (bridge open)
#   2. NCFPD Station 1 - specified flooded detour via De Luz, Camaron,
#      Sandia Creek Drive, ending at the Rock Mountain Road approach
#   3. Temecula Civic Center - bridge closure network
#
# Important assumptions:
#   - 2010 Census blocks/tracts are used.
#   - The yellow study boundary is a manually digitized approximation of the
#     user's map annotation. Inspect the selection-check map on each fresh run.
#   - Bridge OSM way 847853579 is the current Sandia Creek Drive bridge to close.
#   - Two blocks without mapped roads are routed to previously reviewed nearest
#     road-access points: Corte Carrera and Avenida Tierra.
#   - `dodgr` motorcar times are modeled estimates, not measured EMS response
#     times or emergency-vehicle travel times.
# ============================================================================

# ---------------------------------------------------------------------------
# 0. USER SETTINGS
# ---------------------------------------------------------------------------

# Output folder (created if absent)
OUTPUT_DIR <- "Sandia_Creek_Master_Outputs"

# Reuse successful OSM downloads on later runs. The first run still needs
# internet access to retrieve the road and (optionally) river features.
USE_CACHED_OSM <- TRUE

# Current Sandia Creek Drive bridge OSM way ID, verified during prior review
BRIDGE_OSM_ID <- "847853579"

# 2010 Census counties: San Diego (073) and Riverside (065)
COUNTY_FIPS <- c("073", "065")

# Map extent, longitude/latitude (EPSG:4326).
# Slightly wider east-west than the earlier 117.35 to 117.15 request so the
# eastern edge of the hand-drawn yellow boundary is not clipped.
MAP_EXTENT_WGS84 <- c(
  xmin = -117.36,
  ymin = 33.35,
  xmax = -117.14,
  ymax = 33.60
)

# OSM road-network query padding in decimal degrees. The query extent is
# calculated from the station, waypoints, block destinations, plus this margin.
OSM_BBOX_PADDING_DEG <- 0.025

# Maximum distance at which an input point may be snapped to a road without
# being flagged for inspection. This is a QA threshold, not a routing setting.
SNAP_REVIEW_THRESHOLD_M <- 500

# Expected selected-block count from the previous iteration. The script warns
# if the count differs; the approximate hand-digitized boundary may need review.
EXPECTED_YELLOW_BLOCK_COUNT <- 111L

# Use the reviewed nearest-road coordinates for the two blocks with no road
# inside the Census block polygon. Do not change unless these locations are
# re-reviewed against the road network.
USE_REVIEWED_ROAD_ACCESS_OVERRIDES <- TRUE

# ---------------------------------------------------------------------------
# 1. PACKAGES AND SESSION SETUP
# ---------------------------------------------------------------------------

required_packages <- c(
  "tidyverse",
  "sf",
  "tigris",
  "osmdata",
  "dodgr",
  "tidygeocoder",
  "scales",
  "units"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(tigris)
})

# Avoid the invalid NA-print option encountered in earlier sessions.
options(na.print = "NA")
options(tigris_use_cache = TRUE)

# We perform geometric operations in projected UTM coordinates.
sf::sf_use_s2(FALSE)

if (!exists("Incidents_2014_2018_flood_xy", envir = .GlobalEnv)) {
  stop(
    "Load Incidents_2014_2018_flood_xy into the R environment before running this script."
  )
}

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

message("Packages and session settings ready.")

# ---------------------------------------------------------------------------
# 2. DEFINE THE SEVEN RESPONSE-ORIGIN CANDIDATES
# ---------------------------------------------------------------------------

# Coordinates are from the previously assembled all_sites.csv.
# NCFPD station-code matches remain provisional; the Riverside headquarters
# and Temecula Civic Center are candidate locations, not verified apparatus
# dispatch origins.
all_sites <- tibble::tribble(
  ~source,           ~fdid,  ~dept_sta, ~station_no, ~origin_name,                                ~origin_address,                                          ~origin_status,                                             ~origin_lat,       ~origin_lon,
  "NCFPD",           "37075", "01",     1L,         "NCFPD Station 1",                          "315 East Ivy Street, Fallbrook, CA 92028",             "provisional_station_code_match",                          33.383623526508,   -117.249065928903,
  "NCFPD",           "37075", "02",     2L,         "NCFPD Station 2",                          "2180 Winterwarm Drive, Fallbrook, CA 92028",           "provisional_station_code_match",                          33.344648222960,   -117.213205335574,
  "NCFPD",           "37075", "03",     3L,         "NCFPD Station 3",                          "2309 Rainbow Valley Boulevard, Rainbow, CA 92028",    "provisional_station_code_match",                          33.414092821734,   -117.147593865797,
  "NCFPD",           "37075", "04",     4L,         "NCFPD Station 4",                          "4375 Pala Mesa Drive, Fallbrook, CA 92028",            "provisional_station_code_match",                          33.340429262611,   -117.160148449819,
  "NCFPD",           "37075", "05",     5L,         "NCFPD Station 5",                          "5906 Olive Hill Road, Bonsall, CA 92003",              "provisional_station_code_match",                          33.289603983341,   -117.229242851451,
  # The Riverside Unit headquarters is FDID 00013 in the OSFM directory;
  # FDID 33115 is retained for Temecula Fire Department below.
  "Riverside",       "00013", "RRU",   NA_integer_, "CAL FIRE Riverside Unit Headquarters",      "210 W San Jacinto Ave, Perris, CA 92570",              "headquarters_not_verified_apparatus_origin",             33.786648569891,   -117.229874161015,
  "also_riverside",  "33115", NA,       NA_integer_, "Temecula Civic Center",                     "41000 Main St, Temecula, CA 92590",                     "registered_department_address_not_verified_apparatus_origin", 33.494679659370, -117.147397649077
) %>%
  mutate(
    site_label = case_when(
      !is.na(station_no) ~ paste0("NCFPD ", station_no),
      source == "Riverside" ~ "CAL FIRE RRU HQ",
      TRUE ~ "Temecula Civic Center"
    )
  )

# ---------------------------------------------------------------------------
# 3. CREATE THE YELLOW STUDY-AREA POLYGON
# ---------------------------------------------------------------------------

# This ring is the approximate coordinate trace digitized from the yellow
# outline in the user's map screenshot. It is deliberately kept in one block
# near the top of the script so it can be edited if the user supplies a more
# exact GIS boundary.
yellow_ring <- matrix(c(
  -117.197543, 33.493640,
  -117.204171, 33.496474,
  -117.213210, 33.491121,
  -117.218934, 33.484824,
  -117.221344, 33.473804,
  -117.227068, 33.465617,
  -117.234299, 33.460264,
  -117.240927, 33.453652,
  -117.247254, 33.447355,
  -117.254786, 33.442632,
  -117.258100, 33.434446,
  -117.258100, 33.425315,
  -117.256292, 33.415554,
  -117.249664, 33.402330,
  -117.241228, 33.399496,
  -117.232190, 33.392884,
  -117.224959, 33.388161,
  -117.215620, 33.386902,
  -117.207486, 33.396033,
  -117.201761, 33.403904,
  -117.202364, 33.413350,
  -117.201159, 33.423111,
  -117.197242, 33.432557,
  -117.188806, 33.443577,
  -117.179768, 33.451448,
  -117.170127, 33.457431,
  -117.159282, 33.463728,
  -117.150243, 33.468136,
  -117.145122, 33.473804,
  -117.147231, 33.482305,
  -117.153256, 33.488287,
  -117.161692, 33.492695,
  -117.172236, 33.496474,
  -117.182178, 33.496474,
  -117.190012, 33.494270,
  -117.197543, 33.493640
), ncol = 2, byrow = TRUE)

yellow_area <- st_sf(
  region = "Yellow outlined study area",
  geometry = st_sfc(
    st_polygon(list(yellow_ring)),
    crs = 4326
  )
) %>%
  st_transform(26911) %>%
  st_make_valid()

# Map rectangle converted to UTM to ensure the Cartesian limits correspond
# exactly to the stated longitude/latitude extent.
map_bbox_wgs84 <- st_bbox(
  c(
    xmin = unname(MAP_EXTENT_WGS84["xmin"]),
    ymin = unname(MAP_EXTENT_WGS84["ymin"]),
    xmax = unname(MAP_EXTENT_WGS84["xmax"]),
    ymax = unname(MAP_EXTENT_WGS84["ymax"])
  ),
  crs = st_crs(4326)
)

map_extent_polygon_utm <- st_transform(
  st_as_sfc(map_bbox_wgs84),
  26911
)

map_bbox_utm <- st_bbox(map_extent_polygon_utm)
map_xlim_utm <- c(unname(map_bbox_utm["xmin"]), unname(map_bbox_utm["xmax"]))
map_ylim_utm <- c(unname(map_bbox_utm["ymin"]), unname(map_bbox_utm["ymax"]))

# ---------------------------------------------------------------------------
# 4. PREPARE INCIDENT POINTS FROM THE PRELOADED OBJECT
# ---------------------------------------------------------------------------

incidents_input <- as_tibble(Incidents_2014_2018_flood_xy) %>%
  mutate(
    longitude = suppressWarnings(as.numeric(.data$longitude)),
    latitude = suppressWarnings(as.numeric(.data$latitude))
  )

required_incident_columns <- c("longitude", "latitude")
missing_incident_columns <- setdiff(
  required_incident_columns,
  names(incidents_input)
)

if (length(missing_incident_columns) > 0) {
  stop(
    paste(
      "Incidents_2014_2018_flood_xy is missing required coordinate columns:",
      paste(missing_incident_columns, collapse = ", ")
    )
  )
}

incidents_with_coordinates <- incidents_input %>%
  filter(
    is.finite(longitude),
    is.finite(latitude),
    between(longitude, -180, 180),
    between(latitude, -90, 90)
  )

incident_points_wgs84 <- st_as_sf(
  incidents_with_coordinates,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
)

incident_points_utm <- st_transform(
  incident_points_wgs84,
  26911
)

message(
  "Incident records loaded: ", nrow(incident_points_wgs84),
  " (", nrow(Incidents_2014_2018_flood_xy) - nrow(incident_points_wgs84),
  " omitted for missing/invalid coordinates)."
)

# ---------------------------------------------------------------------------
# 5. DOWNLOAD AND REPAIR 2010 CENSUS BLOCKS AND TRACTS
# ---------------------------------------------------------------------------

message("Downloading 2010 Census blocks and tracts for San Diego and Riverside counties...")

blocks_by_county <- purrr::map(
  COUNTY_FIPS,
  ~ tigris::blocks(
    state = "06",
    county = .x,
    year = 2010,
    class = "sf"
  )
)

tracts_by_county <- purrr::map(
  COUNTY_FIPS,
  ~ tigris::tracts(
    state = "06",
    county = .x,
    year = 2010,
    class = "sf"
  )
)

blocks_2010 <- do.call(rbind, blocks_by_county)
tracts_2010 <- do.call(rbind, tracts_by_county)

if (!"GEOID10" %in% names(blocks_2010)) {
  stop("The downloaded 2010 Census block data do not contain GEOID10.")
}
if (!"GEOID10" %in% names(tracts_2010)) {
  stop("The downloaded 2010 Census tract data do not contain GEOID10.")
}

# Repair TIGER block geometries in a projected coordinate system.
blocks_2010_utm <- blocks_2010 %>%
  st_transform(26911) %>%
  st_make_valid()

# A repair can create GEOMETRYCOLLECTION; retain polygonal components.
if (any(as.character(st_geometry_type(blocks_2010_utm)) == "GEOMETRYCOLLECTION")) {
  blocks_2010_utm <- st_collection_extract(
    blocks_2010_utm,
    "POLYGON",
    warn = FALSE
  )
}

blocks_2010_utm <- blocks_2010_utm %>%
  mutate(
    block_geoid_tiger = as.character(GEOID10),
    tract_geoid_tiger = substr(block_geoid_tiger, 1, 11)
  ) %>%
  filter(!st_is_empty(geometry))

tracts_2010_utm <- tracts_2010 %>%
  st_transform(26911) %>%
  st_make_valid() %>%
  mutate(
    tract_geoid_tiger = as.character(GEOID10)
  ) %>%
  filter(!st_is_empty(geometry))

# Crop the Census layers to the map's UTM extent.
blocks_in_extent_valid <- st_crop(
  blocks_2010_utm,
  map_bbox_utm
)

tracts_in_extent <- st_crop(
  tracts_2010_utm,
  map_bbox_utm
)

# ---------------------------------------------------------------------------
# 6. SELECT CENSUS BLOCKS INSIDE THE YELLOW BOUNDARY
# ---------------------------------------------------------------------------

# A point on the surface (rather than a centroid) is used to decide whether
# each block falls inside the hand-digitized yellow boundary.
block_rep_points_utm <- st_point_on_surface(blocks_in_extent_valid)
inside_yellow <- lengths(
  st_within(block_rep_points_utm, yellow_area)
) > 0

yellow_blocks <- blocks_in_extent_valid[inside_yellow, ]

yellow_block_points_utm <- block_rep_points_utm[inside_yellow, ]
yellow_block_points_wgs84 <- st_transform(
  yellow_block_points_utm,
  4326
)

yellow_block_coords <- st_coordinates(yellow_block_points_wgs84)

yellow_block_lookup <- yellow_block_points_wgs84 %>%
  st_drop_geometry() %>%
  transmute(
    block_geoid_tiger = as.character(block_geoid_tiger),
    tract_geoid_tiger = as.character(tract_geoid_tiger),
    block_point_lon = yellow_block_coords[, 1],
    block_point_lat = yellow_block_coords[, 2]
  ) %>%
  distinct(block_geoid_tiger, .keep_all = TRUE)

if (nrow(yellow_block_lookup) != EXPECTED_YELLOW_BLOCK_COUNT) {
  warning(
    "The current yellow polygon selected ", nrow(yellow_block_lookup),
    " Census blocks; the previous iteration selected ",
    EXPECTED_YELLOW_BLOCK_COUNT,
    ". Inspect the saved Yellow_Boundary_Block_Selection_Check.png before proceeding."
  )
}

message("Census blocks selected inside yellow boundary: ", nrow(yellow_block_lookup))

# ---------------------------------------------------------------------------
# 7. ASSIGN HISTORICAL INCIDENTS TO THE SELECTED CENSUS BLOCKS
# ---------------------------------------------------------------------------

incidents_in_yellow_blocks <- st_join(
  incident_points_utm,
  yellow_blocks %>%
    select(block_geoid_tiger, tract_geoid_tiger),
  join = st_within,
  left = FALSE
)

incident_counts_by_block <- incidents_in_yellow_blocks %>%
  st_drop_geometry() %>%
  count(
    block_geoid_tiger,
    name = "historical_incident_count"
  )

yellow_block_lookup <- yellow_block_lookup %>%
  left_join(
    incident_counts_by_block,
    by = "block_geoid_tiger"
  ) %>%
  mutate(
    historical_incident_count = tidyr::replace_na(
      historical_incident_count,
      0L
    )
  )

# Map points are only incidents assigned to the selected yellow-zone blocks.
incidents_yellow_map <- incidents_in_yellow_blocks %>%
  st_transform(26911)

# Save a selection-check map early, so the digitized boundary can be reviewed.
yellow_selection_check_map <- ggplot() +
  geom_sf(
    data = blocks_in_extent_valid,
    fill = "grey96",
    color = "grey75",
    linewidth = 0.15
  ) +
  geom_sf(
    data = yellow_blocks,
    fill = "gold",
    color = "black",
    linewidth = 0.25
  ) +
  geom_sf(
    data = yellow_area,
    fill = NA,
    color = "red",
    linewidth = 0.9
  ) +
  geom_sf(
    data = incidents_yellow_map,
    color = "firebrick",
    size = 0.35,
    alpha = 0.5
  ) +
  coord_sf(
    crs = st_crs(26911),
    default_crs = st_crs(26911),
    xlim = map_xlim_utm,
    ylim = map_ylim_utm,
    expand = FALSE
  ) +
  labs(
    title = "Yellow Study Boundary - Selected 2010 Census Blocks",
    subtitle = paste0(
      nrow(yellow_block_lookup),
      " selected blocks; red points are geocoded incidents assigned to them"
    ),
    x = "Easting (meters)",
    y = "Northing (meters)"
  ) +
  theme_bw()

ggsave(
  file.path(OUTPUT_DIR, "Yellow_Boundary_Block_Selection_Check.png"),
  yellow_selection_check_map,
  width = 11,
  height = 9,
  dpi = 300
)

# ---------------------------------------------------------------------------
# 8. APPLY THE TWO REVIEWED ROAD-ACCESS DESTINATION OVERRIDES
# ---------------------------------------------------------------------------

# These coordinates and distances were established during the earlier road
# snapping review. The original block point remains in the lookup for reference.
road_access_overrides <- tibble::tribble(
  ~block_geoid_tiger, ~routing_lon,   ~routing_lat,  ~nearest_road_name, ~nearest_road_highway, ~distance_to_road_m,
  "060650432541022", -117.1910833,   33.4571827,   "Corte Carrera",   "unclassified",        676.0125,
  "060650432541048", -117.2027959,   33.4518578,   "Avenida Tierra",  "residential",         826.2308
)

if (!USE_REVIEWED_ROAD_ACCESS_OVERRIDES) {
  road_access_overrides <- road_access_overrides[0, ]
}

missing_override_blocks <- setdiff(
  road_access_overrides$block_geoid_tiger,
  yellow_block_lookup$block_geoid_tiger
)

if (length(missing_override_blocks) > 0) {
  warning(
    "One or more saved road-access override GEOIDs are not in the current yellow-zone selection: ",
    paste(missing_override_blocks, collapse = ", ")
  )
}

yellow_block_lookup_routing <- yellow_block_lookup %>%
  mutate(
    routing_lon = block_point_lon,
    routing_lat = block_point_lat,
    destination_method = "Original Census block point on surface",
    nearest_road_name = NA_character_,
    nearest_road_highway = NA_character_,
    distance_to_road_m = NA_real_
  ) %>%
  left_join(
    road_access_overrides,
    by = "block_geoid_tiger",
    suffix = c("", "_override")
  ) %>%
  mutate(
    routing_lon = coalesce(routing_lon_override, routing_lon),
    routing_lat = coalesce(routing_lat_override, routing_lat),
    nearest_road_name = coalesce(nearest_road_name_override, nearest_road_name),
    nearest_road_highway = coalesce(nearest_road_highway_override, nearest_road_highway),
    distance_to_road_m = coalesce(distance_to_road_m_override, distance_to_road_m),
    destination_method = if_else(
      !is.na(routing_lon_override),
      "Nearest mapped road-access point (reviewed override)",
      destination_method
    )
  ) %>%
  select(
    block_geoid_tiger,
    tract_geoid_tiger,
    block_point_lon,
    block_point_lat,
    routing_lon,
    routing_lat,
    destination_method,
    nearest_road_name,
    nearest_road_highway,
    distance_to_road_m,
    historical_incident_count
  )

# Verify the two adjusted blocks still have zero assigned historical incidents.
adjusted_block_review <- yellow_block_lookup_routing %>%
  filter(destination_method != "Original Census block point on surface") %>%
  select(
    block_geoid_tiger,
    nearest_road_name,
    distance_to_road_m,
    historical_incident_count,
    block_point_lon,
    block_point_lat,
    routing_lon,
    routing_lat
  )

utils::write.csv(
  as.data.frame(adjusted_block_review),
  file.path(OUTPUT_DIR, "Adjusted_Census_Block_Destinations.csv"),
  row.names = FALSE,
  na = ""
)

# ---------------------------------------------------------------------------
# 9. GEOCODE THE FLOODED-DETOUR WAYPOINTS
# ---------------------------------------------------------------------------

# Ordered route stops supplied by the user / Google Maps reference.
detour_waypoint_addresses <- tibble(
  stop_order = 1:3,
  stop_name = c(
    "De Luz Road",
    "Camaron Road",
    "Sandia Creek Drive / Rock Mountain entry"
  ),
  address = c(
    "39444 De Luz Rd, Fallbrook, CA 92028",
    "45050 Camaron Rd, Temecula, CA 92590",
    "40273 Sandia Creek Dr, Fallbrook, CA 92028"
  )
)

message("Geocoding the three flooded-detour waypoints using ArcGIS...")

detour_waypoints_geocoded <- tidygeocoder::geocode(
  detour_waypoint_addresses,
  address = address,
  method = "arcgis",
  lat = "latitude",
  long = "longitude"
)

detour_waypoints_geocoded <- detour_waypoints_geocoded %>%
  arrange(stop_order) %>%
  mutate(
    longitude = as.numeric(longitude),
    latitude = as.numeric(latitude)
  )

if (
  nrow(detour_waypoints_geocoded) != 3 ||
  any(!is.finite(detour_waypoints_geocoded$longitude)) ||
  any(!is.finite(detour_waypoints_geocoded$latitude))
) {
  stop("One or more De Luz detour waypoints failed to geocode.")
}

utils::write.csv(
  as.data.frame(detour_waypoints_geocoded),
  file.path(OUTPUT_DIR, "Flooded_Detour_Waypoint_Geocoding.csv"),
  row.names = FALSE,
  na = ""
)

# ---------------------------------------------------------------------------
# 10. DOWNLOAD OPENSTREETMAP ROADS (WITH OVERPASS FALLBACKS)
# ---------------------------------------------------------------------------

# Build a road-network query extent around all origins, detour waypoints,
# block destinations, and adjusted road-access destinations.
ncfpd1_origin_row <- all_sites %>%
  filter(source == "NCFPD", station_no == 1)

temecula_origin_row <- all_sites %>%
  filter(origin_name == "Temecula Civic Center")

route_input_coords <- bind_rows(
  ncfpd1_origin_row %>% transmute(lon = origin_lon, lat = origin_lat),
  temecula_origin_row %>% transmute(lon = origin_lon, lat = origin_lat),
  detour_waypoints_geocoded %>% transmute(lon = longitude, lat = latitude),
  yellow_block_lookup_routing %>% transmute(lon = routing_lon, lat = routing_lat)
) %>%
  filter(is.finite(lon), is.finite(lat))

road_bbox <- c(
  min(route_input_coords$lon) - OSM_BBOX_PADDING_DEG,
  min(route_input_coords$lat) - OSM_BBOX_PADDING_DEG,
  max(route_input_coords$lon) + OSM_BBOX_PADDING_DEG,
  max(route_input_coords$lat) + OSM_BBOX_PADDING_DEG
)

# Try several public Overpass instances, since one instance may time out.
fetch_osm_lines_with_fallback <- function(key, value, bbox, label) {
  
  overpass_urls <- tryCatch(
    osmdata::list_overpass_urls(),
    error = function(e) character()
  )
  
  fallback_urls <- c(
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.nchc.org.tw/api/interpreter"
  )
  
  overpass_urls <- unique(c(overpass_urls, fallback_urls))
  overpass_urls <- overpass_urls[nzchar(overpass_urls)]
  
  last_error <- NULL
  
  for (api_url in overpass_urls) {
    
    message("Requesting ", label, " from ", api_url)
    
    result <- tryCatch({
      osmdata::set_overpass_url(api_url)
      
      query <- osmdata::opq(
        bbox = bbox,
        osm_types = "way",
        timeout = 180
      )
      
      # For a key-only query (for example, all highway ways), omit the value
      # argument rather than passing value = NULL.
      if (is.null(value)) {
        query <- osmdata::add_osm_feature(
          query,
          key = key
        )
      } else {
        query <- osmdata::add_osm_feature(
          query,
          key = key,
          value = value
        )
      }
      
      osmdata::osmdata_sf(query, quiet = FALSE)
      
    }, error = function(e) {
      last_error <<- conditionMessage(e)
      message("  Query failed: ", conditionMessage(e))
      NULL
    })
    
    if (!is.null(result) && !is.null(result$osm_lines) && nrow(result$osm_lines) > 0) {
      message("  Retrieved ", nrow(result$osm_lines), " line features.")
      return(result)
    }
  }
  
  stop(
    "Unable to retrieve ", label, " from the available Overpass instances. Last error: ",
    ifelse(is.null(last_error), "No line features returned", last_error)
  )
}

osm_roads_cache_file <- file.path(OUTPUT_DIR, "OSM_Roads_Cache.rds")
osm_roads <- NULL
use_road_cache <- FALSE

if (USE_CACHED_OSM && file.exists(osm_roads_cache_file)) {
  cached_roads <- tryCatch(readRDS(osm_roads_cache_file), error = function(e) NULL)
  if (is.list(cached_roads) &&
      !is.null(cached_roads$bbox) &&
      !is.null(cached_roads$osm_roads) &&
      isTRUE(all.equal(as.numeric(cached_roads$bbox), as.numeric(road_bbox), tolerance = 1e-8))) {
    osm_roads <- cached_roads$osm_roads
    use_road_cache <- TRUE
    message("Loading cached OSM road network: ", osm_roads_cache_file)
  } else {
    message("Existing OSM road cache does not match the current query extent; a new download will be requested.")
  }
}

if (!use_road_cache) {
  message("Downloading OSM road network. This request may take a few minutes...")
  osm_roads_raw <- fetch_osm_lines_with_fallback(
    key = "highway",
    value = NULL,
    bbox = road_bbox,
    label = "OSM roads"
  )
  
  osm_roads <- osm_roads_raw$osm_lines
  
  if (USE_CACHED_OSM && !is.null(osm_roads) && nrow(osm_roads) > 0) {
    saveRDS(
      list(bbox = as.numeric(road_bbox), osm_roads = osm_roads),
      osm_roads_cache_file
    )
    message("Saved OSM road cache: ", osm_roads_cache_file)
  }
}

if (is.null(osm_roads) || nrow(osm_roads) == 0) {
  stop("The OSM road query returned no line features.")
}

# Make sure road geometries have usable line features and identifiers.
osm_roads <- osm_roads %>%
  st_zm(drop = TRUE, what = "ZM") %>%
  filter(!st_is_empty(geometry)) %>%
  mutate(osm_id = as.character(osm_id))

if (!"highway" %in% names(osm_roads)) {
  stop("The downloaded OSM line data do not contain a highway classification.")
}

if (!"name" %in% names(osm_roads)) {
  osm_roads$name <- NA_character_
}

# Verify that the current bridge OSM way is in the downloaded network.
bridge_feature_check <- osm_roads %>%
  filter(osm_id == BRIDGE_OSM_ID)

if (nrow(bridge_feature_check) == 0) {
  stop(
    "Bridge OSM ID ", BRIDGE_OSM_ID,
    " was not returned in the current OSM download. Check the ID and query extent before proceeding."
  )
}

# ---------------------------------------------------------------------------
# 11. CLEAN OSM MAXSPEED VALUES AND BUILD OPEN/CLOSED NETWORKS
# ---------------------------------------------------------------------------

clean_osm_maxspeed <- function(x) {
  
  if (!"maxspeed" %in% names(x)) {
    x$maxspeed <- NA_character_
    return(x)
  }
  
  raw_speed <- trimws(as.character(x$maxspeed))
  numeric_speed <- suppressWarnings(readr::parse_number(raw_speed))
  
  mph_rows <- !is.na(raw_speed) &
    stringr::str_detect(stringr::str_to_lower(raw_speed), "mph")
  
  numeric_speed[mph_rows] <- numeric_speed[mph_rows] * 1.609344
  
  valid_speed <- is.finite(numeric_speed) & numeric_speed > 0
  
  x$maxspeed <- ifelse(
    valid_speed,
    as.character(numeric_speed),
    NA_character_
  )
  
  x
}

roads_open_clean <- clean_osm_maxspeed(osm_roads)

# The closed network excludes only the current bridge way, not all of
# Sandia Creek Drive.
roads_closed_clean <- roads_open_clean %>%
  filter(osm_id != BRIDGE_OSM_ID)

if (nrow(roads_open_clean) - nrow(roads_closed_clean) != nrow(bridge_feature_check)) {
  stop("Unexpected number of OSM features removed for the bridge closure.")
}

# Audit unsupported road classifications. dodgr excludes types not present in
# its motorcar weighting profile. The summary is saved for documentation.
profile_df <- dodgr::weighting_profiles$weighting_profiles %>%
  filter(name == "motorcar")

motorcar_types <- as.character(profile_df$way)

unsupported_roads <- roads_open_clean %>%
  mutate(
    highway_label = if_else(
      is.na(highway),
      "<missing>",
      as.character(highway)
    )
  ) %>%
  filter(is.na(highway) | !as.character(highway) %in% motorcar_types)

unsupported_summary <- unsupported_roads %>%
  st_drop_geometry() %>%
  count(highway_label, name = "road_segments", sort = TRUE)

utils::write.csv(
  as.data.frame(unsupported_summary),
  file.path(OUTPUT_DIR, "Unsupported_OSM_Highway_Types.csv"),
  row.names = FALSE,
  na = ""
)

unsupported_in_yellow <- unsupported_roads %>%
  st_transform(st_crs(yellow_area)) %>%
  st_filter(yellow_area, .predicate = st_intersects)

message(
  "Unsupported OSM road features intersecting yellow boundary: ",
  nrow(unsupported_in_yellow),
  ". These are excluded by the motorcar weighting profile; inspect the saved audit if this count changes."
)

# Audit explicit access-restriction tags. Important: weight_streetnet() on
# sf-format osmdata_sf() roads does not fully enforce all access restrictions.
# We retain these tags for review rather than silently treating private or
# restricted roads as universally public. Emergency-service access rights may
# differ from ordinary motorcar access and should be checked locally.
access_tag_columns <- intersect(
  c("access", "vehicle", "motor_vehicle", "access:conditional"),
  names(roads_open_clean)
)

if (length(access_tag_columns) > 0) {
  restricted_access_values <- c(
    "no", "private", "customers", "destination", "permit",
    "agricultural", "forestry"
  )
  
  access_tag_audit <- roads_open_clean %>%
    mutate(
      across(
        all_of(access_tag_columns),
        ~ stringr::str_to_lower(trimws(as.character(.x)))
      )
    ) %>%
    filter(
      if_any(
        all_of(access_tag_columns),
        ~ !is.na(.x) & .x %in% restricted_access_values
      )
    )
} else {
  access_tag_audit <- roads_open_clean[0, ]
}

access_tag_audit_yellow <- access_tag_audit %>%
  st_transform(st_crs(yellow_area)) %>%
  st_filter(yellow_area, .predicate = st_intersects)

utils::write.csv(
  as.data.frame(access_tag_audit %>% st_drop_geometry()),
  file.path(OUTPUT_DIR, "OSM_Access_Restriction_Audit_All_Roads.csv"),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  as.data.frame(access_tag_audit_yellow %>% st_drop_geometry()),
  file.path(OUTPUT_DIR, "OSM_Access_Restriction_Audit_Yellow_Area.csv"),
  row.names = FALSE,
  na = ""
)

message(
  "OSM road features carrying explicit access-restriction tags inside yellow area: ",
  nrow(access_tag_audit_yellow),
  ". Review OSM_Access_Restriction_Audit_Yellow_Area.csv; SF-format motorcar routing does not automatically enforce all such restrictions."
)

# The earlier unsupported feature on the yellow boundary is not manually
# reclassified. It remains excluded by its unsupported highway classification.
keep_road_cols <- intersect(
  c("name", "bridge", "layer", "maxspeed", "surface", "access",
    "vehicle", "motor_vehicle", "access:conditional", "oneway"),
  names(roads_open_clean)
)

message("Weighting open and bridge-closure road networks using the dodgr motorcar profile...")

graph_open_raw <- dodgr::weight_streetnet(
  roads_open_clean,
  wt_profile = "motorcar",
  type_col = "highway",
  id_col = "osm_id",
  keep_cols = keep_road_cols
)

graph_closed_raw <- dodgr::weight_streetnet(
  roads_closed_clean,
  wt_profile = "motorcar",
  type_col = "highway",
  id_col = "osm_id",
  keep_cols = keep_road_cols
)

# ---------------------------------------------------------------------------
# 12. CREATE ROUTING COORDINATE MATRICES AND ADD NODES TO BOTH GRAPHS
# ---------------------------------------------------------------------------

make_xy_matrix <- function(lon, lat, id) {
  out <- matrix(
    c(as.numeric(lon), as.numeric(lat)),
    nrow = 1,
    dimnames = list(id, c("x", "y"))
  )
  storage.mode(out) <- "double"
  out
}

ncfpd1_xy <- make_xy_matrix(
  ncfpd1_origin_row$origin_lon,
  ncfpd1_origin_row$origin_lat,
  "NCFPD_Station_1"
)

temecula_xy <- make_xy_matrix(
  temecula_origin_row$origin_lon,
  temecula_origin_row$origin_lat,
  "Temecula_Civic_Center"
)

de_luz_xy <- make_xy_matrix(
  detour_waypoints_geocoded$longitude[1],
  detour_waypoints_geocoded$latitude[1],
  "DE_LUZ"
)

camaron_xy <- make_xy_matrix(
  detour_waypoints_geocoded$longitude[2],
  detour_waypoints_geocoded$latitude[2],
  "CAMARON"
)

rock_mountain_xy <- make_xy_matrix(
  detour_waypoints_geocoded$longitude[3],
  detour_waypoints_geocoded$latitude[3],
  "ROCK_MOUNTAIN_ENTRY"
)

block_xy <- as.matrix(
  yellow_block_lookup_routing %>%
    select(routing_lon, routing_lat)
)

colnames(block_xy) <- c("x", "y")
rownames(block_xy) <- paste0(
  "BLOCK_",
  yellow_block_lookup_routing$block_geoid_tiger
)
storage.mode(block_xy) <- "double"

route_nodes_xy <- rbind(
  ncfpd1_xy,
  temecula_xy,
  de_luz_xy,
  camaron_xy,
  rock_mountain_xy,
  block_xy
)

# Check nearest-edge distances before inserting points.
snap_open <- dodgr::match_points_to_graph(
  graph_open_raw,
  xy = route_nodes_xy,
  distances = TRUE
)

snap_closed <- dodgr::match_points_to_graph(
  graph_closed_raw,
  xy = route_nodes_xy,
  distances = TRUE
)

snap_check <- tibble(
  point_id = rownames(route_nodes_xy),
  normal_snap_m = abs(snap_open$d_signed),
  closure_snap_m = abs(snap_closed$d_signed)
)

snap_review <- snap_check %>%
  filter(
    normal_snap_m > SNAP_REVIEW_THRESHOLD_M |
      closure_snap_m > SNAP_REVIEW_THRESHOLD_M
  )

utils::write.csv(
  as.data.frame(snap_check),
  file.path(OUTPUT_DIR, "Routing_Point_Snap_Check.csv"),
  row.names = FALSE,
  na = ""
)

if (nrow(snap_review) > 0) {
  warning(
    nrow(snap_review),
    " routing point(s) exceed the ", SNAP_REVIEW_THRESHOLD_M,
    " m snapping review threshold. Inspect Routing_Point_Snap_Check.csv."
  )
}

# Add nodes to the graph. For the two adjusted block destinations, the input
# coordinates already represent reviewed road-access points, not the original
# interior block points.
graph_open <- dodgr::add_nodes_to_graph(
  graph_open_raw,
  xy = route_nodes_xy
)

graph_closed <- dodgr::add_nodes_to_graph(
  graph_closed_raw,
  xy = route_nodes_xy
)

# Resolve input locations to the graph's explicit vertex IDs. This avoids
# relying on matrix column order when matching results to Census GEOIDs.
get_graph_vertex_ids <- function(graph, xy) {
  verts <- dodgr::dodgr_vertices(graph)
  idx <- dodgr::match_points_to_verts(verts, xy)
  if (anyNA(idx) || any(idx < 1) || any(idx > nrow(verts))) {
    stop("Could not match one or more input coordinates to graph vertices.")
  }
  verts$id[idx]
}

open_vertex_ids <- get_graph_vertex_ids(graph_open, route_nodes_xy)
closed_vertex_ids <- get_graph_vertex_ids(graph_closed, route_nodes_xy)
names(open_vertex_ids) <- rownames(route_nodes_xy)
names(closed_vertex_ids) <- rownames(route_nodes_xy)

# Named vertex IDs for origins, waypoints, and block destinations.
open_ncfpd1_id <- unname(open_vertex_ids["NCFPD_Station_1"])
open_temecula_id <- unname(open_vertex_ids["Temecula_Civic_Center"])

closed_ncfpd1_id <- unname(closed_vertex_ids["NCFPD_Station_1"])
closed_de_luz_id <- unname(closed_vertex_ids["DE_LUZ"])
closed_camaron_id <- unname(closed_vertex_ids["CAMARON"])
closed_rock_id <- unname(closed_vertex_ids["ROCK_MOUNTAIN_ENTRY"])
closed_temecula_id <- unname(closed_vertex_ids["Temecula_Civic_Center"])

block_vertex_ids_open <- unname(
  open_vertex_ids[paste0("BLOCK_", yellow_block_lookup_routing$block_geoid_tiger)]
)

block_vertex_ids_closed <- unname(
  closed_vertex_ids[paste0("BLOCK_", yellow_block_lookup_routing$block_geoid_tiger)]
)

if (
  length(block_vertex_ids_open) != nrow(yellow_block_lookup_routing) ||
  anyNA(block_vertex_ids_open) ||
  length(block_vertex_ids_closed) != nrow(yellow_block_lookup_routing) ||
  anyNA(block_vertex_ids_closed)
) {
  stop("One or more Census block destinations were not matched to graph vertices.")
}

# ---------------------------------------------------------------------------
# 13. ROUTING FUNCTIONS: TRAVEL TIME AND DISTANCE MATCHED BY BLOCK ID
# ---------------------------------------------------------------------------

# dodgr street-network times are seconds; distances are meters. When
# shortest = FALSE, dodgr_dists reports distance along the fastest route.
# See the package documentation cited in the accompanying explanation.
calculate_routes_by_vertex_id <- function(
    graph,
    from_id,
    to_ids,
    block_geoids
) {
  
  time_matrix <- as.matrix(
    dodgr::dodgr_times(
      graph,
      from = from_id,
      to = to_ids,
      shortest = FALSE
    )
  )
  
  distance_matrix <- as.matrix(
    dodgr::dodgr_dists(
      graph,
      from = from_id,
      to = to_ids,
      shortest = FALSE
    )
  )
  
  if (nrow(time_matrix) != 1 || nrow(distance_matrix) != 1) {
    stop("Expected one origin row in the routing matrices.")
  }
  
  if (ncol(time_matrix) != length(to_ids) || ncol(distance_matrix) != length(to_ids)) {
    stop("Routing matrix dimensions do not match the Census block destination count.")
  }
  
  # dodgr usually returns IDs as matrix column names. If a version returns
  # unnamed columns, the input order is retained by dodgr; assign the explicit
  # input IDs only after validating the column count above.
  if (is.null(colnames(time_matrix))) {
    colnames(time_matrix) <- to_ids
  }
  if (is.null(colnames(distance_matrix))) {
    colnames(distance_matrix) <- to_ids
  }
  
  if (!all(to_ids %in% colnames(time_matrix)) ||
      !all(to_ids %in% colnames(distance_matrix))) {
    stop("Routing matrix output IDs do not match the requested destination IDs.")
  }
  
  time_values <- as.numeric(
    time_matrix[1, match(to_ids, colnames(time_matrix))]
  )
  
  distance_values <- as.numeric(
    distance_matrix[1, match(to_ids, colnames(distance_matrix))]
  )
  
  tibble(
    block_geoid_tiger = block_geoids,
    drive_seconds = time_values,
    distance_m = distance_values
  ) %>%
    mutate(
      modeled_drive_min = drive_seconds / 60,
      modeled_distance_km = distance_m / 1000,
      modeled_distance_mi = distance_m / 1609.344,
      implied_average_speed_kmh = if_else(
        is.finite(modeled_drive_min) & modeled_drive_min > 0,
        modeled_distance_km / (modeled_drive_min / 60),
        NA_real_
      ),
      route_status = if_else(
        is.finite(modeled_drive_min) & is.finite(modeled_distance_km),
        "Reachable",
        "Unreachable"
      )
    )
}

block_geoids <- yellow_block_lookup_routing$block_geoid_tiger

# ---------------------------------------------------------------------------
# 14. SCENARIO 1: NCFPD STATION 1 - NORMAL ACCESS
# ---------------------------------------------------------------------------

message("Calculating NCFPD Station 1 normal-access travel times and distances...")

routes_ncfpd1_normal <- calculate_routes_by_vertex_id(
  graph = graph_open,
  from_id = open_ncfpd1_id,
  to_ids = block_vertex_ids_open,
  block_geoids = block_geoids
)

# ---------------------------------------------------------------------------
# 15. SCENARIO 2: NCFPD STATION 1 - FORCED FLOODED DETOUR
# ---------------------------------------------------------------------------

message("Calculating the three mandatory flooded-detour legs...")

# Each leg is routed on the bridge-closed graph and the legs are summed in
# order. The final leg from the Rock Mountain entry to each block is also
# routed on the bridge-closed graph.
get_single_leg_metrics <- function(graph, from_id, to_id) {
  time_value <- as.numeric(
    dodgr::dodgr_times(
      graph,
      from = from_id,
      to = to_id,
      shortest = FALSE
    )[1, 1]
  )
  
  distance_value <- as.numeric(
    dodgr::dodgr_dists(
      graph,
      from = from_id,
      to = to_id,
      shortest = FALSE
    )[1, 1]
  )
  
  tibble(
    drive_seconds = time_value,
    distance_m = distance_value
  )
}

# Ordered mandatory legs
leg1_de_luz <- get_single_leg_metrics(
  graph_closed,
  closed_ncfpd1_id,
  closed_de_luz_id
)

leg2_camaron <- get_single_leg_metrics(
  graph_closed,
  closed_de_luz_id,
  closed_camaron_id
)

leg3_rock_mountain <- get_single_leg_metrics(
  graph_closed,
  closed_camaron_id,
  closed_rock_id
)

detour_prefix_metrics <- bind_rows(
  leg1_de_luz %>% mutate(route_leg = "Station 1 to De Luz"),
  leg2_camaron %>% mutate(route_leg = "De Luz to Camaron"),
  leg3_rock_mountain %>% mutate(route_leg = "Camaron to Sandia Creek / Rock Mountain entry")
)

if (any(!is.finite(detour_prefix_metrics$drive_seconds)) ||
    any(!is.finite(detour_prefix_metrics$distance_m))) {
  stop("At least one mandatory flooded-detour leg is unreachable on the closed graph.")
}

detour_prefix_seconds <- sum(detour_prefix_metrics$drive_seconds)
detour_prefix_distance_m <- sum(detour_prefix_metrics$distance_m)

# From the Rock Mountain Road entry to all block destinations.
detour_final_legs <- calculate_routes_by_vertex_id(
  graph = graph_closed,
  from_id = closed_rock_id,
  to_ids = block_vertex_ids_closed,
  block_geoids = block_geoids
)

routes_ncfpd1_deluz <- detour_final_legs %>%
  mutate(
    drive_seconds = drive_seconds + detour_prefix_seconds,
    distance_m = distance_m + detour_prefix_distance_m,
    modeled_drive_min = drive_seconds / 60,
    modeled_distance_km = distance_m / 1000,
    modeled_distance_mi = distance_m / 1609.344,
    implied_average_speed_kmh = if_else(
      is.finite(modeled_drive_min) & modeled_drive_min > 0,
      modeled_distance_km / (modeled_drive_min / 60),
      NA_real_
    ),
    route_status = if_else(
      is.finite(modeled_drive_min) & is.finite(modeled_distance_km),
      "Reachable",
      "Unreachable"
    )
  )

# Save the mandatory route-leg detail for transparency.
utils::write.csv(
  as.data.frame(detour_prefix_metrics %>%
                  mutate(
                    modeled_drive_min = drive_seconds / 60,
                    modeled_distance_km = distance_m / 1000
                  )),
  file.path(OUTPUT_DIR, "Flooded_Detour_Mandatory_Legs.csv"),
  row.names = FALSE,
  na = ""
)

# ---------------------------------------------------------------------------
# 16. SCENARIO 3: TEMECULA CIVIC CENTER - BRIDGE-CLOSURE NETWORK
# ---------------------------------------------------------------------------

message("Calculating Temecula Civic Center bridge-closure travel times and distances...")

routes_temecula_closure <- calculate_routes_by_vertex_id(
  graph = graph_closed,
  from_id = closed_temecula_id,
  to_ids = block_vertex_ids_closed,
  block_geoids = block_geoids
)

# ---------------------------------------------------------------------------
# 17. RECONSTRUCT THE FLOODED DETOUR GEOMETRY FROM THE CLOSED GRAPH
# ---------------------------------------------------------------------------

# dodgr_paths uses shortest paths by default. For fastest paths, replace
# d_weighted with time_weighted as recommended in dodgr's time-routing vignette.
graph_closed_for_paths <- graph_closed
graph_closed_for_paths$d_weighted <- graph_closed_for_paths$time_weighted

closed_graph_vertices <- dodgr::dodgr_vertices(graph_closed_for_paths)

# ============================================================
# CORRECTED STEP 17: EXTRACT FLOODED DETOUR PATH VERTICES
# ============================================================

get_path_vertices <- function(
    graph,
    from_id,
    to_id,
    vertices_table
) {
  
  # Calculate fastest path between the specified locations
  path_list <- dodgr::dodgr_paths(
    graph,
    from = from_id,
    to = to_id,
    vertices = TRUE,
    quiet = TRUE
  )
  
  # Extract vertex IDs
  path_vertex_ids <- path_list[[1]][[1]]
  
  # Confirm a valid path was returned
  if (
    is.null(path_vertex_ids) ||
    length(path_vertex_ids) < 2
  ) {
    stop(
      "A required flooded-detour path could not be reconstructed."
    )
  }
  
  # Confirm the vertex table contains the required fields
  if (!all(c("id", "x", "y") %in% names(vertices_table))) {
    stop(
      "Vertex table must contain id, x, and y columns."
    )
  }
  
  # MATCH VERTEX IDs TO ROWS IN THE VERTEX TABLE
  vertex_rows <- match(
    as.character(path_vertex_ids),
    as.character(vertices_table$id)
  )
  
  # Check that all path vertices were matched
  if (anyNA(vertex_rows)) {
    missing_ids <- path_vertex_ids[is.na(vertex_rows)]
    
    stop(
      paste(
        "Some path vertex IDs could not be matched:",
        paste(head(missing_ids, 10), collapse = ", ")
      )
    )
  }
  
  # Extract ordered coordinates
  path_coordinates <- vertices_table[
    vertex_rows,
    c("x", "y"),
    drop = FALSE
  ]
  
  # Check coordinates
  if (
    any(!is.finite(path_coordinates$x)) ||
    any(!is.finite(path_coordinates$y))
  ) {
    stop("Invalid coordinates found in reconstructed path.")
  }
  
  return(path_coordinates)
}
path_leg1 <- get_path_vertices(
  graph_closed_for_paths,
  closed_ncfpd1_id,
  closed_de_luz_id,
  closed_graph_vertices
)

path_leg2 <- get_path_vertices(
  graph_closed_for_paths,
  closed_de_luz_id,
  closed_camaron_id,
  closed_graph_vertices
)

path_leg3 <- get_path_vertices(
  graph_closed_for_paths,
  closed_camaron_id,
  closed_rock_id,
  closed_graph_vertices
)

# Confirm that the adjoining legs meet at their endpoints.
coords_end_1 <- as.numeric(unlist(tail(path_leg1, 1), use.names = FALSE))
coords_start_2 <- as.numeric(unlist(head(path_leg2, 1), use.names = FALSE))
coords_end_2 <- as.numeric(unlist(tail(path_leg2, 1), use.names = FALSE))
coords_start_3 <- as.numeric(unlist(head(path_leg3, 1), use.names = FALSE))

if (
  max(abs(coords_end_1 - coords_start_2)) > 1e-7 ||
  max(abs(coords_end_2 - coords_start_3)) > 1e-7
) {
  stop("The reconstructed detour legs do not meet at their waypoint vertices.")
}

detour_route_coords <- bind_rows(
  path_leg1,
  path_leg2 %>% slice(-1),
  path_leg3 %>% slice(-1)
) %>%
  as.matrix()

if (nrow(detour_route_coords) < 2 || any(!is.finite(detour_route_coords))) {
  stop("Invalid coordinates in reconstructed flooded-detour geometry.")
}

flooded_detour_route <- st_sf(
  route_name = "Flooded Detour Route",
  geometry = st_sfc(
    st_linestring(detour_route_coords),
    crs = 4326
  )
) %>%
  st_transform(26911)

# Waypoint points for map labels
flooded_detour_stops <- tibble(
  stop_order = 0:3,
  stop_name = c(
    "NCFPD Station 1",
    "De Luz Road",
    "Camaron Road",
    "Sandia Creek / Rock Mountain entry"
  ),
  longitude = c(
    as.numeric(ncfpd1_origin_row$origin_lon),
    detour_waypoints_geocoded$longitude
  ),
  latitude = c(
    as.numeric(ncfpd1_origin_row$origin_lat),
    detour_waypoints_geocoded$latitude
  )
)

detour_stop_points <- st_as_sf(
  flooded_detour_stops,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
) %>%
  st_transform(26911)

# ---------------------------------------------------------------------------
# 18. BUILD THE FINAL THREE CENSUS-BLOCK TRAVEL-TIME/DISTANCE TABLES
# ---------------------------------------------------------------------------

block_metadata <- yellow_block_lookup_routing %>%
  select(
    block_geoid_tiger,
    tract_geoid_tiger,
    historical_incident_count,
    block_point_lon,
    block_point_lat,
    routing_lon,
    routing_lat,
    destination_method,
    nearest_road_name,
    nearest_road_highway,
    distance_to_road_m
  )

assemble_block_table <- function(route_results, origin_name, scenario_name) {
  
  output <- route_results %>%
    left_join(block_metadata, by = "block_geoid_tiger") %>%
    mutate(
      origin_name = origin_name,
      scenario = scenario_name
    ) %>%
    select(
      block_geoid_tiger,
      tract_geoid_tiger,
      historical_incident_count,
      block_point_lon,
      block_point_lat,
      routing_lon,
      routing_lat,
      destination_method,
      nearest_road_name,
      nearest_road_highway,
      distance_to_road_m,
      origin_name,
      scenario,
      drive_seconds,
      modeled_drive_min,
      distance_m,
      modeled_distance_km,
      modeled_distance_mi,
      implied_average_speed_kmh,
      route_status
    ) %>%
    arrange(desc(modeled_drive_min))
  
  if (nrow(output) != nrow(yellow_block_lookup_routing)) {
    stop("The output table does not contain one row for each yellow-zone Census block.")
  }
  
  if (anyDuplicated(output$block_geoid_tiger)) {
    stop("Duplicate Census block GEOIDs were found in a scenario table.")
  }
  
  output
}

block_times_ncfpd1_normal_dodgr <- assemble_block_table(
  routes_ncfpd1_normal,
  "NCFPD Station 1",
  "Normal Access"
)

block_times_ncfpd1_deluz_dodgr <- assemble_block_table(
  routes_ncfpd1_deluz,
  "NCFPD Station 1",
  "Flooded Detour - De Luz/Camaron/Sandia Creek"
)

block_times_temecula_closure_dodgr <- assemble_block_table(
  routes_temecula_closure,
  "Temecula Civic Center",
  "Bridge Closure - Temecula Response"
)

# Normal-versus-flooded-detour comparison.
ncfpd1_travel_time_comparison <- block_times_ncfpd1_normal_dodgr %>%
  select(
    block_geoid_tiger,
    normal_drive_min = modeled_drive_min,
    normal_distance_km = modeled_distance_km
  ) %>%
  left_join(
    block_times_ncfpd1_deluz_dodgr %>%
      select(
        block_geoid_tiger,
        detour_drive_min = modeled_drive_min,
        detour_distance_km = modeled_distance_km
      ),
    by = "block_geoid_tiger"
  ) %>%
  mutate(
    added_drive_min = detour_drive_min - normal_drive_min,
    added_distance_km = detour_distance_km - normal_distance_km
  ) %>%
  left_join(
    block_metadata %>%
      select(
        block_geoid_tiger,
        historical_incident_count,
        destination_method,
        nearest_road_name,
        distance_to_road_m
      ),
    by = "block_geoid_tiger"
  ) %>%
  arrange(desc(added_drive_min))

# Scenario-level summary, including distance.
scenario_summary <- bind_rows(
  block_times_ncfpd1_normal_dodgr,
  block_times_ncfpd1_deluz_dodgr,
  block_times_temecula_closure_dodgr
) %>%
  group_by(scenario) %>%
  summarise(
    total_blocks = n(),
    reachable_blocks = sum(route_status == "Reachable"),
    unreachable_blocks = sum(route_status == "Unreachable"),
    mean_drive_min = mean(modeled_drive_min, na.rm = TRUE),
    median_drive_min = median(modeled_drive_min, na.rm = TRUE),
    p90_drive_min = quantile(modeled_drive_min, 0.90, na.rm = TRUE),
    mean_distance_km = mean(modeled_distance_km, na.rm = TRUE),
    median_distance_km = median(modeled_distance_km, na.rm = TRUE),
    p90_distance_km = quantile(modeled_distance_km, 0.90, na.rm = TRUE),
    .groups = "drop"
  )

# Flag implausible network averages for QA, not as a speed cap.
implausible_routes <- bind_rows(
  block_times_ncfpd1_normal_dodgr,
  block_times_ncfpd1_deluz_dodgr,
  block_times_temecula_closure_dodgr
) %>%
  filter(
    is.finite(implied_average_speed_kmh),
    implied_average_speed_kmh > 130
  ) %>%
  select(
    block_geoid_tiger,
    scenario,
    modeled_drive_min,
    modeled_distance_km,
    implied_average_speed_kmh
  )

if (nrow(implausible_routes) > 0) {
  warning(
    nrow(implausible_routes),
    " route result(s) have an implied average speed over 130 km/h. Review before interpreting maps."
  )
}

# ---------------------------------------------------------------------------
# 19. PREPARE THE MAP INPUT DATASETS
# ---------------------------------------------------------------------------

yellow_blocks_map_base <- yellow_blocks %>%
  st_transform(26911)

prepare_block_map_data <- function(route_table) {
  
  if (anyDuplicated(route_table$block_geoid_tiger)) {
    stop("Duplicate block GEOIDs in map input.")
  }
  
  map_data <- yellow_blocks_map_base %>%
    left_join(
      route_table %>%
        select(
          block_geoid_tiger,
          modeled_drive_min,
          modeled_distance_km,
          route_status,
          historical_incident_count,
          destination_method,
          distance_to_road_m
        ),
      by = "block_geoid_tiger"
    )
  
  if (anyNA(map_data$route_status)) {
    stop("One or more Census block polygons did not match the scenario table.")
  }
  
  map_data %>%
    mutate(
      modeled_drive_min = if_else(
        route_status == "Reachable" & is.finite(modeled_drive_min),
        modeled_drive_min,
        NA_real_
      )
    )
}

map_data_ncfpd1_normal <- prepare_block_map_data(
  block_times_ncfpd1_normal_dodgr
)

map_data_ncfpd1_deluz <- prepare_block_map_data(
  block_times_ncfpd1_deluz_dodgr
)

map_data_temecula <- prepare_block_map_data(
  block_times_temecula_closure_dodgr
)

# Common travel-time limits across all three maps.
all_modeled_times <- c(
  block_times_ncfpd1_normal_dodgr$modeled_drive_min,
  block_times_ncfpd1_deluz_dodgr$modeled_drive_min,
  block_times_temecula_closure_dodgr$modeled_drive_min
)

finite_modeled_times <- all_modeled_times[is.finite(all_modeled_times)]

if (length(finite_modeled_times) == 0) {
  stop("No finite travel times were produced; maps cannot be created.")
}

common_time_max <- ceiling(max(finite_modeled_times) / 5) * 5
common_time_limits <- c(0, common_time_max)

# ---------------------------------------------------------------------------
# 20. RETRIEVE THE SANTA MARGARITA RIVER (OPTIONAL MAP CONTEXT)
# ---------------------------------------------------------------------------

# River data are only used as a background reference layer. If Overpass is
# unavailable, mapping and routing continue without the river line.
river_bbox <- c(
  unname(MAP_EXTENT_WGS84["xmin"]),
  unname(MAP_EXTENT_WGS84["ymin"]),
  unname(MAP_EXTENT_WGS84["xmax"]),
  unname(MAP_EXTENT_WGS84["ymax"])
)

osm_santa_margarita <- NULL
river_cache_file <- file.path(OUTPUT_DIR, "Santa_Margarita_River_Cache.rds")

try({
  river_lines <- NULL
  use_river_cache <- FALSE
  
  if (USE_CACHED_OSM && file.exists(river_cache_file)) {
    cached_river <- tryCatch(readRDS(river_cache_file), error = function(e) NULL)
    if (is.list(cached_river) &&
        !is.null(cached_river$bbox) &&
        !is.null(cached_river$river_lines) &&
        isTRUE(all.equal(as.numeric(cached_river$bbox), as.numeric(river_bbox), tolerance = 1e-8))) {
      river_lines <- cached_river$river_lines
      use_river_cache <- TRUE
      message("Loading cached Santa Margarita River features.")
    }
  }
  
  if (!use_river_cache) {
    river_data <- fetch_osm_lines_with_fallback(
      key = "waterway",
      value = "river",
      bbox = river_bbox,
      label = "Santa Margarita River line features"
    )
    river_lines <- river_data$osm_lines
    if (USE_CACHED_OSM && !is.null(river_lines) && nrow(river_lines) > 0) {
      saveRDS(
        list(bbox = as.numeric(river_bbox), river_lines = river_lines),
        river_cache_file
      )
      message("Saved Santa Margarita River cache.")
    }
  }
  
  if (!is.null(river_lines) && nrow(river_lines) > 0) {
    if (!"name" %in% names(river_lines)) {
      river_lines$name <- NA_character_
    }
    
    osm_santa_margarita <- river_lines %>%
      filter(
        stringr::str_detect(
          coalesce(as.character(name), ""),
          regex("Santa Margarita", ignore_case = TRUE)
        )
      ) %>%
      st_transform(26911)
  }
}, silent = TRUE)

if (is.null(osm_santa_margarita) || nrow(osm_santa_margarita) == 0) {
  osm_santa_margarita <- NULL
  message("Santa Margarita River line not available from Overpass; maps will be generated without the river layer.")
}

# ---------------------------------------------------------------------------
# 21. PREPARE COMMON CARTOGRAPHIC REFERENCE LAYERS
# ---------------------------------------------------------------------------

tract_labels_map_utm <- tracts_in_extent %>%
  st_point_on_surface()

# Major road context, including all four roads named in the flooded route.
detour_context_roads_map <- roads_open_clean %>%
  filter(
    !is.na(name),
    stringr::str_detect(
      as.character(name),
      regex(
        "De Luz|Camaron|Sandia Creek|Rock Mountain",
        ignore_case = TRUE
      )
    )
  ) %>%
  st_transform(26911)

# Candidate response locations. The map extent clips origins outside the
# detailed yellow-zone map area; all seven remain in this object.
all_site_points_map_utm <- all_sites %>%
  mutate(
    origin_name = stringr::str_squish(as.character(origin_name)),
    origin_lon = as.numeric(origin_lon),
    origin_lat = as.numeric(origin_lat)
  ) %>%
  filter(is.finite(origin_lon), is.finite(origin_lat)) %>%
  st_as_sf(
    coords = c("origin_lon", "origin_lat"),
    crs = 4326,
    remove = FALSE
  ) %>%
  st_transform(26911)

old_crossing <- st_sf(
  crossing_name = "Current Sandia Creek Drive bridge",
  geometry = st_sfc(
    st_point(c(-117.2416111, 33.4140861)),
    crs = 4326
  )
) %>%
  st_transform(26911)

# ---------------------------------------------------------------------------
# 22. CREATE THE THREE GREEN-TO-RED ARRIVAL-TIME GRADIENT MAPS
# ---------------------------------------------------------------------------

make_arrival_gradient_map <- function(
    map_data,
    map_title,
    active_origin_name,
    show_detour = FALSE
) {
  
  origin_idx <- which(
    tolower(trimws(all_site_points_map_utm$origin_name)) ==
      tolower(trimws(active_origin_name))
  )
  
  if (length(origin_idx) != 1) {
    stop(
      "Expected exactly one response origin for map: ",
      active_origin_name,
      "; found ", length(origin_idx)
    )
  }
  
  active_origin <- all_site_points_map_utm[origin_idx, ]
  adjusted_blocks <- map_data %>%
    filter(destination_method != "Original Census block point on surface")
  
  p <- ggplot() +
    
    # Census block polygons colored by modeled drive time.
    geom_sf(
      data = map_data,
      aes(fill = modeled_drive_min),
      color = "grey35",
      linewidth = 0.25
    ) +
    
    # Dashed outline distinguishes the two road-access-adjusted blocks.
    geom_sf(
      data = adjusted_blocks,
      fill = NA,
      color = "black",
      linetype = "dashed",
      linewidth = 0.75
    ) +
    
    # Census tract boundaries and labels.
    geom_sf(
      data = tracts_in_extent,
      fill = NA,
      color = "black",
      linewidth = 0.5
    ) +
    
    geom_sf_text(
      data = tract_labels_map_utm,
      aes(label = tract_geoid_tiger),
      size = 2.4,
      color = "black"
    ) +
    
    # Yellow study-area boundary.
    geom_sf(
      data = yellow_area,
      fill = NA,
      color = "#C99000",
      linetype = "dashed",
      linewidth = 1
    )
  
  # River is optional if Overpass successfully returned it.
  if (!is.null(osm_santa_margarita)) {
    p <- p + geom_sf(
      data = osm_santa_margarita,
      color = "deepskyblue3",
      linewidth = 1.1
    )
  }
  
  p <- p +
    
    # Road context in grey. The flooded route itself is highlighted separately.
    geom_sf(
      data = detour_context_roads_map,
      color = "grey55",
      linewidth = 0.55
    ) +
    
    # Historical incidents assigned to selected Census blocks.
    geom_sf(
      data = incidents_yellow_map,
      color = "firebrick",
      size = 0.38,
      alpha = 0.45
    ) +
    
    # All candidate response origins in muted grey; active origin is black.
    geom_sf(
      data = all_site_points_map_utm,
      color = "grey35",
      shape = 8,
      size = 3,
      stroke = 1
    ) +
    
    geom_sf(
      data = active_origin,
      color = "black",
      shape = 8,
      size = 5.5,
      stroke = 1.5
    ) +
    
    geom_sf_text(
      data = active_origin,
      aes(label = site_label),
      color = "black",
      size = 3,
      nudge_y = 150,
      show.legend = FALSE
    ) +
    
    # Current bridge location.
    geom_sf(
      data = old_crossing,
      color = "blue",
      shape = 17,
      size = 3.5
    ) +
    
    # Shared gradient: same travel-time values have the same color on all maps.
    scale_fill_gradientn(
      colors = c(
        "#16803C",
        "#78B957",
        "#F5E65B",
        "#EF963D",
        "#C62828"
      ),
      limits = common_time_limits,
      breaks = seq(0, common_time_max, by = 5),
      oob = scales::squish,
      na.value = "grey78",
      name = "Modeled drive time\n(minutes)"
    ) +
    
    coord_sf(
      crs = st_crs(26911),
      default_crs = st_crs(26911),
      xlim = map_xlim_utm,
      ylim = map_ylim_utm,
      expand = FALSE
    ) +
    
    labs(
      title = map_title,
      subtitle = "Modeled driving time to a representative road-access point for each selected 2010 Census block",
      x = "Easting (meters)",
      y = "Northing (meters)",
      caption = paste(
        "Red points = geocoded 2014-2018 incidents; blue triangle = current bridge;",
        "dashed gold = approximate yellow boundary; dashed black = two adjusted block destinations;",
        "grey fill = no connected route."
      )
    ) +
    
    theme_bw() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      panel.grid = element_line(color = "grey90"),
      legend.position = "right"
    )
  
  # Add the forced detour line and its waypoints only to the detour scenario.
  if (show_detour) {
    p <- p +
      geom_sf(
        data = flooded_detour_route,
        color = "#E69F00",
        linewidth = 1.8
      ) +
      geom_sf(
        data = detour_stop_points %>% filter(stop_order > 0),
        shape = 21,
        fill = "white",
        color = "black",
        size = 3
      ) +
      geom_sf_text(
        data = detour_stop_points %>% filter(stop_order > 0),
        aes(label = stop_name),
        color = "black",
        size = 2.6,
        nudge_y = 100,
        check_overlap = TRUE,
        show.legend = FALSE
      )
  }
  
  p
}

map_ncfpd1_normal <- make_arrival_gradient_map(
  map_data = map_data_ncfpd1_normal,
  map_title = "NCFPD Station 1 - Normal Access",
  active_origin_name = "NCFPD Station 1",
  show_detour = FALSE
)

map_ncfpd1_deluz <- make_arrival_gradient_map(
  map_data = map_data_ncfpd1_deluz,
  map_title = "NCFPD Station 1 - Flooded Detour Route",
  active_origin_name = "NCFPD Station 1",
  show_detour = TRUE
)

map_temecula_closure <- make_arrival_gradient_map(
  map_data = map_data_temecula,
  map_title = "Temecula Civic Center - Bridge Closure",
  active_origin_name = "Temecula Civic Center",
  show_detour = FALSE
)

# ---------------------------------------------------------------------------
# 23. SAVE TABLES, MAPS, AND A THREE-LAYER GEOPACKAGE
# ---------------------------------------------------------------------------

# CSV outputs
write_csv(
  block_times_ncfpd1_normal_dodgr,
  file.path(OUTPUT_DIR, "Block_Times_NCFPD1_Normal.csv")
)

write_csv(
  block_times_ncfpd1_deluz_dodgr,
  file.path(OUTPUT_DIR, "Block_Times_NCFPD1_Flooded_Detour.csv")
)

write_csv(
  block_times_temecula_closure_dodgr,
  file.path(OUTPUT_DIR, "Block_Times_Temecula_Bridge_Closure.csv")
)

write_csv(
  ncfpd1_travel_time_comparison,
  file.path(OUTPUT_DIR, "NCFPD1_Normal_vs_Flooded_Detour_Comparison.csv")
)

write_csv(
  scenario_summary,
  file.path(OUTPUT_DIR, "Scenario_Summary_Time_and_Distance.csv")
)

write_csv(
  implausible_routes,
  file.path(OUTPUT_DIR, "Routing_Plausibility_Flags.csv")
)

# PNG maps
map_files <- c(
  normal = file.path(OUTPUT_DIR, "Arrival_Gradient_NCFPD1_Normal.png"),
  detour = file.path(OUTPUT_DIR, "Arrival_Gradient_NCFPD1_Flooded_Detour.png"),
  temecula = file.path(OUTPUT_DIR, "Arrival_Gradient_Temecula_Bridge_Closure.png")
)

ggsave(map_files["normal"], map_ncfpd1_normal, width = 13, height = 10, units = "in", dpi = 300)
ggsave(map_files["detour"], map_ncfpd1_deluz, width = 13, height = 10, units = "in", dpi = 300)
ggsave(map_files["temecula"], map_temecula_closure, width = 13, height = 10, units = "in", dpi = 300)

# GeoPackage with one layer per scenario.
map_gpkg <- file.path(OUTPUT_DIR, "Sandia_Creek_Arrival_Time_Maps.gpkg")
if (file.exists(map_gpkg)) {
  file.remove(map_gpkg)
}

st_write(
  map_data_ncfpd1_normal,
  map_gpkg,
  layer = "NCFPD1_Normal",
  quiet = TRUE
)

st_write(
  map_data_ncfpd1_deluz,
  map_gpkg,
  layer = "NCFPD1_Flooded_Detour",
  append = TRUE,
  quiet = TRUE
)

st_write(
  map_data_temecula,
  map_gpkg,
  layer = "Temecula_Bridge_Closure",
  append = TRUE,
  quiet = TRUE
)

# Save the complete routing inputs and outputs as an RDS for later inspection.
saveRDS(
  list(
    all_sites = all_sites,
    yellow_area = yellow_area,
    yellow_block_lookup_routing = yellow_block_lookup_routing,
    detour_waypoints_geocoded = detour_waypoints_geocoded,
    flooded_detour_route = flooded_detour_route,
    scenario_summary = scenario_summary,
    block_times_ncfpd1_normal_dodgr = block_times_ncfpd1_normal_dodgr,
    block_times_ncfpd1_deluz_dodgr = block_times_ncfpd1_deluz_dodgr,
    block_times_temecula_closure_dodgr = block_times_temecula_closure_dodgr,
    ncfpd1_travel_time_comparison = ncfpd1_travel_time_comparison
  ),
  file.path(OUTPUT_DIR, "Sandia_Creek_Master_Results.rds")
)

# Record R and package versions for reproducibility.
capture.output(
  utils::sessionInfo(),
  file = file.path(OUTPUT_DIR, "R_Session_Info.txt")
)

# ---------------------------------------------------------------------------
# 24. FINAL CONSOLE SUMMARY
# ---------------------------------------------------------------------------

cat("\n============================================================\n")
cat("SANDIA CREEK EMERGENCY ACCESS ANALYSIS COMPLETE\n")
cat("============================================================\n")
cat("Selected Census blocks: ", nrow(yellow_block_lookup_routing), "\n", sep = "")
cat("Historical incidents assigned to selected blocks: ", nrow(incidents_in_yellow_blocks), "\n", sep = "")
cat("Mandatory flooded-detour time (minutes): ", round(detour_prefix_seconds / 60, 2), "\n", sep = "")
cat("Mandatory flooded-detour distance (km): ", round(detour_prefix_distance_m / 1000, 2), "\n", sep = "")
cat("Output folder: ", normalizePath(OUTPUT_DIR), "\n", sep = "")
cat("\nScenario summary:\n")
print(as.data.frame(scenario_summary), row.names = FALSE)
cat("\nMaps created:\n")
print(map_files)
cat("\nReview these before interpretation:\n")
cat("  - Yellow_Boundary_Block_Selection_Check.png\n")
cat("  - Routing_Point_Snap_Check.csv\n")
cat("  - Flooded_Detour_Waypoint_Geocoding.csv\n")
cat("  - Routing_Plausibility_Flags.csv\n")
cat("============================================================\n")

