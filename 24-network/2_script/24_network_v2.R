# 30DayMapChallenge | Network | Harry Aquije Ballon
# One map: cable-system landings + regional fixed-fibre subscription density.
# Regional data: December 2024. No terrestrial routes are inferred.

# 1. Packages and folders -----------------------------------------------------
packages <- c("sf", "dplyr", "readr", "ggplot2", "ggrepel", "scales", "ragg")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Please install: ", paste(missing, collapse = ", "))
invisible(lapply(packages, library, character.only = TRUE))

# Open peru-internet-network.Rproj, or run from the repository root.
root <- Sys.getenv("PERU_NETWORK_ROOT", unset = "")
if (!nzchar(root)) {
  if (dir.exists("1_analysis/00_raw_data")) {
    root <- file.path(getwd(), "1_analysis")
  } else if (dir.exists("00_raw_data/24_network")) {
    root <- getwd()
  } else {
    stop("Open peru-internet-network.Rproj, then run this script.")
  }
}
raw_dir <- file.path(root, "00_raw_data", "24_network", "peru_submarine_geodata_stage")
clean_dir <- file.path(root, "01_clean_data", "24_network")
inter_dir <- file.path(root, "02_intermediate_data", "24_network")
out_dir <- file.path(root, "03_output", "24_network")
invisible(lapply(c(clean_dir, inter_dir, out_dir), dir.create,
                 recursive = TRUE, showWarnings = FALSE))
needed <- c("regional_fibre_2024.csv", "population_2024.csv",
            "peru_departments.geojson", "neighbors.geojson",
            "peru_landing_localities.csv", "peru_system_membership.csv")
absent <- needed[!file.exists(file.path(raw_dir, needed))]
if (length(absent)) stop("Missing in raw_dir: ", paste(absent, collapse = ", "))

# 2. Read source data and calculate the regional measure ----------------------
fibre <- read_csv(file.path(raw_dir, "regional_fibre_2024.csv"),
                  col_types = cols(dept_code = col_character()))
pop <- read_csv(file.path(raw_dir, "population_2024.csv"),
                col_types = cols(dept_code = col_character()))
landings <- read_csv(file.path(raw_dir, "peru_landing_localities.csv"),
                     show_col_types = FALSE)
members <- read_csv(file.path(raw_dir, "peru_system_membership.csv"),
                    show_col_types = FALSE) |> distinct(system_id, point_id)
departments <- st_read(file.path(raw_dir, "peru_departments.geojson"), quiet = TRUE)
neighbors <- st_read(file.path(raw_dir, "neighbors.geojson"), quiet = TRUE)

stopifnot(nrow(fibre) == 25, nrow(pop) == 25,
          !anyDuplicated(fibre$dept_code), !anyDuplicated(pop$dept_code),
          setequal(fibre$dept_code, pop$dept_code),
          setequal(fibre$dept_code, departments$dept_code),
          all(fibre$period == "2024-12"), all(pop$population > 0),
          sum(fibre$fibre_connections) == 2985098,
          sum(pop$population) == 34038457)

regional <- fibre |>
  left_join(select(pop, dept_code, population), by = "dept_code") |>
  mutate(fibre_per_100 = 100 * fibre_connections / population)
map_data <- departments |>
  left_join(select(regional, dept_code, fibre_connections, population, fibre_per_100),
            by = "dept_code")
stopifnot(nrow(map_data) == 25, !anyNA(map_data$fibre_per_100))
write_csv(regional, file.path(clean_dir, "regional_fibre_density_2024.csv"))
saveRDS(map_data, file.path(inter_dir, "regional_fibre_map.rds"))

# 3. Offshore labels: system-to-landing memberships, NOT cable routes ----------
# These text positions are graphic-layout anchors, not geographic installations.
system_labels <- tibble::tribble(
  ~system_id, ~label,                    ~label_x, ~label_y, ~start_x,
  "SAM1",    "SAm-1",                      -86.0,     -5.8,    -84.4,
  "MISTRAL", "Mistral",                    -86.0,     -8.6,    -84.4,
  "SAC",     "SAC",                        -85.5,    -11.5,    -84.0,
  "FOP",     "Fibra Óptica\nal Pacífico",  -83.5,    -16.3,    -80.8
)
stopifnot(all(members$system_id %in% system_labels$system_id),
          all(members$point_id %in% landings$point_id))
links <- members |>
  left_join(system_labels, by = "system_id") |>
  left_join(select(landings, point_id, longitude, latitude), by = "point_id")

# Quadratic Bezier leaders. Their curvature carries no geographic meaning.
curves <- bind_rows(lapply(seq_len(nrow(links)), function(i) {
  z <- links[i, ]; t <- seq(0, 1, length.out = 60)
  cx <- (z$start_x + z$longitude) / 2 - 0.4
  cy <- (z$label_y + z$latitude) / 2
  tibble::tibble(
    link_id = i, system_id = z$system_id,
    lon = (1-t)^2 * z$start_x + 2*(1-t)*t*cx + t^2*z$longitude,
    lat = (1-t)^2 * z$label_y + 2*(1-t)*t*cy + t^2*z$latitude
  )
}))
saveRDS(list(labels = system_labels, memberships = links, curves = curves),
        file.path(inter_dir, "schematic_memberships.rds"))

# 4. Labels and colours -------------------------------------------------------
bg <- "#081C2A"
ink <- "#EDF5F3"
muted <- "#A5BAC4"
cable_colours <- c(SAM1 = "#F3C66F", MISTRAL = "#54D9CB",
                   SAC = "#BAAAF5", FOP = "#FF9B86")

# Selected department names and values; figures describe departments, not cities.
label_codes <- c("03", "04", "08", "11", "12", "13", "14", "15",
                 "16", "17", "18", "20", "21", "22", "23", "24", "25")
region_labels <- map_data |>
  st_drop_geometry() |>
  filter(dept_code %in% label_codes) |>
  mutate(lon = label_lon, lat = label_lat,
         text = paste0(department, "\n", sprintf("%.1f", fibre_per_100)),
         nudge_y = if_else(dept_code %in% c("18", "24"), 0.7, 0))

# Landing labels sit offshore, separate from the department values.
landing_offsets <- tibble::tribble(
  ~point_id,      ~dx,  ~dy,
  "PE_MANCORA",  -1.0,  0.1,
  "PE_LURIN",    -0.8, -0.7,
  "PE_ILO",       0.4, -0.5
)
landing_labels <- landings |>
  left_join(landing_offsets, by = "point_id") |>
  mutate(label_x = longitude + dx, label_y = latitude + dy)
country_labels <- tibble::tribble(
  ~lon, ~lat, ~label,
  -78.8, -0.3, "ECUADOR",
  -69.3, -6.5, "BRAZIL",
  -68.7, -16.9, "BOLIVIA"
)

# 5. One map -----------------------------------------------------------------
p <- ggplot() +
  geom_sf(data = neighbors, fill = "#122A38", colour = "#304653", linewidth = 0.25) +
  geom_sf(data = map_data, aes(fill = fibre_per_100),
          colour = "#B1D0D3", linewidth = 0.22) +
  scale_fill_gradientn(
    colours = c("#21475B", "#377E91", "#75B9B5", "#BCE0C9", "#FFF0B5"),
    limits = c(0, 15), breaks = c(0, 5, 10, 15),
    name = "Fixed-fibre connections per 100 residents",
    guide = guide_colourbar(direction = "horizontal", title.position = "top",
                             barwidth = grid::unit(8, "cm"),
                             barheight = grid::unit(0.32, "cm"))
  ) +
  geom_path(data = curves, aes(lon, lat, group = link_id, colour = system_id),
             linewidth = 0.7, alpha = 0.8, show.legend = FALSE) +
  geom_text(data = system_labels,
             aes(label_x, label_y, label = label, colour = system_id),
             hjust = 0, fontface = "bold", size = 4.1, lineheight = 1.0,
             show.legend = FALSE) +
  scale_colour_manual(values = cable_colours, guide = "none") +
  geom_text(data = country_labels, aes(lon, lat, label = label),
             colour = "#68808D", size = 3.2) +
  geom_text_repel(data = region_labels,
                   aes(lon, lat, label = text),
                   colour = ink, bg.color = bg, bg.r = 0.12,
                   size = 3.0, fontface = "bold", show.legend = FALSE,
                   nudge_y = region_labels$nudge_y,
                   lineheight = 0.95, seed = 24, box.padding = 0.25,
                   point.padding = NA, max.overlaps = Inf,
                   segment.colour = "#9DB9BD", segment.size = 0.25,
                   min.segment.length = 0.15, force = 0.15, force_pull = 5) +
  geom_point(data = landings, aes(longitude, latitude),
              shape = 21, fill = "#FFE0A8", colour = bg, size = 3.5, stroke = 0.6) +
  geom_segment(data = landing_labels,
                 aes(x = longitude, y = latitude, xend = label_x, yend = label_y),
                 colour = "#FFE0A8", linewidth = 0.35) +
  geom_label(data = landing_labels, aes(label_x, label_y, label = name),
              colour = "#FFE0A8", fill = bg, size = 3.4, fontface = "bold",
              label.padding = grid::unit(0.13, "lines"), linewidth = 0) +
  annotate("text", x = -86, y = -2.1, label = "SUBMARINE SYSTEMS",
             hjust = 0, colour = ink, fontface = "bold", size = 3.4) +
  annotate("text", x = -86, y = -2.8,
             label = "Lines identify landing memberships.\nThey are not cable routes.",
             hjust = 0, colour = muted, size = 2.8, lineheight = 1.1) +
  coord_sf(crs = st_crs(4326), default_crs = st_crs(4326),
             xlim = c(-87, -67.5), ylim = c(-19.5, 0.6), datum = NA, expand = FALSE) +
  labs(
    title = "BEYOND THE SHORELINE",
    subtitle = "Peru’s submarine gateways | Regional fixed-fibre data: December 2024",
    caption = paste(
      "Connections include homes and businesses; population is INEI's mid-2024 estimate.",
      "Colours show department averages, not coverage or traffic carried by a particular cable.",
      "Sources: OSIPTEL (Table 3, Informe 280-2025-DPRC); INEI; cables: TeleGeography / GeoCables.",
      "Boundaries: geoBoundaries / Wikimedia, Natural Earth. Harry Aquije Ballon | #30DayMapChallenge",
      sep = "\n"
    )
  ) +
  theme_void(base_family = "sans", base_size = 12) +
  theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    plot.title = element_text(colour = ink, face = "bold", size = 24,
                               margin = margin(b = 7)),
    plot.subtitle = element_text(colour = muted, size = 11,
                                  margin = margin(b = 14)),
    plot.caption = element_text(colour = muted, size = 8.2, hjust = 0,
                                 lineheight = 1.2, margin = margin(t = 12)),
    legend.position = "bottom", legend.justification = "left",
    legend.title = element_text(colour = ink, size = 10.5),
    legend.text = element_text(colour = muted, size = 10),
    legend.background = element_rect(fill = bg, colour = NA),
    plot.margin = margin(18, 18, 16, 18)
  )

# 6. Export ------------------------------------------------------------------
ggsave(file.path(out_dir, "peru_fibre_network_v2.png"), plot = p,
        device = ragg::agg_png, width = 10, height = 11.2, units = "in",
        dpi = 300, bg = bg)
saveRDS(p, file.path(inter_dir, "peru_fibre_plot.rds"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "session_info_v2.txt"))
if (interactive()) print(p)
message("Saved: ", file.path(out_dir, "peru_fibre_network_v2.png"))
