# V2.5-G2-R5 Post-Quarantine Startup Stability Confirmation

## Conclusion

**V2.5-G2-R5 POST-QUARANTINE STARTUP STABILITY CONFIRMATION PASSED**

The unchanged post-R4 quarantine state has now supported two consecutive successful MATLAB/Simulink startup-only probes: R4 and the independently launched R5 replication. R5 made no PREFDIR file move, restore, deletion, cleanup, or environment override.

No simulation, CarSim runtime, calibration case, holdout run, or alpha calculation was performed.

## Fixed pre-probe background

R5 read exact paths and hashes from R3/R4 evidence rather than from abbreviated prompt values.

| Artifact | Pre-probe state | SHA-256 / evidence |
|---|---|---|
| R3 quarantined original Q04 | present | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` |
| Active regenerated Q04 | present | `9972A204D3EDF2243BFF97EB93A89F22159D61F68F5B4F37FAE0B50AEB875066` |
| R4 quarantined SET-2 original | present | `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` |
| Active SET-2 source | absent | expected post-R4 state |

Active Q04 pre-probe fingerprint:

- path: `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\epfwk_cache-24.1.0.2537033-7203099541395556032.json`;
- size: 437372 bytes;
- mtime UTC: `2026-08-29T02:49:33.6959692Z`.

The active SET-2 source remained absent. Therefore no unexpected post-R4 state change blocked the probe.

## Process and environment gates

| Gate | Evidence | Result |
|---|---|---|
| Live MATLAB count before probe | `0` | PASS |
| Process `MATLAB_PREFDIR` | UNSET | PASS |
| User `MATLAB_PREFDIR` | UNSET | PASS |
| Machine `MATLAB_PREFDIR` | UNSET | PASS |
| `TEMP` | `D:\SystemMigration\Temp` | recorded, unchanged |
| `TMP` | `D:\SystemMigration\Temp` | recorded, unchanged |
| `APPDATA` | `C:\Users\21180\AppData\Roaming` | recorded, unchanged |
| `LOCALAPPDATA` | `C:\Users\21180\AppData\Local` | recorded, unchanged |
| `USERPROFILE` | `C:\Users\21180` | recorded, unchanged |

The first launcher command encountered a PowerShell `foreach` syntax error before `Start-Process` was reached. It created no MATLAB PID or capture file, did not consume the R5 probe authorization, and caused no filesystem state change. The corrected launcher then executed the one authorized MATLAB process described below.

## One independent R5 startup-only probe

| Field | Evidence |
|---|---|
| Executable | `D:\matlab\bin\matlab.exe` |
| Mode | `-batch` |
| Working directory | `D:\UsersData\桌面\two` |
| PID | `25088` |
| Launch UTC | `2026-08-29T03:00:38.6726816Z` |
| Exit UTC | `2026-08-29T03:01:03.1727016Z` |
| Exit code | `0` |
| Live MATLAB count after exit | `0` |
| Authorization consumed | YES, exactly once |
| Project model loaded | NO |
| Runner executed | NO |
| `sim()` called | NO |
| CarSim run | NO |

Launcher-level stdout was established before process launch and contains:

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

Stderr is empty. No `errors_warnings` or ApplicationService fatal marker occurred. The two `checkcode` issue counts per file are advisory static findings; both requested files were reached and checked successfully.

| PASS condition | Result |
|---|---|
| `MATLAB_STARTUP_OK` | PASS |
| version reached | PASS |
| expected active PREFDIR | PASS |
| Simulink license = 1 | PASS |
| `SIMULINK_LOAD_OK` | PASS |
| runner `checkcode` executed | PASS |
| analyzer `checkcode` executed | PASS |
| no fatal stderr | PASS |
| no `errors_warnings` fatal | PASS |
| no ApplicationService fatal | PASS |
| process exited | PASS |
| exit code = 0 | PASS |
| no live MATLAB after exit | PASS |

## Post-probe filesystem state

| Artifact | Post-probe state | Hash change |
|---|---|---|
| Active Q04 | present; 437372 bytes; mtime `2026-08-29T03:00:59.2532755Z`; SHA-256 `05169B11D0A99CFDEB28DB67E660A0DEB92FB539AE12797EEF6E7164FB748C79` | YES, automatic MATLAB update |
| Active SET-2 source | absent | NO state change |
| R3 Q04 quarantined original | present; SHA-256 `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | NO |
| R4 SET-2 quarantined original | present; SHA-256 `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` | NO |

Active Q04 changed automatically during successful R5 startup, as it also did during R4. Its size remained unchanged. R5 did not move or overwrite it. The SET-2 source did not regenerate.

## Consecutive-success classification

R4 and R5 both completed with:

- the same post-quarantine policy;
- the original pre-R3 Q04 still externally quarantined;
- regenerated active Q04 present;
- SET-2 original externally quarantined;
- active SET-2 source absent;
- no intervening restore or additional quarantine;
- no `MATLAB_PREFDIR` override;
- complete MATLAB, Simulink, and `checkcode` markers;
- normal launcher completion and exit code 0.

Classification:

**POST_QUARANTINE_STARTUP_STABILITY_CONFIRMED**

THE POST-R4 QUARANTINE STATE HAS NOW SUPPORTED TWO CONSECUTIVE SUCCESSFUL MATLAB/SIMULINK STARTUPS.

THE SET-2 REMOVAL IS STRONGLY ASSOCIATED WITH RECOVERY UNDER THE CURRENT POST-R3 BACKGROUND.

This remains strong incremental evidence, not unique sole-root-cause proof. The causal background still includes a quarantined pre-R3 Q04 and an active Q04 that regenerates and changes during successful startup.

## Frozen and authorization integrity

- frozen/project mismatch count: `0`;
- C01R1 immutable MAT unchanged;
- fixed-fusion target/core/wrapper unchanged;
- `model/simfile.sim` unchanged;
- V2.5-F registries unchanged;
- G1C evidence unchanged;
- R1–R4 evidence unchanged;
- both quarantine originals unchanged;
- live MATLAB count after R5: `0`;
- FWCAL_C02/C03/C04/C05 runtime MAT count: `0`;
- FWCAL_C02-C05 runtime authorizations: **ALL UNCONSUMED**;
- holdout: UNTOUCHED;
- alpha: UNSELECTED.

## Final declarations

THE CURRENT POST-QUARANTINE STATE HAS NOW COMPLETED TWO CONSECUTIVE SUCCESSFUL MATLAB/SIMULINK STARTUP-ONLY PROBES.

NO ADDITIONAL PREFDIR FILE WAS MOVED, RESTORED, DELETED, OR MODIFIED BY THE TEST PROCEDURE.

THE SET-2 ORIGINAL REMAINS PRESERVED IN EXTERNAL QUARANTINE.

THE R3 Q04 ORIGINAL REMAINS PRESERVED IN EXTERNAL QUARANTINE.

THE ACTIVE REGENERATED Q04 STATE HAS BEEN RECORDED.

THIS PROVIDES STRONG RECOVERY EVIDENCE BUT DOES NOT PROVE A UNIQUE SOLE ROOT CAUSE.

NO CALIBRATION RUNTIME WAS EXECUTED.

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

READY TO RESUME V2.5-G2 FROM FWCAL_C02 PRE-SIM GATE
