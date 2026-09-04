# V2.8-A28 final K-degradation unified-health regression status

## Verdict

`FINAL_K_UNIFIED_REGRESSION_PASS`

- `REPLAY_STATUS = PASS`; maximum saved-output/final-health replay difference: `7.1054273576010019e-15`.
- `NEW_RUNTIME_COUNT = 0`; all results are offline derivatives of frozen A17d/A22/A27 evidence.
- Frozen A/B/C windows remain `[0,5) / [5,22.5) / [22.5,40.5] s`.
- Final A25/A27 unified-health formula and every parameter remain unchanged.

## B-phase K degradation and health response

- D RMSE: `0.00518821674265658 m/s`; K RMSE: `1.07478145385687 m/s`.
- `G_D`: min/mean `1 / 1` (`HEALTHY_HIGH`).
- `d_DK` first/last B-quarter mean: `0.412878928621222 / 1.55181052629704 m/s`.
- `I_K` B maximum: `2.44123611905169`; `G_K` minimum: `2.49946030962010e-11`.
- `alpha_K` minimum: `4.31854476149353e-12`; `alpha_K <= 0.05` response: `3.40 s` after B starts.
- `K_HEALTH_REGRESSION = PASS`: final D-health leaves the original K attribution and protection behavior unchanged to numerical precision.

## Fusion performance and recovery

- Original / Final Unified B RMSE: `0.168533016977009 / 0.0266177643928039 m/s`.
- B RMSE / MAE reduction: `84.2062% / 85.9351%`.
- C recovery: `PASS`; decreasing `d_DK/I_K`, increasing `G_K/alpha_K`, `G_K>=0.95` sustained after `14.34 s`, and `alpha_K>=95%` baseline sustained after `13.80 s`.
- Numerical integrity: `PASS`; maximum alpha-sum error `2.22044604925031e-16`, no fallback, no NaN/Inf.

## Final symmetric evidence

- `final_dk_degradation_summary.csv` contains the final K-degradation A17d/A28 and D-degradation A27 cases.
- Three final K figures exist in PNG 600 dpi plus PDF/SVG vector formats; reproduction check `PASS`.
- Plotting source: `results/vy_lifesig_v2_8a28_final_k_unified_regression/generate_a28_thesis_figures.py`
- Plotting source SHA-256: `DEE14D3D2EC3C86E52F9C4DDF56EA4786B44F99C8DDC0579E8F4EA07ED10AEAC`

`FINAL_DK_DEGRADATION_VALIDATION_CLOSED = YES`
