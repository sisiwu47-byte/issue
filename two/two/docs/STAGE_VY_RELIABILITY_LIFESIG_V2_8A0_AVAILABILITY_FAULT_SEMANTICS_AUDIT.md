# V2.8-A0 D/K/F Availability and Fault-Semantics Read-Only Audit

## Verdict

```text
MIXED_SEMANTICS_REQUIRES_MINIMAL_INTERFACE_REVISION
```

The current formal LifeSig availability signals are not uniform physical-track credibility indicators and do not constitute a complete explicit dropout contract. D, K, and F expose different mixtures of post-update numerical success, sanitized-input behavior, assertion-stop behavior, and propagation-boundary validity.

This was a read-only source/evidence audit. No MATLAB, Simulink, CarSim, or `sim()` execution was performed. No implementation, model, estimator, parameter, target, or historical evidence was modified.

## Formal V2.7 availability consumer

The frozen LifeSig core consumes:

```text
activeD = update_valid_D && isfinite(Vy_D)
activeK = update_valid_K && isfinite(Vy_K)
activeF = age_valid_F
          && isfinite(propagation_age_steps)
          && propagation_age_steps >= 0
          && isfinite(Vy_F)
```

Only these quantities affect track participation. `nis_valid_D/K`, NIS, `abs(r)`, `reset_valid`, disagreement, covariance, and truth are not formal weight inputs.

The integration target routes D valid-vector element 1, K diagnostic element 6, and F reliability elements 1/2 to the LifeSig wrapper. The accepted target hash is `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0`.

## D-track audit

### Actual validity path

`vy_dynamic_ekf_v1_17` always executes at 100 Hz. Its `useAy` schedule selects either:

- a two-dimensional Ay+r update when `useAy=true`; or
- a genuine one-dimensional yaw-rate update when `useAy=false`.

The wrapper returns:

```text
update_valid_D = info.updateValid
nis_valid_D = info.updateValid
```

For the Ay+r path, `vy_dynamic_ekf_step_v13` sets `updateValid=true` only after an accepted innovation/S matrix, successful update, finite NIS, and finite state/covariance. Invalid denominator or caught update failure leaves it false and falls back to prediction.

However, the same core first applies `safe_vector` to state, inputs, and measurements; every nonfinite vector element is silently replaced by zero. Consequently, a raw NaN/Inf in `u` or in the scheduled Ay+r measurement may be converted to a finite zero before `updateValid` is evaluated, allowing `update_valid_D=1`. This flag therefore does not prove raw-signal integrity.

For the yaw-only path, `vy_dynamic_ekf_step_v17` recomputes yaw innovation using its original `z(2)`. A nonfinite yaw measurement therefore normally leaves `updateValid=false`; a nonfinite Ay value on a yaw-only hit is not assimilated and does not invalidate the valid yaw update.

### Multirate meaning

`useAy=false` is not a missing-update event. Prediction and yaw update still run at 100 Hz, `measurementDimension_D=1`, and a successful yaw-only update keeps D available. Thus normal 20-Hz Ay scheduling does not create four D availability drops between Ay hits.

### Physical-fault limitation

There is no separate D measurement-present, freshness, finite-before-sanitization, bias, or freeze flag. Finite constant bias and a finite frozen signal can complete the EKF update and remain available. D availability is primarily post-sanitization update numerics, not physical credibility.

## K-track audit

### Actual validity path

`vy_kinematic_kf` and `vy_kinematic_kf_step` require finite `z`, reset, x/P, all three IMU inputs, Q, and a positive finite innovation covariance. `updateValid` is returned only after finite innovation, S, NIS, state, and covariance.

Unlike D, invalid raw values are not sanitized into zero. The wrapper/step uses assertions. A NaN/Inf Vx measurement or IMU input normally raises an execution error before a clean `update_valid_K=0` value can be emitted. Some downstream nonfinite update results can set `updateValid=false`, but several important invalid-input/S paths terminate the block rather than gracefully withdrawing K from LifeSig.

There is no explicit Vx measurement-present/freshness input. A finite stale or frozen Vx measurement and a finite constant bias normally produce a mathematically completed update and `update_valid_K=1`. NIS and `abs(r)` may describe the condition diagnostically but are frozen as `DIAGNOSTIC_ONLY` and cannot remove K from the formal fusion.

### Reset meaning

A finite asserted K reset initializes x/P and then passes the current sample through the ordinary prediction/update path. With valid inputs, K remains available on that same hit. Reset is not a K availability drop.

## F-track audit

### Actual reliability path

The F S-function returns:

```text
[propagation_age_steps; age_valid; reset_valid]
```

At a finite active reset, age is zero. On each successful non-reset propagation it increments by one. `age_valid` requires finite boundary state/input values, finite Vy/P/diagnostics, and nonnegative P.

`reset_valid` means the reset input is finite and its decision is deterministically readable; it is not the reset-active flag and is not consumed by LifeSig.

### Important failure asymmetry

The F mathematical core asserts finite Ay, AVz, Vx, reset, and selected prior/feedback values. A nonfinite primary propagation input therefore normally stops execution before the S-function can emit `age_valid=0`.

There is a narrower boundary case where the core can still return from delayed memories while a current non-direct-feedthrough feedback input is nonfinite; the S-function's broader `finiteInputs` test then emits `age_valid=0`, and LifeSig removes F. This makes F validity behavior different from both D and K.

Finite Ay/AVz/Vx bias or a finite frozen sensor is not detected: propagation can remain numerically valid, age continues, and F remains in the formal fusion with its ordinary age decay. Age is degradation evidence, not a freeze/bias detector.

### Formal F exit conditions

F leaves LifeSig only when the wrapper successfully supplies a false `age_valid`, a nonfinite/negative age, or nonfinite `Vy_F`. Many primary numerical input failures instead raise an error before a graceful track exit. Reset normally produces valid age zero and `H_F=1`, so it does not withdraw F.

## Fault-semantics matrix

| Fault/event | D availability | K availability | F availability | Detectable by current LifeSig? | Evidence/code path |
|---|---|---|---|---|---|
| Raw NaN | Mixed: scheduled Ay+r/u values may be zero-sanitized and remain 1; yaw NaN on yaw-only path normally yields 0 | Usually assertion/runtime failure before a clean 0 | Primary propagation NaN usually asserts before output; limited current-feedback case can yield `age_valid=0` | Not reliably | D `safe_vector`; D v17 yaw check; K finite assertions; F core assertions and S-function `finiteInputs` |
| Raw Inf | Same mixed behavior as NaN | Usually assertion/runtime failure before a clean 0 | Same mixed behavior as NaN | Not reliably | Same paths as NaN |
| Explicit dropout/missing update | No explicit present/freshness input; normal yaw-only update remains available | No explicit Vx-present/freshness input | No explicit propagation-input-present/freshness input | No | Interfaces expose success flags, not raw-source availability flags |
| Finite constant bias | Normally remains 1 | Normally remains 1 | Normally remains 1 | No | Finite mathematical update/propagation succeeds; NIS is diagnostic-only |
| Finite frozen/stale signal | Normally remains 1 | Normally remains 1 | Normally remains 1 while age continues | No | No freshness/change detector in formal availability |
| Estimator numerical/update failure | Can become 0 when invalid denominator/caught/finite-output checks reach `updateValid=false`; some raw invalids are sanitized | Can become 0 for returned invalid update results, but assertion paths stop execution | Can become 0 only when S-function returns and `propagationSucceeded=false`; many failures assert first | Partially, only for clean returned invalid flags | D `updateValid`; K `updateValid`; F `age_valid` |
| Finite reset | Not an explicit D input; initialization/mode reset is followed by update | Reset initializes then updates; normally remains 1 | Reset age=0, normally `age_valid=1`, `H_F=1` | Reset is visible to fusion memory but is not a track dropout | D wrapper persistent semantics; K reset branch; F reset branch; LifeSig reset order |
| Normal multirate no-Ay event | Remains available after successful 1-D yaw update; `measurementDimension_D=1` | Not applicable: Vx update remains 100 Hz | Normal 100-Hz propagation remains available | Correctly not treated as a fault | D v17 yaw-only update; K/F 100-Hz paths |
| Valid zero innovation/NIS | Available | Available | Not applicable | Availability remains true as intended | Validity is independent of NIS numeric zero |
| Nonfinite fused track state at LifeSig input | Forced unavailable by `isfinite(Vy_D)` | Forced unavailable by `isfinite(Vy_K)` | Forced unavailable by `isfinite(Vy_F)` | Yes, if wrapper invocation itself is reached | `vy_lifesig_fusion_step` active-track guards |

## Computation validity versus physical credibility

Current formal availability proves at most that a particular code path produced a numerically usable update/propagation result and finite LifeSig state input. It does not prove that the sensor is fresh, unbiased, unfrozen, physically plausible, or representative of a trustworthy track.

The implementations are also not uniform enough to describe the contract simply as one clean numerical-validity layer:

- D may sanitize raw invalid data before validity evaluation;
- K commonly asserts on raw invalid data instead of emitting availability zero;
- F combines a propagation-success mask with assertions and an age signal.

Accordingly, explicit track-dropout validation would require a minimal, separately frozen raw-boundary validity/freshness contract and graceful propagation of those flags to LifeSig. This audit does not design that interface or any detector.

## Nominal-runtime boundary

A3R10 observed:

```text
availability drops [D K F] = [0 0 0]
fallback count             = 0
```

This proves only that the nominal 16-s run remained on the normal path. It must not be extrapolated into evidence that NaN, Inf, dropout, bias, signal freeze, estimator failure, or physical track unreliability is detected or safely isolated at runtime.

## Integrity anchors

| Artifact | SHA-256 |
|---|---|
| `model/vy_dynamic_ekf_v1_17.m` | `1AE909CF8118663F859EBC9F844374D97AB4238F701745EAC49A380498CE8AE5` |
| `model/vy_dynamic_ekf_step_v17.m` | `8D3EED4EA85E5E4B26D02473171D2E65E4472A374E6E9AA16797A6D92CEBD49E` |
| `model/vy_dynamic_ekf_step_v13.m` | `ADC56DF50B0C11F90074639D1825FBF8173B4E0AC4135D9618FB8D085F3EB928` |
| `model/vy_dynamic_ekf_v1_17_reliability_numeric.m` | `C1D336FE4D281687C039A903C023D0CF5709EA1A43CED799DE8A84124FE7DCC3` |
| `model/vy_kinematic_kf.m` | `73A06F593E0D52B3A168445060F6CA68B35D2F710A913DD16213CDC71FF92298` |
| `model/vy_kinematic_kf_step.m` | `383A5A63AC11C3F43BAE1CA7B6993A1C181363F970CD1BA347D4FF8521727740` |
| `model/vy_feedback_propagation_simulink_sfun.m` | `AA3E9E79D81D1C3D8155D4FF04ED952357B0294E09DF868FEBC7E05753E64FD8` |
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| `model/vy_lifesig_fusion_step.m` | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| `model/vy_lifesig_fusion_simulink_sfun.m` | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |
| `model/vx_vy_lifesig_fusion_v2_7.slx` | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |

