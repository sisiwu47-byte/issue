# V2.3-B1 External CarSim Solver Path Attribution and Compile Recovery

- Date: 2026-08-27
- Scope: CarSim compile-path attribution and one authorized compile-only recovery attempt
- Model changes: **NONE**
- Dataset/config changes: **NONE**
- `sim()` / Start command: **NOT CALLED**
- CarSim runtime: **NOT RUN**
- Final classification: **A — G: embedded in the active CarSim `simfile.sim` configuration selected by the process working directory**
- Final decision: **V2.3-B1 EXTERNAL CARSIM COMPILE-PATH BLOCKER CONFIRMED**

## 1. Executive result

The `G:\carsim\Programs\solvers\carsim_64.dll` request was not introduced by
the V2.3-B builder or by the parallel D/K target. The CarSim S-function stores
only a relative configuration name:

```text
SIMFILE = simfile.sim
Parameters = 'simfile.sim',vs_state,StopMode
```

The first V2.3-B validator ran with the project root as the process current
directory. Consequently, `vs_sf` resolved:

```text
D:\UsersData\桌面\two\simfile.sim
```

That file contains:

```text
PROGDIR G:\carsim\
DATADIR G:\carsimfile\
RESOURCEDIR G:\carsim\\Resources\
```

and is the exact producer of the original G: solver request.

The project also contains the already validated runtime configuration:

```text
D:\UsersData\桌面\two\model\simfile.sim
```

with:

```text
PROGDIR D:\carsim\CarSim2021.0_Prog\
DATADIR D:\carsim\CarSim2021.0_Data\
RESOURCEDIR D:\carsim\CarSim2021.0_Prog\\Resources\
```

Existing accepted runtime scripts explicitly `cd(model)` before loading the
model, so they resolve this D: configuration. The original compile validator
did not change into `model/`, which explains the discrepancy.

An environment-only recovery compile was therefore performed from `model/`
without modifying any file. It successfully changed the requested module to:

```text
Use vehicle solver:
D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

This proves that the G: path attribution and cwd-level recovery are correct.
However, the full-target compile did not pass: `vs_sf`/the D: CarSim solver
then caused a native access violation during CarSim initialization. Therefore
V2.3-B still cannot be accepted under the mandatory full-target compile gate.

## 2. Frozen integrity before and after

| Object | SHA-256 | Result |
|---|---|---|
| `model/vx_vy_parallel_dk_v2_3.slx` | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | unchanged |
| `model/vy_dynamic_ekf_v1_17.m` | `5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0` | unchanged |
| `model/vy_dynamic_ekf_step_v17.m` | `4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F` | unchanged |
| `model/vy_dynamic_ekf_step_v13.m` | `498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4` | unchanged |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | unchanged |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | unchanged |
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | unchanged |

No active/orphan MATLAB process remained after the access-violation exit.

## 3. CarSim block comparison

### 3.1 MATLAB API evidence

Both source and parallel target reported exactly the same active parameters:

| Property | Frozen source | Parallel target |
|---|---|---|
| `BlockType` | `S-Function` | `S-Function` |
| `ReferenceBlock` | `Solver_SF/CarSim S-Function` | same |
| `LinkStatus` | `resolved` | `resolved` |
| `MaskType` | `Vehicle math model library` | same |
| `FunctionName` | `vs_sf` | `vs_sf` |
| `Parameters` | `'simfile.sim',vs_state,StopMode` | same |
| `SIMFILE` | `simfile.sim` | same |
| `Run_RTs` | `off` | `off` |
| `vs_state_ind` | `Run` | `Run` |
| `StopMode_ind` | `Vehicle Model` | same |
| `UserData` | empty | empty |

Dialog/mask fields in each model were the same four fields:

```text
SIMFILE
Run_RTs
vs_state_ind
StopMode_ind
```

The library block itself also reported:

```text
Solver_SF/CarSim S-Function
FunctionName = vs_sf
Parameters = 'simfile.sim',vs_state,StopMode
```

### 3.2 Independent SLX package evidence

The CarSim Reference-block XML fragment extracted read-only from each SLX had
the same SHA-256:

```text
C075E6D4F5A59C4DEC751BE0A36B2001668C4D088847C4DA0F57CE4EF89C16F6
```

Neither SLX package contained `G:\carsim`, `carsim_64.dll`, `PROGDIR`, or
`DATADIR`. Both contained the same `SIMFILE=simfile.sim` instance value.

Therefore:

```text
parallel integration did not introduce the G: path
```

The V2.3-B builder contains no CarSim block `set_param`, no solver-path
assignment, and no simfile generation. It copies the frozen source first and
saves only the new target.

## 4. Callback, workspace, and environment audit

For both models, every audited callback was empty:

```text
PreLoadFcn
PostLoadFcn
InitFcn
StartFcn
StopFcn
CloseFcn
```

No CarSim/program/solver/simfile-related variable was found in either model
workspace or the MATLAB base workspace.

The MATLAB process environment reported:

```text
getenv('PROGDIR') = ''
getenv('DATADIR') = ''
```

Thus the G: path was not injected by a model callback, workspace variable, or
process environment variable.

## 5. Active config and dataset audit

### 5.1 Root config that produced G:

```text
file: D:\UsersData\桌面\two\simfile.sim
SHA-256: 95EBBB022B0F4A4019ECE96353B38C586D8616E914FA9736044D57EEF0E2F9BD
ROOT_FILE_NAME: Run_d05bfc0b-97ca-48c5-b21f-3525f5950963
PROGDIR: G:\carsim\
DATADIR: G:\carsimfile\
```

The `SIMFILE`, generated run UUID, output/archive paths, GUI refresh token,
product/version fields, and `INPUT ... Run_all.par` structure identify it as a
CarSim run configuration artifact. It was selected solely because `vs_sf`
uses a relative filename and the compile cwd was the project root.

### 5.2 Validated D: config

```text
file: D:\UsersData\桌面\two\model\simfile.sim
SHA-256: A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA
ROOT_FILE_NAME: Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517
PROGDIR: D:\carsim\CarSim2021.0_Prog\
DATADIR: D:\carsim\CarSim2021.0_Data\
```

Referenced active parameter archive:

```text
D:\carsim\CarSim2021.0_Data\Results\
Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517\Run_all.par
exists: YES
bytes: 306069
SHA-256: 2FA959F8137B6014F87BC70F1F7716308E92FF22B8E4E7BD6CCC4179EA16C114
```

The audited `.par` contained the expected four steering imports and did not
contain `G:\carsim`, `carsim_64.dll`, `PROGDIR`, or `DATADIR`. No `.par`,
dataset, or simfile was modified.

## 6. Recovery action and compile evidence

The safe environment-level correction was:

```matlab
cd(fullfile(projectRoot,'model'))
report = validate_vy_parallel_dk_v2_3_integration(build,true);
```

Before compile, the command asserted that the cwd-resolved `simfile.sim`
contained the authorized D: `PROGDIR/DATADIR` and no G: path.

The first launch of this command stopped before calling the validator because
an auxiliary inline `regexp(...){1}` print expression was invalid MATLAB
syntax. It did not call compile and is not a compile retry. The corrected
command then made the single authorized recovered-path compile call.

Observed evidence:

```text
V23B1_COMPILE_CWD = D:\UsersData\桌面\two\model
V23B1_D_SIMFILE_CONFIRMED
Use vehicle solver:
D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
```

This fully recovers the requested solver path. The loaded DLL was:

```text
D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
bytes: 6861824
SHA-256: A53EE59C5754933AFC0E361C93DA1B5B70AA755A7F21C122979D7588FF04CF9D
```

The full-target compile then terminated abnormally:

```text
exit status: 0xC0000005 (access violation)
S-function: vs_sf
block: vx_vy_parallel_dk_v2_3/CarSim S-Function
native module: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
first native frames include:
  vs_get_state_q
  vs_copy_io
  vs_initialize
  vs_read_configuration
```

Crash report:

```text
D:\SystemMigration\Temp\matlab_crash_dump.23292-1
```

No `sim()` or Start command was issued. The failure occurred while the
compile-only operation invoked the external S-function initialization path.

## 7. Frozen-source discriminator decision

The frozen source was not separately compiled after the D: access violation.
This was deliberate:

1. the source and parallel CarSim S-function block/config parameters are
   identical by both MATLAB API and independent XML-fragment hash;
2. the G: producer was already conclusively identified as cwd-selected root
   `simfile.sim`;
3. the recovered-path failure is a fatal native crash in the common external
   `vs_sf`/CarSim DLL initialization, not a MATLAB diagnostic identifying a
   D/K block;
4. repeating the same external initialization against the frozen source would
   risk another MATLAB process crash without changing the V2.3-B decision.

Therefore there is no independent source-model compile PASS/FAIL result in
V2.3-B1. At the **path attribution level**, the condition is definitively
inherited because both models use the identical relative `simfile.sim`
boundary. At the **native access-violation level**, source behavior is not
independently executed and is not claimed as measured.

## 8. Attribution classification

| Candidate | Result | Evidence |
|---|---|---|
| A. G: embedded in active external dataset/config | **CONFIRMED** | cwd-selected root `simfile.sim` contains `PROGDIR G:\carsim\` |
| B. callback/workspace injection | excluded | callbacks empty; no relevant base/model workspace variables |
| C. process environment injection | excluded | `PROGDIR` and `DATADIR` environment variables empty |
| D. parallel builder/model copy introduced path | excluded | source/target CarSim block identical; neither SLX embeds G:; builder has no CarSim write |
| E. compile-only legacy behavior inherited from source | path resolution is inherited, but not the primary producer | common relative `simfile.sim`; producer is the selected config file |
| F. inconclusive | excluded | direct producer and selection mechanism identified |

## 9. Minimal next decision

The project-level path fix is known and safe for any future compile command:

```text
set process cwd to D:\UsersData\桌面\two\model
before loading/compiling the model
```

This requires no model, dataset, solver, steering, estimator, or physics
change. It fixes the G: selection issue but does not fix the native CarSim
access violation.

The mandatory full-target compile gate remains unavailable because the
external CarSim 2021 `vs_sf`/solver initialization crashes under this
compile-only path. Under the current authorization, no safe further automatic
fix exists: changing the MEX/DLL, solver, dataset, or S-function behavior is
outside scope, and another compile would only reproduce the established crash.

Static parallel integration remains:

```text
41/41 PASS
```

No evidence attributes the native crash to D/K estimator integration, but a
static PASS cannot replace the explicitly required full-target compile PASS.

## 10. Stop state

**V2.3-B1 EXTERNAL CARSIM COMPILE-PATH BLOCKER CONFIRMED**

- Exact G: producer: project-root `simfile.sim` selected by cwd.
- G: solver-path request: recovered using the existing D: `model/simfile.sim`.
- Recovered solver request: `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`.
- Full-target compile: still failed by native `vs_sf`/CarSim DLL access violation.
- Frozen source separately compiled: NO, because the common external compile
  path had already caused a fatal process crash and no additional safe
  decision information would result.
- Parallel static integration: 41/41 PASS.
- Estimator integration relation: no D/K integration error was emitted; the
  blocker is in the external CarSim S-function initialization boundary.

V2.3-B remains blocked and is not promoted to accepted.

NOT READY FOR V2.3-C.

NO SIMULATION OR CARSIM RUNTIME WAS PERFORMED.

NO D-EKF, K-KF, DK-EKF, MODEL, DATASET, OR SOLVER FILE WAS MODIFIED.

NO FUSION, LIFESIG, THIRD TRACK, Q/R TUNING, OR BIAS CORRECTION WAS PERFORMED.
