# V2.7-A3R7 LifeSig Fusion Core Implementation and Unit Test

## Stage conclusion

```text
LIFESIG_FUSION_CORE_UNIT_TEST_PASS
```

The A3R6 numerical contract is implemented as a pure MATLAB step core and
verified by a pure MATLAB unit test. No Simulink model was loaded or modified,
`sim()` was not called, and CarSim was not used.

## Implemented files

| File | Role | SHA-256 |
|---|---|---|
| `model/vy_lifesig_fusion_step.m` | Pure fusion transition | `B010F7DBDDDA47A236A74BD439B4E52BD5687FBDDF51D745D1A79CBF8FEBCECE` |
| `model/test_vy_lifesig_fusion_v2_7a3r7.m` | Pure MATLAB unit test | `B087FD811ECBA8D88C09A7F7DB65FDC34611E9D6F7B2378D5FE3D4554CDF913F` |
| `results/vy_reliability_lifesig_v2_7a3r7_unit_tests.mat` | Machine-readable final evidence | `76C0F7EC5801BBF4E55030C4C9211BDDFDFEA580070B271314E317F18BFC764B` |

No wrapper or `.slx` file was created or modified in this stage.

## Core interface

The core follows the existing project convention that the mathematical step
is stateless while a later Simulink wrapper owns DWork. Memory is therefore
explicit in the pure-function contract.

Inputs, in order:

```text
Vy_D
update_valid_D
Vy_K
update_valid_K
Vy_F
propagation_age_steps
age_valid_F
reset
last_valid_Vy_LS
has_last_valid
```

Outputs, in order:

```text
Vy_LS
alpha_D
alpha_K
alpha_F
fusion_valid
fallback_active
last_valid_Vy_LS_next
has_last_valid_next
```

All outputs are scalar doubles, matching the current Level-2 MATLAB S-function
boundary convention. The future wrapper will own only the two last-valid
memory values.

## Frozen implementation

The exact frozen parameters are embedded once in the core:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
tau_F = 28.252990189369939 s
Ts = 0.01 s
```

Availability and health follow A3R4/A3R6. D and K require their update-valid
flag and finite state. F requires valid finite nonnegative age and finite
`Vy_F`; its health is the frozen exponential age decay. Inactive terms are
assigned literal zero before multiplication, so an unavailable NaN state
cannot enter the numerator through `0*NaN`.

For finite positive score sum, the core normalizes the scores, returns a valid
fusion, and updates the next last-valid state. It introduces no epsilon. If no
normal score is available, alpha is exactly `[0 0 0]`, the output holds the
last valid value when available or emits zero otherwise, and the fallback is
explicitly invalid. The fallback does not update memory.

Reset clears prior memory before current-hit evaluation. A valid current hit
can therefore re-establish normal fusion and memory on the same reset hit; an
invalid current hit produces the no-history fallback.

## Unit-test evidence

Final command:

```powershell
& 'D:\matlab\Matlab R2024a(1)\anzhuang\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); report=test_vy_lifesig_fusion_v2_7a3r7(); disp('A3R7_BATCH_OK');"
```

Final raw result:

```text
A3R7_UNIT|passed=20/20|all=1|frozen=1
A3R7_HASH|core=B010F7DBDDDA47A236A74BD439B4E52BD5687FBDDF51D745D1A79CBF8FEBCECE|test=B087FD811ECBA8D88C09A7F7DB65FDC34611E9D6F7B2378D5FE3D4554CDF913F
A3R7_BATCH_OK
exit code = 0
```

The tests cover all-track and single-track normal fusion, exact F age decay,
independent D/K/F invalidation, inactive-NaN protection, no-history and
hold-last fallback, repeated fallback memory stability, both reset paths,
randomized nonnegative/normalized weight invariants, scalar-double interface,
last-valid update rules, statelessness, absence of an arbitrary normalization
floor, and formal-input isolation.

Two earlier test invocations exposed only test-harness comparison defects:
exact equality was used against an ordinary floating-point result, and a
source scanner initially matched explanatory comment text. The core numerical
behavior and frozen dependency checks passed in those runs. The assertions
were corrected without changing the frozen formula; the final run above is
the authoritative result.

## Frozen dependency integrity

The unit test hashed the A3R1, A3R4, and A3R6 evidence plus the existing fixed
fusion and F-track step/wrapper files before and after execution. The final
gate was:

```text
frozenUnchanged = 1
```

No D/K/F estimator equation, Q/R, `P0_F/Q_F`, V2.5 baseline, wrapper, fusion
target, or scheduler was modified. NIS, `abs(r)`, disagreement, covariance,
and online truth do not appear in the core input contract. `P_AF` remains
undefined.

READY FOR V2.7-A3R8 SIMULINK WRAPPER AND INTEGRATION TARGET
