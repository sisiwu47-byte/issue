# V2.7-A2R1 RELIABILITY SIGNAL CONTRACT REMEDIATION

## 阶段边界

本阶段只冻结最小 reliability signal contract。未启动 MATLAB/Simulink/CarSim，未运行 `sim()`，未修改任何 `.m`、`.slx`、D/K/F 数学、Q/R、P0_F/Q_F、fusion 或 LifeSig 参数。A2 的 `RELIABILITY_FORMULATION_REQUIRES_REVISION` 保持为历史结论。

## 1. D-track contract

现有 D wrapper 已输出 `NIS_D`、`measurementDimension_D`、`useAy`、`stepIndex`，且 NIS 在当前 prediction/update hit 内形成。但核心存在异常/无效路径把 NIS 保持为零的语义，wrapper 没有传播该路径的状态。因此冻结：

```text
update_valid_D = 1  iff the selected yaw-only or Ay+r update
                 completed with finite innovation, finite S,
                 accepted denominator and finite x/P output.
nis_valid_D    = update_valid_D
```

正常零创新仍是 `update_valid_D=1, nis_valid_D=1`；未更新、分母无效、异常回退为 `NIS_D=0` 时为 `0`。`measurementDimension_D` 继续表示实际更新维度，不被 valid 标志替代。

最小实现位置：在 `vy_dynamic_ekf_step_v13/v17` 将 update-valid 从局部判定传播到 `info`，在 `vy_dynamic_ekf_v1_17` 增加独立标量输出/日志字段。该修改本阶段未执行。

## 2. K-track contract

现有 K wrapper 的 `diag_out(1)=NIS_K`、`diag_out(2)=abs(r)`，二者保留为独立 reliability evidence。冻结：

```text
update_valid_K = 1  iff finite Vx innovation and S>0,
                 update completed, and finite x/P output.
nis_valid_K    = update_valid_K
```

正常零 Vx innovation 为 valid zero-NIS；异常/未更新路径的零值必须由 valid 标志区分。`abs(r)`不由 NIS valid 替代，历史 `abs(r)>0.01`仍只是诊断分区，不是正式 `r0`。

最小实现位置：在 `vy_kinematic_kf_step` 形成并返回 `info.updateValid`，由 `vy_kinematic_kf` 增加独立 valid 输出/日志字段；可选同时输出 `S_K`以便复核 NIS 分母。数学核心和既有五维诊断顺序不变。本阶段未执行。

## 3. F-track contract

F 保持 propagation-only 数学，不新增 measurement innovation/NIS。冻结以下边界语义：

```text
propagation_age_steps:
  reset hit                         -> 0
  first valid non-reset propagation -> 1
  each subsequent valid hit         -> previous + 1

age_valid  = 1 iff age counter is initialized and current propagation
             inputs/state remain finite and accepted.
reset_valid = 1 iff current reset input is finite and its reset decision
              was deterministically consumed by F boundary.
```

`propagation_age_steps`是自最近一次 reset 完成的 propagation increment 数，不是 wall-clock；因此与 A3R1 的 `n>=1` convention 一致。若 age 或状态无效，任何在线 reliability consumer 必须把该证据标为 invalid，不能给高可靠度。

最小实现位置：`vy_feedback_propagation_simulink_sfun` 的 boundary/DWork 增加 age counter 和输出诊断；不修改 `vy_feedback_propagation_step` 的传播方程或 P0/Q0 契约。本阶段未执行。

## 4. Invalid semantics

- 任一 `*_valid=0` 时，NIS/age 数值不得单独解释为高可靠度；后续 LifeSig 层必须先应用 valid mask。
- 不定义 fallback weight、不定义 LifeSig 数值、不调 `epsilon/r0/tau_F`。
- 不使用 `Vy_true`、maneuver ID、holdout switching 或未来样本。

## 5. Existing FWCAL data readiness

冻结 manifest 中的五组 `FWCAL_C01R1/C02/C03/C04/C05` 均有 0–16 s、100 Hz、同一 `Vy_true` 对齐，以及：

- D：`dekf_x_log/dekf_P_log/dekf_diag_log`（含 NIS、`useAy`、`measurementDimension`）；
- K：`kkf_x_log1/kkf_P_log1/kkf_diag_log1`（含 NIS、`abs(r)`、innovation）；
- F：`fusion_f_P_log/fusion_f_diag_log`、`reset_g0`及时间轴；
- maneuver identity 和冻结 evaluation window。

这些原始字段足以支持误差和已有诊断的离线配对，但当前 artifacts **没有**：

1. D 的独立 `nis_valid_D/update_valid_D`；
2. K 的独立 `nis_valid_K/update_valid_K`；
3. F 的显式 `propagation_age_steps/age_valid/reset_valid`。

因此无需重跑即可重建 F 的离线 age 序列，也可审计 D/K 的 nominal NIS/`abs(r)`；但无法从现有日志无歧义完成“正常 NIS=0 与异常 NIS=0”区分，也无法证明未来在线 age boundary value。完整 A2R2 re-audit 的证据准备状态为 **PARTIAL — NOT SUFFICIENT FOR COMPLETE REAUDIT**。

## 6. 是否需要代码接口修改

需要，但仅限后续最小接口增加：D/K valid 标志，以及 F age/valid/reset-valid 输出。不得修改 D/K/F 数学、Q/R、P0_F/Q_F 或 fusion。该接口修改不是本阶段执行内容；现行 F core `P0_F>0` 与 `P0_F_FROZEN=0` contract blocker 继续保持。

## 7. Verdict

契约本身已明确且最小，但由于现有五组 FWCAL 缺少上述独立 valid/age capture，无法在不新增接口证据的情况下完成下一轮完整 adequacy re-audit。

**VERDICT: BLOCKED_PENDING_MINIMAL_RELIABILITY_INTERFACE_CAPTURE**

下一步应先在独立、非运行的接口修订阶段落实这些输出并保持历史数据不可覆盖；随后再进行 `V2.7-A2R2 RELIABILITY ADEQUACY REAUDIT`。不得在本阶段启动 runtime 或拟合 LifeSig 参数。
