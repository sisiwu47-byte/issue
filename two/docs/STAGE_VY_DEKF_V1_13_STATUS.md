# STAGE VY D-EKF V1.13 STATUS

## Implementation and gates

V1.13 applies only k_f=0.78181 and k_r=1.09186 after raw tire-force calculation in its isolated core/model copy. Prediction, measurement and numerical F/H use corrected Fy.

- Unity-gain test: 120 random cases; max x/P/innovation/NIS/S/K difference = 0.
- Force scaling identity max: 0; measurement-force identity max: 8.88e-16.
- V1.12 input/IMU/truth maximum difference: 0.
- V1.13 prediction vs rounded-gain V1.12 offline candidate maximum difference: 5.55e-17.
- Alignment: `x_hat(i), P_new(:,:,i), truth(i+1)`; each case has 1601 updates at 100 Hz and 1600 truth-scored posterior samples.

## State accuracy and consistency

|Case|Vy RMSE base/V13|Vy improve|r RMSE base/V13|r improve|NIS base/V13|NEES base/V13|Vy marginal base/V13|stable|
|:--|:--|--:|:--|--:|:--|:--|:--|:--|
|N|0.03739197 / 0.02914686|22.05%|0.005872812 / 0.004731141|19.44%|0.0779831 / 0.0379695|17.795 / 9.40749|16.6782 / 9.24225|1|
|V15|0.02238832 / 0.01614164|27.901%|0.00473715 / 0.004295998|9.3126%|0.0519185 / 0.034304|10.5633 / 4.82919|9.63006 / 4.66764|1|
|V25|0.0530567 / 0.05537868|-4.3764%|0.007162121 / 0.005039191|29.641%|0.120078 / 0.0569839|24.6944 / 20.0455|23.3756 / 19.8476|1|
|A10|0.02145493 / 0.01501006|30.039%|0.004870871 / 0.004398201|9.704%|0.0409202 / 0.0285989|6.64578 / 2.91063|6.02653 / 2.7711|1|
|A30|0.05070166 / 0.05179815|-2.1626%|0.007132823 / 0.005279807|25.979%|0.12572 / 0.0625787|29.9005 / 23.1766|28.4503 / 22.9106|1|
|F20|0.024932 / 0.01821341|26.948%|0.005833148 / 0.004491815|22.995%|0.0786551 / 0.0281019|7.80578 / 3.4887|7.07008 / 3.34704|1|
|F60|0.04916752 / 0.039404|19.858%|0.006052694 / 0.005141579|15.053%|0.0840323 / 0.0574189|31.0113 / 17.3773|29.2158 / 17.1488|1|

## Innovation and coverage

Gaussian references are 68.27% / 95.45% / 99.73% and are references, not hard gates.

|Case|Ay innovation RMS base/V13|r innovation RMS base/V13|Vy 2sigma base/V13|r 2sigma base/V13|
|:--|:--|:--|:--|:--|
|N|0.01511025 / 0.01427237|0.006027653 / 0.003814089|0.5312 / 0.5281|1.0000 / 1.0000|
|V15|0.01321706 / 0.01088149|0.004907344 / 0.00392781|0.5494 / 0.6400|1.0000 / 1.0000|
|V25|0.01789733 / 0.0217537|0.007487265 / 0.003792032|0.5400 / 0.4425|1.0000 / 1.0000|
|A10|0.01373947 / 0.01157659|0.004201036 / 0.003435189|0.6025 / 0.7238|1.0000 / 1.0000|
|A30|0.01722365 / 0.02196468|0.007731549 / 0.004270268|0.5162 / 0.4406|1.0000 / 1.0000|
|F20|0.01314291 / 0.01138107|0.006192038 / 0.003386026|0.6162 / 0.6250|1.0000 / 1.0000|
|F60|0.02159614 / 0.02008504|0.005763924 / 0.004380309|0.4869 / 0.4956|1.0000 / 1.0000|

## Covariance/stability

|Case|min eig(P)|max cond(P)|P11 min/max/final|P22 min/max/final|P12 min/max|
|:--|--:|--:|:--|:--|:--|
|N|7.166e-05|2.6023|7.2743e-05 / 0.00012872 / 7.3245e-05|0.00012088 / 0.00033497 / 0.00012161|-1.6057e-05 / 4.101e-06|
|V15|4.759e-05|2.6023|4.7805e-05 / 0.00012872 / 4.8264e-05|0.00011689 / 0.00033497 / 0.00011715|-1.0927e-05 / 6.3091e-06|
|V25|7.259e-05|2.6023|7.3986e-05 / 0.00022346 / 0.00010018|0.00012173 / 0.00033497 / 0.0001242|-2.15e-05 / 3.1947e-07|
|A10|7.166e-05|2.6023|7.2743e-05 / 0.00012872 / 7.3245e-05|0.00012118 / 0.00033497 / 0.00012161|-1.2475e-05 / 3.1947e-07|
|A30|7.166e-05|2.6023|7.2743e-05 / 0.00017783 / 7.3245e-05|0.00012038 / 0.00033497 / 0.00012161|-1.9845e-05 / 9.9845e-06|
|F20|7.166e-05|2.6023|7.2743e-05 / 0.000131 / 7.3245e-05|0.00012116 / 0.00033497 / 0.00012161|-1.2059e-05 / 1.549e-06|
|F60|7.166e-05|2.6023|7.2743e-05 / 0.00012872 / 7.3245e-05|0.00012062 / 0.00033497 / 0.00012161|-1.9469e-05 / 5.8977e-06|

## Implemented model-residual re-audit

|Case|wVy RMS|wr RMS|DeltaFy RMS|DeltaMz RMS|prediction equality max|
|:--|--:|--:|--:|--:|--:|
|N|0.001815258|0.0005126214|335.0737|138.7035|2.78e-17|
|V15|0.001555939|0.0005124518|289.1948|139.025|1.39e-17|
|V25|0.002388218|0.000510319|434.7994|138.4903|5.55e-17|
|A10|0.001005908|0.0003407301|186.7537|91.1021|1.39e-17|
|A30|0.002857104|0.0006804375|525.9036|187.5149|2.78e-17|
|F20|0.001101901|0.0002863352|203.5205|76.97249|2.78e-17|
|F60|0.002471118|0.0007666374|454.1157|209.7114|1.39e-17|

## Final answers

1. Vy RMSE improved in **5/7** cases; mean improvement 17.1796%.
2. True-r RMSE improved in **7/7** cases; mean improvement 18.8749%.
3. Cross-case stability: no >10% accuracy degradation = **YES**.
4. Full NEES improved in 7/7; aggregate reduction 36.7404%. Vy marginal improved in 7/7; aggregate reduction 33.6344%.
5. Mean NIS change V13-baseline: -0.0390501. NIS moved toward the nominal 2-D reference: **NO**. Colored IMU noise means NIS is not forced to 2, but all seven already-low values decreased further, so consistency did not move in the desired direction.
6. Vy 2sigma coverage changes are reported case-by-case above.
7. Any case with >10% Vy/r degradation: **NO**. Special cases A10/A30/F60 are included explicitly.
8. Online implementation reproduces the V1.12 rounded fixed-gain prediction: max difference 5.55e-17 (requirement <=1e-10).
9. Evidence sufficient to freeze the D-EKF steady-state force scaling (without further gain tuning): **YES**. Evidence sufficient to close the complete D-EKF V1 and start V2: **NO**; 4/7 V13 cases still have mean NEES > 5.991.
10. Recommended next direction: **D. freeze the V1.13 steady-state force scaling, but resolve corrected-model covariance/colored-noise consistency before K-KF V2**. This is a covariance/colored-noise consistency blocker, not permission to retune gains, Q/R blindly, add relaxation, or add load transfer. No next stage was executed.

## Outputs

- `D:\UsersData\桌面\two\model\vx_vy_dekf_v1_13.slx`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_online_validation.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_online_validation.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_01_state_rmse.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_02_rmse_improvement.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_03_nis.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_04_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_05_marginal_nees.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_06_coverage.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_07_innovation.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_08_covariance_stability.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_13_09_nominal_vy_trace.png`

**AXLE SCALING WAS APPLIED ONLY IN THE V1.13 MODEL COPY.**

**ORIGINAL D-EKF FILES WERE NOT MODIFIED.**

**Q/R AND TIRE PARAMETERS WERE NOT RETUNED.**
