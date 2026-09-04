# V2.3-C Parallel D/K Runtime Preflight Status

## 1. Final status

**V2.3-C PARALLEL D/K RUNTIME PREFLIGHT PASSED**

Exactly one authorized `0.20 s` `sim()` call was made. It completed using the
accepted D: CarSim solver. No builder, model save, model modification,
full-target compile-only retry, 16-s run, fusion, LifeSig, or third track was
performed.

Created evidence:

- `model/run_vy_parallel_dk_v2_3c_preflight.m`
- `model/analyze_vy_parallel_dk_v2_3c_preflight.m`
- `results/vy_parallel_dk_v2_3c_preflight.mat`
- this status document

## 2. Runtime environment gate

| Evidence | Actual | Result |
|---|---|---|
| MATLAB runtime `pwd` | `D:\UsersData\桌面\two\model` | PASS |
| active simfile | `D:\UsersData\桌面\two\model\simfile.sim` | PASS |
| `PROGDIR` | `D:\carsim\CarSim2021.0_Prog\` | PASS |
| `DATADIR` | `D:\carsim\CarSim2021.0_Data\` | PASS |
| actual solver | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` | PASS |
| G: request | `NO` | PASS |
| `simCalled` | `1` | PASS |
| `simulationCompleted` | `1` | PASS |
| `carSimRun` | `1` | PASS |
| actual stop time | `0.20000000000000001 s` | PASS |

CarSim console completion evidence:

```text
Use vehicle solver: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
Termination at simulation time = 0.2 s.
```

The existing Derivative-block warnings were emitted before runtime and did
not prevent CarSim or either estimator from completing. No second runtime was
performed.

## 3. Genuine steering trajectory

The short preflight was checked against the theoretical command at every
actual logging timestamp:

```text
delta(t) = 0.02*sin(2*pi*0.4*t) rad
```

| Metric | Actual |
|---|---:|
| sample count | 203 |
| time range | `[0, 0.20] s` |
| command min / max / maxAbs | `0 / 0.0096350734820343075 / 0.0096350734820343075 rad` |
| command final | `0.0096350734820343075 rad` |
| theoretical final | `0.0096350734820343075 rad` |
| command-vs-theory maxAbsDiff | `0` |
| converted maxAbs / final | `0.55204904581898406 / 0.55204904581898406 deg` |
| median deg/rad ratio | `57.295779513082323` |
| ratio maximum error from `180/pi` | `7.1054273576010019e-15` |
| FL vs converted maxAbsDiff | `0 deg` |
| FR vs converted maxAbsDiff | `0 deg` |
| FL vs FR maxAbsDiff | `0 deg` |
| RL maxAbs | `0 deg` |
| RR maxAbs | `0 deg` |

The active model definition was also checked before `sim()`:

```text
G0 Steer Cmd Rad: amplitude = test_steer_amplitude
                  frequency = 2*pi*test_steer_frequency
Gain22 = 180/pi
Manual Switch1: sw = 0, CurrentSetting = 0
front plant boundary = FL/FR converted command
rear plant boundary = 0
```

This is runtime trajectory evidence, not workspace metadata.

## 4. Independent D-EKF and K-KF runtime streams

| Gate | D-EKF | K-KF |
|---|---:|---:|
| state definition | `[Vy_D; r_D]` | `[Vx_K; Vy_K]` |
| state dimension | `2x1` | `2x1` |
| covariance dimension | `2x2` | `2x2` |
| samples | 21 | 21 |
| time range | `[0, 0.20] s` | `[0, 0.20] s` |
| dt min | `0.0099999999999999811 s` | `0.0099999999999999811 s` |
| dt mean | `0.01 s` | `0.01 s` |
| dt max | `0.010000000000000009 s` | `0.010000000000000009 s` |
| duplicate timestamps | 0 | 0 |
| missing hits | 0 | 0 |
| x / P / diagnostics finite | `YES / YES / YES` | `YES / YES / YES` |
| max covariance asymmetry | `0` | `0` |
| minimum covariance eigenvalue | `1.0611574183795094e-4` | `6.1803402192475183e-5` |

D and K timestamps have the same count, match exactly, and have maximum
timestamp difference `0`. Their implementation remains independent: the
runtime preflight confirmed distinct D and K function-call scheduler sources;
timestamp equality does not imply shared estimator scheduler or state.

## 5. Reset and multirate semantics

### D-EKF

- lifecycle reset count: `1`, at `t=0`;
- frozen initialization prior: `x0=[0;0]`, `P0=diag([0.1,0.1])`;
- first committed state:
  `[-0.0019459692471599475; 0.0021751089544269635]`;
- first committed covariance:
  `[0.00012872236091292726, 3.1946973797934536e-7;
    3.1946973797934536e-7, 0.00033496743822249066]`;
- true Vy initialization: `NO`;
- Ay-update count: `5`;
- Ay-update timestamps:
  `[0, 0.05, 0.10, 0.15, 0.20] s`.

### K-KF

- explicit reset count: `1`, at `t=0`;
- frozen initialization prior: `x0=[20;0]`, `P0=diag([0.1,0.1])`;
- first committed state:
  `[19.999999643665184; -0.00026483886523028937]`;
- first committed covariance:
  `[9.9900199600845891e-5, 0; 0, 0.10100000004767072]`;
- true Vy initialization: `NO`;
- Ay process-input hits: `21/21`;
- D Ay gate controls K Ay path: `NO`.

D reset affects only D state/P and K reset affects only K state/P. A common
physical first-hit time is acceptable; estimator memories remain separate.

## 6. Shared physical input wiring and hit alignment

The current target was loaded read-only before runtime and its actual source
connections were checked, rather than relying only on V2.3-A documentation:

| Physical signal | Actual estimator consumers | Semantics |
|---|---|---|
| Ax_IMU | K only | K process input at every K hit |
| Ay_IMU | D and K | D 20-Hz measurement gate; K 100-Hz process input |
| AVz_IMU | D and K | independent frozen D/K semantics |
| true Vx | D and K | D dynamics input; K Vx measurement |
| steering `[FL FR RL RR]` | D only | front genuine rad command, rear zero |
| reset | independent D lifecycle and K explicit reset | no state/P sharing |
| true Vy online | neither | prohibited / absent |

The nine-column `parallel_input_log` resolved exactly at all 21 D hits and all
21 K hits. K's four-column input log matched the corresponding shared
`[Ax,Ay,AVz,trueVx]` rows with maxAbsDiff `0`.

## 7. Exact replay and one-hit evidence

Both replays used the actual runtime inputs, identical timestamps and indices,
the frozen wrappers/cores, and no arbitrary shift.

| Exact replay gate | D-EKF | K-KF |
|---|---:|---:|
| maxAbs state difference | `0` | `0` |
| maxAbs covariance difference | `0` | `0` |
| maxAbs diagnostic difference | `0` | `0` |
| threshold | `<=1e-12` | `<=1e-12` |
| result | PASS | PASS |

```text
ONE D 100-HZ FUNCTION-CALL HIT = ONE COMMITTED D-EKF STATE ADVANCE: PASS
ONE K 100-HZ FUNCTION-CALL HIT = ONE COMMITTED K-KF STATE ADVANCE: PASS
```

## 8. Independence and prohibited-feature gates

Combined evidence:

```text
formal parallel static gates     = 41/41 PASS
estimator-only harness gates     = 38/38 PASS
compiled estimator gates         = 15/15 PASS
D exact replay                   = PASS, exact zero difference
K exact replay                   = PASS, exact zero difference
```

Confirmed absent:

- D state/P to K and K state/P to D;
- pseudo measurements, `r_D -> K`, or `Vx_K -> D`;
- covariance exchange;
- weighted sum, selector, `alpha_D`, or `alpha_K`;
- LifeSig or reliability logic;
- third estimator/feedback track;
- `Vy_final` or any fused output.

No 0.20-s performance comparison, Vy RMSE/MAE/Bias evaluation, NIS-quality
judgment, covariance convergence judgment, or D-vs-K superiority claim was
made.

## 9. Hash integrity

| Object | SHA-256 | Status |
|---|---|---|
| `model/vx_vy_parallel_dk_v2_3.slx` | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `model/vy_dynamic_ekf_v1_17.m` | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| `model/vy_dynamic_ekf_step_v17.m` | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` | unchanged |
| `model/vy_dynamic_ekf_step_v13.m` | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` | unchanged |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |

Evidence hashes after analysis:

```text
run script     73B19CF89E64B9759816507998341A914ABD3737E25ACB2F74468ADBC67F47ED
analyzer       0066FA7C9CA065AF99C7B3B7B0FCB418C330A37B2E85097DB888EC293FE8F4F8
result MAT     E2D423CF691B929FF4730434E8BB1B7BAA6E032656AB358E159B8EB61B9A9CFD
```

## 10. External compile-only limitation

The previously recorded full-target compile-only `vs_sf` / `carsim_64.dll`
access violation remains an external CarSim initialization limitation. It was
not retried in V2.3-C. The successful shared CarSim runtime and independent D/K
exact replays validate runtime execution; they do not erase or relabel that
separate compile-only limitation.

## 11. Final decision

**V2.3-C PARALLEL D/K RUNTIME PREFLIGHT PASSED**

PARALLEL D/K EXECUTION VALIDATED IN ONE SHARED CARSIM RUNTIME.

D-EKF AND K-KF REMAIN INDEPENDENT.

NO FUSION WAS PERFORMED.

NO LIFESIG WAS IMPLEMENTED.

NO THIRD TRACK WAS IMPLEMENTED.

READY FOR V2.3-D 16-S PARALLEL D/K GENUINE NOMINAL VALIDATION
