# V2.4-C Feedback / Propagation Simulink Integration Status

- Date: 2026-08-28
- Final decision: **V2.4-C FEEDBACK / PROPAGATION SIMULINK INTEGRATION ACCEPTED**
- Static integration gates: **52/52 PASS**
- Compiled-interface/timing gates: **12/12 PASS**
- Compile called / passed / terminated: **1 / 1 / 1**
- `sim()` / Start / CarSim runtime: **NOT CALLED / NOT CALLED / NOT RUN**
- Parallel D/K target modification: **NONE**
- Fusion / LifeSig / tuning: **NONE**

## 1. Created artifacts

| File | Role | SHA-256 |
|---|---|---|
| `model/vy_feedback_propagation_simulink_sfun.m` | Level-2 MATLAB S-function state/delay boundary | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` |
| `model/vx_vy_feedback_track_v2_4.slx` | standalone F-track integration target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` |
| `model/build_vy_feedback_track_v2_4c.m` | deterministic standalone-target builder | `DBEFF7E0E794F2CC4DF2C7BF74F67D6FC05618A58BF21C3F9B491390C48A7DE8` |
| `model/validate_vy_feedback_track_v2_4c_integration.m` | no-run static/compile-only validator | `2C7E4620DA881A4F63766A9D615A774B5839DFE2F7E332414E3934570735E43A` |
| `results/vy_feedback_track_v2_4c_integration_gates.mat` | build/static/compiled evidence | `CACA3EB2CF9763E0E11E5A65F088482194193C305E59BAB640E8B93FA58BC519` |
| `docs/STAGE_VY_FEEDBACK_TRACK_V2_4C_STATUS.md` | this status | computed after creation |

No other `.slx`, wrapper, estimator, runtime MAT, fusion file, or LifeSig file
was created.

## 2. Frozen mathematical boundary

The S-function calls the accepted core exactly once in `Outputs`:

```matlab
[Vy_F,P_F,diag_F] = vy_feedback_propagation_step( ...
    Vy_prev_DWork,P_prev_DWork, ...
    Ay_current,AVz_current,Vx_current, ...
    Vy_feedback_z1_DWork,P_feedback_z1_DWork,feedback_valid_z1_DWork, ...
    reset_current,Ts,Vy_F0,P0_F,Q_F);
```

The core remains byte/hash unchanged:

```text
model/vy_feedback_propagation_step.m
SHA-256 = 80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF
```

This is the actual and accepted V2.4-B core hash. The wrapper contains no copy
of `Ay-r*Vx`, Ts
multiplication, feedback propagation branch, or `P_base+Q_F` mathematics. It
only manages DWork, parameters, inputs, outputs, reset, and commit timing.

## 3. Standalone target structure

The target contains only:

- one independent `F-Track 100Hz Scheduler`;
- one function-call subsystem `F-Track 100Hz`;
- the Level-2 MATLAB S-function boundary;
- deterministic scalar interface sources for Ay, AVz, Vx, current feedback
  state/covariance/valid, and reset;
- scalar `Vy_F`, scalar `P_F`, and vector `diag_F` output interfaces.

It contains no D-EKF, K-KF, DK-EKF, CarSim/`vs_sf`, weighted sum, estimator
selector, fusion, LifeSig, reliability logic, online true Vy, or final Vy.

## 4. DWork ownership and initialization

The wrapper defines exactly five independent scalar-double discrete states:

| DWork | Name | Role | InitializeConditions |
|---:|---|---|---:|
| 1 | `Vy_prev` | previous committed F state | `Vy_F0` |
| 2 | `P_prev` | previous committed F covariance | `P0_F` |
| 3 | `Vy_feedback_z1` | one-sample delayed feedback state | `Vy_F0` |
| 4 | `P_feedback_z1` | one-sample delayed feedback covariance | `P0_F` |
| 5 | `feedback_valid_z1` | one-sample delayed availability flag | `0` |

All have dimension 1, `DatatypeID=0` (`double`), real complexity, and
`UsedAsDiscState=true`. No Unit Delay, Memory, second Delay block, shared
Data Store, global state, or base-workspace estimator state exists. State,
covariance, and valid flag have the same one-hit delay depth.

## 5. Direct-feedthrough contract

| Input port | Signal | DirectFeedthrough | Current Outputs use |
|---:|---|---:|---|
| 1 | `Ay_IMU` | true | YES |
| 2 | `AVz_IMU` | true | YES |
| 3 | `Vx_source` | true | YES |
| 4 | `Vy_feedback_current` | false | NO |
| 5 | `P_feedback_current` | false | NO |
| 6 | `feedback_valid_current` | false | NO |
| 7 | `reset` | true | YES |

`Outputs` reads DWork 3/4/5 and never reads current feedback ports 4/5/6.
Current feedback is read only in `Update`. Therefore the implemented
dependency is exactly:

```text
feedback_current(k)
-> Update(k) capture into z1 DWork
-> Outputs/propagation at k+1
```

No current-sample feedback-to-output path or algebraic loop exists. A future
integration must not add another delay without a separately accepted
architecture change.

## 6. Outputs and Update semantics

### Outputs

`Outputs` calls the frozen stateless core using the current DWork snapshot,
physical inputs, reset, and dialog parameters. It writes only output ports:

```text
Vy_F
P_F
diag_F = [prop_term;deltaVy;feedbackApplied]
```

It performs zero DWork assignments. Repeated output evaluation cannot advance
the committed F state or feedback history.

### Update

For a non-reset hit, `Update` performs one assignment for each committed F
state/covariance and one atomic capture of each current feedback signal:

```text
Output Vy_F -> Vy_prev
Output P_F  -> P_prev
current state/P/valid -> matching z1 DWorks
```

For a reset hit, it writes `Vy_F0/P0_F`, initializes delayed feedback state/P
to the same pair, clears delayed valid to zero, and returns before reading or
capturing current feedback. Thus current feedback at a reset hit cannot become
valid feedback on the next hit.

Structural acceptance:

```text
Outputs state commit count = 0
Update Vy/P commit count per hit = 1
Feedback-delay triple capture per non-reset hit = 1
```

## 7. Scheduler and function-call structure

| Gate | Actual | Result |
|---|---|---|
| Scheduler MaskType | `Function-Call Generator` | PASS |
| configured sample time | `0.01 s` | PASS |
| iterations | `1` | PASS |
| trigger type | `function-call` | PASS |
| scheduler source | local F scheduler | PASS |
| D/K scheduler connection | none | PASS |

The Function-Call subsystem and wrapper compiled without sample-time conflict.
The persisted compiled CST structures contain a detected `0.01-s` period; the
configured scheduler evidence is `[0.01 0]`. The raw API representation is
preserved in the MAT report rather than flattened or invented.

## 8. Static gate evidence

Final no-write static result:

```text
V2_4C_VALIDATE|static=52/52|compileCalled=0|compile=0|compiled=0/0|term=0|passed=1|sim=0|carsim=0
V24C_STATIC_OK
exit code = 0
```

The first static pass reported `50/52`. The two false gates were evidence-tool
false negatives:

1. `noCarSim` enumerated S-function BlockTypes too narrowly even though the
   read-only SLX XML showed exactly one `M-S-Function` with
   `FunctionName=vy_feedback_propagation_simulink_sfun` and no `vs_sf`;
2. `diagnosticOrderingFixed` required ordering comments in the wrapper rather
   than verifying the frozen core ordering plus unmodified `diag_F` pass-through.

Only the static validator was corrected. The target, wrapper, builder, and
core were not modified or rebuilt. The affected static layer was then rerun
and passed 52/52 before compile authorization.

## 9. Compile/update and compiled interfaces

Exactly one standalone compile/update call was made after 52/52 static PASS:

```text
V2_4C_VALIDATE|static=52/52|compileCalled=1|compile=1|compiled=12/12|term=1|passed=1|sim=0|carsim=0
V24C_COMPILE_OK
exit code = 0
```

The MAT evidence records:

```text
compileCalled            = 1
compilePassed            = 1
terminationReached       = 1
compiledEvidenceCaptured = 1
```

Compiled interface acceptance:

| Port | Semantic shape | Compiled width | Compiled type | Result |
|---|---:|---:|---|---|
| Ay | scalar | 1 | double | PASS |
| AVz | scalar | 1 | double | PASS |
| Vx | scalar | 1 | double | PASS |
| current feedback Vy | scalar | 1 | double | PASS |
| current feedback P | scalar | 1 | double | PASS |
| current feedback valid | scalar/double-compatible | 1 | double | PASS |
| reset | scalar/double-compatible | 1 | double | PASS |
| output `Vy_F` | scalar | 1 | double | PASS |
| output `P_F` | scalar | 1 | double | PASS |
| output `diag_F` | configured `3x1` | 3 | double | PASS |

Static dimension configuration plus compiled width/type evidence establishes
the fixed `3x1 double` diagnostic contract. Compilation emitted no dimension,
type, function-call, sample-time, or algebraic-loop failure.

## 10. Parameter policy

The four explicit dialog parameters are:

```text
Ts     = 0.01 s
Vy_F0  = 0 m/s
P0_F   = 0.5 (m/s)^2       TEST-ONLY
Q_F    = 0.0025 (m/s)^2/step TEST-ONLY
```

The model description and build report mark P0_F/Q_F as
`TEST-ONLY / UNTUNED / UNFROZEN`. These values were reused solely for
integration/compile evidence. No tuning, performance optimization, runtime
acceptance, or nominal parameter freeze occurred.

## 11. Frozen integrity

Before/after hash gates passed for the mathematical core and every registered
D-EKF, K-KF, DK-EKF, and parallel target dependency. Key values:

| Frozen object | SHA-256 | Result |
|---|---|---|
| F mathematical core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| D-EKF model | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| K-KF base model | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| K core/wrapper | `3786646E...DA2244 / F242CB75...414D4` | unchanged |
| DK-EKF model | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |

The standalone target remained byte/hash unchanged across both static and
compile validators. No `save_system` was called outside the explicit builder.

## 12. Execution discipline

- Builder: exactly once, exit 0.
- Static validator: first evidence scan 50/52; validator-only correction;
  affected static layer rerun once to 52/52.
- Compile/update: exactly once after 52/52, exit 0.
- Simulation/Start/CarSim: zero calls.
- A later read-only MAT display command failed before loading evidence because
  its explicit Chinese-path `cd` was misdecoded. It did not load a model,
  compile, simulate, or alter evidence and was not retried.
- The visible MATLAB process predates this stage (start time 2026-08-27) and
  was not created by these completed batch sessions; no new orphan was left.

## 13. Required acceptance answers

1. Core remained bit/hash unchanged: **YES**.
2. F state/P memory is independent: **YES**.
3. Feedback state/P/valid has exactly one common delay: **YES**.
4. Current feedback is non-direct-feedthrough: **YES**.
5. Reset clears feedback delay: **YES**.
6. Outputs performs zero state commits: **YES**.
7. Update performs one state/P commit per hit: **YES**.
8. 100-Hz compile semantics holds: **YES**.
9. Compiled dimensions/types are correct: **YES**.
10. Any D/K dependency exists: **NO**.
11. Fusion/LifeSig exists: **NO**.
12. Q_F/P0_F tuning was performed: **NO**.

## 14. Scope boundary

V2.4-C validates implementation structure and compile/interface semantics
only. It does not claim runtime reset sequencing, actual feedback one-hit
delay, multi-step recurrence, exact replay, or numerical performance inside
Simulink. Those remain for V2.4-D standalone runtime validation.

## 15. Final decision

**V2.4-C FEEDBACK / PROPAGATION SIMULINK INTEGRATION ACCEPTED**

STATE / COVARIANCE MEMORY INTEGRATION ACCEPTED.

ONE-SAMPLE FEEDBACK DELAY ARCHITECTURE ACCEPTED.

CURRENT FEEDBACK IS NON-DIRECT-FEEDTHROUGH.

ONE-HIT / ONE-COMMIT STRUCTURE ACCEPTED.

FROZEN MATHEMATICAL CORE WAS NOT MODIFIED.

NO D/K COUPLING WAS INTRODUCED.

NO FUSION WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

Q_F AND P0_F REMAIN TEST-ONLY / UNTUNED / UNFROZEN.

NO SIMULATION OR CARSIM RUNTIME WAS PERFORMED.

READY FOR V2.4-D FEEDBACK / PROPAGATION STANDALONE RUNTIME VALIDATION
