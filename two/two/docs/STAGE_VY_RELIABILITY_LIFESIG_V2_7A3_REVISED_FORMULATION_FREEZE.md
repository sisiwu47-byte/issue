# V2.7-A3 REVISED LIFESIG FUSION FORMULATION FREEZE

## Evidence basis and scope

A2R9 found weak/cross-maneuver-variable D normalized-NIS evidence, inadequate
K NIS/`abs(r)` continuous error-risk evidence, and stable monotonic F-age
evidence. A2R10 found pairwise disagreement useful only as an inconsistency
diagnostic and insufficient for stable track attribution. Therefore no more
disagreement attribution rule or covariance-only cross-track mapping will be
fit.

This stage freezes architecture only. No numerical prior, threshold, health
mapping, fallback, LifeSig parameter, model, or code is implemented; no MATLAB,
Simulink, CarSim, holdout, Q/R tuning, or fusion-performance optimization is
performed.

## Frozen normal-path architecture

For `i in {D,K,F}`:

```text
q_i > 0
0 <= H_i <= 1
score_i = q_i * H_i
```

When at least one score is strictly positive:

```text
alpha_i = score_i / (score_D + score_K + score_F)
Vy_LS = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

This guarantees nonnegative normal-path weights and unit sum. A common positive
scale on all `q_i` cancels during normalization; A3R1 must therefore use a
deterministic normalization convention when it identifies the priors. The
behavior when all scores are zero is explicitly deferred and is not silently
filled by the V2.5 weights in this stage.

## Static quality priors

`q_D`, `q_K`, and `q_F` are positive, offline, static estimator-quality priors.
Their candidate evidence source is the frozen non-holdout calibration set and
the equal-maneuver single-track MSE/error risk for each estimator. They are not
identified from fused RMSE, holdout performance, maneuver ID, or online truth.

A3 freezes neither their values nor the exact risk-to-prior transformation.
Those belong to A3R1 and must be fixed before any runtime implementation.

## Online health-gate roles

### D

```text
H_D = availability_D * update_health_D
```

`update_valid_D/nis_valid_D` are availability evidence. D NIS may be used only
as an update anomaly/consistency gate. A2R9 does not support interpreting it as
a continuous Vy state-error predictor. No NIS threshold or mapping is frozen.

### K

```text
H_K = availability_K * update_health_K * structural_observability_K
```

K validity is availability evidence; K NIS is only an update-health/anomaly
gate. `abs(r)` is only a near-unobservable structural gate and must not be
claimed to continuously predict K error. No NIS mapping, yaw threshold, or
`r0` is frozen.

### F

```text
H_F = availability_F * age_health_F
```

`age_valid/reset_valid` provide availability. Propagation age is retained as
continuous degradation evidence because A2R9 showed a stable monotonic
cross-maneuver error-risk relationship. The mapping and `tau_F` remain
unfrozen.

Invalid evidence cannot be interpreted as high health. All online health
logic must remain causal and may use only current/past diagnostic values.

## Explicit boundaries

- Pairwise disagreement is `DIAGNOSTIC_ONLY`; it is not a formal score/weight
  input and is not used for track attribution.
- Raw or confidence-calibrated covariance is no longer the primary cross-track
  weight source. Estimator covariance may remain available for estimator-local
  and diagnostic use.
- `P_AF = NOT_DEFINED`; no BLUE/statistically optimal covariance claim is made.
- Online `Vy_true`, maneuver ID, future samples, holdout switching, and
  maneuver-specific rules are prohibited.
- No machine-learning/nonlinear classifier, Q/R tuning, fixed-weight retuning,
  or fused-RMSE optimization is authorized.

## Parameters deliberately not frozen

```text
q_D, q_K, q_F
D/K NIS threshold or health mapping
K near-unobservable mapping and r0
F age mapping and tau_F
epsilon/numerical details
all-scores-zero fallback
```

## Architecture verdict

The required diagnostic interfaces already exist, are causal, and were
captured successfully in A2R8. A2R9/A2R10 impose interpretation limits but do
not create a structural interface blocker for the revised architecture.

**V2.7-A3 REVISED LIFESIG FUSION FORMULATION FREEZE PASSED**

READY FOR V2.7-A3R1 STATIC QUALITY PRIOR IDENTIFICATION
