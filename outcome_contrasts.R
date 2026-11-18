#!/usr/bin/env Rscript

# Compare standardized religion slopes for purpose and the other two outcomes
# on identical place-year samples. These are descriptive, clustered contrasts.
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

root <- file.path(getwd(), "results")
settings <- fread(file.path(root, "paper_checks", "temporal_settings.csv"))
setting <- function(name) as.integer(settings[option == name, value])
start_year <- setting("start_year")
end_year <- setting("complete_end_year")
min_years <- setting("min_years")
outcomes <- c("happiness", "lifesat", "purpose")

contrast_row <- function(fit, term, comparison, design, n_units, n_countries) {
  ct <- coeftable(fit)[term, ]
  ci <- confint(fit)[term, ]
  data.table(design, comparison,
             difference = unname(ct["Estimate"]),
             se = unname(ct["Std. Error"]),
             ci_low = as.numeric(ci[1L, 1L]),
             ci_high = as.numeric(ci[1L, 2L]),
             p = unname(ct["Pr(>|t|)"]),
             n_observations = nobs(fit), n_units, n_countries)
}

rows <- list()
for (level in c("Country", "NUTS1")) {
  d <- fread(file.path(root, "religion_panel", paste0("panel_", level, ".csv")))
  d <- d[between(year, start_year, end_year) & is.finite(religion_composite)]
  d <- d[Reduce(`&`, lapply(outcomes, function(name) is.finite(d[[name]])))]
  d <- d[, if (uniqueN(year) >= min_years) .SD, by = unit]
  if (uniqueN(d$ISO) < 15L) stop("Insufficient common sample: ", level)
  d[, x := as.numeric(scale(religion_composite))]
  for (outcome in outcomes) d[, (paste0(outcome, "_z")) := as.numeric(scale(get(outcome)))]
  d[, time := year - start_year]
  for (other in c("happiness", "lifesat")) {
    d[, difference_y := purpose_z - get(paste0(other, "_z"))]
    fit <- feols(difference_y ~ x | unit + year + ISO[time], data = d,
                 vcov = ~ISO, notes = FALSE, warn = FALSE)
    rows[[length(rows) + 1L]] <- contrast_row(
      fit, "x", paste0("purpose minus ", other),
      paste0(level, " annual ", start_year, "-", end_year),
      uniqueN(d$unit), uniqueN(d$ISO))
  }
}

static <- fread(file.path(root, "regional_static", "region_means.csv"))
for (other in c("happiness", "lifesat")) {
  static[, difference_y := purpose_z - get(paste0(other, "_z"))]
  fit <- feols(difference_y ~ religion_z | ISO, data = static,
               weights = ~country_weight, vcov = ~ISO,
               notes = FALSE, warn = FALSE)
  rows[[length(rows) + 1L]] <- contrast_row(
    fit, "religion_z", paste0("purpose minus ", other),
    paste0("NUTS1 period means ", unique(static$window)),
    uniqueN(static$unit), uniqueN(static$ISO))
}

result <- rbindlist(rows)
fwrite(result, file.path(root, "paper_checks", "outcome_contrasts.csv"))
print(result)
