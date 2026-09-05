# STAGE VY K-KF V2.1-G1 STATUS

- Date: 2026-08-26
- Stage: V2.1-G1 Genuine Steering 16 s A/B Observability Validation
- Sol decision: **V2.1-G1 HIGHER-YAW OBSERVABILITY IMPROVED**
- New CarSim runtimes: exactly two (`G1-A`, then `G1-B`)
- Q/R/P0 tuning or online bias correction: **NOT PERFORMED**

## A. Created files and execution

```text
model/run_vy_kkf_v2_1g1_ab_validation.m
model/analyze_vy_kkf_v2_1g1_ab_validation.m
results/vy_kkf_v2_1g1_nominal_002.mat
results/vy_kkf_v2_1g1_highyaw_004.mat
results/vy_kkf_v2_1g1_comparison.mat
docs/STAGE_VY_KKF_V2_1G1_STATUS.md
```

The run script loaded but did not save or modify
`model/vx_vy_kkf_v2_1g_steer.slx`. It assigned only runtime workspace values,
ran A, checked A's steering gate, and ran B only after A passed. The actual
runtime command was:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two');addpath(fullfile(pwd,'model'));try,s=run_vy_kkf_v2_1g1_ab_validation();disp(s);catch ME,disp(getReport(ME,'extended','hyperlinks','off'));exit(1);end;exit(0)"
```

Both cases used `StopTime=16 s`, `Vx=20 m/s`, and `0.4 Hz`; only front-steer
amplitude differed. Each run produced the eight existing Derivative block
warnings and CarSim termination at 16 s. No additional runtime was performed.

The offline analyzer then used only the two saved runtime MAT files. B0/B3 did
not call Simulink or CarSim. A final summary-print field typo was corrected
after all comparison MAT files had already been saved; it did not affect any
computed evidence.

## B. Excitation validity

| Runtime steering metric | G1-A 0.02 rad | G1-B 0.04 rad |
|---|---:|---:|
| command maxAbs (rad) | 0.0200000000 | 0.0400000000 |
| converted maxAbs (deg) | 1.1459155903 | 2.2918311805 |
| FL maxAbs (deg) | 1.1459155903 | 2.2918311805 |
| FR maxAbs (deg) | 1.1459155903 | 2.2918311805 |
| RL maxAbs (deg) | 0 | 0 |
| RR maxAbs (deg) | 0 | 0 |
| identified frequency (Hz) | 0.4000042062 | 0.4000042062 |
| front command applied | 1 | 1 |
| steering gate | PASS | PASS |

For both cases FL/FR matched the converted front command sample-for-sample;
FL/FR mutual max difference and command max differences were all zero. Rear
commands remained zero. These are genuine new A/B steering runtimes. The old
C1/E runs remain a **ZERO-STEER HISTORICAL BASELINE**, not true 0.02/0.04 rad
cases.

## C. Runtime integrity

| Evidence | G1-A | G1-B |
|---|---:|---:|
| simulation completed / CarSim ran | 1 / 1 | 1 / 1 |
| K-KF samples `[u x P diag]` | `[1601 1601 1601 1601]` | `[1601 1601 1601 1601]` |
| time range (s) | `[0 16]` | `[0 16]` |
| dt min / mean / max (s) | `0.00999999999999979 / 0.01 / 0.0100000000000016` | same |
| reset high count / time (s) | `1 / 0` | `1 / 0` |
| x / P / diagnostics finite | `1 / 1 / 1` | `1 / 1 / 1` |
| max covariance asymmetry | 0 | 0 |
| minimum covariance eigenvalue | 6.1803398903e-05 | 6.1803399199e-05 |

Poor estimator performance was not used as a runtime-failure condition.

## D. Genuine yaw-excitation distribution

The diagnostic partition is `low-r: abs(AVz_IMU)<=0.01 rad/s`; it is not a
LifeSig gate.

| AVz evidence | G1-A 0.02 | G1-B 0.04 | B/A or delta |
|---|---:|---:|---:|
| mean(abs(r)) | 0.07922477 | 0.15664413 | 1.9772x |
| median(abs(r)) | 0.08873273 | 0.17681927 | 1.9927x |
| p95(abs(r)) | 0.12678086 | 0.24151130 | 1.9050x |
| max(abs(r)) | 0.13662430 | 0.25293912 | 1.8513x |
| low-r samples / fraction | 80 / 4.9969% | 42 / 2.6234% | -2.3735 pp |
| higher-r samples / fraction | 1521 / 95.0031% | 1559 / 97.3766% | +2.3735 pp |

The 0.04 rad run therefore produced substantially higher yaw excitation than
the 0.02 rad run across mean, median, p95, maximum, and higher-r fraction.

## E. K21 observability evidence

| K21 evidence | G1-A 0.02 | G1-B 0.04 | B/A or delta |
|---|---:|---:|---:|
| mean(abs(K21)) | 1.59188813 | 1.72143393 | 1.0814x |
| median(abs(K21)) | 1.70202988 | 1.92681241 | 1.1321x |
| p95(abs(K21)) | 2.74245798 | 2.70736057 | 0.9872x |
| max(abs(K21)) | 2.92349143 | 2.78783442 | 0.9536x |
| corr(abs(r),abs(K21)) | 0.91984946 | 0.97661419 | +0.056765 |

Partition evidence:

| Partition | A samples | A mean / median | B samples | B mean / median |
|---|---:|---:|---:|---:|
| low-r | 80 | 0.095911 / 0.089352 | 42 | 0.063929 / 0.042404 |
| higher-r | 1521 | 1.670572 / 1.753501 | 1559 | 1.766088 / 1.954667 |

Typical coupling strengthened: overall mean/median K21 and higher-r
mean/median K21 increased, and the r/K21 correlation became stronger. Peak
and p95 K21 did not increase, so the conclusion is stronger sustained/typical
coupling, not a larger K21 maximum.

## F. P22 covariance evidence

| P22 evidence | G1-A 0.02 | G1-B 0.04 | B-A |
|---|---:|---:|---:|
| initial | 0.10100000 | 0.10100000 | 0 |
| final | 0.34001980 | 0.16591052 | -0.17410928 |
| minimum | 0.10100000 | 0.10100000 | 0 |
| maximum | 0.38730217 | 0.20780600 | -0.17949617 |
| mean | 0.32643788 | 0.18040455 | -0.14603332 |
| second-half mean | 0.36175104 | 0.18548295 | -0.17626809 |

G1-B final and mean P22 are approximately 51.2% and 44.7% lower than G1-A.
This is direct evidence that higher yaw more strongly constrained Vy
covariance without any Q/R/P0 change.

## G. Online performance and NIS

| Metric | G1-A 0.02 | G1-B 0.04 | B/A or delta |
|---|---:|---:|---:|
| steering maxAbs (rad) | 0.020000 | 0.040000 | 2.0000x |
| AVz meanAbs | 0.079225 | 0.156644 | 1.9772x |
| AVz p95Abs | 0.126781 | 0.241511 | 1.9050x |
| AVz maxAbs | 0.136624 | 0.252939 | 1.8513x |
| higher-r fraction | 0.950031 | 0.973766 | +0.023735 |
| meanAbs K21 | 1.591888 | 1.721434 | 1.0814x |
| medianAbs K21 | 1.702030 | 1.926812 | 1.1321x |
| maxAbs K21 | 2.923491 | 2.787834 | 0.9536x |
| corr(abs(r),abs(K21)) | 0.919849 | 0.976614 | +0.056765 |
| P22 final | 0.340020 | 0.165911 | -0.174109 |
| P22 max | 0.387302 | 0.207806 | -0.179496 |
| P22 mean | 0.326438 | 0.180405 | -0.146033 |
| Vy RMSE (m/s) | 0.259628 | 0.139960 | -0.119668 |
| Vy final error (m/s) | -0.284806 | -0.145520 | +0.139286 |
| NIS mean | 0.00085452 | 0.00092994 | +0.00007542 |

Full online error metrics:

| Signal/case | RMSE | MAE | Bias | MaxAbsError | Final error |
|---|---:|---:|---:|---:|---:|
| A Vx | 0.00018038 | 0.00014852 | 0.00011105 | 0.00038932 | — |
| B Vx | 0.00018786 | 0.00015389 | 0.00011162 | 0.00038591 | — |
| A Vy | 0.25962780 | 0.24795739 | -0.24795739 | 0.34959782 | -0.28480616 |
| B Vy | 0.13995962 | 0.13464738 | -0.13464738 | 0.20647178 | -0.14551973 |

Vy partitions:

| Case/partition | samples | RMSE | MAE | Bias |
|---|---:|---:|---:|---:|
| A low-r | 80 | 0.250278 | 0.230616 | -0.230616 |
| A higher-r | 1521 | 0.260110 | 0.248869 | -0.248869 |
| B low-r | 42 | 0.132261 | 0.118337 | -0.118337 |
| B higher-r | 1559 | 0.140161 | 0.135087 | -0.135087 |

Online Vy RMSE improved by about 46.1%, and final absolute error improved by
about 48.9%. This performance improvement is evidence, not a runtime PASS
gate.

| NIS | G1-A | G1-B |
|---|---:|---:|
| mean | 0.00085452 | 0.00092994 |
| median | 0.00036480 | 0.00039000 |
| p95 | 0.00284838 | 0.00298899 |
| max | 0.00398990 | 0.00393354 |
| fraction <= 3.8414588 | 1.0 | 1.0 |

NIS was used only as a diagnostic; no tuning inference was made.

## H. B0 exact replay and B3 replay

B0 exactly reproduced both online cases:

| Case | maxAbsXDiff | maxAbsPDiff | maxAbsDiagDiff | gate |
|---|---:|---:|---:|---:|
| G1-A | 0 | 0 | 0 | PASS |
| G1-B | 0 | 0 | 0 | PASS |

B3 removed only `Ay +0.02 m/s^2` and `AVz +0.005 rad/s` offline. Ax remained
unchanged; the online estimator and sensor model were not modified.

| B3 metric | A-B3 | B-B3 | B-A difference |
|---|---:|---:|---:|
| Vy RMSE | 0.02867482 | 0.02897641 | +0.00030159 |
| Vy MAE | 0.02419942 | 0.02507595 | +0.00087653 |
| Vy Bias | -0.00463441 | -0.00266300 | +0.00197141 |
| Vy MaxAbs | 0.05912612 | 0.05550386 | -0.00362226 |
| Vy final error | -0.00577604 | -0.01415521 | -0.00837916 |
| P22 final | 0.34466159 | 0.16802872 | -0.17663286 |
| P22 max | 0.38375481 | 0.20612877 | -0.17762604 |
| P22 mean | 0.32681822 | 0.18049828 | -0.14631993 |

B3 makes the covariance observability benefit clearer: B still has much
lower P22 after deterministic bias removal. It does not show a Vy RMSE benefit;
B-B3 RMSE is about 0.000302 m/s higher than A-B3, and its final error magnitude
is larger. Thus higher yaw strengthened covariance constraint, while residual
de-biased error was already small and did not improve monotonically.

The large online-to-B3 RMSE reductions in both cases show that deterministic
Ay/AVz bias remains a dominant online error contributor. This does not erase
the independent yaw/K21/P22 observability evidence.

## I. Interpretation and required answers

1. **Excitation validity:** both genuine steering commands reached the CarSim
   road-wheel boundary. The 0.04 rad run produced materially higher yaw than
   0.02 rad.
2. **K21:** sustained/typical K21 coupling increased (mean and median), though
   p95 and maximum did not.
3. **P22:** yes, higher yaw substantially strengthened covariance constraint.
4. **Online Vy performance:** yes, RMSE and final absolute error improved.
5. **B3:** it clearly retains the P22 observability benefit, but does not show
   improved de-biased Vy RMSE or final error.
6. **K-KF mathematics:** no evidence from G1 requires a structural change.
7. **Q/R tuning:** no evidence or authorization supports tuning Q/R here.

K21 growth alone is not treated as solved Vy performance, and B3's nearly flat
performance is not treated as an algorithm structural failure.

## J. Frozen hash gate

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` |

All model/core/wrapper hashes match their pre-run baselines. No MATLAB process
was left running.

## K. Final decision

**V2.1-G1 HIGHER-YAW OBSERVABILITY IMPROVED**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

NO Q/R TUNING IS AUTHORIZED.

NO ONLINE BIAS CORRECTION IS AUTHORIZED.

NO FUSION IS AUTHORIZED.

V2.2 WAS NOT STARTED.
