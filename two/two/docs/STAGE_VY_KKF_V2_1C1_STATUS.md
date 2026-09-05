# STAGE VY K-KF V2.1-C1 STATUS

- Date: 2026-08-26
- Stage: V2.1-C1 16 s Nominal Runtime Validation
- Scope: one nominal case only
- Terra execution: **COMPLETED**
- Sol independent acceptance: **PASSED — V2.1-C1 NOMINAL VALIDATION COMPLETED**
- Q/R/P0 tuning: **NOT PERFORMED**
- Fusion / LifeSig / V2.2: **NOT STARTED**

## A. Created files

- `matlab/run_vy_kkf_v2_1c1_nominal.m`
- `matlab/analyze_vy_kkf_v2_1c1_nominal.m`
- `results/vy_kkf_v2_1c1_nominal.mat`
- `results/vy_kkf_v2_1c1_nominal.csv`
- eight PNG files under `results/plots/vy_kkf_v2_1c1_nominal/`
- `docs/STAGE_VY_KKF_V2_1C1_STATUS.md`

No `.slx`, K-KF core/wrapper, V2.1-B validator/test, sensor, scheduler,
reset, D-EKF, controller, or CarSim configuration file was modified.

## B. Actual simulation command

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "addpath(fullfile(pwd,'matlab')); try, r=run_vy_kkf_v2_1c1_nominal(); r=analyze_vy_kkf_v2_1c1_nominal(); catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end; exit(0)"
```

The run used exactly one nominal case:

```text
StopTime              = 16 s
test_speed            = 20 m/s
test_steer_amplitude  = 0.02 rad
test_steer_frequency  = 0.4 Hz
```

CarSim runtime output identified:

```text
Use vehicle solver: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
Termination at simulation time = 16 s.
```

The active `model/simfile.sim` used `D:\carsim` and contained no historical
`G:\carsim` request. Runtime paths were session-only and restored afterward.
Normal CarSim `LastRun` output followed the existing simfile destination under
`D:\carsim\CarSim2021.0_Data\Results`; no dataset definition or configuration
file was edited by the C1 scripts.

## C. Runtime completion and 100 Hz evidence

```text
simulation completed  = 1
sim called            = 1
CarSim run            = 1
runtime error id      = empty
runtime error message = empty

kkf_u_log1 samples    = 1601
kkf_x_log1 samples    = 1601
kkf_P_log1 samples    = 1601
kkf_diag_log1 samples = 1601
true Vx raw samples   = 16001
true Vy raw samples   = 16001
```

The four K-KF logs have identical, strictly increasing timestamps.

```text
t_start               = 0 s
t_end                 = 16 s
dt_min                 = 0.0099999999999997868 s
dt_median              = 0.0099999999999997868 s
dt_max                 = 0.010000000000001563 s
unique dt count       = 1 at tolerance 1e-12
abnormal dt count     = 0
```

True Vx and true Vy were logged from frozen target blocks `Gain38` and
`Gain11`, respectively, at the 1 kHz plant rate. They were linearly
interpolated onto the actual K-KF timestamps only for offline analysis. True Vy
was not connected to or used by the online K-KF.

## D. Reset evidence

Runtime-only logging on the reset output port produced:

```text
reset samples         = 1601
reset high count      = 1
reset high timestamps = 0 s
```

The logging configuration existed only in loaded memory. The target model was
closed using `close_system(...,0)`.

## E. Full-duration primary metrics

All samples from `t=0` through `t=16 s`, including the initial transient, are
included.

| Signal | RMSE (m/s) | MAE (m/s) | Bias (m/s) | MaxAbsError (m/s) |
|---|---:|---:|---:|---:|
| Vx | 0.000104509894579409 | 0.000102031925798951 | 0.000102031480658644 | 0.000177016946850017 |
| Vy | 0.797460298986494 | 0.688034079028083 | -0.688034079028083 | 1.36648988303603 |

No transient-excluded metric is used as a replacement primary metric.

## F. Offline observability partition

The partition signal is the actual online K-KF input `AVz_IMU`, not CarSim
true yaw rate. The threshold is an offline diagnostic only.

| Region | Definition | Samples | Fraction | Vy RMSE | Vy MAE | Vy Bias | Vy MaxAbsError |
|---|---|---:|---:|---:|---:|---:|---:|
| low-r | `abs(AVz_IMU) <= 0.01` | 1516 | 0.946908182386009 | 0.800404926462758 | 0.691967916039843 | -0.691967916039843 | 1.36648988303603 |
| higher-r | `abs(AVz_IMU) > 0.01` | 85 | 0.0530918176139913 | 0.742984365793811 | 0.617872938912441 | -0.617872938912441 | 1.36429943737655 |

## G. NIS characterization

The scalar-measurement chi-square 95% reference is diagnostic only.

```text
reference             = 3.8414588
NIS mean              = 0.000285979359686523
NIS median            = 0.000283149358322085
NIS 95th percentile   = 0.000479964184974465
NIS maximum           = 0.000822542353733466
fraction <= reference = 1
fraction > reference  = 0
```

No measurement gating or covariance adaptation was added.

## H. Runtime/covariance sanity

```text
all x finite                = 1
all P finite                = 1
all diagnostic finite       = 1
all offline truth finite    = 1
max P asymmetry             = 0
minimum P eigenvalue        = 6.180339888013307e-05
minimum P11                 = 6.180339898352174e-05
maximum P11                 = 9.990019960084589e-05
minimum P22                 = 0.101000000047671
maximum P22                 = 1.65527382938442
P11 positive throughout     = 1
P22 positive throughout     = 1
```

The complete state, covariance, diagnostic, truth, error, partition, and reset
arrays are retained in the MAT file for independent Sol recomputation.

## I. CSV evidence

`results/vy_kkf_v2_1c1_nominal.csv` contains 1601 rows and these exact 21
columns:

```text
time,Ax_IMU,Ay_IMU,AVz_IMU,Vx_meas,Vx_K,Vy_K,Vx_true,Vy_true,
Vx_error,Vy_error,P11,P12,P21,P22,NIS,obs_metric,innovation_vx,
K11,K21,low_r_flag
```

`Vy_true` is an offline-validation-only column. A read-back comparison against
the MAT arrays found only decimal serialization differences at approximately
`5e-14` or smaller and no low-r flag mismatch.

## J. Eight plot paths

1. `results/plots/vy_kkf_v2_1c1_nominal/01_kkf_inputs.png`
2. `results/plots/vy_kkf_v2_1c1_nominal/02_vx_estimate_vs_true.png`
3. `results/plots/vy_kkf_v2_1c1_nominal/03_vx_error.png`
4. `results/plots/vy_kkf_v2_1c1_nominal/04_vy_estimate_vs_true_offline.png`
5. `results/plots/vy_kkf_v2_1c1_nominal/05_vy_error.png`
6. `results/plots/vy_kkf_v2_1c1_nominal/06_covariance_diagonal.png`
7. `results/plots/vy_kkf_v2_1c1_nominal/07_nis.png`
8. `results/plots/vy_kkf_v2_1c1_nominal/08_observability_partition.png`

All eight are separate, non-empty PNGs. Their stored image dimensions are
approximately 1410-1454 by 946-998 pixels.

## K. Frozen hashes

All before/after SHA-256 values are identical to the frozen baselines.

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

The target remained 491105 bytes with an unchanged filesystem modification
time. `model/simfile.sim` was also hash-identical before/after.

## L. Warnings

Eight pre-existing Derivative blocks emitted the known warning class:

```text
Derivative, Derivative1, Derivative12, Derivative2,
Derivative3, Derivative4, Derivative6, Derivative7
```

The warnings did not terminate the simulation. No model change was made to
suppress them.

## M. Preliminary baseline findings

- Vx stayed approximately 20 m/s (`19.9820` to `20.0000` m/s) and the isolated
  true-Vx measurement update produced very small Vx error.
- Offline true Vy was numerically zero throughout this run (approximately
  `-2.8e-15` to `1.7e-16` m/s), while K-KF Vy drifted from near zero to
  approximately `-1.3665 m/s`. The full-duration Vy bias is therefore almost
  the negative of its MAE.
- `AVz_IMU` ranged from approximately `-0.00711` to `0.01710 rad/s`; 94.69% of
  samples were in low-r. The higher-r partition contains only 85 samples and
  differs only modestly in aggregate Vy error, so this single run provides
  limited evidence about strongly excited lateral observability.
- P remained finite, symmetric, and positive definite, but P22 increased to
  approximately `1.6553`, consistent with weak lateral-state constraint in
  this largely low-r dataset.
- NIS is far below the scalar 95% reference for every sample. This is a
  baseline consistency finding only; no Q/R inference or tuning action was
  taken in C1.

## N. Sol independent acceptance

Sol independently reviewed the run/analyze sources, read the raw numeric MAT
datasets, recomputed the CSV/MAT metrics, inspected all eight figures, and
recomputed the frozen hashes.

- The 16 s CarSim/Simulink runtime completed and produced 1601 aligned K-KF
  samples at an actual 0.01 s median interval.
- Reset was high exactly once, at `t=0`.
- State, covariance, diagnostics, and offline truth remained finite. The
  covariance remained symmetric and positive definite, although `P22` grew
  from about `0.1010` to `1.6553`, showing weak lateral-state constraint.
- Vx isolation tracking was very close because true Vx is the temporary direct
  measurement. Vy showed substantial negative drift and a full-duration RMSE
  of about `0.7975 m/s` against offline true Vy.
- The higher-r subset had a modestly lower Vy RMSE (`0.7430 m/s`) than the
  low-r subset (`0.8004 m/s`), but it contained only 85 samples. This single
  run does not establish a clear high-r improvement or isolate causality.
- The results support an observability limitation and a possible online
  Ay/AVz/process-model mismatch. The single largely low-r case is insufficient
  to identify an algorithm structural defect or prescribe Q/R changes.
- NIS was far below the scalar 95% reference for every sample. This is a
  consistency finding for the direct true-Vx isolation update, not a tuning
  authorization.

Sol decision: **V2.1-C1 NOMINAL VALIDATION COMPLETED**. This closes the nominal
baseline characterization and permits only the next planning step; parameters
are not optimized, and V2.2 has not started.

## Mandatory declarations

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

TRUE Vy WAS USED FOR OFFLINE VALIDATION ONLY.

TRUE Vx IS TEMPORARILY USED ONLY FOR K-KF ISOLATION.

NO D-EKF OUTPUT WAS USED BY K-KF.

NO Q/R TUNING WAS PERFORMED.

NO FUSION WAS PERFORMED.

V2.2 WAS NOT STARTED.

## Stop-state

**V2.1-C1 NOMINAL VALIDATION COMPLETED.**
