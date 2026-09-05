# Stage VX-ND Thesis Traditional WSS Status

## Verdict

`VX_ND_THESIS_DERIVED_BASELINE_PASS`

- source: accepted `VX-ND` formal raw only
- new simulation/runtime: `0`
- formal raw and formal analysis: unchanged
- estimator, frozen parameters, source `.slx`: unchanged
- artificial sensor noise: not added

## Frozen case facts

- `MU_ROAD_CONSTANT = 0.80`
- steering: `0 rad` throughout
- `StopTime = 16 s`
- reference unit: `km/h`; no additional division by `3.6`
- speed profile: `[0,3,7,9,13,16] s -> [60,60,100,100,60,60] km/h`
- reference initial speed: `60 km/h`
- first finite CarSim Vx at `t=0`: `20.000000 m/s = 72.000000 km/h`

## Offline baseline definition

Traditional WSS uses only `omega=estU(:,1:4)`, `delta=estU(:,5:8)`, and `yawRate=estU(:,14)`, with frozen `Rw=0.393 m`, `a=1.18 m`, `b=1.77 m`, `d=1.575 m`, and `vyPrior=0`. Four kinematic wheel candidates are combined by an equal arithmetic mean. No health, rejection, covariance weighting, IMU detector, wheel-lock flag, or local KF is used.

## Derived metrics

Evaluation uses the formal-analysis-compatible estimator update points in `[0.6,16] s`.

| metric | Traditional WSS | Fusion |
|---|---:|---:|
| RMSE (m/s) | 0.183354273 | 0.163815128 |
| MAE (m/s) | 0.139464909 | 0.130521412 |
| MaxAbs (m/s) | 0.302853643 | 0.257806098 |

- `TraditionalMinusFusion_RMSE = 0.019539145 m/s`
- relative RMSE reduction versus Traditional WSS: `10.6565%`

## Outputs

- derived MAT: `results/vx_formal_validation/v3b/final_acceptance/traditional_wss/VX_ND_traditional_wss.mat`
- metrics CSV: `results/vx_formal_validation/v3b/final_acceptance/traditional_wss/VX_ND_traditional_wss_metrics.csv`
- plotting code: `results/vx_formal_validation/v3b/final_acceptance/thesis_figures/plot_vx_nd_thesis_performance.m`
- figure outputs: paired PNG/PDF/SVG with base name `VX_FIG_ND_longitudinal_speed_performance`

The thesis caption must distinguish the 60 km/h reference from the 72 km/h actual initial CarSim state. Recommended interpretation: after initial-state convergence, the vehicle completes an approximately 60→100→60 km/h normal longitudinal dynamic process.
