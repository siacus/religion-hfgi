#!/usr/bin/env Rscript

# Two-level latent SEM of regional panel: within-region annual variation and
# between-region mean differences, after country/year/trend adjustment.
source("community_sem.R", local = TRUE)

religion_items <- c("afterlife","believegod","lovedgod","relcomfort")
social_items <- c("belonging","loneliness","trust","trusted")

latent_sample <- function(options) {
  d <- read_model_data("latent_diagnostic", "NUTS1")
  setnames(d, c("belief_afterlife","belief_god","loved_by_god","religious_comfort",
                "belonging","reversed_loneliness","trust","trusted",outcomes),
              c("afterlife_z","believegod_z","lovedgod_z","relcomfort_z",
                "belonging_next","loneliness_next","trust_next","trusted_next",
                paste0(outcomes,"_future")))
  d[, `:=`(weight=1/.N,time=year-2013L),by=ISO]
  setorder(d,unit,year)
  fields <- c(paste0(religion_items,"_z"),paste0(social_items,"_next"),paste0(outcomes,"_future"))
  values <- lapply(fields,function(name) {
    fit <- feols(as.formula(paste0(name," ~ 1 | ISO + year + ISO[time]")),
                 data=d,weights=~weight,notes=FALSE,warn=FALSE)
    as.numeric(resid(fit))
  })
  names(values) <- fields
  x <- as.data.table(values)
  x[, unit := d$unit]
  x
}

main_latent <- function() {
  options <- read_settings(file.path("results", "community_pathway", "settings.csv"))
  x <- latent_sample(options)
  model_template <- '
    level: 1
      Rw =~ afterlife_z + believegod_z + lovedgod_z + relcomfort_z
      Sw =~ belonging_next + loneliness_next + trust_next + trusted_next
      Sw ~ aw*Rw
      happiness_future ~ bwh*Sw + cwh*Rw
      lifesat_future ~ bwl*Sw + cwl*Rw
      purpose_future ~ bwp*Sw + cwp*Rw
      happiness_future ~~ lifesat_future
      happiness_future ~~ purpose_future
      lifesat_future ~~ purpose_future
%s
    level: 2
      Rb =~ afterlife_z + believegod_z + lovedgod_z + relcomfort_z
      Sb =~ belonging_next + loneliness_next + trust_next + trusted_next
      Sb ~ ab*Rb
      happiness_future ~ bbh*Sb + cbh*Rb
      lifesat_future ~ bbl*Sb + cbl*Rb
      purpose_future ~ bbp*Sb + cbp*Rb
      happiness_future ~~ lifesat_future
      happiness_future ~~ purpose_future
      lifesat_future ~~ purpose_future
%s
  '
  output_dir <- file.path(getwd(), "results", "latent_multilevel_sem")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  observed <- c(paste0(religion_items, "_z"),
                paste0(social_items, "_next"),
                paste0(outcomes, "_future"))
  bound_lines <- paste(sprintf("      %s ~~ lower(0)*%s", observed, observed),
                       collapse = "\n")
  models <- list(unbounded = sprintf(model_template, "", ""),
                 nonnegative_variances = sprintf(model_template,
                                                 bound_lines, bound_lines))
  fits <- lapply(models, function(model) {
    tryCatch(lavaan::sem(model, data = as.data.frame(x), cluster = "unit",
                         estimator = "MLR", ncpus = 1L, fixed.x = TRUE,
                         meanstructure = TRUE),
             error = function(e) e)
  })
  diagnostics <- rbindlist(lapply(names(fits), function(specification) {
    fit <- fits[[specification]]
    if (inherits(fit, "error") || !lavInspect(fit, "converged"))
      return(data.table(specification, converged = FALSE,
                        admissible = FALSE, negative_variances = NA_integer_,
                        boundary_variances = NA_integer_,
                        n_observations = nrow(x), n_regions = uniqueN(x$unit),
                        df = NA_real_, cfi = NA_real_, rmsea = NA_real_))
    variances <- as.data.table(parameterEstimates(fit))[
      op == "~~" & lhs == rhs]
    data.table(specification, converged = TRUE,
               admissible = all(variances$est >= 0),
               negative_variances = sum(variances$est < 0),
               boundary_variances = sum(variances$est >= 0 &
                                          variances$est <= 1e-4),
               n_observations = nrow(x), n_regions = uniqueN(x$unit),
               df = as.numeric(fitMeasures(fit, "df")),
               cfi = as.numeric(fitMeasures(fit, "cfi")),
               rmsea = as.numeric(fitMeasures(fit, "rmsea")))
  }))
  fwrite(diagnostics, file.path(output_dir, "diagnostics.csv"))
  negative_variances <- rbindlist(lapply(names(fits), function(specification) {
    fit <- fits[[specification]]
    if (inherits(fit, "error") || !lavInspect(fit, "converged"))
      return(NULL)
    d <- as.data.table(parameterEstimates(fit))[
      op == "~~" & lhs == rhs & est < 0]
    d[, specification := specification]
    d
  }), fill = TRUE)
  if (nrow(negative_variances))
    fwrite(negative_variances,
           file.path(output_dir, "negative_variances.csv"))
  else {
    path <- file.path(output_dir, "negative_variances.csv")
    if (file.exists(path)) unlink(path)
  }
  bounded_fit <- fits[["nonnegative_variances"]]
  boundary_variances <- if (!inherits(bounded_fit, "error") &&
                            lavInspect(bounded_fit, "converged"))
    as.data.table(parameterEstimates(bounded_fit))[
      op == "~~" & lhs == rhs & est >= 0 & est <= 1e-4] else data.table()
  if (nrow(boundary_variances))
    fwrite(boundary_variances,
           file.path(output_dir, "boundary_variances.csv"))
  else {
    path <- file.path(output_dir, "boundary_variances.csv")
    if (file.exists(path)) unlink(path)
  }
  for (name in c("diagnostic_paths_uninterpretable.csv", "standardized_paths.csv")) {
    path <- file.path(output_dir, name)
    if (file.exists(path)) unlink(path)
  }
  print(diagnostics)
  if (nrow(negative_variances))
    print(negative_variances[, .(specification, lhs, rhs, est)])
  if (nrow(boundary_variances))
    print(boundary_variances[, .(lhs, rhs, est)])
}

if (sys.nframe() == 0L) main_latent()
