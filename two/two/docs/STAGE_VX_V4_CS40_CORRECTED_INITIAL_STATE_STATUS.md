# Stage VX-V4-CS40 Corrected Initial State Status

## Verdict

`VX_CS40_PHYSICAL_GATE_CHANGED_AFTER_INITIAL_STATE_FIX`

- new runtime count: `1` (committed exactly once)
- rerun: prohibited
- automatic retuning/profile changes: not performed

## Control snapshot and pre-run gates

- user-saved source: `D:/UsersData/桌面/two/model/Yaw Control Diff., DLC w_ Low Mu.cpar`
- source Run dataset: `Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517`
- Run title: `Yaw Control Diff., DLC w/ Low Mu`
- initial-speed token/value/unit: `SV_VXS = 40 km/h`
- `MU_ROAD_CONSTANT = 0.30`
- `TSTOP = 16 s`
- pre-run initial-speed gate: `PASS`
- pre-run mu gate: `PASS`
- new `Run_all.par` SHA-256: `4796D5256635D17A3275D40EA835A932050C82DF1898CA4CD5E63DEABC901F11`

The new Run_all snapshot was extracted from the user-saved cpar. Vehicle, road, powertrain, brake, procedure, and Run-title lineage matches the previous MU03 control. Only the proven headless `simfile.sim` interface was reused.

## Fresh VX-CS40 result

- actual first finite CarSim Vx: `11.111111111 m/s = 40.000000000 km/h`
- post-run initial-state gate: `PASS`
- old `72 -> 40 km/h` initial transient: `DISAPPEARED`
- estimator output finite: `YES`
- drive physical gate `[3,7)`: `FAIL`; RL/RR sustained durations `0/0 s`
- brake physical gate `[9,12)`: `PASS`; RL/RR sustained durations `2.731/2.731 s`

The corrected initial state changed the drive-slip physics. Per the preregistered stop rule, no second runtime, excitation adjustment, estimator change, Traditional WSS analysis, thesis figure, manifest edit, or old-table recomputation was performed.

## Evidence and protection

- raw: `results/vx_formal_validation/v4_cs40/runtime/VX_CS40_raw.mat`
- metadata: `results/vx_formal_validation/v4_cs40/runtime/VX_CS40_metadata.json`
- console: `results/vx_formal_validation/v4_cs40/runtime/VX_CS40_runtime_console.log`
- control manifest: `results/vx_formal_validation/v4_cs40/carsim_control_CS40/control_manifest.json`
- old V3B raw unchanged: `YES`
- old V3B freeze unchanged: `YES`
- estimator unchanged: `YES`
- parameters unchanged: `YES`
- source `vx.slx` unchanged: `YES`
