# V2.8-A2 Dedicated Long-Low-Yaw Observability Validation Prep

## Verdict

```text
LONG_LOW_YAW_VALIDATION_TARGET_READY
```

This stage created and compile-checked an independent, non-holdout
engineering validation target. No `sim()` call or CarSim runtime was
performed.

## Independent target and frozen-source integrity

| Role | File | SHA-256 |
|---|---|---|
| Frozen accepted V2.7 source | `model/vx_vy_lifesig_fusion_v2_7.slx` | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |
| Independent V2.8-A2 target | `model/vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx` | `576019D260B8BD412F93827BE29F74FEFCBABB8FD23DF0735CA372067EABF829` |
| Builder | `model/build_vy_lifesig_fusion_v2_8a2_long_low_yaw.m` | `098BC3ADF6E935A4A6900C97CC9CD355E386DBA7F74189D31B7550BC9A3604A3` |
| Compile validator | `model/validate_vy_lifesig_fusion_v2_8a2_long_low_yaw.m` | `2E5A456589FB389821D1BA7F8DFE7F19AD6FBEE099BE74BDFB31D51EE0371C5F` |

The V2.7 source hash was identical before and after the build and compile
gate. No accepted D/K/F estimator, LifeSig core/wrapper, Q/R, prior, tau,
or baseline model was modified.

## Deterministic steering profile

The independent target contains a model-workspace matrix named
`long_low_yaw_steer_profile` with this frozen engineering definition:

```text
sample time                 = 0.01 s
sample count                = 2201
time range                  = 0.00 ... 22.00 s
initial exact-zero steer    = 0.00 ... 2.00 s
active steer interval       = 2.00 ... 4.50 s
continuous definition       = 0.02*sin(2*pi*0.4*(t-2.0)) rad
number of sine periods      = 1
steer at/after 4.50 s       = exactly 0 rad
post-excitation straight    = 17.50 s
```

Because the continuous sine peak occurs at 0.625 s after excitation start,
which is not a 0.01-s sample instant, the discrete sequence approaches but
does not numerically equal the theoretical `0.02 rad` peak. The builder
checks the sampled sequence against the theoretical amplitude without
requiring an off-grid peak sample.

The From Workspace source is configured as:

```text
VariableName          = long_low_yaw_steer_profile
SampleTime            = 0.01
Interpolate           = off
OutputAfterFinalValue = Holding final value
```

Its final value is zero, so the source cannot resume or extrapolate a
nonzero steering command after the one-cycle excitation.

## Steering topology

The inherited, previously validated physical path remains:

```text
long_low_yaw_steer_profile [rad]
-> G0 Steer Cmd Rad (From Workspace)
-> Gain22 = 180/pi
-> Mux8 ports 2/4
-> Manual Switch1 input 2, CurrentSetting = 0
-> Mux7
-> CarSim IMP_STEER_L1/R1 [deg]
```

Rear steering remains:

```text
Mux8 ports 6/8 <- Constant 0
-> CarSim IMP_STEER_L2/R2 = 0
```

Only the existing `Gain22` performs rad-to-deg conversion. No K low-yaw
gate and no `0.01 rad/s` threshold was added.

## Logged contract

| Required quantity | Runtime log | Source semantics |
|---|---|---|
| Common time | `rel_common_time_100hz_log` | Existing synchronized 100-Hz clock |
| Steering command | `steer_cmd_rad` | Command before `Gain22`, rad |
| Signed yaw rate | `long_low_yaw_r_log` | Same AVz source as `K-KF Input Log Mux` input 3 |
| Offline truth | `rel_vy_true_100hz_log` | Validation-only `Vy_true` |
| D estimate | `fusion_vy_d_log` | Existing `Vy_D` |
| K estimate | `fusion_vy_k_log` | Existing `Vy_K` |
| D error | `long_low_yaw_d_error_log` | Diagnostic-only `Vy_D - Vy_true` |
| K error | `long_low_yaw_k_error_log` | Diagnostic-only `Vy_K - Vy_true` |

Both error blocks drive only To Workspace sinks. Their outputs have no path
to D, K, F, LifeSig, vehicle inputs, or control inputs.

## Compile-only acceptance

The one compile-level validation used the healthy MATLAB installation and
project `model` working directory. It produced:

```text
static gate                  = PASS
compile                      = PASS
termination                 = PASS at t=0
compiled evidence captured  = PASS
steering source             = scalar double, 100 Hz
D/K error logs              = 100 Hz
signed yaw log              = 100 Hz
source hash unchanged       = PASS
target hash unchanged       = PASS
sim() calls                 = 0
CarSim runtime              = 0
```

Compile-only initialization resolved the expected D-lineage solver:

```text
D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

It terminated at simulation time `0 s`; this was interface compilation, not
a vehicle runtime. Existing inherited Derivative-block warnings were emitted
but did not block compile or change the target.

The exact-zero post-excitation steering window is statically proven. Whether
the physical yaw response actually crosses and continuously remains below a
future candidate partition such as `|r| < 0.01 rad/s` is intentionally not
claimed here; that requires the separately authorized long runtime.

## Evidence

| File | SHA-256 |
|---|---|
| `results/vy_lifesig_v2_8a2_long_low_yaw_build.mat` | `C988F61EDDB1819C55C6E7F3FFB199C36455997D684D74EF8EDFDA0F554DD6A3` |
| `results/vy_lifesig_v2_8a2_long_low_yaw_compile.mat` | `0BB76C21BD8FFE1877446B5562DE1C8EBFAC22B345220C35BAA945F3344BC27F` |

## Scope closure

```text
NO SIMULATION WAS PERFORMED.
NO CARSIM RUNTIME WAS PERFORMED.
NO K GATE WAS IMPLEMENTED.
NO 0.01-RAD/S THRESHOLD WAS FROZEN.
NO D/K/F ESTIMATOR WAS MODIFIED.
NO LIFESIG CORE OR WRAPPER WAS MODIFIED.
NO Q/R, PRIOR, TAU, OR F PARAMETER WAS MODIFIED.
THE FROZEN V2.7 TARGET REMAINS UNCHANGED.
```

READY FOR ONE LONG-LOW-YAW CARSIM RUNTIME
