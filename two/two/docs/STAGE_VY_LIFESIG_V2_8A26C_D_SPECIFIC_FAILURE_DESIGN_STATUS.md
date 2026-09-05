# V2.8-A26c D-Specific Failure Scenario Design Status

## Status

`D_SPECIFIC_FAILURE_SCENARIO_DESIGN_PASS`

- Offline only; new MATLAB/Simulink/CarSim physics runtime count: `0`.
- D-only input candidate: estimator-side steering calibration scale; K-KF does not consume steering.
- Replay: PASS; A26b saved-config maxDiff `1.62109e-10`, nominal A-phase maxDiff `1.76064e-11`.
- Tested B scales: `0.5`, `0`, `-1`; no grid search and no Proposed-RMSE selection.
- D/K B RMSE ratios: `0.288652`, `0.568945`, `1.212140`.
- Selected: polarity inversion, `scale=-1`, the first tested severity meeting `D/K >= 1.2`.
- Selected D/K B RMSE: `0.357143/0.294638 m/s`.
- Selected normalized-NIS B mean: `2.81743` versus nominal `0.0376011`; `G_D` mean/min `0.0495978/0.0208602`.
- Numerical status: PASS; update-valid `100%`, no NaN/Inf, K data unchanged.
- Frozen next scenario: plant `mu=0.8`; `0.02 rad/0.4 Hz` sine throughout; A/B/C `[0,5)/[5,22.5)/[22.5,40.5] s`; D steering scale `1/-1/1`.
- `READY_FOR_FINAL_D_ONLY_RUNTIME = YES`.

