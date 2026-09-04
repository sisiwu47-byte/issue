# V2.8-A7 K Physical Health Gate Continuous Formulation

## Result

`K_CONTINUOUS_PHYSICAL_HEALTH_FORMULATION_SUPPORTED_OFFLINE`

The A6 binary low-yaw/concurrent-disagreement condition admits a minimal,
causal, continuous extension without adding a fitted parameter. Across the
five frozen FWCAL calibration maneuvers it produces zero observed disturbance.
In the dedicated A3 physical-low-yaw interval it attenuates K on 88.677% of
samples and covers 95.843% of the upper-quartile K-error region.

This is an offline formulation and behavior audit, not a LifeSig
implementation or runtime validation. No MATLAB, Simulink, or CarSim process
was started. No model, estimator, LifeSig, fusion, Q/R, `q`, or `tau_F` file
was modified.

## Frozen inputs and thresholds

```text
r_online = AVz_IMU
d_DK     = abs(Vy_K - Vy_D)

r_K0 = 0.01 rad/s
d_K0 = 0.3467656927489074 m/s
```

Both thresholds are inherited unchanged from A6. `r_K0` is the
literature-derived structural candidate already audited in this project;
`d_K0` is the conservative maximum of the five maneuver-specific Q99
disagreement levels. Neither threshold is selected from `Vy_true`, estimator
RMSE, or fused performance.

## Continuous causal formulation

Define low-yaw severity:

```text
L_r = max(0, 1 - abs(r_online)/r_K0)
```

Define disagreement-exceedance severity:

```text
L_d = 0                         if d_DK <= d_K0
L_d = 1 - d_K0/d_DK            if d_DK > d_K0
```

Then:

```text
G_K       = 1 - L_r*L_d
H_K_new   = H_K_old*G_K
```

Properties:

- `L_r`, `L_d`, and `G_K` are causal and use the current sample only;
- `0 <= G_K <= 1` for finite inputs;
- `G_K=1` whenever yaw is outside the A6 low-yaw region or disagreement does
  not exceed the A6 boundary;
- attenuation occurs only when the two A6 conditions coexist;
- the mapping is continuous at both thresholds and introduces no new scale,
  window, future sample, hysteresis, smoothing, or fitted exponent;
- `Vy_true` is not an input. It is used only for offline coverage reporting.

Nonfinite-input handling remains an implementation-contract item. This stage
does not silently convert nonfinite evidence into either high or low health.

## Current versus proposed K health

Current V2.7 K health is availability-only:

```text
H_K_old = availability_K
```

In A3, `availability_K=1` throughout, so current `H_K_old` cannot represent the
observed structural K degradation. The proposed form retains that existing
availability prerequisite and adds only the A6-supported physical modifier:

```text
H_K_new = availability_K*G_K
```

It does not change the LifeSig normalization, D/F health, static priors,
fallback, or reset structure.

## Normal-maneuver disturbance

The five original FWCAL records used by A6 were replayed sample-by-sample.

| Maneuver | Samples | `G_K<1` count | disturbed fraction | `alpha_K` change |
|---|---:|---:|---:|---:|
| FWCAL_C01R1 | 1601 | 0 | 0% | exactly 0 |
| FWCAL_C02 | 1601 | 0 | 0% | exactly 0 |
| FWCAL_C03 | 1601 | 0 | 0% | exactly 0 |
| FWCAL_C04 | 1601 | 0 | 0% | exactly 0 |
| FWCAL_C05 | 1601 | 0 | 0% | exactly 0 |

Thus the new formulation has zero observed normal-condition perturbation in
the available five-maneuver evidence. This is an observed-data statement, not
a universal false-trigger guarantee.

## A3 physical-low-yaw behavior

The physical label remains the A4 CarSim-AVz offline interval `4.70--22.00 s`
(`1731` samples). Online `AVz_IMU` is used by the proposed gate; the physical
CarSim signal is not an online input.

| Quantity | `H_K_old` | `H_K_new` / `G_K` |
|---|---:|---:|
| any-attenuation low-yaw coverage | 0% | 88.677% (`1535/1731`) |
| upper-quartile K-error coverage | 0% | 95.843% |
| mean health in physical window | 1 | 0.718894 |
| median health | 1 | 0.735183 |
| minimum health | 1 | 0.205366 |
| fraction `G_K<0.90` | 0% | 75.968% |
| fraction `G_K<0.75` | 0% | 52.802% |
| fraction `G_K<0.50` | 0% | 16.811% |

`upper-quartile K-error coverage` uses offline truth only to audit whether the
causal signal reaches the already-observed degradation region. It did not tune
the formula or either threshold.

## Implied alpha_K change

For descriptive replay only, the frozen V2.7 priors and F age health were kept
unchanged. Only `H_K_old` was replaced by `H_K_new` before the existing score
normalization.

| A3 physical-low-yaw quantity | old `alpha_K` | new `alpha_K` |
|---|---:|---:|
| minimum | 0.146686 | 0.034259 |
| maximum | 0.147312 | 0.147297 |
| mean | 0.147030 | 0.109349 |

Across all A3 samples, `alpha_K_new-alpha_K_old` ranges from
`-0.11303427373389342` to `0`. The new weight never increases K. In the five
normal calibration maneuvers, the alpha change is exactly zero.

No fused RMSE is calculated or optimized in this stage.

## Stability and implementation decision

The continuous mapping is stable in the bounded sense supported here:

- it uses the A6 threshold pair without introducing an additional calibrated
  scale;
- it is continuous and bounded;
- the five normal maneuvers are undisturbed;
- the A3 physical degradation interval and high-K-error region receive broad
  attenuation.

The underlying `AVz_IMU` evidence remains noisy and the memoryless health can
vary sample-to-sample. The user explicitly prohibited a window or future
information, so this stage makes no persistence or chatter-rejection claim.
It also does not prove behavior under other speeds, roads, sensor faults, or
vehicle parameter mismatch.

Within those boundaries, minimal LifeSig integration is worth a later,
separately authorized implementation/regression stage. No complex model or
additional fitted threshold is justified.

```text
CONTINUOUS_FORM_STABLE_IN_AVAILABLE_DATA = YES
NORMAL_FWCAL_PERTURBATION                = ZERO_OBSERVED
LOW_YAW_DEGRADATION_COVERAGE             = 0.8867706528018486
UPPER_QUARTILE_K_ERROR_COVERAGE          = 0.9584295612009238
WORTH_ENTERING_LIFESIG_IMPLEMENTATION    = YES_WITH_BOUNDED_CLAIMS
IMPLEMENTED                              = NO
```

## Evidence lineage

- A6 formulation/status and CSV;
- A4 physical-low-yaw labeling evidence;
- A5 D-specific reliability audit;
- original frozen FWCAL C01R1/C02/C03/C04/C05 MAT files;
- A3 22-s long-low-yaw runtime MAT;
- V2.7 frozen static priors and F age-health formulation.

Machine-readable summary:
`results/vy_lifesig_v2_8a7_k_continuous_health_formulation_audit.csv`.
