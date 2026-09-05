# V2.3-E Parallel D/K Final Acceptance & Freeze

- Date: 2026-08-28
- Scope: read-only final acceptance and SHA-256 freeze registration
- Final decision: **V2.3-E PARALLEL D/K STAGE ACCEPTED AND FROZEN**
- New simulation / CarSim / compile / builder execution: **NONE**
- Model or estimator modification: **NONE**
- Fusion / LifeSig / third track: **NONE**

## 1. Acceptance basis

This acceptance reuses and cross-checks the completed V2.3-A through V2.3-D
stage evidence. No test, compile, simulation, builder, or runtime evidence was
regenerated in V2.3-E. Every registered artifact was read-only hashed again.
The formal parallel target remains exactly:

```text
model/vx_vy_parallel_dk_v2_3.slx
SHA-256 = 98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0
```

The recalculated value matches the expected freeze baseline. The referenced
frozen D-EKF V1, K-KF V2.1, and DK-EKF V2.2 artifacts also match their
registered baselines. The complete machine-readable register is:

```text
results/vy_parallel_dk_v2_3e_freeze_manifest.csv
```

## 2. Final acceptance matrix

| Acceptance item | Evidence/result | Decision |
|---|---|---|
| Architecture audit | V2.3-A accepted | PASS |
| Formal parallel static gates | `41/41` | PASS |
| Estimator-only harness static gates | `38/38` | PASS |
| Estimator-only compiled gates | `15/15` | PASS |
| Estimator-side compile errors | none | PASS |
| 0.20-s shared CarSim runtime | one completed runtime | PASS |
| D 100-Hz execution | 21 hits over 0.20 s; exact 0.01-s cadence | PASS |
| K 100-Hz execution | 21 hits over 0.20 s; exact 0.01-s cadence | PASS |
| D Ay 20-Hz semantics | every fifth D hit | PASS |
| K process-input semantics | Ax/Ay/AVz on every K hit | PASS |
| D reset/lifecycle | exactly once at `t=0` | PASS |
| K reset | exactly once at `t=0` | PASS |
| D covariance validity | finite, symmetric, positive minimum eigenvalue | PASS |
| K covariance validity | finite, symmetric, positive minimum eigenvalue | PASS |
| D exact replay | x/P/diagnostics `0 / 0 / 0` | PASS |
| K exact replay | x/P/diagnostics `0 / 0 / 0` | PASS |
| D one-hit semantics | one 100-Hz hit equals one committed state advance | PASS |
| K one-hit semantics | one 100-Hz hit equals one committed state advance | PASS |
| 16-s genuine nominal runtime | one shared D/K CarSim runtime | PASS |
| K independent non-interference | parallel vs G1-A x/P/diagnostics `0 / 0 / 0` | PASS |
| Parallel coupling evidence | none | PASS |
| True Vy online | no | PASS |
| Fusion | no | PASS |
| LifeSig | no | PASS |
| Third track | no | PASS |

## 3. Integration acceptance and external compile-only limitation

The parallel estimator integration is accepted from the combined evidence:

- formal topology and prohibition gates: `41/41 PASS`;
- estimator-only harness topology gates: `38/38 PASS`;
- estimator-only compiled-interface gates: `15/15 PASS`;
- compiled dimensions, types, function-call domains, and sample-time evidence
  contain no estimator-side defect;
- one 0.20-s and one 16-s shared CarSim runtime completed successfully;
- both estimators reproduce their frozen implementations exactly offline.

The following limitation remains explicitly registered:

**FULL-TARGET COMPILE-ONLY REMAINS EXTERNALLY LIMITED BY CARSIM VS_SF
INITIALIZATION ACCESS VIOLATION.**

The historical G: solver request was attributed to the wrong current-working-
directory `simfile.sim`. Using the correct model-directory configuration
restores the D: solver path, after which the full-target compile-only path can
still terminate with `0xC0000005` in external `vs_sf / carsim_64.dll`
initialization. Real shared CarSim runtime succeeds with the D: solver, and the
estimator-only compile passes. This external compile-only limitation does not
invalidate the verified shared runtime results, does not establish that full
parallel-model compile-only passed, and is not classified as parallel
integration failure.

## 4. Genuine nominal runtime characterization

The accepted V2.3-D condition is one shared 16-s runtime at approximately
20 m/s with genuine front road-wheel steering
`0.02*sin(2*pi*0.4*t) rad` and zero rear steering. Both estimators produced
1601 samples over `[0,16] s` at 100 Hz with equal timestamps, no duplicates,
no missing hits, finite state/covariance/diagnostics, and valid covariance.
D performed 321 Ay updates at 20 Hz; K consumed its process inputs on all
1601 hits.

| Vy error metric | D-EKF | K-KF |
|---|---:|---:|
| RMSE, m/s | `0.0364156191` | `0.2596277957` |
| MAE, m/s | `0.0329971976` | `0.2479573926` |
| Bias, m/s | `-0.0043966920` | `-0.2479573926` |
| MaxAbs, m/s | `0.0612012290` | `0.3495978198` |
| Final error, m/s | `-0.0382753488` | `-0.2848061582` |

D-EKF has substantially lower overall Vy error than K-KF in this genuine
nominal condition. This is a condition-specific characterization and does not
establish that D-EKF universally outperforms K-KF.

## 5. Diagnostic excitation partition

The partition uses `abs(AVz_IMU)=0.01 rad/s` as a diagnostic threshold only.
It is **not LifeSig** and creates no online switch, gate, or weight.

| Partition | Samples | D Vy RMSE, m/s | K Vy RMSE, m/s |
|---|---:|---:|---:|
| low-r, `abs(r)<=0.01` | 80 | `0.0477632` | `0.250278` |
| higher-r, `abs(r)>0.01` | 1521 | `0.0357191` | `0.260110` |

In this nominal dataset D has lower descriptive Vy RMSE in both partitions.
The partition is not an observability implementation and is not used to
generate selector logic or estimator weights.

## 6. State-aligned covariance characterization

The state definitions are preserved:

```text
D-EKF: [Vy; r]  -> Vy variance is P_D(1,1)
K-KF:  [Vx; Vy] -> Vy variance is P_K(2,2)
```

| Vy variance | Initial | Final | Mean |
|---|---:|---:|---:|
| D `P11(Vy)` | `1.2872e-4` | `1.7533e-4` | `3.0699e-4` |
| K `P22(Vy)` | `0.1010` | `0.3400` | `0.3264` |

These covariance values are descriptive and state-aligned. Variance magnitude
is not used as the sole estimator-performance argument, and **no fusion weight
was generated from these covariances**.

## 7. Offline complementarity characterization

```text
corr(e_D,e_K)        = 0.2654077719
mean(abs(e_D-e_K))   = 0.2435636916 m/s
overall D wins       = 97.7514 %
overall K wins       = 2.2486 %
ties                 = 0 %
```

D dominates this nominal condition, while D/K errors are not perfectly
correlated and K wins a small fraction of samples. This is descriptive
complementarity evidence only. It neither authorizes fusion design nor
establishes optimal fixed or adaptive weights. No `alpha_D`, `alpha_K`, or
`Vy_fused` was created.

## 8. Non-interference evidence

### K-KF

The V2.3-D shared runtime and independent frozen K-KF V2.1-G1-A have
samplewise-identical steering, estimator inputs, truth, and timestamps.
Parallel K versus independent G1-A has exact differences:

```text
x = 0
P = 0
diagnostics = 0
```

Therefore, parallel integration did not perturb frozen K-KF.

### D-EKF

**NO QUALIFIED INDEPENDENT GENUINE D-EKF 16-S REFERENCE AVAILABLE.** A
different-condition or zero-steer result is not substituted. The V2.3-D D-EKF
exact replay has x/P/diagnostics differences `0 / 0 / 0`, proving that the
parallel runtime follows frozen D-EKF execution semantics exactly. This is
sufficient non-interference evidence for the current integration freeze.

## 9. Frozen parallel independence rules

The following facts are frozen:

- no D state -> K;
- no K state -> D;
- no `P_D` -> K;
- no `P_K` -> D;
- no pseudo measurement;
- no `r_D` -> K;
- no `Vx_K` -> D;
- no weighted sum;
- no D/K selector;
- no `alpha_D` or `alpha_K`;
- no LifeSig or reliability logic;
- no third feedback track;
- no `Vy_final`.

Shared physical-input fan-out is allowed. Estimator-to-estimator information
exchange is **NONE**. State memories, covariance memories, schedulers, resets,
and output logs remain independent.

## 10. Frozen shared-input policy

| Physical input | Frozen routing |
|---|---|
| `Ax_IMU` | K only |
| `Ay_IMU` | D measurement and K process input |
| `AVz_IMU` | D yaw-rate measurement and K process input |
| true Vx | D physical-dynamics input and K Vx measurement |
| steering `[FL FR RL RR]` rad | D only |
| true Vy | offline truth only; never an online estimator input |

The current true-Vx use is part of the frozen isolation semantics. Any future
replacement by a longitudinal `vx_hat` requires a separate, explicit stage and
validation; it must not be introduced silently.

## 11. Known limitations

1. Formal parallel performance characterization currently centers on one
   genuine nominal condition: approximately 20 m/s, 0.02-rad front steering,
   0.4 Hz, 16 s.
2. Full-target compile-only remains externally limited by the CarSim `vs_sf`
   initialization access violation.
3. Real shared CarSim runtime succeeded, so that compile-only limitation does
   not invalidate the runtime evidence.
4. D-EKF is substantially better in this nominal condition; this does not
   prove the ordering for every condition.
5. K-KF has a material negative nominal Vy bias; no tuning or online bias
   correction was performed.
6. Error correlation and winner fractions are descriptive complementarity
   evidence only.
7. There is no fusion, LifeSig, reliability weighting, adaptive covariance
   weighting, or third feedback track.
8. True Vy was never an online input.
9. True Vx is currently used according to the frozen isolation semantics.
10. Extreme, high-dynamic, sensor-degraded, and model-mismatch conditions have
    not been established by the current evidence.

## 12. Freeze registration

The manifest classifies the formal target as
`FROZEN_PARALLEL_ARCHITECTURE`; D-EKF V1, K-KF V2.1, and DK-EKF V2.2 as
`REFERENCED_FROZEN_DEPENDENCY`; the builder/validators/harness as
`REGISTERED_INTEGRATION_TOOL`; and all accepted machine/status evidence as
`REGISTERED_EVIDENCE`. Every listed SHA-256 was independently recalculated in
V2.3-E and matched the stage baselines.

## 13. Final decision

**V2.3-E PARALLEL D/K STAGE ACCEPTED AND FROZEN**

PARALLEL D/K ARCHITECTURE ACCEPTED.

SHARED CARSIM RUNTIME EXECUTION ACCEPTED.

D-EKF AND K-KF REMAIN INDEPENDENT.

GENUINE NOMINAL PERFORMANCE CHARACTERIZED.

NO D/K MATHEMATICS WERE MODIFIED.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE BIAS CORRECTION WAS IMPLEMENTED.

NO FUSION WAS PERFORMED.

NO LIFESIG WAS IMPLEMENTED.

NO THIRD TRACK WAS IMPLEMENTED.

FULL-TARGET COMPILE-ONLY EXTERNAL CARSIM LIMITATION REMAINS DOCUMENTED.

NO NEW SIMULATION / CARSIM / COMPILE WAS PERFORMED IN V2.3-E.

READY FOR THE THIRD FEEDBACK / PROPAGATION TRACK ARCHITECTURE STAGE
