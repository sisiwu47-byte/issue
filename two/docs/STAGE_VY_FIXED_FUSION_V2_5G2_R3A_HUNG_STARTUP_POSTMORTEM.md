# V2.5-G2-R3A Hung Startup Probe Postmortem

## Conclusion

**R3 HUNG STARTUP POSTMORTEM INCONCLUSIVE**

Classification: **R3A-D**.

The R3 probe-related MATLAB processes are no longer live, but the evidence retained after their exit cannot recover their parent/child relationship, command lines, exit times, or exit codes. No stdout/stderr or batch log contains either the historical `errors_warnings` fatal marker or a batch payload marker. The active Epfwk cache was regenerated during the probe window, proving that startup-side preference/cache work progressed, but this does not prove healthy startup completion or a definite deadlock.

R3 remains classified `INCONCLUSIVE_HUNG_PROCESS`. It must not be reinterpreted as either SET-1 PASS or SET-1 DEFINITIVE FAIL.

## 1. Process snapshot and outcome

At `2026-08-29T02:26:17.3891074Z`:

- PID `15560`: not found as a live process; `HasExited=True` in the R3A snapshot representation.
- PID `30468`: not found as a live process; `HasExited=True` in the R3A snapshot representation.
- live MATLAB process count: `0`.

The R3 live evidence had previously identified both PIDs through `Get-Process -Name MATLAB` and recorded:

| PID | Start UTC | State at R3 observation |
|---:|---|---|
| 15560 | `2026-08-29T02:07:24.0851557Z` | `Responding=True`, `HasExited=False` |
| 30468 | `2026-08-29T02:07:24.1935521Z` | `Responding=True`, `HasExited=False` |

Both began in the same second as the single authorized probe and are therefore temporally associated with it. After exit, `Get-Process` and `Win32_Process` no longer exposed records for either PID. Consequently:

- exact executable path per PID: UNAVAILABLE;
- exact command line per PID: UNAVAILABLE;
- parent PID per process: UNAVAILABLE;
- exact relationship between PID 15560 and PID 30468: **UNRESOLVED**;
- exit timestamp: UNAVAILABLE;
- exit code: **EXIT_CODE_UNAVAILABLE**;
- normal versus abnormal exit: **UNDETERMINED**.

The launcher command is known to have invoked `D:\matlab\bin\matlab.exe -batch`, but the retained evidence cannot bind that executable or its parent/child role to one exact PID. No relationship is inferred merely from the two-PID count or their start order.

## 2. Probe stdout/stderr and payload reachability

The R3 launcher buffered the child output until completion. It did not write a separate stdout, stderr, batch, or temporary capture file before the control wrapper stopped returning output. Targeted checks found no MATLAB crash dump, Java fatal log, batch log, or WER report in the probe window.

| Evidence item | Result |
|---|---|
| exact first meaningful error line | UNAVAILABLE |
| last emitted line | UNAVAILABLE |
| `failed to load settings errors_warnings plugin` | NOT OBSERVED; absence is not proof it did not occur |
| `ApplicationService` fatal marker | NOT OBSERVED |
| `MATLAB_STARTUP_OK` | UNOBSERVED |
| MATLAB version marker | UNOBSERVED |
| active `prefdir` marker | UNOBSERVED |
| Simulink license marker | UNOBSERVED |
| `SIMULINK_LOAD_OK` | UNOBSERVED |
| runner `checkcode` marker | UNOBSERVED |
| analyzer `checkcode` marker | UNOBSERVED |
| payload reached | CANNOT BE PROVEN |

No payload was re-executed and no second MATLAB process was started by R3A.

## 3. Q04 regeneration

The quarantined original remains untouched:

| Field | Quarantined original | Regenerated active file |
|---|---|---|
| Exact filename | `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | same |
| SHA-256 | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8` |
| Size | `437372` bytes | `437372` bytes |
| Creation UTC | quarantine copy created `2026-08-29T02:06:18.0190302Z` | `2026-08-29T02:10:29.1145589Z` |
| Last-write UTC | preserved original mtime `2026-08-28T16:29:15.0502175Z` | `2026-08-29T02:10:29.1203790Z` |
| JSON syntax | VALID | VALID |
| Leaf count | 4234 | 4234 |

- same SHA-256: **NO**;
- same size: **YES**;
- field-level semantic difference count: **1861**;
- difference classes: 1861 `VALUE_CHANGED`, 0 added leaves, 0 removed leaves.

Values in the semantic-diff evidence are represented by type and SHA-256 only. The active regenerated file was not overwritten with the quarantined original.

## 4. Probe-window PREFDIR differential

The analysis window is bounded by:

- quarantine move: `2026-08-29T02:06:18.0050651Z`;
- probe process start: `2026-08-29T02:07:24.0851557Z` / `2026-08-29T02:07:24.1935521Z`;
- first observation proving both PIDs gone: `2026-08-29T02:26:17.3891074Z`.

Because exact exit timestamps are unavailable, the final timestamp is a conservative upper bound.

Eight files were added or changed relative to the R1 pre-probe active-PREFDIR inventory:

| Relative path | Classification | UTC change time | Evidence |
|---|---|---|---|
| `VisibleSettings.json` | MTIME_CHANGED | `2026-08-29T02:09:17.1488243Z` | hash unchanged, valid JSON |
| `sdiprefs.json` | MTIME_CHANGED | `2026-08-29T02:09:56.3033830Z` | hash unchanged, valid JSON |
| `signalanalyzerprefs.json` | MTIME_CHANGED | `2026-08-29T02:09:56.3048684Z` | hash unchanged, valid JSON |
| `stmprefs.json` | MTIME_CHANGED | `2026-08-29T02:09:56.3070259Z` | hash unchanged, valid JSON |
| `sl_toolstrip_plugins\preferences.json` | HASH_CHANGED | `2026-08-29T02:09:57.6759639Z` | new hash `15D7EAC297022574C4EA48F86CECB479CD7402190E1DC65F9D9D5B0EF276A68E`, valid JSON |
| `ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa` | ADDED | `2026-08-29T02:10:12.4689214Z` | 1024 bytes |
| `ddux\ac3` | MTIME_CHANGED | `2026-08-29T02:10:29.0688815Z` | hash unchanged |
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | HASH_CHANGED / REGENERATED | `2026-08-29T02:10:29.1203790Z` | new hash `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8`, valid JSON |

Summary:

- ADDED: `1`;
- HASH_CHANGED: `2`;
- MTIME_CHANGED with identical hash: `5`;
- zero-byte files: `0`;
- invalid JSON/XML files: `0`;
- lock-related files: `0`;
- journal-related files: `0`;
- temp/partial-write evidence: `0`.

These writes demonstrate delayed startup-side settings/cache activity. They do not show whether the batch payload ran.

## 5. Windows Event Log and crash evidence

Application and available WER logs were searched across the probe window. No MATLAB, MathWorks, `errors_warnings`, ApplicationService, Application Error, Application Hang, or Windows Error Reporting event relevant to the two PIDs was found.

- decisive Event Log record: **NONE_FOUND**;
- crash dump: NONE_FOUND;
- WER report archive entry: NONE_FOUND;
- temporary MATLAB/batch/error log: NONE_FOUND.

The absence of an event does not establish a normal exit.

## 6. Comparison with G2 / G2-R0

| Dimension | MODE A: G2 / G2-R0 | MODE B: R3 after Q04 quarantine |
|---|---|---|
| observed primary symptom | immediate `failed to load settings errors_warnings plugin` before batch payload | two MATLAB processes remained live after about 81 seconds; no captured marker |
| payload marker | not reached | unobserved |
| stdout/stderr | explicit settings-plugin failure | no retained output |
| process behavior | startup failure recorded | delayed activity followed by eventual disappearance; exit mode unknown |
| Q04 behavior | existing candidate cache | regenerated at about 185 seconds after process launch |
| other PREFDIR writes | historical R1 evidence | toolstrip hash changed, one DDUX artifact added, five mtimes updated |
| lock/journal/temp evidence | not controlling this classification | none found |
| event-log evidence | no decisive event in retained R1 evidence | none found |

The observable symptoms are not identical. However, because R3 has no retained stdout/stderr, payload marker, exit code, or decisive event, the evidence also cannot prove that the underlying failure mode changed. Classification R3A-C would require a clearly evidenced hang/deadlock-like state; `Responding=True`, later process disappearance, and absence of lock/journal evidence do not meet that bar.

## 7. Classification and next stage

**CLASS R3A-D — R3 HUNG STARTUP POSTMORTEM INCONCLUSIVE**

Answers required by the stage:

1. PID relationship: **UNRESOLVED**; no retained parent/child record.
2. Final exit: both are no longer live; normal versus abnormal exit is **UNDETERMINED**.
3. Exit code: **EXIT_CODE_UNAVAILABLE**.
4. Final `errors_warnings` evidence: NOT OBSERVED; stdout/stderr unavailable.
5. Batch payload reached: CANNOT BE PROVEN.
6. Active Q04 regenerated: YES.
7. Regenerated hash equals quarantined original: NO.
8. Key PREFDIR changes: eight files listed above.
9. Lock/journal/temp evidence: NONE_FOUND.
10. Decisive Event Log evidence: NONE_FOUND.
11. Same failure mode as G2/G2-R0: NOT PROVEN SAME AND NOT PROVEN DIFFERENT.
12. Classification: R3A-D.
13. Next stage: **NEXT MINIMAL CANDIDATE-SET DESIGN**, with the regenerated active Q04 state preserved and explicitly included in the design baseline.
14. C02-C05 authorizations: ALL UNCONSUMED.

No SET-2 file has been selected or authorized. No candidate file other than the already completed R3 SET-1 move was moved by R3A.

## 8. Runtime and frozen-evidence locks

- FWCAL_C02 runtime MAT count: `0`.
- FWCAL_C03 runtime MAT count: `0`.
- FWCAL_C04 runtime MAT count: `0`.
- FWCAL_C05 runtime MAT count: `0`.
- C02-C05 runtime authorizations: **ALL UNCONSUMED**.
- no MATLAB process was started in R3A;
- no `sim()` call;
- no CarSim run;
- no holdout run;
- no alpha calculation;
- no Q04 restore;
- no cache cleanup;
- no PREFDIR modification.

Frozen mismatch count is `0`. Verified hashes include:

| Artifact | SHA-256 |
|---|---|
| C01R1 immutable MAT | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` |
| Fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` |
| Fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` |
| Fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` |
| Frozen D-EKF target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| Frozen K-KF target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| Frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` |
| Frozen F-track target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` |
| Frozen F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| `model/simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` |
| R3 quarantined original Q04 | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` |

V2.5-F registries, G1C evidence, R1 evidence, R2 evidence, G1B recovery evidence, and the quarantine original remain present and were not modified by R3A.

## Final declaration

R3 HUNG STARTUP POSTMORTEM INCONCLUSIVE

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

READY FOR NEXT MINIMAL CANDIDATE-SET DESIGN
