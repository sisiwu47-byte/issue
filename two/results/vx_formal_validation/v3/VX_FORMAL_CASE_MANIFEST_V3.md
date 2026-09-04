# VX Formal Case Manifest V3

- Stage: `VX-V2B — FORMAL CASE REUSE AUDIT & V3 PACKAGE`
- Manifest role: preregistration only
- `FORMAL_RUNTIME_COUNT = 0`
- Formal results represented: `NONE`
- Reference unit at the active controller interface: `km/h`
- Frozen estimator parameters: unchanged
- Core algorithm modification: `NO`

## Primary minimal validation set

| case_id | scientific question | speed reference, km/h | steering / road | frozen analysis windows, s | configuration source | current status |
|---|---|---|---|---|---|---|
| `VX-ND` | Does basic WSS/IMU/Fusion accuracy hold under high-adhesion longitudinal acceleration and braking? | `[0,3,7,9,13,16] -> [60,60,100,100,60,60]` | zero steering; nominal control token `MU_ROAD_CONSTANT=0.8` | overall `[0.60,16.00]`; baseline `[0.60,3.00)`; accel `[3.00,7.00)`; high-speed plateau `[7.00,9.00)`; brake `[9.00,13.00)`; final plateau `[13.00,16.00]` | A20-C1 headless CarSim control lineage; current `vx.cpar` independently confirms the same vehicle/road/run identities | `PREREGISTERED_NOT_RUN` |
| `VX-ST` | Does longitudinal-speed estimation remain valid under a proven steering-dynamic excitation? | `[0,16] -> [72,72]` | A20-C1/A24-N1 DLC-like four alternating half-sines, shifted to `[3,8)`; nominal control token `0.8` | overall `[0.60,16.00]`; baseline `[0.60,3.00)`; steering `[3.00,8.00)`; recovery `[8.00,16.00]` | A20-C1 waveform and control; A24-N1 exact reuse confirms the lineage | `PREREGISTERED_NOT_RUN` |
| `VX-DR` | In one low-mu run, do the acceleration and braking phases physically create rear-wheel degradation, invoke WSS protection, and permit recovery? | `[0,3,7,9,13,16] -> [40,40,70,70,40,40]` | zero steering; A20b local control with `MU_ROAD_CONSTANT=0.30` | overall `[0.60,16.00]`; baseline `[0.60,3.00)`; accel degradation `[3.00,7.00)`; accel recovery `[7.00,9.00)`; brake degradation `[9.00,13.00)`; brake recovery `[13.00,16.00]` | A20b-MU03 headless CarSim control; F/G only inform expected behavior | `PREREGISTERED_NOT_RUN` |

The controller reference values above are already in `km/h`. The configurator must not divide them by `3.6`; the saved model's existing downstream `Gain15=1/3.6` performs the controller-path conversion.

## VX-ST claim gate

The runtime must save `delta_FL`, `delta_FR`, `delta_RL`, and `delta_RR` from the actual CarSim outputs. The A20-C1 excitation is a reusable steering profile, but this preregistration does not itself establish genuine rear steering. If nonzero dynamic RL/RR actual steering cannot be demonstrated, the maximum allowed claim is `STEERING_DYNAMIC_VALIDATION`; `4WIS_REAR_STEERING_VALIDATION` is forbidden.

## VX-DR physical gate and preregistered fallback

The primary physical gate is evaluated separately in `[3,7)` and `[9,13)` using actual rear wheel speeds and CarSim Vx. With `Rw=0.393 m`, define

`kappa_i = (Rw*omega_i - Vx_true) / max(abs(Vx_true), 1 m/s)`.

- acceleration gate: both RL/RR sustain `kappa_i >= +0.10` for at least `0.10 s` inside `[3,7)`;
- braking gate: both RL/RR sustain `kappa_i <= -0.10` for at least `0.10 s` inside `[9,13)`.

`rho_RL/RR`, `validWheel_RL/RR`, `alpha_W`, and `alpha_I` must also be recorded and reported. These estimator responses do not replace the physical kinematic gate.

If both physical gates pass, `VX-DR PASS` is recorded and `VX-DS/VX-BL` must not be run. Only after exactly one completed `VX-DR` formal runtime returns `VX-DR PHYSICAL_GATE_FAIL` may the frozen fallback be used:

| fallback_id | fixed profile | fixed windows | source role |
|---|---|---|---|
| `VX-DS` | `40 -> 70 km/h`, ramp `[3,8)`, plateau `[8,16]`, `MU_ROAD_CONSTANT=0.30` | baseline `[0.60,3)`; drive-slip `[3,8)`; recovery `[8,16]` | historical-F-like; F MAT is `HISTORICAL_BEHAVIOR_TEMPLATE` only |
| `VX-BL` | `70 -> 40 km/h`, ramp `[3,8)`, plateau `[8,16]`, `MU_ROAD_CONSTANT=0.30` | baseline `[0.60,3)`; brake-lock `[3,8)`; recovery `[8,16]` | historical-G-like; G MAT is `HISTORICAL_BEHAVIOR_TEMPLATE` only |

Fallback is triggered only by the physical gate, never by estimator error, figure quality, or a desire for better metrics. Windows may not be moved after observing results.

## Formal outputs

- raw MAT: `results/vx_formal_validation/v3/runtime/<CASE_ID>_formal_raw.mat`
- metadata: embedded in every raw MAT and repeated in `runtime/<CASE_ID>_metadata.json`
- performance table source: `runtime/VX_TABLE_01_representative_condition_performance.csv`
- degradation table source: `runtime/VX_TABLE_02_degradation_recovery_dynamics.csv`
- figure code: `results/vx_formal_validation/v3/thesis_figures/plot_vx_v3_fig01.m` and `plot_vx_v3_fig02.m`

No file named above exists as formal runtime evidence at this stage.
