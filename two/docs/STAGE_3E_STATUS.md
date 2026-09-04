# Stage 3E Final Status

- Stage: `3E`
- Latest status date: `2026-08-11`
- Top-level file: `matlab/longitudinal_velocity_estimator.m`
- Main integration test: `tests/test_longitudinal_velocity_estimator.m`
- MATLAB execution status: `WRITTEN, NOT EXECUTED`
- MATLAB validation status: `PENDING MATLAB VALIDATION`
- BLOCKER count: `0`

This is the canonical Stage 3E status. It incorporates the Stage 3E1 top-level implementation details, the later 1 kHz input / 100 Hz update-gate fix, and the Stage 3E2 persistent-slip confidence/recovery corrections.

## 1. Fixed input contract
`est_u` has 18 elements:
- `1:4` `wheelOmega [FL, FR, RL, RR]` (rad/s)
- `5:8` `wheelAngle [FL, FR, RL, RR]` (rad)
- `9` `Ax` (m/s^2)
- `10` `Ay` (unused holder)
- `11` `Az` (unused holder)
- `12` `AVx` (unused in the Stage 3E main chain)
- `13` `AVy` (unused in the Stage 3E main chain)
- `14` `AVz` (rad/s)
- `15:17` reserved
- `18` reset flag

No `Vx_true`, GPS/BDS, or `Ax_SM/Ay_SM/Az_SM` truth path is used by the estimator.

## 2. Fixed output contract
`est_y` has 38 elements:
- `1` `vx_hat`
- `2` `Pfused`
- `3` `vxWssTrack`
- `4` `Pwwss`
- `5` `vxImuTrack`
- `6` `Pimu`
- `7` `P12`
- `8:11` `vxWheel [FL, FR, RL, RR]`
- `12:15` `eSlip [FL, FR, RL, RR]`
- `16:19` `rhoWheel [FL, FR, RL, RR]`
- `20:23` `Rwheel [FL, FR, RL, RR]`
- `24:27` `validWheel [FL, FR, RL, RR]` as double
- `28` `wssValid`
- `29` `imuValid`
- `30:31` `[alphaW, alphaI]`
- `32` `allWheelInvalid`
- `33` `imuOnlyDuration`
- `34` `degradedMode`
- `35` `estimatorUpdated`
- `36` `slipReady`
- `37` `condPhi`
- `38` `updateCounter`

After the Stage 3E2 confidence extension, the `rhoWheel` output corresponds to the combined confidence used for wheel validity (`rhoRaw`).

## 3. Persistent state after the final Stage 3E2 corrections
The top-level persistent-state audit expects 18 persistent variables. The documented state includes:
- `initialized`, `pCfg`
- `vxFusedPrev`
- `xWPrev`, `PWPrev`
- `xIPrev`, `PIPrev`
- `PWI_prev`
- `axCorrPrev`
- `PfusedPrev`
- `lastFiniteVx`
- `allWheelInvalidDuration`
- `updateCounter`
- `degradedMode`
- the update-gate state and full held output (`updatePhase`/equivalent countdown state and `yHold`)
- `wheelLocked`
- `wheelRecoverCount`

## 4. Initialization and reset
On first call or `reset != 0`:
- compute `vx0 = median(p.Rw*omega_i)` using finite wheel candidates;
- if all wheel candidates are invalid, use the protected initialization fallback `0`;
- set `vxFusedPrev = xWPrev = xIPrev = vx0`;
- set `PWPrev=p.PW0`, `PIPrev=p.PI0`, `PWI_prev=p.PWI0`;
- reset covariance/output history, IMU previous acceleration, invalid-duration timer, counters, degradation state, held output, `wheelLocked`, and `wheelRecoverCount`;
- clear the Stage 3B FIFO by calling `window_delta_velocity_indicator(..., reset=1, ...)`;
- re-arm the 1 kHz/100 Hz gate so the next non-reset sample can perform a true estimator update.

## 5. 1 kHz input / 100 Hz estimator update gate
Final corrected scheduling semantics:
- `Ts_sim = 0.001 s`;
- `Ts_est = 0.01 s`;
- `updateEvery = 10`;
- the gate uses countdown-to-zero behavior (or an equivalent implementation);
- after reset, the next non-reset sample performs an estimator update;
- after a true update, the gate reloads to `updateEvery - 1`, producing exactly nine hold ticks before the next update;
- estimator persistent states advance only on true 100 Hz update ticks;
- hold ticks preserve the full output vector and set `estimatorUpdated=0`;
- `updateCounter` increments only on true updates.

## 6. 100 Hz estimator execution order
On each true update:
1. Read the fixed `est_u` inputs.
2. Run `four_wheel_kinematic_speed`.
3. Run `window_delta_velocity_indicator`.
4. Form the single-step IMU recursive track.
5. Compute slip confidence and wheel validity.
6. Build the WSS internal track.
7. Determine `imuValid` independently of WSS validity.
8. Run the WSS local scalar KF.
9. Run the IMU local scalar KF.
10. Run `correlated_two_track_fusion` and update `PWI`.
11. Apply top-level single/dual-channel state logic and finite-output protection.
12. Update persistent states, wheel-lock recovery state, timers, and degradation state.

## 7. IMU recursive track
- `vyPrior = 0` in the frozen Stage 3E main chain.
- `axCorrCurrent = Ax + AVz*vyPrior`.
- `dvImuStep = 0.5*Ts_est*(axCorrPrev + axCorrCurrent)`.
- `vxImuTrack = vxFusedPrev + dvImuStep`.
- `axCorrPrev <- axCorrCurrent` after a true update.

The 0.5 s `DeltaVImu` window quantity is not substituted for this single-step recursive track; this avoids double integration.

## 8. Window boundary semantics
- At the 50th valid 100 Hz call the finite window is filled, but the first formal full-span residual is not yet used as a valid residual.
- At the 51st valid 100 Hz call the full residual becomes formally valid for slip classification.
- `windowReady` and `residualValid` are not interchangeable.

## 9. Final slip confidence: delta + absolute consistency
The Stage 3E2 correction adds absolute consistency to the original finite-window delta-velocity consistency metric.

Absolute criterion parameters:
- `eAbs_low = 0.20 m/s`
- `eAbs_high = 0.80 m/s`

`rhoAbs`:
- `1` when `eAbs <= eAbs_low`;
- `0` when `eAbs >= eAbs_high`;
- linear interpolation between thresholds.

Combined confidence:
- original finite-window confidence is `rhoDelta`;
- `rhoRaw = min(rhoDelta, rhoAbs)`;
- the corrected caller receives `slip_confidence_mapping` outputs as `[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs]`.

This prevents persistent slip from becoming falsely trusted when the delta metric alone becomes small.

## 10. Wheel lock and recovery hysteresis
Recovery parameters:
- `p.eDelta_recover = 0.10 m/s`
- `p.eAbs_recover = 0.18 m/s`
- `p.Nrecover = 30`

Behavior:
- `wheelLocked` and `wheelRecoverCount` update only on true 100 Hz estimator updates;
- a locked wheel remains locked while recovery criteria are violated;
- 29 consecutive qualifying updates are insufficient;
- the 30th consecutive qualifying update permits recovery;
- an interrupted recovery condition resets the count;
- reset clears lock/recovery state.

## 11. Local KFs and PWI continuity
- WSS local KF uses `wssValid` as `measurementValid`.
- IMU local KF uses `imuValid` as `measurementValid`.
- Existing local-KF and correlated-fusion functions are called; formulas are not duplicated at the top level.
- After each true update, `PWI_plus` becomes the next `PWI_prev`.
- WSS loss/recovery does not manually force `PWI` to zero.

## 12. Channel-state behavior
- Case A: `wssValid && imuValid` -> correlated fusion result.
- Case B: `~wssValid && imuValid` -> IMU local output.
- Case C: `wssValid && ~imuValid` -> WSS local output.
- Case D: `~wssValid && ~imuValid` -> `lastFiniteVx` fallback; do not propagate NaN or force zero to the control output.

If the fusion submodule returns `fusionValid=false`, the top level applies the same finite-output protection.

## 13. all-wheel-invalid duration and degraded mode
`allWheelInvalidDuration`:
- increments by `Ts_est` while `~wssValid && imuValid`;
- resets to zero when WSS becomes valid;
- remains unchanged when both WSS and IMU are invalid.

`degradedMode`:
- WSS valid -> `false`;
- IMU-only -> `true` only after `allWheelInvalidDuration > TimuOnlyMax`;
- both channels invalid -> `true`;
- reset -> `false`.

## 14. lastFiniteVx protection
- Preserve the last finite control estimate.
- Update it only when the current `vx_hat` is valid and finite.
- Use it when both channels fail or fusion is unusable.
- Do not hard-fallback to `0` except for the explicitly defined all-invalid initialization case.

## 15. Static architecture checks
The Stage 3E top level must not introduce:
- CarSim true longitudinal speed as estimator input;
- GPS/BDS fusion;
- duplicate four-wheel kinematics;
- duplicate FIFO logic;
- duplicate confidence mapping;
- duplicate correlated fusion;
- independent inverse-variance fusion in place of correlated fusion;
- a second IMU integration path.

There is no algebraic loop in the IMU track because it uses the previous fused state.

## 16. Written test coverage
Tests cover initialization/reset, constant-speed and acceleration cases, the 50/51 window boundary, single-wheel slip, short/long all-wheel-invalid cases, WSS recovery, WSS-only/IMU-only/dual failure, NaN/Inf isolation, PWI continuity, output integrity, long finite sequences, 1 kHz/100 Hz gate and hold behavior, reset gate re-arming, `est_y(1:38)` interface parsing, `eDelta/eAbs` separation, persistent-slip lock behavior, the 29/30 recovery threshold, interrupted recovery reset, and reset clearing wheel-lock state.

Relevant test files include:
- `tests/test_longitudinal_velocity_estimator.m`
- `tests/test_wheel_lock_recovery.m`
- `tests/test_slip_confidence_mapping.m`
- `tests/test_estimator_default_params.m`

## 17. Stage outcome
- `IMPLEMENTATION COMPLETE`
- `INTEGRATION TESTS WRITTEN`
- 1 kHz/100 Hz gate corrections incorporated
- persistent-slip confidence/recovery corrections incorporated
- `PENDING MATLAB EXECUTION`
- `PENDING MATLAB VALIDATION`

## 18. Next execution step
Run the full MATLAB test and simulation suite in the MATLAB/Simulink/CarSim environment using `docs/MATLAB_EXECUTION_HANDOFF.md`, then record actual execution results separately from this implementation-status document.
