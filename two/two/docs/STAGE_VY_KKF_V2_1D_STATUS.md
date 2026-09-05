# STAGE VY K-KF V2.1-D STATUS

- Date: 2026-08-26
- Stage: V2.1-D IMU Bias Attribution Offline Replay
- Sol execution and independent acceptance: **COMPLETED**
- Runtime mode: **PURE OFFLINE REPLAY**
- CarSim / `sim()`: **NOT RUN**
- Online sensor or K-KF modification: **NONE**

## A. Created files

- `matlab/analyze_vy_kkf_v2_1d_bias_attribution.m`
- `results/vy_kkf_v2_1d_bias_attribution.mat`
- `results/vy_kkf_v2_1d_bias_attribution.csv`
- four PNG files under `results/plots/vy_kkf_v2_1d_bias_attribution/`
- `docs/STAGE_VY_KKF_V2_1D_STATUS.md`

The analysis called the frozen `vy_kinematic_kf` wrapper for every replay
sample. Each case explicitly cleared the wrapper persistent state and used
`reset=1` only for its first sample. C1 `Vy_true` was used only after replay to
calculate offline metrics.

## B. Baseline exact replay gate

The original 1601 C1 samples were replayed with the original
`Ax_IMU/Ay_IMU/AVz_IMU/Vx_meas` values.

```text
threshold      = 1e-12
maxAbsXDiff    = 0
maxAbsPDiff    = 0
maxAbsDiagDiff = 0
gate passed    = 1
```

B0 therefore exactly reproduced the online C1 state, covariance, and five
diagnostics.

## C. Replay metrics

| Case | Change from B0 | Vy RMSE | Vy MAE | Vy Bias | Vy MaxAbs | Final Vy error | P22 final/max | RMSE reduction | Final drift reduction |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| B0 | none | 0.797460 | 0.688034 | -0.688034 | 1.366490 | -1.366490 | 1.655274 | 0% | 0% |
| B1 | remove Ay bias | 0.979274 | 0.845940 | -0.845940 | 1.678369 | -1.678369 | 1.655274 | -22.7991% | -22.8234% |
| B2 | remove AVz bias | 0.176583 | 0.151781 | 0.151780 | 0.338017 | 0.336105 | 1.691216 | 77.8568% | 75.4037% |
| B3 | remove Ay+AVz bias | 0.016145 | 0.013179 | -0.007969 | 0.035595 | 0.017692 | 1.691216 | 97.9754% | 98.7053% |
| B4 | remove all configured bias | 0.014745 | 0.012109 | -0.007590 | 0.032379 | 0.013957 | 1.691216 | 98.1509% | 98.9787% |

## D. Deterministic-bias attribution

Signed final-error effects, calculated as the B0 final error minus the
corresponding no-bias case, are:

```text
Ay bias contribution             = +0.311879402951307 m/s
AVz bias contribution            = -1.702595174091405 m/s
Ay+AVz combined contribution     = -1.384181523742289 m/s
all configured bias contribution = -1.380446415399238 m/s
additional Ax effect (B3-B4)     = +0.003735108343051 m/s
additional Ax RMSE effect        = +0.001399748684384 m/s
```

The positive Ay bias partially cancels the much larger negative contribution
from AVz bias through the `-r*Vx` term. Removing Ay bias alone therefore makes
the negative drift worse. Removing Ay and AVz bias together reduces the Vy
RMSE by about 97.98% and the final absolute drift by about 98.71%. Removing Ax
bias after that produces only a small additional change.

## E. Theoretical accumulation

Using the actual C1 timestamps and measurement:

```text
biasVyDot = 0.02 - 0.005*Vx_meas
bias trajectory = cumtrapz(time, biasVyDot)

final theoretical drift        = -1.278577341557073 m/s
baseline final Vy error        = -1.366489883036026 m/s
baseline minus theory          = -0.087912541478953 m/s
trajectory RMSE                = 0.060234051569963 m/s
correlation coefficient        = 0.999642754929845
final magnitude explained      = 93.5665%
```

The deterministic bias integral explains the dominant magnitude and shape of
the C1 Vy drift without being injected into the filter.

## F. Interpretation

1. B0 exactly reproduces C1 online behavior.
2. Ay bias contributes approximately `+0.312 m/s` at the final sample and
   partially cancels negative drift.
3. AVz bias is the dominant negative term, contributing approximately
   `-1.703 m/s` relative to B2.
4. Removing Ay+AVz bias reduces Vy RMSE and final drift by about 98%.
5. Ax bias has only a small additional Vy effect in this replay.
6. The theoretical integral explains about 93.6% of the final drift magnitude
   and has a trajectory correlation of about 0.99964.
7. The C1 drift is primarily **sensor deterministic bias accumulation**, with
   a smaller residual process/model mismatch. Weak Vy observability remains:
   removing the bias does not reduce P22, and the original run was 94.69%
   low-r. This replay does not establish an algorithm structural defect or
   justify Q/R changes.
8. Evidence is strong enough to consider bias handling in the next planning
   step, but not to implement it automatically. A higher yaw-rate excitation
   test is still needed to validate attribution and observability away from the
   mostly low-r C1 condition before an online correction design is accepted.

## G. Scope and frozen evidence

```text
simCalled                       = 0
carSimRun                       = 0
trueVyFedToFilter               = 0
onlineBiasCorrectionImplemented = 0
qrP0TuningPerformed             = 0
dekfOutputUsed                  = 0
fusionPerformed                 = 0
v2_2Started                     = 0
```

| Frozen file | SHA-256 |
|---|---|
| `model/vx.slx` | `754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB` |
| `model/vx_ax_imu_prereq_v2_1.slx` | `226238301763460F4B609B0249D61B720C6510DD561923C5D066C33E5967F439` |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` |
| `matlab/vy_kinematic_kf_step.m` | `3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244` |
| `matlab/vy_kinematic_kf.m` | `F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4` |

All before/after hashes are identical to the frozen baselines.

## H. Figures

1. `results/plots/vy_kkf_v2_1d_bias_attribution/01_online_vs_baseline_replay.png`
2. `results/plots/vy_kkf_v2_1d_bias_attribution/02_vy_bias_case_trajectories.png`
3. `results/plots/vy_kkf_v2_1d_bias_attribution/03_vy_bias_case_errors.png`
4. `results/plots/vy_kkf_v2_1d_bias_attribution/04_theoretical_bias_attribution.png`

All four figures were independently inspected by Sol.

## Mandatory declarations

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

TRUE Vy WAS USED FOR OFFLINE VALIDATION ONLY.

TRUE Vx REMAINED THE V2.1 ISOLATION MEASUREMENT.

NO D-EKF OUTPUT WAS USED.

NO Q/R TUNING WAS PERFORMED.

NO ONLINE SENSOR BIAS CORRECTION WAS IMPLEMENTED.

NO FUSION WAS PERFORMED.

V2.2 WAS NOT STARTED.

## Stop-state

**V2.1-D BIAS ATTRIBUTION COMPLETED**
