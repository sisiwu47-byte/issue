# STAGE VY D-EKF V1.17 STATUS

## Implementation and validation gates

V1.17 changes only the Ay assimilation schedule in an isolated model copy. Prediction and yaw-rate measurement updates remain at 100 Hz. Alignment: `x_hat(i), P_new(:,:,i), truth(i+1)`.

- 120 random A100 single-step tests: max difference 0 (requirement <=1e-12).
- A50/A20 prediction max difference from A100: 0.
- Seven cases x three modes = 21 simulations; 1601 online calls and 1600 scored posterior samples per simulation.
- Input/IMU/truth max difference: 0; A100 online state/P/diagnostic max difference from V1.13: 0.
- Online metrics vs V1.16 offline replay max difference: 2.53e-09.
- Actual full-call Ay counts are A100/A50/A20 = 1601/801/321. Logged truth-scored counts are 1600/800/320 because the verified Rate Transition alignment discards the initial held row.

## Seven-case core results

|Case|Mode|Vy RMSE|Vy change|r RMSE|r change|NEES|Vy NSEE|r NSEE|gamma Vy|gamma r|Vy 2sigma|r 2sigma|P11 post/prior|Ay std innov|Ay rho1|stable|
|:--|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|:--|
|N|A100|0.02914686|+0%|0.004731141|+0%|9.40749|9.24225|0.181297|9.13515|0.0522178|0.52812|1.00000|0.488861|0.0816705|0.871636|1|
|N|A50|0.02930093|+0.52859%|0.004769608|+0.81306%|6.14517|5.99473|0.183243|5.42024|0.0526815|0.58188|1.00000|0.690074|0.11121|0.87783|1|
|N|A20|0.02965731|+1.7513%|0.00482389|+1.9604%|3.73859|3.59324|0.186393|2.98991|0.0534339|0.67625|1.00000|0.849125|0.166233|0.863862|1|
|V15|A100|0.01614164|+0%|0.004295998|+0%|4.82919|4.66764|0.155388|4.5238|0.0346389|0.64000|1.00000|0.378777|0.0555311|0.78369|1|
|V15|A50|0.01625338|+0.69222%|0.004316087|+0.46762%|3.04342|2.89593|0.15628|2.34295|0.0348605|0.72562|1.00000|0.63962|0.0736758|0.800535|1|
|V15|A20|0.01653624|+2.4446%|0.004345038|+1.1415%|1.79348|1.65139|0.157798|1.1989|0.0352|0.87313|1.00000|0.835226|0.107163|0.792254|1|
|V25|A100|0.05537868|+0%|0.005039191|+0%|20.0455|19.8476|0.200754|21.7793|0.0691261|0.44250|1.00000|0.572693|0.150906|0.955743|1|
|V25|A50|0.05556504|+0.33652%|0.005107784|+1.3612%|13.4815|13.3047|0.204793|13.8534|0.0707182|0.46500|1.00000|0.732238|0.210663|0.955081|1|
|V25|A20|0.05589608|+0.93429%|0.005201372|+3.2184%|8.40488|8.24812|0.210906|8.05531|0.0731922|0.50125|1.00000|0.862746|0.320587|0.929442|1|
|A10|A100|0.01501006|+0%|0.004398201|+0%|2.91063|2.7711|0.157951|2.68431|0.0304233|0.72375|1.00000|0.458961|0.0514584|0.682493|1|
|A10|A50|0.0151309|+0.80507%|0.004430584|+0.73627%|1.92328|1.78365|0.159506|1.53489|0.0305655|0.83000|1.00000|0.674743|0.065083|0.65547|1|
|A10|A20|0.01546055|+3.0013%|0.00447703|+1.7923%|1.20804|1.0681|0.162045|0.820785|0.0307672|0.93875|1.00000|0.843546|0.088167|0.593106|1|
|A30|A100|0.05179815|+0%|0.005279807|+0%|23.1766|22.9106|0.223834|24.653|0.0935033|0.44062|1.00000|0.521824|0.154227|0.962179|1|
|A30|A50|0.05192747|+0.24966%|0.005346134|+1.2562%|15.3|15.0975|0.228041|15.1195|0.0961972|0.46500|1.00000|0.707768|0.215768|0.962174|1|
|A30|A20|0.05218095|+0.73902%|0.005437651|+2.9896%|9.3562|9.17937|0.234444|8.53935|0.10022|0.49938|1.00000|0.856057|0.330791|0.938123|1|
|F20|A100|0.01821341|+0%|0.004491815|+0%|3.4887|3.34704|0.163491|3.44573|0.034125|0.62500|1.00000|0.492432|0.0527757|0.693685|1|
|F20|A50|0.01837082|+0.86424%|0.004529635|+0.84197%|2.33643|2.1949|0.165291|2.05238|0.0344783|0.78000|1.00000|0.692188|0.0672524|0.676443|1|
|F20|A20|0.0187936|+3.1855%|0.00458225|+2.0133%|1.49092|1.34851|0.168162|1.14159|0.0349934|0.92250|1.00000|0.850107|0.0939881|0.648848|1|
|F60|A100|0.039404|+0%|0.005141579|+0%|17.3773|17.1488|0.21391|17.1543|0.0852159|0.49562|1.00000|0.483662|0.131348|0.94921|1|
|F60|A50|0.03959029|+0.47275%|0.005181002|+0.76675%|11.2877|11.1132|0.216099|10.138|0.0858694|0.53250|1.00000|0.687027|0.182709|0.949434|1|
|F60|A20|0.04004287|+1.6213%|0.005237092|+1.8577%|6.80605|6.65105|0.219674|5.59114|0.0869637|0.59250|1.00000|0.84773|0.277513|0.919943|1|

The CSV also contains MAE, bias, maximum error, 1/3-sigma coverage, covariance stability, and dimension-separated NIS fields.


Gaussian coverage references: 68.27% / 95.45% / 99.73%; these are references, not hard gates.

## Dimension-correct NIS and assimilated innovation color

2-D Ay+r NIS reference mean is about 2; 1-D r-only NIS reference mean is about 1. They are reported separately.

|Case|Mode|NIS 2D mean/count|NIS r-only mean/count|Ay innov RMS/std-epsilon|Ay rho1/5/10|r innov RMS|
|:--|:--|:--|:--|:--|:--|--:|
|N|A100|0.037988 / 1600|NaN / 0|0.0142741 / 0.08167|0.8716 / 0.7068 / 0.6153|0.00381515|
|N|A50|0.047746 / 800|0.027269 / 800|0.02225 / 0.11121|0.8778 / 0.6767 / 0.4179|0.00380378|
|N|A20|0.074851 / 320|0.027177 / 1280|0.040609 / 0.16623|0.8639 / 0.3221 / -0.09615|0.00379135|
|V15|A100|0.034321 / 1600|NaN / 0|0.0108835 / 0.055531|0.7837 / 0.5873 / 0.4963|0.00392883|
|V15|A50|0.038652 / 800|0.029368 / 800|0.0172728 / 0.073676|0.8005 / 0.5672 / 0.3239|0.00392324|
|V15|A20|0.049321 / 320|0.029621 / 1280|0.0319728 / 0.10716|0.7923 / 0.2436 / -0.02187|0.00391648|
|V25|A100|0.057011 / 1600|NaN / 0|0.0217574 / 0.15091|0.9557 / 0.863 / 0.7549|0.00379313|
|V25|A50|0.085574 / 800|0.026456 / 800|0.0332595 / 0.21066|0.9551 / 0.7855 / 0.4574|0.00376841|
|V25|A20|0.16429 / 320|0.026246 / 1280|0.0586355 / 0.32059|0.9294 / 0.3163 / -0.1773|0.0037444|
|A10|A100|0.028611 / 1600|NaN / 0|0.0115769 / 0.051458|0.6825 / 0.3245 / 0.2595|0.00343612|
|A10|A50|0.034256 / 800|0.022143 / 800|0.0180337 / 0.065083|0.6555 / 0.3234 / 0.2352|0.00342772|
|A10|A20|0.050366 / 320|0.021961 / 1280|0.0331372 / 0.088167|0.5931 / 0.2018 / -0.04001|0.00341804|
|A30|A100|0.062612 / 1600|NaN / 0|0.0219698 / 0.15423|0.9622 / 0.8846 / 0.7832|0.00427149|
|A30|A50|0.089514 / 800|0.033953 / 800|0.0339475 / 0.21577|0.9622 / 0.8095 / 0.5016|0.0042534|
|A30|A20|0.16315 / 320|0.033947 / 1280|0.0606868 / 0.33079|0.9381 / 0.3678 / -0.1085|0.00423513|
|F20|A100|0.028114 / 1600|NaN / 0|0.0113812 / 0.052776|0.6937 / 0.3528 / 0.2868|0.00338694|
|F20|A50|0.033838 / 800|0.021556 / 800|0.0176136 / 0.067252|0.6764 / 0.3659 / 0.2683|0.00337643|
|F20|A20|0.05206 / 320|0.020929 / 1280|0.032244 / 0.093988|0.6488 / 0.2722 / 0.001412|0.00336582|
|F60|A100|0.057449 / 1600|NaN / 0|0.0200894 / 0.13135|0.9492 / 0.8538 / 0.7287|0.00438157|
|F60|A50|0.077084 / 800|0.036447 / 800|0.0314003 / 0.18271|0.9494 / 0.7583 / 0.4137|0.00437261|
|F60|A20|0.13434 / 320|0.035576 / 1280|0.0569376 / 0.27751|0.9199 / 0.2795 / -0.2161|0.00436353|

## Combined high-dynamic top quartiles

|Subset|Mode|N|Vy RMSE|full NEES|Vy marginal|gamma Vy|Vy 2sigma|
|:--|:--|--:|--:|--:|--:|--:|--:|
|absAy_Q4|A100|2800|0.0479932|14.8229|14.6381|16.1087|0.32929|
|absAy_Q4|A50|2800|0.04815232|10.0816|9.90304|10.3831|0.43893|
|absAy_Q4|A20|2800|0.04842595|6.3805|6.20848|6.12163|0.55929|
|absSteerRate_Q4|A100|2800|0.05939968|32.742|32.455|33.5269|0.07214|
|absSteerRate_Q4|A50|2800|0.0595975|21.3241|21.1167|20.2936|0.13179|
|absSteerRate_Q4|A20|2800|0.05994025|12.7484|12.5764|11.3061|0.25500|
|absDr_Q4|A100|2800|0.06078437|35.4339|35.1257|35.3623|0.01643|
|absDr_Q4|A50|2800|0.06125093|23.2065|22.9951|21.6388|0.04393|
|absDr_Q4|A20|2800|0.06217507|14.0881|13.9183|12.2979|0.15536|

## V25 / A30 / F60 focus

|Case|Mode|Vy RMSE change|r RMSE change|full NEES|Vy marginal|gamma Vy|Vy 2sigma|
|:--|:--|--:|--:|--:|--:|--:|--:|
|V25|A100|+0%|+0%|20.0455|19.8476|21.7793|0.44250|
|V25|A50|+0.33652%|+1.3612%|13.4815|13.3047|13.8534|0.46500|
|V25|A20|+0.93429%|+3.2184%|8.40488|8.24812|8.05531|0.50125|
|A30|A100|+0%|+0%|23.1766|22.9106|24.653|0.44062|
|A30|A50|+0.24966%|+1.2562%|15.3|15.0975|15.1195|0.46500|
|A30|A20|+0.73902%|+2.9896%|9.3562|9.17937|8.53935|0.49938|
|F60|A100|+0%|+0%|17.3773|17.1488|17.1543|0.49562|
|F60|A50|+0.47275%|+0.76675%|11.2877|11.1132|10.138|0.53250|
|F60|A20|+1.6213%|+1.8577%|6.80605|6.65105|5.59114|0.59250|

## Seven-case mean / median changes relative to A100

|Mode|Vy RMSE mean/median|r RMSE mean/median|full NEES reduction mean/median|Vy marginal reduction mean/median|gamma Vy reduction mean/median|Vy 2sigma increase mean/median|
|:--|:--|:--|:--|:--|:--|:--|
|A100|+0% / +0%|+0% / +0%|0% / 0%|0% / 0%|0% / 0%|+0.00000 / +0.00000|
|A50|+0.56415% / +0.52859%|+0.89187% / +0.81306%|34.34% / 33.985%|35.059% / 35.138%|41.156% / 40.666%|+0.06920 / +0.05375|
|A20|+1.9539% / +1.7513%|+2.139% / +1.9604%|59.631% / 59.631%|60.929% / 61.122%|67.549% / 67.27%|+0.15830 / +0.14813|

## Predeclared decision rule

|Mode|Pass|Max Vy/r RMSE change|Mean Vy/r RMSE change|NEES reduction|Vy marginal reduction|gamma Vy reduction|Vy 2sigma change|V25/A30/F60 NEES reductions|
|:--|:--|:--|:--|--:|--:|--:|--:|:--|
|A20|YES|+3.186% / +3.218%|+1.954% / +2.139%|59.626%|60.293%|66.013%|+0.15830|58.07% / 59.63% / 60.83%|
|A50|YES|+0.8642% / +1.361%|+0.5642% / +0.8919%|34.12%|34.466%|39.477%|+0.06920|32.75% / 33.98% / 35.04%|

## Final answers

1. A20 reproduces the V1.16 offline trend: **YES**; online/offline aggregate-metric max difference 2.53e-09 (descriptive replay tolerance 1e-8; the mandatory A100 online equivalence gate remains 1e-10).
2. A50 decision-rule pass: **YES**; its detailed tradeoffs are in the decision table.
3. Selected mode under the predeclared rule: **A20**.
4. Selected-mode mean/max Vy RMSE change relative to A100: +1.9539% / +3.1855%.
5. Selected-mode mean/max true-r RMSE change: +2.13903% / +3.21841%.
6. Aggregate full NEES reduction: 59.6258%.
7. Aggregate Vy marginal NSEE reduction: 60.2931%.
8. Aggregate gamma Vy reduction: 66.0129%.
9. Mean Vy 2sigma coverage change: +0.158304 (absolute fraction).
10. V25/A30/F60 retain visible high-dynamic inconsistency after improvement; their full-NEES reductions are 58.071% / 59.631% / 60.834%. This is a frozen known limitation.
11. Remaining prior inconsistency and colored residual are recorded as D-EKF V1 known limitations for later reliability/fusion handling; no further D-EKF model/covariance tuning is authorized.
12. **FREEZE D-EKF V1 — FINAL Ay ASSIMILATION MODE: A20.** Next development stage: **V2 K-KF**; V1.18 must not be created.

**SELECTED MODE = A20**

**FREEZE D-EKF V1**

Remaining known limitations:

- high-dynamic prior inconsistency;
- colored Ay innovation;
- simplified tire transient/load behavior.

These limitations do not authorize V1.18.

## Outputs

- `D:\UsersData\桌面\two\model\vx_vy_dekf_v1_17.slx`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_online_multirate.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_online_multirate.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_high_dynamic.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_01_vy_rmse.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_02_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_03_vy_marginal.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_04_gamma.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_05_coverage.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_06_contraction.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_07_ay_rho1.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_08_high_dynamic.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_17_09_stability.png`

**V1.13 AXLE GAINS REMAIN FROZEN.**

**V1.13 Q/R REMAIN FROZEN.**

**ONLY Ay MEASUREMENT ASSIMILATION RATE WAS CHANGED.**

**D-EKF PREDICTION AND YAW-RATE UPDATE REMAIN AT 100 Hz.**

**V1.17 IS THE FINAL D-EKF V1 DEVELOPMENT STAGE.**
