# Stage VX-V3B Combined Slip Status

## Verdict

`VX_V3B_COMBINED_SLIP_FORMAL_PASS`

- `PHYSICAL_CALIBRATION_SIM_COUNT = 1`
- selected excitation: `TIER1_REFERENCE_ONLY / T1_2P5`
- V3 historical committed formal count: `5`
- V3B formal contribution: `1`
- total `FORMAL_RUNTIME_COUNT = 6`
- `READY_FOR_VX_FINAL_ACCEPTANCE = YES`

## Frozen physical excitation

- road/control lineage: A20b MU03, `MU_ROAD_CONSTANT=0.30`
- speed reference: `[0,3,7,9,11.5,16] s -> [40,40,70,70,40,40] km/h`
- steering command: `0`
- selected braking ramp: `9.0--11.5 s`; brake analysis end: `12.0 s`
- rear torque override: disabled; Tier 2 and historical F/G audit were not entered
- calibration sustained drive slip, RL/RR: `1.906/1.906 s`
- calibration sustained brake slip, RL/RR: `2.731/2.731 s`
- freeze file: `results/vx_formal_validation/v3b/frozen_physical_excitation.json`

Candidate selection used only CarSim Vx truth, wheel omega, raw kappa, the frozen speed command, and simulation-completion state. Estimator errors, rho, validWheel, alpha, and figures were not used before the physical excitation was frozen.

## Fresh formal VX-CS result

- fresh drive physical gate: `PASS`, RL/RR sustained durations `1.906/1.906 s`
- fresh brake physical gate: `PASS`, RL/RR sustained durations `2.731/2.731 s`
- overall Fusion: RMSE `0.234686559 m/s`, MAE `0.210432655 m/s`, MaxAbs `0.303811582 m/s`, Bias `-0.210432655 m/s`
- DRIVE_SLIP: mean alpha_W `0.096372550`; detection `0.008 s`; wheel recovery `0.838 s`; alpha_W 90/95 recovery `0.008/0.008 s`
- BRAKE_SLIP: mean alpha_W `0.111551800`; detection `0.178 s`; wheel recovery `2.338 s`; alpha_W 90/95 recovery `0.008/0.008 s`

The calibration runtime is not formal evidence. The formal result is the separate fresh file `results/vx_formal_validation/v3b/runtime/VX_CS_formal_raw.mat`, committed exactly once after the excitation freeze.

## Final thesis assets

- TABLE-01: `results/vx_formal_validation/v3b/runtime/VX_TABLE_01_FINAL_representative_condition_performance.csv`
- TABLE-02: `results/vx_formal_validation/v3b/runtime/VX_TABLE_02_FINAL_combined_slip_recovery.csv`
- FIG-01 image/code: `results/vx_formal_validation/v3b/thesis_figures/VX_FIG01_normal_dynamic_estimation.png` / `plot_vx_v3b_fig01.m`
- FIG-02 image/code: `results/vx_formal_validation/v3b/thesis_figures/VX_FIG02_combined_slip_recovery_fusion.png` / `plot_vx_v3b_fig02.m`
- vector PDF exports are retained beside both PNG files.

Both plotting scripts inherit the frozen Vy A19 palette, line styles and widths, grid, axes, typography, legend placement, compact subplot spacing, and 175 mm canvas width. The frozen Vy plotting-source SHA-256 is `CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB`.

## Integrity boundary

No V3 formal runtime evidence was overwritten or deleted. No `VX-ND`, `VX-ST`, `VX-DR`, `VX-DS`, or `VX-BL` runtime was executed. No source `.slx`, estimator implementation, frozen estimator parameter, or CarSim source dataset was modified.

The required Tier-2-only audit implementation is retained as `matlab/audit_historical_fg_physical_excitation_v3b.m`; it was not executed because the first Tier-1 candidate passed.
