# VX-V1 Current Parameter Snapshot

- Snapshot date: 2026-09-02
- Evidence class: `CURRENT_IMPLEMENTATION`
- Formal runtime represented by this snapshot: `NO`
- Formal runtime count: `0`

## Source identity

| Artifact | SHA-256 |
|---|---|
| `model/longitudinal_velocity_estimator.m` | `68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107` |
| `model/estimator_default_params.m` | `09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4` |
| `model/longitudinal_velocity_estimator_simulink.m` | `93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061` |
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |

Every future formal result must save these hashes (or explicitly identify a reviewed successor snapshot). A result without a matching snapshot is not `FORMAL_CURRENT_VERSION_VALIDATION`.

## Current effective parameters

| Group | Parameter | Effective value | Unit | Source / note |
|---|---|---:|---|---|
| Timing | `Ts_sim` | 0.001 | s | model calling rate; static project contract |
| Timing | `Ts_est` | 0.01 | s | `estimator_default_params.m` |
| Timing | `updateEvery` | 10 | calls | hard-coded in top-level estimator |
| Timing | `Twindow` | 0.5 | s | parameter file |
| Timing | `Nwindow` | 50 | updates | parameter file |
| Geometry | `Rw` | 0.393 | m | vehicle/model parameter |
| Geometry | `a` | 1.18 | m | CG to front axle |
| Geometry | `b` | 1.77 | m | CG to rear axle |
| Geometry | `d` | 1.575 | m | track width |
| Assumption | `vyPrior` | 0 | m/s | hard-coded current Vx stage |
| Slip confidence | `e_low`, `e_high` | 0.15, 0.50 | m/s | parameter file |
| Absolute confidence | `eAbs_low`, `eAbs_high` | 0.15, 0.50 | m/s | parameter file |
| Hard isolation | `rho_hard` | 0.05 | 1 | parameter file |
| Recovery | `eDelta_recover`, `eAbs_recover` | 0.12, 0.12 | m/s | parameter file |
| Recovery | `Nrecover` | 30 | updates | 0.30 s at 100 Hz |
| Wheel covariance | `R0` | 1e-4 | (m/s)^2 | parameter file; project tuning |
| Wheel covariance | `R_min`, `R_max` | 1e-6, 1e4 | (m/s)^2 | numerical bounds |
| Geometry guard | `cos_delta_min` | 0.20 | 1 | parameter file |
| Local KF | `QW` | 1e-4 | (m/s)^2/update | WSS process variance |
| Local KF | `QI` | 2e-3 | (m/s)^2/update | IMU process variance |
| Initial covariance | `PW0`, `PI0`, `PWI0` | 1e-4, 1e-4, 0 | (m/s)^2 | parameter file |
| IMU | `biasAxCal` | 0.02178105 | m/s^2 | hard-coded in top-level estimator |
| IMU | `R_Ax` | 1.248708981650e-3 | (m/s^2)^2 | second assignment is effective |
| IMU covariance floor | `R_imuc_floor`, `R_imuc` | 1e-8, 1e-8 | (m/s)^2 | parameter file |
| Fusion adaptation | `a0`, `a1` | 0.10, 2.706246 | m/s^2 | hard-coded in top-level estimator |
| Fusion adaptation | `kA`, `kH` | 30, 18 | 1 | hard-coded current effective values |
| Degradation | `TimuOnlyMax` | 1.0 | s | parameter file |
| Sanity guard | `accelSanityMax` | 50 | m/s^2 | parameter file |

## Non-effective or ambiguous parameter declarations

- `R_Ax = 1.53664e-3` is overwritten immediately; it is not effective.
- `kD_fuse=0.08`, `kH_fuse=1.0`, and `dWI_cap=0.50` remain compatibility fields but do not set current `kA/kH`.
- `v_low=0.30 m/s` exists, but the current top level does not provide a traceable low-speed convergence-to-zero implementation. Treat it as declared but not verified behavior.
- Historical A-H MAT files contain no estimator-code hash or parameter snapshot. They must not inherit this snapshot by assumption.

