# ============================================================================
# SANDIA CREEK BRIDGE EMERGENCY ACCESS STUDY
# MASTER REPRODUCIBLE SCRIPT - 2020 CENSUS BLOCKS / NORTH-SIDE ROUTING
# ============================================================================
# STARTING INPUT
#   A fresh RStudio session plus either:
#     (a) Incidents_2014_2018_flood_xy_2020blocks preloaded, or
#     (b) the CSV at INCIDENT_CSV_PATH below.
#
# OUTPUTS
#   - 2020 Census-block routing tables for three scenarios
#   - Normal vs. flooded-detour comparison
#   - Six maps: 3 travel-time and 3 travel-distance
#   - Spatial GeoPackage, QA CSVs, and an RDS containing core results
#
# ROUTING DESIGN (IMPORTANT)
#   1. NORMAL network: includes the current Sandia Creek bridge and the
#      verified De Luz bridge; removes the unverified OSM track crossing and
#      any other OSM road feature intersecting the river centerline that is
#      not one of those two approved bridges.
#   2. FLOODED DETOUR PREFIX: removes the current Sandia Creek bridge but
#      retains the De Luz bridge. Only the Station 1 -> De Luz leg uses this
#      graph. Thus De Luz is the one permitted crossing for the detour.
#   3. NORTH-SIDE network: contains only motorcar road features on the north
#      side of the river and outside a configurable river buffer. It contains
#      no river-crossing bridge features. De Luz -> Camaron -> Rock Mountain,
#      Rock Mountain -> every selected block, and Temecula -> every selected
#      block are all calculated on this north-side-only graph.
#
#   All routing nodes are inserted with intersections_only=TRUE. This splits
#   the nearest road edge at the perpendicular projection but does NOT add an
#   artificial connector edge from a point to a road. Snap distances are
#   independently measured and exported for review.
#
# CENSUS / MAPPING
#   - Uses 2020 TIGER Census blocks (GEOID20) and tracts (GEOID20).
#   - Incident-to-block counts are taken from block_geoid_2020 in the supplied
#     2020-block incident CSV, not from legacy 2010 GEOIDs.
#   - Only yellow-boundary blocks classified north of the Santa Margarita
#     River are routed and mapped. Blocks within the river review band are
#     excluded pending review; south-side blocks are excluded.
#   - All six maps use exactly the same WGS84 extent:
#       Longitude: 117.35 W to 117.10 W
#       Latitude:  33.35 N to 33.55 N
#
# SPEED ASSUMPTION
#   Maximum modeled edge speed = 56.3 km/h. Lower road-class speeds remain.
#   This is a modeling cap, not a claim that every road has that speed limit.
#
# LIMITATIONS
#   Results are modeled road-network driving times/distances, not observed
#   EMS arrival times. The analysis does not model dispatch/turnout, traffic,
#   signal delay, siren priority, or actual apparatus assignment. Census-block
#   road-access points are representative modeled destinations, not addresses.
# ============================================================================

# ---------------------------------------------------------------------------
# 0. USER SETTINGS
# ---------------------------------------------------------------------------

INCIDENT_CSV_PATH <- "data/Incidents_2014_2018_flood_xy_2020blocks.csv"
OUTPUT_DIR <- "Sandia_Creek_2020_NorthOnly_Validated_Outputs"
USE_CACHED_OSM <- TRUE

STATE_FIPS <- "06"
COUNTY_FIPS <- c("073", "065") # San Diego and Riverside

# Exact map extent requested by user. All map layers will be transformed to
# WGS84 and coord_sf will use these longitude/latitude bounds directly.
MAP_EXTENT_WGS84 <- c(
  xmin = -117.35,
  ymin = 33.35,
  xmax = -117.10,
  ymax = 33.55
)

# Approximate yellow study boundary digitized from the user's annotated map.
YELLOW_RING <- matrix(c(
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

# Block-side classification settings
RIVER_SIDE_REVIEW_BAND_M <- 25
NORTH_ROAD_SIDE_MARGIN_M <- 25
NORTH_ROAD_RIVER_BUFFER_M <- 30

# Audited OSM way IDs from prior inspection
CURRENT_SANDIA_BRIDGE_OSM_ID <- "847853579"
DE_LUZ_BRIDGE_OSM_ID <- "339841757"
UNVERIFIED_TRACK_CROSSING_OSM_ID <- "106831925"
APPROVED_RIVER_CROSSING_IDS <- c(
  DE_LUZ_BRIDGE_OSM_ID,
  CURRENT_SANDIA_BRIDGE_OSM_ID
)

# User-designated destination within the relevant 2020 Census block.
# The block GEOID is found spatially from the 2020 polygons; do NOT hardcode
# any 2010 GEOID here.
SPECIAL_TARGET_LAT <- 33.419007
SPECIAL_TARGET_LON <- -117.214337
SPECIAL_TARGET_MAX_SNAP_M <- 50

# Geocoded waypoint QA thresholds
MAX_WAYPOINT_SNAP_M <- 200
MAX_NCFPD_ORIGIN_SNAP_M <- 200
MAX_TEMECULA_ORIGIN_SNAP_M <- 250
MAX_BLOCK_SNAP_REVIEW_M <- 500
MAX_BLOCK_SNAP_STOP_M <- 1500

# Routing assumptions
MAX_MODELED_SPEED_KMH <- 56.3

# OSM query settings
OSM_BBOX_PADDING_DEG <- 0.025
OVERPASS_FALLBACK_URLS <- c(
  "https://overpass.private.coffee/api/interpreter",
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter"
)

# Harris Trail routing diagnostic point.
# This identifies a potential branch location, NOT a mandatory stop.
HARRIS_TURN_LAT <- 33.408660
HARRIS_TURN_LON <- -117.273281
HARRIS_TURN_MAX_SNAP_M <- 100

# ---------------------------------------------------------------------------
# NCFPD STATION 1 - I-15 / RANCHO CALIFORNIA ROAD ALTERNATIVE
# ---------------------------------------------------------------------------

I15_STATION_WAYPOINTS <- tibble(
  waypoint_order = 1:2,
  waypoint_name = c(
    "I-15 approach",
    "Sandia Creek Drive entry"
  ),
  latitude = c(
    33.387876,
    33.498885
  ),
  longitude = c(
    -117.173591,
    -117.188206
  )
)

I15_WAYPOINT_MAX_SNAP_M <- 250

# Minimum distance the reconstructed waypoint-to-waypoint route must
# overlap each intended road corridor (with a small spatial tolerance).
I15_MIN_MOTORWAY_OVERLAP_M <- 1000
I15_MIN_RANCHO_OVERLAP_M <- 100
I15_MIN_AVENIDA_OVERLAP_M <- 15
I15_MIN_SANDIA_OVERLAP_M <- 5

# ---------------------------------------------------------------------------
# 1. PACKAGES, SESSION SETTINGS, INPUT DATA
# ---------------------------------------------------------------------------

required_packages <- c(
  "tidyverse", "sf", "tigris", "osmdata", "dodgr",
  "tidygeocoder", "scales", "units"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) install.packages(missing_packages)

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(tigris)
})

options(na.print = "NA")
options(tigris_use_cache = TRUE)
sf::sf_use_s2(FALSE)

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

# Preserve leading zeroes and normalize numeric/scientific-notation GEOIDs.
normalize_geoid15 <- function(x) {
  if (is.numeric(x)) {
    out <- ifelse(is.na(x), NA_character_, sprintf("%.0f", x))
  } else {
    out <- trimws(as.character(x))
    is_sci <- !is.na(out) & stringr::str_detect(out, "[eE][+-]?[0-9]+$")
    if (any(is_sci)) out[is_sci] <- sprintf("%.0f", as.numeric(out[is_sci]))
    out <- sub("\\.0+$", "", out)
  }
  out <- ifelse(is.na(out) | out == "", NA_character_, out)
  out <- stringr::str_pad(out, width = 15, side = "left", pad = "0")
  out
}

# Prefer explicitly named 2020-block objects. A legacy object is accepted
# only if it contains block_geoid_2020.
preloaded_candidates <- c(
  "Incidents_2014_2018_flood_xy_2020blocks",
  "Incidents_2014_2018_xy_2020blocks",
  "Incidents_2014_2018_flood_xy"
)
preloaded_name <- preloaded_candidates[
  vapply(preloaded_candidates, exists, logical(1), envir = .GlobalEnv)
]

if (length(preloaded_name) > 0) {
  incidents_raw <- get(preloaded_name[1], envir = .GlobalEnv)
  message("Using preloaded incident object: ", preloaded_name[1])
} else {
  csv_to_read <- INCIDENT_CSV_PATH
  if (!file.exists(csv_to_read)) {
    message("2020-block incident CSV not found at: ", csv_to_read)
    if (!interactive()) {
      stop("Set INCIDENT_CSV_PATH to Incidents_2014_2018_flood_xy_2020blocks.csv.")
    }
    csv_to_read <- file.choose()
  }
  incidents_raw <- readr::read_csv(
    csv_to_read,
    col_types = readr::cols(block_geoid_2020 = readr::col_character()),
    show_col_types = FALSE
  )
  message("Read 2020-block incident CSV: ", csv_to_read)
}

incidents_input <- tibble::as_tibble(as.data.frame(incidents_raw))
required_incident_columns <- c("longitude", "latitude", "block_geoid_2020")
missing_incident_columns <- setdiff(required_incident_columns, names(incidents_input))
if (length(missing_incident_columns) > 0) {
  stop(
    "Incident input must contain longitude, latitude, and block_geoid_2020. Missing: ",
    paste(missing_incident_columns, collapse = ", ")
  )
}

incidents_input <- incidents_input %>%
  mutate(
    longitude = suppressWarnings(as.numeric(longitude)),
    latitude = suppressWarnings(as.numeric(latitude)),
    block_geoid_2020 = normalize_geoid15(block_geoid_2020)
  )

incidents_with_coordinates <- incidents_input %>%
  filter(
    is.finite(longitude), is.finite(latitude),
    between(longitude, -180, 180),
    between(latitude, -90, 90)
  )

if (nrow(incidents_with_coordinates) == 0) {
  stop("The incident input contains no valid longitude/latitude records.")
}

message(
  "Incident rows: ", nrow(incidents_input),
  "; valid geocoded rows: ", nrow(incidents_with_coordinates),
  "; nonmissing 2020 block assignments: ",
  sum(!is.na(incidents_with_coordinates$block_geoid_2020)), "."
)

# ---------------------------------------------------------------------------
# 2. RESPONSE-ORIGIN CANDIDATES
# ---------------------------------------------------------------------------

all_sites <- tibble::tribble(
  ~source,          ~fdid,  ~dept_sta, ~station_no, ~origin_name,                            ~origin_address,                                         ~origin_status,                                              ~origin_lat,      ~origin_lon,
  "NCFPD",          "37075", "01",     1L,         "NCFPD Station 1",                      "315 East Ivy Street, Fallbrook, CA 92028",            "provisional_station_code_match",                           33.383623526508, -117.249065928903,
  "NCFPD",          "37075", "02",     2L,         "NCFPD Station 2",                      "2180 Winterwarm Drive, Fallbrook, CA 92028",          "provisional_station_code_match",                           33.344648222960, -117.213205335574,
  "NCFPD",          "37075", "03",     3L,         "NCFPD Station 3",                      "2309 Rainbow Valley Boulevard, Rainbow, CA 92028",   "provisional_station_code_match",                           33.414092821734, -117.147593865797,
  "NCFPD",          "37075", "04",     4L,         "NCFPD Station 4",                      "4375 Pala Mesa Drive, Fallbrook, CA 92028",           "provisional_station_code_match",                           33.340429262611, -117.160148449819,
  "NCFPD",          "37075", "05",     5L,         "NCFPD Station 5",                      "5906 Olive Hill Road, Bonsall, CA 92003",             "provisional_station_code_match",                           33.289603983341, -117.229242851451,
  "Riverside",      "00013", "RRU",    NA_integer_, "CAL FIRE Riverside Unit Headquarters", "210 W San Jacinto Ave, Perris, CA 92570",             "headquarters_not_verified_apparatus_origin",              33.786648569891, -117.229874161015,
  "also_riverside", "33115", NA,        NA_integer_, "Temecula Civic Center",                 "41000 Main St, Temecula, CA 92590",                    "registered_department_address_not_verified_apparatus_origin", 33.494679659370, -117.147397649077
) %>%
  mutate(
    site_label = case_when(
      !is.na(station_no) ~ paste0("NCFPD ", station_no),
      source == "Riverside" ~ "CAL FIRE RRU HQ",
      TRUE ~ "Temecula Civic Center"
    )
  )

ncfpd1_origin_row <- all_sites %>% filter(source == "NCFPD", station_no == 1)
temecula_origin_row <- all_sites %>% filter(origin_name == "Temecula Civic Center")
if (nrow(ncfpd1_origin_row) != 1 || nrow(temecula_origin_row) != 1) {
  stop("Could not uniquely identify NCFPD Station 1 and Temecula Civic Center.")
}

# ---------------------------------------------------------------------------
# 3. YELLOW STUDY AREA AND MAP BOUNDING BOX
# ---------------------------------------------------------------------------

yellow_area_wgs84 <- st_sf(
  region = "Yellow outlined study area",
  geometry = st_sfc(st_polygon(list(YELLOW_RING)), crs = 4326)
) %>% st_make_valid()
yellow_area_utm <- st_transform(yellow_area_wgs84, 26911)

# Sample the WGS84 rectangle edges before transforming to UTM for Census crop.
n_extent <- 501
extent_coordinates <- bind_rows(
  tibble(lon = seq(MAP_EXTENT_WGS84["xmin"], MAP_EXTENT_WGS84["xmax"], length.out = n_extent), lat = MAP_EXTENT_WGS84["ymin"]),
  tibble(lon = seq(MAP_EXTENT_WGS84["xmin"], MAP_EXTENT_WGS84["xmax"], length.out = n_extent), lat = MAP_EXTENT_WGS84["ymax"]),
  tibble(lon = MAP_EXTENT_WGS84["xmin"], lat = seq(MAP_EXTENT_WGS84["ymin"], MAP_EXTENT_WGS84["ymax"], length.out = n_extent)),
  tibble(lon = MAP_EXTENT_WGS84["xmax"], lat = seq(MAP_EXTENT_WGS84["ymin"], MAP_EXTENT_WGS84["ymax"], length.out = n_extent))
)
extent_points_utm <- st_as_sf(
  extent_coordinates,
  coords = c("lon", "lat"),
  crs = 4326
) %>% st_transform(26911)
extent_xy_utm <- st_coordinates(extent_points_utm)
map_bbox_utm <- st_bbox(c(
  xmin = min(extent_xy_utm[, "X"]),
  ymin = min(extent_xy_utm[, "Y"]),
  xmax = max(extent_xy_utm[, "X"]),
  ymax = max(extent_xy_utm[, "Y"])
), crs = st_crs(26911))

# ---------------------------------------------------------------------------
# 4. DOWNLOAD 2020 CENSUS BLOCKS AND TRACTS
# ---------------------------------------------------------------------------

message("Downloading 2020 TIGER Census blocks and tracts...")
blocks_by_county <- purrr::map(
  COUNTY_FIPS,
  ~ tigris::blocks(state = STATE_FIPS, county = .x, year = 2020, class = "sf")
)
tracts_by_county <- purrr::map(
  COUNTY_FIPS,
  ~ tigris::tracts(state = STATE_FIPS, county = .x, year = 2020, class = "sf")
)
blocks_2020_raw <- do.call(rbind, blocks_by_county)
tracts_2020_raw <- do.call(rbind, tracts_by_county)

block_geoid_column <- intersect(c("GEOID20", "GEOID"), names(blocks_2020_raw))[1]
tract_geoid_column <- intersect(c("GEOID20", "GEOID"), names(tracts_2020_raw))[1]
if (is.na(block_geoid_column) || is.na(tract_geoid_column)) {
  stop("Could not identify 2020 GEOID fields in TIGER block/tract downloads.")
}

blocks_2020_utm <- blocks_2020_raw %>%
  st_transform(26911) %>%
  st_make_valid() %>%
  mutate(
    block_geoid_2020 = normalize_geoid15(.data[[block_geoid_column]]),
    tract_geoid_2020 = substr(block_geoid_2020, 1, 11)
  ) %>%
  filter(!is.na(block_geoid_2020), !st_is_empty(geometry))
if (any(as.character(st_geometry_type(blocks_2020_utm)) == "GEOMETRYCOLLECTION")) {
  blocks_2020_utm <- st_collection_extract(blocks_2020_utm, "POLYGON", warn = FALSE)
}

tracts_2020_utm <- tracts_2020_raw %>%
  st_transform(26911) %>%
  st_make_valid() %>%
  mutate(
    tract_geoid_2020 = as.character(.data[[tract_geoid_column]])
  ) %>%
  filter(!is.na(tract_geoid_2020), !st_is_empty(geometry))

blocks_in_extent_2020 <- st_crop(blocks_2020_utm, map_bbox_utm)
tracts_in_extent_2020 <- st_crop(tracts_2020_utm, map_bbox_utm)

# ---------------------------------------------------------------------------
# 5. SELECT 2020 BLOCKS INSIDE YELLOW BOUNDARY; ASSIGN INCIDENT COUNTS
# ---------------------------------------------------------------------------

block_rep_points_utm <- st_point_on_surface(blocks_in_extent_2020)
inside_yellow <- lengths(st_within(block_rep_points_utm, yellow_area_utm)) > 0
yellow_blocks_all <- blocks_in_extent_2020[inside_yellow, ]
yellow_block_points_utm <- block_rep_points_utm[inside_yellow, ]
yellow_block_points_wgs84 <- st_transform(yellow_block_points_utm, 4326)
yellow_block_xy <- st_coordinates(yellow_block_points_wgs84)

yellow_block_lookup_all <- yellow_block_points_wgs84 %>%
  st_drop_geometry() %>%
  transmute(
    block_geoid_2020 = as.character(block_geoid_2020),
    tract_geoid_2020 = as.character(tract_geoid_2020),
    block_point_lon = yellow_block_xy[, 1],
    block_point_lat = yellow_block_xy[, 2]
  ) %>%
  distinct(block_geoid_2020, .keep_all = TRUE)

if (nrow(yellow_block_lookup_all) == 0) {
  stop("No 2020 Census blocks were selected inside the yellow boundary.")
}

# Counts come from the block_geoid_2020 field in the 2020-block incident CSV.
incident_counts_by_2020_block <- incidents_with_coordinates %>%
  filter(!is.na(block_geoid_2020)) %>%
  count(block_geoid_2020, name = "historical_incident_count")

yellow_block_lookup_all <- yellow_block_lookup_all %>%
  left_join(incident_counts_by_2020_block, by = "block_geoid_2020") %>%
  mutate(historical_incident_count = replace_na(historical_incident_count, 0L))

selected_2020_ids <- yellow_block_lookup_all %>% distinct(block_geoid_2020)
incidents_in_yellow_blocks <- incidents_with_coordinates %>%
  semi_join(selected_2020_ids, by = "block_geoid_2020")

incidents_yellow_sf <- st_as_sf(
  incidents_in_yellow_blocks,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
)

# Save IDs in the input file that do not match the 2020 TIGER blocks.
incident_ids_not_in_tiger <- incidents_with_coordinates %>%
  filter(!is.na(block_geoid_2020)) %>%
  distinct(block_geoid_2020) %>%
  anti_join(
    blocks_2020_utm %>% st_drop_geometry() %>% distinct(block_geoid_2020),
    by = "block_geoid_2020"
  )
write_csv(
  incident_ids_not_in_tiger,
  file.path(OUTPUT_DIR, "Incident_2020_GEOIDs_Not_Found_In_TIGER.csv")
)

message(
  "2020 blocks inside yellow boundary: ", nrow(yellow_block_lookup_all),
  "; geocoded incident points assigned to those blocks: ", nrow(incidents_yellow_sf), "."
)

# ---------------------------------------------------------------------------
# 6. OSM DOWNLOAD HELPER AND SANTA MARGARITA RIVER
# ---------------------------------------------------------------------------

fetch_osm_lines_with_fallback <- function(key, value = NULL, bbox, label) {
  discovered <- tryCatch(as.character(osmdata::list_overpass_urls()), error = function(e) character())
  urls <- unique(c(OVERPASS_FALLBACK_URLS, discovered))
  urls <- urls[!is.na(urls) & nzchar(urls)]
  last_error <- NULL
  
  for (api_url in urls) {
    message("Requesting ", label, " from ", api_url)
    result <- tryCatch({
      osmdata::set_overpass_url(api_url)
      q <- osmdata::opq(bbox = bbox, osm_types = "way", timeout = 240)
      if (is.null(value)) {
        q <- osmdata::add_osm_feature(q, key = key)
      } else {
        q <- osmdata::add_osm_feature(q, key = key, value = value)
      }
      osmdata::osmdata_sf(q, quiet = TRUE)
    }, error = function(e) {
      last_error <<- conditionMessage(e)
      message("  Endpoint failed: ", conditionMessage(e))
      NULL
    })
    
    if (!is.null(result) && !is.null(result$osm_lines) && nrow(result$osm_lines) > 0) {
      message("  Retrieved ", nrow(result$osm_lines), " line features.")
      return(result)
    }
    Sys.sleep(1)
  }
  
  stop(
    "Unable to retrieve ", label, ". Last error: ",
    ifelse(is.null(last_error), "No line features returned", last_error)
  )
}

bbox_contains <- function(cache_bbox, requested_bbox) {
  cache_bbox <- as.numeric(cache_bbox)
  requested_bbox <- as.numeric(requested_bbox)
  length(cache_bbox) == 4 && length(requested_bbox) == 4 &&
    cache_bbox[1] <= requested_bbox[1] &&
    cache_bbox[2] <= requested_bbox[2] &&
    cache_bbox[3] >= requested_bbox[3] &&
    cache_bbox[4] >= requested_bbox[4]
}

river_bbox <- c(
  unname(MAP_EXTENT_WGS84["xmin"]),
  unname(MAP_EXTENT_WGS84["ymin"]),
  unname(MAP_EXTENT_WGS84["xmax"]),
  unname(MAP_EXTENT_WGS84["ymax"])
)
river_cache_file <- file.path(OUTPUT_DIR, "Santa_Margarita_River_Cache.rds")
river_lines <- NULL

if (USE_CACHED_OSM && file.exists(river_cache_file)) {
  cached_river <- tryCatch(readRDS(river_cache_file), error = function(e) NULL)
  if (
    is.list(cached_river) && !is.null(cached_river$bbox) &&
    !is.null(cached_river$river_lines) &&
    bbox_contains(cached_river$bbox, river_bbox)
  ) {
    river_lines <- cached_river$river_lines
    message("Loaded cached Santa Margarita River features.")
  }
}

if (is.null(river_lines)) {
  river_result <- fetch_osm_lines_with_fallback(
    key = "waterway", value = "river", bbox = river_bbox,
    label = "Santa Margarita River"
  )
  river_lines <- river_result$osm_lines
  if (USE_CACHED_OSM && nrow(river_lines) > 0) {
    saveRDS(list(bbox = as.numeric(river_bbox), river_lines = river_lines), river_cache_file)
  }
}

if (!"name" %in% names(river_lines)) stop("OSM river response has no name field.")
osm_santa_margarita <- river_lines %>%
  filter(str_detect(coalesce(as.character(name), ""), regex("Santa Margarita", ignore_case = TRUE))) %>%
  st_transform(4326)
if (nrow(osm_santa_margarita) == 0) {
  stop("No named Santa Margarita River line was found in the OSM river response.")
}
river_centerline_utm <- st_union(st_geometry(st_transform(osm_santa_margarita, 26911)))

# ---------------------------------------------------------------------------
# 7. CLASSIFY 2020 BLOCKS NORTH/SOUTH OF THE RIVER
# ---------------------------------------------------------------------------

nearest_point_on_river_xy <- function(point_geometry, river_geometry) {
  connector <- st_nearest_points(point_geometry, river_geometry)
  cc <- st_coordinates(connector)
  c(X = cc[nrow(cc), "X"], Y = cc[nrow(cc), "Y"])
}

block_side_points <- st_as_sf(
  yellow_block_lookup_all,
  coords = c("block_point_lon", "block_point_lat"),
  crs = 4326,
  remove = FALSE
) %>% st_transform(26911)
block_xy_utm <- st_coordinates(block_side_points)
nearest_river_xy <- t(vapply(
  seq_len(nrow(block_side_points)),
  function(i) nearest_point_on_river_xy(st_geometry(block_side_points)[i], river_centerline_utm),
  FUN.VALUE = c(X = 0, Y = 0)
))

block_side_lookup <- tibble(
  block_geoid_2020 = yellow_block_lookup_all$block_geoid_2020,
  tract_geoid_2020 = yellow_block_lookup_all$tract_geoid_2020,
  historical_incident_count = yellow_block_lookup_all$historical_incident_count,
  river_distance_m = as.numeric(st_distance(block_side_points, river_centerline_utm)),
  northing_offset_m = block_xy_utm[, "Y"] - nearest_river_xy[, "Y"]
) %>%
  mutate(
    river_side = case_when(
      northing_offset_m > RIVER_SIDE_REVIEW_BAND_M ~ "North of river",
      northing_offset_m < -RIVER_SIDE_REVIEW_BAND_M ~ "South of river",
      TRUE ~ "Near river - review"
    )
  )

write_csv(block_side_lookup, file.path(OUTPUT_DIR, "2020_Census_Block_River_Side_Classification.csv"))
write_csv(block_side_lookup %>% count(river_side, name = "census_blocks"),
          file.path(OUTPUT_DIR, "2020_Census_Block_River_Side_Summary.csv"))

north_block_ids <- block_side_lookup %>%
  filter(river_side == "North of river") %>%
  distinct(block_geoid_2020)
if (nrow(north_block_ids) == 0) stop("No 2020 Census blocks classified north of the river.")

yellow_blocks_north <- yellow_blocks_all %>%
  semi_join(north_block_ids, by = "block_geoid_2020")
yellow_block_lookup_north <- yellow_block_lookup_all %>%
  semi_join(north_block_ids, by = "block_geoid_2020")

near_river_blocks <- block_side_lookup %>% filter(river_side == "Near river - review")
if (nrow(near_river_blocks) > 0) {
  warning(
    nrow(near_river_blocks),
    " 2020 blocks are within +/- ", RIVER_SIDE_REVIEW_BAND_M,
    " m of the river and are held out pending review. See the river-side CSV."
  )
}
message(
  "2020 blocks retained north of river: ", nrow(yellow_block_lookup_north),
  "; south excluded: ", sum(block_side_lookup$river_side == "South of river"),
  "; near-river held out: ", nrow(near_river_blocks), "."
)

# A visual QA map for the north/south decision uses WGS84 coordinates.
yellow_blocks_side_map <- yellow_blocks_all %>%
  left_join(block_side_lookup %>% select(block_geoid_2020, river_side), by = "block_geoid_2020") %>%
  st_transform(4326)
yellow_blocks_side_check_map <- ggplot() +
  geom_sf(data = yellow_blocks_side_map, aes(fill = river_side), color = "grey45", linewidth = 0.2) +
  geom_sf(data = osm_santa_margarita, color = "deepskyblue3", linewidth = 1.1) +
  geom_sf(data = yellow_area_wgs84, fill = NA, color = "#C99000", linetype = "dashed", linewidth = 0.9) +
  scale_fill_manual(
    values = c(
      "North of river" = "#78B957",
      "South of river" = "#E76F51",
      "Near river - review" = "#F5E65B"
    ),
    na.value = "grey80"
  ) +
  coord_sf(
    crs = st_crs(4326), default_crs = st_crs(4326),
    xlim = unname(c(MAP_EXTENT_WGS84["xmin"], MAP_EXTENT_WGS84["xmax"])),
    ylim = unname(c(MAP_EXTENT_WGS84["ymin"], MAP_EXTENT_WGS84["ymax"])),
    expand = FALSE
  ) +
  labs(
    title = "2020 Census Blocks by Side of Santa Margarita River",
    subtitle = "Green = retained north-side blocks; red = excluded south-side blocks; yellow = review band",
    fill = "River position", x = "Longitude", y = "Latitude"
  ) + theme_bw()

ggsave(
  file.path(OUTPUT_DIR, "North_South_2020_Block_Classification_Check.png"),
  yellow_blocks_side_check_map, width = 12, height = 10, dpi = 300
)

incidents_yellow_north <- incidents_yellow_sf %>%
  filter(block_geoid_2020 %in% north_block_ids$block_geoid_2020) %>%
  st_transform(4326)

# ---------------------------------------------------------------------------
# 8. LOCATE SPECIAL TARGET 2020 BLOCK SPATIALLY
# ---------------------------------------------------------------------------

special_target_point_wgs84 <- st_sfc(
  st_point(c(SPECIAL_TARGET_LON, SPECIAL_TARGET_LAT)),
  crs = 4326
)
special_target_point_utm <- st_transform(special_target_point_wgs84, 26911)

special_idx <- st_within(special_target_point_utm, st_transform(yellow_blocks_north, 26911))[[1]]
if (length(special_idx) == 0) {
  special_idx <- st_intersects(special_target_point_utm, st_transform(yellow_blocks_north, 26911))[[1]]
}
if (length(special_idx) != 1) {
  stop(
    "The user-designated Rock Mountain coordinate must identify exactly one north-side 2020 Census block. Candidates found: ",
    length(special_idx),
    ". Inspect the coordinate and 2020 block boundary before proceeding."
  )
}
SPECIAL_TARGET_BLOCK_GEOID <- yellow_blocks_north$block_geoid_2020[special_idx]
message("Special Rock Mountain destination belongs to 2020 block: ", SPECIAL_TARGET_BLOCK_GEOID)

# ---------------------------------------------------------------------------
# 9. GEOCODE THE THREE ORDERED DETOUR WAYPOINTS
# ---------------------------------------------------------------------------

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

waypoint_cache_file <- file.path(OUTPUT_DIR, "Flooded_Detour_Waypoints_Cache.rds")
detour_waypoints_geocoded <- NULL
if (USE_CACHED_OSM && file.exists(waypoint_cache_file)) {
  cached_waypoints <- tryCatch(readRDS(waypoint_cache_file), error = function(e) NULL)
  if (is.data.frame(cached_waypoints) && nrow(cached_waypoints) == 3 &&
      all(c("stop_order", "stop_name", "longitude", "latitude") %in% names(cached_waypoints))) {
    detour_waypoints_geocoded <- as_tibble(cached_waypoints)
    message("Loaded cached detour waypoint geocoding.")
  }
}
if (is.null(detour_waypoints_geocoded)) {
  message("Geocoding De Luz, Camaron, and Sandia Creek/Rock Mountain waypoints...")
  detour_waypoints_geocoded <- tidygeocoder::geocode(
    detour_waypoint_addresses,
    address = address,
    method = "arcgis",
    lat = "latitude",
    long = "longitude"
  ) %>%
    arrange(stop_order) %>%
    mutate(
      longitude = as.numeric(longitude),
      latitude = as.numeric(latitude)
    )
  if (USE_CACHED_OSM) saveRDS(detour_waypoints_geocoded, waypoint_cache_file)
}
if (
  nrow(detour_waypoints_geocoded) != 3 ||
  any(!is.finite(detour_waypoints_geocoded$longitude)) ||
  any(!is.finite(detour_waypoints_geocoded$latitude))
) {
  stop("One or more flooded-detour waypoints failed to geocode.")
}

# ---------------------------------------------------------------------------
# 10. DOWNLOAD/CACHE OSM ROAD NETWORK
# ---------------------------------------------------------------------------

route_input_coords <- bind_rows(
  ncfpd1_origin_row %>% transmute(lon = origin_lon, lat = origin_lat),
  temecula_origin_row %>% transmute(lon = origin_lon, lat = origin_lat),
  detour_waypoints_geocoded %>% transmute(lon = longitude, lat = latitude),
  I15_STATION_WAYPOINTS %>%
    transmute(
      lon = longitude,
      lat = latitude
    ),
  yellow_block_lookup_north %>% transmute(lon = block_point_lon, lat = block_point_lat),
  tibble(lon = SPECIAL_TARGET_LON, lat = SPECIAL_TARGET_LAT)
) %>% filter(is.finite(lon), is.finite(lat))

road_bbox <- c(
  min(route_input_coords$lon) - OSM_BBOX_PADDING_DEG,
  min(route_input_coords$lat) - OSM_BBOX_PADDING_DEG,
  max(route_input_coords$lon) + OSM_BBOX_PADDING_DEG,
  max(route_input_coords$lat) + OSM_BBOX_PADDING_DEG
)

road_cache_file <- file.path(OUTPUT_DIR, "OSM_Roads_Cache.rds")
osm_roads <- NULL

# Search current output folder and project subfolders for any earlier larger
# cache that contains the new query area.
if (USE_CACHED_OSM) {
  cache_candidates <- unique(list.files(
    path = ".", pattern = "^OSM_Roads_Cache\\.rds$",
    recursive = TRUE, full.names = TRUE
  ))
  for (cache_path in cache_candidates) {
    cached_roads <- tryCatch(readRDS(cache_path), error = function(e) NULL)
    if (
      is.list(cached_roads) && !is.null(cached_roads$bbox) &&
      !is.null(cached_roads$osm_roads) && bbox_contains(cached_roads$bbox, road_bbox)
    ) {
      osm_roads <- cached_roads$osm_roads
      message("Loaded OSM road cache: ", cache_path)
      break
    }
  }
}

if (is.null(osm_roads)) {
  message("Downloading OSM road network for the 2020 north-side study area...")
  road_result <- fetch_osm_lines_with_fallback(
    key = "highway", value = NULL, bbox = road_bbox,
    label = "OSM road network"
  )
  osm_roads <- road_result$osm_lines
  if (USE_CACHED_OSM && nrow(osm_roads) > 0) {
    saveRDS(list(bbox = as.numeric(road_bbox), osm_roads = osm_roads), road_cache_file)
    message("Saved OSM road cache: ", road_cache_file)
  }
}

if (is.null(osm_roads) || nrow(osm_roads) == 0) stop("OSM road query returned no line features.")
osm_roads <- osm_roads %>%
  st_zm(drop = TRUE, what = "ZM") %>%
  filter(!st_is_empty(geometry)) %>%
  mutate(osm_id = as.character(osm_id))
if (!"highway" %in% names(osm_roads)) stop("OSM road features lack the highway field.")
if (!"name" %in% names(osm_roads)) osm_roads$name <- NA_character_
# Retain interstate route-reference tags for identifying I-15.
if (!"ref" %in% names(osm_roads)) {
  osm_roads$ref <- NA_character_
}

if (!"int_ref" %in% names(osm_roads)) {
  osm_roads$int_ref <- NA_character_
}
required_crossing_ids <- c(DE_LUZ_BRIDGE_OSM_ID, CURRENT_SANDIA_BRIDGE_OSM_ID)
missing_required_ids <- setdiff(required_crossing_ids, osm_roads$osm_id)
if (length(missing_required_ids) > 0) {
  stop("OSM road query did not return required crossing OSM IDs: ", paste(missing_required_ids, collapse = ", "))
}

# ============================================================================
# 11. CLEAN MOTORCAR ROADS, AUDIT RIVER CONTACTS, AND BUILD FOUR NETWORKS
# ============================================================================

# ============================================================================
# 11A. CLEAN OSM ROAD ATTRIBUTES
# ============================================================================

clean_osm_maxspeed <- function(x) {
  
  if (!"maxspeed" %in% names(x)) {
    x$maxspeed <- NA_character_
  }
  
  raw_speed <- trimws(as.character(x$maxspeed))
  
  numeric_speed <- suppressWarnings(
    readr::parse_number(raw_speed)
  )
  
  mph_rows <- !is.na(raw_speed) &
    str_detect(str_to_lower(raw_speed), "mph")
  
  numeric_speed[mph_rows] <-
    numeric_speed[mph_rows] * 1.609344
  
  valid_speed <- is.finite(numeric_speed) &
    numeric_speed > 0
  
  x$maxspeed <- ifelse(
    valid_speed,
    as.character(numeric_speed),
    NA_character_
  )
  
  x
}


# Ensure optional OSM attributes exist.
roads_tagged <- clean_osm_maxspeed(osm_roads)

optional_osm_fields <- c(
  "name",
  "ref",
  "int_ref",
  "bridge",
  "layer",
  "surface",
  "oneway",
  "access",
  "vehicle",
  "motor_vehicle",
  "motorcar",
  "ford"
)

for (field in optional_osm_fields) {
  
  if (!field %in% names(roads_tagged)) {
    roads_tagged[[field]] <- NA_character_
  }
}

access_fields <- c(
  "access",
  "vehicle",
  "motor_vehicle",
  "motorcar",
  "ford"
)

roads_tagged <- roads_tagged %>%
  mutate(
    across(
      all_of(access_fields),
      ~ str_to_lower(trimws(as.character(.x)))
    ),
    across(
      all_of(c("name", "ref", "int_ref", "bridge", "layer")),
      ~ trimws(as.character(.x))
    ),
    highway_clean = str_to_lower(
      trimws(as.character(highway))
    ),
    osm_id = as.character(osm_id)
  )


# ============================================================================
# 11B. IDENTIFY MOTORCAR-ACCESSIBLE ROAD FEATURES
# ============================================================================

motorcar_profile <-
  dodgr::weighting_profiles$weighting_profiles %>%
  filter(name == "motorcar")

motorcar_types <- unique(
  as.character(motorcar_profile$way)
)

nonmotorized_highways <- c(
  "footway",
  "path",
  "pedestrian",
  "steps",
  "bridleway",
  "cycleway"
)

restricted_access_values <- c(
  "no",
  "private"
)

roads_vehicle_all <- roads_tagged %>%
  filter(
    !is.na(highway_clean),
    highway_clean %in% motorcar_types,
    !highway_clean %in% nonmotorized_highways,
    
    is.na(ford) | ford %in% c("", "no"),
    
    if_all(
      all_of(
        c(
          "access",
          "vehicle",
          "motor_vehicle",
          "motorcar"
        )
      ),
      ~ is.na(.x) |
        !.x %in% restricted_access_values
    ),
    
    osm_id != UNVERIFIED_TRACK_CROSSING_OSM_ID
  ) %>%
  select(-highway_clean) %>%
  mutate(osm_id = as.character(osm_id))

if (nrow(roads_vehicle_all) == 0) {
  stop("Motorcar road filtering returned an empty road network.")
}

message(
  "OSM road features: ", nrow(osm_roads),
  "; retained motorcar features: ", nrow(roads_vehicle_all)
)


# ============================================================================
# 11C. AUDIT ALL ROAD FEATURES THAT TOUCH OR CROSS THE RIVER CENTERLINE
# ============================================================================

osm_roads_utm <- st_transform(
  osm_roads,
  26911
)

all_centerline_contacts <- lengths(
  st_intersects(
    osm_roads_utm,
    river_centerline_utm
  )
) > 0

all_centerline_crosses <- lengths(
  st_crosses(
    osm_roads_utm,
    river_centerline_utm
  )
) > 0

river_way_audit <- osm_roads_utm %>%
  mutate(
    touches_river_centerline = all_centerline_contacts,
    crosses_river_centerline = all_centerline_crosses,
    osm_id = as.character(osm_id)
  ) %>%
  filter(
    touches_river_centerline |
      crosses_river_centerline
  ) %>%
  st_drop_geometry() %>%
  select(
    any_of(
      c(
        "osm_id",
        "name",
        "ref",
        "int_ref",
        "highway",
        "bridge",
        "layer",
        "ford",
        "access",
        "touches_river_centerline",
        "crosses_river_centerline"
      )
    )
  ) %>%
  mutate(
    osm_id = as.character(osm_id),
    
    approved_crossing =
      osm_id %in% APPROVED_RIVER_CROSSING_IDS,
    
    study_decision = case_when(
      osm_id == DE_LUZ_BRIDGE_OSM_ID ~
        "Retain for De Luz detour crossing",
      
      osm_id == CURRENT_SANDIA_BRIDGE_OSM_ID ~
        "Retain normal; remove during closure",
      
      osm_id == UNVERIFIED_TRACK_CROSSING_OSM_ID ~
        "Exclude unverified track crossing",
      
      TRUE ~
        "Exclude unapproved river contact/crossing"
    )
  )

write_csv(
  river_way_audit,
  file.path(
    OUTPUT_DIR,
    "2020_OSM_River_Way_Audit.csv"
  )
)

print(river_way_audit)


# ============================================================================
# 11D. BUILD THE VERIFIED NORMAL AND CLOSURE-PREFIX NETWORKS
# ============================================================================

# Every motorcar road touching the river centerline must be one of the
# two previously approved crossings.

river_contact_ids <- unique(
  as.character(river_way_audit$osm_id)
)

unapproved_river_contact_ids <- setdiff(
  river_contact_ids,
  APPROVED_RIVER_CROSSING_IDS
)

roads_vehicle_verified <- roads_vehicle_all %>%
  filter(
    !osm_id %in% unapproved_river_contact_ids,
    osm_id != UNVERIFIED_TRACK_CROSSING_OSM_ID
  )

# Verify both approved bridge features exist in the motorcar network.
if (!DE_LUZ_BRIDGE_OSM_ID %in% roads_vehicle_verified$osm_id) {
  stop("Verified De Luz bridge was removed from the motorcar network.")
}

if (!CURRENT_SANDIA_BRIDGE_OSM_ID %in% roads_vehicle_verified$osm_id) {
  stop("Current Sandia Creek bridge was removed from the normal network.")
}

# Normal network: both approved bridges available.
roads_normal_final <- roads_vehicle_verified

# Closure-prefix network: remove current Sandia Creek bridge.
# De Luz remains available as the only permitted river crossing.
roads_closed_prefix <- roads_vehicle_verified %>%
  filter(
    osm_id != CURRENT_SANDIA_BRIDGE_OSM_ID
  )


# ============================================================================
# 11E. VERIFY THE NORMAL AND CLOSURE-PREFIX CROSSING RESTRICTIONS
# ============================================================================

check_remaining_contacts <- function(
    roads_sf,
    label
) {
  
  roads_utm <- st_transform(
    roads_sf,
    26911
  )
  
  hit <- lengths(
    st_intersects(
      roads_utm,
      river_centerline_utm
    )
  ) > 0
  
  ids <- unique(
    as.character(roads_sf$osm_id[hit])
  )
  
  unexpected <- setdiff(
    ids,
    APPROVED_RIVER_CROSSING_IDS
  )
  
  if (length(unexpected) > 0) {
    
    stop(
      label,
      " still contains unapproved river-contact ways: ",
      paste(unexpected, collapse = ", ")
    )
  }
  
  ids
}

normal_contact_ids <- check_remaining_contacts(
  roads_normal_final,
  "Normal network"
)

closure_contact_ids <- check_remaining_contacts(
  roads_closed_prefix,
  "Closure-prefix network"
)

if (!setequal(
  closure_contact_ids,
  DE_LUZ_BRIDGE_OSM_ID
)) {
  
  stop(
    "Closure-prefix network must contain only the De Luz crossing. Found: ",
    paste(closure_contact_ids, collapse = ", ")
  )
}


# ============================================================================
# 11F. EXPORT ORIGINAL BRIDGE-CROSSING DECISIONS
# ============================================================================

crossing_decision_audit <- tibble(
  
  osm_id = c(
    UNVERIFIED_TRACK_CROSSING_OSM_ID,
    DE_LUZ_BRIDGE_OSM_ID,
    CURRENT_SANDIA_BRIDGE_OSM_ID
  ),
  
  feature = c(
    "Unverified track crossing",
    "De Luz Road bridge",
    "Current Sandia Creek Drive bridge"
  ),
  
  in_normal_network = c(
    UNVERIFIED_TRACK_CROSSING_OSM_ID %in% roads_normal_final$osm_id,
    DE_LUZ_BRIDGE_OSM_ID %in% roads_normal_final$osm_id,
    CURRENT_SANDIA_BRIDGE_OSM_ID %in% roads_normal_final$osm_id
  ),
  
  in_closure_prefix = c(
    UNVERIFIED_TRACK_CROSSING_OSM_ID %in% roads_closed_prefix$osm_id,
    DE_LUZ_BRIDGE_OSM_ID %in% roads_closed_prefix$osm_id,
    CURRENT_SANDIA_BRIDGE_OSM_ID %in% roads_closed_prefix$osm_id
  )
)

write_csv(
  crossing_decision_audit,
  file.path(
    OUTPUT_DIR,
    "River_Crossing_Network_Decisions.csv"
  )
)


# ============================================================================
# 11G. BUILD THE SEPARATE I-15 ALTERNATIVE ACCESS NETWORK
# ============================================================================

# IMPORTANT:
# The I-15 alternative is NOT assigned arbitrary river-crossing IDs.
#
# All road features touching the Santa Margarita River centerline are
# excluded from this independent network.
#
# The I-15/Rancho California/Avenida del Oro/Sandia Creek corridor is
# retained as ordinary motorcar road geometry.
#
# The intended route is subsequently checked against the actual reconstructed
# dodgr path in Section 21.

i15_prohibited_ids <- unique(
  c(
    river_contact_ids,
    DE_LUZ_BRIDGE_OSM_ID,
    CURRENT_SANDIA_BRIDGE_OSM_ID,
    UNVERIFIED_TRACK_CROSSING_OSM_ID
  )
)

roads_i15_access <- roads_vehicle_all %>%
  filter(
    !osm_id %in% i15_prohibited_ids
  )

if (nrow(roads_i15_access) == 0) {
  stop("I-15 alternative motorcar network is empty.")
}

# Explicitly confirm that both existing bridges are excluded.
if (
  any(
    c(
      DE_LUZ_BRIDGE_OSM_ID,
      CURRENT_SANDIA_BRIDGE_OSM_ID
    ) %in% roads_i15_access$osm_id
  )
) {
  stop(
    "De Luz or current Sandia Creek bridge unexpectedly remains ",
    "in the I-15 alternative network."
  )
}

# Explicitly verify that no river-centerline contacts remain.
roads_i15_access_utm <- st_transform(
  roads_i15_access,
  26911
)

i15_remaining_contacts <- lengths(
  st_intersects(
    roads_i15_access_utm,
    river_centerline_utm
  )
) > 0

if (any(i15_remaining_contacts)) {
  stop(
    "I-15 alternative network contains road features ",
    "intersecting the Santa Margarita River centerline."
  )
}

message(
  "I-15 alternative road features: ",
  nrow(roads_i15_access),
  "; remaining river-centerline contacts: ",
  sum(i15_remaining_contacts)
)


# ============================================================================
# 11H. IDENTIFY ROADS FOR THE INTENDED I-15 CORRIDOR
# ============================================================================

# Ensure that the optional road reference columns are available.
# These fields are retained for road identification and QA.

i15_motorway_features <- roads_i15_access %>%
  filter(
    as.character(highway) == "motorway"
  )

i15_ramp_features <- roads_i15_access %>%
  filter(
    as.character(highway) == "motorway_link"
  )

i15_rancho_features <- roads_i15_access %>%
  filter(
    str_detect(
      coalesce(as.character(name), ""),
      regex("Rancho California", ignore_case = TRUE)
    )
  )

i15_avenida_features <- roads_i15_access %>%
  filter(
    str_detect(
      coalesce(as.character(name), ""),
      regex(
        "Avenida.*Oro|Ave.*Oro",
        ignore_case = TRUE
      )
    )
  )

i15_sandia_features <- roads_i15_access %>%
  filter(
    str_detect(
      coalesce(as.character(name), ""),
      regex("Sandia Creek", ignore_case = TRUE)
    )
  )

# Inventory the roads available for the intended route.
i15_named_road_audit <- tibble(
  
  intended_road = c(
    "I-15 motorway",
    "I-15 ramps",
    "Rancho California Road",
    "Avenida del Oro",
    "Sandia Creek Drive"
  ),
  
  retained_osm_segments = c(
    nrow(i15_motorway_features),
    nrow(i15_ramp_features),
    nrow(i15_rancho_features),
    nrow(i15_avenida_features),
    nrow(i15_sandia_features)
  )
)

write_csv(
  i15_named_road_audit,
  file.path(
    OUTPUT_DIR,
    "I15_Intended_Road_Network_Audit.csv"
  )
)

print(i15_named_road_audit)

# Do not stop merely because a name search fails.
# A road may have incomplete OSM naming attributes. The actual waypoint
# snapping and route-geometry validation will determine whether the intended
# corridor is present and connected.

if (nrow(i15_motorway_features) == 0) {
  stop("No motorway features remain in the I-15 alternative network.")
}


# ============================================================================
# 11I. EXPORT I-15 RIVER-CONTACT DECISIONS
# ============================================================================

i15_river_contact_audit <- river_way_audit %>%
  mutate(
    retained_in_i15_network =
      osm_id %in% roads_i15_access$osm_id,
    
    decision = case_when(
      
      osm_id == DE_LUZ_BRIDGE_OSM_ID ~
        "Excluded: De Luz bridge is not part of I-15 alternative",
      
      osm_id == CURRENT_SANDIA_BRIDGE_OSM_ID ~
        "Excluded: closed Sandia Creek bridge",
      
      osm_id == UNVERIFIED_TRACK_CROSSING_OSM_ID ~
        "Excluded: unverified crossing",
      
      retained_in_i15_network ~
        "Retained in I-15 alternative",
      
      TRUE ~
        "Excluded: river-centerline contact"
    )
  )

write_csv(
  i15_river_contact_audit,
  file.path(
    OUTPUT_DIR,
    "I15_Alternative_River_Contact_Audit.csv"
  )
)


# ============================================================================
# 11J. FINAL SECTION 11 QUALITY CHECKS
# ============================================================================

stopifnot(
  
  nrow(roads_vehicle_all) > 0,
  
  nrow(roads_vehicle_verified) > 0,
  
  nrow(roads_normal_final) > 0,
  
  nrow(roads_closed_prefix) > 0,
  
  nrow(roads_i15_access) > 0,
  
  DE_LUZ_BRIDGE_OSM_ID %in%
    roads_normal_final$osm_id,
  
  CURRENT_SANDIA_BRIDGE_OSM_ID %in%
    roads_normal_final$osm_id,
  
  DE_LUZ_BRIDGE_OSM_ID %in%
    roads_closed_prefix$osm_id,
  
  !CURRENT_SANDIA_BRIDGE_OSM_ID %in%
    roads_closed_prefix$osm_id,
  
  !DE_LUZ_BRIDGE_OSM_ID %in%
    roads_i15_access$osm_id,
  
  !CURRENT_SANDIA_BRIDGE_OSM_ID %in%
    roads_i15_access$osm_id,
  
  !UNVERIFIED_TRACK_CROSSING_OSM_ID %in%
    roads_i15_access$osm_id,
  
  !any(i15_remaining_contacts)
)

message("============================================================")
message("SECTION 11 COMPLETE")
message("Motorcar road features: ", nrow(roads_vehicle_all))
message("Verified vehicle features: ", nrow(roads_vehicle_verified))
message("Normal network: ", nrow(roads_normal_final))
message("De Luz closure-prefix network: ", nrow(roads_closed_prefix))
message("I-15 alternative network: ", nrow(roads_i15_access))
message("Normal river contacts: ", length(normal_contact_ids))
message("Closure-prefix river contacts: ", length(closure_contact_ids))
message("I-15 river contacts: ", sum(i15_remaining_contacts))
message("============================================================")

# ---------------------------------------------------------------------------
# 12. BUILD A STRICT NORTH-SIDE-ONLY MOTORCAR ROAD NETWORK
# ---------------------------------------------------------------------------

# The final north-side graph deliberately excludes ALL road features inside a
# 30 m river buffer and keeps only features whose representative point lies
# north of the river. Thus this graph cannot use the De Luz bridge, the closed
# Sandia bridge, or another mapped river-crossing segment.
roads_vehicle_utm <- st_transform(roads_vehicle_verified, 26911)
river_buffer_utm <- st_buffer(river_centerline_utm, NORTH_ROAD_RIVER_BUFFER_M)
road_midpoints_utm <- st_point_on_surface(roads_vehicle_utm)
road_mid_xy <- st_coordinates(road_midpoints_utm)

# # Vectorized nearest-point connectors from each road midpoint to the river.
river_geometry_repeated <- river_centerline_utm[
  rep(1, nrow(road_midpoints_utm))
]

road_to_river_connectors <- st_nearest_points(
  st_geometry(road_midpoints_utm),
  river_geometry_repeated,
  by_element = TRUE
)

# Extract river-side endpoint coordinates with explicit X/Y names.
road_nearest_river_xy <- t(vapply(
  seq_along(road_to_river_connectors),
  function(i) {
    
    g <- road_to_river_connectors[i]
    
    if (st_is_empty(g)) {
      return(c(X = NA_real_, Y = NA_real_))
    }
    
    cc <- st_coordinates(g)
    
    if (!all(c("X", "Y") %in% colnames(cc))) {
      stop(
        "Nearest-river connector ", i,
        " does not contain valid X/Y coordinates."
      )
    }
    
    c(
      X = as.numeric(cc[nrow(cc), "X"]),
      Y = as.numeric(cc[nrow(cc), "Y"])
    )
  },
  FUN.VALUE = c(X = 0, Y = 0)
))

# Explicitly preserve coordinate column names.
colnames(road_nearest_river_xy) <- c("X", "Y")

# Validate coordinate extraction before classifying roads.
if (
  nrow(road_nearest_river_xy) != nrow(road_mid_xy) ||
  any(!is.finite(road_nearest_river_xy))
) {
  stop(
    "Invalid nearest-river coordinates. Check road geometries ",
    "and nearest-point connectors."
  )
}

# Calculate northing offset relative to the nearest river point.
road_northing_offset_m <-
  road_mid_xy[, "Y"] - road_nearest_river_xy[, "Y"]

road_touches_river_buffer <- lengths(
  st_intersects(roads_vehicle_utm, river_buffer_utm)
) > 0
road_touches_river_buffer <- lengths(st_intersects(roads_vehicle_utm, river_buffer_utm)) > 0

north_side_keep <-
  road_northing_offset_m > NORTH_ROAD_SIDE_MARGIN_M &
  !road_touches_river_buffer &
  !roads_vehicle_verified$osm_id %in% APPROVED_RIVER_CROSSING_IDS

roads_north_side <- roads_vehicle_verified[north_side_keep, ]
if (nrow(roads_north_side) == 0) {
  stop("North-side-only motorcar road network is empty. Review river geometry and road-side settings.")
}

# Hard validation: no road in the final-approach graph may intersect the river buffer.
roads_north_side_utm <- st_transform(roads_north_side, 26911)
north_graph_river_contacts <- lengths(st_intersects(roads_north_side_utm, river_buffer_utm)) > 0
if (any(north_graph_river_contacts)) {
  stop("The north-side-only road graph still contains road features intersecting the river buffer.")
}

north_side_road_audit <- tibble(
  osm_id = as.character(roads_vehicle_verified$osm_id),
  name = as.character(roads_vehicle_verified$name),
  highway = as.character(roads_vehicle_verified$highway),
  northing_offset_m = road_northing_offset_m,
  intersects_river_buffer = road_touches_river_buffer,
  retained_in_north_graph = north_side_keep
)
write_csv(north_side_road_audit, file.path(OUTPUT_DIR, "North_Side_Road_Network_Audit.csv"))

message(
  "Vehicle road features: ", nrow(roads_vehicle_verified),
  "; north-side-only features: ", nrow(roads_north_side),
  "; features excluded from north-only graph because of river buffer/side: ",
  sum(!north_side_keep), "."
)


# ============================================================================
# 13. SNAP 2020 BLOCK DESTINATIONS, HARRIS TRAIL, AND RESPONSE ORIGINS
# ============================================================================

# ---------------------------------------------------------------------------
# 13A. GENERAL ROAD-SNAPPING FUNCTION
# ---------------------------------------------------------------------------

snap_points_to_named_road <- function(
    points_df,
    roads_sf,
    lon_col,
    lat_col,
    id_col = NULL,
    name_filter = NULL
) {
  
  # Validate input data.
  if (!inherits(roads_sf, "sf")) {
    stop("roads_sf must be an sf object.")
  }
  
  if (nrow(points_df) == 0) {
    stop("No input points were supplied for road snapping.")
  }
  
  required_coordinate_columns <- c(lon_col, lat_col)
  
  if (!all(required_coordinate_columns %in% names(points_df))) {
    stop(
      "Missing coordinate columns: ",
      paste(
        setdiff(required_coordinate_columns, names(points_df)),
        collapse = ", "
      )
    )
  }
  
  if (!is.null(id_col) && !id_col %in% names(points_df)) {
    stop("The specified id_col does not exist in points_df.")
  }
  
  # Optionally restrict candidate roads by name.
  roads_use <- roads_sf
  
  if (!is.null(name_filter)) {
    roads_use <- roads_use %>%
      filter(
        str_detect(
          coalesce(as.character(name), ""),
          regex(name_filter, ignore_case = TRUE)
        )
      )
  }
  
  # Remove empty geometries.
  roads_use <- roads_use[!st_is_empty(roads_use), ]
  
  if (nrow(roads_use) == 0) {
    stop("No usable road features found for snap: ", name_filter)
  }
  
  # Validate input coordinates.
  input_lon <- suppressWarnings(
    as.numeric(points_df[[lon_col]])
  )
  
  input_lat <- suppressWarnings(
    as.numeric(points_df[[lat_col]])
  )
  
  if (
    any(!is.finite(input_lon)) ||
    any(!is.finite(input_lat))
  ) {
    stop("One or more input points have invalid longitude/latitude values.")
  }
  
  if (
    any(abs(input_lon) > 180) ||
    any(abs(input_lat) > 90)
  ) {
    stop("One or more input coordinates fall outside valid WGS84 bounds.")
  }
  
  # Transform road features and input points to UTM.
  roads_use_utm <- st_transform(roads_use, 26911)
  
  points_utm <- st_as_sf(
    points_df,
    coords = c(lon_col, lat_col),
    crs = 4326,
    remove = FALSE
  ) %>%
    st_transform(26911)
  
  # Find the nearest road feature for each point.
  nearest_idx <- st_nearest_feature(
    points_utm,
    roads_use_utm
  )
  
  if (anyNA(nearest_idx)) {
    stop("Could not identify a nearest road feature for every point.")
  }
  
  nearest_geometries <- st_geometry(roads_use_utm)[nearest_idx]
  
  snap_xy <- matrix(
    NA_real_,
    nrow = nrow(points_df),
    ncol = 2
  )
  
  snap_distance <- rep(NA_real_, nrow(points_df))
  nearest_name <- rep(NA_character_, nrow(points_df))
  nearest_highway <- rep(NA_character_, nrow(points_df))
  
  # Calculate perpendicular projection onto the nearest road geometry.
  for (i in seq_len(nrow(points_df))) {
    
    connector <- st_nearest_points(
      st_geometry(points_utm)[i],
      nearest_geometries[i]
    )
    
    cc <- st_coordinates(connector)
    
    if (nrow(cc) < 2) {
      stop("Invalid nearest-road connector for input point ", i, ".")
    }
    
    # Final connector coordinate is the point on the road.
    road_xy <- cc[nrow(cc), 1:2]
    
    snap_xy[i, ] <- road_xy
    
    snap_distance[i] <- as.numeric(
      st_distance(
        st_geometry(points_utm)[i],
        nearest_geometries[i]
      )
    )
    
    nearest_name[i] <- as.character(
      roads_use$name[nearest_idx[i]]
    )
    
    nearest_highway[i] <- as.character(
      roads_use$highway[nearest_idx[i]]
    )
  }
  
  # Convert snapped coordinates back to WGS84.
  snap_points_wgs84 <- st_sfc(
    lapply(
      seq_len(nrow(snap_xy)),
      function(i) st_point(snap_xy[i, ])
    ),
    crs = 26911
  ) %>%
    st_transform(4326)
  
  snap_coordinates_wgs84 <- st_coordinates(
    snap_points_wgs84
  )
  
  result <- points_df %>%
    mutate(
      routing_lon = snap_coordinates_wgs84[, 1],
      routing_lat = snap_coordinates_wgs84[, 2],
      distance_to_road_m = snap_distance,
      nearest_road_name = nearest_name,
      nearest_road_highway = nearest_highway
    )
  
  # Final output validation.
  if (
    any(!is.finite(result$routing_lon)) ||
    any(!is.finite(result$routing_lat)) ||
    any(!is.finite(result$distance_to_road_m))
  ) {
    stop("Road snapping produced invalid output coordinates or distances.")
  }
  
  result
}


# ---------------------------------------------------------------------------
# 13B. HARRIS TRAIL DIAGNOSTIC ROUTING POINT
# ---------------------------------------------------------------------------

# Harris Trail coordinate is a diagnostic graph node, not a mandatory stop.
# Prefer a Harris-named road segment if one is within the snap threshold.
# Otherwise, test the nearest retained motorcar road and document its name.

harris_turn_input <- tibble(
  point_id = "HARRIS_TRAIL_TURN",
  longitude = HARRIS_TURN_LON,
  latitude = HARRIS_TURN_LAT
)

harris_road_segments <- roads_closed_prefix %>%
  filter(
    str_detect(
      coalesce(as.character(name), ""),
      regex("Harris", ignore_case = TRUE)
    )
  )

harris_named_snap <- NULL

if (nrow(harris_road_segments) > 0) {
  
  harris_named_snap <- snap_points_to_named_road(
    points_df = harris_turn_input,
    roads_sf = harris_road_segments,
    lon_col = "longitude",
    lat_col = "latitude",
    id_col = "point_id"
  )
}

# Use a Harris-named segment if it passes the configured distance threshold.
use_harris_named_snap <-
  !is.null(harris_named_snap) &&
  is.finite(harris_named_snap$distance_to_road_m[1]) &&
  harris_named_snap$distance_to_road_m[1] <= HARRIS_TURN_MAX_SNAP_M

if (use_harris_named_snap) {
  
  harris_turn_snap <- harris_named_snap
  
  harris_turn_snap_method <- "Harris-named motorcar road"
  
} else {
  
  # If no suitably close Harris-named feature exists, identify the nearest
  # retained motorcar road. This is diagnostic only; its name is documented.
  harris_turn_snap <- snap_points_to_named_road(
    points_df = harris_turn_input,
    roads_sf = roads_closed_prefix,
    lon_col = "longitude",
    lat_col = "latitude",
    id_col = "point_id"
  )
  
  harris_turn_snap_method <- "Nearest retained motorcar road; name requires review"
  
  warning(
    "Harris Trail coordinate did not snap within ",
    HARRIS_TURN_MAX_SNAP_M,
    " m of a Harris-named road. The nearest retained road is ",
    harris_turn_snap$nearest_road_name[1],
    " at ",
    round(harris_turn_snap$distance_to_road_m[1], 1),
    " m. Review the Harris Trail snap QA."
  )
}

harris_turn_snap <- harris_turn_snap %>%
  mutate(
    snap_method = harris_turn_snap_method,
    harris_name_match = str_detect(
      coalesce(as.character(nearest_road_name), ""),
      regex("Harris", ignore_case = TRUE)
    )
  )

if (
  !is.finite(harris_turn_snap$distance_to_road_m[1]) ||
  harris_turn_snap$distance_to_road_m[1] > HARRIS_TURN_MAX_SNAP_M
) {
  stop(
    "Harris Trail coordinate is too far from the retained motorcar network: ",
    round(harris_turn_snap$distance_to_road_m[1], 1),
    " m. Review Harris_Trail_Turn_Snap_QA.csv."
  )
}

harris_turn_point_wgs84 <- st_as_sf(
  harris_turn_snap,
  coords = c("routing_lon", "routing_lat"),
  crs = 4326,
  remove = FALSE
)

write_csv(
  harris_turn_snap,
  file.path(OUTPUT_DIR, "Harris_Trail_Turn_Snap_QA.csv")
)

message(
  "Harris Trail diagnostic snap: ",
  round(harris_turn_snap$distance_to_road_m[1], 1),
  " m; road = ",
  harris_turn_snap$nearest_road_name[1],
  "; method = ",
  harris_turn_snap_method,
  "."
)


# ---------------------------------------------------------------------------
# 13C. STATION 1 SNAP TO THE FLOODED-CLOSURE NETWORK
# ---------------------------------------------------------------------------

ncfpd1_flooded_point_df <- ncfpd1_origin_row %>%
  transmute(
    origin_lon,
    origin_lat
  )

ncfpd1_flooded_snapped <- snap_points_to_named_road(
  points_df = ncfpd1_flooded_point_df,
  roads_sf = roads_closed_prefix,
  lon_col = "origin_lon",
  lat_col = "origin_lat"
)

if (
  !is.finite(ncfpd1_flooded_snapped$distance_to_road_m[1]) ||
  ncfpd1_flooded_snapped$distance_to_road_m[1] >
  MAX_NCFPD_ORIGIN_SNAP_M
) {
  stop(
    "Station 1 failed its flooded-closure road snap validation: ",
    round(ncfpd1_flooded_snapped$distance_to_road_m[1], 1),
    " m."
  )
}


# ---------------------------------------------------------------------------
# 13D. SNAP ALL NORTHERN 2020 CENSUS BLOCKS TO NORTH-SIDE ROADS
# ---------------------------------------------------------------------------

yellow_block_lookup_north <- yellow_block_lookup_north %>%
  mutate(
    block_geoid_2020 = as.character(block_geoid_2020)
  )

yellow_block_lookup_north <- snap_points_to_named_road(
  points_df = yellow_block_lookup_north,
  roads_sf = roads_north_side,
  lon_col = "block_point_lon",
  lat_col = "block_point_lat",
  id_col = "block_geoid_2020"
) %>%
  mutate(
    destination_method = if_else(
      distance_to_road_m <= 25,
      "Original Census block point (within 25 m of north-side road)",
      "Nearest mapped north-side motorcar road"
    )
  )

if (
  any(!is.finite(yellow_block_lookup_north$routing_lon)) ||
  any(!is.finite(yellow_block_lookup_north$routing_lat)) ||
  any(!is.finite(yellow_block_lookup_north$distance_to_road_m))
) {
  stop("One or more northern Census blocks failed their north-side road snap.")
}


# ---------------------------------------------------------------------------
# 13E. SPECIAL BLOCK: AUDIT ROCK MOUNTAIN ROAD AND SELECT A VALID SNAP
# ---------------------------------------------------------------------------

special_target_df <- tibble(
  block_geoid_2020 = SPECIAL_TARGET_BLOCK_GEOID,
  special_lon = SPECIAL_TARGET_LON,
  special_lat = SPECIAL_TARGET_LAT
)

special_target_point_utm <- st_sfc(
  st_point(c(SPECIAL_TARGET_LON, SPECIAL_TARGET_LAT)),
  crs = 4326
) %>%
  st_transform(26911)

# Audit the nearest Rock Mountain-named road at each cleaning stage.
nearest_named_road_audit <- function(roads_sf, stage_name) {
  
  named_roads <- roads_sf %>%
    filter(
      str_detect(
        coalesce(as.character(name), ""),
        regex("Rock Mountain", ignore_case = TRUE)
      )
    )
  
  if (nrow(named_roads) == 0) {
    
    return(
      tibble(
        stage = stage_name,
        candidate_segments = 0L,
        nearest_distance_m = NA_real_,
        nearest_osm_id = NA_character_,
        nearest_road_name = NA_character_,
        nearest_highway = NA_character_,
        intersects_river_centerline = NA,
        intersects_30m_river_buffer = NA
      )
    )
  }
  
  named_roads_utm <- st_transform(named_roads, 26911)
  
  nearest_idx <- st_nearest_feature(
    special_target_point_utm,
    named_roads_utm
  )
  
  nearest_geometry <- st_geometry(named_roads_utm)[nearest_idx]
  
  tibble(
    stage = stage_name,
    candidate_segments = nrow(named_roads),
    nearest_distance_m = as.numeric(
      st_distance(special_target_point_utm, nearest_geometry)
    ),
    nearest_osm_id = as.character(named_roads$osm_id[nearest_idx]),
    nearest_road_name = as.character(named_roads$name[nearest_idx]),
    nearest_highway = as.character(named_roads$highway[nearest_idx]),
    intersects_river_centerline =
      lengths(st_intersects(nearest_geometry, river_centerline_utm)) > 0,
    intersects_30m_river_buffer =
      lengths(st_intersects(nearest_geometry, river_buffer_utm)) > 0
  )
}

special_rock_road_audit <- bind_rows(
  nearest_named_road_audit(osm_roads, "Raw OSM road layer"),
  nearest_named_road_audit(roads_vehicle_all, "Motorcar-filtered roads"),
  nearest_named_road_audit(roads_vehicle_verified, "Verified roads"),
  nearest_named_road_audit(roads_north_side, "Final north-side-only roads")
)

write_csv(
  special_rock_road_audit,
  file.path(OUTPUT_DIR, "Special_Rock_Mountain_Road_Audit.csv")
)

print(special_rock_road_audit)

# Retrieve the previously calculated snap for this block.
# This is the default north-side-only road-access destination.
special_block_default_snap <- yellow_block_lookup_north %>%
  filter(
    block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID
  )

if (nrow(special_block_default_snap) != 1) {
  stop(
    "Could not identify exactly one north-side road snap for special block ",
    SPECIAL_TARGET_BLOCK_GEOID,
    "."
  )
}

# Identify Rock Mountain-named roads actually retained in the north graph.
rock_mountain_road_segments_north <- roads_north_side %>%
  filter(
    str_detect(
      coalesce(as.character(name), ""),
      regex("Rock Mountain", ignore_case = TRUE)
    )
  )

special_named_snap <- NULL

if (nrow(rock_mountain_road_segments_north) > 0) {
  
  special_named_snap <- snap_points_to_named_road(
    points_df = special_target_df,
    roads_sf = rock_mountain_road_segments_north,
    lon_col = "special_lon",
    lat_col = "special_lat",
    id_col = "block_geoid_2020"
  )
}

# Use the named-road snap only if it passes the original 50 m requirement.
use_named_road_snap <-
  !is.null(special_named_snap) &&
  is.finite(special_named_snap$distance_to_road_m[1]) &&
  special_named_snap$distance_to_road_m[1] <= SPECIAL_TARGET_MAX_SNAP_M

if (use_named_road_snap) {
  
  special_snap <- special_named_snap
  
  special_destination_method <-
    "User-designated coordinate snapped to Rock Mountain Road (north-side network)"
  
  message(
    "Special block uses Rock Mountain Road snap: ",
    round(special_snap$distance_to_road_m[1], 1),
    " m."
  )
  
} else {
  
  # Do not create an artificial long-distance connection to Rock Mountain.
  # Retain the block's existing north-side-only road snap.
  special_snap <- special_block_default_snap
  
  special_destination_method <-
    paste(
      "Block representative point snapped to nearest north-side motorcar road;",
      "Rock Mountain named-road snap did not pass the 50 m QA check"
    )
  
  named_distance_message <- if (
    !is.null(special_named_snap) &&
    is.finite(special_named_snap$distance_to_road_m[1])
  ) {
    paste0(
      round(special_named_snap$distance_to_road_m[1], 1),
      " m"
    )
  } else {
    "no retained Rock Mountain-named segment"
  }
  
  warning(
    "Special coordinate is ",
    named_distance_message,
    " from the nearest retained Rock Mountain-named segment. ",
    "Using the block's existing north-side road snap instead. ",
    "Review Special_Rock_Mountain_Road_Audit.csv."
  )
}

# Validate the selected destination before updating the lookup.
special_snap_valid <-
  nrow(special_snap) == 1 &&
  all(
    is.finite(
      c(
        special_snap$distance_to_road_m[1],
        special_snap$routing_lon[1],
        special_snap$routing_lat[1]
      )
    )
  )

if (!special_snap_valid) {
  stop(
    "Special block does not have a valid north-side road snap. ",
    "Review the special-target and block-access QA."
  )
}

# Apply the selected special destination to the Census-block lookup.
yellow_block_lookup_north <- yellow_block_lookup_north %>%
  mutate(
    routing_lon = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_snap$routing_lon[1],
      routing_lon
    ),
    routing_lat = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_snap$routing_lat[1],
      routing_lat
    ),
    distance_to_road_m = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_snap$distance_to_road_m[1],
      distance_to_road_m
    ),
    nearest_road_name = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_snap$nearest_road_name[1],
      nearest_road_name
    ),
    nearest_road_highway = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_snap$nearest_road_highway[1],
      nearest_road_highway
    ),
    destination_method = if_else(
      block_geoid_2020 == SPECIAL_TARGET_BLOCK_GEOID,
      special_destination_method,
      destination_method
    )
  )

# Verify all block access distances against the maximum stop threshold.
if (
  any(
    yellow_block_lookup_north$distance_to_road_m >
    MAX_BLOCK_SNAP_STOP_M,
    na.rm = TRUE
  )
) {
  
  bad_blocks <- yellow_block_lookup_north %>%
    filter(
      distance_to_road_m > MAX_BLOCK_SNAP_STOP_M
    ) %>%
    select(
      block_geoid_2020,
      distance_to_road_m,
      nearest_road_name
    )
  
  write_csv(
    bad_blocks,
    file.path(OUTPUT_DIR, "Blocks_Over_Maximum_Road_Snap.csv")
  )
  
  stop(
    "One or more northern Census-block destinations are more than ",
    MAX_BLOCK_SNAP_STOP_M,
    " m from a north-side motorcar road."
  )
}

# Create the complete road-access snap review table.
block_snap_review <- yellow_block_lookup_north %>%
  select(
    block_geoid_2020,
    tract_geoid_2020,
    distance_to_road_m,
    nearest_road_name,
    nearest_road_highway,
    destination_method
  ) %>%
  arrange(desc(distance_to_road_m))

write_csv(
  block_snap_review,
  file.path(OUTPUT_DIR, "2020_North_Block_Road_Access_Snap_Review.csv")
)

if (
  any(
    yellow_block_lookup_north$distance_to_road_m >
    MAX_BLOCK_SNAP_REVIEW_M,
    na.rm = TRUE
  )
) {
  
  warning(
    sum(
      yellow_block_lookup_north$distance_to_road_m >
        MAX_BLOCK_SNAP_REVIEW_M,
      na.rm = TRUE
    ),
    " north-side block(s) are more than ",
    MAX_BLOCK_SNAP_REVIEW_M,
    " m from the nearest north-side motorcar road. ",
    "Their off-network access gaps are documented."
  )
}


# ---------------------------------------------------------------------------
# 13F. SNAP DETOUR WAYPOINTS TO THE NORTH-SIDE-ONLY NETWORK
# ---------------------------------------------------------------------------

waypoint_snap_input <- detour_waypoints_geocoded %>%
  transmute(
    stop_order,
    stop_name,
    longitude,
    latitude
  )

detour_waypoints_snapped <- snap_points_to_named_road(
  points_df = waypoint_snap_input,
  roads_sf = roads_north_side,
  lon_col = "longitude",
  lat_col = "latitude",
  id_col = "stop_name"
)

if (
  any(!is.finite(detour_waypoints_snapped$distance_to_road_m)) ||
  any(
    detour_waypoints_snapped$distance_to_road_m >
    MAX_WAYPOINT_SNAP_M
  )
) {
  
  write_csv(
    detour_waypoints_snapped,
    file.path(OUTPUT_DIR, "Detour_Waypoint_Snap_Failures.csv")
  )
  
  stop(
    "One or more detour waypoints are more than ",
    MAX_WAYPOINT_SNAP_M,
    " m from the north-side road network."
  )
}

write_csv(
  detour_waypoints_snapped,
  file.path(OUTPUT_DIR, "Detour_Waypoint_Road_Snaps.csv")
)


# ---------------------------------------------------------------------------
# 13G. SNAP STATION 1 TO THE NORMAL VERIFIED VEHICLE NETWORK
# ---------------------------------------------------------------------------

ncfpd1_point_df <- ncfpd1_origin_row %>%
  transmute(
    origin_lon,
    origin_lat
  )

ncfpd1_snapped <- snap_points_to_named_road(
  points_df = ncfpd1_point_df,
  roads_sf = roads_normal_final,
  lon_col = "origin_lon",
  lat_col = "origin_lat"
)

if (
  !is.finite(ncfpd1_snapped$distance_to_road_m[1]) ||
  ncfpd1_snapped$distance_to_road_m[1] >
  MAX_NCFPD_ORIGIN_SNAP_M
) {
  stop(
    "NCFPD Station 1 is too far from the verified normal vehicle network: ",
    round(ncfpd1_snapped$distance_to_road_m[1], 1),
    " m."
  )
}


# ---------------------------------------------------------------------------
# 13H. SNAP TEMECULA TO THE NORTH-SIDE-ONLY NETWORK
# ---------------------------------------------------------------------------

temecula_point_df <- temecula_origin_row %>%
  transmute(
    origin_lon,
    origin_lat
  )

temecula_snapped <- snap_points_to_named_road(
  points_df = temecula_point_df,
  roads_sf = roads_north_side,
  lon_col = "origin_lon",
  lat_col = "origin_lat"
)

if (
  !is.finite(temecula_snapped$distance_to_road_m[1]) ||
  temecula_snapped$distance_to_road_m[1] >
  MAX_TEMECULA_ORIGIN_SNAP_M
) {
  stop(
    "Temecula Civic Center is too far from the north-side-only vehicle network: ",
    round(temecula_snapped$distance_to_road_m[1], 1),
    " m."
  )
}

# ===========================================================================
# 13I. I-15 ALTERNATIVE: STATION AND WAYPOINT SNAPS
# ===========================================================================

# Station 1 snaps to the independent I-15 access network.
ncfpd1_i15_snapped <- snap_points_to_named_road(
  points_df = ncfpd1_origin_row %>%
    transmute(origin_lon, origin_lat),
  roads_sf = roads_i15_access,
  lon_col = "origin_lon",
  lat_col = "origin_lat"
)

if (
  !is.finite(ncfpd1_i15_snapped$distance_to_road_m[1]) ||
  ncfpd1_i15_snapped$distance_to_road_m[1] >
  MAX_NCFPD_ORIGIN_SNAP_M
) {
  stop("Station 1 failed its I-15 network snap validation.")
}

# First waypoint: station-side approach.
i15_waypoint1_input <- I15_STATION_WAYPOINTS %>%
  filter(waypoint_order == 1)

i15_waypoint1_snapped <- snap_points_to_named_road(
  points_df = i15_waypoint1_input,
  roads_sf = roads_i15_access,
  lon_col = "longitude",
  lat_col = "latitude",
  id_col = "waypoint_name"
)

# Second waypoint: snap specifically to the north-side-only road network.
# This preserves the same coordinate handoff for the final block routes.
i15_waypoint2_input <- I15_STATION_WAYPOINTS %>%
  filter(waypoint_order == 2)

i15_waypoint2_snapped <- snap_points_to_named_road(
  points_df = i15_waypoint2_input,
  roads_sf = roads_north_side,
  lon_col = "longitude",
  lat_col = "latitude",
  id_col = "waypoint_name"
)

i15_waypoints_snapped <- bind_rows(
  i15_waypoint1_snapped,
  i15_waypoint2_snapped
) %>%
  arrange(waypoint_order)

write_csv(
  i15_waypoints_snapped,
  file.path(OUTPUT_DIR, "I15_Alternative_Waypoint_Snaps.csv")
)

print(
  i15_waypoints_snapped %>%
    select(
      waypoint_order,
      waypoint_name,
      routing_lon,
      routing_lat,
      distance_to_road_m,
      nearest_road_name,
      nearest_road_highway
    )
)

if (
  any(!is.finite(i15_waypoints_snapped$distance_to_road_m)) ||
  any(
    i15_waypoints_snapped$distance_to_road_m >
    I15_WAYPOINT_MAX_SNAP_M
  )
) {
  stop(
    "One or more I-15 route waypoints exceed ",
    I15_WAYPOINT_MAX_SNAP_M,
    " m from their permitted road network. ",
    "Review I15_Alternative_Waypoint_Snaps.csv."
  )
}

# Verify the second waypoint is associated with the Sandia Creek corridor.
if (
  !str_detect(
    coalesce(i15_waypoint2_snapped$nearest_road_name[1], ""),
    regex("Sandia Creek|Avenida.*Oro", ignore_case = TRUE)
  )
) {
  stop(
    "The second I-15 waypoint did not snap to Sandia Creek Drive ",
    "or Avenida del Oro. Actual nearest road: ",
    i15_waypoint2_snapped$nearest_road_name[1],
    ". Review I15_Alternative_Waypoint_Snaps.csv."
  )
}

message("I-15 waypoint snapping completed.")


# ---------------------------------------------------------------------------
# 13I. FINAL SECTION 13 QUALITY CHECKS
# ---------------------------------------------------------------------------

stopifnot(
  nrow(yellow_block_lookup_north) > 0,
  !anyDuplicated(yellow_block_lookup_north$block_geoid_2020),
  all(is.finite(yellow_block_lookup_north$routing_lon)),
  all(is.finite(yellow_block_lookup_north$routing_lat)),
  all(is.finite(yellow_block_lookup_north$distance_to_road_m)),
  is.finite(harris_turn_snap$routing_lon[1]),
  is.finite(harris_turn_snap$routing_lat[1]),
  is.finite(ncfpd1_flooded_snapped$routing_lon[1]),
  is.finite(ncfpd1_flooded_snapped$routing_lat[1]),
  is.finite(ncfpd1_i15_snapped$routing_lon[1]),
  is.finite(ncfpd1_i15_snapped$routing_lat[1]),
  all(is.finite(i15_waypoints_snapped$routing_lon)),
  all(is.finite(i15_waypoints_snapped$routing_lat)),
  is.finite(ncfpd1_snapped$routing_lon[1]),
  is.finite(ncfpd1_snapped$routing_lat[1]),
  is.finite(temecula_snapped$routing_lon[1]),
  is.finite(temecula_snapped$routing_lat[1])
)

message("============================================================")
message("SECTION 13 COMPLETE")
message("Northern Census blocks snapped: ", nrow(yellow_block_lookup_north))
message(
  "Special block: ", SPECIAL_TARGET_BLOCK_GEOID,
  "; road: ", special_snap$nearest_road_name[1]
)
message(
  "Harris Trail snap distance: ",
  round(harris_turn_snap$distance_to_road_m[1], 1),
  " m"
)
message(
  "Station 1 flooded-network snap distance: ",
  round(ncfpd1_flooded_snapped$distance_to_road_m[1], 1),
  " m"
)
message("All Section 13 coordinate checks passed.")
message("============================================================")



# ---------------------------------------------------------------------------
# 14. BUILD COORDINATE MATRICES AND ROUTING GRAPHS
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
  ncfpd1_snapped$routing_lon[1],
  ncfpd1_snapped$routing_lat[1],
  "NCFPD_STATION_1"
)
temecula_xy <- make_xy_matrix(
  temecula_snapped$routing_lon[1],
  temecula_snapped$routing_lat[1],
  "TEMECULA_CIVIC_CENTER"
)
de_luz_xy <- make_xy_matrix(
  detour_waypoints_snapped$routing_lon[1],
  detour_waypoints_snapped$routing_lat[1],
  "DE_LUZ_NORTH_SIDE"
)
camaron_xy <- make_xy_matrix(
  detour_waypoints_snapped$routing_lon[2],
  detour_waypoints_snapped$routing_lat[2],
  "CAMARON_NORTH_SIDE"
)
rock_mountain_xy <- make_xy_matrix(
  detour_waypoints_snapped$routing_lon[3],
  detour_waypoints_snapped$routing_lat[3],
  "ROCK_MOUNTAIN_NORTH_SIDE"
)

block_xy_north <- as.matrix(
  yellow_block_lookup_north %>% select(routing_lon, routing_lat)
)
colnames(block_xy_north) <- c("x", "y")
block_geoids_north <- yellow_block_lookup_north$block_geoid_2020
rownames(block_xy_north) <- paste0("BLOCK_", block_geoids_north)
storage.mode(block_xy_north) <- "double"

# Keep only OSM attributes required by the motorcar graph.
keep_road_cols <- intersect(
  c("name", "bridge", "layer", "maxspeed", "surface", "access", "vehicle", "motor_vehicle", "motorcar", "ford", "oneway"),
  names(roads_normal_final)
)

cap_dodgr_speed <- function(graph, speed_cap_kmh = MAX_MODELED_SPEED_KMH) {
  required <- c("d", "d_weighted", "time", "time_weighted")
  missing <- setdiff(required, names(graph))
  if (length(missing) > 0) {
    stop("Graph lacks fields required for speed cap: ", paste(missing, collapse = ", "))
  }
  min_time <- graph$d * 3.6 / speed_cap_kmh
  min_weighted_time <- graph$d_weighted * 3.6 / speed_cap_kmh
  graph$time <- pmax(graph$time, min_time)
  graph$time_weighted <- pmax(graph$time_weighted, min_weighted_time)
  graph
}

build_routing_graph <- function(roads_sf, xy, graph_label) {
  message("Weighting and inserting nodes: ", graph_label)
  raw <- dodgr::weight_streetnet(
    roads_sf,
    wt_profile = "motorcar",
    type_col = "highway",
    id_col = "osm_id",
    keep_cols = keep_road_cols
  )
  
  # Crucial: insert by splitting road edges only; no off-road connector edges.
  with_nodes <- dodgr::add_nodes_to_graph(
    raw,
    xy = xy,
    intersections_only = TRUE
  )
  capped <- cap_dodgr_speed(with_nodes)
  list(raw = raw, with_nodes = with_nodes, graph = capped)
}

# ---------------------------------------------------------------------------
# FLOODED CLOSURE GRAPH: ONE CONTINUOUS NETWORK
# ---------------------------------------------------------------------------

# Station 1 is snapped to the closure network.
ncfpd1_flooded_xy <- make_xy_matrix(
  ncfpd1_flooded_snapped$routing_lon[1],
  ncfpd1_flooded_snapped$routing_lat[1],
  "NCFPD_STATION_1_FLOODED"
)

# Harris Trail is inserted as a diagnostic node, not a mandatory waypoint.
harris_turn_xy <- make_xy_matrix(
  harris_turn_snap$routing_lon[1],
  harris_turn_snap$routing_lat[1],
  "HARRIS_TRAIL_TURN"
)

# All existing north-side block road-access destinations are retained.
flooded_access_nodes_xy <- rbind(
  ncfpd1_flooded_xy,
  harris_turn_xy,
  block_xy_north
)

# Important:
# roads_closed_prefix excludes the closed Sandia Creek bridge and all
# unapproved river crossings. It retains the verified De Luz bridge.
flooded_access_network <- build_routing_graph(
  roads_sf = roads_closed_prefix,
  xy = flooded_access_nodes_xy,
  graph_label = "Flooded closure - continuous De Luz-only crossing network"
)

graph_flooded_access_speedcap <- flooded_access_network$graph

# Confirm that De Luz is still the only road feature touching the river
# centerline in this routing network.
flooded_graph_roads_utm <- st_transform(roads_closed_prefix, 26911)

flooded_graph_river_contacts <- lengths(
  st_intersects(flooded_graph_roads_utm, river_centerline_utm)
) > 0

flooded_graph_crossing_ids <- unique(
  as.character(
    roads_closed_prefix$osm_id[flooded_graph_river_contacts]
  )
)

if (!setequal(flooded_graph_crossing_ids, DE_LUZ_BRIDGE_OSM_ID)) {
  stop(
    "Flooded graph does not contain exactly the verified De Luz crossing. ",
    "Found: ",
    paste(flooded_graph_crossing_ids, collapse = ", ")
  )
}

if (CURRENT_SANDIA_BRIDGE_OSM_ID %in% roads_closed_prefix$osm_id) {
  stop("Closed Sandia Creek bridge unexpectedly remains in the flooded graph.")
}

# Normal network: Station 1 + all north-side block access points; both
# approved bridges are available, all unapproved crossings removed.
normal_nodes_xy <- rbind(ncfpd1_xy, block_xy_north)
normal_network <- build_routing_graph(roads_normal_final, normal_nodes_xy, "normal access")
graph_normal_speedcap <- normal_network$graph

# Closure-prefix network: only used from Station 1 to the north-side De Luz
# waypoint. De Luz is the only river crossing retained in this graph.
prefix_nodes_xy <- rbind(ncfpd1_xy, de_luz_xy)
closure_prefix_network <- build_routing_graph(roads_closed_prefix, prefix_nodes_xy, "closure prefix (De Luz crossing only)")
graph_closure_prefix_speedcap <- closure_prefix_network$graph

# North-side-only network: used for De Luz -> Camaron -> Rock Mountain ->
# blocks, and for Temecula -> blocks. No river-touching roads are included.
north_nodes_xy <- rbind(
  temecula_xy,
  de_luz_xy,
  camaron_xy,
  rock_mountain_xy,
  block_xy_north
)
north_network <- build_routing_graph(roads_north_side, north_nodes_xy, "north-side-only final approach")
graph_north_speedcap <- north_network$graph
# ===========================================================================
# I-15 ALTERNATIVE ROUTING GRAPHS - NCFPD STATION 1
# ===========================================================================

# Station 1 coordinates.
ncfpd1_i15_xy <- make_xy_matrix(
  ncfpd1_i15_snapped$routing_lon[1],
  ncfpd1_i15_snapped$routing_lat[1],
  "NCFPD_STATION_1_I15"
)

# Waypoint 1.
i15_waypoint1_xy <- make_xy_matrix(
  i15_waypoint1_snapped$routing_lon[1],
  i15_waypoint1_snapped$routing_lat[1],
  "I15_APPROACH"
)

# Waypoint 2.
i15_waypoint2_xy <- make_xy_matrix(
  i15_waypoint2_snapped$routing_lon[1],
  i15_waypoint2_snapped$routing_lat[1],
  "SANDIA_CREEK_ENTRY"
)

# Graph 1: Station 1, approach waypoint, and Sandia Creek entry.
i15_access_nodes_xy <- rbind(
  ncfpd1_i15_xy,
  i15_waypoint1_xy,
  i15_waypoint2_xy
)

i15_access_network <- build_routing_graph(
  roads_i15_access,
  i15_access_nodes_xy,
  "NCFPD Station 1 - I-15 and Rancho California corridor"
)

graph_i15_access_speedcap <- i15_access_network$graph

# Graph 2: final approach from Sandia Creek Drive to all northern blocks.
i15_north_nodes_xy <- rbind(
  i15_waypoint2_xy,
  block_xy_north
)

i15_north_network <- build_routing_graph(
  roads_north_side,
  i15_north_nodes_xy,
  "NCFPD Station 1 I-15 alternative - north-side final approach"
)

graph_i15_north_speedcap <- i15_north_network$graph
# ---------------------------------------------------------------------------
# 15. VERIFY EDGE SPEED CAP AND SNAP DISTANCES
# ---------------------------------------------------------------------------

check_graph_speeds <- function(graph, scenario_name) {
  edge_speeds <- graph$d * 3.6 / graph$time
  tibble(
    scenario = scenario_name,
    edges = length(edge_speeds),
    mean_edge_speed_kmh = mean(edge_speeds, na.rm = TRUE),
    median_edge_speed_kmh = median(edge_speeds, na.rm = TRUE),
    maximum_edge_speed_kmh = max(edge_speeds, na.rm = TRUE),
    edges_exceeding_cap = sum(edge_speeds > MAX_MODELED_SPEED_KMH + 0.001, na.rm = TRUE)
  )
}

speed_cap_validation <- bind_rows(
  check_graph_speeds(graph_normal_speedcap, "Normal access"),
  check_graph_speeds(graph_closure_prefix_speedcap, "Closure prefix"),
  check_graph_speeds(graph_north_speedcap, "North-side-only routes"),
  check_graph_speeds(
    graph_i15_access_speedcap,
    "I-15 approach and corridor"
  ),
  
  check_graph_speeds(
    graph_i15_north_speedcap,
    "I-15 north-side final approach"
  ),
)
write_csv(speed_cap_validation, file.path(OUTPUT_DIR, "Speed_Cap_Edge_Validation.csv"))
if (any(speed_cap_validation$edges_exceeding_cap > 0)) {
  stop("One or more routing graphs contain edges above the configured maximum speed.")
}

# Verify all graph insertion points have no large snap displacement.
get_snap_check <- function(graph_raw, xy, graph_name) {
  if (nrow(xy) == 0) return(tibble())
  match_result <- dodgr::match_points_to_graph(
    graph_raw,
    xy = xy,
    distances = TRUE
  )
  tibble(
    graph = graph_name,
    point_id = rownames(xy),
    snap_distance_m = abs(as.numeric(match_result$d_signed))
  )
}

snap_check <- bind_rows(
  get_snap_check(normal_network$raw, normal_nodes_xy, "Normal access"),
  get_snap_check(closure_prefix_network$raw, prefix_nodes_xy, "Closure prefix"),
  get_snap_check(north_network$raw, north_nodes_xy, "North-side-only")
)
write_csv(snap_check, file.path(OUTPUT_DIR, "Graph_Node_Snap_Check.csv"))

# ---------------------------------------------------------------------------
# 16. MATCH ROUTING COORDINATES TO VERTEX IDS
# ---------------------------------------------------------------------------

get_graph_vertex_ids <- function(graph, xy) {
  vertices <- dodgr::dodgr_vertices(graph)
  index <- dodgr::match_pts_to_verts(vertices, xy = xy, connected = FALSE)
  if (anyNA(index) || any(index < 1) || any(index > nrow(vertices))) {
    stop("Could not match one or more routing points to graph vertices.")
  }
  as.character(vertices$id[index])
}

normal_vertex_ids <- get_graph_vertex_ids(graph_normal_speedcap, normal_nodes_xy)
names(normal_vertex_ids) <- rownames(normal_nodes_xy)
prefix_vertex_ids <- get_graph_vertex_ids(graph_closure_prefix_speedcap, prefix_nodes_xy)
names(prefix_vertex_ids) <- rownames(prefix_nodes_xy)
north_vertex_ids <- get_graph_vertex_ids(graph_north_speedcap, north_nodes_xy)
names(north_vertex_ids) <- rownames(north_nodes_xy)

# ===========================================================================
# I-15 ALTERNATIVE GRAPH VERTEX IDENTIFICATION
# ===========================================================================

i15_access_vertex_ids <- get_graph_vertex_ids(
  graph_i15_access_speedcap,
  i15_access_nodes_xy
)

names(i15_access_vertex_ids) <- rownames(i15_access_nodes_xy)

i15_north_vertex_ids <- get_graph_vertex_ids(
  graph_i15_north_speedcap,
  i15_north_nodes_xy
)

names(i15_north_vertex_ids) <- rownames(i15_north_nodes_xy)

# Access-network vertex IDs.
i15_station1_id <- unname(
  i15_access_vertex_ids["NCFPD_STATION_1_I15"]
)

i15_waypoint1_id <- unname(
  i15_access_vertex_ids["I15_APPROACH"]
)

i15_waypoint2_access_id <- unname(
  i15_access_vertex_ids["SANDIA_CREEK_ENTRY"]
)

# North-side final-network vertex IDs.
i15_waypoint2_north_id <- unname(
  i15_north_vertex_ids["SANDIA_CREEK_ENTRY"]
)

i15_block_vertex_ids <- unname(
  i15_north_vertex_ids[paste0("BLOCK_", block_geoids_north)]
)

if (
  is.na(i15_station1_id) ||
  is.na(i15_waypoint1_id) ||
  is.na(i15_waypoint2_access_id) ||
  is.na(i15_waypoint2_north_id) ||
  anyNA(i15_block_vertex_ids)
) {
  stop("One or more I-15 alternative graph vertices could not be matched.")
}

# Verify identical waypoint coordinates across the two graphs.
i15_access_waypoint_xy <- get_vertex_xy(
  graph_i15_access_speedcap,
  i15_waypoint2_access_id
)

i15_north_waypoint_xy <- get_vertex_xy(
  graph_i15_north_speedcap,
  i15_waypoint2_north_id
)

i15_handoff_distance_m <- coord_distance_m(
  i15_access_waypoint_xy,
  i15_north_waypoint_xy
)

if (i15_handoff_distance_m > 2) {
  stop(
    "I-15 waypoint-to-north-side handoff differs by ",
    round(i15_handoff_distance_m, 2),
    " m."
  )
}

# Match all continuous flooded-closure graph nodes.
flooded_access_vertex_ids <- get_graph_vertex_ids(
  graph_flooded_access_speedcap,
  flooded_access_nodes_xy
)

names(flooded_access_vertex_ids) <- rownames(flooded_access_nodes_xy)

flooded_ncfpd1_id <- unname(
  flooded_access_vertex_ids["NCFPD_STATION_1_FLOODED"]
)

flooded_harris_id <- unname(
  flooded_access_vertex_ids["HARRIS_TRAIL_TURN"]
)

flooded_block_vertex_ids <- unname(
  flooded_access_vertex_ids[paste0("BLOCK_", block_geoids_north)]
)

if (
  is.na(flooded_ncfpd1_id) ||
  is.na(flooded_harris_id) ||
  anyNA(flooded_block_vertex_ids)
) {
  stop("One or more flooded-closure routing nodes could not be matched.")
}
normal_ncfpd1_id <- unname(normal_vertex_ids["NCFPD_STATION_1"])
prefix_ncfpd1_id <- unname(prefix_vertex_ids["NCFPD_STATION_1"])
prefix_de_luz_id <- unname(prefix_vertex_ids["DE_LUZ_NORTH_SIDE"])
north_de_luz_id <- unname(north_vertex_ids["DE_LUZ_NORTH_SIDE"])
north_camaron_id <- unname(north_vertex_ids["CAMARON_NORTH_SIDE"])
north_rock_id <- unname(north_vertex_ids["ROCK_MOUNTAIN_NORTH_SIDE"])
north_temecula_id <- unname(north_vertex_ids["TEMECULA_CIVIC_CENTER"])

normal_block_ids <- unname(normal_vertex_ids[paste0("BLOCK_", block_geoids_north)])
north_block_vertex_ids <- unname(north_vertex_ids[paste0("BLOCK_", block_geoids_north)])
if (anyNA(normal_block_ids) || anyNA(north_block_vertex_ids)) {
  stop("At least one northern 2020 Census block could not be matched to a graph vertex.")
}

# De Luz waypoint must resolve to the same graph vertex coordinate in both
# prefix and north-side graphs (within 2 m), confirming a continuous handoff.
get_vertex_xy <- function(graph, vertex_id) {
  verts <- dodgr::dodgr_vertices(graph)
  idx <- match(as.character(vertex_id), as.character(verts$id))
  if (is.na(idx)) stop("Graph vertex ID not found.")
  c(x = verts$x[idx], y = verts$y[idx])
}
de_luz_prefix_xy <- get_vertex_xy(graph_closure_prefix_speedcap, prefix_de_luz_id)
de_luz_north_xy <- get_vertex_xy(graph_north_speedcap, north_de_luz_id)
de_luz_handoff_m <- as.numeric(st_distance(
  st_sfc(st_point(de_luz_prefix_xy), crs = 4326) %>% st_transform(26911),
  st_sfc(st_point(de_luz_north_xy), crs = 4326) %>% st_transform(26911)
))
if (de_luz_handoff_m > 2) {
  stop("De Luz prefix-to-north-side handoff differs by ", round(de_luz_handoff_m, 2), " m. The two graphs do not share an identical waypoint connection.")
}

# ---------------------------------------------------------------------------
# 17. ROUTING CALCULATION FUNCTIONS
# ---------------------------------------------------------------------------

calculate_fastest_routes_by_vertex_id <- function(
    graph,
    from_id,
    to_ids,
    destination_ids,
    route_label = "Route"
) {
  if (length(to_ids) != length(destination_ids)) {
    stop("to_ids and destination_ids have different lengths for ", route_label)
  }
  unique_to_ids <- unique(as.character(to_ids))
  
  time_matrix <- as.matrix(dodgr::dodgr_times(
    graph,
    from = as.character(from_id),
    to = unique_to_ids,
    shortest = FALSE
  ))
  
  # Select the fastest path and report physical road length along that path.
  distance_graph <- graph
  distance_graph$d_weighted <- distance_graph$time_weighted
  distance_matrix <- as.matrix(dodgr::dodgr_dists(
    distance_graph,
    from = as.character(from_id),
    to = unique_to_ids,
    shortest = FALSE
  ))
  
  if (nrow(time_matrix) != 1 || nrow(distance_matrix) != 1 ||
      ncol(time_matrix) != length(unique_to_ids) ||
      ncol(distance_matrix) != length(unique_to_ids)) {
    stop("Unexpected routing matrix dimensions for ", route_label)
  }
  
  align_cols <- function(mat, ids, label) {
    if (is.null(colnames(mat))) {
      return(as.numeric(mat[1, seq_along(ids)]))
    }
    idx <- match(ids, as.character(colnames(mat)))
    if (anyNA(idx)) stop("Could not align ", label, " result columns for ", route_label)
    as.numeric(mat[1, idx])
  }
  
  unique_times <- align_cols(time_matrix, unique_to_ids, "time")
  unique_distances <- align_cols(distance_matrix, unique_to_ids, "distance")
  match_idx <- match(as.character(to_ids), unique_to_ids)
  time_values <- unique_times[match_idx]
  distance_values <- unique_distances[match_idx]
  
  tibble(
    destination_id = as.character(destination_ids),
    drive_seconds = time_values,
    distance_m = distance_values
  ) %>%
    mutate(
      route_status = if_else(
        is.finite(drive_seconds) & is.finite(distance_m),
        "Reachable", "Unreachable"
      ),
      modeled_drive_min = if_else(route_status == "Reachable", drive_seconds / 60, NA_real_),
      modeled_distance_km = if_else(route_status == "Reachable", distance_m / 1000, NA_real_),
      modeled_distance_mi = if_else(route_status == "Reachable", distance_m / 1609.344, NA_real_),
      implied_average_speed_kmh = if_else(
        route_status == "Reachable" & modeled_drive_min > 0,
        modeled_distance_km / (modeled_drive_min / 60),
        NA_real_
      )
    )
}

calculate_single_leg <- function(graph, from_id, to_id, label) {
  result <- calculate_fastest_routes_by_vertex_id(
    graph = graph,
    from_id = from_id,
    to_ids = to_id,
    destination_ids = label,
    route_label = label
  )
  result %>% mutate(route_leg = label)
}

# ---------------------------------------------------------------------------
# 18. SCENARIO 1 - NORMAL NCFPD STATION 1 ACCESS
# ---------------------------------------------------------------------------

message("Calculating normal-access routes to northern 2020 Census blocks...")
routes_ncfpd1_normal_north <- calculate_fastest_routes_by_vertex_id(
  graph = graph_normal_speedcap,
  from_id = normal_ncfpd1_id,
  to_ids = normal_block_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "NCFPD Station 1 normal access"
)

# ---------------------------------------------------------------------------
# 19. SCENARIO 2 - FORCED DE LUZ DETOUR, THEN NORTH-SIDE-ONLY ROUTING
# ---------------------------------------------------------------------------

message("Calculating forced De Luz detour: only first leg may cross the river...")

# Leg 1: Station 1 -> De Luz bridge-side waypoint. This is the ONLY detour
# leg calculated on the closure-prefix graph that contains De Luz as a crossing.
detour_leg1 <- calculate_single_leg(
  graph_closure_prefix_speedcap,
  prefix_ncfpd1_id,
  prefix_de_luz_id,
  "Station 1 to De Luz (only permitted river crossing)"
)

# Legs 2 and 3 are constrained to the north-side-only graph.
detour_leg2 <- calculate_single_leg(
  graph_north_speedcap,
  north_de_luz_id,
  north_camaron_id,
  "De Luz to Camaron (north-side roads only)"
)
detour_leg3 <- calculate_single_leg(
  graph_north_speedcap,
  north_camaron_id,
  north_rock_id,
  "Camaron to Rock Mountain (north-side roads only)"
)

# ---------------------------------------------------------------------------
# FLOODED CLOSURE: DIRECT FASTEST ROUTES FROM STATION 1 TO EVERY BLOCK
# ---------------------------------------------------------------------------

message(
  "Calculating continuous flooded-closure routes from Station 1 ",
  "to all northern 2020 Census blocks..."
)

routes_ncfpd1_deluz_north <- calculate_fastest_routes_by_vertex_id(
  graph = graph_flooded_access_speedcap,
  from_id = flooded_ncfpd1_id,
  to_ids = flooded_block_vertex_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "NCFPD Station 1 - continuous flooded closure network"
)

# Final Rock Mountain -> block routes are also north-side-only.
detour_final_legs_north <- calculate_fastest_routes_by_vertex_id(
  graph = graph_north_speedcap,
  from_id = north_rock_id,
  to_ids = north_block_vertex_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "Rock Mountain to northern 2020 blocks (north-side roads only)"
)

# ---------------------------------------------------------------------------
# 20. SCENARIO 3 - TEMECULA CIVIC CENTER DURING BRIDGE CLOSURE
# ---------------------------------------------------------------------------

message("Calculating Temecula-to-north-side routes on the north-only graph...")
routes_temecula_north <- calculate_fastest_routes_by_vertex_id(
  graph = graph_north_speedcap,
  from_id = north_temecula_id,
  to_ids = north_block_vertex_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "Temecula to northern 2020 blocks (north-side roads only)"
)

# ===========================================================================
# SCENARIO 4 - NCFPD STATION 1 I-15 / RANCHO CALIFORNIA ALTERNATIVE
# ===========================================================================

message("Calculating NCFPD Station 1 I-15 alternative routes...")

# Leg 1: Station 1 -> first route waypoint.
i15_leg1 <- calculate_single_leg(
  graph_i15_access_speedcap,
  i15_station1_id,
  i15_waypoint1_id,
  "Station 1 to I-15 approach"
)

# Leg 2: first waypoint -> Sandia Creek Drive entry.
i15_leg2 <- calculate_single_leg(
  graph_i15_access_speedcap,
  i15_waypoint1_id,
  i15_waypoint2_access_id,
  "I-15 via Rancho California and Avenida del Oro to Sandia Creek"
)

mandatory_i15_legs <- bind_rows(
  i15_leg1,
  i15_leg2
)

if (
  any(!is.finite(mandatory_i15_legs$drive_seconds)) ||
  any(!is.finite(mandatory_i15_legs$distance_m))
) {
  stop(
    "One or more mandatory I-15 route legs are unreachable. ",
    "Review waypoint snaps and graph connectivity."
  )
}

i15_prefix_seconds <- sum(
  mandatory_i15_legs$drive_seconds
)

i15_prefix_distance_m <- sum(
  mandatory_i15_legs$distance_m
)

# Leg 3: Sandia Creek Drive entry -> every northern block.
i15_final_legs_north <- calculate_fastest_routes_by_vertex_id(
  graph = graph_i15_north_speedcap,
  from_id = i15_waypoint2_north_id,
  to_ids = i15_block_vertex_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "I-15 alternative: Sandia Creek entry to northern blocks"
)

# Add the two mandatory route legs to the destination-specific final legs.
routes_ncfpd1_i15_north <- i15_final_legs_north %>%
  mutate(
    drive_seconds = drive_seconds + i15_prefix_seconds,
    distance_m = distance_m + i15_prefix_distance_m,
    
    route_status = if_else(
      is.finite(drive_seconds) & is.finite(distance_m),
      "Reachable",
      "Unreachable"
    ),
    
    modeled_drive_min = if_else(
      route_status == "Reachable",
      drive_seconds / 60,
      NA_real_
    ),
    
    modeled_distance_km = if_else(
      route_status == "Reachable",
      distance_m / 1000,
      NA_real_
    ),
    
    modeled_distance_mi = if_else(
      route_status == "Reachable",
      distance_m / 1609.344,
      NA_real_
    ),
    
    implied_average_speed_kmh = if_else(
      route_status == "Reachable" & modeled_drive_min > 0,
      modeled_distance_km / (modeled_drive_min / 60),
      NA_real_
    )
  )

write_csv(
  mandatory_i15_legs %>%
    mutate(
      modeled_drive_min = drive_seconds / 60,
      modeled_distance_km = distance_m / 1000
    ),
  file.path(OUTPUT_DIR, "Mandatory_I15_Alternative_Legs.csv")
)

# ---------------------------------------------------------------------------
# 21. EXTRACT AND VALIDATE THE FLOODED DETOUR GEOMETRY
# ---------------------------------------------------------------------------

extract_fastest_path_coordinates <- function(graph, from_id, to_id) {
  graph_for_paths <- graph
  graph_for_paths$d_weighted <- graph_for_paths$time_weighted
  vertices <- dodgr::dodgr_vertices(graph_for_paths)
  path_result <- dodgr::dodgr_paths(
    graph_for_paths,
    from = as.character(from_id),
    to = as.character(to_id),
    vertices = TRUE,
    quiet = TRUE
  )
  path_values <- path_result[[1]][[1]]
  if (is.null(path_values) || length(path_values) < 2) {
    stop("A required route path could not be reconstructed.")
  }
  vertex_rows <- match(as.character(path_values), as.character(vertices$id))
  if (anyNA(vertex_rows)) {
    valid_indices <- is.numeric(path_values) &&
      all(path_values == as.integer(path_values)) &&
      all(path_values >= 1) &&
      all(path_values <= nrow(vertices))
    if (valid_indices) {
      vertex_rows <- as.integer(path_values)
    } else {
      stop("Path values could not be matched to graph vertex IDs or row indices.")
    }
  }
  vertices[vertex_rows, c("x", "y"), drop = FALSE]
}

# The first path may cross only the De Luz bridge.
path_leg1 <- extract_fastest_path_coordinates(
  graph_closure_prefix_speedcap,
  prefix_ncfpd1_id,
  prefix_de_luz_id
)
# These legs are on the north-side-only graph and cannot cross the river.
path_leg2 <- extract_fastest_path_coordinates(
  graph_north_speedcap,
  north_de_luz_id,
  north_camaron_id
)
path_leg3 <- extract_fastest_path_coordinates(
  graph_north_speedcap,
  north_camaron_id,
  north_rock_id
)

# Check cross-graph waypoint handoffs before combining linework.
end1 <- as.numeric(tail(path_leg1, 1))
start2 <- as.numeric(head(path_leg2, 1))
end2 <- as.numeric(tail(path_leg2, 1))
start3 <- as.numeric(head(path_leg3, 1))
coord_distance_m <- function(a, b) {
  as.numeric(st_distance(
    st_sfc(st_point(a), crs = 4326) %>% st_transform(26911),
    st_sfc(st_point(b), crs = 4326) %>% st_transform(26911)
  ))
}
if (coord_distance_m(end1, start2) > 2 || coord_distance_m(end2, start3) > 2) {
  stop("Detour path segments do not join at the same snapped waypoint coordinates.")
}

detour_coords <- bind_rows(
  path_leg1,
  path_leg2 %>% slice(-1),
  path_leg3 %>% slice(-1)
) %>% as.matrix()

if (nrow(detour_coords) < 2 || any(!is.finite(detour_coords))) {
  stop("The reconstructed De Luz detour contains invalid coordinates.")
}

# ===========================================================================
# NCFPD STATION 1 I-15 ALTERNATIVE: FULL ROUTE GEOMETRY AND ROAD QA
# ===========================================================================

# Reconstruct the actual Station 1 -> waypoint 1 path.
i15_path_leg1 <- extract_fastest_path_coordinates(
  graph_i15_access_speedcap,
  i15_station1_id,
  i15_waypoint1_id
)

# Reconstruct the actual waypoint 1 -> waypoint 2 path.
i15_path_leg2 <- extract_fastest_path_coordinates(
  graph_i15_access_speedcap,
  i15_waypoint1_id,
  i15_waypoint2_access_id
)

# Validate the graph handoff between the two route legs.
i15_leg_handoff_m <- coord_distance_m(
  as.numeric(tail(i15_path_leg1, 1)),
  as.numeric(head(i15_path_leg2, 1))
)

if (!is.finite(i15_leg_handoff_m) || i15_leg_handoff_m > 2) {
  stop("I-15 alternative waypoint legs do not connect within 2 m.")
}

# ---------------------------------------------------------------------------
# ROAD-CORRIDOR OVERLAP QA
# ---------------------------------------------------------------------------

# Measure how much of a reconstructed path follows an intended road layer.
# A small buffer tolerates minor differences between graph and OSM geometry.
measure_path_near_road_m <- function(
    path_df,
    roads_sf,
    buffer_m = 15
) {
  
  if (nrow(roads_sf) == 0) {
    return(0)
  }
  
  route_utm <- st_sfc(
    st_linestring(
      as.matrix(path_df %>% select(x, y))
    ),
    crs = 4326
  ) %>%
    st_transform(26911)
  
  roads_utm <- st_transform(roads_sf, 26911)
  
  road_union <- st_union(
    st_geometry(roads_utm)
  )
  
  road_buffer <- st_buffer(
    road_union,
    dist = buffer_m
  )
  
  overlap <- suppressWarnings(
    st_intersection(route_utm, road_buffer)
  )
  
  sum(
    as.numeric(st_length(overlap)),
    na.rm = TRUE
  )
}

# Measure the route between the two supplied waypoints.
i15_stage2_road_use <- tibble(
  intended_road = c(
    "I-15 motorway",
    "Rancho California Road",
    "Avenida del Oro",
    "Sandia Creek Drive"
  ),
  
  available_osm_segments = c(
    nrow(i15_motorway_features),
    nrow(i15_rancho_features),
    nrow(i15_avenida_features),
    nrow(i15_sandia_features)
  ),
  
  route_overlap_m = c(
    measure_path_near_road_m(
      i15_path_leg2,
      i15_motorway_features
    ),
    
    measure_path_near_road_m(
      i15_path_leg2,
      i15_rancho_features
    ),
    
    measure_path_near_road_m(
      i15_path_leg2,
      i15_avenida_features
    ),
    
    measure_path_near_road_m(
      i15_path_leg2,
      i15_sandia_features
    )
  ),
  
  minimum_required_overlap_m = c(
    I15_MIN_MOTORWAY_OVERLAP_M,
    I15_MIN_RANCHO_OVERLAP_M,
    I15_MIN_AVENIDA_OVERLAP_M,
    I15_MIN_SANDIA_OVERLAP_M
  )
) %>%
  mutate(
    route_qa_passed =
      route_overlap_m >= minimum_required_overlap_m
  )

write_csv(
  i15_stage2_road_use,
  file.path(OUTPUT_DIR, "I15_Alternative_Route_Corridor_QA.csv")
)

print(i15_stage2_road_use)

if (any(!i15_stage2_road_use$route_qa_passed)) {
  stop(
    "The route between the supplied waypoints did not follow all expected ",
    "I-15 / Rancho California / Avenida del Oro / Sandia Creek roads. ",
    "Review I15_Alternative_Route_Corridor_QA.csv before using the results."
  )
}

# ---------------------------------------------------------------------------
# BUILD THE COMPLETE SHARED I-15 ROUTE PREFIX
# ---------------------------------------------------------------------------

i15_prefix_xy <- bind_rows(
  i15_path_leg1,
  i15_path_leg2 %>% slice(-1)
)

if (
  nrow(i15_prefix_xy) < 2 ||
  any(!is.finite(as.matrix(i15_prefix_xy)))
) {
  stop("I-15 alternative shared route prefix contains invalid coordinates.")
}

# Verify that any portion of the prefix inside the river buffer follows
# the retained motorway/motorway-link corridor.
i15_prefix_utm <- st_sfc(
  st_linestring(as.matrix(i15_prefix_xy)),
  crs = 4326
) %>%
  st_transform(26911)

i15_river_portion <- suppressWarnings(
  st_intersection(
    i15_prefix_utm,
    river_buffer_utm
  )
)

i15_freeway_features <- bind_rows(
  i15_motorway_features,
  i15_ramp_features
)

i15_freeway_union_utm <- st_union(
  st_geometry(
    st_transform(i15_freeway_features, 26911)
  )
)

i15_freeway_buffer_utm <- st_buffer(
  i15_freeway_union_utm,
  dist = 25
)

i15_unapproved_river_portion <- suppressWarnings(
  st_difference(
    i15_river_portion,
    i15_freeway_buffer_utm
  )
)

i15_unapproved_river_length_m <- sum(
  as.numeric(st_length(i15_unapproved_river_portion)),
  na.rm = TRUE
)

if (i15_unapproved_river_length_m > 3) {
  stop(
    "The I-15 alternative route contains ",
    round(i15_unapproved_river_length_m, 1),
    " m of travel inside the river buffer outside the motorway corridor."
  )
}

# ---------------------------------------------------------------------------
# RECONSTRUCT COMPLETE ROUTES TO EVERY CENSUS BLOCK
# ---------------------------------------------------------------------------

route_lines_ncfpd1_i15_north <- make_destination_route_lines(
  graph = graph_i15_north_speedcap,
  from_id = i15_waypoint2_north_id,
  destination_vertex_ids = i15_block_vertex_ids,
  destination_geoids = block_geoids_north,
  route_results = routes_ncfpd1_i15_north,
  scenario_name = "NCFPD Station 1 - I-15 / Rancho California Alternative",
  shared_prefix = i15_prefix_xy
)

if (nrow(route_lines_ncfpd1_i15_north) == 0) {
  stop("No I-15 alternative route geometries were reconstructed.")
}

write_csv(
  route_lines_ncfpd1_i15_north %>%
    st_drop_geometry() %>%
    select(
      block_geoid_2020,
      modeled_drive_min,
      modeled_distance_km,
      route_status,
      is_longest_route
    ),
  file.path(OUTPUT_DIR, "I15_Alternative_Route_Line_QA.csv")
)

# ---------------------------------------------------------------------------
# FULL FLOODED-CLOSURE DODGR ROUTES
# ---------------------------------------------------------------------------

route_lines_ncfpd1_deluz_north <- make_destination_route_lines(
  graph = graph_flooded_access_speedcap,
  from_id = flooded_ncfpd1_id,
  destination_vertex_ids = flooded_block_vertex_ids,
  destination_geoids = block_geoids_north,
  route_results = routes_ncfpd1_deluz_north,
  scenario_name = "NCFPD Station 1 - Flooded closure, De Luz-only crossing"
)

# ---------------------------------------------------------------------------
# HARRIS TRAIL ROUTE PROXIMITY AUDIT
# ---------------------------------------------------------------------------

route_lines_flooded_utm <- st_transform(
  route_lines_ncfpd1_deluz_north,
  26911
)

harris_turn_point_utm <- st_transform(
  harris_turn_point_wgs84,
  26911
)

harris_route_distances <- as.numeric(
  st_distance(
    route_lines_flooded_utm,
    harris_turn_point_utm
  )
)

harris_turn_route_qa <- route_lines_ncfpd1_deluz_north %>%
  st_drop_geometry() %>%
  mutate(
    distance_to_harris_turn_m = harris_route_distances,
    passes_near_harris_turn = distance_to_harris_turn_m <= 30
  ) %>%
  arrange(desc(modeled_drive_min))

write_csv(
  harris_turn_route_qa,
  file.path(OUTPUT_DIR, "Harris_Trail_Route_Proximity_QA.csv")
)

# Isolate the slowest flooded-closure destination.
slowest_flooded_route <- route_lines_ncfpd1_deluz_north %>%
  slice_max(modeled_drive_min, n = 1, with_ties = FALSE)

slowest_route_qa <- slowest_flooded_route %>%
  st_drop_geometry() %>%
  mutate(
    distance_to_harris_turn_m =
      harris_route_distances[
        match(
          destination_id,
          route_lines_ncfpd1_deluz_north$destination_id
        )
      ]
  )

print(slowest_route_qa)

print(
  harris_turn_route_qa %>%
    filter(destination_id == slowest_flooded_route$destination_id) %>%
    select(
      destination_id,
      modeled_drive_min,
      modeled_distance_km,
      distance_to_harris_turn_m,
      passes_near_harris_turn
    )
)

# Validate the post-De Luz linework does not intersect the river buffer.
post_de_luz_lines <- st_sfc(
  st_linestring(as.matrix(bind_rows(
    path_leg2,
    path_leg3 %>% slice(-1)
  ) %>% select(x, y))),
  crs = 4326
) %>% st_transform(26911)
if (lengths(st_intersects(post_de_luz_lines, river_buffer_utm)) > 0) {
  stop("A post-De Luz detour leg intersects the river buffer. Do not use the results.")
}

# Validate special target final leg also remains outside the river buffer.
special_target_vertex_id <- north_block_vertex_ids[
  match(paste0("BLOCK_", SPECIAL_TARGET_BLOCK_GEOID), paste0("BLOCK_", block_geoids_north))
]
if (length(special_target_vertex_id) != 1 || is.na(special_target_vertex_id)) {
  stop("Special target block was not found among the north-side graph destinations.")
}
special_final_path <- extract_fastest_path_coordinates(
  graph_north_speedcap,
  north_rock_id,
  special_target_vertex_id
)
special_final_line_utm <- st_sfc(
  st_linestring(as.matrix(special_final_path)),
  crs = 4326
) %>% st_transform(26911)
if (lengths(st_intersects(special_final_line_utm, river_buffer_utm)) > 0) {
  stop("The special target final-leg route intersects the river buffer. Do not use the results.")
}

# Export special target QA.
special_target_validation <- routes_ncfpd1_deluz_north %>%
  filter(destination_id == paste0("BLOCK_", SPECIAL_TARGET_BLOCK_GEOID)) %>%
  select(destination_id, modeled_drive_min, modeled_distance_km, implied_average_speed_kmh, route_status)
if (nrow(special_target_validation) != 1) {
  stop("Special 2020 target block is missing or duplicated in detour results.")
}
write_csv(special_target_validation, file.path(OUTPUT_DIR, "Special_Target_2020_Block_Validation.csv"))

# Ordered route points for mapping.
detour_stop_points <- tibble(
  stop_order = 0:3,
  stop_name = c(
    "NCFPD Station 1",
    "De Luz Road",
    "Camaron Road",
    "Sandia Creek / Rock Mountain entry"
  ),
  longitude = c(
    ncfpd1_xy[1, "x"],
    detour_waypoints_snapped$routing_lon
  ),
  latitude = c(
    ncfpd1_xy[1, "y"],
    detour_waypoints_snapped$routing_lat
  )
)
detour_stop_points_wgs84 <- st_as_sf(
  detour_stop_points,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
)



# ---------------------------------------------------------------------------
# 21A. RECONSTRUCT DODGR ROUTES TO EVERY NORTHERN 2020 CENSUS BLOCK
# ---------------------------------------------------------------------------

make_destination_route_lines <- function(
    graph,
    from_id,
    destination_vertex_ids,
    destination_geoids,
    route_results,
    scenario_name,
    shared_prefix = NULL,
    check_north_only = FALSE
) {
  
  expected_destination_ids <- paste0("BLOCK_", destination_geoids)
  
  if (length(destination_vertex_ids) != length(destination_geoids)) {
    stop("Destination vertex IDs and GEOIDs have different lengths.")
  }
  
  # Only reconstruct routes that were successfully calculated.
  reachable <- route_results %>%
    filter(
      route_status == "Reachable",
      is.finite(modeled_drive_min),
      is.finite(distance_m)
    )
  
  if (nrow(reachable) == 0) {
    stop("No reachable destinations for route-line reconstruction: ", scenario_name)
  }
  
  destination_idx <- match(
    as.character(reachable$destination_id),
    expected_destination_ids
  )
  
  if (anyNA(destination_idx)) {
    stop("Could not match one or more route results to their block vertex IDs.")
  }
  
  # Optional shared prefix, used for the flooded De Luz detour.
  prefix_xy <- NULL
  
  if (!is.null(shared_prefix)) {
    
    prefix_xy <- as.data.frame(shared_prefix)
    
    if (ncol(prefix_xy) != 2) {
      stop("Shared route prefix must contain exactly two coordinate columns.")
    }
    
    names(prefix_xy) <- c("x", "y")
    
    if (nrow(prefix_xy) < 2 || any(!is.finite(as.matrix(prefix_xy)))) {
      stop("Shared route prefix contains invalid coordinates.")
    }
  }
  
  route_geometries <- vector("list", nrow(reachable))
  
  longest_destination_id <- reachable$destination_id[
    which.max(reachable$modeled_drive_min)
  ]
  
  for (i in seq_len(nrow(reachable))) {
    
    destination_vertex <- destination_vertex_ids[destination_idx[i]]
    
    # Reconstruct the actual fastest-time route through the graph.
    final_path <- extract_fastest_path_coordinates(
      graph,
      from_id,
      destination_vertex
    )
    
    if (
      nrow(final_path) < 2 ||
      any(!is.finite(as.matrix(final_path[, c("x", "y")])) )
    ) {
      stop(
        "Invalid reconstructed path for ",
        reachable$destination_id[i],
        " in scenario ",
        scenario_name
      )
    }
    
    # Attach the shared prefix when this is a staged detour scenario.
    if (!is.null(prefix_xy)) {
      
      prefix_endpoint <- c(
        tail(prefix_xy$x, 1),
        tail(prefix_xy$y, 1)
      )
      
      final_path_start <- c(
        final_path$x[1],
        final_path$y[1]
      )
      
      handoff_distance_m <- coord_distance_m(
        prefix_endpoint,
        final_path_start
      )
      
      if (!is.finite(handoff_distance_m) || handoff_distance_m > 2) {
        stop(
          "Route prefix does not join the final block route for ",
          reachable$destination_id[i],
          ". Handoff distance: ",
          round(handoff_distance_m, 2),
          " m."
        )
      }
      
      route_xy <- bind_rows(
        prefix_xy,
        final_path %>% slice(-1)
      )
      
      # For the flooded scenario, verify that everything after De Luz
      # remains on the north-side-only network.
      if (check_north_only) {
        
        north_only_xy <- bind_rows(
          path_leg2,
          path_leg3 %>% slice(-1),
          final_path %>% slice(-1)
        )
        
        north_only_geometry <- st_sfc(
          st_linestring(as.matrix(north_only_xy)),
          crs = 4326
        ) %>%
          st_transform(26911)
        
        if (lengths(st_intersects(
          north_only_geometry,
          river_buffer_utm
        )) > 0) {
          stop(
            "Post-De Luz route to ",
            reachable$destination_id[i],
            " intersects the river buffer. Do not use this route."
          )
        }
      }
      
    } else {
      
      route_xy <- final_path
    }
    
    if (nrow(route_xy) < 2) {
      stop("Route contains fewer than two coordinates.")
    }
    
    route_geometries[[i]] <- st_linestring(
      as.matrix(route_xy %>% select(x, y))
    )
  }
  
  route_metadata <- reachable %>%
    mutate(
      block_geoid_2020 = str_remove(destination_id, "^BLOCK_"),
      scenario = scenario_name,
      is_longest_route = destination_id == longest_destination_id
    )
  
  st_sf(
    route_metadata,
    geometry = st_sfc(route_geometries, crs = 4326)
  )
}


# ---------------------------------------------------------------------------
# RECONSTRUCT THE THREE SCENARIOS
# ---------------------------------------------------------------------------

# Scenario 1: NCFPD Station 1 normal access.
route_lines_ncfpd1_normal_north <- make_destination_route_lines(
  graph = graph_normal_speedcap,
  from_id = normal_ncfpd1_id,
  destination_vertex_ids = normal_block_ids,
  destination_geoids = block_geoids_north,
  route_results = routes_ncfpd1_normal_north,
  scenario_name = "NCFPD Station 1 - Normal Access"
)


# Scenario 2: NCFPD Station 1 flooded De Luz detour.
#
# The shared prefix contains:
# Station 1 -> De Luz -> Camaron -> Rock Mountain.
#
# Each individual destination route then extends from Rock Mountain
# to its own north-side Census block.
route_lines_ncfpd1_deluz_north <- make_destination_route_lines(
  graph = graph_north_speedcap,
  from_id = north_rock_id,
  destination_vertex_ids = north_block_vertex_ids,
  destination_geoids = block_geoids_north,
  route_results = routes_ncfpd1_deluz_north,
  scenario_name = "NCFPD Station 1 - Flooded De Luz Detour",
  shared_prefix = detour_coords,
  check_north_only = TRUE
)


# Scenario 3: Temecula Civic Center during bridge closure.
route_lines_temecula_north <- make_destination_route_lines(
  graph = graph_north_speedcap,
  from_id = north_temecula_id,
  destination_vertex_ids = north_block_vertex_ids,
  destination_geoids = block_geoids_north,
  route_results = routes_temecula_north,
  scenario_name = "Temecula - Bridge Closure"
)


message(
  "Reconstructed route geometries: ",
  nrow(route_lines_ncfpd1_normal_north), " normal; ",
  nrow(route_lines_ncfpd1_deluz_north), " flooded detour; ",
  nrow(route_lines_temecula_north), " Temecula."
)

#############

# 21A troubleshooting the troubled block (the one west of sandia creek drive)

############
# ---------------------------------------------------------------------------
# ISOLATE THE PURPLE (LONGEST) ROUTE AND TEST FOR FORCED BACKTRACKING
# ---------------------------------------------------------------------------

# Identify the destination represented by the purple line.
suspect_route <- route_lines_ncfpd1_deluz_north %>%
  filter(is_longest_route)

if (nrow(suspect_route) != 1) {
  stop("Expected exactly one purple-highlighted longest route.")
}

suspect_block_geoid <- as.character(
  suspect_route$block_geoid_2020[1]
)

suspect_block_index <- match(
  suspect_block_geoid,
  block_geoids_north
)

if (is.na(suspect_block_index)) {
  stop("Could not match the suspect block to its north-side graph vertex.")
}

suspect_vertex_id <- north_block_vertex_ids[suspect_block_index]

message("Suspect 2020 Census block: ", suspect_block_geoid)

# Retrieve the current modeled result.
suspect_current_result <- routes_ncfpd1_deluz_north %>%
  filter(destination_id == paste0("BLOCK_", suspect_block_geoid))

# Retrieve its current Rock Mountain -> block final leg.
suspect_current_final_leg <- detour_final_legs_north %>%
  filter(destination_id == paste0("BLOCK_", suspect_block_geoid))

if (nrow(suspect_current_result) != 1 ||
    nrow(suspect_current_final_leg) != 1) {
  stop("Could not uniquely retrieve the current route and final leg.")
}

# ---------------------------------------------------------------------------
# ALTERNATIVE: STATION 1 -> DE LUZ -> BLOCK
# ---------------------------------------------------------------------------

# Calculate the fastest north-side-only route from De Luz to every block.
# This does not force vehicles to continue to Camaron or Rock Mountain.
detour_from_deluz_all_blocks <- calculate_fastest_routes_by_vertex_id(
  graph = graph_north_speedcap,
  from_id = north_de_luz_id,
  to_ids = north_block_vertex_ids,
  destination_ids = paste0("BLOCK_", block_geoids_north),
  route_label = "De Luz directly to northern 2020 Census blocks"
)

suspect_alternative_final_leg <- detour_from_deluz_all_blocks %>%
  filter(destination_id == paste0("BLOCK_", suspect_block_geoid))

if (nrow(suspect_alternative_final_leg) != 1) {
  stop("Could not retrieve the alternative De Luz-to-block route.")
}

# The Station 1 -> De Luz crossing leg is retained in both strategies.
de_luz_prefix_seconds <- detour_leg1$drive_seconds[1]
de_luz_prefix_distance_m <- detour_leg1$distance_m[1]

suspect_route_comparison <- tibble(
  block_geoid_2020 = suspect_block_geoid,
  
  route_strategy = c(
    "Current: De Luz -> Camaron -> Rock Mountain -> block",
    "Alternative: De Luz -> fastest north-side route -> block"
  ),
  
  modeled_drive_min = c(
    suspect_current_result$modeled_drive_min[1],
    (de_luz_prefix_seconds +
       suspect_alternative_final_leg$drive_seconds[1]) / 60
  ),
  
  modeled_distance_km = c(
    suspect_current_result$modeled_distance_km[1],
    (de_luz_prefix_distance_m +
       suspect_alternative_final_leg$distance_m[1]) / 1000
  )
)

print(suspect_route_comparison)

#21 alternate routing test

# ---------------------------------------------------------------------------
# RECONSTRUCT BOTH COMPLETE ROUTES TO THE SUSPECT BLOCK
# ---------------------------------------------------------------------------

# Current route: Station 1 -> De Luz -> Camaron -> Rock Mountain -> block.
current_final_path <- extract_fastest_path_coordinates(
  graph_north_speedcap,
  north_rock_id,
  suspect_vertex_id
)

detour_prefix_df <- tibble(
  x = detour_coords[, 1],
  y = detour_coords[, 2]
)

current_full_route_xy <- bind_rows(
  detour_prefix_df,
  current_final_path %>% slice(-1)
)

# Alternative: Station 1 -> De Luz -> fastest north-side route -> block.
alternative_final_path <- extract_fastest_path_coordinates(
  graph_north_speedcap,
  north_de_luz_id,
  suspect_vertex_id
)

# Verify that the prefix and alternative final leg join.
alternative_handoff_m <- coord_distance_m(
  c(tail(path_leg1$x, 1), tail(path_leg1$y, 1)),
  c(alternative_final_path$x[1], alternative_final_path$y[1])
)

if (alternative_handoff_m > 2) {
  stop("Alternative route does not connect properly at the De Luz handoff.")
}

alternative_full_route_xy <- bind_rows(
  path_leg1,
  alternative_final_path %>% slice(-1)
)

# Verify the alternative north-side final leg avoids the river buffer.
alternative_final_utm <- st_sfc(
  st_linestring(as.matrix(alternative_final_path)),
  crs = 4326
) %>%
  st_transform(26911)

if (lengths(st_intersects(alternative_final_utm, river_buffer_utm)) > 0) {
  stop("Alternative De Luz-to-block route intersects the river buffer.")
}

# Create a two-feature route layer.
suspect_route_comparison_sf <- st_sf(
  route_strategy = c(
    "Current: mandatory Rock Mountain waypoint",
    "Alternative: direct north-side routing after De Luz"
  ),
  
  block_geoid_2020 = suspect_block_geoid,
  
  geometry = st_sfc(
    st_linestring(as.matrix(current_full_route_xy)),
    st_linestring(as.matrix(alternative_full_route_xy)),
    crs = 4326
  )
)

# Highlight the destination block.
suspect_block_geom <- yellow_blocks_map_base_north %>%
  filter(block_geoid_2020 == suspect_block_geoid)

if (nrow(suspect_block_geom) != 1) {
  stop("Could not identify exactly one suspect Census block polygon.")
}

# Plot all road context and both complete routes.
suspect_route_map <- ggplot() +
  
  geom_sf(
    data = roads_normal_final %>% st_transform(4326),
    color = "grey78",
    linewidth = 0.25
  ) +
  
  geom_sf(
    data = river_map_wgs84,
    color = "deepskyblue3",
    linewidth = 1.0
  ) +
  
  geom_sf(
    data = yellow_blocks_map_base_north,
    fill = NA,
    color = "grey65",
    linewidth = 0.2
  ) +
  
  geom_sf(
    data = suspect_block_geom,
    fill = "#F5E65B",
    color = "black",
    linewidth = 0.9
  ) +
  
  geom_sf(
    data = suspect_route_comparison_sf,
    aes(color = route_strategy),
    linewidth = 1.15,
    alpha = 0.95
  ) +
  
  geom_sf(
    data = detour_stop_points_wgs84,
    color = "black",
    fill = "white",
    shape = 21,
    size = 2.5
  ) +
  
  scale_color_manual(
    values = c(
      "Current: mandatory Rock Mountain waypoint" = "#7B1FA2",
      "Alternative: direct north-side routing after De Luz" = "#0072B2"
    )
  ) +
  
  coord_sf(
    crs = st_crs(4326),
    default_crs = st_crs(4326),
    xlim = unname(c(
      MAP_EXTENT_WGS84["xmin"],
      MAP_EXTENT_WGS84["xmax"]
    )),
    ylim = unname(c(
      MAP_EXTENT_WGS84["ymin"],
      MAP_EXTENT_WGS84["ymax"]
    )),
    expand = FALSE
  ) +
  
  labs(
    title = "Full Route Comparison - Suspect 2020 Census Block",
    subtitle = paste("Block GEOID:", suspect_block_geoid),
    color = "Routing strategy",
    x = "Longitude",
    y = "Latitude"
  ) +
  
  theme_bw() +
  
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

print(suspect_route_map)

ggsave(
  file.path(OUTPUT_DIR, "Suspect_Block_Full_Route_Comparison.png"),
  suspect_route_map,
  width = 13,
  height = 10,
  dpi = 300
)

write_csv(
  suspect_route_comparison,
  file.path(OUTPUT_DIR, "Suspect_Block_Route_Comparison.csv")
)
# ---------------------------------------------------------------------------
# 22. ASSEMBLE NORTHERN 2020 BLOCK TIME/DISTANCE TABLES
# ---------------------------------------------------------------------------

block_metadata_north <- yellow_block_lookup_north %>%
  select(
    block_geoid_2020,
    tract_geoid_2020,
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

assemble_north_block_table <- function(route_results, origin_name, scenario_name) {
  output <- route_results %>%
    mutate(block_geoid_2020 = str_remove(destination_id, "^BLOCK_")) %>%
    left_join(block_metadata_north, by = "block_geoid_2020") %>%
    mutate(origin_name = origin_name, scenario = scenario_name) %>%
    select(
      block_geoid_2020,
      tract_geoid_2020,
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
  
  if (nrow(output) != nrow(yellow_block_lookup_north)) {
    stop("Scenario table does not contain exactly one row per northern 2020 Census block.")
  }
  if (anyDuplicated(output$block_geoid_2020)) {
    stop("Duplicate 2020 Census block GEOIDs found in scenario table.")
  }
  output
}

block_times_ncfpd1_normal_north <- assemble_north_block_table(
  routes_ncfpd1_normal_north,
  "NCFPD Station 1",
  "Normal Access"
)
block_times_ncfpd1_deluz_north <- assemble_north_block_table(
  routes_ncfpd1_deluz_north,
  "NCFPD Station 1",
  "Flooded Detour - De Luz/Camaron/Sandia Creek"
)
block_times_temecula_north <- assemble_north_block_table(
  routes_temecula_north,
  "Temecula Civic Center",
  "Bridge Closure - Temecula Response"
)

block_times_ncfpd1_i15_north <- assemble_north_block_table(
  routes_ncfpd1_i15_north,
  "NCFPD Station 1",
  "I-15 / Rancho California Alternative"
)

ncfpd1_travel_time_comparison_north <- block_times_ncfpd1_normal_north %>%
  select(
    block_geoid_2020,
    normal_drive_min = modeled_drive_min,
    normal_distance_km = modeled_distance_km
  ) %>%
  left_join(
    block_times_ncfpd1_deluz_north %>%
      select(
        block_geoid_2020,
        detour_drive_min = modeled_drive_min,
        detour_distance_km = modeled_distance_km
      ),
    by = "block_geoid_2020"
  ) %>%
  mutate(
    added_drive_min = detour_drive_min - normal_drive_min,
    added_distance_km = detour_distance_km - normal_distance_km
  ) %>%
  left_join(
    block_metadata_north %>%
      select(block_geoid_2020, historical_incident_count, destination_method, distance_to_road_m),
    by = "block_geoid_2020"
  ) %>%
  arrange(desc(added_drive_min))

ncfpd1_travel_time_comparison_north <-
  ncfpd1_travel_time_comparison_north %>%
  
  left_join(
    block_times_ncfpd1_i15_north %>%
      select(
        block_geoid_2020,
        i15_drive_min = modeled_drive_min,
        i15_distance_km = modeled_distance_km
      ),
    by = "block_geoid_2020"
  ) %>%
  
  mutate(
    i15_added_drive_min_vs_normal =
      i15_drive_min - normal_drive_min,
    
    i15_added_distance_km_vs_normal =
      i15_distance_km - normal_distance_km,
    
    i15_added_drive_min_vs_deluz =
      i15_drive_min - detour_drive_min
  )

all_north_route_tables <- bind_rows(
  block_times_ncfpd1_normal_north,
  block_times_ncfpd1_deluz_north,
  block_times_temecula_north,
  block_times_ncfpd1_i15_north
)

scenario_summary_north <- all_north_route_tables %>%
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

route_speed_validation_north <- all_north_route_tables %>%
  filter(route_status == "Reachable") %>%
  group_by(scenario) %>%
  summarise(
    routes = n(),
    mean_route_speed_kmh = mean(implied_average_speed_kmh, na.rm = TRUE),
    median_route_speed_kmh = median(implied_average_speed_kmh, na.rm = TRUE),
    maximum_route_speed_kmh = max(implied_average_speed_kmh, na.rm = TRUE),
    routes_over_cap = sum(implied_average_speed_kmh > MAX_MODELED_SPEED_KMH + 0.1, na.rm = TRUE),
    .groups = "drop"
  )
if (any(route_speed_validation_north$routes_over_cap > 0)) {
  stop("At least one scenario route has an implied average speed above the edge speed cap. Check time/distance route alignment.")
}

# ---------------------------------------------------------------------------
# 23. PREPARE MAP INPUTS - ALL GEOMETRIES IN WGS84
# ---------------------------------------------------------------------------

yellow_blocks_map_base_north <- yellow_blocks_north %>% st_transform(4326)

north_tract_ids <- yellow_block_lookup_north %>% distinct(tract_geoid_2020)
tracts_map_wgs84_north <- tracts_in_extent_2020 %>%
  semi_join(north_tract_ids, by = "tract_geoid_2020") %>%
  st_transform(4326)
tract_labels_wgs84_north <- st_point_on_surface(tracts_map_wgs84_north)

river_map_wgs84 <- osm_santa_margarita %>% st_transform(4326)
yellow_area_map_wgs84 <- yellow_area_wgs84
flooded_detour_route_map_wgs84 <- flooded_detour_route_north

# Major roads kept as geographic context; route geometry is highlighted
# separately on the De Luz detour map.
detour_context_roads_wgs84 <- roads_normal_final %>%
  filter(
    !is.na(name),
    str_detect(
      as.character(name),
      regex("De Luz|Camaron|Carancho|Sandia Creek|Rock Mountain", ignore_case = TRUE)
    )
  ) %>% st_transform(4326)

i15_context_roads_wgs84 <- bind_rows(
  i15_motorway_features,
  i15_ramp_features,
  i15_rancho_features,
  i15_avenida_features,
  i15_sandia_features
) %>%
  distinct(osm_id, .keep_all = TRUE) %>%
  st_transform(4326)

detour_context_roads_wgs84 <- bind_rows(
  detour_context_roads_wgs84,
  i15_context_roads_wgs84
) %>%
  distinct(osm_id, .keep_all = TRUE)

# Current bridge OSM line and approximate crossing point for map reference.
current_bridge_line_wgs84 <- osm_roads %>%
  filter(osm_id == CURRENT_SANDIA_BRIDGE_OSM_ID) %>%
  st_transform(4326)
if (nrow(current_bridge_line_wgs84) == 0) {
  warning("Current bridge OSM line not available for map overlay; approximate point will be shown.")
}
old_crossing_wgs84 <- st_sf(
  crossing_name = "Current Sandia Creek Drive bridge",
  geometry = st_sfc(st_point(c(-117.2416111, 33.4140861)), crs = 4326)
)

# All candidate locations, but only those inside the common frame are drawn.
all_site_points_wgs84 <- all_sites %>%
  filter(
    between(origin_lon, MAP_EXTENT_WGS84["xmin"], MAP_EXTENT_WGS84["xmax"]),
    between(origin_lat, MAP_EXTENT_WGS84["ymin"], MAP_EXTENT_WGS84["ymax"])
  ) %>%
  st_as_sf(coords = c("origin_lon", "origin_lat"), crs = 4326, remove = FALSE)

incidents_north_map <- incidents_yellow_north %>% st_transform(4326)

prepare_north_map_data <- function(route_table) {
  if (anyDuplicated(route_table$block_geoid_2020)) stop("Duplicate 2020 GEOIDs in map data.")
  map_data <- yellow_blocks_map_base_north %>%
    left_join(
      route_table %>% select(
        block_geoid_2020,
        modeled_drive_min,
        modeled_distance_km,
        route_status,
        historical_incident_count,
        destination_method,
        distance_to_road_m
      ),
      by = "block_geoid_2020"
    )
  if (any(is.na(map_data$route_status))) stop("A northern 2020 block has no matching route result.")
  map_data %>% mutate(
    modeled_drive_min = if_else(route_status == "Reachable" & is.finite(modeled_drive_min), modeled_drive_min, NA_real_),
    modeled_distance_km = if_else(route_status == "Reachable" & is.finite(modeled_distance_km), modeled_distance_km, NA_real_),
    destination_adjusted = is.finite(distance_to_road_m) & distance_to_road_m > 500
  )
}

map_data_ncfpd1_normal_north <- prepare_north_map_data(block_times_ncfpd1_normal_north)
map_data_ncfpd1_deluz_north <- prepare_north_map_data(block_times_ncfpd1_deluz_north)
map_data_temecula_north <- prepare_north_map_data(block_times_temecula_north)
map_data_ncfpd1_i15_north <- prepare_north_map_data(
  block_times_ncfpd1_i15_north
)
# ---------------------------------------------------------------------------
# 24. SHARED TIME AND DISTANCE COLOR SCALES
# ---------------------------------------------------------------------------

all_north_times <- c(
  block_times_ncfpd1_normal_north$modeled_drive_min,
  block_times_ncfpd1_deluz_north$modeled_drive_min,
  block_times_temecula_north$modeled_drive_min,
  block_times_ncfpd1_i15_north$modeled_drive_min
)
all_north_distances <- c(
  block_times_ncfpd1_normal_north$modeled_distance_km,
  block_times_ncfpd1_deluz_north$modeled_distance_km,
  block_times_temecula_north$modeled_distance_km,
  block_times_ncfpd1_i15_north$modeled_distance_km
)
finite_times <- all_north_times[is.finite(all_north_times)]
finite_distances <- all_north_distances[is.finite(all_north_distances)]
if (length(finite_times) == 0 || length(finite_distances) == 0) {
  stop("No finite north-side travel-time/distance results are available for mapping.")
}
common_time_max_north <- ceiling(max(finite_times) / 5) * 5
common_distance_max_north <- ceiling(max(finite_distances) / 5) * 5
common_time_limits_north <- c(0, common_time_max_north)
common_distance_limits_north <- c(0, common_distance_max_north)
common_time_breaks_north <- seq(0, common_time_max_north, by = 5)
common_distance_breaks_north <- seq(0, common_distance_max_north, by = 5)

# ---------------------------------------------------------------------------
# 25. ONE MAP FUNCTION - IDENTICAL WGS84 EXTENT ON EVERY MAP
# ---------------------------------------------------------------------------

make_north_gradient_map <- function(
    map_data,
    map_title,
    active_origin_name,
    metric = c("time", "distance"),
    show_detour = FALSE,
    route_lines = NULL
) {
  metric <- match.arg(metric)
  if (metric == "time") {
    fill_variable <- "modeled_drive_min"
    fill_limits <- common_time_limits_north
    fill_breaks <- common_time_breaks_north
    legend_title <- "Modeled drive time\n(minutes)"
    metric_description <- "Modeled driving time"
  } else {
    fill_variable <- "modeled_distance_km"
    fill_limits <- common_distance_limits_north
    fill_breaks <- common_distance_breaks_north
    legend_title <- "Modeled road distance\n(km)"
    metric_description <- "Modeled road-network distance"
  }
  
  origin_idx <- which(
    tolower(trimws(all_site_points_wgs84$origin_name)) ==
      tolower(trimws(active_origin_name))
  )
  if (length(origin_idx) != 1) {
    stop("Expected exactly one map origin for ", active_origin_name, "; found ", length(origin_idx))
  }
  active_origin <- all_site_points_wgs84[origin_idx, , drop = FALSE]
  adjusted_blocks <- map_data %>% filter(destination_adjusted)
  
  p <- ggplot() +
    geom_sf(
      data = map_data,
      aes(fill = .data[[fill_variable]]),
      color = "grey35",
      linewidth = 0.22
    ) +
    geom_sf(
      data = adjusted_blocks,
      fill = NA,
      color = "black",
      linetype = "dashed",
      linewidth = 0.65
    ) +
    geom_sf(
      data = tracts_map_wgs84_north,
      fill = NA,
      color = "black",
      linewidth = 0.45
    ) +
    geom_sf_text(
      data = tract_labels_wgs84_north,
      aes(label = tract_geoid_2020),
      size = 2.2,
      color = "black",
      check_overlap = TRUE
    ) +
    geom_sf(
      data = yellow_area_map_wgs84,
      fill = NA,
      color = "#C99000",
      linetype = "dashed",
      linewidth = 0.9
    ) +
    geom_sf(
      data = river_map_wgs84,
      color = "deepskyblue3",
      linewidth = 1.15
    ) +
    geom_sf(
      data = detour_context_roads_wgs84,
      color = "grey55",
      linewidth = 0.5
    ) +
    geom_sf(
      data = incidents_north_map,
      color = "firebrick",
      size = 0.36,
      alpha = 0.5
    ) +
    geom_sf(
      data = all_site_points_wgs84,
      color = "grey40",
      shape = 8,
      size = 3,
      stroke = 1
    ) +
    geom_sf(
      data = active_origin,
      color = "black",
      shape = 8,
      size = 5.2,
      stroke = 1.5
    ) +
    geom_sf_text(
      data = active_origin,
      aes(label = site_label),
      color = "black",
      size = 2.8,
      nudge_y = 0.002,
      check_overlap = TRUE,
      show.legend = FALSE
    ) +
    geom_sf(
      data = old_crossing_wgs84,
      color = "blue",
      shape = 17,
      size = 3.4
    ) +
    scale_fill_gradientn(
      colors = c("#16803C", "#78B957", "#F5E65B", "#EF963D", "#C62828"),
      limits = fill_limits,
      breaks = fill_breaks,
      oob = scales::squish,
      na.value = "grey78",
      name = legend_title
    ) +
    # Direct WGS84 limits are used rather than projected UTM limits. This is
    # the same exact geographic rectangle for all six maps.
    coord_sf(
      crs = st_crs(4326),
      default_crs = st_crs(4326),
      xlim = unname(c(MAP_EXTENT_WGS84["xmin"], MAP_EXTENT_WGS84["xmax"])),
      ylim = unname(c(MAP_EXTENT_WGS84["ymin"], MAP_EXTENT_WGS84["ymax"])),
      expand = FALSE
    ) +
    labs(
      title = map_title,
      subtitle = paste0(metric_description, " to north-side 2020 Census block road-access destinations"),
      x = "Longitude",
      y = "Latitude",
      caption = paste(
        "Red points = geocoded 2014-2018 incidents in retained north-side blocks;",
        "blue triangle = current Sandia Creek Drive bridge;",
        "orange line (detour map only) = Station 1 -> De Luz -> Camaron -> Rock Mountain;",
        "dashed gold = yellow study boundary; dashed black = block road-access snap >500 m;",
        "grey fill = no connected route. All post-De Luz legs use north-side-only roads."
      )
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      panel.grid = element_line(color = "grey90"),
      legend.position = "right"
    )
  # Overlay actual dodgr fastest-time paths to individual block destinations.
  if (!is.null(route_lines) && nrow(route_lines) > 0) {
    
    # All modeled routes: thin, partially transparent charcoal lines.
    p <- p +
      geom_sf(
        data = route_lines,
        color = "grey15",
        linewidth = 0.30,
        alpha = 0.30,
        inherit.aes = FALSE
      ) +
      
      # Highlight the destination with the longest modeled drive time.
      geom_sf(
        data = route_lines %>% filter(is_longest_route),
        color = "#7B1FA2",
        linewidth = 1.05,
        alpha = 1,
        inherit.aes = FALSE
      ) +
      
      # Re-draw the active origin so it remains visible over the routes.
      geom_sf(
        data = active_origin,
        color = "black",
        shape = 8,
        size = 5.2,
        stroke = 1.5,
        inherit.aes = FALSE
      )
  }
  if (show_detour) {
    p <- p +
      geom_sf(
        data = flooded_detour_route_map_wgs84,
        color = "#E69F00",
        linewidth = 1.7
      ) +
      geom_sf(
        data = detour_stop_points_wgs84 %>% filter(stop_order > 0),
        shape = 21,
        fill = "white",
        color = "black",
        size = 2.8
      ) +
      geom_sf_text(
        data = detour_stop_points_wgs84 %>% filter(stop_order > 0),
        aes(label = stop_name),
        color = "black",
        size = 2.5,
        nudge_y = 0.0015,
        check_overlap = TRUE,
        show.legend = FALSE
      )
  }
  p
}

# ---------------------------------------------------------------------------
# 26. GENERATE THREE TIME MAPS AND THREE DISTANCE MAPS
# ---------------------------------------------------------------------------

# NCFPD Station 1 - Normal
map_north_ncfpd1_normal_time <- make_north_gradient_map(
  map_data_ncfpd1_normal_north,
  "NCFPD Station 1 - Normal Access",
  "NCFPD Station 1",
  metric = "time",
  show_detour = FALSE,
  route_lines = route_lines_ncfpd1_normal_north
)

map_north_ncfpd1_normal_distance <- make_north_gradient_map(
  map_data_ncfpd1_normal_north,
  "NCFPD Station 1 - Normal Access Distance",
  "NCFPD Station 1",
  metric = "distance",
  show_detour = FALSE,
  route_lines = route_lines_ncfpd1_normal_north
)


# NCFPD Station 1 - Flooded De Luz detour
map_north_ncfpd1_deluz_time <- make_north_gradient_map(
  map_data_ncfpd1_deluz_north,
  "NCFPD Station 1 - Flooded De Luz Detour",
  "NCFPD Station 1",
  metric = "time",
  show_detour = TRUE,
  route_lines = route_lines_ncfpd1_deluz_north
)

map_north_ncfpd1_deluz_distance <- make_north_gradient_map(
  map_data_ncfpd1_deluz_north,
  "NCFPD Station 1 - Flooded De Luz Detour Distance",
  "NCFPD Station 1",
  metric = "distance",
  show_detour = TRUE,
  route_lines = route_lines_ncfpd1_deluz_north
)

map_north_ncfpd1_i15_time <- make_north_gradient_map(
  map_data_ncfpd1_i15_north,
  "NCFPD Station 1 - I-15 / Rancho California Alternative",
  "NCFPD Station 1",
  metric = "time",
  show_detour = FALSE,
  route_lines = route_lines_ncfpd1_i15_north
)

map_north_ncfpd1_i15_distance <- make_north_gradient_map(
  map_data_ncfpd1_i15_north,
  "NCFPD Station 1 - I-15 Alternative Distance",
  "NCFPD Station 1",
  metric = "distance",
  show_detour = FALSE,
  route_lines = route_lines_ncfpd1_i15_north
)


# Temecula Civic Center - Bridge closure
map_north_temecula_time <- make_north_gradient_map(
  map_data_temecula_north,
  "Temecula Civic Center - Bridge Closure",
  "Temecula Civic Center",
  metric = "time",
  show_detour = FALSE,
  route_lines = route_lines_temecula_north
)

map_north_temecula_distance <- make_north_gradient_map(
  map_data_temecula_north,
  "Temecula Civic Center - Bridge Closure Distance",
  "Temecula Civic Center",
  metric = "distance",
  show_detour = FALSE,
  route_lines = route_lines_temecula_north
)

print(map_north_ncfpd1_normal_time)
print(map_north_ncfpd1_deluz_time)
print(map_north_temecula_time)
print(map_north_ncfpd1_normal_distance)
print(map_north_ncfpd1_deluz_distance)
print(map_north_temecula_distance)
print(map_north_ncfpd1_i15_time)
print(map_north_ncfpd1_i15_distance)

# ---------------------------------------------------------------------------
# 27. EXPORT TABLES, QA, SIX MAPS, GEOPACKAGE, AND REPRODUCIBILITY RDS
# ---------------------------------------------------------------------------

write_csv(block_times_ncfpd1_normal_north, file.path(OUTPUT_DIR, "Block_Times_2020_NCFPD1_Normal_North.csv"))
write_csv(block_times_ncfpd1_deluz_north, file.path(OUTPUT_DIR, "Block_Times_2020_NCFPD1_Flooded_Detour_North.csv"))
write_csv(block_times_temecula_north, file.path(OUTPUT_DIR, "Block_Times_2020_Temecula_Closure_North.csv"))
write_csv(ncfpd1_travel_time_comparison_north, file.path(OUTPUT_DIR, "NCFPD1_Normal_vs_Flooded_Detour_2020_North.csv"))
write_csv(scenario_summary_north, file.path(OUTPUT_DIR, "Scenario_Summary_Time_and_Distance_2020_North.csv"))
write_csv(route_speed_validation_north, file.path(OUTPUT_DIR, "Route_Speed_Validation_2020_North.csv"))
write_csv(crossing_decision_audit, file.path(OUTPUT_DIR, "River_Crossing_Decisions_2020_North.csv"))
write_csv(block_snap_review, file.path(OUTPUT_DIR, "2020_Block_Road_Access_Snap_Review.csv"))
write_csv(
  block_times_ncfpd1_i15_north,
  file.path(
    OUTPUT_DIR,
    "Block_Times_2020_NCFPD1_I15_Alternative.csv"
  )
)

write_csv(
  ncfpd1_travel_time_comparison_north,
  file.path(
    OUTPUT_DIR,
    "NCFPD1_Normal_DeLuz_I15_Comparison.csv"
  )
)

map_objects <- list(
  Arrival_Time_NCFPD1_I15_Alternative_2020_North =
    map_north_ncfpd1_i15_time,
  Arrival_Distance_NCFPD1_I15_Alternative_2020_North =
    map_north_ncfpd1_i15_distance
  Arrival_Time_NCFPD1_Normal_2020_North = map_north_ncfpd1_normal_time,
  Arrival_Time_NCFPD1_Flooded_Detour_2020_North = map_north_ncfpd1_deluz_time,
  Arrival_Time_Temecula_Closure_2020_North = map_north_temecula_time,
  Arrival_Distance_NCFPD1_Normal_2020_North = map_north_ncfpd1_normal_distance,
  Arrival_Distance_NCFPD1_Flooded_Detour_2020_North = map_north_ncfpd1_deluz_distance,
  Arrival_Distance_Temecula_Closure_2020_North = map_north_temecula_distance
)
for (map_name in names(map_objects)) {
  ggsave(
    filename = file.path(OUTPUT_DIR, paste0(map_name, ".png")),
    plot = map_objects[[map_name]],
    width = 13,
    height = 10,
    units = "in",
    dpi = 300
  )
}

# Spatial output. Each layer contains 2020 block polygons plus time, distance,
# incident count, and access-snap fields for its scenario.
map_gpkg <- file.path(OUTPUT_DIR, "Sandia_Creek_2020_North_Access_Maps.gpkg")
if (file.exists(map_gpkg)) file.remove(map_gpkg)
st_write(map_data_ncfpd1_normal_north, map_gpkg, layer = "NCFPD1_Normal", quiet = TRUE)
st_write(map_data_ncfpd1_deluz_north, map_gpkg, layer = "NCFPD1_Flooded_Detour", append = TRUE, quiet = TRUE)
st_write(map_data_temecula_north, map_gpkg, layer = "Temecula_Bridge_Closure", append = TRUE, quiet = TRUE)
st_write(
  route_lines_ncfpd1_normal_north,
  map_gpkg,
  layer = "NCFPD1_Normal_Route_Lines",
  append = TRUE,
  quiet = TRUE
)

st_write(
  route_lines_ncfpd1_deluz_north,
  map_gpkg,
  layer = "NCFPD1_Flooded_Detour_Route_Lines",
  append = TRUE,
  quiet = TRUE
)

st_write(
  route_lines_temecula_north,
  map_gpkg,
  layer = "Temecula_Closure_Route_Lines",
  append = TRUE,
  quiet = TRUE
)

st_write(
  route_lines_ncfpd1_deluz_north,
  map_gpkg,
  layer = "NCFPD1_Flooded_Closure_Full_Routes",
  append = TRUE,
  quiet = TRUE
)
st_write(
  map_data_ncfpd1_i15_north,
  map_gpkg,
  layer = "NCFPD1_I15_Alternative",
  append = TRUE,
  quiet = TRUE
)

st_write(
  route_lines_ncfpd1_i15_north,
  map_gpkg,
  layer = "NCFPD1_I15_Alternative_Route_Lines",
  append = TRUE,
  quiet = TRUE
)

saveRDS(
  list(
    all_sites = all_sites,
    yellow_area = yellow_area_wgs84,
    block_side_lookup = block_side_lookup,
    yellow_block_lookup_north = yellow_block_lookup_north,
    special_target_block_geoid_2020 = SPECIAL_TARGET_BLOCK_GEOID,
    detour_waypoints_snapped = detour_waypoints_snapped,
    river_way_audit = river_way_audit,
    roads_normal_final = roads_normal_final,
    roads_i15_access = roads_i15_access,
    i15_access_network = i15_access_network,
    i15_north_network = i15_north_network,
    graph_i15_access_speedcap = graph_i15_access_speedcap,
    graph_i15_north_speedcap = graph_i15_north_speedcap,
    i15_waypoints_snapped = i15_waypoints_snapped,
    i15_river_contact_audit = i15_river_contact_audit,
    i15_stage2_road_use = i15_stage2_road_use,
    i15_routes = routes_ncfpd1_i15_north,
    i15_route_lines = route_lines_ncfpd1_i15_north,
    i15_table = block_times_ncfpd1_i15_north
    roads_closed_prefix = roads_closed_prefix,
    roads_north_side = roads_north_side,
    graph_normal_speedcap = graph_normal_speedcap,
    graph_closure_prefix_speedcap = graph_closure_prefix_speedcap,
    graph_north_speedcap = graph_north_speedcap,
    flooded_detour_route_north = flooded_detour_route_north,
    normal_table = block_times_ncfpd1_normal_north,
    detour_table = block_times_ncfpd1_deluz_north,
    temecula_table = block_times_temecula_north,
    comparison = ncfpd1_travel_time_comparison_north,
    scenario_summary = scenario_summary_north,
    speed_validation = route_speed_validation_north,
    map_objects = map_objects,
    graph_flooded_access_speedcap = graph_flooded_access_speedcap,
    flooded_access_network = flooded_access_network,
    route_lines_flooded_closure = route_lines_ncfpd1_deluz_north,
    harris_turn_snap = harris_turn_snap,
  ),
  file.path(OUTPUT_DIR, "Sandia_Creek_2020_NorthOnly_Master_Results.rds")
)

#LONGEST ROUTE TABLES:
# Identify the highest modeled drive-time destination in each scenario.
longest_route_qa <- bind_rows(
  route_lines_ncfpd1_normal_north %>%
    st_drop_geometry() %>%
    filter(is_longest_route),
  
  route_lines_ncfpd1_deluz_north %>%
    st_drop_geometry() %>%
    filter(is_longest_route),
  
  route_lines_temecula_north %>%
    st_drop_geometry() %>%
    filter(is_longest_route)
) %>%
  select(
    scenario,
    block_geoid_2020,
    modeled_drive_min,
    modeled_distance_km,
    implied_average_speed_kmh
  )

write_csv(
  longest_route_qa,
  file.path(OUTPUT_DIR, "Longest_Dodgr_Route_By_Scenario.csv")
)

print(longest_route_qa)
message("============================================================")
message("2020 NORTH-ONLY MASTER ANALYSIS COMPLETE")
message("2020 north-side Census blocks routed: ", nrow(yellow_block_lookup_north))
message("Special target 2020 GEOID: ", SPECIAL_TARGET_BLOCK_GEOID)
message("Output folder: ", normalizePath(OUTPUT_DIR, mustWork = FALSE))
message("Six maps, three tables, comparison, QA files, GeoPackage, and RDS saved.")
message("Review North_South_2020_Block_Classification_Check.png and QA CSVs before interpretation.")
message("All post-De Luz detour legs and Temecula routes use a north-side-only road graph.")
message("============================================================")
