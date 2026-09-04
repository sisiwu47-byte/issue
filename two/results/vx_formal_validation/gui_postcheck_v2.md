# VX-V2 Post-GUI Static Check

- Check date: 2026-09-02
- Evidence class: `CURRENT_IMPLEMENTATION / PRE-RUNTIME_STATIC_CHECK`
- `FORMAL_RUNTIME_COUNT = 0`
- Verdict: `MANUAL_GUI_ACTION_REQUIRED`

## Confirmed

- `model/vx.slx` was saved after V1; current candidate SHA-256 is `9E83DA1D750A8C52174869A967AD47838FE765C62746D18ED366E27B4EE21D5C`.
- Core estimator, parameter and wrapper hashes remain exactly equal to the V1 freeze.
- Estimator block SID 313 is active and calls `longitudinal_velocity_estimator_simulink(u)` with output dimension 38.
- The active input Mux SID 246 has grouped dimensions `[4 4 3 3 3 1]`, totaling 18.
- Active logs exist for `est_y_log` (SID 310), `est_u_log` (SID 311), and `Vx_true_log` (SID 312).
- Estimator output 1 reaches the active `vx_hat` Goto SID 274.
- Estimator inputs 5:8 receive four actual wheel-angle tags `WEEL1`, `WEEL3`, `WEEL2`, `WEEL4` through the active four-input Mux SID 251.
- The active controller speed feedback remains the CarSim `Vx` tag. This is consistent with the independent-validation Stage A defined by `specs/signal_interface.md`; it is not a blocker for estimator-only formal validation.

## Unclosed formal-case gates

1. The active controller reference source is Repeating Sequence Interpolated2 SID 438 with `TimeValues=[0 3 8 16]` and `OutValues=[72 72 72 72]` km/h. This is only compatible with the T1 constant-speed level; it does not instantiate N1, N2, D1 or D2.
2. Existing historical Stateflow profiles contain command shapes resembling N2/D1/D2, but their `vx_ref` routing is not connected to the active controller reference path. They cannot be counted as current formal case definitions.
3. T1 has an active `From` block tagged `driver_steering`, but no matching Goto/source is present in the saved model package. Therefore the frozen `0.02 rad, 0.4 Hz, [3,13] s` steering excitation is not traceable.
4. Although all four actual wheel-angle outputs enter the estimator, static structure cannot prove that RL/RR will execute genuine rear steering in T1.
5. No current, traceable CarSim road/dataset configuration establishes `mu=0.3` for D1/D2 or the intended RL/RR drive-slip/brake-lock excitation.
6. The V1 packaging/analyzer still carries the pre-GUI model hash. It must be updated only after the final GUI-ready model/case configuration is frozen; doing so now would falsely endorse an incomplete runtime baseline.

No MATLAB/Simulink/CarSim runtime was executed. A headless MATLAB static query was attempted once but MATLAB terminated during startup with `failed to load settings errors_warnings plugin`; the model XML then provided the static evidence above. This startup failure is not treated as formal runtime evidence.
