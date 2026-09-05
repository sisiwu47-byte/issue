# V2.5-I2-P3 H02 A3 Final Formal Runtime Pre-Sim Revalidation

## 结论

**V2.5-I2-P3 H02 A3 FINAL FORMAL RUNTIME PRE-SIM REVALIDATION PASSED**

- Statistical run ID：`FWHOLD_H02`
- Execution attempt：`FWHOLD_H02_EXEC_A3`
- Condition：`0.035 rad / 0.35 Hz / 16 s / 100 Hz`
- Role：`PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`
- Final gates：`52/52 PASS`
- A3 launcher invocation：`0`
- H02 authorization：`UNCONSUMED`
- H03：`UNRUN / UNVIEWED / UNCONSUMED`

## Lineage and immutable history

A1 remains a closed pre-commit infrastructure failure and A2 remains a closed pre-commit static-gate failure. Their phase files, runtime status, launcher evidence, P1/P2/R1/R2/R3 evidence, and hashes were read only and remain immutable. R3's root cause remains `STATIC_PARAMETER_PARSE_DEFECT_PROVEN`.

R4 replaced only the runner-local literal-only parser with a restricted recursive-descent parser. The exact `isequal(report.static.weights,alpha)` gate remains. The parser accepts finite numeric literals, exact `pi`, unary signs, binary `+ - * /`, and parentheses; it requires full token consumption and finite intermediate/final results, rejects unknown identifiers and unsafe syntax, and uses no `eval`, `evalin`, `str2num`, `feval`, or general expression evaluation. The frozen target, weights, core, wrapper, and preregistry were not modified.

## A3 frozen execution chain

Runner SHA-256：`869AB9683FA6265DE7768FACEB1DC8BBCF2AC2F1CA12F5175A0C2F91D8DF1F1C`  
Analyzer SHA-256：`9A2678F24ACF2EC15B9025E3DDD1285E7D927C35AE96F5448B51DA0A149E6BD8`  
A3 bootstrap SHA-256：`42CD5A87C1EDF9DEBCC404646BD9B1EE3E6DEAF4C13939F068FC001A9B6A8A7E`  
A3 launcher SHA-256：`2693BD1367BA063D4CF10FB26CDA5088FEFBDA52E6E9C4B18DAC66F620A4B181`

The runner, analyzer, and bootstrap all reference exactly:

```text
results/vy_fixed_fusion_v2_5i2_H02_exec_a3_phase_markers.csv
```

Active A1/A2 phase references are zero. The runner has one executable `sim()` call, zero retry/fallback paths, and retains the durable commit/read-back-before-sim boundary. The A3 bootstrap calls the runner exactly once; the ASCII launcher starts MATLAB exactly once and has no fallback.

## Pre-sim state

- A3 phase file：`ABSENT`
- `SIM_AUTHORIZATION_COMMITTED`：`ABSENT`
- Formal H02 MAT：`ABSENT`
- A3 stdout/stderr/exitcode/status：`ABSENT`
- Live MATLAB：`0`
- Live CarSim solver：`0`
- Process/User/Machine `MATLAB_PREFDIR`：`UNSET / UNSET / UNSET`
- Active SET-2：`ABSENT`
- H02 authorization：`UNCONSUMED`
- H03：`UNRUN / UNVIEWED / UNCONSUMED`

The preregistry and fixed runtime weights remain exact: `FWHOLD_H02`, `0.035 rad / 0.35 Hz / 16 s / 100 Hz`, `V25_FIXED_WEIGHT_ALPHA_V1`, `alpha_D=0.9004680917645591`, `alpha_K=0.09953190823544089`, `alpha_F=0`.

No MATLAB, Simulink, `load_system`, `sim()`, CarSim, H02 runtime, H03 action, model modification, alpha modification, or preregistry modification occurred in P3.

This is the final pre-sim revalidation for A3. The next authorized action is exactly one execution of the frozen A3 ASCII launcher. Once a durable commit is written and verified, H02 authorization becomes permanently consumed and no second A3 launcher/runtime is permitted.

**READY FOR V2.5-I2 H02 EXEC_A3 FIRST-AND-ONLY FORMAL RUNTIME**
