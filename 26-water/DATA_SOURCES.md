# Data sources

The map covers landings on Peru’s Pacific coast from January through December 2025. All weights are metric tonnes. The period follows the calendar year, including landings from fishing seasons that crossed a year boundary.

| Input | Use |
| --- | --- |
| [BD_PA_2013-2025-dic.xlsx](1_analysis/00_raw_data/26_water/public_sources/BD_PA_2013-2025-dic.xlsx) | PRODUCE marine artisanal estimates. The preparation script filters sheet `BD` to year `2025` and scope `MARITIMO`, then sums across months and uses for each landing site and resource. [Artisanal landings database](https://www.producempresarial.pe/desembarque-pesquero-artesanal-2013-2023/) |
| [1._ANEXOS_BOLETIN_AGO_2026.xlsx](1_analysis/00_raw_data/26_water/public_sources/1._ANEXOS_BOLETIN_AGO_2026.xlsx) | PRODUCE’s August 2026 bulletin revises its 2025 series. Sheet `Cdr 8`, columns `BV:CG`, gives January–December 2025 anchoveta landings for fishmeal by locality. The 24 locality rows reconcile to the national total in each month. [Bulletin and annex](https://www.producempresarial.pe/agosto-2026-boletin-estadistico-de-pesca/) |
| [ports_reference.csv](1_analysis/00_raw_data/26_water/public_sources/ports_reference.csv) | Geographic coordinates for landing localities. The table records the source for each point. The map uses INEI port gazetteers and the Navy’s position for the José Olaya artisanal pier at San Andrés. [INEI 2018, table 1.13](https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/Lib1635/cap01/cap01.pdf) · [INEI 2014, table 1.9](https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/Lib1173/cap01/cap01.pdf) · [DHN, September 2025](https://www.dhn.mil.pe/Archivos/navegacion/avilonas/2025/09-2025.pdf) |
| [neighbors.geojson](1_analysis/00_raw_data/24_network/peru_submarine_geodata_stage/neighbors.geojson) | Peru and its neighbours, from Natural Earth’s public-domain 1:50m country polygons. [Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/) |
| [peru_departments.geojson](1_analysis/00_raw_data/24_network/peru_submarine_geodata_stage/peru_departments.geojson) | Department boundaries from geoBoundaries / Wikimedia Commons. The Day 24 preparation combined the two Lima polygons into one department. [Project boundary metadata](../24-network/1_analysis/00_raw_data/24_network/peru_submarine_geodata_stage/boundary_metadata.json) · [geoBoundaries](https://www.geoboundaries.org/api/current/gbOpen/PER/ADM1/) |

## Reading the figures

The map locates 46 individual artisanal sites and 15 ports with positive fishmeal landings. Thirteen appear in both groups. The symbols therefore cover 48 localities. Carquín/Huacho and Supe/Vidal account for 2,804 tonnes reported jointly. A further 72,375 tonnes fall under unspecified sites. These amounts are included in the national artisanal estimate of 1,240,816 tonnes.

The revised national total for anchoveta landed for fishmeal is 4,613,702 tonnes. Chimbote accounts for 985,690 tonnes and Ilo for 175,126 tonnes. The earlier December 2025 bulletin gave 984,762 tonnes and 76,264 tonnes respectively. The map uses the August 2026 edition consistently across ports. [Earlier PRODUCE bulletin](https://www.producempresarial.pe/diciembre-2025-boletin-estadistico-de-pesca/)
