# V2.8-A14 K-health 正式实现前离线消融

## 结论

```text
K-health improves reliability under estimator degradation while preserving
nominal fusion behavior = SUPPORTED_WITH_BOUNDED_NOMINAL_PRESERVATION
```

这里的 nominal preservation 是工程意义上的有界小扰动，不是所有样本逐位相同。
本阶段未启动 MATLAB、Simulink 或 CarSim，未修改正式模型、代码、估计器、
`q_D/q_K/q_F`、`tau_F`、Q/R 或其他参数。

候选泄漏积分仅用于本次消融：

```text
rho    = 0.995
lambda = 10 1/m
```

不声明最优，不正式冻结。

## 三种方法

- Method A：原 V2.7 LifeSig，`H_K=availability_K`；
- Method B：A8 瞬时门 `G_K=1-L_r*L_d`；
- Method C：泄漏积分 `I_K(k)=0.995*I_K(k-1)+Ts*max(0,d_DK-d0)`，
  `G_K=exp(-10*I_K)`。

所有在线候选量仅由当前/历史因果信号产生；`Vy_true` 仅用于离线评价。

## A3 长低横摆结果

窗口：`4.70--22.00 s`，1731 samples。

| 方法 | RMSE | MAE | MaxAbs | Bias | alpha_K mean |
|---|---:|---:|---:|---:|---:|
| Original LifeSig | 0.17063446 | 0.15759709 | 0.27090747 | -0.15759709 | 0.14702998 |
| A8 instantaneous | 0.12261568 | 0.11358918 | 0.26480610 | -0.11358918 | 0.10934897 |
| Proposed leaky | 0.02618446 | 0.02137088 | 0.06512052 | -0.02137088 | 0.02388262 |

候选泄漏门相对原 LifeSig 的 RMSE 降低 `84.655%`，相对 A8 瞬时门降低
`78.645%`。响应时间（相对 4.70 s）：

- `G_K<0.99`：1.31 s；
- `G_K<=0.50`：2.57 s；
- `alpha_K<=0.05`：3.09 s；
- `alpha_K<=0.02`：3.91 s。

## 单轨迹/融合消融

| 方法 | RMSE | MAE | MaxAbs | Bias |
|---|---:|---:|---:|---:|
| D-only | 0.00447073 | 0.00426439 | 0.01135534 | -0.00414120 |
| K-only | 1.08949148 | 0.99985803 | 1.74866874 | -0.99985803 |
| F-only | 1.14577722 | 1.07607684 | 1.75043078 | -1.07607684 |
| Static prior | 0.17533128 | 0.16168268 | 0.27965733 | -0.16168268 |
| Original LifeSig | 0.17063446 | 0.15759709 | 0.27090747 | -0.15759709 |
| A8 instantaneous | 0.12261568 | 0.11358918 | 0.26480610 | -0.11358918 |
| Proposed leaky | 0.02618446 | 0.02137088 | 0.06512052 | -0.02137088 |

D-only 仍然最好，因此本阶段支持的是 K 退化影响抑制，不是融合优于 D-EKF。

## 正常 FWCAL

- Method B 沿用冻结 A8 processed replay：五组输出和权重变化均为零；
- Method C 直接同拍 raw-MAT 重放：C01R1/C03/C04 完全不变；
- C02/C05 有很小非零变化；
- 五组最大 `alpha_K` 绝对变化：`0.000828584`；
- 五组最大输出 RMS 变化：`5.94666e-05 m/s`；
- 五组最大输出 MaxAbs 变化：`0.000282325 m/s`；
- 五组最大 RMSE 变化：`2.19986e-05 m/s`。

A8 processed normal evidence 与 Method-C direct raw-MAT replay 的数据处理 lineage
已明确区分，不把二者混写为相同证据。该差异不影响“正常扰动很小”的结论，
但阻止宣称 Method C 在所有正常样本严格不改变输出。

## Claim boundary

现有证据支持：

> 在已审计的 A3 K 轨迹低横摆退化场景中，泄漏积分 K-health 显著降低退化
> K 轨迹对融合结果的影响；在五组正常 FWCAL 中，融合行为保持到有界且很小的
> 扰动水平。

现有证据不支持：

- 参数全局最优；
- `rho/lambda` 已冻结；
- 所有 nominal 样本逐位不变；
- LifeSig 优于 D-EKF；
- 正式 Simulink/CarSim 实现已验证；
- 通用故障鲁棒性已验证。

## 输出

目录：`results/vy_lifesig_v2_8a14_k_health_ablation/`

- `summary.csv`
- `normal_case_comparison.csv`
- `low_yaw_comparison.csv`
- `ablation_table.csv`
- `timeseries.csv`
- `figures/alpha_K_comparison.svg`
- `figures/Vy_estimation_comparison.svg`
- `figures/RMSE_comparison.svg`
- `figures/health_state_curve.svg`
- `status.md`

