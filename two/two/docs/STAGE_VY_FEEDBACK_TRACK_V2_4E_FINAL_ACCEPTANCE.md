# V2.4-E Feedback / Propagation Track Final Acceptance & Implementation Freeze

## 1. Final decision

**V2.4-E FEEDBACK / PROPAGATION TRACK ACCEPTED AND IMPLEMENTATION-FROZEN**

本阶段仅对既有文件、阶段状态、机器证据和冻结哈希做独立只读验收。没有启动 MATLAB，没有 compile、`sim()`、CarSim、rebuild 或 `save_system`，没有修改模型、数学核心、S-function、D/K/DK-EKF/parallel target，也没有实施 fusion、LifeSig、reliability logic 或调参。

冻结范围是第三 F-track 的 architecture、mathematical equation、interface、state/covariance memory、feedback delay、reset 和 one-hit/one-commit implementation semantics。`P0_F` 与 `Q_F` 的具体设计数值明确排除在参数冻结之外。

## 2. Evidence acceptance matrix

| Stage | Actual machine/document evidence | Acceptance |
|---|---|---|
| V2.4-A architecture | scalar `Vy_F/P_F`; 100-Hz propagation; delayed-feedback and anti-algebraic-loop contract; no true Vy/D/K/fusion | PASS |
| V2.4-B mathematical core | 34/34; sign regression `prop_term=-1`, `deltaVy=-0.01`; 10,000-step finite/nonnegative/deterministic; stateless core | PASS |
| V2.4-C Simulink integration | static 52/52; compiled 12/12; compile called/passed/terminated/evidence = 1/1/1/1 | PASS |
| V2.4-D0 runtime interface | static 35/35; compiled 11/11; estimator integration unchanged; deterministic source copy registered | PASS |
| Original V2.4-D runtime | 21 hits/100 Hz; initial reset and one-sample delay passed; second-reset gates failed; 19/23 retained | RESOLVED INFRASTRUCTURE EVIDENCE |
| V2.4-D1 forensic | breakpoint `0.15000000000000002` versus F hit `0.14999999999999999`; difference `2.7755575615628914e-17 s` | ROOT CAUSE IDENTIFIED |
| V2.4-D2 corrected runtime | timeline 21/21 exact; max difference 0; 21 hits/100 Hz; analyzer 24/24; replay Vy/P/diag = 0/0/0 | PASS |

Direct read-only MATLAB-v5 evidence extraction confirmed the stated gate counts and values. No test was rerun to reproduce evidence.

## 3. Frozen mathematical definition

State and scalar covariance:

```text
state:      Vy_F
covariance: P_F = Var(Vy_F)
rate:       100 Hz
Ts:         0.01 s
```

At each non-reset hit:

```text
prop_term = Ay_IMU - AVz_IMU*Vx_source
deltaVy   = Ts*prop_term

if feedback_valid_z1:
    Vy_base = Vy_feedback_z1
    P_base  = P_feedback_z1
else:
    Vy_base = Vy_prev
    P_base  = P_prev

Vy_F = Vy_base + deltaVy
P_F  = P_base + Q_F
```

Diagnostic ordering is immutable:

```text
diag_F = [prop_term; deltaVy; feedbackApplied]
index 1 = prop_term
index 2 = deltaVy
index 3 = feedbackApplied
```

The core is stateless. It contains no measurement correction, Kalman gain, Vx state, yaw-rate state, D/K input, fusion, LifeSig, reliability logic or online true Vy.

## 4. Frozen reset semantics

Reset has highest priority and may occur at any 100-Hz hit:

```text
Vy_F   = Vy_F0
P_F    = P0_F
diag_F = [0;0;0]
```

On that hit there is no propagation, no `Q_F` increment, no delayed-feedback consumption and no current-feedback capture. Update clears/reinitializes the delayed triplet:

```text
Vy_feedback_z1 = Vy_F0
P_feedback_z1  = P0_F
feedback_valid_z1 = 0
```

`RESET MAY OCCUR AT ANY 100-HZ HIT.` It is not an initial-only reset.

V2.4-D2 behaviorally and temporally verified the second reset at index 16: `Vy_F=0`, `P_F=0.5`, `diag_F=[0;0;0]`. At index 17 the output resumed normal propagation with `Vy_F=-0.01`, `P_F=0.5025`, and `feedbackApplied=0`, proving delay clearing and reset-hit feedback rejection.

## 5. Frozen feedback and anti-algebraic-loop contract

The external current feedback ports are:

```text
Vy_feedback_current
P_feedback_current
feedback_valid_current
```

All three are non-direct-feedthrough. They are captured atomically in `Update(k)` and become available only through the matching z^-1 DWorks at hit `k+1`. State, covariance and valid flag must always share the same one-sample delay and the same reset clearing. Delaying only state or only covariance/valid is prohibited.

The frozen future-loop contract is:

```text
fusion(k)
-> feedback current state/P/valid
-> one-sample z^-1
-> F propagation(k+1)
```

The current-sample loop `F(k) -> fusion(k) -> F(k)` is prohibited. Current feedback ports being non-direct-feedthrough is part of the frozen implementation contract.

## 6. Standalone and one-hit/one-commit semantics

When delayed feedback valid is false, F strictly propagates from its own previous `Vy_F/P_F`. The S-function owns exactly five scalar-double DWorks: previous state, previous covariance, delayed feedback state, delayed feedback covariance, and delayed feedback valid.

`Outputs` performs zero DWork/state commits. `Update` performs one committed state/covariance advance per 100-Hz hit and one atomic feedback-triplet capture on each non-reset hit. V2.4-D2 exact same-index replay returned maximum differences `0/0/0`, confirming:

`ONE 100-HZ HIT = ONE COMMITTED F-TRACK STATE/COVARIANCE ADVANCE.`

## 7. Implementation freeze

| Frozen implementation artifact | SHA-256 | Status |
|---|---|---|
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | FROZEN |
| `model/vy_feedback_propagation_simulink_sfun.m` | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | FROZEN |
| `model/vx_vy_feedback_track_v2_4.slx` | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | FROZEN |

The standalone SLX is frozen at its current bit-level implementation state. This does not promote the TEST-ONLY dialog values of `P0_F/Q_F` to accepted design parameters.

## 8. Validation model and tooling classification

`model/vx_vy_feedback_track_v2_4d_runtime.slx` is classified as `REGISTERED_VALIDATION_MODEL`, SHA-256 `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A`. It differs from the primary target only through deterministic top-level stimulus sources. Its From Workspace sources are validation infrastructure and are not the final estimator architecture.

The V2.4-C builder/validator and V2.4-D0 runtime-interface builder/validator are `REGISTERED_TOOLING`, not estimator mathematics. Runners, analyzers, result MAT/CSV files and stage documents are `REGISTERED_EVIDENCE`.

The machine-readable freeze manifest contains 44 rows:

- 3 `FROZEN_IMPLEMENTATION`;
- 1 `REGISTERED_VALIDATION_MODEL`;
- 4 `REGISTERED_TOOLING`;
- 21 `REGISTERED_EVIDENCE`;
- 13 `REFERENCED_FROZEN_DEPENDENCY`;
- 2 `PARAMETER_EXCLUDED_FROM_FREEZE`.

Manifest SHA-256: `3F986E96B0148B6EFE6DD7085644D7F87067DB95C52BA7839C86776DF8B9E1C2`. Every file-backed manifest row was independently rehashed and matched.

## 9. Original failed runtime registration

The following remain present and unchanged:

```text
results/vy_feedback_track_v2_4d_standalone.mat
SHA-256 = 5B1376DCA2884636E675B5AAAD2266707D136DFF85C804B921E209A49D9A5C8C

docs/STAGE_VY_FEEDBACK_TRACK_V2_4D_STATUS.md
SHA-256 = 05C1BC3C25912D8BA521DA5BC3270817FD510F25F818D161D9657832BC543359
```

The original V2.4-D runtime failed its second-reset gate. V2.4-D1 proved that the runner's colon-generated From Workspace breakpoint occurred one representable-double step after the actual function-call hit. V2.4-D2 changed only runner timestamp construction to integer ticks and passed 24/24 with exact replay. No estimator implementation change was needed. The original failed runtime is therefore retained as resolved test-infrastructure evidence rather than hidden or overwritten.

## 10. Parameter freeze exclusion

`P0_F=0.5` and `Q_F=0.0025 (m/s)^2/step` were validation-only values. For both parameters:

```text
TEST-ONLY VALUE USED IN VALIDATION
NOT TUNED
NOT ACCEPTED AS FINAL DESIGN VALUE
NOT PARAMETER-FROZEN
```

Frozen aspects are the parameter locations, units, positivity requirements and covariance propagation equation. The numerical values are not frozen. Future selection/tuning must be a separate explicitly authorized stage.

## 11. Vx and true-Vy policy

`Vx_source` remains a scalar physical longitudinal-speed development input. Standalone tests use deterministic Vx. A future multi-track isolation integration may temporarily use physical true Vx, but replacement `true Vx -> longitudinal estimator vx_hat` requires a separate explicit validation stage and was not implemented here.

`TRUE Vy ONLINE INPUT = NO.` The F core/interface contains no true Vy. True Vy is allowed only for offline validation.

## 12. Relationship to D/K and distinction from K-KF

D-EKF and K-KF remain mutually independent frozen tracks. The standalone F-track has no D state, K state, D/K covariance or fusion feedback. Any future F feedback connection is allowed only through a separately authorized fusion-feedback integration stage using delayed fused state/P/valid. Silent direct routes `Vy_D -> F`, `Vy_K -> F`, `P_D -> F` or `P_K -> F` are prohibited.

K-KF has state `[Vx;Vy]`, a 2x2 covariance and a Vx measurement correction. F-track has only scalar Vy and scalar covariance, has no measurement correction or Vx state, and propagates a previous feedback/own state. `F-TRACK IS NOT A SECOND K-KF.`

## 13. Referenced frozen dependencies

The K-KF V2.1, DK-EKF V2.2 and parallel D/K V2.3 freeze manifests were read. Every `FROZEN` and `REFERENCED_FROZEN_DEPENDENCY` entry was rehashed against the current file with zero mismatch. D-EKF V1 artifacts recorded in the parallel manifest likewise matched.

Status remains:

```text
D-EKF V1 FROZEN
K-KF V2.1 FROZEN
DK-EKF V2.2 FROZEN
Parallel D/K V2.3 FROZEN
```

They are referenced dependencies and were not redefined as a new estimator.

## 14. Known limitations

1. F-track has completed deterministic standalone runtime validation only.
2. Standalone performance has not been characterized using real CarSim dynamic signals.
3. Final fusion does not exist.
4. LifeSig/reliability logic does not exist.
5. `P0_F/Q_F` are not tuned or parameter-frozen.
6. Final fused-feedback closed-loop behavior has not been validated.
7. Sensor degradation and model mismatch have not been validated.
8. The true longitudinal-speed development source has not been replaced by longitudinal `vx_hat`.
9. The original V2.4-D runner timeline issue is resolved by D2 and is not an estimator defect.

## 15. Final acceptance statements

F-TRACK ARCHITECTURE ACCEPTED.

SCALAR PROPAGATION MATHEMATICS ACCEPTED.

SIMULINK STATE / COVARIANCE MEMORY SEMANTICS ACCEPTED.

ONE-SAMPLE FEEDBACK DELAY ACCEPTED.

CURRENT FEEDBACK NON-DIRECT-FEEDTHROUGH ACCEPTED.

RESET PRIORITY AND DELAY CLEARING ACCEPTED.

ONE-HIT / ONE-COMMIT ACCEPTED.

EXACT RUNTIME REPLAY ACCEPTED.

ORIGINAL V2.4-D FAILURE RESOLVED AS RUNNER TIMELINE INFRASTRUCTURE DEFECT.

NO F-TRACK MATHEMATICS WERE MODIFIED DURING THE FIX.

NO D/K COUPLING WAS INTRODUCED.

NO FUSION WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

P0_F AND Q_F REMAIN UNTUNED AND ARE EXCLUDED FROM DESIGN-PARAMETER FREEZE.

NO NEW SIMULATION / COMPILE / CARSIM WAS PERFORMED IN V2.4-E.

READY FOR V2.5-A FIXED-WEIGHT THREE-TRACK FUSION ARCHITECTURE AUDIT
