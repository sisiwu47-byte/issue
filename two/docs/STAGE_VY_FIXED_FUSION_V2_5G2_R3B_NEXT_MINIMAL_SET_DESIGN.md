# V2.5-G2-R3B Next Minimal Candidate-Set Design

## Conclusion

**V2.5-G2-R3B NEXT MINIMAL CANDIDATE-SET DESIGN ACCEPTED**

`R3B_SET_2` is frozen as one exact file:

```text
ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa
```

R3B performed read-only evidence analysis only. No PREFDIR file was moved, modified, deleted, restored, or cleaned. No MATLAB process was started.

## Q04 four-version availability

| Version | Availability | SHA-256 | Size | JSON validity |
|---|---|---|---:|---|
| R4 healthy baseline | metadata only; content not archived | `8B44E7543CC83B3F80847D7ED848101C5F8A3D5AFC4FA83FC1FE445038679FCA` | 300994 | UNAVAILABLE |
| quarantined pre-R3 | complete | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | 437372 | VALID |
| regenerated post-R3 | complete | `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8` | 437372 | VALID |
| old-bad backup | complete | `50FC4DDD1691C3E00FE0B52291465AB50F77B96E0F66BC7433566746A2F9CEBB` | 445922 | VALID |

The R4 healthy inventory proves the original healthy file hash and size but did not archive the JSON contents. Therefore `regenerated versus healthy` field-level comparison is **MISSING_CONTENT / UNAVAILABLE**, not inferred from file hashes.

Available recursive comparisons:

| Pair | Field-level difference count | Union leaf count |
|---|---:|---:|
| regenerated vs quarantined pre-R3 | 1861 | 4234 |
| regenerated vs old-bad | 2530 | 4413 |
| quarantined pre-R3 vs old-bad | 2522 | 4413 |
| regenerated vs R4 healthy | UNAVAILABLE | healthy content not archived |

Among the 4234 regenerated leaves:

- 1883 equal both quarantined and old-bad;
- 490 equal quarantined only;
- 0 equal old-bad only;
- 1861 are unique regenerated values relative to both available comparison versions.

Consequently, regenerated Q04 is **MIXED / DISTINCT**, and among available complete versions is structurally closer to `QUARANTINED_PRE_R3` than to `OLD_BAD`. It cannot be classified relative to `HEALTHY_BASELINE` at field level.

## Q04 high-value semantics

Semantic categories were derived from field paths and redacted scalar-keyword classification. Raw sensitive values were not written.

Findings:

- no regenerated leaf matched old-bad only;
- version semantics remained common to quarantined and old-bad;
- plugin/toolstrip, settings/provider/service, registration/dependency, path/cache, and error/warning related leaves were either retained from quarantined pre-R3 or regenerated to values distinct from both complete comparison versions;
- no `ApplicationService`-specific leaf was identified;
- the single error/warning-related leaf matched quarantined pre-R3 only;
- high-value plugin/settings paths do not demonstrate a return to old-bad state;
- healthy restoration cannot be claimed because healthy JSON content is missing.

This evidence does not justify a second identical Q04-only quarantine test.

## Exact R3 probe HASH_CHANGED files

The two records were obtained programmatically from the R3A PREFDIR diff:

| Relative path | Pre-probe SHA-256 | Post-probe SHA-256 | Size | Post mtime UTC | Type/validity |
|---|---|---|---:|---|---|
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B` | `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8` | 437372 before / 437372 after | `2026-08-29T02:10:29.1203790Z` | JSON / VALID |
| `sl_toolstrip_plugins\preferences.json` | `7F25F8AEDF8F2DCDAA3B3A991E771E7F5D388AB29F290EC106A16639575F9924` | `15D7EAC297022574C4EA48F86CECB479CD7402190E1DC65F9D9D5B0EF276A68E` | 193 before / 193 after | `2026-08-29T02:09:57.6759639Z` | JSON / VALID |

Absolute paths are under:

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
```

## Toolstrip preference finding

`sl_toolstrip_plugins\preferences.json` has the strongest direct plugin/toolstrip filename semantics, but its actual content evidence remains low-value:

- five post-R3 leaves were inspected;
- entry type, Toolstrip content, package URI, and version equal old-bad;
- package URI and version also equal the R2 pre-probe version;
- only `entries[0].uuid` changed from both pre-probe and old-bad;
- post-R3, pre-probe, old-bad, and healthy metadata hashes are all distinct, but healthy content was not archived.

The probe-window hash change is therefore attributable to UUID churn, not a demonstrated plugin enable/disable, provider, package URI, or version change. Q05 is not selected.

## Original application preference candidates

`sdiprefs.json`, `signalanalyzerprefs.json`, and `stmprefs.json` remained byte-identical during R3. Only their mtimes changed. R2 semantic evidence still classifies them as UI/session/plot/comparison preferences, without a direct startup provider or ApplicationService field. They remain LOW priority.

## New upstream/companion candidate

Exact file:

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a\ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa
```

Evidence:

- added during R3 at `2026-08-29T02:10:12.4689214Z`;
- appeared about 17 seconds before Q04 regeneration;
- exact filename explicitly refers to Simulink performance startup;
- size: `1024` bytes;
- current SHA-256: `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E`;
- path absent from the R4 healthy baseline inventory;
- same path exists in the preserved old-bad backup;
- current hash equals old-bad hash exactly;
- binary/signed `.jsonrsa` artifact: no fabricated JSON field interpretation was attempted.

This file has the strongest combined temporal, healthy-divergence, old-bad-recurrence, startup-semantic, regeneration, minimality, and reversibility evidence. Its direct plugin/settings semantic relevance is lower than Q05, but its causal test value is higher.

## Candidate scoring summary

Qualitative dimensions:

- `T`: probe-window temporal relevance;
- `H`: healthy-baseline divergence;
- `O`: old-bad similarity;
- `S`: startup/plugin/settings semantic relevance;
- `R`: regeneration behavior relevance;
- `M`: minimality and reversibility.

| Candidate | T | H | O | S | R | M | Overall | SET-2 |
|---|---|---|---|---|---|---|---|---|
| Q01 `sdiprefs.json` | MEDIUM | HIGH | HIGH | LOW | LOW | HIGH | LOW | NO |
| Q02 `signalanalyzerprefs.json` | MEDIUM | HIGH | HIGH | LOW | LOW | HIGH | LOW | NO |
| Q03 `stmprefs.json` | MEDIUM | HIGH | HIGH | LOW | LOW | HIGH | LOW | NO |
| Q04 regenerated Epfwk cache | HIGH | HIGH | LOW | HIGH | HIGH | HIGH | HIGH / DEFERRED | NO |
| Q05 toolstrip preference | HIGH | HIGH | MEDIUM | HIGH | HIGH | HIGH | MEDIUM | NO |
| Q06 startup-performance schema | HIGH | HIGH | HIGH | MEDIUM | HIGH | HIGH | HIGH | **YES** |

## Frozen R3B_SET_2

`R3B_SET_2` contains exactly one file:

| Order | Relative path | Expected current SHA-256 | Size |
|---:|---|---|---:|
| 1 | `ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa` | `30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E` | 1024 |

Why this is minimal:

- one exact file, not a directory;
- introduces one new causal variable;
- does not repeat SET-1 Q04;
- does not combine the low-value Q05 UUID churn with Q06;
- reversible by an externally verified MOVE;
- no evidence shows that Q06 and another file form an inseparable transaction.

## Future R4 execution constraints

A future separately authorized R4 may:

1. require live MATLAB count `0`;
2. verify the exact Q06 source path, size, and SHA-256;
3. create a new unique quarantine root outside active PREFDIR;
4. MOVE this one file only;
5. verify source absent and destination hash exact;
6. execute one and only one startup-only probe;
7. record regeneration and outcome.

It may not delete, restore, clean, move Q04/Q05/app preferences, run `sim()`, run CarSim, or consume C02-C05 authorization.

## Authorization and integrity state

- SET-2 execution: NOT STARTED;
- PREFDIR files moved or modified in R3B: `0`;
- MATLAB processes started in R3B: `0`;
- simulations: `0`;
- CarSim runs: `0`;
- FWCAL_C02/C03/C04/C05 runtime MAT count: `0`;
- FWCAL_C02-C05 authorizations: **ALL UNCONSUMED**;
- holdout: UNTOUCHED;
- alpha: UNSELECTED;
- quarantined original Q04: preserved with SHA-256 `95464B5EEE5B786BB6A910F2765B15DB11A79644DC0F7F12BC6724149E8AE65B`;
- regenerated active Q04: preserved with SHA-256 `9862F10507A234973F285D7788DE4E8618BB7952A449D707FF3A2345CDC674C8`.

## Final declarations

R3B_SET_2 IS EVIDENCE-SELECTED AND MINIMAL.

NO FILE WAS MOVED OR MODIFIED IN R3B.

NO MATLAB PROCESS WAS STARTED.

NO CALIBRATION RUNTIME WAS EXECUTED.

FWCAL_C02-C05 RUNTIME AUTHORIZATIONS REMAIN UNCONSUMED.

READY FOR V2.5-G2-R4 TARGETED QUARANTINE SET-2 STARTUP TEST
