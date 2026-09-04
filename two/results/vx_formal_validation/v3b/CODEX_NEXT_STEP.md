# VX V3B Codex Entry — FORMAL PASS / FINAL ACCEPTANCE ONLY

V3B formal execution is complete.

Current frozen result:

- `VX_V3B_COMBINED_SLIP_FORMAL_PASS`
- `PHYSICAL_CALIBRATION_SIM_COUNT = 1`
- selected excitation = `TIER1_REFERENCE_ONLY / T1_2P5`
- total `FORMAL_RUNTIME_COUNT = 6`
- fresh VX-CS drive physical gate = PASS
- fresh VX-CS brake physical gate = PASS
- no blocker

Do NOT execute the former V3B calibration/formal-runtime plan again.

Do NOT rerun `VX-ND`, `VX-ST`, `VX-DR`, or `VX-CS`.
Do NOT run V3A.
Do NOT retune estimator/parameters, change the frozen physical excitation, or modify source model/CarSim datasets.

The only current execution entry is:

`results/vx_formal_validation/v3b/final_acceptance/CODEX_NEXT_STEP.md`

That stage is evidence/claim/figure final acceptance only and must not call `sim`.
