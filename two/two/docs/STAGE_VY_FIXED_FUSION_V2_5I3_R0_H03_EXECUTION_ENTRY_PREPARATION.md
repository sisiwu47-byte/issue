# V2.5-I3-R0 H03 Dedicated Execution-Entry Preparation

## 状态

**READY FOR H03 FINAL PRE-SIM REVALIDATION**

本阶段仅完成 H03 execution-entry 的创建与静态冻结。未启动 MATLAB、Simulink 或 CarSim，未执行 H03 launcher，未创建 phase marker 或 authorization commit，未读取 H03 performance/data，也未修改模型、权重、Q/R 或 registry。

## Frozen H03 run card

- statistical run ID：`FWHOLD_H03`
- execution attempt：`FWHOLD_H03_EXEC_R0`
- registry execution order：`3`
- role：`HOLDOUT_VALIDATION`（注册角色）
- scientific role：`SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`
- steering：`0.030 rad / 0.45 Hz / sine`
- front policy：`FL_FR_SAME_PHASE`
- rear policy：`RL_RR_ZERO`
- duration：`16 s`
- estimator rate：`100 Hz`
- speed scope：`VERIFIED_APPROX_20_MPS_CLASS`
- truth alignment：`TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT`
- evaluation window：`[0_16]`
- fixed weights：`V25_FIXED_WEIGHT_ALPHA_V1`，`alpha_D=0.9004680917645591`，`alpha_K=0.09953190823544089`，`alpha_F=0`
- formal MAT（未来唯一输出）：`results/vy_fixed_fusion_v2_5i_fwhold_h03.mat`
- frozen target：`model/vx_vy_fixed_fusion_v2_5.slx`
- target SHA-256：`AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`

H01 保持永久关闭且无 usable holdout data；H02 保持 `POST_COMMIT_PERSISTENT_STALL_TERMINATED`、authorization `CONSUMED`、formal data `NO_USABLE_HOLDOUT_DATA`。H03 当前仍为 `UNRUN / UNVIEWED / UNCONSUMED`。

## Created and frozen execution chain

| Artifact | Path | SHA-256 | Static role |
|:--|:--|:--|:--|
| runner | `model/run_vy_fixed_fusion_v2_5i3_H03_holdout.m` | `AB65E8D5DCDEE92EA8AC53AEFE1BFDC97CD4FC7BD8390C17E8656DD90EB631C2` | one-shot H03 runner; self-hash explicitly uses `[mfilename('fullpath') '.m']` |
| analyzer | `model/analyze_vy_fixed_fusion_v2_5i3_H03_holdout.m` | `B6DE7B43EAEB154BF59EE906F8A08343217AED1CAEB0B5955BBE357D54182823` | read-only Phase 1 eligibility then H03 per-run diagnostics |
| bootstrap | `model/run_vy_fixed_fusion_v2_5i3_H03_formal_bootstrap.m` | `9F384B9DDAA6BBBD244E4EEAE1A0AEE7C3261688F04FFA94A03303042B9F394B` | ASCII-style single bootstrap; references the same phase path and calls runner once |
| launcher | `model/launch_vy_fixed_fusion_v2_5i3_H03_formal.cmd` | `91CFA89E7B01915A0554361852672701458F82172F2404C3D6295B8F0E5BF7F3` | starts MATLAB once; unique H03 stdout/stderr/exit/status paths; no fallback |

The runner and analyzer both reference the same attempt-scoped paths:

```text
phase   = results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv
commit  = results/vy_fixed_fusion_v2_5i3_H03_sim_authorization_committed.csv
```

Both paths are currently `ABSENT`. H03 formal MAT and launcher output paths are also `ABSENT`; no phase marker or commit was created in R0.

## Authorization and retry audit

- runner `sim()` call sites：exactly one executable call, in the single runtime try block
- runner retry/fallback paths：none
- bootstrap runner invocations：one
- ASCII launcher MATLAB invocations：one
- direct MATLAB fallback：none
- old A1/A2 launcher reference：none
- commit order：pre-sim gates → write/close/durability/read-back of `SIM_AUTHORIZATION_COMMITTED` → append phase → unique `sim()`
- if commit fails：no `sim()` is reached
- after commit：authorization is permanently consumed; no second H03 runtime is permitted

The H03 analyzer is separate from runtime entry and consumes only the exact H03 formal MAT after a successful runtime. It does not compute PARTIAL23, the original three-holdout aggregate, generalization classification, or perform weight fitting/retuning. The report carries the frozen scientific role `SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`.

## Integrity snapshot

- formal target unchanged and hash-verified as above
- core/wrapper and fixed-weight lineage unchanged from H02/P3/R4 evidence
- H03 authorization：`UNCONSUMED`
- H03 phase/commit/runtime artifacts：`ABSENT`
- no MATLAB/Simulink/CarSim action in R0

H03 remains gated on a future final pre-sim revalidation. This preparation does not authorize execution by itself.
