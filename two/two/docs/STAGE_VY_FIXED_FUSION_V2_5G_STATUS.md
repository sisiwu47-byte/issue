# V2.5-G Fixed-Weight Calibration Data Acquisition Status

## Stage decision

**V2.5-G FIXED-WEIGHT CALIBRATION DATA ACQUISITION BLOCKED**

Acquisition stopped at the first preregistered run, `FWCAL_C01`. Its single
authorized `sim()` call was consumed, but the MATLAB process terminated with an
external CarSim access violation during `vs_sf` initialization. The run was not
retried and no later calibration or holdout condition was executed.

## Preregistration and requested order

The two CSV files were read programmatically. They contained exactly five
`CALIBRATION_ONLY` rows and three untouched `HOLDOUT_VALIDATION` rows. The
frozen acquisition order recorded by V2.5-F was:

`FWCAL_C01 -> FWCAL_C03 -> FWCAL_C04 -> FWCAL_C02 -> FWCAL_C05`

The pre-registration files remained byte-for-byte unchanged:

| File | SHA-256 after the failed run |
|---|---|
| `docs/STAGE_VY_FIXED_FUSION_V2_5F_CALIBRATION_HOLDOUT_PLAN.md` | `97E3D7C9C3F35853372702A8CC545FEB02D9C182CEC012D47BA177D19673F230` |
| `results/vy_fixed_fusion_v2_5f_suite_plan.csv` | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` |
| `results/vy_fixed_fusion_v2_5f_run_registry.csv` | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` |

Their registered statuses remain `PLANNED_NOT_RUN`; V2.5-G did not edit them.

## Runner/analyzer preparation

Created:

- `model/run_vy_fixed_fusion_v2_5g_calibration.m`
- `model/analyze_vy_fixed_fusion_v2_5g_calibration.m`

The runner enforces one registered calibration ID per call, the V2.5-F order,
no overwrite/retry, no holdout ID, exact CSV/registry parameter agreement,
frozen/preregistration hashes, the accepted D: CarSim environment, and one
literal `sim()` site. It does not assign `test_speed`. The analyzer contains no
`sim()` and is designed to consume a saved MAT only.

MATLAB `checkcode` completed before the runtime:

- runner: no syntax error; one non-blocking `ISCL` performance suggestion
- analyzer: zero findings
- marker reached: `V25G_STATIC_CHECK_OK`

No builder, `save_system`, model edit, optimizer, alpha calculation, or weight
tuning was invoked.

## FWCAL_C01 exact run card

| Field | Value |
|---|---|
| run ID / role | `FWCAL_C01` / `CALIBRATION_ONLY` |
| target | `model/vx_vy_fixed_fusion_v2_5.slx` |
| steering | `0.02 rad`, `0.30 Hz`, sine, FL/FR equal, RL/RR zero |
| duration / estimator rate | `16 s` / `100 Hz` |
| speed scope | current CarSim approximately-20-m/s class; not runner-parameterized |
| active configuration | `model/simfile.sim` |
| expected solver | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` |
| reserved result | `results/vy_fixed_fusion_v2_5g_fwcal_c01.mat` |

The pre-sim run card was printed, after which the one authorized C01 `sim()` was
called. No `V25G_RUNTIME_OK` marker was reached.

## Exact blocker

The MATLAB process exited with status `0xC0000005` (`Access violation`). The
first diagnostic was external to the estimator/fusion MATLAB code:

`carsim_64.dll: vs_read_configuration -> vs_initialize -> vs_copy_io -> vs_target_heading -> vs_get_state_q`

MATLAB identified the executing S-function as:

`vx_vy_fixed_fusion_v2_5/CarSim S-Function` (`vs_sf.mexw64`)

The failure occurred during CarSim/S-function initialization, before simulation
completion and before runtime logs could be saved or analyzed. Because this was
a fatal MEX/DLL access violation, MATLAB could not execute the runner's normal
MAT-file error-save path.

Consequently:

- `results/vy_fixed_fusion_v2_5g_fwcal_c01.mat`: not generated
- acquisition manifest: not generated (there is no completed run to register)
- analyzer: not executed
- C01 formal calibration eligibility: `NOT ELIGIBLE / NOT ACQUIRED`
- valid already-acquired V2.5-G calibration runs: `NONE`

## Stop discipline and holdout lock

| Run | `sim()` calls | Result | Stage action |
|---|---:|---|---|
| `FWCAL_C01` | 1 | external CarSim initialization crash | stopped; no retry |
| `FWCAL_C03` | 0 | not run | authorization unconsumed |
| `FWCAL_C04` | 0 | not run | authorization unconsumed |
| `FWCAL_C02` | 0 | not run | authorization unconsumed |
| `FWCAL_C05` | 0 | not run | authorization unconsumed |

All three holdout rows remain untouched:

- holdout simulations executed: `0`
- holdout MAT files generated: `0`
- holdout performance viewed: `NO`

## Frozen integrity after failure

| Artifact | SHA-256 | Status |
|---|---|---|
| fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | unchanged |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | unchanged |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | unchanged |
| parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| D-EKF target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| D-EKF wrapper | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| K-KF base target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| K-KF core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| K-KF wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| DK-EKF core | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| DK-EKF wrapper | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| DK-EKF adapter | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |
| F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| F wrapper | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | unchanged |
| F target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | unchanged |
| active `simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | unchanged |

No `.slx`, frozen algorithm, CarSim dataset, or pre-registration file changed.

## Remaining state

- D/K/F/fusion runtime integrity for V2.5-G C01: not observable because CarSim initialization crashed.
- No calibration performance was evaluated.
- No maneuver was selected or removed based on performance.
- `alpha_D`, `alpha_K`, and `alpha_F` remain `UNSELECTED`.
- V2.5-H is not authorized because V2.5-G has no acquired dataset.

