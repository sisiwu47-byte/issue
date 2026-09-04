# STAGE VY D-EKF V1.14 STATUS

## Scope, data, and alignment

Offline audit of the frozen V1.13 corrected model. Seven cases x 1600 posterior/truth-aligned samples = 11200 samples. Alignment: `x_hat(i), posterior P_new(:,:,i), truth(i+1)`. Each source run had 1601 updates at 100 Hz.

## NIS covariance budget and standardized innovations

|Case|S11/var(nuAy)|S22/var(nur)|epsilon Ay std|epsilon r std|eps rho1 Ay/r|eps Neff Ay/r|
|:--|--:|--:|--:|--:|:--|:--|
|N|191.997|46.2531|0.0816705|0.153026|0.87164 / 0.44556|63.623 / 115.95|
|V15|384.401|45.9929|0.0555311|0.153472|0.78369 / 0.44693|77.209 / 118.88|
|V25|60.8706|45.7675|0.150906|0.155812|0.95574 / 0.46659|53.67 / 107.58|
|A10|452.614|60.131|0.0514584|0.133256|0.68249 / 0.26861|120.58 / 265.76|
|A30|58.4137|35.5155|0.154227|0.17662|0.96218 / 0.58378|51.596 / 81.279|
|F20|436.142|61.2344|0.0527757|0.13221|0.69368 / 0.25758|112.54 / 275.63|
|F60|76.5566|33.7805|0.131348|0.179561|0.94921 / 0.59681|55.577 / 82.853|

Full per-case CSV contains mean/median/p95 S_state, R, S, their proportions, epsilon rho1/2/5/10/20, cross-correlation, and innovation covariance.

### Full covariance matrices

Matrices are reported as `[11 12; 21 22]`.

|Case|mean(S)|Cov(innovation)|
|:--|:--|:--|
|N|[0.0249589 0.000348348; 0.000348348 0.000581719]|[0.000129997 9.25558e-06; 9.25558e-06 1.25769e-05]|
|V15|[0.030876 0.00031809; 0.00031809 0.000569297]|[8.03223e-05 9.89051e-06; 9.89051e-06 1.23779e-05]|
|V25|[0.0220035 0.000365786; 0.000365786 0.000589988]|[0.00036148 1.80687e-06; 1.80687e-06 1.2891e-05]|
|A10|[0.0260322 0.000342221; 0.000342221 0.000579185]|[5.75153e-05 1.14804e-05; 1.14804e-05 9.63206e-06]|
|A30|[0.0240094 0.000352061; 0.000352061 0.000584349]|[0.000411024 2.19938e-06; 2.19938e-06 1.64533e-05]|
|F20|[0.024848 0.000352462; 0.000352462 0.00058191]|[5.69723e-05 9.59798e-06; 9.59798e-06 9.50299e-06]|
|F60|[0.025124 0.000341531; 0.000341531 0.000581457]|[0.000328176 1.36149e-05; 1.36149e-05 1.72128e-05]|
## NEES direction and covariance ellipse

|Case|NEES mean|Vy/cross/r terms|Vy marginal|r marginal|gamma Vy|gamma r|axis diff|
|:--|--:|:--|--:|--:|--:|--:|--:|
|N|9.40749|9.30473 / -0.0797017 / 0.182468|9.24225|0.181297|9.13515|0.0522178|76.332 deg|
|V15|4.82919|4.69059 / -0.0174331 / 0.156037|4.66764|0.155388|4.5238|0.0346389|83.699 deg|
|V25|20.0455|20.0414 / -0.198742 / 0.202798|19.8476|0.200754|21.7793|0.0691261|26.485 deg|
|A10|2.91063|2.78315 / -0.0313667 / 0.158847|2.7711|0.157951|2.68431|0.0304233|78.216 deg|
|A30|23.1766|23.1217 / -0.170933 / 0.225807|22.9106|0.223834|24.653|0.0935033|71.182 deg|
|F20|3.4887|3.35693 / -0.0324261 / 0.164188|3.34704|0.163491|3.44573|0.034125|77.297 deg|
|F60|17.3773|17.3307 / -0.169443 / 0.216047|17.1488|0.21391|17.1543|0.0852159|75.255 deg|

P12 is small enough that a raw Ce12/Pbar12 ratio can be unstable; the report therefore uses absolute cross-covariances, correlations, eigenvalues, and principal-axis angles.

|Case|Ce [11 12; 21 22]|mean(P) [11 12; 21 22]|eig(Ce) major/minor|eig(mean P) major/minor|Ce/P corr|Ce/P axis deg|
|:--|:--|:--|:--|:--|:--|:--|
|N|[0.00083983 -5.1883e-05; -5.1883e-05 6.4409e-06]|[9.1934e-05 -5.7906e-06; -5.7906e-06 0.00012335]|0.00084305 / 3.2233e-06|0.00012438 / 9.0901e-05|-0.7054 / -0.05438|176.5 / 100.1|
|V15|[0.00025643 -1.8086e-05; -1.8086e-05 4.1143e-06]|[5.6684e-05 -2.4129e-06; -2.4129e-06 0.00011878]|0.00025772 / 2.8244e-06|0.00011887 / 5.6591e-05|-0.5568 / -0.02941|175.9 / 92.22|
|V25|[0.0030453 -0.00011471; -0.00011471 8.7235e-06]|[0.00013983 -1.0611e-05; -1.0611e-05 0.0001262]|0.0030497 / 4.3965e-06|0.00014562 / 0.0001204|-0.7038 / -0.07988|177.8 / 151.4|
|A10|[0.00021687 -1.0664e-05; -1.0664e-05 3.7269e-06]|[8.0793e-05 -6.7168e-06; -6.7168e-06 0.0001225]|0.00021741 / 3.1946e-06|0.00012356 / 7.9738e-05|-0.3751 / -0.06752|177.1 / 98.93|
|A30|[0.0026716 -0.00012154; -0.00012154 1.1614e-05]|[0.00010837 -5.0296e-06; -5.0296e-06 0.00012421]|0.0026772 / 6.0721e-06|0.00012567 / 0.00010691|-0.69 / -0.04335|177.4 / 106.2|
|F20|[0.0003218 -1.7118e-05; -1.7118e-05 4.2105e-06]|[9.3392e-05 -5.2379e-06; -5.2379e-06 0.00012339]|0.00032272 / 3.2906e-06|0.00012427 / 9.2504e-05|-0.465 / -0.04879|176.9 / 99.63|
|F60|[0.0015433 -0.00010353; -0.00010353 1.0508e-05]|[8.9965e-05 -6.6666e-06; -6.6666e-06 0.0001233]|0.0015502 / 3.5468e-06|0.00012459 / 8.8681e-05|-0.813 / -0.0633|176.2 / 100.9|

The large angle difference is primarily an anisotropy/direction mismatch: empirical error is Vy-dominated, while mean posterior covariance is r-dominated. It is not evidence that P12 alone is the root cause.

## Coverage and scale

Gaussian references: 68.27% / 95.45% / 99.73% (descriptive only).

|Case|Vy coverage 1/2/3sigma|r coverage 1/2/3sigma|Vy RMSE/median sigma|r RMSE/median sigma|
|:--|:--|:--|--:|--:|
|N|0.4444 / 0.5281 / 0.6356|0.9981 / 1.0000 / 1.0000|3.1711|0.427529|
|V15|0.5069 / 0.6400 / 0.7625|1.0000 / 1.0000 / 1.0000|2.16321|0.394643|
|V25|0.4006 / 0.4425 / 0.4881|0.9931 / 1.0000 / 1.0000|4.99597|0.450147|
|A10|0.5437 / 0.7238 / 0.9094|1.0000 / 1.0000 / 1.0000|1.69985|0.398291|
|A30|0.4019 / 0.4406 / 0.4806|0.9825 / 1.0000 / 1.0000|5.39931|0.476046|
|F20|0.4612 / 0.6250 / 0.9087|1.0000 / 1.0000 / 1.0000|1.97948|0.40558|
|F60|0.4256 / 0.4956 / 0.5675|0.9912 / 1.0000 / 1.0000|4.28653|0.464942|

## Sensor-noise audit

|Case|Ay bias/var/rho1/rho5/rho10|R_Ay/var|r bias/var/rho1/rho5/rho10|R_r/var|
|:--|:--|--:|:--|--:|
|N|0.019956 / 0.00068555 / 0.9919 / 0.9764 / 0.9475|14.5868|0.0049561 / 1.1327e-05 / 0.5296 / 0.1446 / 0.1127|29.7102|
|V15|0.019956 / 0.00027421 / 0.9801 / 0.9539 / 0.921|36.4686|0.0049561 / 1.0635e-05 / 0.4991 / 0.08985 / 0.0581|31.6416|
|V25|0.019956 / 0.0013385 / 0.9956 / 0.9835 / 0.956|7.47101|0.0049561 / 1.2029e-05 / 0.557 / 0.1937 / 0.1612|27.975|
|A10|0.019956 / 0.00018071 / 0.9702 / 0.9375 / 0.9082|55.3371|0.0049561 / 9.9182e-06 / 0.4629 / 0.02542 / -0.004982|33.9292|
|A30|0.019956 / 0.0014977 / 0.996 / 0.9836 / 0.9545|6.67687|0.0049561 / 1.3656e-05 / 0.6097 / 0.2883 / 0.2551|24.6427|
|F20|0.019956 / 0.00020312 / 0.9736 / 0.9488 / 0.9361|49.2311|0.0049561 / 1.0141e-05 / 0.4747 / 0.04692 / 0.01754|33.1852|
|F60|0.019956 / 0.0012774 / 0.9951 / 0.9732 / 0.916|7.82817|0.0049561 / 1.3682e-05 / 0.6104 / 0.2871 / 0.2463|24.595|

Robust empirical variance ranges [min median max]: Ay [0.000180711 0.000685553 0.00149771], r [9.91822e-06 1.13267e-05 1.36824e-05]. Gamma ranges: Vy [2.68431 9.13515 24.653], r [0.0304233 0.0522178 0.0935033]. These are diagnostic targets only.

## Dynamic dependence

|Rank|Variable|Q4/Q1 full-NEES growth|
|--:|:--|--:|
|1|absDr|155.587|
|2|absSteerRate|145.35|
|3|absAy|66.0395|
|4|absSteer|62.2975|
|5|absR|58.1439|
|6|Vx|1.15213|

Detailed Q1/Q4 comparison (all seven cases merged):

|Variable|Bin|range|N|Vy marginal|full NEES|var(nu Ay)|mean S11|mean P11|
|:--|--:|:--|--:|--:|--:|--:|--:|--:|
|Vx|Q1|14.985..19.977|2800|9.8633|10.0248|0.000215741|0.022504|9.13899e-05|
|Vx|Q4|19.982..24.976|2800|11.3858|11.5499|0.000227625|0.0369089|0.000111384|
|absAy|Q1|8.4066e-17..2.4086e-05|2800|0.102835|0.224456|4.63657e-05|0.0404342|7.21272e-05|
|absAy|Q4|1.6578..3.4219|2800|14.6381|14.8229|0.000543492|0.0169882|0.000141803|
|absSteer|Q1|0..1.0094e-09|2800|0.103085|0.225221|4.67475e-05|0.0404602|7.20844e-05|
|absSteer|Q4|0.01536..0.029961|2800|13.7947|14.0307|0.000552421|0.0183859|0.000124295|
|absSteerRate|Q1|0..8.4899e-10|2800|0.104192|0.227968|4.6744e-05|0.0403319|7.26878e-05|
|absSteerRate|Q4|0.036516..0.098549|2800|32.8444|33.1351|0.000191109|0.0204131|0.000103892|
|absR|Q1|3.9836e-18..1.1633e-06|2800|0.102476|0.224496|4.70013e-05|0.040523|7.17329e-05|
|absR|Q4|0.091143..0.18222|2800|12.862|13.0531|0.000555824|0.017522|0.000135624|
|absDr|Q1|1.643e-18..4.0509e-07|2800|0.104267|0.227743|4.6805e-05|0.0403154|7.27898e-05|
|absDr|Q4|0.21187..0.55271|2800|35.1257|35.4339|0.000286952|0.0201719|0.00010394|

## Final answers

1. Primary low-NIS channel: **Ay** based on standardized variance; both channels are over-covered.
2. Ay mean(S11)/innovation variance, seven-case mean: **237.285**.
3. r mean(S22)/innovation variance, seven-case mean: **46.9536**.
4. Mean standardized-innovation std: Ay **0.0968453**, r **0.154851**.
5. Mean |rho1| standardized innovations Ay/r: 0.842662 / 0.43798; mean descriptive Neff 76.3981 / 149.705 from N=1600.
6. Colored noise alone explains NIS near 0.04--0.13: **NO**. Correlation changes confidence intervals/effective N, not the large per-sample covariance ratio.
7. High NEES source after V1.13: **Vy diagonal term**.
8. Median empirical Vy-error variance / mean P11: **9.13515**.
9. Median empirical r-error variance / mean P22: **0.0522178**.
10. Median principal-axis mismatch: **76.3323 deg**; orientation correction indicated: **YES**.
11. Dynamic-condition NEES ranking is listed above; top condition is **absDr**.
12. Recommended controlled V1.15: **E. one controlled small-scale joint covariance calibration study with the deterministic model and axle gains frozen: constrain measurement covariance to empirical cross-case ranges and test a structured state/process covariance correction that raises Vy uncertainty while reducing the excessive r uncertainty; verify ellipse orientation and colored residuals, but do not combine this with a colored-noise filter**. Do not apply targets in this stage.

Why NIS << 2 and NEES >> 2 coexist: measurement-side S/R is much larger than the actual innovation covariance, making innovations small after normalization, while state-side posterior P—especially Vy—remains smaller than empirical state-error covariance. Any measured ellipse-angle mismatch adds a covariance-structure component. These are different covariance projections and are not contradictory.

## Outputs

- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_corrected_covariance.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_corrected_covariance.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_01_nis_budget_ratio.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_02_epsilon_std.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_03_nominal_epsilon_acf.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_04_nees_terms.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_05_gamma.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_06_axis_difference.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_07_dynamic_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_14_08_sensor_R_ratio.png`

**NO Q/R WAS CHANGED.**

**NO MODEL PARAMETER WAS CHANGED.**

**NO SIMULINK/CARSIM RUN WAS PERFORMED.**

**V1.13 AXLE GAINS REMAIN FROZEN.**
