# V2.6-A2 F-track Covariance Base-Source Readiness Audit

## 范围与结论

本阶段为只读审计。未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未修改任何 `.m`/`.slx`、权重、Q/R 或 `P0_F/Q_F`，未读取 H01/H02/H03。机器可读证据为 `results/vy_covariance_adaptive_fusion_v2_6a2_f_track_readiness_audit.csv`。

**VERDICT = READY_FOR_F_COVARIANCE_PARAMETER_IDENTIFICATION**

该 verdict 仅表示 F-track 协方差参数可以进入独立识别阶段；不表示 `P0_F/Q_F` 已冻结，也不表示三轨迹 adaptive runtime 已可实施。

## 1. F-track 实际 recurrence

冻结 core `model/vy_feedback_propagation_step.m` 的输入包含当前 IMU/速度源、上一 F 状态/协方差、延迟反馈三元组和 reset。每个非 reset hit 的实际计算为：

```text
prop_term = Ay_IMU - AVz_IMU*Vx_source
deltaVy   = Ts*prop_term
Vy_F      = Vy_base + deltaVy
P_F       = P_base + Q_F
diag_F    = [prop_term; deltaVy; feedbackApplied]
```

`feedback_valid_delayed == false` 时：

```text
Vy_base = Vy_prev
P_base  = P_prev
```

`feedback_valid_delayed == true` 时，core 要求延迟 state/P 有限且协方差非负，然后使用：

```text
Vy_base = Vy_feedback_delayed
P_base  = P_feedback_delayed
```

`reset == true` 无条件返回：

```text
Vy_F = Vy_F0
P_F  = P0_F
diag_F = [0;0;0]
```

S-function `model/vy_feedback_propagation_simulink_sfun.m` 持有五个标量 double DWork：`Vy_prev`、`P_prev`、`Vy_feedback_z1`、`P_feedback_z1`、`feedback_valid_z1`。输入 4/5/6 的 feedback state/P/valid 为 non-direct-feedthrough；Update 在非 reset hit 原子捕获当前三元组，下一 hit 作为一采样延迟使用。reset 会清空 delayed triplet。该结构明确要求 state、P、valid 使用同一 z^-1 语义，不存在 current-sample algebraic loop。

## 2. Frozen architectural intent

V2.4-E 冻结记录把 delayed fusion feedback 定义为“未来 separately authorized”的闭环选项；当前 V2.5 fixed fusion 中 `feedbackApplied` 保持为 0，F-track 是 standalone。因而 delayed feedback **不是当前 standalone/A1 的强制接口**。只有未来明确选择闭环反馈时，才需要把反馈三元组接入 F-track。

## 3. A1 contract 完整性

A1 已冻结的 standalone 最小 contract 为同一 100-Hz sample 的六个标量输入：

```text
Vy_D, P_D11, Vy_K, P_K22, Vy_F, P_F
```

输出为：

```text
Vy_AF, alpha_D, alpha_K, alpha_F
```

可选 `fusion_numeric_valid` 仅用于数值诊断；`P_AF = NOT_DEFINED`。

如果未来单独授权 fusion feedback，`Vy_feedback_source` 可以定义为 `z^-1(Vy_AF)`，但这是闭环架构新增内容。由于 A1 明确不定义 `P_AF`，当前不存在可供 F 使用的 `P_feedback_source`。因此“延迟融合反馈闭环”本身会被 uncertainty contract 阻塞；这不阻塞当前允许的 standalone covariance identification。

## 4. 当前 P0_F/Q_F 状态

实际检查到的 validation/test 值为：

```text
P0_F = 0.5
Q_F  = 0.0025 (m/s)^2/step
```

它们出现在 `build_vy_feedback_track_v2_4c.m`、`build_vy_feedback_track_v2_4d0_runtime_interface.m`、`run_vy_feedback_track_v2_4d2_reset_fix.m` 以及 V2.5 非 holdout calibration runner/audit 参数中。所检查文件未发现不一致的第二组值。

V2.4-E 明确将这两个数值标为 validation TEST-ONLY，并排除在 design-parameter freeze 之外；V2.5 C01R1 记录同样标记 `UNTUNED / UNFROZEN`。没有正式 calibration/freeze evidence。因此本阶段不把它们升级为正式参数，也不调参。

## 5. Calibration-data readiness

非 holdout 的 `results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat` 及其 57-gate acquisition/integrity 记录提供了未来离线识别所需的同轴数据：

- `fusion_vy_f_log` / `dataset.F.Vy`：F-track state；
- `vy_true_log1` / `dataset.Vy_true`：真实 Vy，仅 offline；
- reset、`fusion_f_P_log`、`fusion_f_diag_log` 及 `feedbackApplied`：可定位 propagation step 和反馈状态；
- 1601 个 0–16 s、100-Hz 对齐样本，平均 `dt = 0.01 s`；
- `FWCAL_C01R1` maneuver identity、预注册条件和完整 truth alignment 元数据。

该记录状态为 `ELIGIBLE_CALIBRATION_DATA`，且没有查看或使用 holdout。故：

```text
CALIBRATION_DATA_READINESS = DATA_READY
```

这只是数据可用性判断，不执行拟合。

## 6. 数值与边界说明

`P_F` 在数学定义上是标量 `Var(Vy_F)`，单位与 `P_D(1,1)`、`P_K(2,2)` 相同，可作为 A1 covariance input。core 已对有效反馈协方差执行 finite/nonnegative 检查；A1 的 epsilon floor、finite check、非负检查和归一化保护保持不变。本阶段不选择 epsilon 数值、不引入 LifeSig/NIS/observability/reliability，也不声称严格 BLUE 或 statistically optimal fusion。

## 7. 状态与下一步

```text
COVARIANCE_FUSION_FORMULATION       = READY
THREE_TRACK_RUNTIME_IMPLEMENTATION  = BLOCKED_PENDING_F_COVARIANCE_FREEZE
VERDICT                              = READY_FOR_F_COVARIANCE_PARAMETER_IDENTIFICATION
```

阻塞原因仅为 `P0_F/Q_F` 尚未形成独立、可追溯的正式冻结值；这不是 core recurrence 歧义，也不是 calibration data 缺失。下一阶段可进行受约束的 F covariance 参数识别，但仍不得在本阶段修改或调参。

## 冻结完整性

| 文件 | SHA-256 |
|---|---|
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| `model/vy_feedback_propagation_simulink_sfun.m` | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` |
| `model/vx_vy_feedback_track_v2_4.slx` | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` |
| `model/vx_vy_feedback_track_v2_4d_runtime.slx` | `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A` |
| `results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat` | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` |

## 最终状态

**READY FOR V2.6-A3 F-TRACK COVARIANCE PARAMETER IDENTIFICATION**
