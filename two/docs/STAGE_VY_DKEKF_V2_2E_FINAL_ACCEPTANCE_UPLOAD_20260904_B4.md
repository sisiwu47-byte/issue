# V2.2-E DK-EKF Baseline Final Acceptance and Freeze

- Date: 2026-08-27
- Acceptance authority: Sol
- Baseline identity: **UNIFIED DK-EKF BASELINE**
- Final decision: **V2.2-E DK-EKF BASELINE ACCEPTED AND FROZEN**
- New simulation or CarSim run in V2.2-E: **NO**

## 1. Final accepted algorithm definition

The frozen state and shared covariance are

```text
x_DK = [Vx; Vy; r]
P_DK = 3x3 shared covariance
Ts   = 0.01 s
```

Prediction is performed at 100 Hz:

```text
Vx_dot = Ax_IMU + r*Vy
```

The Vy/r lateral prediction and Ay measurement prediction are mathematically
identical to frozen D-EKF V1.17, except that their Vx is the unified state
`x(1)`. The accepted update order is:

1. prediction;
2. scalar Vx measurement update;
3. scalar AVz/r measurement update;
4. scalar Ay measurement update only when `doAyUpdate=true`.

Prediction, Vx, and AVz/r execute at 100 Hz. Ay assimilation executes at
20 Hz. All prediction and measurement updates act on one state and one shared
3x3 covariance; this is not output fusion.

## 2. Frozen parameters and reset

```text
Q_DK = diag([1e-4, 1e-4, 1e-4])
R_Vx = 1e-4
R_r  = 3.365172961808e-4
R_Ay = 1e-2
P0   = diag([0.1, 0.1, 0.1])
x0   = [z_Vx; 0; 0]
```

TRUE Vy initialization is **NO**. These values are accepted as the frozen
no-tuning baseline parameter set and must not be silently changed.

## 3. Independent acceptance matrix

The five required status documents and their machine evidence were read in
V2.2-E. No test, compile, model update, simulation, or CarSim run was repeated.

| Area | Actual machine/status evidence | Acceptance |
|---|---|---|
| Mathematical core | 25/25 core + 7/7 wrapper = 32/32 | PASS |
| D-EKF lateral prediction equivalence | maximum error `0` | PASS |
| D-EKF Ay prediction equivalence | maximum error `0` | PASS |
| Prediction Jacobian | maximum error `3.7792546692116957e-7`, tolerance `5e-4` | PASS |
| Ay Jacobian | maximum error `2.473576863337712e-7`, tolerance `5e-4` | PASS |
| Shared state/covariance | `[Vx;Vy;r]`, one `3x3 P` | PASS |
| Simulink integration | 31/31 gates | PASS |
| Function-call semantics | one 100-Hz hit = one committed state advance | PASS |
| C2 0.20-s preflight | 13/13 gates | PASS |
| C2 100-Hz runtime | 21 committed hits, no duplicate/missing hit | PASS |
| C2 20-Hz Ay | 5 enabled/applied hits, exact sequence | PASS |
| C2 reset | one high at `t=0`; `[20,0,0]`, `0.1*I3` prior | PASS |
| C2 numeric/covariance | finite, symmetric, positive minimum eigenvalue | PASS |
| C2 exact replay | x/P/diag differences `0/0/0` | PASS |
| D1 genuine steering | 0.02 rad, `frontCommandApplied=1` | PASS |
| D1 physical response | AVz response differs materially from zero-steer C2 | PASS |
| D1 execution/numerics | 100 Hz, 20-Hz Ay, reset, finite, covariance, replay | PASS |
| D2 genuine nominal runtime | 16 s, CarSim complete, 1601 committed samples | PASS |
| D2 exact replay | x/P/diag differences `0/0/0` | PASS |
| D2 fairness | all online-source and no-fusion gates | PASS |
| D2 frozen hash integrity | validation/target/core/wrapper/adapter and references unchanged | PASS |

Machine evidence read during acceptance:

- `results/vy_dkekf_v2_2b_unit_tests.mat`
- `results/vy_dkekf_v2_2c1_integration.mat`
- `results/vy_dkekf_v2_2c2_preflight.mat`
- `results/vy_dkekf_v2_2d1_steer_smoke.mat`
- `results/vy_dkekf_v2_2d2_nominal_validation.mat`

## 4. D2 genuine nominal baseline performance

Condition: approximately 20 m/s, genuine 0.02-rad front steering at 0.4 Hz,
rear steering zero, and 16 s duration.

| State | RMSE | MAE | Bias | MaxAbsError | Final error |
|---|---:|---:|---:|---:|---:|
| Vx (m/s) | 0.00012220 | 0.00012010 | 0.00012010 | 0.00018473 | 0.00010120 |
| Vy (m/s) | 0.03609615 | 0.03273062 | -0.00442339 | 0.06063858 | -0.03823195 |
| r (rad/s) | 0.00453985 | 0.00417149 | 0.00414601 | 0.01124240 | 0.00479218 |

P22 registration:

```text
final = 1.7543224744e-04
range = [1.0668231452e-04, 4.8760688063e-04]
mean  = 3.0705471324e-04
```

This performance is accepted as baseline characterization, not a universal
performance guarantee.

## 5. NIS consistency characterization

| NIS | Valid samples | Mean | p95 | Max | Fraction <= 3.8414588 |
|---|---:|---:|---:|---:|---:|
| Vx | 1601 | 0.00039396 | 0.00062841 | 0.00089712 | 1 |
| r | 1601 | 0.03104848 | 0.11565514 | 0.31637449 | 1 |
| Ay, applied updates only | 321 | 0.06005155 | 0.22412159 | 0.49238991 | 1 |

The NIS values are substantially below order one. The current statistical
assumptions appear conservative in this genuine nominal condition. This is a
documented consistency characteristic, not a runtime failure, and does not
provide sufficient evidence for Q/R tuning.

## 6. Genuine K-KF reference

K-KF V2.1-G1-A and DK-EKF D2 both used approximately 20 m/s, genuine
0.02-rad front steering at 0.4 Hz, rear steering zero, and 16 s duration.

| Vy metric | K-KF V2.1-G1-A | DK-EKF V2.2-D2 |
|---|---:|---:|
| RMSE (m/s) | 0.25962780 | 0.03609615 |
| MAE (m/s) | 0.24795739 | 0.03273062 |
| MaxAbsError (m/s) | 0.34959782 | 0.06063858 |
| Final error (m/s) | -0.28480616 | -0.03823195 |

The DK-EKF baseline significantly outperformed K-KF in this genuine nominal
condition. This result does not establish that DK-EKF is superior in every
condition, and it does not authorize modification of frozen K-KF V2.1.

## 7. Fairness freeze

```text
TRUE VY ONLINE       = NO
TRUE Vx              = measurement only
Ax_IMU               = prediction input only
AVz_IMU              = measurement only
Ay_IMU               = measurement only
shared state         = YES
shared 3x3 covariance= YES
output fusion        = NO
LifeSig              = NO
adaptive fusion      = NO
```

## 8. Registered known limitations

1. Formal DK-EKF performance validation is currently concentrated on the
   genuine nominal 20 m/s / 0.02 rad / 0.4 Hz / 16 s condition.
2. NIS_Vx, NIS_r, and NIS_Ay are substantially below order one; the statistical
   assumptions appear conservative in this nominal condition.
3. Current evidence is insufficient to support Q/R tuning.
4. Online bias correction is not implemented.
5. The baseline uses true Vx as the Vx measurement for baseline isolation and
   controlled comparison.
6. True Vy is never an online input or initializer.
7. The baseline contains no LifeSig, adaptive reliability, adaptive covariance
   fusion, or output fusion.
8. A different Vx source requires a new, explicit validation stage and must not
   be introduced by silently modifying this frozen baseline.
9. Current results do not establish performance in every high-dynamic or limit
   condition.

## 9. Freeze manifest

The current SHA-256 values were independently recomputed in V2.2-E:

| Frozen file | SHA-256 | Status |
|---|---|---|
| `model/vy_dkekf_baseline_step.m` | `6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457` | FROZEN |
| `model/vy_dkekf_baseline.m` | `7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973` | FROZEN |
| `model/vy_dkekf_baseline_simulink_sfun.m` | `12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1` | FROZEN |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | FROZEN |
| `model/vx_vy_dkekf_v2_2d_nominal.slx` | `A17E7609D2248C832A80F773660941B68025E3A38CFC1F3938CBCA2BD0165E5B` | FROZEN |

Machine-readable manifest:
`results/vy_dkekf_v2_2e_freeze_manifest.csv`.

The following D2 files are registered for baseline reproducibility and were
not modified in V2.2-E:

| Evidence file | SHA-256 | Registration |
|---|---|---|
| `model/run_vy_dkekf_v2_2d2_nominal_validation.m` | `07CB0F8340CA7999EEDF3881213FB05542D7692305AF682A9158E32DD84E850D` | REGISTERED_EVIDENCE |
| `model/analyze_vy_dkekf_v2_2d2_nominal_validation.m` | `F3997A66632BE7849CA31EB2928180C408C1E186C6DF7CA6720ACEE9F08EA330` | REGISTERED_EVIDENCE |
| `results/vy_dkekf_v2_2d2_nominal_validation.mat` | `B8F390F9DE81AFEEEB0141E9266F5D0E7C76AC9D28D1138C143E78DFE969E57B` | REGISTERED_EVIDENCE |
| `docs/STAGE_VY_DKEKF_V2_2D2_STATUS.md` | `8AB3C78E0F4858DAAA841E1D1959D3B465884D0FB6DBFB8C65263A77608D369E` | REGISTERED_EVIDENCE |

## 10. Final acceptance

- Unified DK-EKF mathematics: **ACCEPTED**.
- Shared-state/shared-covariance implementation: **ACCEPTED**.
- Simulink integration: **ACCEPTED**.
- Runtime execution semantics: **ACCEPTED**.
- Genuine nominal performance: **CHARACTERIZED AND ACCEPTED**.
- Conservative NIS characteristic: **DOCUMENTED**.
- Q/R tuning performed: **NO**.
- Online bias correction implemented: **NO**.
- Baseline frozen for subsequent comparison: **YES**.

**V2.2-E DK-EKF BASELINE ACCEPTED AND FROZEN**

**READY FOR THE PARALLEL D-EKF / K-KF STAGE**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS FROZEN.

DK-EKF V2.2 BASELINE IS ACCEPTED AND FROZEN.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE BIAS CORRECTION WAS IMPLEMENTED.

NO OUTPUT FUSION WAS PERFORMED.

NO LIFESIG WAS IMPLEMENTED.

NO ADAPTIVE FUSION WAS IMPLEMENTED.

NO NEW SIMULATION OR CARSIM RUN WAS PERFORMED IN V2.2-E.
