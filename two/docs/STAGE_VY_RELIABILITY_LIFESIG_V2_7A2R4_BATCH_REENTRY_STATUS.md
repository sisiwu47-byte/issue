# V2.7-A2R4 BATCH-PATH RE-ENTRY STATUS

## MATLAB execution policy

The user-confirmed healthy default MATLAB batch entry is now:

```text
D:\matlab\Matlab R2024a(1)\anzhuang\bin\matlab.exe
```

The startup-only probe produced `MATLAB_BATCH_STARTUP_OK`. Future project
MATLAB work should prefer this executable. The previous
`D:\matlab\bin\matlab.exe` entry is retired for this project because of its
reproducible settings-plugin startup failure.

## A2R4 repeat gate

The reliability target remains byte-for-byte unchanged:

```text
model/vx_vy_reliability_diagnostic_v2_7.slx
SHA-256 = 636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499
```

Existing valid A2R4 evidence already proves:

```text
model load                    PASS
D/K/F static contracts        PASS
scheduler static contract     PASS
required logging contract     PASS
simCalled                     0
carSimRun                     0
compile                       FAIL
```

Exact compile blocker:

```text
Parallel D-EKF 100Hz output width        = 71
Parallel D Full P Extract Outputs         = [45 4 20]
Parallel D Full P Extract partition total = 69
```

The healthy batch path changes only the MATLAB startup route. It does not
change this target-side interface mismatch. Because neither the target nor
the validator inputs changed, another compile would only repeat an already
established failure and was not executed.

## Verdict

**V2.7-A2R4 RELIABILITY TARGET MODEL-LOAD / UPDATE PREFLIGHT BLOCKED**

```text
COMPILE_BLOCKED_BY_D_EXTRACT_DEMUX_69_TO_71_INTERFACE_MISMATCH
```

The smallest future correction remains a diagnostic-target-only change:

```text
Parallel D Full P Extract Outputs:
[45 4 20] -> [45 4 22]
```

That model change is outside the current preflight-only authorization and was
not applied. No MATLAB process, Simulink compile, simulation, or CarSim
runtime was started during this re-entry check.
