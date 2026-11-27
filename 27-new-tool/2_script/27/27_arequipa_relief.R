# Arequipa, looking up and looking down | Day 27, New tool
# Harry Aquije Ballon

#===============================================================================
# 1. Project, packages and public downloads ----
#===============================================================================

# Open 27-new-tool.Rproj to run the sections. If you start R elsewhere,
# you can also set this line to the full path of your downloaded Day 27 folder.
project_root <- "C:/Users/harry/Desktop/projects/30daymapchallenge/27-new-tool"
folder <- normalizePath(getwd(), winslash = "/")
if (file.exists(file.path(folder, "27-new-tool", "27-new-tool.Rproj"))) {
  folder <- file.path(folder, "27-new-tool")
}
while (!file.exists(file.path(folder, "27-new-tool.Rproj")) && dirname(folder) != folder) {
  folder <- dirname(folder)
}
if (file.exists(file.path(folder, "27-new-tool.Rproj"))) project_root <- folder
if (!file.exists(file.path(project_root, "27-new-tool.Rproj"))) {
  stop("Set project_root in section 1 to the folder containing 27-new-tool.Rproj.")
}
needed <- c("terra", "sf", "jsonlite", "tanaka", "ragg")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install with install.packages(c(",
                          paste(sprintf('"%s"', missing), collapse = ", "), "))")

day_folder <- function(stage) file.path(project_root, "1_analysis", stage, "27_new_tool")
raw_dir <- day_folder("00_raw_data")
clean_dir <- day_folder("01_clean_data")
intermediate_dir <- day_folder("02_intermediate_data")
output_dir <- day_folder("03_output")
for (path in c(raw_dir, clean_dir, intermediate_dir, output_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

# Reuse the saved originals. Only a missing input needs internet access.
# Download to a temporary name so an interrupted transfer cannot become an input.
get_input <- function(filename, url) {
  path <- file.path(raw_dir, filename)
  if (!file.exists(path)) {
    part <- tempfile(tmpdir = raw_dir)
    on.exit(unlink(part))
    if (download.file(url, part, mode = "wb") != 0L || !file.rename(part, path)) {
      stop("Could not save ", filename)
    }
  }
  path
}
get_tile <- function(tile) {
  stem <- paste0("Copernicus_DSM_COG_30_", tile, "_DEM")
  filename <- paste0(stem, ".tif")
  get_input(filename, paste("https://copernicus-dem-90m.s3.amazonaws.com",
                            stem, filename, sep = "/"))
}
misti_dem <- terra::rast(get_tile("S17_00_W072_00"))
colca_east <- terra::rast(get_tile("S16_00_W072_00"))
colca_west <- terra::rast(get_tile("S16_00_W073_00"))
colca_dem <- terra::merge(colca_west, colca_east)

#===============================================================================
# 2. Rivers and landmarks ----
#===============================================================================

# Both official OSM relations describe entire rivers. Each member way lists
# its surveyed nodes in order. Keep the main channel and reconstruct each way.

utm <- 32719    # WGS 84 / UTM zone 19S. Distances in this projection are metres.
read_main_channel <- function(filename, id) {
  url <- sprintf("https://api.openstreetmap.org/api/0.6/relation/%s/full.json", id)
  elements <- jsonlite::read_json(get_input(filename, url))$elements
  type <- vapply(elements, "[[", "", "type")
  nodes <- elements[type == "node"]
  node_ids <- vapply(nodes, function(n) as.character(n$id), "")
  lonlat <- t(vapply(nodes, function(n) c(n$lon, n$lat), numeric(2)))
  relation <- Filter(function(e) e$type == "relation" && e$id == id, elements)
  stopifnot(length(relation) == 1L)
  members <- Filter(function(m) m$type == "way" && m$role == "main_stream",
                    relation[[1]]$members)
  ids <- vapply(members, "[[", numeric(1), "ref")
  ways <- Filter(function(e) e$type == "way" && e$id %in% ids, elements)
  stopifnot(length(ways) > 0, length(ways) == length(ids))
  lines <- lapply(ways, function(w) {
    rows <- match(as.character(unlist(w$nodes)), node_ids)
    stopifnot(!anyNA(rows))
    sf::st_linestring(lonlat[rows, , drop = FALSE])
  })
  sf::st_transform(sf::st_sfc(lines, crs = 4326), utm)
}

chili <- read_main_channel("rio_chili_relation_2237688.json", 2237688)
colca <- read_main_channel("colca_relation_2634345.json", 2634345)

point_utm <- function(lon, lat) {
  sf::st_transform(sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326), utm)
}

plaza <- point_utm(-71.5369, -16.3988)             # Centre of the Plaza de Armas
misti_reference <- point_utm(-71.4073, -16.2980)  # Instituto Geofísico del Perú
lookout <- point_utm(-71.905903, -15.611146)       # MINCETUR inventory, site 615

# The IGP reference falls inside the crater. Choose the highest native DEM
# cell within 1 km of that reference to locate the summit rim on this grid.
summit_area <- sf::st_buffer(misti_reference, 1000)
summit_window <- terra::crop(misti_dem, terra::vect(sf::st_transform(summit_area, 4326)),
                             snap = "out")
cells <- terra::as.data.frame(summit_window, xy = TRUE, na.rm = TRUE)
names(cells) <- c("lon", "lat", "elevation_m")
cell_points <- sf::st_transform(sf::st_as_sf(cells, coords = c("lon", "lat"), crs = 4326), utm)
in_circle <- lengths(sf::st_within(cell_points, summit_area)) > 0
rim <- cell_points[in_circle, ]
summit <- sf::st_geometry(rim[which.max(rim$elevation_m), ])

# Shortest horizontal line from the official lookout to the main channel.
# The second vertex is the nearest point on the river, including between nodes.
to_river <- sf::st_nearest_points(lookout, sf::st_union(colca))
river_xy <- unname(sf::st_coordinates(to_river)[2, c("X", "Y")])
river_point <- sf::st_sfc(sf::st_point(river_xy), crs = utm)

#===============================================================================
# 3. Measure both straight-line profiles in the ORIGINAL elevation grids ----
#===============================================================================

# Sample at approximately the native 90 m spacing. Include both endpoints.
# Bilinear interpolation estimates the surface at a point between cell centres.

sample_profile <- function(area, from, to, dem) {
  a <- as.numeric(sf::st_coordinates(from))
  b <- as.numeric(sf::st_coordinates(to))
  metres <- sqrt(sum((b - a)^2))
  fraction <- seq(0, 1, length.out = ceiling(metres / 90) + 1L)
  sample_xy <- data.frame(x = a[1] + fraction * (b[1] - a[1]),
                          y = a[2] + fraction * (b[2] - a[2]))
  pts <- sf::st_as_sf(sample_xy, coords = c("x", "y"), crs = utm)
  lonlat <- sf::st_coordinates(sf::st_transform(pts, 4326))
  z <- terra::extract(dem, lonlat, method = "bilinear")[[1]]
  stopifnot(all(is.finite(z)))
  data.frame(area, distance_m = fraction * metres, elevation_m = z,
             longitude = lonlat[, 1], latitude = lonlat[, 2], row.names = NULL)
}

misti_profile <- sample_profile("El Misti", plaza, summit, misti_dem)
colca_profile <- sample_profile("Colca Canyon", lookout, river_point, colca_dem)
profiles <- rbind(misti_profile, colca_profile)
endpoints <- rbind(misti_profile[c(1, nrow(misti_profile)), ],
                   colca_profile[c(1, nrow(colca_profile)), ])
endpoints$place <- c("Plaza de Armas", "El Misti summit rim", "Cruz del Cóndor", "Río Colca")
relief <- function(p) tail(p$elevation_m, 1) - p$elevation_m[1]
stopifnot(relief(misti_profile) > 0, relief(colca_profile) < 0)

write.csv(endpoints, file.path(clean_dir, "transect_endpoints.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")

write.csv(profiles, file.path(intermediate_dir, "elevation_profiles.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")

#===============================================================================
# 4. Build the Tanaka contours on equal map windows ----
#===============================================================================

# Both frames cover 30 by 25 km. The 100 m plot grid is horizontal spacing.
# The 100 m contour interval is a separate choice about vertical elevation.
make_map <- function(dem, river, from, to) {
  xy <- rbind(sf::st_coordinates(from), sf::st_coordinates(to))
  centre <- colMeans(xy)
  xr <- centre[1] + c(-15000, 15000)
  yr <- centre[2] + c(-12500, 12500)
  bounds <- sf::st_bbox(c(xmin = xr[1], ymin = yr[1], xmax = xr[2], ymax = yr[2]),
                        crs = sf::st_crs(utm))
  # Extra cells beyond the frame prevent an artificial border in the shading.
  template <- terra::rast(terra::ext(xr[1]-200, xr[2]+200, yr[1]-200, yr[2]+200),
                          resolution = 100, crs = "EPSG:32719")
  grid <- terra::project(dem, template, method = "bilinear")
  stopifnot(!anyNA(terra::values(grid)))
  limits <- range(terra::minmax(grid))
  breaks <- seq(floor(limits[1] / 100) * 100, ceiling(limits[2] / 100) * 100, by = 100)
  bands <- tanaka::tanaka_contour(grid, breaks = breaks)
  main_channel <- sf::st_crop(river, bounds)
  stopifnot(length(main_channel) > 0, nrow(bands) > 1)
  list(bands = bands, river = main_channel, xy = xy, xr = xr, yr = yr)
}
misti_map <- make_map(misti_dem, chili, plaza, summit)
colca_map <- make_map(colca_dem, colca, lookout, river_point)

#===============================================================================
# 5. Draw the maps and profiles ----
#===============================================================================

# Colour has the same elevation meaning on both maps. The Tanaka package
# supplies the directional highlights and shadows on the edges of the bands.
paper <- "#F9F6EE"
ink <- "#252F2C"
muted <- "#53605A"
rule <- "#C5BFB1"
river_ink <- "#125F70"
section_ink <- "#85391F"
palette_height <- grDevices::colorRamp(c("#97A99B", "#C2C2A3", "#D8C19B",
                                         "#D9AD87", "#E7C7A6", "#F5E8CA"))
terrain_colour <- function(z) {
  rgb <- palette_height(pmax(0, pmin(1, (z - 1200) / 4800)))
  grDevices::rgb(rgb[,1], rgb[,2], rgb[,3], maxColorValue = 255)
}

fmt_m <- function(x) format(round(x), big.mark = ",", trim = TRUE)
# Endpoint labels show the nearest modelled metre; the headline change is
# calculated before rounding and then rounded to the nearest ten metres.
fmt_change <- function(p) paste0(fmt_m(round(abs(relief(p)) / 10) * 10), " m")

# Draw with normalised page coordinates. Each map has exactly the same physical
# width and the same aspect ratio. The axes below share km and elevation scales.
window <- function(box, xr = c(0, 1), yr = c(0, 1), aspect = NA) {
  par(fig = box, new = TRUE, mar = rep(0, 4), xaxs = "i", yaxs = "i")
  plot.new()
  plot.window(xr, yr, asp = aspect)
}

label <- function(x, y, txt, size = 1, colour = ink, align = 0, face = 1,
                  family = "sans") {
  text(x, y, txt, adj = c(align, .5), cex = size, col = colour,
       font = face, family = family)
}

map_label <- function(anchor, offset, txt, align, colour = ink) {
  pos <- anchor + offset
  segments(anchor[1], anchor[2], pos[1], pos[2], col = colour, lwd = .85)
  w <- strwidth(txt, cex = .88, font = 2)
  h <- strheight("Mg", cex = .88, font = 2)
  rect(pos[1] - align*w - 175, pos[2] - h*.83,
       pos[1] + (1-align)*w + 175, pos[2] + h*.83, col = paper, border = NA)
  label(pos[1], pos[2], txt, .88, colour, align, 2)
}

draw_map <- function(map, box, is_misti) {
  window(box, map$xr, map$yr, 1)
  bands <- map$bands[order(map$bands$min), ]
  tanaka::tanaka(bands, col = terrain_colour((bands$min + bands$max) / 2),
                 shift = 40, light = "#FAEFCE", dark = "#8C795F",
                 legend.pos = NA, add = TRUE)
  plot(map$river, add = TRUE, col = river_ink, lwd = 1.3)
  xy <- map$xy
  lines(xy, col = paper, lwd = 3.3)
  lines(xy, col = section_ink, lwd = 1.9, lty = "22")
  if (is_misti) {
    map_label(xy[1,], c(-950,-1350), "Plaza de Armas", 1)
    map_label(xy[2,], c(1050,1450), "Summit rim", 0)
    # Anchor the river label to a visible vertex northwest of the plaza.
    river_xy <- sf::st_coordinates(map$river)[, c("X","Y"), drop = FALSE]
    target <- xy[1,] + c(-3400, 6500)
    nearest <- which.min((river_xy[,1]-target[1])^2 + (river_xy[,2]-target[2])^2)
    map_label(river_xy[nearest,], c(-950, 600), "Río Chili", 1, river_ink)
  } else {
    map_label(xy[1,], c(-1500,-1850), "Cruz del Cóndor", 1)
    map_label(xy[2,], c(1600, 1900), "Río Colca", 0, river_ink)
  }
  points(xy, pch = 21, bg = c(paper, section_ink), col = section_ink, cex = .93, lwd = 1.5)
  # The scale bar is five kilometres in projected coordinates.
  sx <- map$xr[1] + 850
  sy <- map$yr[1] + 600
  rect(sx-260, sy-240, sx+5400, sy+1050, col = paper, border = NA)
  segments(sx, sy, sx+5000, sy, lwd = 1.5, col = ink)
  segments(c(sx,sx+5000), sy, c(sx,sx+5000), sy+220, col = ink)
  label(sx+2500, sy+590, "5 km", .7, align = .5)
  box(col = rule, lwd = .75)
}

draw_profile <- function(p, left, right, is_misti) {
  # Use identical plotting areas, with free space to the right of a short line.
  window(c(left+.034, right-.011, .148, .305), c(0, 20), c(1800, 6200))
  at <- c(2000, 4000, 6000)
  abline(h = at, col = rule, lwd = .7, lty = "33")
  x <- p$distance_m / 1000
  z <- p$elevation_m
  polygon(c(x, rev(range(x))), c(z, 1800, 1800), col = "#D9C7A8", border = NA)
  lines(x, z, col = section_ink, lwd = 2)
  points(range(x), c(z[1], tail(z,1)), pch = 21, bg = c(paper, section_ink),
         col = section_ink, cex = .78, lwd = 1.2, xpd = NA)
  axis(2, at, format(at, big.mark = ","), las = 1, tick = FALSE, line = -.5,
       cex.axis = .72, col.axis = muted, mgp = c(0,.5,0))
  axis(1, seq(0,20,5), labels = c("0","5","10","15","20 km"), line = 0,
       lwd = .65, tck = -.025, cex.axis = .74, col = rule, col.axis = muted,
       mgp = c(0,.40,0))
  if (!is_misti) {
    label(3, 3780, paste0("Lookout   ", fmt_m(z[1]), " m"), .81)
    label(3, 2650, paste0("River   ", fmt_m(tail(z,1)), " m"), .81)
  } else {
    label(.6, z[1]+400, paste0(fmt_m(z[1]), " m"), .78)
    label(tail(x,1)-.6, tail(z,1)+35, paste0(fmt_m(tail(z,1)), " m"), .78, align = 1)
  }
}

#===============================================================================
# 6. Export the figure ----
#===============================================================================

draw_figure <- function() {
  par(mar = rep(0,4), bg = paper, family = "sans", fg = ink,
      xaxs = "i", yaxs = "i", cex = 1, xpd = FALSE)
  plot.new()
  plot.window(c(0,1), c(0,1))
  left <- c(.048, .515)
  right <- c(.485, .952)
  label(.048,.966,"SOUTHERN PERU", .92, section_ink, face = 2)
  label(.952,.966,"27 NOVEMBER 2026   /   NEW TOOL", .84, muted, 1)
  label(.045,.920,"Arequipa, looking up and looking down", 2.70, family = "serif")
  label(.048,.873,"From the Plaza de Armas to El Misti’s summit, and from Cruz del Cóndor to the river below.", 1.08)
  segments(.048,.847,.952,.847, col = rule)
  label(left[1],.817,"El Misti",1.59,face=2,family="serif")
  label(left[2],.817,"Colca Canyon",1.59,face=2,family="serif")
  label(right[1],.816,paste(fmt_change(misti_profile), "rise"),1.15,section_ink,1,2)
  label(right[2],.816,paste(fmt_change(colca_profile), "local drop"),1.15,section_ink,1,2)
  map_top <- .788
  map_bottom <- map_top - (right[1]-left[1]) * (12/10.6) * (25/30)
  draw_map(misti_map, c(left[1], right[1], map_bottom, map_top), TRUE)
  draw_map(colca_map, c(left[2], right[2], map_bottom, map_top), FALSE)

  window(c(0,1,0,1))
  label(left[1],.342,"Plaza de Armas to summit rim",1.07,face=2)
  label(left[2],.342,"Cruz del Cóndor to Río Colca",1.07,face=2)
  distance_label <- function(p) sprintf("%.1f km", tail(p$distance_m,1)/1000)
  label(right[1],.342,distance_label(misti_profile),1,muted,1)
  label(right[2],.342,distance_label(colca_profile),1,muted,1)
  draw_profile(misti_profile,left[1],right[1],TRUE)
  draw_profile(colca_profile,left[2],right[2],FALSE)

  window(c(0,1,0,1))
  segments(.048,.104,.952,.104,col=rule)
  label(.048,.083,"Elevation above sea level",.83,face=2)
  swatches <- seq(1900, 6000, length.out = 50)
  strip <- seq(.225,.375,length.out = length(swatches)+1)
  rect(head(strip,-1),.076,tail(strip,-1),.089,col=terrain_colour(swatches),border=NA)
  label(.220,.082,"1,900",.70,muted,1)
  label(.381,.082,"6,000 m",.70,muted)
  segments(.494,.082,.515,.082,col=section_ink,lwd=1.7,lty="22")
  label(.523,.082,"Profile line",.80)
  label(.952,.082,"100 m contours   /   Northwest light   /   North up",.79,muted,1)
  label(.048,.052,"Surface elevations from Copernicus GLO-90. Rivers © OpenStreetMap contributors. Landmarks from IGP and MINCETUR.",.76,muted)
  label(.048,.029,"produced using Copernicus WorldDEM-90 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved",.60,muted)
}

map_file <- file.path(output_dir, "27_arequipa_looking_up_and_down_v1.png")
ragg::agg_png(map_file, width = 12, height = 10.6, units = "in", res = 300,
              pointsize = 12, background = paper)

tryCatch(draw_figure(), finally = dev.off())
print(endpoints[, c("place", "elevation_m", "distance_m")], row.names = FALSE)
message("Saved ", map_file)
