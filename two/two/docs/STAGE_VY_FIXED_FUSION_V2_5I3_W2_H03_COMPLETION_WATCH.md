# V2.5-I3-W2 H03 Active Completion Watch

## Scope

对同一 `FWHOLD_H03 / FWHOLD_H03_EXEC_R0` 实例完成一次约 180 秒被动观察。未启动新 MATLAB，未重跑 launcher、runner 或 `sim()`，未执行 analyzer，未进行任何 termination。

## Observation

- 起止时间：`2026-08-30T10:12:53.1654359+08:00` 至 `2026-08-30T10:15:53.5142699+08:00`
- 时长：`180.348834 s`
- 实际快照：`13`（每约 15 s，S0–S12）
- live PID（结束快照）：`18828, 18900, 21428, 25072`，另有 FCBrowser `12144,12500,15940,17464,20368`
- 所列进程均 `Responding=True`，MainWindowTitle 为空；未观察到可确认的 modal/window 变化

CPU 累计增量（S0→S12）：

- MATLAB 18828：`72.328125 → 73.1875 s`，`+0.859375 s`
- helper 18900：`0.015625 → 0.015625 s`，`+0.000000 s`
- CarSim 21428：`6.71875 → 7.203125 s`，`+0.484375 s`
- CarSim 25072：`424.046875 → 451.65625 s`，`+27.609375 s`

PID 21428 路径此前已确认是 `D:\carsim\CarSim2021.0_Prog\CarSim.exe`；PID 25072 的 executable path、parent 和 command line 仍因权限不可读，因此不对其 solver 具体身份或 license 原因作推断。其持续 CPU 增长是仍在计算/仿真活动中的直接证据。

## Durable state

- phase 起止 SHA-256 均为 `D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`
- last durable phase：`SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED`：ABSENT
- `FORMAL_MAT_SAVED`：ABSENT
- formal H03 MAT：ABSENT
- launcher exitcode/status：ABSENT
- stdout/stderr：均 `0` bytes
- H03 authorization：`CONSUMED` permanently
- second H03 runtime：NOT AUTHORIZED
- termination performed：`FALSE`

## Classification

**ACTIVE_COMPUTATION_OR_SIMULATION**

观察期内 CarSim-named PID 25072 CPU 增长约 27.61 s，未出现持久化 phase/output 变化，说明实例仍在计算/仿真阶段。没有明确 modal 或 license failure 证据；manual interaction clearly required：`UNRESOLVED / 未明确需要`。termination justified：`NO`。

证据 CSV：`results/vy_fixed_fusion_v2_5i3_H03_exec_r0_w2_completion_watch.csv`。
