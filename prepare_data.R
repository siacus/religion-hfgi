#!/usr/bin/env Rscript
source("model_data.R")
dir.create("results/religion_panel",recursive=TRUE,showWarnings=FALSE)
dir.create("results/community_pathway",recursive=TRUE,showWarnings=FALSE)
for (lev in c("Country","NUTS1")) {
  d <- read_model_data("annual_association",lev)
  d <- d[,.(ISO,unit,year,religion_composite=religious_expression,happiness,lifesat,purpose)]
  fwrite(d,file.path("results/religion_panel",paste0("panel_",lev,".csv")))
}
settings <- list(start_year=2013L,end_year=2022L,min_years=4L)
fwrite(data.table(option=names(settings),value=unlist(settings)),"results/community_pathway/settings.csv")
