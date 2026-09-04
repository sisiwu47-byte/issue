# VX-V1 Current Interface Snapshot

- Snapshot date: 2026-09-02
- Evidence class: `CURRENT_IMPLEMENTATION`
- Formal runtime represented: `NO`

## Input contract

`est_u` is an 18-by-1 vector. Wheel order is `[FL, FR, RL, RR]`.

| Indices | Signal | Unit | Current use |
|---|---|---|---|
| 1:4 | wheel angular speed | rad/s | WSS candidates |
| 5:8 | actual wheel steering angle | rad | 4WIS geometry correction |
| 9 | `Ax` | m/s^2 | detector and independent IMU propagation |
| 10:11 | `Ay`, `Az` | m/s^2 | unpacked, not used by current Vx core |
| 12:13 | `AVx`, `AVy` | rad/s | unpacked, not used by current Vx core |
| 14 | `AVz` | rad/s | geometry correction and validity |
| 15:17 | reserved/raw specific force | mixed | not used by current Vx core |
| 18 | reset | logical/double | clears all persistent states |

No `Vx_true`, `Vy_true`, true slip, GPS/GNSS, friction coefficient, or wheel torque is an online estimator input.

## Actual 38-output contract

This table follows executable assignments in `model/longitudinal_velocity_estimator.m`, not the older `specs/signal_interface.md` table.

| Index | Actual current signal | Unit |
|---:|---|---|
| 1 | `vx_hat` / Fusion | m/s |
| 2 | `P_fused` | (m/s)^2 |
| 3 | WSS local-KF state `xW` | m/s |
| 4 | WSS local covariance `PW` | (m/s)^2 |
| 5 | IMU local-KF state `xI` | m/s |
| 6 | IMU local covariance `PI` | (m/s)^2 |
| 7 | raw WSS combined track `vxWssTrack` | m/s |
| 8:11 | wheel speed candidates FL/FR/RL/RR | m/s |
| 12:15 | finite-window increment errors FL/FR/RL/RR | m/s |
| 16:19 | final wheel confidence FL/FR/RL/RR | 1 |
| 20:23 | adaptive wheel covariance FL/FR/RL/RR | (m/s)^2 |
| 24:27 | final valid-wheel flags FL/FR/RL/RR | 0/1 |
| 28 | WSS channel valid | 0/1 |
| 29 | IMU channel valid | 0/1 |
| 30:31 | `alphaW`, `alphaI` | 1 |
| 32 | WSS-equivalent measurement covariance | (m/s)^2 |
| 33 | all-wheel-invalid/IMU-only duration | s |
| 34 | WSS local-KF gain `KW` | 1 |
| 35 | estimator updated on this 1-kHz call | 0/1 |
| 36 | slip window ready | 0/1 |
| 37 | `QW` diagnostic | (m/s)^2/update |
| 38 | 100-Hz update counter | count |

## Known contract conflict

The legacy specification/test mapping labels outputs 7, 32, 34, and 37 as `PWI`, `allWheelInvalid`, `degradedMode`, and `condPhi`. The executable mapping above instead exports `vxWssTrack`, `RwssEquivalent`, `KW`, and `QW`.

- `CURRENT_IMPLEMENTATION`: executable mapping above.
- `HISTORICAL_VALIDATION`: A-H result consumers use columns 1, 3, 5, 16:19, 24:31, 35, and 38, which remain usable.
- `FORMAL_CURRENT_VERSION_VALIDATION`: must use this snapshot and must not interpret columns 7/32/34/37 using the legacy labels.

The legacy `tests/test_longitudinal_velocity_estimator.m` also points to a non-current `matlab/` source location and contains 81 old-index/path references. It is excluded from the formal VX-V1 gate. The replacement static contract test is `tests/test_vx_v1_current_contract.m`.

## Simulink connection state

Static inspection of `model/vx.slx` shows:

- MATLAB Function block SID 313, function `longitudinal_velocity_estimator_simulink(u)`: `Commented=on`.
- `vx_hat` Goto block SID 274 (`Goto7`): `Commented=on`.
- Associated legacy estimator Demux/Goto diagnostic branch is commented.
- Active `From` blocks with Goto tag `Vx` still consume the CarSim/model Vx signal.
- No static evidence establishes `vx_hat -> controller u(33)` or `vx_hat -> active Vy estimator`.

Therefore current downstream connection status is `NOT_CONNECTED / MANUAL_GUI_CONFIRMATION_REQUIRED`.

