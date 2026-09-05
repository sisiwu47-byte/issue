# STAGE VY D-EKF V1.5 STATUS

## 验收与冻结项

正式核心与 debug 核心自动测试 120 组，容差 1e-12；`x_new/P_new/innovation/NIS/S/K` 最大差异均为 0。三组仿真各 1601 个 100 Hz 更新点，固定输入逐点一致。

现有 subsystem 输出 Rate Transition 的首点为零初值，随后诊断延迟一个样本。离线顺序重放与模型可见的 1600 个更新点最大差异为 `[0 0 0]`，因此预算统计使用经验证的完整 1601 点重放序列。

**NO Q OR R WAS CHANGED IN V1.5.**

## 核心预算统计（典型值取 median）

|Case|Q11/Ppred11|Q22/Ppred22|HPH/S11|R/S11|HPH/S22|R/S22|mean(S11)/var(nuAy)|mean(S22)/var(nur)|
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|1|0.184138682|0.403556889|0.739681681|0.260318319|0.198587294|0.801412706|664.599791|198.789821|
|2|0.516657429|0.833372512|0.643602982|0.356397018|0.780978936|0.219021064|160.162436|96.3262138|
|9|0.924115074|0.991446156|0.94987695|0.0501230504|0.988897136|0.0111028643|136.390982|72.8079656|

## Per-channel normalized innovation

|Case|Ay mean|Ay median|Ay p95|Ay max|r mean|r median|r p95|r max|
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|1|0.00234835145|0.000930468033|0.0088152955|0.0501454269|0.00554886014|0.0024514594|0.0205146118|0.0376802258|
|2|0.0137963195|0.00652516951|0.0501956913|0.136403072|0.0108456767|0.00509089371|0.0429637587|0.107881316|
|9|0.018724967|0.00774706538|0.0728420077|0.220482751|0.014638145|0.00682858146|0.055228034|0.164089857|

## Kalman gain mean（完整 mean/median/min/max 位于 CSV）

|Case|K11|K12|K21|K22|
|---:|---:|---:|---:|---:|
|1|-0.0910838697|-0.045565846|0.0439911583|0.1950062|
|2|-0.0661260168|-0.112910516|-0.0119104025|0.768643397|
|9|-0.106914952|-0.181082311|-0.00209257612|0.985030878|

## 对最终问题的回答

1. vy 状态的典型 Q11/Ppred11（Case 1/2/9）为 `[0.18413868 0.51665743 0.92411507]`。
2. r 状态的典型 Q22/Ppred22（Case 1/2/9）为 `[0.40355689 0.83337251 0.99144616]`。
3. Ay 的 HPH'/S 与 R/S（Case 1/2/9）分别为 `[0.73968168 0.64360298 0.94987695]` 与 `[0.26031832 0.35639702 0.05012305]`。
4. r 的 HPH'/S 与 R/S（Case 1/2/9）分别为 `[0.19858729 0.78097894 0.98889714]` 与 `[0.80141271 0.21902106 0.011102864]`。
5. mean(S11)/var(nu_Ay) 为 `[664.59979 160.16244 136.39098]`。
6. mean(S22)/var(nu_r) 为 `[198.78982 96.326214 72.807966]`。
7. Case 1 到 Case 9，R_r 降低 883.049844 倍、R_Ay 降低 14.5957786 倍。Case 9 中剩余的 S 预算及 Q/Ppred 比例见上表，因此单纯继续降低 R 不能消除由预测协方差形成的下限。
8. **支持**：当前证据支持 Q/Ppred 过于保守是 NIS 偏低的主要原因之一；该判断不等价于 Q 是唯一原因，模型误差、bias 和有色噪声仍然存在。
9. 下一阶段仅建议另建副本做 Q 扫描：Q11=`[1e-4,3e-5,1e-5]`，Q22=`[1e-3,3e-4,1e-4]`，固定代表性 R、工况和全部其他条件；V1.5 未执行该扫描。
10. **NO Q OR R WAS CHANGED IN V1.5.**

S 重构最大误差：`[0 0 0]`；P_noQ 重构最大误差：`[0 0 0]`；P_pred=P_noQ+Q 最大误差：`[1.3878e-17 1.3878e-17 1.3878e-17]`。

## 输出文件

- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_covariance_audit.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_covariance_audit.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_covariance_audit_runs.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_P_pred.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_S_Ay_budget.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_S_r_budget.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_innovation_vs_S.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_Q_contribution.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_5_Kalman_gain.png`
- `D:\UsersData\桌面\two\model\vx_vy_dekf_v1_5.slx`
- `D:\UsersData\桌面\two\matlab\analyze_vy_dekf_v1_5_covariance_audit.m`
- `D:\UsersData\桌面\two\matlab\run_vy_dekf_v1_5_covariance_audit.m`
- `D:\UsersData\桌面\two\matlab\vy_dynamic_ekf_step_v15_debug.m`
- `D:\UsersData\桌面\two\matlab\vy_dynamic_ekf_v1_5.m`
- `D:\UsersData\桌面\two\tests\test_vy_dynamic_ekf_step_v15_debug_equivalence.m`
