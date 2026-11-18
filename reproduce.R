#!/usr/bin/env Rscript
# Run from the repository root. Each stage has its own R session.
if (!file.exists("data/model_data.csv")) stop("Run from the repository root.")
required <- c("data.table","fixest","lavaan","ggplot2")
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop("Missing packages: ",paste(missing,collapse=", "),". Run Rscript install_dependencies.R.")
for(stage in c("prepare_data.R","annual_associations.R","community_sem.R",
              "regional_static.R","latent_multilevel_sem.R","country_year_robustness.R","outcome_contrasts.R",
              "report_figures.R","verify_results.R")) {
  message("\n=== ",stage," ===")
  status <- system2(file.path(R.home("bin"),"Rscript"),stage)
  if(status!=0L) stop("Stage failed: ",stage)
}
python <- Sys.which("python3")
if(!nzchar(python)) stop("Python 3 is required to export manuscript tables and diagrams.")
if(system2(python,"export_paper_outputs.py")!=0L) stop("Output export failed.")
writeLines(capture.output(sessionInfo()),"results/sessionInfo.txt")
message("Replication complete. See results/verification.csv and results/paper_outputs/.")
