# STAGE VY D-EKF V1.8 STATUS

## 边界与时间对齐

本阶段仅对已有 V1.7 结果做离线诊断；没有重新仿真、调 Q/R、创建 adaptive-Q 或把真值送入在线 EKF。B3 是去除已知固定 bias 后的主要残差诊断 case，仍然只是 oracle ablation，不是最终在线估计器。

Rate Transition 已验证的实际对应关系：

- x_hat index: `audits.states(i,:)`
- posterior P_new index: `audits.pNew(:,:,i)`
- truth index: `runs.vyTrue(i+1), runs.rTrue(i+1)`
- reported time: `runs.t(i+1)`
- update input index: `runs.u(i,:)`
- 因此 `x_hat(i)` 与同一 replay update 的 `P_new(:,:,i)` 组合，再对齐 `truth(i+1)`；未使用 P_pred。
- 原始 100 Hz truth/input 格点 1601 个；一步过程残差 1600 个，正好少一个；posterior/NEES 因 Rate Transition 因果对齐后为 1600 个；`Ts=0.01 s`。

clean Ay 来源：`CarSim Ay -> Gain36=9.8 before IMU bias/noise/filter`；与 V1.7 true-r 和在线输入的最大差异为 0 / 0。

## Full NEES、marginal NSEE 与 coverage

`eVy^2/P11` 和 `er^2/P22` 仅定义为 marginal normalized squared error，不是 full-NEES 分解项。

|Case|NEES mean|marg Vy|marg r|Vy diagonal|cross|r diagonal|identity max|
|:--|--:|--:|--:|--:|--:|--:|--:|
|B0|17.7949936|16.6782211|0.275580942|17.7093966|-0.212876948|0.298473935|2.84e-14|
|B3|17.555431|16.5165617|0.13729734|17.527701|-0.120379957|0.148109961|2.84e-14|

full term 通过 2x2 解析系数计算，NEES 本身通过 `P\e` 线性求解；没有显式 `inv(P)`。cross term 允许为负。

高斯单状态 coverage 参考：1sigma=68.27%，2sigma=95.45%，3sigma=99.73%；仅作参考，不是硬判据。

|Case|Vy 1s|Vy 2s|Vy 3s|r 1s|r 2s|r 3s|Vy rho1/rho10|r rho1/rho10|
|:--|--:|--:|--:|--:|--:|--:|:--|:--|
|B0|0.4506|0.5312|0.6069|0.9456|1.0000|1.0000|0.9995 / 0.9597|0.9639 / 0.7775|
|B3|0.4437|0.5269|0.6038|0.9988|1.0000|1.0000|0.9995 / 0.9596|0.9636 / 0.7769|

## B3 动态条件结果

|Section|Group|N|Vy RMSE|r RMSE|NEES mean|NEES p95|>95%|
|:--|:--|--:|--:|--:|--:|--:|--:|
|Overall|all|1600|0.0372034|0.00415537|17.5554|70.8165|0.4462|
|Time|initial t<1 s|99|0.000708042|0.00159288|0.0221779|0.0694359|0.0000|
|Steering|low <=0.002|689|0.0122009|0.00267819|1.93285|16.9139|0.1060|
|Steering|mid (0.002,0.01]|261|0.0416552|0.00542015|24.4522|62.8974|0.6667|
|Steering|high >0.01|650|0.050522|0.00480669|31.346|73.1469|0.7185|
|AbsAyTrue|Q1 [4.32785e-16, 2.55988e-05]|400|0.000807875|0.00178077|0.0283189|0.102374|0.0000|
|AbsAyTrue|Q2 [2.57592e-05, 0.681039]|400|0.0379543|0.00283536|20.7311|67.7583|0.4525|
|AbsAyTrue|Q3 [0.691673, 1.87866]|400|0.0531845|0.00510222|35.623|73.7883|0.7375|
|AbsAyTrue|Q4 [1.88713, 2.33531]|400|0.0355892|0.0056414|13.8393|39.563|0.5950|
|AbsDrTrueDt|Q1 [1.64304e-18, 4.52249e-07]|400|0.000826495|0.001815|0.0294595|0.105409|0.0000|
|AbsDrTrueDt|Q2 [4.66441e-07, 0.0846973]|400|0.0241212|0.00398825|6.25564|22.5477|0.3850|
|AbsDrTrueDt|Q3 [0.0854052, 0.246978]|400|0.0445484|0.00534725|23.2885|64.4558|0.5150|
|AbsDrTrueDt|Q4 [0.246979, 0.369531]|400|0.0544912|0.00461249|40.6482|73.7883|0.8850|

## 一步过程模型残差

严格调用 `vy_dynamic_ekf_step_v15_debug` 的现有 prediction，输入 `x_true(k),u(k)` 并只读取 measurement update 前的 `info.x_pred`。`z` 对 x_pred 的数值影响已验证为 0。

|State|N|mean|std|RMS|p95 abs|max abs|rho1|rho10|RMS/sqrt(Qii)|
|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|
|Vy|1600|3.8986342e-06|0.0026831881|0.00268235231|0.00549367051|0.00584116363|0.999545|0.955597|0.268235|
|r|1600|1.91947175e-06|0.00238316976|0.00238242568|0.0039391287|0.00396935593|0.999636|0.964376|0.238243|

`dr_true/dt` 内部样本使用 MATLAB `gradient` 中央差分，两个边界样本使用一侧差分。主相关性使用 Ay_true；Ay_IMU 只作附加对照。

过程残差的动态分组：

|Section|Group|N|wVy mean|wVy RMS|wr mean|wr RMS|
|:--|:--|--:|--:|--:|--:|--:|
|Steering|low <=0.002|689|-4.70601e-05|0.000905328|1.89987e-05|0.000194595|
|Steering|mid (0.002,0.01]|261|8.49754e-05|0.00335673|-2.34366e-05|0.00186049|
|Steering|high >0.01|650|2.53594e-05|0.00350965|-6.00312e-06|0.0035414|
|AbsAyTrue|Q1|400|1.44732e-06|2.93296e-06|2.59153e-07|5.28651e-07|
|AbsAyTrue|Q2|400|4.79462e-05|0.00316671|2.39049e-05|0.00148071|
|AbsAyTrue|Q3|400|-4.63221e-05|0.00375842|-1.67845e-05|0.00266104|
|AbsAyTrue|Q4|400|1.25232e-05|0.00215088|2.98354e-07|0.00366472|
|AbsDrTrueDt|Q1|400|1.48637e-06|2.98786e-06|2.63349e-07|5.29403e-07|
|AbsDrTrueDt|Q2|400|-6.09222e-05|0.00143043|1.04628e-05|0.00263683|
|AbsDrTrueDt|Q3|400|6.75006e-06|0.00290367|-5.70979e-05|0.00328182|
|AbsDrTrueDt|Q4|400|6.82803e-05|0.00427816|5.40497e-05|0.00223173|

主 signed/absolute 相关性：

|Variable|corr wVy|corr wr|corr abs wVy|corr abs wr|
|:--|--:|--:|--:|--:|
|FrontMeanSteer|-0.734941|-0.991546|0.571853|0.984562|
|MaxAbsSteer|0.0062226|-0.00262214|0.571791|0.984559|
|Ay_true|-0.455674|-0.918562|0.289875|0.8689|
|dr_true_dt|-0.833451|-0.299153|0.755713|0.423055|

## 最终判断

1. NEES 主要由哪个状态贡献：**Vy**。
2. 去 bias 后剩余 NEES 峰值位于 **t=3.44 s**。最高分组：steering `high >0.01 (NEES mean 31.346)`，|Ay_true| `Q3 [0.691673, 1.87866] (NEES mean 35.623)`，|dr_true/dt| `Q4 [0.246979, 0.369531] (NEES mean 40.6482)`。
3. 当前 P 主要低估的状态：**Vy**。
4. 一步过程残差 RMS 是否超过 sqrt(Qii)：**否**。
5. 是否存在随 steering/Ay 增长的动态相关残差：**是**（最大高/低 RMS 比 6932.2）。但是否能解释为纯随机 state-dependent uncertainty：**否**；强 signed 相关性需先排查模型失配。
6. V1.9 应优先研究：**model correction**。
7. full NEES 高的主要来源：**Vy diagonal term**。B3 mean terms=[17.5277, -0.12038, 0.14811]。
8. marginal normalized error 与 full-NEES decomposition 是否给出一致结论：**是**。
9. 过程残差全局均值接近0且RMS随动态增加：**是**。这排除单一固定 bias；但由于 signed correlation 高达 0.991546，不能仅解释为随机 state-dependent Q。
10. 是否存在系统性模型失配证据：**是**。虽然左右转向抵消后全局均值接近0，残差与 signed steering/Ay 的强相关表明误差具有可预测的方向性。优先 model correction，不用增大Q掩盖。
11. **NO ADAPTIVE-Q ALGORITHM WAS CREATED.** V1.8 只决定 V1.9 研究优先级。

## 产物

- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_nees_source.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_process_residual.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_process_correlations.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_process_conditions.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_nees_source.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_01_B0_B3_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_02_B3_marginal_nsee.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_03_B3_full_nees_terms.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_04_B3_error_2sigma.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_05_steering_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_06_Ay_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_07_process_residual.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_8_08_residual_scatter.png`
- `D:\UsersData\桌面\two\matlab\analyze_vy_dekf_v1_8_nees_source.m`

B3 WAS USED ONLY AS AN ORACLE-CORRECTED DIAGNOSTIC CASE.

NO ONLINE ESTIMATOR OR ADAPTIVE-Q LOGIC WAS CREATED.
