# V2.1-H Final Independent K-KF Acceptance & Freeze

- Date: 2026-08-26
- Scope: final evidence review and freeze only
- Sol decision: **V2.1-H INDEPENDENT K-KF ACCEPTED AND FROZEN**
- New simulation or CarSim run: **NONE**
- Algorithm, model, parameter, sensor, scheduler, reset, D-EKF, or fusion change: **NONE**

## 1. Accepted mathematical definition

The frozen independent K-KF state and continuous-time kinematics are:

```text
x_K = [vx; vy]
vx_dot = ax + r*vy
vy_dot = ay - r*vx
A = [0 r; -r 0]
```

The implemented 100 Hz Euler prediction and Vx measurement update are:

```text
Ts = 0.01 s
F = [1 r*Ts; -r*Ts 1]
x_pred = F*x + Ts*[ax; ay]
z = true Vx
H = [1 0]
```

Frozen baseline parameters:

```text
P0   = diag([0.1, 0.1])
Q_K  = diag([1e-4, 1e-3])
R_Vx = 1e-4
```

The gain uses scalar right division by `S`, not `inv`. Covariance uses the
Joseph update and explicit roundoff symmetrization. `obs_metric=abs(r)` and
`abs(r)>0.01 rad/s` is a diagnostic partition only; it is not a formal LifeSig
or online observability gate. True Vy is used only for offline validation and
is not an online K-KF input.

## 2. Final acceptance matrix

| Area | Evidence | Result |
|---|---|---|
| Core unit tests | 13 core checks passed; deterministic randomized sequence remained finite, symmetric, and positive definite | ACCEPTED |
| Wrapper unit tests | 7 wrapper checks passed; persistent advancement and explicit-reset reproducibility verified | ACCEPTED |
| Combined V2.1-A | 20/20 tests; `simulinkUsed=0`, `carSimUsed=0` | ACCEPTED |
| Covariance implementation | Joseph form independently reconstructed; symmetry and positive definiteness verified | ACCEPTED |
| Matrix operation | scalar right division used; no explicit inverse | ACCEPTED |
| Reset behavior | initializes `x=[z;0]`, `P=P0`; runtime reset high exactly once at `t=0` | ACCEPTED |
| Function-call integration | TriggerType `function-call`; local scheduler MaskType `Function-Call Generator`; actual scheduler connection verified | ACCEPTED |
| Integration gates | 22/22 gates passed; default validation path does not rebuild or rewrite the frozen model | ACCEPTED |
| Compiled sample time | K-KF parent, Ax, Ay, AVz, and Vx boundary `[0.01 0]`; raw Vx `[0.001 0]` | ACCEPTED |
| Input dimensions/types | `3 / 1 / 1`, all double | ACCEPTED |
| Output dimensions/types | `2 / 2x2 / 5`, all double | ACCEPTED |
| Required logging | `kkf_u_log1`, `kkf_x_log1`, `kkf_P_log1`, `kkf_diag_log1` | ACCEPTED |
| Runtime rate | G1-A and G1-B each produced 1601 aligned samples over 0-16 s with actual `dt=0.01 s` | ACCEPTED |
| Runtime numerical behavior | x/P/diagnostics finite; maximum covariance asymmetry 0; minimum covariance eigenvalue positive | ACCEPTED |
| G1-A B0 replay | maxAbsXDiff / maxAbsPDiff / maxAbsDiagDiff = `0 / 0 / 0` | ACCEPTED |
| G1-B B0 replay | maxAbsXDiff / maxAbsPDiff / maxAbsDiagDiff = `0 / 0 / 0` | ACCEPTED |
| Genuine steering path | Both 0.02 and 0.04 rad commands reached FL/FR CarSim boundaries; RL/RR remained zero | ACCEPTED |
| Yaw-dependent observability | Higher yaw increased typical K21 coupling and substantially reduced P22 | ACCEPTED |
| Independence | no true Vy or D-EKF output is used online by K-KF | ACCEPTED |

## 3. Genuine observability acceptance

The old C1 and E runs are a **ZERO-STEER HISTORICAL BASELINE**. They are not
genuine 0.02/0.04 rad steering cases. The accepted genuine A/B evidence is
only G1-A and G1-B:

| Evidence | G1-A genuine 0.02 rad | G1-B genuine 0.04 rad |
|---|---:|---:|
| mean abs(r) | 0.079225 | 0.156644 |
| mean abs(K21) | 1.591888 | 1.721434 |
| median abs(K21) | 1.702030 | 1.926812 |
| p95 abs(K21) | 2.742458 | 2.707361 |
| max abs(K21) | 2.923491 | 2.787834 |
| P22 final | 0.340020 | 0.165911 |
| online Vy RMSE (m/s) | 0.259628 | 0.139960 |
| online Vy final error (m/s) | -0.284806 | -0.145520 |

Higher yaw observability improved: mean/median K21 increased and P22 was much
more strongly constrained. This is a sustained/typical coupling conclusion,
not a claim that peak K21 increased; p95 and maximum K21 did not increase.

## 4. Deterministic-bias sensitivity

Offline B3 removed only the known deterministic Ay and AVz injected biases:

```text
G1-A B3 Vy RMSE = 0.028675 m/s
G1-B B3 Vy RMSE = 0.028976 m/s
```

Both errors fell to approximately 0.029 m/s. The higher-yaw P22/covariance
observability benefit remained, but B3 Vy RMSE did not continue to improve
monotonically. The small B3 difference is not evidence that higher yaw
fundamentally worsens K-KF. The complete V2.1 evidence identifies no structural
algorithm error and supplies no Q/R tuning basis.

Historical zero-steer attribution remains documented: deterministic AVz bias
was the dominant drift source, while Ay bias partially counteracted that
drift. No online bias correction was implemented.

## 5. Known limitations

1. Vy observability weakens as `r` approaches zero.
2. Under weak excitation, P22 grows and is less strongly constrained.
3. Deterministic AVz bias was the primary source of the historical zero-steer
   Vy drift.
4. Ay bias partially counteracted that historical drift.
5. Higher yaw materially improves covariance observability.
6. After dominant deterministic bias removal, higher yaw does not guarantee
   monotonically lower Vy RMSE.
7. Online bias correction is not implemented.
8. Q/R/P0 tuning was not performed.
9. LifeSig is not implemented.
10. Fusion is not implemented.

No additional defect judgment is inferred beyond this evidence.

## 6. Freeze manifest

The machine-readable manifest is
`results/vy_kkf_v2_1h_freeze_manifest.csv`. Final independently recomputed
SHA-256 values are:

| File | Role | SHA-256 | Status |
|---|---|---|---|
| `model/vy_kinematic_kf_step.m` | K-KF mathematical step core | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` | FROZEN |
| `model/vy_kinematic_kf.m` | persistent K-KF wrapper | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` | FROZEN |
| `model/vx_vy_kkf_v2_1.slx` | accepted independent K-KF base integration model | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | FROZEN |
| `model/vx_vy_kkf_v2_1g_steer.slx` | accepted genuine-steering validation model | `59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E` | FROZEN |
| `model/vx.slx` | legacy vehicle source model | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` | FROZEN |
| `model/vx_ax_imu_prereq_v2_1.slx` | Ax-IMU prerequisite model | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` | FROZEN |
| `model/vx_vy_dekf_v1_17.slx` | D-EKF V1.17 frozen model | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | FROZEN |

All core/wrapper and model hashes match their established baselines. No hash
or evidence conflict was found.

## 7. Acceptance and future boundary

- K-KF mathematical implementation: ACCEPTED
- Simulink integration: ACCEPTED
- Runtime numerical behavior: ACCEPTED
- Yaw-dependent observability behavior: EXPERIMENTALLY CONFIRMED
- Deterministic bias sensitivity: DOCUMENTED
- Q/R tuning: NOT AUTHORIZED
- Online bias correction: NOT IMPLEMENTED

The next stage is not started automatically. Only the necessary DK-EKF
baseline stage is identified as the permitted handoff direction.

## 8. Final declarations

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

K-KF V2.1 IS ACCEPTED AND FROZEN.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE BIAS CORRECTION WAS IMPLEMENTED.

NO FUSION WAS PERFORMED.

NO LIFESIG IMPLEMENTATION WAS PERFORMED.

NO OBSERVABILITY GATE WAS IMPLEMENTED.

NO D-EKF FILE WAS MODIFIED.

NO K-KF CORE/WRAPPER FILE WAS MODIFIED.

NO FROZEN SIMULINK MODEL WAS MODIFIED.

NO NEW SIMULATION OR CARSIM RUN WAS PERFORMED IN V2.1-H.

V2.2 WAS NOT STARTED.

## 9. Stop-state

**V2.1-H INDEPENDENT K-KF ACCEPTED AND FROZEN**

**READY FOR THE NECESSARY DK-EKF BASELINE STAGE**
