# V2.5-G2-R2 Targeted Quarantine / Regeneration Plan

## Conclusion

**V2.5-G2-R2 TARGETED QUARANTINE / REGENERATION PLAN ACCEPTED**

`R3_QUARANTINE_SET_1` is frozen as one exact Epfwk cache file. R2 performed semantic inspection and planning only: no PREFDIR file was created, modified, moved, renamed, deleted, or restored, and no MATLAB process was started.

## Evidence limitation

The R4 baseline inventory preserved per-file hashes and metadata but did not archive copies of the baseline JSON contents. Consequently:

- file-level baseline/current change is proven by SHA-256;
- CURRENT versus preserved OLD-BAD field-level comparison is complete;
- baseline versus current key-level values cannot be reconstructed and are explicitly recorded as `BASELINE_CONTENT_NOT_ARCHIVED`.

The exact root-cause file remains unproven.

## Candidate semantic assessment

| ID | Exact relative path | Current / baseline / old-bad relationship | Current-vs-old-bad changed keys | Semantic finding | Priority | SET-1 |
|---|---|---|---:|---|---|---|
| Q01 | `sdiprefs.json` | current equals old-bad; differs from baseline hash | `0` | comparisons, runs, colors, plots, layout and display preferences; likely benign UI/session regeneration | LOW | NO |
| Q02 | `signalanalyzerprefs.json` | current equals old-bad; differs from baseline hash | `0` | analyzer, plot and table preferences; likely benign UI/session regeneration | LOW | NO |
| Q03 | `stmprefs.json` | current equals old-bad; differs from baseline hash | `0` | comparisons, runs, colors, plots, layout and display preferences; likely benign UI/session regeneration | LOW | NO |
| Q04 | `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | differs from both baseline and old-bad | `2522` | plugin/framework location cache with entries, package URIs, UUIDs, registration keys and values | HIGH | **YES** |
| Q05 | `sl_toolstrip_plugins\preferences.json` | differs from both baseline and old-bad | `1` | plugin metadata exists, but the only current-vs-old-bad field difference is `entries[0].uuid`; package URI and version are unchanged | MEDIUM | NO |

All five JSON files are syntactically valid. Value evidence is recorded as type/length/hash summaries; path-, user-, machine-, session-, identifier-, URI-, token- and credential-like values are redacted.

## App preference findings

The current structures of `sdiprefs.json`, `signalanalyzerprefs.json`, and `stmprefs.json` are dominated by:

- comparison alignment/options;
- run and plot preferences;
- display colors, layouts, rows and columns;
- analyzer/table presentation state.

No direct settings-provider, ApplicationService, startup-component or plugin-registration field was identified in these three candidates. Their current contents equal old-bad byte-for-byte, but that alone does not prove corruption. They are classified `LIKELY_BENIGN_PREFERENCE_REGENERATION` and are excluded from SET-1.

Because the R4 baseline content was not archived, this classification is structural and conservative rather than a complete baseline field-diff proof.

## Epfwk cache finding

Exact current file:

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\epfwk_cache-24.1.0.2537033-7203099541395556032.json
```

Evidence:

- SHA-256: `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B`;
- R4 baseline SHA-256: `8B44E7543CC83B3F80847D7ED848101C5F8A3D5AFC4FA83FC1FE445038679FCA`;
- old-bad SHA-256: `50FC4DDD1691C3E00FE0B52291465AB50F77B96E0F66BC7433566746A2F9CEBB`;
- size: `437372 bytes`;
- creation time UTC: `2026-08-28T15:07:27.5356972Z`;
- last-write time UTC: `2026-08-28T16:29:15.0502175Z`;
- rewritten after G1D success and before the first G2 failure;
- valid JSON;
- top-level fields include `entries`, `packageUris`, and `version`;
- recursive semantics include `locationCache`, entry UUIDs, registration keys and value arrays;
- current versus old-bad changed leaf count: `2522`.

This is the highest semantic and temporal candidate and is a single cache artifact expected to be regenerable. It is therefore the sole member of SET-1.

## Toolstrip preference finding

`sl_toolstrip_plugins\preferences.json` is plugin-relevant and was rewritten in the same time window, but:

- current versus old-bad changed leaf count is only `1`;
- that leaf is `entries[0].uuid`;
- `packageUris[0]` and `version` are unchanged between current and old-bad.

It remains a second-tier candidate. It is not included in SET-1 so that the first experiment remains single-file and causally interpretable.

## Frozen R3_QUARANTINE_SET_1

| Order | Exact source | Expected SHA-256 | Planned destination |
|---:|---|---|---|
| 1 | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\epfwk_cache-24.1.0.2537033-7203099541395556032.json` | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | `D:\SystemMigration\Temp\V25G2_R3_TARGETED_PREFDIR_QUARANTINE_SET1_20260829T012500Z\epfwk_cache-24.1.0.2537033-7203099541395556032.json` |

The planned quarantine root is outside the active PREFDIR, outside the R2 diagnostic PREFDIR, and outside the preserved old-bad backup. It did not exist during R2 and was not created.

SET-1 is a minimal causal test set. Selection does not declare the Epfwk cache corrupt.

## Future R3 move protocol

R3 may execute the following only with explicit authorization:

1. Confirm live MATLAB process count is `0`.
2. Confirm Process/User/Machine `MATLAB_PREFDIR` are all UNSET.
3. Confirm the exact source exists and its SHA-256, size, ctime and mtime match the frozen action plan.
4. Confirm the planned quarantine root and destination do not exist.
5. Create the unique external quarantine root.
6. Move/rename the one exact file to the exact destination; do not delete it.
7. Verify source absent, destination present, and destination SHA-256 equals the original SHA-256.
8. Only after every move gate passes, consume the one authorized startup-only probe.

No wildcard, whole-PREFDIR operation, installation-file operation, old-bad restoration, or additional candidate is permitted in SET-1.

## Frozen R3 startup-only probe

R3 allows exactly one new MATLAB startup probe after the move gates pass:

```text
Executable: D:\matlab\bin\matlab.exe
Mode: -batch
MATLAB_PREFDIR Process/User/Machine: UNSET
Working directory: existing formal project working directory
```

Payload:

```matlab
disp('MATLAB_STARTUP_OK');
disp(version);
fprintf('ACTIVE_PREFDIR=%s\n',prefdir);
fprintf('SIMULINK_LICENSE=%d\n',license('test','Simulink'));
load_system('simulink');
disp('SIMULINK_LOAD_OK');
close_system('simulink',0);
```

Prohibited in the probe:

- `sim()`;
- CarSim;
- C02-C05 runner or analyzer execution;
- project model load;
- PREFDIR override;
- a second startup probe.

## R3 stop discipline

If the startup probe passes:

- stop before C02;
- record whether MATLAB regenerated the quarantined filename;
- record new hash, size, mtime and semantic differences;
- do not treat one PASS as complete root-cause proof;
- require a separate decision before any second startup or G2 resumption.

If the startup probe fails with the same plugin error:

- wait for the MATLAB process to exit normally;
- do not move a second candidate set;
- do not run another probe;
- return to a new planning stage.

## Frozen rollback protocol

Rollback is allowed only in a separately authorized action when live MATLAB count is `0`:

1. Verify the quarantine file still has the original SHA-256.
2. Verify the original active-PREFDIR target path does not exist.
3. Move the file back to the original exact relative path.
4. Verify restored SHA-256 equals the original SHA-256.

If MATLAB regenerated the target path, stop and audit both files. Never overwrite the regenerated target automatically.

## Deferred candidates

- Q01–Q03 remain untouched because their observable semantics are primarily normal UI/session preferences.
- Q05 remains untouched because only an entry UUID differs while its plugin package URI/version semantics are stable.
- No other one of the 5,898 same-hash files is included merely because it matches old-bad.

## Authorization state

- No MATLAB process was started in R2.
- No PREFDIR file was modified or moved.
- No quarantine directory was created.
- No simulation or CarSim runtime was performed.
- FWCAL_C02/C03/C04/C05 simulation counts remain `0`.
- FWCAL_C02-C05 runtime authorizations remain **ALL UNCONSUMED**.
- Holdout remains untouched.
- `alpha_D / alpha_K / alpha_F` remain `UNSELECTED`.

## Evidence files

- `results/vy_fixed_fusion_v2_5g2_r2_quarantine_candidates.csv`
- `results/vy_fixed_fusion_v2_5g2_r2_candidate_json_semantic_diff.csv`
- `results/vy_fixed_fusion_v2_5g2_r2_r3_quarantine_action_plan.csv`

## Final declarations

THE EXACT ROOT-CAUSE FILE IS NOT YET PROVEN.

R3_QUARANTINE_SET_1 IS A MINIMAL CAUSAL TEST SET, NOT A DECLARATION THAT EVERY FILE IN THE SET IS CORRUPT.

NO PREFDIR FILE WAS MODIFIED OR MOVED IN R2.

NO MATLAB PROCESS WAS STARTED.

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

READY FOR V2.5-G2-R3 TARGETED QUARANTINE SET-1 STARTUP TEST
