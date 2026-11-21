# Religion, connectedness, and well-being

Replication materials for **Religious expression and well-being across countries and regions: Evidence from a decade of social media posts**, by Stefano M. Iacus, Giuseppe Porro, and Haodong Qi.

This repository accompanies the manuscript version of **21 November 2026**. It reproduces the reported analyses for **2013–2022** from one CSV containing the model variables. It includes the national and regional annual associations, longitudinal connectedness pathways, regional period-average analyses, country-by-year sensitivity checks, outcome contrasts, attempted latent-model diagnostics, and coefficient figures.

## Quick start

Requirements: **R 4.5.2 or a compatible R version**, Python 3 (standard library only), and the R packages `data.table`, `fixest`, `lavaan`, and `ggplot2`. The versions used for verification are recorded in [the software manifest](software_versions.csv). No API credentials, Dropbox files, raw posts, database access, or LaTeX installation are needed.

```sh
git clone https://github.com/siacus/religion-hfgi.git
cd religion-hfgi
Rscript install_dependencies.R
Rscript reproduce.R
```

The dependency installer installs missing packages; it does not pin or replace existing versions. To match the reference environment, use the versions in the software manifest. The reproduction command fits the models, checks the numerical outputs against the manuscript reference estimates, rebuilds the six coefficient figures, and exports Tables 1–8, Supplementary Table S1, and the TikZ diagram fragments. It does not compile LaTeX or generate a manuscript PDF.

Generated files go to `results/`, which is ignored by Git. A successful run ends with `Replication complete`. See `results/verification.csv` for the numerical comparison and `results/sessionInfo.txt` for the execution environment. Estimates and confidence intervals are checked at a scaled tolerance of `1e-6`; observation counts must match exactly. Rendering may differ across operating systems and fonts.

## What is in the released data?

**[data/model_data.csv](data/model_data.csv)** is the only input dataset. It contains geographic and temporal identifiers and the five variables used in the reported observed-variable models:

- religious expression;
- social connectedness;
- happiness;
- life satisfaction;
- purpose in life.

The data are already cleaned and prepared at the indicator level. They contain no post text or user identifiers. Eight component indicators are included only in the additional `latent_diagnostic` block, where they are necessary to reproduce the attempted latent SEM in the Supplementary material. The full HFGI dataset is intended for a separate release. This package starts from the model variables and reproduces the statistical analysis; it does not reproduce language classification or reconstruct the component indices from raw data.

The CSV contains four **analysis blocks**, identified by `analysis`. Each block has its own documented preparation because the models use different weighting and standardization. **Do not pool the blocks or treat repeated geographic identifiers across them as independent observations.**

| Analysis block | Geography | Rows in CSV | Final model sample |
|---|---|---:|---|
| `annual_association` | Country | 592 | 592 country-years, 60 countries |
| `annual_association` | NUTS1 | 7,840 | 7,840 region-years, 953 regions, 59 countries |
| `longitudinal_pathway` | Country | 592 | 460 eligible baseline years, 60 countries |
| `longitudinal_pathway` | NUTS1 | 7,840 | 4,714 eligible baseline years, 796 regions, 59 countries |
| `regional_averages` | NUTS1 | 682 | 682 regions, 42 countries |
| `latent_diagnostic` | NUTS1 | 4,714 | 4,714 baseline region-years, 796 regions, 59 countries |

`NUTS1` is the historical label in the analysis files for **first-level administrative regions worldwide**; it does not imply that every unit belongs to the European NUTS system. The longitudinal blocks contain annual observations before matching `t`, `t+1`, and `t+2`. The period-average block represents 2013–2022, so its `year` field is intentionally missing.

See **[From model variables to estimates](docs/VARIABLES_AND_METHODS.md)** for the full data dictionary, the construction of the released indicators, all standardization conventions, weights, lag construction, and model specifications.

## Geographic coverage maps

The geographic coverage figure added on 21 November 2026 is reproduced by
`coverage_maps.R`. It maps eligible years in the same `annual_association`
block used by the statistical analyses; no model is refitted.

```sh
Rscript install_dependencies.R --maps
Rscript coverage_maps.R --data data/model_data.csv --spatial-dir /path/to/boundaries --output-dir results/coverage_maps
```

Map rendering additionally requires the project's administrative boundary
layers (`adm0.shp` and `adm1_simplify.shp`, including companion files).
These external geometry files are not bundled with this release. Their hashes,
matching rules and the verified country/region crosswalk are documented in
[Geographic coverage maps](docs/COVERAGE_MAPS.md). The statistical replication
pipeline remains self-contained from `data/model_data.csv` and does not require
these geometry files. The final PNG and coverage checks are included in
`reference/coverage_maps/`.

## Execution sequence

`reproduce.R` runs these stages, each in a separate R process:

1. `prepare_data.R`: reads the annual-association block and creates analysis panels and settings.
2. `annual_associations.R`: fits the national and regional associations with place and year effects and country-specific linear trends.
3. `community_sem.R`: constructs consecutive-year samples from the longitudinal blocks, removes the specified effects and trends, and estimates the national and regional observed-variable SEMs.
4. `regional_static.R`: uses the regional-average block to fit the within-country association regressions and the complementary static SEM.
5. `latent_multilevel_sem.R`: fits both attempted latent specifications and reproduces their diagnostic results.
6. `country_year_robustness.R`: replaces common year effects and national trends with country-by-year effects; repeats outcome contrasts and the informative-country sensitivity.
7. `outcome_contrasts.R`: estimates the six direct comparisons of the purpose slope with the other two outcome slopes.
8. `report_figures.R`: rebuilds the six coefficient figures from the estimated results.
9. `verify_results.R`: compares numerical results with the frozen reference outputs.
10. `export_paper_outputs.py`: formats Tables 1–8 and updates the coefficient labels in the path diagrams.

`model_data.R` provides the data reader and longitudinal input mapping; `observed_sem_diagnostics.R` computes SEM diagnostic checks. All paths are relative to this repository. [The manuscript crosswalk](docs/MANUSCRIPT_CROSSWALK.md) maps each table, figure, and hypothesis to its code and output.

## Reference results and provenance

`reference/` contains frozen numerical outputs supporting the manuscript. These files are **verification targets**, not substitutes for estimating the reported models. This includes `reference/latent_multilevel_sem/diagnostics.csv`: both latent specifications are re-estimated, although their path coefficients are not substantively interpreted in the paper.

`templates/` contains only manuscript figure fragments needed to reproduce the conceptual diagrams and estimated path diagrams. The full manuscript, editorial notes, correspondence, historical drafts, bootstrap experiments, and unrelated exploratory analyses are not included.

[provenance.json](provenance.json) identifies the source manuscript snapshot and the data/reference hashes. The manuscript has no assigned publication DOI in this package. The HFGI framework is described in [Iacus et al. (2026), Scientific Data](https://doi.org/10.1038/s41597-026-07803-1); that descriptor concerns US counties and is not a release identifier for this international analysis file.

## Citation

Please cite the accompanying paper and identify the version or commit of this replication repository. Machine-readable citation metadata are provided in [CITATION.cff](CITATION.cff).
