# STAGE VY D-EKF V1.15 STATUS

## Fixed scope and anchors

V1.15 performed the final planned structured diagonal covariance calibration on an isolated V1.15 model copy. Alignment: `x_hat(i), P_new(:,:,i), truth(i+1)`.

|Case|empirical Ay variance|empirical r variance|
|:--|--:|--:|
|N|0.00068555327|1.1326666e-05|
|V15|0.00027420835|1.0635274e-05|
|V25|0.0013385065|1.2029195e-05|
|A10|0.00018071057|9.9182234e-06|
|A30|0.0014977069|1.3655889e-05|
|F20|0.00020312381|1.0140586e-05|
|F60|0.001277437|1.3682358e-05|

- R_emp = diag([0.000685553271, 1.13266661e-05])
- R_cons = diag([0.00205665981, 3.39799984e-05])
- Wrapper C0/V1.13 120-step equality max: 0.
- Vehicle/log input equality across configurations: calibration 0, full 0; C0 vs V1.13 archive input/output 0 / 0.
- Simulations: 36 calibration + 21 full = 57. Each run has 1601 updates and 1600 scored posterior samples.

## Four-case calibration screen

|Configuration|Qvy/Qr|RAy/Rr|worst Vy/r improve|high Vy marginal|high NEES|median gamma Vy/r|mean NIS|axis|reject|Pareto|selected|
|:--|:--|:--|:--|--:|--:|:--|--:|--:|:--|:--|:--|
|C0|0.0001 / 0.0001|0.01 / 0.0003365|0% / 0%|19.969|20.2|19.47 / 0.07717|0.05377|73.22|0|0|0|
|Qv0.0003_Qr1e-05_RE|0.0003 / 1e-05|0.0006856 / 1.133e-05|0.3018% / -22.57%|135.81|142.97|128.6 / 2.589|0.476|6.484|1|0|0|
|Qv0.0003_Qr1e-05_RC|0.0003 / 1e-05|0.002057 / 3.398e-05|0.1999% / -6.102%|49.87|52.351|47.67 / 0.8175|0.3079|4.12|0|1|1|
|Qv0.0003_Qr3e-05_RE|0.0003 / 3e-05|0.0006856 / 1.133e-05|0.3531% / -34.09%|135.38|142.15|128.4 / 2.493|0.2429|9.031|1|0|0|
|Qv0.0003_Qr3e-05_RC|0.0003 / 3e-05|0.002057 / 3.398e-05|0.2691% / -22.44%|49.681|52.02|47.57 / 0.861|0.1655|6.357|1|0|0|
|Qv0.001_Qr1e-05_RE|0.001 / 1e-05|0.0006856 / 1.133e-05|0.3123% / -22.62%|130.57|137.78|122.8 / 2.592|0.4687|6.518|1|0|0|
|Qv0.001_Qr1e-05_RC|0.001 / 1e-05|0.002057 / 3.398e-05|0.2018% / -6.388%|45.24|47.782|42.72 / 0.8204|0.3012|4.255|0|1|1|
|Qv0.001_Qr3e-05_RE|0.001 / 3e-05|0.0006856 / 1.133e-05|0.3695% / -34.14%|130.12|136.92|122.5 / 2.494|0.2353|8.92|1|0|0|
|Qv0.001_Qr3e-05_RC|0.001 / 3e-05|0.002057 / 3.398e-05|0.3033% / -22.58%|45.03|47.418|42.6 / 0.8633|0.1583|6.49|1|0|0|

No single weighted cost was used. Candidates first passed the >10% state-error/stability gates, then non-dominated points were identified. The selected pair represents consistency-first and accuracy-robust Pareto boundaries.

## Full seven-case validation

|Case|Config|Vy RMSE (improve)|r RMSE (improve)|NIS mean/p95|eps std Ay/r|NEES mean/p95|marg Vy/r|gamma Vy/r|2sigma Vy/r|axis|min eig/max cond|stable|
|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|--:|:--|:--|
|N|C0|0.0291469 (+0%)|0.00473114 (+0%)|0.037988 / 0.11914|0.08167 / 0.153|9.4075 / 35.802|9.242 / 0.1813|9.135 / 0.05222|0.5281 / 1.0000|76.33|7.17e-05 / 2.602|1|
|V15|C0|0.0161416 (+0%)|0.004296 (+0%)|0.034321 / 0.11838|0.05553 / 0.1535|4.8292 / 18.578|4.668 / 0.1554|4.524 / 0.03464|0.6400 / 1.0000|83.7|4.76e-05 / 2.602|1|
|V25|C0|0.0553787 (+0%)|0.00503919 (+0%)|0.057011 / 0.18323|0.1509 / 0.1558|20.045 / 62.591|19.85 / 0.2008|21.78 / 0.06913|0.4425 / 1.0000|26.48|7.26e-05 / 2.602|1|
|A10|C0|0.0150101 (+0%)|0.0043982 (+0%)|0.028611 / 0.092817|0.05146 / 0.1333|2.9106 / 11.258|2.771 / 0.158|2.684 / 0.03042|0.7238 / 1.0000|78.22|7.17e-05 / 2.602|1|
|A30|C0|0.0517982 (+0%)|0.00527981 (+0%)|0.062612 / 0.19165|0.1542 / 0.1766|23.177 / 77.631|22.91 / 0.2238|24.65 / 0.0935|0.4406 / 1.0000|71.18|7.17e-05 / 2.602|1|
|F20|C0|0.0182134 (+0%)|0.00449182 (+0%)|0.028114 / 0.089995|0.05278 / 0.1322|3.4887 / 11.463|3.347 / 0.1635|3.446 / 0.03412|0.6250 / 1.0000|77.3|7.17e-05 / 2.602|1|
|F60|C0|0.039404 (+0%)|0.00514158 (+0%)|0.057449 / 0.17493|0.1313 / 0.1796|17.377 / 66.696|17.15 / 0.2139|17.15 / 0.08522|0.4956 / 1.0000|75.25|7.17e-05 / 2.602|1|
|N|Qv0.001_Qr1e-05_RC|0.0289687 (+0.611%)|0.00490981 (-3.78%)|0.26404 / 1.0545|0.03132 / 0.4832|25.222 / 97.343|23.17 / 1.913|22.32 / 0.5392|0.4713 / 0.8688|4.683|1.24e-05 / 4.626|1|
|V15|Qv0.001_Qr1e-05_RC|0.016041 (+0.623%)|0.00438473 (-2.07%)|0.29004 / 1.1153|0.02046 / 0.4859|15.906 / 59.823|14.2 / 1.595|13.63 / 0.3523|0.5350 / 0.9344|6.55|1.17e-05 / 2.081|1|
|V25|Qv0.001_Qr1e-05_RC|0.0551305 (+0.448%)|0.00536112 (-6.39%)|0.25461 / 1.0408|0.05785 / 0.4825|42.324 / 150.3|39.97 / 2.218|42.88 / 0.7655|0.4181 / 0.8156|2.829|1.24e-05 / 10.48|1|
|A10|Qv0.001_Qr1e-05_RC|0.0148942 (+0.772%)|0.00454478 (-3.33%)|0.21569 / 0.85539|0.02167 / 0.426|8.9568 / 31.874|7.276 / 1.656|7.137 / 0.3047|0.5881 / 0.9344|3.412|1.24e-05 / 3.009|1|
|A30|Qv0.001_Qr1e-05_RC|0.0516936 (+0.202%)|0.00560228 (-6.11%)|0.33217 / 1.3657|0.05647 / 0.5508|55.101 / 209.13|52.32 / 2.463|53.85 / 1.071|0.4175 / 0.7662|3.828|1.23e-05 / 7.734|1|
|F20|Qv0.001_Qr1e-05_RC|0.0180363 (+0.973%)|0.00466813 (-3.93%)|0.20708 / 0.80467|0.0229 / 0.421|9.8039 / 31.327|8.018 / 1.729|8.304 / 0.3529|0.4925 / 0.9225|4.315|1.24e-05 / 4.88|1|
|F60|Qv0.001_Qr1e-05_RC|0.0391416 (+0.666%)|0.00531919 (-3.45%)|0.3538 / 1.3922|0.04746 / 0.5672|45.92 / 180.25|43.43 / 2.246|42.56 / 0.8754|0.4494 / 0.7969|4.759|1.23e-05 / 4.285|1|
|N|Qv0.0003_Qr1e-05_RC|0.0289823 (+0.565%)|0.00490306 (-3.63%)|0.26735 / 1.0623|0.05592 / 0.483|26.942 / 103.39|24.92 / 1.909|24.19 / 0.5383|0.4650 / 0.8694|4.505|1.23e-05 / 4.15|1|
|V15|Qv0.0003_Qr1e-05_RC|0.0160478 (+0.581%)|0.00438168 (-1.99%)|0.29148 / 1.1162|0.03682 / 0.4858|16.473 / 61.916|14.77 / 1.593|14.21 / 0.3519|0.5294 / 0.9344|6.407|1.17e-05 / 1.974|1|
|V25|Qv0.0003_Qr1e-05_RC|0.0551503 (+0.412%)|0.00534668 (-6.1%)|0.26399 / 1.0408|0.1034 / 0.4822|47.743 / 163.93|45.46 / 2.208|49.38 / 0.7613|0.4144 / 0.8169|2.653|1.24e-05 / 8.591|1|
|A10|Qv0.0003_Qr1e-05_RC|0.0149025 (+0.717%)|0.00453953 (-3.21%)|0.21775 / 0.85639|0.03831 / 0.4257|9.4197 / 33.614|7.752 / 1.653|7.601 / 0.3045|0.5775 / 0.9344|3.155|1.23e-05 / 2.791|1|
|A30|Qv0.0003_Qr1e-05_RC|0.0516946 (+0.2%)|0.00558904 (-5.86%)|0.34031 / 1.3703|0.1016 / 0.5504|60.229 / 222.51|57.51 / 2.453|60.11 / 1.065|0.4138 / 0.7675|3.735|1.23e-05 / 6.583|1|
|F20|Qv0.0003_Qr1e-05_RC|0.0180502 (+0.896%)|0.00466168 (-3.78%)|0.20927 / 0.80944|0.04009 / 0.4207|10.461 / 33.071|8.69 / 1.726|9.023 / 0.3523|0.4856 / 0.9225|4.166|1.23e-05 / 4.358|1|
|F60|Qv0.0003_Qr1e-05_RC|0.039163 (+0.612%)|0.00531199 (-3.31%)|0.35992 / 1.3955|0.08567 / 0.567|49.081 / 191.9|46.64 / 2.241|45.95 / 0.8737|0.4450 / 0.7981|4.541|1.23e-05 / 3.868|1|

## Final freeze decision

Chosen robust Pareto configuration: **Qv0.001_Qr1e-05_RC**. Decision: **DO NOT FREEZE D-EKF V1**.

1. Stable in all seven cases: **YES**.
2. Mean Vy RMSE improvement vs V1.13: **+0.613545%**; no case worse than 10%: **YES**.
3. Mean true-r RMSE improvement vs V1.13: **-4.15007%**.
4. V25/A30/F60 full-NEES reduction: **-136.545%**; Vy-marginal reduction: **-126.552%**.
5. Median gamma Vy: 22.3215 (baseline 9.13515), improved: **NO**.
6. Median gamma r: 0.53925 (baseline 0.0522178), improved: **YES**.
7. Median NIS: 0.264041 (baseline 0.0379877), left extreme 0.01--0.1 scale: **YES**.
8. Standardized innovation std moved toward one: Ay **NO** (0.0968453 -> 0.036876), r **YES** (0.154851 -> 0.488083). Both channels improved: **NO**.
9. Median principal-axis difference: 4.31452 deg (baseline 76.3323 deg), clearly improved: **YES**.
10. Colored standardized residual remains: **YES**; mean |rho1| 0.532258. This is a remaining reliability/robustness-layer limitation, not permission for another D-EKF tuning grid.

## Outputs

- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_covariance_calibration.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_covariance_calibration.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_calibration_screen.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_calibration_config_summary.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_01_calibration_high_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_02_vy_rmse.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_03_nis.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_04_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_05_gamma.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_06_standardized_innovation.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_07_axis.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_15_08_colored_residual.png`

**V1.13 AXLE GAINS REMAIN FROZEN.**

**ONLY DIAGONAL Q/R COVARIANCE WAS CALIBRATED.**

**NO COLORED-NOISE MODEL WAS ADDED.**

**NO OTHER D-EKF MODEL PARAMETER WAS CHANGED.**
