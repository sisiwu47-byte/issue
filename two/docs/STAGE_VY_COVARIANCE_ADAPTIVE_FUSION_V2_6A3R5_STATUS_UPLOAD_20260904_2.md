# V2.6-A3R5 Affine confidence calibration formulation freeze

## 阶段结论

本阶段冻结 covariance-only confidence calibration 的最后一个最小扩展方案，不求参数、不实现代码、不运行 MATLAB/Simulink/CarSim。A3R4 的 `CONSTANT_SCALE_REDUCES_MISMATCH_BUT_REMAINS_INADEQUATE` 保持不变。

## Affine mapping

对 D/K 定义：

```text
P_D_eff = a_D + b_D * P_D11
P_K_eff = a_K + b_K * P_K22

a_D >= 0, b_D >= 0
a_K >= 0, b_K >= 0
```

`a_i` 单位为 `(m/s)^2`，表示 raw covariance 未表达的 effective confidence uncertainty floor；`b_i` 为无量纲 raw covariance scale。两者只存在于 fusion confidence layer，不是 estimator Q/R、physical process covariance、cross-covariance 或 independence correction。

F 保持 A3R1 reference：

```text
P_F_eff = P_F
c_F = 1
P0_F_FROZEN = 0
Q_F_FROZEN = 0.000525656083041383 (m/s)^2/step
```

本阶段不重新拟合 F。

## A3R6 identification objective

仅对 D/K 使用五组既有非-holdout calibration 的 raw error：

```text
e_i,j,k = Vy_i,j,k - Vy_true_j,k
P_eff_i,j,k = a_i + b_i * P_i,j,k

J_i(a_i,b_i) = (1/M) * sum_j mean_k[
    log(P_eff_i,j,k) + e_i,j,k^2/P_eff_i,j,k
]
```

只使用 finite 且 raw `P_i>0` 的样本，并要求每个有效样本的 `P_eff>0`。不去均值、不 bias correction、不滤波，不使用 `Vy_AF RMSE`。

## 必须比较的边界模型

```text
A: a_i=0, b_i>0   constant-scale model
B: a_i>0, b_i=0   constant confidence variance model
C: a_i>0, b_i>0   full affine mapping
```

Affine 参数更多不构成自动接受理由；A3R6 必须用目标值、稳定性和预测性证据进行比较。

## A3R6 adequacy requirements

后续 A3R6 必须完成：

1. full-set multi-start 识别，并以 profile/Hessian 或等价方法检查可辨识性；
2. 五次 leave-one-maneuver-out 参数识别及相对变化；
3. LOO held-out `e_D²/P_D_eff`、`e_K²/P_K_eff` 的 mean/median/p05/p95；
4. full-set 每 maneuver 及 aggregate 的 D/K/F consistency ratio；
5. `P_eff` 与 `e²` 的 Pearson/Spearman 和 covariance 分箱关系；
6. calibrated A1 implied-weight 的分布及最大权重、`>0.90`、`>0.99`、`<0.01` 比例。

这些都是 offline confidence diagnostics，不称 NIS，不引入 LifeSig、observability 或 residual reliability。

## 复杂度停止规则

```text
AFFINE_MAPPING_IS_LAST_COVARIANCE_ONLY_CALIBRATION_EXTENSION
```

如果 affine 仍不能通过 out-of-maneuver confidence adequacy，不再尝试 maneuver-dependent scale、polynomial/lookup/nonlinear map 或 hand weight caps，而冻结：

```text
COVARIANCE_ONLY_CONFIDENCE_INADEQUATE
```

随后另立阶段设计 LifeSig/NIS/observability/residual reliability architecture。

## A1 接入语义与未来 verdict

若 A3R6 通过，A1 使用：

```text
P_D_eff = a_D + b_D*P_D11
P_K_eff = a_K + b_K*P_K22
P_F_eff = P_F
```

`P_AF` 仍为 `NOT_DEFINED`。

A3R6 仅允许以下结论：

```text
AFFINE_CONFIDENCE_CALIBRATION_ACCEPTABLE
AFFINE_REDUCES_MISMATCH_BUT_REMAINS_INADEQUATE
AFFINE_PARAMETER_IDENTIFICATION_UNSTABLE
INSUFFICIENT_DATA
```

只有第一项允许正式冻结 `a_D,b_D,a_K,b_K`。

## F-track blocker

实际 `model/vy_feedback_propagation_step.m` 仍有 `assert(P0_F > 0)`，因此：

```text
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

本阶段不修改 F core 或参数入口。

机器可读规格证据：`results/vy_covariance_adaptive_fusion_v2_6a3r5_formulation.csv`。
