# V2.6-A3R2 状态

阶段：V2.6-A3R2 — CROSS-TRACK COVARIANCE COMPARABILITY AUDIT

结论：`COVARIANCE_SCALE_CALIBRATION_REQUIRED`

既有五组非-holdout calibration 数据均完成 100 Hz、0–16 s、同时间戳 `Vy_true` 对齐。D/K/F 的 covariance 单位均为 `(m/s)^2`，但绝对尺度明显不兼容：D 全局均值约 `3.6966e-4`，K 约 `0.2494`，F 约 `0.4205`。A1 implied-weight 离线诊断（排除 F 的 t=0 精确零 covariance）得到 mean alpha `[0.9954751, 0.00170375, 0.00282113]`，D 为最大权重的样本比例 `1.0`，构成 `SCALE_DOMINATED_WEIGHT_SATURATION`。

`P0_F_FROZEN=0` 在当前 `model/vy_feedback_propagation_step.m` 的 `P0_F>0` 断言下尚不能直接消费；本阶段未修改 core 或参数入口。`P_AF=NOT_DEFINED`，未拟合任何 `c_i`，未调 Q/R、权重或 epsilon。

完整数值表和机器可读证据：

- `results/vy_covariance_adaptive_fusion_v2_6a3r2_comparability.csv`
- `docs/STAGE_VY_COVARIANCE_ADAPTIVE_FUSION_V2_6A3R2_CROSS_TRACK_COMPARABILITY.md`
