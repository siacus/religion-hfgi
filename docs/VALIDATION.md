# Replication validation

The complete workflow was rerun on 21 November 2026 from the single released
`data/model_data.csv`, including the USA. It uses no upstream HFGI archive.
All reported models, including both supplementary latent specifications, were
re-estimated, and all six coefficient figures and formatted outputs regenerated.

- All 91 checked numeric fields match the manuscript reference outputs.
- Maximum scaled discrepancy: 2.71e-08; tolerance: 1e-6.
- Observation and cluster counts agree exactly.
- All 66 estimate/interval triples in the seven numeric main tables match the
  updated LaTeX source at displayed precision.
- All 27 coefficient labels in the three estimated path diagrams agree.
- All three observed-variable SEMs converge to admissible solutions with
  positive-definite robust parameter covariance matrices.
- The latent diagnostic retains three negative variances in the unconstrained
  fit and three boundary variances in the bounded fit; its paths are not interpreted.

See `reference/replication_verification.csv` and
`reference/replication_sessionInfo.txt`. Fresh outputs are written under
`results/`; the reference values are verification targets, never fitted inputs.

## Geographic coverage

All 61 countries and 1,004 regional units match the boundary layers. Coverage
is 602 country-years and 8,350 region-years. All 50 US states and District of
Columbia contribute ten eligible years. The 21 historical boundary-name
reconciliations remain documented in the crosswalk. The 450-dpi PNG was
visually inspected for coverage, labels, colour scale and layout. Tiny
administrative units may be difficult to distinguish at the global map scale.

No manuscript compilation or PDF inspection was performed.
