#!/usr/bin/env Rscript
source("model_data.R")
fit_check <- function(panel, level, outcome, end_year, trend, options) {
  d <- panel[year >= options$start_year & year <= end_year &
               is.finite(religion_composite) & is.finite(get(outcome)),
             .(ISO, unit, year, x = religion_composite, y = get(outcome))]
  d <- d[, if (uniqueN(year) >= options$min_years) .SD, by = unit]
  if (nrow(d) < 30L || uniqueN(d$ISO) < 8L || sd(d$x) <= 0 || sd(d$y) <= 0) {
    stop("Insufficient variation or coverage: ", level, " ", outcome, " ", end_year)
  }
  # As in the main analysis, standardize within the model's estimation sample.
  d[, `:=`(x = as.numeric(scale(x)), y = as.numeric(scale(y)),
           country_trend = year - options$start_year)]
  form <- if (trend) {
    y ~ x | unit + year + ISO[country_trend]
  } else {
    y ~ x | unit + year
  }
  fit <- suppressMessages(fixest::feols(form, data = d, vcov = ~ISO,
                                       notes = FALSE, warn = FALSE))
  ct <- fixest::coeftable(fit)["x", ]
  ci <- stats::confint(fit)["x", ]
  data.frame(
    level = level, outcome = outcome,
    window = sprintf("%d-%d", options$start_year, end_year),
    end_year = end_year, country_linear_trends = trend,
    beta = unname(ct["Estimate"]), se_cluster_country = unname(ct["Std. Error"]),
    ci_low = unname(ci[1L]), ci_high = unname(ci[2L]),
    p = unname(ct["Pr(>|t|)"]),
    n_observations = stats::nobs(fit), n_units = uniqueN(d$unit),
    n_countries = uniqueN(d$ISO), n_years = uniqueN(d$year)
  )
}


options <- list(start_year=2013L,end_year=2022L,complete_end_year=2022L,min_years=4L)
rows <- list()
for (lev in c("Country","NUTS1")) {
  d <- fread(file.path("results/religion_panel",paste0("panel_",lev,".csv")))
  for (outcome in outcomes)
    rows[[length(rows)+1L]] <- fit_check(d,lev,outcome,2022L,TRUE,options)
}
dir.create("results/paper_checks",recursive=TRUE,showWarnings=FALSE)
fwrite(rbindlist(rows),"results/paper_checks/temporal_robustness.csv")
fwrite(data.table(option=names(options),value=unlist(options)),"results/paper_checks/temporal_settings.csv")
