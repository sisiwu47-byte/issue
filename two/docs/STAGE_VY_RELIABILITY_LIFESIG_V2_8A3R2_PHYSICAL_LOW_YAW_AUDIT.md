# V2.8-A3R2 Physical Low-Yaw Offline Audit

## Verdict

`K_PHYSICAL_LOW_YAW_DEGRADATION_SUPPORTED`

This is an offline audit of the existing V2.8-A3 runtime. No MATLAB,
Simulink, or CarSim process was started and no model was modified.

## Signal and window contract

- Physical low yaw is labelled only by CarSim ideal `AVz` from the saved A3
  ERD output.
- `AVz` is converted from deg/s to rad/s before applying the frozen strict
  condition `|AVz| < 0.01 rad/s`.
- `AVz_IMU` is not used to define the physical-low-yaw window.
- No K gate is implemented or evaluated.
- The longest continuous physical-low-yaw window is `4.7--22.0 s`, duration
  `17.3 s`. It contains 174 CarSim ERD samples; maximum `|AVz|` inside the
  window is `0.0022873340640217066 rad/s`.
- The same closed time interval selects 1731 aligned 100-Hz samples from the
  saved D/K/truth logs.
- Saved D/K error logs exactly replay `Vy_D - Vy_true` and
  `Vy_K - Vy_true` (maximum discrepancy zero).

## Overall error in the physical-low-yaw window

| Track | RMSE (m/s) | MAE (m/s) | MaxAbs (m/s) | Bias (m/s) | Error start (m/s) | Error end (m/s) |
|---|---:|---:|---:|---:|---:|---:|
| D | 0.00447072703735 | 0.00426439091908 | 0.0113553403044 | -0.00414120324247 | 0.0113553403044 | -0.00323432718038 |
| K | 1.08949147528 | 0.999858029826 | 1.74866874382 | -0.999858029826 | -0.248906388872 | -1.74866874382 |

K error changes by `-1.49976235495 m/s` from window start to end, and its
least-squares slope is `-0.0865779659290 m/s^2`. The absolute K error grows
from `0.248906388872` to `1.74866874382 m/s`. D does not show a comparable
sustained degradation.

## Equal-sample front/middle/rear comparison

The 1731 samples divide exactly into three consecutive groups of 577.

| Segment | Time (s) | D RMSE | D MAE | D MaxAbs | D Bias | K RMSE | K MAE | K MaxAbs | K Bias |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Front | 4.70--10.46 | 0.00461386 | 0.00438271 | 0.0113553 | -0.00401314 | 0.521883 | 0.501242 | 0.759461 | -0.501242 |
| Middle | 10.47--16.23 | 0.00430930 | 0.00411275 | 0.00840166 | -0.00411275 | 1.00442 | 0.995930 | 1.23319 | -0.995930 |
| Rear | 16.24--22.00 | 0.00448379 | 0.00429771 | 0.00901029 | -0.00429771 | 1.50988 | 1.50240 | 1.74867 | -1.50240 |

K RMSE increases monotonically from `0.521883` to `1.00442` to
`1.50988 m/s`; rear-minus-front K RMSE is `0.98799963 m/s`. D RMSE remains
near `0.0045 m/s`; rear-minus-front D RMSE is `-0.000130075 m/s`.

## Scientific interpretation

The existing A3 evidence supports K-track degradation during a sustained
physical-low-yaw interval. The conclusion is based on raw aligned errors,
without de-meaning, bias correction, threshold retuning, or fusion-RMSE
analysis. It does not define, implement, or validate an online K gate.

## Evidence lineage

- A3 runtime MAT:
  `results/vy_lifesig_v2_8a3_long_low_yaw_runtime.mat`
  (`FA1BAB75DB7EF33B634E649704D7950166BEA5184E1496F57AB953C7B32AC771`).
- A3 CarSim channel metadata:
  `results/vy_lifesig_v2_8a3_carsim_control/LastRun.vs`
  (`47ACD451503DF1BC64297A544F007152BD52D870C33C91D4559DE902F383F3AD`).
- A3 CarSim binary output:
  `results/vy_lifesig_v2_8a3_carsim_control/LastRun.vsb`
  (`87E481A199186F5530BFD81B2E7A6CBCA3033BCFD6A150BABCCBD9F8FD224118`).
- Machine-readable A3R2 audit:
  `results/vy_lifesig_v2_8a3r2_physical_low_yaw_audit.csv`.
