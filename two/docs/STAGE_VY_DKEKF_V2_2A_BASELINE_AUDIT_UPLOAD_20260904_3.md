# STAGE VY DK-EKF V2.2-A BASELINE DESIGN AUDIT

- Date: 2026-08-26
- Scope: architecture/fairness audit only
- Simulation / CarSim: **NOT RUN**
- Existing model or algorithm modification: **NONE**
- Final decision: **V2.2-A EXISTING DK-EKF NOT SUITABLE AS-IS — MINIMUM BASELINE DESIGN REQUIRED**

## 1. Search result and candidate classification

A targeted search used only the requested DK-EKF/DKEKF,
dynamic-kinematic, combined-EKF, reference-estimator, baseline-estimator, and
`vx_vy` terms. Candidate SLX internals and their directly called estimator
files were then read without compiling, updating, saving, or simulating any
model.

No file, block, function call, status document, or validation script contains
an implemented DK-EKF/DKEKF/combined dynamic-kinematic estimator. The relevant
existing estimators are two separate frozen tracks:

1. D-EKF V1.17: `model/vx_vy_dekf_v1_17.slx`, calling
   `vy_dynamic_ekf_v1_17` and its V1.17/V1.13 step functions.
2. K-KF V2.1: `model/vx_vy_kkf_v2_1.slx`, calling the independent
   `vy_kinematic_kf` wrapper/core.

The D-EKF historical SLX copies contain only `Vy D-EKF 100Hz`; the K-KF SLX
contains only `K-KF 100Hz`. There is no shared state, shared covariance,
cross-update, pseudo measurement, state injection, or combined output between
them. The closest existing candidate is therefore the frozen D-EKF, but it is
not a DK-EKF and must remain classified as the D-EKF comparison track.

## 2. Architecture table

The table documents the actual closest existing candidate, not a presumed
DK-EKF.

| Item | Existing candidate: frozen D-EKF V1.17 |
|---|---|
| Exact model | `model/vx_vy_dekf_v1_17.slx` |
| Direct estimator | `model/vy_dynamic_ekf_v1_17.m` |
| Prediction/update cores | `model/vy_dynamic_ekf_step_v17.m`, `model/vy_dynamic_ekf_step_v13.m` |
| State | `[vy; r]` |
| State dimension/order | 2; lateral velocity first, yaw rate second |
| Initial state | `[0;0]` on empty persistent state or mode change |
| Prediction | dynamic tire-force model only; `vy_dot=sum(Fy)/m-vx*r`, `r_dot=(a*Fy_front-b*Fy_rear)/Iz` |
| Kinematic prediction | none; no `vx_dot=ax+r*vy` state equation |
| Measurements | `[Ay_IMU; AVz_IMU]` |
| Measurement equations | `h_Ay=sum(Fy)/m`; `h_r=r` |
| D/K coupling | none; no K subfilter or unified D/K state exists |
| Pseudo measurement | none |
| State injection / feedback | none between D-EKF and K-KF |
| Shared covariance | none; D-EKF has its own `2x2 P` |
| Weighted fusion / switching | none |
| Vx source | CarSim true Vx via `Gain38=1/3.6`, signal `vx_carsim`, Goto tag `Vx`, `From32` |
| Vx role | exogenous online D-EKF model input, not a D-EKF state |
| Steering source | four actual CarSim road-wheel angles `[FL FR RL RR]`, radians |
| Vy truth online | no; `vy_true_log1` is an offline-validation log only |
| Scheduler | `D-EKF 100Hz Scheduler`, Function-Call Generator, `sample_time=0.01`, one iteration |
| Input rate boundary | combined Mux9 1 kHz vector through deterministic/integrity-on `D-EKF Input RT 100Hz` |
| Prediction/r update rate | 100 Hz |
| Ay update rate | wrapper supports 100/50/20 Hz; actual saved model workspace value is 100, while the frozen V1 selection documented for validation is A20 via runtime override |
| Output boundary | deterministic/integrity-on `D-EKF Output RT 1kHz`, held between 100 Hz calls |
| Reset | no explicit reset input; persistent state resets on empty state or mode change |
| Q | `diag([1e-4,1e-4])`, hardcoded |
| R | `diag([1e-2,3.365172961808e-4])`, hardcoded for Ay/r |
| P0 | `0.1*eye(2)`, hardcoded |
| Other fixed parameters | `m=1860`, `Iz=2687.1`, `a=1.18`, `b=1.77`, `track=1.575`, `Rw=0.393`, `k_f=0.78181`, `k_r=1.09186` |
| Outputs | state `[vy_hat;r_hat]`, `2x2 P`, 65 diagnostics |
| Runtime logs | `est_y_log1`, `est_P_log1`, `est_diag_log1`, `est_u_log1`, `est_z_log1`; `vy_true_log1` offline only |
| Existing diagnostics | NIS, innovation, F/H/S/K, prior/posterior P, tire forces/slips, update mode/count/contraction |
| LifeSig/reliability/adaptive fusion | none |

The saved model's A100 workspace default versus the documented final A20
runtime selection must be made explicit in any future D-EKF comparison run.
This is a reproducibility configuration boundary, not evidence of a DK-EKF.

## 3. Actual online measurement audit

| Input/measurement | Actual source | Unit | Effective estimator rate | Equation/use | Preprocess |
|---|---|---|---:|---|---|
| Vx | CarSim true Vx through `Gain38=1/3.6`, `vx_carsim` | m/s | 100 Hz after input RT | exogenous tire-slip/dynamic-model input | km/h to m/s gain; deterministic Rate Transition |
| FL/FR/RL/RR steer | CarSim returned road-wheel steer signals | rad | 100 Hz after input RT | tire slip angles and lateral forces | combined vector Rate Transition |
| Ay_IMU | existing virtual Ay sensor subsystem | m/s^2 | available at 100 Hz; assimilated at selected 100/50/20 Hz | `z_Ay`, compared with `sum(Fy)/m` | existing virtual-sensor processing only; no wrapper bias removal |
| AVz_IMU | existing virtual yaw-rate sensor subsystem | rad/s | 100 Hz | `z_r`, compared with state `r` | existing virtual-sensor processing only; no wrapper bias removal |

The current D-EKF does not use Ax, wheel speed, true Vy, true beta, or true
lateral-acceleration truth as an online measurement. True Vy is logged only
for offline error calculation. The Vx input is explicitly CarSim truth, as in
the isolation-stage assumptions; it is not a longitudinal estimator output.

## 4. Dynamic/kinematic coupling finding

Actual existing structure:

```text
CarSim true Vx + four road-wheel angles
        -> D-EKF dynamic tire-force prediction for [vy,r]
Ay_IMU / AVz_IMU
        -> D-EKF measurement update
        -> [vy_D, r_D], P_D, diagnostics

Ax_IMU / Ay_IMU / AVz_IMU + true-Vx isolation measurement
        -> independent K-KF prediction/update
        -> [vx_K, vy_K], P_K, diagnostics
```

There is no connection between the two estimators. This is neither a unified
DK-EKF nor two cross-updating filters. It is also not simple D/K fusion. The
same files cannot be counted both as a DK-EKF baseline and later as a simple
D/K fusion comparison.

## 5. Fairness table

| Criterion | PASS/FAIL | Evidence |
|---|---|---|
| No true Vy online | PASS | D-EKF and K-KF paths do not consume true Vy; it is offline validation only |
| No other unreasonable lateral truth online | PASS | Ay/AVz are virtual sensors and steering is actual road-wheel feedback; no true beta or true lateral acceleration is injected |
| Comparable Vx source | PASS WITH SCOPE NOTE | D-EKF uses CarSim true Vx and K-KF uses the same temporary true-Vx isolation concept; future baseline must declare this explicitly |
| Comparable sensor set for a DK estimator | FAIL | existing D-EKF lacks Ax/kinematic Vx state and existing K-KF lacks dynamic tire-force state; no estimator uses the necessary joint input set |
| Comparable sample rate | FAIL AS DK BASELINE | each separate track is scheduled, but no joint scheduler exists; D-EKF Ay mode also requires explicit A20 selection rather than relying on saved A100 default |
| No future-fusion feature leakage | PASS | no D/K weighted fusion or adaptive multi-track feature exists |
| No LifeSig leakage | PASS | no LifeSig implementation exists |
| No adaptive fusion leakage | PASS | no adaptive covariance fusion exists |
| Reproducible Q/R/P0 | PASS | D-EKF and K-KF parameter sets are fixed and documented; they remain separate parameter sets |
| Clear final Vy output | PASS FOR EACH SEPARATE TRACK | `vy_D` and `vy_K` exist independently, but no `vy_DK` output exists |
| Genuine combined dynamic/kinematic estimator | FAIL | no shared state/covariance, sequential cross-update, pseudo measurement, or state injection exists |
| Suitable traditional DK-EKF baseline as-is | FAIL | the candidate is only the already-counted D-EKF comparison track |

Overall fairness decision: **NOT FAIR AS A DK-EKF BASELINE**. The problem is
not truth leakage or an overly advanced feature; it is the absence of a real
joint DK estimator and a unique DK output/covariance.

## 6. Minimum necessary DK-EKF baseline design

The next stage should implement one isolated, unified EKF without modifying
the frozen D-EKF or K-KF.

### State, reset, and covariance

```text
x_DK = [vx; vy; r]
state dimension/order = 3, [vx, vy, yaw rate]
x0 = [Vx_meas; 0; 0]
P0_DK = diag([0.1,0.1,0.1])
```

Use an explicit first-call reset at `t=0`; do not depend solely on uncleared
persistent state.

### Unified prediction

Reuse the verified K-KF longitudinal kinematics and frozen D-EKF tire-force
dynamics in one shared state/covariance:

```text
vx_dot = Ax_IMU + r*vy
vy_dot = (Fy_FL*cos(delta_FL) + Fy_FR*cos(delta_FR)
          + Fy_RL + Fy_RR)/m - r*vx
r_dot  = (a*(Fy_FL*cos(delta_FL) + Fy_FR*cos(delta_FR))
          - b*(Fy_RL + Fy_RR))/Iz
```

The tire-force/slip calculation uses the unified `[vx,vy,r]` state and actual
four-wheel steering. One EKF prediction advances all three states and one
`3x3 P`; numerical Jacobians may reuse the proven D-EKF approach. There is no
separate D/K state injection or post-hoc weighted average.

### Sequential measurements

Use Joseph-form updates on the same shared covariance:

| Measurement | Equation | Initial R | Update rate |
|---|---|---:|---:|
| Vx measurement | `h_Vx=x(1)` | `1e-4` | 100 Hz |
| AVz_IMU | `h_r=x(3)` | `3.365172961808e-4` | 100 Hz |
| Ay_IMU | `h_Ay=sum(Fy)/m` | `1e-2` | 20 Hz, matching frozen D-EKF A20 selection |

No true Vy, pseudo-Vy measurement, state injection, bias estimator, LifeSig,
or adaptive covariance is allowed. True Vx remains the explicitly temporary
isolation measurement unless a later separately authorized longitudinal
source replacement is made.

### Initial process covariance strategy

Without tuning, map the accepted per-state values by model origin:

```text
Q_DK = diag([1e-4,1e-4,1e-4])
         vx: K-KF accepted value
         vy/r: D-EKF accepted values
```

This is a traceable initial baseline, not an optimized parameter claim.

### Required inputs and scheduler

| Input | Unit | Required estimator boundary |
|---|---|---|
| Ax_IMU | m/s^2 | explicit 100 Hz input |
| Vx_meas | m/s | explicit 100 Hz boundary from current isolation source |
| Ay_IMU | m/s^2 | 100 Hz signal, assimilated every fifth call |
| AVz_IMU | rad/s | 100 Hz |
| FL/FR/RL/RR road-wheel steer | rad | explicit deterministic 1 kHz-to-100 Hz boundary if sourced at plant rate |

Use one local 100 Hz Function-Call Scheduler. Prediction, Vx update, and yaw
update run every call; Ay update runs every fifth call. Any 1 kHz CarSim signal
must cross a named deterministic/integrity-on Rate Transition before entering
the estimator. Do not connect 1 kHz truth directly to a 100 Hz estimator.

### Outputs and baseline diagnostics

```text
x_DK = [vx_hat_DK; vy_hat_DK; r_hat_DK]
P_DK = complete 3x3 covariance
diagnostics = innovations, per-update NIS, gains, update flags,
              prediction/update finite status
```

Required logs should retain estimator inputs, state, full covariance, and
diagnostics. These are validation diagnostics only; no reliability score,
LifeSig, hard switch, fusion weight, or adaptive covariance is part of this
baseline.

## 7. DK-EKF versus future simple D/K fusion

The minimum DK-EKF baseline is a **single unified state and covariance** with
dynamic and kinematic equations inside one EKF. Future simple D/K fusion is a
separate comparison that combines the already-frozen `vy_D` and `vy_K`
outputs. A fixed or adaptive weighted average of those outputs must not be
classified as the DK-EKF baseline.

## 8. Frozen integrity

Read-only SHA-256 confirmation after the audit:

| Frozen file | SHA-256 | Status |
|---|---|---|
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | unchanged |
| `model/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | unchanged |
| `model/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | unchanged |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | unchanged |
| `model/vx_vy_kkf_v2_1g_steer.slx` | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | unchanged |

No existing file was modified. No simulation, CarSim run, Q/R tuning, online
bias correction, fusion, LifeSig, or adaptive covariance fusion was performed.

## 9. Next minimum task

The next stage is limited to implementing and statically/unit validating the
isolated **minimum necessary unified `[vx,vy,r]` DK-EKF baseline** defined
above. It must create a new track without editing D-EKF V1 or K-KF V2.1 and
must stop before simple D/K fusion or adaptive multi-track fusion.

## 10. Final decision

**V2.2-A EXISTING DK-EKF NOT SUITABLE AS-IS — MINIMUM BASELINE DESIGN REQUIRED**

NO SIMULATION.

NO CARSIM.

NO MODEL MODIFICATION.

NO D-EKF MODIFICATION.

NO K-KF MODIFICATION.

NO Q/R TUNING.

NO ONLINE BIAS CORRECTION.

NO FUSION.

NO LIFESIG IMPLEMENTATION.

NO ADAPTIVE COVARIANCE FUSION.
