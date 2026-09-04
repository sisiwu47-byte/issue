# V2.8-A21 — D-EKF degradation mechanism audit status

## Verdict

`D_EKF_DEGRADATION_AUDIT_INSUFFICIENT_EVIDENCE`

The frozen evidence establishes a 2.90658× C2 D-track degradation under matched steering and closely matched yaw excitation, with no observed numerical failure. It does not contain the innovations, NIS, covariance, predicted-measurement, or force/model-residual histories needed for a causal mechanism conclusion.

## Key results

- C0 D RMSE: `0.0290187 m/s`.
- C2 D RMSE: `0.0843450 m/s`.
- Degradation factor: `2.90658`.
- First affected frozen phase: `A`; exact time onset is not assigned without a new threshold.
- `EXCITATION_CONFOUNDING = NO`.
- `LOW_YAW_NOT_PRIMARY_D_DEGRADATION_EXPLANATION`.
- `INNOVATION_EVIDENCE = NOT_AVAILABLE_IN_EXISTING_EVIDENCE`.
- `NUMERICAL_FAILURE = NOT_OBSERVED`.
- `TIRE_FORCE_MODEL_MISMATCH = PLAUSIBLE_BUT_NOT_PROVEN`.
- Mechanism: `CASE_D5: MULTI_FACTOR_OR_UNRESOLVED`.
- Top existing online candidate: `D-K disagreement d_DK (WEAK)`.
- `ADDITIONAL_D_DIAGNOSTIC_LOGGING_REQUIRED = YES`.
- `READY_FOR_D_HEALTH_CANDIDATE_VALIDATION = NO`.

## Evidence and figure disposition

- Required CSV count: 3; all present and non-empty.
- Offline D-error trace: `d_error_timeseries_offline.csv`, 4051 samples over the unchanged 0–40.5 s window.
- Diagnostic figure count: 1, exported as PNG/PDF/SVG.
- `NEW_THESIS_CORE_FIGURE_COUNT = 0`.
- Persistent plotting source: `results/vy_lifesig_v2_8a21_d_ekf_degradation_audit/generate_a21_diagnostic_figures.py`.
- Source SHA-256: `498A2E527BA97B00EBBAB4DD3DEF4E0DD402BF11018D73397E0E9F9F50F54BC4`.
- Evidence directory: `results/vy_lifesig_v2_8a21_d_ekf_degradation_audit/`.

## Scope closure

A17d, A20, and A20a verdicts remain unchanged. A21 added zero MATLAB/Simulink/CarSim runtimes and made no algorithm, parameter, model, core, wrapper, source-evidence, or acceptance-window change. A targeted future runtime is recommended only to persist existing D diagnostic outputs; it is not authorized or executed by this stage.
