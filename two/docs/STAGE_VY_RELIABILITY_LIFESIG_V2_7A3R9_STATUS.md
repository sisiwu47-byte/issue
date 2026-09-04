# V2.7-A3R9 0.2-S LifeSig Integration Smoke Runtime

Date: 2026-08-31 (Asia/Hong_Kong)

## Verdict

```text
LIFESIG_INTEGRATION_SMOKE_PASS
READY FOR V2.7-A3R10 FULL 16S NOMINAL RUNTIME VALIDATION
```

This was one `NON_HOLDOUT_ENGINEERING_DIAGNOSTIC` smoke runtime. It was not a
calibration or holdout run and did not tune any parameter.

## Fixed runtime condition

```text
StopTime             = 0.20 s
speed                = 20 m/s
front steer amplitude= 0.02 rad
steer frequency      = 0.4 Hz
estimator/fusion rate= 100 Hz
runtime cwd          = D:\UsersData\桌面\two\model
CarSim solver        = D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

Exactly one `sim()` call was executed. CarSim terminated normally at simulation
time 0.2 s and the MATLAB batch exited with code 0. No retry occurred.

## Runtime and logging gates

All required LifeSig, D/K/F, F-age, common-time, reset, offline-truth, and
steering logs existed. The 100-Hz validation set contained 21 aligned samples:

```text
t = 0.00 ... 0.20 s
mean dt = 0.01 s
all aligned = 1
all finite = 1
```

LifeSig runtime result:

```text
normal samples                = 21
fallback samples              = 0
max |sum(alpha)-1|            = 2.2204460492503131e-16
minimum-alpha/nonnegative gate= PASS
H_D availability error        = 0
H_K availability error        = 0
H_F age-exponential error     = 0
```

`H_D` and `H_K` exactly matched their online availability inputs. `H_F`
exactly matched:

```text
age_valid_F * exp(-(propagation_age_steps*0.01)/28.252990189369939)
```

All 21 samples were valid normal-path samples. Therefore this runtime confirms
that fallback was not spuriously asserted (`fusion_valid=1`,
`fallback_active=0`) and that the flags agree with the frozen formula. It does
not claim a new runtime exercise of the fallback branch; that branch remains
covered by the accepted A3R7 unit tests.

## Exact offline replay

The analyzer replayed the frozen LifeSig core sequentially using only the
logged D/K/F states, D/K availability, F age/age-valid, reset, and the wrapper's
frozen last-valid state transition. `Vy_true` was retained only as an offline
diagnostic log and did not enter health, score, alpha, or replay calculations.

Maximum absolute runtime-versus-replay errors:

```text
Vy_LS            = 0
alpha_D/K/F      = 0
H_D/H_K/H_F      = 0
fusion_valid     = 0
fallback_active  = 0
overall maximum  = 0
```

## Evidence

```text
A3R9_RUNTIME|sim=1|completed=1|carsim=1|targetUnchanged=1|logs=24
A3R9_ANALYSIS|N=21|t=[0 0.20000000000000001]|dt=0.01|finite=1|aligned=1|normal=21|fallback=0|alphaErr=2.22e-16|healthErr=0|replayErr=0|passed=1
A3R9_SMOKE_ALL_OK
```

| Artifact | SHA-256 |
|---|---|
| `model/run_vy_lifesig_fusion_v2_7a3r9_smoke.m` | `40CFF2F6A33C283C1075FA010B7056E44C57D415796E541F26FABE4688247649` |
| `model/analyze_vy_lifesig_fusion_v2_7a3r9_smoke.m` | `1810D5A3C60B32D04C14DE3F004C62FAAD14EE8EF4DE89CC25FA228BBA0B3015` |
| `results/vy_reliability_lifesig_v2_7a3r9_smoke.mat` | `FA51429F9E7EFBE06CAF79F42ADF2A4D7DFB30797937C0C93C5BDBC34EE81D20` |
| `results/vy_reliability_lifesig_v2_7a3r9_smoke_evidence.csv` | `8105765F68BBD59D477F4CC640E56F5457E4C00B3AD20F459263FE93DDCCB60D` |

## Integrity and exclusions

| Artifact | SHA-256 | Status |
|---|---|---|
| LifeSig target | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` | unchanged |
| LifeSig core | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` | unchanged |
| LifeSig wrapper | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` | unchanged |

No q/tau/fallback, D/K/F estimator, Q/R, P0_F/Q_F, model, or fusion
mathematics were changed. Final process inspection found zero live MATLAB or
CarSim runtime processes.
