# Data sources

Prepared for a map published on 24 November 2026. Source links are retained to make the small research extract traceable.

## Fixed-fibre connections

- **File:** `regional_fibre_2024.csv`.
- **Source:** OSIPTEL, [Informe 280-2025-DPRC](https://www.osiptel.gob.pe/media/uareffhf/informe280-2025-dprc.pdf), Table 3, printed page 16.
- **Reference period:** December 2024. Source data revision: 20 August 2025.
- **Coverage:** 24 departments plus Callao; residential and commercial fixed-fibre connections together.
- **National total:** 2,985,098 connections. Departmental rows reconcile to the publication's total.
- These are fibre connections, not a strict FTTH-only series. More recent national figures and revisions exist; the repository keeps this complete departmental source vintage consistent.

## Population

- **File:** `population_2024.csv`.
- **Source:** INEI [population estimates and projections](https://www.inei.gob.pe/estadisticas/indice-tematico/population-estimates-and-projections/), [source workbook](https://www.inei.gob.pe/media/MenuRecursivo/indices_tematicos/proy_03_4.xlsx), sheet `2024-2026`.
- **Reference date:** 30 June 2024.
- **National total:** 34,038,457 residents.
- Lima department includes metropolitan Lima; Callao is separate.

## Department boundaries

- **File:** `peru_departments.geojson`.
- **Source:** [geoBoundaries gbOpen PER ADM1](https://www.geoboundaries.org/api/current/gbOpen/PER/ADM1/). The included `boundary_metadata.json` preserves the source and a versioned download link.
- **Reference year:** 2008; standardized build: February 2024.
- **Source license recorded in metadata:** Public Domain; source: Wikimedia Commons.
- The source's Lima region and metropolitan Lima polygons were dissolved to match the statistical department, producing 25 units with Callao separate. Boundaries are generalized for national cartography, not current cadastral work.
- `label_lon` and `label_lat` are graphic label anchors computed inside the polygons, not population centres or observed infrastructure locations.
- Credit: geoBoundaries / Wikimedia Commons.

## Surrounding countries

- **File:** `neighbors.geojson`.
- **Source:** [Natural Earth 1:50m country polygons](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson).
- Subset: Peru, Ecuador, Colombia, Brazil, Bolivia and Chile.
- Natural Earth data are [public domain](https://www.naturalearthdata.com/about/terms-of-use/).

## Submarine landing records

- **Files:** `peru_landing_localities.csv` and `peru_system_membership.csv`. Each row retains its source URL.
- **Locality coordinates:** [GeoCables — Peru](https://geocables.com/locations/pe).
- **SAm-1 memberships:** [GeoCables — South America-1](https://geocables.com/cable/south-america-1-sam-1).
- **SAC membership:** [GeoCables — South American Crossing](https://geocables.com/cable/south-american-crossing-sac).
- **Fibra Optica al Pacifico memberships:** [TeleGeography — Submarine Cable Map](https://www.submarinecablemap.com/submarine-cable/fibra-optica-al-pacfico).
- **Mistral membership:** [TeleGeography — Submarine Cable Map](https://www.submarinecablemap.com/submarine-cable/south-pacific-cable-system-spcsmistral).
- GeoCables identifies TeleGeography as its cable-data source. The references are therefore not independent evidence streams.
- The records are a small curated set of selected systems and approximate landing localities, not surveyed station coordinates or a comprehensive live operational database.
- Offshore curves are generated graphic leaders. No third-party submarine route geometry is included.

## Reuse

Attribution is provided for the source records and geographic files. The repository's MIT license covers only the original R code; it does not relicense OSIPTEL, INEI, TeleGeography, GeoCables or other third-party source material, and it does not apply to the map artwork. Consult the linked providers' terms when reusing their source datasets.
