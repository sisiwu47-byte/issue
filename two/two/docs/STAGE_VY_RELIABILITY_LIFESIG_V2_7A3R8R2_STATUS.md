# V2.7-A3R8R2 Builder Evidence-Lifecycle Remediation Status

Date: 2026-08-31 (Asia/Hong_Kong)

## Stage conclusion

```text
V2.7-A3R8R2 BUILDER EVIDENCE-LIFECYCLE REMEDIATION PASSED
V2.7-A3R8 LIFESIG SIMULINK INTEGRATION COMPILE BLOCKED
```

The R1 integration target was verified before execution and was not rebuilt or
saved in this stage. Its SHA-256 remained exactly:

```text
model/vx_vy_lifesig_fusion_v2_7.slx
4C134667E94E4D56D53BC2B96D92D5693E74DE36A8CD68561B80811EFC5D6A79
```

The builder now has an evidence-only recovery path for that exact target. All
handle-derived port identities and target metadata are materialized while the
model is loaded. After `close_system`, evidence packing uses only ordinary
MATLAB values. The recovery path does not call `copyfile` or `save_system` and
records `targetRebuilt=false` and `targetUnchanged=true`.

## Modified file

| File | SHA-256 |
|---|---|
| `model/build_vy_lifesig_fusion_v2_7a3r8.m` | `ADEC2D8B36F88DD9A114808A04A25BB21107FA6B8561211A770E26859DDC2887` |

No LifeSig core, wrapper, D/K/F estimator, parameter, fusion baseline, or SLX
file was modified.

## Build evidence recovery

The single healthy MATLAB batch reported:

```text
A3R8R2_BUILD_EVIDENCE|target=4C134667E94E4D56D53BC2B96D92D5693E74DE36A8CD68561B80811EFC5D6A79|targetUnchanged=1|rebuilt=0|logs=9|sim=0|carsim=0
```

Generated evidence:

| File | Size (bytes) | SHA-256 |
|---|---:|---|
| `results/vy_reliability_lifesig_v2_7a3r8_build.mat` | 1296 | `9F25F0D9CBD065F682E250B68DFC535018C8C071361680E66C6355D3DFA56869` |

This closes the R1 `Invalid Simulink object` evidence-lifecycle defect.

## Authorized compile-level run

Exactly one healthy MATLAB batch was started from the project `model`
directory. It performed builder evidence recovery and then the existing
load/static/update/compile-level validator. It did not call `sim()` and did not
run CarSim runtime.

Validator result:

```text
A3R8_COMPILE|static=1|compile=0|term=0|compiled=0|dims=0|types=0|rate=0|source=1|target=1|passed=0|sim=0|carsim=0
```

New exact blocker:

```text
identifier: Simulink:Parameters:InvParamSetting
block: vx_vy_lifesig_fusion_v2_7/G0 Steer Cmd Rad
parameter: Amplitude
diagnostic: the Amplitude parameter is invalid
```

The batch exited with code `1`. Per the stage stop rule, no second compile and
no automatic target/configuration remediation were attempted.

Generated failure evidence:

| File | Size (bytes) | SHA-256 |
|---|---:|---|
| `results/vy_reliability_lifesig_v2_7a3r8_compile.mat` | 1248 | `FE711CCF7D687483E9E367F3CA543513FC478CBEAAD42504F0B1F221A38E0DCC` |

## Integrity

| Artifact | SHA-256 | Status |
|---|---|---|
| source reliability target | `2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F` | unchanged |
| LifeSig integration target | `4C134667E94E4D56D53BC2B96D92D5693E74DE36A8CD68561B80811EFC5D6A79` | unchanged, not rebuilt |
| LifeSig core | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` | unchanged |
| LifeSig wrapper | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` | unchanged |

The MATLAB launcher returned exit code `1`. Final process enumeration was
inconclusive at the API level: `Get-Process` retained a PID 32132 entry with no
readable handle/CPU/HasExited data, while `Win32_Process` reported PID 32132
absent. No termination was attempted and no second MATLAB instance was
started.

## Stop state

```text
NO SIMULATION WAS RUN.
NO CARSIM RUNTIME WAS RUN.
NO SECOND COMPILE WAS RUN.
THE BUILDER EVIDENCE-LIFECYCLE DEFECT IS REMEDIATED.
LIFESIG SIMULINK INTEGRATION REMAINS BLOCKED BY THE NEW AMPLITUDE PARAMETER ERROR.
```
