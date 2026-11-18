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
