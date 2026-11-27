# Data and measurements

## Elevation

The three GeoTIFFs are from the Copernicus DEM GLO-90 2021 release distributed through the AWS Open Data Registry. The grid records surface elevation above the EGM2008 geoid in metres at three arc seconds of spacing, approximately 90 m. The Arequipa panel uses one tile and the Colca panel straddles the 72°W tile boundary. [Copernicus specifications](https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM) · [AWS release](https://registry.opendata.aws/copernicus-dem/)

| Coverage | Provider download |
| --- | --- |
| Arequipa and El Misti | [S17 W072](https://copernicus-dem-90m.s3.amazonaws.com/Copernicus_DSM_COG_30_S17_00_W072_00_DEM/Copernicus_DSM_COG_30_S17_00_W072_00_DEM.tif) |
| Colca, east of 72°W | [S16 W072](https://copernicus-dem-90m.s3.amazonaws.com/Copernicus_DSM_COG_30_S16_00_W072_00_DEM/Copernicus_DSM_COG_30_S16_00_W072_00_DEM.tif) |
| Colca, west of 72°W | [S16 W073](https://copernicus-dem-90m.s3.amazonaws.com/Copernicus_DSM_COG_30_S16_00_W073_00_DEM/Copernicus_DSM_COG_30_S16_00_W073_00_DEM.tif) |

## Rivers

The November 2026 OpenStreetMap snapshots contain the Río Chili (relation 2237688) and the Colca–Majes–Camaná river system (relation 2634345). The script follows ways marked `main_stream` and clips them to each map. The public copies omit contributor account names and IDs. © OpenStreetMap contributors. The river data are available under the Open Database License (ODbL). [Río Chili source JSON](https://api.openstreetmap.org/api/0.6/relation/2237688/full.json) · [Río Colca source JSON](https://api.openstreetmap.org/api/0.6/relation/2634345/full.json) · [OpenStreetMap licence](https://www.openstreetmap.org/copyright)

## How the profiles were measured

The transects are straight lines in WGS 84 / UTM zone 19S. Along each line, the script samples the original elevation grid with bilinear interpolation at intervals of at most 90 m, including both endpoints. The profiles use horizontal distance in kilometres. The headline differences are rounded to the nearest ten metres after subtraction. [Endpoints with coordinates](1_analysis/01_clean_data/27_new_tool/transect_endpoints.csv) · [All profile samples](1_analysis/02_intermediate_data/27_new_tool/elevation_profiles.csv)

- **El Misti.** The line starts at the centre of Arequipa’s Plaza de Armas (16.3988°S, 71.5369°W). IGP gives a reference coordinate within the crater and a published summit elevation of 5,822 m. The script locates the highest native grid-cell centre within 1 km of that coordinate. This cell falls on the rim, about 406 m from the reference. The modelled rise is 3,462 m over 17.59 km. [Plaza location](https://www.openstreetmap.org/#map=18/-16.3988/-71.5369) · [IGP volcano profile](https://repositorio.igp.gob.pe/items/9d53cb87-2b30-4837-ac9a-b0e4bea0b962)
- **Colca Canyon.** MINCETUR lists Cruz del Cóndor at 15.611146°S, 71.905903°W. From that point to the nearest point on the Río Colca, the grid gives a drop of 1,137 m over 1.01 km. MINCETUR also describes more than 1,250 m of relief in this sector. Its description leaves the river endpoint unspecified. The figure on the map applies to the marked line. [Official lookout coordinate, row 317](https://transparencia.mincetur.gob.pe/documentos/newweb/portals/0/transparencia/pmi/Anexo_4-CPS-CB-ZonaDesarrolloTuristico-14102025.pdf) · [MINCETUR viewpoint description](https://consultasenlinea.mincetur.gob.pe/fichaInventario/index.aspx?cod_Ficha=615)

## Copernicus data notice

The included tiles and derived elevations are supplied under the [Copernicus WorldDEM-90 licence, pp. 19–21](https://dataspace.copernicus.eu/sites/default/files/media/files/2025-06/copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf#page=19). The same terms apply to redistribution.

Original tiles: © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.

Map and profiles: produced using Copernicus WorldDEM™-90 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.

The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM™-90.
