# V2.8-A13 K-health 泄漏积分参数选择与验证

## 阶段结论

本阶段完成 20 组离线网格：

```text
rho    = 0.90 / 0.95 / 0.98 / 0.99 / 0.995
lambda = 1 / 2 / 5 / 10 1/m
```

推荐后续验证范围（不是参数冻结）：

```text
rho    = 0.99--0.995
lambda = 5--10 1/m
```

未启动 MATLAB、Simulink 或 CarSim；未修改正式 LifeSig、模型、D/K/F、
`q_D/q_K/q_F` 或 `tau_F`。

## 数据与重放语义

- 低横摆数据：A8/A11/A12 已有离线 replay；
- 固定窗口：`4.70--22.00 s`，`1731` samples；
- `d0=0.3467656927489074 m/s`，`Ts=0.01 s`；
- `I_K(k)=rho*I_K(k-1)+Ts*max(0,abs(Vy_K-Vy_D)-d0)`；
- `G_K=exp(-lambda*I_K)`；
- 状态在 `4.70 s` 置零，与 A11/A12 的离线重放约定一致；
- 与 A12 重叠网格的 RMSE 最大差为 `0`。

## 推荐范围的低横摆结果

| rho | lambda | RMSE | MAE | MaxAbs | Bias | alpha_K mean | 到 0.05 | 到 0.02 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.99 | 5 | 0.035766 | 0.031239 | 0.067409 | -0.031239 | 0.038129 | 4.85 s | 6.96 s |
| 0.99 | 10 | 0.027922 | 0.023170 | 0.065187 | -0.023170 | 0.026829 | 3.46 s | 4.58 s |
| 0.995 | 5 | 0.031101 | 0.025778 | 0.067232 | -0.025778 | 0.031279 | 4.09 s | 5.36 s |
| 0.995 | 10 | 0.026184 | 0.021371 | 0.065121 | -0.021371 | 0.023883 | 3.09 s | 3.91 s |

网格最小 RMSE 位于 `(rho,lambda)=(0.995,10)`，但该单点不冻结。
`rho<=0.98` 或 `lambda<=2` 的累计抑制明显更弱；推荐矩形中的四个点均能在
`3.09--4.85 s` 内使 `alpha_K<=0.05`，并在 `3.91--6.96 s` 内使
`alpha_K<=0.02`。

## 正常 FWCAL 扰动

五组 NON_HOLDOUT_RELIABILITY_CALIBRATION MAT 通过 MATLAB 安装自带 HDF5
库离线只读解析。C01R1/C03/C04/C05 均不越过 `d0`，20 组组合全部保持不变。
C02 的直接同拍 raw-MAT 重放得到 17 个越界样本，而既有冻结 A11 processed
summary 记录为 16 个。A13 保守采用 17 个样本并公开该 1-sample lineage 差异；
该差异不改变参数范围结论。在推荐范围内：

- `alpha_K` 最大绝对变化：`0.000399801--0.000828584`；
- `alpha_D` 最大绝对变化：`0.000396473--0.000821687`；
- 输出 RMS 变化：`2.17236e-05--5.94666e-05 m/s`；
- 输出 MaxAbs 变化：`0.000136225--0.000282325 m/s`。

因此正常扰动很小但不为零，未将其隐藏或写成“完全无影响”。

## 恢复能力

A3 记录在 `22 s` 结束时仍处于物理低横摆退化段，完整真实退化后恢复记录：

```text
NOT_AVAILABLE
```

现有正常 FWCAL_C02 在最后一次阈值越界后有 `3.66 s` 低 disagreement 尾段，
可确认泄漏状态实际下降、`G_K` 回升。例如 `lambda=10`：

- `rho=0.99`：`I_K 0.000631991 -> 0.0000159659 m`，
  `G_K 0.993700 -> 0.999840`；
- `rho=0.995`：`I_K 0.000659004 -> 0.000105229 m`，
  `G_K 0.993432 -> 0.998948`。

该证据说明泄漏机制能恢复，但不能替代“严重退化后回到正常状态”的专门验证。
因此推荐的是参数范围，不是正式冻结值。

## 输出

主结果目录：
`results/vy_lifesig_v2_8a13_k_health_parameter_selection/`

- `summary.csv`
- `parameter_grid.csv`
- `normal_fwcal_impact.csv`
- `recovery_analysis.csv`
- `timeseries.csv`
- `figures/rho_lambda_heatmap.svg`
- `figures/alpha_K_time_series.svg`
- `figures/RMSE_vs_parameter.svg`
- `status.md`

## 冻结边界

```text
RECOMMENDED_RHO_RANGE    = 0.99--0.995
RECOMMENDED_LAMBDA_RANGE = 5--10 1/m
FORMAL_PARAMETER_FREEZE  = NO
REAL_POST-DEGRADATION_RECOVERY_VALIDATION = NOT_AVAILABLE
```
