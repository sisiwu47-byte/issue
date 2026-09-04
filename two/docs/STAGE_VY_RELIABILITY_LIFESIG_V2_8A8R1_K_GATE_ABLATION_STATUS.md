# V2.8-A8R1 K-health Gate Strength Ablation Status

`A — K_HEALTH_GATE_SUPPRESSION_INSUFFICIENT`

The existing A8 replay was audited read-only over the frozen physical-low-yaw interval `4.70--22.00 s` (`1731` samples). No MATLAB, Simulink, or CarSim process was started and no frozen file or parameter was changed.

| Output | RMSE [m/s] | MAE [m/s] | MaxAbs [m/s] | Bias [m/s] |
|---|---:|---:|---:|---:|
| D-EKF | 0.00447073 | 0.00426439 | 0.01135534 | -0.00414120 |
| K-KF | 1.08949148 | 0.99985803 | 1.74866874 | -0.99985803 |
| original LifeSig | 0.17063446 | 0.15759709 | 0.27090747 | -0.15759709 |
| current A8 gate | 0.12261568 | 0.11358918 | 0.26480610 | -0.11358918 |
| ideal K-off ablation | 0.01259078 | 0.01236477 | 0.01896340 | -0.01232237 |

The current gate reduces RMSE by `28.1413%` relative to original LifeSig, but ideal K isolation reduces the remaining Case-B RMSE by another `89.7315%`. Mean `alpha_K` is `0.147030` in Case A, `0.109349` in Case B, and exactly zero in Case C. Thus the K track is severely degraded, but its effect is avoidable if it is isolated; the principal limitation of A8 is insufficient K suppression.

Full evidence and figures are in:
`results/vy_lifesig_v2_8a8r1_k_gate_ablation/`.

Case C is an offline oracle ablation and is not a deployable gate. This stage does not authorize tuning or implementation changes.
