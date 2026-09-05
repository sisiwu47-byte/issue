# V2.7-A2R4 RELIABILITY TARGET MODEL-LOAD / UPDATE PREFLIGHT

## Verdict

**V2.7-A2R4 BLOCKED BY MATLAB STARTUP ENVIRONMENT**

Exact classification:

```text
MATLAB_STARTUP_SETTINGS_PLUGIN_FAILURE_BEFORE_MODEL_LOAD
```

The reliability target was not loaded and the compile/update-level check was
not reached. This is not evidence of a target port, dimension, sample-time,
wrapper, S-function, or logging failure.

## 1. Prior failure evidence and selected startup policy

A2R3 recorded two distinct startup failures before any project/model load:

```text
default PREFDIR:
failed to load settings errors_warnings plugin

new temporary clean PREFDIR:
Unable to load ApplicationService for command client-v1
```

The frozen V2.5-G2 R4/R5 evidence established that healthy default-PREFDIR
startup had previously been achieved after quarantining exactly:

```text
ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa
SHA-256 = 30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E
```

At A2R4 entry this SET-2 file had regenerated in the active default PREFDIR,
with the same 1024-byte size and SHA-256. `MATLAB_PREFDIR` was UNSET at
process, user, and machine scope; live MATLAB and live CarSim solver counts
were both zero. Therefore the minimal evidence-based policy was to reuse the
default PREFDIR after append-only SET-2 quarantine, not to repeat another
clean-PREFDIR experiment.

SET-2 was moved without deletion or overwrite to:

```text
D:\SystemMigration\Temp\V27A2R4_SET2_QUARANTINE_20260830T071618Z\
  ddux\schemas\SL_PERFORMANCE_STARTUP.jsonrsa
```

The destination hash is unchanged. The active source remains absent after
the preflight attempts.

## 2. Preflight validator prepared

The stage created:

```text
model/validate_vy_reliability_diagnostic_v2_7a2r4.m
```

Its only authorized model operations are:

```text
load_system(reliability target)
one compile/update-level interface check
compiled dimension/type/sample-time capture
termination
close_system(...,0)
```

It contains no `sim()` call and no `save_system` call. The expected target
hash is asserted before and after the check.

## 3. Actual execution evidence

The first launcher route used `Start-Process` with redirected stdout/stderr.
MATLAB startup-side activity occurred, proven by the active Q04 cache mtime
and hash change, but stdout/stderr remained empty and no validator MAT or
payload marker was produced. This route therefore provided no model-load
evidence and was not interpreted as a target failure.

The launcher mechanism was then changed materially to the repository's
historically successful direct invocation:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); ..."
```

It produced the exact first diagnostic:

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: failed to load settings errors_warnings plugin
```

No validator marker was reached. Consequently:

```text
modelLoaded              = NOT REACHED
compileCalled            = 0
compilePassed            = NOT TESTED
terminationReached       = NOT APPLICABLE
compiledEvidenceCaptured = 0
simCalled                = 0
carSimRun                 = 0
```

The required result MAT is absent. The target SHA-256 remains:

```text
636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499
```

## 4. Post-attempt hygiene

- live MATLAB count: 0;
- live CarSim solver count: 0;
- active SET-2: ABSENT;
- quarantined SET-2 copy: PRESENT, hash preserved;
- `MATLAB_PREFDIR`: UNSET;
- default PREFDIR was not replaced or deleted;
- Q04 post-attempt SHA-256:
  `7A181D98273DDE89E015EEFC31F4BB85AC92EC42B78DC2CD27C5C666AE0F2A84`;
- no model was saved or modified;
- no simulation, CarSim runtime, calibration capture, or holdout was run.

## 5. Stop condition

The same default-PREFDIR settings-plugin failure is now directly reproduced
after the known SET-2 artifact was quarantined. Another MATLAB launch without
new startup-root-cause evidence would only repeat the same failure and is not
authorized by the project's bounded-execution rule.

The next action must be a separate MATLAB startup/settings remediation stage.
The target model-load/update verdict remains **NOT TESTED**, not failed.
