# V2.5-G1D FWCAL_C01R1 Replacement Calibration Acquisition Status

## Stage conclusion

**V2.5-G1D FWCAL_C01R1 REPLACEMENT CALIBRATION ACQUISITION PASSED**

`FWCAL_C01R1` completed its one authorized 16-s runtime. The acquired dataset passed all 57 preregistration, runtime-integrity, replay, truth-alignment, evaluation-window, immutability, and frozen-integrity gates and is eligible for future formal fixed-weight calibration. No weight was calculated or selected in this stage.

## 1. Replacement lineage

| Item | Value |
|---|---|
| Replacement run ID | `FWCAL_C01R1` |
| Role | `CALIBRATION_ONLY` |
| Replaces | `FWCAL_C01` |
| Replacement generation | `1` |
| Original C01 status | `FAILED_INFRASTRUCTURE` |
| Original C01 usable data | `NO` |
| Original C01 simulation authorization | `CONSUMED` |
| Replacement reason | Original C01 failed during infrastructure/CarSim initialization before producing usable estimator/truth performance data. |

The original `FWCAL_C01` record remains append-only and unchanged. The replacement used the exact original preregistered condition; no performance-based maneuver change or cherry-picking occurred.

## 2. Preregistered and actual condition

| Parameter | Preregistered | Actual | Gate |
|---|---:|---:|---|
| Front steering amplitude | `0.02 rad` | `0.02 rad` | PASS |
| Steering frequency | `0.30 Hz` | `0.30 Hz` | PASS |
| Duration / StopTime | `16 s` | `16 s` | PASS |
| Estimator rate | `100 Hz` | `100 Hz` | PASS |
| Waveform | sine | sine; pointwise command error within `1e-12` | PASS |
| Front policy | FL/FR same phase | FL/FR equal to converted command | PASS |
| Rear policy | RL/RR zero | RL maxAbs `0`, RR maxAbs `0` | PASS |
| Speed scope | verified approximately 20 m/s class | min `19.976323206850093`, mean `19.97917974999022`, max `20` m/s | PASS |

## 3. Pre-simulation environment gates

| Gate | Actual | Result |
|---|---|---|
| Result path absent before run | absent | PASS |
| Live MATLAB process count before launch | `0` | PASS |
| Persistent `MATLAB_PREFDIR` | Process/User/Machine all `UNSET` | PASS |
| Active preference directory | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` (R4 fresh default) | PASS |
| MATLAB version | `24.1.0.2537033 (R2024a)` | PASS |
| Working directory | `D:\UsersData\桌面\two\model` | PASS |
| Active simfile | `D:\UsersData\桌面\two\model\simfile.sim` | PASS |
| CarSim solver | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` | PASS |
| CarSim MEX | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64` | PASS |
| G request | `NO` | PASS |

No `MATLAB_PREFDIR` override was used, the old preference directory was not restored, and the R2 diagnostic preference directory was not used.

## 4. Runtime authorization and completion

| Evidence | Value |
|---|---|
| `sim()` called | `YES` |
| `sim()` call count | `1` |
| FWCAL_C01R1 authorization | `CONSUMED` |
| MATLAB exit status | `0` |
| Runtime status | `EXIT_0_RUNTIME_AND_POST_ANALYSIS_OK` |
| CarSim initialization | PASS |
| CarSim completion | PASS |
| Termination | normal at simulation time `16 s` |
| `0xC0000005` | not observed |

No second `FWCAL_C01R1` simulation was run.

## 5. Timing and scheduler integrity

| Track | Samples | Start | End | Timing result |
|---|---:|---:|---:|---|
| D-EKF | `1601` | `0 s` | `16 s` | PASS |
| K-KF | `1601` | `0 s` | `16 s` | PASS |
| F-track | `1601` | `0 s` | `16 s` | PASS |
| Fixed-weight fusion | `1601` | `0 s` | `16 s` | PASS |

- D/K timestamp maximum difference: `0`.
- D/F timestamp maximum difference: `0`.
- D/fusion timestamp maximum difference: `0`.
- Time step: min `0.0099999999999997868 s`, mean `0.01 s`, max `0.010000000000001563 s`.
- D-EKF Ay updates: `321/321`, consistent with the registered 20-Hz semantics.
- K-KF Ax/Ay/AVz hits: `1601/1601/1601`, consistent with the registered process-input semantics.
- F-track `feedbackApplied` count: `0`; the F-track remained standalone.

## 6. Numerical and replay integrity

| Check | Evidence | Result |
|---|---|---|
| D covariance | finite; max asymmetry `0`; minimum eigenvalue `9.9618893366379863e-05` | PASS |
| K covariance | finite; max asymmetry `0`; minimum eigenvalue `6.1803398889438533e-05` | PASS |
| F covariance | finite; minimum P `0.5` | PASS |
| D frozen replay | max differences state/P/diag = `[0 0 0]` | PASS |
| K frozen replay | max differences state/P/diag = `[0 0 0]` | PASS |
| F frozen replay | max differences Vy/P/diag = `[0 0 0]` | PASS |
| Fusion exact replay | max absolute difference `0` | PASS |

## 7. Truth alignment

The replacement inherited the original C01 truth-alignment policy from the frozen V2.5-F plan/registry and the G1C remediation registry. It was not redesigned after viewing estimator performance.

| Metadata | Value |
|---|---|
| Truth availability | `YES` |
| Truth finite | `YES` |
| Registered alignment rule | deterministic registered C01 rule |
| `TRUTH_ALIGNMENT_MODE` | `DIRECT_SAME_TIMESTAMP_ALIGNMENT` |
| Original truth sample count | `16001` |
| Aligned truth sample count | `1601` |
| Common estimator-grid sample count | `1601` |
| Truth/common-grid start | `0 s` |
| Truth/common-grid end | `16 s` |
| Maximum timestamp discrepancy on directly matched samples | `0` |
| Interpolation | none |
| Alignment success | PASS |

No cross-correlation lag search, manual offset, per-track alignment, per-window alignment, or RMSE-driven delay adjustment was performed.

## 8. Evaluation window

| Metadata | Value |
|---|---|
| Registered rule | `FULL REGISTERED RUN WINDOW` |
| Evaluation start | `0 s` |
| Evaluation end | `16 s` |
| Evaluation samples | `1601` |
| Initial/final transient removal | none |
| Window compliance | PASS |

Dataset eligibility was determined only from condition fidelity, runtime/timing integrity, signal completeness, truth availability/alignment, replay integrity, and frozen integrity. D/K/F/fusion performance ranking was not used for eligibility, maneuver selection, or tuning.

## 9. Runtime MAT immutability

| Item | Value |
|---|---|
| Path | `results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat` |
| SHA-256 | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` |
| Size | `4,319,877 bytes` |
| mtime | `2026-08-29T00:26:51.7763391+08:00` |
| Analyzer write-back | `NO` |
| Formal calibration eligibility | `ELIGIBLE_CALIBRATION_DATA` |

The runtime MAT was saved once, hashed immediately, and remained byte-identical through post-analysis and CSV/status generation.

## 10. Integrity gate result

- Integrity gate count: `57`.
- Gates passed: `57/57`.
- Gates failed: `0`.
- Machine-readable evidence: `results/vy_fixed_fusion_v2_5g1d_C01R1_integrity_gates.csv`.
- Acquisition record: `results/vy_fixed_fusion_v2_5g1d_C01R1_acquisition_record.csv`.

## 11. Dataset locks and alpha status

| Item | Status |
|---|---|
| `FWCAL_C01` | permanently `FAILED_INFRASTRUCTURE / NO_USABLE_DATA`; authorization consumed |
| `FWCAL_C01R1` | completed; `ELIGIBLE_CALIBRATION_DATA`; replaces C01 |
| `FWCAL_C02`–`FWCAL_C05` | `PLANNED_NOT_RUN`; runtime authorizations unconsumed |
| Holdout runtime count | `0` |
| Holdout result MAT count | `0` |
| Holdout performance viewed | `NO` |
| `alpha_D` | `UNSELECTED` |
| `alpha_K` | `UNSELECTED` |
| `alpha_F` | `UNSELECTED` |

No QP, optimization, grid search, candidate-alpha calculation, manual weighting, covariance weighting, or formal equal-weight confirmation was performed.

## 12. Frozen and historical integrity

All 19 frozen artifacts in the runner manifest matched their registered SHA-256 values before and after runtime; mismatch count was `0`. Key values are:

| Artifact | SHA-256 | Status |
|---|---|---|
| Fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | unchanged |
| Fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | unchanged |
| Fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | unchanged |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| Frozen D-EKF target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| Frozen K-KF target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| Frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| Frozen F-track target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | unchanged |
| Frozen F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| Active simfile | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | unchanged |

The V2.5-F plan, suite and original registry; G1C remediation registry and gates; R4 evidence; and G1B recovery diagnostic evidence also matched their historical hashes before and after the run. No `.slx`, simfile, CarSim dataset, estimator core/wrapper, or preregistration record was modified.

## 13. Final declarations

FWCAL_C01R1 COMPLETED ITS ONE AUTHORIZED 16-S RUNTIME.

THE REPLACEMENT CONDITION EXACTLY MATCHED THE ORIGINAL PRE-REGISTERED FWCAL_C01 CONDITION.

FWCAL_C01R1 PASSED ALL RUNTIME AND DATA-INTEGRITY GATES.

FWCAL_C01R1 IS ELIGIBLE FOR FORMAL FIXED-WEIGHT CALIBRATION.

FWCAL_C01 REMAINS PERMANENTLY RECORDED AS FAILED-INFRASTRUCTURE / NO-USABLE-DATA.

NO PERFORMANCE-BASED MANEUVER CHANGE OR CHERRY-PICKING OCCURRED.

F-TRACK REMAINED STANDALONE.

TRUE Vy WAS RECORDED FOR OFFLINE CALIBRATION ONLY.

NO FUSED COVARIANCE WAS GENERATED.

NO WEIGHTS WERE CALCULATED OR TUNED.

C02-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

READY FOR V2.5-G2 REMAINING PRE-REGISTERED CALIBRATION ACQUISITION RESUMPTION
