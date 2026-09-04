# V2.8-A2 Long-Low-Yaw Runtime Status

## Verdict

```text
LOW_YAW_RUNTIME_INSUFFICIENT
```

The first-and-only authorized V2.8-A2 `sim()` call was consumed. No second
V2.8-A2 runtime is authorized.

## Actual execution result

The healthy MATLAB batch ran from the project `model` directory and selected
the accepted D-drive solver:

```text
D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

The requested model stop time was `22 s`, but the actual CarSim console
reported:

```text
Termination at simulation time = 16 s.
```

The console contains no `22 s` termination record. Therefore the runner's
formal 22-s completion gate correctly failed:

```text
identifier = V28A2:CarSimCompletionMissing
message    = Authorized 22-s CarSim completion evidence is missing.
```

This is one partial 16-s physical runtime, not a successful 22-s validation.
The evidence does not establish why the active CarSim execution terminated
at 16 s; no dataset, model, or runtime configuration was modified to pursue
that question.

## Authorization closure

Read-back from the immutable runtime MAT gives:

```text
simCalled             = 1
simInvocationCount    = 1
authorization         = CONSUMED
simulationCompleted   = 0
formal carSimRun      = 0
target/source hashes  = unchanged
```

The formal `carSimRun` field is false because it requires the specified
22-s completion, not because the solver never executed.

## Data availability

The CarSim completion assertion occurred before the runner's log extraction
loop. Read-back from the saved MAT gives:

```text
runtime.raw field count = 0
analysis MAT             = ABSENT
analysis CSV             = ABSENT
```

Consequently this stage has no persisted samples for:

- signed yaw rate;
- `Vy_D`, `Vy_K`, or `Vy_true`;
- D/K errors;
- steering runtime fidelity.

The requested 0.005/0.01/0.02 rad/s sensitivity partitions, near-zero-yaw
duration, longest continuous low-yaw interval, and D/K error metrics cannot
be computed. It would be invalid to infer K drift from the configured input
profile or from the console termination time alone.

## Scientific conclusion

This execution supports none of the following claims:

- that a continuous `|r| < 0.01 rad/s` interval was realized;
- that K-KF retained, drifted, improved, or degraded during low yaw;
- that D outperformed K during such an interval;
- that a low-yaw structural gate is supported or rejected.

The only defensible verdict is `LOW_YAW_RUNTIME_INSUFFICIENT` because the
unique authorization is consumed and no usable time-series evidence was
persisted.

## Integrity and evidence

| Artifact | SHA-256 / status |
|---|---|
| `model/vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx` | `576019D260B8BD412F93827BE29F74FEFCBABB8FD23DF0735CA372067EABF829` unchanged |
| `results/vy_lifesig_v2_8a2_long_low_yaw_runtime.mat` | `20FCC7834F861F17C2798A644DD2F424B80D9B8D78B394D1CA3110E3948F8758` |
| `results/vy_lifesig_v2_8a2_long_low_yaw_analysis.mat` | ABSENT |
| `results/vy_lifesig_v2_8a2_long_low_yaw_summary.csv` | ABSENT |

Post-exit inspection found no live CarSim solver runtime. The user-owned
healthy MATLAB Automation GUI was not terminated or modified.

## Scope closure

```text
SIM INVOCATIONS = 1.
AUTHORIZATION = CONSUMED.
NO SECOND V2.8-A2 RUNTIME IS AUTHORIZED.
NO MODEL OR ESTIMATOR WAS MODIFIED.
NO K GATE WAS IMPLEMENTED.
NO Q/R, LIFESIG, PRIOR, OR TAU PARAMETER WAS MODIFIED.
NO LOW-YAW PERFORMANCE CLAIM IS AVAILABLE.
```
