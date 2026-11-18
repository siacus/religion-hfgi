# Read the released model variables; no raw posts or component indicators are required.
suppressPackageStartupMessages({library(data.table); library(fixest); library(lavaan)})
outcomes <- c("happiness", "lifesat", "purpose")
read_model_data <- function(analysis_name, level = NULL) {
  x <- fread("data/model_data.csv", na.strings = "NA")
  x <- x[analysis == analysis_name]
  if (!is.null(level)) x <- x[geographic_level == level]
  if (!nrow(x)) stop("Empty released analysis block: ", analysis_name)
  setnames(x, c("country", "life_satisfaction"), c("ISO", "lifesat"))
  x
}
prepare <- function(level, options) {
  d <- read_model_data("longitudinal_pathway", level)
  setnames(d,c("religious_expression","connectedness",outcomes),
           c("religion_composite_z","community_z",paste0(outcomes,"_z")))
  d[, time := year - 2013L]
  setorder(d,ISO,unit,year)
  d
}
