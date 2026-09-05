# V2.5-G1 CarSim Runtime Initialization Failure Forensic Audit

## Decision

**V2.5-G1 CARSIM RUNTIME INITIALIZATION FORENSIC INCONCLUSIVE**

Attribution category: **G. INCONCLUSIVE — CONTROLLED DIAGNOSTIC RUNTIME REQUIRED**.

The available read-only evidence rules out an observed target-hash change,
working-directory switch, wrong selected simfile, G: solver loading, duplicate
`carsim_64.dll`, target callback, or steering-variable-to-CarSim-configuration
dependency. It does not distinguish a transient external CarSim failure from
the changed MATLAB startup/preference environment or another initialization
state difference. No causal claim is made without a discriminating runtime.

No MATLAB process, compile, simulation, or CarSim runtime was started in V2.5-G1.

## Fixed evidence

### Successful reference: V2.5-D

The existing status and MAT evidence record:

- target: `model/vx_vy_fixed_fusion_v2_5.slx`
- target SHA-256: `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE`
- normal simulation, `StopTime=0.20 s`
- MATLAB exit code `0`
- runtime completed using `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- working directory: `D:\UsersData\桌面\two\model`
- active simfile: `D:\UsersData\桌面\two\model\simfile.sim`
- G: request: `NO`
- 28/28 runtime gates passed

The saved reference MAT remains present:

`results/vy_fixed_fusion_v2_5d_preflight.mat`

SHA-256: `63F233D9B0B444EDCA7C332F522AF9A588EB3A9C6F0E5FD9718CA5BEA09184F8`.

The associated CarSim log says it started with `simfile.sim`, loaded
`Run_all.par`, began the VS output file, and stopped normally at `t=0.2` under
external control.

### Failed reference: V2.5-G / FWCAL_C01

- target and target SHA-256: identical to V2.5-D
- registered command: `0.02 rad`, `0.30 Hz`, sine, FL/FR equal, rear zero
- requested duration/rate: `16 s` / `100 Hz`
- exact run card was printed before the single authorized `sim()`
- fatal exit: `0xC0000005` at 2026-08-28 14:42:58 +08:00
- no simulation completion, runtime logs, result MAT, or analyzer execution

The crash stack loaded the D: binaries and failed in this order:

`vs_sf.mexw64 -> vs_read_configuration -> vs_initialize -> vs_copy_io -> vs_target_heading -> vs_get_state_q`

This is an actual runtime-initialization failure, not a compile-only test.

## Structured runner comparison

| Concern | Successful V2.5-D | Failed C01 | Classification / relevance |
|---|---|---|---|
| executable | `D:\matlab\bin\matlab.exe` | same | same infrastructure |
| MATLAB mode | `-batch` | `-batch` | same infrastructure |
| outer command cwd | project root | project root | same |
| runner cwd at `sim()` | explicit `cd(model)` | explicit `cd(model)` | same; C01 reached the post-assert run card |
| cwd restoration | `onCleanup`, after runtime | same | irrelevant before CarSim initialization |
| MATLAB path additions | `model`, solver directory, `Matlab84+` | same order | same |
| `load_system` | `Solver_SF`, then formal target | same | same |
| `SimulationInput` | not used | not used | same |
| direct runner `set_param` | none | none | same |
| model workspace amplitude | `0.02` | `0.02` from registry | identical |
| model workspace frequency | `0.40` | `0.30` from registry | expected maneuver difference; only sine-source consumer found |
| base workspace amplitude/frequency | fixed `0.02/0.40` | registered `0.02/0.30` | expected maneuver difference |
| `test_speed` | assigned `20` | intentionally not assigned | no target consumer or callback found; irrelevant to CarSim selection |
| `vy_v17_mode_code` | `20` | `20` | same |
| StopTime override | literal `0.20` | registered value formatted as `16` | expected maneuver difference; possible external-horizon difference, but no causal evidence |
| simulation mode | normal | normal, same frozen target | same |
| output options | `ReturnWorkspaceOutputs=on`, `FastRestart=off` | same | same |
| runtime logs | D/K/F/fusion and steering | same plus existing true-Vy/true-Vx log blocks | collection occurs after simulation; no config dependency found |
| static prereg/hash gates | V2.5-C evidence gate | expanded V2.5-F registry/hash gates | pre-sim only; irrelevant after run card |
| cache/codegen path | dedicated V2.5-D temp folders | new per-run C01 temp folders | infrastructure difference; potentially relevant, not proven causal |
| MATLAB preference environment | no explicit `MATLAB_PREFDIR` in recorded command | new isolated `MATLAB_PREFDIR` | potentially relevant environment difference |
| startup diagnostics | no failure in accepted D evidence | `Unable to load ApplicationService for command client-v1` was observed before the runner executed | potentially relevant environment anomaly; not linked to the DLL fault by evidence |
| batch payload | one D function | ordered calibration loop; C01 was first | no preceding calibration state existed; loop itself is not an evidenced cause |
| `sim()` call site | one literal call | one literal call | identical options except StopTime |

Immediately before the C01 `sim()` call there is no `cd(projectRoot)`, `cd('..')`,
relative-path helper, callback call, or cleanup invocation. Cleanup only restores
the original cwd after control returns; the fatal MEX crash prevented that code
from executing in the failed process.

## Simfile and path forensic

Two project simfiles exist and are materially different:

| Path | SHA-256 | mtime | Key paths |
|---|---|---|---|
| `D:\UsersData\桌面\two\model\simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | 2026-08-27 13:27:13 +08:00 | D: PROGDIR/DATADIR |
| `D:\UsersData\桌面\two\simfile.sim` | `95EBBB022B0F4A4019ECE96353B38C586D8616E914FA9736044D57EEF0E2F9BD` | 2026-08-23 17:22:37 +08:00 | obsolete G: paths |

The runner explicitly reads the model-directory file, validates its D: macros,
changes cwd to `model`, constructs `fullfile(pwd,'simfile.sim')`, and asserts it
equals the model-directory path. The run card is printed only after those gates.
No intervening runner statement changes cwd.

The fatal stack independently confirms that the process loaded:

- `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- `D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64`

No C01 evidence contains a G: loaded-module path. The obsolete root simfile is a
latent project hazard, but existing evidence does not show that C01 resolved it.
Therefore the crash is not attributed to a G: request.

The active model simfile macros are:

- `PROGDIR D:\carsim\CarSim2021.0_Prog\`
- `DATADIR D:\carsim\CarSim2021.0_Data\`
- `WORK_DIR D:\carsim\CarSim2021.0_Data\`
- external ports: 16 imports / 35 exports

The file was last modified before both V2.5-D and C01 and remained unchanged.

## Target, callback, and mask audit

The target remained exactly:

`801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE`.

Read-only SLX inspection found:

- simulation mode: `normal`
- model solver: `VariableStepAuto`
- stored model StopTime: `16`
- no target `PreLoadFcn`, `PostLoadFcn`, `InitFcn`, `StartFcn`, `StopFcn`, or `CloseFcn`
- CarSim reference block: `Solver_SF/CarSim S-Function`
- CarSim instance `SIMFILE`: literal relative name `simfile.sim`
- state: `Run`; stop mode: `Vehicle Model`

The referenced `Solver_SF.slx` has SHA-256
`46BAF58DED45B68DCC195BA0D242BC930C0EC688D5E5A5E6E8248DCBE54F22C7`.
Its active CarSim mask initialization only maps `vs_state_ind`, `StopMode_ind`,
and `SIMFILE` into the S-function parameters. It does not change cwd and does
not reference steering amplitude, steering frequency, PROGDIR, DATADIR, or
calibration IDs.

## Maneuver-parameter side-effect audit

Across the unpacked target, the only consumers found were:

- `test_steer_amplitude` -> `G0 Steer Cmd Rad/Amplitude`
- `test_steer_frequency` -> `G0 Steer Cmd Rad/Frequency` as `2*pi*...`
- `Gain22` remains `180/pi`
- CarSim block `SIMFILE` remains `simfile.sim`

There is no target callback and no CarSim mask/configuration reference to either
steering variable. `test_speed` has no target consumer. Thus no project-side
dependency from amplitude/frequency/test_speed to CarSim file or solver selection
was found. The difference `0.40 -> 0.30 Hz` is not accepted as the cause of a
pre-runtime DLL access violation without dynamic evidence.

Changing `StopTime` changes the requested simulation horizon, but it does not
change the target, CarSim block mask, simfile path, PROGDIR, DATADIR, or loaded
DLL in the inspected artifacts. Static evidence alone cannot prove whether the
external solver has a horizon-sensitive initialization defect.

## DLL/MEX collision audit

No `carsim_64.dll` or `vs_sf.mexw64` exists in the project tree.

Under `D:\carsim`:

- one `carsim_64.dll` was found, SHA-256
  `A53EE59C5754933AFC0E361C93DA1B5B70AA755A7F21C122979D7588FF04CF9D`
- two `vs_sf.mexw64` paths were found (solver root and `Matlab84+`), both with
  identical SHA-256
  `6C00C5572DFA4DA512603C6BA24B36151479B36AD127E566937B95E19208C74C`

Both runners add the same two solver directories in the same order. The crash
dump identifies the `Matlab84+` copy. No version/path collision difference
between D and C01 is evidenced.

## Generated-file evidence

The configured CarSim run directory is:

`D:\carsim\CarSim2021.0_Data\Results\Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517`

Its `LastRun.vs`, echo, VSB, end, and log files have timestamps around the
successful V2.5-D runtime at 12:28. None was updated at the C01 crash time around
14:42. No C01 CarSim echo/log/output was produced. This places the failure before
normal CarSim output initialization and prevents a deeper configuration-level
comparison from generated logs.

The G runner contains no write, copy, builder, `save_system`, or dataset update
operation for any CarSim artifact.

## Crash artifacts

| Artifact | SHA-256 | Evidence |
|---|---|---|
| `D:\SystemMigration\Temp\matlab_crash_dump.4772-1` | `4945CC9A7370F58FDAEFC9D27C4038A97819693971B90C7BA0522E51F8FC0CAF` | exception, PID 4772, exact DLL/MEX stack |
| `D:\SystemMigration\Temp\bd8d-a5d9-d521-786b.dmr` | `B27EB22B480860AA70A4A725DA2F8F86C8AC2FC654AC33506FA7F9D80A608C89` | MATLAB crash artifact at the matching time |

No matching Windows WER text or new CarSim log was found in the inspected
locations.

## Compile-only limitation separation

**THE C01 RUNTIME FAILURE MUST NOT BE AUTOMATICALLY COLLAPSED INTO THE PREVIOUS COMPILE-ONLY LIMITATION.**

Both involve `vs_sf`/`carsim_64.dll` initialization and the same exception class,
but the prior event occurred in full-target compile-only initialization, while
C01 was an actual authorized `sim()` runtime. The present evidence does not prove
that their internal root cause is identical.

## Why attribution remains inconclusive

Project artifacts and routing are the same as the successful D reference. The
failure left no CarSim log and no runner MAT because the MEX/DLL access violation
terminated MATLAB. The remaining relevant differences are external or
initialization-state variables:

1. C01 used a newly created isolated `MATLAB_PREFDIR`; D did not record one.
2. The C01 process emitted ApplicationService startup warnings before executing.
3. C01 used a new per-run Simulink cache/codegen directory.
4. C01 requested 16 s instead of 0.20 s.
5. An external CarSim DLL may have failed transiently despite identical files.

No saved boundary evidence distinguishes these hypotheses. Therefore categories
A (cwd/simfile), C (wrong path/DLL), and D (maneuver-variable dependency) are not
supported; category B or E remains possible, but neither is proven.

## Only permitted next stage

The next stage may only be:

**V2.5-G1B CONTROLLED CARSIM RUNTIME RECOVERY DIAGNOSTIC**

It should execute the already-known successful V2.5-D preflight configuration,
not any calibration or holdout maneuver:

- same accepted frozen target
- same single-function V2.5-D command structure
- model cwd and model `simfile.sim`
- default/known-good MATLAB preference environment, without the C01 isolated
  prefdir unless separately justified
- `0.02 rad`, `0.40 Hz`, `0.20 s`
- one diagnostic runtime authorization only
- explicit pre/post environment, cwd, simfile, DLL/MEX, and process evidence

This would obtain new discriminating infrastructure information rather than
repeat a calibration performance experiment. If it passes, the environment has
recovered and C01 still must not be overwritten. If it fails at the same DLL
boundary, the current external CarSim runtime environment remains blocked.

No estimator, SLX, or CarSim dataset change is indicated by current evidence.

## Calibration and replacement state

- `FWCAL_C01`: permanently `FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- `FWCAL_C03`, `FWCAL_C04`, `FWCAL_C02`, `FWCAL_C05`: `NOT RUN`; authorization unconsumed
- holdout runtime count: `0`
- holdout data generated/viewed: `NO / NO`
- calibration performance data produced: `NONE`
- `alpha_D`, `alpha_K`, `alpha_F`: `UNSELECTED`

If runtime recovery is later proven and the C01 condition is reacquired, it must
use a new append-only remediation entry such as `FWCAL_C01R1`, with exactly the
same amplitude, frequency, duration, waveform, speed scope, and evaluation rule,
and explicitly replace failed-infrastructure C01. The original V2.5-F registry
must remain unchanged. Such a replacement would not be performance cherry-picking
because C01 produced no performance data.

NO CALIBRATION PERFORMANCE DATA WERE PRODUCED.

C01 REMAINS FAILED-INFRASTRUCTURE.

C02-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA REMAINS UNSELECTED.

