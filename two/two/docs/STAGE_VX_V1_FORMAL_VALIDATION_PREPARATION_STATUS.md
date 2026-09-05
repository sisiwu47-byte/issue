# STAGE VX-V1 — Formal Validation Baseline Preparation

## Verdict

- `VERDICT = MANUAL_GUI_ACTION_REQUIRED`
- `VX_FORMAL_VALIDATION_PREPARATION_PASS = NO`
- `CURRENT_IMPLEMENTATION = CLEAR`
- `FORMAL_RUNTIME_COUNT = 0`
- `READY_FOR_VX_FORMAL_RUNTIME = NO`

The static preparation package is complete, but the current model has an inactive estimator/`vx_hat` route and T1 rear steering is not confirmed. A PASS is prohibited until the manual GUI gate is closed.

## Current formal implementation

- Estimator: `model/longitudinal_velocity_estimator.m`, SHA-256 `68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107`.
- Parameters: `model/estimator_default_params.m`, SHA-256 `09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4`.
- Wrapper: `model/longitudinal_velocity_estimator_simulink.m`, 18 inputs / 38 outputs.
- Current effective key values: `Ts_sim=0.001 s`, `Ts_est=0.01 s`, `QI=2e-3`, `QW=1e-4`, `kA=30`, `kH=18`, `R_Ax=1.248708981650e-3`, `Twindow=0.5 s`, `rho_hard=0.05`, `Nrecover=30`.
- No parameter was changed and no algorithm tuning was performed in this stage.

## Evidence classification

- `CURRENT_IMPLEMENTATION`: frozen in `parameter_snapshot.md` and `interface_snapshot.md`.
- `HISTORICAL_VALIDATION`: A-H MAT files; hashes preserved in `evidence_separation.md`, but current code/parameter/model lineage is absent and historical `kA/kH` differ.
- `FORMAL_CURRENT_VERSION_VALIDATION`: none; count remains zero.
- The legacy `tests/test_longitudinal_velocity_estimator.m` uses old source paths/output semantics and is excluded from the formal gate. `tests/test_vx_v1_current_contract.m` is the non-runtime replacement contract test; it has been created but not executed in this no-MATLAB stage.

## Prepared formal entrypoints

- Frozen cases/windows/questions: `results/vx_formal_validation/validation_case_manifest.md`.
- Runtime provenance packager: `matlab/package_vx_formal_runtime_result.m`.
- Frozen case definition: `matlab/vx_formal_validation_case_definition.m`.
- Batch metric/table analyzer: `matlab/analyze_vx_formal_validation_batch.m`.
- The analyzer accepts only N1/N2/T1/D1/D2 formal MAT files with matching manifest and hashes; A-H inputs are rejected by construction.

## Thesis figures

- Manifest: `results/vx_formal_validation/thesis_figure_manifest.md`.
- Paired source code exists for `VX-FIG-01` and `VX-FIG-02`; no image has been generated.
- Both scripts inherit the frozen Vy palette, strokes, grids, axes, font, legends, compact spacing, the 175-mm canvas classes, and 600-dpi/vector export rules from `results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js` (SHA-256 `CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB`).
- Each plotting script contains its figure ID, title, question, case, source file, signal contract and current `GENERATED_FROM_FORMAL_RUNTIME: NO` state.

## Blockers

1. In `model/vx.slx`, estimator block SID 313 and `vx_hat` Goto SID 274 are statically `Commented=on`.
2. No static evidence proves `vx_hat` is connected to controller `u(33)` or the active downstream Vy/side-slip estimator.
3. The available steering candidate does not establish genuine rear steering; T1 remains `BLOCKED_REAR_STEER_CONFIRMATION`.
4. Saving a GUI-reviewed `.slx` will change its hash; the snapshot/packager must then be deliberately updated before formal runtime.

## Required next action

Follow `docs/simulink_manual_connection.md`. After the user reports `VX_GUI_CONFIRMATION_COMPLETE`, perform a new read-only hash/interface snapshot before any formal runtime. No N1/N2/T1/D1/D2 run is authorized by this status alone.
