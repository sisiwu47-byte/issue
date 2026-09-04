# V2.5-I2-P0-R2 H02 Formal Runtime Pre-Sim Authorization Revalidation

## Conclusion

`V2.5-I2-P0-R2 H02 FORMAL RUNTIME PRE-SIM AUTHORIZATION REVALIDATION PASSED`

Fresh R2 read-only verification passed all `40/40` pre-sim gates. It did not start MATLAB, Simulink, CarSim, the H02 launcher, or the H02 bootstrap. It created no runtime marker and did not consume H02 authorization.

## Historical preservation and remediation lineage

The original P0 remains historically `BLOCKED` at `37/38 PASS`; its three evidence hashes remain unchanged. R1 append-only remediation also remains intact:

- R1 archive: `D:\SystemMigration\Temp\V25I2_P0_R1_H02_SET2_PRELAUNCH_HYGIENE_20260829T223607819Z\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa`
- Size: `1024` bytes
- SHA-256: `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`
- Fresh active SET-2 state: `ABSENT`

The historical blocked P0 record was not rewritten. The R1 archive and remediation evidence were not modified.

## Frozen run identity

| Field | Value |
|---|---|
| run_id | `FWHOLD_H02` |
| role | `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE` |
| condition | `0.035 rad / 0.35 Hz / 16 s / 100 Hz` |
| waveform | `SINE_FRONT_EQUAL_REAR_ZERO` |
| front/rear policy | `FL_FR_SAME_PHASE / RL_RR_ZERO` |
| speed scope | `VERIFIED_APPROX_20_MPS_CLASS` |
| truth alignment | `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT` |
| evaluation window | `[0_16]` |
| weight set | `V25_FIXED_WEIGHT_ALPHA_V1` |
| alpha | `[0.9004680917645591 0.09953190823544089 0]` |
| formal result | `results/vy_fixed_fusion_v2_5i_fwhold_h02.mat` |

H01 remains `CLOSED_FAILED_ACQUISITION`, and the original three-holdout primary metric remains `INCOMPLETE_DUE_TO_MISSING_H01_FORMAL_DATA`. H02 and H03 remain partial diagnostic evidence only and do not replace H01.

## Frozen hashes

| Artifact | SHA-256 | Result |
|---|---|---|
| runner | `D3218ED275508FD1F95F53C2F480081871331E9C9D9D978FFCAFEA6878F58844` | MATCH |
| analyzer | `E0A56418F141FA02A5B6E487753365D00358D498FC9514D719024EC9CAF708C8` | MATCH |
| MATLAB bootstrap | `9A4F389BD6B214798730891E01996CCD8219AA3236C2D92F5CE54D8F7C2ACB30` | MATCH |
| ASCII launcher | `92DC61AABC34DAF2A40A891296B65B176EE9E42A3031F2EB4A990685CC5A579B` | MATCH |
| formal target | `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` | MATCH |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | MATCH |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | MATCH |

Static execution-entry audit confirms exactly one executable `sim()` call site, zero retry/fallback paths, durable commit creation/close/existence/size/read-back validation before `SIM_AUTHORIZATION_COMMITTED`, and no sim-before-commit path. The ASCII launcher starts MATLAB exactly once and calls the H02 bootstrap only; the bootstrap enters the exact project model directory and invokes the dedicated H02 runner exactly once.

## Untouched and environment gates

- Live MATLAB and conflicting CarSim solver processes: `0`.
- `MATLAB_PREFDIR`: Process `UNSET`; User `UNSET`; Machine `UNSET`.
- H02 original status: `PLANNED_NOT_RUN`.
- H02 runtime count: `0`; data viewed: `FALSE`.
- H02 commit marker: `ABSENT`.
- H02 phase marker file: `ABSENT`.
- Formal H02 MAT: `ABSENT`.
- H02 runtime-only output artifacts: `ABSENT`.
- H02 authorization: `UNCONSUMED`.
- H03 remains `UNRUN / UNVIEWED / UNCONSUMED`; formal H03 MAT is absent.
- Project model directory, project simfile, D-drive CarSim PROGDIR/DATADIR, and solver DLL all exist; simfile D-drive lineage matches.

## Next-stage boundary

The next stage is permitted to execute the R0-frozen H02 ASCII launcher one time only. This R2 record is not `SIM_AUTHORIZATION_COMMITTED` and does not consume the runtime authorization. During the future formal runtime, authorization becomes `CONSUMED` only after the durable commit record has been created, closed, verified for existence and size, read back, and validated immediately before the unique `sim()` call.

THE ORIGINAL BLOCKED P0 RECORD REMAINS PRESERVED.

THE R1 SET-2 APPEND-ONLY REMEDIATION REMAINS INTACT.

THE FRESH R2 REVALIDATION CONFIRMED THAT THE ACTIVE PRELAUNCH SET-2 PATH IS ABSENT.

ALL H02 EXECUTION-ENTRY, IMPLEMENTATION, ENVIRONMENTAL, AND UNTOUCHED-DATA GATES PASSED.

NO MATLAB, SIMULINK, CARSIM, RUNTIME PHASE MARKER, OR SIM_AUTHORIZATION_COMMITTED RECORD WAS CREATED.

FWHOLD_H02 REMAINS COMPLETELY UNRUN AND UNVIEWED.

H02 FORMAL RUNTIME AUTHORIZATION REMAINS UNCONSUMED.

THE NEXT STAGE MAY EXECUTE THE FROZEN ASCII LAUNCHER ONE TIME ONLY.
