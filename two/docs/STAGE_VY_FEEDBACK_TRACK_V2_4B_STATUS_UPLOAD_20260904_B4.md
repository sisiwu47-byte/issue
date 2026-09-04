# V2.4-B Feedback / Propagation Mathematical Core Status

- Date: 2026-08-28
- Final decision: **V2.4-B FEEDBACK / PROPAGATION MATHEMATICAL CORE ACCEPTED**
- Unit tests: **34/34 PASS**
- Simulation / CarSim / Simulink model: **NOT USED**
- Wrapper / persistent state / feedback delay: **NOT IMPLEMENTED**
- D/K coupling / fusion / LifeSig: **NONE**
- Q_F / P0_F tuning: **NOT PERFORMED**

## 1. Created artifacts

| File | Role | SHA-256 |
|---|---|---|
| `model/vy_feedback_propagation_step.m` | stateless scalar propagation core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| `model/test_vy_feedback_propagation_v2_4b.m` | deterministic unit and robustness tests | `088AC1FD40001669E9890F8BAB53CF9817F71A9456F8A4D88DB105E2A05A24D2` |
| `results/vy_feedback_track_v2_4b_unit_tests.mat` | machine-readable test evidence | `5A21FBE82B85DC21363715D6AF7EE9F612F76916EDA318504254DFE9F87D8FDA` |
| `docs/STAGE_VY_FEEDBACK_TRACK_V2_4B_STATUS.md` | this status | computed after creation |

No helper, wrapper, S-function, MATLAB Function block, `.slx`, delay block, or
fusion artifact was created.

## 2. Exact core interface

```matlab
[Vy_F,P_F,diag_F] = vy_feedback_propagation_step( ...
    Vy_prev,P_prev,Ay_IMU,AVz_IMU,Vx_source, ...
    Vy_feedback_delayed,P_feedback_delayed, ...
    feedback_valid_delayed,reset,Ts,Vy_F0,P0_F,Q_F)
```

All state, covariance, physical, feedback, initialization, and noise inputs
are scalar. Flags are finite scalar numeric/logical-compatible values. Outputs
are scalar `double` state/covariance and fixed `3x1 double` diagnostics.

The function contains no `persistent`, global state, workspace access, random
source, wrapper memory, or delay memory. Equal inputs therefore have equal
outputs independently of call history.

## 3. Exact mathematical equations

For a non-reset hit:

```text
prop_term = Ay_IMU - AVz_IMU*Vx_source
deltaVy   = Ts*prop_term
```

Base selection is atomic:

```text
if feedback_valid_delayed:
    Vy_base = Vy_feedback_delayed
    P_base  = P_feedback_delayed
    feedbackApplied = 1
else:
    Vy_base = Vy_prev
    P_base  = P_prev
    feedbackApplied = 0
```

The outputs are exactly:

```text
Vy_F = Vy_base + Ts*(Ay_IMU - AVz_IMU*Vx_source)
P_F  = P_base + Q_F
```

The sign regression reproduces the frozen K-KF lateral kinematics
`vy_dot=ay-r*vx`:

```text
Ay=1 m/s^2, AVz=0.1 rad/s, Vx=20 m/s, Ts=0.01 s
prop_term = -1 m/s^2
deltaVy   = -0.01 m/s
```

Actual result: exact `-1 / -0.01`, PASS. No `Ay+r*Vx` sign is present.

## 4. Reset priority

Reset is evaluated before dynamics, feedback selection, and covariance
increment. On a reset hit:

```text
Vy_F   = Vy_F0
P_F    = P0_F
diag_F = [0;0;0]
```

There is no propagation, feedback consumption, or Q_F increment on that hit.
The configured initialization is returned exactly. True Vy is not an input or
reset source.

## 5. Delayed-feedback contract

`Vy_feedback_delayed`, `P_feedback_delayed`, and
`feedback_valid_delayed` are defined as values that **have already passed
through the required one-sample delay**. The mathematical core does not
implement `z^-1`, remember a fused state, or own any feedback history.

When the delayed valid flag is true, state and covariance are both selected
from the delayed feedback pair. When false, both are selected from the prior
standalone F pair. State-only or covariance-only branch replacement is
impossible in the implemented selection structure.

The flag means feedback-source availability only. It is not a measurement
update, fusion weight, LifeSig, reliability decision, or observability gate.

## 6. Diagnostic contract

The fixed ordering is:

```text
diag_F = [
    prop_term;          % index 1, m/s^2
    deltaVy;            % index 2, m/s
    feedbackApplied     % index 3, numeric 0 or 1
]
```

Reset returns exact zeros. No NIS, LifeSig, observability score, adaptive Q,
reliability value, or alpha is emitted.

## 7. Preconditions and failure policy

Runtime assertions are implemented directly in the stateless core. They are
simple scalar checks compatible with a future thin integration boundary:

| Quantity | Required condition |
|---|---|
| `Ts` | finite and `>0` |
| `P0_F` | finite and `>0` |
| `Q_F` | finite and `>=0` |
| active physical inputs | finite real scalars |
| standalone `Vy_prev/P_prev` | finite; `P_prev>=0` |
| valid feedback `Vy/P` | finite; `P_feedback_delayed>=0` |

Inactive branch values are structurally scalar numeric but are not used for
finite/variance computation checks. Reset ignores dynamic and feedback branch
values after validating the global configuration. Invalid active inputs raise
an explicit error. There is no covariance clipping, `abs(P)`, `max(P,eps)`,
or silent correction.

## 8. Parameter units and test-only policy

| Parameter | Unit | Mathematical location | Requirement |
|---|---|---|---|
| `Ts` | s | multiplies `prop_term` | `>0`; architecture baseline 0.01 s |
| `Vy_F0` | m/s | reset state | finite |
| `P0_F` | `(m/s)^2` | reset covariance | `>0` |
| `Q_F` | `(m/s)^2` per discrete step | added once on each non-reset hit | `>=0` |

The principal unit-test constants were:

```text
Ts=0.01, Vy_F0=0.125, P0_F=0.5, Q_F=0.0025
```

Additional recurrence/robustness cases used `Q_F=0`, `0.001`, `0.125`, and
`1e-6` solely to exercise algebraic gates. All are **TEST-ONLY, NOT TUNED,
AND NOT FROZEN FOR RUNTIME**. Passing tests does not promote any test value to
a nominal estimator parameter.

## 9. Unit-test evidence

Final batch result:

```text
V2_4B_UNIT_TESTS|passed=34/34|all=1|stateless=1|frozen=1
V2_4B_SIGN|prop=-1|delta=-0.01
V2_4B_LONG|N=10000|finite=1|nonnegative=1|repeat=1|maxDiff=0
V2_4B_HASH|core=80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF|test=088AC1FD40001669E9890F8BAB53CF9817F71A9456F8A4D88DB105E2A05A24D2
V24B_TEST_BATCH_OK
exit code = 0
```

| Gate group | Cases | Result |
|---|---|---|
| reset state/covariance/diagnostics/priority | T1-T5 | PASS |
| standalone zero/positive/negative and sign | T6-T9 | PASS |
| feedback state/P selection and atomicity | T10-T13 | PASS |
| Q increment and diagnostics | T14-T19 | PASS |
| fixed dimensions and deterministic purity | T20-T21 | PASS |
| multi-step, feedback rebase, continuity | T22-T24 | PASS |
| no true-Vy, D/K, or fusion dependency | T25-T27 | PASS |
| 10,000-step finite deterministic propagation | T28 | PASS |
| explicit invalid-input rejection | T29-T34 | PASS |

The analytical multi-step gates require error `<=1e-12`; simple algebraic
cases use exact or machine-precision comparisons. Per-case expected values,
actual values, and maximum numerical errors are stored in the MAT evidence.

## 10. Long-run numerical sanity

The bounded deterministic 10,000-step case was executed twice with identical
inputs and TEST-ONLY covariance increment:

```text
all Vy/P outputs finite        = YES
all P outputs nonnegative      = YES
repeat state sequence exact    = YES
repeat covariance sequence     = YES
maximum repeat difference      = 0
hidden-state discrepancy       = NONE
```

This is a numerical sanity test, not performance validation, Q tuning, or P0
tuning. No CarSim, Simulink, sensor degradation, or estimator comparison was
involved.

## 11. Execution record and evidence recovery

The first pure MATLAB batch completed the core test calculations but failed
before saving/printing the final gate report because the evidence packer used
`mfilename('fullpath')` without appending `.m` for the test-script SHA-256
path. The exact failure was a `FileNotFoundException` in the local
`file_sha256` helper. This was an evidence-path defect after the mathematical
cases, not a core failure. No result MAT was created by that attempt.

Only the test-script path was corrected to:

```matlab
testFile = [mfilename('fullpath') '.m'];
```

The second and final pure MATLAB batch then produced the durable 34/34 result
above and exited 0. No core equation or gate was weakened, and no third run was
performed.

## 12. Dependency and prohibited-feature audit

The core interface/source contains none of:

- Ax or steering;
- `Vy_D`, `r_D`, `P_D`;
- `Vx_K`, `Vy_K`, `P_K`;
- true Vy;
- `alpha_D`, `alpha_K`, `alpha_F`;
- `Vy_fused`, `Vy_final`;
- fusion, LifeSig, reliability, or workspace estimator inputs.

It reads only its explicit scalar arguments. It does not access the base
workspace, D/K logs, frozen model signals, or any online truth value.

## 13. Frozen integrity

All before/after hashes matched. Key objects include:

| Frozen object | SHA-256 | Result |
|---|---|---|
| parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| D-EKF V1.17 model | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| D wrapper | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| K-KF V2.1 model | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| K core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| K wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| DK-EKF V2.2 model | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| DK core | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| DK wrapper | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| DK adapter | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |

The MAT report records the complete 13-object before/after set, including the
D V13 dependency and K genuine-steering source.

## 14. Required acceptance answers

1. Reset hit completely avoids propagation: **YES**.
2. Valid feedback selects delayed state and covariance together: **YES**.
3. Invalid/false feedback strictly uses prior F state/covariance: **YES**.
4. Propagation sign matches frozen K-KF kinematics: **YES**.
5. Covariance is exactly `P_base+Q_F`: **YES**.
6. Diagnostic ordering is fixed: **YES**.
7. Core is completely stateless: **YES**.
8. Any D/K/fusion dependency exists: **NO**.
9. True Vy is used: **NO**.
10. Q_F/P0_F tuning was performed: **NO**.

## 15. Final decision

**V2.4-B FEEDBACK / PROPAGATION MATHEMATICAL CORE ACCEPTED**

SCALAR Vy PROPAGATION CORE ACCEPTED.

SCALAR COVARIANCE PROPAGATION ACCEPTED.

RESET / FEEDBACK SEMANTICS ACCEPTED.

CORE IS STATELESS.

NO D/K COUPLING WAS INTRODUCED.

NO FUSION WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

Q_F AND P0_F REMAIN UNTUNED / UNFROZEN.

NO SIMULATION / CARSIM / SIMULINK MODEL WAS USED.

READY FOR V2.4-C FEEDBACK / PROPAGATION SIMULINK INTEGRATION
