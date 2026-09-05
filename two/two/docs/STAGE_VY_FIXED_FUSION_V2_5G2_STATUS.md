# V2.5-G2 Remaining Pre-Registered Calibration Acquisition Status

## Stage conclusion

**V2.5-G2 REMAINING PRE-REGISTERED CALIBRATION ACQUISITION BLOCKED**

Blocker classification: **PRE-SIM MATLAB STARTUP / LIVE-PROCESS GATE**.

No C02-C05 simulation was started. All four per-run simulation authorizations remain unconsumed.

## Pre-registration audit

The original V2.5-F suite and run registry were read with an explicit comma delimiter. The remaining original `CALIBRATION_ONLY / PLANNED_NOT_RUN` rows are exactly four and their original CSV row order is:

| Order | Run ID | Amplitude | Frequency | Duration | Rate | Reserved runtime MAT | Status |
|---:|---|---:|---:|---:|---:|---|---|
| 1 | `FWCAL_C02` | `0.020 rad` | `0.50 Hz` | `16 s` | `100 Hz` | `results/vy_fixed_fusion_v2_5g_fwcal_c02.mat` | NOT RUN |
| 2 | `FWCAL_C03` | `0.030 rad` | `0.40 Hz` | `16 s` | `100 Hz` | `results/vy_fixed_fusion_v2_5g_fwcal_c03.mat` | NOT RUN |
| 3 | `FWCAL_C04` | `0.040 rad` | `0.30 Hz` | `16 s` | `100 Hz` | `results/vy_fixed_fusion_v2_5g_fwcal_c04.mat` | NOT RUN |
| 4 | `FWCAL_C05` | `0.040 rad` | `0.40 Hz` | `16 s` | `100 Hz` | `results/vy_fixed_fusion_v2_5g_fwcal_c05.mat` | NOT RUN |

All rows retain `SINE_FRONT_EQUAL_REAR_ZERO`, the registered approximately-20-m/s CarSim speed class, `TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`, and the registered full `[0,16]` evaluation window. All four reserved result paths were absent before the startup check.

## Prepared peripheral files

- `model/run_vy_fixed_fusion_v2_5g2_remaining_calibration.m`
  - SHA-256: `8D5B28E80D4A898F4E86D73DE7B8F58E56F149F106C5CBC78735B195ED19E67C`
  - One real `sim()` call site, parameterized by one allowed run ID.
  - Enforces original registry row order and predecessor eligibility.
- `model/analyze_vy_fixed_fusion_v2_5g2_remaining_calibration.m`
  - SHA-256: `D30117C13F7F9004AF5C4281CEA129864A82E27D38F63B6FD7DDB996CD9FD6D6`
  - Contains no `sim()` call.
  - Designed to analyze one immutable runtime MAT and emit per-run acquisition/gate CSV evidence without writing the MAT.

Static source checks found no `save_system`, QP, alpha solve, grid search, or model-write path. MATLAB `checkcode` did not execute because MATLAB failed during startup, so MATLAB-side syntax validation remains pending.

## Exact failed startup attempt

The following was a new MATLAB batch process intended only to run `checkcode` on the two newly prepared scripts. It did not load a project model and did not call `sim()`:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); f={'model/run_vy_fixed_fusion_v2_5g2_remaining_calibration.m','model/analyze_vy_fixed_fusion_v2_5g2_remaining_calibration.m'}; ..."
```

First startup diagnostic:

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

No `CHECKCODE` or project-side marker was reached.

## Live-process gate

After waiting on the same failed startup process, read-only process evidence was:

| PID | Start time | HasExited | CIM process | Classification |
|---:|---|---|---|---|
| `31276` | `2026-08-29T01:28:59.4196517+08:00` | `False` | unavailable | live-process blocker under the G2 rule |
| `27736` | `2026-08-29T01:28:59.4775998+08:00` | `True` | unavailable | stale/exited object, not counted |
| `29492` | `2026-08-27T12:23:44.9031024+08:00` | `True` | unavailable | known stale/exited object, not counted |

The G2 rule requires a live MATLAB count of zero before C02 and forbids terminating a live process. PID 31276 was not terminated, interrupted, or otherwise manipulated. No alternative MATLAB startup was attempted.

## Authorization and dataset state

| Run ID | `sim()` calls in G2 | Authorization | Runtime MAT | Eligibility |
|---|---:|---|---|---|
| `FWCAL_C01R1` | `0` | previously consumed | unchanged | ELIGIBLE |
| `FWCAL_C02` | `0` | UNCONSUMED | absent | NOT ACQUIRED |
| `FWCAL_C03` | `0` | UNCONSUMED | absent | NOT ACQUIRED |
| `FWCAL_C04` | `0` | UNCONSUMED | absent | NOT ACQUIRED |
| `FWCAL_C05` | `0` | UNCONSUMED | absent | NOT ACQUIRED |

- `FWCAL_C01` remains `FAILED_INFRASTRUCTURE / NO_USABLE_DATA` and was not rerun.
- C01R1 runtime MAT remains SHA-256 `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4`.
- No aggregate calibration acquisition manifest was created because C02-C05 were not acquired.
- Holdout remains untouched.
- `alpha_D / alpha_K / alpha_F` remain `UNSELECTED`.

## Frozen and registry integrity

Read-only hashes after the blocked startup remained exact:

| Artifact | SHA-256 | Status |
|---|---|---|
| Fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | unchanged |
| Fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | unchanged |
| Fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | unchanged |
| F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| Parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| Frozen D target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| Frozen K target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| Frozen DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| Frozen F target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | unchanged |
| `model/simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | unchanged |
| V2.5-F suite plan | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` | unchanged |
| V2.5-F original registry | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` | unchanged |

No `.slx`, frozen estimator/fusion core, simfile, CarSim dataset, preregistration registry, or immutable C01R1 MAT was modified.

## Resume condition

G2 may resume only after PID 31276 has exited normally and a fresh read-only process check reports zero MATLAB processes with `HasExited=False`. The next executable calibration run remains `FWCAL_C02`; its authorization is unconsumed. No retry or replacement ID has been created.
