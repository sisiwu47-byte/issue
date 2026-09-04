# V2.5-G2 FWCAL_C02 Status

## Current final conclusion

**V2.5-G2 FWCAL_C02 FORMAL CALIBRATION ACQUISITION PASSED**

FWCAL_C02 completed its first and only authorized formal runtime. The runtime authorization is now permanently **CONSUMED**.

### Formal runtime identity

- run ID/role: `FWCAL_C02 / CALIBRATION_ONLY`
- original registry order: `2`
- replacement run: `NONE`
- steering: planned/actual `0.020 rad`, `0.50 Hz`
- duration/rate: planned/actual `16 s`, `100 Hz`
- waveform: `SINE_FRONT_EQUAL_REAR_ZERO`
- front/rear policy: FL/FR same phase; RL/RR zero
- speed scope: existing verified approximately 20 m/s class
- truth alignment: `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`
- evaluation window: full `[0,16]`, 1601 samples

No maneuver condition, estimator, fusion algorithm, vehicle model, simfile, or CarSim dataset was modified.

### Startup and CarSim

- `MATLAB_STARTUP_OK`
- MATLAB: `24.1.0.2537033 (R2024a)`
- active prefdir: `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a`
- Process/User/Machine `MATLAB_PREFDIR`: all `UNSET`
- Simulink license: `1`
- `SIMULINK_LOAD_OK`
- startup fatal errors: none observed
- solver: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- matching MEX: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64`
- G: request: `NO`
- CarSim termination: normal at simulation time `16 s`
- MATLAB batch exit code: `0`

The existing Derivative-block messages were warnings and did not interrupt simulation.

### SET-2 lifecycle

Active SET-2 was absent before MATLAB launch and at runner entry. It remained absent after target load, immediately before `sim()`, during the recorded runtime lifecycle, and after MATLAB exit. Provenance gate passed because absence itself satisfies the corrected lifecycle policy.

Post-runtime hygiene was performed only after live MATLAB process count reached zero. No SET-2 artifact existed, so no archive move was required. The R3 Q04 original, R4 SET-2 original, and C02-R0 archive remain unchanged.

### Runtime integrity

- simulation/CarSim: completed
- D/K/F/fusion samples: `1601 / 1601 / 1601 / 1601`
- interval: `[0,16] s`
- dt min/mean/max: `0.0099999999999997868 / 0.01 / 0.010000000000001563 s`
- D-K, D-F, D-fusion maximum timestamp difference: `0 / 0 / 0`
- duplicate/missing hit gates: PASS
- D Ay updates: `321 / 321`
- K Ax/Ay/AVz hits: `1601 / 1601 / 1601`
- F feedbackApplied count: `0`
- D/K/F state and covariance/P: finite
- D covariance max asymmetry/min eigenvalue: `0 / 0.00010039140086337631`
- K covariance max asymmetry/min eigenvalue: `0 / 0.000061803398903582669`
- F minimum P: `0.5`

### Exact replay and maneuver evidence

- D state/P/diag maximum differences: `0 / 0 / 0`
- K state/P/diag maximum differences: `0 / 0 / 0`
- F Vy/P/diag maximum differences: `0 / 0 / 0`
- fusion maximum replay difference: `0`
- steering maximum command: `0.020 rad`
- steering frequency: `0.50 Hz`
- rear RL/RR maximum: `0 / 0`
- actual Vx min/mean/max: `19.977274630990316 / 19.979413142297986 / 20 m/s`

The fixed integration weights remain test-only and were not interpreted as formal alpha.

### Truth and eligibility

- true Vy use: offline calibration truth only
- alignment mode: `DIRECT_SAME_TIMESTAMP_ALIGNMENT`
- original/aligned truth samples: `16001 / 1601`
- evaluation window: full `[0,16]`, 1601 samples
- performance-based selection: not performed
- formal calibration eligibility: `ELIGIBLE_CALIBRATION_DATA`
- analyzer gates: `61/61 PASS`
- in-memory runtime gates: `23/23 PASS`

### Immutable formal evidence

- formal MAT: `results/vy_fixed_fusion_v2_5g_fwcal_c02_formal_runtime.mat`
- SHA-256: `46972ED1AF86820551AA8C9AED2F2F8E4BC78F9551115F0A30715C62912BC4B3`
- size: `3988820` bytes
- UTC mtime: `2026-08-29T07:51:15.9696561Z`

The hash remained identical through analyzer-only evidence generation.

The earlier file `results/vy_fixed_fusion_v2_5g_fwcal_c02.mat` remains unchanged at SHA-256 `F78B76F1D63CB465B98401BF033E842A6BC440D88237F625AD11E8FF1D9A484F`; it is permanently classified as `PRE_SIM_FAILURE_EVIDENCE` and excluded from calibration.

### Locked continuation state

- FWCAL_C01R1: eligible and unchanged
- FWCAL_C02: completed; eligible; authorization consumed
- FWCAL_C03-C05: unrun and unconsumed
- holdout: untouched; performance not viewed
- alpha_D / alpha_K / alpha_F: unselected
- formal optimization/weight tuning: not performed
- frozen mismatch count: `0`

FWCAL_C02 COMPLETED ITS FIRST AND ONLY AUTHORIZED FORMAL RUNTIME.

THE ORIGINAL PRE-REGISTERED C02 CONDITION WAS PRESERVED EXACTLY.

FWCAL_C02 IS ELIGIBLE FOR FORMAL FIXED-WEIGHT CALIBRATION.

THE EARLIER C02 PRE-SIM FAILURE MAT REMAINS PRESERVED AND EXCLUDED FROM CALIBRATION.

POST-STARTUP SET-2 REGENERATION WAS ALLOWED WITH PROVENANCE LOGGING; IN THIS SESSION SET-2 REMAINED ABSENT.

THE POST-RUNTIME SET-2 HYGIENE CHECK WAS PERFORMED ONLY AFTER ALL MATLAB PROCESSES EXITED; NO SET-2 ARTIFACT EXISTED, SO NO ARCHIVE MOVE WAS REQUIRED.

FWCAL_C01R1 REMAINS ELIGIBLE AND UNCHANGED.

FWCAL_C03-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

## Historical pre-sim conclusion (preserved)

**V2.5-G2 FWCAL_C02 PRE-SIM BLOCKED**

FWCAL_C02 did not call `sim()` and did not start CarSim. Its one-runtime authorization remains **UNCONSUMED**.

## Original preregistration

The two frozen V2.5-F CSV registries uniquely resolve FWCAL_C02 as original order 2:

- role/status: `CALIBRATION_ONLY / PLANNED_NOT_RUN`
- steering: `0.020 rad`, `0.50 Hz`, `SINE_FRONT_EQUAL_REAR_ZERO`
- front/rear policy: FL/FR same phase; RL/RR zero
- duration/rate: `16 s / 100 Hz`
- speed scope: `CURRENT_CARSIM_20_MPS_CLASS_NOT_RUNNER_PARAMETERIZED`
- truth alignment: `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`
- evaluation window: `[0_16]`
- reserved result path: `results/vy_fixed_fusion_v2_5g_fwcal_c02.mat`

Planned and commanded run-card values were identical.

## Exact blocker

Before MATLAB launch, active SET-2 was absent, all three `MATLAB_PREFDIR` scopes were unset, and live MATLAB process count was zero. The runner also recorded `postQuarantine.activeSet2SourceAbsent = 1` during its initial environment audit.

After `load_system` and static preflight, but immediately before the only `sim()` call site, MATLAB had regenerated:

`C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa`

The immediate evidence was:

- `activeSet2SourceAbsent = 0`
- active SET-2 SHA-256: `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`
- error identifier: `V25G2:ImmediatePreSim`
- error message: `Immediate pre-sim gate failed.`
- `simCalled = 0`
- `simCallCount = 0`
- `simulationCompleted = 0`
- `carSimRun = 0`
- MATLAB batch exit code: `1`

This is a pre-simulation environment-policy failure, not estimator, fusion, Simulink-runtime, or CarSim-runtime evidence.

## Reserved-path evidence collision

The runner's failure branch saved the pre-simulation report to the formally reserved runtime path despite `simCalled = 0`:

- file: `results/vy_fixed_fusion_v2_5g_fwcal_c02.mat`
- SHA-256: `F78B76F1D63CB465B98401BF033E842A6BC440D88237F625AD11E8FF1D9A484F`
- size: `177408` bytes
- UTC mtime: `2026-08-29T07:15:22.7140490Z`

This file contains pre-sim failure evidence and is **not** a usable calibration runtime dataset. It was not overwritten, deleted, or renamed. Consequently, the frozen result-path absence gate also no longer passes. Any future attempt requires an explicit append-only evidence/result-path policy decision; it cannot proceed automatically.

## Environment and lineage integrity

- R3 Q04 quarantine original: exists; SHA-256 `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B`
- R4 SET-2 quarantine original: exists; SHA-256 `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`
- no quarantine artifact was restored, moved, deleted, or additionally quarantined
- C01R1 remains unchanged and eligible; SHA-256 `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`
- C03-C05 remain unrun and their runtime authorizations remain unconsumed
- holdout remains untouched
- `alpha_D / alpha_K / alpha_F` remain unselected

## Frozen integrity

The fixed-fusion target remains:

`801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE`

All audited frozen D-EKF, K-KF, DK-EKF, F-track, parallel, fusion core/wrapper, and `simfile.sim` hashes remain at their accepted baselines.

## Peripheral evidence changes

Only the G2 runner/analyzer evidence handling was adjusted before the attempted runtime to normalize numeric registry fields and record quarantine/PREFDIR evidence. No `.slx`, estimator, fusion core/wrapper, CarSim dataset, simfile, weight, or preregistered maneuver was changed.

## Required decision before any further C02 action

Two constraints now require explicit resolution:

1. whether automatic SET-2 regeneration during model loading is compatible with the post-quarantine policy; and
2. how to preserve the existing pre-sim failure MAT while restoring a unique append-only path for any future formal C02 dataset.

No second or replacement C02 runtime is authorized by this status.

## Current handoff (supersedes the historical blocker above)

The R0 lifecycle/path remediation resolved both historical blockers, and the subsequent first formal FWCAL_C02 runtime passed. No second C02 runtime is authorized or needed.

READY FOR V2.5-G2 FWCAL_C03 CALIBRATION ACQUISITION
