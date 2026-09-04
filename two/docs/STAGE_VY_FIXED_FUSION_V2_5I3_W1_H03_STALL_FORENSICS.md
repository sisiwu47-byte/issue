# V2.5-I3-W1 H03 Active Runtime Stall Forensics

## Scope and authorization

- Run ID: `FWHOLD_H03`
- Attempt: `FWHOLD_H03_EXEC_R0`
- Launcher invocation: `1`
- `SIM_AUTHORIZATION_COMMITTED`: PRESENT (commit SHA-256 `5787BA448087421D39197504CEEDFDBA4628F9AF350579264574FAF1F10ABB8A`)
- H03 authorization: `CONSUMED` permanently
- Second H03 runtime: **NOT AUTHORIZED**
- No new MATLAB, launcher, runner, `sim()`, or termination was performed.

## Bounded observation

Observation ran from `2026-08-30T10:05:24.8743592+08:00` to `2026-08-30T10:06:25.2527806+08:00` (60.378 s, 8 snapshots). The phase file hash remained `D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`; the last durable phase remained `SIM_AUTHORIZATION_COMMITTED`.

The primary CIM/WMI process query returned **Access Denied**, so its zero-process result is not treated as authoritative. A supplementary read-only `Get-Process` check showed:

- MATLAB PID `18828`, Responding=True; CPU `71.12 -> 71.14 s` over 10 s (+0.02 s), title empty.
- helper PID `18900`, Responding=True; CPU `0.02 -> 0.02 s` (+0.00 s), title empty.
- CarSim PID `21428`, Responding=True, executable `D:\carsim\CarSim2021.0_Prog\CarSim.exe`; CPU `5.97 -> 6.03 s` (+0.06 s), title empty.
- CarSim PID `25072`, Responding=True; executable path/command line unavailable; CPU `372.55 -> 374.09 s` over 10 s (+1.54 s), title empty.
- FCBrowser processes were present; no visible window title was reported.

The CPU increase of the CarSim-named process is positive evidence of ongoing computation/simulation, but the exact solver executable and parent/command line cannot be proven because CIM/WMI access was denied. No modal/error window was observable through the safe process fields.

## Durable output state

- `SIM_RETURNED`: ABSENT
- `FORMAL_MAT_SAVED`: ABSENT
- formal H03 MAT: ABSENT
- launcher exitcode/status: ABSENT
- launcher stdout/stderr: 0 bytes (files present at `D:\V25_H03_BOOTSTRAP\FWHOLD_H03_EXEC_R0_stdout.txt` and `D:\V25_H03_BOOTSTRAP\FWHOLD_H03_EXEC_R0_stderr.txt`)
- analyzer: NOT RUN (no formal MAT)
- termination performed: FALSE

## Classification

**ACTIVE_COMPUTATION_OR_SIMULATION**

This classification is based on the observed CPU growth of the CarSim-named process. Exact parent/command-line ownership and a solver-specific executable path remain **UNRESOLVED**; no license or modal attribution is made. Manual user interaction is **UNRESOLVED / not clearly required**. Termination justified: **NO**.

Evidence CSV: `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_w1_stall_forensics.csv`.
