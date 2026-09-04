# V2.7-A2R4 GUI RECOVERY MODEL-LOAD / UPDATE PREFLIGHT

## Verdict

**V2.7-A2R4 RELIABILITY TARGET MODEL-LOAD / UPDATE PREFLIGHT BLOCKED**

Exact classification:

```text
MODEL_LOAD_AND_STATIC_CONTRACT_PASS
COMPILE_BLOCKED_BY_D_EXTRACT_DEMUX_69_TO_71_INTERFACE_MISMATCH
```

The earlier `errors_warnings` startup failure is not the active blocker for
this execution path. The healthy interactive MATLAB belongs to a different
installation root from the failing batch executable:

```text
healthy GUI matlabroot:
D:\matlab\Matlab R2024a(1)\anzhuang

previous failing batch path:
D:\matlab\bin\matlab.exe
```

`enableservice('AutomationServer',true)` returned logical `1`. The existing
GUI session was reused; no second MATLAB process was launched. A direct GUI
probe produced the durable marker
`results/vy_matlab_gui_automation_attach_probe.txt`, proving that commands
and evidence files can be exchanged through the healthy session.

## Validator-only remediation

Only the preflight validator was corrected. No model or estimator logic was
modified.

1. The K wrapper is a Stateflow `EMChart`; its script is now read through
   `sfroot` instead of the invalid block parameter `Script`.
2. Static gate defaults are initialized so an earlier error cannot be masked
   by a missing report field.
3. The repository's established compile-only API
   `feval(model,[],[],[],'compile')` / `'term'` replaces the invalid
   `SimulationCommand='compile'` call.
4. The validator provides the same compile-time workspace contract used by
   existing preflight/runtime scripts, in both model and base workspaces:

```text
test_speed            = 20
test_steer_amplitude  = 0.02
test_steer_frequency  = 0.4
vy_v17_mode_code      = 20
```

Base-workspace values are restored on cleanup. The target is always closed
without saving.

Final validator SHA-256:

```text
85FD03D7A873D8C33991864E875E1516565E3D72942C2D20B5509289CC63FD9A
```

## Final preflight evidence

The final saved report records:

```text
modelLoaded              = 1
dContractOK              = 1
kContractOK              = 1
fContractOK              = 1
schedulersOK             = 1
requiredLogsPresent      = 1
compileCalled            = 1
compilePassed            = 0
terminationReached       = 0
compiledEvidenceCaptured = 0
simCalled                = 0
carSimRun                 = 0
```

The exact compile diagnostic is:

```text
Invalid setting for input port dimensions of
vx_vy_reliability_diagnostic_v2_7/Parallel D Full P Extract.
The dimensions are being set to 71. This is not valid because the total
number of input and output elements are not the same.

vx_vy_reliability_diagnostic_v2_7/Parallel D-EKF 100Hz output port 1
is a one-dimensional vector with 71 elements.
```

Static inspection of the frozen SLX package shows:

```text
Parallel D Output Demux  Outputs = [2 2 65 2]
Parallel D Full P Extract Outputs = [45 4 20]
```

The extractor partition still totals 69, while the D reliability boundary
now outputs 71 values. The two newly appended validity values are at the
tail, so the smallest future target-only interface correction is to preserve
the existing 45-value head and four-value P slice and extend the tail from 20
to 22:

```text
[45 4 20] -> [45 4 22]
```

That target change was not authorized in A2R4 and was not applied.

## Integrity

The target SHA-256 before and after every load/compile attempt remains:

```text
636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499
```

Final evidence:

| File | SHA-256 |
|---|---|
| `results/vy_reliability_diagnostic_v2_7a2r4_model_load_update.mat` | `9BCC2CC5DE2CDCD5DEB33A3B97616F31FB669D091B28CC640D3A2CA2EF404160` |
| `results/vy_reliability_diagnostic_v2_7a2r4_compile_error_report.txt` | `7A14302FDDD18BCEE48DEC7EB54BBA051F4D22894D3A189DAAC323ABFE0CACAA` |
| `results/vy_reliability_diagnostic_v2_7a2r4_gui_recovery_gates.csv` | `9C9E901624F2443B97AC3C47EE501592CDC85147F9F62C18AF01EC9D88758051` |

No `sim()` call, CarSim runtime, calibration capture, model save, estimator
change, Q/R change, or P0_F/Q_F change occurred. The user-owned healthy GUI
MATLAB session remains open; it was not terminated.

## Required next action

The next stage, if authorized, should be a minimal diagnostic-target interface
remediation limited to `Parallel D Full P Extract`, followed by one affected
compile/update regression. It must not modify D/K/F equations, Q/R, fusion,
or the frozen V2.5 targets.
