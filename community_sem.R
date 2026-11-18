#!/usr/bin/env Rscript

# Observed-variable longitudinal SEM for the two aggregate HFGI indices.
# Fixed effects are removed with the same weighted projection as the
# regression paths; country-clustered uncertainty remains descriptive.
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(lavaan)
})
source("model_data.R", local = TRUE)
source("observed_sem_diagnostics.R", local = TRUE)

read_settings <- function(path) {
  settings <- fread(path)
  values <- as.list(setNames(settings$value, settings$option))
  for (key in c("start_year", "end_year", "min_years"))
    values[[key]] <- as.integer(values[[key]])
  values
}

lagged_sample <- function(d) {
  next_m <- d[, .(unit, year = year - 1L, community_next = community_z)]
  future_y <- d[, .(unit, year = year - 2L,
                    happiness_future = happiness_z,
                    lifesat_future = lifesat_z,
                    purpose_future = purpose_z)]
  sample <- merge(merge(d, next_m, by = c("unit", "year")),
                  future_y, by = c("unit", "year"))
  sample <- sample[, if (uniqueN(year) >= 3L) .SD, by = unit]
  sample[, weight := 1 / .N, by = ISO]
  sample
}

fit_level <- function(level, options) {
  d <- lagged_sample(prepare(level, options))
  names_to_fit <- c("religion_composite_z", "community_z",
                    paste0(outcomes, "_z"), "community_next",
                    paste0(outcomes, "_future"))
  residuals <- lapply(names_to_fit, function(name) {
    fit <- feols(as.formula(paste0(name, " ~ 1 | unit + year + ISO[time]")),
                 data = d, weights = ~weight, notes = FALSE, warn = FALSE)
    as.numeric(resid(fit))
  })
  names(residuals) <- names_to_fit
  sem_data <- as.data.table(residuals)
  sem_data[, `:=`(ISO = d$ISO, weight = d$weight)]
  model <- '
    community_next ~ a*religion_composite_z + community_z + happiness_z + lifesat_z + purpose_z
    happiness_future ~ b_h*community_next + c_h*religion_composite_z + community_z + happiness_z + lifesat_z + purpose_z
    lifesat_future ~ b_l*community_next + c_l*religion_composite_z + community_z + happiness_z + lifesat_z + purpose_z
    purpose_future ~ b_p*community_next + c_p*religion_composite_z + community_z + happiness_z + lifesat_z + purpose_z
    happiness_future ~~ lifesat_future
    happiness_future ~~ purpose_future
    lifesat_future ~~ purpose_future
    # Country fixed effects already force these residualized means to zero.
    community_next ~ 0*1
    happiness_future ~ 0*1
    lifesat_future ~ 0*1
    purpose_future ~ 0*1
    indirect_h := a*b_h
    indirect_l := a*b_l
    indirect_p := a*b_p
    total_h := c_h + indirect_h
    total_l := c_l + indirect_l
    total_p := c_p + indirect_p
  '
  fit <- lavaan::sem(model, data = as.data.frame(sem_data),
                     sampling.weights = "weight", cluster = "ISO",
                     estimator = "MLR", ncpus = 1L, fixed.x = TRUE,
                     meanstructure = TRUE)
  if (!lavInspect(fit, "converged")) stop("SEM did not converge: ", level)
  estimates <- as.data.table(parameterEstimates(fit, ci = TRUE))
  path <- estimates[(lhs == "community_next" & rhs == "religion_composite_z") |
                      (lhs %in% paste0(outcomes, "_future") &
                         rhs %in% c("community_next", "religion_composite_z")) |
                      op == ":=",
                    .(lhs, op, rhs, label, estimate = est, se, pvalue, ci.lower, ci.upper)]
  path[, `:=`(level = level, n_observations = nrow(d),
              n_units = uniqueN(d$unit), n_countries = uniqueN(d$ISO))]
  diagnostics <- observed_sem_diagnostics(fit, sem_data,
    c("community_next", paste0(outcomes, "_future")), names_to_fit,
    cluster = "ISO", weight = "weight")
  diagnostics[, level := level]
  list(paths = path, fit = fit, diagnostics = diagnostics)
}

main_sem <- function() {
  options <- read_settings(file.path("results", "community_pathway", "settings.csv"))
  options$output_dir <- file.path(getwd(), "results", "community_sem")
  dir.create(options$output_dir, recursive = TRUE, showWarnings = FALSE)
  fits <- lapply(c("Country", "NUTS1"), fit_level, options = options)
  names(fits) <- c("Country", "NUTS1")
  paths <- rbindlist(lapply(fits, `[[`, "paths"))
  fwrite(paths, file.path(options$output_dir, "sem_paths.csv"))
  fit_stats <- rbindlist(lapply(fits, `[[`, "diagnostics"))
  fwrite(fit_stats, file.path(options$output_dir, "sem_fit.csv"))
  cat("Estimated longitudinal observed-variable SEM for",
      paste(names(fits), collapse = " and "), "\n")
  print(paths[, .(level, lhs, op, rhs, estimate, se, pvalue)])
}

if (sys.nframe() == 0L) main_sem()
