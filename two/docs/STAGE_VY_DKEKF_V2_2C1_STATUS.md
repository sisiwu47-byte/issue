# STAGE VY DK-EKF V2.2-C1 STATUS

## Conclusion

**V2.2-C1 DK-EKF SIMULINK INTEGRATION ACCEPTED**

The formal target uses the accepted V2.2-C1R2 interpreted numeric boundary.
All 31 integration gates pass. No simulation or CarSim run was performed,
and V2.2-C2 was not started.

## Formal boundary

```text
block path:
vx_vy_dkekf_v2_2/DK-EKF Baseline/DK-EKF Numeric Boundary

BlockType:
M-S-Function

FunctionName:
vy_dkekf_baseline_simulink_sfun

adapter SHA-256:
12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1
```

The previous MATLAB Function/frozen-wrapper boundary was replaced by the
exact isolated-feasibility Level-2 MATLAB S-function adapter. The adapter
was not modified during formal integration.

## Input mapping

| Port | Adapter input | Compiled dimension/type | Unit / meaning | Actual source block |
|---:|---|---|---|---|
| 1 | `Ax_IMU` | scalar double | longitudinal acceleration, m/s^2 | `vx_vy_dkekf_v2_2/Ax IMU Sensor 100Hz` |
| 2 | `steering` | width-4 double (`[4 1]` at adapter) | four-wheel steering, rad | `vx_vy_dkekf_v2_2/DK-EKF Steering RT 100Hz`, upstream `Mux11` |
| 3 | `z_Vx` | scalar double | Vx measurement, m/s | `vx_vy_dkekf_v2_2/DK-EKF Vx RT 100Hz`, upstream `Gain38 = 1/3.6` |
| 4 | `z_r` | scalar double | yaw-rate measurement, rad/s | `vx_vy_dkekf_v2_2/AVz传感器` (`AVz_IMU`) |
| 5 | `z_Ay` | scalar double | lateral acceleration, m/s^2 | `vx_vy_dkekf_v2_2/ay传感器` (`Ay_IMU`) |
| 6 | `doAyUpdate` | scalar double | 20 Hz Ay update enable | `vx_vy_dkekf_v2_2/DK-EKF Ay 20Hz Pulse` |
| 7 | `resetFlag` | scalar double | first-call reset | `vx_vy_dkekf_v2_2/DK-EKF Reset First Call` |

No true-Vy input exists. True Vx is connected only through the measurement
path. The frozen core lateral dynamics use `Vx = x(1)` and do not use `z_Vx`
as a dynamics bypass.

## Outputs and logs

```text
x    = [3 1] double -> dkekf_x_log1
P    = [3 3] double -> dkekf_P_log1
diag = [7 1] double -> dkekf_diag_log1
inputs             -> dkekf_u_log1
```

Fixed diagnostic order:

```text
1 NIS_Vx
2 NIS_r
3 NIS_Ay
4 AyUpdateApplied
5 innovation_Vx
6 innovation_r
7 innovation_Ay
```

## Execution semantics

```text
trigger type                 = function-call
scheduler MaskType           = Function-Call Generator
scheduler sample time        = 0.01 s
scheduler iterations         = 1
scheduler connection         = PASS
adapter sample time          = inherited [-1 0]
calls frozen stateless core  = 1
calls persistent wrapper     = 0
Outputs writes DWork x/P     = 0
Update x commit count        = 1
Update P commit count        = 1
copied EKF mathematics       = 0
execution semantics safe     = 1
```

**ONE 100-HZ FUNCTION-CALL HIT = ONE COMMITTED DK-EKF STATE ADVANCE**

Repeated `Outputs` evaluation reads the same DWork snapshot and cannot
commit an additional transition. `Update` performs the single x/P commit.

Reset remains high for the first hit and steps low at 0.01 s. Ay scheduling
remains a period-0.05 s, 20%-width, phase-zero pulse sampled at 0.01 s,
providing the designed 20 Hz Ay update enable.

## Compile evidence

The validator first attempted formal target compile/update diagram:

```text
compileCalled = 1
formal target compile passed = 0
diagnostic identifier = Simulink:SFunctions:SFcnErrorStatus
first diagnostic = CarSim S-Function `vs_sf` was unable to load
                   G:\carsim\Programs\solvers\carsim_64.dll
```

This is an external CarSim solver dependency failure, so the explicitly
authorized exact-interface fallback was used. The unsaved in-memory harness
copied the formal Function-Call subsystem and contained the same Level-2
S-function, exact adapter, seven numeric inputs, three numeric outputs, and
100 Hz Function-Call Generator. It used no dummy substitute.

```text
fallback compile called/passed = 1 / 1
method = Exact subsystem copy in unsaved in-memory compile harness
x = [3 1] double
P = [3 3] double
diag = [7 1] double
all inputs = double
compile diagnostic = NONE
```

After correcting only peripheral validator interpretation (`M-S-Function`
recognition, vector-width representation, and case-normalized DWork scan),
the saved compile evidence was reused. The target was not rebuilt or
recompiled to regenerate already valid evidence.

## All 31 gates

```text
targetModelExists              = 1
frozenSourceHashes             = 1
coreWrapperHashes              = 1
subsystemExists                = 1
functionCallTrigger            = 1
scheduler100Hz                 = 1
firstHitDesignedAtZero         = 1
axConnected                    = 1
ayConnected                    = 1
avzConnected                   = 1
trueVxMeasurementConnected     = 1
trueVyOnlineAbsent             = 1
doAyInputExists                = 1
ayScheduler20Hz                = 1
resetExists                    = 1
xDimension3                    = 1
pDimension3x3                  = 1
diagnosticsDimension           = 1
requiredLogs                   = 1
noOutputFusion                 = 1
noLifeSig                      = 1
noAdaptiveFusion               = 1
noTrueVxBypass                 = 1
frozenReferencesResolve        = 1
compileEquivalentHarness       = 1
targetNoWrite                  = 1
steeringSourceConnected        = 1
defaultNoBuilder               = 1
defaultNoCopy                  = 1
defaultNoSaveModel             = 1
testTargetNoWrite              = 1

gateCount = 31
gatesTrue = 31
passed = 1
```

## No-write evidence

After the explicit builder saved the new target, default validation did not
call the builder, `copyfile`, or `save_system`:

```text
bytes before/after = 501134 / 501134
mtime before/after = 740221.34050925926 / 740221.34050925926
SHA-256 before     = E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15
SHA-256 after      = E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15
targetNoWrite      = 1
simCalled          = 0
carSimRun          = 0
```

Machine evidence: `results/vy_dkekf_v2_2c1_integration.mat`.

## Frozen integrity

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` |

```text
accepted adapter:
model/vy_dkekf_baseline_simulink_sfun.m
12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1

new formal target:
model/vx_vy_dkekf_v2_2.slx
E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15
```

## Files changed in C1R3

- `model/vx_vy_dkekf_v2_2.slx`
- `model/build_vy_dkekf_v2_2.m`
- `model/validate_vy_dkekf_v2_2_integration.m`
- `tests/test_vy_dkekf_v2_2_integration.m`
- `results/vy_dkekf_v2_2c1_integration.mat`
- `docs/STAGE_VY_DKEKF_V2_2C1_STATUS.md`

No frozen reference, core, wrapper, adapter, Q/R, fusion, LifeSig, adaptive
logic, or C2 artifact was modified.

READY FOR V2.2-C2 0.20-S RUNTIME PREFLIGHT
