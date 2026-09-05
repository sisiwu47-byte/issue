# V2.7-A3R10 Full 16 s Nominal Runtime Validation

## Stage verdict

`LIFESIG_16S_NOMINAL_VALIDATION_PASS`

Role: `NON_HOLDOUT_NOMINAL_ENGINEERING_VALIDATION`

The single authorized runtime completed normally. MATLAB batch exited with code 0, CarSim terminated normally at simulation time 16 s, and no retry or second `sim()` was executed.

## Frozen runtime condition

- Stop time: 16 s
- Nominal speed: approximately 20 m/s
- Front road-wheel steering: 0.02 rad amplitude, 0.4 Hz sine
- Estimator/fusion rate: 100 Hz
- Runtime working directory: project `model/`
- CarSim solver lineage: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`

## Runtime integrity

- Simulation completed: YES
- CarSim ran: YES
- Authorized `sim()` invocations: 1
- Samples: 1601
- Time range: 0 to 16 s
- Mean/nominal sample interval: 0.01 s
- All required logs aligned: YES
- All formal logs finite: YES
- Normal-path samples: 1601
- Fallback samples: 0
- Availability drops `[D K F]`: `[0 0 0]`

No fallback occurred because all three track inputs remained numerically available and the score sum remained positive. This is a runtime observation, not a change to fallback semantics.

## LifeSig contract and exact replay

- `alpha_D/K/F >= 0`: PASS
- Maximum normal-path `abs(sum(alpha)-1)`: `2.2204460492503131e-16`
- Maximum health replay error: `0`
- Maximum full frozen-core replay error, including `Vy_LS`: `0`
- Minimum score sum: `0.99526889054144274`
- `fusion_valid`: consistent with the normal path for all 1601 samples
- `fallback_active`: zero for all 1601 samples

The offline replay used the runtime inputs and the frozen sequential core formula, including last-valid/reset state semantics. No parameter was fitted or changed.

## Weight and health behavior

| Signal | Minimum | Maximum | Mean | Standard deviation |
|---|---:|---:|---:|---:|
| `alpha_D` | 0.84261840932572185 | 0.84662387957019702 | 0.84480592205575633 | 0.0011545081952323338 |
| `alpha_K` | 0.14643969744669252 | 0.14713581308366519 | 0.14681986799459618 | 0.00020064340980259309 |
| `alpha_F` | 0.0062403073461377309 | 0.01094189322758545 | 0.0083742099496471791 | 0.0013551516050349266 |

- `H_F` start/end: `1` / `0.56761509547270994`
- `alpha_F` start/end: `0.01094189322758545` / `0.0062403073461377309`
- `H_D/H_K` matched their frozen availability semantics exactly.
- `H_F` matched the frozen age exponential exactly.

## Descriptive-only truth metrics

These metrics are reporting only. They were not used to tune `q`, `tau_F`, fallback, Q/R, P0_F/Q_F, or any health gate.

| Output | RMSE | MAE | MaxAbs | Bias |
|---|---:|---:|---:|---:|
| LifeSig `Vy_LS` | 0.057604956671948829 | 0.047226524779178478 | 0.10759579896829302 | -0.045051740738381342 |
| D track | 0.036415619095730323 | 0.032997197566322564 | 0.061201229017568012 | -0.0043966919566230831 |
| K track | 0.25962779566180644 | 0.24795739263649411 | 0.349597819793529 | -0.24795739263649411 |
| F track | 0.74738332275976438 | 0.64797303941009787 | 1.2660624093959161 | -0.64797303941009787 |
| Static-quality-prior baseline | 0.059409251831957541 | 0.049258453029168078 | 0.11035029457553254 | -0.047105590951723217 |
| Frozen V2.5 fixed fusion replay | 0.045506137078519533 | 0.036513291485064429 | 0.088564609144097931 | -0.028638753266451687 |

## Artifact integrity

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `model/run_vy_lifesig_fusion_v2_7a3r10_nominal.m` | 8974 | `B5CD0EA5D3036713001FF4353DF1A6601A09D418FE9033F882CE3D6688797B2F` |
| `model/analyze_vy_lifesig_fusion_v2_7a3r10_nominal.m` | 10647 | `EE323A392961A18E5AF4AA979C114B540F0821009078C17806AE9EE12390CF7C` |
| `model/vx_vy_lifesig_fusion_v2_7.slx` | 519905 | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |
| `model/vy_lifesig_fusion_step.m` | 3224 | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| `model/vy_lifesig_fusion_simulink_sfun.m` | 2729 | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |
| `results/vy_reliability_lifesig_v2_7a3r10_nominal.mat` | 978255 | `E02DA4498441249C6AD7108FAD529C9724053B3B7FE469FFC0DF629208FCBBF3` |
| `results/vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv` | 2027 | `6F934A700D1EDEE2CFC1569DC08BB94595854FD589582194AEFAE5392B1C4C3D` |

The target, LifeSig core, and wrapper hashes match their pre-run values. No model, estimator, fusion parameter, Q/R, P0_F/Q_F, prior, health gate, or fallback rule was modified by the runtime.

## Process closure note

The authorized batch command returned exit code 0. No CarSim solver process was visible after completion. A separate/inaccessible `MATLAB.exe` and pre-existing `MATLABWebUI` processes were visible to the restricted process query; they cannot be attributed to this completed batch from available permissions and were not touched.

## Next stage

`READY FOR V2.7 FINAL ACCEPTANCE AND FREEZE AUDIT`
