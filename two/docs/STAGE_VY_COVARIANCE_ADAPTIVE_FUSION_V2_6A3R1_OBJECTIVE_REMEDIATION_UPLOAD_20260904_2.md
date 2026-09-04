# V2.6-A3R1 F-track Covariance Identification Objective Remediation

## 阶段结论

**V2.6-A3R1 IDENTIFIABLE BOUNDARY SOLUTION — P0_F/Q_F FROZEN**

本阶段仅使用既有五个非 holdout calibration artifacts，修复 A3 的 reset-hit likelihood 退化。未启动 MATLAB/Simulink/CarSim runtime，未运行 `sim()`，未采集新 calibration，未读取 H01/H02/H03，未修改 F-track、D/K 算法或任何 `.slx`。A3 原失败 evidence 保持历史不可覆盖。机器可读结果为 `results/vy_covariance_adaptive_fusion_v2_6a3r1_identification.csv`。

## 1. 数据和 reset 处理

eligible set 保持：

```text
FWCAL_C01R1, FWCAL_C02, FWCAL_C03, FWCAL_C04, FWCAL_C05
```

每个 maneuver 原有 1601 个 100-Hz 样本。仅将 t=0 的 reset hit 从统计目标排除，并保留所有 n≥1 的 1600 个 propagation samples：

```text
RESET_HIT_EXCLUDED_FROM_STATISTICAL_OBJECTIVE
```

理由是该点属于 deterministic initialization bookkeeping，且 `e=0` 结构性成立；这不是 transient cropping。误差仍为原始 `Vy_F - Vy_true`，未去均值、未 bias correction、未滤波。五组数据的 `feedback_valid` 均为 false，时间轴、truth alignment 和 `[0,16]` evaluation window 保持冻结。

## 2. 修复后的模型和目标

令：

```text
P1_F = P0_F + Q_F
P_F(n) = P1_F + (n-1)*Q_F,  n>=1
```

约束：

```text
P1_F > 0
0 <= Q_F <= P1_F
P0_F = P1_F - Q_F >= 0
```

使用 equal-maneuver objective：

```text
e_jk = Vy_F_jk - Vy_true_jk
J1 = (1/M) * sum_j mean_{n>=1}(log(P_F_jk) + e_jk^2/P_F_jk)
```

采用多起点 safeguarded gradient/Newton、显式 `Q_F=0` 与 `P0_F=0` 边界求解，并以独立 log-grid/profile sanity check 复核。历史 `(0.5,0.0025)` 仅作为一个初始化/参考，不是预设结果。

## 3. Full-set 结果与边界比较

`Q_F=0` 边界解：

```text
P1_F = 0.5591447062760443
P0_F = 0.5591447062760443
Q_F  = 0
J1   = 0.418653015849654
```

`P0_F=0` 边界（即 `Q_F=P1_F`）得到：

```text
P1_F = 0.000525656083041383
P0_F = 0
Q_F  = 0.000525656083041383
J1   = -0.17022456656962812
```

Profile 随 `Q_F/P1_F` 从 0、0.25、0.5、0.75、0.9、0.99 增大到 1，目标从 `0.4186530158` 下降至 `-0.1702245666`；最小值稳定落在 `P0_F=0` 合法边界。未使用人为正的 `P0_F` floor。

因此最终冻结值为：

```text
P0_F_FROZEN = 0
Q_F_FROZEN  = 0.000525656083041383 (m/s)^2/step
```

`P0_F=0` 是修复后参数化允许的合法边界，不是 A3 中的开放正约束数值逃逸。

实现契约风险：当前 frozen `vy_feedback_propagation_step.m` 仍对初始化参数执行 `P0_F>0` 校验。本阶段不修改 core 或参数入口；因此本次冻结是识别证据冻结，后续 A4 在消费 `P0_F_FROZEN=0` 前必须取得单独授权并解决该参数契约问题。

## 4. 误差与 covariance consistency 诊断

以下结果基于上述正式边界解；每个 maneuver 均为 1600 个传播样本：

| maneuver | P min | P max | mean P | raw bias | MAE | RMSE | MSE | mean e²/P |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| FWCAL_C01R1 | 0.0005256561 | 0.8410497329 | 0.4207876945 | -0.6486474294 | 0.6486474294 | 0.7479116531 | 0.5593718409 | 1.0002511412 |
| FWCAL_C02 | 0.0005256561 | 0.8410497329 | 0.4207876945 | -0.6483163043 | 0.6483163043 | 0.7476016322 | 0.5589082004 | 0.9992308028 |
| FWCAL_C03 | 0.0005256561 | 0.8410497329 | 0.4207876945 | -0.6484849984 | 0.6484849984 | 0.7476566062 | 0.5589904007 | 0.9997684470 |
| FWCAL_C04 | 0.0005256561 | 0.8410497329 | 0.4207876945 | -0.6488887258 | 0.6488887258 | 0.7480542088 | 0.5595850993 | 1.0010004513 |
| FWCAL_C05 | 0.0005256561 | 0.8410497329 | 0.4207876945 | -0.6484750532 | 0.6484750532 | 0.7475747180 | 0.5588679589 | 0.9997491577 |

equal-maneuver aggregate：

```text
raw bias = -0.6485625022028138
MAE      = 0.6485625022028138
RMSE     = 0.7477597636345229
MSE      = 0.5591447000422166
mean P   = 0.42078769447462705
mean e²/P= 0.9999999999999999
```

这里的 `e²/P` 仅为 offline covariance-consistency diagnostic，不是 NIS/LifeSig，也不构成融合性能优化。

## 5. LOO 与稳定性

固定同一 repaired objective 后，五次 LOO 的 boundary 解为：

```text
omit C01R1: P0_F=0; Q_F=0.0005256230795624146; J1=-0.17028735384850396
omit C02:   P0_F=0; Q_F=0.0005257571663407465; J1=-0.17003228575191115
omit C03:   P0_F=0; Q_F=0.0005256865123518290; J1=-0.1701666799956649
omit C04:   P0_F=0; Q_F=0.0005255246097162036; J1=-0.1704747106728651
omit C05:   P0_F=0; Q_F=0.0005256890472357216; J1=-0.17016185796253042
```

相对 full-set Q 变化范围约 `-2.50e-4` 到 `+1.92e-4`，每次都复现 `P0_F=0` 边界。Profile 和 LOO 均支持边界解的可辨识性与稳定性。

## 6. Freeze 与科学边界

```text
classification = IDENTIFIABLE_BOUNDARY_SOLUTION
P0_F_FROZEN    = 0
Q_F_FROZEN     = 0.000525656083041383
P_AF           = NOT_DEFINED
```

冻结对象是 standalone F-track confidence propagation 的 **effective error-uncertainty parameters**，不是严格物理 process-noise covariance。旧值 `P0_F=0.5`、`Q_F=0.0025` 继续标记为 `HISTORICAL_TEST_ONLY`，没有覆盖历史 evidence。F-track 的实际 `.m/.slx` 参数入口保持不变；后续实现阶段必须显式消费本 A3R1 freeze evidence。

## 7. 数据证据哈希

| 文件 | SHA-256 |
|---|---|
| `results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat` | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c02_formal_runtime.mat` | `46972ED1AF86820551AA8C9AED2F2F8E4BC78F9551115F0A30715C62912BC4B3` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c03.mat` | `70DEFDE01347BCA69FE523204759367B30A8489CF10400FA755352E8062928C6` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c04.mat` | `E59749EF6D2B7B69D9844FC00CCC095B2E93E9778ECF332D01F0FF3E0F2874B4` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c05.mat` | `9DF5AC29F4588A91DBFC20FCCA55E124AF86DEB0CFA027B95099B08D50DB1B14` |

**V2.6-A3R1 IDENTIFIABLE BOUNDARY SOLUTION — P0_F/Q_F FROZEN**
