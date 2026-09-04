# STAGE VY K-KF V2.1-C0 STATUS

- Date: 2026-08-26
- Stage: V2.1-C0 Nominal Runtime Preflight
- Scope: one complete-target 0.20 s smoke test only
- Terra execution: **COMPLETED; PENDING SOL INDEPENDENT ACCEPTANCE**
- V2.1-C1 16 s nominal validation: **NOT STARTED**
- V2.2: **NOT STARTED**

## Runtime environment

The existing `model/simfile.sim` was used without modification. Its active
configuration resolves to:

```text
PROGDIR D:\carsim\CarSim2021.0_Prog\
DATADIR D:\carsim\CarSim2021.0_Data\
Solver library D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\Solver_SF.slx
Vehicle solver D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

The historical `G:\carsim` request was not present in the active simfile.
MATLAB paths were added only in the run process and restored on cleanup. No
solver path, CarSim configuration, dataset definition, or `.slx` was saved.
As part of normal CarSim execution, the existing simfile directed transient
`LastRun` output to its configured `D:\carsim\CarSim2021.0_Data\Results`
location; no CarSim configuration file was edited by the C0 scripts.

## Actual command

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "addpath(fullfile(pwd,'matlab')); try, r=run_vy_kkf_v2_1c0_preflight(); analyze_vy_kkf_v2_1c0_preflight(); catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end; exit(0)"
```

CarSim reported:

```text
Use vehicle solver: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
Termination at simulation time = 0.2 s.
```

## Runtime evidence

All four required Timeseries logs were read from the actual SimulationOutput.

| Log | Samples | Shape | Type | Start | End | Finite |
|---|---:|---:|---|---:|---:|---|
| `kkf_u_log1` | 21 | `21x4` | double | 0 | 0.20 | yes |
| `kkf_x_log1` | 21 | `21x2` | double | 0 | 0.20 | yes |
| `kkf_P_log1` | 21 | `2x2x21` | double | 0 | 0.20 | yes |
| `kkf_diag_log1` | 21 | `21x5` | double | 0 | 0.20 | yes |

All four timestamp vectors are identical and strictly increasing.

```text
dt_min                = 0.0099999999999999811 s
dt_median             = 0.010000000000000002 s
dt_max                = 0.010000000000000009 s
unique dt count       = 1 (tolerance 1e-12)
abnormal interval count = 0
```

Runtime-only signal logging on the loaded reset output port produced:

```text
reset samples         = 21
reset high count      = 1
reset high timestamps = 0 s
```

The logging flag was not saved to the model; the model was closed with
`close_system(...,0)`.

Covariance and state sanity evidence:

```text
all x finite          = 1
all P finite          = 1
all diag finite       = 1
max P asymmetry       = 0
all P diagonals > 0   = 1
minimum P eigenvalue  = 6.1803399082801004e-05
runtime error id      = empty
runtime error message = empty
```

This preflight does not evaluate Vy accuracy or make a performance claim.
`obs_metric` was logged but was not used as a formal C0 gate.

## Frozen hash evidence

All values are SHA-256; before and after values are identical.

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

For `model/vx_vy_kkf_v2_1.slx`, byte length remained `491105` and its
filesystem modification time was also unchanged. `model/simfile.sim` hash was
unchanged before/after runtime.

## Remaining risks and review boundary

- Simulink emitted pre-existing warnings for several Derivative blocks. They
  did not stop the 0.20 s run and were not addressed because model changes are
  outside C0 scope.
- This is only a short scheduling/logging/reset smoke test. It does not verify
  16 s nominal behavior, Vy RMSE, observability performance, or tuning.
- Final C0 acceptance belongs to Sol after independent inspection of the run
  script, result MAT, raw timestamps, reset trace, covariance evidence, and
  hashes.

## Mandatory declarations

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

K-KF RUNTIME EXECUTION WAS TESTED ONLY IN THE V2.1-C0 SHORT PREFLIGHT.

TRUE Vy WAS NOT USED BY THE ONLINE K-KF.

TRUE Vx IS TEMPORARILY USED ONLY AS THE V2.1 ISOLATION MEASUREMENT.

NO D-EKF OUTPUT WAS USED BY K-KF.

NO Q/R TUNING WAS PERFORMED.

V2.2 WAS NOT STARTED.

## Stop-state

**V2.1-C0 EXECUTION COMPLETE. READY FOR SOL INDEPENDENT ACCEPTANCE.**
