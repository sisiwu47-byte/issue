# V2.5-G2-C02-R0 Pre-Sim Lifecycle & Result-Path Remediation

## Conclusion

**V2.5-G2-C02-R0 PRE-SIM LIFECYCLE & RESULT-PATH REMEDIATION ACCEPTED**

The C02 blocker occurred before `sim()` and did not consume the FWCAL_C02 runtime authorization.

## Methodological finding

R4/R5 established that SET-2 absence at MATLAB process launch is part of the healthy startup recovery gate. The blocked C02 pre-sim session then established a distinct lifecycle fact: after a healthy startup, `load_system(target)` can automatically regenerate SET-2 before simulation.

The corrected frozen lifecycle is:

1. Before MATLAB launch: active SET-2 **MUST BE ABSENT**.
2. MATLAB startup: startup marker, default `prefdir`, Simulink license/load, and absence of fatal startup errors must pass.
3. After target load: SET-2 may be present as `ALLOWED_POST_STARTUP_REGENERATION`.
4. Immediately before `sim()`: if present, path, SHA-256, size, creation time, and modification time are captured. Prelaunch and runner-entry absence plus a current-session timestamp check must prove provenance.
5. A regenerated SET-2 is never moved or deleted while MATLAB is live.
6. After all MATLAB processes exit, any regenerated SET-2 must be append-only archived before the next independent calibration run.

The earlier requirement that SET-2 remain absent until `sim()` was an over-strict orchestration gate. Correcting it does not alter estimator logic, fusion logic, vehicle model, CarSim configuration, or maneuver conditions.

## Regenerated SET-2 archive

The live MATLAB process count was zero before the state transition.

- source: `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa`
- source SHA-256: `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`
- source size: `1024` bytes
- source ctime/mtime: `2026-08-29T07:12:44.2016420Z`
- archive destination: `D:\SystemMigration\Temp\V25G2_C02_R0_REGENERATED_SET2_ARCHIVE_20260829T072335Z\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa`
- move time: `2026-08-29T07:23:35.9628003Z`
- source after move: `ABSENT`
- destination after move: `PRESENT`, byte/hash exact

The R3 Q04 original and R4 SET-2 original quarantine entries remain unchanged at their accepted hashes. Nothing was restored, deleted, or overwritten.

## Preserved pre-sim failure evidence

The original reserved path is permanently retained as failure evidence:

- path: `results/vy_fixed_fusion_v2_5g_fwcal_c02.mat`
- role: `PRE_SIM_FAILURE_EVIDENCE`
- formal calibration data: `NO`
- sim called: `NO`
- runtime authorization consumed: `NO`
- formal calibration eligibility: `NOT_APPLICABLE_PRE_SIM`
- SHA-256: `F78B76F1D63CB465B98401BF033E842A6BC440D88237F625AD11E8FF1D9A484F`

The file was not deleted, renamed, overwritten, or reused. The corrected analyzer explicitly excludes it from calibration.

## Append-only formal runtime path

FWCAL_C02 remains the original preregistered run ID. No replacement ID or replacement run was created.

The registered formal runtime path is now:

`results/vy_fixed_fusion_v2_5g_fwcal_c02_formal_runtime.mat`

It is absent at R0 completion. The runner may create it only after `sim()` is actually called. Any future pre-sim failure exits without creating a formal runtime MAT.

## Runner/analyzer correction

Only peripheral orchestration and evidence handling changed:

- C02 resolves to the new formal path through the append-only remediation registry.
- C03 sequence checking also resolves C02 through that registered formal path.
- the original C02 failure MAT is hash-locked and excluded from analyzer input.
- active SET-2 must be absent before launch and at runner entry.
- post-target-load SET-2 presence is allowed only with current-session provenance and full metadata logging.
- a pre-sim exception with `simCalled = 0` cannot save to the formal runtime path.
- runtime failure evidence may be saved only after `sim()` was actually called.

The original V2.5-F suite plan and run registry were not modified. Amplitude, frequency, duration, rate, waveform, speed scope, truth alignment, and evaluation window remain unchanged.

## Gate result

All 20 R0 gates passed:

1. live MATLAB count = 0
2. regenerated SET-2 append-only archived
3. active SET-2 source absent after hygiene
4. R3 Q04 quarantine unchanged
5. R4 SET-2 quarantine unchanged
6. old C02 failure MAT unchanged
7. old MAT classified `PRE_SIM_FAILURE_EVIDENCE`
8. old MAT excluded from calibration
9. new formal C02 path registered
10. new formal path absent
11. run ID remains FWCAL_C02
12. maneuver unchanged
13. sim call count remains 0
14. runtime authorization remains UNCONSUMED
15. prelaunch absence and post-startup regeneration are distinguished
16. pre-sim failure cannot occupy the formal runtime path
17. C03-C05 untouched
18. holdout untouched
19. alpha remains unselected
20. frozen model/core/simfile hashes unchanged

## Locked state

- FWCAL_C02 runtime authorization: `UNCONSUMED`
- FWCAL_C03-C05: `UNRUN / UNCONSUMED`
- holdout: `UNTOUCHED`
- alpha_D / alpha_K / alpha_F: `UNSELECTED`
- MATLAB / `sim()` / CarSim executions in R0: `0 / 0 / 0`

THE C02 BLOCKER OCCURRED BEFORE sim() AND DID NOT CONSUME THE FWCAL_C02 RUNTIME AUTHORIZATION.

FWCAL_C02 REMAINS THE ORIGINAL PRE-REGISTERED RUN ID; NO REPLACEMENT RUN WAS CREATED.

THE PRIOR C02 MAT IS PERMANENTLY PRESERVED AS PRE_SIM_FAILURE_EVIDENCE AND IS EXCLUDED FROM FORMAL CALIBRATION.

A NEW APPEND-ONLY FORMAL C02 RUNTIME PATH HAS BEEN REGISTERED.

SET-2 MUST BE ABSENT BEFORE MATLAB LAUNCH, BUT MATLAB-GENERATED SET-2 REGENERATION AFTER A HEALTHY STARTUP / TARGET LOAD IS NOW EXPLICITLY ALLOWED WITH PROVENANCE LOGGING.

NO MANEUVER CONDITION WAS CHANGED.

NO MATLAB / sim() / CarSim WAS EXECUTED IN R0.

FWCAL_C02 RUNTIME AUTHORIZATION REMAINS UNCONSUMED.

C03-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

READY TO RESUME V2.5-G2 FWCAL_C02 FROM THE CORRECTED PRE-SIM GATE
