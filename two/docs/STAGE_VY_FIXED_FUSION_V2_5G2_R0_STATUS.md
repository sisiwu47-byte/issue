# V2.5-G2-R0 MATLAB Startup Recurrence Health Gate Status

## Conclusion

**V2.5-G2-R0 MATLAB STARTUP RECURRENCE HEALTH GATE BLOCKED**

The uniquely authorized startup-only probe reproduced the same MATLAB startup failure before any requested MATLAB command executed:

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

## Pre-launch process gate

- PID 31276: no longer returned by `GetProcessById`; not live.
- Live MATLAB process count immediately before the probe: `0`.
- The pre-launch process gate therefore passed.

## Authorized probe outcome

- A new MATLAB `-batch` process was started once for this R0 probe.
- `MATLAB_STARTUP_OK`: not reached.
- MATLAB version output: not reached.
- Active `prefdir` output: not reached.
- Simulink license output: not reached.
- `load_system('simulink')`: not reached.
- G2 runner `checkcode`: not reached.
- G2 analyzer `checkcode`: not reached.
- Project model load: not performed.
- `sim()`: not called.
- CarSim: not run.

After the fatal startup error, PID 19452 remained reported with `HasExited=False`. It was not terminated, interrupted, or manipulated. The same startup path must not be retried without a new, root-cause-backed recovery action and explicit authorization.

## Calibration authorization state

| Run ID | `sim()` count | Runtime authorization |
|---|---:|---|
| `FWCAL_C02` | `0` | UNCONSUMED |
| `FWCAL_C03` | `0` | UNCONSUMED |
| `FWCAL_C04` | `0` | UNCONSUMED |
| `FWCAL_C05` | `0` | UNCONSUMED |

No C02-C05 runtime MAT was created. C01R1 remains the only eligible acquired formal calibration dataset. Holdout remains untouched and `alpha_D / alpha_K / alpha_F` remain `UNSELECTED`.

## Stop state

`READY TO RESUME V2.5-G2 FROM FWCAL_C02 PRE-SIM GATE` is **not** granted.

Wait for PID 19452 to exit normally before any further MATLAB startup investigation. Do not start C02.
