# Stage 3D Final Status

- Stage: `3D`
- Stage-2 formula source: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB status: `PENDING MATLAB VALIDATION`
- Test execution status: `WRITTEN, NOT EXECUTED`
- BLOCKER count: `0`
- Next stage: `Stage 3E`

## 1. Algorithm and test files
- `matlab/local_scalar_kf_step.m`
- `matlab/correlated_two_track_fusion.m`
- `tests/test_stage3d1_local_scalar_kf.m`
- `tests/test_correlated_two_track_fusion.m`

## 2. Local scalar KF interface
```matlab
[xPlus, PPlus, xMinus, PMinus, K] = ...
    local_scalar_kf_step(xPrev, PPrev, z, R, Q, measurementValid, p)
```
The function is pure scalar logic with no persistent state.

### WSS local KF
- `xPrev=xW_prev`, `PPrev=PW_prev`.
- `z=vxWssTrack`, `R=RwssEquivalent`, `Q=QW`.
- `measurementValid=wssValid`.
- Outputs are `xW_plus`, `PW_plus`, `xW_minus`, `PW_minus`, `KW`.

### IMU local KF
- `xPrev=xI_prev`, `PPrev=PI_prev`.
- `z=vxImuTrack`, `R=R_IMU`, `Q=QI`.
- `measurementValid=imuValid`.
- Outputs are `xI_plus`, `PI_plus`, `xI_minus`, `PI_minus`, `KI`.

## 3. Local KF frozen equations
- `A = 1`, `H = 1`.
- Prediction: `xMinus = xPrev`.
- Prediction covariance: `PMinus = PPrev + Q`.
- Valid update gain: `K = PMinus/(PMinus + R)`.
- Posterior: `xPlus = xMinus + K*(z - xMinus)`.
- Posterior covariance: `PPlus = (1-K)*PMinus`.
- Invalid measurement/variance paths keep prediction-only outputs.

## 4. Local KF numerical protection
- Non-finite `xPrev` -> `0`.
- Non-finite/negative `PPrev` or `Q` -> `0`.
- Non-finite/negative `PMinus` -> `0`.
- `measurementValid=false`, non-finite `z`, or invalid `R` skips measurement update.
- `PMinus + R <= 1e-12` or non-finite -> `K=0`.
- `K` is protected to a finite `[0,1]` range inside the local KF.
- Non-finite `xPlus` reverts to `xMinus`; invalid `PPlus` reverts to a non-negative finite value.

Initialization is controlled by the top level: `xW0=xI0=vx0`, with `PW0`, `PI0`; no reset state machine is implemented inside the pure KF function.

## 5. Correlated fusion interface
```matlab
[vxFused, Pfused, alphaW, alphaI, PWI_minus, PWI_plus, Phi, condPhi, fusionValid] = ...
    correlated_two_track_fusion(xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p)
```

## 6. Cross-covariance recursion
- `Q_WI_common = (QW + QI)/2`.
- `PWI_minus = PWI_prev + Q_WI_common`.
- `PWI_plus = (1-KW)*PWI_minus*(1-KI)`.
- Invalid local channels naturally produce `K=0`; no extra cross-covariance gate is injected.
- `PWI_prev` is supplied by the top-level state and is not reset internally.

## 7. Phi and correlated weights
- `Phi = [PW, PWI_plus; PWI_plus, PI]`.
- `den = phi11 + phi22 - 2*phi12`.
- `alphaW = (phi22 - phi12)/den`.
- `alphaI = (phi11 - phi12)/den`.
- The implementation uses the closed-form scalar equivalent of `Phi^{-1}1/(1^T Phi^{-1}1)` and does not call `inv(Phi)`.
- Weights are normalized so `alphaW + alphaI = 1`.
- Negative correlated-fusion weights are allowed; there is no intentional clipping to `[0,1]` in the correlated fusion stage.

## 8. Fused state and covariance
When both channels are valid:
- `vxFused = alphaW*xW + alphaI*xI`.
- `Pfused = alphaW^2*PW + 2*alphaW*alphaI*PWI_plus + alphaI^2*PI`.

Single-channel fallback:
- WSS only: `alphaW=1`, `alphaI=0`, `vxFused=xW`, `Pfused=PW`, `fusionValid=true`.
- IMU only: `alphaW=0`, `alphaI=1`, `vxFused=xI`, `Pfused=PI`, `fusionValid=true`.

Both invalid:
- `fusionValid=false`;
- `vxFused=NaN`;
- `Pfused=NaN`.

The final correlated fusion operates on local-KF posterior states (`xW_plus`, `xI_plus`), not directly on raw upstream tracks.

## 9. Correlated-fusion numerical protection
- Non-finite or negative local variances are guarded to finite physical values.
- Invalid common process-noise inputs fall back safely.
- `den <= eps_den` uses a protected denominator.
- `condPhi` is returned as a conditioning monitor.
- Cauchy-Schwarz bound is enforced: `|PWI_plus| <= sqrt(PW*PI + eps)`.
- `Pfused` uses a minimum floor `Pfused_min` (default `1e-12`) when a finite fused covariance is expected.
- `Phi` is symmetric by construction.

## 10. Stage outcome
- `IMPLEMENTATION COMPLETE`
- `TESTS WRITTEN`
- `PENDING MATLAB EXECUTION`
- `PENDING MATLAB VALIDATION`

## 11. Next stage
Stage 3E integrates initialization/reset, four-wheel kinematics, Stage 3B window logic, Stage 3C confidence/WSS track, IMU recursion, both local KFs, persistent `PWI`, correlated fusion, single/dual-channel state logic, `allWheelInvalidDuration`, `degradedMode`, last-finite output protection, and the unified estimator interface.
