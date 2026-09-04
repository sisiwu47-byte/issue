# V2.8-A6 K Physical-Degradation Health Indicator Offline Formulation

## Result

`MINIMAL_K_LOW_YAW_HEALTH_GATE_OFFLINE_FORMULATION_SUPPORTED`

A stable amplitude-threshold pair exists within the current five calibration
maneuvers plus the dedicated A3 long-low-yaw record. The supported result is an
offline formulation, not a LifeSig implementation or externally validated
fault detector. Raw gate output remains temporally fragmented by `AVz_IMU`
noise, so no persistence, hysteresis, or smoothing claim is made.

No MATLAB, Simulink, or CarSim process was started. No model, LifeSig, fusion,
`q`, `tau`, estimator, or parameter file was modified.

## Candidate inputs

Both inputs are causal and already online:

- `r_online = AVz_IMU`;
- `d_DK = abs(Vy_K - Vy_D)`.

`Vy_true`, future samples, maneuver identity, NIS, covariance, and RMSE do not
enter the candidate gate. `Vy_true` is used only to describe A3 detection
coverage after the gate has been fixed from physical/input-distribution
evidence.

The two inputs have complementary roles supported by A4/A5:

- low `abs(AVz_IMU)` identifies the structural condition in which K loses Vy
  observability, but does not measure accumulated K error severity;
- large D/K disagreement identifies growing track separation, but cannot alone
  identify which track is wrong;
- A5 places the evidenced D-specific limitation at **high** lateral/yaw
  excitation. Therefore the conjunction of near-zero yaw and large D/K
  disagreement is materially more K-specific than disagreement alone, while
  still retaining the attribution caveat outside the audited conditions.

## Minimal causal formulation

The proposed instantaneous diagnostic gate is

```text
r_low      = isfinite(r_online) && abs(r_online) < r_K0
dk_diverge = isfinite(Vy_D) && isfinite(Vy_K) && abs(Vy_K - Vy_D) > d_K0

G_K = 0, if r_low && dk_diverge
G_K = 1, otherwise
```

with the offline-supported candidate values

```text
r_K0 = 0.01 rad/s
d_K0 = 0.3467656927489074 m/s
```

If eventually integrated, the comparison object would be
`H_K_candidate = H_K_current * G_K`; this stage does not make that change.
Nonfinite-input/fallback behavior must be frozen separately before
implementation; it is not inferred here.

`r_K0` is the existing literature-derived structural candidate audited in A4,
not a value optimized from K error. `d_K0` is the conservative normal-data
envelope `max_j Q99(abs(Vy_K-Vy_D))` over the five equal-role calibration
maneuvers. It is derived only from the online disagreement distribution and a
false-trigger interpretation, not from `Vy_true`, RMSE, or fusion performance.

## Threshold stability

Per-maneuver disagreement 99th percentiles are:

| Run | Q99 `d_DK` (m/s) | maximum `d_DK` (m/s) |
|---|---:|---:|
| C01R1 | 0.319771 | 0.322346 |
| C02 | 0.346766 | 0.353099 |
| C03 | 0.256042 | 0.259674 |
| C04 | 0.305313 | 0.312817 |
| C05 | 0.289232 | 0.294258 |

The selected `d_K0` is driven by C02 but remains conservative rather than
outlier-max based. Leave-one-maneuver-out thresholds lie in
`0.319771--0.346766 m/s`. When C02 is omitted, applying the lower threshold to
C02 produces a `0.9994%` combined-gate trigger rate; all other omitted-case
tests are zero. Across that LOO range, A3 physical-low-yaw coverage changes only
from `88.68%` to `90.99%`. This supports a stable threshold **region** in the
available data.

Adjacent disagreement choices also give similar A3 coverage:

- pooled Q99 `0.334311 m/s`: `89.83%` coverage, pooled calibration false
  trigger `0.0500%` (C02 only);
- selected max-case Q99 `0.346766 m/s`: `88.68%` coverage, zero observed false
  triggers;
- pooled Q99.9 `0.350594 m/s`: `88.39%` coverage, zero false triggers;
- calibration maximum `0.353099 m/s`: `88.10%` coverage, zero false triggers.

No value was selected by error or fused-RMSE optimization.

## Per-maneuver normal impact

| Run | yaw-only `abs(r)<0.01` | disagreement-only `d_DK>d_K0` | combined gate active |
|---|---:|---:|---:|
| C01R1 | 4.872% | 0% | 0% |
| C02 | 5.871% | 0.999% | 0% |
| C03 | 3.498% | 0% | 0% |
| C04 | 2.623% | 0% | 0% |
| C05 | 2.623% | 0% | 0% |

Thus the yaw condition alone would suppress K during ordinary zero crossings,
and disagreement alone would affect C02. Their conjunction leaves current K
health unchanged in all five calibration records. This is the principal reason
to prefer the two-input minimum gate.

## A3 low-yaw degradation coverage

Physical low yaw remains labelled only by CarSim ideal AVz over `4.70--22.00 s`.
The proposed gate uses only `AVz_IMU` and D/K estimates.

| Quantity | Current `H_K=availability_K` | Proposed `G_K` conjunction |
|---|---:|---:|
| physical-low-yaw degradation coverage | 0% | 88.677% (1535/1731) |
| precision relative to physical-low-yaw interval | not applicable | 100% in A3 |
| first detection | none | 5.85 s |
| delay from physical-window start | not applicable | 1.15 s |
| upper-quartile physical-window K-error coverage | 0% | 95.843% |
| calibration false-trigger rate | 0% | 0% in every maneuver |

Current `H_K` remains one throughout A3 and therefore cannot represent the
structural observability failure. The candidate gate activates preferentially
after disagreement has grown: gated samples have mean absolute K error
`1.0501 m/s`, versus `0.6060 m/s` for ungated samples inside the physical
window. These error statistics validate the fixed candidate descriptively;
they were not used to choose either threshold.

## Important temporal limitation

Because raw `AVz_IMU` contains bias/noise, the A3 gate is split into 65 active
segments; the longest uninterrupted segment is only `1.09 s`. The sample-level
coverage is high, but persistent health-state behavior is not yet validated.
This audit intentionally does not add a past-time persistence counter,
hysteresis, smoothing, or a future window.

Accordingly:

- a stable memoryless threshold pair is supported offline;
- a formal LifeSig-ready temporal gate is **not** frozen;
- no more complex classifier or nonlinear attribution rule is justified;
- a later stage, if authorized, should freeze causal persistence and invalid
  semantics before any implementation, without retuning the two amplitudes by
  performance.

## Evidence lineage

- A4 status/evidence SHA-256:
  `9E083FBB45FADD0F92EDF7367788455B33906F70CA15D41C783714D47DD5E96F`,
  `417EC96A6DB2F50837D1CFE39337544DF70D1AABE881597EA4337BE62F27FE3D`.
- A5 status/evidence SHA-256:
  `31121DAD3C257573D2F6E9C751392CD356619F64C526CB733D0B41C87C1EF25D`,
  `FF1430D5B382E9A717FB36C5CED31A6478626950B5DC9772F1B6CB37981E3D6B`.
- Calibration manifest SHA-256:
  `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`.
- Machine-readable A6 audit:
  `results/vy_lifesig_v2_8a6_k_physical_health_indicator_audit.csv`.

