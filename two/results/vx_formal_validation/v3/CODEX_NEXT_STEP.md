# VX V3 Codex Execution Entry

Use this file as the single execution entry for the next stage. Do not re-audit the whole repository and do not restate prior status/evidence.

## Read only first

1. `AGENTS.md`
2. `results/vx_formal_validation/v3/case_handoff.json`
3. `results/vx_formal_validation/v3/runtime_contract.md`
4. `results/vx_formal_validation/v3/VX_FORMAL_CASE_MANIFEST_V3.md`

Read other files only when one of these four explicitly points to them or an implementation detail must be verified.

## Current state

- `FORMAL_RUNTIME_COUNT = 0`
- primary cases: `VX-ND`, `VX-ST`, `VX-DR`
- fallback `VX-DS/VX-BL` is forbidden unless one completed `VX-DR` runtime fails a preregistered physical gate
- GUI setup required: `NO`
- source `model/vx.slx`, estimator core and frozen parameters must not be modified
- controller reference values are in `km/h`; do not divide the V3 profile values by `3.6`

## Missing executable assets to create

Create only in allowed paths:

- `matlab/configure_vx_formal_case_v3.m`
- `matlab/run_vx_formal_validation_v3.m`
- `matlab/analyze_vx_formal_validation_v3.m`
- `results/vx_formal_validation/v3/thesis_figures/plot_vx_v3_fig02.m`
- `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`

Do not create or modify scripts under `model/`.

## Configurator contract

`configure_vx_formal_case_v3(caseId)` must prepare a case without saving changes to `model/vx.slx` or altering source CarSim packages.

Prefer `Simulink.SimulationInput`, workspace variables, copied validation controls, or a temporary derived validation model/work directory.

Cases:

- `VX-ND`: speed `[0,3,7,9,13,16] -> [60,60,100,100,60,60] km/h`, zero steering, nominal A20-C1 CarSim control (`MU_ROAD_CONSTANT=0.8`).
- `VX-ST`: 72 km/h constant; use `vx_st_profile_a20_c1.json`; nominal A20-C1 control (`0.8`). Log command plus all four actual wheel angles.
- `VX-DR`: speed `[0,3,7,9,13,16] -> [40,40,70,70,40,40] km/h`, zero steering; A20b MU03 CarSim control (`MU_ROAD_CONSTANT=0.30`).

The configurator must return enough metadata for the runner to save exact profiles, selected control source, working directory, and hashes.

## Runner contract

`run_vx_formal_validation_v3(caseId)` must:

1. validate pre-run hashes against `case_handoff.json`;
2. reject an unauthorized fallback case;
3. configure the requested case;
4. create `SIM_INVOCATION_COMMITTED=YES` provenance before `sim`;
5. execute exactly one formal runtime;
6. save complete required raw signals and metadata to the manifest path;
7. save post-run hashes;
8. call the analyzer;
9. increment formal runtime count only after the actual formal simulation invocation.

Do not use historical A-H or Vy outputs as runtime substitutes.

## Analyzer contract

`analyze_vx_formal_validation_v3.m` must implement only the frozen metrics/windows in `runtime_contract.md`.

For `VX-ST`, determine whether actual RL/RR wheel angles support `4WIS_REAR_STEERING_VALIDATION`; otherwise limit the claim to `STEERING_DYNAMIC_VALIDATION`.

For `VX-DR`, compute the preregistered kappa gates from actual rear wheel speeds and CarSim Vx:

- acceleration `[3,7)`: RL and RR each sustain `kappa >= +0.10` for at least `0.10 s`;
- braking `[9,13)`: RL and RR each sustain `kappa <= -0.10` for at least `0.10 s`.

Only these physical gates may activate fallback. Estimator RMSE or figure quality may not activate fallback.

## Execution order

After scripts pass static/contract checks, execute in this order:

1. `VX-ND`
2. `VX-ST`
3. `VX-DR`

Do not stop between accepted primary cases for user confirmation.

If `VX-DR` passes both physical gates, do not run `VX-DS/VX-BL`.
If `VX-DR` fails either physical gate, record `VX_DR_PHYSICAL_GATE_FAIL` and stop before fallback unless the existing preregistered fallback can be executed without GUI and without modifying frozen model/algorithm assets; if it can, run only the necessary fallback case(s) according to the manifest.

## MATLAB execution

Use the existing local MATLAB/Simulink/CarSim execution path. If MATLAB startup fails, read `docs/MATLAB_EXECUTION_HANDOFF.md` and existing local execution/status evidence only; do not start a broad environment investigation. Never automate GUI.

## Required final artifacts

After accepted runtimes generate/update:

- `results/vx_formal_validation/v3/runtime/VX_ND_formal_raw.mat`
- `results/vx_formal_validation/v3/runtime/VX_ST_formal_raw.mat`
- `results/vx_formal_validation/v3/runtime/VX_DR_formal_raw.mat`
- per-case metadata JSON and concise logs
- `results/vx_formal_validation/v3/runtime/VX_TABLE_01_representative_condition_performance.csv`
- `results/vx_formal_validation/v3/runtime/VX_TABLE_02_degradation_recovery_dynamics.csv`
- `results/vx_formal_validation/v3/thesis_figures/VX_FIG01_normal_dynamic_estimation.{png,pdf,svg}`
- `results/vx_formal_validation/v3/thesis_figures/VX_FIG02_degradation_recovery_fusion.{png,pdf,svg}` only when its physical claim gate allows it
- keep both figure `.m` scripts beside the outputs
- update `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`

## Stop conditions

Stop and report only if:

- pre-run source/hash mismatch;
- required local source/control file is genuinely missing;
- MATLAB/Simulink/CarSim cannot execute through an existing non-GUI path;
- completing the task would require modifying forbidden source/model/CarSim assets.

For a GUI-only blocker output exactly `MANUAL_GUI_ACTION_REQUIRED` plus the minimum manual action; do not automate GUI.

## Final reply limit

Final reply <=20 lines and only report:

1. verdict
2. formal runtime count
3. ND/ST/DR status
4. ST rear-steering gate
5. DR accel/brake physical gates
6. 3-8 key metrics
7. fallback executed YES/NO
8. TABLE-01/TABLE-02 paths
9. FIG-01/FIG-02 image + code paths
10. blocker if any
11. `READY_FOR_VX_FINAL_ACCEPTANCE = YES/NO`
