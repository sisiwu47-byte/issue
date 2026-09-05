# V2.5-G1B Controlled CarSim Runtime Recovery Diagnostic Status

## Stage decision

**V2.5-G1B CONTROLLED CARSIM RUNTIME RECOVERY DIAGNOSTIC FAILED**

The controlled process failed at MATLAB startup, before any project function,
model load, CarSim load, pre-sim marker, or `sim()` call. The known-good runtime
could therefore not be exercised.

Exact startup failure:

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

The process was terminated after this explicit fatal startup diagnostic. No
alternative preference policy, second MATLAB start, or runtime retry was used.

## Prepared control configuration

The independent diagnostic runner was prepared directly from the successful
V2.5-D reference, not from the calibration runner or registry:

| Item | Prepared value |
|---|---|
| role | `RUNTIME_RECOVERY_DIAGNOSTIC` |
| calibration eligibility | `FALSE` |
| holdout eligibility | `FALSE` |
| target | `model/vx_vy_fixed_fusion_v2_5.slx` |
| target SHA-256 | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` |
| StopTime | `0.20 s` |
| steering amplitude | `0.02 rad` |
| steering frequency | `0.40 Hz` |
| waveform/routing | sine; FL/FR same phase; RL/RR zero |
| speed scope | existing verified approximately-20-m/s class |
| model cwd gate | `D:\UsersData\桌面\two\model` |
| simfile gate | `D:\UsersData\桌面\two\model\simfile.sim` |
| solver gate | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` |
| MEX gate | `D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64` |
| cache/codegen | reuse the exact V2.5-D cache/codegen directory policy; no deletion |

The runner has one literal `sim()` call, preceded immediately by hard assertions
and a `V25G1B_PRE_SIM` console marker. The analyzer contains no `sim()`.

## MATLAB invocation and preference policy

The attempted command used the same executable and batch command structure as
the accepted V2.5-D reference:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); run_vy_fixed_fusion_v2_5g1b_recovery_diagnostic; analyze_vy_fixed_fusion_v2_5g1b_recovery_diagnostic; disp('V25G1B_ALL_OK');"
```

V2.5-D did not record an explicit `MATLAB_PREFDIR`. The parent environment for
G1B was inspected immediately before launch:

```text
MATLAB_PREFDIR = <UNSET>
policy         = inherited/default; no explicit override
```

The failed C01 isolated preference directory was not reused, and no third
preference policy was created.

## Startup stop condition and authorization accounting

The fatal settings-plugin error occurred before the MATLAB command body ran.
The following markers were not reached:

- `V25G1B_PRE_SIM`
- `V25G1B_RUNTIME_OK`
- `V25G1B_ANALYSIS`
- `V25G1B_ALL_OK`

Therefore:

```text
runner entered                  = NO
model loaded                    = NO
CarSim DLL/MEX loaded by G1B    = NO
simCalled                       = NO
diagnostic runtime consumed     = NO
simulation completed            = NO
CarSim initialized              = NO
0xC0000005 repeated             = NO
runtime logs generated          = NO
analyzer executed               = NO
```

This is not evidence that the known-good CarSim control runtime now passes or
that it repeats the C01 DLL crash. It is evidence that the current default-policy
MATLAB execution environment is not healthy enough to reach the controlled
runtime boundary.

No diagnostic MAT was generated because no runtime result exists.

## Created project files

- `model/run_vy_fixed_fusion_v2_5g1b_recovery_diagnostic.m`
- `model/analyze_vy_fixed_fusion_v2_5g1b_recovery_diagnostic.m`
- `docs/STAGE_VY_FIXED_FUSION_V2_5G1B_STATUS.md`

Not generated:

- `results/vy_fixed_fusion_v2_5g1b_recovery_diagnostic.mat`
- environment snapshot CSV
- calibration MAT
- holdout MAT
- alpha/optimization result

## Cache evidence

No cache was deleted or cleared. Before launch:

- successful V2.5-D cache existed with 32 files
- successful V2.5-D codegen directory existed with zero files
- failed C01 cache existed separately with 32 files
- failed C01 codegen directory existed separately with zero files

The runner was prepared to reuse the V2.5-D cache/codegen paths exactly, but it
never entered MATLAB and therefore did not change the active configuration.

## Frozen and preregistration integrity

Post-failure hashes remained unchanged:

| Artifact | SHA-256 |
|---|---|
| fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` |
| F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` |
| parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` |
| D-EKF target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| K-KF target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` |
| F target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` |
| V2.5-F plan | `97E3D7C9C3F35853372702A8CC545FEB02D9C182CEC012D47BA177D19673F230` |
| V2.5-F suite CSV | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` |
| V2.5-F registry CSV | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` |
| C01 failure status | `371A6961A63742B75A34A1DD6F9715D610BA3C5DA422B86F1AD125D0ED9062F9` |
| G1 forensic status | `D50F5F438AAA213EAF197A105AF3C5A76132C72E09B133A0F487972E09ABA91A` |

No SLX, estimator, fusion core/wrapper, CarSim dataset, simfile, cache, or
pre-registration artifact was modified.

## Required answers

1. Exact V2.5-D control condition used? **Prepared exactly, but not executed because MATLAB did not start.**
2. MATLAB invocation matched the successful reference? **YES: same executable, `-batch`, root `cd`, model `addpath`, and single-function structure.**
3. MATLAB_PREFDIR policy? **UNSET / inherited default, matching the recorded V2.5-D policy.**
4. Pre-sim cwd exact model directory? **NOT REACHED / NOT OBSERVABLE.**
5. Active simfile was model/simfile.sim? **Prepared and hard-gated, but runtime boundary was not reached.**
6. D: solver/MEX actually loaded? **NO; MATLAB failed before project code.**
7. G request NO? **Static prepared configuration is NO; no runtime load occurred.**
8. Unique diagnostic runtime completed? **NO.**
9. Did `0xC0000005` occur again? **NO; failure was the settings-plugin fatal startup error.**
10. D/K/F/fusion runtime complete? **NO runtime was produced.**
11. Diagnostic data role excluded from calibration? **YES; role is explicitly `RUNTIME_RECOVERY_DIAGNOSTIC`, but no data exists.**
12. C01 still FAILED_INFRASTRUCTURE? **YES.**
13. C02-C05 still unrun? **YES.**
14. Holdout untouched? **YES: zero runs, zero MATs, no performance viewed.**
15. Alpha still UNSELECTED? **YES.**
16. Evidence supports C01 replacement preregistration? **NO; the required controlled recovery diagnostic did not pass.**

## Stop state

The current blocker is earlier than CarSim: the default-policy MATLAB batch
environment cannot reliably start. A future stage must remediate and independently
verify MATLAB startup/normal exit before any new CarSim authorization. It must not
continue calibration acquisition, execute C01/C02-C05, touch holdout, or solve
weights.

CURRENT MATLAB EXECUTION ENVIRONMENT IS NOT HEALTHY ENOUGH TO RUN THE KNOWN-GOOD CONTROL CONFIGURATION.

C01 REMAINS FAILED-INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA.

C02-C05 REMAIN NOT RUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

