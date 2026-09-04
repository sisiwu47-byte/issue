# V2.5-I1-R0 H01 Holdout Runner/Analyzer Preparation

## Stage status

**V2.5-I1-R0 H01 HOLDOUT RUNNER/ANALYZER PREPARATION & FREEZE PASSED**

H01 was previously blocked because no runtime runner matched the frozen V2.5-I holdout protocol. The existing calibration runner was not reused: it accepts only calibration IDs and contains the superseded `801FC...` target hash gate. It remains unchanged.

## Dedicated artifacts

- Runner: `model/run_vy_fixed_fusion_v2_5i1_H01_holdout.m` — SHA-256 `05E15D23CEB9A2F3B60772311D4858C75DDE1F161647884655BDE26635AF739D`
- Analyzer: `model/analyze_vy_fixed_fusion_v2_5i1_H01_holdout.m` — SHA-256 `052F2BA6BB7285E7056417C235F8782F994EE0B2980433DF268474556B53C0DC`

The runner has no run-ID input. It reads the frozen preregistration and uses only the row with `execution_order=1`; its exact current ID is `FWHOLD_H01`. Any other identity is rejected before the simulation call. H02 and H03 are checked only for untouched status/path metadata; their MAT files are never loaded.

## Frozen target and weight contract

The only accepted formal target is `model/vx_vy_fixed_fusion_v2_5.slx` with SHA-256 `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`. The runner reads and verifies H2 weight evidence `V25_FIXED_WEIGHT_ALPHA_V1`:

`alpha_D=0.9004680917645591`, `alpha_K=0.09953190823544089`, `alpha_F=0`, sum `1`.

No command-line or user override, normalization, fitting, adaptive logic, or performance-based change is possible. The formal result path is read directly from the preregistration and must be absent before execution.

## One-simulation contract

The runner contains exactly one executable `sim()` call site, protected by pre-simulation gates. It has no retry loop, fallback simulation, alternate target, or second execution path. `simCalled=0` and `simCallCount=0` before the call. Immediately before the call the authorization becomes consumed; any later exception cannot trigger another call. If the pre-simulation phase fails, no formal H01 MAT is written. A formal MAT is written only after the single simulation entry has occurred.

The runner records the preregistration card, actual maneuver settings, frozen alpha, target hash, MATLAB version/PREFDIR, SET-2 provenance policy, CarSim environment, all required D/K/F/fusion/truth/steering/Vx logs, and completion metadata. It does not move or delete SET-2.

## Analyzer contract

The analyzer accepts no run ID and reads exactly the H01 formal MAT path from the frozen preregistration. It never scans the results directory, loads calibration MATs, loads H02/H03, or writes to the formal runtime MAT. It writes only separate integrity-gate, acquisition, and metric CSV files.

Phase 1 performs integrity and eligibility checks: runtime completion, exact condition, timing/sample counts derived from duration/rate, D/K/F integrity, scheduler/input evidence, covariance checks, exact replay, steering/truth/evaluation fidelity, target hash, and frozen alpha. Only when every Phase 1 gate passes is `ELIGIBLE_HOLDOUT_DATA` assigned and Phase 2 entered.

Phase 2 computes only H01 frozen metrics (MSE, RMSE, MAE, bias, max-absolute error, best-single MSE, `ratio_H01`, `gain_vs_D_H01`, and `FW_BETTER/TIE/WORSE`). It does not compute three-holdout aggregates (`J_H_*`, `rho_holdout`) and cannot modify alpha.

## Static R0 evidence

`results/vy_fixed_fusion_v2_5i1_r0_runner_analyzer_freeze.csv` records the dedicated artifacts, exact target lineage, one-call/no-retry properties, read-only analyzer policy, and unchanged calibration references. `results/vy_fixed_fusion_v2_5i1_r0_preparation_gates.csv` records 24/24 preparation gates as PASS.

No MATLAB, Simulink, `sim()`, CarSim, H01 runtime, holdout data read, performance calculation, model modification, alpha modification, or calibration-script modification occurred in R0. H01 authorization remains `UNCONSUMED`; H02/H03 remain `UNRUN`, `UNVIEWED`, and `UNCONSUMED`.

THE CALIBRATION RUNNER WAS NOT REPURPOSED OR MODIFIED.

THE H01 RUNNER ACCEPTS ONLY THE FROZEN H01 RUN ID AND USES ONLY THE H2-FROZEN FORMAL TARGET.

THE RUNNER CONTAINS EXACTLY ONE AUTHORIZED sim() CALL PATH AND NO RETRY PATH.

THE ANALYZER ENFORCES INTEGRITY/ELIGIBILITY BEFORE ANY PERFORMANCE METRIC IS CALCULATED.

THE ANALYZER DOES NOT READ H02/H03 AND DOES NOT COMPUTE THREE-HOLDOUT AGGREGATES.

NO MATLAB, SIMULINK, sim(), OR CARSIM WAS EXECUTED.

NO HOLDOUT DATA WERE READ.

H01 RUNTIME AUTHORIZATION REMAINS UNCONSUMED.

H02/H03 REMAIN UNRUN AND UNVIEWED.
