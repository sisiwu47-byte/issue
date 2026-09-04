# STAGE VY K-KF V2.1-F EXCITATION AUDIT STATUS

- Date: 2026-08-26
- Stage: V2.1-F Excitation Command Path Audit
- Scope: static/configuration-path audit only
- Simulation performed in this audit: **NO**
- CarSim run performed in this audit: **NO**
- Final Sol conclusion: **V2.1-F CONFIGURED STEERING PARAMETER IS NOT THE ACTIVE EXCITATION SOURCE**

## A. Executive finding

The C1 and E run scripts assign different values to a MATLAB report field and
to workspace variables named `test_steer_amplitude`, but the frozen target
model contains no reference to `test_steer_amplitude`,
`test_steer_frequency`, or `test_speed`. The values are therefore visible in
both the model and base workspaces before `sim()`, but are not consumed by a
Simulink block, controller, initialization callback, CarSim parameter, or
CarSim dataset entry.

The active CarSim interface instead imports four **road-wheel steer** channels.
In the frozen model's selected input branch, front-left and front-right steer
come from `Gain22`, whose input is unconnected and therefore supplies zero;
rear-left and rear-right steer come from `Constant10 = 0`. This is distinct
from steering-wheel angle and from steering-like controller signals elsewhere
in the model.

`0.04 RAD WAS METADATA/UNUSED CONFIGURATION, NOT VERIFIED VEHICLE INPUT.`

## B. Exact C1 versus E run-script diff

The complete source diff contains these changes and no connected excitation
implementation change:

1. Function name/comment: `run_vy_kkf_v2_1c1_nominal` / nominal wording became
   `run_vy_kkf_v2_1e_highyaw` / high-yaw wording.
2. Result path changed from `results/vy_kkf_v2_1c1_nominal.mat` to
   `results/vy_kkf_v2_1e_highyaw.mat`.
3. `report.stage` changed from C1 nominal to V2.1-E high-yaw.
4. Lines 37-38 changed
   `report.nominal.steerAmplitude_rad = 0.02` to
   `report.condition.steerAmplitude_rad = 0.04`; frequency remained `0.4 Hz`,
   speed remained `20 m/s`, and E added `caseCount = 1`.
5. C1 `qrTuningPerformed = false` became E
   `qrP0TuningPerformed = false`, with the additional E scope flags
   `onlineBiasCorrectionImplemented = false`, `fusionPerformed = false`, and
   `v2_2Started = false`.
6. Cache/code-generation temporary folder suffixes changed from `v2_1c1` to
   `v2_1e`.
7. Lines 94-99 in E assign `test_speed`, `test_steer_amplitude`, and
   `test_steer_frequency` from `report.condition` instead of C1's
   `report.nominal`, in both the model workspace and base workspace.
8. Runtime-only reset/true-Vx/true-Vy logging names changed from the C1 suffix
   to the E suffix; the four K-KF output logs are unchanged.
9. Runtime error identifiers/messages, assertions, and console label changed
   from C1 to E wording.

The `0.02 -> 0.04` change is not a block parameter, `SimulationInput`
variable, CarSim parameter, dataset field, controller reference, or external
input. It is:

- a MATLAB structure field used as result metadata; and
- a value copied to same-named variables in the target model workspace and
  MATLAB base workspace.

These assignments occur before `sim()` (E lines 94-99; `sim()` starts at line
114), so they are not post-run-only writes. Their only demonstrated effect is
metadata/workspace population because no runtime consumer exists.

## C. Consumption and workspace audit

Static inspection of all files inside the frozen target SLX archive found zero
occurrences of:

```text
test_steer_amplitude
test_steer_frequency
test_speed
```

The target archive also contains no callback, initialization expression, model
workspace source, or data-dictionary reference that consumes or rewrites these
names. The run scripts contain no `Simulink.SimulationInput`, `setVariable`, or
steering-related `set_param` call.

Therefore:

- Simulink block consumer: **NONE**
- controller consumer: **NONE**
- CarSim consumer: **NONE**
- initialization-script/callback consumer: **NONE**
- later overwrite of `0.04` back to a fixed value: **NONE FOUND**
- workspace visibility defect: **NO**; the value is deliberately placed in
  both model and base workspaces before runtime
- actual defect: **the visible variable is unused by the active model path**

The cleanup routine clears the base-workspace variables only after the runtime
section; this is cleanup, not an excitation override.

## D. Actual steering source and physical meaning

The frozen target topology is:

```text
vx_vy_kkf_v2_1/Mux6 (four ZGND zeros)
                         \
                          vx_vy_kkf_v2_1/Mux7 [4,12]
                         /                     |
vx_vy_kkf_v2_1/Manual Switch1                 v
  selected Mux8 branch                 CarSim S-Function input u (16 channels)
```

The selected 12-channel `Mux8` branch maps to the CarSim import dataset as
follows for steering:

| CarSim channel | Physical quantity | Frozen Simulink source |
|---|---|---|
| `IMP_STEER_L1` | front-left road-wheel steer | `Gain22`, gain `180/pi`, input unconnected -> zero |
| `IMP_STEER_R1` | front-right road-wheel steer | same `Gain22` output -> zero |
| `IMP_STEER_L2` | rear-left road-wheel steer | `Constant10 = 0` |
| `IMP_STEER_R2` | rear-right road-wheel steer | `Constant10 = 0` |

`Manual Switch1` has `CurrentSetting = 0`, selecting its lower/second input,
the un-commented `Mux8` branch. Its alternate `Mux5` branch contains older
steering/controller paths whose immediate source blocks are commented on.

The CarSim configuration confirms:

- `model/simfile.sim`: `PORTS_IMP 1,16`, with the active input archive
  `Run_all.par`.
- `Run_all.par`: `opt_steer_ext(1) = 4` and `opt_steer_ext(2) = 4`.
- CarSim import dataset `zidongjiashia2`: all four
  `IMP_STEER_L1/R1/L2/R2` use `Replace 0.0! 1`.

Thus the active vehicle excitation source is the **Simulink external road-wheel
steer import vector**, not the run-script amplitude and not a CarSim internal
driver profile. The loaded CarSim procedure is `DLC Low Friction` and includes
a straight-path definition and a speed controller, but the steering system is
configured for the four external imported road-wheel angles above.

CarSim's exported `Steer_SW` is steering-wheel angle feedback. It is not the
command source. `Steer_L1/R1/L2/R2` are road-wheel steer exports and must not be
confused with steering-wheel angle or a controller reference.

## E. Controller-override audit

The target contains steering-like controller signals, including Goto tags
`driver_steering5` and `driver_steering10`. They do not match the separate
`driver_steering` From tag and do not feed the selected CarSim steering import
ports. The un-commented `driver_steering` From block itself has no outgoing
line; a second From block with that tag is commented on.

Consequently, no controller was found overriding `0.04` or saturating it back
to the C1 value. The stronger finding is that `0.04` never enters a controller
reference or actuator-command path. C1 and E can therefore have identical
vehicle steering without any numerical controller override.

## F. MAT runtime-log audit

The HDF5 object trees of both MAT files were read directly. Their raw runtime
records contain only:

- `kkf_u_log1`
- `kkf_x_log1`
- `kkf_P_log1`
- `kkf_diag_log1`
- stage-specific reset trace
- offline true Vx
- offline true Vy

Neither MAT contains a runtime series for steering command, steering-wheel
angle, or any road-wheel steer angle. The only steering-named objects are
metadata:

```text
C1 report.nominal.steerAmplitude_rad   = 0.02
C1 report.nominal.steerFrequency_Hz    = 0.4
E  report.condition.steerAmplitude_rad = 0.04
E  report.condition.steerFrequency_Hz  = 0.4
```

`ACTUAL STEERING RUNTIME SIGNAL WAS NOT LOGGED IN C1/E.`

Accordingly, steering maxAbs, RMS, and time-series difference metrics cannot
be computed from the authorized existing evidence. `AVz_IMU` was not used as
a substitute for an actual steering log.

## G. Answers to the ten required questions

1. **Actual run-script differences:** listed completely in section B. The only
   intended excitation change is the metadata/workspace value `0.02 -> 0.04`;
   no connected input-path change exists.
2. **What object was set:** `report.nominal/condition.steerAmplitude_rad` and
   `test_steer_amplitude` in the model and base workspaces. No block, controller,
   CarSim, or dataset parameter was set.
3. **Was it consumed:** no. The frozen target has zero references to the three
   `test_*` variables.
4. **True steering source:** CarSim external road-wheel imports. In the selected
   model branch, front road-wheel steer is zero from unconnected `Gain22` and
   rear road-wheel steer is zero from `Constant10`.
5. **Override:** no later value overwrite or active controller override was
   found. The configured value is bypassed/unused.
6. **Workspace visibility:** no visibility problem. Both base and model
   workspaces receive the value before `sim()`; no consumer requests it.
7. **Another CarSim internal path:** no active internal steering profile was
   identified. CarSim is configured to replace all four road-wheel steer
   channels from the Simulink import vector; that vector is a different path
   from the MATLAB test variable.
8. **Existing steering runtime log:** no.
   `ACTUAL STEERING RUNTIME SIGNAL WAS NOT LOGGED IN C1/E.`
9. **Why AVz_IMU did not change:** C1 and E drove the same active steering
   interface values because the changed workspace variable was unreferenced.
   Identical plant excitation therefore explains the identical AVz_IMU and
   downstream K-KF/replay results.
10. **Minimum future repair location:** the active Simulink-to-CarSim input
    configuration and its run-script injection, plus runtime logging. A future
    authorized repair must drive the actual `IMP_STEER_L1/R1` (and, if intended,
    L2/R2) road-wheel channels from an explicitly parameterized connected
    source, set that source from the run configuration, and log the resulting
    `Steer_SW` and/or `Steer_L1/R1/L2/R2`. It is not a K-KF, sensor, Q/R, or
    offline-analysis repair. No repair was performed here.

## H. Frozen hashes

All frozen SHA-256 values were independently recomputed during this audit and
match the established baselines:

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

No frozen file was modified.

## I. Final Sol decision

**V2.1-F CONFIGURED STEERING PARAMETER IS NOT THE ACTIVE EXCITATION SOURCE**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

NO K-KF PARAMETER WAS CHANGED.

NO SENSOR BIAS CORRECTION WAS IMPLEMENTED.

NO SIMULATION OR CARSIM RUN WAS PERFORMED IN THIS AUDIT.

NO FUSION WAS PERFORMED.

V2.2 WAS NOT STARTED.
