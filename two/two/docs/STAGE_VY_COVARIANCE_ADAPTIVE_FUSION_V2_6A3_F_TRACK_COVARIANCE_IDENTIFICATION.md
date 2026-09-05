# V2.6-A3 F-track Covariance Parameter Identification

## 阶段结论

**V2.6-A3 NUMERICAL IDENTIFICATION FAILURE — PARAMETERS NOT FROZEN**

本阶段只使用既有非 holdout calibration artifacts 做离线识别。没有启动 MATLAB/Simulink/CarSim runtime，没有运行 `sim()`，没有新 calibration runtime，没有读取 H01/H02/H03，也没有修改任何 D/K/F 算法或模型。机器可读证据为 `results/vy_covariance_adaptive_fusion_v2_6a3_identification.csv`。

## 1. 数据门禁

最终 eligible set 为：

```text
FWCAL_C01R1, FWCAL_C02, FWCAL_C03, FWCAL_C04, FWCAL_C05
```

五个记录均有 1601 个 100-Hz F-track 样本、0–16 s 对齐时间轴、reset 信息、`feedbackApplied=0`、真实 Vy offline 日志、maneuver identity 和冻结 evaluation window。每个记录的 reset 仅在 t=0；因此严格按 core 语义设置 `n=0` 于 reset hit，后续每个非 reset hit 递增 1。没有剔除 transient；只检查了有限性和既有 integrity gate。

## 2. Objective 与计算方法

对每条轨迹：

```text
e_jk = Vy_F_jk - Vy_true_jk
P_jk(P0_F,Q_F) = P0_F + n_jk*Q_F
```

使用 equal-maneuver Gaussian quasi-negative-log-likelihood：

```text
J = (1/M) * sum_j mean_k(log(P_jk) + e_jk^2/P_jk)
```

约束为 `P0_F>0`、`Q_F>=0`，单位分别是 `(m/s)^2` 和 `(m/s)^2/step`。采用多起点 safeguarded analytic-gradient/Newton、`Q_F=0` 一维边界求解，并用独立 log-grid/profile sanity check 复核；起点包含历史测试值 `(0.5,0.0025)`，但未依赖或优先选择该值。

## 3. 关键数值结果：目标函数退化

合法 `Q_F=0` 边界的一维解为：

```text
P0_F = 0.5587954528618008
Q_F  = 0
J    = 0.41802821108081173
```

但正 `Q_F` profile 更低，并且当 `P0_F` 的正数搜索下界继续降低时，目标持续下降：

```text
P0_F=1e-8   Q_F=0.0005256561083542736   J=-0.18162390636686981
P0_F=1e-12  Q_F=0.0005256560857018172   J=-0.18737684423236559
```

根因是所有 reset 样本在 t=0 满足 `e=0`。因此该项对目标贡献 `log(P0_F)`；在严格约束 `P0_F>0` 下，`P0_F→0+` 会使目标无界下降。也就是说，当前目标与包含 reset 初始样本的窗口组合没有有限的联合最小值。不同起点和独立 profile 均指向同一 floor-dependent degeneration，而不是可追溯的有限参数解。

这不是“`Q_F=0` 边界自动失败”：`Q_F=0` 本身是合法边界，但它不是全局最优；真正问题是 `P0_F` 的开放正约束和 reset 零误差样本造成的数值奇异性。

## 4. 误差与 NEES 诊断（明确为非冻结 floor candidate）

为使诊断可复现，使用显式报告 floor `P0_F=1e-8`、`Q_F=0.0005256561083542736`。该组数值不是正式 candidate，也没有写入 F-track 参数入口。

| maneuver | P min | P max | raw bias | MAE | RMSE | MSE | mean P | mean NEES |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| FWCAL_C01R1 | 1e-8 | 0.8410497834 | -0.6482422780 | 0.6482422780 | 0.7476780402 | 0.5590224518 | 0.4205248967 | 0.9996263028 |
| FWCAL_C02 | 1e-8 | 0.8410497834 | -0.6479113597 | 0.6479113597 | 0.7473681161 | 0.5585591010 | 0.4205248967 | 0.9986066017 |
| FWCAL_C03 | 1e-8 | 0.8410497834 | -0.6480799484 | 0.6480799484 | 0.7474230729 | 0.5586412500 | 0.4205248967 | 0.9991439101 |
| FWCAL_C04 | 1e-8 | 0.8410497834 | -0.6484834236 | 0.6484834236 | 0.7478205514 | 0.5592355771 | 0.4205248967 | 1.0003751447 |
| FWCAL_C05 | 1e-8 | 0.8410497834 | -0.6480700095 | 0.6480700095 | 0.7473412103 | 0.5585188846 | 0.4205248967 | 0.9991246328 |

Equal-maneuver aggregate at this diagnostic floor is raw bias `-0.6481574038`、MAE `0.6481574038`、RMSE `0.7475261982`、MSE `0.5587954529`、mean NEES `0.9993751512`。这些只用于展示目标退化下的数值行为，不构成参数接受或性能结论；误差未去均值、未 bias-correct、未滤波。

## 5. LOO / stability

在同一显式 `P0_F=1e-8` floor 下，LOO 的 `Q_F` 为：

```text
omit C01R1: 0.0005256231037798012  (relative shift -6.28e-5)
omit C02:   0.0005257571881215952  (relative shift  1.92e-4)
omit C03:   0.0005256865411037481  (relative shift  5.79e-5)
omit C04:   0.0005255246327302347  (relative shift -2.50e-4)
omit C05:   0.0005256890750825641  (relative shift  6.27e-5)
```

这些小的 Q 变化不能消除 P0→0 奇异性；每次 LOO 仍依赖人为 floor，因此不能判定为可冻结的稳定联合解。

## 6. Freeze decision 与科学边界

```text
classification       = NUMERICAL_IDENTIFICATION_FAILURE
P0_F_FROZEN          = NO
Q_F_FROZEN           = NO
P_AF                 = NOT_DEFINED
```

旧值 `P0_F=0.5`、`Q_F=0.0025` 继续保留为 `HISTORICAL_TEST_ONLY`，没有覆盖历史 evidence，也没有升级为正式参数。识别目标针对的是 standalone F-track 的 **effective error-uncertainty parameters**；本阶段没有声称严格物理 process-noise covariance、BLUE 或 statistically optimal fusion。

当前最小 blocker 是 objective 的初始 reset 样本奇异性，而不是缺少 calibration data。后续若继续，应由单独阶段决定可审计的初始样本/先验处理或其他不改变科学角色的识别约束；本阶段不自行改 window、去除 reset 样本、调参或实现 workaround。

## 7. 数据完整性哈希

| artifact | SHA-256 |
|---|---|
| `results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat` | `0AD814FFB9637A9DFBFB498E3AF36CEC4F8E6E27DEB4F1EB130BE338304870F4` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c02_formal_runtime.mat` | `46972ED1AF86820551AA8C9AED2F2F8E4BC78F9551115F0A30715C62912BC4B3` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c03.mat` | `70DEFDE01347BCA69FE523204759367B30A8489CF10400FA755352E8062928C6` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c04.mat` | `E59749EF6D2B7B69D9844FC00CCC095B2E93E9778ECF332D01F0FF3E0F2874B4` |
| `results/vy_fixed_fusion_v2_5g_fwcal_c05.mat` | `9DF5AC29F4588A91DBFC20FCCA55E124AF86DEB0CFA027B95099B08D50DB1B14` |

**V2.6-A3 NUMERICAL IDENTIFICATION FAILURE — P0_F/Q_F NOT FROZEN.**
