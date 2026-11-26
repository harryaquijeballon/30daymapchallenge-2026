# Where Peru's catch comes ashore | Day 26, Water
# Harry Aquije Ballon

#===============================================================================
# Open 30daymapchallenge.Rproj. Run each section in order, or source this
# whole file to rebuild the tables, map and CSV of plotted values.

# Packages ----
needed <- c("readxl", "dplyr", "sf", "units", "ggplot2", "patchwork", "ragg")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install the missing packages: ", paste(missing, collapse = ", "))
library(ggplot2)

# 1. Prepare the landing tables ----
# From the scripts folder, use the copy beside this map. From the project
# root, use the path below. Update it if you move the scripts to another folder.
project_root <- "C:/Users/harry/Desktop/projects/30daymapchallenge"

prep_script <- file.path(
  project_root, "2_script", "26", "26_water_check_landings_2025.R"
)

source(prep_script, encoding = "UTF-8", chdir = TRUE)

# The preparation script sets raw_dir and clean_dir and writes three CSVs.
lookup <- read.csv(file.path(raw_dir, "ports_reference.csv"), fileEncoding = "UTF-8")
read_clean <- function(name) read.csv(file.path(clean_dir, name), fileEncoding = "UTF-8")
fleet <- read_clean("artisanal_marine_site_totals_2025.csv")
species <- read_clean("artisanal_marine_site_resource_2025.csv")
meal <- read_clean("anchoveta_for_fishmeal_by_port_2025.csv")
named <- subset(fleet, location_type == "named locality")
pooled <- subset(fleet, location_type == "combined localities")
unspecified <- subset(fleet, location_type == "unspecified")

# 2. Match the ports ----
# Match only individually reported places. Chicama is another name for
# Malabrigo. The gazetteer calls Supe Puerto "Supe". In the artisanal file,
# SUPE/VIDAL and CARQUIN/HUACHO cover two places each. Their tonnes stay in
# the coverage note. Assigning a whole pair's catch to one dock would mislead.
port_key <- function(x) {
  key <- tolower(iconv(enc2utf8(trimws(x)), from = "UTF-8", to = "ASCII//TRANSLIT"))
  key <- gsub(" +", "_", key)
  key[key == "chicama"] <- "malabrigo"
  key[key == "supe_puerto"] <- "supe"
  key
}
named$port_id <- port_key(named$landing_site)
meal$port_id <- port_key(meal$landing_site)
stopifnot(!anyDuplicated(named$port_id), !anyDuplicated(meal$port_id),
          !anyDuplicated(lookup$port_id))
ids <- union(named$port_id, meal$port_id[meal$tonnes > 0])
if (!all(ids %in% lookup$port_id)) stop("Missing coordinates: ", paste(setdiff(ids, lookup$port_id), collapse = ", "))
port_values <- lookup[match(ids, lookup$port_id), ]
port_values$artisanal_t <- named$tonnes[match(ids, named$port_id)]
port_values$fishmeal_t <- meal$tonnes[match(ids, meal$port_id)]
# NA = no separate value in that source. A numeric 0 = an explicit zero.
# A fishmeal-only locality with a reported zero stays in the 24-row source
# table. With neither half to draw, it has no symbol on the map.
stopifnot(nrow(named) == 46, nrow(pooled) == 2, sum(meal$tonnes > 0) == 15,
          isTRUE(all.equal(sum(port_values$fishmeal_t, na.rm = TRUE), sum(meal$tonnes))),
          isTRUE(all.equal(sum(port_values$artisanal_t, na.rm = TRUE) + sum(pooled$tonnes) +
                             sum(unspecified$tonnes), sum(fleet$tonnes))))
species$port_id <- port_key(species$landing_site)
leading <- species[order(-species$tonnes, species$resource), ]
leading <- leading[!duplicated(leading$port_id), ]
port_values$leading_resource <- leading$resource[match(ids, leading$port_id)]
port_values$leading_resource_t <- leading$tonnes[match(ids, leading$port_id)]

# 3. Measure port distances ----
# Use the original geographic positions. Report
# distance to the nearest locality with positive 2025 fishmeal landings.
# A shared locality has distance zero. These are geodesic distances in km.
geographic <- sf::st_as_sf(port_values, coords = c("lon", "lat"), crs = 4326)
active <- which(port_values$fishmeal_t > 0)
distances <- units::set_units(sf::st_distance(geographic, geographic[active, ]), "km")
nearest <- apply(as.matrix(distances), 1, which.min)
port_values$nearest_fishmeal_port <- port_values$port[active[nearest]]
port_values$distance_km <- as.numeric(distances[cbind(seq_len(nrow(port_values)), nearest)])
audit_dir <- file.path(analysis_dir, "02_intermediate_data", "26_water")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(port_values, file.path(audit_dir, "2025_mapped_port_values.csv"), row.names = FALSE,
          fileEncoding = "UTF-8", na = "")

# 4. Project the coastline and ports ----
# Use an equal-area projection centred on coastal Peru. Its x/y units are
# kilometres, which also makes it easy to construct real semicircles. The
# chart radius is a symbol size, independent of any vessel's fishing range.
projection <- sf::st_crs("+proj=laea +lat_0=-11 +lon_0=-77 +datum=WGS84 +units=km +no_defs")
# Use a separate copy for symbol layout so this section can be rerun.
ports <- port_values
xy <- sf::st_coordinates(sf::st_transform(geographic, projection))
ports$x <- xy[, 1]
ports$y <- xy[, 2]
base_dir <- file.path(analysis_dir, "00_raw_data", "24_network", "peru_submarine_geodata_stage")
countries <- sf::st_read(file.path(base_dir, "neighbors.geojson"), quiet = TRUE)
# Project the basemap into the same units. coord_sf sets the coastal window.
countries <- sf::st_transform(countries, projection)
departments <- sf::st_transform(sf::st_read(file.path(base_dir, "peru_departments.geojson"),
                                             quiet = TRUE), projection)

# 5. Size and place the port symbols ----
# Encode tonnes by area. Both fisheries and the legend use the same
# square-root scale. Tiny volumes keep their true size. A fixed dot identifies
# the port on the coastline. A short dash to the right marks a reported zero.
radius <- function(t) 77 * sqrt(t / 1e6)
ports$left <- radius(ifelse(is.na(ports$artisanal_t), 0, ports$artisanal_t))
ports$right <- radius(ifelse(is.na(ports$fishmeal_t), 0, ports$fishmeal_t))
ports <- ports[order(-pmax(ports$left, ports$right), ports$port_id), ]

# Start the largest symbols at their true locations. Smaller neighbours try
# successively wider rings until their two halves fit. Store the original
# point for the leader line. The layout never changes the distance calculation.
directions <- seq(0, 2 * pi, length.out = 17)[-17]
trials <- expand.grid(angle = directions, step = seq(8, 256, by = 8))
trials <- rbind(c(0, 0), transform(trials, dx = step * cos(angle),
                                  dy = step * sin(angle))[c("dx", "dy")])
boxes <- data.frame(xmin = numeric(), xmax = numeric(), ymin = numeric(), ymax = numeric())
for (i in seq_len(nrow(ports))) {
  height <- max(ports$left[i], ports$right[i], 2)
  for (k in seq_len(nrow(trials))) {
    x <- ports$x[i] + trials$dx[k]
    y <- ports$y[i] + trials$dy[k]
    box <- data.frame(xmin = x - max(ports$left[i], 2) - 3,
                      xmax = x + max(ports$right[i], 6) + 3,
                      ymin = y - height - 3, ymax = y + height + 3)
    overlap <- box$xmin < boxes$xmax & box$xmax > boxes$xmin &
      box$ymin < boxes$ymax & box$ymax > boxes$ymin
    if (!any(overlap)) break
  }
  if (any(overlap)) stop("Unable to place the symbol for ", ports$port[i])
  ports$cx[i] <- x
  ports$cy[i] <- y
  boxes <- rbind(boxes, box)
}
# Each polygon starts and ends on the vertical diameter. Mirroring the arc
# puts artisanal volume on the left and anchoveta for fishmeal on the right.
halves <- function(x, y, left, right, id) {
  parts <- lapply(c("artisanal", "fishmeal"), function(side) {
    r <- if (side == "artisanal") left else right
    if (r <= 0) return(NULL)
    angle <- seq(-pi / 2, pi / 2, length.out = 73)
    sign <- if (side == "artisanal") -1 else 1
    data.frame(x = x + sign * r * cos(angle), y = y + r * sin(angle),
               side = side, id = paste(id, side))
  })
  do.call(rbind, parts)
}
glyphs <- do.call(rbind, Map(halves, ports$cx, ports$cy, ports$left, ports$right, ports$port_id))
shifted <- subset(ports, abs(cx - x) + abs(cy - y) > 0.1)
zeros <- subset(ports, fishmeal_t == 0)

# 6. Label the ports ----
# Label three different port economies. Every value in
# these notes is retrieved from the joined data, including Paita's distance.
at <- function(id) ports[match(id, ports$port_id), ]
tonnes <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
paita <- at("paita")
chimbote <- at("chimbote")
ilo <- at("ilo")
stopifnot(paita$leading_resource == "POTA", ilo$leading_resource == "JUREL",
          paita$nearest_fishmeal_port == "Bayóvar")
notes <- data.frame(
  port = c("Paita", "Chimbote", "Ilo"), tx = c(-231, 72, 290), ty = c(775, 350, -322),
  cx = c(paita$cx, chimbote$cx + chimbote$right, ilo$cx),
  cy = c(paita$cy, chimbote$cy, ilo$cy),
  body = c(sprintf("%s t of artisanal landings, including\n%s t of giant squid (pota).\nBayóvar, %d km away, landed %s t\nof anchoveta for fishmeal.",
                   tonnes(paita$artisanal_t), tonnes(paita$leading_resource_t),
                   round(paita$distance_km), tonnes(at("bayovar")$fishmeal_t)),
           sprintf("%s t of anchoveta for fishmeal.\nArtisanal vessels landed %s t here.",
                   tonnes(chimbote$fishmeal_t), tonnes(chimbote$artisanal_t)),
           sprintf("%s t artisanal and %s t for fishmeal.\nJack mackerel (jurel) led artisanal landings\nwith %s t.",
                   tonnes(ilo$artisanal_t), tonnes(ilo$fishmeal_t), tonnes(ilo$leading_resource_t))))
# Ilo's symbol is southeast of its note. End the leader below the text.
notes$end_x <- notes$tx - 12
notes$end_y <- notes$ty - 15
notes$end_x[notes$port == "Ilo"] <- notes$tx[notes$port == "Ilo"] + 260
notes$end_y[notes$port == "Ilo"] <- notes$ty[notes$port == "Ilo"] - 107
# Bend this one line inland to pass clear of other southern port symbols.
notes$via_x <- ifelse(notes$port == "Ilo", ilo$cx + 95, notes$end_x)
notes$via_y <- ifelse(notes$port == "Ilo", ilo$cy + 100, notes$end_y)
# Use quieter labels for geographic orientation. Move only this text.
secondary <- data.frame(
  id = c("zorritos", "talara", "bayovar", "pimentel", "malabrigo", "coishco", "supe",
         "chancay", "callao", "tambo_de_mora", "pisco", "atico", "matarani"),
  lx = c(-506, -555, -549, -428, -413, -395, -236, -202, -155, -85, -53, 290, 465),
  ly = c(851, 718, 538, 458, 366, 225, 77, -45, -127, -252, -323, -596, -739))
secondary <- merge(secondary, ports, by.x = "id", by.y = "port_id", sort = FALSE)
secondary$label <- secondary$port
atico <- at("atico")
stopifnot(atico$leading_resource == "BONITO")
secondary$label[secondary$id == "atico"] <- sprintf("Ático\n%s t of bonito", tonnes(atico$leading_resource_t))
ink <- "#18333C"; teal <- "#007B78"; orange <- "#BA4C27"
paper <- "#F8F5EB"; sea <- "#DFECEB"; land <- "#EEE3CC"; muted <- "#476169"
key_t <- c(1e5, 5e5, 1e6)
key_x <- c(-798, -580, -333)
key <- do.call(rbind, Map(halves, key_x, -648, radius(key_t), radius(key_t), seq_along(key_t)))
draw_halves <- function(data) geom_polygon(data = data, aes(x, y, group = id, fill = side),
                                            colour = NA)
label <- function(x, y, text, size, colour = ink, face = "plain", family = "sans", hjust = 0) {
  annotate("text", x = x, y = y, label = text, size = size, colour = colour,
           family = family, fontface = face, hjust = hjust)
}

# 7. Draw the map ----
# The legend repeats the same polygon function used
# for the ports: either half of its 100,000-tonne symbol represents 100,000 t.
map <- ggplot() +
  geom_sf(data = countries, fill = "#E2E4D6", colour = "#B6C0AE", linewidth = 0.27) +
  geom_sf(data = departments, fill = land, colour = "#D0C6AB", linewidth = 0.18) +
  label(320, 640, "P E R U", 6, "#818467", hjust = 0.5) +
  annotate("text", x = -642, y = -91, label = "Pacific Ocean", angle = -25,
           family = "serif", fontface = "italic", size = 7, colour = "#6D9296") +
  geom_segment(data = shifted, aes(x, y, xend = cx, yend = cy), colour = "#617577", linewidth = 0.24) +
  geom_segment(data = secondary, aes(cx, cy, xend = lx + 4, yend = ly),
               colour = "#698181", linewidth = 0.21) +
  geom_segment(data = notes, aes(cx, cy, xend = via_x, yend = via_y),
               colour = "#788274", linewidth = 0.30) +
  geom_segment(data = subset(notes, port == "Ilo"), aes(via_x, via_y, xend = end_x, yend = end_y),
               colour = "#788274", linewidth = 0.30) +
  geom_point(data = ports, aes(x, y), size = 0.8, colour = "#4B6461") +
  draw_halves(glyphs) +
  geom_segment(data = zeros, aes(cx + 2, cy, xend = cx + 12, yend = cy),
               colour = orange, linewidth = 0.46) +
  geom_text(data = secondary, aes(lx, ly, label = label), hjust = 1, colour = ink,
            lineheight = 1.08, size = 3.45) +
  geom_text(data = notes, aes(tx, ty, label = port), family = "serif", fontface = "bold",
            colour = ink, size = 6.5, hjust = 0) +
  geom_text(data = notes, aes(tx, ty - 36, label = body), size = 3.7, lineheight = 1.09,
            colour = ink, hjust = 0, vjust = 1) +
  label(-869, -388, "Annual landings", 6.3, family = "serif", face = "bold") +
  label(-869, -449, "Left half   ·   Artisanal marine landings", 4.2, teal, face = "bold") +
  label(-869, -495, "Right half   ·   Anchoveta for fishmeal", 4.2, orange, face = "bold") +
  draw_halves(key) +
  geom_text(data = data.frame(x = key_x, value = c("100,000 t","500,000 t","1 million t")),
            aes(x, -760, label = value), size = 3.6, colour = ink) +
  label(-869, -819, "Each half uses the same area scale. A dash marks a reported zero.", 3.45, muted) +
  label(-869, -854, "A blank half has no separately reported figure at that site.", 3.45, muted) +
  scale_fill_manual(values = c(artisanal = teal, fishmeal = orange), guide = "none") +
  coord_sf(crs = projection, default_crs = projection, xlim = c(-925, 882),
           ylim = c(-895, 910), expand = FALSE, datum = NA) +
  theme_void(base_family = "sans") +
  theme(panel.background = element_rect(fill = sea, colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# Header and source lines stay outside the map to keep the shoreline clear.
strip <- function() ggplot() + coord_cartesian(xlim = c(0, 1), ylim = c(0, 1),
                                              expand = FALSE, clip = "off") + theme_void()
header <- strip() +
  label(0, .87, "PERU   /   PACIFIC COAST                                      JANUARY–DECEMBER 2025", 3.8, teal, "bold") +
  label(0, .53, "Where Peru’s catch comes ashore", 11.4, family = "serif", face = "bold") +
  label(0, .13, "Giant squid made Paita Peru’s leading artisanal port. Chimbote landed the most anchoveta for fishmeal.", 4.45)
coverage <- sprintf(paste0("%d artisanal sites and %d ports with fishmeal landings mapped. Carquín/Huacho and Supe/Vidal jointly account for %s t. ",
                           "Unspecified sites account for %s t (%.1f%%)."),
                    nrow(named), length(active), tonnes(sum(pooled$tonnes)), tonnes(sum(unspecified$tonnes)),
                    100 * sum(unspecified$tonnes) / sum(fleet$tonnes))
footer <- strip() +
  label(0, .82, coverage, 3.15) +
  label(0, .51, "PRODUCE marine artisanal estimates and August 2026 bulletin, table 8 (revised 2025 figures). Geography from INEI, DHN, geoBoundaries and Natural Earth.", 3.05, muted)
figure <- patchwork::wrap_plots(header, map, footer, ncol = 1, heights = c(1.23, 10.4, .95)) +
  patchwork::plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA),
                                           plot.margin = margin(16, 22, 12, 22)))

# 8. Save the figure ----
output_dir <- Sys.getenv("WATER_OUTPUT_DIR", unset = file.path(analysis_dir, "03_output", "26_water"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
map_file <- file.path(output_dir, "26_water_peru_landings_2025.png")
ggsave(map_file, figure, device = ragg::agg_png, width = 11.2, height = 13.25,
       units = "in", dpi = 300, bg = paper)
message("Saved ", normalizePath(map_file, winslash = "/"), " (", nrow(ports), " mapped localities).")
if (interactive()) print(figure)
