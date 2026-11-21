# Manuscript-to-code crosswalk

This mapping refers to the manuscript snapshot of 18 November 2026, identified by SHA-256 in `provenance.json`. All model outputs are regenerated from `data/model_data.csv`; conceptual diagrams and layout fragments are supplied as templates. The manuscript itself and its editorial front matter are not distributed here.

## Main tables

| Paper item | Question | Estimation script | Numerical output under `results/` | Formatted export under `results/paper_outputs/` |
|---|---|---|---|---|
| Table 1 (`tab:annual`) | H1, H1-Reg | `annual_associations.R` | `paper_checks/temporal_robustness.csv` | `table_1_annual.csv`, `.md` |
| Table 2 (`tab:country-sem`) | H2 | `community_sem.R` | `community_sem/sem_paths.csv`, Country rows | `table_2_country_sem.csv`, `.md` |
| Table 3 (`tab:region-sem`) | H2-Reg | `community_sem.R` | `community_sem/sem_paths.csv`, NUTS1 rows | `table_3_region_sem.csv`, `.md` |
| Table 4 (`tab:country-year-robustness`) | H1-Reg sensitivity | `country_year_robustness.R` | `country_year_robustness/coefficients.csv`, outcome_specific rows | `table_4_country_year.csv`, `.md` |
| Table 5 (`tab:static`) | H3 | `regional_static.R` | `regional_static/association.csv` | `table_5_regional_averages.csv`, `.md` |
| Table 6 (`tab:static-sem`) | Complementary H3 decomposition | `regional_static.R` | `regional_static/sem_paths.csv` | `table_6_static_sem.csv`, `.md` |
| Table 7 (`tab:contrasts`) | H4 | `outcome_contrasts.R` | `paper_checks/outcome_contrasts.csv` | `table_7_contrasts.csv`, `.md` |
| Table 8 (`tab:hypothesis-summary`) | Interpretation of H1–H4 | `export_paper_outputs.py` | Derived from the verified association/path/contrast intervals | `table_8_hypotheses.csv`, `.md` |
| Table S1 (`tab:latent`) | Latent-model diagnostics | `latent_multilevel_sem.R` | `latent_multilevel_sem/diagnostics.csv` | `table_S1_latent_diagnostics.csv`, `.md` |

The hypothesis summary is an interpretation, not another fitted model. “No” for H2-Reg means that the predicted indirect association is not established; it does not establish absence. H4 comparisons are exploratory and unadjusted for multiple testing.

## Figures

| Paper item | Contents | Reproduction |
|---|---|---|
| Figure 1 (`fig:coverage`) | National and regional coverage, coloured by eligible years | `coverage_maps.R` → `results/coverage_maps/geographic_coverage.png`; requires external boundary layers (see `docs/COVERAGE_MAPS.md`) |
| Figure 2 (`fig:dag`) | Proposed connectedness pathway | `templates/dag.tex` copied to `results/paper_outputs/` |
| Figure 3 (`fig:estimation-strategy`) | Estimation sequence | `templates/estimation-strategy.tex` copied to `results/paper_outputs/` |
| Figure S1 | National association and SEM coefficient panels | `report_figures.R` → `results/report_figures/model1_country.png`, `model2_sem_country.png` |
| Figure S2 | National estimated paths | `export_paper_outputs.py` → `results/paper_outputs/country-paths.tex` |
| Figure S3 | Regional association and SEM coefficient panels | `report_figures.R` → `results/report_figures/model1_region.png`, `model2_sem_region.png` |
| Figure S4 | Regional estimated paths | `export_paper_outputs.py` → `results/paper_outputs/region-paths.tex` |
| Figure S5 | Regional-average association and SEM coefficient panels | `report_figures.R` → `results/report_figures/static_region_association.png`, `static_region_sem.png` |
| Figure S6 | Regional-average estimated paths | `export_paper_outputs.py` → `results/paper_outputs/static-paths.tex` |
| Figure S7 | Attempted latent specification | `templates/latent-specification.tex` copied to `results/paper_outputs/` |

The six coefficient PNG files are generated directly from fitted estimates. The TikZ path labels are updated from the freshly fitted SEM results. Diagram fragments retain the manuscript's cross-reference labels; they are intended to be included in the manuscript context, not compiled as standalone documents. No PDF compilation is part of this workflow.

## Additional numerical statements in the text

- Equal-country weighting, lag construction, eligibility rules and sample sizes are documented in `docs/VARIABLES_AND_METHODS.md` and executed in the corresponding model scripts.
- The observed-SEM admissibility checks and positive-definite parameter covariance results are saved in `community_sem/sem_fit.csv` and `regional_static/sem_fit.csv`.
- Retained residual variation, singleton country-year cells and informative countries are recorded in `country_year_robustness/diagnostics.csv`.
- The informative-country sensitivity is in `country_year_robustness/coefficients.csv`, selecting `sample == informative_countries`.
- The two additional H4 contrasts under country-by-year effects are in `country_year_robustness/outcome_contrasts.csv`.
- Negative and boundary latent variances are recorded in `latent_multilevel_sem/negative_variances.csv` and `boundary_variances.csv`.

No bootstrap, historical period comparison, religious-affiliation moderation, random-slope exploratory model, or alternative unpublished analysis is run or included.
