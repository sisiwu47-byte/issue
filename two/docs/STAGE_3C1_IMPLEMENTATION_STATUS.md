# Stage 3C1 Implementation Status

- Stage: `3C1`
- Math authority: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB validation state: `PENDING MATLAB VALIDATION`
- BLOCKER count: `0`

## Files Added/Modified
- `matlab/slip_confidence_mapping.m`
- `matlab/wss_track_builder.m`
- `docs/STAGE_3C1_IMPLEMENTATION_STATUS.md`

## Function Interfaces

### 1) `slip_confidence_mapping`
- Signature:
  - `[rhoWheel, Rwheel, validWheel] = slip_confidence_mapping(eSlip, residualValid, validGeom, p)`
- Inputs:
  - `eSlip`: `4x1` in wheel order `[FL, FR, RL, RR]`
  - `residualValid`: `4x1 logical`
  - `validGeom`: `4x1 logical`
  - `p`: parameter struct
- Outputs:
  - `rhoWheel`: `4x1`
  - `Rwheel`: `4x1`
  - `validWheel`: `4x1 logical`

### 2) `wss_track_builder`
- Signature:
  - `[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel)`
- Inputs:
  - `vxWheel`: `4x1` in wheel order `[FL, FR, RL, RR]`
  - `Rwheel`: `4x1`
  - `validWheel`: `4x1 logical`
- Outputs:
  - `vxWssTrack`: scalar
  - `RwssEquivalent`: scalar
  - `alphaWheel`: `4x1`
  - `wssValid`: logical

## Stage-2 formulas used
- Continuous confidence (piecewise):
  - `rho_i = 1`, `e_i <= e_low`
  - `rho_i = (e_high - e_i)/(e_high - e_low)`, `e_low < e_i < e_high`
  - `rho_i = 0`, `e_i >= e_high`
- Adaptive variance:
  - `R_i = sat(R0_i/(rho_i + epsilon), R_min, R_max)`
- Hard isolation:
  - `validWheel(i)` is true only if:
    - `residualValid(i)` is true
    - `validGeom(i)` is true
    - `eSlip(i)` is finite
    - `rho_i > rho_hard`
- WSS internal fusion:
  - `q_i = 1/R_i`
  - `alpha_i = q_i / sum(q_i)` for valid wheels
  - `vxWssTrack = sum(alpha_i * vxWheel_i)` for valid wheels
  - `RwssEquivalent = 1 / sum(q_i)` for valid wheels
  - If no valid wheel: `wssValid = false`; no forced fusion, no pseudo `vxWssTrack` replacement, no wheel average.

## Parameter sources
- `e_low`, `e_high`, `rho_hard`, `R0`, `R_min`, `R_max`, `epsilon` from `p`.

## Exception handling
- Input size checks enforce 4x1 vectors in fixed wheel order.
- Non-finite `eSlip`, `residualValid=false`, or `validGeom=false` skip normal confidence update.
- `R_i` is clipped by saturation to finite bounds, guaranteeing finite positive variance.
- `wss_track_builder` additionally filters invalid inputs:
  - `isfinite(vxWheel)` and `isfinite(Rwheel)` and `Rwheel > 0`
  - invalid wheels produce `alphaWheel=0`
- `wssValid=false` branch never computes fusion; returns `vxWssTrack = NaN` and bounded finite `RwssEquivalent` fallback.
- No use of `eval`, `assignin`, `global`, `FIFO`, `degradedMode`, KF/PWI blocks, IMU-only timer, or GPS.

## Static checks
- Wheel order fixed `[FL, FR, RL, RR]`.
- `rhoWheel` constrained to `[0,1]`.
- `Rwheel` bounded and finite (via `sat` and init `R_max`).
- Invalid-wheel `alphaWheel` entries are zero.
- Valid-wheel weights are normalized by construction.
- No fusion executed when `wssValid = false`.
- No `Vx_true`/`GPS` usage introduced.
- MATLAB implementation not yet executed in this environment.
