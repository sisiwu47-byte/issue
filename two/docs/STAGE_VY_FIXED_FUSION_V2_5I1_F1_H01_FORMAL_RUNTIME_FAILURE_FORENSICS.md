# V2.5-I1-F1 H01 Formal Runtime Failure Forensics

## Stage conclusion

**V2.5-I1-F1 H01 FORMAL RUNTIME FAILURE FORENSICS & HOLDOUT COMPLETENESS FREEZE PASSED**

One and only one formal H01 launcher invocation occurred. No immutable formal H01 runtime MAT was produced. `simCallCount` was not persisted and must not be fabricated.

The best-supported allowed classification is **SIM_BOUNDARY_UNRESOLVED_NATIVE_TERMINATION**: the observed MATLAB processes terminated without a persisted runner report, but the available durable evidence cannot distinguish a runner/pre-sim error from entry into `sim()` or CarSim runtime. This classification is conservative; a specific native crash, faulting module, CarSim entry, or exception code was **not proven**.

## Forensic findings

- Observed MATLAB PIDs: 19516 and 20708, approximately 2026-08-30 00:12:02–00:12:47 +08:00.
- Formal launcher/bootstrap, runner, analyzer and R4 lineage hashes match their frozen values.
- The formal launcher defines no persistent stdout, stderr, exit-code, marker or status paths. No formal-session launcher log was found.
- Runner line 78 sets `simCalled=true`, `simCallCount=1` and authorization `CONSUMED` only in memory; line 79 calls the unique `sim()`. The formal MAT is saved only at lines 91–94 after control returns. A hard termination or an earlier assertion can therefore leave no persisted sim-boundary field.
- Both `.dmr` files have the `SQLite format 3` signature. Static printable-string extraction identified MATLAB/Simulink repository schemas, but no `vx_vy_fixed_fusion_v2_5`, CarSim, `carsim_64.dll`, `vs_sf`, access violation, `0xC0000005`, PID, solver or fatal-crash evidence.
- Windows Application/WER query for 2026-08-30 00:07–00:18 +08:00 returned no relevant events. No related `.dmp`, MATLAB crash dump, `java.log`, `hs_err_pid`, `.log` or `.txt` artifact was found in the bounded crash locations; only the two DMR files were present.

Accordingly, neither `PRE_SIM_FAILURE_PROVEN` nor `SIM_ENTRY_OR_RUNTIME_FAILURE_PROVEN` is justified. No component is blamed.

## Authorization and eligibility freeze

H01 authorization remains **CONSUMED_BY_SAFETY_POLICY** regardless of forensic classification. **NO SECOND H01 RUNTIME IS AUTHORIZED.**

- H01 formal data status: `NO_USABLE_HOLDOUT_DATA`
- H01 metric eligibility: `NOT_ELIGIBLE_FOR_METRIC_AGGREGATION`
- Reason: `NO_IMMUTABLE_FORMAL_RUNTIME_DATASET`
- H01 performance metrics: not calculated
- H02/H03: `UNRUN / UNVIEWED / UNCONSUMED`; result MAT files absent

`V25_FIXED_WEIGHT_ALPHA_V1` and all model/core/wrapper/preregistry artifacts remain unchanged.

## Holdout completeness freeze

The frozen primary metric is `EQUAL_MANEUVER_MSE`, with `J_H_D`, `J_H_K`, `J_H_F`, and `J_H_FW` each defined as the one-third sum over H01, H02, and H03. Because H01 has no usable immutable dataset:

`PRIMARY_THREE_HOLDOUT_AGGREGATE_STATUS = INCOMPLETE_DUE_TO_MISSING_H01_FORMAL_DATA`

Therefore `J_H_D`, `J_H_K`, `J_H_F`, `J_H_FW`, `rho_holdout`, and the primary generalization classification must not be computed. A two-run H02/H03 average cannot substitute for the preregistered three-holdout metric. No post-failure amendment is created in F1.

Machine-readable evidence is frozen in `results/vy_fixed_fusion_v2_5i1_f1_H01_failure_forensics.csv` and `results/vy_fixed_fusion_v2_5i1_f1_failure_artifact_manifest.csv`.
