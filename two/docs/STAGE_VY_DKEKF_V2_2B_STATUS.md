# STAGE VY DK-EKF V2.2-B STATUS

## 1. Stage conclusion

**V2.2-B UNIFIED DK-EKF MATHEMATICAL CORE ACCEPTED**

This stage created and unit-tested a pure-MATLAB, genuinely unified
dynamic-kinematic EKF baseline. It did not integrate Simulink, run a
simulation or CarSim, tune Q/R, implement bias correction, or add any
fusion, LifeSig, observability gate, or adaptive covariance logic.

## 2. Frozen-source extraction

The implemented equations were extracted from the actual frozen sources
`vy_dynamic_ekf_v1_17.m`, `vy_dynamic_ekf_step_v17.m`,
`vy_dynamic_ekf_step_v13.m`, `vy_kinematic_kf_step.m`, and
`vy_kinematic_kf.m`. No literature substitute was used.

### 2.1 Frozen D-EKF V1.17

| Item | Actual frozen definition |
|---|---|
| State | `[Vy; r]` |
| Online control vector | `[Vx; delta_FL; delta_FR; delta_RL; delta_RR]` |
| Steering unit | rad at the D-EKF mathematical interface |
| Vy prediction | `Vy_dot = (Fy_FL*cos(delta_FL)+Fy_FR*cos(delta_FR)+Fy_RL+Fy_RR)/m - Vx*r` |
| r prediction | `r_dot = (a*(Fy_FL*cos(delta_FL)+Fy_FR*cos(delta_FR))-b*(Fy_RL+Fy_RR))/Iz` |
| Ay prediction | `h_Ay = (Fy_FL*cos(delta_FL)+Fy_FR*cos(delta_FR)+Fy_RL+Fy_RR)/m` |
| r measurement prediction | `h_r=r` |
| Discretization | forward Euler, `x_pred=x+0.01*f` |
| Prediction Jacobian | centered numerical Jacobian of the complete Euler transition |
| Measurement Jacobian | centered numerical Jacobian of `[h_Ay;h_r]` |
| Low-speed treatment | no Vx clamp or division replacement; wheel denominators use `atan2(numerator,Vx +/- r*track/2)`; non-finite inputs/outputs are sanitized by the frozen core |
| P0/reset | `[0;0]`, `0.1*I2`; persistent reset on empty storage or mode change |
| Q_D | `diag([1e-4,1e-4])`, added as discrete step covariance |
| R_Ay | `1e-2` |
| R_r | `3.365172961808e-4` |
| Update order | prediction, then simultaneous `[Ay;r]` update on Ay steps; prediction then scalar r update otherwise |
| Final schedule | prediction/r at 100 Hz; selected Ay assimilation A20, every fifth 100 Hz call |

The four slip angles are the frozen expressions

```text
alpha_FL = delta_FL - atan2(Vy+a*r, Vx-r*track/2)
alpha_FR = delta_FR - atan2(Vy+a*r, Vx+r*track/2)
alpha_RL = delta_RL - atan2(Vy-b*r, Vx-r*track/2)
alpha_RR = delta_RR - atan2(Vy-b*r, Vx+r*track/2)
```

`tireForceLocal` produces raw wheel forces. The frozen axle correction is
`Fy=[k_f,k_f,k_r,k_r].*Fy_raw`, with `k_f=0.78181` and `k_r=1.09186`.
Vehicle parameters are `m=1860 kg`, `Iz=2687.1 kg m^2`, `a=1.18 m`,
`b=1.77 m`, `track=1.575 m`, and `Rw=0.393 m` (`Rw` is not used by these
lateral equations). If explicit wheel normal loads are absent, the same
static axle-load calculation as the frozen core is used.

### 2.2 Frozen K-KF V2.1 mappings

| Item | Frozen value mapped into DK-EKF |
|---|---|
| Vx process equation | `Vx_dot=Ax+r*Vy` |
| Vx discrete process variance | `Q_K(1,1)=1e-4` |
| Vx measurement variance | `R_Vx=1e-4` |
| Vx initial covariance | `P0_K(1,1)=0.1` |
| Vx reset state | current Vx measurement |
| Lateral truth at reset | not used; frozen stage-1 prior is zero |

The frozen K-KF also has `Q_K(2,2)=1e-3`, but that is its kinematic Vy
process component. It is not mapped into the unified baseline because the
unified Vy process is the frozen D-EKF process, whose variance is `1e-4`.

Neither frozen P0 contains an off-diagonal term, so no frozen
cross-covariance was silently discarded.

## 3. Unified mathematical baseline

### 3.1 Shared state and prediction

```text
x = [Vx; Vy; r]
P is one shared 3x3 covariance

Vx_dot = Ax_IMU + r*Vy
Vy_dot = (Fy_FL*cos(delta_FL)+Fy_FR*cos(delta_FR)+Fy_RL+Fy_RR)/m - Vx*r
r_dot  = (a*(Fy_FL*cos(delta_FL)+Fy_FR*cos(delta_FR))
          -b*(Fy_RL+Fy_RR))/Iz

x_pred = x + Ts*f(x,Ax_IMU,delta),  Ts=0.01 s
F = I3 + Ts*A_DK
A_DK = partial(f)/partial([Vx,Vy,r])
```

The first continuous Jacobian row is exactly `[0,r,Vy]`. The two nonlinear
lateral rows are centered finite differences of the complete frozen
tire-force equations with respect to all three shared states. Consequently
`partial(Vy_dot)/partial(Vx)` and `partial(r_dot)/partial(Vx)` are evaluated,
not padded with zero. The relative differentiation step is `1e-6`.

The former exogenous D-EKF Vx is replaced exclusively by `x(1)` in slip
angles, tire forces, lateral prediction, and Ay prediction. AVz_IMU and
Ay_IMU are not process inputs.

### 3.2 Measurements and fixed update order

| Order | Measurement | Equation | Rate | Variance |
|---:|---|---|---:|---:|
| 1 | Vx isolation measurement | `h_Vx=x(1)`, `H_Vx=[1 0 0]` | 100 Hz | `1e-4` |
| 2 | AVz_IMU | `h_r=x(3)`, `H_r=[0 0 1]` | 100 Hz | `3.365172961808e-4` |
| 3 | Ay_IMU | exact frozen `h_Ay`; full numerical `1x3 H_Ay` | 20 Hz | `1e-2` |

Every applied scalar update uses `K=(P*H')/S` with scalar division and the
Joseph covariance form. `inv()` is not used. `doAyUpdate=false` leaves the
post-r state and covariance bit-for-bit unchanged by the Ay stage. Only
`P=0.5*(P+P')` numerical symmetry cleanup is used; there is no eigenvalue
clipping.

### 3.3 Q, P0, and reset

```text
Q_DK  = diag([1e-4,1e-4,1e-4])
P0_DK = diag([0.1,0.1,0.1])
x0_DK = [z_Vx;0;0]
```

Q is the direct no-tuning mapping of frozen K-KF Vx noise and frozen D-EKF
Vy/r noise. On empty persistent storage or explicit reset, the wrapper uses
the current Vx measurement, zero Vy, and zero r, then processes the current
sample through the normal prediction/update sequence. True Vy is neither an
input nor an initializer.

## 4. Unit-test evidence

Pure MATLAB command (clean per-process preference directory was used because
the default preference path reproduced the known settings-plugin startup
failure):

```powershell
$env:MATLAB_PREFDIR=<new-system-temp-directory>
D:\matlab\bin\matlab.exe -batch "addpath(fullfile(pwd,'model')); addpath(fullfile(pwd,'tests')); report=run_vy_dkekf_v2_2b_unit_tests(); exit(0)"
```

Result: exit code 0. MATLAB emitted the non-blocking warning
`Unable to load ApplicationService for command client-v1`, then ran all
tests and exited normally with no orphan process.

| Evidence | Result |
|---|---:|
| Core tests | 25/25 |
| Wrapper tests | 7/7 |
| Total | 32/32 |
| Frozen D-EKF lateral prediction max error | 0 |
| Frozen D-EKF Ay prediction max error | 0 |
| Prediction Jacobian maximum absolute error | `3.7792546692116957e-7` |
| Ay Jacobian maximum absolute error | `2.473576863337712e-7` |
| Jacobian tolerance | `5e-4` |
| 500-step minimum covariance eigenvalue | `6.1801106049347025e-5` |
| 500-step maximum covariance asymmetry | 0 |
| Joseph reconstruction maximum error | 0 (within test gate `1e-14`) |
| simulation called | 0 |
| CarSim run | 0 |

The independent finite-difference checks used a `2e-5` relative step,
distinct from the core's `1e-6` step. The `5e-4` absolute tolerance allows
for differencing-step truncation/roundoff across the nonlinear tire model;
the observed errors are more than three orders of magnitude smaller. Cases
cover nominal and low-but-legal Vx, signed Vy/r, signed steering, and the
genuine-steering range near `+/-0.04 rad`. No singular Vx point was used.

The deterministic 500-step sequence applies Ay every fifth 100 Hz call and
checks finite state/covariance/Jacobians, symmetry, and covariance PSD at
every step. Poor estimation performance was not evaluated or used for
tuning.

Machine evidence: `results/vy_dkekf_v2_2b_unit_tests.mat`.

## 5. Fairness gates

| Gate | Result |
|---|---|
| TRUE VY ONLINE INPUT | NO — PASS |
| TRUE Vx measurement only | YES — PASS |
| TRUE Vx direct lateral-model input | NO — PASS |
| AVz_IMU measurement only | YES — PASS |
| Ay_IMU measurement only | YES — PASS |
| Ax_IMU prediction input | YES — PASS |
| One shared state | YES — PASS |
| One shared 3x3 covariance | YES — PASS |
| Output fusion | NO — PASS |
| LifeSig | NO — PASS |
| Adaptive fusion | NO — PASS |

This is a single joint EKF: prediction and all three measurement updates act
on the same state and covariance. It is not D/K output averaging, weighted
fusion, or a pseudo multi-track construction.

## 6. Files and integrity

Created files and SHA-256 after the passing run:

| File | SHA-256 |
|---|---|
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` |
| `tests/test_vy_dkekf_baseline_step.m` | `67EEDB1959BF5BE4D9668B02C698C6FF3F4BF5CE3DD5A881728F4AF34AA24D50` |
| `tests/test_vy_dkekf_baseline_wrapper.m` | `845BB2DB52DB64D07FC318FD407E69A4A42458907BBA0C9384190566AFAB101F` |
| `tests/run_vy_dkekf_v2_2b_unit_tests.m` | `1163EAC6F6D9D45D6B0CF37D2455C0EAE84C573E5B953345AD53D59D05DF950C` |
| `results/vy_dkekf_v2_2b_unit_tests.mat` | `4830F68813679C0E7483D68A66C94304E81D70788700BA9AD862326BF0015616` |

Frozen integrity is rechecked after this document is written. Required
baseline hashes are:

| Frozen file | Required SHA-256 |
|---|---|
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` |

D-EKF V1 IS FROZEN.

K-KF V2.1 IS FROZEN.

NO Q/R TUNING.

NO ONLINE BIAS CORRECTION.

NO FUSION.

NO LIFESIG.

NO V2.2-C UNTIL V2.2-B PASSES.

## 7. Stop state

**V2.2-B UNIFIED DK-EKF MATHEMATICAL CORE ACCEPTED**

**READY FOR V2.2-C DK-EKF SIMULINK INTEGRATION**
