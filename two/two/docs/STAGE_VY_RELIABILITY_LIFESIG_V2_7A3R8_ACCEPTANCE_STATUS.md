# V2.7-A3R8 LifeSig Simulink Integration Acceptance

Date: 2026-08-31 (Asia/Hong_Kong)

## Final conclusion

```text
LIFESIG_SIMULINK_INTEGRATION_COMPILE_PASS
READY FOR 0.2S LIFESIG SMOKE RUNTIME
```

## Exact root cause

Both the accepted A2R7/A2R8 reliability diagnostic target and the new LifeSig
target use the same proven steering source definition:

```text
block       = G0 Steer Cmd Rad
Amplitude   = test_steer_amplitude
Frequency   = 2*pi*test_steer_frequency
SampleTime  = 0
```

The A2R4/A2R7/A2R8 accepted compile/runtime paths assigned
`test_steer_amplitude=0.02` and `test_steer_frequency=0.4` into the model
workspace before compile/runtime. The A3R8 compile validator did not establish
those variables, and the copied LifeSig target did not contain persistent
defaults. Therefore Simulink could not resolve the Sine Wave `Amplitude`
expression and raised `Simulink:Parameters:InvParamSetting` before model update.

The block definition itself and its radian steering semantics were correct. The
failure was a missing workspace dependency in the independent target.

## Minimal remediation

Only the independent LifeSig target steering-source configuration and its
builder were changed:

- The Sine Wave expressions and `SampleTime=0` were retained unchanged.
- The target model workspace now persistently provides:
  - `test_steer_amplitude = 0.02`
  - `test_steer_frequency = 0.4`
- The builder verifies the exact expressions and deterministically establishes
  those defaults for both a newly constructed target and the existing target.
- The existing target was not rebuilt; it was saved once only to persist the
  two steering workspace defaults.

No LifeSig core/wrapper mathematics, q/tau/fallback, D/K/F estimator, Q/R,
P0_F/Q_F, source diagnostic target, or frozen baseline was modified.

## Artifacts and hashes

| Artifact | SHA-256 |
|---|---|
| `model/build_vy_lifesig_fusion_v2_7a3r8.m` | `E8E7067C1B468F1E6AD760D5A2D72B9E30776A847A890678CEE1108E2E3DFA07` |
| `model/vx_vy_lifesig_fusion_v2_7.slx` | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |
| `results/vy_reliability_lifesig_v2_7a3r8_build.mat` | `2A0A2E93170748AD58487F33FC3EEC75C7426A01B5E7BA19CC5EBE8ED2BA3B47` |
| `results/vy_reliability_lifesig_v2_7a3r8_compile.mat` | `2AB41889D435A11AAF42C724BF38DBEBDF3A97CEA3E8C9B66B64D7A2C98FD2A4` |

Unchanged integrity anchors:

| Artifact | SHA-256 |
|---|---|
| source reliability target | `2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F` |
| LifeSig core | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| LifeSig wrapper | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |

## Single authorized batch

Exactly one healthy MATLAB batch was executed from the project `model`
directory. It performed target configuration persistence, load/update/compile,
logging/port/dimension/type/sample-time audit, and termination. It did not call
`sim()` and did not perform a CarSim runtime.

```text
A3R8R2_BUILD_EVIDENCE|target=65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0|targetUnchanged=0|rebuilt=0|steeringConfigModified=1|logs=9|sim=0|carsim=0

A3R8_COMPILE|static=1|compile=1|term=1|compiled=1|dims=1|types=1|rate=1|source=1|target=1|passed=1|sim=0|carsim=0

A3R8_INTEGRATION_ACCEPTANCE_OK
batch exit code = 0
```

The compile emitted the existing `Solver_SF` shadowing warning and existing
Derivative-block warnings. They were non-fatal. The accepted D-drive CarSim
solver was resolved during compile-only initialization; termination occurred at
simulation time 0 s. No simulation runtime was performed.

Final process recheck found zero live MATLAB/CarSim runtime processes through
`Win32_Process`.
