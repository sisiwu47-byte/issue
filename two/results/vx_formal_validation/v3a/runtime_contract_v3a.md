# VX V3A Formal Runtime Contract — VX-DS Only

## Inheritance

V3A inherits the frozen source-model/estimator/parameter/wrapper identities and algorithm parameters from V3. It adds no estimator tuning and does not alter prior V3 results.

Frozen implementation parameters include `QI=0.002`, `kA=30`, `kH=18`, `QW=0.0001`, `Rw=0.393 m`, estimator update `0.01 s`, simulation step `0.001 s`.

## Authorized runtime

Only one new case is authorized: `VX-DS`.

Do not run `VX-ND`, `VX-ST`, `VX-DR`, or `VX-BL` in this stage.

## VX-DS configuration

- speed time, s: `[0,3,8,16]`
- speed reference, km/h: `[40,40,70,70]`
- steering: zero
- source control directory: `results/vy_lifesig_v2_8a20b_mu03_diagnostic/carsim_control_MU03`
- required `Run_all.par` source SHA-256: `8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8`
- required `simfile.sim` source SHA-256: `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`
- required copied token: `MU_ROAD_CONSTANT=0.30`
- stop time: `16 s`
- speed values remain `km/h`; do not divide them by `3.6` in the configurator because the saved model has the downstream conversion.

All changes must be applied only to a generated validation copy and copied control directory.

## Required signals and result schema

Reuse the proven V3 runner signal contract:

- `Vx_true_log`
- `est_u_log`, aligned N-by-18
- `est_y_log`, aligned N-by-38
- zero steering command log

Save scalar `R` with at least:

- `R.metadata.formalRuntime=true`
- `R.metadata.caseId='VX-DS'`
- `R.metadata.amendment='V3A'`
- `R.time`
- `R.vxTrue`
- `R.estU`
- `R.estY`
- `R.Ax=R.estU(:,9)`
- `R.steerCommand`
- `R.configuration`
- pre/post source and generated hashes.

Output root: `results/vx_formal_validation/v3a/runtime/`.

## Frozen analysis windows

- overall `[0.60,16.00]`
- baseline `[0.60,3.00)`
- degradation `[3.00,8.00)`
- recovery `[8.00,16.00]`

Score estimator metrics only at genuine estimator updates (`est_y(:,35)>0.5`) with finite truth.

## Metrics

Overall and degradation phase: WSS/IMU/Fusion RMSE, MAE, MaxAbs, Bias.

Mechanism/recovery evidence:

- mean `alpha_W`, mean `alpha_I` during `[3,8)`;
- RL/RR physical-gate sustained duration;
- detection response: first estimator update after `3 s` where both RL/RR are invalid OR both `rho<=0.05`; otherwise `NOT_DETECTED`;
- wheel recovery: after `8 s`, first 30 consecutive 100-Hz updates with both RL/RR valid; otherwise `NOT_REACHED`;
- `alpha_W` recovery 90%/95%: first 30 consecutive updates after `8 s` at or above 90%/95% of baseline mean `alpha_W` from `[0.60,3.00)`; otherwise `NOT_REACHED`.

No missing event may be replaced by a window endpoint.

## Physical gate

Using raw physical signals:

`kappa_i=(0.393*omega_i-Vx_true)/max(abs(Vx_true),1)`.

`VX-DS PHYSICAL_GATE_PASS` requires RL and RR each to sustain `kappa>=+0.10` for at least `0.10 s` inside `[3,8)`.

The gate is independent of estimator RMSE, `rho`, or fusion weights.

## Final thesis outputs

After a passing VX-DS runtime create:

1. `results/vx_formal_validation/v3a/runtime/VX_DS_formal_raw.mat`
2. `.../VX_DS_metadata.json`
3. `.../VX_DS_analysis.mat` and `.json`
4. `.../VX_TABLE_01_FINAL_representative_condition_performance.csv`, rows exactly `VX-ND`, `VX-ST`, `VX-DS`; ND/ST metrics are read from accepted V3 analysis files, not rerun.
5. `.../VX_TABLE_02_FINAL_drive_slip_recovery.csv`, VX-DS only.
6. `results/vx_formal_validation/v3a/thesis_figures/plot_vx_v3a_fig02.m`
7. `.../VX_FIG02_drive_slip_recovery.{png,pdf,svg}` only if the physical gate passes.
8. Generate existing V3 `VX-FIG-01` from accepted `VX_ND_formal_raw.mat`; do not change its scientific source.
9. `docs/STAGE_VX_V3A_DS_FORMAL_VALIDATION_STATUS.md`.

If VX-DS fails the physical gate, retain its raw evidence, do not export FIG-02 as a successful mechanism figure, and stop without parameter/profile retuning.
