# V2.5-I3-R1 H03 ASCII Bootstrap Path Remediation

## 结论

**V2.5-I3-R1 H03 ASCII BOOTSTRAP PATH REMEDIATION PASSED**

R0 runner、analyzer、bootstrap、launcher 及其 evidence 均保留，未覆盖。R1 只增加了新的纯 ASCII Windows bootstrap 目录及对应入口文件；未启动 MATLAB、Simulink、CarSim 或 H03 launcher，未创建 phase marker、authorization commit 或 formal MAT。

## R0 lineage preserved

- runner `model/run_vy_fixed_fusion_v2_5i3_H03_holdout.m`：`AB65E8D5DCDEE92EA8AC53AEFE1BFDC97CD4FC7BD8390C17E8656DD90EB631C2`
- analyzer `model/analyze_vy_fixed_fusion_v2_5i3_H03_holdout.m`：`B6DE7B43EAEB154BF59EE906F8A08343217AED1CAEB0B5955BBE357D54182823`
- H03 identity、条件、固定权重、target 和 R0 phase/commit/formal-MAT 路径均未改变

冻结 H03 identity 仍为：`FWHOLD_H03` / `FWHOLD_H03_EXEC_R0`，条件 `0.030 rad / 0.45 Hz / 16 s / 100 Hz`，科学角色 `SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`。

## New ASCII execution entry

新目录：

```text
D:\V25_H03_BOOTSTRAP
```

该目录在创建前不存在，provenance 明确，未覆盖既有目录。

| Artifact | Exact path | SHA-256 |
|:--|:--|:--|
| bootstrap | `D:\V25_H03_BOOTSTRAP\run_v25_i3_h03_exec_r0_formal.m` | `43FFD09AD9F5F9E1F421FCA9A786B43A25EA7BE43E4385CC3248256C85B718DE` |
| launcher | `D:\V25_H03_BOOTSTRAP\launch_v25_i3_h03_exec_r0_formal.cmd` | `66747BF4EF3E260545369D78FBEF1AFE4B5F40247F586D84A8AABBA29EFEDC29` |

Launcher 静态特征：

- 工作目录仅为 `%~dp0`（ASCII bootstrap 目录）
- `matlab.exe` 调用次数：`1`
- 不直接 `cd` 到中文项目路径
- retry/fallback：`0`
- launcher execution：`NOT EXECUTED`
- launcher 文件字节为 ASCII-only

Bootstrap 静态特征：

- 不直接调用 `sim()`
- 调用 H03 runner exactly once
- 内部按 R0 既定路径执行 `cd(projectModelDir)`，目标为 `D:\UsersData\桌面\two\model`
- `phaseFile` 与 `commitFile` 与 R0 完全一致
- commit 仍由 runner 在唯一 `sim()` 前持久化、关闭并读回

## H03 artifact and authorization state

```text
phase   = D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv  (ABSENT)
commit  = D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i3_H03_sim_authorization_committed.csv (ABSENT)
formal  = D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i_fwhold_h03.mat                    (ABSENT)
```

H03 authorization：`UNCONSUMED`。H01 仍为无 usable holdout data 的永久关闭状态；H02 仍为 `POST_COMMIT_PERSISTENT_STALL_TERMINATED`、authorization `CONSUMED`，未重跑。

## CarSim license record

仅记录用户人工确认：`CarSim Solver for Windows / Feature code carsimCN / License Version 2021 / Available = Yes (1) / Take = 1`。R1 未进行 runtime probe 或任何 CarSim 操作。

证据 CSV：`results/vy_fixed_fusion_v2_5i3_r1_ascii_bootstrap_remediation.csv`。

READY FOR H03 FINAL PRE-SIM REVALIDATION
