# VX-V1 Formal Validation Case Manifest

- Manifest version: `VX-V1-2026-09-02`
- Formal runtime count: `0`
- Allowed formal cases: `N1`, `N2`, `T1`, `D1`, `D2`
- Historical A-H role: `HISTORICAL_VALIDATION / ENGINEERING_MATRIX_ONLY`
- All windows below are frozen before runtime. Changing a window requires a new manifest version and must occur before rerunning that case.

## Common runtime contract

- Model candidate: `model/vx.slx`, after manual estimator activation and downstream-routing review.
- Stop time: 16.0 s.
- CarSim/model step: 0.001 s.
- Estimator true update: 0.01 s.
- Scored samples: estimator updates only (`est_y(:,35)>0.5`), with truth interpolated to the same time axis.
- Common overall evaluation window: `[0.60, 15.99] s`.
- Metrics for WSS, IMU, Fusion: RMSE, MAE, MaxAbs, Bias.
- Required provenance: case ID, manifest version, model/code/parameter hashes, parameter struct, timestamps, fixed windows, complete `est_u`, complete `est_y`, and CarSim Vx truth.

## Case definitions

| Case | Unique scientific question | Frozen command/scenario | Frozen windows | Required extra signals | Status |
|---|---|---|---|---|---|
| N1 | Does normal steady-state basic accuracy hold? | Straight, zero steering, approximately 60 km/h, model-default high-adhesion road; no deliberate wheel fault | overall `[0.60,15.99]` | Vx truth, Ax, wheel speeds/angles | `READY_AFTER_GUI` |
| N2 | Under combined longitudinal acceleration/deceleration, do WSS/IMU/Fusion remain valid? | Straight high-adhesion combination: approximately 60→100 km/h over `[3,8]`, then 100→60 km/h over `[8,13]` | baseline `[0.60,3.00)`; acceleration `[3.00,8.00)`; braking `[8.00,13.00)`; settle `[13.00,15.99]` | Vx truth, Ax | `READY_AFTER_GUI` |
| T1 | Does longitudinal speed estimation work during genuine steering dynamics on the 4WIS-capable platform? | 20 m/s initial speed; accepted genuine-steering candidate: 0.02 rad, 0.4 Hz, active `[3,13]`; actual four wheel angles must be logged | baseline `[0.60,3.00)`; steering `[3.00,13.00)`; settle `[13.00,15.99]` | Vx truth, steering command, four actual wheel angles, AVz, Ax | `BLOCKED_REAR_STEER_CONFIRMATION` |
| D1 | During drive slip, does wheel health decrease, WSS lose weight, and recover after the excitation ends? | Low adhesion candidate `mu=0.3`; approximately 40→70 km/h drive excitation on `[3,8]`; affected wheels intended RL/RR | baseline `[0.60,3.00)`; degradation `[3.00,8.00)`; recovery `[8.00,12.00)`; post-recovery `[12.00,15.99]` | affected-wheel rho/valid, alphaW/I, drive torque/command | `READY_AFTER_GUI` |
| D2 | During braking lock, is the same protection active and does real recovery occur? | Low adhesion candidate `mu=0.3`; approximately 70→40 km/h braking excitation on `[3,8]`; affected wheels intended RL/RR | baseline `[0.60,3.00)`; degradation `[3.00,8.00)`; recovery `[8.00,12.00)`; post-recovery `[12.00,15.99]` | affected-wheel rho/valid, alphaW/I, brake torque/command | `READY_AFTER_GUI` |

`model-default high adhesion` is deliberately not assigned an invented coefficient. The final runtime metadata must save the actual CarSim road dataset/coefficient.

## Degradation/recovery metric definitions

These definitions are frozen before runtime:

1. **Degradation RMSE**: RMSE within the case's fixed degradation window for WSS, IMU, and Fusion.
2. **Mean alpha_W**: mean `est_y(:,30)` within the fixed degradation window.
3. **Detection response time**: first estimator-update time at or after degradation start for which any affected wheel satisfies `rho_i <= rho_hard` or `validWheel_i == 0`, minus degradation start.
4. **Wheel unlock/recovery time**: first estimator-update time at or after recovery start for which all affected wheels are valid and remain valid for 10 consecutive updates, minus recovery start.
5. **alpha_W baseline**: median alpha_W in the fixed baseline window.
6. **alpha_W recovery 90% / 95%**: first time after recovery start when alpha_W reaches 90% / 95% of the baseline value and remains above that threshold for 10 consecutive updates, minus recovery start.
7. A missing event is reported as `NaN / NOT_OBSERVED`; the window must not be moved afterward.

## Formal result schema

Each runtime must save `results/vx_formal_validation/VX_<CASE>_formal.mat` containing scalar struct `R` with:

- `R.metadata.caseId`, `manifestVersion`, `formalRuntime=true`, `generatedAt`;
- `modelFile`, `modelSha256`, `estimatorSha256`, `parameterSha256`, complete parameter snapshot;
- `R.windows` exactly matching this manifest;
- `R.affectedWheelIndices` (`[3 4]` for D1/D2 unless preregistered otherwise);
- `R.time`, `R.vxTrue`, `R.Ax`, `R.steeringInput`, `R.estU`, `R.estY`;
- road/dataset identity and command settings actually used.

## Frozen thesis-table plan

### VX-TABLE-01 — Representative-condition estimation performance

- Rows: `N1`, `N2`, `T1`, `D1`, `D2` only.
- Thesis columns: WSS RMSE, IMU RMSE, Fusion RMSE, Fusion MAE, Fusion MaxAbs.
- The formal analysis also preserves MAE, MaxAbs and Bias for all three estimators in `VX_TABLE01_full_metrics.csv`; those extra columns are evidence, not a mandate to enlarge the thesis table.

### VX-TABLE-02 — Degradation/recovery dynamics

- Rows: `D1`, `D2` only.
- Columns: degradation-phase WSS/IMU/Fusion RMSE, degradation mean alpha_W, detection response time, wheel unlock/recovery time, alpha_W baseline recovery 90%, alpha_W baseline recovery 95%.
- No A-H row is allowed in either thesis table.
