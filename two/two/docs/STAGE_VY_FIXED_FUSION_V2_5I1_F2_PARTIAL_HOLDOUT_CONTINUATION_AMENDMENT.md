# V2.5-I1-F2 Post-Failure Partial Holdout Continuation Amendment

## Stage conclusion

**V2.5-I1-F2 POST-FAILURE PARTIAL HOLDOUT CONTINUATION AMENDMENT PASSED**

H01 acquisition failure is permanent. `H01_runtime_status=CLOSED_FAILED_ACQUISITION`; rerun, replacement run, condition substitution, `H01R1`, calibration substitution, and nearby-condition substitution are all forbidden. The F1 classification remains `SIM_BOUNDARY_UNRESOLVED_NATIVE_TERMINATION`, `simCallCount=NOT_PERSISTED`, authorization `CONSUMED_BY_SAFETY_POLICY`, and formal data status `NO_USABLE_HOLDOUT_DATA`.

## Primary metric remains incomplete

The original frozen primary metric remains `EQUAL_MANEUVER_MSE`, with each track aggregate defined as one-third of H01, H02, and H03, followed by the frozen `rho_holdout` comparison. Since H01 has no immutable formal dataset, this lineage is permanently:

`PRIMARY_THREE_HOLDOUT_AGGREGATE_STATUS=INCOMPLETE_DUE_TO_MISSING_H01_FORMAL_DATA`

Even if H02 and H03 succeed, the original `J_H_D`, `J_H_K`, `J_H_F`, `J_H_FW`, `rho_holdout`, and original generalization classification must not be computed. A two-run average must not be presented as the original primary metric.

## Prospective H02/H03 role

H02 and H03 may continue only as `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`. They retain their untouched preregistered identities and conditions, are not calibration data, do not replace H01, and cannot be used for retuning.

- H02 (`FWHOLD_H02`, original row 8): 0.035 rad, 0.35 Hz, 16 s, 100 Hz, `SINE_FRONT_EQUAL_REAR_ZERO`, `FL_FR_SAME_PHASE`, `RL_RR_ZERO`, speed class `VERIFIED_APPROX_20_MPS_CLASS`, truth rule `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`, evaluation `[0_16]`, result `results/vy_fixed_fusion_v2_5i_fwhold_h02.mat`.
- H03 (`FWHOLD_H03`, original row 9): 0.030 rad, 0.45 Hz, 16 s, 100 Hz, with the same waveform/policies/speed/truth/evaluation rules, result `results/vy_fixed_fusion_v2_5i_fwhold_h03.mat`.

Both remain `PLANNED_NOT_RUN / UNRUN / UNVIEWED / UNCONSUMED`, with runtime count zero and no result MAT.

Per-run MSE/RMSE/MAE/Bias/MaxAbs, best-single MSE, ratio, gain versus D, and `FW_BETTER/FW_TIE/FW_WORSE` remain allowed only after performance-independent eligibility passes.

## Prospectively defined partial summary

Before either H02 or H03 is observed, F2 defines the equal two-run `J_PARTIAL23_D/K/F/FW`, `best_single_PARTIAL23`, and `rho_PARTIAL23`. This family is permanently marked `DESCRIPTIVE_PARTIAL_HOLDOUT_SUMMARY_ONLY`, `primary=FALSE`, and `generalization_classification_allowed=FALSE`. It becomes computable only if both H02 and H03 are eligible. If either acquisition fails, `PARTIAL23_SUMMARY_STATUS=INCOMPLETE`; the remaining run cannot be renormalized into a one-run summary.

## Immutable weights and execution evidence protocol

`V25_FIXED_WEIGHT_ALPHA_V1=[0.9004680917645591,0.09953190823544089,0]` remains immutable. No QP, renormalization, positive F floor, adaptive/covariance weighting, per-condition weight, model/estimator/Q/R/window/truth/condition change is allowed.

Future H02/H03 execution must use a pure-ASCII Windows bootstrap, then MATLAB-internal `cd` to the original model directory, then a run-specific runner. After all pre-sim gates pass and immediately before the unique `sim()`, the runner must atomically write, flush, and close an immutable `SIM_AUTHORIZATION_COMMITTED` record. Authorization becomes consumed when that durable record is successfully written, regardless of any subsequent crash. The required durable phase markers are frozen in `results/vy_fixed_fusion_v2_5i1_f2_future_holdout_execution_protocol.csv`. This amendment is prospective and does not alter H01 history.

## Lineage and F2 gates

F1 evidence hashes remain `9E6617A1EFDAE0BCE97E3F74DF2D8CA73642B062FD254FD155AAEF07C762DB10`, `6446F558A9AFBAEA42B089F66F74C7299D8D2392B2A3B84F84F39E9DF27422FC`, and `D904FBA433F3D89EA9F5BA21D9614B206AD801686ADD2D26A734B2668972A0D5`. Original metric freeze `0670A1AF0655ECBAA85850C5F5D1F47E4AE872A3F58D0AC89F7B6A1681A1EA05`, registry `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`, weights `E409692637168719AE3B0537D49F81DC2AFB50A67D111A7C40793A76B18700EC`, and target `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` are unchanged.

All 22 F2 gates pass: F1 unchanged; H01 closed/no rerun; H02/H03 untouched with no MAT/data viewed; weights/target/original metric/registry unchanged; original primary incomplete with no two-run substitution; per-run metrics frozen; PARTIAL23 prospectively defined, non-primary and non-classifying; no retuning; future authorization commit, durable phase markers and ASCII bootstrap frozen; no MATLAB/Simulink/CarSim; no model or registry modification.
