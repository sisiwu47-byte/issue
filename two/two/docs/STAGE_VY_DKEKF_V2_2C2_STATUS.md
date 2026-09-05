# STAGE VY DK-EKF V2.2-C2 STATUS

## Conclusion

**V2.2-C2 DK-EKF 0.20-S RUNTIME PREFLIGHT ACCEPTED**

The one authorized 0.20 s CarSim runtime completed. Runtime outputs were
replayed offline through the frozen `vy_dkekf_baseline_step` with exact
same-timestamp alignment and zero x/P/diag difference. No second simulation
or 16 s run was performed.

## Runtime environment

```text
PROGDIR = D:\carsim\CarSim2021.0_Prog\
DATADIR = D:\carsim\CarSim2021.0_Data\
solver  = D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
actual  = D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
historical G:\ request = 0
working directory = project model directory
```

The script verified the D-drive simfile macros, DLL, Solver_SF library,
existing 10-channel input log, and four required runtime logs before calling
`sim()`. The model and CarSim dataset/simfile were not saved or modified.

## Runtime completion and rate

```text
StopTime             = 0.20 s
simulation completed = 1
simCalled            = 1
carSimRun             = 1

dkekf_u_log1 samples    = 203 solver/input log samples
dkekf_x_log1 samples    = 21 committed samples
dkekf_P_log1 samples    = 21 committed samples
dkekf_diag_log1 samples = 21 committed samples

committed t start/end = 0 / 0.20000000000000001 s
dt min                = 0.0099999999999999811 s
dt mean               = 0.01 s
dt max                = 0.010000000000000009 s
duplicate timestamp   = 0
missing 100-Hz hit    = 0
actual 100 Hz         = 1
```

The input Mux is also logged at intermediate solver times. All 21 committed
x/P/diag timestamps had an exact, zero-delta input-log sample. No timestamp
shift or interpolation was used.

## Reset and initialization

```text
reset high count      = 1
reset high timestamps = [0]
initial x prior       = [20 0 0]
initial P prior       = diag([0.1 0.1 0.1])
true Vy used          = NO
```

The first logged x/P are the posterior produced by the first core step at
t=0, not the bare reset prior.

## Ay 20 Hz evidence

```text
doAyUpdate high count      = 5
doAyUpdate high timestamps = [0 0.05 0.1 0.15 0.2]
AyUpdateApplied count      = 5
AyUpdateApplied timestamps = [0 0.05 0.1 0.15 0.2]
applied only when enabled  = 1
sequence exact             = 1
```

## Numeric and covariance evidence

```text
x dimension    = 3
P dimension    = 3x3
diag dimension = 7
all x finite   = 1
all P finite   = 1
all diag finite = 1

max(abs(P-P'))       = 0
minimum P eigenvalue = 6.180339295124853e-05
P11 min/max = [6.1803397852704141e-05 9.9900199600724325e-05]
P22 min/max = [0.00010003615722255692 0.00040884410362461389]
P33 min/max = [0.00012175241261285108 0.00033496808177292447]
```

No covariance clipping or output modification was performed.

## Offline exact replay

Alignment rule:

At each function-call timestamp `t_k`, adapter `Outputs` reads the current
committed DWork state (or the reset prior), consumes the actual logged input
at exactly `t_k`, calls the frozen core once, and exposes that candidate
posterior. `Update` then commits the same candidate at the end of that hit.
Therefore replay step k is compared directly with runtime sample k; no shift
is permitted or applied.

The input log contained near-coincident pre/post event solver samples around
t=0.01. The exact timestamp sample at t=0.01 was used; its time delta was
zero. The pre-event t=0.01-eps sample was not shifted onto the function-call
hit.

```text
maxAbsXDiff    = 0
maxAbsPDiff    = 0
maxAbsDiagDiff = 0
acceptance     = <= 1e-12 PASS
timestamp shift applied = 0
```

Thus:

**ONE 100-HZ FUNCTION-CALL HIT = ONE COMMITTED DK-EKF STATE ADVANCE: PASS**

There is no double-step execution.

## Fairness

```text
TRUE VY ONLINE          = NO
true Vx                 = measurement only
Ax_IMU                  = prediction input
AVz_IMU                 = measurement only
Ay_IMU                  = measurement only
shared state/P          = YES
output fusion           = NO
LifeSig                 = NO
adaptive fusion         = NO
```

## Runtime gates

```text
simulationCompleted          = 1
carSimRan                    = 1
logsAligned100Hz             = 1
resetOnceAtZero              = 1
resetInitializationSemantics = 1
ay20HzRuntimeSequence        = 1
outputDimensions             = 1
numericFinite                = 1
covarianceValid              = 1
exactReplay                  = 1
oneHitOneCommittedAdvance    = 1
fairness                     = 1
hashIntegrity                = 1

gates = 13/13
passed = 1
```

## Integrity hashes

The formal target before and after runtime:

```text
E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15
target unchanged = 1
```

| Frozen/reference file | SHA-256 |
|---|---|
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` |

All frozen/reference hashes and `model/simfile.sim` were unchanged.

## Warnings and execution discipline

- Eight pre-existing Derivative block warnings occurred and were nonfatal.
- No ApplicationService warning was observed in the saved simulation console.
- The unique runtime completed and its evidence was saved.
- The initial batch later exited nonzero because the first analyzer assumed
  the higher-rate u-log must have the same sample count as x/P/diag. This was
  an evidence-tool error after CarSim termination, not a runtime failure.
- The analyzer was corrected and run without `sim()`; the runtime was not
  repeated. Final analysis-only exit code was 0.

## Files created

- `model/run_vy_dkekf_v2_2c2_preflight.m`
- `model/analyze_vy_dkekf_v2_2c2_preflight.m`
- `results/vy_dkekf_v2_2c2_preflight.mat`
- `docs/STAGE_VY_DKEKF_V2_2C2_STATUS.md`

No target, core, wrapper, adapter, D-EKF, K-KF, Q/R, fusion, LifeSig, or
adaptive-logic file was modified.

READY FOR V2.2-D DK-EKF NOMINAL VALIDATION
