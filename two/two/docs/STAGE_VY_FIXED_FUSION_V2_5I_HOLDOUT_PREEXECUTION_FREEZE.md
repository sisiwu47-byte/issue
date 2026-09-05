# V2.5-I Holdout Validation Pre-Execution Freeze

## Stage conclusion

**V2.5-I HOLDOUT VALIDATION PRE-EXECUTION FREEZE PASSED**

The three original V2.5-F holdout maneuvers were frozen without reading or running holdout data. H2 implementation lineage is complete, including the explicit V2.5-H2-R1 reconstructed freeze manifest.

## Untouched holdouts and exact preregistration

| run_id | original row | status | authorization | order | steer amplitude (rad) | frequency (Hz) | duration (s) | rate (Hz) | result path |
|---|---:|---|---|---:|---:|---:|---:|---:|---|
| FWHOLD_H01 | 7 | PLANNED_NOT_RUN | UNCONSUMED | 1 | 0.025 | 0.35 | 16 | 100 | `results/vy_fixed_fusion_v2_5i_fwhold_h01.mat` |
| FWHOLD_H02 | 8 | PLANNED_NOT_RUN | UNCONSUMED | 2 | 0.035 | 0.35 | 16 | 100 | `results/vy_fixed_fusion_v2_5i_fwhold_h02.mat` |
| FWHOLD_H03 | 9 | PLANNED_NOT_RUN | UNCONSUMED | 3 | 0.030 | 0.45 | 16 | 100 | `results/vy_fixed_fusion_v2_5i_fwhold_h03.mat` |

All three retain the exact original `SINE_FRONT_EQUAL_REAR_ZERO` waveform, `FL_FR_SAME_PHASE` front policy, `RL_RR_ZERO` rear policy, `VERIFIED_APPROX_20_MPS_CLASS` speed scope, truth alignment `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`, and evaluation window `[0_16]`. Their result MATs are absent, `data_viewed=FALSE`, and runtime count is zero. The original V2.5-F suite plan and run registry were not modified.

Execution order is permanently H01 → H02 → H03. Each holdout has one and only one authorized runtime; once `sim()` is called, its authorization is consumed permanently, including after crash or integrity failure. Only H01 may be authorized next, after pre-sim checks and no other holdout access.

## Formal implementation hard lock

All holdouts must use `model/vx_vy_fixed_fusion_v2_5.slx`, SHA-256 `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`.

Weight set `V25_FIXED_WEIGHT_ALPHA_V1` is immutable:

- `alpha_D = 0.9004680917645591`
- `alpha_K = 0.09953190823544089`
- `alpha_F = 0`
- sum = `1`

The H2 runtime representation is a global constant fixed weight. The F-track remains present, executed, logged, standalone, and feedback-disabled; `alpha_F=0` does not remove it. No covariance/P-based weighting, NIS, LifeSig, observability weighting, speed/yaw scheduling, switching, adaptive alpha, or truth-dependent weighting is permitted.

The H2-R1 lineage identity is retained as `RECONSTRUCTED_FREEZE_LINEAGE_MANIFEST`; it was reconstructed from immutable evidence and is not claimed to have existed at original H2 completion.

## Truth, metrics, and eligibility

`Vy_true` is post-runtime offline validation only and cannot enter D/K/F/FW runtime calculation or online decisions. Each holdout uses its original truth-alignment and evaluation-window rules without cross-correlation, manual shifts, transient deletion, or result-dependent window changes.

The primary metric is equal-maneuver holdout MSE:

`J_H_FW=(1/3)*(MSE_FW_H01+MSE_FW_H02+MSE_FW_H03)`

and analogously for D, K, and F. `J_H_best_single=min(J_H_D,J_H_K,J_H_F)`, `rho_holdout=J_H_FW/J_H_best_single`. Classification is preregistered as aggregate gain for `rho<1`, tie within numerical tolerance for `rho=1`, and no aggregate gain for `rho>1`. `gain_vs_D=(J_H_D-J_H_FW)/J_H_D` is diagnostic only. Per-run RMSE, MAE, bias, max-absolute error, MSE, best-single MSE, and ratio are recorded with the same windows and alignment.

Holdout eligibility is independent of performance: condition fidelity, completion, timing, state/covariance integrity, exact replay, truth availability/alignment, and evaluation window determine validity. No holdout result may be used to retune, re-optimize, renormalize, change alpha, or alter conditions.

## Frozen lineage artifacts

The machine-readable snapshot is `results/vy_fixed_fusion_v2_5i_preexecution_freeze_manifest.csv` (12 records, SHA-256 `4B6216A38D4F40702AA32783894A6F4A47E9807A7ACBC4AAA0886A777E4A86F8`). It includes the formal target, frozen core/wrapper, H1/H2/H2-R1/calibration lineage, original F plan/registry, this holdout preregistry, and metric freeze without self-hashing.

Key lineage hashes:

- H2 runtime weight manifest: `E409692637168719AE3B0537D49F81DC2AFB50A67D111A7C40793A76B18700EC`
- H2 reconstructed freeze manifest: `6752F7D45BBEC4FC6A392E14FBDC7133B73C27CCF2DEFEE028B88FFF6D842A22`
- H2-R1 remediation evidence: `212D0A2843E013C028753CF3C0DA5FCE58192E2CD595C7F842227BEC0DE364FD`
- H1 freeze manifest: `D896BF5CE1191B09F544F1ECF68D6B6E54A0F521170BDD9A4CDDF49239DC254D`
- calibration manifest: `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`

No MATLAB, Simulink, CarSim, `sim()`, holdout read, holdout performance evaluation, model modification, alpha modification, QP, or retuning was performed in V2.5-I.

H01 / H02 / H03 REMAIN UNRUN AND UNVIEWED.

READY FOR V2.5-I1 H01 FIRST-AND-ONLY HOLDOUT RUNTIME
