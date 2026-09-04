# V2.8-A5 D-EKF Reliability Limitation Audit

## Result

`D_SPECIFIC_HIGH_LATERAL_EXCITATION_DEGRADATION_SUPPORTED`

The five existing non-holdout calibration maneuvers contain an interpretable
D-track limitation: at the same nominal 20 m/s speed class, increasing the
steering/lateral-excitation level materially increases D lateral-velocity error.
This is evidence of a high-lateral-excitation/model-mismatch sensitivity, not a
new online fault detector and not proof of one uniquely identified physical
parameter error.

No MATLAB, Simulink, or CarSim process was started. No model, LifeSig, `q`,
`tau`, estimator, or fusion parameter was modified or fitted.

## Data and causal boundary

Only the five frozen calibration artifacts listed in
`results/vy_fixed_fusion_v2_5g2_calibration_acquisition_manifest.csv` were used:
`FWCAL_C01R1`, `C02`, `C03`, `C04`, and `C05`. All have 1601 aligned 100-Hz
samples over 0--16 s. The analyzed physical/logged variables are `Ay_IMU`,
`AVz_IMU`, actual front steering command, the shared actual Vx signal, and
`abs(Vy_K-Vy_D)`. `Vy_true` is used only to form offline D/K errors and is not
proposed as an online signal.

## Maneuver-level result

| Run | Steering | D RMSE (m/s) | D MAE (m/s) | D MaxAbs (m/s) | K RMSE (m/s) | mean abs(Ay) (m/s^2) | mean abs(yaw) (rad/s) |
|---|---|---:|---:|---:|---:|---:|---:|
| C01R1 | 0.020 rad / 0.30 Hz | 0.02966 | 0.02714 | 0.04931 | 0.26005 | 1.5329 | 0.07924 |
| C02 | 0.020 rad / 0.50 Hz | 0.04331 | 0.03885 | 0.07174 | 0.26108 | 1.4484 | 0.07787 |
| C03 | 0.030 rad / 0.40 Hz | 0.06555 | 0.06110 | 0.09524 | 0.18150 | 2.2365 | 0.11806 |
| C04 | 0.040 rad / 0.30 Hz | 0.12231 | 0.10791 | 0.21117 | 0.14298 | 3.0223 | 0.15641 |
| C05 | 0.040 rad / 0.40 Hz | 0.11850 | 0.10869 | 0.18814 | 0.13996 | 2.9530 | 0.15664 |

D remains the most accurate individual track in every maneuver, but its margin
over K narrows sharply in C04/C05. The high-excitation D RMSE is approximately
four times C01R1 and about three times C02. Across the five maneuver summaries,
D MSE has Pearson association `0.967` with mean `abs(Ay)`, `0.966` with mean
`abs(yaw)`, and `0.967` with mean `abs(steer)`; these five-point results are
descriptive and partly encode maneuver identity.

## Within-maneuver relationship audit

The limitation is not a stable instantaneous one-variable gate:

- `abs(Ay)` versus D squared error changes from strongly negative in C01R1/C02
  (`-0.657`, `-0.852`) to positive in C04/C05 (`0.642`, `0.417`).
- `abs(yaw)` shows the same sign change (`-0.634`, `-0.790` versus `0.586`,
  `0.337`).
- steering, Vx, and D/K disagreement also lack a stable within-maneuver mapping.
- The pooled correlations (`abs(Ay)=0.573`, `abs(yaw)=0.532`,
  `abs(steer)=0.362`) therefore primarily support a **regime-level** high
  lateral-excitation limitation, not a sample-level threshold.

The descriptive upper-decile D-error samples reinforce this boundary. In C04
and C05 they occur at mean `abs(Ay)=4.473/4.238 m/s^2`, mean
`abs(yaw)=0.2328/0.2249 rad/s`, and mean steering `0.03361/0.02962 rad`.
Conversely, the upper-decile samples in C01R1/C02 occur at low instantaneous
excitation, showing phase/history and deterministic model mismatch are also
present. No new threshold is inferred from these quantiles.

## Vehicle speed and disagreement

The actual Vx means span only `19.9697--19.9794 m/s`; Vx was not independently
varied. Its pooled negative correlation with D error reflects the small speed
sag that accompanies stronger lateral excitation and is not evidence of a
separate speed-driven degradation mechanism.

`abs(Vy_K-Vy_D)` is not a D-specific indicator in this set. Its pooled Pearson
correlation with D squared error is `-0.345`, and its within-maneuver
correlations are weak or negative (`-0.251` to `0.066`). Disagreement still
means the tracks differ, but it cannot attribute that difference to D.

## D uncertainty limitation

`P_D11` increases somewhat with excitation, but its magnitude does not keep up
with the actual D error:

| Run | mean P_D11 ((m/s)^2) | D RMSE (m/s) | mean e_D^2/P_D11 | median e_D^2/P_D11 | fraction e_D^2/P_D11 > 1 |
|---|---:|---:|---:|---:|---:|
| C01R1 | 0.0003087 | 0.02966 | 3.519 | 2.774 | 77.33% |
| C02 | 0.0003042 | 0.04331 | 7.734 | 5.549 | 82.20% |
| C03 | 0.0003548 | 0.06555 | 14.273 | 13.127 | 90.32% |
| C04 | 0.0004478 | 0.12231 | 31.210 | 27.710 | 93.82% |
| C05 | 0.0004328 | 0.11850 | 33.779 | 33.191 | 94.38% |

These are offline covariance-consistency diagnostics, not NIS. They show a
clear unrepresented deterministic/model-mismatch component: covariance gives
some ordering information at high excitation (`P_D11` versus squared error is
positive within C04/C05), but its confidence scale substantially understates
the observed error and becomes increasingly inconsistent across maneuvers.
This is consistent with the previously rejected raw cross-track covariance
weighting route and does not authorize covariance retuning here.

## Frozen conclusion and future validation target

- A D-specific degradation **regime** exists: stronger steering/lateral/yaw
  excitation at the same nominal speed class reduces D accuracy and exposes
  covariance-scale/model-mismatch limitations.
- No single audited online variable provides a stable causal sample-level D
  reliability gate across all five maneuvers.
- D dominance remains factual for the present calibration suite: D is still the
  lowest-RMSE individual track in all five cases.
- If D reliability research continues, the next meaningful validation target
  should independently vary high lateral excitation and model mismatch (for
  example vehicle/tire/load sensitivity) while preserving an untouched
  evaluation set. It should not be another nominal D-versus-K ranking run.
- This stage does not modify LifeSig, does not add a D gate, and does not use
  `Vy_true` online.

## Evidence lineage

- Calibration manifest SHA-256:
  `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`.
- Source MAT hashes remain those frozen in the manifest:
  C01R1 `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`,
  C02 `46972ED1AF86820551AA8C9AED2F2F8E4BC78F9551115F0A30715C62912BC4B3`,
  C03 `70DEFDE01347BCA69FE523204759367B30A8489CF10400FA755352E8062928C6`,
  C04 `E59749EF6D2B7B69D9844FC00CCC095B2E93E9778ECF332D01F0FF3E0F2874B4`,
  C05 `9DF5AC29F4588A91DBFC20FCCA55E124AF86DEB0CFA027B95099B08D50DB1B14`.
- Machine-readable summary:
  `results/vy_lifesig_v2_8a5_dekf_reliability_limitation_audit.csv`.

