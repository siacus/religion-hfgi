#!/usr/bin/env Rscript
# Map the exact annual-association samples, without fitting any model.
# Usage: Rscript coverage_maps.R --data MODEL_DATA.csv --spatial-dir DIR --output-dir DIR
suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(patchwork)
})
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %% 2L == 0L)
opt <- list(data = NULL, spatial_dir = NULL, output_dir = "results/coverage_maps")
for (i in seq(1L, length(args), by = 2L)) {
  key <- gsub("-", "_", sub("^--", "", args[i]))
  stopifnot(key %in% names(opt))
  opt[[key]] <- args[i + 1L]
}
stopifnot(!is.null(opt$data), !is.null(opt$spatial_dir))
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)
d <- fread(opt$data, na.strings = "NA")[analysis == "annual_association"]
stopifnot(all(d$year %in% 2013:2022),
          !anyDuplicated(d[, .(geographic_level, unit, year)]),
          all(is.finite(as.matrix(d[, .(religious_expression, happiness,
                                         life_satisfaction, purpose)]))))
coverage <- d[, .(n_years = uniqueN(year),
                  years = paste(sort(unique(year)), collapse = ";")),
              by = .(geographic_level, country, unit)]
country <- coverage[geographic_level == "Country"]
region <- coverage[geographic_level == "NUTS1"]
stopifnot(nrow(country) == 60L, sum(country$n_years) == 592L,
          nrow(region) == 953L, uniqueN(region$country) == 59L,
          sum(region$n_years) == 7840L, all(coverage$n_years %in% 4:10))
fwrite(coverage, file.path(opt$output_dir, "coverage_by_unit.csv"))

message("Reading the project's existing boundary layers...")
world <- st_read(file.path(opt$spatial_dir, "adm0.shp"), quiet = TRUE)
regions <- st_read(file.path(opt$spatial_dir, "adm1_simplify.shp"), quiet = TRUE)
lookup <- unique(as.data.table(st_drop_geometry(world))[, .(ID_0, ISO2)])
stopifnot(!anyDuplicated(lookup$ID_0))
regions$country <- lookup$ISO2[match(regions$ID_0, lookup$ID_0)]
regions$boundary_unit <- paste(regions$country, regions$ID_1, regions$NAME_1, sep = "|")
boundaries <- unique(as.data.table(st_drop_geometry(regions))[
  , .(country, region_id = as.integer(ID_1), boundary_name = NAME_1, boundary_unit)])
region[, c("country_key", "region_id", "region_name") := tstrsplit(unit, "|", fixed = TRUE)]
region[, region_id := as.integer(region_id)]
stopifnot(all(region$country == region$country_key))
region[, boundary_unit := unit]
region[, match_method := "Exact country, region ID and name"]
missing <- which(!region$unit %in% boundaries$boundary_unit)
# The legacy shapefile replaces some Unicode characters with '?', and uses
# the older name Laoighis for Laois. Only accept a unique country/ID match;
# require the name to agree after those documented substitutions.
for (i in missing) {
  candidate <- boundaries[country == region$country[i] & region_id == region$region_id[i]]
  stopifnot(nrow(candidate) == 1L)
  old <- candidate$boundary_name
  current <- region$region_name[i]
  encoding_match <- nchar(old) == nchar(current) &&
    all(strsplit(old, "")[[1L]] == "?" |
        strsplit(old, "")[[1L]] == strsplit(current, "")[[1L]])
  alias_match <- region$unit[i] == "IE|11|Laois" && old == "Laoighis"
  stopifnot(encoding_match || alias_match)
  region$boundary_unit[i] <- candidate$boundary_unit
  region$match_method[i] <- if (alias_match) "Unique country/ID; Laois=Laoighis" else
    "Unique country/ID; legacy '?' encoding"
}
stopifnot(!anyDuplicated(region$boundary_unit))
region[, boundary_name := boundaries$boundary_name[match(boundary_unit, boundaries$boundary_unit)]]
fwrite(region[, .(country, unit, region_id, region_name, boundary_name,
                  boundary_unit, match_method, n_years)],
       file.path(opt$output_dir, "regional_boundary_crosswalk.csv"))
regions$n_years <- region$n_years[match(regions$boundary_unit, region$boundary_unit)]
world$n_years <- country$n_years[match(world$ISO2, country$country)]
stopifnot(setequal(world$ISO2[!is.na(world$n_years)], country$country),
          setequal(regions$boundary_unit[!is.na(regions$n_years)], region$boundary_unit))
message("All 60 countries and 953 regions matched; simplifying display geometry...")

# Simplification affects display only; statistical samples and identifiers
# remain untouched. Retain original geometry for any feature made empty.
sf_use_s2(FALSE)
world <- world[is.na(world$ISO2) | world$ISO2 != "AQ", c("ISO2", "n_years")]
original <- st_geometry(world)
simplified <- suppressWarnings(st_simplify(original, dTolerance = 0.035, preserveTopology = TRUE))
empty <- st_is_empty(simplified)
simplified[empty] <- original[empty]
st_geometry(world) <- simplified
selected <- regions[!is.na(regions$n_years), c("boundary_unit", "n_years")]
robinson <- "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs"
project <- function(x) st_transform(st_wrap_dateline(x, options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180")), robinson)
world <- project(world)
selected <- project(selected)
saveRDS(list(world = world, selected = selected),
        file.path(opt$output_dir, "display_geometry.rds"))
world$years <- factor(world$n_years, levels = 4:10)
selected$years <- factor(selected$n_years, levels = 4:10)
palette <- setNames(c("#d3e7ed", "#b0d5df", "#82bbc9", "#51a0b2",
                      "#2b8299", "#155e7a", "#0b3954"), as.character(4:10))
map_theme <- theme_void(base_size = 10, base_family = "sans") +
  theme(plot.title = element_text(face = "bold", size = 11, margin = margin(b = 3)),
        plot.subtitle = element_text(size = 9, color = "#404040", margin = margin(b = 4)),
        plot.margin = margin(5, 4, 3, 4), legend.position = "bottom",
        legend.title = element_text(size = 9), legend.text = element_text(size = 9),
        legend.key.width = grid::unit(8, "mm"), legend.key.height = grid::unit(4, "mm"))
scale_years <- function() scale_fill_manual(values = palette, limits = as.character(4:10),
  drop = FALSE, na.value = "#e5e5e5", na.translate = FALSE,
  name = "Years available, 2013–2022",
  guide = guide_legend(nrow = 1, title.position = "top", title.hjust = 0.5))
coordinates <- function() coord_sf(crs = robinson, datum = NA, expand = FALSE,
  xlim = c(-17000000, 17000000), ylim = c(-6300000, 8500000))
national <- ggplot() +
  geom_sf(data = world, fill = "#e5e5e5", color = "white", linewidth = 0.12) +
  geom_sf(data = world[!is.na(world$n_years), ], aes(fill = years),
          color = "white", linewidth = 0.12) +
  scale_years() + coordinates() + map_theme +
  theme(legend.position = "none") +
  labs(title = "A  National coverage", subtitle = "60 countries · 592 country-years")
regional <- ggplot() +
  geom_sf(data = world, fill = "#e5e5e5", color = "white", linewidth = 0.12) +
  geom_sf(data = selected, aes(fill = years), color = "white", linewidth = 0.10,
          show.legend = TRUE) +
  scale_years() + coordinates() + map_theme +
  labs(title = "B  Regional coverage", subtitle = "953 regions in 59 countries · 7,840 region-years")
combined <- (national / regional / guide_area()) +
  plot_layout(heights = c(1, 1, 0.15), guides = "collect") +
  plot_annotation(caption = "Grey: outside the corresponding analysis sample.",
    theme = theme(plot.caption = element_text(size = 9, hjust = 0.5),
                  plot.margin = margin(3, 3, 3, 3)))
ggsave(file.path(opt$output_dir, "geographic_coverage.png"), combined,
       width = 7.1, height = 7.6, dpi = 450, bg = "white", device = ragg::agg_png)
summary <- coverage[, .(units = .N, countries = uniqueN(country),
                       observations = sum(n_years), min_years = min(n_years),
                       max_years = max(n_years)), by = geographic_level]
fwrite(summary, file.path(opt$output_dir, "sample_checks.csv"))
fwrite(coverage[, .N, by = .(geographic_level, n_years)][order(geographic_level, n_years)],
       file.path(opt$output_dir, "years_distribution.csv"))
capture.output(sessionInfo(), file = file.path(opt$output_dir, "session_info.txt"))
print(summary)
message("Coverage maps saved without compiling the manuscript.")
