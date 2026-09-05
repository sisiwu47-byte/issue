# V2.5-G2-R4 Targeted Quarantine Set-2 Startup Test

## Conclusion

**V2.5-G2-R4 TARGETED QUARANTINE SET-2 STARTUP TEST PASSED**

MATLAB completed the single authorized startup-only probe successfully under the current post-R3 background after the one-file SET-2 artifact was quarantined. This is strong incremental causal evidence, but it does not prove that SET-2 is the sole root cause: the original pre-R3 Q04 remained externally quarantined, while the regenerated active Q04 remained present and was updated again by the successful R4 startup.

No simulation, CarSim runtime, calibration case, holdout run, or alpha calculation was performed.

## Frozen SET-2 input

The exact action plan was read from `results/vy_fixed_fusion_v2_5g2_r3b_set2_action_plan.csv`.

| Field | Value |
|---|---|
| SET | `R3B_SET_2` |
| Candidate | `Q06` |
| Relative path | `ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa` |
| Absolute source | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa` |
| Expected SHA-256 | `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` |
| Expected size | 1024 bytes |
| Operation | MOVE outside active PREFDIR; no delete |

The action plan freezes the destination relative path, while the R3B status requires R4 to create a new unique external quarantine root. R4 used:

```text
D:\SystemMigration\Temp\V25G2_R4_TARGETED_PREFDIR_QUARANTINE_SET2_20260829T024814Z
```

This root did not exist before execution and is outside the active PREFDIR, R2 diagnostic PREFDIR, old-bad backup, and Q04 quarantine.

## Pre-move hard gates

| Gate | Evidence | Result |
|---|---|---|
| Live MATLAB process count | `0` | PASS |
| Process/User/Machine `MATLAB_PREFDIR` | all UNSET | PASS |
| SET-2 source exists | YES | PASS |
| Source size | 1024 bytes | PASS |
| Source SHA-256 | `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` | PASS |
| Source creation UTC | `2026-08-29T02:10:12.4676352Z` | recorded |
| Source mtime UTC | `2026-08-29T02:10:12.4689214Z` | recorded |
| Source attributes | `Archive` | recorded |
| R3 quarantined Q04 original | exists; `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | PASS |
| Active regenerated Q04 | exists; `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8` | PASS |

Neither Q04 version was moved, restored, deleted, overwritten, or modified by the SET-2 move.

## Exact one-file MOVE

| Field | Evidence |
|---|---|
| Move timestamp UTC | `2026-08-29T02:48:14.5415188Z` |
| Source absent after move | YES |
| Destination present | YES |
| Destination | `D:\SystemMigration\Temp\V25G2_R4_TARGETED_PREFDIR_QUARANTINE_SET2_20260829T024814Z\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa` |
| Destination size | 1024 bytes |
| Destination SHA-256 | `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` |
| Other file moved | NO |
| Directory moved | NO |

The quarantined SET-2 original was not restored after the probe.

## Single startup-only probe

Launcher-level stdout and stderr capture files were created before MATLAB was started.

| Field | Evidence |
|---|---|
| Executable | `D:\matlab\bin\matlab.exe` |
| Mode | `-batch` |
| Working directory | `D:\UsersData\桌面\two` |
| PID | `31648` |
| Launch UTC | `2026-08-29T02:49:13.2696137Z` |
| Exit UTC | `2026-08-29T02:49:37.5462150Z` |
| Completion | normal wait completion |
| Exit code | `0` |
| Live MATLAB count before/after | `0 / 0` |
| Probe count | exactly one |
| `MATLAB_PREFDIR` override | NO |
| Project target loaded | NO |
| `sim()` | NO |
| CarSim | NO |

Raw stdout markers:

```text
MATLAB_STARTUP_OK
MATLAB_VERSION=24.1.0.2537033 (R2024a)
ACTIVE_PREFDIR=C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
SIMULINK_LICENSE=1
SIMULINK_LOAD_OK
CHECKCODE_RUNNER_EXECUTED=1
CHECKCODE_RUNNER_ISSUE_COUNT=2
CHECKCODE_ANALYZER_EXECUTED=1
CHECKCODE_ANALYZER_ISSUE_COUNT=2
G2_CHECKCODE_OK
```

Stderr is empty. The `checkcode` issue counts are static advisory findings; both requested files were reached and checked, and no fatal startup, `errors_warnings`, or ApplicationService error occurred.

| Gate | Result |
|---|---|
| `MATLAB_STARTUP_OK` | PASS |
| version reached | PASS |
| expected active PREFDIR | PASS |
| Simulink license = 1 | PASS |
| `SIMULINK_LOAD_OK` | PASS |
| runner `checkcode` executed | PASS |
| analyzer `checkcode` executed | PASS |
| `errors_warnings` fatal absent | PASS |
| ApplicationService fatal absent | PASS |
| exit code = 0 | PASS |

## SET-2 regeneration

After MATLAB exited:

- active SET-2 source path regenerated: **NO**;
- active source remains absent;
- quarantined original remains present;
- quarantined original SHA-256 remains `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`;
- automatic restore: NO;
- `.jsonrsa` structured analysis: not attempted because it is treated as a signed/opaque artifact.

## Q04 background after probe

The active regenerated Q04 remained present and was updated automatically during successful startup:

| Field | Before R4 probe | After R4 probe |
|---|---|---|
| SHA-256 | `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8` | `9972A204D3EDF2243BFF97EB93A89F22159D61F68F5B4F37FAE0B50AEB875066` |
| Size | 437372 | 437372 |
| mtime UTC | `2026-08-29T02:10:29.1203790Z` | `2026-08-29T02:49:33.6959692Z` |
| JSON validity | VALID | VALID |
| Leaf count | 4234 | 4234 |
| Field-level differences | — | 1891 value changes |

The dominant changed categories were path/cache, plugin/toolstrip, settings/provider/service, and registration/dependency-related fields. Values are retained only as type and SHA-256 summaries. Q04 was not moved or overwritten.

The pre-R3 Q04 original remains in its R3 external quarantine with its registered hash and was not restored.

## Probe-window PREFDIR differential

Window:

```text
SET-2 move: 2026-08-29T02:48:14.5415188Z
MATLAB launch: 2026-08-29T02:49:13.2696137Z
MATLAB exit: 2026-08-29T02:49:37.5462150Z
```

Six active-PREFDIR files changed:

| Relative path | Status | Post-probe SHA-256 / result |
|---|---|---|
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | HASH_CHANGED | `9972A204D3EDF2243BFF97EB93A89F22159D61F68F5B4F37FAE0B50AEB875066` |
| `sl_toolstrip_plugins\preferences.json` | HASH_CHANGED | `E3A746BEC56CA92D6B36A2F704BC014A51C972862D64A4A95265A3D249DCC721` |
| `sdiprefs.json` | MTIME_ONLY | content hash unchanged |
| `signalanalyzerprefs.json` | MTIME_ONLY | content hash unchanged |
| `stmprefs.json` | MTIME_ONLY | content hash unchanged |
| `VisibleSettings.json` | MTIME_ONLY | content hash unchanged |

Summary:

- ADDED: `0`;
- HASH_CHANGED: `2`;
- MTIME_ONLY: `4`;
- SET-2 regenerated: `NO`;
- invalid JSON/XML: `0`.

## Incremental causal interpretation

**STARTUP RECOVERED UNDER THE CURRENT POST-R3 BACKGROUND AFTER SET-2 QUARANTINE.**

This is stronger than the inconclusive R3 result because R4 captured a complete launcher-level trace, every required payload marker, a normal exit, and exit code 0. It demonstrates that healthy startup is possible when the single SET-2 startup-schema artifact is absent under the current post-R3 background.

It does not prove that `SL_PERFORMANCE_STARTUP.jsonrsa` is the sole root cause because:

- the original pre-R3 Q04 remains quarantined;
- a regenerated Q04 remains active;
- active Q04 and toolstrip preference content changed again during R4;
- only one post-SET-2 startup probe was authorized and executed.

No second probe or calibration run is permitted in R4.

## Frozen and authorization integrity

- frozen mismatch count: `0`;
- C01R1 immutable MAT hash: `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`;
- fixed-fusion target/core/wrapper: unchanged;
- parallel D/K, D-EKF, K-KF, DK-EKF and F-track frozen targets: unchanged;
- `model/simfile.sim`: unchanged;
- V2.5-F, G1C, R1, R2, R3, R3A and R3B evidence: unchanged;
- Q04 quarantined original: unchanged;
- FWCAL_C02/C03/C04/C05 runtime MAT count: `0`;
- FWCAL_C02-C05 runtime authorizations: **ALL UNCONSUMED**;
- holdout: UNTOUCHED;
- alpha: UNSELECTED.

## Final declarations

MATLAB STARTUP COMPLETED SUCCESSFULLY UNDER THE CURRENT POST-R3 BACKGROUND AFTER QUARANTINING THE SINGLE SET-2 STARTUP-SCHEMA ARTIFACT.

THIS IS STRONG INCREMENTAL CAUSAL EVIDENCE, BUT IT DOES NOT YET PROVE THAT SET-2 IS THE SOLE ROOT CAUSE.

THE SET-2 ORIGINAL REMAINS PRESERVED IN EXTERNAL QUARANTINE.

THE R3 Q04 ORIGINAL REMAINS PRESERVED AND WAS NOT RESTORED.

NO CALIBRATION RUNTIME WAS EXECUTED.

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

READY FOR V2.5-G2-R5 POST-QUARANTINE STARTUP STABILITY / RECOVERY DECISION
