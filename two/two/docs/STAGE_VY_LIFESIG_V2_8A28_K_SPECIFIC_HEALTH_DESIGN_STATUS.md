# V2.8-A28 K-specific health audit and offline design status

## Verdict

`K_SPECIFIC_HEALTH_DESIGN_PASS`

- `NEW_RUNTIME_COUNT = 0`
- Selected K-specific evidence: posterior `P22 = Var(Vy_K)`.
- Exact covariance replay check against logged K11/K21/`obs_metric`: maximum difference `3.552713678800501e-15`.
- `P22` depends only on the frozen K-KF covariance recursion and its yaw-rate input; it does not depend on D-EKF, `d_DK`, or true Vy.

## Frozen offline candidate

- Healthy-only reference: `P22_0 = 0.3882795926788009`, the maximum P99 across frozen A17d-A, A20-C1-A, and A27 continuous-excitation K data.
- `e_K = max(0, P22 - P22_0)`.
- `G_K = 1/(1 + e_K/P22_0)`.
- `H_K = availability_K * G_K`; fixed `qD/qK/qF` and A27 D-health remain unchanged.
- P22 already carries covariance memory, so no extra smoother, integral, or tuned scale was introduced.
- `d_DK` is retained only as a diagnostic consistency quantity and is removed from K-health.

## Offline validation

- A17d B: `G_K` mean/min `0.4080442008 / 0.1944451870`; sustained `G_K<=0.5` response `4.47 s`.
- A17d Original / K-self-health Unified B RMSE: `0.1685330170 / 0.0628769645 m/s`; fusion protection remains present.
- A17d recovery: sustained `G_K>=0.95` after `5.55 s` in C.
- Healthy false-suppression fraction (`G_K<0.95`): maximum `0` across A17d-A, A20-C1-A, and A27 continuous excitation.
- A27 B old final / K-self-health Unified RMSE: `0.2762842742 / 0.2769302075 m/s` (`+0.2338%`); the passed D-case protection is not materially changed.
- `K_SPECIFIC_HEALTH_INDEPENDENT_OF_D = PASS`.

## Scope

- This stage validates offline feasibility only; no formal model/core was modified.
- It does not establish online/runtime behavior, arbitrary K faults, simultaneous D/K faults, or global robustness.

Evidence: `results/vy_lifesig_v2_8a28_k_specific_health_design/`

`READY_FOR_FINAL_K_SELF_HEALTH_VALIDATION = YES`
