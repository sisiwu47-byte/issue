# V2.3-B Parallel D/K Simulink Integration Status

- Date: 2026-08-27
- Sol decision: **V2.3-B PARALLEL D/K SIMULINK INTEGRATION BLOCKED**
- Builder/static integration: **PASS**
- Full-target compile-only gate: **BLOCKED by external CarSim solver path**
- `sim()` / Start command: **NOT CALLED**
- CarSim runtime: **NOT RUN**

## 1. Actual created files

| File | Role | SHA-256 |
|---|---|---|
| `model/vx_vy_parallel_dk_v2_3.slx` | new parallel D/K validation target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` |
| `model/build_vy_parallel_dk_v2_3.m` | deterministic source-copy and frozen D-EKF integration builder | `DA3F7681A1E6E74E4485A0D9FDDE5EA667A9FC886F17B071FF156711254BDE87` |
| `model/validate_vy_parallel_dk_v2_3_integration.m` | no-run static and optional full-target compile-only validator | `2376D7C395546954C39A1D18B588A21523960B096A175DB8D2E18BBCAF50B46A` |
| `results/vy_parallel_dk_v2_3b_integration_gates.mat` | builder, static-gate, compile error, and hash evidence | `69378DA11EA9205F3971F17E43930058507F1A754E6B3294C5A7161BA02D5B81` |

This status document is the only additional stage artifact. No runtime result
MAT was created.

## 2. Integration implemented in the new target

The builder copied the frozen genuine-steering K-KF source:

```text
model/vx_vy_kkf_v2_1g_steer.slx
-> model/vx_vy_parallel_dk_v2_3.slx
```

It then copied, rather than reimplemented, these blocks from the frozen
D-EKF donor:

| Frozen donor path | Parallel target path | Copy method |
|---|---|---|
| `vx_vy_dekf_v1_17/Vy D-EKF 100Hz` | `vx_vy_parallel_dk_v2_3/Parallel D-EKF 100Hz` | Simulink `add_block` copy of the exact subsystem |
| `vx_vy_dekf_v1_17/D-EKF 100Hz Scheduler` | `vx_vy_parallel_dk_v2_3/Parallel D-EKF 100Hz Scheduler` | exact block copy |
| `vx_vy_dekf_v1_17/D-EKF Input RT 100Hz` | `vx_vy_parallel_dk_v2_3/Parallel D-EKF Input RT 100Hz` | exact block copy |

The copied D boundary still calls exactly:

```matlab
vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)
```

with raw width 69 and target model-workspace mode `vy_v17_mode_code=20`.
No D-EKF equation, Jacobian, Q/R, Joseph update, state memory, covariance
memory, or measurement-update implementation was recreated.

The frozen K subsystem, scheduler, reset, wrapper, and existing logs were
retained from the copied source. The builder did not replace or rebuild K-KF.

## 3. Shared physical routing evidence

| Physical signal | D-EKF route | K-KF route | Static result |
|---|---|---|---|
| `Ax_IMU` | none | frozen K IMU mux input 1 | PASS |
| `Ay_IMU` | D measurement mux input 1 | frozen K IMU mux input 2 | PASS |
| `AVz_IMU` | D measurement mux input 2 | frozen K IMU mux input 3 | PASS |
| true Vx from `Gain38=1/3.6` | D control mux input 1 through D-owned 100-Hz RT | frozen K Vx RT/measurement | PASS |
| steering `[FL;FR;RL;RR]` rad | D control input only | no K input | PASS |
| true Vy | no online D input | no online K input | PASS |

The shared branches originate at physical sources. None originates at an
estimator state, covariance, diagnostic, innovation, or gain output.

### Genuine steering path

Static line tracing proved the same active rad command drives both the plant
conversion path and D-EKF:

```text
G0 Steer Cmd Rad
  +--> Gain22 = 180/pi
       -> Mux8 ports 2/4
       -> Manual Switch1 input 2, CurrentSetting=0
       -> CarSim front road-wheel imports [deg]
  +--> Parallel D Steering Mux ports 1/2 [rad]

Parallel D Rear Steer Zero Rad = 0
  -> Parallel D Steering Mux ports 3/4 [rad]

wheel order = [FL;FR;RL;RR]
```

`Mux8` ports 6/8 remain zero for the plant rear wheels. Exactly one top-level
`180/pi` gain exists, so D receives rad directly and the plant boundary
receives deg without a second conversion.

## 4. Scheduler, reset, state, and covariance independence

| Gate | D-EKF | K-KF | Result |
|---|---|---|---|
| Function-call scheduler | copied independent generator, 0.01 s, one iteration | retained frozen generator, 0.01 s, one iteration | PASS |
| Trigger | local D scheduler to local D function-call trigger | local K scheduler to local K function-call trigger | PASS |
| Ay semantics | A20 wrapper counter: joint `[Ay;r]` update every fifth 100-Hz hit | physical Ay remains in K process input on each K hit | PASS |
| Reset/lifecycle | wrapper-owned empty-persistent/mode-change reset | independent explicit first-hit Step | PASS |
| State | D persistent `[Vy;r]` | K persistent `[Vx;Vy]` | independent / PASS |
| Covariance | D-owned 2x2 `P` | K-owned 2x2 `PState` | independent / PASS |

No reset wire, persistent state, covariance memory, or scheduler is shared
between the two estimators.

## 5. Logs and no-coupling gates

Created D/common logs:

```text
dekf_x_log
dekf_P_log
dekf_diag_log
parallel_input_log
```

The frozen K logs remain:

```text
kkf_x_log1
kkf_P_log1
kkf_diag_log1
```

`parallel_input_log` columns are planned as:

```text
[Ax_IMU, Ay_IMU, AVz_IMU, trueVx,
 steer_FL_rad, steer_FR_rad, steer_RL_rad, steer_RR_rad, K_reset]
```

D reset remains an independent wrapper lifecycle event rather than a shared
numeric reset line.

Static validator result:

```text
static gates = 41/41 true
staticPassed = 1
simCalled = 0
carSimRun = 0
```

The 41 gates include all required hard prohibitions:

- no D state/P/diagnostic output reaches K;
- no K state/P/diagnostic output reaches D;
- no covariance exchange or covariance fusion;
- no pseudo measurement (`Vy_D`, `Vy_K`, `r_D`, or `Vx_K`);
- no weighted sum, `alpha_D`, or `alpha_K`;
- no estimator-output switch;
- no LifeSig or reliability gate;
- no DK-EKF/third online track;
- no `Vy_final`;
- both estimator outputs terminate in their own observation/logging paths.

## 6. Commands and exact results

All MATLAB invocations used the same initialized clean preference directory;
no duplicate MATLAB instance was started while another command was active.

### Builder

```powershell
$env:MATLAB_PREFDIR='D:\SystemMigration\Temp\vy_v23b_pref_011e708dbb2149ab80558694000c0b33'
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); build=build_vy_parallel_dk_v2_3(); save(fullfile(pwd,'results','vy_parallel_dk_v2_3b_integration_gates.mat'),'build'); disp('V23B_BUILDER_BATCH_OK');"
```

Result:

```text
V2_3B_BUILD_OK
V23B_BUILDER_BATCH_OK
exit code = 0
```

### Static validator

```matlab
S=load(fullfile(pwd,'results','vy_parallel_dk_v2_3b_integration_gates.mat'),'build');
report=validate_vy_parallel_dk_v2_3_integration(S.build,false);
```

Result:

```text
V2_3B_VALIDATE|static=41/41|compileCalled=0|passed=1|sim=0|carsim=0
exit code = 0
```

### Full-target compile-only gate

```matlab
S=load(fullfile(pwd,'results','vy_parallel_dk_v2_3b_integration_gates.mat'),'build');
report=validate_vy_parallel_dk_v2_3_integration(S.build,true);
```

Result:

```text
compileCalled = 1
compilePassed = 0
compiled interface gates = 0/9 (not resolved because compilation stopped at CarSim)
simCalled = 0
carSimRun = 0
exit code = 1
```

Exact first diagnostic:

```text
Simulink:SFunctions:SFcnErrorStatus
'vx_vy_parallel_dk_v2_3/CarSim S-Function' S-Function 'vs_sf':
Unable to load solver module G:\carsim\Programs\solvers\carsim_64.dll
```

The existing plant also emitted its pre-existing Derivative-block warnings
before the CarSim S-function error. No parallel D/K dimension, algebraic-loop,
or sample-time diagnostic was emitted before the external solver load stopped
the full compile. This does not constitute compiled-interface acceptance:
the required full-target compile gate remains failed/unresolved.

An estimator-only harness was not run because the static integration already
isolated D/K topology and the exact full-target blocker is external and
unambiguous. A harness PASS would not satisfy the required full-target gate.

## 7. Frozen integrity after all actions

| Frozen object | SHA-256 | Status |
|---|---|---|
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| `model/vy_dynamic_ekf_v1_17.m` | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| `model/vy_dynamic_ekf_step_v17.m` | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` | unchanged |
| `model/vy_dynamic_ekf_step_v13.m` | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` | unchanged |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged / absent from parallel target |
| `model/vx_vy_dkekf_v2_2d_nominal.slx` | `A17E7609D2248C832A80F773660941B68025E3A38CFC1F3938CBCA2BD0165E5B` | unchanged / absent from parallel target |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |

## 8. Exact blocker and stop state

The parallel architecture and all static integration/no-coupling gates pass,
but V2.3-B acceptance explicitly requires a successful full-target
compile/update. The active model's CarSim S-function still requests an
unavailable solver DLL at a frozen/external path:

```text
G:\carsim\Programs\solvers\carsim_64.dll
```

Changing the solver installation, dataset, S-function, or frozen source model
is outside V2.3-B authorization. No retry can add information until that
external path is made resolvable or a separately authorized configuration
change is made.

**V2.3-B PARALLEL D/K SIMULINK INTEGRATION BLOCKED**

PARALLEL EXECUTION ARCHITECTURE ONLY.

NO FUSION.

NO LIFESIG.

NO THIRD TRACK.

NO CARSIM RUNTIME PERFORMED.

NOT READY FOR V2.3-C UNTIL THE REQUIRED FULL-TARGET COMPILE GATE PASSES.
