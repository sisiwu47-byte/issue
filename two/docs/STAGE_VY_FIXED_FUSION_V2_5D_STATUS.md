# V2.5-D Fixed-Weight Three-Track Runtime Preflight Status

## Stage decision

**V2.5-D FIXED-WEIGHT THREE-TRACK RUNTIME PREFLIGHT PASSED**

One and only one authorized 0.20-s shared CarSim runtime was executed. The saved runtime was then analyzed without another simulation. Runtime gates are **28/28 PASS**.

## Created artifacts

- `model/run_vy_fixed_fusion_v2_5d_preflight.m`
- `model/analyze_vy_fixed_fusion_v2_5d_preflight.m`
- `results/vy_fixed_fusion_v2_5d_preflight.mat`
- `docs/STAGE_VY_FIXED_FUSION_V2_5D_STATUS.md`

No model or SLX file was created, rebuilt, modified, or saved.

## Runtime command and CarSim context

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); run_vy_fixed_fusion_v2_5d_preflight;"
```

Runtime evidence:

```text
MATLAB exit code       = 0
simulation completed   = YES
CarSim runtime         = PASS
StopTime               = 0.20 s
working directory      = D:\UsersData\桌面\two\model
active simfile         = D:\UsersData\桌面\two\model\simfile.sim
active solver          = D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
G: request             = NO
runtime type           = real CarSim runtime, not compile-only
```

The known full-target compile-only limitation was not retried.

## Actual fixed-weight and F parameters

```text
alpha_D = 0.33333333333333331
alpha_K = 0.33333333333333331
alpha_F = 0.33333333333333331
sum     = 1

F Ts    = 0.01 s
Vy_F0   = 0
P0_F    = 0.5
Q_F     = 0.0025000000000000001
```

The weights remain **TEST-ONLY / NOT SELECTED / NOT TUNED / NOT FROZEN**. `P0_F` and `Q_F` remain **TEST-ONLY / UNTUNED / UNFROZEN**.

## Shared runtime timestamps

| Stream | Samples | Start | End | dt min | dt mean | dt max | Duplicates | Missing |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| D | 21 | 0 | 0.20 | 0.0099999999999999811 | 0.01 | 0.010000000000000009 | 0 | 0 |
| K | 21 | 0 | 0.20 | 0.0099999999999999811 | 0.01 | 0.010000000000000009 | 0 | 0 |
| F | 21 | 0 | 0.20 | 0.0099999999999999811 | 0.01 | 0.010000000000000009 | 0 | 0 |
| fusion | 21 | 0 | 0.20 | 0.0099999999999999811 | 0.01 | 0.010000000000000009 | 0 | 0 |

```text
D vs K max timestamp difference      = 0
D vs F max timestamp difference      = 0
D vs fusion max timestamp difference = 0
same index / same timestamp           = YES
```

## D-EKF runtime evidence

- Samples: 21; base execution: 100 Hz
- Reset count: 1 at `t=0`
- Ay-update count: 5 at `0, 0.05, 0.10, 0.15, 0.20 s`
- State/P/diagnostics finite: YES / YES / YES
- Maximum covariance asymmetry: `0`
- Minimum covariance eigenvalue: `0.00010611574183795094` (>0)

Exact frozen replay:

```text
max state diff = 0
max P diff     = 0
max diag diff  = 0
```

## K-KF runtime evidence

- Samples: 21; base execution: 100 Hz
- Reset count: 1 at `t=0`
- Ax/Ay/AVz process-input counts: `21 / 21 / 21`
- State/P/diagnostics finite: YES / YES / YES
- Maximum covariance asymmetry: `0`
- Minimum covariance eigenvalue: `6.1803402192475183e-05` (>0)

Exact frozen replay:

```text
max state diff = 0
max P diff     = 0
max diag diff  = 0
```

## F-track runtime evidence

- Samples: 21; base execution: 100 Hz
- Reset count: 1 at `t=0`
- `Vy_F`, `P_F`, `diag_F` finite: YES
- `P_F >= 0`: YES
- `feedbackApplied == 1` count: **0**
- `feedbackApplied` remained zero for the full runtime

Exact frozen replay:

```text
max Vy diff   = 0
max P diff    = 0
max diag diff = 0
```

F feedback validity remained fixed false. `Vy_FW` was not routed back to F. `FUSION-FEEDBACK LOOP CLOSED = NO`.

## Fusion runtime and exact replay

- `Vy_D`, `Vy_K`, `Vy_F`, and `Vy_FW`: 21 samples each
- Fusion input/output type: scalar double
- Output finite: YES
- No interpolation, timestamp shift, index shift, or one-sample compensation was used

```text
maxAbsFusionReplayDiff  = 0
RMSEFusionReplayDiff    = 0
meanAbsFusionReplayDiff = 0
```

Combined with the exact timestamps, this verifies that `Vy_FW(k)` uses `Vy_D(k)`, `Vy_K(k)`, and `Vy_F(k)` from the same logical current 100-Hz sample.

## Steering runtime boundary

The inherited genuine-steering path remained active:

```text
source       = G0 Steer Cmd Rad
source unit  = rad
conversion   = Gain22 = 180/pi
boundary unit= deg
FL/FR route  = Mux8 ports 2/4
RL/RR route  = Mux8 ports 6/8, zero
```

For the 0–0.20-s interval:

```text
command maxAbs       = 0.0096350734820343075 rad
converted maxAbs     = 0.55204904581898406 deg
deg/rad ratio        = 57.295779513082323
FL maxAbs            = 0.55204904581898406 deg
FR maxAbs            = 0.55204904581898406 deg
RL maxAbs            = 0
RR maxAbs            = 0
FL/FR vs converted   = 0 / 0 max difference
```

## One-hit / one-commit and independence

- D: one hit = one committed frozen D advance — PASS
- K: one hit = one committed frozen K advance — PASS
- F: one hit = one committed frozen F advance — PASS
- Fusion: stateless current-sample combination — PASS
- D state is not fed to K; K state is not fed to D
- F state enters fusion only
- `Vy_FW` is not fed back
- No covariance exchange or pseudo measurement
- No selector, adaptive alpha, reliability logic, or LifeSig
- Shared physical fan-out is not estimator coupling

## No covariance / DK-EKF / truth input

- Fusion inputs are exactly `Vy_D`, `Vy_K`, and `Vy_F`
- `P_D`, `P_K`, and `P_F` do not enter fusion
- `P_FW` does not exist
- No inverse-covariance weighting was calculated
- DK-EKF does not enter the fusion path
- True Vy is not an online D/K/F/fusion input
- No performance comparison or formal weight selection was performed

## Hash integrity

Target before and after:

```text
801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE
```

The fusion core, fusion wrapper, F core, parallel target, and all frozen D/K/DK-EKF/F dependencies matched their registered hashes before and after runtime. `targetHashUnchanged=1` and `allFrozenHashesUnchanged=1`.

## Required answers

1. Shared CarSim runtime succeeded? **YES**
2. D/K/F/fusion each produced 21 samples? **YES**
3. All four timestamps match sample-by-sample? **YES**
4. D ran at 100 Hz with five Ay updates? **YES**
5. K consumed Ax/Ay/AVz for 21/21/21 hits? **YES**
6. F ran at 100 Hz? **YES**
7. F `feedbackApplied` remained zero? **YES**
8. Fusion-feedback loop remains open? **YES**
9. Maximum fusion replay error? **0**
10. D replay errors? **0 / 0 / 0**
11. K replay errors? **0 / 0 / 0**
12. F replay errors? **0 / 0 / 0**
13. One-hit/one-commit passed? **YES**
14. `P_FW` exists? **NO**
15. Covariance fusion used? **NO**
16. DK-EKF fusion input used? **NO**
17. Weights tuned? **NO**
18. Adaptive weighting or LifeSig implemented? **NO**
19. Frozen hashes unchanged? **YES**
20. Evidence supports beginning a separate weight-selection/characterization stage? **YES — READY TO BEGIN A SEPARATE WEIGHT-SELECTION / CHARACTERIZATION STAGE.**

SHARED D/K/F/FUSION RUNTIME EXECUTION ACCEPTED.

D/K/F/FUSION TIMESTAMPS ARE EXACTLY ALIGNED.

D/K/F FROZEN EXECUTION SEMANTICS REMAIN UNCHANGED.

FIXED-WEIGHT FUSION EXACT CURRENT-SAMPLE REPLAY PASSED.

F-TRACK REMAINS STANDALONE.

NO FUSION-FEEDBACK LOOP IS CLOSED.

NO FUSED COVARIANCE IS GENERATED.

TEST-ONLY WEIGHTS REMAIN UNSELECTED / UNTUNED / UNFROZEN.

NO ADAPTIVE WEIGHTING WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

READY FOR V2.5-E FIXED-WEIGHT BASELINE WEIGHT-SELECTION ARCHITECTURE
