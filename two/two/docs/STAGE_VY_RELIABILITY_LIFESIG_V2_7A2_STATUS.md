# V2.7-A2 RELIABILITY SIGNAL ADEQUACY AUDIT

## 范围与证据边界

本阶段仅使用 A0/A1、D/K/F 冻结源码、既有 A3R1–A3R6 证据和五组非-holdout `FWCAL_C01R1/C02/C03/C04/C05` 结果文件。未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未获取新数据，未调 `r0/tau_F`，未修改模型、算法、Q/R 或 covariance mapping。

五个 FWCAL MAT 均有 0–16 s、100 Hz、`Vy_true` 对齐及 D/K/F 日志（包括 `dekf_diag_log`、`kkf_diag_log1`、F `P/diag`）。但当前冻结的机器可读汇总只保存了 covariance/error 和 A3R4 动态分箱结果，没有逐样本导出的 `NIS/measurementDimension/abs(r)/propagation_age` 与同拍 `e²` 配对表。本审计不在禁止 MATLAB 的条件下重新解码或制造这些统计量。逐项记录见 [`results/vy_reliability_lifesig_v2_7a2_signal_adequacy_audit.csv`](../results/vy_reliability_lifesig_v2_7a2_signal_adequacy_audit.csv)。

## 1. Timing / causality audit

### D-track

`vy_dynamic_ekf_step_v17` 在当前 hit 完成 prediction 后执行 yaw-only 或 Ay+r update，并在同一 hit 形成 innovation、`S` 和 NIS；wrapper 随后将 NIS、`useAy`、`measurementDimension`、`stepIndex`输出/记录。因而这些量原则上可由同一拍、位于 D 输出之后的 reliability consumer 因果使用。限制是 D core 的异常/无效路径会将 NIS 保持为 0，而 wrapper 没有独立 `update_valid/finite` 输出；仅凭 `NIS=0` 无法区分“低创新”与“无效更新”。这是 D reliability 的有效性接口 blocker。

### K-track

`vy_kinematic_kf_step` 在当前标量 Vx measurement update 中形成 innovation、`S`、NIS 和增益；wrapper 输出 `NIS`、`abs(r)`、innovation、K11/K21。因此同拍消费在调度上是 causal。`S` 和 update-valid/finite 状态未由 wrapper 明确输出，现有 evidence 也没有逐样本 NIS/`e²` 配对统计，故不能在 A2 证明 NIS 单独解释力或其与 `abs(r)` 的互补性。

### F-track

F 每个 100 Hz hit 只做传播，`P_F` 和 `feedbackApplied` 在同一输出形成；没有 measurement innovation/NIS。`propagation_age` 可根据 reset 和连续传播 step 离线重建，但当前 S-function 不输出 age 或 reset-valid echo，因此不能无歧义地在未来在线计算 `LifeSig_F=exp(-age*Ts/tau_F)`。这是明确的最小接口缺口，而不是要求为 F 发明 innovation。

## 2. Signal–error adequacy

### D

D 的信号形成时序和数学语义正确，但现有冻结汇总缺少同拍 `nu_D=NIS_D/measurementDimension` 与 `e_D²` 的 Pearson/Spearman、分箱及跨 maneuver 统计；同时 NIS=0 的 invalid ambiguity 未解决。因此 D signal-error adequacy：**NOT ESTABLISHED**。

### K

K 的 `NIS_K` 与 `abs(r)` 均为真实在线诊断，且形成时序 causal。现有 evidence 没有逐样本 paired adequacy 表，不能严谨判断：

- `NIS_K` 单独与 `e_K²` 的关系；
- `abs(r)` 单独与 `e_K²` 的关系；
- 二者是否提供互补信息。

历史 `abs(r)>0.01` 仍仅为诊断分区，未作为正式阈值或 `r0`。K signal-error adequacy：**NOT ESTABLISHED**。

### F

F 的 age 在离线 100 Hz/reset 语义下可重建。A3R4 已有的 F covariance-versus-error 分箱为：Pearson `0.9746880887`、Spearman `0.9999870043`，且 `P_F` 与 propagation count 线性递增；这支持 age-equivalent error risk 的稳定单调趋势。但该证据不是新增 A2 计算，也不能替代在线显式 age 输出。F signal-error adequacy：**PARTIAL OFFLINE SUPPORT; ONLINE AGE INTERFACE REQUIRED**。

## 3. Cross-maneuver / LifeSig parameter boundary

- 五组 calibration 时间轴和 truth alignment 已冻结一致；本阶段不使用 holdout。
- 没有设置临时人为阈值，也没有拟合 `epsilon`、`r0` 或 `tau_F`。
- 不使用 `Vy_AF` RMSE、调权、Q/R、P0_F/Q_F 或 maneuver-specific switching。
- `Vy_true` 仅为 offline adequacy reference；不得进入在线 LifeSig。

## 4. Overall verdict

现有 D/K 的 NIS、调度和 `abs(r)` 具备 causal formation，但 D/K 有效性上下文和逐样本 signal-error adequacy evidence 不完整；F 的离线 age-equivalent 关系较强，但在线 `propagation_age`/reset-valid 尚未成为接口。因此本阶段不能无条件接受 A1 LifeSig 规格进入参数识别。

**VERDICT: RELIABILITY_FORMULATION_REQUIRES_REVISION**

最小后续修订范围：导出 D/K 显式 valid/update context（或等价可靠重建证据），在不运行新模型的前提下明确 F age/reset signal contract；之后才能进行 A3 LifeSig 参数识别。不得在本阶段修改算法或运行时。
