# V2.8-A27 Final D-EKF Model-Mismatch Fusion Validation Status

## Verdict

`FINAL_D_MODEL_MISMATCH_FUSION_PASS`

- Runtime count: `1`; CarSim-Simulink termination `40.5 s`; raw logs and frozen hash integrity passed.
- Controlled severe D-only mismatch: front lateral-force gain `k_f=0.78181/0.0390905/0.78181`; plant `mu=0.8`; continuous `0.02 rad / 0.4 Hz` sine.
- Exact D replay: raw maxDiff `0`; analysis alignment maxDiff `5.55e-16`; update-valid `100%`.

## Formal results

- D RMSE A/B/C: `0.037441/0.383518/0.038936 m/s`.
- K RMSE A/B/C: `0.173362/0.294638/0.310038 m/s`.
- B D/K ratio: `1.301656`; D-dominant degradation passed.
- normalized-NIS mean A/B/C: `0.0390205/2.893114/0.0508800`.
- B `G_D mean/min=0.0537073/0.0203974`; D-health response `0.04 s`.
- B `G_K mean/min=0.924014/0.877985`; D-aware K guard passed.
- alpha-D baseline/min: `0.843834/0.099703`; response time `0.25 s`.
- alpha-K baseline/B mean: `0.146651/0.764528`; weight redistribution passed.
- Original/Proposed B RMSE: `0.373254/0.276284 m/s`; reduction `25.9795%`.
- Original/Proposed B MAE: `0.322325/0.266153 m/s`; reduction `17.4271%`.
- C recovery: PASS; `G_D` and alpha-D recovery times both `0.50 s`.
- Numerical integrity: PASS; no NaN/Inf, fallback `0`, alpha-sum max error `2.22e-16`.

## Figures and boundary

- Three final thesis figures generated as PNG 600 dpi and vector PDF/SVG; source reproducibility passed.
- Plot source: `results/vy_lifesig_v2_8a27_final_d_model_mismatch_validation/generate_a27_thesis_figures.py`.
- This is a controlled severe model-mismatch stress case, not typical real-world uncertainty or a global robustness claim.
- `READY_FOR_FINAL_K_UNIFIED_REGRESSION = YES`.

