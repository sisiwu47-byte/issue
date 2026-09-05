# STAGE VY D-EKF V1.10 STATUS

## 范围与基线验收

本阶段仅使用 V1.8/V1.9 已有数据做 6x6 离线 relaxation-length ablation。未运行 CarSim/Simulink，未修改正式 D-EKF、Q/R、`tireForceLocal`、Fz、车辆参数或轮胎参数。

- 样本数 1600，Ts=0.01 s。
- TRAIN: `3<=t<8 s`；VALIDATION: `8<=t<=13 s`。
- lag 定义：**positive lag L means input leads residual by L samples**。
- sigma=(0,0) vs V1.9: x_pred 0，w_model 0，DeltaFy 0，DeltaMz 0。
- 固定 `Q=diag([1e-4,1e-4])`，`R=diag([1e-2,3.365172961808e-4])`。

## Relaxation grid 与时间常数

|sigma [m]|tau at mean Vx [s]|
|--:|--:|
|0|0|
|0.5|0.025024505|
|1|0.0500490099|
|2|0.10009802|
|4|0.20019604|
|8|0.400392079|

## 七个单指标 winner（不等于综合推荐）

|Criterion|Case|sigma_f|sigma_r|
|:--|--:|--:|--:|
|minimum TRAIN Vy RMS|11|0.5|4|
|minimum VALIDATION Vy RMS|11|0.5|4|
|minimum VALIDATION r RMS|35|8|4|
|minimum VALIDATION DeltaFy RMS|11|0.5|4|
|minimum VALIDATION DeltaMz RMS|35|8|4|
|minimum high-rate Vy residual|11|0.5|4|
|lowest combined hysteresis|18|1|8|

## Pareto candidates

门槛：TRAIN and VALIDATION must improve Vy and DeltaFy without degrading r or DeltaMz; Pareto objectives then use validation Vy/r/Fy/Mz plus high-rate Vy and hysteresis。

|Case|sigma_f|sigma_r|TRAIN Vy red|VAL Vy red|VAL r red|VAL Fy red|VAL Mz red|high-rate Vy red|hysteresis red|
|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
|13|1|0|32.6216%|33.833%|0.249452%|33.3792%|0.273962%|44.1146%|22.9963%|
|7|0.5|0|19.0074%|19.5251%|1.41538%|19.2971%|1.47278%|26.7745%|20.5618%|

## 综合诊断候选

选择 Case 13: `sigma_f=1 m`, `sigma_r=0 m`。该点仅用于诊断，不是已辨识参数。

|Metric|TRAIN|VALIDATION|
|:--|--:|--:|
|Vy RMS reduction|32.6216%|33.833%|
|r RMS reduction|0.826621%|0.249452%|
|DeltaFy RMS reduction|32.2049%|33.3792%|
|DeltaMz RMS reduction|0.935905%|0.273962%|
|front axle RMS reduction|19.1036%|20.147%|
|rear axle RMS reduction|0%|0%|

- high steering-rate Vy/r reduction: 44.1146% / -11.4532%。
- combined hysteresis reduction: 22.9963%。
- |steering correlation| reduction Vy/r: -28.0434% / 9.49193%。
- residual rho1 Vy/r: 0.999478898 / 0.999665174。
- 至少一个 lag peak 命中 +/-20 边界，不解释为精确物理 delay。

## Quasi-steady subset

`|front steer|>0.005 rad` 且 `|steering rate|<=0.0168096036 rad/s`，N=216。

|Model|DeltaFyf mean/RMS|DeltaFyr mean/RMS|front gain|rear gain|
|:--|:--|:--|--:|--:|
|Current|-12.43272 / 683.8138|-7.184643 / 143.5517|1.273246|0.9112248|
|Selected|-8.491346 / 604.2471|-7.184643 / 143.5517|1.243964|0.9112248|

## V1.10 最终回答

1. 一阶 relaxation 是否显著改善 Vy prediction residual：**是**（TRAIN 32.6216%，VALIDATION 33.833%）。
2. 是否显著改善 r residual：**否**（VALIDATION 0.249452%）。
3. 是否降低 DeltaFy：**是**（VALIDATION 33.3792%）。
4. 是否降低 DeltaMz：**是**（VALIDATION 0.273962%）。
5. 更敏感的参数：**sigma_f**（front/rear main-effect range 0.00558055 / 0.00118665）。
6. front axle residual 是否改善：**是**（20.147%）。
7. rear axle residual 是否改善：**否**（0%）。
8. high steering-rate residual 是否下降：Vy/r 44.1146% / -11.4532%。
9. hysteresis 是否下降：**是**（22.9963%）。
10. 高度有色 rho1 是否显著下降：**否**。Vy/r=0.999478898 / 0.999665174，相对变化 0.00659073% / -0.00287084%。
11. 是否存在 TRAIN/VALIDATION 都改善的合理 sigma 区域：**是**；候选数 2。
12. quasi-steady 区域是否仍有显著 gain mismatch：**是**；front 1.27325 -> 1.24396，rear 0.911225 -> 0.911225。
13. 下一阶段：**B. continue steady-state tire gain/shape diagnosis**。

前轴/Vy 通道是否存在 transient 成分证据：**是**。
当前四轮两状态候选是否满足整体 success criteria：**否**。

## 产物

- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_tire_transient.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_candidate_summary.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_ranking.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_tire_transient.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_01_validation_state_heatmaps.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_02_validation_force_heatmaps.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_03_train_validation.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_04_selected_residual_time.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_05_axle_scatter.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_06_selected_hysteresis.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_07_dynamic_heatmaps.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_10_08_validation_pareto.png`
- `D:\UsersData\桌面\two\matlab\analyze_vy_dekf_v1_10_tire_transient.m`
- `D:\UsersData\桌面\two\matlab\vy_dekf_v1_10_transient_candidate.m`

**NO TRANSIENT TIRE MODEL WAS APPLIED ONLINE.**

**NO TIRE PARAMETER WAS IDENTIFIED OR CHANGED.**

**THIS WAS AN OFFLINE RELAXATION-LENGTH ABLATION ONLY.**
