# VX V3A Codex Execution Entry — VX-DS ONLY

本文件是下一阶段唯一执行入口。不要重新扫描项目，不要重跑 V3 已完成工况，不要再审计 historical G，不要尝试 VX-BL。

## 只读文件

先读且只读：

1. `AGENTS.md`
2. 本文件
3. `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`
4. `results/vx_formal_validation/v3a/VX_FORMAL_CASE_AMENDMENT_V3A.md`
5. `results/vx_formal_validation/v3a/runtime_contract_v3a.md`
6. `results/vx_formal_validation/v3a/case_handoff_v3a.json`
7. `matlab/configure_vx_formal_case_v3.m`
8. `matlab/run_vx_formal_validation_v3.m`
9. `matlab/analyze_vx_formal_validation_v3.m`

只有在实现新 V3A 脚本时，才读取上述模板直接引用的辅助函数/路径。禁止全仓扫描。

## 当前冻结事实

- V3 `FORMAL_RUNTIME_COUNT=5` committed，accepted raw results=3。
- `VX-ND` 已完成，禁止重跑。
- `VX-ST` 已完成，claim ceiling=`STEERING_DYNAMIC_VALIDATION`，禁止重跑。
- `VX-DR` 已完成且整体 physical gate FAIL，禁止重跑。
- DR acceleration gate PASS：RL/RR positive-slip sustained `1.906/1.906 s`，mean alpha_W `0.096373`，detection `0.008 s`，wheel recovery `0.838 s`。
- DR braking gate FAIL：RL/RR `0/0 s`，`NOT_DETECTED`。
- A20b-MU03 control 已被当前 V3 runtime 证明能产生 rear drive slip；没有证据证明同一 control 能产生 brake lock。
- V3A 论文正式低附机制工况改为 `VX-DS`；`VX-BL` 不授权。

不要在回复中复述已有 status/evidence 全文。

## 目标

新建独立 V3A 执行层，完成 **恰好一次** `VX-DS` current-version formal runtime，并生成最终论文代表表/机制表/FIG-02；同时从已接受的 V3 ND raw 生成 FIG-01。

不得为了 PASS 修改 estimator、冻结参数、物理门、窗口、速度 profile、mu token、源 `model/*.slx` 或 CarSim 源 dataset。

## 必须创建的文件

### 1. `matlab/configure_vx_formal_case_v3a.m`

不要修改或扩展 V3 configurator；以其当前实现为模板新建 V3A 文件，只支持 `VX-DS`。

必须保持：

- source model/estimator/parameter/wrapper 的冻结 SHA-256 校验与 V3 相同；
- validation-copy 策略；
- V3 已验证需要的 `disable_unused_duplicate_wheel_tags` workaround；
- zero-steering source replacement/logging；
- `Simulink.SimulationInput`；
- 不保存 `model/vx.slx`。

唯一 case：

```text
VX-DS
speedTime_s = [0;3;8;16]
speed_kmh   = [40;40;70;70]
steering    = 0
StopTime    = 16
reference unit = km/h
```

CarSim control 只用：

`results/vy_lifesig_v2_8a20b_mu03_diagnostic/carsim_control_MU03`

必须验证原始：

- `Run_all.par` SHA-256 = `8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8`
- `simfile.sim` SHA-256 = `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`
- copied `MU_ROAD_CONSTANT = 0.30`

生成目录改为：

`results/vx_formal_validation/v3a/configured/VX_DS/`

不要把 40/70 再除以 3.6；源模型 downstream Gain15 负责单位转换。

### 2. `matlab/run_vx_formal_validation_v3a.m`

以当前 V3 runner 为模板，但：

- 只接受 `VX-DS`；
- 调 `configure_vx_formal_case_v3a("VX-DS")`；
- runtime root = `results/vx_formal_validation/v3a/runtime/`；
- 保留现有 CarSim solver path、working-directory 切换、onCleanup、pre/post hash、SimulationOutput 信号提取与 N×18/N×38 对齐；
- `sim` 前写 `SIM_INVOCATION_COMMITTED=YES`；
- 只允许一条新的 formal `sim` invocation；
- metadata 增加 `stage='VX-V3A'`、`amendment='V3A'`、`caseId='VX-DS'`；
- raw = `VX_DS_formal_raw.mat`；
- raw `R` 接口保持 V3 figure-compatible：`time/vxTrue/estU/estY/Ax/steerCommand/configuration`；
- 完成后立即调用 V3A analyzer。

如果 raw/commit 已存在，禁止覆盖，直接停止报告。

### 3. `matlab/analyze_vx_formal_validation_v3a.m`

只接受 `VX-DS`。

固定窗口：

- overall `[0.60,16.00]`
- baseline `[0.60,3.00)`
- degradation `[3.00,8.00)`
- recovery `[8.00,16.00]`

物理门：

`kappa=(0.393*omega-Vx_true)/max(abs(Vx_true),1)`

RL/RR 各自在 `[3,8)` 持续 `kappa>=0.10` 至少 `0.10 s` 才 PASS。

指标沿用 V3 已实现定义：

- WSS/IMU/Fusion overall RMSE/MAE/MaxAbs/Bias；
- degradation WSS/IMU/Fusion RMSE；
- mean alpha_W / alpha_I；
- RL/RR sustained duration；
- detection response；
- wheel recovery，30 consecutive estimator updates；
- alpha_W recovery 90%/95%，30 consecutive updates；
- missing event 写 `NOT_DETECTED`/`NOT_REACHED`，禁止用窗口末端代替。

保存：

- `VX_DS_analysis.mat`
- `VX_DS_analysis.json`

不要修改 V3 的 ND/ST/DR raw 或 analysis。

### 4. 最终 TABLE-01

生成：

`results/vx_formal_validation/v3a/runtime/VX_TABLE_01_FINAL_representative_condition_performance.csv`

行顺序严格：

1. `VX-ND` — 读取现有 V3 `VX_ND_analysis.mat`
2. `VX-ST` — 读取现有 V3 `VX_ST_analysis.mat`
3. `VX-DS` — 读取新 V3A analysis

列：

`CaseId,WSS_RMSE,IMU_RMSE,Fusion_RMSE,Fusion_MAE,Fusion_MaxAbs`

不得再把 `VX-DR` 放入最终 thesis representative table；它继续保留为 failed combined-case evidence。

### 5. 最终 TABLE-02

生成：

`results/vx_formal_validation/v3a/runtime/VX_TABLE_02_FINAL_drive_slip_recovery.csv`

只记录 `VX-DS`：

- degradation WSS/IMU/Fusion RMSE
- mean alpha_W / alpha_I
- sustained RL/RR
- PhysicalGatePass
- DetectionResponse
- WheelRecovery
- AlphaWRecovery90/95

不再放 failed DR BRAKE 行，也不制造 brake-lock row。

### 6. `results/vx_formal_validation/v3a/thesis_figures/plot_vx_v3a_fig02.m`

不要改历史 `v3/.../plot_vx_v3_fig02.m`；它继续证明原 DR combined figure 被 gate 阻塞。

新 FIG-02：

- source raw: `v3a/runtime/VX_DS_formal_raw.mat`
- source analysis: `v3a/runtime/VX_DS_analysis.mat`
- 只有 `A.ds.physicalGatePass==true` 才允许 export；不要依赖 raw metadata 里事后回写 gate。
- 3行：
  1. `Vx_true / WSS / IMU / Fusion`
  2. `rho_RL / rho_RR` (`estY(:,18:19)`)
  3. `alpha_W / alpha_I` (`estY(:,30:31)`)
- xline = `3 s`、`8 s`
- title/scientific question 改为“低附着驱动滑移—恢复及自适应融合过程”
- header：`SOURCE_RUNTIME_CASE: VX-DS`、`SOURCE_RESULT_FILE: ...v3a...VX_DS_formal_raw.mat`
- 样式继承现有 FIG-02/Vy frozen style。
- export：PNG 600 dpi + vector PDF + SVG。

### 7. FIG-01

现有 V3 ND raw 已 accepted。直接执行：

`results/vx_formal_validation/v3/thesis_figures/plot_vx_v3_fig01.m`

生成 PNG/PDF/SVG。成功后只把脚本 header 的 `GENERATED_FROM_FORMAL_RUNTIME` 改为 `YES`，不要改数据源和版式。

### 8. status

生成：

`docs/STAGE_VX_V3A_DS_FORMAL_VALIDATION_STATUS.md`

必须记录：

- 原 V3 committed count=5；
- V3A 新 committed contribution；
- 总 committed count；
- accepted result count；
- VX-DS physical gate；
- DS metrics/recovery；
- ND/ST/DS final table path；
- FIG-01/FIG-02 paths；
- 明确 `BRAKE_LOCK_CURRENT_VERSION_FORMAL_VALIDATION = NOT_CLAIMED`；
- final acceptance 状态。

## 执行顺序

1. 静态确认 V3A 三份新说明文件一致；
2. 创建 V3A configure/runner/analyzer/FIG02；
3. MATLAB syntax/static check；
4. 调 configurator 一次做 configuration-only precheck，不计 runtime；
5. PASS 后只运行一次 `run_vx_formal_validation_v3a("VX-DS")`；
6. 分析物理门；
7. gate PASS 才生成 FIG-02；
8. 生成 final tables + FIG-01 + status；
9. 不运行 BL，不重跑 ND/ST/DR。

若 MATLAB/Simulink/CarSim 需要真正 GUI 操作，禁止自动 GUI，输出 `MANUAL_GUI_ACTION_REQUIRED` + 最少人工步骤。

## 最终回复 <=20 行

只报告：

1. verdict
2. total FORMAL_RUNTIME_COUNT
3. VX-DS physical gate + RL/RR sustained durations
4. degradation mean alpha_W
5. detection / wheel recovery / alpha90 / alpha95
6. WSS/IMU/Fusion degradation RMSE
7. overall Fusion RMSE
8. final TABLE-01 path
9. final TABLE-02 path
10. FIG-01 path
11. FIG-02 image + code path
12. `BRAKE_LOCK_CURRENT_VERSION_FORMAL_VALIDATION = NOT_CLAIMED`
13. `READY_FOR_VX_FINAL_ACCEPTANCE = YES/NO`
