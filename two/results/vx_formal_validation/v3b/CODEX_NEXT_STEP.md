# VX V3B Codex Execution Entry — COMBINED DRIVE/BRAKE SLIP

本文件是当前唯一执行入口。V3A 已 superseded；不要执行 V3A 的 VX-DS-only 方案。不要重跑 V3 的 VX-ND/VX-ST/VX-DR。

## 只读文件

先读且只读：

1. `AGENTS.md`
2. 本文件
3. `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`
4. `results/vx_formal_validation/v3b/VX_FORMAL_CASE_AMENDMENT_V3B.md`
5. `results/vx_formal_validation/v3b/runtime_contract_v3b.md`
6. `results/vx_formal_validation/v3b/case_handoff_v3b.json`
7. `matlab/configure_vx_formal_case_v3.m`
8. `matlab/run_vx_formal_validation_v3.m`
9. `matlab/analyze_vx_formal_validation_v3.m`
10. `tests/tiaocan/validate_online_kH60_FG.m`
11. `tests/save_case_E_result.m` 仅看 torque 字段/历史 provenance 警告，不要全文复述。

只有 Tier 2 真正需要确认 wheel-torque route 时，才读取 `model/MPC_Demo3_wuguzhang.m` 中 torque input/output、Qmax 和相关约束片段；不要全文读取控制器。当前已知 Qmax=1600 Nm。

不要扫描整个仓库，不要复述已有 status/evidence。

## 当前冻结事实

- V3 committed formal sim count = 5；accepted raw = 3。
- V3 `VX-DR` acceleration gate PASS，braking gate FAIL。
- 失败原因按当前证据归类为 `PHYSICAL_EXCITATION_INSUFFICIENT_FOR_BRAKE_SLIP`，不是 estimator failure。
- V3A 尚无 formal runtime，现已 superseded；不要创建/运行 V3A VX-DS。
- 新目标：一个新的 `VX-CS` current-version formal case，在同一次低附着 40->70->40 运行中同时形成 rear drive slip 和 rear brake slip。

## 阶段 A：创建 V3B 物理激励审计/标定执行层

必须新建：

### `matlab/audit_historical_fg_physical_excitation_v3b.m`

只读取：

- `tests/results_case_F.mat`
- `tests/results_case_G.mat`

不得修改 MAT。

用 `whos -file`/结构字段先确认 `E`。从 `E.est_u_time/E.est_u_data`、`E.Vx_true_*`、以及存在的 `E.T_L1/E.T_L2/E.T_R1/E.T_R2/E.T_total` 提取物理量。

输出 compact：

`results/vx_formal_validation/v3b/calibration/historical_FG_physical_audit.csv`
`results/vx_formal_validation/v3b/calibration/historical_FG_physical_audit.json`

至少报告：

- F: known degraded interval `[5.778,7.999]`
- G: known degraded/locked interval `[4.709,9.175]`
- 每个 torque channel 在 interval 内 min/max/median/5th/95th percentile
- wheel kappa RL/RR min/max and sustained positive/negative slip duration
- 是否存在明确负 torque physical signature

不要用这些旧数据算当前 estimator performance，不要据此改 estimator。

### `matlab/calibrate_vx_combined_physical_excitation_v3b.m`

这是非正式 physical calibration runner。必须显式写：

`FORMAL_RUNTIME=false`
`SIM_INVOCATION_COMMITTED=NO`

单独计数 `PHYSICAL_CALIBRATION_SIM_COUNT`。

它必须复用 V3 configurator 的 validation-copy、hash、CarSim solver、working-directory、duplicate-Goto workaround 和 logging 方法，但不要修改 V3 文件；需要新建 V3B helper/configurator。

候选选择只能看：Vx truth、wheel omega、applied speed/torque command、simulation completion。禁止读取/打印/比较 Fusion/WSS/IMU RMSE、rho、validWheel、alpha 或图像。

## 阶段 B：Tier 1 reference-only calibration

新建：

### `matlab/configure_vx_physical_calibration_v3b.m`

只生成 validation copy，不调用 sim。

共同配置：

- low-mu control = A20b MU03；保持原 Run_all/simfile hash 校验；
- `MU_ROAD_CONSTANT=0.30`；
- steering=0；StopTime=16；
- speed prefix = `[0;3;7;9] -> [40;40;70;70] km/h`；
- source model/estimator/parameter/wrapper frozen hashes保持 V3。

Tier1 candidate 顺序固定：

1. `T1_2P5`: speed `[0;3;7;9;11.5;16] -> [40;40;70;70;40;40]`
2. `T1_2P0`: speed `[0;3;7;9;11.0;16] -> [40;40;70;70;40;40]`
3. `T1_1P5`: speed `[0;3;7;9;10.5;16] -> [40;40;70;70;40;40]`

每次 calibration sim 后只算 raw kappa：

`kappa=(0.393*omega-Vx_true)/max(abs(Vx_true),1)`

Drive gate: RL/RR each `>=+0.10` sustained >=0.10 s in `[3,7)`.
Brake gate: RL/RR each `<=-0.10` sustained >=0.10 s in `[9, brakeRampEnd+0.5)`.

按顺序运行，第一条两个 gate 都 PASS 后立即停止 Tier1，不再跑更强 candidate。

每条 calibration 保存：

`results/vx_formal_validation/v3b/calibration/<candidate>/physical_only.mat`
`.../physical_gate.json`

只保存 physical signals/commands/gates，不保存 estimator metrics table。

## 阶段 C：Tier 2 only if ALL Tier1 fail

先运行 historical F/G audit，再 programmatically inspect generated validation-copy connectivity。

目标不是改 source `.slx`，而是确认是否存在无歧义的 signed RL/RR longitudinal wheel-torque command route。

允许使用 `find_system`, `PortConnectivity`, line source/destination tracing；禁止 GUI automation。

如果不能无歧义确认 RL/RR command channels：

停止并输出：
`MANUAL_GUI_ACTION_REQUIRED`
然后只给最少人工识别步骤。

如果 route 可确认，新建 generated-copy-only brake override helper，例如：

`matlab/apply_vx_rear_brake_override_v3b.m`

要求：

- 只改 `results/vx_formal_validation/v3b/configured/...` validation copy；
- source `model/vx.slx` 不保存修改；
- 在 braking excitation 窗口只对 RL/RR signed longitudinal torque command 加/设负 torque；
- preserve absolute wheel torque command clamp `<=1600 Nm`；
- candidate magnitudes 固定为 `800 -> 1200 -> 1600 Nm`；
- stop at first physical PASS；
- candidate selection still forbidden from estimator metrics。

Tier2 使用 Tier1 中最温和且数值稳定的 speed braking profile `T1_2P5` 作为 speed reference，除非它无法完成仿真；不要同时扫描 speed duration 和 torque magnitude。

## 阶段 D：冻结第一条 physical PASS

第一条 combined physical PASS 后必须立即生成：

`results/vx_formal_validation/v3b/frozen_physical_excitation.json`

必须包括：

- selected tier/candidate
- exact speedTime_s/speed_kmh
- brakeRampEnd_s / brakeAnalysisEnd_s
- Tier2 时 exact RL/RR route/block/port + negative torque magnitude/timing
- PHYSICAL_CALIBRATION_SIM_COUNT
- calibration drive/brake sustained durations
- source/generated/control hashes
- `PHYSICAL_EXCITATION_FROZEN=YES`

生成后禁止继续 calibration，也禁止看到 formal estimator metrics 后修改该文件。

## 阶段 E：新建正式 V3B 执行层

### `matlab/configure_vx_formal_case_v3b.m`

只支持 `VX-CS`。

不得硬编码重新选择 candidate；必须读取并验证 `frozen_physical_excitation.json`，严格重建 frozen validation copy。

### `matlab/run_vx_formal_validation_v3b.m`

只支持 `VX-CS`。

- raw root = `results/vx_formal_validation/v3b/runtime/`
- pre-run verify source/control/freeze hashes
- sim 前写 formal commit record：`SIM_INVOCATION_COMMITTED=YES`
- exactly one fresh formal sim
- formal count contribution=1
- 保持 V3 R schema：`time/vxTrue/estU/estY/Ax/steerCommand/configuration`
- metadata 增加 `stage=VX-V3B`, `caseId=VX-CS`, freezeFileSha256
- 不得用 calibration raw 当 formal raw

### `matlab/analyze_vx_formal_validation_v3b.m`

只分析 formal `VX-CS`。

重新从 fresh formal raw 计算两个 kappa gate。fresh formal 中任一 gate FAIL：保存证据并停止，不回 calibration。

Estimator metrics 使用 V3 frozen definitions：overall + DRIVE_SLIP + BRAKE_SLIP + recoveries。

TABLE-02 必须有同一 VX-CS runtime 的两行：`DRIVE_SLIP`, `BRAKE_SLIP`。

## 阶段 F：最终论文资产

生成：

`results/vx_formal_validation/v3b/runtime/VX_TABLE_01_FINAL_representative_condition_performance.csv`
行：VX-ND, VX-ST, VX-CS

`results/vx_formal_validation/v3b/runtime/VX_TABLE_02_FINAL_combined_slip_recovery.csv`
行：DRIVE_SLIP, BRAKE_SLIP（都来自 VX-CS）

新建：
`results/vx_formal_validation/v3b/thesis_figures/plot_vx_v3b_fig02.m`

FIG-02 只在 formal VX-CS 两个 physical gates 都 PASS 时 export；3 panels：
1. Vx_true/WSS/IMU/Fusion
2. rho_RL/rho_RR
3. alpha_W/alpha_I
标出 3 s, 7 s, 9 s, frozen brakeRampEnd，以及 final recovery boundary。

FIG-01 继续使用已 accepted V3 ND raw；不重跑 ND。

生成 status：
`docs/STAGE_VX_V3B_COMBINED_SLIP_STATUS.md`

记录：V3 historical count=5、calibration sim count、V3B formal contribution、total formal count、selected excitation、fresh two gates、metrics、tables/figures、final acceptance。

## 禁止事项

- 不改 estimator/frozen parameters/physical gate thresholds；
- 不改 V3 raw/results；
- 不执行 V3A VX-DS；
- 不为了 RMSE 选择 calibration candidate；
- 不反复 formal run 到 PASS；
- 不自动 GUI；
- 不重新扫描仓库；
- 不回显长日志。

## 最终回复 <=20 行

只报告：
1. verdict
2. PHYSICAL_CALIBRATION_SIM_COUNT
3. selected Tier/candidate
4. calibration drive/brake gate durations
5. total FORMAL_RUNTIME_COUNT
6. formal VX-CS drive/brake gates
7. DRIVE/BRAKE mean alpha_W + detection/recovery key metrics
8. overall Fusion RMSE
9. TABLE-01/TABLE-02 paths
10. FIG-01/FIG-02 paths
11. blocker if any
12. READY_FOR_VX_FINAL_ACCEPTANCE=YES/NO
