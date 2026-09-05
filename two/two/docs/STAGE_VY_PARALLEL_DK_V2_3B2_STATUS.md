# V2.3-B2 Parallel D/K Estimator-Only Compile Isolation Status

- Date: 2026-08-27
- Final status: **V2.3-B2 PARALLEL D/K ESTIMATOR-ONLY COMPILE ISOLATION PASSED**
- V2.3-B status: **V2.3-B PARALLEL D/K SIMULINK INTEGRATION ACCEPTED WITH EXTERNAL CARSIM COMPILE-ONLY LIMITATION**
- Evidence recovery: `compileCalled=1`, `compilePassed=1`, `terminationReached=1`, `compiledEvidenceCaptured=1`
- `sim()` / Start: **NOT CALLED**
- CarSim runtime: **NOT RUN**
- Full-target compile: **NOT CALLED IN B2**

## 1. Created artifacts

| File | Role | SHA-256 |
|---|---|---|
| `model/vx_vy_parallel_dk_v2_3b2_compile_harness.slx` | exact-copy estimator-only compile harness | `D78119DAAEC56ECC4CC816BBF0F58DBB23FD752DB75EA1CAA9560A17D9C78C15` |
| `model/build_vy_parallel_dk_v2_3b2_compile_harness.m` | deterministic harness builder | `C9F84DD1AD4809E591936D451EFDFAFE553AA805BB17F424A4F3CE01C851E3DE` |
| `model/validate_vy_parallel_dk_v2_3b2_compile_harness.m` | static/compiled-interface validator, corrected after evidence failure | `059CE1E8D7826138BB1E25849DEBBA9B987D2943EA405A11D1C8E3CEC0FC87AF` |
| `results/vy_parallel_dk_v2_3b2_compile_gates.mat` | final build, static, compiled-interface, type, and sample-time evidence | `027D5CE3B90C0E0C76EC86D7A0077D8A8CAD2B2DA10C87861A37E64CE6BC0C2B` |

No runtime result was created.

## 2. Harness construction

The source of truth was the formal parallel target:

```text
model/vx_vy_parallel_dk_v2_3.slx
SHA-256:
98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0
```

The builder copied the actual blocks from that target using Simulink
`add_block` copy operations:

- `Parallel D-EKF 100Hz`;
- independent D Function-Call Generator;
- D input Rate Transition and D input/output mux/extraction blocks;
- `K-KF 100Hz`;
- independent K Function-Call Generator;
- frozen K IMU mux, Vx Rate Transition, and first-hit reset Step.

The D wrapper remains exactly:

```matlab
vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)
```

with `vy_v17_mode_code=20`. The K MATLAB Function chart script is identical
to the chart copied from the formal parallel target and still calls:

```matlab
vy_kinematic_kf(u,z,resetFlag)
```

No D/K equation, Jacobian, measurement update, Q/R/P0, Joseph update, state
memory, or covariance memory was recreated.

The harness contains no `vs_sf`, CarSim S-function, vehicle dynamics, solver
DLL, or external CarSim configuration. Deterministic numeric compile sources
provide only:

```text
Ax scalar
Ay scalar
AVz scalar
true Vx scalar
steering [FL;FR;RL;RR] rad = [0.01;0.01;0;0]
K first-hit reset
```

These sources were not executed as a performance scenario.

## 3. Static evidence

Builder result:

```text
V2_3B2_BUILD_OK
harness hash = D78119DAAEC56ECC4CC816BBF0F58DBB23FD752DB75EA1CAA9560A17D9C78C15
vs_sf = 0
sim = 0
carsim = 0
exit code = 0
```

Static validator result:

```text
static gates = 38/38 PASS
compileCalled = 0
fullTargetCompileCalled = 0
simCalled = 0
carSimRun = 0
exit code = 0
```

The formal parallel target's prior `41/41` static evidence was reused only
after its exact SHA-256 was rechecked. It was not recompiled.

The 38 B2 static gates confirmed:

- no CarSim/`vs_sf` in the harness;
- D and K blocks are exact copied implementation boundaries;
- independent 100-Hz Function-Call Generators;
- D A20 internal Ay update every fifth 100-Hz hit;
- K Ay remains a 100-Hz process input and is not controlled by the D Ay gate;
- independent D lifecycle reset and K explicit first-hit reset;
- independent D/K persistent state and covariance storage;
- Ax goes to K only;
- Ay, AVz, and true Vx fan out from common deterministic physical sources;
- four-channel rad steering goes to D only;
- true Vy is absent online;
- D and K outputs terminate only in observation/extraction sinks;
- no state/P/pseudo-measurement cross-feed;
- no weighted sum, D/K selector, alpha, LifeSig, reliability logic, DK-EKF,
  third feedback track, or `Vy_final`.

## 4. Compile attempts and exact evidence failure

The harness compile gate was entered only after `38/38` static gates passed.
The full target was never loaded or compiled in B2.

### Attempt 1

The estimator-only `feval(h,[],[],[],'compile')` completed without an
estimator compile diagnostic. The validator then successfully called both:

```text
compiled_interfaces(build)
compiled_sample_times(build)
```

set `compile.passed=true`, and terminated the compiled model. During the
post-compile gate calculation, the validator failed at:

```text
sample_is(st.dParent,0.01)
```

with:

```text
Too many input arguments.
```

### Attempt 2

The first helper was replaced with a direct check. The second and final
authorized harness compile again completed, extracted compiled interfaces and
sample times, set `compile.passed=true`, and terminated. It then failed at:

```text
double(st.dParent)
```

with the same comma-separated-list symptom:

```text
Too many input arguments.
```

Root cause:

```matlab
st=struct('dParent',get_param(...), ...)
```

Some `CompiledSampleTime` values are cell arrays. Passing them directly to the
`struct` constructor created a nonscalar struct array. Consequently,
`st.dParent` expanded as a comma-separated list during evidence evaluation.

This is an evidence/serialization bug after estimator compilation, not an
estimator, dimension, type, scheduler, or sample-time compile diagnostic.

However, the interface values were neither printed nor saved before the
post-processing exception. Therefore this stage does not possess durable raw
evidence for the required D/K dimensions and CST values and cannot claim B2
acceptance.

## 5. Validator correction completed without another compile

The validator now constructs a scalar evidence struct with field-by-field
assignment:

```matlab
st=struct();
st.dParent=get_param(...);
st.kParent=get_param(...);
st.dInputBoundary=get_param(...);
st.kVxBoundary=get_param(...);
```

and recursively evaluates numeric/cell sample-time evidence using
`contains_period`.

No third compile was run. The same gate had already been compiled twice, and
the project execution policy prohibits another equivalent run without an
explicit new authorization.

## 6. Frozen integrity

| Object | SHA-256 | Result |
|---|---|---|
| formal parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| frozen D-EKF model | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| frozen K genuine-steering model | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |
| D wrapper | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| K core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| K wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |

No MATLAB process remained active after either attempt.

## 7. V2.3-B2R evidence capture recovery

The user explicitly authorized one additional estimator-only compile after
the evidence-packing defect was corrected. The builder was not run, the
harness was not saved or modified, and the formal target was neither loaded
nor compiled.

Final command result:

```text
V2_3B2_VALIDATE|
  static=38/38|
  compileCalled=1|
  compilePassed=1|
  compiled=15/15|
  passed=1|
  fullTarget=0|
  sim=0|
  carsim=0

B2R_RESULT|
  compileCalled=1|
  compilePassed=1|
  terminationReached=1|
  evidenceCaptured=1|
  static=38/38|
  formal=41/41|
  passed=1

exit code = 0
```

No estimator-side warning or error was reported.

### 7.1 Compiled dimensions and types

These values were read from compiled port information before model
termination and persisted in the MAT evidence:

| Interface | Raw compiled shape | Width | Type | Accepted semantic shape |
|---|---:|---:|---|---|
| D-EKF state `x_D` | `2` | 2 | `double` | 2x1 `[Vy;r]` |
| D-EKF covariance `P_D` | `[2 2]` | 4 | `double` | 2x2 |
| K-KF state `x_K` | `2` | 2 | `double` | 2x1 `[Vx;Vy]` |
| K-KF covariance `P_K` | `[2 2]` | 4 | `double` | 2x2 |
| D steering input | `4` | 4 | `double` | 4x1 `[FL;FR;RL;RR]` rad |
| Ax | `1` | 1 | `double` | scalar |
| Ay | `1` | 1 | `double` | scalar |
| AVz | `1` | 1 | `double` | scalar |
| true Vx | `1` | 1 | `double` | scalar |
| K reset | `1` | 1 | `double` | scalar/logical-compatible |
| D `useAy` diagnostic gate | `1` | 1 | `double` | scalar/logical-compatible |

Simulink reports column-vector signals as one-dimensional widths `2` and `4`;
the frozen wrapper/interface ordering establishes the accepted 2x1 and 4x1
semantic shapes. Both covariance outputs are actual compiled 2x2 matrices.

No estimator-side dimension or data-type mismatch exists.

### 7.2 Sample-time and function-call evidence

Compiled parent domains:

```text
D parent CST = [0.01 0]
K parent CST = [0.01 0]
```

The D input Rate Transition and K Vx Rate Transition compiled CST evidence is
stored in the MAT report in its original API representation:

```text
dInputBoundary: 2x1 cell
kVxBoundary:    2x1 cell
```

The cell-valued structures were deliberately preserved and not flattened.
The acceptance gate uses their compiled relationships together with the
following already-passed structural evidence:

- D and K each have a distinct Function-Call Generator;
- each generator has `sample_time=0.01`, one iteration, and connects only to
  its own function-call TriggerPort;
- both compiled parent domains are 100 Hz;
- frozen D A20 logic uses `stride=100/modeCode=5`, so `useAy` is asserted
  every fifth D hit, preserving 20-Hz Ay assimilation;
- the compiled `useAy` observation is a scalar double/logical-compatible
  signal;
- K Ay comes directly from the common physical Ay source on every K hit and
  is not controlled by the D gate;
- K first-hit Step remains high at t=0 and low from 0.01 s;
- D lifecycle reset remains internal and independent;
- no sample-time conflict was emitted during compile.

Compiled scheduler/sample-time gates: PASS.

### 7.3 Independence and integrity

Harness static gates remain `38/38 PASS`, including every required no-coupling
gate. Formal parallel static gates remain `41/41 PASS` and were reused only
after the exact formal-target hash was rechecked.

The harness SHA-256 remained:

```text
D78119DAAEC56ECC4CC816BBF0F58DBB23FD752DB75EA1CAA9560A17D9C78C15
```

The formal target and every frozen D-EKF, K-KF, and DK-EKF object remained at
the hashes recorded in section 6.

## 8. Final decision

All authorized B2R conditions passed:

- estimator-only harness compile: PASS;
- termination: PASS;
- compiled dimensions/types captured: PASS;
- compiled/structural sample-time evidence captured: PASS;
- harness static gates: 38/38 PASS;
- formal parallel static gates: 41/41 PASS;
- estimator-side errors: NONE;
- frozen integrity: PASS;
- simulation/CarSim runtime: NOT PERFORMED.

**V2.3-B2 PARALLEL D/K ESTIMATOR-ONLY COMPILE ISOLATION PASSED**

**V2.3-B PARALLEL D/K SIMULINK INTEGRATION ACCEPTED WITH EXTERNAL CARSIM COMPILE-ONLY LIMITATION**

FULL-TARGET COMPILE-ONLY REMAINS EXTERNALLY BLOCKED BY CARSIM VS_SF
INITIALIZATION ACCESS VIOLATION.

PARALLEL D/K ESTIMATOR INTEGRATION ITSELF IS ACCEPTED.

STATIC PARALLEL GATES = 41/41 PASS.

ESTIMATOR-ONLY HARNESS STATIC GATES = 38/38 PASS.

NO SIMULATION OR CARSIM RUNTIME WAS PERFORMED.

NO D-EKF, K-KF, DK-EKF, OR FROZEN MODEL WAS MODIFIED.

NO FUSION, LIFESIG, THIRD TRACK, Q/R TUNING, OR BIAS CORRECTION WAS
PERFORMED.

READY FOR V2.3-C SINGLE SHORT PARALLEL D/K RUNTIME PREFLIGHT
