# V2.8-A26b Corrected D-Only Degradation / Recovery Formal Validation Status

## Verdict

`D_ONLY_CORRECTED_VALIDATION_FAIL`

The only authorized CarSim-Simulink runtime completed at `40.5 s`; runtime count remains `1`. Offline D replay passed with maximum difference `1.6210854880682746e-10`. Frozen-source and runtime guard integrity passed.

## Frozen condition and phase results

- A/B/C: `[0,5) / [5,22.5) / [22.5,40.5] s`; D-EKF `k_f=0.78181/0.390905/0.78181`.
- D RMSE A/B/C: `0.037441 / 0.129090 / 0.038880 m/s`.
- K RMSE A/B/C: `0.173362 / 0.294638 / 0.310038 m/s`.
- B excitation: yaw RMS `0.087272 rad/s`, low-yaw coverage `4.8%`, longest low-yaw interval `0.05 s`; `K_NO_LOW_YAW_DEGRADATION=PASS`.
- B D/K RMSE ratio: `0.438131`; `D_TO_K_WEIGHT_TRANSFER_IS_BENEFICIAL=NO`.

## Health, fusion, and recovery

- normalized-NIS mean A/B/C: `0.0390205 / 0.401486 / 0.0380356`; D degradation response passed.
- B `G_D min/mean=0.134064/0.315870`; B `G_K min=0.803104` versus original unguarded `0.419519`; D-aware K guard passed.
- alpha-D baseline/min: `0.843834/0.423140`; response time `0.53 s`.
- Original/Proposed B RMSE: `0.125051/0.155396 m/s`; RMSE reduction `-24.2655%`, so fusion improvement failed.
- C recovery passed: `G_D` recovery `0.40 s`, alpha-D recovery `0.26 s`.
- Numerical integrity passed: no NaN/Inf, update-valid throughout, alpha-sum max error `3.33e-16`, fallback count `0`.

## Evidence boundary

The experiment supports D mismatch detection, D-aware K attribution protection, and recovery. It does not support beneficial D-to-K transfer or improved unified fusion because D remained more accurate than K in phase B. The three exported figures are failure evidence, not successful validation figures.

- Evidence: `results/vy_lifesig_v2_8a26b_corrected_d_only_validation/`.
- Plotting source: `generate_a26b_evidence_figures.py`; all PNG/PDF/SVG outputs pass source reproduction checks.
- `READY_FOR_FINAL_K_REGRESSION = NO`.

