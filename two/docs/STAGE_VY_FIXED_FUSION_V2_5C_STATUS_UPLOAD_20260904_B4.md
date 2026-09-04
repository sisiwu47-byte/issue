# V2.5-C Fixed-Weight Three-Track Fusion Simulink Integration Status

## Stage decision

**V2.5-C FIXED-WEIGHT THREE-TRACK FUSION SIMULINK INTEGRATION ACCEPTED**

The formal V2.5 integration target was accepted by static architecture evidence. The estimator-only harness was accepted by one authorized compile/termination cycle. No simulation, CarSim runtime, or full-target compile-only attempt was performed.

## Created artifacts

- `model/vy_fixed_weight_fusion_simulink_sfun.m`
- `model/vx_vy_fixed_fusion_v2_5.slx`
- `model/vx_vy_fixed_fusion_v2_5c_compile_harness.slx`
- `model/build_vy_fixed_fusion_v2_5c.m`
- `model/validate_vy_fixed_fusion_v2_5c_integration.m`
- `results/vy_fixed_fusion_v2_5c_integration_gates.mat`
- `docs/STAGE_VY_FIXED_FUSION_V2_5C_STATUS.md`

No runtime result was created.

## Architecture accepted

The new formal target is a copy of the frozen parallel D/K target with an exact accepted F-track execution boundary and a new stateless fixed-weight fusion boundary. The frozen source target was never saved.

| Fusion port | Exact source | Mapping | Compiled interface |
|---|---|---|---|
| 1 | D-EKF state `[Vy;r]` | element 1 = `Vy_D` | scalar double |
| 2 | K-KF state `[Vx;Vy]` | element 2 = `Vy_K` | scalar double |
| 3 | F-track output 1 | scalar `Vy_F` | scalar double |
| output 1 | frozen fusion core result | `Vy_FW` | scalar double |

The routes from the three state selectors to the fusion wrapper are direct and contain no artificial delay. The structural contract is `Vy_FW(k) = f(Vy_D(k),Vy_K(k),Vy_F(k))` at the same logical 100-Hz sample. Actual runtime timestamp equality remains a V2.5-D gate.

## Fusion wrapper

- Level-2 MATLAB S-function: `vy_fixed_weight_fusion_simulink_sfun`
- Inputs: three scalar double, all direct-feedthrough
- Output: one scalar double
- Dialog parameters: `alpha_D`, `alpha_K`, `alpha_F`
- Sample time: `[0.01 0]`
- DWork: none
- persistent/global memory: none
- Update/state-commit method: none
- mathematical implementation: calls the frozen `vy_fixed_weight_fusion_step` core; the weighted-sum equation is not copied into the wrapper

## F-track standalone policy

- Physical inputs: shared `Ay_IMU`, `AVz_IMU`, and the existing isolated physical Vx source `Gain38`
- Scheduler: independent 100 Hz function-call generator
- State/DWork: independent from D-EKF and K-KF
- `feedback_valid_current = 0`
- `Vy_feedback_current = 0`, finite deterministic placeholder
- `P_feedback_current = 0.5`, finite deterministic placeholder
- `Vy_FW` destination: logging only; it does not enter any F-track input
- Fusion-feedback loop closed: **NO**

The F-track integration values `P0_F=0.5` and `Q_F=0.0025` remain **TEST-ONLY / UNTUNED / UNFROZEN**.

## Static architecture evidence

- Formal integration target gates: **69/69 PASS**
- Estimator-only harness gates: **60/60 PASS**
- Formal target compile-only: **not called**
- `sim()`: **not called**
- CarSim runtime: **not called**

The gates confirm exact D/K/F state mapping, three fusion inputs only, no `r_D`, no `Vx_K`, no covariance input, no `P_FW`, no DK-EKF input, no true-Vy online input, no adaptive weighting, no LifeSig, no NIS/observability/reliability logic, no winner selector, and no fusion feedback.

## Estimator-only compiled evidence

One authorized harness compile was used after both static gate sets passed.

```text
compileCalled             = 1
compilePassed             = 1
terminationReached        = 1
compiledEvidenceCaptured  = 1
compiled gates            = 24/24 PASS
```

| Interface | Compiled shape | Width | Type |
|---|---:|---:|---|
| D state | `2` | 2 | double |
| D P | `[2 2]` | 4 | double |
| K state | `2` | 2 | double |
| K P | `[2 2]` | 4 | double |
| F Vy | `1` | 1 | double |
| F P | `1` | 1 | double |
| F diag | `[3 1]` | 3 | double |
| selected D Vy | `1` | 1 | double |
| selected K Vy | `1` | 1 | double |
| fusion input 1 | `1` | 1 | double |
| fusion input 2 | `1` | 1 | double |
| fusion input 3 | `1` | 1 | double |
| Vy_FW | `1` | 1 | double |

Compiled sample times:

```text
D parent       = [0.01 0]
K parent       = [0.01 0]
F parent       = [0.01 0]
fusion wrapper = [0.01 0]
```

No estimator-side dimension, type, or sample-time conflict occurred.

## Weight classification

The integration and compile harness use `[1/3,1/3,1/3]` only as a legal **TEST-ONLY** vector.

- NOT SELECTED BASELINE WEIGHTS
- NOT TUNED
- NOT FROZEN
- no runtime adaptation
- no RMSE optimization

## Hash and no-write evidence

| Artifact | SHA-256 | Status |
|---|---|---|
| frozen parallel D/K source | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | unchanged |
| frozen F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | unchanged |
| frozen F S-function | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | unchanged |
| accepted F target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | unchanged |
| frozen fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | unchanged |
| V2.5 integration target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | new, not frozen |
| estimator-only compile harness | `0B1F883A65F1C844DE8C5E68F24CAF2578C039FDC0EDC4B1E733BADB5BC53E16` | new |
| fusion Simulink wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | new |

Validator evidence records `frozenUnchanged=1`, `targetNoWrite=1`, `harnessNoWrite=1`, and `wrapperNoWrite=1`.

## Required answers

1. Fusion core hash unchanged? **YES**
2. Fusion wrapper calls the frozen core? **YES**
3. Wrapper stateless? **YES**
4. D/K/F Vy mapping correct? **YES**
5. Covariance fusion present? **NO**
6. `P_FW` present? **NO**
7. DK-EKF enters fusion? **NO**
8. F feedback remains disabled? **YES**
9. `Vy_FW` feeds back to F? **NO**
10. D/K/F all retain 100-Hz base semantics? **YES**
11. Harness compile passed? **YES**
12. Compiled fusion inputs/output scalar double? **YES**
13. Formal weights selected or tuned? **NO**
14. Adaptive weighting or LifeSig implemented? **NO**

## External limitation

Full-target compile-only was not retried. The existing `vs_sf / carsim_64.dll` initialization access-violation limitation is already documented and does not alter the estimator-only integration acceptance in this stage.

THREE-TRACK D/K/F STATE FUSION ROUTING ACCEPTED.

FUSION WRAPPER IS STATELESS AND CALLS THE FROZEN CORE.

D/K/F CURRENT Vy SIGNAL MAPPING IS ACCEPTED.

F-TRACK REMAINS STANDALONE.

NO FUSION-FEEDBACK LOOP IS CLOSED.

NO FUSED COVARIANCE IS GENERATED.

NO DK-EKF SIGNAL ENTERS THE FUSION.

TEST-ONLY WEIGHTS WERE USED FOR INTEGRATION ONLY.

FORMAL FIXED-WEIGHT VALUES REMAIN UNSELECTED / UNTUNED / UNFROZEN.

NO ADAPTIVE WEIGHTING WAS IMPLEMENTED.

NO LIFESIG WAS IMPLEMENTED.

NO CARSIM RUNTIME OR SIMULATION WAS PERFORMED.

FULL-TARGET COMPILE-ONLY WAS NOT RETRIED BECAUSE THE EXISTING EXTERNAL CARSIM LIMITATION IS ALREADY DOCUMENTED.

READY FOR V2.5-D FIXED-WEIGHT THREE-TRACK RUNTIME PREFLIGHT
