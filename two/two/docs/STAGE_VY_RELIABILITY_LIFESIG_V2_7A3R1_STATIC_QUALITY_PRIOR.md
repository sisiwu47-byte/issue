# V2.7-A3R1 Static Quality Prior Identification

## Stage conclusion

```text
STATIC_QUALITY_PRIOR_IDENTIFIABLE_AND_STABLE
```

The three full-set prior values are accepted and frozen. This stage used only
the five `NON_HOLDOUT_RELIABILITY_CALIBRATION` datasets and performed no
simulation, estimator tuning, LifeSig-parameter fitting, or holdout access.

## Frozen method

For track `i` in `{D,K,F}` and maneuver `j`, the raw error and risk are

```text
e_i = Vy_i - Vy_true
MSE_i,j = mean(e_i^2)
R_i = mean_j(MSE_i,j)
q_i_raw = 1/R_i
q_i = q_i_raw / sum(q_raw)
```

No error was de-meaned, bias-corrected, filtered, or cropped. `Vy_true` is an
offline calibration reference only and is forbidden in online reliability
logic. The objective contains no fused-output metric.

## Input integrity

All five inputs retained their frozen A2R8 SHA-256 and supplied 1601 aligned
samples over `[0,16]` s at a median step of approximately `0.01` s:

| Maneuver | SHA-256 |
|---|---|
| FWCAL_C01R1 | `BA2546C4FB18810197B0ED721B9D83E1C14CB1354B75B64FF6E960A226B70864` |
| FWCAL_C02 | `7942F1612A055B906DD9012E3D5A2F53314FB5E2560370CCD0BF901243AD589B` |
| FWCAL_C03 | `30C12ED01DC1C1E044D4154E7476794306F3231DE414F7E4CFBA3E88D450400A` |
| FWCAL_C04 | `2E003C60081F959FFD36B317A94D1AD9CE9DF8FECE9CB63794B298A37B4F01A5` |
| FWCAL_C05 | `2BA043D6536816A5DCE77831D3A34D0CF952FCD145377512CADAB584047F5C6F` |

## Per-maneuver raw MSE

Units are `(m/s)^2`.

| Maneuver | D | K | F |
|---|---:|---:|---:|
| FWCAL_C01R1 | 0.000879691487512762 | 0.0676271179104089 | 0.559022451828382 |
| FWCAL_C02 | 0.00190943142562175 | 0.0681616057545178 | 0.558559100958084 |
| FWCAL_C03 | 0.00432321339749905 | 0.0329424130165604 | 0.558641249964097 |
| FWCAL_C04 | 0.0150184015000388 | 0.0204446051230952 | 0.559235577050983 |
| FWCAL_C05 | 0.0141506922758809 | 0.0195886946196503 | 0.558518884619274 |

## Full-set risk and frozen priors

```text
R_D = 0.007256286017310652
R_K = 0.04175288728484652
R_F = 0.5587954528841641

q_D_raw = 137.8115467905196
q_K_raw = 23.950439479258062
q_F_raw = 1.7895635958356586

q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
```

The double-precision sum is `1.0000000000000002`; the residual from one is
roundoff only. All priors are strictly positive.

## Leave-one-maneuver-out stability

| Omitted maneuver | q_D | q_K | q_F | max absolute component shift | ranking |
|---|---:|---:|---:|---:|---|
| FWCAL_C01R1 | 0.789470421264906 | 0.198024348057578 | 0.0125052306775167 | 0.053147988060816 | D>K>F |
| FWCAL_C02 | 0.793753015115208 | 0.19404216431986 | 0.012204820564931 | 0.0488653942105135 | D>K>F |
| FWCAL_C03 | 0.836077470907788 | 0.151969272485017 | 0.0119532566071958 | 0.00654093841793413 | D>K>F |
| FWCAL_C04 | 0.890929005083733 | 0.100594020145216 | 0.00847697477105111 | 0.0483105957580109 | D>K>F |
| FWCAL_C05 | 0.887402046430702 | 0.103812792458871 | 0.00878516111042757 | 0.0447836371049801 | D>K>F |

LOO ranges are:

```text
q_D: 0.789470421264906 .. 0.890929005083733
q_K: 0.100594020145216 .. 0.198024348057578
q_F: 0.00847697477105111 .. 0.0125052306775167
```

The quality ranking `D>K>F` is invariant. The maximum absolute component
shift is `0.053147988060816`. The maximum relative shift is
`0.352258653290805`, on the smaller K component when C01R1 is omitted; this
is disclosed rather than hidden. It does not constitute isolated
single-maneuver dominance: omissions C01R1, C02, C04, and C05 produce similar
maximum absolute shifts (`0.0448` to `0.0531`), while none changes ranking or
approaches a rank crossing.

## Freeze decision and boundaries

```text
q_D_FROZEN = 0.8426184093257221
q_K_FROZEN = 0.14643969744669255
q_F_FROZEN = 0.010941893227585452
classification = STATIC_QUALITY_PRIOR_IDENTIFIABLE_AND_STABLE
```

These are static individual-estimator quality priors. They are not fixed
fusion weights by themselves: the A3 architecture later multiplies each by
its online health gate. No health mapping, NIS threshold, `r0`, `tau_F`, or
fallback behavior is identified here.

## Evidence files

- `results/vy_reliability_lifesig_v2_7a3r1_static_prior_identification.mat`
  contains the raw computed matrices and LOO results; its pending field
  records the pre-review calculation state, while this freeze record is the
  authoritative post-review decision.
- `results/vy_reliability_lifesig_v2_7a3r1_static_prior_mse.csv`
- `results/vy_reliability_lifesig_v2_7a3r1_static_prior_loo.csv`
- `results/vy_reliability_lifesig_v2_7a3r1_static_prior_freeze.csv`

READY FOR V2.7-A3R2 ONLINE HEALTH-GATE FORMULATION
