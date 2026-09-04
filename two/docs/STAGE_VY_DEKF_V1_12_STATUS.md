# STAGE VY D-EKF V1.12 STATUS

## Scope and fixed configuration

Seven independent CarSim/Simulink cases were run with 1601 updates each at 100 Hz. The online D-EKF remained the original V1.7 dynamics with Q/R fixed. Fixed gains kf=0.781809347 and kr=1.09185835 came only from V1.11 TRAIN and were evaluated offline.

FULL dynamic interval: 3<=t<=13 s. Quasi-steady: |front steer|>0.005 rad and the lowest 25% |steering rate| within each case.

## Actual operating conditions

Actual min/max statistics below use the 3--13 s excitation interval, excluding the initial speed-settling transient.

|Case|target Vx|actual Vx min/mean/max|max steer FL/FR/RL/RR|max |Ay||max |r||max |Vy||outside envelope|
|:--|--:|:--|:--|--:|--:|--:|:--|
|N|20|19.977 / 19.979 / 19.982|0.019976 / 0.019975 / 2.4492e-05 / 2.4486e-05|2.3353|0.12289|0.099626|0|
|V15|15|14.985 / 14.986 / 14.987|0.019982 / 0.019982 / 1.3368e-05 / 1.3535e-05|1.4661|0.097406|0.035844|0|
|V25|25|24.965 / 24.971 / 24.976|0.019971 / 0.019969 / 3.7461e-05 / 3.7459e-05|3.2647|0.14372|0.31128|0|
|A10|20|19.981 / 19.981 / 19.982|0.0099873 / 0.0099867 / 1.0885e-05 / 1.0878e-05|1.185|0.061909|0.04705|0|
|A30|20|19.97 / 19.976 / 19.982|0.029967 / 0.029967 / 3.8459e-05 / 3.8458e-05|3.4219|0.18222|0.1654|0|
|F20|20|19.976 / 19.979 / 19.982|0.019975 / 0.019975 / 2.517e-05 / 2.517e-05|2.4476|0.12425|0.090271|0|
|F60|20|19.978 / 19.98 / 19.982|0.019977 / 0.019977 / 2.3542e-05 / 2.3542e-05|2.1712|0.12076|0.097107|0|

## Effective-gain cross-condition audit

|Case|kf eff|kf drift|kr eff|kr drift|kf after sigmaF1|quasi N|
|:--|--:|--:|--:|--:|--:|--:|
|N|0.784225292|0.30902%|1.09542819|0.32695%|0.803842337|203|
|V15|0.745323468|-4.6669%|1.04561279|-4.2355%|0.743476054|203|
|V25|0.820982672|5.0106%|1.13715598|4.1487%|0.850287088|202|
|A10|0.715806395|-8.4423%|1.03604229|-5.112%|0.73453229|163|
|A30|0.844720823|8.0469%|1.14235924|4.6252%|0.865343695|217|
|F20|0.815825184|4.3509%|1.14814702|5.1553%|0.82147715|204|
|F60|0.73432324|-6.0739%|1.00432741|-8.0167%|0.774346129|203|

Dependence ranges (max-min):

|Dimension|kf range|kr range|
|:--|--:|--:|
|Speed|0.0756592037|0.0915431901|
|Amplitude|0.128914427|0.106316949|
|Frequency|0.0815019441|0.143819609|

Largest dimension: kf **Amplitude**, kr **Frequency**. corr(gain,max|Ay|)=0.90903 / 0.75866. Front frequency range before/after sigmaF1: 0.0815019441 / 0.0471310205 (reduction 42.172%).

## FULL dynamic Current vs fixed gain

|Case|Fyf red|Fyr red|Fy red|Mz red|wVy red|wr red|Current/Fixed Fy RMS|Current/Fixed Mz RMS|
|:--|--:|--:|--:|--:|--:|--:|:--|:--|
|N|49.584%|34.497%|32.998%|78.152%|32.41%|78.483%|630.862 / 422.689|802.481 / 175.329|
|V15|48.111%|9.0121%|37.213%|69.443%|37.202%|69.968%|582.189 / 365.541|574.874 / 175.666|
|V25|41.039%|39.935%|12.903%|82.905%|10.941%|83.206%|628.913 / 547.765|1023.84 / 175.028|
|A10|54.579%|19.424%|42.259%|75.586%|42.016%|75.638%|408.263 / 235.735|471.719 / 115.167|
|A30|35.302%|35.51%|14.909%|77.015%|14.128%|77.804%|779.444 / 663.235|1031.18 / 237.014|
|F20|65.55%|51.452%|39.812%|88.431%|39.141%|88.46%|426.737 / 256.843|841.069 / 97.3025|
|F60|40.926%|18.12%|30.796%|64.758%|30.181%|65.987%|828.277 / 573.198|752.194 / 265.09|

## Quasi-steady Current vs fixed gain

|Case|Fy red|Mz red|Fyf red|Fyr red|wVy red|wr red|
|:--|--:|--:|--:|--:|--:|--:|
|N|77.318%|98.443%|88.275%|65.612%|76.689%|98.582%|
|V15|70.573%|95.869%|82.335%|-0.85891%|70.522%|95.536%|
|V25|41.756%|95.72%|72.791%|59.59%|37.819%|96.544%|
|A10|64.825%|90.173%|75.74%|-37.205%|65.212%|89.417%|
|A30|6.8698%|88.001%|56.73%|57.871%|3.8961%|89.339%|
|F20|46.233%|98.104%|80.451%|61.169%|44.664%|97.897%|
|F60|61.748%|94.399%|76.669%|-74.367%|61.925%|95.751%|

## Unmodified online D-EKF baseline

|Case|Vy RMSE|r RMSE|NIS mean/p95|NEES mean/p95|replay max|
|:--|--:|--:|:--|:--|--:|
|N|0.037391971|0.0058728121|0.0779831 / 0.253996|17.795 / 70.6353|0|
|V15|0.022388318|0.0047371499|0.0519185 / 0.185856|10.5633 / 37.8163|0|
|V25|0.053056702|0.0071621211|0.120078 / 0.370892|24.6944 / 113.705|0|
|A10|0.021454928|0.0048708706|0.0409202 / 0.139583|6.64578 / 23.8141|0|
|A30|0.050701665|0.007132823|0.12572 / 0.389968|29.9005 / 136.692|0|
|F20|0.024931996|0.0058331476|0.0786551 / 0.261832|7.80578 / 32.0818|0|
|F60|0.049167524|0.0060526936|0.0840323 / 0.275761|31.0113 / 115.41|0|

## Final answers

1. Cross-speed generalization: kf/kr ranges 0.0756592 / 0.0915432.
2. Cross-amplitude generalization: kf/kr ranges 0.128914 / 0.106317.
3. Cross-frequency generalization: kf/kr ranges 0.0815019 / 0.14382.
4. Largest kf dependence: **Amplitude**.
5. Largest kr dependence: **Frequency**.
6. Non-nominal cases improving all four Fy/Mz/wVy/wr: 6/6.
7. Any normal case worse by >10%: **NO**.
8. Gain behavior is not perfectly invariant: kf shows the strongest amplitude/max-|Ay| dependence, while kr shows the strongest frequency dependence; speed dependence is smaller. All observed drifts remain within about 10%.
9. sigma_f=1 frequency-dependence reduction: 42.1719%.
10. Sufficient support to recommend online axle-scaling implementation next: **YES**. Recommendation: **A. V1.13 formal constant axle-gain implementation**. V1.13 was not executed.

## Outputs

- `D:\UsersData\桌面\two\model\vx_vy_dekf_v1_12.slx`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_cross_condition.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_cross_condition.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_01_kf_vs_Vx.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_02_kr_vs_Vx.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_03_gain_vs_amplitude.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_04_gain_vs_frequency.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_05_gain_vs_maxAy.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_06_DeltaFy_reduction.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_07_DeltaMz_reduction.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_08_state_residual_reduction.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_09_fixed_current_heatmap.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_12_10_transient_gain_vs_frequency.png`

**FIXED AXLE GAINS WERE EVALUATED OFFLINE ONLY.**

**NO AXLE-SCALING CORRECTION WAS APPLIED ONLINE.**

**NO TIRE OR VEHICLE PARAMETER WAS CHANGED.**
