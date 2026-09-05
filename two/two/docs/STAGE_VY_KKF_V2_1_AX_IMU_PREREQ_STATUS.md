# STAGE VY K-KF V2.1 — AX_IMU PREREQUISITE STATUS

- Date: 2026-08-26
- Scope: create and validate `Ax_IMU` prerequisite only
- Status: **PASSED**
- K-KF status: **NOT STARTED**

## Outcome

A reliable 100 Hz longitudinal virtual-IMU signal named `Ax_IMU` was created
in an isolated model copy:

`model/vx_ax_imu_prereq_v2_1.slx`

No original model, D-EKF model, K-KF source, K-KF block, K-KF test, or K-KF
result was modified or created.

## Signal path and units

```text
vx_ax_imu_prereq_v2_1/Gain28
  clean Ax_carsim, 1 kHz, Gain=9.8, m/s^2
    -> Ax IMU Input RT 100Hz
    -> Ax IMU Sensor 100Hz
         input 1: clean Ax, m/s^2
         input 2: white noise, m/s^2
         input 3: bias, m/s^2
         input 4: reset flag
    -> Ax_IMU
         -> local Goto tag Ax_IMU
         -> ax_imu_prereq_log1
```

The clean input is explicitly rate-transitioned from the 1 kHz plant domain
to 100 Hz before entering the virtual sensor. Compiled evidence confirms:

- `Ax IMU Sensor 100Hz CompiledSampleTime = [0.01 0]`
- all three logged/branched `Ax_IMU` line handles originate from the single
  block `vx_ax_imu_prereq_v2_1/Ax IMU Sensor 100Hz`
- the sensor clean-input source is `Ax IMU Input RT 100Hz`
- output unit is m/s^2

The count of three is Simulink's representation of branches to Goto/logging;
it is not three sensors.

## Fixed prerequisite parameters

No tuning was performed. Because no separate Ax virtual-sensor parameter
specification exists, Ax uses the same acceleration-axis sensor assumptions as
the existing Ay virtual IMU:

| Parameter | Value |
|---|---:|
| sample time | `0.01 s` |
| execution rate | `100 Hz` |
| bias | `0.02 m/s^2` |
| white-noise variance | `2.5e-5 (m/s^2)^2` |
| white-noise standard deviation | `0.005 m/s^2` |
| low-pass cutoff | `20 Hz` |
| random seed | `20260820` |

The Ax seed is deliberately distinct from the existing Ay seed `20260819` to
avoid artificial cross-axis noise correlation. This is a reproducibility and
independence choice, not estimator tuning.

## Algorithm and reset behavior

The standalone implementation is `matlab/imu_ax_preprocess.m`:

```text
axMeasured = axCarsim + biasInput + whiteNoise
tau        = 1/(2*pi*20)
alpha      = 0.01/(tau + 0.01) = 0.556862724144178
axOut      = yPrev + alpha*(axMeasured - yPrev)
```

On first execution or when `resetFlag > 0.5`, `yPrev` is initialized to the
current finite `axMeasured`. All four inputs have finite guards. The model reset
source mirrors Ay: before `t=0.01 s` it is 1, then it changes to 0.

## Validation results

### Pure MATLAB unit test

`tests/test_imu_ax_preprocess.m` passed 7 checks:

1. reset initializes to the current clean+bias+noise measurement;
2. first-order low-pass recursion matches the analytical equation;
3. explicit reset replaces persistent filter state;
4. constant input remains constant;
5. NaN/Inf inputs are guarded;
6. step response remains finite and monotonic;
7. step response converges.

Result:

`AX_IMU_UNIT_TEST_OK|tests=7|Ts=0.01|fc=20|alpha=0.556862724144178`

### Simulink compilation and isolated execution

- Target model compilation: passed.
- `CompiledSampleTime`: `[0.01 0]`.
- Unique Ax sensor source: passed.
- Explicit 1 kHz-to-100 Hz rate transition: passed.
- K-KF block absence check: passed.
- Isolated Simulink harness: 21 samples over 0.20 s.
- Median sample interval: `0.01 s`.
- All output samples finite: passed.
- With clean Ax=1, noise=0, bias=0.02, output remained `1.02 m/s^2`: passed.

Final marker:

`AX_IMU_VALIDATION_OK|CST=[0.01 0]|samples=21|dt=0.01|finite=1|no_kkf=1`

An initial attempt to run the full copied CarSim model for 0.20 s was not used
as validation evidence because the pre-existing CarSim configuration requested
`G:\carsim\Programs\solvers\carsim_64.dll`, which is unavailable in the current
environment. No CarSim path, dataset, source model, or frozen model was changed
to work around that external configuration. Compilation plus the isolated
Simulink harness provide the prerequisite evidence without expanding scope.

## Integrity evidence

| File | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |

The two frozen hashes are unchanged from the prior audit.

## Files created or updated

Created:

- `matlab/imu_ax_preprocess.m`
- `tests/test_imu_ax_preprocess.m`
- `matlab/build_ax_imu_prereq_v2_1_model.m`
- `matlab/validate_ax_imu_prereq_v2_1.m`
- `model/vx_ax_imu_prereq_v2_1.slx`
- `results/ax_imu_prereq_v2_1_validation.mat`
- `docs/STAGE_VY_KKF_V2_1_AX_IMU_PREREQ_STATUS.md`

Updated:

- `docs/STAGE_VY_KKF_V2_1_STATUS.md` (prerequisite-status addendum only)

## Scope stop

The mandatory `Ax_IMU` prerequisite is ready in the isolated copy. This task
stops here. It does not authorize K-KF implementation, nominal K-KF simulation,
K-KF tuning, V2.2, or any D-EKF change.

**D-EKF V1 IS FROZEN.**

**AX_IMU PREREQUISITE IS READY.**

**K-KF WAS NOT STARTED.**
