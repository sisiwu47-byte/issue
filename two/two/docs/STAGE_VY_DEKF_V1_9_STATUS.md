# STAGE VY D-EKF V1.9 STATUS

## 范围与验收

V1.9 仅使用已有 V1.7/V1.8 数据做离线诊断；未运行 CarSim/Simulink，未修改 Q/R、在线 D-EKF、轮胎参数或任何模型修正。

- 有效一步样本：1600，Ts=0.01 s。
- B0/B3 过程输入和真值最大差异：0；两者过程审计相同。
- diagnostic helper vs verified debug x_pred 最大差异：0。
- helper vs V1.8 archived x_pred 最大差异：0。
- lag 定义：**positive lag L means input leads residual by L samples**。
- B3 是主要 oracle-corrected diagnostic case，不是最终在线估计器；B0 仅作 control。

## KNOWN BEFORE V1.9（V1.8 结论）

- B3 NEES mean=17.5554，主要来自 Vy diagonal term。
- 固定 IMU bias 不解释剩余 NEES。
- 一步残差全局均值接近0，但高度有色且与 signed steering 强相关。
- V1.8 未执行 DeltaFy/DeltaMz、前后轴或 full-geometry 归因。

## NEWLY MEASURED IN V1.9

### Current vs full-geometry 一步残差

|Model|State|mean|RMS|p95 abs|max abs|rho1|rho10|RMS reduction|
|:--|:--|--:|--:|--:|--:|--:|--:|--:|
|Current|Vy|3.8986342e-06|0.00268235231|0.00549367051|0.00584116363|0.999545|0.955597|0%|
|Current|r|1.91947175e-06|0.00238242568|0.0039391287|0.00396935593|0.999636|0.964376|0%|
|FullGeometry|Vy|3.8986342e-06|0.00268235231|0.00549367051|0.00584116363|0.999545|0.955597|7.40087e-09%|
|FullGeometry|r|1.91949992e-06|0.00238239069|0.00393906985|0.00396927524|0.999636|0.964375|0.00146856%|

导数形式模型缺陷 `d_model=w_model/Ts`：

|Model|State|mean|std|RMS|p95 abs|max abs|rho1|rho10|
|:--|:--|--:|--:|--:|--:|--:|--:|--:|
|Current|Vy|0.00038986342|0.26831881|0.26823523|0.54936705|0.58411636|0.999545|0.955597|
|Current|r|0.00019194717|0.23831698|0.23824257|0.39391287|0.39693559|0.999636|0.964376|
|FullGeometry|Vy|0.00038986342|0.26831881|0.26823523|0.54936705|0.58411636|0.999545|0.955597|
|FullGeometry|r|0.00019194999|0.23831348|0.23823907|0.39390698|0.39692752|0.999636|0.964375|

导数缺陷的 zero-lag signed correlation：

|Input|Residual|current|full|abs correlation reduction|
|:--|:--|--:|--:|--:|
|Steer_FL|dVy|-0.734941|-0.734941|2.34984e-08%|
|Steer_FL|dr|-0.991547|-0.991546|0.000114513%|
|Steer_FR|dVy|-0.734941|-0.734941|2.34985e-08%|
|Steer_FR|dr|-0.991546|-0.991545|0.000114514%|
|Steer_RL|dVy|0.255047|0.255047|9.51494e-08%|
|Steer_RL|dr|0.807074|0.807076|-0.000286009%|
|Steer_RR|dVy|0.255702|0.255702|9.48338e-08%|
|Steer_RR|dr|0.807512|0.807514|-0.000290362%|
|FrontMeanSteer|dVy|-0.734941|-0.734941|2.34984e-08%|
|FrontMeanSteer|dr|-0.991546|-0.991545|0.000114514%|
|Ay_true|dVy|-0.455674|-0.455674|4.96419e-08%|
|Ay_true|dr|-0.918562|-0.918563|-0.000114796%|
|r_true|dVy|-0.526095|-0.526095|4.12271e-08%|
|r_true|dr|-0.945196|-0.945196|-5.56149e-05%|
|dr_true_dt|dVy|-0.833451|-0.833451|-1.56413e-08%|
|dr_true_dt|dr|-0.299153|-0.299147|0.00198626%|

### 等效总力、横摆力矩和前后轴缺陷

`Fy_total_true_equiv=m*Ay_true`，没有重复用 `m*(dVy/dt+Vx*r)` 构造。`Mz_true_equiv=Iz*gradient(r_true)`。

|Quantity|Unit|mean|RMS|p95 abs|max abs|rho1|rho10|corr steer|corr Ay|corr r|corr dr|
|:--|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
|DeltaFy_current|N|0.7232696|499.3833|1017.7746|1070.9095|0.99955|0.95597|-0.74096|-0.46377|-0.53388|-0.82815|
|DeltaFy_full|N|0.7232696|499.3833|1017.7746|1070.9095|0.99955|0.95597|-0.74096|-0.46377|-0.53388|-0.82815|
|DeltaMz_current|N*m|0.51578116|634.81338|1048.6493|1056.4532|0.99963|0.96424|-0.99092|-0.91708|-0.94373|-0.30168|
|DeltaMz_full|N*m|0.51578873|634.80398|1048.6334|1056.4315|0.99963|0.96424|-0.99092|-0.91708|-0.94373|-0.30168|
|DeltaFyf|N|0.60880283|485.25924|889.36332|979.947|0.99959|0.95955|-0.89694|-0.69305|-0.74815|-0.64514|
|DeltaFyr|N|0.11446677|141.23636|249.91927|259.98925|0.99959|0.95981|0.46184|0.74135|0.68282|-0.71162|

前后轴重构是 bicycle-equivalent offline diagnostic，不是 CarSim 真实轮胎力，也不是新估计模型。

|Axle|equiv RMS|model RMS|defect mean|defect RMS|corr steer|peak corr|lag|gain|offset|model-equiv corr|
|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
|Front|1441.6058|1840.0462|0.60880283|485.25924|-0.896944|-0.987122|-17|1.25793|-0.617299|0.985539|
|Rear|989.93769|875.28422|0.11446677|141.23636|0.461844|0.830448|20|0.88071|-0.111861|0.996075|

### Full-geometry 新增项量级

|Term|force RMS N|force/model|moment RMS Nm|moment/model|
|:--|--:|--:|--:|--:|
|A rear steering cosine|1.39241898e-07|5.19851e-09%|2.46458159e-07|2.75227e-08%|
|B Fx*sin(delta)|0|0%|0|0%|
|C track-width yaw moment|0|0%|0.0124816396|0.00139386%|
|D other transform difference|2.4511319e-13|9.15116e-15%|2.74462928e-13|3.06501e-14%|

Fx 核查：

|Wheel|RMS Fx N|max abs Fx N|
|:--|--:|--:|
|FL|0|0|
|FR|0|0|
|RL|0|0|
|RR|0|0|

`lambda=zeros(4,1)` 下 Fx 数值上为0。full geometry 真正新增主要是后轮 steering cosine 和 `-y*Fxb` track yaw moment。

### 左右转向条件偏差

|Group|N|DeltaFy mean/RMS|DeltaMz mean/RMS|DeltaFyf mean/RMS|DeltaFyr mean/RMS|
|:--|--:|:--|:--|:--|:--|
|left >0.002|456|-471.7799 / 636.5507|-805.3381 / 842.0768|-556.0639 / 632.2393|84.284 / 177.1918|
|near-zero <=0.002|689|-9.143703 / 167.0484|5.691666 / 54.86731|-3.556844 / 106.7667|-5.58686 / 64.3366|
|right <-0.002|455|489.2063 / 654.683|800.303 / 837.789|564.813 / 640.4551|-75.60661 / 180.0331|

### 时滞、转向速率与 hysteresis

|Input|Residual|peak corr|lag samples|lag seconds|
|:--|:--|--:|--:|--:|
|FrontMeanSteer|dVy|-0.954888|-20|-0.2|
|FrontMeanSteer|dr|-0.992172|-1|-0.01|
|Ay_true|dVy|-0.820715|-20|-0.2|
|Ay_true|dr|-0.994042|-16|-0.16|
|r_true|dVy|-0.864947|-20|-0.2|
|r_true|dr|-0.993095|-12|-0.12|
|dr_true_dt|dVy|-0.947996|18|0.18|
|dr_true_dt|dr|-0.691259|20|0.2|

|Axle|valid bins|separation RMS|normalized hysteresis index|possible evidence|
|:--|--:|--:|--:|:--:|
|Front|12|534.0087|1.10046|是|
|Rear|12|314.8284|2.22909|是|

steering-rate tertiles：

|Group|N|wVy current/full RMS|wr current/full RMS|
|:--|--:|:--|:--|
|T1|533|3.939105e-06 / 3.939105e-06|1.120261e-06 / 1.120261e-06|
|T2|534|0.00297408 / 0.00297408|0.003389419 / 0.00338935|
|T3|533|0.003568863 / 0.003568863|0.002351338 / 0.002351331|

## V1.9 最终回答

1. 当前失配是否主要来自力/力矩几何遗漏：**否**。DeltaFy/DeltaMz RMS reduction=7.63281e-09% / 0.00148017%。
2. full geometry 是否显著降低 Vy residual：**否**（7.40087e-09%）。
3. full geometry 是否显著降低 r residual：**否**（0.00146856%）。
4. signed steering correlation 绝对值变化：Vy 2.34984e-08%，r 0.000114514%。
5. full candidate 后是否仍存在非零相位结构/高度有色残差：**是 / 是**。 部分峰值命中 +/-20 样本边界，因此本阶段不把峰值 lag 解释为精确物理时延。
6. 左右转向是否存在近似反对称条件bias：**是**。
7. V1.10 优先方向：**tire transient/relaxation investigation**；次级线索：**tire steady-state gain/shape audit after transient attribution**。
8. 当前误差首先表现为：**both total lateral force and yaw moment**（relative RMS 0.207204 / 1.35512）。
9. bicycle-equivalent 前后轴分解中模型残差更大的车轴：**Front**。
10. geometry candidate 新增项量级是否足以解释当前残差：**否**。最大 force/moment correction 为当前模型 RMS 的 5.19851e-09% / 0.00139386%。
11. 下一阶段最应检查：**tire transient/relaxation investigation**；然后检查 **tire steady-state gain/shape audit after transient attribution**。名义 prediction 残差不使用 Jacobian，因此 numerical Jacobian 不是本轮缺陷的直接来源。

残差对 steering amplitude/rate 的增长比为 18.1989 / 2098.92，当前更强依赖 **steering rate/dynamic transition**。

## 产物

- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_model_mismatch.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_force_moment.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_lags.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_correlations.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_conditions.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_geometry_terms.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_axle_attribution.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_model_mismatch.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_01_derivative_defects.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_02_force_moment_defects.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_03_axle_equiv_vs_model.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_04_axle_defect_vs_steer.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_05_hysteresis.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_06_geometry_magnitude.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_07_left_right_bias.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_9_08_axle_defect_time.png`
- `D:\UsersData\桌面\two\matlab\analyze_vy_dekf_v1_9_model_mismatch.m`
- `D:\UsersData\桌面\two\matlab\vy_dekf_v1_9_prediction_audit.m`

**NO MODEL CORRECTION WAS APPLIED ONLINE.**

**Q AND R WERE FIXED.**

**THIS WAS AN OFFLINE MODEL-MISMATCH ABLATION ONLY.**
