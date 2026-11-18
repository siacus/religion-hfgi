# From model variables to estimates

## 1. Scope and unit of observation

`data/model_data.csv` contains **22,260 rows** distributed across six analysis/geography blocks. A row is either a country-year, a region-year, or a regional average over 2013–2022. The same place-year can occur in both an annual-association block and a longitudinal block because their indicator scaling differs. These are alternate model inputs, not additional independent observations.

The release starts **after geographic cleaning, quality filtering, and construction of the composite indicators**. Upstream post-level data are not included. Component indicators are restricted to the model inputs required for the supplementary latent diagnostic; the full component series are not released. The construction rules are documented below to explain the supplied values; the executable scripts take those final model variables as inputs. This boundary preserves the separate planned release of the full dataset.

## 2. Data dictionary

| Column | Meaning |
|---|---|
| `analysis` | `annual_association`, `longitudinal_pathway`, `regional_averages`, or `latent_diagnostic`; selects the model-specific preparation. |
| `geographic_level` | `Country` or `NUTS1` (first-level administrative regions worldwide). |
| `country` | Two-letter country code; clustering and country-weighting identifier. |
| `unit` | Unique place identifier. Countries use their country code; regions combine country, regional identifier, and regional name. Treat as an opaque identifier. |
| `year` | Calendar year, 2013–2022; `NA` for the 2013–2022 period-average block. |
| `religious_expression` | Composite religious-expression index, with scaling specific to the analysis block below. |
| `connectedness` | Composite social-connectedness index. Intentionally `NA` in the annual-association block because those regressions do not use it. |
| `happiness` | Expressed happiness indicator. |
| `life_satisfaction` | Expressed life-satisfaction indicator; called `lifesat` inside the R analysis code. |
| `purpose` | Expressed purpose-in-life indicator. |
| `belief_afterlife`, `belief_god`, `loved_by_god`, `religious_comfort` | Standardized religious-expression components at baseline t, supplied only for the latent diagnostic. |
| `belonging`, `reversed_loneliness`, `trust`, `trusted` | Standardized connectedness components at t+1, supplied only for the latent diagnostic. |
| `n_years` | Number of complete annual observations used for each regional average (8–10); `NA` in annual blocks. |

Missing values are encoded as `NA`. The unique row key is `(analysis, geographic_level, unit, year)` for annual blocks and `(analysis, unit)` for regional averages. All five model variables in the longitudinal and regional-average blocks are complete. The intentionally empty connectedness column in the annual-association block must not be used to drop rows. In the latent block, religious_expression and connectedness are intentionally empty because latent factors replace the composite indices. Its happiness, life_satisfaction and purpose columns hold outcomes at t+2, while year denotes baseline t. The eight component columns are intentionally empty in all other blocks. Missingness is therefore structural by analysis, not a reason for listwise deletion across the entire CSV.

## 3. Cleaning and eligibility applied before release

All input preparation is restricted to 2013–2022; incomplete 2023 observations are excluded, including from the computation of scaling parameters. Geographic identifiers must be valid. The original dimension scores must be finite and within their admissible [-1, 1] range; expression shares must be in [0, 1]. Each place-year must have at least 1,000 posts, and each required dimension must have at least 30 contributing posts, approximated by `round(expression_share * total_posts)`.

Duplicate place-year-dimension records were resolved before forming the indicators. Religion and outcome records prefer a named-country record and then the largest post denominator; connectedness records retain the eligible record with the largest denominator. No interpolation or imputation fills missing scores.

Annual association and initial longitudinal panels require at least four eligible years per place. Static regional averages require at least eight complete annual observations and at least two eligible regions in each country. Model-specific sample rules are applied separately; do not interpret the larger initial longitudinal blocks as the final SEM sample.

## 4. Indicator construction and scaling

### Religious expression and connectedness

Religious expression combines belief in an afterlife, belief in God, feeling loved by God, and comfort derived from religion, with equal item weights. Connectedness combines societal belonging, loneliness reversed in direction, trust in others, and feeling trusted, also with equal item weights. The reversal ensures that greater connectedness always has the same direction. These composites describe the valence of expressed experiences, not religious affiliation shares or representative population averages.

The outcome indicators are happiness, life satisfaction, and purpose in life. They are retained separately throughout; no overall well-being composite is estimated.

### Annual-association block

The supplied religious-expression variable is the mean of the four item z scores. Each religion item was initially standardized separately at each geographic level over the quality-filtered 2013–2022 preparation panel, using its available observations, the ordinary arithmetic mean, and the sample standard deviation. A composite requires all four items. The released annual block then retains complete religious-expression and outcome observations and the minimum-year eligibility rule. The three supplied outcome variables are unstandardized expression scores.

At estimation, `annual_associations.R` standardizes the supplied composite and each outcome **within the relevant estimation sample**, using the arithmetic mean and sample standard deviation (`scale()` in R). Observations receive equal weight. Thus a coefficient compares changes in standard-deviation units; no component indicators are needed to reproduce it.

### Longitudinal-pathway block

These supplied variables are **already standardized** over the complete annual pathway panel, before creating the lagged sample. Each country receives equal total weight across its eligible observations: for an observation in country c, w = 1 / N_c. Weighted standardization uses

`z = (x - weighted_mean(x, w)) / sqrt(weighted_mean((x - weighted_mean(x, w))^2, w))`.

This is a weighted population-moment standard deviation, not the sample standard deviation used in the annual regressions. The religious-expression composite and each outcome were standardized using these weights. For connectedness, loneliness was reversed, each of the four components was standardized with these weights, the four standardized components were averaged equally, and the average was standardized again. The released connectedness variable is that final index.

**Do not standardize this block again.** `community_sem.R` uses the supplied values, constructs lags, and computes a new set of equal-country estimation weights on the final lagged sample. This change of estimation weights does not redefine the supplied variables.

### Regional-average block

Before release, complete annual component and outcome scores were averaged within each region over 2013–2022. Every eligible year received equal weight. Only regions with at least eight complete years and countries with at least two eligible regions were retained.

The item period means were standardized with country-balanced weights `w = 1 / number_of_eligible_regions_in_country`. Loneliness was reversed. The religious-expression and connectedness indices were each formed by averaging their four standardized item means and then standardized again with the same weights. Outcome period means were also standardized with these weights. The CSV contains these **final standardized regional indices and outcomes**, not the components or their raw means.

The static variables cannot in general be obtained by simply averaging the supplied longitudinal indices: averaging, item standardization, sample selection and weighting are performed in a different order. For this reason, the release includes the regional-average model inputs as a separate block in the same CSV. `regional_static.R` uses them directly without further standardization.

## 5. Models and sample construction

### National and regional annual associations: H1 and H1-Reg

The outcome is regressed on religious expression with place and year fixed effects and country-specific linear time trends. National models use country effects; regional models use region effects. Standard errors are clustered by country, with the `fixest` default finite-sample adjustment and confidence-interval convention. Country-by-year sensitivity replaces the common year effects and national trends with country-by-year effects, holding the sample and scaling fixed.

The informative-country sensitivity retains the original scaling and excludes countries with no residual religious-expression variation under country-by-year effects. Its sample contains 7,797 region-years, 946 regions and 53 countries. It is reported as a sensitivity in the Supplementary material.

### Longitudinal connectedness pathways: H2 and H2-Reg

For each unit, the scripts match religious expression at t to connectedness at t+1 and each outcome at t+2, using calendar-year joins. A gap cannot be treated as a consecutive observation. Every unit must contribute at least three eligible baseline years. Baseline connectedness and all three baseline outcomes enter both the connectedness and outcome equations. This yields 460 country baseline-years and 4,714 region baseline-years.

Before fitting, each modeled variable is regressed on place and year effects and country-specific linear trends using equal-country estimation weights. The residuals enter the SEM without additional standardization. The SEM uses robust maximum likelihood with country-clustered uncertainty, an explicit mean structure, and zero intercepts for the connectedness equation and the three outcome equations. The three outcome residuals may covary.

The reported paths are a (religious expression to connectedness), b_k (connectedness to outcome), c'_k (religious expression conditional on connectedness), a*b_k (indirect association), and c_k = c'_k + a*b_k (total association). Intervals use robust standard errors and a normal approximation; derived-path uncertainty uses the delta method.

### Regional averages: H3 and complementary static SEM

Regress the supplied standardized outcome averages on religious expression with country fixed effects and equal total country weight; cluster standard errors by country. For the static SEM, remove weighted country means first, then fit connectedness and the three outcome equations. The zero-intercept and covariance conventions match the longitudinal SEM. Its coefficients describe same-period regional differences. The regression slope equals the SEM total-association point estimate; the interval calculations differ.

### Outcome contrasts: H4

For each design, regress `purpose - happiness` and `purpose - life_satisfaction` on religious expression using the same standardized outcomes, sample, controls and weights as the corresponding association model. These are comparisons of association slopes, not indirect SEM paths. The six primary comparisons are exploratory, with country-clustered intervals and no multiple-testing adjustment. The country-by-year specification provides two additional regional sensitivity contrasts.

### Attempted latent multilevel SEM: Supplementary material

The `latent_diagnostic` block contains the 4,714 eligible baseline region-years. Its four religious-expression components refer to t, the four social components to t+1, and the three outcome columns to t+2. Before release, each component was standardized on the complete annual pathway panel using the same equal-country weights as the longitudinal model; loneliness was reversed before standardization. The columns are not yet residualized.

`latent_multilevel_sem.R` removes country and year effects and country-specific linear trends from each supplied measurement, using country-balanced weights computed on this lagged sample. Unlike the observed regional SEM, this diagnostic removes country effects, not region effects. It then fits the within-region and between-region latent measurement and structural equations, clustering by region. Baseline outcome and connectedness controls are omitted, as in the paper's diagnostic specification.

Both the unconstrained model and the version with nonnegative observed residual-variance bounds are estimated. The first has three negative residual variances; the second has three variances at the boundary and weak global fit. The scripts reproduce these diagnostic results and Supplementary Table S1; they do not interpret the latent path coefficients. This block is included for complete methodological transparency without releasing unrelated component series.
