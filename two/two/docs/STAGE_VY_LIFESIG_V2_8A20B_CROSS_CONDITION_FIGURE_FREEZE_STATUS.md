# V2.8-A20b — K-KF / K-health cross-condition thesis figure freeze status

## Final verdict

`K_CROSS_CONDITION_THESIS_FIGURE_FREEZE_PASS`

- `OFFLINE_THESIS_FIGURE_GENERATION_ONLY = YES`.
- New MATLAB/Simulink/CarSim runtime count: `0/0/0`; GUI use: `NO`.
- A20 verdict remains `A20_LIMITED_CROSS_CONDITION_FAIL`.
- A20a remains `CASE_B: PARTIAL_RECOVERY_WINDOW_INSUFFICIENT`.
- `K_HEALTH_CROSS_CONDITION_EVIDENCE = PARTIAL`.

## Frozen figures

- Fig4: `results/vy_lifesig_v2_8a20b_cross_condition_thesis_figures/Fig4_KKF_cross_steering_validation` in PNG/PDF/SVG.
- Fig5: `results/vy_lifesig_v2_8a20b_cross_condition_thesis_figures/Fig5_low_mu_cross_condition_validation` in PNG/PDF/SVG.
- `FINAL_A20B_THESIS_FIGURE_COUNT = 2`.
- `TOTAL_K_SECTION_CORE_FIGURES = 5` (`baseline=3`, `cross-condition=2`).
- A19 style mapping inherited exactly; no new visual theme, dual y-axis, or engineering signal label was introduced.
- Axis/curve contracts: Fig4 `4 axes, 1/3/1/3`; Fig5 `3 axes, 3/3/2`; maximum `3` curves per axis.
- PNG `600 dpi`; PDF/SVG vector; visual QA passed with no observed clipping or missing labels.

## Source and reproduction

- Plot source: `results/vy_lifesig_v2_8a20b_cross_condition_thesis_figures/generate_a20b_cross_condition_figures.py`.
- Source SHA-256: `42B11AF9F9E8AF54A987BAC4D702D8AC01BDB8109DA4E6E7509978C5A69D128C`.
- Project-relative paths: YES; absolute `D:\` references: `0`.
- One isolated Python-only reproduction check: `PASS`.
- Formal/reproduction PNG and SVG: byte-identical; PDFs: vector-only with identical page geometry and equal byte size.
- Frozen C0/C1/C2 data and A20/A20a interpretation hashes remained unchanged.

## Freeze state

- `K_CROSS_CONDITION_FIGURES_READY = YES`.
- The figures support cross-condition evidence only; full K-KF or K-health generalization is not claimed.
