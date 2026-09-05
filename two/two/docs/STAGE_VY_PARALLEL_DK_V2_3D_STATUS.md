# V2.3-D Parallel D/K Genuine Nominal Validation Status

## Final status

**V2.3-D PARALLEL D/K GENUINE NOMINAL VALIDATION COMPLETED**

Exactly one authorized 16-s shared CarSim runtime was executed. No second
runtime, rebuild, `save_system`, full-target compile-only retry, estimator
modification, Q/R tuning, bias correction, fusion, LifeSig, third track, or
DK-EKF runtime was performed.

Created files:

- `model/run_vy_parallel_dk_v2_3d_nominal_validation.m`
- `model/analyze_vy_parallel_dk_v2_3d_nominal_validation.m`
- `results/vy_parallel_dk_v2_3d_nominal_validation.mat`
- this status document

## A. Runtime validity

| Gate | Actual | Result |
|---|---|---|
| MATLAB `pwd` | `D:\UsersData\桌面\two\model` | PASS |
| active simfile | `D:\UsersData\桌面\two\model\simfile.sim` | PASS |
| `PROGDIR` | `D:\carsim\CarSim2021.0_Prog\` | PASS |
| `DATADIR` | `D:\carsim\CarSim2021.0_Data\` | PASS |
| actual solver | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` | PASS |
| G: request | `NO` | PASS |
| `simCalled / simulationCompleted / carSimRun` | `1 / 1 / 1` | PASS |
| actual StopTime | `16 s` | PASS |

CarSim console evidence:

```text
Use vehicle solver: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
Termination at simulation time = 16 s.
```

The existing Derivative-block warnings remained non-blocking. The recorded
full-target compile-only `vs_sf` access violation remains a separate external
CarSim initialization limitation and was not retried.

### Genuine steering from this runtime

| Metric | Actual |
|---|---:|
| samples / time | `16003 / [0,16] s` |
| command min / max / maxAbs | `-0.02 / 0.02 / 0.02 rad` |
| converted min / max / maxAbs | `-1.1459155902616465 / 1.1459155902616465 / 1.1459155902616465 deg` |
| fitted frequency | `0.40000420621982108 Hz` |
| command vs theoretical sine maxAbsDiff | `0` |
| median deg/rad | `57.295779513082323` |
| ratio error from `180/pi` | `7.1054273576010019e-15` |
| FL / FR maxAbs | `1.1459155902616465 / 1.1459155902616465 deg` |
| FL/FR vs converted maxAbsDiff | `0 / 0 deg` |
| FL vs FR maxAbsDiff | `0 deg` |
| RL / RR maxAbs | `0 / 0 deg` |

### Independent runtime streams

| Gate | D-EKF | K-KF |
|---|---:|---:|
| state | `[Vy_D;r_D]`, `2x1` | `[Vx_K;Vy_K]`, `2x1` |
| covariance | `2x2` | `2x2` |
| samples | 1601 | 1601 |
| time | `[0,16] s` | `[0,16] s` |
| dt min / mean / max | `0.0099999999999997868 / 0.01 / 0.010000000000001563 s` | same |
| duplicate timestamps / missing hits | `0 / 0` | `0 / 0` |
| x / P / diagnostics finite | `YES / YES / YES` | `YES / YES / YES` |
| covariance max asymmetry | `0` | `0` |
| minimum covariance eigenvalue | `1.0003008776283697e-4` | `6.1803398902939073e-5` |

D/K sample counts are equal, timestamps match exactly, and maximum timestamp
difference is `0`. Their function-call scheduler implementations remain
independent.

### Reset and multirate gates

- D reset/lifecycle: one at `t=0`; prior `x=[0;0]`, `P=diag([0.1,0.1])`.
- K reset: one at `t=0`; prior `x=[20;0]`, `P=diag([0.1,0.1])`.
- True Vy initialization: `NO` for both estimators.
- D Ay updates: `321`, from `0` through `16 s`; interval min/mean/max is
  `0.049999999999998934 / 0.05 / 0.050000000000000711 s`.
- K Ax/Ay/AVz process inputs: `1601/1601` actual K hits.
- D Ay gate controls K Ay: `NO`.

## B. Numerical and replay validity

Both replays used this runtime's actual inputs, the same timestamps and
indices, frozen implementations, and no arbitrary shift.

| Replay | x maxAbsDiff | P maxAbsDiff | diagnostics maxAbsDiff | Result |
|---|---:|---:|---:|---|
| D-EKF 16 s | `0` | `0` | `0` | PASS |
| K-KF 16 s | `0` | `0` | `0` | PASS |

```text
ONE D 100-HZ HIT = ONE COMMITTED D-EKF ADVANCE: PASS
ONE K 100-HZ HIT = ONE COMMITTED K-KF ADVANCE: PASS
```

Offline truth provenance and alignment:

- `Vx_true_log <- Gain38`, m/s;
- `vy_true_log1 <- Gain11`, m/s;
- `avz_log1 <- Demux4/2`, CarSim deg/s, converted offline once by `pi/180`;
- D and K Vx/Vy/r truth alignment: exact timestamp match;
- interpolation: not needed;
- extrapolation: not used;
- truth online estimator use: `NO` except frozen true-Vx roles already defined.

## C. D-EKF performance

| State | RMSE | MAE | Bias | MaxAbsError | FinalError |
|---|---:|---:|---:|---:|---:|
| Vy_D, m/s | `0.036415619095730323` | `0.032997197566322564` | `-0.0043966919566230831` | `0.061201229017568012` | `-0.038275348781093205` |
| r_D, rad/s | `0.0045399313572879862` | `0.004172974976330796` | `0.0041477018733029293` | `0.011203881240727229` | `0.0047636557023542497` |

Existing frozen D diagnostics only:

- aggregate `NIS = diag(1) = info.NIS`;
- Ay/r innovations are `diag(10:11) = z-h`;
- `AyUpdateApplied = diag(56) = useAy`;
- step index is `diag(57)`;
- joint-update NIS is `diag(60)` on Ay hits;
- r-only NIS is `diag(61)` on r-only hits.

| Diagnostic | mean | median | p95 | max |
|---|---:|---:|---:|---:|
| aggregate NIS | `0.043777095519187133` | `0.021310239440894881` | `0.16939441428377935` | `0.52580605209548781` |
| joint NIS, 321 hits | `0.091506935656628249` | `0.063456554336524237` | `0.25279077519575038` | `0.52580605209548781` |
| r-only NIS | `0.031807346547219506` | `0.013644093919923776` | `0.11567745397571795` | `0.31914459407136631` |

Applied Ay innovation mean/RMS/maxAbs:
`-0.025564239917361488 / 0.043881600578848455 / 0.15031699268626858`.
The r innovation mean/RMS/maxAbs is
`0.0011543677881261237 / 0.0041235220943561957 / 0.013070923461092024`.

## D. K-KF performance

| State | RMSE | MAE | Bias | MaxAbsError | FinalError |
|---|---:|---:|---:|---:|---:|
| Vx_K, m/s | `0.00018038270529703834` | `0.00014852232309570918` | `0.00011104740929482872` | `0.00038932351035114721` | `-0.000058577929909375825` |
| Vy_K, m/s | `0.25962779566180644` | `0.24795739263649411` | `-0.24795739263649411` | `0.349597819793529` | `-0.28480615822432354` |

Frozen K diagnostic definition is exactly:

```text
[NIS; obs_metric=abs(AVz_IMU); innovation_Vx; K11; K21]
```

`obs_metric` matched actual `abs(AVz_IMU)` with max difference `0`. The
`0.01 rad/s` split remained descriptive only, not a formal gate or LifeSig.

| Diagnostic | mean | median | p95 | max |
|---|---:|---:|---:|---:|
| NIS | `0.00085451996222920211` | `0.00036479571254436559` | `0.0028483848130333098` | `0.0039899041859609132` |
| obs_metric | `0.079224767508222091` | `0.088732727067727377` | `0.12678085739759343` | `0.13662429862884545` |
| K11 | `0.61926753109155164` | `0.61894564439534061` | `0.62014181650252342` | `0.99900199600845885` |
| K21 | `0.15950079095336836` | `0.26581465709292595` | `2.7410816804628153` | `2.9234914259753975` |

## E. Same-run D/K comparison

All numbers below come from the same V2.3-D shared CarSim runtime.

| Vy metric | D-EKF | K-KF | D minus K |
|---|---:|---:|---:|
| RMSE | `0.036415619095730323` | `0.25962779566180644` | `-0.223212176566076` |
| MAE | `0.032997197566322564` | `0.24795739263649411` | `-0.214960195070172` |
| Bias | `-0.0043966919566230831` | `-0.24795739263649411` | `0.243560700679871` |
| MaxAbsError | `0.061201229017568012` | `0.349597819793529` | `-0.288396590775961` |
| FinalError | `-0.038275348781093205` | `-0.28480615822432354` | `0.246530809443230` |

By overall Vy RMSE in this nominal run, D-EKF has the smaller error. This is
a descriptive result, not evidence that K-KF is unnecessary or may be removed.

### State-aligned covariance

Values are `[initial, final, min, max, mean]`:

| Quantity | Values |
|---|---|
| D `P11(Vy)` | `[0.00012872236091292726, 0.00017532782616298226, 0.00010676780332613539, 0.00048753146212755398, 0.00030698974517134344]` |
| D `P22(r)` | `[0.00033496743822249066, 0.00012630119171345058, 0.0001214094281212789, 0.00033496743822249066, 0.00012593952457865709]` |
| K `P11(Vx)` | `[9.9900199600845891e-5, 6.1943431621789633e-5, 6.1803399247583742e-5, 9.9900199600845891e-5, 6.1926753109155147e-5]` |
| K `P22(Vy)` | `[0.10100000004767072, 0.34001979717424824, 0.10100000004767072, 0.3873021681155186, 0.32643787641132921]` |

Vy uncertainty is correctly compared as D `P11` versus K `P22`; D `P22` was
not misidentified as Vy variance. No fusion weight was generated.

## F. Common excitation-partition behavior

The common online `AVz_IMU` partition used
`low-r <= 0.01 rad/s`, `higher-r > 0.01 rad/s`.

| Yaw statistic | Actual |
|---|---:|
| mean(abs(r)) | `0.079224767508222091` |
| median(abs(r)) | `0.088732727067727377` |
| p95(abs(r)) | `0.12678085739759343` |
| max(abs(r)) | `0.13662429862884545` |
| low-r | `80 / 0.04996876951905059` |
| higher-r | `1521 / 0.9500312304809494` |

| Track/partition | RMSE | MAE | Bias |
|---|---:|---:|---:|
| D Vy low-r | `0.047763234750152872` | `0.045518432573575712` | `-0.0052063610467680006` |
| D Vy higher-r | `0.035719114531849297` | `0.032338618473238899` | `-0.0043541058111848229` |
| K Vy low-r | `0.25027770559245061` | `0.23061624280134246` | `-0.23061624280134246` |
| K Vy higher-r | `0.26011027834664219` | `0.24886948467253103` | `-0.24886948467253103` |

The partition is diagnostic only. No switch, weighting, LifeSig, or fusion was
derived from it.

## G. Offline complementarity characterization

```text
Pearson correlation(e_D,e_K) = 0.26540777187448517
mean(abs(e_D-e_K))           = 0.24356369156472568 m/s
```

Winner fractions use exact equality of absolute errors as the tie definition:

| Partition | D smaller | K smaller | tie |
|---|---:|---:|---:|
| overall | `0.97751405371642719` | `0.022485946283572766` | `0` |
| low-r | `0.9375` | `0.0625` | `0` |
| higher-r | `0.9796186719263642` | `0.020381328073635765` | `0` |

The non-unity error correlation and occasional K wins are descriptive
complementarity evidence. They do not authorize immediate fusion.

### Independent-reference policy

V2.1-G1-A was machine-readable and fully qualified. Actual timestamps,
steering, K inputs, Vx/Vy truth all matched V2.3-D samplewise with maximum
differences `0`; parallel K x/P/diagnostics also differed from independent
G1-A by `0/0/0`. Therefore the parallel integration did not perturb frozen
K-KF.

**NO QUALIFIED INDEPENDENT GENUINE D-EKF 16-S REFERENCE AVAILABLE.**

No zero-steer or different-condition evidence was substituted. The current
D exact replay `0/0/0` is the non-interference evidence for D-EKF.

## H. Parallel independence and integrity

Combined evidence:

```text
formal parallel static gates = 41/41 PASS
harness static gates         = 38/38 PASS
compiled estimator gates     = 15/15 PASS
V2.3-C short runtime         = PASS
V2.3-D D exact replay        = 0/0/0 PASS
V2.3-D K exact replay        = 0/0/0 PASS
```

Current shared-input logs resolved exactly at all D and K hits. K's actual
`[Ax,Ay,AVz,trueVx]` log matched the common input rows with maxAbsDiff `0`.
Actual wiring remains:

- Ax -> K only;
- Ay -> D measurement and K process input;
- AVz -> D r measurement and K process input;
- true Vx -> D dynamics and K Vx measurement;
- steering -> D only;
- true Vy -> neither estimator online.

Confirmed absent: D->K, K->D, covariance exchange, pseudo measurement,
weighted sum, estimator switch, alpha, reliability logic, LifeSig, third
track, and `Vy_final`.

### Frozen hashes

| Object | SHA-256 | Status |
|---|---|---|
| parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| D model | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| D wrapper | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| D step V17 | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` | unchanged |
| D step V13 | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` | unchanged |
| K base model | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| K genuine model | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |
| K core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| K wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| DK-EKF model | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged / not run |
| DK core | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| DK wrapper | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| DK adapter | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |

Evidence hashes:

```text
runner      C0DEDB3634E61D57A73022FBF8BB973EF04812EEC599A598019AC0B52FDFAABA
analyzer    5F5C3AE0AEDAB8C6964425861238921CB060AE97796BC15AA65592716F3B707C
result MAT  AB65F66E0F6963ACF417079FA570C3B3582791CC946DCF48764A83B99807883C
```

## Required answers

1. D-EKF Vy RMSE/MAE/Bias/MaxAbs/final:
   `0.0364156191 / 0.0329971976 / -0.0043966920 / 0.0612012290 / -0.0382753488 m/s`.
2. K-KF Vy RMSE/MAE/Bias/MaxAbs/final:
   `0.2596277957 / 0.2479573926 / -0.2479573926 / 0.3495978198 / -0.2848061582 m/s`.
3. Overall Vy error is smaller for D-EKF in this shared nominal runtime.
4. D-EKF has lower Vy RMSE in both low-r and higher-r partitions; the exact
   partition metrics are recorded above.
5. D Vy variance `P11` remains around `1e-4`; K Vy variance `P22` ranges from
   `0.1010` to `0.3873` with mean `0.3264`. These are descriptive, not weights.
6. Error correlation is `0.2654077719`; overall winner fractions are
   D `0.9775140537`, K `0.0224859463`, ties `0`.
7. Both 16-s exact replays pass with exact `0/0/0` differences.
8. No parallel coupling evidence exists.
9. No evidence in this stage authorizes modifying frozen D/K mathematics.
10. No evidence authorizes starting fusion now. Even with descriptive
    complementarity, the fixed route requires parallel acceptance/freeze first.
11. The next minimum stage is **V2.3-E PARALLEL D/K FINAL ACCEPTANCE & FREEZE**.

## Stage conclusion

**V2.3-D PARALLEL D/K GENUINE NOMINAL VALIDATION COMPLETED**

READY FOR V2.3-E PARALLEL D/K FINAL ACCEPTANCE & FREEZE
