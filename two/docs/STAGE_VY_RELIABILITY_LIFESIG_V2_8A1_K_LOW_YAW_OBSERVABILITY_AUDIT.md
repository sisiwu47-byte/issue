# V2.8-A1 K Low-Yaw Observability Gate Adequacy Audit

## Verdict

`INSUFFICIENT_LOW_YAW_DATA`

The K-KF has a genuine structural observability loss at exactly zero yaw rate,
but the available non-holdout records contain only short zero-crossing segments,
not sustained low-yaw straight-running intervals. The existing data therefore
do not support freezing `0.01 rad/s`, or any nearby value, as a formal K-track
availability boundary.

No model, estimator, Q/R, prior, `tau_F`, fusion logic, or source file was
modified. No MATLAB, Simulink, or CarSim process was started. This is an offline
read-only audit of existing evidence.

## 1. Structural observability

The frozen K-KF uses

```text
x_K = [Vx; Vy]
F_K = [1, r*Ts; -r*Ts, 1]
C_K = [1, 0]
Ts  = 0.01 s
```

The two-step discrete observability matrix is

```text
O_K = [C_K; C_K*F_K]
    = [1, 0; 1, r*Ts]
det(O_K) = r*Ts
```

Thus `rank(O_K)=1` at `r=0`: `Vy` is not observable from the Vx measurement at
that instant. For nonzero `r`, the formal rank returns to two, while the
conditioning degrades continuously as `|r|` approaches zero. This matches the
PBH result in the reference paper, which states that lateral velocity is
unobservable at `r=0`.

The current source already computes `obs_metric=abs(r)` and a historical
`obs_flag = abs(r)>0.01`. That flag remains diagnostic only; it has never been
accepted as a formal availability gate.

## 2. Literature boundary audit

The reference paper `references/精度1applsci-15-01365-v2.pdf` provides two
distinct facts:

- page 6: the kinematic model loses lateral-velocity observability at `r=0`;
- page 10: its independent K-KF sets estimated lateral velocity to zero when
  `|r|<0.01 rad/s` to reduce drift on straights.

The second item is a literature-specific output clamp. It is not automatically
equivalent to declaring this project's K track unavailable, and the numerical
boundary cannot be transferred without project-data adequacy.

## 3. Data and method

The audit used only the five `NON_HOLDOUT_RELIABILITY_CALIBRATION` records and
the existing A3R10 nominal record. Every record contains 1601 aligned 100-Hz
samples over 0--16 s. `Vy_true` was used offline only.

For each candidate threshold, samples were partitioned by strict
`abs(r)<threshold`. Contiguous windows were identified without filtering or
time padding. Window span is `(last sample time - first sample time)`. K and D
errors are raw `Vy_est-Vy_true`; no de-meaning or bias correction was applied.

## 4. Project behavior at the literature candidate

| Dataset | low-yaw samples / fraction | windows | longest span | K RMSE low / other (m/s) | D RMSE low (m/s) | mean / max K within-window max-error rise (m/s) |
|---|---:|---:|---:|---:|---:|---:|
| FWCAL_C01R1 | 78 / 4.872% | 18 | 0.09 s | 0.25544 / 0.26029 | 0.03644 | 0.00299 / 0.00837 |
| FWCAL_C02 | 94 / 5.871% | 19 | 0.07 s | 0.25418 / 0.26150 | 0.06202 | 0.00298 / 0.00673 |
| FWCAL_C03 | 56 / 3.498% | 14 | 0.05 s | 0.17151 / 0.18185 | 0.07691 | 0.00259 / 0.00500 |
| FWCAL_C04 | 42 / 2.623% | 11 | 0.05 s | 0.14010 / 0.14306 | 0.09325 | 0.00291 / 0.00521 |
| FWCAL_C05 | 42 / 2.623% | 13 | 0.05 s | 0.13226 / 0.14016 | 0.11860 | 0.00205 / 0.00499 |
| A3R10 nominal | 80 / 4.997% | 15 | 0.06 s | 0.25028 / 0.26011 | 0.04776 | 0.00363 / 0.00915 |

At `0.01 rad/s`, the five calibration records provide only 312 low-yaw samples
out of 8005 (equal-maneuver coverage 3.898%). Their 75 windows are short: the
maximum span is 0.09 s. K error can increase slightly while crossing zero yaw,
but the available interval is too brief to establish sustained drift.

K low-yaw RMSE is not higher than its complementary-region RMSE in any of the
five calibration maneuvers or A3R10. D is generally much more accurate in the
same low-yaw samples, but that descriptive contrast reflects overall track
quality and does not by itself validate a low-yaw switching boundary.

## 5. Nearby-boundary sensitivity

| Candidate `|r|` boundary | Equal-maneuver coverage | longest span | K RMSE low / other (m/s) | D RMSE low (m/s) |
|---:|---:|---:|---:|---:|
| 0.005 rad/s | 1.861% | 0.04 s | 0.20392 / 0.20436 | 0.08914 |
| 0.010 rad/s | 3.898% | 0.09 s | 0.19819 / 0.20460 | 0.08228 |
| 0.020 rad/s | 7.970% | 0.18 s | 0.20075 / 0.20469 | 0.07769 |

Changing the boundary changes coverage as expected, but none of these three
candidates isolates a region with larger K RMSE. No threshold was optimized
against fusion RMSE or estimation performance.

## 6. Interpretation boundary

- `CONTINUOUS_RELIABILITY_PREDICTOR`: still not supported. A2R9 already showed
  that `abs(r)` does not continuously predict K error.
- `STRUCTURAL_NEAR_UNOBSERVABLE_GATE`: mathematically motivated, but not yet
  empirically adequate for a frozen project boundary.
- `0.01 rad/s`: retained only as a literature-derived candidate and historical
  diagnostic partition.
- `FORMAL K AVAILABILITY GATE`: not implemented and not authorized by this
  audit.

A future adequacy test would require a non-holdout engineering diagnostic with
intentional sustained straight/near-zero-yaw intervals of materially longer
duration, while preserving raw K/D/truth signals. This audit does not authorize
that runtime or any gate implementation.

## 7. Evidence integrity

| Artifact | SHA-256 |
|---|---|
| `model/vy_kinematic_kf_step.m` | `383A5A63AC11C3F43BAE1CA7B6993A1C181363F970CD1BA347D4FF8521727740` |
| `model/vy_kinematic_kf.m` | `73A06F593E0D52B3A168445060F6CA68B35D2F710A913DD16213CDC71FF92298` |
| FWCAL_C01R1 | `BA2546C4FB18810197B0ED721B9D83E1C14CB1354B75B64FF6E960A226B70864` |
| FWCAL_C02 | `7942F1612A055B906DD9012E3D5A2F53314FB5E2560370CCD0BF901243AD589B` |
| FWCAL_C03 | `30C12ED01DC1C1E044D4154E7476794306F3231DE414F7E4CFBA3E88D450400A` |
| FWCAL_C04 | `2E003C60081F959FFD36B317A94D1AD9CE9DF8FECE9CB63794B298A37B4F01A5` |
| FWCAL_C05 | `2BA043D6536816A5DCE77831D3A34D0CF952FCD145377512CADAB584047F5C6F` |
| A3R10 nominal MAT | `E02DA4498441249C6AD7108FAD529C9724053B3B7FE469FFC0DF629208FCBBF3` |
| reference PDF | `F881062A7453365E7805CF2CD2473629778BD10929B72E686534A31C783E5849` |

Machine-readable audit table:
`results/vy_reliability_lifesig_v2_8a1_k_low_yaw_observability_audit.csv`.

## Final decision

`INSUFFICIENT_LOW_YAW_DATA`

No near-zero yaw boundary is frozen.
