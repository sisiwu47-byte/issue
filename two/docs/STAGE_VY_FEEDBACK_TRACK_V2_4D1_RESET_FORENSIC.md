# V2.4-D1 Second-Reset Delivery Forensic Audit

## 1. Final decision

**V2.4-D1 SECOND-RESET DELIVERY ROOT CAUSE IDENTIFIED**

Attribution classification:

```text
A. RUNNER RESET DATA CONSTRUCTION DEFECT
```

The defect is specifically in the runner's floating-point time-axis
construction, not in the index assignment of the reset bit. The reset value at
index 16 is correctly one, but its stored From Workspace breakpoint occurs one
representable-double step after the corresponding F-track function-call hit.

No simulation, compile, rebuild, model modification, or `save_system` was
performed in V2.4-D1.

## 2. Fixed evidence and hashes

The audit used only the existing failed runtime evidence, its runner/analyzer,
the accepted runtime model, and the frozen S-function/core.

| Object | SHA-256 | Result |
|---|---|---|
| `model/vx_vy_feedback_track_v2_4d_runtime.slx` | `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A` | UNCHANGED |
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| `model/vy_feedback_propagation_simulink_sfun.m` | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | UNCHANGED |
| `model/vx_vy_feedback_track_v2_4.slx` | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |
| `model/vx_vy_parallel_dk_v2_3.slx` | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |

The fixed failed-runtime MAT remained unmodified.

## 3. Runner reset-data construction

The reset workspace variable is:

```text
ftrack_test_reset
```

The runner constructs:

```matlab
t = (0:params.Ts:0.20).';
inputs.reset = zeros(21,1);
inputs.reset(1) = 1;
inputs.reset(16) = 1;

simIn.setVariable('ftrack_test_reset',[inputs.time inputs.reset]);
```

Therefore the actual From Workspace data container is a `21x2 double` matrix:
the first column is time and the second column is reset. The saved components
are `inputs.time`, a `21x1 double`, and `inputs.reset`, a `21x1 double`.

The pulse is index-based. It does not use floating-point equality, rounding,
or `find(abs(t-x)<tol)`. The second reset is explicitly assigned at MATLAB
index 16.

### Stored reset samples (`format long g` equivalent)

| Index | Stored time double | Reset value |
|---:|---:|---:|
| 1 | `0` | 1 |
| 2 | `0.01` | 0 |
| 15 | `0.14000000000000001` | 0 |
| 16 | `0.15000000000000002` | 1 |
| 17 | `0.16` | 0 |
| 21 | `0.20000000000000001` | 0 |

Actual nonzero reset indices are exactly `[1 16]`.

## 4. Time-vector integrity

The commanded time vector itself is finite and monotonic:

```text
sample count = 21
strictly increasing = YES
duplicate count = 0
NaN/Inf = 0
dt min = 0.0099999999999999811
dt mean = 0.01
dt max = 0.010000000000000009
```

The nearest stored reset-data timestamp to decimal 0.15 is:

```text
index = 16
storedTime = 0.15000000000000002
storedTime - 0.15 = +2.7755575615628914e-17 s
reset = 1
```

## 5. Actual F-track hit discriminator

The failed runtime contains an actual F output at sample index 16:

```text
outputTime = 0.14999999999999999
outputTime - MATLAB literal 0.15 = 0
Vy_F = 0.92999999999999994
P_F = 0.26750000000000002
diag_F = [-1 -0.01 0]
```

The decisive comparison is between the two stored doubles:

```text
From Workspace reset breakpoint = 0.15000000000000002
F-track function-call hit        = 0.14999999999999999
breakpoint - F hit               = 2.7755575615628914e-17 s
```

Thus an actual 100-Hz F hit at nominal `t=0.15` exists, but it occurs before
the reset=1 breakpoint encoded by the runner.

## 6. Reset From Workspace block

Actual block parameters read from the runtime SLX were:

```text
full path = vx_vy_feedback_track_v2_4d_runtime/Reset First Hit
BlockType = FromWorkspace
VariableName = ftrack_test_reset
SampleTime = 0.01
Interpolate = off
OutputAfterFinalValue = Holding final value
ZeroCross = on
OutDataTypeStr = Inherit: auto
OutputDimensions parameter = not available on this block
OutputDataTypeStr parameter = not available on this block
```

The accepted D0 compiled-interface evidence resolves the corresponding F-track
input as scalar double.

## 7. Exact source semantics at the failed event

With interpolation disabled, the source holds the preceding data value until
the next stored breakpoint. For the three relevant F hits:

| Nominal hit | Exact relation to stored reset data | Source value selected |
|---:|---|---:|
| 0.14 | stored index 15 is reset=0 | 0 |
| 0.15 | hit `0.14999999999999999` is before reset=1 breakpoint `0.15000000000000002` | 0 |
| 0.16 | stored index 17 has already returned reset to 0 | 0 |

The reset=1 interval begins after the 0.15 F hit and ends at the next 0.16
breakpoint. No F-track function-call hit occurs inside that interval. The
single-hit reset pulse is therefore skipped completely.

The block's observed behavior is consistent with its configured
non-interpolating time-breakpoint semantics. This is why the primary
classification is runner time-data construction defect rather than a From
Workspace implementation defect.

## 8. Complete routing audit

The actual route is:

```text
vx_vy_feedback_track_v2_4d_runtime/Reset First Hit : Outport 1
  -> vx_vy_feedback_track_v2_4d_runtime/F-Track 100Hz : Inport 7
  -> vx_vy_feedback_track_v2_4d_runtime/F-Track 100Hz/reset : Outport 1
  -> vx_vy_feedback_track_v2_4d_runtime/F-Track 100Hz/
     F-Track Stateful Boundary : Inport 7
```

This is a direct source-to-subsystem-boundary-to-S-function route. There is no:

- Rate Transition;
- Zero-Order Hold block;
- Unit Delay or Memory;
- Data Type Conversion;
- Switch, Merge, or Selector;
- other intermediate sampling/state block.

Therefore classification C (intermediate routing/sample-time defect) is
excluded by the actual model structure.

## 9. Port mapping and scheduler

The wrapper has seven inputs and three outputs. Input 7 is explicitly declared:

```matlab
block.InputPort(7).DirectFeedthrough = true;  % reset
```

It is not the feedback-valid port; feedback-valid is input 6.

Scheduler evidence:

```text
path = vx_vy_feedback_track_v2_4d_runtime/F-Track 100Hz Scheduler
MaskType = Function-Call Generator
sample_time = 0.01
numberOfIterations = 1
trigger source = local F-Track scheduler
TriggerType = function-call
```

The runtime output timestamp at nominal 0.15 is present at index 16. Hence the
failure is not the absence of a scheduled F hit, and classification D is
excluded.

## 10. Initial reset versus second reset

The two reset commands differ at the source-time boundary:

- At `t=0`, the data breakpoint and simulation initialization time are both
  exactly zero. The initial source value is available and the reset passes.
- At nominal `t=0.15`, the colon-generated data timestamp is
  `0.15000000000000002`, while the F hit is
  `0.14999999999999999`. The reset breakpoint is not yet active.
- At the next F hit, the source has advanced to the index-17 reset value zero.

Therefore “the initial reset works” does not imply that all later
single-sample time-matrix pulses are aligned with function-call hits.

## 11. S-function reset semantics

Read-only source inspection established:

1. Reset is input port 7.
2. `Outputs` reads the current `block.InputPort(7).Data` on every hit and passes
   it to the frozen core.
3. Reset is direct-feedthrough.
4. `Update` independently reads the current input-7 value and clears all five
   DWorks when it is nonzero.
5. There is no condition limiting reset to initialization.
6. There is no `time==0` special case.
7. There is no reset latch.

The S-function code therefore supports arbitrary reset hits. Classification E
is excluded by the inspected implementation and by the exact timing mechanism
already identified upstream.

## 12. Frozen-core reset semantics

The frozen core executes the following for any nonzero reset input:

```matlab
Vy_F = Vy_F0;
P_F = P0_F;
diag_F = zeros(3,1);
return
```

There is no time-dependent or initialization-only condition. The core reset
mathematics remains accepted and unchanged.

## 13. Command versus boundary evidence

The failed V2.4-D MAT contains command evidence but no signal logged immediately
at S-function input 7:

```text
RESET BOUNDARY OBSERVABILITY MISSING IN FAILED V2.4-D RUN.
```

Nevertheless, the existing evidence is sufficient for root-cause attribution
because all of the following are now exact and mutually consistent:

- command matrix breakpoint doubles;
- actual F-hit timestamp double;
- From Workspace no-interpolation semantics;
- direct, intermediate-block-free route;
- ordinary-propagation output at the failed hit.

Direct boundary logging would strengthen a future fix-verification run, but it
is not required to identify the present cause.

## 14. Minimal future fix

The minimum future change is runner-only time-axis correction. Do not change
the model, core, S-function, scheduler, P0_F, or Q_F.

Replace the colon-generated breakpoint vector with an integer-tick-derived
vector aligned to the scheduler representation, for example:

```matlab
tick = (0:20).';
t = tick * Ts;
```

For `tick=15`, this produces the same representable double as the observed
function-call hit instead of the later colon breakpoint. Future pre-sim gates
should explicitly compare every event breakpoint double against the intended
integer tick and should reject a pulse whose active interval contains no
function-call hit.

No stimulus-interface block change is required by the identified cause.

## 15. Need for future runtime evidence

1. Root cause identifiable from existing evidence: **YES**.
2. Stimulus-interface model modification required: **NO**.
3. Boundary logging required to identify this cause: **NO**; recommended for
   independent confirmation in any future diagnostic run.
4. A new diagnostic 0.20-s runtime is ultimately required to validate the
   corrected runner timestamp and close V2.4-D: **YES**, but it is not authorized
   in this stage.
5. Such a run would not repeat a performance experiment. It would test a
   materially changed fault hypothesis and timestamp construction, with the
   specific goal of verifying reset delivery at S-function input 7.

## 16. Stop state

```text
sim() called in V2.4-D1 = 0
compile/update called = 0
CarSim called = 0
rebuild called = 0
save_system called = 0
model files modified = 0
core/S-function files modified = 0
fusion/LifeSig/tuning performed = 0
```

V2.4-D remains blocked until a separately authorized runner correction and
diagnostic runtime validation are completed.
