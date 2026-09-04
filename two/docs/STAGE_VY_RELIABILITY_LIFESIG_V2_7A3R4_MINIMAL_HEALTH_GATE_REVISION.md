# V2.7-A3R4 Minimal Evidence-Supported Health-Gate Revision

## Stage conclusion

```text
V2.7-A3R4 MINIMAL EVIDENCE-SUPPORTED HEALTH-GATE REVISION PASSED
```

This stage revises and freezes formulation only. It uses the frozen A2R9–A3R3
evidence and introduces no new parameter search, implementation, simulation,
CarSim run, Q/R tuning, fused-RMSE optimization, or holdout logic.

## Evidence-driven revision

A3R3 established:

```text
tau_F_FROZEN = 28.252990189369939 s
p_NIS = NOT_IDENTIFIABLE_NOT_FROZEN
r0 = NOT_IDENTIFIABLE_NOT_FROZEN
```

Therefore the formal weight path removes the unsupported NIS and yaw-scale
mappings. Their signals and validity interfaces remain available for
diagnostics, but no numerical value is manufactured for `p_NIS` or `r0`.

## Frozen static priors

The A3R1 priors remain unchanged:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
```

They are static individual-track quality priors, not standalone final fusion
weights.

## Revised D health

The D wrapper's `update_valid_D` is asserted only when the selected update
completed with valid innovation mathematics and finite state/covariance
output. Freeze:

```text
availability_D = update_valid_D && isfinite(Vy_D)
H_D = availability_D
```

`nis_valid_D`, `NIS_D`, and `measurementDimension_D` remain logged diagnostic
evidence. They do not multiply or continuously scale the formal D score.

## Revised K health

The K wrapper's `update_valid_K` is asserted only after a valid scalar Vx
update with finite state/covariance output. Freeze:

```text
availability_K = update_valid_K && isfinite(Vy_K)
H_K = availability_K
```

`nis_valid_K`, `NIS_K`, and `abs(r)` remain diagnostic evidence only. No
historical `0.01 rad/s` plotting threshold is reused, and no `r0` is assigned.

## F health retained

F age was the only online reliability evidence with stable cross-maneuver
error-risk support, and A3R3 identified a stable exponential time scale. With
the current 100-Hz reliability contract:

```text
Ts = 0.01 s
tau_F = 28.252990189369939 s

availability_F = age_valid_F
                 && isfinite(propagation_age_steps)
                 && propagation_age_steps >= 0

t_age = propagation_age_steps * Ts
H_F = availability_F * exp(-t_age/tau_F)
```

Thus invalid age evidence gives zero health. A valid reset hit has age zero
and health one; the first valid propagation has age one and begins the frozen
exponential degradation. `reset_valid` remains a boundary diagnostic.

## Frozen fusion normal path

For `i in {D,K,F}`:

```text
score_i = q_i * H_i
```

When `score_D + score_K + score_F > 0`:

```text
alpha_i = score_i / (score_D + score_K + score_F)
Vy_LS = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

The normal-path scores and weights are nonnegative, and the weights sum to
one. The behavior when all scores are zero is deliberately not frozen; this
stage does not silently substitute V2.5 weights or another fallback.

## Diagnostic-only signals and scientific boundaries

The following are frozen as `DIAGNOSTIC_ONLY` and do not enter the formal
score or weight:

```text
NIS_D / nis_valid_D / measurementDimension_D
NIS_K / nis_valid_K
abs(r) observability evidence
pairwise disagreement
D/K/F covariance
```

These interfaces retain engineering and future validation value. NIS or
observability may re-enter a formal weight only after a separate stage
provides independent anomaly or low-observability evidence and freezes an
identifiable mapping. Existing calibration error, fused RMSE, maneuver ID,
holdout switching, or the historical `0.01 rad/s` diagnostic partition may
not be used to manufacture such a mapping.

Raw or calibrated covariance is not a primary cross-track weight source.
`P_AF = NOT_DEFINED`; no BLUE/statistically optimal covariance claim is made.
Online `Vy_true`, future samples, maneuver-specific logic, and holdout-derived
switching remain forbidden.

## Frozen verdict

The revised formulation is fully specified for its positive-score normal
path using only evidence-supported quantities. It requires no new estimator
interface and leaves the unresolved all-score-zero branch explicit for a
later formulation stage.

READY FOR V2.7-A3R5 REVISED FUSION OFFLINE BEHAVIOR AUDIT
