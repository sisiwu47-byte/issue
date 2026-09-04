# V2.7-A3R5 Revised Fusion Offline Behavior Audit

## Verdict

```text
REVISED_LIFESIG_BEHAVIOR_CONFIRMED_WEAKLY_ADAPTIVE
```

The revised A3R4 formula behaves exactly as specified and is genuinely
time-varying. Its practical adaptation is weak under the available five
calibration maneuvers because D and K remain continuously available and the
only continuous gate acts on F, whose frozen prior is about 1.1% initially.

This was an offline replay only. No Simulink model was loaded, no `sim()` or
CarSim runtime was performed, no holdout data was used, and no q, tau, gate,
Q/R, model, or fusion source was modified.

## Frozen inputs replayed

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452

tau_F = 28.252990189369939 s
Ts = 0.01 s

H_D = availability_D
H_K = availability_K
H_F = availability_F * exp(-(age_steps*Ts)/tau_F)
```

The five inputs were exactly `FWCAL_C01R1/C02/C03/C04/C05`, each with 1601
samples over the frozen 0–16 s, 100-Hz window. Their A2R8 hashes were retained.

The frozen V2.5 baseline was reconstructed from its runtime-weight manifest:

```text
alpha_D_V25 = 0.9004680917645591
alpha_K_V25 = 0.09953190823544089
alpha_F_V25 = 0
```

## Availability and zero-score audit

Every maneuver produced identical availability behavior:

| Maneuver | D drops | K drops | F drops | all-score-zero count | minimum score sum |
|---|---:|---:|---:|---:|---:|
| FWCAL_C01R1 | 0 | 0 | 0 | 0 | 0.995268890541443 |
| FWCAL_C02 | 0 | 0 | 0 | 0 | 0.995268890541443 |
| FWCAL_C03 | 0 | 0 | 0 | 0 | 0.995268890541443 |
| FWCAL_C04 | 0 | 0 | 0 | 0 | 0.995268890541443 |
| FWCAL_C05 | 0 | 0 | 0 | 0 | 0.995268890541443 |

The unfrozen all-score-zero branch was never entered. No fallback behavior is
inferred or designed from this absence.

## Alpha behavior

Because all five records share the same 0–16 s age sequence and no
availability drop, the alpha trajectories are the same in each maneuver.

| Track | Min | Max | Mean | Std | First | Last |
|---|---:|---:|---:|---:|---:|---:|
| D | 0.842618409326 | 0.846623879570 | 0.844805922056 | 0.001154147580 | 0.842618409326 | 0.846623879570 |
| K | 0.146439697447 | 0.147135813084 | 0.146819867995 | 0.000200580738 | 0.146439697447 | 0.147135813084 |
| F | 0.006240307346 | 0.010941893228 | 0.008374209950 | 0.001354728319 | 0.010941893228 | 0.006240307346 |

F age produces the intended monotonic behavior:

```text
H_F:       1 -> 0.56761509547270994
alpha_F:   0.01094189322758545 -> 0.0062403073461377309
end/start alpha_F ratio = 0.570313310168791
corr(age_steps,alpha_F) = -0.99742896299524775
```

The lost F score is redistributed by normalization, increasing D by
`0.00400547024447517` and K by `0.000696115636972666` over 16 s. Thus the
formula does not degenerate to a constant weight, but its time variation is
small in absolute cross-track-weight terms.

## Output comparisons

The static-prior reference was reconstructed exactly as:

```text
Vy_Q = q_D*Vy_D + q_K*Vy_K + q_F*Vy_F
```

| Maneuver | RMS(Vy_LS−Vy_Q) | maxAbs(Vy_LS−Vy_Q) | RMS(Vy_LS−Vy_V25) | maxAbs(Vy_LS−Vy_V25) |
|---|---:|---:|---:|---:|
| C01R1 | 0.00269401 | 0.00583771 | 0.01724038 | 0.02218832 |
| C02 | 0.00270020 | 0.00594410 | 0.01746911 | 0.02435829 |
| C03 | 0.00275277 | 0.00566936 | 0.01378263 | 0.01970749 |
| C04 | 0.00275500 | 0.00655682 | 0.01266105 | 0.02268959 |
| C05 | 0.00277605 | 0.00579363 | 0.01273343 | 0.02235415 |

Pooled values are:

```text
RMS(Vy_LS - Vy_Q)     = 0.0027358001674273285 m/s
maxAbs(Vy_LS - Vy_Q)  = 0.0065568190056678466 m/s

RMS(Vy_LS - Vy_V25)   = 0.014931870906783912 m/s
maxAbs(Vy_LS - Vy_V25)= 0.024358289244444331 m/s
```

`Vy_LS−Vy_Q` isolates the online age-gate effect. The larger difference from
V2.5 also contains the already frozen change from V2.5 weights to the A3R1
static quality priors; it must not be attributed solely to adaptivity.

## Descriptive-only truth metrics

| Maneuver | RMSE Vy_LS | RMSE Vy_Q | RMSE Vy_V25 |
|---|---:|---:|---:|
| C01R1 | 0.05646835 | 0.05849698 | 0.04269471 |
| C02 | 0.06199553 | 0.06377083 | 0.05101918 |
| C03 | 0.06875427 | 0.06982261 | 0.06523424 |
| C04 | 0.11211090 | 0.11263197 | 0.11467667 |
| C05 | 0.10794664 | 0.10836730 | 0.11077408 |

MAE, MaxAbs, and Bias are retained in the evidence CSV. These values are
`DESCRIPTIVE_ONLY`; mixed maneuver outcomes do not authorize changing q,
`tau_F`, gates, Q/R, or any model.

## Classification rationale

The behavior is not static: F health and alpha vary monotonically, and
`Vy_LS` differs measurably from `Vy_Q`. It is not classified as meaningfully
adaptive because all D/K/F availability flags remain one, no discrete health
event occurs, and the sole continuous change reduces an already small F
weight from 1.09% to 0.62%. The appropriate evidence-based classification is
therefore `CONFIRMED_WEAKLY_ADAPTIVE`.

## Evidence

- `results/vy_reliability_lifesig_v2_7a3r5_behavior_audit.mat`
- `results/vy_reliability_lifesig_v2_7a3r5_alpha_stats.csv`
- `results/vy_reliability_lifesig_v2_7a3r5_output_comparison.csv`
- `results/vy_reliability_lifesig_v2_7a3r5_descriptive_performance.csv`
- `results/vy_reliability_lifesig_v2_7a3r5_behavior_classification.csv`

READY FOR V2.7-A3R6 NUMERICAL FALLBACK AND IMPLEMENTATION CONTRACT FREEZE
