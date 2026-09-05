# V2.8-A24 — D-EKF healthy cross-steering NIS validation status

## Verdict

`D_NIS_CROSS_STEERING_VALIDATION_PASS`

`READY_FOR_D_HEALTH_DESIGN = YES`

## Runtime and replay

- New runtime count=`1`; no second runtime.
- N1 exactly reuses the A20 C1 DLC-like profile/control: mu=`0.8`, StopTime=`40.5 s`.
- N1 exact replay max `Vy_D` difference=`0`; Ay+r/r-only update counts=`811/3240`; update-valid fraction=`1.0`.
- N1 D RMSE=`0.0232682276 m/s`; A20 C1=`0.0232760315 m/s`; difference=`-0.0000078039 m/s`.
- `DIAGNOSTIC_INSTRUMENTATION_ALGORITHM_EFFECT = NONE`.

## Three-condition result

- normalized-NIS RMS N0/N1/D1=`0.0500631 / 0.0468360 / 0.1820490`.
- N1/N0=`0.93554x`; D1/N0=`3.63639x`; D1/N1=`3.88694x`.
- NIS_2D RMS N0/N1/D1=`0.110425 / 0.118769 / 0.564807`.
- NIS_r RMS N0/N1/D1=`0.0486890 / 0.0431274 / 0.146543`.
- N0/N1 chi-square 95% and 99% exceedance fractions are zero in both update modes.
- Covariance is finite; mean trace(P) N0/N1/D1=`0.000408746 / 0.000395097 / 0.000541546`.

## Candidate and scope

- `normalized_NIS = PROMISING`; online available and independent of true Vy.
- No NIS threshold, G_D, D-health law, Q/R/P0, algorithm, vehicle/tire parameter, or waveform was changed.
- Diagnostic-only figure count=`1`; PNG 600 dpi and vector PDF/SVG; reproduction check=`PASS`.
- Plotting source: `results/vy_lifesig_v2_8a24_d_nis_cross_steering_validation/generate_a24_diagnostic_figure.py`.
- Evidence: `results/vy_lifesig_v2_8a24_d_nis_cross_steering_validation/`.
