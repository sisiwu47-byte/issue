# V2.5-G2-R3 Targeted Quarantine Set-1 Startup Test

## Conclusion

**V2.5-G2-R3 TARGETED QUARANTINE SET-1 STARTUP TEST BLOCKED**

The single pre-registered Epfwk cache file was moved successfully and preserved byte-for-byte in the external quarantine. The one authorized MATLAB startup-only probe was then launched, but it did not complete within the observation window. Two MATLAB processes associated in time with that launch remained live. In accordance with the R3 hang stop rule, no process was terminated and no second probe was started.

This outcome does not establish whether quarantining SET-1 restores startup, and it does not establish whether the Epfwk cache file is or is not a root cause. Startup, Simulink-load, and `checkcode` markers remain unobserved because the launch wrapper could not persist its buffered output before the live MATLAB processes completed.

## Pre-move hard gates

| Gate | Evidence | Result |
|---|---|---|
| Live MATLAB process count | `0` | PASS |
| Process `MATLAB_PREFDIR` | UNSET | PASS |
| User `MATLAB_PREFDIR` | UNSET | PASS |
| Machine `MATLAB_PREFDIR` | UNSET | PASS |
| Exact quarantine root absent | `D:\SystemMigration\Temp\V25G2_R3_TARGETED_PREFDIR_QUARANTINE_SET1_20260829T012500Z` absent | PASS |
| Root outside active PREFDIR | YES | PASS |
| Exact destination absent | YES | PASS |
| Exact source present | YES | PASS |
| Source size | `437372` bytes | PASS |
| Source SHA-256 | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | PASS |
| Source creation time UTC | `2026-08-28T15:07:27.5356972Z` | PASS |
| Source last-write time UTC | `2026-08-28T16:29:15.0502175Z` | PASS |

## Exact quarantine move

Only candidate `Q04` in `R3_QUARANTINE_SET_1` was moved.

| Field | Value |
|---|---|
| Source | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\epfwk_cache-24.1.0.2537033-7203099541395556032.json` |
| Destination | `D:\SystemMigration\Temp\V25G2_R3_TARGETED_PREFDIR_QUARANTINE_SET1_20260829T012500Z\epfwk_cache-24.1.0.2537033-7203099541395556032.json` |
| Operation | MOVE |
| Move time UTC | `2026-08-29T02:06:18.0050651Z` |
| Source absent after move | YES |
| Destination present after move | YES |
| Destination size | `437372` bytes |
| Destination SHA-256 | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` |
| Other candidate files moved | NO |
| Directory moved | NO |

The first filesystem command attempt failed before creating the quarantine root because `New-Item` does not accept `-LiteralPath`. It caused no PREFDIR state transition and did not consume the MATLAB probe. The corrected command retained the exact pre-registered paths and MOVE semantics.

## One authorized startup-only probe

The probe authorization was consumed exactly once.

| Field | Evidence |
|---|---|
| Executable | `D:\matlab\bin\matlab.exe` |
| Mode | `-batch` |
| Working directory | `D:\UsersData\桌面\two` |
| `MATLAB_PREFDIR` override | NO |
| Project model loaded | NO |
| `sim()` called | NO |
| CarSim run | NO |
| First live PID | `15560`, start UTC `2026-08-29T02:07:24.0851557Z` |
| Second live PID | `30468`, start UTC `2026-08-29T02:07:24.1935521Z` |
| Observation UTC | `2026-08-29T02:08:45.1872664Z` |
| Live MATLAB count at observation | `2` |
| Process state | `Responding=True`, `HasExited=False` for both |
| Exit code | unavailable; processes still live |
| `MATLAB_STARTUP_OK` | UNOBSERVED |
| MATLAB version | UNOBSERVED |
| active `prefdir` | UNOBSERVED |
| Simulink license | UNOBSERVED |
| `SIMULINK_LOAD_OK` | UNOBSERVED |
| runner `checkcode` | UNOBSERVED |
| analyzer `checkcode` | UNOBSERVED |
| `errors_warnings` fatal | UNOBSERVED |
| `ApplicationService` fatal | UNOBSERVED |
| Probe result | BLOCKED — PROCESS STILL LIVE |

No force kill, `Stop-Process`, `taskkill`, signal injection, or second MATLAB launch was used. The two live processes must be closed normally by the user or process owner before any later PREFDIR or startup work.

## Regeneration state

At the hang observation time, the exact active-PREFDIR source path was still absent and the quarantined original remained present with the registered SHA-256. This is a provisional state observation only: because the MATLAB processes were still live, post-exit regeneration analysis was not performed and no causal interpretation is made.

The quarantined original was not restored. No additional cache or preference file was moved.

## Frozen and historical integrity

| Artifact | SHA-256 | Result |
|---|---|---|
| C01R1 immutable MAT | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` | MATCH |
| Fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | MATCH |
| Fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | MATCH |
| Fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | MATCH |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | MATCH |
| Frozen D-EKF target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | MATCH |
| Frozen K-KF target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | MATCH |
| Frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | MATCH |
| Frozen F-track target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | MATCH |
| Frozen F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | MATCH |
| Active `simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | MATCH |
| G1B recovery runtime MAT | `030CE3FDE238641D046D9DC9DABF07AFE75BB00F38CB12E0181F6755C4A7CC12` | MATCH |
| G1B recovery status | `4C3EA774732CDB163B32BC39A7AE93D1BE38F922C69E7BD8DBC557EBB2CAA6C7` | MATCH |
| R2 candidates | `00E9E636B1F44860078253C9A2DF4E9790ACB9206855A21BEA8C1DC0160E0908` | MATCH |
| R2 semantic diff | `BD868F573A89553C65470B847A6E0FB9DE69E0D7608B2A8C31592246D1E2B16E` | MATCH |
| R3 action plan | `98EC35395D7F82A15D796E55EB0FBDAC355BDC3572D1B49D5EA200B80198421C` | MATCH |
| R2 status | `A0184738FC0F3F8642C24A31308CC1C1A1F558A79C54EA6E1BF1D33B18AD24F1` | MATCH |

No model, estimator core/wrapper, `simfile.sim`, calibration registry, runtime MAT, or historical R1/R2 evidence was modified.

## Authorization state and stop discipline

- `FWCAL_C02 sim()` count: `0`
- `FWCAL_C03 sim()` count: `0`
- `FWCAL_C04 sim()` count: `0`
- `FWCAL_C05 sim()` count: `0`
- C02-C05 runtime authorizations: **ALL UNCONSUMED**
- Holdout: UNTOUCHED
- `alpha_D / alpha_K / alpha_F`: UNSELECTED
- Second MATLAB probe: NOT EXECUTED
- Additional PREFDIR quarantine: NOT EXECUTED
- Automatic restore: NOT EXECUTED

## Final declarations

THE SINGLE-FILE SET-1 QUARANTINE DID NOT PRODUCE A COMPLETED STARTUP PROBE.

PROCESS STILL LIVE.

NO SECOND STARTUP PROBE WAS EXECUTED.

NO ADDITIONAL PREFDIR FILE WAS MOVED.

THE ORIGINAL FILE REMAINS PRESERVED IN THE EXTERNAL QUARANTINE.

NO CALIBRATION RUNTIME WAS EXECUTED.

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

The live MATLAB processes must be closed normally before any next-stage action. No force termination is authorized.

READY FOR NEXT MINIMAL CANDIDATE-SET FORENSIC DESIGN
