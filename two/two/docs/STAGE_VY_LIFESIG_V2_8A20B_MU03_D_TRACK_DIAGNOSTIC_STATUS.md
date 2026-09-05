# V2.8-A20b μ=0.30 D-track diagnostic status

## Verdict

`MU03_D_TRACK_DIAGNOSTIC_COMPLETE`

`COEFFICIENT_MU_IDENTITY_NOT_IDENTIFIABLE_FROM_D_TRACK_ONLY`

- Exactly one μ=0.30 CarSim runtime completed naturally at `40.5 s`.
- CarSim `MU_ROAD_CONSTANT=0.30`; the already active user-specified low-mu `tireForceLocal.m` block was unchanged during runtime.
- Frozen target/core/wrapper hashes passed; parameter retuning and algorithm modification are both NO.
- A20 C0/C1/C2 evidence hashes remain unchanged.

## D-track comparison

| road μ | overall RMSE | MAE | MaxAbs | Bias | B-phase RMSE |
|---:|---:|---:|---:|---:|---:|
| 0.80 | 0.0290187 | 0.0216633 | 0.0650116 | -0.00438951 | 0.00518822 |
| 0.35 | 0.0843450 | 0.0569090 | 0.186383 | -0.00621537 | 0.00767497 |
| 0.30 | 0.0724587 | 0.0502363 | 0.153464 | -0.00621821 | 0.00811486 |

Units are `m/s`. Compared with μ=0.35, μ=0.30 overall RMSE is `14.0925%` lower; B-phase RMSE is `5.7315%` higher. A/C RMSE is also lower at μ=0.30 (`0.0961865/0.0957963`) than at μ=0.35 (`0.112233/0.111568`).

## Boundary

The D response is phase-dependent, so the μ=0.30 run does not show more overall D degradation. Because D error is a combined estimator/vehicle response rather than a tire-parameter identification residual, this experiment cannot uniquely classify the coefficient block as μ=0.30 or μ=0.35. A dedicated tire-force/handling parameter-identification experiment with independent reference measurements would be required for that claim; it is outside this diagnostic stage.

Evidence directory: `results/vy_lifesig_v2_8a20b_mu03_diagnostic/`.
