# V2.8-A4 Online-Implementability Offline Audit

## Verdict

`ONLINE_K_LOW_YAW_DETECTION_FEASIBLE`

This verdict is bounded: the existing causal signals can identify the A3 K-track
degradation episode when `AVz_IMU` supplies the structural low-yaw context and
`abs(Vy_K-Vy_D)` supplies the growing track-divergence evidence. It does **not**
freeze a gate, threshold, mapping, or LifeSig modification. Neither signal alone
is accepted here as a complete K-specific health quantity.

No MATLAB, Simulink, or CarSim process was started. No model, estimator, or
LifeSig file was modified.

## Evidence and signal contract

- The offline physical label is the longest continuous interval satisfying the
  frozen strict condition `abs(CarSim AVz) < 0.01 rad/s`: `4.70--22.00 s`
  (`17.30 s`, 1731 aligned 100-Hz samples). `AVz_IMU` was not used to form this
  label.
- The saved A3 `kkf_diag_log1` contract was verified against the frozen wrapper:
  row 1 is `NIS_K`, row 2 is `abs(AVz_IMU)`, and rows 6/7 are
  `update_valid_K`/`nis_valid_K`. Row 2 equals the saved online `abs(AVz_IMU)`
  sample-by-sample (maximum difference `0`).
- `NIS_K` and `abs(Vy_K-Vy_D)` have no frozen binary threshold. Therefore a
  threshold-dependent overlap percentage would invent a new gate. For these
  signals, the audit reports physical-window distributions and threshold-free
  ROC AUC using the predeclared direction (high NIS or high disagreement).
- For `AVz_IMU`, the already studied literature-derived candidate
  `abs(AVz_IMU)<0.01 rad/s` is used only for descriptive overlap. It is not
  frozen as a gate.

## Physical-window overlap and K-error correspondence

| Online signal | Physical-low-yaw overlap evidence | Relation to elevated K error | LifeSig health suitability |
|---|---|---|---|
| `AVz_IMU` | Candidate `abs(AVz_IMU)<0.01`: coverage/recall `95.03%`, precision `88.54%`, IoU `84.62%`; threshold-free low-yaw AUC `0.7502`. The longest uninterrupted candidate interval is only `1.09 s` because the IMU signal contains bias/noise. | Mean `abs(AVz_IMU)` is nearly unchanged while K error grows across the physical window; within-window Pearson/Spearman versus K squared error are `-0.0305/-0.0339`. | Suitable as causal **structural low-yaw context**, but not as a continuous K-error severity signal and not as an unsmoothed/frozen binary gate on this evidence. |
| `NIS_K` | No frozen binary event; high-NIS physical-label AUC `0.3373`. Mean NIS is `0.0002452` inside versus `0.0005978` outside. | NIS decreases while K error increases: within-window Pearson/Spearman `-0.4827/-0.5167`; upper-quartile K-error AUC in the high-NIS direction is `0.2395`. | Not suitable as the A3 low-yaw K-health signal. It remains `DIAGNOSTIC_ONLY`. |
| `update_valid_K` | `1` for all `2201/2201` samples; invalid-event coverage of the physical window is `0%` and AUC is `0.5`. | K reaches `1.7487 m/s` absolute error while update validity stays high. | Not suitable for detecting structural observability degradation; it retains numerical/update-validity meaning only. |
| `abs(Vy_K-Vy_D)` | No frozen binary event; high-disagreement physical-label AUC `0.9994`. Mean disagreement is `0.9957 m/s` inside versus `0.1610 m/s` outside. | Very strong relation to K squared error: overall Pearson/Spearman `0.9688/0.9984`, within-window `0.9813/0.999997`. | Strong causal divergence diagnostic, but not a standalone K-specific health signal because disagreement alone cannot identify whether D or K is responsible. Use is bounded by the earlier cross-track attribution result. |

## Error-growth discriminator

The physical-low-yaw window shows clear K degradation while the online signals
behave differently:

| Physical-window third | Time (s) | mean `abs(e_K)` (m/s) | K RMSE (m/s) | mean `abs(AVz_IMU)` (rad/s) | mean `NIS_K` | mean `update_valid_K` | mean `abs(Vy_K-Vy_D)` (m/s) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Front | 4.70--10.46 | 0.50124 | 0.52188 | 0.005256 | 0.0003187 | 1 | 0.49723 |
| Middle | 10.47--16.23 | 0.99593 | 1.00442 | 0.004855 | 0.0002420 | 1 | 0.99182 |
| Rear | 16.24--22.00 | 1.50240 | 1.50988 | 0.005099 | 0.0001748 | 1 | 1.49810 |

Thus `AVz_IMU` causally marks the structural operating context but does not
encode accumulated severity; `NIS_K` and `update_valid_K` do not detect the
failure mode; cross-track disagreement closely tracks the accumulated error in
this dedicated case. All samples in the descriptive upper quartile of K squared
error occur inside the physical-low-yaw interval, and disagreement separates
that region with AUC `1.0`; this is an offline adequacy statistic, not a proposed
online threshold.

## Interpretation boundary

The A3 episode can be recognized online in principle by combining two distinct
causal facts:

1. low measured yaw context from `AVz_IMU`; and
2. growing D/K divergence from `abs(Vy_K-Vy_D)`.

This supports feasibility of future K low-yaw detection, not readiness of a
formal LifeSig gate. A future formulation must preserve the attribution caveat:
disagreement cannot by itself prove K is wrong, and raw `AVz_IMU<0.01` is
temporally fragmented by sensor bias/noise. This stage intentionally does not
design hysteresis, persistence, thresholds, mappings, or weights.

## Evidence lineage

- A3 runtime MAT:
  `results/vy_lifesig_v2_8a3_long_low_yaw_runtime.mat`
  (`FA1BAB75DB7EF33B634E649704D7950166BEA5184E1496F57AB953C7B32AC771`).
- A3R2 physical-label evidence:
  `results/vy_lifesig_v2_8a3r2_physical_low_yaw_audit.csv`
  (`9673CAD413F65FB175B1DBA28DE5BFD9EE85F9075A5EEA24F8A9C81E9C474D15`).
- K wrapper/core audited read-only:
  `model/vy_kinematic_kf.m`
  (`73A06F593E0D52B3A168445060F6CA68B35D2F710A913DD16213CDC71FF92298`),
  `model/vy_kinematic_kf_step.m`
  (`383A5A63AC11C3F43BAE1CA7B6993A1C181363F970CD1BA347D4FF8521727740`).
- Machine-readable A4 summary:
  `results/vy_lifesig_v2_8a4_online_k_low_yaw_audit.csv`.

