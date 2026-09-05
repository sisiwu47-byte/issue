# V2.8-A26 D-only degradation/recovery formal validation status

## Verdict

`D_ONLY_UNIFIED_HEALTH_VALIDATION_FAIL`

`A26_RUNTIME_DATA_RECOVERABLE=YES`  
`ALGORITHM_INTEGRITY=PASS`  
`RUNTIME_COUNT=1`  
`READY_FOR_FINAL_K_REGRESSION=NO`

## Fixed experiment and evidence

- A/B/C: `[0,5) / [5,22.5) / [22.5,40.5] s`; D-EKF `par.k_f=0.78181/1.0/0.78181`; plant `mu=0.8`; continuous `0.02 rad, 0.4 Hz` sine.
- Offline D replay maximum difference: `7.196673812437382e-11 m/s`; update-valid fraction `1`; no new runtime.
- The forensic `tireForceLocal.m` change only removed stray `> ` before `end`; no coefficient/formula/branch or algorithm source changed. The exact replay retains the phase-A-only helper-resolution startup artifact documented in `evidence_lineage.md`.

## Formal results

| item | result |
|---|---:|
| B D RMSE | `0.0500141 m/s` |
| B K RMSE | `0.294638 m/s` |
| B Original / Proposed RMSE | `0.0702874 / 0.0746755 m/s` |
| RMSE / MAE reduction | `-6.24294% / -5.60266%` |
| B `G_D` / `G_K` minimum | `0.609731 / 0.934769` |
| D-health response time | `1.68 s` from B start |
| alpha-D frozen 10% response | `NOT_REACHED` |
| C recovery | `NOT_ESTABLISHED`; qualifying D-only degradation/alpha-D response absent |

B does not exceed both nominal A and C D RMSE, so the preregistered D-only degradation condition fails. K remains at its same-condition healthy level, and the D-aware K check passes without false K suppression; however Proposed worsens both RMSE and MAE versus Original. Numerical integrity passes (`NaN/Inf=0` for required signals, alpha-sum max error `2.2204e-16`, fallback `0`).

## Outputs

- Metrics: `phase_metrics.csv`, `d_degradation_response_metrics.csv`, `d_recovery_metrics.csv`, `unified_health_metrics.csv`.
- Figures: three logical figures, each PNG 600 dpi plus vector PDF/SVG.
- Source: `generate_a26_thesis_figures.py`; reproduction: `figure_reproduction_manifest.md`.
