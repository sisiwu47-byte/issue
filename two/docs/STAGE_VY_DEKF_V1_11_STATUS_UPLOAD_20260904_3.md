# STAGE VY D-EKF V1.11 STATUS

## Scope and audit

V1.11 used only archived V1.9/V1.10 data. The axle-equivalent forces are offline bicycle-equivalent diagnostics, not CarSim true tire forces.

- Samples: 1600, Ts=0.01 s.
- TRAIN: 3 <= t < 8 s; VALIDATION: 8 <= t <= 13 s.
- Quasi-steady threshold: |steer|>0.005 rad and |steer rate|<=0.0168096035653 rad/s.
- TRAIN quasi N=109; VALIDATION quasi N=107.
- Baseline maximum reconstruction error: 2.7284841053187847e-12 (requirement <=1e-10).

## Gain definition and TRAIN-only fit

`k_correction = equivalent/model` is the applied correction direction. `G_model_over_equiv` is separately fitted in the reverse direction; because both are least-squares fits with residuals, it need not be the exact reciprocal.

|Axle|k correction (equiv/model)|G model/equiv LS|1/k correction|VALIDATION effective k|drift|
|:--|--:|--:|--:|--:|--:|
|Front|0.781809347|1.277321|1.27908422|0.787124538|0.679858%|
|Rear|1.09185835|0.914579338|0.915869723|1.10055133|0.796164%|

## Constant-gain implication

Primary steady-state interpretation uses VALIDATION quasi; VALIDATION all is also shown to expose transient contamination.

|Metric|Current RMS quasi|Constant RMS quasi|reduction quasi|reduction all|
|:--|--:|--:|--:|--:|
|DeltaFy|549.642936 N|123.764345 N|77.4828%|32.1509%|
|DeltaMz|1038.80887 Nm|14.4153095 Nm|98.6123%|78.1619%|
|wVy|0.0029266142 m/s|0.000679235163 m/s|76.7911%|31.5805%|
|wr|0.00390262877 rad/s|5.73249332e-05 rad/s|98.5311%|78.3843%|

Continuous VALIDATION residual color (501 contiguous samples):

|Model|Vy rho1|Vy rho10|r rho1|r rho10|
|:--|--:|--:|--:|--:|
|Current|0.999591485|0.961056289|0.999647639|0.966840784|
|ConstantGain|0.999546541|0.955835213|0.999100845|0.91835171|
|GainShape|0.999087967|0.912989232|0.998144954|0.829577622|

## Gain-shape fit and incremental value

`g(alpha)=c0+c2*alpha^2`; coefficients use TRAIN quasi only. This is diagnostic-only, not a tire model or identified tire parameter.

|Axle|c0|c2 [1/rad^2]|alpha-bin gain CV|
|:--|--:|--:|--:|
|Front|0.367558893|1686.77581|0.0359206|
|Rear|0.879530019|1167.91559|0.0420382|

|Metric|Gain-shape extra reduction vs constant, VALIDATION quasi|
|:--|--:|
|DeltaFyf|37.8134%|
|DeltaFyr|81.0174%|
|DeltaFy|62.4689%|
|DeltaMz|-352.585%|
|wVy|62.4449%|
|wr|-345.998%|

## |Ay| dependence and left/right symmetry

- TRAIN |Ay| quartile k ranges: front 0.739594498..0.81378154; rear 1.02519014..1.13095201.
- VALIDATION |Ay| quartile k ranges: front 0.752570232..0.816034655; rear 1.05225002..1.13371315.

|Dataset|Direction|N|k front|k rear|post-gain DeltaFyf mean|DeltaFyr mean|DeltaMz mean|
|:--|:--|--:|--:|--:|--:|--:|--:|
|TRAIN|Left|55|0.776109416|1.08224028|-20.2122119|-20.3073383|12.0935788|
|TRAIN|Right|54|0.787443035|1.10099324|-16.7078528|-9.48805448|-2.92140983|
|VALIDATION|Left|54|0.787455074|1.10100439|16.7457794|9.50369747|2.93847519|
|VALIDATION|Right|53|0.786787835|1.10008802|-14.6065827|-8.24152863|-2.64826189|

## Interaction with existing sigma_f=1 m, sigma_r=0 candidate

|Dataset|front k correction after transient|rear k correction|front G model/equiv|rear G model/equiv|
|:--|--:|--:|--:|--:|
|TRAIN|0.801926626|1.09185835|1.24667909|0.914579338|
|VALIDATION|0.805540883|1.10055133|1.24128608|0.907928589|

## Final answers

1. Front steady-state mismatch: see constant-gain reduction and gain-shape incremental reduction above; classification: **constant scaling helps, with a secondary shape contribution**.
2. Rear steady-state mismatch: **constant scaling helps, with a secondary shape contribution**.
3. TRAIN-to-VALIDATION generalization drift is front 0.679858%, rear 0.796164%.
4. Constant gain VALIDATION quasi reductions: DeltaFy 77.4828%, DeltaMz 98.6123%, Vy 76.7911%, r 98.5311%.
5. Gain-shape extra VALIDATION quasi reductions: DeltaFy 62.4689%, DeltaMz -352.585%, Vy 62.4449%, r -345.998%.
6. Alpha-bin correction-gain CV: front 0.0359206, rear 0.0420382.
7. VALIDATION |Ay| quartile correction-gain range: front 0.0634644, rear 0.0814631. Reported only as possible load/load-sensitivity dependence, not proof of load transfer.
8. VALIDATION left/right gain difference: front 0.0847696%, rear 0.0832654%.
9. After sigma_f=1 m, TRAIN quasi front k=0.801926626 and VALIDATION quasi front k=0.805540883; deviation from 1 remains a separately measured steady-state issue.
10. Recommended V1.12 direction from the numerical classification: **A. axle-wise steady-state force scaling has the strongest current support; alpha-shape dependence is secondary and not yet moment-consistent**. No correction is implemented here.

Highly colored residual assessment is retained in the MAT/CSV rho1/rho10 records; constant/shape fits are not treated as online-ready models.

## Outputs

- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_steady_tire_gain.csv`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_steady_tire_gain.mat`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_01_Fyf_equiv_vs_model.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_02_Fyr_equiv_vs_model.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_03_Fyf_vs_alpha_f.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_04_Fyr_vs_alpha_r.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_05_effective_k_f_vs_alpha.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_06_effective_k_r_vs_alpha.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_07_effective_gain_vs_Ay.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_08_current_vs_constant_deltaFy_deltaMz.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_09_current_vs_shape_deltaFy_deltaMz.png`
- `D:\UsersData\桌面\two\results\vy_dekf_v1_11_10_train_vs_validation_gain.png`

**NO STEADY-STATE TIRE CORRECTION WAS APPLIED ONLINE.**

**NO TIRE PARAMETER WAS IDENTIFIED OR CHANGED.**

**THIS WAS AN OFFLINE STEADY-STATE GAIN/SHAPE ATTRIBUTION ONLY.**
