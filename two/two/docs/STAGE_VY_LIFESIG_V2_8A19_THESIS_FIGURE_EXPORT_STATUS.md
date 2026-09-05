# V2.8-A19 K-health thesis figure generation and export

## Final verdict

`K_HEALTH_THESIS_FIGURE_EXPORT_PASS`

- `OFFLINE_PLOTTING_ONLY = YES`
- `FINAL_THESIS_FIGURE_COUNT = 3`
- `A19_RUNTIME_COUNT = 0`
- `A17d_FORMAL_RUNTIME_COUNT_REMAINS = 1`
- `DATA_SOURCE = A17d full_timeseries.csv + A18 frozen tables/manifests`
- `DATA_MODIFICATION = NO`
- `PARAMETER_RETUNING = NO`
- `ALGORITHM_MODIFICATION = NO`
- `MODEL_MODIFICATION = NO`
- `THESIS_FIGURE_SET_READY = YES`

## Generated core figures

1. `Fig1_KKF_low_yaw_degradation`: K-KF low-yaw degradation mechanism; 2 subplots, `1 + 3` curves.
2. `Fig2_K_health_dynamics`: disagreement -> cumulative degradation -> health factor -> fusion-weight adaptation; 4 subplots, `2 + 1 + 1 + 3` curves.
3. `Fig3_Vy_original_vs_proposed`: Original/Proposed fusion-output and signed-error comparison; 2 subplots, `3 + 2` curves.

Each figure is exported as 600 dpi PNG plus vector PDF and SVG under `results/vy_lifesig_v2_8a19_thesis_figures/`.

## Static and visual acceptance

- All nine requested PNG/PDF/SVG outputs exist and are non-empty.
- PNG dimensions are `4134 x 3543`, `4134 x 5551`, and `4134 x 3543`, with 600 dpi metadata.
- All PDFs are one page at the requested figure geometry and passed Poppler render inspection.
- All 4051 saved samples are represented as continuous curves without markers; no plotting input is NaN/Inf.
- Shared x range is exactly `0--40.5 s`; A/B/C boundaries are exactly `5.0 s` and `22.5 s`.
- Legends, axes, titles, units, panel labels, and phase labels are present; no legend blocks a B degradation or C recovery trajectory.
- No axis has more than four curves; no dual axis, 3D, radar, dashboard, RMSE/MAE clutter, response threshold clutter, or visible engineering log name is present.
- Style mapping is consistent across all three figures and uses both color and line pattern for grayscale distinction.
- Figure 2 SVG metadata records `IK_UNIT_REQUIRES_THESIS_DEFINITION`; the visible I_K axis does not assert a dimensionless unit.

## A18 consistency check

The A17d phase table and A18 thesis table match exactly for all 12 estimator/phase rows and all four metrics. The frozen values used for consistency gates remain: B RMSE `0.168533016977009 -> 0.026617764392804 m/s` (`84.2062019239618%`), B MAE `0.154841775586824 -> 0.0217783044761216 m/s` (`85.93512351974428%`), physical low-yaw longest duration `17.38 s`, alpha_K response `3.40/4.18 s`, and G_K recovery `12.91/14.34 s`. No metric was re-frozen or recomputed.

## Auxiliary files

- `results/vy_lifesig_v2_8a19_thesis_figures/thesis_plot_style_manifest.md`
- `results/vy_lifesig_v2_8a19_thesis_figures/thesis_figure_export_manifest.md`
- `results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js`

No MATLAB, Simulink, CarSim, `sim()`, or MATLAB/Simulink/CarSim GUI was invoked.
