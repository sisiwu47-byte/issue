# V2.8-A15 K-health 正式冻结前验证

## 阶段结论

```text
V2.8-A15 K-HEALTH PRE-FREEZE VALIDATION PASSED
FORMAL SIMULINK IMPLEMENTATION = ALLOWED
```

本阶段仅复用 A13/A14 现有离线证据，未启动 MATLAB、Simulink 或
CarSim，未修改模型、估计器、LifeSig 代码、`q_D/q_K/q_F`、`tau_F`
或 Q/R。

## 冻结的实现候选

```text
I_K(k) = 0.995*I_K(k-1)
         + 0.01*max(0, abs(Vy_K-Vy_D)-0.3467656927489074)

G_K(k) = exp(-10*I_K(k))

rho    = 0.995
lambda = 10 1/m
Ts     = 0.01 s
d0     = 0.3467656927489074 m/s
```

`rho/lambda` 现冻结为 `FROZEN_FOR_IMPLEMENTATION`，但不声称为全局最优。

## A14 独立重放复现

对 `4.70--22.00 s`、1731 个样本重新计算泄漏积分、`G_K`、权重和
`Vy_LS`：

- `I_K` 最大差异：`0`；
- `G_K` 最大差异：`0`；
- `alpha_K` 最大差异：`5.551115123125783e-17`；
- `Vy_LS` 最大差异：`2.7755575615628914e-17 m/s`；
- RMSE/MAE/MaxAbs/Bias 均在 `1e-14` 容差内复现：`PASS`。

## 正常 FWCAL 保持性

- C01R1/C03/C04：直接离线重放完全不变；
- C02/C05：保留 A14 已披露的微小非零扰动；
- 最大输出 RMS 变化：`5.946661750521324e-05 m/s`；
- 最大输出 MaxAbs 变化：`0.0002823247504146779 m/s`；
- 最大 `alpha_K` 绝对变化：`0.0008285839738473022`；
- 最大 RMSE 变化：`2.199860127398423e-05 m/s`。

因此正常工况结论为“工程意义上的有界小扰动保持”，不是五组数据
全部逐位相同。

## 低横摆退化工况

| 指标 | `rho=0.995, lambda=10` |
|---|---:|
| RMSE | 0.02618446471317122 m/s |
| MAE | 0.02137088226879241 m/s |
| MaxAbs | 0.06512052197977002 m/s |
| Bias | -0.02137088226879241 m/s |
| `alpha_K` mean | 0.02388261564731424 |
| `alpha_K` min | 3.526148452663255e-12 |
| `alpha_K` max | 0.1467395279044887 |
| `alpha_K <= 0.05` | 3.09 s |
| `alpha_K <= 0.02` | 3.91 s |

## 参数决策依据

- 与邻近 `rho=0.99, lambda=10` 相比，`rho=0.995` 保留更长的累积
  disagreement 证据，低横摆 RMSE 再降低 `6.222%`，`alpha_K`
  降至 0.05 也更快。
- 与邻近 `rho=0.995, lambda=5` 相比，`lambda=10` 对相同状态给出
  更强抑制，低横摆 RMSE 降低 `15.808%`。
- 两个值都是 A13 预先审计推荐区间的端点；选择优先约束已观测
  K 退化，没有用正常工况融合 RMSE 重新调参。

## 声明边界

- 允许进入正式 Simulink 实现：`YES`；
- 正式 Simulink/CarSim runtime 验证：`NOT_YET_PERFORMED`；
- 完整的退化后恢复段：`NOT_AVAILABLE`，因此恢复能力仍未验证；
- 不声称全局最优、通用故障鲁棒性或 LifeSig 优于 D-EKF；
- D-only 在已审计 A3 低横摆窗口中仍是最准确的单轨迹。

## 证据

主报告：
`results/vy_lifesig_v2_8a15_k_health_freeze/freeze_report.md`

机器可读表：

- `parameter_decision.csv`；
- `comparison.csv`。

图：

- `figures/low_yaw_alphaK_freeze.svg`；
- `figures/low_yaw_output_freeze.svg`；
- `figures/nearby_parameter_RMSE.svg`。
