# V2.6-A1 Covariance Fusion Formulation Freeze

## Scope

本阶段只冻结 covariance-based adaptive fusion 的数学规格、数值保护和接口边界。未实现任何 `.m/.slx`，未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未调整 fixed weights、Q/R、P0_F/Q_F，也未使用 H01/H02/H03 数据。

## State-aligned covariance inputs

```text
P_D = P_D11 = P_D(1,1)
P_K = P_K22 = P_K(2,2)
P_F = P_F
```

三者均为 Vy 方差，单位 `(m/s)^2`。D/K/F 的实际输出接口和状态定义已在 A0 审计中确认。

## Normal adaptive weighting (frozen formulation)

对 `i ∈ {D,K,F}`，定义：

```text
valid_i = isfinite(Vy_i) && isfinite(P_i) && (P_i >= 0)

P_eff_i = max(P_i, epsilon_P),  if valid_i
score_i  = P_ref / P_eff_i,      if valid_i
score_i  = 0,                    otherwise
```

其中 `epsilon_P` 为严格正的数值 floor；A1 只冻结其作用和量纲，不从 holdout 选择数值。

当至少存在一个 valid track：

```text
P_ref  = min(P_eff_i over valid tracks)
alpha_i = score_i / sum_j(score_j)
Vy_AF  = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

因为公共 `P_ref` 在归一化时约去，该形式数学上等价于 normalized inverse-covariance weighting，但避免直接计算 `1/P_i` 所造成的 overflow/underflow 风险。有效时必有：

```text
alpha_i >= 0
sum(alpha_i) = 1
```

无效轨迹的 score 和 alpha 均为零；不以饱和、替换 state 或隐式重算 covariance 修复无效输入。

## Numerical fallback

若不存在任何 valid covariance/state pair，normal covariance weighting 不可用，使用既有 V2.5 fixed-weight baseline 作为 numerical fallback：

```text
alpha_D = 0.9004680917645591
alpha_K = 0.09953190823544089
alpha_F = 0
```

该 fallback 仅是数值保护，不是 LifeSig、reliability logic 或 performance tuning。若所有 `Vy` state 本身均 nonfinite，只记录需要纯 diagnostic validity indication；A1 不定义更复杂的恢复或降级算法。

## Scientific interpretation boundary

正式名称冻结为：

**INVERSE-COVARIANCE CONFIDENCE WEIGHTING**

不得声称严格 statistically optimal fusion 或 BLUE，因为 D/K/F 共享部分 measurement/process information，cross-covariance 未建模。

```text
P_AF = NOT_DEFINED
```

不得使用简单 inverse-covariance sum 声称真实 fused covariance，也不得把 `P_AF` 作为当前输出。

## Candidate signal contract

最小输入（同一 100-Hz current sample，均为 scalar double）：

```text
Vy_D, P_D11, Vy_K, P_K22, Vy_F, P_F
```

候选输出：

```text
Vy_AF, alpha_D, alpha_K, alpha_F
```

可选 `fusion_numeric_valid` 仅用于数值诊断；不得扩展为 LifeSig 或 reliability subsystem。D/K/F 内部 state、P、scheduler、reset 和日志保持不变。现有 V2.5 fixed-fusion 不修改。

## F-track dependency

本地 F-track 冻结证据明确：

- `P_F=Var(Vy_F)` 的数学定义和传播语义已接受；
- `P_F=P_base+Q_F`，reset 时为 `P0_F`；
- `P0_F=0.5`、`Q_F=0.0025 (m/s)^2/step` 仅为 validation TEST-ONLY 值；
- `P0_F/Q_F` 仍为 `UNTUNED / UNFROZEN`。

因此：

```text
COVARIANCE_FUSION_FORMULATION = READY
THREE_TRACK_RUNTIME_IMPLEMENTATION = BLOCKED_PENDING_F_COVARIANCE_FREEZE
```

原因是 `P_F` 将直接影响 `alpha_F`；在正式三轨迹 adaptive runtime implementation 前，必须为 `P0_F/Q_F` 建立独立、可追溯的冻结值。A1 不进行该冻结或调参。

## Explicit exclusions

本阶段及当前 V2.6 formulation 不引入：

- LifeSig、NIS、observability gating；
- residual/reliability logic；
- maneuver-specific weighting；
- H01/H02/H03 tuning 或 holdout-driven weighting；
- D/K Q/R retuning；
- true Vy online input；
- third feedback track 或 fusion feedback loop。

## Verdict

**V2.6 COVARIANCE FUSION FORMULATION = READY**

**THREE-TRACK RUNTIME IMPLEMENTATION = BLOCKED PENDING F COVARIANCE FREEZE**

机器可读 formulation evidence：`results/vy_covariance_adaptive_fusion_v2_6a1_formulation_freeze.csv`。

READY FOR V2.6-A2 F-TRACK COVARIANCE READINESS AND FREEZE
