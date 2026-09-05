# V2.5-G2-R1 Recurring MATLAB Settings/PREFDIR Differential Forensic

## Conclusion

**RECURRENT PREFDIR/SETTINGS-STATE CORRUPTION EVIDENCE FOUND**

Conservative classification: **CLASS A**.

The active R4 fresh default PREFDIR acquired a large regenerated state after its initial successful startup. Most importantly, three preference JSON files changed after the successful G1D runtime and became byte-for-byte identical to the corresponding files in the preserved old-bad PREFDIR. The same time window also contains rewrites of the Epfwk cache and Simulink toolstrip plugin preferences. This is high-value recurrence evidence inside the active PREFDIR.

This evidence does not prove which individual file causes the `errors_warnings` plugin startup failure. No file with `errors_warnings` or `ApplicationService` in its path or readable text was found in the active PREFDIR, and all inspected JSON/XML was syntactically valid.

## 1. Process gate

- PID 19452 was no longer returned by `GetProcessById`.
- Live MATLAB process count: `0`.
- No MATLAB process was started in R1.
- No process was terminated.

## 2. Exact PREFDIR paths

| Role | Path | Exists |
|---|---|---|
| R4 fresh default / current active PREFDIR | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` | YES |
| Preserved old-bad backup | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a_V25G1B_BAD_BACKUP_20260828T150506Z` | YES |
| R2 diagnostic PREFDIR | `D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR` | not used or modified |

The paths were obtained from the immutable R4 status and evidence rather than inferred from memory.

## 3. R4 baseline versus current inventory

R4 baseline contained 12 regular files. Current recursive inventory contains 5,915 files and 803 root/directory entries.

| Exclusive diff category | Count |
|---|---:|
| `ADDED` | `6704` |
| `DELETED` | `0` |
| `HASH_CHANGED` | `5` |
| `SIZE_CHANGED` | `0` |
| `MTIME_CHANGED_ONLY` | `3` |
| `UNCHANGED` | `6` |
| `TYPE_CHANGED` | `0` |

`SIZE_CHANGED=0` is the exclusive category count. One hash-changed file, the Epfwk cache, also changed size from 300,994 to 437,372 bytes and is classified under the higher-priority `HASH_CHANGED` category.

The five hash-changed files are:

| Relative path | Current SHA-256 | Current mtime UTC | JSON status | Same hash as old-bad |
|---|---|---|---|---|
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | `2026-08-28T16:29:15.0502175Z` | VALID_JSON | NO |
| `sdiprefs.json` | `EB485EE54583EA75D584A39D891AD5C04F3FBB26BAD6ACCF63DD74C98DAC577A` | `2026-08-28T16:29:14.1447975Z` | VALID_JSON | **YES** |
| `signalanalyzerprefs.json` | `2EBFC3EE9BF28C19EC831717165349005FA7243221AC600E400A7F525AEB2774` | `2026-08-28T16:29:14.1457968Z` | VALID_JSON | **YES** |
| `sl_toolstrip_plugins\preferences.json` | `7F25F8AEDF8F2DCDAA3B3A991E771E7F5D388AB29F290EC106A16639575F9924` | `2026-08-28T16:29:14.8795334Z` | VALID_JSON | NO |
| `stmprefs.json` | `61B981FF08C45EB36C98F4EDA5D5921C909F081BFCDFAFCC545FC975B4483AC4` | `2026-08-28T16:29:14.1471007Z` | VALID_JSON | **YES** |

## 4. Current versus old-bad cross-match

- Current files with the same relative path and same SHA-256 as old-bad: `5898`.
- Breakdown:
  - newly added since the R4 baseline: `5893`;
  - hash-changed since R4 baseline: `3`;
  - unchanged since R4 baseline: `2`.
- The three changed preference files highlighted above satisfy:
  - same relative path as old-bad;
  - same SHA-256 as old-bad;
  - changed from the R4 fresh baseline;
  - settings/preferences relevance.

They are therefore recorded as **HIGH-VALUE RECURRENCE EVIDENCE**. “Same hash” demonstrates byte identity; it does not by itself prove whether MATLAB copied the old file or deterministically regenerated identical content.

## 5. Timeline

| Event | Time UTC | Time +08:00 |
|---|---|---|
| R4 fresh PREFDIR generation | `2026-08-28T15:07:00.9599963Z` | `2026-08-28 23:07:00.9599963` |
| G1B 0.20-s diagnostic MAT saved | `2026-08-28T15:27:39.7319108Z` | `2026-08-28 23:27:39.7319108` |
| G1D C01R1 immutable MAT saved | `2026-08-28T16:26:51.7763391Z` | `2026-08-29 00:26:51.7763391` |
| Preference/Epfwk/plugin rewrites | `2026-08-28T16:29:14.1447975Z`–`16:29:15.0502175Z` | `2026-08-29 00:29:14`–`00:29:15` |
| First G2 failed-start process start | `2026-08-28T17:28:59.4196517Z` | `2026-08-29 01:28:59.4196517` |
| G2-R0 recurrent failed-start process start | `2026-08-29T01:04:20.5978730Z` | `2026-08-29 09:04:20.5978730` |

The five key preference/cache/plugin files were rewritten approximately 2 minutes 22 seconds after the successful G1D MAT save and approximately 59 minutes 44 seconds before the first G2 startup failure.

For all PREFDIR differences, mtime-window counts were:

- R4 generation to G1B success: `6693`;
- G1B success to G1D success: `7`;
- G1D success to first G2 failure: `12`;
- first G2 failure to R0 failure: `0`;
- after R0 failure at inventory time: `0`.

## 6. JSON/XML and targeted settings inspection

- Current PREFDIR JSON parsed: `6`, invalid: `0`.
- Current PREFDIR XML parsed: `399`, invalid: `0`.
- External-cache targeted JSON/XML invalid count: `0`.
- The Epfwk cache is valid JSON with top-level properties `entries`, `packageUris`, and `version`.
- The Epfwk cache contains `settings` and `plugin` metadata but no readable `errors_warnings` or `ApplicationService` token.
- No readable JSON/XML/TXT/LOG/PRF file in the current PREFDIR matched `errors_warnings` or `ApplicationService`.

Therefore no malformed JSON/XML was identified, and the exact failing plugin artifact remains unidentified.

## 7. External cache audit

The bounded read-only external inventory includes:

- `%LOCALAPPDATA%\MathWorks` to depth 4;
- `%APPDATA%\MathWorks` outside the active and preserved PREFDIR trees to depth 3;
- MATLAB/MathWorks-related top-level `%TEMP%` entries;
- four targeted installation settings/ApplicationService artifacts.

No external cache/settings entry in this bounded inventory had an mtime between the successful G1D MAT save and the G2-R0 failure. No malformed external JSON/XML was found. This provides no strong CLASS B evidence.

Windows Application Event Log inspection for the two failure windows returned no MATLAB, MathWorks, ApplicationService, `errors_warnings`, Application Error, or Windows Error Reporting event.

## 8. Launch-command differential

| Property | G1D success | G2 first failure | G2-R0 failure |
|---|---|---|---|
| Executable | `D:\matlab\bin\matlab.exe` | same | same |
| Launch mode | `-batch` | `-batch` | `-batch` |
| Initial working directory | `D:\UsersData\桌面\two` | same | same |
| `-r` / `-sd` | none | none | none |
| `-nosplash` / `-nodesktop` / `-nojvm` | none | none | none |
| `singleCompThread` | none | none | none |
| `MATLAB_PREFDIR` | UNSET | UNSET | UNSET |
| Batch payload reached | YES | NO | NO |

The G2 payloads differed from G1D because they requested static/startup diagnostics instead of the runtime runner. Both failures occurred before their first MATLAB statement, so this downstream payload difference cannot explain the startup plugin failure.

The complete G1D shell command was not persisted verbatim in project evidence; executable, `-batch` mode, working directory, and PREFDIR policy are independently established. No material startup executable or flag difference was found. CLASS C is not supported by current evidence.

## 9. Current environment

| Variable/scope | Current value |
|---|---|
| Process `MATLAB_PREFDIR` | UNSET |
| User `MATLAB_PREFDIR` | UNSET |
| Machine `MATLAB_PREFDIR` | UNSET |
| `TEMP` | `D:\SystemMigration\Temp` |
| `TMP` | `D:\SystemMigration\Temp` |
| `APPDATA` | `C:\Users\21180\AppData\Roaming` |
| `LOCALAPPDATA` | `C:\Users\21180\AppData\Local` |
| `USERPROFILE` | `C:\Users\21180` |
| MATLAB/CarSim-related PATH entries | `D:\matlab\runtime\win64`; `D:\matlab\bin` |

No environment variable was modified.

## 10. Installation-target integrity

| Installation artifact | Size | SHA-256 | Readable |
|---|---:|---|---|
| `D:\matlab\bin\win64\app_service_host\jsd\services_host\mwApplicationService.dll` | `561000` | `081BA4FCBA835A91401837B8A01E41CEAC4B4C7413FB8580FAABA90C76EF04FD` | YES |
| `D:\matlab\bin\win64\cppms_cache_manifests\mwApplicationService.bpf` | `133` | `F0D95CEE38ABDFD991ECC2E58540AC96722ECD9F67B366CE8D6C0C7860B6A5F9` | YES |
| `D:\matlab\bin\win64\settings_plugins\settings\security_impl\mwsecurity_impl.dll` | `126312` | `E50E798D7DBE74A95515D0046BA4F0A87136391B45270E22B62A1297FAA9078B` | YES |
| `D:\matlab\bin\win64\connector_plugins\settings\settings_request_response\libmwsettings_request_response.dll` | `769384` | `6C54799336E16261225B8E29FAE3B0716B4E2EB7C5DF8ACCD52A70FC80233B3A` | YES |

All targeted installation files exist, are nonzero, readable, and retain installation-era mtimes. No earlier file-specific hash baseline was available, so this establishes current readability/integrity but not cryptographic non-change from a prior R1 snapshot. No CLASS D installation anomaly was found.

## 11. Locked project evidence

- C01R1 immutable MAT SHA-256 remains `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`.
- Frozen target/core, simfile, original V2.5-F registries, G1C remediation registry, and G1B/R4 evidence were not modified.
- No C02-C05 runner was executed.
- C02/C03/C04/C05 `sim()` counts remain `0`.
- All four C02-C05 runtime authorizations remain `UNCONSUMED`.
- Holdout remains untouched.
- `alpha_D / alpha_K / alpha_F` remain `UNSELECTED`.

## 12. Required answers

1. R4 fresh to current: added `6704`, deleted `0`, hash-changed `5`.
2. Most suspicious files: `sdiprefs.json`, `signalanalyzerprefs.json`, `stmprefs.json`, followed by the concurrently rewritten Epfwk cache and `sl_toolstrip_plugins\preferences.json`.
3. Yes. Current/old-bad same-path same-hash files: `5898`; three changed preference JSON files are high-value recurrence evidence.
4. No malformed inspected JSON/XML was found.
5. No decisive outside-PREFDIR cache anomaly was found in the bounded targeted audit.
6. No material executable, `-batch`, working-directory, PREFDIR, or startup-flag difference was found between G1D and the failed probes. Payload differed but was never reached in the failures.
7. Targeted installation files exist, are nonzero and readable; no installation-level anomaly was evidenced.
8. Classification: **CLASS A — RECURRENT PREFDIR/SETTINGS-STATE CORRUPTION EVIDENCE FOUND**.
9. Yes. A separate **TARGETED QUARANTINE/REGENERATION PLAN** is needed before another MATLAB start. R1 performs no quarantine or regeneration.
10. C02-C05 authorizations remain **ALL UNCONSUMED**.

## Evidence files

- `results/vy_fixed_fusion_v2_5g2_r1_current_prefdir_inventory.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_prefdir_diff.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_prefdir_timeline.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_current_vs_oldbad.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_external_cache_inventory.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_launch_command_diff.csv`
- `results/vy_fixed_fusion_v2_5g2_r1_event_log_summary.csv`

## Stop state

No remediation, MATLAB startup, simulation, CarSim runtime, calibration acquisition, holdout access, or alpha calculation was performed.
