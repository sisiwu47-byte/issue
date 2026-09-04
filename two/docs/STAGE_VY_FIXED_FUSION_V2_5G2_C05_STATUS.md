# V2.5-G2 FWCAL_C05 Status

## Stage conclusion

**V2.5-G2 FWCAL_C05 FORMAL CALIBRATION ACQUISITION PASSED**

FWCAL_C05 completed its first and only authorized formal runtime. Its runtime authorization is permanently `CONSUMED`.

## Original preregistration and run card

FWCAL_C05 was programmatically resolved as original V2.5-F registry row 5 (CSV data row 6):

- role/status: `CALIBRATION_ONLY / PLANNED_NOT_RUN`
- planned/commanded steering amplitude: `0.040 / 0.040 rad`
- planned/commanded steering frequency: `0.40 / 0.40 Hz`
- planned/actual duration: `16 / 16 s`
- planned/actual estimator rate: `100 / 100 Hz`
- waveform: `SINE_FRONT_EQUAL_REAR_ZERO`
- front/rear policy: FL/FR same phase; RL/RR zero
- speed scope: `CURRENT_CARSIM_20_MPS_CLASS_NOT_RUNNER_PARAMETERIZED`
- truth alignment: `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`
- evaluation window: `[0_16]`
- formal result path: `results/vy_fixed_fusion_v2_5g_fwcal_c05.mat`

No maneuver value or frozen implementation was changed.

## MATLAB, CarSim, and SET-2 lifecycle

- MATLAB startup marker reached
- MATLAB `24.1.0.2537033 (R2024a)`
- default prefdir used; Process/User/Machine `MATLAB_PREFDIR` all unset
- Simulink license `1`; `SIMULINK_LOAD_OK`
- no `errors_warnings` or ApplicationService startup fatal
- solver: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- matching D: `vs_sf.mexw64`; G: request `NO`
- CarSim terminated normally at simulation time `16 s`
- MATLAB batch exit code: `0`

Active SET-2 was absent before MATLAB launch, at runner entry, after target load, immediately before `sim()`, and after MATLAB exit. Post-load provenance passed. Post-runtime hygiene was checked only after live MATLAB process count reached zero; no SET-2 artifact existed, so no archive move was required.

Existing Derivative-block warnings were nonfatal and did not interrupt runtime.

## Runtime integrity

- D/K/F/fusion samples: `1601 / 1601 / 1601 / 1601`
- time range: `[0,16] s`
- dt min/mean/max: `0.0099999999999997868 / 0.01 / 0.010000000000001563 s`
- D-K, D-F, D-fusion timestamp maximum differences: `0 / 0 / 0`
- duplicate/missing hit gates: PASS
- D Ay updates: `321 / 321`
- K Ax/Ay/AVz hits: `1601 / 1601 / 1601`
- F feedbackApplied count: `0`
- D covariance max asymmetry/min eigenvalue: `0 / 0.00010125671209728746`
- K covariance max asymmetry/min eigenvalue: `0 / 0.000061803399198607023`
- F minimum P: `0.5`
- all required state/covariance/diagnostic outputs: finite

## Exact replay, maneuver, and truth

- D state/P/diag maximum differences: `0 / 0 / 0`
- K state/P/diag maximum differences: `0 / 0 / 0`
- F Vy/P/diag maximum differences: `0 / 0 / 0`
- fusion maximum replay difference: `0`
- actual steering amplitude/frequency: `0.040 rad / 0.40 Hz`
- FL/FR same-phase and RL/RR zero gates: PASS
- actual Vx min/mean/max: `19.961102124383302 / 19.970164342856862 / 20 m/s`
- truth alignment mode: `DIRECT_SAME_TIMESTAMP_ALIGNMENT`
- original/aligned truth samples: `16001 / 1601`
- evaluation window: full `[0,16]`, 1601 samples
- performance-based selection: not performed

## Immutable evidence and eligibility

- formal MAT: `results/vy_fixed_fusion_v2_5g_fwcal_c05.mat`
- SHA-256: `9DF5AC29F4588A91DBFC20FCCA55E124AF86DEB0CFA027B95099B08D50DB1B14`
- size: `4056924` bytes
- UTC mtime: `2026-08-29T10:07:58.5552945Z`
- runtime/in-memory gates: `23/23 PASS`
- analyzer integrity gates: `61/61 PASS`
- formal eligibility: `ELIGIBLE_CALIBRATION_DATA`

The formal MAT hash remained unchanged through analyzer-only evidence generation.

## Locked continuation state

- FWCAL_C01R1: eligible and unchanged at `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`
- FWCAL_C02 formal MAT: eligible and unchanged at `46972ED1AF86820551AA8C9AED2F2F8E4BC78F9551115F0A30715C62912BC4B3`
- old C02 pre-sim MAT: unchanged at `F78B76F1D63CB465B98401BF033E842A6BC440D88237F625AD11E8FF1D9A484F` and permanently excluded
- FWCAL_C03: eligible and unchanged at `70DEFDE01347BCA69FE523204759367B30A8489CF10400FA755352E8062928C6`
- FWCAL_C04: eligible and unchanged at `E59749EF6D2B7B69D9844FC00CCC095B2E93E9778ECF332D01F0FF3E0F2874B4`
- FWCAL_C05: eligible; authorization consumed
- formal calibration set: five eligible maneuvers (`C01R1`, `C02`, `C03`, `C04`, `C05`)
- original FWCAL_C01: permanently excluded; failed infrastructure/no usable data
- FWCAL_C05: completed; no further C05 runtime authorized
- holdout: all `H01-H03` remain `PLANNED_NOT_RUN`, result MAT absent, `data_viewed=FALSE`
- alpha_D / alpha_K / alpha_F: unselected
- no formal weights calculated or tuned
- frozen mismatch count: `0`

FWCAL_C05 COMPLETED ITS FIRST AND ONLY AUTHORIZED FORMAL RUNTIME.

THE ORIGINAL V2.5-F C05 CONDITION WAS PRESERVED EXACTLY.

FWCAL_C05 IS ELIGIBLE FOR FORMAL FIXED-WEIGHT CALIBRATION.

FWCAL_C01R1 / C02 / C03 / C04 / C05 FORM THE COMPLETE FIVE-MANEUVER FORMAL CALIBRATION DATASET.

ALL FIVE DATASETS ARE ELIGIBLE.

THE ORIGINAL FAILED FWCAL_C01 REMAINS EXCLUDED.

THE C02 PRE-SIM FAILURE MAT REMAINS EXCLUDED.

NO DIAGNOSTIC OR HISTORICAL DEVELOPMENT DATA WERE INCLUDED.

THE FINAL CALIBRATION ACQUISITION MANIFEST CONTAINS EXACTLY FIVE ELIGIBLE ROWS.

HOLDOUT REMAINS COMPLETELY UNTOUCHED.

NO WEIGHTS WERE CALCULATED OR TUNED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

READY FOR V2.5-H OFFLINE CONSTRAINED-QP WEIGHT SOLVE & IDENTIFIABILITY
