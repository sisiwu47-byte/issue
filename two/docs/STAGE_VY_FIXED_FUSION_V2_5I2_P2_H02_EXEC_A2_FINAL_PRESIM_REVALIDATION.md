# V2.5-I2-P2 H02 A2 Final Formal Runtime Pre-Sim Revalidation

## Conclusion

**V2.5-I2-P2 H02 A2 FINAL FORMAL RUNTIME PRE-SIM REVALIDATION PASSED**

- Statistical run ID: `FWHOLD_H02`
- Execution attempt ID: `FWHOLD_H02_EXEC_A2`
- Role: `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`
- Condition: `0.035 rad / 0.35 Hz / 16 s / 100 Hz`
- Final gates: `52/52 PASS`
- H02 authorization: `UNCONSUMED`
- H03: `UNRUN / UNVIEWED / UNCONSUMED`

## Immutable history and remediation lineage

A1 remains immutable as a closed pre-commit infrastructure failure. Its last durable phase is `PROJECT_CD_OK`; the phase evidence remains 166 bytes with SHA-256 `F4EC95718EA83D5689B8A395AF377F42BAFDE24FBBAF54060AB906684243C521` and mtime `2026-08-30T06:47:26.5499120+08:00`.

P1 remains historically blocked at `47/48 PASS`, with `A2 launcher authorized = FALSE` and blocker `ANALYZER_A1_PHASE_PATH_REFERENCE`. Its four evidence files were not modified.

R2 repaired only the analyzer's A2 phase-lineage binding. The R2 gate evidence remains `34/34 PASS`. Bootstrap, runner, and analyzer now share the exact phase path `results/vy_fixed_fusion_v2_5i2_H02_exec_a2_phase_markers.csv`; the active analyzer contains zero active references to the historical A1 phase path.

## Frozen active execution chain

| Artifact | SHA-256 |
|---|---|
| Runner | `92FCB9C866DE819E32FD4309C8EDAC9219E69C203FD5AA824765AC0EF9D853D6` |
| Analyzer | `317625E45EA95CF1714A6037EA086F6ADED8DCD5918C4005C8261804A95F5DBA` |
| A2 bootstrap | `834DB18FC49F9F88CDB2179AD5A5CF544854B2F9CA0889602A2001FE7B1C1B89` |
| A2 launcher | `383DCEC3FE13DDF6FC64F035DDE7DB08E6B392B6F8180A03D0B6A8E6450686DF` |
| Formal target | `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` |
| Fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` |
| Fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` |

The runner self-hash uses the explicit `.m` path, verifies that file with `isfile`, and retains the common SHA-256 helper. The analyzer's metrics, eligibility, truth alignment, evaluation window, condition, weights, and aggregate scope are unchanged.

## Frozen condition and weights

The immutable preregistry SHA-256 is `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`. Its unique execution-order-2 row defines `FWHOLD_H02`, `0.035 rad`, `0.35 Hz`, `16 s`, `100 Hz`, `SINE_FRONT_EQUAL_REAR_ZERO`, `FL_FR_SAME_PHASE`, `RL_RR_ZERO`, the verified approximately-20-m/s speed class, frozen truth alignment, `[0_16]` evaluation window, formal result path, target hash, and fixed weights.

The frozen weight set is `V25_FIXED_WEIGHT_ALPHA_V1`: `alpha_D=0.9004680917645591`, `alpha_K=0.09953190823544089`, `alpha_F=0`, sum `1`. There is no QP, retuning, adaptive weighting, condition-specific alpha, or holdout-derived normalization in the A2 chain.

## Environment and authorization boundary

- Live MATLAB processes: `0`
- Process/User/Machine `MATLAB_PREFDIR`: `UNSET / UNSET / UNSET`
- Active SET-2 file: `ABSENT`
- A2 launcher invocation count: `0`
- A2 phase marker: `ABSENT`
- `SIM_AUTHORIZATION_COMMITTED`: `ABSENT`
- Formal H02 MAT and all runtime-only H02 outputs: `ABSENT`
- CarSim project, D-drive `PROGDIR`, D-drive `DATADIR`, and solver paths: present; project `simfile.sim` has the audited D-drive lineage and the runner enforces G request `NO`.

The frozen runner has one executable `sim()` call, no retry/fallback, and no sim-before-commit path. It performs runner/target/weight/preregistry/result/CarSim/cwd/condition/H03 checks before writing the unique commit, then closes it, verifies persistence and size, reads it back, validates exact identity/hash/weights, writes the durable `SIM_AUTHORIZATION_COMMITTED` phase, and only then reaches the unique `sim()` call.

No MATLAB, Simulink, CarSim, launcher, bootstrap, runtime marker, authorization commit, performance calculation, model modification, alpha modification, or preregistry modification occurred in P2.

## Frozen decision

All final static, environmental, lineage, output-lifecycle, and authorization-boundary gates passed. The original three-holdout primary aggregate remains `INCOMPLETE_DUE_TO_MISSING_H01_FORMAL_DATA`; H02 remains partial diagnostic evidence and does not authorize `rho_holdout` or `PARTIAL23` calculation.

There will be no further static pre-sim stage after this P2 pass. The next stage is permitted to execute the frozen A2 ASCII launcher exactly once. Once the durable `SIM_AUTHORIZATION_COMMITTED` record is written and verified during that runtime, H02 authorization becomes permanently `CONSUMED` regardless of the subsequent runtime outcome.

**READY FOR V2.5-I2 H02 EXEC_A2 FIRST-AND-ONLY FORMAL RUNTIME**
