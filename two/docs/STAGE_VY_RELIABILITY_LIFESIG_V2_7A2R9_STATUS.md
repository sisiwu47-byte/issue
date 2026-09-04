# V2.7-A2R9 RELIABILITY ADEQUACY RE-AUDIT

## Scope

This is an offline audit of the five newly captured
`NON_HOLDOUT_RELIABILITY_CALIBRATION` MAT files. No model was loaded, no
`sim()`/CarSim runtime was run, no LifeSig parameter was fitted, and no
epsilon/r0/tau_F, Q/R, fusion, or holdout data was used.

The audit uses only valid samples:

- D: `update_valid_D && nis_valid_D`, finite `NIS_D` and positive measurement
  dimension/covariance;
- K: `update_valid_K && nis_valid_K`, finite NIS and `abs(r)`;
- F: `age_valid && reset_valid`, finite propagation age/covariance.

## Timing and causality

All five records have 1601 samples on the common 100-Hz grid from 0 to 16 s,
with aligned offline `Vy_true`. D/K diagnostics are formed on their estimator
hits; F age is emitted on the same propagation hit. `Vy_true` is used only for
this offline error reference and is not an online input.

## Signal/error statistics

Correlations below are Pearson / Spearman between each reliability signal and
the corresponding squared Vy error. Every maneuver had 1601 valid samples.

| Maneuver | D nu | K NIS | K abs(r) | F age |
|---|---:|---:|---:|---:|
| C01R1 | 0.2443 / 0.2048 | 0.2278 / 0.1385 | -0.0300 / -0.0375 | 0.9746 / 1.0000 |
| C02 | 0.2719 / 0.3387 | 0.2239 / 0.1111 | 0.0016 / -0.0078 | 0.9746 / 1.0000 |
| C03 | 0.0148 / 0.1691 | 0.2050 / 0.1091 | -0.0187 / 0.0071 | 0.9747 / 1.0000 |
| C04 | 0.0351 / 0.1797 | 0.1917 / 0.0847 | -0.1241 / -0.0837 | 0.9745 / 1.0000 |
| C05 | 0.1645 / 0.0984 | 0.1976 / 0.1082 | -0.0510 / 0.0029 | 0.9747 / 1.0000 |
| Pooled aggregate | 0.1070 / 0.3279 | 0.1203 / 0.0838 | -0.3707 / -0.3295 | 0.9746 / 1.0000 |

Equal-frequency bin diagnostics for every signal and maneuver are stored in
the audit MAT; the same CSV contains the per-maneuver summary rows. D's
`useAy`/measurement-dimension stratifications were also computed. They do not
remove the weak and variable D relationship.

### D adequacy

`nu_D` is causal and valid-masked, but its error-risk relationship is weak and
varies materially by maneuver (Pearson 0.015–0.272). It is not established as
a stable standalone LifeSig evidence signal.

### K adequacy and complementarity

K NIS has only weak positive per-maneuver association (Pearson 0.192–0.228;
pooled 0.120). `abs(r)` is effectively uncorrelated or negatively correlated
with squared error (pooled Pearson -0.371). Joint rank diagnostics remained
small (0.073, 0.090, 0.079, -0.005, 0.055), while partial correlations show
NIS retaining modest association and `abs(r)` no stable unique contribution.
Thus K NIS alone is not adequate, `abs(r)` alone is not adequate, and robust
complementarity is not established.

### F adequacy

Propagation age shows a highly stable monotonic error-risk relationship across
all maneuvers (Pearson 0.9745–0.9747; Spearman ≈0.999995), with age semantics
verified as reset age 0, first propagation age 1, then unit increments. F age
is therefore adequate as an offline-supported causal reliability signal.

## Verdicts

```text
D_SIGNAL_ADEQUACY        = WEAK_AND_CROSS_MANEUVER_VARIABLE
K_NIS_ADEQUACY            = INADEQUATE_STABLE_ERROR_RISK_EXPLANATION
K_OBSERVABILITY_ADEQUACY  = INADEQUATE_AS_STANDALONE_SIGNAL
K_COMPLEMENTARITY         = NOT_ESTABLISHED
F_AGE_ADEQUACY            = ADEQUATE_STABLE_MONOTONIC
```

Overall:

```text
RELIABILITY_FORMULATION_REQUIRES_REVISION
```

The blocker is signal adequacy, not missing data or runtime integrity. No
temporary threshold or parameter tuning was introduced. `Vy_true` remains
offline-only; no maneuver-specific switching, holdout logic, LifeSig
parameter fitting, or fusion performance tuning was performed.

Evidence:

- `results/vy_reliability_lifesig_v2_7a2r9_adequacy_audit.mat`
- `results/vy_reliability_lifesig_v2_7a2r9_adequacy_audit.csv`

No A3 LifeSig parameter-identification stage is authorized until the
reliability formulation is revised to address the weak D/K relationships.
