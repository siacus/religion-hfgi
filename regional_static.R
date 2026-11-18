#!/usr/bin/env Rscript
source("model_data.R")
source("observed_sem_diagnostics.R")
fit_association <- function(d) {
  rbindlist(lapply(outcomes, function(outcome) {
    fit <- feols(as.formula(paste0(outcome, "_z ~ religion_z | ISO")),
                 data = d, weights = ~country_weight, vcov = ~ISO,
                 notes = FALSE, warn = FALSE)
    ct <- coeftable(fit)["religion_z", ]
    ci <- confint(fit)["religion_z", ]
    data.table(window = d$window[1L], outcome,
               beta = unname(ct["Estimate"]), se = unname(ct["Std. Error"]),
               p = unname(ct["Pr(>|t|)"]),
               ci_low = as.numeric(ci[1L, 1L]),
               ci_high = as.numeric(ci[1L, 2L]),
               n_regions = stats::nobs(fit), n_countries = uniqueN(d$ISO))
  }))
}

fit_static_sem <- function(d, return_fit = FALSE) {
  names_to_fit <- c("religion_z", "social_z", paste0(outcomes, "_z"))
  residuals <- lapply(names_to_fit, function(name) {
    fit <- feols(as.formula(paste0(name, " ~ 1 | ISO")),
                 data = d, weights = ~country_weight,
                 notes = FALSE, warn = FALSE)
    as.numeric(resid(fit))
  })
  names(residuals) <- names_to_fit
  sem_data <- as.data.table(residuals)
  sem_data[, ISO := d$ISO]
  sem_data[, country_weight := d$country_weight]
  model <- '
    social_z ~ a*religion_z
    happiness_z ~ b_h*social_z + c_h*religion_z
    lifesat_z ~ b_l*social_z + c_l*religion_z
    purpose_z ~ b_p*social_z + c_p*religion_z
    happiness_z ~~ lifesat_z
    happiness_z ~~ purpose_z
    lifesat_z ~~ purpose_z
    # Country fixed effects already force these residualized means to zero.
    social_z ~ 0*1
    happiness_z ~ 0*1
    lifesat_z ~ 0*1
    purpose_z ~ 0*1
    indirect_h := a*b_h
    indirect_l := a*b_l
    indirect_p := a*b_p
    total_h := c_h + indirect_h
    total_l := c_l + indirect_l
    total_p := c_p + indirect_p
  '
  fit <- lavaan::sem(model, data = as.data.frame(sem_data),
                     sampling.weights = "country_weight", cluster = "ISO",
                     estimator = "MLR", ncpus = 1L, fixed.x = TRUE,
                     meanstructure = TRUE)
  if (!lavInspect(fit, "converged")) stop("Static SEM did not converge.")
  path <- as.data.table(parameterEstimates(fit, ci = TRUE))
  path <- path[(lhs == "social_z" & rhs == "religion_z") |
                 (lhs %in% paste0(outcomes, "_z") &
                    rhs %in% c("religion_z", "social_z")) |
                 op == ":=",
               .(lhs, op, rhs, label, estimate = est, se, pvalue,
                 ci.lower, ci.upper)]
  path[, window := d$window[1L]]
  path[, n_regions := nrow(d)]
  path[, n_countries := uniqueN(d$ISO)]
  path[, df := as.numeric(fitMeasures(fit, "df"))]
  diagnostics <- observed_sem_diagnostics(fit, sem_data,
    c("social_z", paste0(outcomes, "_z")), names_to_fit,
    cluster = "ISO", weight = "country_weight")
  diagnostics[, window := d$window[1L]]
  path[, covariance_structure_df := diagnostics$covariance_structure_df]
  if (return_fit) return(list(paths = path, fit = fit, diagnostics = diagnostics))
  path
}


d <- read_model_data("regional_averages")
setnames(d,c("religious_expression","connectedness",outcomes),
         c("religion_z","social_z",paste0(outcomes,"_z")))
d[, `:=`(country_weight=1/.N,window="2013-2022"),by=ISO]
d[, effective_years := n_years]
setorder(d,ISO,unit)
out <- "results/regional_static"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
fwrite(d,file.path(out,"region_means.csv"))
fwrite(fit_association(d),file.path(out,"association.csv"))
fitted <- fit_static_sem(d,return_fit=TRUE)
fwrite(fitted$paths,file.path(out,"sem_paths.csv"))
fwrite(fitted$diagnostics,file.path(out,"sem_fit.csv"))
fwrite(data.table(option=c("start_year","end_year"),value=c(2013L,2022L)),file.path(out,"settings.csv"))
