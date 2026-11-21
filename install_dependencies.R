# Run once before reproduce.R. Existing installations are preserved.
packages <- c("data.table","fixest","lavaan","ggplot2")
if ("--maps" %in% commandArgs(trailingOnly = TRUE))
  packages <- unique(c(packages, "sf", "patchwork", "ragg"))
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) install.packages(missing,repos="https://cloud.r-project.org")
