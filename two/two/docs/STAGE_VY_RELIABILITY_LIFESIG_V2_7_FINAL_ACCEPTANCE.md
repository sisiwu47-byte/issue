# V2.7 Final Acceptance and Freeze Audit

## Final verdict

```text
V2.7_FINAL_ACCEPTED_AND_FROZEN_WITH_BOUNDED_CLAIMS
```

This was a read-only audit of the existing A2R9–A3R10 evidence and current implementation artifacts. No MATLAB, Simulink, CarSim, or `sim()` execution was performed. No model, source implementation, estimator, parameter, Q/R, P0_F/Q_F, or historical evidence was modified.

## Final frozen mathematics

Exact static quality priors:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
```

Exact F health constants:

```text
tau_F = 28.252990189369939 s
Ts    = 0.01 s
```

Track availability and health:

```text
availability_D = update_valid_D && isfinite(Vy_D)
H_D = double(availability_D)

availability_K = update_valid_K && isfinite(Vy_K)
H_K = double(availability_K)

availability_F = age_valid_F
                 && isfinite(propagation_age_steps)
                 && propagation_age_steps >= 0
                 && isfinite(Vy_F)

H_F = double(availability_F)
      * exp(-(propagation_age_steps*Ts)/tau_F)
```

Normal fusion path:

```text
score_i = q_i * H_i
S = score_D + score_K + score_F

if isfinite(S) && S > 0:
    alpha_i = score_i / S
    Vy_LS = sum of active finite score_i*Vy_i terms / S
    fusion_valid = 1
    fallback_active = 0
    update last_valid_Vy_LS
```

Inactive terms are assigned literal zero before multiplication, preventing `0*NaN` contamination. No normalization epsilon is used. On the normal path, alpha is nonnegative and sums to one within floating-point roundoff.

Fallback and reset contract:

```text
if S is nonfinite or S <= 0:
    Vy_LS = last_valid_Vy_LS when history exists, otherwise 0
    alpha_D = alpha_K = alpha_F = 0
    fusion_valid = 0
    fallback_active = 1
    do not update last-valid memory
```

Reset first clears last-valid history, then evaluates the current hit. A valid current hit may immediately produce normal fusion and establish new history; an invalid hit produces the no-history fallback.

## Frozen signal roles and exclusions

```text
NIS_D / NIS_K             = DIAGNOSTIC_ONLY
abs(r) observability      = DIAGNOSTIC_ONLY
pairwise disagreement     = DIAGNOSTIC_ONLY
D/K/F covariance          = NOT_IN_FORMAL_PRIMARY_WEIGHT
Vy_true                   = OFFLINE_VALIDATION_ONLY
P_AF                      = NOT_DEFINED
```

NIS, yaw observability, disagreement, covariance, maneuver identity, holdout state, and online truth do not enter the formal LifeSig weight path. No statistically optimal/BLUE or fused-covariance claim is made.

## Implementation acceptance evidence

### Core regression

- Core diagnostic-output remediation test: `24/24 PASS`.
- The original eight core outputs were bitwise equivalent in 1000 deterministic randomized comparisons after adding `H_D/H_K/H_F` outputs.
- Unit-test evidence SHA-256: `306E5BE2890C0570637C0B6DAD9E1652B088ADE36566EF22FDEC92679F20723E`.

### Wrapper and integration

- Wrapper: 8 scalar-double inputs, 9 scalar-double outputs, two scalar DWork memories, sample time `[0.01 0]`.
- Wrapper delegates fusion/health mathematics to the core and owns only last-valid memory.
- Wrapper compile-only test: PASS.
- LifeSig integration load/update/compile gates: PASS.
- Compile evidence SHA-256: `2AB41889D435A11AAF42C724BF38DBEBDF3A97CEA3E8C9B66B64D7A2C98FD2A4`.

### Runtime evidence

- 0.2 s smoke: 21 aligned 100-Hz samples; runtime/replay maximum error `0`; fallback count `0`; PASS.
- 16 s nominal: 1601 aligned samples over `[0,16]` s; `dt=0.01 s`; all formal logs finite; runtime/replay maximum error `0`; PASS.
- 16 s maximum `abs(sum(alpha)-1)`: `2.2204460492503131e-16`.
- 16 s health replay maximum error: `0`.
- 16 s minimum score sum: `0.99526889054144274`.
- Nominal availability drops `[D K F]`: `[0 0 0]`.
- Nominal fallback count: `0`.

## Current frozen implementation hashes

| Artifact | SHA-256 |
|---|---|
| `model/vy_lifesig_fusion_step.m` | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| `model/vy_lifesig_fusion_simulink_sfun.m` | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |
| `model/vx_vy_lifesig_fusion_v2_7.slx` | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |
| `model/test_vy_lifesig_fusion_v2_7a3r7.m` | `169E4E492DBB19FC64984815CAA4179A4AC452C7FD97968273CA4DD9E07BCA98` |
| `model/test_vy_lifesig_fusion_simulink_wrapper_v2_7a3r8.m` | `2884B3A4D8FFF2B3FE97FCA2AD8EDDD26BCC5D6FE9CEF281E2BE6B1693532F85` |
| `results/vy_reliability_lifesig_v2_7a3r9_smoke.mat` | `FA51429F9E7EFBE06CAF79F42ADF2A4D7DFB30797937C0C93C5BDBC34EE81D20` |
| `results/vy_reliability_lifesig_v2_7a3r10_nominal.mat` | `E02DA4498441249C6AD7108FAD529C9724053B3B7FE469FFC0DF629208FCBBF3` |
| `results/vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv` | `6F934A700D1EDEE2CFC1569DC08BB94595854FD589582194AEFAE5392B1C4C3D` |

The core, wrapper, and integration-target hashes match the accepted A3R8, A3R9, and A3R10 lineage.

## A3R10 descriptive-only performance

All values below come from the same frozen 16 s A3R10 dataset. They are not a tuning objective and did not change any parameter.

| Output | RMSE | MAE | MaxAbs | Bias |
|---|---:|---:|---:|---:|
| D track | 0.036415619095730323 | 0.032997197566322564 | 0.061201229017568012 | -0.0043966919566230831 |
| K track | 0.25962779566180644 | 0.24795739263649411 | 0.349597819793529 | -0.24795739263649411 |
| F track | 0.74738332275976438 | 0.64797303941009787 | 1.2660624093959161 | -0.64797303941009787 |
| Static-prior fusion | 0.059409251831957541 | 0.049258453029168078 | 0.11035029457553254 | -0.047105590951723217 |
| Frozen V2.5 fixed fusion | 0.045506137078519533 | 0.036513291485064429 | 0.088564609144097931 | -0.028638753266451687 |
| LifeSig fusion | 0.057604956671948829 | 0.047226524779178478 | 0.10759579896829302 | -0.045051740738381342 |

LifeSig is slightly different from and descriptively better than the static-prior fusion for this nominal run, but it is worse than the D track and frozen V2.5 fixed fusion on RMSE. Therefore no general or nominal performance-superiority claim is supported.

## Bounded claim audit

```text
V2.7_IMPLEMENTATION_ACCEPTANCE
    = ACCEPTED

V2.7_RUNTIME_CONTRACT_ACCEPTANCE
    = ACCEPTED_FOR_0P2S_SMOKE_AND_16S_NOMINAL_NORMAL_PATH

V2.7_ADAPTIVITY_CLAIM
    = WEAKLY_ADAPTIVE_UNDER_OBSERVED_NOMINAL_AVAILABILITY

V2.7_PERFORMANCE_SUPERIORITY_CLAIM
    = NOT_SUPPORTED

V2.7_FALLBACK_RUNTIME_CLAIM
    = NOT_VALIDATED_BY_ACTUAL_CARSIM_FAILURE_OR_AVAILABILITY_DROP

V2.7_FINAL_FREEZE_STATUS
    = ACCEPTED_AND_FROZEN_WITH_BOUNDED_CLAIMS
```

The nominal run had zero availability drops and never entered fallback. Unit tests validate fallback/reset mathematics, but they are not evidence of an actual CarSim fault or runtime availability-loss event. The accepted runtime evidence validates the normal path only.

The F age gate caused real but small weight variation: `alpha_F` changed from `0.01094189322758545` to `0.0062403073461377309`, while D/K remained continuously available. This supports only `WEAKLY_ADAPTIVE`, not broad fault-adaptive or reliability-superiority claims.

## Remaining independent blocker

The previously identified covariance-track contract remains unchanged:

```text
P0_F_FROZEN = 0
CURRENT_F_CORE_CONTRACT_ACCEPTS_ZERO = NO
```

The current F propagation core still asserts `P0_F > 0`. This remains a blocker for the separate covariance-based path, but it does not block the accepted noncovariance LifeSig primary weight path because F covariance is not a formal LifeSig input.

## Freeze conclusion

V2.7 is accepted and frozen as an implementation and validated nominal normal-path contract with explicitly bounded scientific claims. This freeze does not establish performance superiority, runtime fault fallback behavior, fused covariance, or NIS/observability/disagreement-based weighting.

