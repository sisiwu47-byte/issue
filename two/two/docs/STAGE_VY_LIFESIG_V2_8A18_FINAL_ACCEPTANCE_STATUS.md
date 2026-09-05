# V2.8-A18 K-health final acceptance and thesis evidence freeze

## Final verdict

`K_HEALTH_FINAL_ACCEPTANCE_FREEZE_PASS`

- `A17d_FORMAL_RUNTIME_EVIDENCE_UNIQUE = YES`
- `RUNTIME_COUNT = 1`
- `PARAMETER_RETUNING = NO`
- `ALGORITHM_MODIFICATION = NO`
- `MODEL_MODIFICATION = NO`
- `WINDOW_RESELECTION = NO`
- `A18_RUNTIME_OR_GUI_INVOKED = NO`
- `K_HEALTH_RETUNING_CLOSED = YES`
- `READY_FOR_CROSS_CONDITION_GENERALIZATION_VALIDATION = YES`

## Accepted evidence chain

1. `MECHANISM_DESIGN_EVIDENCE`: A15 frozen leakage-integral contract and A16 implementation regression. It explains cumulative disagreement, degradation memory, and leakage recovery; it is not used as a substitute for runtime proof.
2. `OFFLINE_VALIDATION`: A15/A16 replay and normal-FWCAL evidence support the frozen `rho=0.995`, `lambda=10 1/m`, `d0=0.3467656927489074 m/s`, `Ts=0.01 s` and bounded normal-condition influence. No global-optimum claim is made.
3. `FORMAL_RUNTIME_VALIDATION`: A17d is the only formal degradation/recovery runtime baseline: 40.5 s, 4051 samples, one runtime. A17c supplies only fixed scenario lineage.

## Frozen thesis results

- Commanded phases remain A `[0,5.0) s`, B `[5.0,22.5) s`, C `[22.5,40.5] s`.
- B RMSE: Original `0.168533016977009 m/s`, Proposed `0.026617764392804 m/s`, improvement `84.2062019239618%`.
- B MAE: Original `0.154841775586824 m/s`, Proposed `0.0217783044761216 m/s`, improvement `85.93512351974428%`.
- Physical low-yaw coverage: `99.3714285714286%`; longest continuous window `5.11--22.49 s`, duration `17.38 s`.
- `alpha_K <= 0.05/0.02` response: `3.40/4.18 s` after B start.
- Recovery, C start-to-end frozen one-second summaries: `I_K 2.4396622840850064 -> 0.0010620945571823345 m`; `G_K 3.6592043007515637e-11 -> 0.98943644418981258`; `alpha_K 6.3232678281385599e-12 -> 0.14633156613259596`.
- Sustained 1 s recovery after C start: `G_K 0.90/0.95 = 12.91/14.34 s`; `alpha_K` 90%/95% baseline = `12.49/13.80 s`.
- `G_K >= 0.99` sustained 1 s: `NOT_REACHED_WITHIN_RUNTIME`.

## Thesis artifacts

- `results/vy_lifesig_v2_8a18_final_acceptance/thesis_phase_metrics.csv`
- `results/vy_lifesig_v2_8a18_final_acceptance/thesis_health_dynamics.csv`
- `results/vy_lifesig_v2_8a18_final_acceptance/thesis_figure_manifest.md`
- `results/vy_lifesig_v2_8a18_final_acceptance/claim_boundary.md`
- `results/vy_lifesig_v2_8a18_final_acceptance/evidence_lineage.md`

`THESIS_CORE_FIGURE_COUNT = 3`. All are `NEEDS_THESIS_REFORMAT`; A18 does not redraw figures. The `I_K` dimensional audit gives unit `m`, consistent with `Ts*e_K` and `lambda` in `1/m`.

## Static acceptance checks

- Five required result files exist and are non-empty.
- `thesis_phase_metrics.csv`: 12 rows; exact numerical transcription from A17d `phase_metrics.csv` passed.
- `thesis_health_dynamics.csv`: 21 requested dynamics rows; no hash, compile, port, dimension, replay, or fallback diagnostics.
- Evidence lineage records source stage/file/field, evidence class, runtime count, and `recomputed_in_A18 = NO` for every frozen entry.
- Claim boundary includes every required supported and unsupported claim and preserves `d_DK` as multi-track consistency evidence rather than absolute K error.
- Final thesis figure count is 3, with no redundant core figure and no more than four subplots per figure.
- No MATLAB, Simulink, CarSim, `sim()`, GUI control, parameter search, runtime replay, or scientific metric recomputation was performed in A18.
