# Diagnostics for the residualized, observed-variable SEMs used in this project.
# Four zero-mean constraints are implied by the first-stage fixed effects.
# Their nominal lavaan df must not be interpreted as tests of the path structure.
observed_sem_diagnostics <- function(fit, data, endogenous, variables,
                                     cluster, weight) {
  p <- data.table::as.data.table(lavaan::parameterTable(fit))
  intercepts <- p[op == "~1" & lhs %in% endogenous]
  stopifnot(nrow(intercepts) == length(endogenous),
            all(intercepts$free == 0L), all(intercepts$est == 0))
  weight_name <- weight
  means <- data[, lapply(.SD, function(z) weighted.mean(z, w = get(weight_name))),
                by = c(cluster), .SDcols = variables]
  max_mean <- max(abs(as.matrix(means[, ..variables])))
  if (max_mean > 1e-8) stop("SEM inputs are not centered within countries")
  covariance <- lavaan::lavInspect(fit, "vcov")
  eigenvalues <- eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
  converged <- lavaan::lavInspect(fit, "converged")
  admissible <- lavaan::lavInspect(fit, "post.check")
  if (!converged || !admissible || min(eigenvalues) <= 0)
    stop("Observed SEM failed convergence, admissibility or covariance diagnostics")
  nominal_df <- as.numeric(lavaan::fitMeasures(fit, "df"))
  covariance_df <- nominal_df - nrow(intercepts)
  stopifnot(covariance_df == 0)
  data.table::data.table(df = nominal_df,
    covariance_structure_df = covariance_df,
    fixed_zero_intercepts = nrow(intercepts),
    n_free_parameters = nrow(covariance),
    converged, admissible, min_vcov_eigenvalue = min(eigenvalues),
    max_vcov_eigenvalue = max(eigenvalues),
    max_abs_country_residual_mean = max_mean,
    n_observations = nrow(data), n_countries = data.table::uniqueN(data[[cluster]]))
}
