# V2.5-I2-A3-W1 Active Runtime Stall Forensics

## Classification

**ACTIVE_BUT_STALLED_UNRESOLVED**

This is a read-only snapshot of the already-authorized `FWHOLD_H02_EXEC_A3` instance. No MATLAB launch, H02 rerun, H03 run, process termination, or evidence modification was performed.

## Supporting local evidence

- Live MATLAB/helper count: `2`
  - PID `6192`, process name `MATLAB`, `Responding=True`, no visible title, start `2026-08-30 08:24:32 +08:00`
  - PID `21044`, process name `matlab`, `Responding=True`, no visible title, start `2026-08-30 08:24:32 +08:00`
- CPU sampling over 3 seconds: PID `6192` delta `0`; PID `21044` delta `0`.
- No CarSim/VS solver process was enumerated.
- No relevant visible window title was reported by the process interface. Hidden modal-window ownership could not be proven with the available read-only access.
- `Get-CimInstance Win32_Process` command-line/parent query was denied; command-line and parent/child classification is therefore `UNRESOLVED`.
- Application event query from `08:20` local time returned zero matching MATLAB/CarSim/license events. Complete WER/provider coverage is not proven.

## Durable A3 state

A3 phase file:

```text
results/vy_fixed_fusion_v2_5i2_H02_exec_a3_phase_markers.csv
SHA-256: 7D546B3F2AF8333019445E48BA24FAE061BA26C3CB6C82BE8128B448ED564E5B
```

Its final durable phase remains `SIM_AUTHORIZATION_COMMITTED` and its mtime is `2026-08-30T08:26:07.2558868+08:00`. No `SIM_RETURNED` or `FORMAL_MAT_SAVED` phase exists.

- Commit: `PRESENT`, SHA-256 `DC85865CB4E9A0633141A9CB53A5E710F46F0F2A4D87B0477CB9897DEA3321A8`
- Formal H02 MAT: `ABSENT`
- Launcher exitcode: `ABSENT`
- Launcher status: `ABSENT`
- stdout: present, size `0`, currently locked by the active instance
- stderr: present, size `0`, currently locked by the active instance
- SET-2: `ABSENT`
- H03: `UNRUN / UNVIEWED / UNCONSUMED`

## Attribution limits

The local snapshot proves an active stalled state after authorization commit, but does not independently prove whether the process is waiting on a modal interaction, a license/external service, or another internal/external condition. The user-reported CarSim Solver license popup is not present in readable final launcher stderr/stdout/status evidence, so license failure is not independently classified here.

Manual user interaction is **UNRESOLVED**. Process termination is **NOT justified** and no termination was attempted. The already-consumed authorization remains permanent; no second H02 runtime is authorized.

**NO SECOND H02 RUNTIME IS AUTHORIZED.**
