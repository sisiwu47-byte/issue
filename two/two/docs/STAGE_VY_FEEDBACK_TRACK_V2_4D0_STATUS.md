# V2.4-D0 Deterministic Runtime Stimulus Interface Enablement

## 1. Stage decision

**V2.4-D0 DETERMINISTIC RUNTIME STIMULUS INTERFACE ACCEPTED**

The accepted V2.4-C estimator integration was copied to a dedicated runtime
validation model. Only the seven top-level test stimulus sources were replaced.
No simulation or CarSim runtime was performed.

## 2. Created files

| File | Role | SHA-256 |
|---|---|---|
| `model/vx_vy_feedback_track_v2_4d_runtime.slx` | deterministic-source runtime validation copy | `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A` |
| `model/build_vy_feedback_track_v2_4d0_runtime_interface.m` | source-only copy builder | `02CB5423A5F544252901D907697C88D0FD0B697FEEEC49F0A2B9A14717C40896` |
| `model/validate_vy_feedback_track_v2_4d0_runtime_interface.m` | static, structural, and compile-only validator | `CA5A13504CF3C0CBBB00F527496A459453FF48365019CB18D55334464652D291` |
| `results/vy_feedback_track_v2_4d0_interface_gates.mat` | machine-readable D0 evidence | `A904FB82EA49836889AF117D6D2DEBA98FA1EB5CF1B14BAA18BF7AC0831F0E9F` |
| `docs/STAGE_VY_FEEDBACK_TRACK_V2_4D0_STATUS.md` | this status record | recorded after creation |

No V2.4-D runtime result MAT, runtime runner, or runtime analyzer was created.

## 3. Exact source-only change

The original seven top-level Constant/Step sources were replaced in place by
seven From Workspace blocks. Their original destinations and semantic order
were retained:

| F-track port | Runtime source block | Workspace variable |
|---:|---|---|
| 1 | `Ay Source` | `ftrack_test_Ay` |
| 2 | `AVz Source` | `ftrack_test_AVz` |
| 3 | `Vx Source` | `ftrack_test_Vx` |
| 4 | `Vy Feedback Current` | `ftrack_test_Vy_feedback` |
| 5 | `P Feedback Current` | `ftrack_test_P_feedback` |
| 6 | `Feedback Valid Current` | `ftrack_test_feedback_valid` |
| 7 | `Reset First Hit` | `ftrack_test_reset` |

Every source has:

```text
SampleTime = 0.01
Interpolate = off
OutputAfterFinalValue = Holding final value
```

Thus all seven sources accept the same 21 timestamps and use exact discrete
zero-order-hold semantics. No Step/Switch/Pulse event network was introduced.

## 4. Deterministic sequence expressibility

The validated interface profile uses `t = 0:0.01:0.20` with 21 samples:

- `Ay_IMU = 1`, `AVz_IMU = 0.1`, and `Vx_source = 20` at every hit;
- reset pulses are independently represented at indices 1 and 16
  (`t=0` and `t=0.15`);
- feedback-valid pulses are independently represented at indices 1, 9, and 16
  (`t=0`, `t=0.08`, and `t=0.15`);
- feedback state/P carry distinct finite values at the initial-reset,
  delayed-feedback, and runtime-reset events;
- `t=0.08` uses `Vy_feedback=1.0`, `P_feedback=0.25`;
- `t=0.15` uses `Vy_feedback=5.0`, `P_feedback=0.75`.

The interface can therefore express every future V2.4-D event without further
model modification.

## 5. Static and structural gates

```text
Static source/interface gates = 35/35 PASS
ESTIMATOR INTEGRATION STRUCTURE UNCHANGED = YES
Precompile gate = PASS
```

The structural comparison confirmed equality of the accepted model and runtime
copy at the estimator boundary and inside it:

- S-function block path and block type;
- `FunctionName = vy_feedback_propagation_simulink_sfun`;
- dialog parameters `0.01,0,0.5,0.0025`;
- seven inputs and three outputs;
- scheduler parameters and function-call route;
- all internal blocks and lines;
- top-level output/logging routes.

All top-level blocks other than the seven authorized stimulus sources remained
structurally identical. No input-port permutation or semantic fan-out exists.

## 6. Compile/update evidence

Exactly one compile was called after the static and structural gates passed:

```text
compileCalled = 1
compilePassed = 1
terminationReached = 1
compiledEvidenceCaptured = 1
compiled gates = 11/11 PASS
```

Compiled interface evidence:

| Interface | Resolved dimension | Resolved type |
|---|---:|---|
| F-track inputs 1 through 7 | scalar each | double each |
| `Vy_F` | scalar | double |
| `P_F` | scalar | double |
| `diag_F` | 3x1 | double |

Scheduler/function-call evidence remained 100 Hz with configured sample time
`[0.01 0]`. No dimension, data-type, or sample-time conflict was reported.

The first sandboxed MATLAB start failed in the settings plugin before project
code ran. A subsequent non-sandbox batch created the runtime copy, but a pure
validator parser error occurred before any static gate or compile call. The
validator-only rerun reused the existing build report and runtime copy; it did
not rebuild. The one successful compile above is the only compile performed.

## 7. Independence and parameter gates

All corresponding static gates passed:

```text
no D-EKF / K-KF / DK-EKF blocks = YES
no fusion / weighted sum / alpha = YES
no LifeSig / reliability logic = YES
no true Vy = YES
no CarSim = YES
```

The estimator dialog parameters remain:

```text
Ts = 0.01 s
Vy_F0 = 0
P0_F = 0.5
Q_F = 0.0025
```

`P0_F` and `Q_F` remain **TEST-ONLY / UNTUNED / UNFROZEN**.

## 8. Frozen integrity

The following independently recalculated hashes matched their baselines after
the builder and compile-only validator completed:

| Frozen item | SHA-256 | Result |
|---|---|---|
| Accepted standalone target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |
| F-track mathematical core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| F-track S-function | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | UNCHANGED |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |
| D-EKF V1.17 target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | UNCHANGED |
| K-KF base target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | UNCHANGED |
| K-KF core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | UNCHANGED |
| K-KF wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | UNCHANGED |
| DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | UNCHANGED |
| DK-EKF core | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | UNCHANGED |
| DK-EKF wrapper | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | UNCHANGED |
| DK-EKF adapter | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | UNCHANGED |

The evidence MAT records `sourceUntouched=1`, `runtimeNoWriteDuringValidation=1`,
and `frozenUnchanged=1`.

## 9. Runtime authorization state

```text
sim() called = 0
CarSim called = 0
runtime result MAT created = 0
V2.4-D single 0.20-s runtime authorization consumed = 0
```

RUNTIME VALIDATION COPY IS READY.

ACCEPTED V2.4-C STANDALONE TARGET WAS NOT MODIFIED.

ONLY TEST STIMULUS SOURCES DIFFER.

F-TRACK CORE / S-FUNCTION / SCHEDULER SEMANTICS ARE UNCHANGED.

THE SINGLE V2.4-D RUNTIME AUTHORIZATION REMAINS UNUSED.

READY TO RESUME V2.4-D SINGLE STANDALONE RUNTIME VALIDATION
