# Rebuild the 2025 artisanal and fishmeal landing tables
# Harry Aquije Ballon

#===============================================================================
# Run the sections in order to inspect the monthly records and port totals.
# This script requires readxl and dplyr. The map also runs it automatically.

# Project folders ----
# Find 1_analysis starting from the project root or a folder inside it.
project_root <- getwd()
while (!dir.exists(file.path(project_root, "1_analysis"))) {
  parent_dir <- dirname(project_root)
  if (parent_dir == project_root) {
    # Running this script on its own from outside the project.
    project_root <- "C:/Users/harry/Desktop/projects/30daymapchallenge"
    break
  }
  project_root <- parent_dir
}
analysis_dir <- file.path(project_root, "1_analysis")
if (!dir.exists(analysis_dir)) stop("Set project_root to the folder containing 1_analysis.")

raw_dir <- file.path(analysis_dir, "00_raw_data", "26_water", "public_sources")
clean_dir <- file.path(analysis_dir, "01_clean_data", "26_water")

# 1. Read the marine artisanal records ----
# PRODUCE's artisanal workbook includes marine and inland fisheries. Use the
# published scope field to select the coast. Read the year as text so the
# source notes beneath the data are harmless. Values are already in tonnes.
art <- readxl::read_excel(file.path(raw_dir, "BD_PA_2013-2025-dic.xlsx"),
                          sheet = "BD", skip = 4, col_types = "text")
stopifnot(identical(names(art), c("AÑO", "MES", "UTILIZACIÓN", "REGION",
  "PUNTO DE DESEMBARQUE", "AMBITO", "ESPECIE", "DESEMBARQUE (TM)")))
names(art) <- c("year", "month", "use", "region", "landing_site",
                "scope", "resource", "tonnes")
marine <- dplyr::filter(art, year == "2025", scope == "MARITIMO")
marine$tonnes <- as.numeric(marine$tonnes)
marine$month <- as.integer(marine$month)
stopifnot(!anyNA(marine[c("region", "landing_site", "resource", "month", "tonnes")]),
          setequal(marine$month, 1:12))

# 2. Calculate annual totals by species and site ----
# Sum across uses and months. Keep the department because OTROS occurs in
# several places. Keep the source's combined sites and resource groups whole.
# Months with records measures coverage for this particular site and resource.
annual <- marine |>
  dplyr::group_by(region, landing_site, resource) |>
  dplyr::summarise(months_with_records = dplyr::n_distinct(month),
                   tonnes = sum(tonnes), .groups = "drop") |>
  dplyr::arrange(region, landing_site, dplyr::desc(tonnes))
stopifnot(isTRUE(all.equal(sum(annual$tonnes), sum(marine$tonnes))))
# The port totals support a single proportional-symbol map. Flag which rows
# can be placed at one locality and keep all unlocated weight in the total.
site_totals <- marine |>
  dplyr::group_by(region, landing_site) |>
  dplyr::summarise(months_with_records = dplyr::n_distinct(month),
                   tonnes = sum(tonnes), .groups = "drop") |>
  dplyr::mutate(location_type = dplyr::case_when(
    landing_site == "OTROS" ~ "unspecified",
    grepl("/", landing_site, fixed = TRUE) ~ "combined localities",
    TRUE ~ "named locality")) |>
  dplyr::arrange(dplyr::desc(tonnes))
stopifnot(isTRUE(all.equal(sum(site_totals$tonnes), sum(annual$tonnes))))

# 3. Check the monthly anchoveta figures ----
# The August 2026 annex revises earlier port figures for 2025, notably at
# Ilo and Chimbote. Table 8 has one national row, subtotals and 24 localities.
# Read only BV:CG (January–December 2025). Verify the headers and
# reconcile the port rows to the national total separately for every month.
bulletin <- file.path(raw_dir, "1._ANEXOS_BOLETIN_AGO_2026.xlsx")
month_header <- readxl::read_excel(bulletin, sheet = "Cdr 8", range = "BV6:CG7",
                             col_names = FALSE, .name_repair = "minimal")
stopifnot(as.character(month_header[[1]][1]) == "2025",
          identical(as.character(unlist(month_header[2, ], use.names = FALSE)),
                    c("Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Set","Oct","Nov","Dic")))
locations <- readxl::read_excel(bulletin, sheet = "Cdr 8", range = "A8:A36",
                                col_names = "reported_label")[[1]]
monthly <- as.matrix(readxl::read_excel(bulletin, sheet = "Cdr 8", range = "BV8:CG36",
  col_types = "numeric", col_names = FALSE, .name_repair = "minimal"))
port_row <- !grepl("^(Total|Región|Norte *\\+)", trimws(locations))
stopifnot(locations[1] == "Total", sum(port_row) == 24L, !anyNA(monthly),
          max(abs(colSums(monthly[port_row, , drop = FALSE]) - monthly[1, ])) < 0.01)
industrial <- data.frame(reported_label = locations[port_row],
  landing_site = trimws(sub("[[:space:]]*[0-9]+/[[:space:]]*$", "", locations[port_row])),
  tonnes = rowSums(monthly[port_row, , drop = FALSE]), stringsAsFactors = FALSE)
industrial <- industrial[order(-industrial$tonnes), ]

# 4. Save the three landing tables ----
dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(annual, file.path(clean_dir, "artisanal_marine_site_resource_2025.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8")
utils::write.csv(site_totals, file.path(clean_dir, "artisanal_marine_site_totals_2025.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8")
utils::write.csv(industrial, file.path(clean_dir, "anchoveta_for_fishmeal_by_port_2025.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8")
message(sprintf("Coastal artisanal estimate: %.1f tonnes in %d site-resource rows.",
                sum(annual$tonnes), nrow(annual)))
message(sprintf("Anchoveta for fishmeal: %.1f tonnes across %d positive localities.",
                sum(industrial$tonnes), sum(industrial$tonnes > 0)))
