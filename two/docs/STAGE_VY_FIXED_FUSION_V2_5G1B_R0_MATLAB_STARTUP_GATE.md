# V2.5-G1B-R0 MATLAB Startup Environment Recovery Gate

## Decision

**V2.5-G1B-R0 MATLAB STARTUP ENVIRONMENT RECOVERY GATE BLOCKED**

The one authorized startup-only probe reproduced the same fatal settings-plugin
failure before the MATLAB command body ran. No second probe was attempted.

## Read-only pre-start environment audit

Audit time: `2026-08-28T15:50:23.3369527+08:00`.

| Item | Actual value |
|---|---|
| MATLAB executable | `D:\matlab\bin\matlab.exe` |
| executable SHA-256 | `E717C21CC33170584F474DDA03FEF013CA03EFEE63B9C84AF0D684584DB8589B` |
| MATLAB_PREFDIR | `<UNSET>` |
| preference policy | inherited/default; no explicit override |
| TEMP | `D:\SystemMigration\Temp` |
| TMP | `D:\SystemMigration\Temp` |
| USERPROFILE | `C:\Users\21180` |
| APPDATA | `C:\Users\21180\AppData\Roaming` |
| LOCALAPPDATA | `C:\Users\21180\AppData\Local` |
| current pwd | `D:\UsersData\桌面\two` |
| C: free bytes | `38482649088` |
| D:/TEMP free bytes | `153703686144` |

One pre-existing MATLAB process was observed and left untouched:

```text
PID        = 29492
start time = 2026-08-27T12:23:44.9031024+08:00
responding = TRUE
image      = D:\matlab\bin\win64\MATLAB.exe
```

It was not identified as a process created by the R0 probe and was not killed.

The default R2024a preference directory exists at
`C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a`. Its settings and
preference files were only listed; none was opened for writing, deleted, renamed,
or replaced.

## Existing failure/log evidence

No new settings-plugin crash dump or WER report attributable to the earlier G1B
startup failure was found in the inspected recent locations.

The only recent MATLAB crash artifacts remained the earlier C01 CarSim failure:

| Artifact | Timestamp | SHA-256 | Classification |
|---|---|---|---|
| `D:\SystemMigration\Temp\matlab_crash_dump.4772-1` | 2026-08-28 14:42:59 +08:00 | `4945CC9A7370F58FDAEFC9D27C4038A97819693971B90C7BA0522E51F8FC0CAF` | C01 `carsim_64.dll` access violation; not R0 |
| `D:\SystemMigration\Temp\bd8d-a5d9-d521-786b.dmr` | 2026-08-28 14:42:44 +08:00 | `B27EB22B480860AA70A4A725DA2F8F86C8AC2FC654AC33506FA7F9D80A608C89` | matching C01 crash artifact; not R0 |

Existing MathWorks ServiceHost logs contain historical client/service activity and
transport/settings events, but no new log with the exact R0 `errors_warnings`
fatal message was generated or identified. No log or preference file was modified.

**NO CARSIM CODE WAS EXECUTED IN R0.** The C01 DLL failure and the R0 MATLAB
settings-plugin failure are separate observed boundaries and are not assigned a
common root cause.

## Sole startup-only probe

Exact command:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "disp('MATLAB_STARTUP_OK'); disp(version); fprintf('SIMULINK_LICENSE=%d\n',license('test','Simulink')); load_system('simulink'); disp('SIMULINK_LOAD_OK'); close_system('simulink',0);"
```

No project `cd`, project runner, project model, CarSim library, compile/update, or
simulation call was present in the probe.

Observed output:

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

The failed process did not exit normally after reporting the fatal error and was
terminated through its existing process session. Tool-level exit code after that
termination was `1`. No probe-created MATLAB process remained afterward.

## Probe evidence matrix

| Evidence | Result |
|---|---|
| process launch attempted | YES |
| MATLAB command engine reached | NO |
| normal exit | NO |
| exit code | `1` after termination of the fatal startup process |
| `MATLAB_STARTUP_OK` | NOT PRINTED |
| MATLAB version | NOT PRINTED |
| `SIMULINK_LICENSE` | NOT EXECUTED |
| `SIMULINK_LOAD_OK` | NOT PRINTED |
| Fatal Startup Error | YES |
| `errors_warnings` plugin error | YES |
| ApplicationService error in this probe | NO such line observed |
| settings-related fatal error | YES |
| Simulink loaded | NO |
| CarSim loaded/executed | NO / NO |
| `sim()` called | NO |

The probe therefore fails both MATLAB-startup and Simulink-readiness gates. No
conclusion about the current CarSim runtime can be drawn.

## Integrity and authorization state

After the failed startup probe:

- only the pre-existing MATLAB PID 29492 remained
- no R0 result MAT/CSV was created
- fixed-fusion target hash remained
  `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE`
- `model/simfile.sim` remained
  `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA`
- V2.5-F registry remained
  `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE`
- no model, dataset, preference, settings, cache, runner, or prior evidence was modified

The original G1B real-runtime authorization remains **UNCONSUMED** because the
G1B diagnostic runner and its sole `sim()` call were never entered.

## Locked project state

- `FWCAL_C01`: `FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- C02-C05: `NOT RUN`
- holdout: zero runtime, zero MAT, performance not viewed
- `alpha_D`, `alpha_K`, `alpha_F`: `UNSELECTED`
- no optimization, tuning, fusion feedback, LifeSig, or `Vy_final`

## Only permitted next stage

The next stage can only be:

**V2.5-G1B-R1 MATLAB SETTINGS / PREFDIR REMEDIATION AUDIT**

R0 does not authorize another MATLAB startup attempt, a new preference policy,
CarSim recovery runtime, calibration replacement, C02-C05, holdout, or weight
selection.

THE G1B REAL-RUNTIME AUTHORIZATION IS STILL UNCONSUMED.

NO CARSIM CONCLUSION CAN BE DRAWN.

