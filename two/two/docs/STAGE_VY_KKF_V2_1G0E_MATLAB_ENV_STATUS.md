# STAGE VY K-KF V2.1-G0E MATLAB ENVIRONMENT STATUS

- Date: 2026-08-26
- Stage: V2.1-G0E MATLAB Execution Environment Recovery
- Scope: MATLAB startup/environment diagnostics only
- Final Sol decision: **V2.1-G0E BLOCKED BY MATLAB EXECUTION ENVIRONMENT**

## A. Layer 1: exact MATLAB batch probe

Exact command:

```powershell
D:\matlab\bin\matlab.exe -batch "disp(version); disp('MATLAB_BATCH_OK'); exit(0)"
```

Observed evidence:

```text
exit code: 1 after terminating the stuck unified command session
MATLAB_BATCH_OK present: NO
captured stdout/stderr (PTY-combined):
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

The probe did not reach MATLAB command execution. The process count was seven
both before and after this probe, so this specific probe left no new orphan.

## B. Settings and preference inspection

Environment and installation identity:

```text
MATLAB_PREFDIR environment variable: unset
MATLAB executable: D:\matlab\bin\matlab.exe
MATLAB product/file version: 24.1.0.2508561 (R2024a)
default roaming preferences: C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
default local preferences:   C:\Users\21180\AppData\Local\MathWorks\MATLAB\R2024a
```

Both preference directories exist. Their ACLs grant the current sandbox user
Modify access and the owning user FullControl. No explicit current lock or
temporary settings file was found. The roaming directory contains ordinary
R2024a `.mlsettings` files and pre-existing SQLite `-shm`/`-wal` cache files;
none was deleted, renamed, overwritten, or otherwise modified in this task.

The default preference directory was last modified before this G0E task. The
available evidence does not prove that the user's original preferences are
corrupt or permission-blocked.

### Residual-process audit

Read-only command-line inspection identified six old headless `-batch`
processes from three prior failed probes:

```text
29356 / 21804
26112 / 23568
1452  / 21096
```

Their complete command lines matched the earlier MAT-read/model-read probes.
All six were terminated after identity verification. PID `16192`, created on
2026-08-25 as `-desktop -MLAutomation -Embedding`, was treated as the user's
pre-existing MATLAB desktop automation session and was not modified or
terminated.

After cleanup, only PID `16192` remained.

## C. Single clean-MATLAB_PREFDIR probe

A single new project-external directory was created:

```text
D:\SystemMigration\Temp\vy_kkf_g0e_pref_sol_clean_01
```

Only the current process received that `MATLAB_PREFDIR`. Exact MATLAB command:

```powershell
D:\matlab\bin\matlab.exe -batch "disp(version); disp('CLEAN_PREFDIR_OK'); exit(0)"
```

Observed evidence, including the repeat after verified orphan cleanup:

```text
exit code: 1 after terminating the stuck unified command session
CLEAN_PREFDIR_OK present: NO
captured stdout/stderr (PTY-combined):
Unable to load ApplicationService for command `client-v1`
```

The post-cleanup attempt emitted that diagnostic three times and did not reach
MATLAB code. The command session was terminated; no new MATLAB orphan remained.
The clean directory contains only a zero-byte `MLintDefaultSettings.txt`,
showing that startup failed before normal preference initialization.

The installed ApplicationService binary exists at:

```text
D:\matlab\bin\win64\app_service_host\jsd\services_host\mwApplicationService.dll
```

No matching startup log was produced in the system temp directory. Because a
fresh preference root fails after the old orphans are removed, user preference
damage or locking is not the sufficient root cause. The narrowest confirmed
failure is that the R2024a startup stack cannot load/communicate with its
settings/ApplicationService layer in the current execution environment.

## D. Layer 3: Simulink minimum load

**NOT EXECUTED.** MATLAB base startup never reached either success marker, so
the prerequisite for `license('test','Simulink')` and
`load_system('simulink')` was not met. No project model or CarSim library was
opened.

## E. Layer 4: project path

**NOT EXECUTED.** The Simulink layer was not reached, so the gated project
`cd`/`addpath` probe was not attempted. No builder, run script, or analyzer was
called.

## F. COM decision

COM was investigated once only after `-batch` had been confirmed unreliable.
The probe first recorded the sole existing PID `16192`, then attempted to
construct `Matlab.Application` and write a base-MATLAB marker in system temp.

```text
COM constructor/connection returned: NO (stuck for more than 60 s)
base marker created: NO
MATLAB command execution demonstrated: NO
```

The attempt created PID `13052` with command line
`/MLAutomation -Embedding`. It was identity-checked and terminated after the
marker remained absent. PID `16192` was left untouched. Because COM could not
demonstrate even a base MATLAB command and created a new orphan, it has no
reliable advantage and must not be used as the subsequent G0 execution path.

## G. Answers to the seven required questions

1. **Can MATLAB start reliably?** No.
2. **Can `-batch` execute a minimum command and exit?** No; no success marker,
   exit code 1 after stopping the stuck session.
3. **Are preferences/settings damaged or locked?** Not proven. The default
   directories exist and are writable, no explicit lock was found, and the
   failure persists with a fresh preference root after verified orphan cleanup.
4. **Does a temporary clean `MATLAB_PREFDIR` work?** No. It fails in
   ApplicationService before normal preference initialization.
5. **Can Simulink load without a project model?** Not tested because its
   mandatory base-MATLAB prerequisite failed.
6. **Are project `cd`/`addpath` operations normal?** Not tested because the
   prior gates failed; no evidence attributes the startup failure to the
   project path.
7. **Is COM still necessary?** No. It did not execute a marker and created an
   orphan. No reliable MATLAB execution path is currently selected.

## H. File and process discipline

Created in the project:

```text
docs/STAGE_VY_KKF_V2_1G0E_MATLAB_ENV_STATUS.md
```

Created outside the project only for the authorized clean-preference test:

```text
D:\SystemMigration\Temp\vy_kkf_g0e_pref_sol_clean_01
```

No `.slx`, estimator source, G0 builder/run/analyze source, CarSim dataset,
MATLAB installation file, or user preference file was modified. No `sim()` or
CarSim run occurred.

## I. Frozen hashes

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

## J. Final Sol decision

**V2.1-G0E BLOCKED BY MATLAB EXECUTION ENVIRONMENT**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

NO MODEL WAS MODIFIED.

NO SIMULATION OR CARSIM RUN WAS AUTHORIZED.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE BIAS CORRECTION WAS IMPLEMENTED.

NO FUSION WAS PERFORMED.

V2.2 WAS NOT STARTED.
