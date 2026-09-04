# V2.3-A Parallel D-EKF / K-KF Architecture Audit

- Date: 2026-08-27
- Scope: architecture audit only
- Simulation / CarSim: **NOT RUN**
- Model or estimator modification: **NONE**
- Fusion, LifeSig, switching, or third feedback track: **NONE**
- Sol decision: **V2.3-A PARALLEL D/K ARCHITECTURE ACCEPTED FOR INTEGRATION**

## 1. Recommended source model and target boundary

Recommended source model:

```text
model/vx_vy_kkf_v2_1g_steer.slx
SHA-256:
59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E
```

Recommended future target name:

```text
model/vx_vy_parallel_dk_v2_3.slx
```

V2.3-B must create a new copy. It must not save or modify the source model.
The source is recommended because it already contains the frozen K-KF
integration, independent 100-Hz K scheduler/reset/logs, the Ax-IMU
prerequisite, and the validated genuine-steering plant path. V2.3-B therefore
needs to add only the frozen D-EKF V1.17 track and its independent boundary.

`model/vx_vy_dkekf_v2_2d_nominal.slx` is not recommended as the source. It
contains K-KF, genuine steering, and the accepted DK-EKF baseline. Using it
would require deleting or disabling DK-EKF to avoid an unauthorized third
track. That expands the modification surface and creates ambiguity about which
estimator is active. `model/vx_vy_dekf_v1_17.slx` remains the exact structural
donor/reference for the D-EKF Function-Call subsystem, scheduler, rate
transition, wrapper expression, A20 mode, and log demultiplexing.

The architecture contains exactly two online estimators:

```text
common CarSim plant and physical sensors
              |
              +--> frozen D-EKF V1.17
              |
              +--> frozen K-KF V2.1

D outputs --> logs only
K outputs --> logs only
```

## 2. A. D/K interface table

| Item | Frozen D-EKF V1.17 | Frozen K-KF V2.1 |
|---|---|---|
| State | `x_D=[Vy;r]` | `x_K=[Vx;Vy]` |
| State memory | wrapper persistent `x` | wrapper persistent `xState` |
| Covariance | independent `P_D`, 2x2 | independent `P_K`, 2x2 |
| Covariance memory | wrapper persistent `P` | wrapper persistent `PState` |
| Primary function | `vy_dynamic_ekf_v1_17(w,20)` | `vy_kinematic_kf(u,z,resetFlag)` |
| Control/input vector | `u_D=[Vx_true;delta_FL;delta_FR;delta_RL;delta_RR]` | `u_K=[Ax_IMU;Ay_IMU;AVz_IMU]` |
| Measurement vector | `z_D=[Ay_IMU;AVz_IMU]` | `z_K=Vx_true` scalar measurement |
| True Vx role | exogenous physical Vx used directly in slip angles, tire forces, lateral prediction, and Ay prediction; D-EKF has no Vx state | Vx measurement only; initializes `Vx_K` and performs scalar Vx updates |
| Ax role | no D-EKF input | 100-Hz kinematic prediction input |
| Ay role | measurement; applied jointly with r every fifth hit in frozen A20 mode | 100-Hz kinematic prediction input |
| AVz/r role | measurement at every 100-Hz hit | 100-Hz kinematic prediction input |
| Steering role | four road-wheel angles in rad, order `[FL,FR,RL,RR]` | no estimator input |
| Prediction rate | 100 Hz | 100 Hz |
| Vx update rate | none; Vx is exogenous input | 100 Hz |
| r update rate | 100 Hz | no measurement update; r is an IMU process input |
| Ay assimilation/prediction rate | A20: 20 Hz measurement assimilation | Ay process input at 100 Hz |
| Scheduler | independent Function-Call Generator, `0.01 s`, one iteration | independent Function-Call Generator, `0.01 s`, one iteration |
| Reset | when D wrapper persistent storage is empty or `modeCode` changes; frozen A20 mode is `20`; initializes `[Vy;r]=[0;0]`, `P_D=0.1*I2`, counter 0 | explicit independent `resetFlag`; first-hit Step high at `t=0`, low from `0.01 s`; initializes `[z_Vx;0]`, `P_K=diag([0.1,0.1])` before processing the current hit |
| Deterministic run-start rule | runtime harness must `clear vy_dynamic_ekf_v1_17` before a new run; no shared reset line and no wrapper modification | retain frozen K reset Step; clearing K wrapper is optional pre-run hygiene, not a substitute for the reset gate |
| Canonical state output | `[Vy_hat_D;r_hat_D]` | `[Vx_hat_K;Vy_hat_K]` |
| Frozen raw output | width 69: state `y(1:2)`, posterior P diagonal `y(3:4)`, 65 diagnostics `y(5:69)`; full posterior P is embedded at `y(46:49)` | state width 2, full P `2x2`, diagnostics width 5 |
| Existing log contract | `est_u_log1`, `est_z_log1`, `est_y_log1`, `est_P_log1`, `est_diag_log1` | `kkf_u_log1`, `kkf_x_log1`, `kkf_P_log1`, `kkf_diag_log1` |
| Online output consumer in parallel target | logs only | logs only |

D-EKF V1.17 exact measurement behavior is preserved: prediction and r update
occur on every 100-Hz call; when A20 `useAy=true`, the frozen core performs the
joint two-dimensional `[Ay;r]` update, and otherwise performs the scalar r-only
update. V2.3-B must not rewrite this as sequential scalar updates.

## 3. B. Shared-signal routing table

Common physical signal fan-out is allowed. Each estimator must receive the
physical source independently; no branch may originate from another
estimator's state, covariance, diagnostic, innovation, or gain.

| Shared physical signal | D-EKF branch | K-KF branch | Required routing policy |
|---|---|---|---|
| `Ax_IMU` | no consumer | `u_K(1)` | fan-out is unnecessary; connect only to K from the frozen 100-Hz Ax sensor |
| `Ay_IMU` | `z_D(1)` | `u_K(2)` | one sensor output may branch to both; D measurement scheduling remains internal A20 while K consumes the same sample for 100-Hz prediction |
| `AVz_IMU` | `z_D(2)` | `u_K(3)` | one sensor output branches to both; neither branch may use the other estimator's r estimate |
| true Vx, `Gain38=1/3.6`, m/s | `u_D(1)` through a D-owned 100-Hz boundary | scalar `z_K` through the existing K-owned Vx Rate Transition | branch at the physical Vx source; use separate D/K rate-boundary blocks; never substitute `Vx_hat_K`, `Vy_hat_D`, or a DK-EKF state |
| four-wheel steering, rad `[FL,FR,RL,RR]` | `u_D(2:5)` | no consumer | branch from the same pre-CarSim rad command that drives the plant; preserve wheel order; do not convert deg back to rad and do not add another `180/pi` |
| true Vy | no consumer | no consumer | offline truth logging only; no online connection or initialization |
| reset/lifecycle | D wrapper-internal empty/mode reset | K explicit first-hit reset | not a shared physical signal; keep independent and verify separately |

The plant steering boundary remains the validated path:

```text
road-wheel command [rad]
-> existing Gain22 = 180/pi
-> CarSim IMP_STEER_* [deg]
```

D-EKF receives the common command on the rad side. K-KF receives no steering
input. This is common physical-signal fan-out, not estimator coupling.

## 4. C. Independence gate table

These are mandatory V2.3-B static/compile gates. V2.3-A accepts the
architecture only with all rows enforced; V2.3-B must produce actual model
evidence for them.

| Gate | Accepted architecture rule | V2.3-B evidence required |
|---|---|---|
| Exactly two tracks | only frozen D-EKF and frozen K-KF | block/reference scan; DK-EKF and any third estimator absent |
| D state memory independent | D persistent `x` belongs only to `vy_dynamic_ekf_v1_17` | no Data Store/shared persistent wrapper with K |
| K state memory independent | K persistent `xState` belongs only to `vy_kinematic_kf` | no Data Store/shared persistent wrapper with D |
| Covariances independent | `P_D` and `P_K` remain separate 2x2 objects | no signal line, assignment, or covariance conversion between tracks |
| Schedulers independent | separate 100-Hz Function-Call Generators | two actual local scheduler-to-trigger connections, each `0.01 s`, one iteration |
| Resets independent | D empty/mode lifecycle and K first-hit reset remain distinct | no common reset wire; D mode fixed at A20; K reset structure unchanged |
| D output to K input | forbidden | upstream trace of every K input contains no D block/log/output |
| K output to D input | forbidden | upstream trace of every D input contains no K block/log/output |
| Covariance exchange | forbidden | source/text scan and line trace show no P_D/P_K exchange |
| Pseudo measurement | forbidden | D receives only physical Vx/steering/Ay/AVz; K receives only physical Ax/Ay/AVz/Vx |
| Weighted sum | forbidden | no Sum/Gain/MATLAB logic combining D and K outputs |
| Fixed/adaptive weights | forbidden | no weight parameters, reliability weights, or covariance-based weighting |
| Switching | forbidden | no Manual/Multiport/Switch selecting D versus K output for feedback or publication |
| LifeSig/observability gate | forbidden | diagnostic signals may be logged only; no online gating consumer |
| Third feedback track | forbidden | DK-EKF V2.2 and any other estimator absent from the new target |
| True Vy online | forbidden | true-Vy source has logs/offline consumers only and no path to either estimator |
| Shared sensor fan-out only | allowed | common branches originate only at physical sensor/Vx/steering sources |
| Independent logs | required | D and K state/P/diagnostic/input logs have distinct variable names and sources |
| Estimator outputs | logs only | neither D nor K output reaches controller, plant, sensor, the other estimator, or a combined online output |

Offline post-run comparison of D and K logs is allowed in a later validation
stage. It must not be represented as an online third track or fed back into the
model.

## 5. V2.3-B integration scope

The only permitted next stage is:

**V2.3-B — PARALLEL D/K SIMULINK INTEGRATION**

V2.3-B may create only a new parallel target and the minimum builder,
validator, tests, result evidence, and status documentation needed to prove:

- frozen D-EKF V1.17 integration;
- frozen K-KF V2.1 integration;
- common physical sensor/Vx/steering fan-out;
- independent scheduler and reset semantics;
- independent input/state/P/diagnostic logs;
- static and compile-only architecture gates;
- source and frozen hash preservation;
- default validation path does not rewrite a frozen model.

V2.3-B must not implement or introduce:

- fusion or a combined estimate;
- fixed or adaptive weights;
- LifeSig, adaptive reliability, or observability switching;
- pseudo measurements;
- estimator-to-estimator signals;
- a DK-EKF/third feedback track;
- simulation or CarSim unless separately authorized by a later stage.

## 6. Frozen integrity reviewed in V2.3-A

| File | SHA-256 | Status |
|---|---|---|
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged / frozen |
| `model/vy_dynamic_ekf_v1_17.m` | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged / frozen |
| `model/vy_dynamic_ekf_step_v17.m` | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` | unchanged / frozen |
| `model/vy_dynamic_ekf_step_v13.m` | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` | unchanged / frozen dependency |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged / frozen |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged / frozen source |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged / frozen |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged / frozen |

## 7. Final decision

The source model, exact frozen interfaces, common physical-signal fan-out,
state/covariance memory separation, scheduler/reset separation, logging
boundary, and all forbidden coupling paths are sufficiently defined for a
minimal new-target integration stage. No architecture ambiguity requires
fusion or estimator modification.

**V2.3-A PARALLEL D/K ARCHITECTURE ACCEPTED FOR INTEGRATION**

Next stage only:

**V2.3-B — PARALLEL D/K SIMULINK INTEGRATION**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS FROZEN.

DK-EKF V2.2 BASELINE IS FROZEN AND IS NOT A THIRD PARALLEL TRACK.

TRUE Vy ONLINE = NO.

NO FUSION WAS IMPLEMENTED.

NO MODEL WAS MODIFIED.

NO SIMULATION OR CARSIM RUN WAS PERFORMED.
