#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(data.table))
checks <- list(
 list('paper_checks/temporal_robustness.csv',c('level','outcome')),
 list('community_sem/sem_paths.csv',c('level','label')),
 list('community_sem/sem_fit.csv','level'),
 list('regional_static/association.csv',c('window','outcome')),
 list('regional_static/sem_paths.csv',c('window','label')),
 list('regional_static/sem_fit.csv','window'),
 list('paper_checks/outcome_contrasts.csv',c('design','comparison')),
 list('country_year_robustness/coefficients.csv',c('sample','outcome','design')),
 list('country_year_robustness/outcome_contrasts.csv',c('outcome','design')),
 list('country_year_robustness/diagnostics.csv','outcome'),
 list('latent_multilevel_sem/diagnostics.csv','specification'))
report <- list()
for(check in checks) {
  path <- check[[1]]; keys <- check[[2]]
  expected <- fread(file.path('reference',path));actual <- fread(file.path('results',path))
  setorderv(expected,keys);setorderv(actual,keys)
  stopifnot(nrow(actual)==nrow(expected),identical(actual[,..keys],expected[,..keys]))
  fields <- names(expected)[vapply(expected,is.numeric,logical(1))]
  for(field in fields) {
    a <- actual[[field]]; b <- expected[[field]]
    stopifnot(identical(is.na(a),is.na(b)),identical(is.finite(a),is.finite(b)))
    use <- is.finite(a)&is.finite(b)
    error <- if(any(use)) max(abs(a[use]-b[use])) else 0
    relative <- if(any(use)) max(abs(a[use]-b[use])/pmax(1,abs(b[use]))) else 0
    count <- grepl('^n_|^df$|degrees|variances|clusters',field)
    tolerance <- if(count) 0 else 1e-6
    report[[length(report)+1L]] <- data.table(file=path,field,max_absolute_error=error,
        max_scaled_error=relative,tolerance,passed=relative<=tolerance)
  }
}
z <- rbindlist(report);fwrite(z,'results/verification.csv')
if(!all(z$passed)) {print(z[passed==FALSE]);stop('Reference comparison failed.')}
for(path in c('community_sem/sem_fit.csv','regional_static/sem_fit.csv')) {
 d <- fread(file.path('results',path));stopifnot(all(d$converged),all(d$admissible),all(d$min_vcov_eigenvalue>0))
}
cat('Verified',nrow(z),'numeric fields against the manuscript reference outputs.\n')
