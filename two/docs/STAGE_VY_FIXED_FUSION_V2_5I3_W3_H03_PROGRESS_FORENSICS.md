# V2.5-I3-W3 H03 Active Runtime Progress Forensics

## Scope

对同一 `FWHOLD_H03 / FWHOLD_H03_EXEC_R0` 实例完成约 120 秒只读观察。未启动新 MATLAB，未重跑 launcher/runner/`sim()`，未运行 analyzer，未执行 termination。

## Observation

- 观察起止：`2026-08-30T10:18:56.9324014+08:00` → `2026-08-30T10:20:58.1341672+08:00`
- 时长：`121.201766 s`
- 采样：`9`（S0–S8，约 15 s 间隔）
- 结束时 live MATLAB/helper/CarSim-related PID：`18828, 18900, 21428, 25072`；FCBrowser：`12144,12500,15940,17464,20368`
- 所有可枚举进程 `Responding=True`，窗口标题为空；未发现 modal/window 状态变化

补充 15 秒 CPU/资源采样（只读）：

- MATLAB 18828：CPU `74.6875 → 74.75 s`（`+0.0625 s`），working set/private memory/threads (`97`) 不变
- helper 18900：CPU `0.015625 → 0.015625 s`（`+0.0000 s`），working set/private memory/threads (`3`) 不变
- CarSim 21428：CPU `7.9375 → 7.984375 s`（`+0.046875 s`），working set/private memory/threads (`8`) 不变
- CarSim 25072：CPU `498.6875 → 501.015625 s`（`+2.328125 s`），working set/private memory/threads (`9`) 不变

进程 I/O 计数（Read/Write operations/bytes）无法读取：CIM/WMI 查询受 `Access Denied` 限制；不以缺失值推断无 I/O。

## File/progress evidence

观察期间 H03 phase、commit、formal MAT、launcher stdout/stderr 相关文件均无新增、大小变化或 last-write-time 变化。phase 文件始终为 621 bytes，stdout/stderr 均为 0 bytes，未出现可识别的仿真时间推进或新输出文件。

## Durable state

- phase 起止 SHA-256 均为 `D34FE03F566F1AC3C9E3DD009CF3C4ABC053E38FEF6C4199FE48BC75CB03C1F6`
- last durable phase：`SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED`：ABSENT
- `FORMAL_MAT_SAVED`：ABSENT
- formal H03 MAT：ABSENT
- launcher exitcode/status：ABSENT
- stdout/stderr：`0/0` bytes
- cumulative wall-clock since MATLAB start：约 `1434.114 s`
- H03 authorization：`CONSUMED` permanently
- termination performed：`FALSE`

## Classification

**ACTIVE_CPU_WITHOUT_OBSERVABLE_PROGRESS**

CarSim-named PID 25072 CPU 在补充 15 秒内增加约 2.33 s，但未观察到 I/O、文件、phase 或 formal output 进度。具体 solver identity 仍受权限限制，未作 license/modal 归因。termination justified：`NO`（本阶段未执行）。

证据 CSV：`results/vy_fixed_fusion_v2_5i3_H03_exec_r0_w3_progress_forensics.csv`。
