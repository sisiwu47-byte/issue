# V2.7-A2R5 D DEMUX 71-WIDTH MINIMAL REMEDIATION

## Verdict

**V2.7-A2R5 BLOCKED BY EXTERNAL CARSIM SOLVER PATH DURING COMPILE-ONLY INITIALIZATION**

The authorized D Demux repair succeeded. The subsequent one-and-only healthy
MATLAB batch reached compile-level initialization and stopped on a new,
external CarSim solver-path blocker.

## Authorized target change

Only the independent reliability diagnostic target was saved:

```text
model/vx_vy_reliability_diagnostic_v2_7.slx
```

The exact semantic change is:

```text
vx_vy_reliability_diagnostic_v2_7/Parallel D Full P Extract
Outputs: [45 4 20] -> [45 4 22]
```

Static gates after the save:

```text
D reliability boundary output width = 71
Demux partition                    = [45 4 22]
Demux partition sum                = 71
45-value head                      = unchanged
4-value full-P slice               = unchanged
tail                               = 20 -> 22
```

The tail extension accounts for the two validity values appended by A2R2;
the three-segment ordering remains unchanged.

Target hashes:

```text
before = 636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499
after  = 2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F
```

The SLX archive retained 53 entries with no additions or removals. Seven
entries changed because `save_system` updated metadata/thumbnail and
canonicalized existing XML order/default fields. Offline XML comparison found
only one logical model-parameter change: the authorized Demux `Outputs`
value. Details are recorded in
`results/vy_reliability_diagnostic_v2_7a2r5_slx_diff_audit.csv`.

## Single healthy batch execution

Exact executable:

```text
D:\matlab\Matlab R2024a(1)\anzhuang\bin\matlab.exe
```

Invocation count was exactly one. The batch performed the authorized save,
reloaded the target, checked the static contracts, and called the compile-only
API once. It did not call `sim()`.

Pre-compile gates:

```text
model load                  PASS
D reliability contract     PASS
K reliability contract     PASS
F diagnostic-port contract PASS
D/K/F scheduler contract   PASS
required logging contract  PASS
Demux 71-width contract    PASS
```

The compile then returned:

```text
FIRST_ERROR_ID = Simulink:SFunctions:SFcnErrorStatus

S-Function 'vs_sf' in
vx_vy_reliability_diagnostic_v2_7/CarSim S-Function:
Unable to load solver module
G:\carsim\Programs\solvers\carsim_64.dll
```

The active project `simfile.sim` confirms the same G-drive lineage:

```text
SET_MACRO $(OUTPUT_PATH)$ G:\carsimfile\Results
SET_MACRO $(WORK_DIR)$    G:\carsimfile\
PROGDIR                   G:\carsim\
DATADIR                   G:\carsimfile\
RESOURCEDIR               G:\carsim\\Resources\
```

`simfile.sim` SHA-256 is:

```text
95EBBB022B0F4A4019ECE96353B38C586D8616E914FA9736044D57EEF0E2F9BD
```

Per the A2R5 stop rule, no solver path, simfile, model block, or other project
content was modified after this new blocker appeared. No second compile was
performed.

## Integrity

Frozen baseline/source hashes remain unchanged:

```text
model/vx_vy_fixed_fusion_v2_5.slx
AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B

model/vy_dynamic_ekf_v1_17_reliability_numeric.m
C1D336FE4D281687C039A903C023D0CF5709EA1A43CED799DE8A84124FE7DCC3

model/vy_dynamic_ekf_v1_17.m
1AE909CF8118663F859EBC9F844374D97AB4238F701745EAC49A380498CE8AE5

model/vy_kinematic_kf.m
73A06F593E0D52B3A168445060F6CA68B35D2F710A913DD16213CDC71FF92298

model/vy_feedback_propagation_step.m
80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF
```

Runtime/behavior integrity:

```text
simCalled    = 0
carSimRun    = 0
calibration  = NOT RUN
Q/R          = UNCHANGED
P0_F/Q_F     = UNCHANGED
fusion       = UNCHANGED
```

The batch exited with code 1 after saving the failure evidence. Its generated
MAT is:

```text
results/vy_reliability_diagnostic_v2_7a2r5_remediation_compile.mat
SHA-256 = A6591421F91CFBEE259318BA9E807BAE31B7BCE8AE1921B44B9A78FC1323E2F2
```

## Stop state

The 71-width D interface defect is corrected. A2R5 cannot be declared ready
for the smoke runtime because full-target compile-only initialization is now
blocked by the unavailable `G:` CarSim solver lineage. No further modification
or retry is authorized in this stage.
