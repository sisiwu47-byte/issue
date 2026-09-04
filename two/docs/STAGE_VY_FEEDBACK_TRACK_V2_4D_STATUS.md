# V2.4-D Feedback / Propagation Standalone Runtime Validation Status

## 1. Final decision

**V2.4-D FEEDBACK / PROPAGATION STANDALONE RUNTIME VALIDATION BLOCKED**

The one authorized 0.20-s standalone simulation completed. The initial reset
and one-sample feedback-delay events passed, but the commanded runtime reset at
`t=0.15 s` was not consumed by the F-track. A second simulation is prohibited
and was not performed.

## 2. Actual files

| File | Role | SHA-256 |
|---|---|---|
| `model/run_vy_feedback_track_v2_4d_standalone.m` | single-runtime runner | `CEB148BD32286FEEB71A110EC67C231DBD7059D096ABA67E454C95EBCBA5B8E6` |
| `model/analyze_vy_feedback_track_v2_4d_standalone.m` | saved-MAT exact-replay analyzer | `AFF9B8301F9156AF659ED10EDB437FE8D735C6F2000B1DE9E588F6229DC3753F` |
| `results/vy_feedback_track_v2_4d_standalone.mat` | runtime and analysis evidence | `5B1376DCA2884636E675B5AAAD2266707D136DFF85C804B921E209A49D9A5C8C` |
| `docs/STAGE_VY_FEEDBACK_TRACK_V2_4D_STATUS.md` | this final blocked status | recorded after creation |

No SLX, core, S-function, D/K/DK-EKF, fusion, or LifeSig file was modified.

## 3. Runtime execution evidence

```text
simCalled = 1
simulationCompleted = 1
CarSim run = 0
Vy_F samples = 21
P_F samples = 21
diag_F samples = 21
time start/end = 0 / 0.20000000000000001 s
dt min/mean/max = 0.0099999999999999811 / 0.01 / 0.010000000000000009 s
duplicate timestamps = 0
missing hits = 0
actual mean rate = 100 Hz
```

Runtime dimensions and numeric integrity passed:

```text
Vy_F = scalar per hit
P_F = scalar per hit
diag_F = 3x1 per hit
Vy_F finite = YES
P_F finite = YES
diag_F finite = YES
P_F nonnegative = YES
covariance clipping performed = NO
```

The S-function parameters read before the simulation were:

```text
Ts = 0.01 s
Vy_F0 = 0
P0_F = 0.5
Q_F = 0.0025
```

`P0_F` and `Q_F` remain **TEST-ONLY / UNTUNED / UNFROZEN**.

## 4. Commanded deterministic sequence

The runner supplied seven common-timestamp, 21-sample From Workspace matrices.
The commanded sequence passed its construction checks:

```text
Ay = 1.0 at all hits
AVz = 0.1 at all hits
Vx = 20.0 at all hits
feedback-valid command indices = [1 9 16]
reset command indices = [1 16]
t=0 feedback command = Vy 2.0, P 0.8
t=0.08 feedback command = Vy 1.0, P 0.25
t=0.15 feedback command = Vy 5.0, P 0.75
```

These are the runner's commanded workspace sequences. The validation copy did
not contain separate runtime logging immediately at each F-track input port.
Consequently, after the failed reset event, the saved MAT cannot independently
show whether the `t=0.15` pulse was omitted by From Workspace time evaluation or
missed at the F-track boundary execution hit.

## 5. Actual output event table

| time | reset command | current feedback-valid command | current feedback Vy/P command | Vy_F | P_F | prop_term | deltaVy | feedbackApplied |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.00 | 1 | 1 | 2.0 / 0.8 | 0 | 0.5 | 0 | 0 | 0 |
| 0.01 | 0 | 0 | 0 / 0.5 | -0.01 | 0.5025 | -1 | -0.01 | 0 |
| 0.08 | 0 | 1 | 1.0 / 0.25 | -0.08 | 0.52 | -1 | -0.01 | 0 |
| 0.09 | 0 | 0 | 0 / 0.5 | 0.99 | 0.2525 | -1 | -0.01 | 1 |
| 0.10 | 0 | 0 | 0 / 0.5 | 0.98 | 0.255 | -1 | -0.01 | 0 |
| 0.15 | 1 | 1 | 5.0 / 0.75 | **0.93** | **0.2675** | **-1** | **-0.01** | 0 |
| 0.16 | 0 | 0 | 0 / 0.5 | **0.92** | **0.27** | **-1** | **-0.01** | 0 |

## 6. Passed runtime semantics

- Initial reset at `t=0`: **PASS** (`Vy_F=0`, `P_F=0.5`, `diag=[0;0;0]`).
- Initial-reset feedback rejection at `t=0.01`: **PASS**.
- Physical propagation diagnostics on accepted non-reset hits: **PASS**
  (`prop_term=-1`, `deltaVy=-0.01`).
- Current feedback non-direct-feedthrough at `t=0.08`: **PASS**.
- One-sample delayed feedback application at `t=0.09`: **PASS**
  (`Vy_F=0.99`, `P_F=0.2525`, `feedbackApplied=1`).
- Post-feedback continuation at `t=0.10`: **PASS**.
- Actual timestamps, dimensions, finite values, and P nonnegativity: **PASS**.
- Standalone independence (no D/K/DK-EKF, fusion, LifeSig, true Vy, or CarSim):
  **PASS**.

## 7. Failed runtime semantics

The runtime analyzer reported `19/23` gates true. The four failed gates were:

```text
runtimeResetPriority
resetClearsDelayedFeedback
exactReplay
oneHitOneCommit
```

At `t=0.15`, the expected reset output was `Vy_F=0`, `P_F=0.5`, and
`diag=[0;0;0]`. The actual output was the ordinary propagation result
`Vy_F=0.93`, `P_F=0.2675`, and `diag=[-1;-0.01;0]`. At `t=0.16`, the model
continued from that state instead of restarting from `Vy_F0/P0_F`.

Therefore the required runtime-reset priority and feedback-delay clearing were
not demonstrated.

## 8. Offline exact replay

The analyzer used the frozen `vy_feedback_propagation_step` at the same sample
index and timestamp, with no shift or compensation. Replay differences were:

```text
maxAbsVyDiff = 0.92999999999999994
maxAbsPDiff = 0.23249999999999998
maxAbsDiagDiff = 1
```

The mismatch begins at the commanded `t=0.15` reset. The analyzer did not shift
indices to manufacture a pass. Because exact replay failed, the combined
one-hit/one-commit gate cannot be accepted for the full event sequence even
though the 21 timestamps themselves are correct.

## 9. Exact blocker and evidence limit

The exact observed blocker is:

```text
THE COMMANDED t=0.15 RESET PULSE WAS NOT CONSUMED BY THE F-TRACK RUNTIME.
```

The initial reset proves that the frozen core/S-function reset branch can work.
The failure is confined to delivery/consumption of the later single-hit reset
event in the runtime stimulus path. With no boundary-input log in this already
completed simulation, more specific attribution would require new
instrumentation and another separately authorized runtime. Neither was done.

## 10. Hash integrity

| Item | Post-runtime SHA-256 | Result |
|---|---|---|
| Runtime validation model | `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A` | UNCHANGED |
| Accepted V2.4-C target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |
| Frozen F-track core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| Accepted F-track S-function | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | UNCHANGED |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |
| Frozen D-EKF V1.17 target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | UNCHANGED |
| Frozen K-KF target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | UNCHANGED |
| Frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | UNCHANGED |

All registered frozen D/K/DK-EKF core, wrapper, and adapter hashes also matched
their baselines.

## 11. Stop state

```text
authorized sim() count = 1
second sim() count = 0
CarSim count = 0
model modification after runtime = 0
rebuild count = 0
save_system count = 0
performance evaluation = 0
tuning = 0
```

V2.4-D remains blocked. V2.4-E is not authorized from this evidence.
