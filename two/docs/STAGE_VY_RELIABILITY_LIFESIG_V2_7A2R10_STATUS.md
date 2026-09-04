# V2.7-A2R10 CROSS-TRACK DISAGREEMENT RELIABILITY ADEQUACY AUDIT

## Scope

Offline-only audit of the five A2R8 non-holdout reliability calibration MAT
files. Pairwise disagreement was constructed as
`d_DK=abs(Vy_D-Vy_K)`, `d_DF=abs(Vy_D-Vy_F)`, and
`d_KF=abs(Vy_K-Vy_F)`. `Vy_true` was used only to score offline squared-error
risk. No model, runtime, LifeSig parameter, threshold, classifier, holdout, or
fusion weight was changed.

All five maneuvers had 1601 aligned samples. Online validity masks were applied
for D/K/F; candidate attribution signals remained causal (valid flags, NIS,
`abs(r)`, and F age). No maneuver ID or future sample was used online.

## Pearson relationship to squared error

Values are Pearson correlations of disagreement with the indicated track's
squared Vy error; the machine-readable CSV/MAT also contains Spearman and
equal-frequency bin diagnostics.

| Maneuver | d_DK→eD² | d_DK→eK² | d_DK→eF² | d_DF→eD² | d_DF→eK² | d_DF→eF² | d_KF→eD² | d_KF→eK² | d_KF→eF² |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C01R1 | 0.066 | 0.872 | 0.606 | 0.008 | 0.692 | 0.965 | 0.002 | 0.599 | 0.988 |
| C02 | -0.058 | 0.792 | 0.584 | -0.048 | 0.749 | 0.963 | -0.040 | 0.681 | 0.992 |
| C03 | -0.270 | 0.253 | 0.303 | -0.024 | 0.369 | 0.956 | 0.025 | 0.351 | 0.986 |
| C04 | -0.049 | -0.202 | 0.064 | -0.040 | 0.127 | 0.924 | 0.017 | 0.189 | 0.976 |
| C05 | -0.120 | -0.292 | 0.073 | -0.010 | 0.091 | 0.929 | 0.047 | 0.174 | 0.981 |
| Pooled | -0.339 | 0.624 | 0.262 | -0.015 | 0.338 | 0.947 | 0.101 | 0.194 | 0.972 |

## Attribution assessment

Disagreement involving F is dominated by F-error association (pooled
`d_DF→eF²=0.947`, `d_KF→eF²=0.972`). `d_DK` changes from strong K association
in C01R1/C02 to weak or negative K association in C04/C05, so it cannot
reliably identify whether D or K is the failing track. Descriptive sign/rank
alignment of error differences also changes by maneuver and is not a stable
attribution rule.

Existing online evidence does not repair this: D/K validity and NIS health are
causal but their A2R9 error-risk relationships were weak; K `abs(r)` was
non-positive/unstable; F age is highly predictive of F error but does not by
itself disambiguate D-vs-K disagreement. No threshold or LifeSig mapping was
fit.

## Per-signal verdicts

```text
D_DISAGREEMENT_ADEQUACY       = DESCRIPTIVE_ONLY_NOT_STABLE_ATTRIBUTOR
K_DISAGREEMENT_ADEQUACY       = DESCRIPTIVE_ONLY_NOT_STABLE_ATTRIBUTOR
F_DISAGREEMENT_ADEQUACY       = DESCRIPTIVE_ONLY_NOT_STABLE_ATTRIBUTOR
TRACK_ATTRIBUTION_ADEQUACY    = INSUFFICIENT
```

Overall verdict:

```text
RELIABILITY_INFORMATION_INSUFFICIENT_FOR_TRACK_ATTRIBUTION
```

Pairwise disagreement is useful as an inconsistency diagnostic, but current
evidence is insufficient to causally attribute the disagreement to a specific
track with stable cross-maneuver reliability. No A3 revised LifeSig formulation
is authorized on this evidence alone.

Evidence:

- `results/vy_reliability_lifesig_v2_7a2r10_disagreement_audit.mat`
- `results/vy_reliability_lifesig_v2_7a2r10_disagreement_audit.csv`
