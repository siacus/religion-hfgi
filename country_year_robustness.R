#!/usr/bin/env Rscript

# Regional annual association sensitivity to unrestricted country-year effects.
# Uses the saved panel and settings underlying the manuscript; no SEM rerun.
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

out_dir <- file.path("results", "country_year_robustness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
settings_path <- file.path("results", "paper_checks", "temporal_settings.csv")
panel_path <- file.path("results", "religion_panel", "panel_NUTS1.csv")
settings <- fread(settings_path)
setting <- function(key) as.integer(settings[option == key, value])
start_year <- setting("start_year")
end_year <- setting("complete_end_year")
min_years <- setting("min_years")
panel <- fread(panel_path)
stopifnot(!anyDuplicated(panel, by = c("unit", "year")))
old <- fread(file.path("results", "paper_checks", "temporal_robustness.csv"))
outcomes <- c("happiness", "lifesat", "purpose")

prepare <- function(required) {
  d <- panel[between(year, start_year, end_year) & is.finite(religion_composite)]
  d <- d[Reduce(`&`, lapply(required, function(v) is.finite(d[[v]])))]
  d <- d[, if (uniqueN(year) >= min_years) .SD, by = unit]
  d[, `:=`(x = as.numeric(scale(religion_composite)), time = year - start_year)]
  for (v in required) d[, (paste0(v, "_z")) := as.numeric(scale(get(v)))]
  d
}

fit_model <- function(d, design) {
  form <- if (design == "country_linear_trends") {
    y ~ x | unit + year + ISO[time]
  } else {
    y ~ x | unit + ISO^year
  }
  # Keep the same rows even if a country-year is a singleton. Such rows carry
  # no identifying within-cell variation; quantify this in diagnostics.csv.
  feols(form, data = d, vcov = ~ISO, fixef.rm = "none",
        demeaned = TRUE, fixef.tol = 1e-9, notes = FALSE)
}

extract <- function(fit, d, outcome, design, sample) {
  stopifnot(nobs(fit) == nrow(d), "x" %in% names(coef(fit)))
  # Independent FWL slope check using residualized variables from the FE fit.
  xd <- as.numeric(fit$X_demeaned[, "x"])
  fwl <- sum(xd * fit$y_demeaned) / sum(xd^2)
  stopifnot(abs(fwl - coef(fit)["x"]) < 1e-8)
  ct <- coeftable(fit)["x", ]
  ci <- as.numeric(confint(fit)["x", ])
  data.table(sample, outcome, design, beta = unname(ct["Estimate"]),
             se = unname(ct["Std. Error"]), ci_low = ci[1], ci_high = ci[2],
             p = unname(ct["Pr(>|t|)"]), n_observations = nrow(d),
             n_regions = uniqueN(d$unit), n_countries = uniqueN(d$ISO),
             n_years = uniqueN(d$year), residual_x_ss = sum(xd^2))
}

rows <- diagnostics <- samples <- list()
for (outcome in outcomes) {
  d <- prepare(outcome)
  d[, y := get(paste0(outcome, "_z"))]
  fits <- lapply(c("country_linear_trends", "country_year_fe"), function(design) {
    fit <- fit_model(d, design)
    rows[[length(rows) + 1L]] <<- extract(fit, d, outcome, design, "outcome_specific")
    fit
  })
  selected_outcome <- outcome
  selected_end_year <- end_year
  ref <- old[level == "NUTS1" & outcome == selected_outcome & end_year == selected_end_year &
               country_linear_trends == TRUE]
  stopifnot(nrow(ref) == 1L)
  baseline <- rows[[length(rows) - 1L]]
  stopifnot(abs(baseline$beta - ref$beta) < 1e-7,
            abs(baseline$se - ref$se_cluster_country) < 1e-7,
            baseline$n_observations == ref$n_observations)
  cells <- d[, .N, by = .(ISO, year)]
  xd <- as.numeric(fits[[2]]$X_demeaned[, "x"])
  info <- data.table(ISO = d$ISO, x2 = xd^2)[, .(x_ss = sum(x2)), by = ISO]
  # Exclude countries with no residual identifying variation to check that
  # counting noninformative clusters does not drive the reported intervals.
  informative <- d[ISO %chin% info[x_ss > 1e-10, ISO]]
  informative_fit <- fit_model(informative, "country_year_fe")
  informative_row <- extract(informative_fit, informative, outcome,
                             "country_year_fe", "informative_countries")
  stopifnot(abs(informative_row$beta - coef(fits[[2]])["x"]) < 1e-7)
  rows[[length(rows) + 1L]] <- informative_row
  diagnostics[[outcome]] <- data.table(
    outcome, n_country_year_cells = nrow(cells),
    singleton_country_year_cells = sum(cells$N == 1L),
    countries_with_identifying_variation = sum(info$x_ss > 1e-10),
    residual_x_ss_ratio = sum(xd^2) / sum(fits[[1]]$X_demeaned[, "x"]^2))
  samples[[outcome]] <- d[, .(outcome = selected_outcome, ISO, unit, year)]
}

# Paired outcome contrasts on exactly the same rows and standardization.
common <- prepare(outcomes)
contrast_rows <- list()
for (design in c("country_linear_trends", "country_year_fe")) {
  common_coefs <- numeric()
  for (outcome in outcomes) {
    common[, y := get(paste0(outcome, "_z"))]
    fit <- fit_model(common, design)
    rows[[length(rows) + 1L]] <- extract(fit, common, outcome, design, "common_outcomes")
    common_coefs[outcome] <- coef(fit)["x"]
  }
  for (other in c("happiness", "lifesat")) {
    common[, y := purpose_z - get(paste0(other, "_z"))]
    fit <- fit_model(common, design)
    stopifnot(abs(coef(fit)["x"] - (common_coefs["purpose"] - common_coefs[other])) < 1e-8)
    contrast_rows[[length(contrast_rows) + 1L]] <- extract(
      fit, common, paste0("purpose minus ", other), design, "common_outcomes")
  }
}

result <- rbindlist(rows)
contrasts <- rbindlist(contrast_rows)
fwrite(result, file.path(out_dir, "coefficients.csv"))
fwrite(contrasts, file.path(out_dir, "outcome_contrasts.csv"))
fwrite(rbindlist(diagnostics), file.path(out_dir, "diagnostics.csv"))
fwrite(rbindlist(samples), file.path(out_dir, "sample_keys.csv"))
inputs <- c(panel_path, settings_path,
            file.path("results", "paper_checks", "temporal_robustness.csv"))
fwrite(data.table(path = inputs, md5 = unname(tools::md5sum(inputs))),
       file.path(out_dir, "input_hashes.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))

lines <- c("# Regional association sensitivity: country-by-year effects", "",
  sprintf("Window: %d–%d; minimum %d observed years per region.", start_year, end_year, min_years),
  "Prepared HFGI NUTS1 panel; unweighted OLS; country-clustered standard errors with fixest default small-sample adjustments.",
  "Baseline: region FE + year FE + country linear trends. Sensitivity: region FE + country-by-year FE.",
  "Country-by-year FE subsume common year effects and country linear trends.",
  "Each pair uses identical observations and the same sample-standardized predictor and outcome; no restandardization after absorbing FE.",
  "Singleton country-years are retained to preserve the sample but provide no within-cell identifying variation.", "",
  "| Outcome | Specification | Beta | 95% CI | Region-years | Regions | Countries |",
  "|---|---|---:|---|---:|---:|---:|")
for (i in which(result$sample == "outcome_specific")) {
  z <- result[i]
  lines <- c(lines, sprintf("| %s | %s | %.3f | [%.3f, %.3f] | %d | %d | %d |",
    z$outcome, z$design, z$beta, z$ci_low, z$ci_high, z$n_observations, z$n_regions, z$n_countries))
}
lines <- c(lines, "", "## Direct outcome contrasts on common samples", "",
           "| Contrast | Specification | Difference | 95% CI |", "|---|---|---:|---|")
for (i in seq_len(nrow(contrasts))) {
  z <- contrasts[i]
  lines <- c(lines, sprintf("| %s | %s | %.3f | [%.3f, %.3f] |",
                            z$outcome, z$design, z$beta, z$ci_low, z$ci_high))
}
lines <- c(lines, "", "## Validation and scope", "",
  "Reproduced saved baseline coefficients, standard errors, and sample sizes (tolerance 1e-7).",
  "Verified slopes against residualized-variable OLS and outcome contrasts against differences of slopes.",
  "See diagnostics.csv for singleton cells and residual predictor variation retained by the stricter specification.",
  "This checks contemporaneous associations after arbitrary additive country-year shifts; it does not test lagged mediation, causal identification, regional measurement validity, or heterogeneous exposure to national shocks.",
  "Reproduce with `Rscript country_year_robustness.R` from the repository root.")
lines <- c(lines, "", "## Informative-country sensitivity", "",
  "Remove countries with zero residual predictor variation under country-year FE, preserving the original standardization.",
  "",
  "| Outcome | Beta | 95% CI | Region-years | Countries |", "|---|---:|---|---:|---:|")
for (i in which(result$sample == "informative_countries")) {
  z <- result[i]
  lines <- c(lines, sprintf("| %s | %.3f | [%.3f, %.3f] | %d | %d |",
    z$outcome, z$beta, z$ci_low, z$ci_high, z$n_observations, z$n_countries))
}
lines <- c(lines, "", "## Interpretation", "",
  sprintf("All three country-year FE association intervals exclude zero on the positive side: %s.",
          all(result[sample == "outcome_specific" & design == "country_year_fe", ci_low] > 0)),
  sprintf("Both country-year FE purpose-minus-other outcome contrast intervals exclude zero on the positive side: %s.",
          all(contrasts[design == "country_year_fe", ci_low] > 0)),
  sprintf("All three intervals remain positive after excluding noninformative countries: %s.",
          all(result[sample == "informative_countries", ci_low] > 0)),
  "The observed regional associations survive removal of additive changes shared by all regions of a country in a year.",
  "This provides a complementary regional association check for the national-connectedness framing; it does not estimate the lagged SEM paths.")
writeLines(lines, file.path(out_dir, "summary.md"))
print(result[sample == "outcome_specific"])
print(contrasts)
print(rbindlist(diagnostics))
