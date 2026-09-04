# Stage 3D1 Status

- Stage: `3D1`
- Stage-2 formula source: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB status: `PENDING MATLAB VALIDATION`
- Test execution status: `WRITTEN, NOT EXECUTED`
- BLOCKER count: `0`

## 1. New/updated files
- `matlab/local_scalar_kf_step.m`
- `tests/test_stage3d1_local_scalar_kf.m`
- `docs/STAGE_3D1_STATUS.md`

## 2. Function interface
- `[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, measurementValid, p)`
- Pure scalar function, no persistent state.

## 3. WSS local KF I/O
- Input:
  - `xPrev` (previous WSS state `xW_prev`)
  - `PPrev` (previous WSS covariance `PW_prev`)
  - `z` (`vxWssTrack`)
  - `R` (`RwssEquivalent`)
  - `Q` (`QW`)
  - `measurementValid` (`wssValid`)
  - `p` (optional protection parameter struct)
- Output:
  - `xPlus` (`xW_plus`)
  - `PPlus` (`PW_plus`)
  - `xMinus` (`xW_minus`)
  - `PMinus` (`PW_minus`)
  - `K` (`KW`)

## 4. IMU local KF I/O
- Input:
  - `xPrev` (previous IMU state `xI_prev`)
  - `PPrev` (previous IMU covariance `PI_prev`)
  - `z` (`vxImuTrack`)
  - `R` (`R_IMU`)
  - `Q` (`QI`)
  - `measurementValid` (`imuValid`)
  - `p` (optional protection parameter struct)
- Output:
  - `xPlus` (`xI_plus`)
  - `PPlus` (`PI_plus`)
  - `xMinus` (`xI_minus`)
  - `PMinus` (`PI_minus`)
  - `K` (`KI`)

## 5. A / H / Q / R
- Stage-2 frozen scalar KF:
  - `A = 1`
  - `H = 1`
  - WSS uses `Q = QW`
  - IMU uses `Q = QI`
  - Measurement variance passed in as `R` (`RwssEquivalent` or `R_IMU`)

## 6. Prediction formula
- `xMinus = xPrev`
- `PMinus = PPrev + Q`
- Non-finite/negative `xPrev`, `PPrev`, `Q` are protected before use.

## 7. Update formula
- When valid:
  - `K = PMinus / (PMinus + R)`
  - `xPlus = xMinus + K * (z - xMinus)`
  - `PPlus = (1 - K) * PMinus`
- Invalid measurement paths keep prediction outputs.

## 8. Invalid measurement behavior
- `measurementValid = false` => prediction-only output (`xPlus=xMinus`, `PPlus=PMinus`).
- `z` is NaN/Inf => no measurement update.
- `R` is NaN/Inf or `R <= 0` => no measurement update.
- WSS `wssValid=false` with `vxWssTrack=NaN` is explicitly skipped.

## 9. Numerical protections
- `xPrev` NaN/Inf -> treated as `0`.
- `PPrev` NaN/Inf/negative -> treated as `0`.
- `Q` NaN/Inf/negative -> treated as `0`.
- `PMinus = PPrev + Q`; if non-finite/negative -> set to `0`.
- Denominator `PMinus + R` non-finite or `<= 1e-12` => `K = 0`.
- `K` non-finite or `<0` => `K = 0`; `K > 1` => clamp to `1`.
- Non-finite `xPlus` reverts to `xMinus`.
- `PPlus < 0` set to `0`.
- Non-finite `PPlus` set to `max(PMinus, 0)`.

## 10. Initialization
- Top-level controls initial values:
  - WSS initial interface: `xW0 = vx0`, `PW0`
  - IMU initial interface: `xI0 = vx0`, `PI0`
- No additional reset logic is implemented here; this stage keeps the function pure.

## 11. Test file
- `tests/test_stage3d1_local_scalar_kf.m` (10 specified cases implemented)

## 12. MATLAB status
- `PENDING MATLAB VALIDATION`

## 13. BLOCKER count
- `0`

## 14. Not yet implemented
- `PWI` recursion
- `Phi`
- correlated fusion weights (`alphaW`, `alphaI`)
- final fused state `vxFused / Pfused`
- top-level `longitudinal_velocity_estimator`
- GPS/BDS path

## Next stage
- Stage 3D2:
  - PWI recursion
  - Phi construction
  - correlated fusion
