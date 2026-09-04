# V2.2-C1R2 Interpreted Numeric Boundary Feasibility

## Stage conclusion

**V2.2-C1R2 INTERPRETED NUMERIC BOUNDARY FEASIBLE**

The isolated Level-2 MATLAB S-function boundary compiled with fixed numeric
ports. The formal `model/vx_vy_dkekf_v2_2.slx` target was not loaded, saved,
or modified. No time-advance simulation or CarSim run was performed.

## Frozen-interface findings

- Wrapper signature:
  `function [x_new, P_new, info] = vy_dkekf_baseline(Ax_IMU, steering, z_Vx, z_r, z_Ay, doAyUpdate, resetFlag)`
- Core signature:
  `function [x_new, P_new, info] = vy_dkekf_baseline_step(x, P, Ax_IMU, steering, z_Vx, z_r, z_Ay, doAyUpdate, Ts, par, cfg)`
- The wrapper owns persistent `xState` and `PState`.
- On the first call or when `resetFlag > 0.5`, it initializes
  `xState=[z_Vx;0;0]` and `PState=diag([0.1 0.1 0.1])`.
- Every wrapper invocation calls `vy_dkekf_baseline_step` exactly once and
  commits the returned `x_new` and `P_new`.
- Core `info` top-level fields include `x_pred`, `P_prior`, `P_pred`, `f`,
  `A`, `F`, the three measurement Jacobians and predicted measurement
  values, nested `Vx`, `r`, and `Ay`, force/slip diagnostics, and fixed
  state/covariance dimension metadata.
- Each nested measurement record contains `innovation`, `S`, `K`, `NIS`,
  `H`, `h`, prior/posterior x/P, and `updateApplied`.
- Neither frozen entry point is written specifically as a MATLAB Function
  code-generation adapter. CASE A proved that omitting the returned `info`
  value is not sufficient: MATLAB Function type propagation still could not
  resolve x/P. The diagnostic does not isolate one internal construct, so
  persistent state, the complete analyzed call graph, structs/local
  functions, and MATLAB Function code-generation analysis remain possible
  contributors rather than a claimed single root cause.

## Selected adapter

**OPTION 2** was selected.

The Level-2 MATLAB S-function owns only wrapper-equivalent x/P/reset interface
state in DWork and calls the frozen stateless
`vy_dkekf_baseline_step` function. It contains the frozen wrapper's interface
configuration mapping but no prediction, Jacobian, measurement, Joseph
update, tire-force, Q/R, or other EKF equations. Therefore no second EKF
mathematical implementation was created.

OPTION 1 was rejected because calling the persistent wrapper from `Outputs`
would mutate wrapper state. Repeated `Outputs` evaluation at one simulation
time could then advance the estimator more than once.

## Execution semantics

- `Outputs` reads one DWork snapshot, applies reset initialization when
  required, calls the frozen stateless core, and writes only numeric output
  ports.
- `Outputs` does not write x/P DWork.
- `Update` commits the already computed x/P outputs to DWork.
- Repeated `Outputs` evaluations before `Update` therefore recompute from the
  same snapshot and cannot advance committed estimator state.
- In the isolated harness the block is inside a Function-Call Subsystem driven
  by a 0.01 s Function-Call Generator with one iteration. Each function-call
  hit has one discrete `Update` commit.

Static execution-semantics audit result:

```text
safe                         = 1
callsFrozenCore              = 1
callsPersistentWrapper       = 0
outputsWritesState           = 0
updateCommitsState           = 1
containsCopiedEkfMath        = 0
```

## Fixed numeric diagnostics

`diag` is a fixed 7x1 double vector with this order:

```text
1  NIS_Vx
2  NIS_r
3  NIS_Ay
4  AyUpdateApplied
5  innovation_Vx
6  innovation_r
7  innovation_Ay
```

When the frozen core marks the Ay update as skipped, its unavailable Ay NIS
is NaN. Numeric packaging maps only that skipped NIS to zero while preserving
`AyUpdateApplied=0`; no reliability, LifeSig, fusion, or observability logic
was added.

## Compile-only evidence

One new MATLAB batch session was used for the new boundary mechanism:

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "addpath(fullfile(pwd,'model')); addpath(fullfile(pwd,'tests')); try, report=test_vy_dkekf_v2_2c1r2_sfun_feasibility(); if report.passed, exit(0); else, if ~isempty(report.compileErrorReport), disp(report.compileErrorReport); end; exit(2); end; catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end"
```

Raw result:

```text
exit code                    = 0
compileCalled                = 1
blockRecognized              = 1
input dimensions             = 1 / [4 1] / 1 / 1 / 1 / 1 / 1
input types                  = all double
x dimension/type             = [3 1] / double
P dimension/type             = [3 3] / double
diag dimension/type          = [7 1] / double
passed                       = 1
simCalled                    = 0
carSimRun                    = 0
algorithm runtime in compile = 0
frozenUnchanged              = 1
compile diagnostic           = NONE
orphan MATLAB process        = NONE
```

The harness used only `compile`/`term`; it did not invoke `sim` or advance
model time. The in-memory harness was closed without saving.

Evidence file:
`results/vy_dkekf_v2_2c1r2_sfun_feasibility.mat`

## Integrity hashes after compile

```text
model/vy_dkekf_baseline_step.m
6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457

model/vy_dkekf_baseline.m
7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973

model/vx_vy_dkekf_v2_2.slx
DE3DDADDDAD7953640547914E809DA7B6A5C3FB261AE211FF255B06A74B09DCF

model/vy_dkekf_baseline_simulink_sfun.m
12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1

results/vy_dkekf_v2_2c1r2_sfun_feasibility.mat
C0258229A7025B1F02BBB037EFD6848A17ABCB58F874540FC7F67003F9561A9A
```

Core, wrapper, and target hashes match their frozen baselines. The adapter
was unchanged by compile.

## Files created

- `model/vy_dkekf_baseline_simulink_sfun.m`
- `tests/test_vy_dkekf_v2_2c1r2_sfun_feasibility.m`
- `results/vy_dkekf_v2_2c1r2_sfun_feasibility.mat`
- `docs/STAGE_VY_DKEKF_V2_2C1R2_STATUS.md`

No target, frozen core, frozen wrapper, Q/R, fusion, LifeSig, or C2 artifact
was modified or created.
