# V2.6-A0 Covariance-Based Adaptive Fusion Architecture Audit

## Scope and read-only result

本阶段仅审计现有冻结 D/K/F 轨迹与 V2.5 fixed-fusion 接口。没有启动 MATLAB、Simulink 或 CarSim，没有运行 `sim()`，没有修改 `.m`、`.slx`、算法、权重、Q/R 或 P0/QF，也没有读取或复用 H01/H02/H03 数据。

相关当前文件 hash 已核对：

- `model/vx_vy_parallel_dk_v2_3.slx`：`98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0`
- `model/vx_vy_fixed_fusion_v2_5.slx`：`AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- `model/vy_dynamic_ekf_v1_17.m`：`5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0`
- `model/vy_kinematic_kf.m`：`F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4`
- `model/vy_feedback_propagation_step.m`：`80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF`
- `model/vy_fixed_weight_fusion_step.m`：`4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`

机器可读审计：`results/vy_covariance_adaptive_fusion_v2_6a0_architecture_audit.csv`。

## D-track audit

| 项目 | 实际事实 |
|---|---|
| 状态 | `x_D=[Vy_D;r_D]` |
| Vy 输出 | `y(1)=Vy_D`，单位 m/s |
| covariance | 后验完整 `P_D` 由 wrapper 输出嵌入 `y(46:49)`，并由并行/fixed-fusion tooling 提取为 `dekf_P_log` |
| Vy variance | 状态对齐位置为 `P_D(1,1)`，单位 (m/s)^2 |
| 速率 | prediction 与 r update 100 Hz；A20 Ay assimilation 每第五次，即 20 Hz |
| 初始化/生命周期 | persistent 为空或 mode 改变时 `x=[0;0]`、`P_D=0.1I2`；无外部 reset port |
| 特殊处理 | D step 有 PSD 对称化/投影和有限值回退；未引入自适应权重或 observability gate |

结论：`P_D(1,1)` 是实际模块输出中的 state-aligned candidate covariance，不是由标签猜测。

## K-track audit

| 项目 | 实际事实 |
|---|---|
| 状态 | `x_K=[Vx_K;Vy_K]` |
| Vy 输出 | `x_new(2)=Vy_K`，单位 m/s |
| covariance | wrapper 输出完整 2x2 `P_new/PState` |
| Vy variance | 状态对齐位置为 `P_K(2,2)`，单位 (m/s)^2 |
| 速率 | prediction 与 Vx measurement update 100 Hz |
| 初始化/reset | `resetFlag>0.5` 时 `x=[z_Vx;0]`、`P=diag([0.1,0.1])`，并处理当前样本 |
| 特殊处理 | 输入有限性断言、Joseph covariance update、对称化；低 yaw-rate 仅记录 covariance 演化，不增加 gate |

结论：`P_K(2,2)` 是实际 K wrapper 的 state-aligned candidate covariance。

## F-track audit

冻结 F-track 的实际数学为：

```text
prop_term = Ay_IMU - AVz_IMU*Vx_source
deltaVy   = Ts*prop_term
Vy_F      = Vy_base + deltaVy
P_F       = P_base + Q_F
```

其中 `P_F=Var(Vy_F)`，是标量 (m/s)^2；reset 时直接返回 `Vy_F0/P0_F`。V2.5 中 `feedback_valid_current` 固定为 false，F 仍 standalone；S-function 支持一采样延迟的 state/P/valid feedback，但 fixed-fusion 没有闭合该反馈。

`P_F` 在数学定义上可作为 Vy variance 参与 covariance-based fusion，且单位与 `P_D(1,1)`、`P_K(2,2)` 可比较。可是 `P0_F/Q_F` 仍是 TEST-ONLY/UNTUNED/UNFROZEN；不能在 A0 调整或把其测试数值解释为最终标定。已有 F runtime 证明了有限/非负，但没有提供可据此选择 epsilon/floor 的最终数值。

## Existing fusion interface

V2.5 fixed-fusion S-function 是无状态 100-Hz 三输入组合器：

```text
inputs:  Vy_D, Vy_K, Vy_F       (three scalar-double, m/s)
output:  Vy_FW                  (one scalar-double, m/s)
```

当前没有 covariance input、没有 `P_FW` output，`P_D/P_K/P_F` 只在各轨迹/日志边界存在，尚未送入 fusion layer。现有 fixed-fusion 必须保持不变。

## Minimum V2.6 interface addition (not implemented)

最小新 contract 应为同一 100-Hz current sample 的六个标量输入：

```text
Vy_D, P_D11, Vy_K, P_K22, Vy_F, P_F
```

建议输出：

```text
Vy_AF, alpha_D, alpha_K, alpha_F
```

`P_AF` 在 A0 不定义、不声称；若以后需要，必须另立统计设计。新增仅应在融合边界增加 covariance extraction/routing 和 adaptive combiner，不重构 D/K/F 内部。D/K/F 的 state、P、scheduler、reset 和 logs 保持独立。

## Covariance numerical audit

已有证据显示：

- D/K covariance 在接受的 parallel runtime/replay 中 finite、symmetric、正定下界为正；未观察到 NaN/Inf/负特征值。
- F covariance 在 standalone 语义中要求 finite、nonnegative，并按 `P_base+Q_F` 传播；可为零或非常小的输入在未来边界上不能排除。
- 可能存在初始化瞬态及量级差异：历史证据中 F 的 TEST-ONLY `P0_F=0.5`，而 D/K 的 accepted minimum eigenvalue 约为 `1e-4` 量级。该事实只说明必须做 scale/conditioning 审计，不授权任何 tuning。

因此，任何 inverse-covariance implementation 至少需要以下保护类别（A0 不选择数值）：

1. finite check，拒绝 NaN/Inf；
2. nonnegative check，拒绝负 covariance；
3. epsilon/floor，防止 zero 或极小 covariance 导致倒数爆炸；
4. normalization-denominator finite/nonzero protection；
5. 对极大/极小量级的稳定缩放或等价 overflow/underflow protection。

不应在本阶段加入 LifeSig、NIS、observability、residual reliability、maneuver hand-tuning、holdout tuning 或 true Vy。

## Architecture boundary and verdict

V2.6 当前允许的对象仅为 `Vy_D/Vy_K/Vy_F`、`P_D11/P_K22/P_F`、covariance-derived time-varying weights 及必要数值保护。V2.6 当前不允许 reliability subsystem 或第三反馈轨迹。

**READY_WITH_MINIMAL_INTERFACE_ADDITION**

理由：D/K/F 的 state-aligned covariance 已由现有实现输出，数学单位可比较；但现有 V2.5 fixed-fusion 输入没有 covariance，必须在 fusion 边界新增最小的三路 covariance 输入和 adaptive combiner contract。该新增尚未实施。

**READY FOR V2.6-A1 COVARIANCE FUSION FORMULATION**
