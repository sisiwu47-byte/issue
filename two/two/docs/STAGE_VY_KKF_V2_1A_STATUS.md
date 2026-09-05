# STAGE VY K-KF V2.1-A STATUS

- Date: 2026-08-26
- Stage: V2.1-A K-KF MATLAB core + wrapper + unit tests
- Status: **PASSED**
- Simulink K-KF integration: **NOT STARTED**
- CarSim execution: **NOT RUN**

## Outcome

The independent kinematic Kalman-filter MATLAB core, persistent wrapper, and
pure MATLAB unit-test suite were implemented and validated. Work stopped at
the V2.1-A boundary. No Simulink K-KF model, CarSim run, nominal analysis,
plot, tuning, or V2.2 work was performed.

## Core interface and equations

File: `matlab/vy_kinematic_kf_step.m`

```matlab
[x_new, P_new, info] = vy_kinematic_kf_step(x, P, u, z, cfg)
```

Fixed layout:

- `x = [vx; vy]`
- `u = [Ax; Ay; r]`
- `z = Vx` scalar measurement
- `H = [1 0]`

The implemented 100 Hz Euler prediction is:

```text
F      = [1, r*Ts; -r*Ts, 1]
x_pred = F*x + Ts*[Ax; Ay]
P_pred = F*P*F' + Q_K
```

The scalar Vx update uses right division by `S`; neither the core nor wrapper
forms an explicit inverse. Covariance uses the Joseph update:

```text
I_KH  = I - K*H
P_new = I_KH*P_pred*I_KH' + K*R_Vx*K'
```

The result is explicitly symmetrized only to remove floating-point roundoff.

## Fixed baseline configuration

No parameter tuning was performed.

| Parameter | Value |
|---|---:|
| `Ts` | `0.01 s` |
| `P0` | `diag([0.1, 0.1])` |
| `Q_K` | `diag([1e-4, 1e-3])` |
| `R_Vx` | `1e-4` |
| `H` | `[1 0]` |

`R_Vx` remains an isolation-baseline value for a true-Vx measurement and is
not interpreted as a final `vx_hat` covariance.

## Core diagnostic output

`info` contains:

- `x_pred`
- `P_pred`
- `innovation`
- `S`
- `K`
- `NIS`
- `obs_metric = abs(r)`
- `obs_flag = abs(r) > 0.01`
- `F`
- `H`

`obs_flag` is diagnostic only and does not change prediction, measurement
update, gain, covariance, or any filter state.

## Persistent wrapper and reset

File: `matlab/vy_kinematic_kf.m`

```matlab
[x_new, P_new, diag_out] = vy_kinematic_kf(u, z, resetFlag)
```

The wrapper owns persistent `xState` and `PState`. On empty persistent state or
`resetFlag > 0.5`, it initializes:

```text
xState = [z; 0]
PState = diag([0.1, 0.1])
```

The current sample then follows the normal core prediction/update path. This
provides deterministic run isolation without a separate bypass equation.

Fixed diagnostic layout:

```text
diag_out(1) = NIS
diag_out(2) = obs_metric
diag_out(3) = innovation_vx
diag_out(4) = K11
diag_out(5) = K21
```

## Unit-test results

Test files:

- `tests/test_vy_kinematic_kf_step.m`
- `tests/test_vy_kinematic_kf_wrapper.m`
- `tests/run_vy_kkf_v2_1a_unit_tests.m`

### Core: 13 checks passed

The core tests cover:

1. `r=0`, `Ax=Ay=0` state propagation;
2. `r=0` gives `obs_metric=0` and a false diagnostic flag;
3. nonzero `r` gives exact `abs(r)` and exact Euler `F`;
4. `H` is strictly `[1 0]`;
5. posterior covariance symmetry;
6. posterior covariance positive definiteness;
7. independent Joseph-form reconstruction;
8. finite state/covariance/innovation/gain/NIS outputs;
9. scalar NIS equation;
10. Ax/Ay input order and Euler prediction;
11. rejection of a vector measurement;
12. five-input interface and static truth/dynamic-filter isolation;
13. 500 deterministic randomized sequential updates remain finite,
    symmetric, and positive definite.

Core marker:

```text
K_KF_CORE_TEST_OK|tests=13|minEig=9.99001996007984e-05|symErr=0|josephErr=0
```

### Wrapper: 7 checks passed

The wrapper tests cover direct equivalence to the core, fixed diagnostic
layout, persistent advancement, explicit-reset reproducibility, fresh-run
initialization, interface/dependency isolation, and observability diagnostic
mapping.

Wrapper marker:

```text
K_KF_WRAPPER_TEST_OK|tests=7|resetXErr=0|resetPErr=0|diag=5
```

Combined marker:

```text
V2_1A_TEST_SUITE_OK|total=20|simulink=0|carsim=0
```

The machine-readable report is
`results/vy_kkf_v2_1a_unit_tests.mat`.

## Independence and scope checks

- The core accepts only `x`, `P`, `[Ax;Ay;r]`, scalar Vx measurement, and cfg.
- The wrapper accepts only `[Ax_IMU;Ay_IMU;AVz_IMU]`, scalar Vx, and reset.
- Offline lateral truth is absent from both implementations.
- No dynamic-filter source, output, state, covariance, or diagnostic is used.
- No `inv(...)` is used.
- No Simulink API or CarSim call exists in the V2.1-A implementation/tests.
- `model/vx_vy_kkf_v2_1.slx` was not created.
- K-KF run/analyze scripts and nominal result files were not created.

## Frozen-file integrity

| File | SHA-256 after V2.1-A |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |

All three hashes are unchanged from the prerequisite handoff.

## Files created or updated

Created:

- `matlab/vy_kinematic_kf_step.m`
- `matlab/vy_kinematic_kf.m`
- `tests/test_vy_kinematic_kf_step.m`
- `tests/test_vy_kinematic_kf_wrapper.m`
- `tests/run_vy_kkf_v2_1a_unit_tests.m`
- `results/vy_kkf_v2_1a_unit_tests.mat`
- `docs/STAGE_VY_KKF_V2_1A_STATUS.md`

Updated:

- `docs/STAGE_VY_KKF_V2_1_STATUS.md` (V2.1-A status addendum only)

## Decision and stop

V2.1-A qualifies the MATLAB core and wrapper for a later, separately authorized
Simulink integration stage. It does not validate vehicle-level tracking,
100 Hz Function-Call execution, nominal performance, observability-region
metrics, or NIS consistency in CarSim.

This task stops here.

**D-EKF V1 IS FROZEN.**

**K-KF V2.1-A MATLAB CORE IS INDEPENDENT.**

**SIMULINK K-KF INTEGRATION WAS NOT STARTED.**

**CARSIM WAS NOT RUN.**
