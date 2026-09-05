# V2.5-I3-E0 H03 First-and-Only Formal Runtime Status

## Current state

**ACTIVE_BUT_STALLED_POST_COMMIT**

H03 的唯一 launcher 已执行一次并仍未自然结束。当前只做状态记录；未启动第二个 MATLAB、未重跑 launcher、未调用第二次 `sim()`、未运行 H01/H02 或 analyzer。

## Authorization boundary

- run ID：`FWHOLD_H03`
- attempt：`FWHOLD_H03_EXEC_R0`
- condition：`0.030 rad / 0.45 Hz / 16 s / 100 Hz`
- launcher invocation：`1`
- `SIM_AUTHORIZATION_COMMITTED`：`PRESENT`
- commit SHA-256：`5787BA448087421D39197504CEEDFDBA4628F9AF350579264574FAF1F10ABB8A`
- H03 authorization：`CONSUMED`（永久）
- second H03 runtime：`NOT AUTHORIZED`

## Current live evidence

- MATLAB PID `18828`：存活，Responding=True，CPU 约 `69.890625 s`
- MATLAB helper PID `18900`：存活，Responding=True，CPU 约 `0.015625 s`
- live MATLAB/helper count：`2`
- live CarSim solver count：`0`
- phase path：`results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv`
- phase SHA-256：`D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`
- last durable phase：`SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED`：`ABSENT`
- `FORMAL_MAT_SAVED`：`ABSENT`
- formal H03 MAT：`ABSENT`
- launcher exitcode：`ABSENT`
- launcher status：`ABSENT`
- launcher stdout/stderr：均为 `0` bytes
- analyzer：`NOT_RUN_NO_FORMAL_MAT`
- termination performed：`FALSE`

主 MATLAB 在 commit 后长时间仅有极小 CPU 增长，solver 未出现，launcher 尚未退出；当前无法从持久 phase/stdout/stderr 判定具体等待原因。不得把该状态未经额外证据归因于 license、MATLAB、runner 或模型。

## Closure boundary

由于已提交授权，本次 H03 runtime authorization 已永久消费；即使后续进程退出或失败，也不得第二次运行 H03。当前未生成 formal holdout 数据，因此不能进入 analyzer 或任何 performance/holdout 汇总计算。

本快照未执行 termination；是否终止需单独的后续控制决策。

证据：`results/vy_fixed_fusion_v2_5i3_H03_exec_r0_e0_postcommit_stall_snapshot.csv`
