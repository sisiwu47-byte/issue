# V2.4-A Third Feedback / Propagation Track Architecture Audit

- Date: 2026-08-28
- Scope: architecture and mathematical-contract audit only
- Final decision: **V2.4-A THIRD FEEDBACK / PROPAGATION TRACK ARCHITECTURE ACCEPTED**
- Simulation / CarSim / compile / builder: **NOT RUN**
- Model, estimator, or frozen artifact modification: **NONE**
- Third-track implementation / fusion / LifeSig: **NONE**

## 1. Existing-definition audit

A bounded read-only search was performed in `docs/`, `model/`, and `results/`
for `feedback track`, `propagation track`, `third track`, `Vy_F`, `P_F`,
`feedback Vy`, `propagated Vy`, `feedback propagation`, and Chinese-equivalent
terms. Existing V2.3 artifacts contain only prohibitions, absence gates, and
readiness statements for a future third track. They contain no approved
third-track state equation, covariance equation, feedback contract, or
implemented third-track block/code.

Occurrences of `P_fused` and fusion formulae in the separate longitudinal-
velocity project do not define a lateral-Vy F-track and are outside this
architecture. They are not reused or silently substituted here.

**NO PRE-EXISTING IMPLEMENTED THIRD-TRACK MATHEMATICS FOUND**

Therefore this audit does not override an existing approved Vy third-track
design.

## 2. Frozen K-KF sign and unit audit

The frozen K-KF core defines:

```matlab
F = [1, r*Ts; -r*Ts, 1];
x_pred = F*x + Ts*[ax; ay];
```

with `x=[Vx;Vy]`, `u=[Ax;Ay;r]`, and `Ts=0.01 s`. Its second state row is
therefore exactly:

```text
Vy_pred = Vy_previous + Ts*(Ay - r*Vx)
```

The proposed scalar propagation uses the same sign and kinematic relation.
Its units are consistent:

```text
Ay                 m/s^2
r * Vx             (rad/s)*(m/s) = m/s^2, with rad dimensionless
Ay - r*Vx          m/s^2
Ts*(Ay-r*Vx)       m/s
Vy_F               m/s
```

The checked frozen artifacts remain:

```text
model/vy_kinematic_kf_step.m
SHA-256 = 3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244

model/vy_kinematic_kf.m
SHA-256 = F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4
```

## 3. Exact F-track mathematical contract

### 3.1 State and covariance

The track has one scalar state of interest and one scalar variance:

```text
x_F = Vy_F                       [m/s]
P_F = Var(Vy_F)                  [(m/s)^2]
```

It has no Vx state, no yaw-rate state, and no cross-covariance matrix.

### 3.2 Timing and base selection

The track executes at 100 Hz with:

```text
Ts = 0.01 s
```

At every non-reset hit `k`, define:

```text
if feedback_valid(k):
    Vy_base(k) = Vy_feedback(k)
    P_base(k)  = P_feedback(k)
else:
    Vy_base(k) = Vy_F(k-1)
    P_base(k)  = P_F(k-1)
```

The feedback triplet at the F boundary is contractually **already delayed by
one sample**. In a future fusion integration:

```text
Vy_feedback(k)    = Vy_hat(k-1)
P_feedback(k)     = P_hat(k-1)
feedback_valid(k) = fusion_valid(k-1)
```

Current-sample fusion output is never a direct-feedthrough F input.

### 3.3 Propagation

For each non-reset hit:

```text
prop_term(k) = Ay_IMU(k) - AVz_IMU(k)*Vx_source(k)        [m/s^2]
deltaVy(k)   = Ts*prop_term(k)                            [m/s]
Vy_F(k)      = Vy_base(k) + deltaVy(k)                    [m/s]
P_F(k)       = P_base(k) + Q_F                            [(m/s)^2]
```

`Q_F` is a discrete per-propagation-step variance increment with unit
`(m/s)^2/step`. It is not a continuous-time spectral density. Any future use
of a continuous noise density must define and validate its discretization in a
separate stage.

### 3.4 Reset dominance

When `reset(k)=true`, reset dominates propagation:

```text
Vy_F(k) = Vy_F0
P_F(k)  = P0_F
diag_F  = [0;0;0]
```

The previous F state/covariance and the feedback-delay history are cleared.
The feedback delay is initialized invalid, with safe stored placeholders
`Vy_F0` and `P0_F`. No propagation or feedback is applied on the reset hit.
True Vy is not used for initialization.

## 4. A. State/interface table

| Item | F-track contract |
|---|---|
| State | scalar `Vy_F`, m/s |
| Covariance | scalar `P_F=Var(Vy_F)`, `(m/s)^2` |
| Physical inputs | scalar `Ay_IMU` m/s^2, `AVz_IMU` rad/s, `Vx_source` m/s |
| Feedback inputs | scalar delayed `Vy_feedback`, delayed `P_feedback`, delayed `feedback_valid` |
| Lifecycle input | scalar/logical-compatible `reset` |
| Parameters | `Ts`, `Vy_F0`, `P0_F`, discrete per-step `Q_F` |
| Outputs | scalar `Vy_F`, scalar `P_F`, fixed `3x1` numeric `diag_F` |
| Rate | independent 100 Hz, `Ts=0.01 s` |
| Reset | output `Vy_F0/P0_F`; clear own memory and feedback delay; no true-Vy initialization |
| Feedback | availability-based selection of the delayed state/covariance pair; not a measurement update |
| True Vy usage | offline truth only; online use is prohibited |

All required scalar physical and feedback inputs must be finite. When
`feedback_valid=true`, `Vy_feedback` must be finite and `P_feedback` must be a
finite nonnegative scalar. Contract violation must be reported; it must not be
silently converted into reliability logic.

## 5. B. Signal-source table

| Signal | Source | Role | Online allowed? |
|---|---|---|---|
| `Ay_IMU` | common physical IMU fan-out | lateral acceleration in propagation | YES |
| `AVz_IMU` | common physical IMU fan-out | physical yaw rate `r` in propagation | YES |
| `Vx_source` | current physical true-Vx isolation source | exogenous longitudinal speed in `r*Vx` | YES, baseline isolation only |
| `Vy_feedback` | standalone: unused; future: delayed final-fusion state | optional propagation base state | RESERVED; not connected in V2.4-A/B standalone work |
| `P_feedback` | standalone: unused; future: delayed final-fusion variance | covariance base paired with state feedback | RESERVED; not connected in V2.4-A/B standalone work |
| `feedback_valid` | standalone constant false; future delayed fusion availability | selects delayed feedback pair versus own prior pair | YES as availability only; not LifeSig/reliability |
| true Vy | CarSim truth log | offline validation truth | NO online |

Direct inputs from `r_D_hat`, `r_K_hat`, `Vy_D`, `Vy_K`, `P_D`, or `P_K` are
prohibited. Steering and Ax are deliberately absent: the scalar lateral
kinematic relation requires only physical Ay, physical yaw rate, and Vx.
Inputs are not added merely for interface symmetry.

True Vx is retained only to isolate F-track mathematics consistently with the
frozen D/K baseline. Replacing it with a longitudinal `vx_hat` requires its
own explicit validation stage and must not be introduced silently.

## 6. C. D/K/F comparison table

| Property | D-EKF | K-KF | F-track |
|---|---|---|---|
| Purpose | dynamic lateral estimator | kinematic two-state estimator | one-step/short-horizon propagation of a previous feedback or own F state |
| State | `[Vy;r]` | `[Vx;Vy]` | scalar `Vy_F` |
| Measurement correction | Ay/r measurement updates | scalar Vx measurement update | none |
| Vx handling | exogenous physical dynamics input | Vx state plus Vx measurement correction | exogenous physical propagation input; no Vx state/update |
| Ax handling | unused | process input | unused |
| Ay handling | measurement with frozen multirate semantics | process input | physical propagation input only |
| AVz handling | yaw-rate measurement | physical process input | physical propagation input only |
| Steering handling | four-wheel dynamics input | unused | unused |
| Feedback dependence | none | none | standalone none; future delayed final-fusion feedback allowed |
| Covariance | independent 2x2 `P_D` | independent 2x2 `P_K` | scalar `P_F` propagated without measurement correction |

F-track is not another K-KF: it has no Vx state, no Vx measurement update, no
Kalman gain, no measurement correction, and no shared 2x2 state covariance.
It is also not another D-EKF, a weighted D/K fusion, a hard switch, or a
LifeSig track.

## 7. Feedback-valid and covariance semantics

`feedback_valid=true` means only that the **previous, delayed** feedback
state/covariance pair is available and must be used as the current propagation
base. It is not:

- a measurement update;
- a fusion gate;
- LifeSig;
- a reliability or observability decision;
- permission to use an undelayed current-sample result.

State and covariance feedback are inseparable. If the propagation base state
is replaced by delayed fused `Vy_feedback`, its base uncertainty must also be
the paired delayed `P_feedback`. Replacing state while retaining unrelated old
`P_F` is prohibited because it breaks state/covariance consistency.

`feedbackApplied=1` reports that the delayed pair was actually consumed on
the current non-reset hit. In standalone mode it remains zero.

## 8. Standalone and future-feedback modes

### Standalone baseline

```text
Vy_F0 = 0 m/s
P0_F  = configurable positive scalar
feedback_valid = false at every hit
```

After reset, the track recursively propagates its own previous `Vy_F/P_F`.
This mode is sufficient for unit tests, integration tests, and short runtime
validation without D/K or fusion coupling.

### Future fusion-feedback mode

Future fusion may consume current candidates `Vy_D(k)`, `Vy_K(k)`, and
`Vy_F(k)` and publish a fused state/covariance. Only its one-sample-delayed
state/covariance/valid triplet may become the F base at the next hit. D/K
remain mutually independent; F becomes feedback-dependent only through this
explicit delayed final-fusion boundary.

## 9. Algebraic-loop prevention

The required future data dependency is:

```text
physical Ay/r/Vx at k ---------------------------> F propagation at k
                                                        |
                                                        v
D(k), K(k), F(k) -------------------------------> future fusion at k
                                                        |
                                                        v
                                           explicit z^-1 state/P/valid
                                                        |
                                                        v
                                                F base at k+1
```

The forbidden dependency is:

```text
F(k) -> fusion(k) -> Vy_hat(k)/P_hat(k) -> F(k)
```

Future integration must provide statically checkable gates:

- feedback delay exists for state, covariance, and valid flag;
- feedback-delay reset/initialization is defined;
- no undelayed fusion-to-F direct feedthrough exists;
- no algebraic-loop path exists.

## 10. D. Future-loop table

| Path | Allowed now? | Allowed later? | Delay required? |
|---|---|---|---|
| direct D -> F | NO | NO direct path; D may only contribute indirectly through final fusion | N/A; fusion return rule applies |
| direct K -> F | NO | NO direct path; K may only contribute indirectly through final fusion | N/A; fusion return rule applies |
| fusion -> F | NO | YES in a separately authorized feedback-integration stage | YES, state/P/valid all through `z^-1` |
| F -> fusion | NO because fusion does not yet exist | YES as one candidate input | no forward delay required; the fusion return path must be delayed |

V2.4-A and standalone F development prohibit `Vy_D -> F`, `Vy_K -> F`,
`P_D -> F`, `P_K -> F`, and every fusion input. Only common physical sensor
fan-out is allowed.

## 11. Output and diagnostic contract

The proposed exact output contract is:

```text
Vy_F                         scalar m/s
P_F                          scalar (m/s)^2
diag_F = [                   fixed 3x1 double
    prop_term;               m/s^2
    deltaVy;                 m/s
    feedbackApplied          dimensionless numeric 0 or 1
]
```

The ordering directly exposes the propagation derivative, its actual
one-sample increment, and the selected base source. No NIS, observability
score, adaptive Q, reliability weight, LifeSig, or `alpha_F` is defined.

## 12. Parameter policy

| Parameter | Meaning | Unit | Requirement | V2.4-A status |
|---|---|---|---|---|
| `Ts` | discrete propagation interval | s | finite and `>0`; baseline `0.01` | architecture fixed |
| `Vy_F0` | reset state | m/s | finite; standalone baseline `0` | interface fixed |
| `P0_F` | reset variance | `(m/s)^2` | finite and `>0` | numeric value NOT YET FROZEN |
| `Q_F` | variance added per discrete hit | `(m/s)^2/step` | finite and `>=0` | numeric value NOT YET FROZEN |

No nominal `P0_F` or `Q_F` number is inferred or tuned in V2.4-A. V2.4-B may
use explicit test-only parameter values to exercise equations and numerical
guards, but those values must be labelled test-only and cannot become final
tuning by implication.

## 13. Future fusion boundary

The eventual architecture may evaluate:

```text
Vy_hat = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

and may read state-aligned variances `P_D(Vy)=P_D(1,1)`,
`P_K(Vy)=P_K(2,2)`, and scalar `P_F`. V2.4-A freezes only the F output
contract. It defines no `alpha_D`, `alpha_K`, `alpha_F`, normalization,
fallback, reliability policy, switch, or `Vy_fused`.

## 14. Architecture acceptance gates

| Gate | Decision |
|---|---|
| Existing project definitions checked | PASS |
| No conflicting implemented third-track mathematics | PASS |
| Scalar propagation sign matches frozen K-KF | PASS |
| Units are dimensionally consistent | PASS |
| Feedback state/covariance semantics are paired and unambiguous | PASS |
| Standalone mode requires no D/K/fusion input | PASS |
| Future fusion return requires explicit one-sample delay | PASS |
| Reset clears F and feedback-delay state | PASS |
| True Vy online excluded | PASS |
| `Q_F/P0_F` parameterized but not tuned | PASS |
| No premature D/K/fusion/LifeSig connection | PASS |

## 15. Smallest next stage

The only next stage is:

**V2.4-B — FEEDBACK / PROPAGATION MATHEMATICAL CORE**

Its scope is limited to the scalar propagation core, scalar covariance
propagation, reset behavior, feedback-valid semantics, unit tests, and
numerical robustness. It must not perform Simulink integration or connect D,
K, fusion, LifeSig, fixed/adaptive weights, or a final Vy output. Later stages
may separately cover Simulink integration, short standalone runtime, and
characterization/freeze; core validation must not be skipped.

## 16. Final decision

**V2.4-A THIRD FEEDBACK / PROPAGATION TRACK ARCHITECTURE ACCEPTED**

Exact state: scalar `Vy_F` with scalar variance `P_F`.

Exact propagation: `Vy_F=Vy_base+Ts*(Ay_IMU-AVz_IMU*Vx_source)`.

Exact covariance propagation: `P_F=P_base+Q_F`, with discrete per-step `Q_F`.

Inputs/outputs: physical `Ay/AVz/Vx`, delayed feedback state/P/valid, reset;
scalar `Vy_F/P_F` and fixed `diag_F=[prop_term;deltaVy;feedbackApplied]`.

Reset: `Vy_F0/P0_F`, no propagation on reset hit, feedback history cleared,
and no true-Vy initialization.

Feedback-valid: availability of a paired one-sample-delayed feedback
state/covariance base, not a measurement, LifeSig, or reliability gate.

Standalone mode: `feedback_valid=false`, recursively propagate own prior
state/covariance.

Future feedback mode: only one-sample-delayed final-fusion state/covariance may
be used; no direct D/K feedback input is allowed.

Algebraic-loop prevention: mandatory `z^-1` on fusion-return state,
covariance, and valid flag; no current-sample fusion-to-F feedthrough.

Parameter policy: `Ts=0.01 s`; `P0_F>0` and `Q_F>=0`; their nominal numeric
values remain **NOT YET FROZEN** and untuned.

READY FOR V2.4-B FEEDBACK / PROPAGATION MATHEMATICAL CORE
