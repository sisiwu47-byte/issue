# V2.6-A3R6 Affine confidence identification and adequacy audit

## 最终判定

```text
AFFINE_PARAMETER_IDENTIFICATION_UNSTABLE
```

并按 A3R5 停止规则冻结：

```text
COVARIANCE_ONLY_CONFIDENCE_INADEQUATE
```

本阶段只读取五组既有非-holdout calibration MAT，未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未采集新数据，未修改 D/K/F、Q/R、P0_F/Q_F、模型或融合实现。

## Full-set affine identification

使用 A3R5 冻结目标：

```text
P_eff = a + b*P
J(a,b) = (1/M) * sum_j mean_k[
    log(P_eff) + e^2/P_eff
]
```

通过解析消除固定 `r=a/b` 下的 `b`，再进行 1001 点 log-profile 与局部 golden refinement，并显式比较两条边界。

### D-track

```text
affine:          a_D=0.0001817244800527478 (m/s)^2
                 b_D=17.505437815616418
                 J_D=-4.094461524998127

constant-scale:  a_D=0
                 b_D=18.10292352356165
                 J_D=-4.094191991323464

constant-confidence:
                 a_D=0.007211109023598891
                 b_D=0
                 J_D=-3.9321325220938697
```

Affine 相对 constant-scale 的目标改善仅为 `-0.0002695336746629806`，且 interior ratio `a_D/b_D≈1.04e-5`，非常接近边界。

### K-track

```text
affine:          a_K=4.703222532518878e-13 (m/s)^2
                 b_K=0.14881262675455179
                 J_K=-2.3452375096046563

constant-scale:  a_K=0
                 b_K=0.14881262675638557
                 J_K=-2.3452375096063784

constant-confidence:
                 a_K=0.041752887284846496
                 b_K=0
                 J_K=-2.175986673553205
```

K 的 affine 结果数值上退化为 `a_K=0` constant-scale 边界；目标差异仅 `1.72e-12`。

## LOO 稳定性与预测一致性

| omitted | D model / a_D / b_D | D held-out mean | K b_K | K held-out mean |
|---|---|---:|---:|---:|
| C01R1 | affine / 0.0005304931 / 20.06673345 | 0.1555 | 0.13714625 | 1.4253 |
| C02 | affine / 0.0001590473 / 20.19612668 | 0.3683 | 0.13749803 | 1.4114 |
| C03 | constant-scale / 0 / 19.06045837 | 0.7488 | 0.15169919 | 0.9049 |
| C04 | affine / 0.0008077480 / 12.01799824 | 2.2240 | 0.15832824 | 0.6995 |
| C05 | affine / 0.0001630497 / 13.62549907 | 2.3920 | 0.15939143 | 0.6682 |

D 的 LOO `a_D` 在 `0` 到 `8.07748e-4` 间变化，CV 约 `0.88765`；`b_D` CV 约 `0.20397`，并在 boundary/interior 间切换。K 始终回到 `a_K≈0` 边界，`b_K` CV 约 `0.06549`。

被留出 maneuver 的 D/K ratio 仍呈系统性 spread；完整 median/p05/p95 已写入机器可读 evidence。

## Full-set post-scale consistency

使用 full-set affine D candidate、K boundary candidate 和 A3R1 F covariance，五个 maneuver 的 mean `e²/P_eff` 为：

```text
C01R1: D=0.1913, K=1.3136, F=1.0003
C02:   D=0.4199, K=1.3041, F=0.9992
C03:   D=0.7823, K=0.9224, F=0.9998
C04:   D=1.7360, K=0.7442, F=1.0010
C05:   D=1.8704, K=0.7156, F=0.9997
```

D 仍从显著低估变为显著高估，K 则呈相反工况趋势；常数 affine mapping 未消除 out-of-maneuver mismatch。

## Dynamic confidence relationship

五等频 bins 的 Pearson/Spearman：

```text
D: 0.5705 / 0.3529
K: 0.9001 / 0.8656
F: 0.9747 / 0.99999
```

D 的动态关系较弱且受 maneuver 影响明显；K/F 的关系更清晰，但这不能弥补 D/K 的跨工况失配。

## Calibrated A1 implied weights

在 8000 个正 covariance 样本上：

```text
mean alpha   = [0.8124601309, 0.1574315570, 0.0301083121]
median alpha = [0.8347891816, 0.1425269405, 0.0127970778]
p05          = [0.6388567928, 0.0575536751, 0.0047428713]
p95          = [0.9356350752, 0.3004537283, 0.1176642940]

max-weight fraction = [0.995, 0, 0.005]
alpha > 0.90       = [0.18425, 0, 0]
alpha > 0.99       = [0, 0, 0]
alpha < 0.01       = [0, 0, 0.358625]
```

相较 A3R2，gross scale saturation 已降低；但 D 仍在 `99.5%` 样本中为最大权重，记录为：

```text
SCALE_SATURATION_REDUCED_BUT_NOT_ELIMINATED
```

## Freeze decision 与 F blocker

```text
a_D/b_D/a_K/b_K formal implementation freeze = NOT PERFORMED
P_AF = NOT_DEFINED
P0_F_FROZEN = 0
Q_F_FROZEN = 0.000525656083041383
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

Affine mapping 是已冻结的 covariance-only 最后扩展。由于参数不稳定、LOO 预测 spread 和权重偏置仍存在，不再继续更复杂 covariance mapping；后续应转入单独 reliability architecture 设计。

机器可读证据：`results/vy_covariance_adaptive_fusion_v2_6a3r6_identification.csv`。
