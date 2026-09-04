# V2.6-A3R4 Confidence-scale identification and adequacy audit

## 阶段结论

```text
CONSTANT_SCALE_REDUCES_MISMATCH_BUT_REMAINS_INADEQUATE
```

本阶段仅从五组既有非-holdout calibration MAT 重新计算 full-precision confidence scales，并完成 LOO、post-scale consistency、动态关系和 A1 implied-weight 诊断。未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未采集新数据，未修改模型、算法、Q/R、P0_F/Q_F 或融合实现。

## 数据和定义

使用 `FWCAL_C01R1`、`FWCAL_C02`、`FWCAL_C03`、`FWCAL_C04`、`FWCAL_C05`，统一采用冻结的 0–16 s、100 Hz、同时间戳 `Vy_true`、raw error、无去均值/去偏/滤波规则。D/K 仅使用 finite 且 raw covariance 大于零的样本。F 使用：

```text
P0_F = 0
Q_F  = 0.000525656083041383 (m/s)^2/step
c_F  = 1
```

F 的 t=0 精确零 covariance 样本保留为状态事实；ratio 和 A1 权重诊断只排除该点。

## Full-set identification

由原始样本得到：

```text
c_D = 18.10292352356165
c_K = 0.14881262675638557
units = dimensionless
J_D  = -4.094191991323464
J_K  = -2.3452375096063784
```

解析关系使 full-set mean `e²/P_eff` 等于 1；该事实本身不作为 adequacy gate。

### Full-set post-scale consistency

| Maneuver | D mean / median / p05 / p95 | K mean / median / p05 / p95 | F mean / median / p05 / p95 |
|---|---|---|---|
| C01R1 | 0.1944 / 0.1532 / 0.0037 / 0.5628 | 1.3136 / 1.3576 / 0.2256 / 2.1529 | 1.0003 / 1.0096 / 0.1017 / 1.8200 |
| C02 | 0.4272 / 0.3065 / 0.0018 / 1.2800 | 1.3041 / 1.4369 / 0.2444 / 1.9677 | 0.9992 / 1.0039 / 0.1029 / 1.8190 |
| C03 | 0.7884 / 0.7251 / 0.0212 / 1.8767 | 0.9224 / 0.9042 / 0.2681 / 1.5685 | 0.9998 / 1.0028 / 0.1022 / 1.8101 |
| C04 | 1.7241 / 1.5307 / 0.0384 / 3.8556 | 0.7442 / 0.7227 / 0.2194 / 1.4081 | 1.0010 / 1.0118 / 0.1010 / 1.8235 |
| C05 | 1.8659 / 1.8334 / 0.0375 / 3.9177 | 0.7156 / 0.6792 / 0.2310 / 1.2903 | 0.9997 / 1.0011 / 0.1014 / 1.8072 |

F 的 ratio 稳定接近 1，但 D/K 显示明显 maneuver-dependent spread：D 从约 0.19–1.87，K 从约 0.72–1.31。

## LOO identification and predictive consistency

| Omitted maneuver | c_D | ΔD | c_K | ΔK | held-out D mean | held-out K mean |
|---|---:|---:|---:|---:|---:|---:|
| C01R1 | 21.7489028186 | +20.14% | 0.1371462526 | −7.84% | 0.1618 | 1.4253 |
| C02 | 20.6951949938 | +14.32% | 0.1374980336 | −7.60% | 0.3737 | 1.4114 |
| C03 | 19.0604583749 | +5.29% | 0.1516991855 | +1.94% | 0.7488 | 0.9049 |
| C04 | 14.8260551066 | −18.10% | 0.1583282356 | +6.39% | 2.1051 | 0.6995 |
| C05 | 14.1840063238 | −21.65% | 0.1593914265 | +7.11% | 2.3815 | 0.6682 |

留一预测的完整 median/p05/p95 已写入机器可读证据。D 的 LOO 范围约 `14.1840–21.7489`，K 的范围约 `0.13715–0.15939`；被留出 maneuver 的 ratio 仍呈系统性方向变化，说明单一常数不能完全解释时变/工况失配。

## Dynamic confidence relationship

五等频 covariance bins 的 squared-error 均值：

```text
D: P_eff mean [0.0031511, 0.0051338, 0.0066601, 0.0079453, 0.0105695]
   e² mean   [0.0035064, 0.0034930, 0.0042826, 0.0064430, 0.0183306]
   Pearson=0.5705, Spearman=0.3529

K: P_eff mean [0.0233642, 0.0282331, 0.0336421, 0.0455927, 0.0547487]
   e² mean   [0.0130545, 0.0217541, 0.0300758, 0.0564918, 0.0873882]
   Pearson=0.9001, Spearman=0.8656

F: P_eff mean [0.0843678, 0.2525777, 0.4207877, 0.5889976, 0.7572076]
   e² mean   [0.0204857, 0.1603174, 0.4352170, 0.8533713, 1.3263320]
   Pearson=0.9747, Spearman=0.99999
```

F 和 K 的动态关系较清晰，D 的关系较弱且 maneuver spread 明显；这不是单纯的统一尺度问题。

## Calibrated A1 implied weights

在 8000 个三路 covariance 均严格为正的样本上，使用 A1 冻结公式：

```text
mean alpha   = [0.8117942799, 0.1580594782, 0.0301462419]
median alpha = [0.8344334439, 0.1429803771, 0.0128493164]
p05          = [0.6359897136, 0.0557098487, 0.0046443034]
p95          = [0.9371032398, 0.3039075185, 0.1182140959]
max-weight fraction = [0.995, 0, 0.005]
alpha > 0.90       = [0.187125, 0, 0]
alpha > 0.99       = [0, 0, 0]
alpha < 0.01       = [0, 0, 0.3575]
```

相较 A3R2 raw covariance 的 `mean alpha_D≈0.9955`，gross scale saturation 已降低；但 D 仍在 `99.5%` 样本中为最大权重，说明权重行为仍主要偏向 D，并未形成充分均衡、可解释的三轨迹动态 confidence allocation。故记录为：

```text
SCALE_SATURATION_REDUCED_BUT_NOT_ELIMINATED
```

本阶段没有根据 `Vy_AF RMSE`、holdout 或任何性能指标调 scale。

## Verdict 与 freeze

```text
CONSTANT_SCALE_REDUCES_MISMATCH_BUT_REMAINS_INADEQUATE
c_D/c_K formal implementation freeze = NOT PERFORMED
P_AF = NOT_DEFINED
```

平均尺度失配已被解析校准，但 maneuver/time-dependent consistency spread、D-track 最大权重持续占优及 LOO predictive spread 仍明显。因此 `c_D/c_K` 仅作为 A3R4 diagnostic candidate，不升级为正式 implementation parameters。

F-track blocker 保持不变：

```text
P0_F_FROZEN = 0
Q_F_FROZEN = 0.000525656083041383
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

`model/vy_feedback_propagation_step.m` 仍有 `P0_F>0` 断言，本阶段未修改。

机器可读证据：`results/vy_covariance_adaptive_fusion_v2_6a3r4_identification.csv`。
