# V2.7-A1 RELIABILITY / LIFESIG FORMULATION FREEZE

## 范围

本阶段仅冻结 LifeSig 数学规格并核对现有 D/K/F 信号语义。未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未修改任何 `.m`、`.slx`、Q/R、P0_F/Q_F 或 fusion 实现，也未引入 H01/H02/H03 数据。

依据：V2.7-A0 架构审计、冻结 D/K/F core/wrapper 及 V2.6 covariance evidence。逐项审计记录见 [`results/vy_reliability_lifesig_v2_7a1_formulation_audit.csv`](../results/vy_reliability_lifesig_v2_7a1_formulation_audit.csv)。

## 冻结的 LifeSig 规格

### D-track

```text
nu_D       = NIS_D / measurementDimension
R_D_NIS    = min(1, 1 / max(nu_D, epsilon))
LifeSig_D  = R_D_NIS
```

`measurementDimension` 与 `NIS_D` 已由 D wrapper 的诊断输出提供（100 Hz 基础调用，Ay 更新时为二维、其他时为 yaw-only 维度）。`epsilon` 必须严格为正，但本阶段不指定数值、不调参。

语义前提：只有当前 hit 的 update/finite 状态有效时才消费该公式；D core 在无效或异常路径可能将 NIS 置零，因此后续接口必须提供或可靠重建 `D_update_valid`，避免把无效 NIS=0解释为高可靠度。这是有效性前提，不是新增 LifeSig 算法。

### K-track

```text
nu_K       = NIS_K
R_K_NIS    = min(1, 1 / max(nu_K, epsilon))
R_K_obs    = abs(r) / (abs(r) + r0)
LifeSig_K  = R_K_NIS * R_K_obs
```

K wrapper 的 `diag_out(1)`为 Vx NIS，`diag_out(2)`为 `abs(r)`，因此候选公式与现有量的物理语义一致。`r0>0` 严格为正但未冻结；历史 `abs(r)>0.01` 仅是诊断分区阈值，明确不复用为正式 `r0`。K 的 update-valid/finite 上下文仍应在 A2 复核或以最小接口补充。

### F-track

```text
t_age      = propagation_age * Ts
LifeSig_F  = exp(-t_age / tau_F)
```

`tau_F>0` 严格为正但未冻结。F 当前 standalone 只提供 `P_F` 和 `diag_F=[prop_term; deltaVy; feedbackApplied]`，没有显式 `propagation_age` 或 reset-valid 输出；因此公式本身与传播语义一致，但实现该公式需要一个最小、因果的 `propagation_age`（以及用于初始化保护的 reset-valid）边界信号。不得用 `Vy_true`、误差或未来样本替代 age。

## 数学与边界性质

- 对 `epsilon>0`、`r0>0`、`tau_F>0` 且有效输入满足定义域时，三条 `LifeSig_i` 均位于 `[0,1]`：D/K 由截断和非负 NIS 保证，K 的观测项在 `[0,1)`，F 的指数项在 `(0,1]`。
- 不引入 smoothing、时间窗、滞回或任何未冻结的门限；不定义最终 fusion weights。
- raw covariance 不直接进入 LifeSig 公式；`P_AF = NOT_DEFINED` 保持不变。
- 该规格不是 statistically optimal/BLUE 证明，也不是 NIS/LifeSig 性能验收。

## 在线因果性与排除项

未来实现只能使用当前或历史 estimator 信号：D/K 当前 hit 的 NIS、测量维度、有效性和 `abs(r)`，F 当前/历史传播 age、reset-valid、feedbackApplied。禁止：

- 在线 `Vy_true`；
- maneuver ID、holdout 结果或 holdout-derived switching；
- 未来样本、非因果平滑/窗口；
- residual-based truth comparison；
- Q/R、P0_F/Q_F、fixed weights 调整；
- LifeSig 与 observability/NIS gate、fusion weight 或第三反馈轨迹的提前耦合。

## 参数与既有 blocker

本阶段未冻结 `epsilon`、`r0`、`tau_F`。F-track 既有状态仍为：

```text
P0_F_FROZEN = 0
Q_F_FROZEN  = 0.000525656083041383 (m/s)^2/step
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

不得在 A1 修改 `model/vy_feedback_propagation_step.m` 或其 S-function；上述 P0_F contract blocker 原样保留。

## 架构判定

候选公式与 D/K/F 的物理语义没有数学冲突。现有接口的两个已知边界是：D/K 需要显式有效性上下文以区分无效 NIS=0，F 需要最小因果 `propagation_age`/reset-valid 信号才能实际计算 `LifeSig_F`。这些属于后续 signal-adequacy/interface 工作，不授权在本阶段实现。

**ARCHITECTURE VERDICT: READY_FOR_V2.7_A2_RELIABILITY_SIGNAL_ADEQUACY_AUDIT**

**READY FOR V2.7-A2 RELIABILITY SIGNAL ADEQUACY AUDIT**
