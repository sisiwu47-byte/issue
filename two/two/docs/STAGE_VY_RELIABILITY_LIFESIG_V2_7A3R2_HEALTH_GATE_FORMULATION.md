# V2.7-A3R2 Online Health-Gate Formulation Freeze

## Scope and evidence basis

This stage freezes the online health-gate mathematics only. It reads the A3
architecture, A3R1 priors, A2R1/A2R2 interface contract, current diagnostic
source semantics, and A2R8/A2R9 evidence. No MATLAB, Simulink, CarSim, `sim()`,
parameter fitting, Q/R tuning, code implementation, or holdout data is used.

The frozen A3R1 priors are:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
```

## Chi-square threshold semantics

For a measurement dimension `m` and a probability `p_NIS`:

```text
T(p_NIS,m) = F_chi2_m_inverse(p_NIS)
0 < p_NIS < 1
```

`F_chi2_m_inverse` is the chi-square quantile satisfying
`Pr(ChiSquare_m <= T)=p_NIS`. This is a one-sided upper anomaly threshold:
large NIS is attenuated; a valid small or exactly zero NIS receives gate one.
The numerical value of `p_NIS` is deliberately not frozen.

The runtime implementation need not call a toolbox quantile function. After
A3R3 freezes `p_NIS`, the positive scalar thresholds for dimensions 1 and 2
may be computed deterministically and supplied as parameters. This preserves
the mathematical definition without imposing a runtime Statistics Toolbox or
code-generation dependency.

## D-track health

The existing D contract provides `NIS_D`, `update_valid_D`, `nis_valid_D`,
`measurementDimension_D`, and `useAy_D`. Source inspection confirms:

- `measurementDimension_D=1` on the yaw-only update;
- `measurementDimension_D=2` on the Ay+r update;
- `NIS_D` is computed from the matching scalar or two-dimensional innovation;
- the validity flag is false on an invalid or unexecuted update, even when the
  stored NIS fallback value is zero.

Define:

```text
m_D = measurementDimension_D
T_D = T(p_NIS,m_D)

valid_D = update_valid_D && nis_valid_D
          && isfinite(NIS_D) && NIS_D >= 0
          && m_D in {1,2}

G_D_NIS = 0                         if valid_D = 0
G_D_NIS = 1                         if valid_D = 1 and NIS_D <= T_D
G_D_NIS = T_D / NIS_D               if valid_D = 1 and NIS_D > T_D

H_D = G_D_NIS
```

Thus a normal zero innovation/NIS remains valid with `H_D=1`, while an
invalid-path zero cannot masquerade as high health. D NIS is only an update
anomaly/consistency gate and is not interpreted as a continuous Vy-error
predictor.

## K-track health

The existing K contract provides scalar `NIS_K`, `update_valid_K`,
`nis_valid_K`, and `obs_metric_K=abs(r)`. Its measurement is the single scalar
Vx update, so its chi-square dimension is exactly one:

```text
T_K = T(p_NIS,1)

valid_K = update_valid_K && nis_valid_K
          && isfinite(NIS_K) && NIS_K >= 0

G_K_NIS = 0                         if valid_K = 0
G_K_NIS = 1                         if valid_K = 1 and NIS_K <= T_K
G_K_NIS = T_K / NIS_K               if valid_K = 1 and NIS_K > T_K

r0 > 0                              [rad/s]
G_K_obs = abs(r)/(abs(r)+r0)         if abs(r) is finite
G_K_obs = 0                          otherwise

H_K = G_K_NIS * G_K_obs
```

K NIS is only update-health evidence. `abs(r)` is only a structural
near-unobservability gate: it is zero at `r=0`, increases monotonically, and
approaches one for yaw excitation large relative to `r0`. It is not claimed
to continuously predict K state error. The historical `0.01 rad/s` plotting
partition is not reused as `r0`; the value of `r0` remains unfrozen.

## F-track health

The F reliability port supplies `propagation_age_steps`, `age_valid`, and
`reset_valid` on the same propagation hit. The current diagnostic target is
100 Hz, so its established sample interval is `Ts=0.01 s`:

```text
t_age = propagation_age_steps * Ts
tau_F > 0                            [s]

H_F = 0                              if age_valid=0 or age is invalid
H_F = exp(-t_age/tau_F)              if age_valid=1
```

The established age convention remains reset hit `0`, first successful
non-reset propagation `1`, then one increment per accepted hit. Consequently,
a valid reset hit has `t_age=0` and `H_F=1`. `reset_valid` remains a boundary
diagnostic; `age_valid` is the health availability mask. `tau_F` remains
unfrozen.

## Normal fusion path

For `i in {D,K,F}`:

```text
score_i = q_i * H_i
```

When and only when `score_D+score_K+score_F > 0`:

```text
alpha_i = score_i / (score_D + score_K + score_F)
Vy_LS = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

Every normal-path health, score, and weight is in `[0,1]`; weights are
nonnegative and sum to one. The all-score-zero fallback remains explicitly
unfrozen, so A3R2 does not silently define an output on that branch.

## Frozen exclusions

- Pairwise disagreement remains `DIAGNOSTIC_ONLY`.
- Raw or confidence-calibrated covariance is not reintroduced as the primary
  cross-track weight source.
- `P_AF = NOT_DEFINED`; no BLUE or statistically optimal covariance claim is
  made.
- Online `Vy_true`, maneuver ID, future samples, holdout-derived switching,
  and maneuver-specific rules remain forbidden.
- No smoothing/window, LifeSig parameter, NIS probability, `r0`, `tau_F`, or
  fallback value is frozen here.

## Interface-compatibility verdict

The formulas match the implemented signal semantics: D exposes the actual
one- or two-dimensional update dimension and valid-masked NIS; K exposes a
valid-masked scalar NIS and causal current `abs(r)`; F exposes same-hit age and
validity at 100 Hz. No additional estimator algorithm is required for this
formulation.

```text
V2.7-A3R2 ONLINE HEALTH-GATE FORMULATION FREEZE PASSED
```

READY FOR V2.7-A3R3 ONLINE HEALTH-GATE PARAMETER IDENTIFICATION
