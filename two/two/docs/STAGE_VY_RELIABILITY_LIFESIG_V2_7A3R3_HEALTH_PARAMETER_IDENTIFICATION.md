# V2.7-A3R3 Online Health-Gate Parameter Identification and Identifiability Audit

## Stage verdict

```text
PARTIAL_PARAMETER_FREEZE_REQUIRES_FORMULATION_REVISION
```

Only `tau_F` has sufficient identification and stability evidence. `p_NIS`
and `r0` remain unfrozen. This is a pure offline audit of the five
`NON_HOLDOUT_RELIABILITY_CALIBRATION` datasets; no model was loaded, no
`sim()`/CarSim runtime or holdout data was used, and no fused RMSE, Q/R,
estimator, or fusion parameter was optimized.

## Input set and integrity

The input set is exactly:

```text
FWCAL_C01R1
FWCAL_C02
FWCAL_C03
FWCAL_C04
FWCAL_C05
```

Each dataset supplied 1601 aligned samples on the frozen 0–16 s, 100-Hz
grid. The source SHA-256 values remain the A2R8 values:

| Maneuver | SHA-256 |
|---|---|
| FWCAL_C01R1 | `BA2546C4FB18810197B0ED721B9D83E1C14CB1354B75B64FF6E960A226B70864` |
| FWCAL_C02 | `7942F1612A055B906DD9012E3D5A2F53314FB5E2560370CCD0BF901243AD589B` |
| FWCAL_C03 | `30C12ED01DC1C1E044D4154E7476794306F3231DE414F7E4CFBA3E88D450400A` |
| FWCAL_C04 | `2E003C60081F959FFD36B317A94D1AD9CE9DF8FECE9CB63794B298A37B4F01A5` |
| FWCAL_C05 | `2BA043D6536816A5DCE77831D3A34D0CF952FCD145377512CADAB584047F5C6F` |

## `p_NIS` nominal false-alarm audit

The audited standard CDF probabilities were `0.95`, `0.975`, `0.99`,
`0.995`, and `0.999`. For every valid sample, the D threshold used the
actual logged measurement dimension (1 for yaw-only and 2 for Ay+r); K used
dimension 1. Vy error was not used anywhere in this audit.

Equal-maneuver summaries are:

| Track | p_NIS | Nominal false alarm | Observed exceedance mean (range) | Mean gate (range) |
|---|---:|---:|---:|---:|
| D | 0.95 | 0.05 | 0.00124922 (0–0.00187383) | 0.99912551 (0.99849660–1) |
| D | 0.975 | 0.025 | 0.00124922 (0–0.00187383) | 0.99922929 (0.99860767–1) |
| D | 0.99 | 0.01 | 0.00124922 (0–0.00187383) | 0.99936926 (0.99875864–1) |
| D | 0.995 | 0.005 | 0.00087445 (0–0.00187383) | 0.99945907 (0.99883835–1) |
| D | 0.999 | 0.001 | 0.00062461 (0–0.00124922) | 0.99952006 (0.99886904–1) |
| K | 0.95 | 0.05 | 0 (0–0) | 1 (1–1) |
| K | 0.975 | 0.025 | 0 (0–0) | 1 (1–1) |
| K | 0.99 | 0.01 | 0 (0–0) | 1 (1–1) |
| K | 0.995 | 0.005 | 0 (0–0) | 1 (1–1) |
| K | 0.999 | 0.001 | 0 (0–0) | 1 (1–1) |

These results show stable gate duty, but they do not identify a unique
statistical design value. D uses the same very small set of exceedance events
over `p=0.95..0.99`, while K has no exceedance at any candidate. Selecting a
candidate from these records would therefore amount to imposing an unstated
false-alarm preference rather than identifying a parameter. No frozen
nominal false-alarm budget exists in A3R2.

```text
p_NIS_STATUS = NOT_IDENTIFIABLE_NOT_FROZEN
p_NIS_VALUE  = NOT_FROZEN
```

A future revision must first state the acceptable nominal anomaly false-alarm
probability or an equivalent requirements-level criterion; it must not use Vy
error or fused RMSE to choose `p_NIS`.

## `tau_F` identification

The frozen A3R1 static F risk was used as the reference:

```text
R_F = 0.5587954528841641 (m/s)^2
```

The 0–16 s age range was divided into deterministic one-second bins. For each
bin, raw `e_F^2=(Vy_F-Vy_true)^2` was averaged within each maneuver and then
equally across maneuvers. The relative health target was frozen for this
identification as:

```text
h_target(t_bin) = min(1, R_F / risk_F(t_bin))
```

The positive scalar `tau_F` minimized equal-bin squared error between that
target and the already frozen health shape:

```text
h_model(t) = exp(-t/tau_F)
```

Full-set result:

```text
tau_F = 28.252990189369939 s
objective = 0.026000712868902175
log(tau) profile curvature = 0.10878820308826698
```

The nonzero profile curvature and the tightly grouped LOO solutions establish
local identifiability. LOO results are:

| Omitted | tau_F (s) | Objective | Relative shift |
|---|---:|---:|---:|
| FWCAL_C01R1 | 28.251186265449434 | 0.025992700858421466 | 0.00006384896 |
| FWCAL_C02 | 28.255037576322657 | 0.026008033565677924 | 0.00007246620 |
| FWCAL_C03 | 28.255638734317365 | 0.026004792208754509 | 0.00009374388 |
| FWCAL_C04 | 28.247567775970875 | 0.025988808711496669 | 0.00019192352 |
| FWCAL_C05 | 28.255544999814266 | 0.026009299609161398 | 0.00009042620 |

Thus the LOO range is `28.247567775970875–28.255638734317365 s`; the maximum
relative displacement is only `0.00019192352252696583` (0.0192%). The fit is
not exact: the capped relative-risk target remains one through the early-age
low-risk bins, whereas an exponential begins decaying immediately. This
model-shape residual is explicitly retained in the objective and is not
hidden by performance tuning. It does not undermine the numerical
identifiability or cross-maneuver stability of the best parameter within the
already frozen exponential formulation.

```text
tau_F_STATUS = IDENTIFIABLE_AND_STABLE_FROZEN
tau_F_FROZEN = 28.252990189369939 s
```

## `r0` structural identifiability

`abs(r)` is causal and available online, but A2R9 established that it is not a
stable K error predictor. The present K dynamics establish only that yaw rate
controls the structural coupling; they do not define a unique physical scale
at which `abs(r)/(abs(r)+r0)` must equal a particular health. No frozen
observability-conditioning target, coupling-gain requirement, or allowable
near-zero-yaw region exists from which `r0` can be derived.

Using `e_K^2`, fused RMSE, the historical `0.01 rad/s` plotting partition, or
manual maneuver preferences to manufacture this scale is prohibited.

```text
r0_STATUS = NOT_IDENTIFIABLE_NOT_FROZEN
r0_VALUE  = NOT_FROZEN
```

## Freeze summary and remaining blocker

```text
p_NIS = NOT_FROZEN
tau_F = 28.252990189369939 s  [FROZEN]
r0    = NOT_FROZEN

OVERALL = PARTIAL_PARAMETER_FREEZE_REQUIRES_FORMULATION_REVISION
```

The A3R2 equations, A3R1 priors, pairwise-disagreement diagnostic-only role,
covariance exclusion, and `P_AF=NOT_DEFINED` remain unchanged. No
implementation stage is ready until requirements-level semantics resolve
`p_NIS` and the K structural observability scale or revise the corresponding
gates.

## Evidence

- `results/vy_reliability_lifesig_v2_7a3r3_health_parameter_audit.mat`
- `results/vy_reliability_lifesig_v2_7a3r3_pnis_audit.csv`
- `results/vy_reliability_lifesig_v2_7a3r3_pnis_summary.csv`
- `results/vy_reliability_lifesig_v2_7a3r3_tau_f_bins.csv`
- `results/vy_reliability_lifesig_v2_7a3r3_tau_f_target_fit.csv`
- `results/vy_reliability_lifesig_v2_7a3r3_tau_f_loo.csv`
- `results/vy_reliability_lifesig_v2_7a3r3_health_parameter_decision.csv`
