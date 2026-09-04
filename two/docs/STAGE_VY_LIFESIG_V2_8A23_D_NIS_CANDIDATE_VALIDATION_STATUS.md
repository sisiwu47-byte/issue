# V2.8-A23 — D-EKF NIS candidate validation status

## Verdict

`D_NIS_CANDIDATE_VALIDATION_LIMITED`

`READY_FOR_D_HEALTH_DESIGN = NO`

## Replay and runtime

- Replay status: `N0=PASS`, `N1=NOT_AVAILABLE`, `D1=PASS`.
- N0/D1 saved-vs-replay `Vy_D` max difference=`0`; update-valid fraction=`1.0`.
- N0/D1 update counts: Ay+r 2D=`811`, r-only=`3240`; P11/P22/trace(P) are finite.
- N1 A20 C1 evidence lacks `est_u_log1`, `est_z_log1`, `Vx`, and `Ay`; exact diagnostic replay is impossible without a new runtime.
- `NEW_RUNTIME_COUNT = 0`; MATLAB/Simulink/CarSim calls=`0`.

## D performance and mode-separated NIS

- D RMSE N0/N1/D1=`0.0290186746 / 0.0232760315 / 0.0843558890 m/s`.
- Ay+r 2D NIS RMS N0/D1=`0.110424818 / 0.564806719`; separation=`5.114853x`.
- r-only NIS RMS N0/D1=`0.048689008 / 0.146543463`; separation=`3.009785x`.
- N0 chi-square 95%/99% exceedance fractions are `0/0` for both modes; N1 false-positive behavior is unavailable.
- D1 also remains below the fixed chi-square 95%/99% references, so those references do not by themselves classify this degradation.
- N0-vs-N1 healthy stability, a mandatory PROMISING condition, cannot be established.

## Candidate assessment

- Top candidate family: `normalized_NIS — WEAK`.
- Raw normalized-NIS D1/N0 RMS separation=`3.636392x`; D1 Pearson/Spearman with absolute D error=`0.608354/0.688267`.
- Prespecified 0.5 s and 1.0 s means were evaluated without window search; both remain `WEAK` because N1 is unavailable.
- `NIS_2D`, `NIS_r`, `abs(r innovation)`, and `trace(P)` are `WEAK`; `abs(Ay innovation)` is `NOT_SUPPORTED`.
- No true Vy is needed online for NIS/normalized NIS; true Vy was used only for offline correlation assessment.
- No D-health function, G_D, threshold, gain, persistence rule, parameter change, or estimator modification was introduced.

## Figures and evidence

- Diagnostic-only figure count=`2`; PNG=`600 dpi`, PDF/SVG=`vector`; reproduction check=`PASS`.
- Plot source SHA-256: `69B5453682A70770CE5CA82352B984B0171405C5C9796A973351F7603E77C100`.
- A19 frozen style geometry, typography, palette, line/dash conventions, grid, and phase boundaries are reused.
- Evidence: `results/vy_lifesig_v2_8a23_d_nis_candidate_validation/`.
- Frozen D/K/LifeSig/K-health implementations, Q/R/P0, vehicle/tire parameters, windows, prior data, and prior verdicts remain unchanged.
