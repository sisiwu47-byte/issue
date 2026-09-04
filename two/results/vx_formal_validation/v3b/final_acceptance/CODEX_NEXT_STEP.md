# VX V3B Final Acceptance Entry — NO NEW SIMULATION

本文件是 Vx 下一阶段唯一执行入口。V3B 已完成 formal PASS；本阶段只做证据归档、论文口径冻结和最终图表验收。

## 绝对禁止

- 不调用 `sim`；
- 不运行 MATLAB/Simulink/CarSim GUI；
- 不重跑 VX-ND/VX-ST/VX-DR/VX-CS；
- 不重新 calibration；
- 不修改 estimator、冻结参数、物理门、冻结 excitation、source `.slx` 或 CarSim source dataset；
- 不为了更好看的 RMSE/图形重新选择数据；
- 不重算新的主性能指标，除 final-acceptance consistency/claim audit 外。

## 当前冻结事实

读取：

1. `AGENTS.md`
2. `docs/STAGE_VX_V3B_COMBINED_SLIP_STATUS.md`
3. `results/vx_formal_validation/v3b/VX_FORMAL_CASE_AMENDMENT_V3B.md`
4. `results/vx_formal_validation/v3b/runtime_contract_v3b.md`
5. `matlab/analyze_vx_formal_validation_v3b.m`
6. `results/vx_formal_validation/v3b/thesis_figures/plot_vx_v3b_fig01.m`
7. `results/vx_formal_validation/v3b/thesis_figures/plot_vx_v3b_fig02.m`

然后只读取本机现有 runtime/freeze/table/figure evidence，不扫描整个仓库。

冻结事实：

- V3B verdict = `VX_V3B_COMBINED_SLIP_FORMAL_PASS`
- physical calibration sim count = 1
- selected = `TIER1_REFERENCE_ONLY / T1_2P5`
- total formal committed count = 6
- VX-CS drive physical gate = PASS, RL/RR 1.906/1.906 s
- VX-CS brake physical gate = PASS, RL/RR 2.731/2.731 s
- no Tier2 rear-torque override
- source estimator/model/frozen parameters unchanged
- READY_FOR_VX_FINAL_ACCEPTANCE was provisionally YES before final claim audit

## Step 1 — local evidence completeness only

Verify these existing files. Missing file means archive/evidence packaging blocker; it does NOT authorize rerun:

### Freeze/calibration
- `results/vx_formal_validation/v3b/frozen_physical_excitation.json`
- `results/vx_formal_validation/v3b/calibration/physical_calibration_count.json`
- `results/vx_formal_validation/v3b/calibration/T1_2P5/physical_gate.json`
- `results/vx_formal_validation/v3b/calibration/T1_2P5/physical_only.mat`

### Formal VX-CS
- `results/vx_formal_validation/v3b/runtime/VX_CS_formal_raw.mat`
- `results/vx_formal_validation/v3b/runtime/VX_CS_metadata.json`
- `results/vx_formal_validation/v3b/runtime/VX_CS_runtime_commit.txt`
- `results/vx_formal_validation/v3b/runtime/VX_CS_analysis.mat`
- `results/vx_formal_validation/v3b/runtime/VX_CS_analysis.json`
- `results/vx_formal_validation/v3b/runtime/VX_TABLE_01_FINAL_representative_condition_performance.csv`
- `results/vx_formal_validation/v3b/runtime/VX_TABLE_02_FINAL_combined_slip_recovery.csv`

### Figures
- `results/vx_formal_validation/v3b/thesis_figures/VX_FIG01_normal_dynamic_estimation.png`
- `results/vx_formal_validation/v3b/thesis_figures/VX_FIG01_normal_dynamic_estimation.pdf`
- `results/vx_formal_validation/v3b/thesis_figures/VX_FIG02_combined_slip_recovery_fusion.png`
- `results/vx_formal_validation/v3b/thesis_figures/VX_FIG02_combined_slip_recovery_fusion.pdf`

Do not require GitHub to contain ignored/binary runtime assets in order to call the scientific result valid. Record local path + SHA-256 in evidence lineage.

## Step 2 — final claim audit: baseline readiness

This is a claim-interpretation audit, not a new performance metric and not a reason to retune.

From existing `VX_CS_formal_raw.mat`, record the last estimator update immediately BEFORE t=3.0 s and immediately BEFORE t=9.0 s:

- rho_RL = estY(:,18)
- rho_RR = estY(:,19)
- validWheel_RL = estY(:,26)
- validWheel_RR = estY(:,27)
- alpha_W = estY(:,30)
- physical kappa_RL/RR from estU(:,3:4) and vxTrue

Save:

`results/vx_formal_validation/v3b/final_acceptance/VX_CS_phase_entry_state.csv`

Use existing hard-degradation criterion only (`rho<=0.05` or validWheel=0); do not invent a new health threshold.

Interpretation rule:

- If rear wheels are already hard-degraded immediately before t=3, then DRIVE `detectionResponse=0.008 s` is `PREEXISTING_DEGRADATION_AT_PHASE_START`, not a causal drive-slip detection response.
- If the `[0.6,3)` alpha_W baseline is itself a degraded baseline, the reported alpha_W recovery90/95 values must remain in engineering evidence but are `NOT_THESIS_USABLE_AS_HEALTHY_BASELINE_RECOVERY`.
- For BRAKE, evaluate whether rear wheels were recovered immediately before t=9. If yes, brake detection 0.178 s may be described as an actual health-transition response.

Do NOT alter `analyze_vx_formal_validation_v3b.m` or overwrite its formal metrics. This audit only sets thesis claim boundaries.

## Step 3 — FIG-01 interpretation audit

The plotted CarSim Vx starts near 20 m/s (~72 km/h) and settles toward the 60 km/h command before the 60->100->60 main profile.

Therefore final thesis caption/text must NOT say the vehicle is at 60 km/h from t=0.

Recommended wording role:

`初始状态收敛后，车辆完成约60→100→60 km/h的正常纵向动态过程。`

Do not crop/change evidence merely to hide the initial transient. Reformatting labels to Chinese is allowed later without changing source data.

## Step 4 — FIG-02 interpretation audit

FIG-02 may support:

- the same low-mu formal runtime physically contains both rear drive slip and rear brake slip;
- WSS contribution is strongly suppressed during degraded intervals;
- brake phase shows a clear recovered -> degraded -> recovered health transition if pre-9 s state is healthy;
- fused Vx remains finite/bounded through the combined-slip run.

FIG-02 must NOT automatically support:

- `drive slip was newly detected in 0.008 s` if health was already degraded before t=3;
- `alpha_W recovered to healthy baseline in 0.008 s` if the formal baseline `[0.6,3)` is degraded;
- genuine 4WIS rear-steering validation;
- arbitrary-mu/general operating-domain robustness.

## Step 5 — final thesis tables

Do not rewrite the formal CSVs. Create thesis-facing copies under final_acceptance.

### `VX_THESIS_TABLE_01.csv`
Source: formal TABLE-01. Rows only:
- VX-ND
- VX-ST
- VX-CS

Columns:
- CaseId
- WSS_RMSE
- IMU_RMSE
- Fusion_RMSE
- Fusion_MAE
- Fusion_MaxAbs

### `VX_THESIS_TABLE_02.csv`
Source: formal TABLE-02. Prefer the compact scientifically interpretable columns:
- Phase
- WSS_RMSE
- IMU_RMSE
- Fusion_RMSE
- MeanAlphaW
- SustainedRL_s
- SustainedRR_s
- PhysicalGatePass
- DetectionResponse_s or claim-safe status
- WheelRecovery_s

Keep alpha_W recovery90/95 in evidence lineage; include in thesis table only if final claim audit confirms the baseline is a healthy baseline. Do not silently replace formal values with newly defined values.

## Step 6 — claim boundary

Generate:

`results/vx_formal_validation/v3b/final_acceptance/claim_boundary.md`

SUPPORTED should include only evidence-backed claims:

- current frozen Vx estimator completed current-version formal validation under normal longitudinal dynamics, steering dynamics, and one low-mu combined drive/brake-slip condition;
- VX-CS physically realized both rear drive slip and rear brake slip under the frozen T1_2P5 reference-only excitation;
- during degraded intervals mean WSS fusion contribution is strongly reduced (formal mean alpha_W retained from evidence);
- rear-wheel validity recovered after both degraded phases;
- brake-phase detection response may be claimed only if pre-brake phase-entry state is recovered.

NOT SUPPORTED must include:

- genuine rear-wheel steering / 4WIS steering validation (V3 ST rear-steering gate failed);
- universal robustness over arbitrary speed/mu/noise/faults;
- independently measured effective tire-road coefficient equal to 0.30; only the saved control token/configuration is established;
- closed-loop controller validation with vx_hat replacing CarSim truth unless separate evidence exists;
- causal drive-slip detection time if pre-drive state was already degraded;
- healthy-baseline alpha recovery time if `[0.6,3)` is degraded.

## Step 7 — evidence lineage

Generate:

`results/vx_formal_validation/v3b/final_acceptance/evidence_lineage.md`

For every thesis number record:

- metric/claim name
- value/status
- case/phase/window
- source file
- source struct/column/CSV row
- formal vs calibration vs claim-audit evidence class
- formal runtime count contribution
- whether recomputed in final acceptance

Final acceptance must not create new estimator performance values.

## Step 8 — thesis figure manifest

Generate:

`results/vx_formal_validation/v3b/final_acceptance/thesis_figure_manifest.md`

Only two Vx core figures are required:

1. `VX-FIG-01` — normal longitudinal dynamics, 2 panels.
2. `VX-FIG-02` — combined slip/recovery, 3 panels.

For each record source raw, plot code, PNG/PDF, scientific question, exact claim ceiling, and status:

- `DIRECTLY_USABLE`
- or `NEEDS_LABEL_REFORMAT`
- or `CLAIM_LIMIT_REQUIRED`

Do not generate extra Vx figures merely because more signals exist.

## Step 9 — final status

Generate:

`docs/STAGE_VX_FINAL_ACCEPTANCE_STATUS.md`

Required fields:

- `V3B_FORMAL_VERDICT = VX_V3B_COMBINED_SLIP_FORMAL_PASS`
- `FORMAL_RUNTIME_COUNT = 6`
- `PHYSICAL_CALIBRATION_SIM_COUNT = 1`
- `PARAMETER_RETUNING = NO`
- `ALGORITHM_MODIFICATION = NO`
- `SOURCE_MODEL_MODIFICATION = NO`
- drive/brake physical gates
- claim-audit result for drive phase-entry health
- claim-audit result for brake phase-entry health
- TABLE-01/TABLE-02 final paths
- FIG-01/FIG-02 final paths
- claim boundary path
- evidence lineage path
- `READY_FOR_VX_THESIS_WRITING = YES/NO`

Scientific final acceptance may be YES with a limited claim even if drive detection time is not thesis-usable; do not demand a rerun unless the thesis specifically requires demonstrating a healthy->degraded onset for the drive phase.

## Optional stronger-evidence branch — DO NOT EXECUTE AUTOMATICALLY

Only if the user later explicitly requires a clean healthy->drive-slip->healthy->brake-slip->healthy mechanism trace, propose a new preregistered V3C. V3C would need a physically healthy pre-drive baseline (preferably by resolving the initial CarSim speed mismatch or extending preconditioning) before any new formal runtime. This is NOT part of the current final-acceptance task.

## Final reply <=20 lines

Report only:

1. verdict
2. runtime/calibration counts unchanged
3. local evidence completeness
4. drive phase-entry state result
5. brake phase-entry state result
6. thesis-usable vs evidence-only metrics
7. final table paths
8. figure manifest/claim boundary/evidence lineage paths
9. READY_FOR_VX_THESIS_WRITING
10. whether V3C is required (`NO` unless user explicitly requires clean drive onset evidence)
