# V2.5-A Fixed-Weight Three-Track Fusion Architecture Audit

## 1. Stage decision

**V2.5-A FIXED-WEIGHT THREE-TRACK FUSION ARCHITECTURE ACCEPTED**

本阶段仅完成 architecture、interface 与 mathematical-contract 审计。没有启动 MATLAB、compile、simulation 或 CarSim；没有创建 fusion code/SLX/runtime artifact；没有修改 frozen D-EKF、K-KF、DK-EKF、parallel D/K 或 F-track；没有选择或调节权重；没有实现 adaptive weighting、LifeSig、reliability logic 或 fusion feedback。

本阶段接受的是一个可复现的 **OPEN-LOOP THREE-TRACK STATE FUSION BASELINE**，不是最终 adaptive estimator。

## 2. Existing fusion-definition audit

对 `docs/`、`model/`、`results/` 中的文本文件进行了有界关键词搜索，并对 `model/` 下 21 个 SLX 的压缩 XML 做了只读 token 搜索。搜索项包括 `alpha_D`、`alpha_K`、`alpha_F`、`Vy_FW`、`Vy_fused`、`Vy_final`、fixed-weight/weighted/three-track fusion 及中文等价词。

实际分类如下：

- V2.3 documents/validators only assert that weighted fusion and fused outputs do not exist.
- V2.4-A contains only a future candidate equation and explicitly states that weights, normalization, fallback and fused output are not defined.
- SLX matches are tire slip-angle symbols `alpha_f`; they are unrelated to estimator weights.
- `docs/STAGE_2A_FUSION_FORMULAS.md` defines a separate longitudinal-speed WSS/IMU two-channel correlated fusion for `v_x`. It is not a lateral-Vy D/K/F fusion and is not reused here.
- No model, code, result or approved document defines a lateral three-track combiner or `Vy_FW` implementation.

**NO PRE-EXISTING IMPLEMENTED THREE-TRACK FUSION FOUND**

There is no conflicting approved lateral-Vy fusion mathematics to override.

## 3. Accepted fixed-weight mathematical contract

The fixed-weight baseline output is:

```text
Vy_FW = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

The immutable parameter ordering is:

```text
alpha = [alpha_D; alpha_K; alpha_F]
```

Units:

```text
Vy_D, Vy_K, Vy_F, Vy_FW : m/s
alpha_D, alpha_K, alpha_F : dimensionless
```

Pre-runtime constraints:

```text
all alpha values are finite scalar doubles
alpha_D >= 0
alpha_K >= 0
alpha_F >= 0
abs(alpha_D + alpha_K + alpha_F - 1) <= 1e-12
```

The `1e-12` sum tolerance is a strict double-precision parameter-validation tolerance, not a weight tuning parameter. Invalid weights must cause an explicit pre-runtime error. Runtime silent normalization such as `alpha=alpha/sum(alpha)` is prohibited because it would conceal invalid configuration.

## 4. Strict meaning of fixed weights

Within one runtime, `alpha_D`, `alpha_K` and `alpha_F` are constant parameters. They cannot depend on:

- time;
- `P_D`, `P_K` or `P_F`;
- NIS, LifeSig or reliability;
- observability or AVz partition;
- vehicle state or sensor-validity flags;
- online/offline truth error;
- any switching, fallback or adaptive logic.

There is no runtime renormalization, hard selection or validity-dependent reweighting. The numerical values remain:

```text
NOT YET SELECTED
NOT TUNED
NOT FROZEN
```

Only parameter names, ordering, units, constraints and mathematical position are accepted in V2.5-A. A single V2.3-D nominal case is not sufficient evidence for selecting baseline weights.

## 5. A. Fusion interface table

| Item | Fixed-weight fusion contract |
|---|---|
| Inputs | scalar-double `Vy_D`, `Vy_K`, `Vy_F`, all in m/s |
| Parameters | scalar-double dimensionless `alpha_D`, `alpha_K`, `alpha_F` |
| Parameter constraints | finite; nonnegative; sum-to-one within `1e-12`; validated before runtime |
| Output | scalar-double `Vy_FW`, m/s |
| Output meaning | FIXED-WEIGHT THREE-TRACK FUSION BASELINE OUTPUT |
| Rate | 100 Hz using same-current-sample D/K/F values |
| State memory | none |
| Fusion delay | none |
| Covariance input | none |
| Covariance output | none |
| Truth input | none |
| Feedback | none; `Vy_FW` is not returned to F-track |
| Diagnostics | none required; weights remain inspectable parameters |

The output must not be named `Vy_final`. Fixed fusion is a comparison baseline; adaptive covariance/reliability processing and the final estimator output do not yet exist.

## 6. B. Track input table

| Track | Signal used | Included? |
|---|---|---|
| Frozen D-EKF | `Vy_D`, scalar m/s | YES |
| Frozen K-KF | `Vy_K`, scalar m/s | YES |
| Frozen F-track | `Vy_F`, scalar m/s | YES |
| Frozen DK-EKF V2.2 | none; comparison baseline only | NO |

DK-EKF must not be silently added as a fourth input. This architecture is exactly D/K/F three-track state fusion.

## 7. State-only output and covariance warning

D/K/F estimation errors are structurally correlated because the tracks share physical signals including Ay, AVz and Vx. V2.3-D also measured:

```text
corr(e_D,e_K) = 0.26540777187448517
```

This is nonzero. Future F feedback would introduce further correlation through a shared fused-history path.

Therefore:

**D/K/F ESTIMATION ERRORS ARE NOT ASSUMED INDEPENDENT.**

The expression

```text
alpha_D^2*P_D(1,1) + alpha_K^2*P_K(2,2) + alpha_F^2*P_F
```

is not accepted as an exact fused variance because it silently sets all cross-covariances to zero. The existing longitudinal two-channel correlated-fusion framework is not a validated D/K/F lateral cross-covariance framework and cannot be transplanted by analogy.

The accepted V2.5 baseline therefore has:

```text
FIXED-WEIGHT BASELINE OUTPUTS STATE ONLY.
NO FUSED COVARIANCE IS GENERATED.
```

## 8. D/K/F covariance alignment for future work

The state-aligned uncertainty locations remain:

| Track | State definition | Vy variance location |
|---|---|---|
| D-EKF | `[Vy;r]` | `P_D(1,1)` |
| K-KF | `[Vx;Vy]` | `P_K(2,2)` |
| F-track | scalar `Vy_F` | scalar `P_F` |

These may become inputs to a separately designed adaptive/correlation-aware fusion interface. V2.5 fixed-weight fusion must not read them.

## 9. F-track feedback policy

V2.4 froze an atomic feedback contract consisting of state, covariance and valid flag, all delayed by exactly one sample. Because V2.5 fixed fusion outputs `Vy_FW` only and does not generate a statistically defensible `P_FW`, it must not feed state alone back into F while retaining stale `P_F` or inventing a placeholder covariance.

For all V2.5 fixed-weight baseline development unless a later architecture stage explicitly changes this boundary:

```text
F feedback_valid = false
Vy_FW -> F feedback = prohibited
placeholder P -> F feedback = prohibited
direct Vy_D/Vy_K -> F feedback = prohibited
```

The loop remains open not because F-track cannot accept feedback, but because state-only closure would violate the frozen state/covariance/valid atomic feedback contract.

Future closure requires a separately accepted design that simultaneously defines fused state, fused covariance, valid semantics and a one-sample delay.

## 10. Current and future architecture diagrams

Current V2.5 fixed baseline:

```text
D-EKF Vy_D ─┐
            │
K-KF Vy_K ──┼──> stateless fixed-weight combiner ──> Vy_FW
            │
F-track Vy_F┘

F-track remains standalone
feedback_valid = false
NO Vy_FW feedback to F-track
```

Future boundary only:

```text
Adaptive/correlation-aware fusion
        │
        └──> fused state / covariance / valid
                         │
                         v
                 common one-sample z^-1
                         │
                         v
                      F-track

FUTURE ONLY — NOT V2.5
```

## 11. C. Weight policy table

| Property | V2.5 fixed baseline | Future adaptive stage |
|---|---|---|
| Time varying | NO | Not defined here |
| Uses P | NO | May use aligned P only after correlation consistency is resolved |
| Uses LifeSig | NO | Not defined here |
| Uses NIS | NO | Not defined here |
| Uses observability | NO | Not defined here |
| Can switch/fallback | NO | Not defined here |
| Normalization | no runtime normalization; pre-runtime sum check only | Not defined here |
| Parameter status | names/constraints accepted; values unselected/untuned/unfrozen | Not defined here |
| Error-independence assumption | explicitly NO | must be justified rather than assumed |
| Covariance output | none | requires separate architecture |

V2.5-A does not design inverse-covariance weights, Kalman fusion, covariance intersection, cross-covariance estimation, adaptive alpha or LifeSig weighting.

## 12. D. Feedback policy table

| Signal/path | V2.5 fixed baseline | Future separately approved stage |
|---|---|---|
| `Vy` fusion -> F | prohibited | possible only as part of atomic state/P/valid feedback |
| `P` fusion -> F | not generated | must be statistically defensible and paired with state |
| valid -> F | constant false | must be explicitly defined |
| return-path delay | no return path | exactly one common sample for state/P/valid |
| closed loop | NO | only after algebraic-loop and covariance-consistency acceptance |
| direct D/K -> F | prohibited | remains prohibited; only final fused feedback may be considered |

## 13. Degenerate weights and regression cases

The future mathematical core must accept all valid convex cases, including:

```text
[1,0,0]  -> exact D passthrough
[0,1,0]  -> exact K passthrough
[0,0,1]  -> exact F passthrough
```

An ordinary convex vector such as `[1/3,1/3,1/3]` may be used as a TEST-ONLY unit-test case. It is not the selected fixed baseline and must not be promoted to a final weight set by implication.

## 14. Timing and statelessness

The combiner executes at 100 Hz and consumes the same current sample:

```text
Vy_D(k), Vy_K(k), Vy_F(k) -> Vy_FW(k)
```

It adds no state memory, estimator dynamics or artificial D/K/F shift. The mathematical core is a deterministic stateless algebraic combiner. Equal current inputs and parameters must produce equal output independently of call history.

## 15. Truth and calibration policy

`TRUE Vy ONLINE INPUT = NO.` Truth Vy may be used only for offline weight studies, offline validation and performance metrics.

If later baseline weights are calibrated with offline truth, calibration and validation datasets must be explicitly separated. The same operating case cannot both tune weights and support a claim of independent validation.

## 16. Comparison role

The fixed D/K/F result may later serve as a simple comparison baseline against:

- D-EKF;
- K-KF;
- DK-EKF comparison baseline;
- final adaptive multi-track fusion.

It is not the final method and carries no claim of optimality, independence-aware covariance or reliability adaptation.

## 17. Frozen-foundation integrity

The accepted V2.4-E manifest remains:

```text
results/vy_feedback_track_v2_4e_freeze_manifest.csv
SHA-256 = 3F986E96B0148B6EFE6DD7085644D7F87067DB95C52BA7839C86776DF8B9E1C2
```

All 44 file-backed/excluded rows were read; every file-backed SHA-256 matched. This includes three F-track `FROZEN_IMPLEMENTATION` entries and 13 D/K/DK-EKF/parallel `REFERENCED_FROZEN_DEPENDENCY` entries. No frozen artifact was modified in V2.5-A.

## 18. Acceptance gates

| Gate | Result |
|---|---|
| No conflicting lateral three-track fusion implementation | PASS |
| Convex fixed-state equation accepted | PASS |
| Constant/nonnegative/sum-to-one alpha contract accepted | PASS |
| Scalar `Vy_FW` output contract accepted | PASS |
| No covariance-independence assumption introduced | PASS |
| No `P_FW` claimed or generated | PASS |
| F feedback remains open | PASS |
| D/K/F implementations and mathematics unchanged | PASS |
| DK-EKF excluded from fusion inputs | PASS |
| True Vy excluded online | PASS |
| No adaptive/reliability/LifeSig logic | PASS |
| Weight values remain unselected/untuned/unfrozen | PASS |

## 19. Next bounded stage

The only next stage is:

**V2.5-B — FIXED-WEIGHT FUSION MATHEMATICAL CORE**

Its scope is limited to a stateless weighted-sum core, explicit pre-runtime weight validation and deterministic unit tests. It must not perform Simulink integration, select/tune weight values, close F feedback, create fused covariance, run CarSim, or implement adaptive/LifeSig logic.

## 20. Final acceptance statements

FIXED-WEIGHT STATE FUSION EQUATION ACCEPTED.

WEIGHTS ARE CONSTANT, NONNEGATIVE, AND SUM TO ONE.

WEIGHT VALUES ARE NOT YET SELECTED OR FROZEN.

FIXED-WEIGHT FUSION IS STATE-ONLY.

NO FUSED COVARIANCE IS CLAIMED.

D/K/F ERRORS ARE NOT ASSUMED INDEPENDENT.

F-TRACK FEEDBACK REMAINS DISABLED IN V2.5.

NO FUSION-FEEDBACK LOOP IS CLOSED.

NO ADAPTIVE WEIGHTING WAS DESIGNED.

NO LIFESIG WAS IMPLEMENTED.

READY FOR V2.5-B FIXED-WEIGHT FUSION MATHEMATICAL CORE
