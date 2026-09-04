# VX V3 Codex Execution Entry — FALLBACK CONFIGURATION

本文件是下一阶段唯一执行入口。不要重新扫描项目，不要重跑已完成的 VX-ND/VX-ST/VX-DR，不要复述已有 evidence。

## 只读这些

1. `AGENTS.md`
2. 本文件
3. `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`
4. `results/vx_formal_validation/v3/VX_FORMAL_CASE_MANIFEST_V3.md`
5. `results/vx_formal_validation/v3/runtime_contract.md`
6. `matlab/configure_vx_formal_case_v3.m`
7. `matlab/run_vx_formal_validation_v3.m`
8. `matlab/analyze_vx_formal_validation_v3.m`

只有为定位历史 G 型制动激励来源时，才允许定向读取与 `results_case_G` / historical-G-like brake/lock 直接相关的脚本或配置；禁止全仓扫描。

## 当前冻结事实

- `FORMAL_RUNTIME_COUNT = 5` committed；accepted raw results = `3`。
- `VX-ND = COMPLETE`，不得重跑。
- `VX-ST = COMPLETE`，rear-steering gate FAIL；claim ceiling = `STEERING_DYNAMIC_VALIDATION`，不得重跑。
- `VX-DR = COMPLETE / PHYSICAL_GATE_FAIL`，不得重跑。
- VX-DR acceleration gate PASS：RL/RR sustained `1.906/1.906 s`，mean alpha_W `0.096373`。
- VX-DR braking gate FAIL：RL/RR sustained `0/0 s`，`NOT_DETECTED`。
- 因为只有 braking gate 失败，`VX-DS` 不需要配置或运行。
- 下一步唯一授权 fallback：`VX-BL`。
- 冻结估计算法、参数、`model/*.slx`、CarSim 源数据集不得修改；禁止自动 GUI。

## 本阶段目标

只完成 `VX-BL` 的可追溯 fallback 配置；配置闭合后若能无 GUI、无冻结资产修改地执行，则允许执行 **恰好一次** VX-BL formal runtime，并完成分析/表图更新。

不要为了得到 PASS 改 estimator、门槛、窗口、轮胎半径或分析公式。

## VX-BL 预注册定义

- speed reference: `70 -> 40 km/h`
- `[0,3) s`: 70 km/h baseline
- `[3,8) s`: 70 -> 40 km/h smooth braking ramp
- `[8,16] s`: 40 km/h recovery plateau
- steering: zero
- low-mu control: `MU_ROAD_CONSTANT = 0.30`
- physical gate: RL/RR each sustain `kappa <= -0.10` for at least `0.10 s` inside `[3,8)`
- `kappa_i = (0.393*omega_i - Vx_true)/max(abs(Vx_true),1)`
- fixed windows: baseline `[0.60,3)`; brake-lock `[3,8)`; recovery `[8,16]`

## 先做最小 fallback provenance audit

VX-DR 已证明“仅把 mu=0.30 + 70->40 指令放入组合工况”没有形成后轮制动退化。因此不要直接盲跑 VX-BL。

只定向检查历史 G 相关本地资产，回答一个问题：

`是否存在可追溯、可复制到 validation copy 的 historical-G-like 制动/后轮锁定激励配置？`

允许检查：
- `tests/results_case_G.mat` 的 metadata/字段名，不把结果当 formal evidence；
- 明确引用 G / lock / brake / rear-wheel braking 的现有验证脚本；
- 与这些脚本直接引用的本地 CarSim/Simulink control/config 文件。

禁止：
- 从 G 的结果曲线反推并伪造控制输入；
- 修改源 CarSim dataset；
- 修改 `model/vx.slx`；
- 为寻找更强制动而大范围试参。

若找不到可追溯制动激励来源：停止并输出 `VX_BL_CONFIGURATION_BLOCKED_NO_TRACEABLE_BRAKE_SOURCE`。如果唯一缺口确实只能 GUI 完成，输出 `MANUAL_GUI_ACTION_REQUIRED` + 最少步骤。

## 若 provenance 闭合，最小修改执行层

只在允许路径中最小扩展现有代码：

1. `matlab/configure_vx_formal_case_v3.m`
   - 新增 `VX-BL`；
   - 保留现有 ND/ST/DR 行为不变；
   - 使用上面的固定速度 profile、zero steering、mu=0.30；
   - 仅把已审计的 historical-G-like braking excitation 复制/应用到 **generated validation copy**；
   - 不保存源模型/源 CarSim dataset。

2. `matlab/run_vx_formal_validation_v3.m`
   - 仅新增 VX-BL case 支持；
   - 保持 provenance、hash、工作目录、raw R 结构不变；
   - 只允许一次新的 VX-BL formal `sim` invocation。

3. `matlab/analyze_vx_formal_validation_v3.m`
   - 仅新增 VX-BL 固定窗口/物理门/退化恢复指标；
   - 不改变已有 ND/ST/DR 结果。

## VX-BL runtime 后判定

若 braking physical gate PASS：
- `VX-BL = COMPLETE / PHYSICAL_GATE_PASS`
- 使用 VX-BL 的 braking/recovery 行替换 TABLE-02 中失败的 VX-DR BRAKE 行；VX-DR ACCEL 行继续保留。
- FIG-02 不再要求“VX-DR 两个 gate 同时 PASS”；改为基于正式证据组合展示：drive-slip 机制来自 VX-DR acceleration，brake-lock 机制来自 VX-BL。若单图无法清楚呈现两个 source case，则保持 FIG-02 为 drive-slip/recovery 主图，并把 VX-BL 作为表格/补充证据，不强行拼图。
- 更新 thesis figure manifest 和 status。

若 VX-BL physical gate FAIL：
- 保存真实正式证据；
- 不重跑、不调门槛、不调估计器；
- verdict = `VX_BL_PHYSICAL_GATE_FAIL`
- `READY_FOR_VX_FINAL_ACCEPTANCE = NO`

## FIG-01

ND 已 accepted。FIG-01 现在可以直接从 `VX_ND_formal_raw.mat` 生成，不受 DR braking gate 失败影响。若绘图执行环境可用，本阶段应生成 FIG-01 PNG/PDF/SVG，并把脚本头部 `GENERATED_FROM_FORMAL_RUNTIME` 更新为 `YES`。

## 最终回复 <=20 行

只报告：
1. verdict
2. FORMAL_RUNTIME_COUNT
3. VX-BL provenance source
4. VX-BL configuration status
5. 若运行：braking physical gate + sustained durations
6. 3-6 个关键指标
7. TABLE-02 更新状态
8. FIG-01 状态
9. FIG-02 状态
10. blocker（若有）
11. `READY_FOR_VX_FINAL_ACCEPTANCE = YES/NO`
