# V2.5-H Offline Constrained-QP Weight Solve & Identifiability

## Stage conclusion

**V2.5-H OFFLINE CONSTRAINED-QP WEIGHT SOLVE & IDENTIFIABILITY PASSED**

The fixed-weight candidate was solved offline using only the five rows in the immutable calibration manifest. No Simulink, CarSim, runtime, holdout, or model modification was performed.

## Data gate

- manifest: `results/vy_fixed_fusion_v2_5g2_calibration_acquisition_manifest.csv`
- manifest SHA-256: `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`
- exact rows and order: `FWCAL_C01R1`, `FWCAL_C02`, `FWCAL_C03`, `FWCAL_C04`, `FWCAL_C05`
- M: `5`; all rows `CALIBRATION_ONLY / ELIGIBLE`
- every registered MAT exists and matches manifest SHA-256 and size
- all five datasets have finite `Vy_D`, `Vy_K`, `Vy_F`, `Vy_true`, common 1601-point grid, and recorded truth/evaluation PASS metadata
- no excluded data loaded; original C01 and old C02 pre-sim failure MAT are excluded

## Full five-maneuver QP

The objective was exactly maneuver-equal:

`J(alpha) = (1/M) sum_j (1/N_j) ||[Vy_D Vy_K Vy_F] alpha - Vy_true||^2`

with `alpha >= 0` and `sum(alpha)=1`, without regularization or a positive floor.

- solver: `quadprog`
- algorithm: `interior-point-convex`
- exit flag: `1` (`optimal`)
- iterations: `8`
- alpha_D: `0.9004680917645591`
- alpha_K: `0.09953190823500144`
- alpha_F: `4.39495370645866e-13` (numerical zero)
- sum(alpha): `1`
- objective: `0.006783869483537023`
- equality residual: `0`
- minimum alpha: `4.39495370645866e-13`
- free-variable stationarity residual: `3.67761376907038e-16`
- active lower-bound multiplier: `0.0222` (positive)
- complementarity residual: `9.7677e-15`
- KKT/feasibility: PASS

The QP matrices `H`, `f`, `Aeq`, `beq`, `lb` are saved in the result MAT; `H` is symmetrized and PSD within numerical tolerance.

## Reduced identifiability

Using `alpha_F = 1-alpha_D-alpha_K`, the reduced contrasts were formed with the same maneuver-equal normalization.

- contrast matrix dimensions: `8005 x 2` (five maneuvers, each 1601 samples)
- numerical rank: `2`
- rank tolerance: `4.443667656062189e-13`
- singular values: `0.4363020785664398`, `0.03410103415861833`
- sigma_min: `0.03410103415861833`
- sigma_max: `0.4363020785664398`
- `cond(X)`: `12.79439434408395`
- reduced Hessian condition number: `130.3505558104789`
- conditioning assessment: acceptable; no severe collinearity or flat direction observed

## LOO whole-maneuver sensitivity

Each leave-one-maneuver-out solve used the identical objective and simplex constraints.

| left out | alpha_D | alpha_K | alpha_F | max component shift |
|---|---:|---:|---:|---:|
| C01R1 | 0.8484846899 | 0.1515153101 | 4.66e-14 | 0.05198340184 |
| C02 | 0.8551443877 | 0.1448556123 | 6.18e-14 | 0.04532370404 |
| C03 | 0.8933596645 | 0.1066403355 | 2.62e-13 | 0.00710842730 |
| C04 | 0.9427868054 | 0.0572131946 | 1.57e-11 | 0.04231871362 |
| C05 | 0.9428831478 | 0.0571168522 | 1.11e-11 | 0.04241505608 |

Maximum LOO component shift is `0.05198340184377356`; LOO sensitivity gate PASS. No maneuver was removed or reweighted.

## Whole-maneuver bootstrap

Bootstrap used 1000 deterministic whole-maneuver resamples with replacement (`rng` seed `20260829`); samples were never treated as IID.

- mean alpha: approximately `[0.8883, 0.1117, 0]`
- median alpha: approximately `[0.9005, 0.0995, 0]`
- standard deviation: `[0.07698575579, 0.07698575579, 1.5835121e-11]`
- 2.5%–97.5% intervals:
  - alpha_D: `[0.6812, 1.0000]`
  - alpha_K: `[0, 0.3188]`
  - alpha_F: `[0, 0]` (numerical boundary)
- zero-weight frequencies: D `0`, K `0.025`, F `1.0`
- boundary-hit frequency: `1.0`

The bootstrap is discrete because only five maneuvers are available; it is used for stability evidence only and does not replace the full-5 QP candidate. Bootstrap stability gate PASS under the predeclared sensitivity criterion.

## Per-maneuver diagnostics

Full-candidate diagnostics are saved in `results/vy_fixed_fusion_v2_5h_per_maneuver_metrics.csv`. They are descriptive only and were not used to alter alpha or exclude a maneuver.

| run | RMSE_D | RMSE_K | RMSE_F | RMSE_FW | MAE_FW | Bias_FW | MaxAbs_FW |
|---|---:|---:|---:|---:|---:|---:|---:|
| C01R1 | 0.0296596 | 0.2600521 | 0.7476780 | 0.0426947 | 0.0341506 | -0.0306431 | 0.0782194 |
| C02 | 0.0433136 | 0.2610778 | 0.7473681 | 0.0507544 | 0.0414963 | -0.0299146 | 0.0972338 |
| C03 | 0.0655539 | 0.1815004 | 0.7474231 | 0.0650717 | 0.0582300 | -0.0230316 | 0.1066900 |
| C04 | 0.1223121 | 0.1429846 | 0.7478206 | 0.1144727 | 0.1007075 | -0.0267163 | 0.2055731 |
| C05 | 0.1184998 | 0.1399596 | 0.7473412 | 0.1103728 | 0.1002975 | -0.0222572 | 0.1856652 |

## Outputs and freeze status

- result MAT: `results/vy_fixed_fusion_v2_5h_weight_selection.mat`
- QP solution CSV: `results/vy_fixed_fusion_v2_5h_qp_solution.csv`
- identifiability CSV: `results/vy_fixed_fusion_v2_5h_identifiability.csv`
- LOO CSV: `results/vy_fixed_fusion_v2_5h_loo_sensitivity.csv`
- bootstrap CSV: `results/vy_fixed_fusion_v2_5h_maneuver_bootstrap.csv`
- per-maneuver metrics CSV: `results/vy_fixed_fusion_v2_5h_per_maneuver_metrics.csv`
- simplex map: diagnostic-only; not used as the formal solver
- classification: `IDENTIFIABLE_AND_STABLE`
- weight freeze eligibility: `ELIGIBLE`
- alpha status: `SELECTED_FIXED_WEIGHT_CANDIDATE` (not yet frozen)

THE FIXED-WEIGHT CANDIDATE WAS SELECTED USING ONLY THE FIVE PRE-REGISTERED CALIBRATION MANEUVERS.

THE OBJECTIVE USED EQUAL MANEUVER WEIGHTING.

NO HOLDOUT DATA WERE RUN, READ, OR USED.

NO REGULARIZATION OR POSITIVE WEIGHT FLOOR WAS INTRODUCED.

NO MODEL OR FUSION IMPLEMENTATION WAS MODIFIED.

NO SIMULATION OR CARSIM RUN WAS PERFORMED IN V2.5-H.

READY FOR V2.5-H1 FIXED-WEIGHT CANDIDATE ACCEPTANCE & FREEZE
