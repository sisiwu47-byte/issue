# V2.6-A3R3 Confidence-scale calibration formulation freeze

## 阶段结论

本阶段冻结 confidence-scale calibration 的数学规格，不冻结 `c_D/c_K` 数值，不实现代码，不运行 MATLAB/Simulink/CarSim。A3R2 的结论 `COVARIANCE_SCALE_CALIBRATION_REQUIRED` 保持不变。

## Effective confidence covariance

```text
P_D_eff = c_D * P_D11
P_K_eff = c_K * P_K22
P_F_eff = P_F

c_D > 0, c_K > 0, c_F = 1
```

`c_D`、`c_K` 是仅存在于 fusion confidence layer 的无量纲 effective confidence calibration factors，不修改 D-EKF/K-KF 内部 covariance recursion 或 Q/R。F 以 A3R1 冻结的 covariance 为 reference，不重新拟合 `c_F`。

## 识别目标与解析关系

对 D/K 分别使用既有五组 calibration 的 raw error：

```text
e_i,j,k = Vy_i,j,k - Vy_true_j,k
P_eff_i,j,k = c_i * P_i,j,k

J_i(c_i) = (1/M) * sum_j mean_k[
    log(c_i * P_i,j,k) + e_i,j,k^2/(c_i * P_i,j,k)
]
```

只使用 finite 且 `P_i>0` 的样本；不去均值、不 bias correction、不滤波。解析最优关系冻结为：

```text
c_i* = (1/M) * sum_j mean_k(e_i,j,k^2 / P_i,j,k)
```

A3R3 不从 A3R2 rounded 汇总值冻结参数；A3R4 必须从五组原始 calibration evidence 重新计算 full-precision `c_D/c_K`。约 `18.1` 与 `0.149` 仅为 sanity expectation。

## A1 接入语义

后续 A1 inverse-covariance weighting 必须使用：

```text
P_D_eff, P_K_eff, P_F_eff
```

A1 的 validity、epsilon、归一化和 fallback 结构保持不变。候选输出为 `Vy_AF`、`alpha_D`、`alpha_K`、`alpha_F`，可选 `fusion_numeric_valid`；`P_AF = NOT_DEFINED`。

名称固定为：

```text
CONFIDENCE-SCALE-CALIBRATED INVERSE-COVARIANCE WEIGHTING
```

这不是严格 statistically optimal fusion 或 BLUE。`c_D/c_K` 不是 D/K 的 process-noise covariance、Q/R retuning、独立性修正、cross-covariance 估计，也不是基于 `Vy_AF RMSE` 的性能权重。

## A3R4 必须执行的 adequacy audit

A3R4 需要从原始数据检查：

1. full-set 与五次 LOO 的 `c_D/c_K` 及相对变化；
2. post-scale 的 `e_D²/P_D_eff`、`e_K²/P_K_eff`、`e_F²/P_F` 的每 maneuver/aggregate mean、median、p05、p95；
3. `P_eff` 与 squared error 的 Pearson/Spearman 及 covariance 分箱描述；
4. calibrated effective covariance 下 A1 implied weights 的 mean、median、p05、p95、max-weight、`>0.90`、`>0.99`、`<0.01` 比例。

这些均为 offline confidence diagnostics，不是 NIS/LifeSig，也不允许优化 `Vy_AF RMSE`。

A3R4 最终只能判定：

```text
CONSTANT_CONFIDENCE_SCALE_CALIBRATION_ACCEPTABLE
CONSTANT_SCALE_REDUCES_MISMATCH_BUT_REMAINS_INADEQUATE
CONFIDENCE_SCALE_IDENTIFICATION_UNSTABLE
INSUFFICIENT_DATA
```

A3R3 不提前给出上述 verdict。

## F-track contract blocker

继续保持：

```text
P0_F_FROZEN = 0
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

当前 `model/vy_feedback_propagation_step.m` 的 `P0_F>0` 断言未修改；该问题留给独立 implementation-contract remediation。

机器可读规格证据：`results/vy_covariance_adaptive_fusion_v2_6a3r3_formulation.csv`。
