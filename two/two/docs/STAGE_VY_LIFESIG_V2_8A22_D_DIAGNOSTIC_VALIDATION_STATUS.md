# V2.8-A22 — D-EKF targeted diagnostic validation status

## Verdict

`A22_D_DIAGNOSTIC_VALIDATION_PASS`

`OFFLINE_RECONSTRUCTION = PASS`

`READY_FOR_D_HEALTH_CANDIDATE_VALIDATION = YES`

## Paired evidence

- D0: mu=`0.8`, baseline tire mode, runtime count=`1`, exact replay max difference=`0`.
- D1: mu=`0.35`, low-mu tire mode, runtime count=`1`, exact replay max difference=`0`.
- New paired runtime count=`2`; no D0/D1 repeat runtime.
- Frozen time/steering contract: 4051 samples, `0–40.5 s`, A/B/C boundaries `5.0/22.5 s`.
- D0/D1 RMSE=`0.0290186746 / 0.0843558890 m/s`; degradation factor=`2.906952`.

## Diagnostic separation

- Ay innovation RMS D1/D0=`2.107307`; P95 ratio=`2.174741`.
- r innovation RMS D1/D0=`1.843668`; P95 ratio=`1.835053`.
- NIS RMS D1/D0=`4.322620`; P95 ratio=`4.503565`.
- Innovation covariance remains finite; D1/D0 S22 mean ratio is approximately `1.02`.
- P11/P22/trace(P) RMS ratios=`1.479033 / 1.023245 / 1.348232`; covariance is finite and bounded.
- update-valid fraction=`1.0` for D0 and D1; no numerical/update failure observed.

## Mechanism and candidate ranking

- Mechanism classification: `CASE_D1 MODEL_MISMATCH_DOMINANT`.
- Rationale: both innovations and normalized NIS increase under matched excitation, while covariance remains bounded and all updates remain valid; excitation and numerical failure are not dominant explanations.
- Top D-specific candidate: `NIS — PROMISING`.
- `|r innovation| — PROMISING`; `|Ay innovation| — PROMISING`; `P11/trace(P) — WEAK`; `P22 — NOT_SUPPORTED`.
- `d_DK` remains multi-track inconsistency and is not a D-health primary candidate.
- No D-health algorithm, threshold or adaptation law was designed in A22.

## Diagnostic-only figures and reproducibility

- Figure count=`3`; each exported as PNG `600 dpi` plus vector PDF/SVG.
- `NEW_THESIS_CORE_FIGURE_COUNT = 0`.
- Style inherits the frozen A19 geometry, typography, palette, line widths/dashes, grid and phase boundaries.
- Plotting source: `results/vy_lifesig_v2_8a22_d_diagnostic_validation/generate_a22_diagnostic_figures.py`.
- Plotting source SHA-256: `69D67A3FE632EAC4D59E0C759AE2C25AFFE70E72795FA79548B462EFD48E6AB5`.
- Reproduction check=`PASS`; PNG dimensions=`4134×3543`, `4134×3543`, `4134×5551`; PDF pages render correctly and contain zero raster-image XObjects.

## Scope

- A17d/A20/A21 evidence and verdicts remain unchanged.
- Frozen D/K/LifeSig/K-health algorithms, Q/R/P0, vehicle/tire parameters, model and acceptance windows remain unchanged.
- A22 supports the next candidate-validation stage only; it does not establish global robustness or a finalized D-health design.
