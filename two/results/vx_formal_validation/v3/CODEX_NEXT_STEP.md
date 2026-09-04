# VX V3 Codex Execution Entry — CURRENT

本文件是下一阶段唯一执行入口。不要重新扫描项目，不要复述已有 status/evidence，不要重新设计工况。

## 只读这些

先读：
1. `AGENTS.md`
2. 本文件
3. `results/vx_formal_validation/v3/case_handoff.json`
4. `results/vx_formal_validation/v3/runtime_contract.md`
5. `matlab/configure_vx_formal_case_v3.m`
6. `results/vx_formal_validation/v3/thesis_figures/plot_vx_v3_fig01.m`

`VX_FORMAL_CASE_MANIFEST_V3.md` 仅在 VX-DR 物理门失败、需要确认 fallback 预注册信息时再读。

## 当前已闭合

- `FORMAL_RUNTIME_COUNT = 0`
- `matlab/configure_vx_formal_case_v3.m` 已存在；不要重写，除非实际执行发现纯执行层 bug。
- 主工况固定：`VX-ND -> VX-ST -> VX-DR`
- 冻结算法/参数、`model/*.slx`、CarSim 源数据集不得修改。
- 速度参考单位为 `km/h`，不要再除以 `3.6`。
- GUI setup = `NO`；禁止自动 GUI。

## 第一门：本地依赖预检（先做，避免浪费 token）

只检查以下 4 个本地文件是否存在；GitHub 当前未镜像这些 CarSim control 源文件，因此“GitHub不存在”不算阻塞：

- `results/vy_lifesig_v2_8a20_limited_cross_condition/carsim_control_C1/simfile.sim`
- `results/vy_lifesig_v2_8a20_limited_cross_condition/carsim_control_C1/Run_all.par`
- `results/vy_lifesig_v2_8a20b_mu03_diagnostic/carsim_control_MU03/simfile.sim`
- `results/vy_lifesig_v2_8a20b_mu03_diagnostic/carsim_control_MU03/Run_all.par`

若本地也缺失，立即停止，输出 `VX_V3_LOCAL_CONTROL_SOURCE_MISSING` + 缺失路径；不要从历史 MAT 重建，不要搜索整个仓库。

若存在，直接执行配置预检：

```matlab
addpath(fullfile(pwd,'matlab'));
[~,cND] = configure_vx_formal_case_v3("VX-ND");
[~,cST] = configure_vx_formal_case_v3("VX-ST");
[~,cDR] = configure_vx_formal_case_v3("VX-DR");
```

配置脚本自身会校验冻结 source/control SHA-256。哈希不匹配时不要改冻结哈希，直接报告阻塞。

## 需要创建的执行层文件

仅创建/修改允许路径：

- `matlab/run_vx_formal_validation_v3.m`
- `matlab/analyze_vx_formal_validation_v3.m`
- `results/vx_formal_validation/v3/thesis_figures/plot_vx_v3_fig02.m`
- `results/vx_formal_validation/v3/thesis_figure_manifest.md`
- `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`

如 configurator 仅有执行性问题，可最小修改 `matlab/configure_vx_formal_case_v3.m`；不得改变预注册 profile、物理门、冻结参数或源模型。

## Runner 最小合同

`run_vx_formal_validation_v3(caseId)` 只支持 `VX-ND/ST/DR`，并必须：

1. 调用 configurator，使用其 `cfg.generatedModel` 和 `cfg.runtimeWorkingDirectory`；
2. 用完整路径 `load_system(cfg.generatedModel)`；
3. `sim` 前切换到 `cfg.runtimeWorkingDirectory`，用 `onCleanup` 保证恢复原目录；不要假设 CarSim 会从仓库根目录找到 `simfile.sim`；
4. `sim` 前写 case-specific provenance，包含 `SIM_INVOCATION_COMMITTED=YES`、case、时间、profile、source/generated hashes；
5. 只调用一次正式 `sim(simIn)`；
6. 从 `SimulationOutput` 直接取得 `Vx_true_log`、`est_u_log`、`est_y_log`、`vx_v3_steer_command_log`；缺信号就报错，不得离线伪造；
7. 对齐到估计器时间轴并保存 scalar `R`：
   - `R.metadata.formalRuntime=true`
   - `R.metadata.caseId`
   - `R.time`
   - `R.vxTrue`
   - `R.estU` (N×18)
   - `R.estY` (N×38)
   - `R.Ax = R.estU(:,9)`
   - `R.steerCommand`
   - `R.configuration=cfg`
8. 保存 `runtime/<CASE>_formal_raw.mat`、metadata JSON、简短 log、post-run hashes；
9. 立即调用 analyzer，确认该 case 数据完整后再进入下一个主工况。

不要用 A-H/Vy 结果替代 V3 runtime。

## Analyzer 最小合同

严格使用 `runtime_contract.md` 的固定窗口/指标：

- 所有主工况：WSS/IMU/Fusion 的 RMSE、MAE、MaxAbs、Bias；论文 TABLE-01 保留 WSS/IMU/Fusion RMSE + Fusion MAE/MaxAbs。
- `VX-ST`：从 `R.estU(:,5:8)` 检查实际四轮转角；只有 RL/RR 有真实动态响应时才标记 `4WIS_REAR_STEERING_VALIDATION`，否则最高只能 `STEERING_DYNAMIC_VALIDATION`。
- `VX-DR`：用 `Rw=0.393`、`R.estU(:,1:4)` 和 `R.vxTrue` 计算 kappa；加速 `[3,7)` 与制动 `[9,13)` 分别执行预注册持续 0.10 s 物理门，并计算退化/恢复指标形成 TABLE-02。
- 未达到事件必须写 `NOT_DETECTED` / `NOT_REACHED`，不得用窗口末端代替。

## Fallback 边界

当前 configurator 明确只支持 `VX-ND/ST/DR`。因此本阶段**不要运行 `VX-DS/BL`**。

- VX-DR 两个物理门都 PASS：fallback = `NOT_REQUIRED`。
- 任一物理门 FAIL：保存完整 DR 正式证据，状态写 `VX_DR_PHYSICAL_GATE_FAIL` 和 `READY_FOR_VX_FALLBACK_CONFIGURATION=YES`，然后停止；不要自行扩展 configurator 或重跑更“好看”的 DR。

## 图表输出

接受的正式 runtime 后生成：

- `runtime/VX_TABLE_01_representative_condition_performance.csv`
- `runtime/VX_TABLE_02_degradation_recovery_dynamics.csv`
- `thesis_figures/VX_FIG01_normal_dynamic_estimation.{png,pdf,svg}`
- `thesis_figures/VX_FIG02_degradation_recovery_fusion.{png,pdf,svg}`（仅当 DR 对应物理门允许机制展示）

每张图必须保留对应 `.m`。绘图脚本头部和 `thesis_figure_manifest.md` 必须写明 figure ID、source case/result、scientific question、status；成功从正式 MAT 生成后把 `GENERATED_FROM_FORMAL_RUNTIME` 标为 `YES`。

FIG-01 已存在，不要重写版式，只让 runner 的 `R` 结构与其输入合同一致。FIG-02 建议 3 行：Vx True/WSS/IMU/Fusion；rho_RL/rho_RR；alpha_W/alpha_I。

## 执行顺序

依赖预检 PASS -> 配置预检 PASS -> 创建 runner/analyzer/FIG-02 -> `VX-ND` -> `VX-ST` -> `VX-DR` -> 表/图/status。

ND/ST 接受后不要等待用户确认。只有真正 GUI-only 阻塞时输出：

`MANUAL_GUI_ACTION_REQUIRED`

并给最少人工步骤；禁止自动 GUI。

## 最终回复 <=20 行

只报告：
1. verdict
2. FORMAL_RUNTIME_COUNT
3. ND/ST/DR 状态
4. ST rear-steering gate
5. DR accel/brake gates
6. 3-8 个关键指标
7. fallback = NOT_REQUIRED / NEEDS_CONFIGURATION
8. TABLE-01/TABLE-02 路径
9. FIG-01/FIG-02 图片+代码路径
10. blocker（若有）
11. `READY_FOR_VX_FINAL_ACCEPTANCE = YES/NO`
