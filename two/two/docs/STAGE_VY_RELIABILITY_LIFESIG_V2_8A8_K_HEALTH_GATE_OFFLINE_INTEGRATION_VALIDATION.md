# V2.8-A8 K Physical Health Gate LifeSig Offline Integration Validation

## Verdict

`K_PHYSICAL_HEALTH_GATE_OFFLINE_LIFESIG_INTEGRATION_PASS`

The A7 continuous K-health modifier improves the frozen LifeSig output in the
dedicated A3 physical-low-yaw degradation interval without perturbing any of
the five normal FWCAL calibration maneuvers. The result supports a future
minimal implementation, but it does not show superiority over D-EKF and is not
a Simulink/runtime acceptance.

No MATLAB, Simulink, or CarSim process was started. No model, LifeSig source,
estimator, `q`, `tau_F`, Q/R, fallback, or threshold was modified.

## Offline replay contract

The A7 formulation was used unchanged:

```text
r_K0 = 0.01 rad/s
d_K0 = 0.3467656927489074 m/s
d_DK = abs(Vy_K - Vy_D)

L_r = max(0, 1 - abs(AVz_IMU)/r_K0)
L_d = 0                              if d_DK <= d_K0
L_d = 1 - d_K0/d_DK                 if d_DK > d_K0
G_K = 1 - L_r*L_d

H_K_new = H_K_old*G_K
```

All remaining frozen V2.7 LifeSig quantities were retained:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
tau_F = 28.252990189369939 s
H_D = availability_D
H_F = availability_F*exp(-age_steps*0.01/tau_F)
score_i = q_i*H_i
alpha_i = score_i/sum(score)
```

`Vy_true` is absent from every online formula. It is used only to calculate
offline validation metrics and coverage. No future window or filtering is
used.

## Evidence recovery and replay integrity

The A3 MAT contains the complete saved `SimulationOutput` in addition to its
simplified D/K evidence. Existing F-track, old LifeSig, health, and weight logs
were recovered read-only from that same authorized run.

- old frozen LifeSig formula versus saved output: maximum absolute difference
  `1.1102230246251565e-16 m/s`;
- new `sum(alpha)` maximum absolute error: `2.220446049250313e-16`;
- therefore F and old-LifeSig signals are not reconstructed from truth or from
  a new runtime.

## A3 low-yaw performance

The evaluation window is the A4 offline physical label
`|CarSim AVz|<0.01 rad/s`, longest interval `4.70--22.00 s`, `1731` samples.
CarSim AVz labels the offline window only; online `G_K` uses `AVz_IMU`.

| Estimator | RMSE [m/s] | MAE [m/s] | MaxAbs [m/s] | Bias [m/s] |
|---|---:|---:|---:|---:|
| D-EKF | 0.00447073 | 0.00426439 | 0.01135534 | -0.00414120 |
| K-KF | 1.08949148 | 0.99985803 | 1.74866874 | -0.99985803 |
| frozen LifeSig before A7 | 0.17063446 | 0.15759709 | 0.27090747 | -0.15759709 |
| modified LifeSig | 0.12261568 | 0.11358918 | 0.26480610 | -0.11358918 |

Relative to frozen LifeSig, the modified replay reduces:

- RMSE by `28.1413%`;
- MAE by `27.9243%`;
- MaxAbs by `2.2522%`;
- absolute bias by `27.9243%`.

This is a genuine improvement over the old LifeSig replay in the specified
low-yaw interval. D-EKF remains far more accurate, so no best-estimator or
performance-superiority claim is made for modified LifeSig.

## Weight behavior before and after

| Weight in physical low-yaw window | Before min/max/mean | After min/max/mean |
|---|---|---|
| `alpha_D` | 0.844034 / 0.847636 / 0.846015 | 0.844034 / 0.959876 / 0.883412 |
| `alpha_K` | 0.146686 / 0.147312 / 0.147030 | 0.034259 / 0.147297 / 0.109349 |
| `alpha_F` | 0.005052 / 0.009281 / 0.006955 | 0.005095 / 0.009281 / 0.007239 |

The K modifier only removes K score. Normalization reallocates most of that
score to D and a small amount to F. `alpha_K` never increases; its largest
sample-level reduction is `0.11303427373389342`.

## Health coverage

Within the physical low-yaw interval:

- `G_K<1` coverage: `88.677%` (`1535/1731`);
- upper-quartile K-error coverage: `95.843%`;
- `G_K` mean: `0.718894`;
- `G_K` minimum: `0.205366`.

These coverage figures use truth only to assess an already-frozen causal
formula. They do not tune the threshold or health mapping.

## Normal-condition disturbance

The same offline integration was applied to FWCAL C01R1/C02/C03/C04/C05.
For all five maneuvers:

```text
G_K changed samples       = 0
alpha_K max absolute change = 0
LifeSig output disturbance  = 0
```

This is zero observed perturbation on the available normal calibration set,
not a universal false-trigger guarantee.

## Curves and machine-readable evidence

- full 2201-sample replay:
  `results/vy_lifesig_v2_8a8_k_gate_replay_timeseries.csv`;
- `G_K` and weight before/after curves:
  `results/vy_lifesig_v2_8a8_health_and_weights.svg`;
- D/K/old-LifeSig/new-LifeSig/Vy-true curves:
  `results/vy_lifesig_v2_8a8_vy_replay.svg`;
- compact metric table:
  `results/vy_lifesig_v2_8a8_k_gate_offline_replay_summary.csv`.

## Acceptance boundary

```text
LOW_YAW_LIFESIG_RELIABILITY_IMPROVED = YES
NORMAL_FWCAL_DISTURBANCE             = ZERO_OBSERVED
D_EKF_REMAINS_BEST_IN_A3_LOW_YAW     = YES
THRESHOLDS_REOPTIMIZED                = NO
FORMAL_MODEL_MODIFIED                 = NO
SIMULINK_OR_CARSIM_RUN                = NO
READY_FOR_MINIMAL_IMPLEMENTATION      = YES_WITH_BOUNDED_CLAIMS
```

If a future implementation is authorized, it must preserve the A7 formula and
thresholds exactly and must be verified by unit regression before any runtime.
