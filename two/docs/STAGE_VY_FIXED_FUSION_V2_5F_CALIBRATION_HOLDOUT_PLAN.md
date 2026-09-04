# V2.5-F Fixed-Weight Calibration / Holdout Suite Design and Data Registry

## Stage decision

**V2.5-F FIXED-WEIGHT CALIBRATION / HOLDOUT SUITE DESIGN ACCEPTED**

This stage performed read-only model/evidence inspection and pre-registered future runs. No MATLAB runtime, simulation, CarSim, optimizer, alpha calculation, runner execution, holdout generation, model modification, or new SLX was used.

Machine-readable plans:

- `results/vy_fixed_fusion_v2_5f_suite_plan.csv`
- `results/vy_fixed_fusion_v2_5f_run_registry.csv`

## 1. Actual maneuver-parameterization audit

The formal target was inspected directly from its SLX ZIP/XML representation. Existing V2.1-G1, V2.2-D2, V2.3-D, and V2.5-D runners/status evidence was used to distinguish active consumers from metadata.

| Variable | Classification | Actual evidence and consequence |
|---|---|---|
| Longitudinal speed / Vx reference | **NOT CURRENTLY PARAMETERIZABLE** | Existing runners assign `test_speed`, but the formal SLX contains no `test_speed` consumer. Vehicle speed is governed by the active CarSim dataset/configuration. Changing the reliable operating-speed class requires a separately authorized CarSim/speed interface stage. |
| Steering amplitude | **PARAMETERIZABLE WITHOUT MODEL CHANGE** | `G0 Steer Cmd Rad` has `Amplitude=test_steer_amplitude`, and the runner can assign that workspace value before runtime. |
| Steering frequency | **PARAMETERIZABLE WITHOUT MODEL CHANGE** | `G0 Steer Cmd Rad` has `Frequency=2*pi*test_steer_frequency`, with an active workspace consumer. |
| Simulation duration | **PARAMETERIZABLE WITHOUT MODEL CHANGE** | Existing accepted runners pass `StopTime` to `sim`; 16 s has completed repeatedly. No saved model edit is required. |
| Steering waveform family | **NOT CURRENTLY PARAMETERIZABLE** | The active block is a fixed Simulink `Sin` block. A step, chirp, DLC, or random-steer source would require model/maneuver development. |
| Front/rear routing | **NOT CURRENTLY PARAMETERIZABLE** | Active structure is fixed: sine rad command → `Gain22=180/pi` → `Mux8` ports 2/4 → selected `Manual Switch1` leg → CarSim FL/FR. `Constant10=0` drives rear ports 6/8. |
| CarSim maneuver/config selector | **NOT CURRENTLY PARAMETERIZABLE** | The CarSim block is bound to `SIMFILE=simfile.sim`; the validated runtime context is selected by working directory and the current D: CarSim dataset. No workspace maneuver-selector consumer was found. |
| Runner/workspace-only condition change | **PARTIAL** | Amplitude, frequency, and duration can be changed without an SLX edit. Speed class, waveform family, wheel-routing policy, and CarSim dataset cannot. |

The formal fixed-weight baseline scope is therefore explicitly limited to the **current verified approximately 20 m/s CarSim operating-speed class**. V2.5-F does not claim wide-speed calibration.

## 2. Historical runtime evidence used only for range design

| Evidence | Actual verified condition | Role in V2.5-F |
|---|---|---|
| K-KF V2.1-G1 A | ~20 m/s class, 0.02 rad, 0.4 Hz, 16 s, genuine front steering | development/range evidence only |
| K-KF V2.1-G1 B | ~20 m/s class, 0.04 rad, 0.4 Hz, 16 s, genuine front steering | verified high-yaw envelope boundary only |
| DK-EKF V2.2-D2 | ~20 m/s class, 0.02 rad, 0.4 Hz, 16 s | development/range evidence only |
| Parallel D/K V2.3-D | ~20 m/s class, 0.02 rad, 0.4 Hz, 16 s | development/range evidence only |
| Fixed fusion V2.5-D | same class/configuration, 0.02 rad/0.4 Hz source, 0.20 s | execution preflight only |

No multiple-speed runtime and no frequency other than 0.4 Hz has been accepted as runtime evidence. Planned 0.30–0.50-Hz conditions are therefore clearly marked as new calibration acquisition conditions, not previously verified results.

The planned envelope is conservative relative to the genuine G1-B boundary:

```text
maximum planned steering amplitude = 0.04 rad
maximum planned peak steering rate = 2*pi*0.04*0.4
                                   = 0.100530964914874 rad/s
```

Every planned calibration and holdout combination has amplitude no greater than 0.04 rad and peak steering rate no greater than that already realized boundary. This is a pre-registration safety rationale, not runtime acceptance; V2.5-G must still enforce per-run steering and completion gates.

Historical MAT files remain excluded from formal alpha fitting:

| Historical result | SHA-256 | Classification |
|---|---|---|
| `vy_kkf_v2_1g1_nominal_002.mat` | `99232BD741E2226A3FF05D4FBCFF3BD25C2962E6D2D673737A9975FF652535D3` | DEVELOPMENT_EVIDENCE |
| `vy_kkf_v2_1g1_highyaw_004.mat` | `9966A0D090222F50E8A983AD789EFA736622EBD5751EF746833C79B336D17060` | DEVELOPMENT_EVIDENCE |
| `vy_dkekf_v2_2d2_nominal_validation.mat` | `B8F390F9DE81AFEEEB0141E9266F5D0E7C76AC9D28D1138C143E78DFE969E57B` | DEVELOPMENT_EVIDENCE |
| `vy_parallel_dk_v2_3d_nominal_validation.mat` | `AB65F66E0F6963ACF417079FA570C3B3582791CC946DCF48764A83B99807883C` | DEVELOPMENT_EVIDENCE |
| `vy_fixed_fusion_v2_5d_preflight.mat` | `63F233D9B0B444EDCA7C332F522AF9A588EB3A9C6F0E5FD9718CA5BEA09184F8` | EXECUTION_PREFLIGHT |

**FORMAL ALPHA FITTING USES DEDICATED NEW CALIBRATION RUNS ONLY.**

## 3. Exact pre-registered calibration suite

All calibration runs use the current fixed CarSim speed class, equal front-wheel sine steering, zero rear steering, 16 s, and 100-Hz estimator streams.

| Run ID | Role | Vx setting | Amplitude | Frequency | Waveform | Duration | Rate | Status |
|---|---|---|---:|---:|---|---:|---:|---|
| FWCAL_C01 | CALIBRATION_ONLY | current ~20 m/s class | 0.020 rad | 0.30 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWCAL_C02 | CALIBRATION_ONLY | current ~20 m/s class | 0.020 rad | 0.50 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWCAL_C03 | CALIBRATION_ONLY | current ~20 m/s class | 0.030 rad | 0.40 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWCAL_C04 | CALIBRATION_ONLY | current ~20 m/s class | 0.040 rad | 0.30 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWCAL_C05 | CALIBRATION_ONLY | current ~20 m/s class | 0.040 rad | 0.40 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |

This is a crossed/spread amplitude-frequency design: low amplitude is not always bound to low frequency, and high amplitude is represented at both lower and verified frequencies. The design intent is sufficient to seek contrast diversity in `[Vy_D-Vy_F, Vy_K-Vy_F]`; actual rank and conditioning remain mandatory V2.5-H data gates.

## 4. Exact untouched holdout suite

| Run ID | Role | Vx setting | Amplitude | Frequency | Waveform | Duration | Rate | Status |
|---|---|---|---:|---:|---|---:|---:|---|
| FWHOLD_H01 | HOLDOUT_VALIDATION | current ~20 m/s class | 0.025 rad | 0.35 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWHOLD_H02 | HOLDOUT_VALIDATION | current ~20 m/s class | 0.035 rad | 0.35 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |
| FWHOLD_H03 | HOLDOUT_VALIDATION | current ~20 m/s class | 0.030 rad | 0.45 Hz | sine | 16 s | 100 Hz | PLANNED_NOT_RUN |

These are interpolation-style combinations inside the calibration amplitude/frequency envelope and do not duplicate a calibration condition. They are not sensor-failure or extreme-extrapolation cases.

All three holdout result paths were checked and do not exist. The runs and their truth/performance remain ungenerated and unopened.

## 5. Immutable run-role registry

Registry version: `V2.5-F-v1`, registered `2026-08-28`.

- Run IDs are unique and may never be reused for a different condition.
- Roles are assigned before first execution and are immutable.
- A failed run retains its ID and failed evidence; a retry receives a new versioned ID.
- Calibration rows can never become independent holdout rows.
- Holdout rows remain `PLANNED_NOT_RUN` until alpha is frozen.
- Current `result_sha256` is `NOT_GENERATED` for every new row.
- Current alpha status is `UNSELECTED` for every row.

## 6. Evaluation window

The registered evaluation window is the **full run, `[0,16] s`, including the initialization transient**, for every calibration and holdout maneuver.

No post-hoc first-0.5-s, first-1-s, or condition-specific trimming is permitted. A future change to this rule requires a new registry version before generating any affected data.

## 7. Truth-alignment rule

The single registered rule is:

```text
1. D/K/F must already share one exact 100-Hz timestamp grid.
2. Vy_true is mapped once to that common estimator grid.
3. Exact truth timestamps pass through unchanged.
4. Otherwise use deterministic piecewise-linear interpolation.
5. Extrapolation is forbidden; truth must bracket the full [0,16] grid.
6. Duplicate/nonmonotonic/nonfinite truth timestamps reject the run.
7. No per-track alignment, cross-correlation shift, RMSE-driven delay,
   manual offset, or index compensation is permitted.
```

This matches the previously used exact-match-first / bounded linear-interpolation method in the accepted parallel analysis, but is now pre-registered for all future suite runs.

## 8. Logging contract

Every acquisition must save:

- run ID, immutable role, registry version, result status;
- runtime target path/hash, fusion core hash, fusion wrapper hash;
- CarSim solver path, active simfile/context, MATLAB exit/completion evidence;
- planned and actual amplitude, frequency, duration, sample rate, steering waveform and wheel routing;
- actual Vx time history and realized operating-speed statistics;
- D/K/F/fusion timestamps and sample-integrity statistics;
- `Vy_D`, `Vy_K`, `Vy_F`, and any test/frozen-alpha `Vy_FW`;
- offline `Vy_true` with provenance and alignment audit;
- D/K/F reset evidence and F `feedbackApplied` evidence;
- actual front/rear steering signals;
- target/frozen hashes before and after;
- reserved result path and final result SHA-256.

Only `Vy_D`, `Vy_K`, `Vy_F`, and aligned `Vy_true` may enter the future V2.5-H fitting objective. The other fields are reproducibility and integrity evidence.

## 9. Future acquisition order

The fixed order is:

```text
V2.5-G calibration acquisition only:
FWCAL_C01 → FWCAL_C03 → FWCAL_C04 → FWCAL_C02 → FWCAL_C05

V2.5-H:
read only the five completed CALIBRATION_ONLY results
→ constrained-QP solve
→ rank/conditioning/sensitivity gates
→ alpha freeze or WEIGHT FREEZE BLOCKED

V2.5-I only after alpha freeze:
FWHOLD_H01 → FWHOLD_H02 → FWHOLD_H03
```

No holdout run may be executed, generated, or opened in V2.5-G/H.

## 10. Suite-separation and design gates

Static registry checks establish:

- calibration maneuver count = 5;
- holdout maneuver count = 3;
- duplicate run IDs = 0;
- duplicate exact calibration/holdout conditions = 0;
- all calibration roles = `CALIBRATION_ONLY`;
- all holdout roles = `HOLDOUT_VALIDATION`;
- all new statuses = `PLANNED_NOT_RUN`;
- all new result hashes = `NOT_GENERATED`;
- existing reserved result MAT count = 0;
- actual alpha values calculated = NO;
- optimizer executed = NO;
- intended excitation diversity = SUFFICIENT within the current-speed-class scope;
- actual identifiability/rank/conditioning = NOT YET TESTED.

## 11. Fixed exclusions and parameter status

- `P0_F=0.5` and `Q_F=0.0025` remain TEST-ONLY / UNTUNED / UNFROZEN.
- No covariance or `P_FW` enters fixed-weight fitting.
- No LifeSig, NIS, observability, reliability, winner, or adaptive signal enters fitting.
- No true Vy enters online D/K/F/fusion paths.
- No grid search, least-squares solve, manual comparison, or optimization was performed.

```text
alpha_D = UNSELECTED
alpha_K = UNSELECTED
alpha_F = UNSELECTED
```

## 12. Frozen integrity

| Artifact | SHA-256 | Status |
|---|---|---|
| fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | unchanged |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | unchanged |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | unchanged |
| F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| parallel D/K target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |

Frozen D/K/DK-EKF/F dependencies were not modified.

DEDICATED CALIBRATION MANEUVERS ARE PRE-REGISTERED.

UNTOUCHED HOLDOUT MANEUVERS ARE PRE-REGISTERED BUT NOT RUN.

HISTORICAL DEVELOPMENT/PREFLIGHT DATA ARE EXCLUDED FROM FORMAL ALPHA FITTING.

RUN ROLES ARE FIXED BEFORE DATA GENERATION.

EVALUATION WINDOW AND TRUTH-ALIGNMENT RULE ARE PRE-REGISTERED.

NO WEIGHTS WERE CALCULATED.

NO HOLDOUT DATA WERE GENERATED OR VIEWED.

NO SIMULATION / CARSIM / OPTIMIZATION WAS PERFORMED.

READY FOR V2.5-G FIXED-WEIGHT CALIBRATION DATA ACQUISITION
