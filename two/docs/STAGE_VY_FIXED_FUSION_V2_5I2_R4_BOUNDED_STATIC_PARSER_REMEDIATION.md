# V2.5-I2-R4 Bounded Static-Expression Parser Remediation and A3 Refreeze

## Conclusion

**V2.5-I2-R4 BOUNDED STATIC-EXPRESSION PARSER REMEDIATION & A3 EXECUTION-ENTRY REFREEZE PASSED**

- R3 root cause: `STATIC_PARAMETER_PARSE_DEFECT_PROVEN`
- Statistical run ID: `FWHOLD_H02`
- New execution attempt: `FWHOLD_H02_EXEC_A3`
- Gates: `52/52 PASS`
- H02 authorization: `UNCONSUMED`
- H03: `UNRUN / UNVIEWED / UNCONSUMED`

## Bounded parser remediation

R3 proved that the target weight values were numerically correct. The frozen target serializes the fusion parameters as `0.9004680917645591,1-0.9004680917645591,0`; the failure was solely the literal-only `str2double` parser rejecting the valid arithmetic expression in the second token.

The target SLX was not modified. `V25_FIXED_WEIGHT_ALPHA_V1` was not modified. The exact runner gate remains:

```matlab
isequal(report.static.weights, alpha)
```

Only the runner-local parser was replaced with a deterministic recursive-descent parser supporting:

```text
finite numeric literals / exact pi / unary + and - / binary + - * / / parentheses
```

It permits space and tab whitespace, requires complete token consumption, rejects unknown identifiers and unsupported syntax, rejects division by zero, and rejects nonfinite intermediate or final results. It contains no `eval`, `str2num`, general MATLAB expression evaluation, filesystem access, or workspace access. The outer list contract remains comma-separated, ordered, `1xN double`.

Python was used only as an independent numeric reference. It confirmed `1-0.9004680917645591 = 0.099531908235440891` and `180/pi = 57.295779513082323`. The MATLAB parser was not executed in R4.

## Frozen hashes and implementation integrity

| Artifact | Historical predecessor | Active A3 SHA-256 |
|---|---|---|
| Runner/parser | `92FCB9C866DE819E32FD4309C8EDAC9219E69C203FD5AA824765AC0EF9D853D6` | `869AB9683FA6265DE7768FACEB1DC8BBCF2AC2F1CA12F5175A0C2F91D8DF1F1C` |
| Analyzer | `317625E45EA95CF1714A6037EA086F6ADED8DCD5918C4005C8261804A95F5DBA` | `9A2678F24ACF2EC15B9025E3DDD1285E7D927C35AE96F5448B51DA0A149E6BD8` |
| A3 MATLAB bootstrap | A2: `834DB18FC49F9F88CDB2179AD5A5CF544854B2F9CA0889602A2001FE7B1C1B89` | `42CD5A87C1EDF9DEBCC404646BD9B1EE3E6DEAF4C13939F068FC001A9B6A8A7E` |
| A3 ASCII launcher | A2: `383DCEC3FE13DDF6FC64F035DDE7DB08E6B392B6F8180A03D0B6A8E6450686DF` | `2693BD1367BA063D4CF10FB26CDA5088FEFBDA52E6E9C4B18DAC66F620A4B181` |

Analyzer reverse-substitution of only the A3 phase filename reproduces its frozen R2 SHA-256 exactly, proving no metric, eligibility, truth-alignment, window, or formal-MAT logic changed.

Unchanged formal artifacts:

- Target: `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- Fusion core: `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- Fusion wrapper: `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`
- Preregistry: `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`
- Runtime weights: `alpha_D=0.9004680917645591`, `alpha_K=0.09953190823544089`, `alpha_F=0`, sum `1`

## A3 execution lineage

A1 and A2 execution evidence remain immutable, and A2 remains permanently closed. A3 is not a new holdout or changed condition; it is a new execution attempt for the same untouched `FWHOLD_H02` statistical holdout.

Bootstrap, runner, and analyzer all reference:

```text
results/vy_fixed_fusion_v2_5i2_H02_exec_a3_phase_markers.csv
```

Active A1/A2 phase references are zero. The new A3 bootstrap and launcher are frozen under `D:\V25_H02_BOOTSTRAP_A3` and were not executed. The runner retains one executable `sim()` call, zero retry paths, and the original durable commit/read-back-before-sim authorization boundary.

At R4 completion:

- A3 launcher invocation: `0`
- A3 phase file: `ABSENT`
- `SIM_AUTHORIZATION_COMMITTED`: `ABSENT`
- Formal H02 MAT: `ABSENT`
- A3 stdout/stderr/exitcode/status: `ABSENT`
- Live MATLAB: `0`

No MATLAB, Simulink, `load_system`, `sim()`, CarSim, H02 runtime, or H03 action occurred. H02 formal runtime authorization remains `UNCONSUMED`.

A fresh final pre-sim revalidation is required before any A3 launcher execution.

**READY FOR V2.5-I2-P3 H02 A3 FINAL FORMAL RUNTIME PRE-SIM REVALIDATION**
