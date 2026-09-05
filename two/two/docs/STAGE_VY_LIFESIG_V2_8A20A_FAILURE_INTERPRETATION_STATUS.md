# V2.8-A20a K-health cross-condition failure interpretation status

## Final verdict

`A20A_SCOPE_CLOSURE_PASS`

- `OFFLINE_EVIDENCE_INTERPRETATION_ONLY = YES`
- MATLAB/Simulink/CarSim runtime count: `0/0/0`; C1/C2 rerun: NO.
- New thesis figure count: `0`.
- A20 original verdict remains `A20_LIMITED_CROSS_CONDITION_FAIL`.

## C1 classification

`CASE_B: PARTIAL_RECOVERY_WINDOW_INSUFFICIENT`

- C phase: frozen `22.5--40.5 s`.
- Strict `d_DK < d0` appears once, `25.44--28.48 s`, continuous span `3.04 s`; `d0=0.346766 m/s`.
- C `d_DK`: mean `0.755205`, last-1-s mean `1.36407`, final `1.41107 m/s`.
- On the sustained interval, `I_K 0.878896 -> 0.191494` (decrease), `G_K 0.000152406 -> 0.147351` (increase), `alpha_K 0.0000263471 -> 0.0248541` (increase).
- C phase `I_K`: start `2.39131`, end `1.76999`, minimum `0.156414`.
- C phase `G_K`: start `4.11789e-11`, end `2.05611e-8`, maximum `0.209269`.
- C phase `alpha_K`: start `7.11488e-12`, end `3.56230e-9`, maximum `0.0349372`.
- Recovery mechanism direction is consistent during the established interval, but the consistency condition does not persist and original full-recovery thresholds remain NOT REACHED.

## Mixed A20 evidence and D-track

- C1 degradation protection: supported; C1 full recovery acceptance: limited/failed.
- C2 K-health behavior: PASS; D-track degradation: observed.
- C2 RMSE D/K/Original/Proposed: `0.08435 / 0.78278 / 0.14573 / 0.08391 m/s`.
- C2 `d_DK` means multi-track inconsistency; it is not K true error and D is not ground truth.
- A17d remains the formal full degradation/recovery evidence.

## Scope closure

- `K_HEALTH_CROSS_CONDITION_EVIDENCE = PARTIAL`
- `KNOWN_RECOVERY_LIMITATION_DOCUMENTED = YES`
- `K_HEALTH_CROSS_CONDITION_VALIDATION_CLOSED = NO`
- `K_HEALTH_DEVELOPMENT_CLOSED = YES`
- `READY_FOR_D_EKF_VALIDATION = YES`

Evidence: `results/vy_lifesig_v2_8a20a_failure_interpretation/`.
