# V2.5-I3-W4 H03 Controlled Termination and Post-Exit Closure

## Frozen authorization boundary

- Run ID: `FWHOLD_H03`
- Attempt: `FWHOLD_H03_EXEC_R0`
- Launcher invocation: `1`
- `SIM_AUTHORIZATION_COMMITTED`: PRESENT
- H03 authorization: `CONSUMED` permanently
- Second H03 runtime: **NOT AUTHORIZED**

## Pre-termination snapshot

- MATLAB `18828`, helper `18900`: Responding=True, created at approximately 09:57, confirmed as the H03 runtime instance.
- CarSim `21428`: executable `D:\carsim\CarSim2021.0_Prog\CarSim.exe`, started 09:20; treated as Browser/owner process and excluded.
- CarSim `25072`: started 09:24:26 (before H03), executable/parent/command line unavailable; ownership not proven and excluded.
- FCBrowser PIDs `12144,12500,15940,17464,20368`: excluded.
- phase SHA-256: `D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`
- last durable phase: `SIM_AUTHORIZATION_COMMITTED`
- commit SHA-256: `5787BA448087421D39197504CEEDFDBA4628F9AF350579264574FAF1F10ABB8A`
- `SIM_RETURNED`: ABSENT; `FORMAL_MAT_SAVED`: ABSENT; formal MAT: ABSENT
- launcher stdout/stderr: `0/0` bytes; exitcode/status not yet present

## Termination

1. Non-force `Stop-Process` for PIDs `18828` and `18900`: both returned **Access Denied**.
2. `CloseMainWindow()` for both: returned `False`; both remained live.
3. `Stop-Process -Force` was then applied only to confirmed H03 PIDs `18828` and `18900`; both exited successfully.

No Browser, License Manager, FCBrowser, or unconfirmed CarSim PID was terminated.

## Post-exit closure

- confirmed H03 MATLAB/helper live count: `0`
- confirmed H03 CarSim runtime live count: `0` (no CarSim PID was proven to belong to H03; pre-existing PID 25072 remains unclassified and untouched)
- phase SHA-256 unchanged: `D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`
- last durable phase: `SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED`: ABSENT
- `FORMAL_MAT_SAVED`: ABSENT
- formal H03 MAT: ABSENT
- launcher exitcode: `-1`
- launcher status: `FORMAL_LAUNCH_COMPLETED,exit_code=-1`
- stdout/stderr: `0/0` bytes
- analyzer: `NOT_RUN_NO_FORMAL_MAT`
- active H03 SET-2: `ABSENT`

The `-1` exitcode is a termination-wrapper result after forced process termination; it is not evidence of a normal `sim()` return.

## Final classification

**V2.5-I3 H03 EXEC_R0 CLOSED AFTER AUTHORIZATION COMMIT**

runtime classification: **POST_COMMIT_CPU_SPIN_TERMINATED**

root cause: **UNRESOLVED** (no new persistent evidence proving license, CarSim, MATLAB, runner, or model cause)

formal data status: **NO_USABLE_HOLDOUT_DATA**

H03 therefore cannot provide `SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`. It cannot replace H01/H02, support PARTIAL23, original three-holdout aggregation, generalization classification, or weight/Q/R changes.

Evidence CSV: `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_w4_termination_closure.csv`.
