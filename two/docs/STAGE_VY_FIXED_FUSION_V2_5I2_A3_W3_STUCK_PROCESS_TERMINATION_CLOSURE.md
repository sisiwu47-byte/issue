# V2.5-I2-A3-W3 Stuck-Process Controlled Termination & Post-Exit Closure

## Final classification

**V2.5-I2 H02 EXEC_A3 CLOSED AFTER AUTHORIZATION COMMIT**

`runtime classification = POST_COMMIT_PERSISTENT_STALL_TERMINATED`

本阶段仅处理已确认属于 `FWHOLD_H02_EXEC_A3` 的 PID 6192（MATLAB 主进程）和 PID 21044（helper）。未启动 MATLAB、launcher 或仿真，未运行 H03，未修改历史 A1/A2/A3 phase evidence。

## Termination record

- 终止前确认：PID 6192 与 21044 同一 A3 启动时刻（约 `2026-08-30 08:24:32 +08:00`）、同一 session；此前 W1/W2 均记录为该 A3 实例。
- 首次受控退出：对两个 PID 执行 `Stop-Process`（non-force），均返回 `Access Denied`，进程仍存活。
- 必要强制终止：仅对 PID `6192;21044` 执行 `Stop-Process -Force`，两者均报告请求成功。
- 等待 5 秒后：两个 PID 均不再存活。
- 终止未涉及其他 MATLAB、CarSim 或用户进程。

## Post-exit state

- live MATLAB/helper：`0`
- live CarSim/VS solver：`0`
- phase file：`results/vy_fixed_fusion_v2_5i2_H02_exec_a3_phase_markers.csv`
- phase SHA-256：`7D546B3F2AF8333019445E48BA24FAE061BA26C3CB6C82BE8128B448ED564E5B`（与 W2 结束时一致）
- last durable phase：`SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED`：`ABSENT`
- `FORMAL_MAT_SAVED`：`ABSENT`
- formal H02 MAT：`ABSENT`
- analyzer：`NOT_EXECUTED_NO_FORMAL_MAT`

终止后 launcher 文件状态：

- exitcode：存在，内容 `-1`
- status：存在，内容 `FORMAL_LAUNCH_COMPLETED,exit_code=-1`
- stdout：存在，`0` bytes
- stderr：存在，`0` bytes

由于进程是强制终止，`-1` 是 launcher 包装层在退出闭合时写入的结果；它不是正常仿真返回，也不能伪造为 `SIM_RETURNED`。因此 `SIM_RETURNED` 仍为 absent，formal MAT 未生成。

## SET-2 / H03 / authorization

- post-runtime active SET-2：`ABSENT`；未发现需要归档的新 A3 SET-2 artifact。
- H03：`UNRUN / UNVIEWED / UNCONSUMED`
- H02 authorization：`CONSUMED`（永久）
- formal data status：`NO_USABLE_HOLDOUT_DATA`
- second H02 runtime：`NOT AUTHORIZED`

## Root-cause boundary

根因：`UNRESOLVED`。本地持久 evidence 只能证明授权提交后持续 stall 并最终被受控强制终止；空 stdout/stderr、无 SIM_RETURNED、无 formal MAT，不能把原因正式归为 CarSim license failure，也不能归咎于 MATLAB、runner、模型或 S-function。

**NO SECOND H02 RUNTIME IS AUTHORIZED.**
