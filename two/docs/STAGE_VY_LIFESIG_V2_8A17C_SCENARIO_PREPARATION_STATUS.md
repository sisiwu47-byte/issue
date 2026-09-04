# V2.8-A17c Degradation-Recovery Scenario Preparation Status

## Final verdict

`SCENARIO_PREPARATION_PASS`

`READY_FOR_SINGLE_RUNTIME_DEGRADATION_RECOVERY_VALIDATION = YES`

`RUNTIME_COUNT = 0`

This stage created and compile-checked an independent, non-holdout V2.8 scenario target. No `sim()` call or CarSim runtime was performed.

## Independent lineage

| Artifact | SHA-256 | Status |
|---|---|---|
| A17a source target `model/vx_vy_lifesig_fusion_v2_8_recovery_validation.slx` | `C86D631F05C0942788BB4F67051608051A9AD95E22910DB3B61A271A498595BD` | unchanged |
| A17c target `model/vx_vy_lifesig_fusion_v2_8_degradation_recovery.slx` | `9BE6048ACA51F721528660F240CCB6E0FCA6004A3CC39798BF5F63C3BC52CE0F` | new independent target |
| independent `simfile.sim` | `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A` | D: lineage retained |
| independent `Run_all.par` | `C94F72AF3305FACED6E533169899271DA540558495315435E2BC4FB5533B095E` | only `TSTOP` changed to 40.5 s |
| V2.8 core | `E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17` | unchanged |
| V2.8 wrapper | `AD7FB99E833042490A171515B962718384EC2AD5F8B661F771C9ACF99501A164` | unchanged |
| frozen V2.7 target | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` | unchanged |
| frozen V2.7 core | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` | unchanged |
| frozen V2.7 wrapper | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` | unchanged |

The independent simfile retains `PROGDIR D:\carsim\CarSim2021.0_Prog\` and `DATADIR D:\carsim\CarSim2021.0_Data\`. Its control file contains `TSTOP 40.5`; the Simulink target `StopTime` is also 40.5 s.

## Frozen scenario definition

The steering command is a 4051-sample, 100 Hz `From Workspace` profile using the previously verified steering-input route.

| Phase | Time | Duration | Front road-wheel command |
|---|---:|---:|---|
| A — normal entry | 0 to 5.0 s | 5.0 s | `0.02*sin(2*pi*0.4*t)` rad |
| B — long straight/low-yaw candidate | 5.0 to 22.5 s | 17.5 s | exactly 0 rad |
| C — normal recovery excitation | 22.5 to 40.5 s | 18.0 s | `0.02*sin(2*pi*0.4*(t-22.5))` rad |

The stored profile contains exact zero at both 5.0 s and 22.5 s. Phase B is exact-zero steering throughout; phases A and C attain the requested 0.02-rad amplitude. The scenario does not alter any health logic to manufacture recovery.

## Binding and logging contract

The target remains bound to:

- core: `vy_lifesig_fusion_v2_8_step`
- wrapper: `vy_lifesig_fusion_v2_8_simulink_sfun`
- `I_K` initial/reset state: 0, unchanged

The target preserves the signals required for the future single runtime: common 100 Hz time, `Vy_true`, `Vy_D`, `Vy_K`, `Vy_F`, V2.8 `Vy_LS`, `d_DK`, `I_K`, `G_K`, `H_K`, `alpha_D/K/F`, `AVz_IMU`, CarSim AVz, D/K/F availability, reset, and steering-path logs.

`Vy_true` and CarSim AVz are offline-only diagnostics and do not feed the online LifeSig block. The frozen V2.7 Original LifeSig is not duplicated as a second online algorithm in this scenario target; it is recoverable exactly after runtime from the preserved D/K/F, availability, F-age, and reset inputs using the frozen V2.7 formula. This preserves the requested Original-LifeSig comparison without changing the A17a fusion architecture.

## Compile/update preflight

Exactly one compile/update call was reached:

| Gate | Result |
|---|---|
| static scenario/profile/logging audit | PASS |
| compile called | YES, once |
| compile | PASS |
| termination reached | PASS |
| compiled dimensions | PASS |
| compiled data types | PASS |
| 100 Hz sample-time contract | PASS |
| target/control hashes unchanged across compile | PASS |
| unresolved port/dimension/function error | none |
| `sim()` | NOT CALLED |
| CarSim runtime | NOT PERFORMED |

Compile-only CarSim initialization resolved `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` and terminated at simulation time 0 s. Existing derivative warnings were emitted during compile, but no compile error or interface conflict occurred.

## Evidence

| Evidence | SHA-256 |
|---|---|
| `results/vy_lifesig_v2_8a17c_scenario/scenario_build_evidence.mat` | `EAEE30BD933B157F1A4A27FF74539E7AF22C6995787C427A1B5BB794FFF23CFE` |
| `results/vy_lifesig_v2_8a17c_scenario/scenario_definition.csv` | `219B3E0935BA5B8542291CF52CAFBD8755BA1252A9A9603CAD17D51C5D9B5E4C` |
| `results/vy_lifesig_v2_8a17c_scenario/compile_preflight_evidence.mat` | `91B39CD7E62B52D7C2E71C05B33051909ED8ED1F9B39B5A4DC88CA6FCCFB544E` |
| `results/vy_lifesig_v2_8a17c_scenario/matlab_gui_preflight_recovery.log` | `6840852841AA1CC47F91F036D83DE78063DC53B0060E42F69619C9BEF68B5E98` |
| `results/vy_lifesig_v2_8a17c_scenario/matlab_gui_preflight_recovery_status.txt` | `05D934194121300B8FB7FDA8A1A30D4FEFDE3FA55D8402CD3B6330A63CDE986D` |

The first pre-compile attempt stopped before target creation and before compile because the evidence comparison consumed one CR character while replacing the TSTOP line. Its log/status and partial controls remain preserved separately. The line-ending-preserving evidence fix did not alter the scenario or estimator under test; the only authorized compile was therefore still unused and was subsequently consumed once by the successful preflight.

