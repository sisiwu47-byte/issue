# STAGE VY K-KF V2.1-B STATUS

- Date: 2026-08-26
- Stage: V2.1-B K-KF Simulink Integration Only
- Gate decision: **V2.1-B SIMULINK INTEGRATION PASSED**
- Simulation: **NOT RUN**
- CarSim runtime: **NOT RUN**
- Nominal validation: **NOT STARTED**

## A. Handoff summary

The frozen V2.1-A wrapper was integrated into an isolated model copy under a
real 100 Hz Function-Call Subsystem. All 22 declared hard gates passed:

```text
V2_1B_BUILD_OK
V2_1B_COMPILE_AUDIT_OK|parent=[0.01 0]|Ax=[0.01 0]|Ay=[0.01 0]|AVz=[0.01 0]|VxRaw=[0.001 0]|VxBoundary=[0.01 0]|sim=0|carsim=0
V2_1B_INTEGRATION_TEST_OK|gates=22|sim=0|carsim=0
```

No runtime performance, execution count, output sample interval, nominal
metric, observability-region behavior, or NIS consistency is claimed.

## B. Created/modified files

Created:

- `model/vx_vy_kkf_v2_1.slx`
- `matlab/build_vy_kkf_v2_1_model.m`
- `matlab/validate_vy_kkf_v2_1_integration.m`
- `tests/test_vy_kkf_v2_1_integration.m`
- `results/vy_kkf_v2_1b_build_report.mat`
- `results/vy_kkf_v2_1b_compile_audit.mat`
- `results/vy_kkf_v2_1b_integration_test.mat`
- `docs/STAGE_VY_KKF_V2_1B_STATUS.md`

Updated:

- `docs/STAGE_VY_KKF_V2_1_STATUS.md` — V2.1-B addendum/status only

Generated compile/cache artifacts are confined to
`results/simulink_cache_vy_kkf_v2_1b/` and
`results/simulink_codegen_vy_kkf_v2_1b/`.

No nominal CSV, nominal MAT result, plot, run script, or analysis script was
created.

## C. Model architecture

Source model:

`model/vx_ax_imu_prereq_v2_1.slx`

Independent target copy:

`model/vx_vy_kkf_v2_1.slx`

Integrated structure:

```text
Ax_IMU ----\
Ay_IMU ----- K-KF IMU Mux [Ax_IMU; Ay_IMU; AVz_IMU] ---\
AVz_IMU ---/                                                \
                                                             -> K-KF 100Hz
true Vx at 1 kHz -> K-KF Vx RT 100Hz -----------------------/
K-KF Reset First Call --------------------------------------/
K-KF 100Hz Scheduler -- function-call event ---------------> trigger

K-KF 100Hz/K-KF Wrapper:
    [x_new,P_new,diag_out] = vy_kinematic_kf(u,z,resetFlag)
```

The wrapper MATLAB chart uses `SystemSampleTime=-1` inside the Function-Call
Subsystem, so it inherits the parent event. The model contains no duplicated
K-KF state equation, covariance equation, parameter set, or second wrapper.

## D. 100 Hz scheduling source

No reusable Function-Call Generator or Function-Call Subsystem existed in the
prerequisite model. A local independent event was therefore added without
modifying controller or D-EKF scheduling.

Actual event-source block path:

`vx_vy_kkf_v2_1/K-KF 100Hz Scheduler`

Properties:

- block: Function-Call Generator
- `sample_time = 0.01`
- `numberOfIterations = 1`
- destination: `vx_vy_kkf_v2_1/K-KF 100Hz` trigger port

Parent subsystem path:

`vx_vy_kkf_v2_1/K-KF 100Hz`

## E. Compiled sample-time evidence

Target-model Update Diagram evidence:

| Boundary | Actual block path | Compiled sample time |
|---|---|---:|
| K-KF parent Function-Call Subsystem | `vx_vy_kkf_v2_1/K-KF 100Hz` | `[0.01 0]` |
| Ax_IMU | `vx_vy_kkf_v2_1/Ax IMU Sensor 100Hz` | `[0.01 0]` |
| Ay_IMU | `vx_vy_kkf_v2_1/ay传感器` | `[0.01 0]` |
| AVz_IMU | `vx_vy_kkf_v2_1/AVz传感器` | `[0.01 0]` |
| raw true Vx | `vx_vy_kkf_v2_1/Gain38` | `[0.001 0]` |
| K-KF Vx measurement boundary | `vx_vy_kkf_v2_1/K-KF Vx RT 100Hz` output side | `[0.01 0]` |

The Rate Transition block reports two compiled rates because it is a
multi-rate block: input side `[0.001 0]`, output side `[0.01 0]`.

This evidence supports only:

**K-KF COMPILED IN A 100 HZ SCHEDULING DOMAIN.**

It does not establish runtime execution count or interval.

## F. Rate-transition evidence

The only newly required conversion is true Vx:

```text
vx_vy_kkf_v2_1/Gain38
    CompiledSampleTime [0.001 0]
    unit m/s after Gain=1/3.6
        -> vx_vy_kkf_v2_1/K-KF Vx RT 100Hz
             deterministic = on
             integrity = on
             input side  [0.001 0]
             output side [0.01 0]
        -> K-KF parent input 2 (z)
```

Ax_IMU, Ay_IMU, and AVz_IMU already compile at 100 Hz and were connected
directly without redundant Rate Transition blocks.

## G. Port dimensions and data types

Target Update Diagram clears dimensions/types after returning. A full target
compile reaches the pre-existing CarSim DLL load and is unavailable in this
environment. Dimensions and types were therefore read during `compile`/`term`
of an exact copy of `K-KF 100Hz` in an unsaved in-memory harness. The harness
used the same Function-Call Generator and did not execute any time step.

| Parent port | Meaning | Compiled dimension | Compiled type |
|---|---|---:|---|
| input 1 | `[Ax_IMU; Ay_IMU; AVz_IMU]` | `3` | `double` |
| input 2 | `Vx_meas` | `1` | `double` |
| input 3 | `resetFlag` | `1` | `double` |
| output 1 | `[vx_hat_K; vy_hat_K]` | `2` | `double` |
| output 2 | full covariance `P` | `2x2` | `double` |
| output 3 | diagnostic vector | `5` | `double` |

The harness parent also compiled at `[0.01 0]`, matching the target Update
Diagram evidence.

## H. Reset structure

Actual reset block path:

`vx_vy_kkf_v2_1/K-KF Reset First Call`

Static properties:

- block type: Step
- sample time: `0.01 s`
- step time: `0.01 s`
- before value: `1`
- after value: `0`
- destination: K-KF parent input 3

Design intent:

- first K-KF call: reset high;
- all calls from `t=0.01 s` onward: reset low;
- wrapper initialization: `x=[z;0]`, `P=diag([0.1,0.1])`.

**RESET STRUCTURE COMPILED / STATICALLY VERIFIED.**

**RESET RUNTIME EXECUTION WAS NOT VERIFIED.**

## I. Logging interface

All logs use Timeseries format. No log data was generated.

| Variable | Definition |
|---|---|
| `kkf_u_log1` | columns 1–4: `Ax_IMU`, `Ay_IMU`, `AVz_IMU`, `Vx_meas` |
| `kkf_x_log1` | columns 1–2: `vx_hat_K`, `vy_hat_K` |
| `kkf_P_log1` | complete `2x2` posterior covariance matrix |
| `kkf_diag_log1` | columns 1–5: `NIS`, `obs_metric`, `innovation_vx`, `K11`, `K21` |

## J. Independence audit

Exact online input order was traced at `K-KF IMU Mux`:

1. `Ax_IMU` from `Ax IMU Sensor 100Hz`;
2. `Ay_IMU` from `ay传感器`;
3. `AVz_IMU` from `AVz传感器`.

Measurement input is true Vx only, through `K-KF Vx RT 100Hz`.

Static chart inspection confirms the subsystem calls only:

`vy_kinematic_kf(u,z,resetFlag)`

The online path contains none of:

- true Vy;
- CarSim true AVz replacing AVz_IMU;
- D-EKF Vy or r_hat;
- D-EKF state, P, diagnostic, scheduler, or reliability signal;
- any dynamic-filter implementation call.

True Vy remains elsewhere in the copied plant model solely as a future
offline validation source and has no connection to K-KF.

## K. Frozen-file hash audit

| Frozen file | Before | After |
|---|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` | unchanged |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` | unchanged |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |

Created target-model hash:

`model/vx_vy_kkf_v2_1.slx` =
`B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712`

The K-KF core/wrapper hashes prove that P0, Q, R, Joseph update, state model,
measurement model, diagnostic definitions, and reset initialization were not
changed during integration.

## L. CarSim/runtime statement

No `sim(...)` call exists in the V2.1-B build, validator, or integration test.
No `SimulationCommand start`, StopTime, or Fast Restart operation exists.

Target Update Diagram succeeded. A diagnostic full-compile attempt stopped
before execution when the pre-existing CarSim S-Function requested the
unavailable module:

`G:\carsim\Programs\solvers\carsim_64.dll`

No CarSim path, dataset, S-Function, frozen model, or solver configuration was
changed. The exact K-KF subsystem was instead compile-audited in an unsaved
in-memory harness. No simulation time step or CarSim runtime occurred.

## M. Gate decision

All 22 declared gates passed.

**V2.1-B SIMULINK INTEGRATION PASSED**

## N. Next step

Ready for GPT review before V2.1 nominal runtime validation.

D-EKF V1 IS FROZEN.
K-KF V2.1 IS AN INDEPENDENT TRACK.
K-KF WAS COMPILED IN A 100 HZ SCHEDULING DOMAIN.
K-KF RUNTIME EXECUTION AT 100 HZ WAS NOT VERIFIED IN THIS TASK.
TRUE Vy WAS NOT CONNECTED TO THE ONLINE K-KF.
TRUE Vx IS TEMPORARILY USED ONLY AS THE V2.1 ISOLATION MEASUREMENT.
NO D-EKF OUTPUT WAS USED BY K-KF.
CARSIM WAS NOT RUN.
V2.2 WAS NOT STARTED.
