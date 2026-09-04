# V2.5-I2-R3 H02 Static Target-Parameter Gate Forensics

## Conclusion

**V2.5-I2-R3 H02 STATIC TARGET-PARAMETER GATE FORENSICS PASSED**

- Statistical run ID: `FWHOLD_H02`
- Historical execution attempt: `FWHOLD_H02_EXEC_A2`
- A2 status: `CLOSED_PRECOMMIT_STATIC_GATE_FAILURE`
- A2 last durable phase: `PREREGISTRY_PARSED`
- A2 phase SHA-256: `198B630905D6610C6C2C5C92DE59030FD68F7E499F2054099F3F501BFF43698F`
- `SIM_AUTHORIZATION_COMMITTED`: `ABSENT`
- H02 authorization: `UNCONSUMED`
- `sim()` / CarSim: not entered
- H03: `UNRUN / UNVIEWED / UNCONSUMED`

The A2 phase file, A2 launcher outputs, A2 runtime status, SET-2 hygiene evidence, P1 evidence, and R1/R2 remediation evidence were read only and remain immutable. A2 is permanently closed and must never be launched again.

## Compound-gate decomposition

The thrown gate is at runner line 83:

```matlab
report.static.pass && isequal(report.static.weights, alpha)
```

`alpha` is constructed at line 47 as a `1x3 double` row:

```matlab
alpha=[double(w.runtime_alpha_D),double(w.runtime_alpha_K),double(w.runtime_alpha_F)];
```

Its frozen value is `[0.9004680917645591, 0.09953190823544089, 0]`.

`report.static` is produced by the nested `static_preflight` function in `model/run_vy_fixed_fusion_v2_5i2_H02_holdout.m` (same file SHA-256 `92FCB9C866DE819E32FD4309C8EDAC9219E69C203FD5AA824765AC0EF9D853D6`). `report.static.weights` is constructed by:

```matlab
parse_expr_list(get_param(fusion,'Parameters'))
```

The nested parser splits on commas, allocates `zeros(1,numel(p))`, and calls `str2double` on each trimmed token. Therefore the result is also a `1x3 double` row; shape, class, and order are not the failure.

## TOP_GATE_A — `report.static.pass`

Classification: **PASS_PROVEN_STATICALLY**.

The actual producer defines three subconditions:

1. `numel(weights)==3`: PASS. The fusion Parameters string contains three comma-separated tokens.
2. `numel(fp)==4`: PASS. `F-Track Stateful Boundary` serializes `0.01,0,0.5,0.0025` in `simulink/systems/system_500.xml`.
3. `Gain22` exact string equals `180/pi`: PASS. `Gain22` SID 109 serializes `<P Name="Gain">180/pi</P>` in `simulink/systems/system_root.xml`.

The producer does not include a finite-value check, so the NaN described below does not make `report.static.pass` false.

## TOP_GATE_B — `isequal(report.static.weights,alpha)`

Classification: **FAIL_PROVEN_STATICALLY**.

The formal target serializes the fusion S-function parameters in `simulink/systems/system_root.xml` as:

```text
0.9004680917645591,1-0.9004680917645591,0
```

The parser produces:

```text
[0.90046809176455911, NaN, 0]
```

because `str2double` parses numeric text but does not evaluate the arithmetic expression in token 2. The frozen `alpha` is finite, so `isequal` is false.

An offline IEEE-double reproduction showed:

```text
1 - 0.9004680917645591 = 0.099531908235440891
frozen alpha_K         = 0.099531908235440891
exact double equality = TRUE
```

Thus there is no intended numeric weight mismatch, no order mismatch, no `1x3` versus `3x1` mismatch, and no class mismatch. The target's algebraic expression is numerically exact, but the helper incorrectly treats every token as a literal.

## Root-cause classification

**E. STATIC_PARAMETER_PARSE_DEFECT_PROVEN**

The strict proof chain is source `parse_expr_list` + read-only SLX serialization + deterministic offline token/double reproduction. The root cause is the literal-only parsing of a valid frozen constant expression. `Gain22` and both token-count subconditions pass statically.

## Read-only archive evidence

The SLX was opened directly as a ZIP package and was not extracted, saved, modified, or repacked.

- `simulink/systems/system_root.xml`: SHA-256 `0A6B78E098C4B1A5BFB162C00B0479647FA9C40E4F9C7A64DF5D4A562EC90804`; contains fusion Parameters and Gain22.
- `simulink/systems/system_500.xml`: SHA-256 `A491B94E467FDD4BCABA73ACC7D9FF5E7770963B1D699CEABD9F179D59F8A67A`; contains F-track Parameters.
- Formal target remains SHA-256 `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`.

No MATLAB, Simulink, `load_system`, simulation, CarSim, code modification, target modification, weight modification, or preregistry modification occurred in R3.

## Minimal future remediation class

R3 implements no fix. A bounded R4 may remediate only the runner's constant-expression parameter parsing and persist individual pre-commit subgate diagnostics. It must preserve exact weight equality, reject nonfinite parsed values, retain the target/core/wrapper/weights/registry unchanged, and use new execution lineage if a later runtime is separately authorized.

`NEXT_ATTEMPT_ID_IF_AUTHORIZED = FWHOLD_H02_EXEC_A3`

**READY FOR V2.5-I2-R4 BOUNDED STATIC-GATE REMEDIATION**
