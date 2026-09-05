# V2.7-A3R8R1 Core Health-Diagnostic Output Remediation

## Current stage status

```text
V2.7-A3R8R1 CORE REMEDIATION PASSED
V2.7-A3R8 SIMULINK INTEGRATION BLOCKED DURING BUILDER EVIDENCE PACKING
```

The authorized core diagnostic-output remediation and wrapper compile-only
test passed. The independent target was saved, but the builder then failed
while packaging evidence. Per the stage stop rule, no repair or second build
was attempted and the target validator was not run.

## Core remediation

`vy_lifesig_fusion_step` now appends three outputs after all original eight
outputs:

```text
H_D
H_K
H_F
```

They are the exact internal values used to form the three scores. No second
health calculation was added. The positions and semantics of `Vy_LS`, all
alpha values, validity/fallback flags, next memory values, reset behavior,
priors, `tau_F`, `Ts`, availability rules, and fallback behavior remain
unchanged.

Final core regression evidence:

```text
A3R7_UNIT|passed=24/24|all=1|frozen=1
A3R8R1_CORE_TEST_OK
```

The added tests verify all health outputs, invalid health semantics, exact F
age health, and 1000 deterministic randomized comparisons of the original
eight outputs against the pre-remediation A3R7 transition. The first eight
outputs were bitwise equivalent in every comparison.

## Wrapper result

`vy_lifesig_fusion_simulink_sfun` was created with:

```text
inputs  = 8 scalar doubles
outputs = 9 scalar doubles
DWork   = 2 scalar doubles
sample time = [0.01 0]
```

The two DWork values are `last_valid_Vy_LS` and `has_last_valid`. The wrapper
contains no priors, tau, exponential, score, normalization, fallback, or reset
mathematics; both Outputs and Update delegate to the core.

Wrapper compile-only result:

```text
A3R8_WRAPPER|static=1|compile=1|term=1|passed=1|sim=0|carsim=0
```

## Builder failure and stop point

The builder copied the accepted diagnostic target to the independent file and
saved the LifeSig blocks and logs. It then closed the model and attempted to
call `port_identity` on source port handles retained from the closed model.
Those handles were no longer valid.

Exact first failure:

```text
build_vy_lifesig_fusion_v2_7a3r8>port_identity (line 133)
Invalid Simulink object

build_vy_lifesig_fusion_v2_7a3r8 (line 97)
build.inputSources={port_identity(dVy); ...}
```

This is an evidence-packing lifecycle defect after `save_system`, not a core
or wrapper numerical failure. Because the exception occurred before the build
report was saved and before the validator was invoked:

```text
build evidence MAT = ABSENT
target compile evidence MAT = ABSENT
target compileCalled = 0
target acceptance = NOT ESTABLISHED
```

The load step also emitted a warning that the `Solver_SF` library was not
found in that builder session. The target compile never ran, so this warning
remains unresolved and is not promoted to a compile failure diagnosis.

The minimal future repair is limited to builder evidence packaging: convert
the required source port identities to strings before closing the model (or
store the already-known block/port strings directly). A later authorized run
must also load the accepted D-drive `Solver_SF` lineage before target
load/compile. No algorithm, wrapper, target connection, or frozen baseline
change is implied by that repair.

## Artifacts and hashes

| Artifact | SHA-256 |
|---|---|
| `model/vy_lifesig_fusion_step.m` | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| `model/test_vy_lifesig_fusion_v2_7a3r7.m` | `169E4E492DBB19FC64984815CAA4179A4AC452C7FD97968273CA4DD9E07BCA98` |
| `results/vy_reliability_lifesig_v2_7a3r7_unit_tests.mat` | `306E5BE2890C0570637C0B6DAD9E1652B088ADE36566EF22FDEC92679F20723E` |
| `model/vy_lifesig_fusion_simulink_sfun.m` | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |
| `model/test_vy_lifesig_fusion_simulink_wrapper_v2_7a3r8.m` | `2884B3A4D8FFF2B3FE97FCA2AD8EDDD26BCC5D6FE9CEF281E2BE6B1693532F85` |
| `results/vy_reliability_lifesig_v2_7a3r8_wrapper_test.mat` | `9EB569F17E70B2C7E2E94E1656A4C4D659FA1FFB077EBE063D0258D7389D42FA` |
| `model/vx_vy_lifesig_fusion_v2_7.slx` | `4C134667E94E4D56D53BC2B96D92D5693E74DE36A8CD68561B80811EFC5D6A79` |

The source diagnostic target remained exactly:

```text
model/vx_vy_reliability_diagnostic_v2_7.slx
SHA-256 = 2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F
```

No D/K/F estimator, Q/R, `P0_F/Q_F`, V2.5 baseline, prior, tau, or frozen
baseline was modified. `sim()` and CarSim runtime were not executed.
