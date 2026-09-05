# V2.2-D2 DK-EKF Genuine Nominal Validation Status

- Date: 2026-08-27
- Stage: V2.2-D2 — DK-EKF 16-s genuine nominal validation
- Sol conclusion: **V2.2-D2 DK-EKF GENUINE NOMINAL VALIDATION COMPLETED**
- Characterization: **DK-EKF NOMINAL BASELINE NUMERICALLY VALID AND PERFORMANCE CHARACTERIZED**
- New CarSim runtimes in D2: exactly one
- Builder / `save_system`: not called
- Q/R tuning, online bias correction, fusion, LifeSig: not performed

## A. Executed configuration and environment

The fixed validation model was used without rebuild or save:

`model/vx_vy_dkekf_v2_2d_nominal.slx`

Runtime configuration:

| Item | Actual value |
|---|---:|
| StopTime | 16 s |
| commanded Vx | 20 m/s |
| front steering amplitude | 0.02 rad |
| steering frequency | 0.4 Hz |
| rear steering | 0 |

CarSim used the accepted D: environment:

- `PROGDIR = D:\carsim\CarSim2021.0_Prog\`
- `DATADIR = D:\carsim\CarSim2021.0_Data\`
- solver: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- G: request: **NO**
- console completion: `Termination at simulation time = 16 s.`

The pre-analysis MATLAB syntax-check session initially hit the previously known
settings-plugin startup error inside the restricted execution context. It did
not load a model or call `sim()`. A sandbox-external syntax-check session then
completed normally. This was not a CarSim runtime and did not consume the one
authorized D2 runtime.

## B. Genuine steering evidence

| Metric | Actual |
|---|---:|
| `steer_cmd_rad` maxAbs | 0.0200000000000000 rad |
| converted maxAbs | 1.14591559026165 deg |
| median deg/rad ratio | 57.2957795130823 |
| FL maxAbs | 1.14591559026165 deg |
| FR maxAbs | 1.14591559026165 deg |
| RL maxAbs | 0 deg |
| RR maxAbs | 0 deg |
| FL vs converted maxAbsDiff | 0 |
| FR vs converted maxAbsDiff | 0 |
| FL vs FR maxAbsDiff | 0 |
| fitted frequency | 0.400004206219821 Hz |
| `frontCommandApplied` | 1 |

The 16-s D2 runtime therefore independently proves that the nominal front
road-wheel command reached the CarSim boundary. Rear command remained zero.

## C. Runtime, reset, and Ay scheduler integrity

| Evidence | Actual |
|---|---:|
| `simulationCompleted / simCalled / carSimRun` | `1 / 1 / 1` |
| x / P / diag samples | `1601 / 1601 / 1601` |
| raw input samples | 16003 |
| time range | `[0, 16]` s |
| dt min / mean / max | `0.00999999999999979 / 0.01 / 0.0100000000000016` s |
| duplicate timestamps | 0 |
| missing 100-Hz hits | 0 |
| reset high count / time | `1 / 0 s` |
| `doAyUpdate` / `AyUpdateApplied` count | `321 / 321` |
| Ay first / last / median interval | `0 / 16 / 0.05 s` |

Initialization prior was `x0=[20,0,0]` and `P0=diag([0.1,0.1,0.1])`.
The first logged P is the posterior after the reset hit, not the prior. TRUE Vy
was not used for initialization.

The raw 1-kHz input log and 100-Hz output timestamps had 1589 bit-exact hits.
The remaining 12 hits differed only by floating representation
(`maxNearestTimeDelta=8.8817841970012523e-16 s`), with a unique nearest hit and
within `32*eps`. No timestamp or index shift was applied.

## D. Numerical and covariance validity

- Dimensions: `x=3`, `P=3x3`, `diag=7`.
- x, P, and diagnostics: all finite.
- Maximum covariance asymmetry: `0`.
- Minimum covariance eigenvalue over all samples:
  `6.18019434960469e-05`.

| Covariance | Initial logged posterior | Final | Min | Max | Mean |
|---|---:|---:|---:|---:|---:|
| P11 | 9.99001996007243e-05 | 6.18030503963256e-05 | 6.18030390549780e-05 | 9.99001996007243e-05 | 6.18307543740244e-05 |
| P22 | 1.29670271453691e-04 | 1.75432247439703e-04 | 1.06682314517032e-04 | 4.87606880630845e-04 | 3.07054713236899e-04 |
| P33 | 3.34968081772924e-04 | 1.26314925446581e-04 | 1.21319072383098e-04 | 3.34968081772924e-04 | 1.25938956174805e-04 |

No covariance clipping or tuning was applied.

## E. Offline truth alignment and performance

Offline truth was not fed to the estimator. `Vx_true_log`, `vy_true_log1`, and
`avz_log1` each contained 16001 samples and all DK-EKF timestamps had exact
timestamp matches. CarSim AVz truth was logged in deg/s and converted offline
once with `pi/180` to rad/s. No interpolation or extrapolation was required.

| State | RMSE | MAE | Bias | MaxAbsError | Final error |
|---|---:|---:|---:|---:|---:|
| Vx (m/s) | 0.0001221994625 | 0.0001201043090 | 0.0001201038638 | 0.0001847294103 | 0.0001011950956 |
| Vy (m/s) | 0.03609614959 | 0.03273061676 | -0.004423390516 | 0.06063857957 | -0.03823195237 |
| r (rad/s) | 0.004539848056 | 0.004171493663 | 0.004146006357 | 0.01124239912 | 0.004792178613 |

- Vy estimate range: `[-0.1368313191, 0.1217355342] m/s`.
- Vy truth range: `[-0.09296531853, 0.09297498184] m/s`.

## F. Excitation partitions and Vy performance

Online `AVz_IMU` excitation:

| Metric | Actual |
|---|---:|
| mean(abs(r)) | 0.07922476751 rad/s |
| median(abs(r)) | 0.08873272707 rad/s |
| p95(abs(r)) | 0.1267808574 rad/s |
| max(abs(r)) | 0.1366242986 rad/s |
| low-r count / fraction | `80 / 0.04996876952` |
| higher-r count / fraction | `1521 / 0.9500312305` |

The `0.01 rad/s` threshold is diagnostic only; no LifeSig or observability gate
was implemented.

| Vy partition | Samples | RMSE | MAE | Bias |
|---|---:|---:|---:|---:|
| low-r | 80 | 0.04724791116 | 0.04501844295 | -0.005219797294 |
| higher-r | 1521 | 0.03541252102 | 0.03208431427 | -0.004381501928 |

## G. NIS and innovations

`3.8414588` is used only as the 1-DOF 95% diagnostic reference.

| NIS | Samples | Mean | Median | p95 | Max | Fraction <= 3.8414588 |
|---|---:|---:|---:|---:|---:|---:|
| Vx | 1601 | 0.0003939562603 | 0.0003873097424 | 0.0006284127674 | 0.0008971174555 | 1 |
| r | 1601 | 0.03104848284 | 0.01427708942 | 0.1156551450 | 0.3163744936 | 1 |
| Ay update hits only | 321 | 0.06005155145 | 0.02952396097 | 0.2241215879 | 0.4923899115 | 1 |

| Innovation | Mean | RMS | MaxAbs |
|---|---:|---:|---:|
| Vx | -0.0003154283536 | 0.0003212869495 | 0.0004846325056 |
| r | 0.001156928948 | 0.004082829994 | 0.01301361995 |
| Ay, update hits only | -0.02627760629 | 0.04414512824 | 0.1451820075 |

All three NIS series are well below the nominal order-one scale and every value
is below the 95% reference. This is a documented conservative consistency
characteristic for this one condition, not a runtime failure and not sufficient
evidence to tune Q/R.

## H. Exact replay and one-hit semantics

The offline B0 replay used the actual 100-Hz hit inputs, the frozen step
function, the runtime reset initialization, the same timestamp/index, and no
arbitrary shift.

| Replay metric | Actual |
|---|---:|
| maxAbsXDiff | 0 |
| maxAbsPDiff | 0 |
| maxAbsDiagDiff | 0 |

**ONE 100-HZ FUNCTION-CALL HIT = ONE COMMITTED DK-EKF STATE ADVANCE: PASS.**

## I. Fairness

- TRUE Vy online: NO.
- True Vx: measurement only.
- Ax_IMU: prediction input only.
- AVz_IMU: measurement only.
- Ay_IMU: measurement only.
- Shared x/P: YES.
- Output fusion: NO.
- LifeSig: NO.
- Adaptive fusion: NO.

## J. Genuine K-KF G1-A reference

Both runs used 16 s, approximately 20 m/s, genuine 0.02-rad front steering at
0.4 Hz, rear steering zero, and passed their own steering gates. The comparison
is therefore accepted as apples-to-apples for this baseline reference.

| Vy metric | K-KF G1-A | DK-EKF D2 | DK minus K |
|---|---:|---:|---:|
| RMSE | 0.2596277957 | 0.03609614959 | -0.2235316461 |
| MAE | 0.2479573926 | 0.03273061676 | -0.2152267759 |
| Bias | -0.2479573926 | -0.004423390516 | +0.2435340021 |
| MaxAbsError | 0.3495978198 | 0.06063857957 | -0.2889592402 |
| Final error | -0.2848061582 | -0.03823195237 | +0.2465742059 |

No D-EKF comparison was made because this stage did not establish an existing
genuine 0.02-rad / 0.4-Hz / 16-s D-EKF runtime.

## K. Frozen hash integrity

| File | SHA-256 | Status |
|---|---|---|
| `model/vx_vy_dkekf_v2_2d_nominal.slx` | `A17E7609D2248C832A80F773660941B68025E3A38CFC1F3938CBCA2BD0165E5B` | unchanged |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |

## L. Decision answers and stop state

1. DK-EKF Vy metrics are listed in Section E: RMSE `0.03609615 m/s`, MAE
   `0.03273062 m/s`, bias `-0.004423391 m/s`, maxAbs `0.06063858 m/s`, and
   final error `-0.03823195 m/s`.
2. Vx and r metrics are listed in Section E; both were computed against offline
   CarSim truth with no estimator feedback.
3. P22 final is `1.75432247439703e-04`; its logged range is
   `[1.06682314517032e-04, 4.87606880630845e-04]`.
4. NIS is finite and below the diagnostic bound for every sample, but is
   substantially below order one; this conservative behavior is documented.
5. Exact replay passed with zero x/P/diag difference.
6. Under the matched genuine nominal condition, DK-EKF Vy error is materially
   lower than K-KF G1-A for every reported magnitude metric.
7. This single valid nominal run supplies no evidence requiring a DK-EKF
   mathematical change.
8. It also supplies insufficient evidence to tune Q/R; no tuning was performed.
9. The next minimal phase is a read-only independent DK-EKF baseline acceptance
   and freeze review using this archived D2 evidence and hashes. It must not
   automatically introduce tuning, bias correction, fusion, or LifeSig.

**V2.2-D2 DK-EKF GENUINE NOMINAL VALIDATION COMPLETED**

**DK-EKF NOMINAL BASELINE NUMERICALLY VALID AND PERFORMANCE CHARACTERIZED**

NO DK-EKF CORE MODIFICATION.

NO Q/R TUNING.

NO ONLINE BIAS CORRECTION.

NO FUSION.

NO LIFESIG.
