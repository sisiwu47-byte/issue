# V2.7-A2R3 RELIABILITY DIAGNOSTIC CAPTURE TARGET INTEGRATION

## 1. Scope and target

An independent diagnostic target was created from the existing frozen V2.5
three-track target:

```text
model/vx_vy_fixed_fusion_v2_5.slx
-> model/vx_vy_reliability_diagnostic_v2_7.slx
```

The source target remains byte/hash unchanged. The new target is explicitly
marked:

```text
NON_HOLDOUT_ENGINEERING_DIAGNOSTIC
```

It is not H01/H02/H03 and must not overwrite formal holdout evidence. No
simulation, CarSim runtime, new calibration acquisition, LifeSig algorithm,
Q/R change, scheduler change, fusion change, or P0_F/Q_F change occurred.

## 2. Exact logging contract

All target logs use `Timeseries`, so each signal retains its own time vector.
The three estimator schedulers remain independent 100-Hz function-call
generators with configured sample time 0.01 s. An explicit 100-Hz truth copy
and common digital-clock log provide the shared offline sample identity.

### D-track

| Required signal | Actual log and extraction |
|---|---|
| `Vy_D` | `fusion_vy_d_log`, scalar selected from D state element 1 |
| `P_D11` | `dekf_P_log`, matrix element `(1,1)` |
| `NIS_D` | `dekf_diag_log`, element 1 |
| `measurementDimension_D` | `dekf_diag_log`, element 59 |
| `update_valid_D` | `rel_d_valid_log`, element 1 |
| `nis_valid_D` | `rel_d_valid_log`, element 2 |
| `useAy_D` | `dekf_diag_log`, element 56 |

The copied target's D boundary calls
`vy_dynamic_ekf_v1_17_reliability_numeric`, which preserves the historical
69 values and appends only the two validity bits. Its configured width is 71
and its top-level partition is `[2 2 65 2]`.

### K-track

| Required signal | Actual log and extraction |
|---|---|
| `Vy_K` | `fusion_vy_k_log`, scalar selected from K state element 2 |
| `P_K22` | `kkf_P_log1`, matrix element `(2,2)` |
| `NIS_K` | `kkf_diag_log1`, element 1 |
| `obs_metric_K=abs(r)` | `kkf_diag_log1`, element 2 |
| `update_valid_K` | `kkf_diag_log1`, element 6 |
| `nis_valid_K` | `kkf_diag_log1`, element 7 |

Only the copied target's embedded K MATLAB Function diagnostic vector is
extended from 5 to 7 elements. State and covariance outputs are unchanged.
`S_K` is not exposed because it is not necessary for the frozen A2R1 capture
contract.

### F-track

| Required signal | Actual log and extraction |
|---|---|
| `Vy_F` | `fusion_vy_f_log`, scalar |
| `P_F` | `fusion_f_P_log`, scalar |
| `propagation_age_steps` | `rel_f_reliability_log`, element 1 |
| `age_valid` | `rel_f_reliability_log`, element 2 |
| `reset_valid` | `rel_f_reliability_log`, element 3 |

The A2R2 S-function's fourth output is connected to a new subsystem outport
and then to `rel_f_reliability_log`; it is no longer unconnected.

### Offline truth and identity

```text
rel_vy_true_100hz_log      scalar Vy_true after an explicit 0.01-s Rate Transition
rel_common_time_100hz_log  scalar Digital Clock with sample time 0.01 s
```

`Vy_true` remains offline validation-only and is not connected to any
estimator or fusion input.

## 3. Static interface and integrity audit

The target SLX package expanded successfully. All 45 XML files parsed, with
zero malformed XML files. Relative to the source archive, exactly five files
changed:

```text
metadata/coreProperties.xml
simulink/stateflow/chart_100.xml
simulink/systems/system_477.xml
simulink/systems/system_500.xml
simulink/systems/system_root.xml
```

No archive entry was added or removed. Static interface gates passed 28/28,
including D width/partition, K diagnostic ordering, the real F port-4 route,
all required logs, D/K/F 0.01-s schedulers, 100-Hz truth/time identity, frozen
fusion expression, unchanged current F parameters, and absence of LifeSig or
`Vy_final`.

Configured semantic shapes are:

```text
D x 2x1, D P 2x2, D historical diag 65x1, D valid 2x1
K x 2x1, K P 2x2, K diagnostic 7x1
F Vy scalar, F P scalar, F reliability diagnostic 3x1
Vy_true scalar, common time scalar
```

## 4. Hashes

| File | SHA-256 |
|---|---|
| `model/vx_vy_fixed_fusion_v2_5.slx` | `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` |
| `model/vx_vy_reliability_diagnostic_v2_7.slx` | `636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499` |
| `model/vy_dynamic_ekf_v1_17_reliability_numeric.m` | `C1D336FE4D281687C039A903C023D0CF5709EA1A43CED799DE8A84124FE7DCC3` |

A2R2 D/K/F source hashes remain exactly those recorded by A2R2. The F core
remains `80C21D2...D0E5FF`; fixed-fusion core and wrapper are unchanged.

## 5. Execution limitation and readiness

Two MATLAB startup-only attempts were made before choosing the no-runtime
archive audit path. The default-preference attempt failed before project/model
load with `failed to load settings errors_warnings plugin`; a new temporary
preference attempt failed before model load with `Unable to load
ApplicationService for command client-v1`. No third MATLAB start was made and
no compile/update or simulation was attempted. Processes created by the failed
startup attempts exited or were cleaned up; the pre-existing CarSim application
process was not touched.

Therefore the target-side integration is complete and all requested static
gates pass. A MATLAB model-load/update check is deliberately deferred to the
authorized engineering smoke stage, where it can precede the single non-holdout
runtime. The existing F parameters remain `P0_F=0.5`, `Q_F=0.0025`; the
separate frozen `P0_F=0` core-contract blocker was not handled here.

**READY FOR V2.7 RELIABILITY DIAGNOSTIC SMOKE RUNTIME**
