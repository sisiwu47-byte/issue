# STAGE VY K-KF V2.1-E STATUS

- Date: 2026-08-26
- Stage: V2.1-E Higher-Yaw Excitation Validation
- Sol execution and acceptance: **COMPLETED**
- Requested case: `16 s`, `20 m/s`, `0.04 rad`, `0.4 Hz`
- Actual excitation finding: **HIGHER-YAW EXCITATION STILL INSUFFICIENT**
- Q/R/P0 tuning or online bias correction: **NOT PERFORMED**

## A. Created files

- `matlab/run_vy_kkf_v2_1e_highyaw.m`
- `matlab/analyze_vy_kkf_v2_1e_highyaw.m`
- `results/vy_kkf_v2_1e_highyaw.mat`
- `results/vy_kkf_v2_1e_highyaw.csv`
- six PNG files under `results/plots/vy_kkf_v2_1e_highyaw/`
- `docs/STAGE_VY_KKF_V2_1E_STATUS.md`

No `.slx`, K-KF, sensor, scheduler, reset, D-EKF, controller, or CarSim
configuration file was modified.

## B. Actual runtime command

The one authorized run was launched through a hidden MATLAB COM session using:

```powershell
$m = New-Object -ComObject Matlab.Application
$m.Execute("cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'matlab')); r=run_vy_kkf_v2_1e_highyaw(); r=analyze_vy_kkf_v2_1e_highyaw();")
```

The run report recorded exactly one configured case:

```text
StopTime             = 16 s
test_speed           = 20 m/s
test_steer_amplitude = 0.04 rad
test_steer_frequency = 0.4 Hz
case count            = 1
```

CarSim output identified the authorized D-drive solver and termination at
simulation time 16 s.

## C. Runtime and reset evidence

```text
simulationCompleted = 1
simCalled           = 1
carSimRun           = 1

K-KF sample counts  = 1601 / 1601 / 1601 / 1601
t_start              = 0 s
t_end                = 16 s
dt_min               = 0.0099999999999997868 s
dt_median            = 0.0099999999999997868 s
dt_max               = 0.010000000000001563 s
abnormal dt count    = 0
strictly increasing  = 1
four logs aligned    = 1

reset high count     = 1
reset high timestamp = 0 s
```

## D. Runtime stability

```text
state/P/diagnostics/truth finite = 1
P11 range = [6.180339898352174e-05, 9.990019960084589e-05]
P22 range = [0.101000000047671, 1.65527382938442]
P22 final = 1.65527382938442
max P asymmetry = 0
minimum P eigenvalue = 6.180339888013307e-05
```

Eight known pre-existing Derivative-block warnings occurred and did not
terminate the simulation. No model change was made to suppress them.

## E. Online Vx and Vy metrics

| Signal | RMSE | MAE | Bias | MaxAbsError | Final error |
|---|---:|---:|---:|---:|---:|
| Vx | 0.000104510 | 0.000102032 | 0.000102031 | 0.000177017 | — |
| Vy | 0.797460 | 0.688034 | -0.688034 | 1.366490 | -1.366490 |

True Vy was used only to calculate these offline metrics.

## F. Observability partitions

The partition used the actual online `AVz_IMU` input.

| Region | Samples | Fraction | Vy RMSE | Vy MAE | Vy Bias | Vy MaxAbsError |
|---|---:|---:|---:|---:|---:|---:|
| `abs(AVz_IMU) <= 0.01` | 1516 | 94.6908% | 0.800405 | 0.691968 | -0.691968 | 1.366490 |
| `abs(AVz_IMU) > 0.01` | 85 | 5.3092% | 0.742984 | 0.617873 | -0.617873 | 1.364299 |

The realized AVz range was `[-0.00710862, 0.01710204] rad/s`. Despite the
recorded `0.04 rad` configuration, the realized higher-r fraction is identical
to accepted C1 (`5.3092%`). The intended excitation increase was therefore not
realized in the logged K-KF input. Its upstream cause was not investigated or
modified in this constrained stage.

## G. K21 observability evidence

| Region | mean(abs(K21)) | median(abs(K21)) | max(abs(K21)) |
|---|---:|---:|---:|
| low-r | 0.257820 | 0.223436 | 0.863772 |
| higher-r | 0.479824 | 0.440144 | 1.124746 |

```text
max(abs(K21)), all samples       = 1.124745829050854
corr(abs(AVz_IMU), abs(K21))     = 0.576803622954027
higher-r / low-r mean ratio      = 1.861080714221739
```

Within the available samples, stronger yaw is associated with stronger
Vx-measurement-to-Vy covariance coupling. This does not establish an E-vs-C1
increase because the realized yaw distribution did not change.

## H. B0 exact replay gate

```text
threshold      = 1e-12
maxAbsXDiff    = 0
maxAbsPDiff    = 0
maxAbsDiagDiff = 0
gate passed    = 1
```

The E B0 replay exactly reproduced the online state, covariance, and
diagnostics.

## I. B3 de-biased replay

Only the authorized B3 replay was run:

```text
Ay_test = Ay_IMU - 0.02
r_test  = AVz_IMU - 0.005
Ax      = original Ax_IMU
```

```text
Vy RMSE            = 0.016145189926330 m/s
Vy MAE             = 0.013179209402929 m/s
Vy Bias            = -0.007968766838818 m/s
Vy MaxAbsError     = 0.035595164576753 m/s
final Vy error     = 0.017691640706263 m/s
P22 final/max      = 1.691216039616611
RMSE reduction     = 97.9754239870187%
final drift reduction = 98.7053222328324%
```

No B1, B2, or B4 replay was run.

## J. C1 versus E

| Evidence | C1 | E |
|---|---:|---:|
| configured steering amplitude | 0.02 rad | 0.04 rad |
| realized higher-r fraction | 5.3092% | 5.3092% |
| online Vy RMSE | 0.797460 | 0.797460 |
| online final Vy error | -1.366490 | -1.366490 |
| online P22 final/max | 1.655274 | 1.655274 |
| B3 Vy RMSE | 0.016145 | 0.016145 |
| B3 final Vy error | 0.017692 | 0.017692 |
| B3 P22 final | 1.691216 | 1.691216 |

The E higher-r fraction is `1.0x` C1, online P22 final reduction is `0%`, and
B3 RMSE changes only at floating-point roundoff. The recorded E behavior is
therefore effectively the C1 behavior, not a realized higher-yaw case.

## K. P22 conclusion

P22 was not more constrained than C1. It ended at the exact accepted C1 value
and continued increasing throughout the run. B3 remained accurate but also
ended with P22 approximately `1.6912`; removing deterministic bias does not
remove the weak-observability covariance growth.

## L. NIS

```text
mean                 = 0.000285979359687
median               = 0.000283149358322
95th percentile      = 0.000479964184974
maximum              = 0.000822542353733
fraction > 3.8414588 = 0
```

No tuning or measurement gate was derived from NIS.

## M. Frozen hashes

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

All before/after hashes, target model byte count/mtime, and `simfile.sim` hash
are unchanged.

## N. Mechanism conclusion

- The result continues to support **deterministic sensor bias plus weak
  observability**: B3 removes approximately 98% of the error while P22 remains
  weakly constrained.
- The within-run K21 statistics support yaw-dependent covariance coupling, but
  the requested higher-yaw input was not realized, so this stage cannot test
  whether more excitation would reduce P22 or increase correction strength
  relative to C1.
- A configuration/excitation-path mismatch is possible because the stored
  command changed while the realized K-KF inputs and outputs did not. The cause
  is not attributed here and no model/configuration change was authorized.
- There is no new evidence of an algorithm structural issue, and no Q/R tuning
  inference is authorized.

## Figures

1. `results/plots/vy_kkf_v2_1e_highyaw/01_avz_threshold.png`
2. `results/plots/vy_kkf_v2_1e_highyaw/02_vy_online_vs_true.png`
3. `results/plots/vy_kkf_v2_1e_highyaw/03_vy_online_error.png`
4. `results/plots/vy_kkf_v2_1e_highyaw/04_k21_vs_avz.png`
5. `results/plots/vy_kkf_v2_1e_highyaw/05_p22_comparison.png`
6. `results/plots/vy_kkf_v2_1e_highyaw/06_vy_online_b3_true.png`

All six figures were independently inspected by Sol.

## Mandatory declarations

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

TRUE Vy WAS USED FOR OFFLINE VALIDATION ONLY.

TRUE Vx REMAINED THE V2.1 ISOLATION MEASUREMENT.

NO D-EKF OUTPUT WAS USED.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE BIAS CORRECTION WAS IMPLEMENTED.

NO FUSION WAS PERFORMED.

V2.2 WAS NOT STARTED.

## Stop-state

**V2.1-E HIGHER-YAW VALIDATION COMPLETED**

**HIGHER-YAW EXCITATION STILL INSUFFICIENT**
