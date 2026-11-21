# Geographic coverage figure

The two panels map the **annual association** block of the public replication
dataset, restricted to 2013–2022. They show eligible years per geographic unit,
not religious-expression or well-being scores.

- National: 61 countries, 602 country-years (8–10 years per country).
- Regional: 1,004 regions in 60 countries, 8,350 region-years (4–10 years per region).

The longitudinal and regional period-average models use different inclusion
criteria. Their samples are not represented by these maps.

## Reproduction

From the public repository root:

```sh
Rscript coverage_maps.R \
  --data data/model_data.csv \
  --spatial-dir /path/to/project/spatial \
  --output-dir results/coverage_maps
```

The script requires R packages `data.table`, `sf`, `ggplot2`, `patchwork`,
and `ragg`. It writes a 450-dpi PNG; it does not compile
the manuscript or refit statistical models.

## Boundary matching and display

The geometry inputs are the project's existing `adm0.shp` and
`adm1_simplify.shp` layers with their companion files. The manuscript analysis uses their administrative identifiers. No upstream
release or boundary vintage is inferred from their filenames. The boundary
files are not redistributed by this figure-building task.

National units match by ISO2. Regional units match by country, administrative
ID and name. Twenty names contain question marks in place of Unicode
characters in the legacy boundary layer; they are matched only when the
country/ID combination is unique and all other name characters agree. Laois
matches the boundary name Laoighis under the same country/ID. Every correction
is recorded in `regional_boundary_crosswalk.csv`.

Some administrative units have multiple geometry records. All parts receive
the same coverage value; they are not counted as separate statistical units.
Assertions require all 61 national and all 1,004 regional units to be mapped.

Maps use the Robinson projection and the same discrete 4–10-year colour scale.
Grey denotes exclusion from the corresponding analysis sample, not zero
religious expression or zero well-being. Antarctica is omitted. National
coastlines are simplified for display only, retaining the original geometry
if simplification would make a feature empty. Statistical inputs are unchanged.

## Outputs

- `coverage_by_unit.csv`: one row per included national or regional unit,
  with the eligible years listed explicitly.
- `regional_boundary_crosswalk.csv`: auditable matching of all regional units.
- `sample_checks.csv`, `years_distribution.csv`: sample totals and counts by
  number of available years.
- `input_provenance.json`: SHA-256 hashes of data and boundary inputs.
- `session_info.txt`: R environment used to draw the figure.
- `geographic_coverage.png`: final figure.

The PNG is included in the manuscript's data section. Figure numbering is
managed by LaTeX through `fig:coverage`.

The model-input CSV includes the USA as one country and the 50 states plus District of Columbia as regional units. All 51 US regional units contribute ten eligible years to this map.
