# V2.7-A0 RELIABILITY / LIFESIG / OBSERVABILITY / NIS 架构审计

## 范围与完整性

本阶段仅做源码和既有冻结证据的只读审计；未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未修改模型、D/K/F、Q/R、P0_F/Q_F 或 fusion 实现。A3R6 的结论 `COVARIANCE_ONLY_CONFIDENCE_INADEQUATE` 保持不变。

本次核对的主要源码哈希（SHA-256）：

| 文件 | SHA-256 |
|---|---|
| `model/vy_dynamic_ekf_v1_17.m` | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` |
| `model/vy_dynamic_ekf_step_v17.m` | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` |
| `model/vy_dynamic_ekf_step_v13.m` | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| `model/vy_feedback_propagation_simulink_sfun.m` | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` |
| `model/vy_fixed_weight_fusion_simulink_sfun.m` | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30` |
| `model/vy_fixed_weight_fusion_step.m` | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` |

## D/K/F 现有在线信号事实

### D-track

- 状态为 `[Vy; r]`。wrapper 每个调用保持 persistent `x/P`，100 Hz 基础调用；Ay 更新由 `modeCode`/`useAy`/`measurementDimension` 表示的调度决定。
- `P_D11=P(1,1)` 已由输出 `y(3)`提供。当前输出还含创新 `y(14:15)`、创新协方差矩阵日志 `y(38:41)`、NIS `y(5)`及 `y(64:65)`、增益/预测协方差和 `useAy/stepIndex/modeCode/measurementDimension`。
- 这些是可在线消费的诊断量，不等于已实现 LifeSig 或 reliability gate。由于 yaw-only 调用会保留未使用分量的占位值，NIS 必须结合 measurement dimension/validity 解释。

### K-track

- 状态为 `[Vx; Vy]`，每次 wrapper 调用执行预测和标量 Vx 更新；resetFlag>0.5 时以 `[z;0]` 和 `diag([0.1,0.1])`初始化。
- `P_K22=P_new(2,2)`由 wrapper 输出。`diag_out=[NIS; abs(r); innovation_Vx; K11; K21]`，因此 NIS、创新、`abs(r)`（既有低 yaw 诊断）和增益均可在线取得。
- 核心计算的标量创新协方差 `S` 尚未由 wrapper 输出；若未来 reliability 需要直接复核 NIS 分母，最小接口增加为输出 `S_K` 或明确的 update-valid/finite 标志。现有 `obs_flag=abs(r)>0.01`仅为诊断，不是本阶段 observability gate。

### F-track

- standalone recurrence 为 `Vy_F = Vy_base + Ts*(Ay_IMU-AVz_IMU*Vx_source)`、`P_F=P_base+Q_F`；reset 返回 `Vy_F0/P0_F`，并将 feedback memories 清零。
- S-function 输出 `Vy_F`、标量 `P_F` 和 `diag_F=[prop_term; deltaVy; feedbackApplied]`。反馈三元组在 boundary 处使用一采样延迟，当前 `feedback_valid`/`feedbackApplied` 可在线识别。
- F 无测量更新，故没有 measurement innovation 或 NIS；不能为了 reliability 凭空制造 truth-free innovation。传播 age 和显式 reset/initialization-valid 尚未输出，若 A1 需要基于 age/reset 的可靠性保护，属于最小接口增加。
- 已知 `P0_F_FROZEN=0` 与当前 F core `P0_F>0` 契约冲突仍是既有 implementation-contract blocker；本阶段没有修改。

## 候选 reliability 信号分类

完整逐项清单见 [`results/vy_reliability_lifesig_v2_7a0_architecture_audit.csv`](../results/vy_reliability_lifesig_v2_7a0_architecture_audit.csv)。核心分类如下：

| 对象 | 已在线可得 | 最小接口增加 | 新算法/禁止在线使用 |
|---|---|---|---|
| D | `P_D11`、innovation、`S`日志、NIS、`useAy/measurementDimension/stepIndex` | explicit finite/update-valid | `Vy_true`、maneuver/holdout ID |
| K | `P_K22`、Vx innovation、NIS、`abs(r)`、K11/K21 | `S_K`及 reset/update-valid（若需无歧义消费） | `Vy_true`、maneuver/holdout ID |
| F | `P_F`、propagation diagnostics、feedbackApplied | propagation age、reset-valid echo | measurement innovation/NIS（当前模型不适用） |

`Vy_true`、maneuver ID 和 holdout-derived switching 明确属于 `OFFLINE_TRUTH_ONLY_NOT_ALLOWED`，不能进入在线 reliability。

## 现有 LifeSig/NIS/reliability 实现审计

- 源码中没有启用的 LifeSig、残差可靠性、权重切换或第三反馈轨迹。
- D/K 的 NIS 是已有数值诊断；K 的 `obs_metric/obs_flag` 是 `abs(r)`诊断。二者目前都没有形成 LifeSig、NIS gate、权重选择或 estimator-to-estimator coupling。
- F 只有传播/反馈应用诊断，无 NIS。V2.6 `P_AF=NOT_DEFINED`保持不变。

## 最小、因果的 V2.7 reliability signal contract（仅规格候选）

未来 A1 可在不重构 D/K/F 的前提下，接收：

```text
D: Vy_D, P_D11, innovation_D, S_D(or NIS_D), D_update_valid, D_measurement_dimension
K: Vy_K, P_K22, innovation_K, S_K(or NIS_K), K_update_valid, K_obs_metric, K_reset_valid
F: Vy_F, P_F, F_feedbackApplied, F_reset_valid, F_propagation_age
```

其中 `S_K`、D/K/F 的显式 valid/reset/age 信号是最小接口增量候选，而不是本阶段实施内容。后续 logic 必须只使用当前或历史样本（causal），不得读取 `Vy_true`、maneuver ID、holdout 结果或未来样本。输出应先限定为每轨迹数值有效性/可靠性诊断；LifeSig/NIS/observability 公式和门限需在后续独立阶段冻结。

## 架构结论

现有 D/K 已具备 covariance、innovation、NIS 和调度相关诊断，F 具备 covariance、传播/反馈应用状态但不具备测量创新（这是其 standalone 数学性质）。因此不存在阻止下一阶段“规格冻结”的架构缺口；仅需在 A1 明确最小 valid/reset/age 端口，且不改变估计器数学。

**VERDICT: READY_FOR_V2.7_A1_RELIABILITY_FORMULATION**

该结论不表示已实现 LifeSig、NIS gate 或 observability gate，也不表示任何 runtime 性能验收。V2.6 的 covariance-only confidence inadequacy、F 的 P0_F contract blocker 继续保留。

**READY FOR V2.7-A1 RELIABILITY FORMULATION**
