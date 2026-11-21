# Replication validation

The full workflow was run successfully on 18 November 2026 using the single
released `data/model_data.csv`, without access to the upstream HFGI files.
All reported models, including both supplementary latent specifications, were
re-estimated. The six coefficient figures and the formatted outputs were generated.

- All 91 checked numeric fields match the manuscript reference outputs.
- Maximum scaled discrepancy: 2.41e-08; tolerance: 1e-6.
- Observation and cluster counts are checked for exact agreement.
- The 66 estimate/interval triples in the seven numerical main tables were
  independently compared with the current LaTeX source at displayed precision.
- The three observed-variable SEMs converged to admissible solutions with
  positive-definite robust parameter covariance matrices.
- The latent diagnostic reproduces its negative-variance and boundary findings;
  it is not treated as an interpretable substantive model.

See `reference/replication_verification.csv` for the recorded checks and
`reference/replication_sessionInfo.txt` for the environment. Every new run creates
fresh files under `results/`; reference outputs are never used as fitted values.

No manuscript PDF was compiled or inspected. Figure verification concerns the
underlying estimates and successful generation, not pixel-identical rendering.

## Geographic coverage figure, 21 November 2026

The map script was run against the released CSV and the project's boundary
layers. All 60 national and 953 regional units were matched. Coverage totals
(592 country-years and 7,840 region-years) also agree country by country with
the manuscript's independently documented coverage. The 21 boundary-name
reconciliations are recorded explicitly in the published crosswalk. The final
450-dpi PNG was visually inspected for map coverage, labels, colour scale and
layout. No statistical model was changed or rerun for this addition.
