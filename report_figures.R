#!/usr/bin/env Rscript

# Rebuild geography-specific figures in REPORT.md from current model outputs.
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

output_dir <- file.path(getwd(), "results", "report_figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
outcomes <- c("happiness", "lifesat", "purpose")
outcome_labels <- c("Happiness", "Life satisfaction", "Purpose in life")
outcome_colors <- c("Happiness" = "#2364AA",
                    "Life satisfaction" = "#B35316",
                    "Purpose in life" = "#15916D")
label_outcome <- function(x) factor(x, levels = outcomes, labels = outcome_labels)
path_outcome <- function(lhs) sub("_(future|z)$", "", lhs)
derived_outcome <- function(lhs) setNames(outcomes, c("h", "l", "p"))[
  sub("^indirect_", "", lhs)]

setting <- function(settings, name) {
  value <- settings[option == name, value]
  if (length(value) != 1L) stop("Missing or duplicate setting: ", name)
  value
}

temporal <- fread(file.path("results", "paper_checks", "temporal_robustness.csv"))
temporal_settings <- fread(file.path("results", "paper_checks", "temporal_settings.csv"))
model1_window <- sprintf("%s-%s", setting(temporal_settings, "start_year"),
                         setting(temporal_settings, "complete_end_year"))
model1 <- temporal[window == model1_window & country_linear_trends == TRUE]
if (nrow(model1) != 6L) stop("Expected six model-1 estimates.")
model1[, outcome_label := label_outcome(outcome)]

for (geography in c("Country", "NUTS1")) {
  d <- model1[level == geography]
  if (nrow(d) != 3L) stop("Expected three outcomes for ", geography)
  label <- if (geography == "Country") "Countries" else "Regions"
  slug <- if (geography == "Country") "country" else "region"
  p <- ggplot(d, aes(x = beta, y = outcome_label, color = outcome_label)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey65") +
    geom_segment(aes(x = ci_low, xend = ci_high, yend = outcome_label),
                 linewidth = 1.2) +
    geom_point(size = 3.4) +
    scale_color_manual(values = outcome_colors, guide = "none") +
    labs(title = paste(label, "— religious expression and well-being"),
         subtitle = paste("Within-place regression coefficients,", model1_window),
         x = "Standardized coefficient and 95% confidence interval", y = NULL,
         caption = "Place and year fixed effects; country trends; country-clustered SE") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.major.y = element_blank(),
          plot.title = element_text(face = "bold"))
  ggsave(file.path(output_dir, paste0("model1_", slug, ".png")), p,
         width = 9, height = 4.4, dpi = 180)
}

sem <- fread(file.path("results", "community_sem", "sem_paths.csv"))
pathway_settings <- fread(file.path("results", "community_pathway", "settings.csv"))
model2_window <- sprintf("%s-%s", setting(pathway_settings, "start_year"),
                         setting(pathway_settings, "end_year"))

for (geography in c("Country", "NUTS1")) {
  d <- sem[level == geography]
  if (nrow(d) != 13L) stop("Expected thirteen SEM paths for ", geography)
  a <- d[lhs == "community_next" & rhs == "religion_composite_z"]
  b <- d[rhs == "community_next"]
  direct <- d[lhs %in% paste0(outcomes, "_future") &
                rhs == "religion_composite_z"]
  indirect <- d[lhs %in% c("indirect_h", "indirect_l", "indirect_p")]
  a <- rbindlist(lapply(outcomes, function(y) copy(a)[, outcome := y]), fill = TRUE)
  b[, outcome := path_outcome(lhs)]
  direct[, outcome := path_outcome(lhs)]
  indirect[, outcome := derived_outcome(lhs)]
  a[, path := "a: Religion t → social t+1"]
  b[, path := "b: Social t+1 → outcome t+2"]
  direct[, path := "c′: Conditional religion–outcome"]
  indirect[, path := "a×b: Descriptive product"]
  plot_data <- rbindlist(list(a, b, direct, indirect), fill = TRUE)
  if (nrow(plot_data) != 12L) stop("Expected twelve plotted paths for ", geography)
  plot_data[, `:=`(
    outcome_label = label_outcome(outcome),
    path = factor(path, levels = c("a: Religion t → social t+1",
                                 "b: Social t+1 → outcome t+2",
                                 "c′: Conditional religion–outcome",
                                 "a×b: Descriptive product"))
  )]
  label <- if (geography == "Country") "Countries" else "Regions"
  slug <- if (geography == "Country") "country" else "region"
  p <- ggplot(plot_data, aes(x = estimate, y = path, color = path)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey65") +
    geom_segment(aes(x = ci.lower, xend = ci.upper, yend = path), linewidth = 1.1) +
    geom_point(size = 2.8) +
    facet_wrap(~outcome_label, nrow = 1) +
    scale_color_manual(values = c("#2364AA", "#15916D", "#8052A2", "#B35316"),
                       guide = "none") +
    labs(title = paste(label, "— longitudinal SEM paths"),
         subtitle = paste("Observed-variable model,", model2_window),
         x = "Standardized coefficient and approximate 95% confidence interval",
         y = NULL,
         caption = "Country-clustered robust SE. The product a×b describes a statistical pathway.") +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major.y = element_blank(),
          strip.text = element_text(face = "bold"),
          plot.title = element_text(face = "bold"))
  ggsave(file.path(output_dir, paste0("model2_sem_", slug, ".png")), p,
         width = 15, height = 6.6, dpi = 180)
}

static_settings <- fread(file.path("results", "regional_static", "settings.csv"))
static_window <- sprintf("%s-%s", setting(static_settings, "start_year"),
                         setting(static_settings, "end_year"))
static_association <- fread(file.path("results", "regional_static", "association.csv"))
static_association <- static_association[window == static_window]
if (nrow(static_association) != 3L)
  stop("Expected three static regional association estimates.")
static_association[, outcome_label :=
                     label_outcome(outcome)]
p <- ggplot(static_association,
            aes(x = beta, y = outcome_label, color = outcome_label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey65") +
  geom_segment(aes(x = ci_low, xend = ci_high, yend = outcome_label),
               linewidth = 1.2) +
  geom_point(size = 3.4) +
  scale_color_manual(values = outcome_colors, guide = "none") +
  labs(title = "Regions — long-run mean associations",
       subtitle = paste("Within-country differences across regions,", static_window),
       x = "Standardized coefficient and 95% confidence interval", y = NULL,
       caption = "Country fixed effects; equal country weight; country-clustered SE") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold"))
ggsave(file.path(output_dir, "static_region_association.png"), p,
       width = 9, height = 4.4, dpi = 180)

static_sem <- fread(file.path("results", "regional_static", "sem_paths.csv"))
static_sem <- static_sem[window == static_window]
if (nrow(static_sem) != 13L) stop("Expected thirteen static SEM paths.")
a <- static_sem[lhs == "social_z" & rhs == "religion_z"]
b <- static_sem[rhs == "social_z"]
direct <- static_sem[lhs %in% paste0(outcomes, "_z") & rhs == "religion_z"]
indirect <- static_sem[lhs %in% c("indirect_h", "indirect_l", "indirect_p")]
a <- rbindlist(lapply(outcomes, function(y) copy(a)[, outcome := y]), fill = TRUE)
b[, outcome := path_outcome(lhs)]
direct[, outcome := path_outcome(lhs)]
indirect[, outcome := derived_outcome(lhs)]
a[, path := "a: Religion mean → social mean"]
b[, path := "b: Social mean → well-being mean"]
direct[, path := "c′: Conditional religion mean"]
indirect[, path := "a×b: Descriptive product"]
static_plot <- rbindlist(list(a, b, direct, indirect), fill = TRUE)
static_plot[, outcome_label := label_outcome(outcome)]
static_plot[, path := factor(path, levels = c("a: Religion mean → social mean",
                                            "b: Social mean → well-being mean",
                                            "c′: Conditional religion mean",
                                            "a×b: Descriptive product"))]
p <- ggplot(static_plot, aes(x = estimate, y = path, color = path)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey65") +
  geom_segment(aes(x = ci.lower, xend = ci.upper, yend = path), linewidth = 1.1) +
  geom_point(size = 2.8) +
  facet_wrap(~outcome_label, nrow = 1) +
  scale_color_manual(values = c("#2364AA", "#15916D", "#8052A2", "#B35316"),
                     guide = "none") +
  labs(title = "Regions — static SEM paths",
       subtitle = paste("Associations among regional period means,", static_window),
       x = "Standardized coefficient and approximate 95% confidence interval",
       y = NULL,
       caption = "Country-clustered SE. No time ordering; a×b is a descriptive product.") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank(),
        strip.text = element_text(face = "bold"),
        plot.title = element_text(face = "bold"))
ggsave(file.path(output_dir, "static_region_sem.png"), p,
       width = 15, height = 6.6, dpi = 180)
