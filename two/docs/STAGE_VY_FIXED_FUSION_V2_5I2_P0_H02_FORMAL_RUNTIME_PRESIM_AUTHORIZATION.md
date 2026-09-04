# V2.5-I2-P0 H02 Formal Runtime Pre-Sim Authorization

## Conclusion

`V2.5-I2-P0 H02 FORMAL RUNTIME PRE-SIM AUTHORIZATION BLOCKED`

The exact critical blocker is that the active default R2024a PREFDIR still contains:

`C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa`

- Exists: `TRUE`
- Size: `1024` bytes
- SHA-256: `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`
- Last write time: `2026-08-29T22:34:45.8547875+08:00`

The P0 rule requires this SET-2 candidate to be absent. It was not deleted, moved, archived, or modified. MATLAB was not started.

## Run-card identity

| Field | Frozen value |
|---|---|
| run_id | `FWHOLD_H02` |
| role | `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE` |
| condition | `0.035 rad / 0.35 Hz / 16 s / 100 Hz` |
| waveform | `SINE_FRONT_EQUAL_REAR_ZERO` |
| front policy | `FL_FR_SAME_PHASE` |
| rear policy | `RL_RR_ZERO` |
| speed scope | `VERIFIED_APPROX_20_MPS_CLASS` |
| truth alignment | `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT` |
| evaluation window | `[0_16]` |
| weight set | `V25_FIXED_WEIGHT_ALPHA_V1` |
| alpha_D | `0.9004680917645591` |
| alpha_K | `0.09953190823544089` |
| alpha_F | `0` |
| formal result path | `results/vy_fixed_fusion_v2_5i_fwhold_h02.mat` |
| authorization state | `UNCONSUMED` |

## Frozen execution-entry integrity

| Artifact | SHA-256 | Result |
|---|---|---|
| runner | `D3218ED275508FD1F95F53C2F480081871331E9C9D9D978FFCAFEA6878F58844` | MATCH |
| analyzer | `E0A56418F141FA02A5B6E487753365D00358D498FC9514D719024EC9CAF708C8` | MATCH |
| MATLAB bootstrap | `9A4F389BD6B214798730891E01996CCD8219AA3236C2D92F5CE54D8F7C2ACB30` | MATCH |
| ASCII launcher | `92DC61AABC34DAF2A40A891296B65B176EE9E42A3031F2EB4A990685CC5A579B` | MATCH |
| formal target | `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` | MATCH |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | MATCH |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | MATCH |

The R0 freeze artifacts are unchanged. The R0 preparation gate file remains `37/37 PASS`. Static control-flow audit still shows one executable `sim()` call site, zero retry/fallback paths, durable commit creation and read-back before the unique `sim()` call, one ASCII MATLAB launch, and one dedicated H02 runner invocation.

## Lineage and untouched-state findings

- H01 remains `CLOSED_FAILED_ACQUISITION`; rerun and replacement remain forbidden.
- The original three-holdout primary metric remains `INCOMPLETE_DUE_TO_MISSING_H01_FORMAL_DATA`.
- H02 and H03 remain `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`; neither replaces H01.
- The immutable preregistry hash is `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`.
- The unique execution-order-2 row is `FWHOLD_H02`, with original registry role `HOLDOUT_VALIDATION` and status `PLANNED_NOT_RUN`.
- H02 remains completely unrun and unviewed: runtime count `0`, data viewed `FALSE`, formal MAT absent.
- H03 remains completely unrun and unviewed: runtime count `0`, data viewed `FALSE`, formal MAT absent.

## Environment and side-effect evidence

- Live MATLAB process count: `0`.
- No conflicting MATLAB helper or CarSim solver process was observed by the available read-only process enumeration.
- `MATLAB_PREFDIR`: Process `UNSET`; User `UNSET`; Machine `UNSET`.
- Project model directory, project `simfile.sim`, D-drive CarSim PROGDIR, DATADIR, and solver DLL all exist.
- Project `simfile.sim` still points to the audited D-drive PROGDIR/DATADIR lineage.
- Runtime phase marker file: `ABSENT`.
- `SIM_AUTHORIZATION_COMMITTED`: `ABSENT`.
- Formal H02 MAT: `ABSENT`.
- H02 acquisition, integrity, metrics, and runtime-status artifacts: `ABSENT`.
- No MATLAB, Simulink, CarSim, launcher, bootstrap, or runtime was executed in P0.

## Authorization result

The gate evidence is `37/38 PASS`; critical gate 24 (`active SET-2 absent`) failed. Therefore formal runtime launch authorization for the next stage is `FALSE`. H02 authorization remains `UNCONSUMED`; no runtime phase markers or commit record were created.

The frozen launcher must not be executed until a separately authorized remediation makes the active SET-2 prelaunch gate pass and a fresh read-only P0 gate is completed.
