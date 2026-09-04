# V2.5-B Fixed-Weight Fusion Mathematical Core Status

## 1. Final decision

**V2.5-B FIXED-WEIGHT FUSION MATHEMATICAL CORE ACCEPTED**

The pure MATLAB state-fusion core passed all 34 deterministic, rejection,
randomized, and source-isolation gates. No Simulink model, compile,
simulation, CarSim, covariance fusion, weight selection/tuning, F-track
feedback, adaptive logic, or LifeSig was used.

## 2. Created artifacts

| File | Role | SHA-256 |
|---|---|---|
| `model/vy_fixed_weight_fusion_step.m` | stateless three-track state-fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` |
| `model/test_vy_fixed_weight_fusion_v2_5b.m` | 34-gate pure MATLAB test suite | `DF51622E8563B708E9CEB5069C7B39C44DEDACBF8319CFF1FC92B85074FCD464` |
| `results/vy_fixed_fusion_v2_5b_unit_tests.mat` | machine-readable test evidence | `56E54933544004B3338ED7E05E082E2F60D07D7E1FB5563032732D710732947E` |
| `docs/STAGE_VY_FIXED_FUSION_V2_5B_STATUS.md` | this acceptance record | computed after creation |

No separate validator was created. Lightweight argument and parameter
preconditions are enforced directly by the stateless core.

## 3. Exact mathematical and interface contract

Exact function interface and ordering:

```matlab
Vy_FW = vy_fixed_weight_fusion_step( ...
    Vy_D, Vy_K, Vy_F, alpha_D, alpha_K, alpha_F)
```

The immutable input ordering is:

```text
1 Vy_D
2 Vy_K
3 Vy_F
4 alpha_D
5 alpha_K
6 alpha_F
```

The only output is scalar-double `Vy_FW` in m/s. Its exact equation is:

```text
Vy_FW = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

The core has no additional output, diagnostic vector, confidence value,
weight output, or fused covariance.

## 4. Weight constraints and failure policy

All three weights must be real finite numeric scalars and satisfy:

```text
alpha_D >= 0
alpha_K >= 0
alpha_F >= 0
abs(alpha_D + alpha_K + alpha_F - 1) <= 1e-12
```

`1e-12` is the fixed implementation-validation tolerance for the sum check.
It is not a tuning parameter.

The core does not normalize, clip, repair, project, or otherwise modify
weights. Invalid weights generate explicit errors. In particular,
`[0.2,0.2,0.2]` is rejected with
`vy_fixed_weight_fusion_step:InvalidWeightSum`; it is not changed to equal
weights.

## 5. State-input validation

`Vy_D`, `Vy_K`, and `Vy_F` must each be real finite numeric scalars. Accepted
numeric inputs are converted to double before evaluation, so the output
contract is consistently scalar double. NaN, Inf, vectors, complex values,
and nonnumeric values are rejected rather than saturated, replaced, or sent
to a fallback path. A nonfinite arithmetic result is also rejected.

## 6. Stateless and deterministic semantics

The core has no `persistent`, global, memory, workspace access, random source,
time input, delay, or state update. Equal ordered inputs and weights therefore
produce exactly equal outputs independently of call history.

The accepted core is a same-sample algebraic combiner only. It contains no
estimator dynamics and no D/K/F sample shift.

## 7. Unit-test summary

Final pure MATLAB result:

```text
V2_5B_UNIT_TESTS|passed=34/34|all=1|stateless=1|noNormalize=1|frozen=1
V2_5B_RANDOM|seed=2505|N=1000|maxAnalytical=0|maxConvexViolation=0|finite=1
V25B_UNIT_TEST_BATCH_OK
exit code = 0
```

| Test group | Gates | Result |
|---|---:|---|
| D-only/K-only/F-only identity | T1-T3 | PASS |
| Equal-input and analytical convex combinations | T4-T9 | PASS |
| Convex bounds, deterministic purity, stateless sequence, legal zero weight | T10-T14 | PASS |
| Negative/nonfinite/sum-invalid rejection and no silent normalization | T15-T24 | PASS |
| Scalar-double output, input/weight permutation mapping, randomized tests | T25-T27 | PASS |
| No covariance/adaptive/truth/DK/feedback/state and one-output source gates | T28-T34 | PASS |

Key analytical evidence includes:

- `[1,0,0]`, `[0,1,0]`, and `[0,0,1]` are exact passthrough cases;
- states `[1,2,3]` with TEST-ONLY weights `[0.5,0.3,0.2]` produce `1.7`;
- negative, mixed-sign, zero-state, equal-input, and equal TEST-ONLY weight
  cases match their analytical results;
- every accepted convex combination remains inside the input convex hull.

## 8. Randomized convex test

The deterministic random test used:

```text
RNG seed = 2505
case count = 1000
max analytical error = 0
max convex-bound violation = 0
all outputs finite = YES
```

Random nonnegative weights were normalized only inside the test-data generator
to create legal convex vectors. This is explicitly separate from the fusion
core:

`CORE DOES NOT NORMALIZE WEIGHTS.`

## 9. State-only and correlation policy

Static source gates and direct MAT evidence confirm:

```text
no covariance input = YES
no P_D / P_K / P_F = YES
no P_FW = YES
fused covariance generated = NO
track independence assumed = NO
```

D/K/F errors remain correlated through shared physical signals and are not
assumed independent. This core performs only the accepted fixed-weight state
equation; it does not infer uncertainty from individual track covariance.

## 10. Prohibited-feature isolation

Source-level gates passed for all of the following:

- no DK-EKF input or dependency;
- no online true Vy input or reference;
- no F-track feedback state/P/valid input;
- no fusion-feedback loop;
- no adaptive or time-varying weights;
- no NIS, observability, reliability, switch, winner, or fallback logic;
- no LifeSig;
- no `Vy_final`;
- no Simulink, simulation, or CarSim call.

## 11. Weight parameter status

```text
alpha_D: NOT SELECTED / NOT TUNED / NOT FROZEN
alpha_K: NOT SELECTED / NOT TUNED / NOT FROZEN
alpha_F: NOT SELECTED / NOT TUNED / NOT FROZEN
```

All numbers used by the tests—including degenerate vectors,
`[0.5,0.3,0.2]`, `[1/3,1/3,1/3]`, `[0,0.4,0.6]`, and generated random convex
vectors—are TEST-ONLY. No equal-weight or other baseline value was selected.
No V2.3-D truth-error optimization, grid search, least-squares fit, RMSE
minimization, Bayesian tuning, or manual weight choice was performed.

## 12. Frozen-foundation integrity

The V2.5-A architecture document remained:

```text
SHA-256 = 16C97B60772D56BD4F32D2D9C75D2E5CEB9D0E37CFCD4C8E226C332B1720B122
```

Before and after the tests, 17 registered dependencies matched their exact
baselines with zero mismatch. They cover:

- V2.5-A architecture;
- F-track core, S-function, and accepted standalone target;
- frozen parallel D/K target;
- frozen D-EKF model/wrapper/dependencies;
- frozen K-KF model/genuine-steering model/core/wrapper;
- frozen DK-EKF model/core/wrapper/adapter.

No D/K/F/DK-EKF/parallel/SLX artifact was modified.

## 13. Execution record

Exactly one pure MATLAB unit-test batch was started after all static source
gates passed. It saved the MAT evidence, printed 34/34 and the 1000-case random
summary, and exited 0. MATLAB startup was not repeated. Simulink was not loaded;
compile, `sim()`, CarSim, model build, and model save counts are all zero.

## 14. Final acceptance statements

STATE-ONLY FIXED-WEIGHT FUSION CORE ACCEPTED.

WEIGHT CONSTRAINT VALIDATION ACCEPTED.

CORE IS STATELESS.

NO SILENT WEIGHT NORMALIZATION EXISTS.

NO FUSED COVARIANCE IS GENERATED.

NO TRACK-INDEPENDENCE ASSUMPTION WAS INTRODUCED.

NO F-TRACK FEEDBACK WAS CLOSED.

NO ADAPTIVE LOGIC WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

WEIGHT VALUES REMAIN UNSELECTED / UNTUNED / UNFROZEN.

NO SIMULINK / SIMULATION / CARSIM WAS USED.

READY FOR V2.5-C FIXED-WEIGHT FUSION SIMULINK INTEGRATION
