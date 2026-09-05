# STAGE VY D-EKF V1.7 STATUS

## 实验边界与验收

本阶段完成 B0--B3 四组已知注入 bias 的受控消融。bias 只在虚拟 IMU 原始输出与 D-EKF 量测入口之间减去；原始 Ay/AVz 日志保持不变，corrected Ay/AVz 另行记录。真值只用于离线评分，未进入在线估计。

- 每组实际更新：1601；真值因果对齐评分样本：1600。
- 四组车辆输入、原始 IMU、Vy/r 真值逐点一致：1。
- 正式/debug 核心一致性测试：120 组，通过：1。
- 四组均数值稳定：1。

## 固定参数

- `Q = diag([1e-4,1e-4])`
- `R = diag([1e-2,3.365172961808e-4])`
- B0: `[0,0]`；B1: `[0.02,0]`；B2: `[0,0.005]`；B3: `[0.02,0.005]`。

## 状态精度、innovation 与一致性

|Case|Vy RMSE|Vy MAE|Vy Bias|Vy Max|r RMSE|r MAE|r Bias|r Max|nuAy mean|nur mean|NIS mean|NIS p95|NEES mean|NEES p95|
|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
|B0|0.0373919712|0.0267537093|-0.00373725474|0.0778861508|0.00587281214|0.00483409262|0.00414258131|0.0155168033|-0.0103666482|0.0012596577|0.0779830892|0.253995541|17.7949936|70.6352968|
|B1|0.037234407|0.0260747752|-0.00153094151|0.07793152|0.00583955915|0.00480237026|0.00409568024|0.0154676368|-0.0131768654|0.00132710982|0.081200553|0.257790634|17.6924469|70.7425316|
|B2|0.0372701209|0.0262185575|-0.00222790294|0.0767927299|0.00415512341|0.00325882804|5.66121389e-06|0.0118361675|0.00294216974|-7.7413481e-05|0.0705278125|0.240450272|17.6222387|69.9353846|
|B3|0.0372033775|0.0258395159|-2.38926917e-05|0.0790080072|0.00415537408|0.00326069502|-4.0754907e-05|0.0118880646|0.000123997403|-1.05443811e-05|0.0701618269|0.237998366|17.555431|70.8165105|

完整 CSV 另含 innovation std/RMS、NIS/NEES median/max/阈值超限率，以及 r 对 raw/corrected AVz 的 RMSE。

## 相对 B0 的归因

|Case|归因|Vy RMSE reduction|r RMSE reduction|abs Vy bias reduction|abs r bias reduction|NEES mean reduction|NIS mean change|
|:--|:--|--:|--:|--:|--:|--:|--:|
|B0|baseline|0%|0%|0%|0%|0%|0%|
|B1|Ay bias effect|0.421385%|0.566219%|59.0357%|1.13217%|0.576267%|4.12585%|
|B2|yaw-rate bias effect|0.325873%|29.2481%|40.3866%|99.8633%|0.970806%|-9.56012%|
|B3|combined effect|0.504369%|29.2439%|99.3607%|99.0162%|1.34624%|-10.0294%|

特别对比：B0 -> B1 的 Ay innovation mean 为 -0.0103666482162 -> -0.0131768654453；B0 -> B2 的 r innovation mean 为 0.00125965770331 -> -7.74134809588e-05。

## 协方差量级确认

|Case|median P11|change vs B0|median P22|change vs B0|
|:--|--:|--:|--:|--:|
|B0|7.72279437862e-05|0%|0.000123703797718|0%|
|B1|7.72588388941e-05|0.0400051%|0.000123707075078|0.00264936%|
|B2|7.729489183e-05|0.0866889%|0.000123639122769|-0.0522821%|
|B3|7.74043543968e-05|0.228428%|0.000123641980837|-0.0499717%|

P 中位数变化均小于 10%：1。因 Q/R 未变且 P 量级无异常，NEES 变化主要归因于状态误差变化。

## V1.7 最终判断

判据：major total-error source: >=10% RMSE reduction; material mean-bias source: >=25% absolute-bias reduction; significant NEES/NIS change: >=20%; NIS still low: mean<0.5。

1. Ay bias 是否是 Vy 状态误差的主要来源之一：**否（按 RMSE）**。B1 的 Vy RMSE 仅改善 0.421385%，但 `abs(Vy bias)` 改善 59.0357%，因此 Ay bias 是 Vy 平均偏差的显著来源，不是当前时变/RMSE 误差的主导来源。
2. AVz bias 是否是 r 状态误差的主要来源之一：**是**。B2 的 r RMSE 改善 29.2481%，`abs(r bias)` 改善 99.8633%。
3. 去除两个 bias 后 NEES 是否显著下降：**否**（B3 相对 B0 1.34624%）。
4. NIS 是否明显改变：**否**（B3 相对 B0 -10.0294%；B3 mean 0.0701618269）。
5. `bias` 解释 state inconsistency、covariance scaling/colored noise 继续解释 measurement inconsistency：**否**。 当前消融结果不同时满足“NEES 显著改善且 NIS 仍低”。
6. 下一阶段是否值得设计可在线实现的 bias 处理：**是**。

上述判断只决定下一阶段研究方向，不会把 oracle 常数补偿自动写入正式估计器。

## 产物

- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_bias_ablation.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_bias_ablation.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_bias_ablation_runs.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_01_vy_rmse.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_02_r_rmse.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_03_state_bias.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_04_nis_mean.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_05_nees_mean.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_06_B0_B3_vy_trace.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_07_B0_B3_r_trace.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_7_08_B0_B3_innovation.png`
- `D:\UsersData\桌面\two\model\vx_vy_dekf_v1_7.slx`
- `D:\UsersData\桌面\two\matlab\run_vy_dekf_v1_7_bias_ablation.m`
- `D:\UsersData\桌面\two\matlab\analyze_vy_dekf_v1_7_bias_ablation.m`

**NO FINAL BIAS COMPENSATION WAS APPLIED.**

**Q AND R WERE FIXED.**

**THIS WAS A CONTROLLED BIAS ABLATION ONLY.**
