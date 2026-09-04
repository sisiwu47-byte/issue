# Stage 3C Final Status

- Stage: `3C`
- Stage-2 formula source: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB validation state: `PENDING MATLAB VALIDATION`
- Test execution state: `WRITTEN, NOT EXECUTED`
- BLOCKER count: `0`

## 1. Algorithm and test files
- `matlab/slip_confidence_mapping.m`
- `matlab/wss_track_builder.m`
- `tests/test_slip_confidence_mapping.m`
- `tests/test_wss_track_builder.m`

## 2. Function interfaces

### `slip_confidence_mapping`
```matlab
[rhoWheel, Rwheel, validWheel] = slip_confidence_mapping(eSlip, residualValid, validGeom, p)
```
- `eSlip`: `4x1`, wheel order `[FL, FR, RL, RR]`.
- `residualValid`: `4x1 logical`.
- `validGeom`: `4x1 logical`.
- Outputs `rhoWheel`, `Rwheel`, `validWheel` are all `4x1` in the same wheel order.

### `wss_track_builder`
```matlab
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel)
```
- `vxWheel`: `4x1`, wheel order `[FL, FR, RL, RR]`.
- `Rwheel`: `4x1`.
- `validWheel`: `4x1 logical`.
- `vxWssTrack` and `RwssEquivalent` are scalar; `alphaWheel` is `4x1`; `wssValid` is logical.

## 3. Continuous confidence
For each wheel:
- `rho_i = 1`, when `e_i <= e_low`.
- `rho_i = (e_high - e_i)/(e_high - e_low)`, when `e_low < e_i < e_high`.
- `rho_i = 0`, when `e_i >= e_high`.
- Enforced range: `0 <= rho_i <= 1`.

## 4. Adaptive measurement variance
- `R_i = sat(R0_i/(rho_i + epsilon), R_min, R_max)`.
- Parameters `e_low`, `e_high`, `rho_hard`, `R0`, `R_min`, `R_max`, `epsilon` are read from `p`.

## 5. Hard isolation
`validWheel(i)` is true only when all conditions hold:
- `residualValid(i) = true`;
- `validGeom(i) = true`;
- `eSlip(i)` is finite;
- `rho_i > rho_hard`.

`rho_i <= rho_hard` is treated as invalid.

## 6. WSS internal fusion
For valid wheels only:
- `q_i = 1/R_i`.
- `alpha_i = q_i/sum(q_valid)`.
- `vxWssTrack = sum(alpha_i * vxWheel_i)`.
- `RwssEquivalent = 1/sum(q_valid)`.

Invalid-wheel `alphaWheel` entries are zero. Valid-wheel weights are normalized by construction.

## 7. All-wheel-invalid behavior
If no valid wheel remains:
- `wssValid = false`;
- `vxWssTrack = NaN`;
- no forced wheel average or pseudo measurement is generated;
- downstream local KF must use `wssValid` as the measurement-update gate.

## 8. Exception and numerical handling
- Input size checks enforce `4x1` vectors in `[FL, FR, RL, RR]` order.
- Non-finite `eSlip`, `residualValid=false`, or `validGeom=false` skip normal confidence update.
- `R_i` is saturated to finite positive bounds.
- `wss_track_builder` filters non-finite `vxWheel`, non-finite `Rwheel`, and `Rwheel <= 0`.
- When `wssValid=false`, fusion is not evaluated; `RwssEquivalent` uses a bounded finite fallback.
- No `eval`, `assignin`, `global`, duplicate FIFO, KF/PWI logic, IMU-only timer, GPS/BDS, or `Vx_true` path is introduced in Stage 3C.

## 9. Stage outcome
- `IMPLEMENTATION COMPLETE`
- `TESTS WRITTEN`
- `PENDING MATLAB EXECUTION`
- `PENDING MATLAB VALIDATION`

## 10. Next stage
Stage 3D:
- local scalar KFs;
- `PWI` cross-covariance recursion;
- `Phi` construction;
- correlated fusion.
