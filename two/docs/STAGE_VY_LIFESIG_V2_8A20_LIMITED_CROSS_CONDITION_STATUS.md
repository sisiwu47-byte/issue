# V2.8-A20 limited cross-condition validation status

## Final verdict

`A20_LIMITED_CROSS_CONDITION_FAIL`

- C0: A17d baseline reused, no rerun, formal runtime count remains `1`.
- C1: different DLC-like steering excitation, μ=0.8, runtime `1`, `CROSS_CONDITION_BEHAVIOR_FAIL` because recovery was not reached within the saved runtime.
- C2: A17d steering with preselected μ=0.35 and authorized low-mu tire block, runtime `1`, `CROSS_CONDITION_BEHAVIOR_PASS`.
- `NEW_RUNTIME_COUNT = 2`; repeat protection prevented an extra C2 invocation before simulation.
- `PARAMETER_RETUNING = NO`; `ALGORITHM_MODIFICATION = NO`.

## Key whole-runtime metrics

| condition | D RMSE | K RMSE | Original RMSE | Proposed RMSE | condition pass |
|---|---:|---:|---:|---:|---|
| C0 | 0.0290187 | 0.781501 | 0.127161 | 0.0434078 | baseline PASS |
| C1 | 0.0232760 | 0.893689 | 0.143239 | 0.0322799 | NO |
| C2 | 0.0843450 | 0.782777 | 0.145728 | 0.0839144 | YES |

Units are `m/s`. Both new conditions pass integrity, health-direction, normal-preservation, catastrophic-degradation, and exact V2.8/V2.7 replay checks. C1 alone fails recovery; C2 recovery trend passes.

## K-health and D-track interpretation

- C1: meaningful degradation YES; `I_K peak=2.38947`, `G_K min=4.19441e-11`, `alpha_K min=7.24706e-12`, response `3.69 s`; `G_K/alpha_K` recovery NOT REACHED; D-track degradation NO.
- C2: meaningful degradation YES; `I_K peak=2.44249`, `G_K min=2.46842e-11`, `alpha_K min=4.26492e-12`, response `3.38 s`; recovery trend YES although 0.90 sustained threshold is not reached; D-track degradation YES.
- For C2, pairwise disagreement attribution is ambiguous; D is not treated as ground truth and `d_DK` is not interpreted as unique K error.

## Figure and evidence freeze

- Two figures generated from persisted `generate_a20_thesis_figures.py`, SHA-256 `DB3CF2EA59ED50C7146B1DEC3331D3F17AE236CF912FE1498429A29372B0FF2D`.
- Each figure exists as 600-dpi PNG and vector PDF/SVG; axes/curve counts are `4: 2/1/1/3` and `3: 3/2/2`.
- A19 style inheritance YES; x-range `0--40.5 s`; A/B/C boundaries `5.0/22.5 s`.
- One isolated reproduction check PASS: both SVG/PNG pairs byte-identical; PDF vector geometry structurally identical.
- Evidence: `results/vy_lifesig_v2_8a20_limited_cross_condition/` (`final_evidence.mat`, combined CSVs, manifests, lineage, claim boundary).

## Closure state

- `K_HEALTH_CROSS_CONDITION_VALIDATION_CLOSED = NO`
- `READY_FOR_D_EKF_VALIDATION = NO`
- `DEFERRED_FUTURE_VALIDATION = cross-speed, sensor fault, parameter perturbation`
