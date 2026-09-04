# 车辆横向速度多轨迹估计：硕士论文写作资料交接

> 本文件是当前项目用于论文写作的唯一主入口。它只保留最终方法、可引用验证结果、严格结论边界和最小资料包，不记录开发时间线，不把工程门禁或失败运行包装成论文结果。

状态标签：

- `FINAL_METHOD`：最终采用且已冻结的方法；
- `VALIDATED_RESULT`：已有实现或运行证据支持的结果；
- `DIAGNOSTIC_ONLY`：只可用于分析或讨论，不属于正式在线权重；
- `NOT_VALIDATED`：尚无相应运行或实验支撑；
- `ABANDONED_ROUTE`：已审计但未纳入最终方法的路线。

---

## 1. 最终研究主线

### 1.1 本部分解决的问题

`FINAL_METHOD`：在车辆横向速度 `Vy` 不能直接作为在线测量的条件下，构造三条相互独立、机理不同的估计轨迹，并在统一 100 Hz 时间基准上形成一个具有最小在线健康调节能力的融合输出 `Vy_LS`。

研究对象不是控制器重构，也不是完整车辆状态观测器重构。核心问题是：如何利用动力学模型、运动学模型和惯性传播三种互补信息，得到可供后续车辆稳定性控制使用的横向速度估计接口，同时避免把未经证据支持的 NIS、协方差或观测性指标强行解释为可靠度权重。

### 1.2 三条轨迹的作用

- **D 轨迹（D-EKF）**：利用车辆横向动力学、轮胎侧向力、IMU 横向加速度和横摆角速度测量估计 `[Vy,r]`。在当前 nominal 工况中它是精度最高的单轨迹。
- **K 轨迹（K-KF）**：利用平面运动学关系和纵向速度测量估计 `[Vx,Vy]`。它提供与动力学模型不同的估计机理，并揭示横摆激励对 `Vy` 可观测性的影响。
- **F 轨迹（propagation track）**：采用 `Ay-rVx` 的惯性积分传播 `Vy`，不做测量校正。它提供第三条纯传播信息源，并显式输出传播年龄作为误差随时间累积的在线证据。

三条轨迹在线不使用真实 `Vy`，轨迹之间不交换状态或协方差。

### 1.3 最终 LifeSig 融合解决的问题

`FINAL_METHOD`：最终融合不是协方差最优融合，而是“静态质量先验 × 最小在线健康门”的归一化加权：

- 静态先验 `q_D/q_K/q_F` 表示各轨迹在非 holdout 标定工况中的平均误差风险；
- D/K 在线健康仅表示当前更新和输出在数值上可用；
- F 在线健康利用传播年龄的指数衰减；
- 所有正式 score 为零时，使用明确标记为 invalid 的 last-valid 数值保持。

该结构解决的是**统一输出、数值连续性和有限的时间变化权重**，而不是已经证明的全面故障隔离或性能最优性。

### 1.4 与车辆稳定性控制接口的关系

`FINAL_METHOD`：融合器输出为 100 Hz 标量横向速度估计 `Vy_LS [m/s]`，可作为后续稳定性控制状态接口。

若下游同时具有纵向速度 `Vx [m/s]`，侧偏角候选接口为：

```text
beta_hat = atan2(Vy_LS, Vx)                 [rad]
```

小侧偏角下可近似为 `beta_hat ≈ Vy_LS/Vx`。实际控制器接线、低速保护、`Vx` 来源切换及基于 `beta_hat` 的稳定性控制闭环均为 `NOT_VALIDATED`，不得写成已完成工作。

---

## 2. 最终实际采用的方法

### 2.1 D-EKF

**状态与作用**

```text
x_D = [Vy; r]
```

- `Vy [m/s]`：车辆质心横向速度；
- `r [rad/s]`：横摆角速度。

**输入**

- `Vx [m/s]`；
- 四轮转角 `[delta_FL,delta_FR,delta_RL,delta_RR] [rad]`；
- 轮胎/车辆参数；
- 测量 `Ay_IMU [m/s^2]`、`AVz_IMU=r_meas [rad/s]`。

**输出**

- `Vy_D`、`r_D`；
- `P_D (2×2)`；
- innovation、NIS、增益等诊断；
- `update_valid_D` 数值更新有效标志。

**核心思想**

采用横向动力学预测、数值 Jacobian 和 Joseph 形式 EKF 更新。预测与横摆角速度更新保持 100 Hz；最终采用 A20 模式，Ay+r 二维更新为 20 Hz，其余拍执行一维 r 更新。

**采样周期**：基础周期 `Ts=0.01 s`；Ay 更新周期 `0.05 s`。

**冻结参数**：见第 4 节。

**边界**：`update_valid_D` 是数值更新有效性，不是物理可信度。部分非有限输入会在 D core 内被替换为零，因此不能把它写成完整传感器故障检测。

### 2.2 K-KF

**状态**

```text
x_K = [Vx; Vy]
```

**输入**

- `u=[Ax_IMU;Ay_IMU;r]`；
- 标量 `Vx` 测量；
- reset。

**输出**

- `Vx_K`、`Vy_K`；
- `P_K (2×2)`；
- NIS、`abs(r)`、innovation、`K11/K21`；
- `update_valid_K`。

**核心思想**

采用刚体平面运动学关系进行 Euler 预测，并使用 `Vx` 标量测量校正纵向状态。横摆角速度通过状态转移矩阵建立 `Vx` 测量对 `Vy` 的间接观测耦合。

**采样周期**：`Ts=0.01 s`，100 Hz。

**冻结参数**：见第 4 节。

**边界**：当前隔离验证使用真实物理 `Vx` 作为 K-KF 的 `Vx` measurement；真实 `Vy` 仅用于离线验证。K 的低横摆可观测性问题已被确认，但 `abs(r)` 没有进入最终正式权重。

### 2.3 F propagation track

**状态**

```text
Vy_F
```

同时实现了标量 `P_F` 传播，但 `P_F` 不进入最终 LifeSig 主权重。

**输入**

- `Ay_IMU [m/s^2]`；
- `AVz_IMU=r [rad/s]`；
- `Vx_source [m/s]`；
- reset。

最终 LifeSig 集成采用 standalone 模式：`feedback_valid=false`，不从 D/K/fusion 接收反馈状态。

**输出**

- `Vy_F`、`P_F`；
- propagation diagnostic；
- `propagation_age_steps`、`age_valid`、`reset_valid`。

**核心思想**

从横向加速度运动学关系中扣除 `rVx` 项，对横向速度进行离散积分。传播年龄从 reset 后零开始，每次有效传播递增，用于描述无测量校正传播的不确定性累积趋势。

**采样周期**：`Ts=0.01 s`，100 Hz。

**参数边界**：当前运行模型中的 `P0_F=0.5`、`Q_F=0.0025 (m/s)^2/step` 是历史 test-only 数值，不是最终论文可宣称的已标定 covariance 参数。最终 LifeSig 不使用 `P_F` 形成权重。

### 2.4 Static quality prior

`FINAL_METHOD`：基于五组 `NON_HOLDOUT_RELIABILITY_CALIBRATION` 工况，按轨迹分别计算未经去均值、未经 bias correction 的原始 MSE；先对 maneuver 等权求平均风险，再取逆风险并归一化。

冻结结果：

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452
```

这些量是 estimator-quality prior，不是单独使用的最终固定权重。

### 2.5 LifeSig reliability fusion

`FINAL_METHOD`：

- D/K：仅以 update availability 和有限状态作为正式健康门；
- F：以 availability 乘传播年龄指数衰减；
- NIS、`abs(r)`、pairwise disagreement 和 covariance 均不进入正式 score；
- 归一化 score 得到实时 `alpha_D/K/F` 和 `Vy_LS`。

冻结 `tau_F=28.252990189369939 s`，`Ts=0.01 s`。

### 2.6 Fallback/reset

`FINAL_METHOD`：正常路径更新 last-valid 输出；所有 score 无法形成有限正和时，输出最后一次 valid `Vy_LS`，若历史不存在则输出零，同时 alpha 全零、`fusion_valid=0`、`fallback_active=1`。

reset 先清除 last-valid 历史，再评价当前拍；当前输入有效时允许同拍重新进入正常融合。

`VALIDATED_RESULT`：fallback/reset 已通过纯 MATLAB 单元测试。`NOT_VALIDATED`：真实 CarSim availability drop 或故障条件下没有触发过 fallback。

---

## 3. 论文必须保留的公式

### 3.1 D-EKF 状态和更新模型

状态：

```text
x_D = [Vy, r]^T
```

连续动力学：

```text
dVy/dt = (Fy_FL cos(delta_FL) + Fy_FR cos(delta_FR)
          + Fy_RL + Fy_RR)/m - Vx*r

dr/dt  = (a(Fy_FL cos(delta_FL) + Fy_FR cos(delta_FR))
          - b(Fy_RL + Fy_RR))/Iz
```

其中 `Fy_* [N]` 为轮胎侧向力，`m [kg]` 为整车质量，`Iz [kg·m^2]` 为横摆转动惯量，`a/b [m]` 为质心到前/后轴距离。前后轴侧向力分别使用冻结比例 `k_f/k_r` 修正。

Euler 预测及协方差：

```text
x_D^- = x_D + Ts*f_D(x_D,u)
P_D^- = Phi_D P_D Phi_D^T + Q_D
```

测量模型：

```text
z_D = [Ay_IMU; AVz_IMU]
h_D(x_D^-) = [(sum corrected lateral force)/m; r]
```

Ay 更新拍采用二维测量；其余拍只使用第二维横摆角速度测量。

EKF 更新：

```text
innovation_D = z_D - h_D(x_D^-)
S_D = C_D P_D^- C_D^T + R_D
K_D = P_D^- C_D^T S_D^-1
x_D^+ = x_D^- + K_D innovation_D

P_D^+ = (I-K_D C_D)P_D^-(I-K_D C_D)^T
        + K_D R_D K_D^T
```

作用：由动力学模型和 IMU 测量估计 `Vy/r`。参数来源：冻结 D-EKF V1.17 实现；采样与 Ay 多速率来自最终 A20 选择。

### 3.2 K-KF 模型

连续模型：

```text
dVx/dt = Ax + r*Vy
dVy/dt = Ay - r*Vx
```

100 Hz Euler 预测：

```text
F_K = [1, r*Ts;
      -r*Ts, 1]

x_K^- = F_K x_K + Ts[Ax;Ay]
P_K^- = F_K P_K F_K^T + Q_K
```

纵向速度测量更新：

```text
z_K = Vx_meas
C_K = [1,0]
innovation_K = z_K - C_K x_K^-
S_K = C_K P_K^- C_K^T + R_Vx
K_K = P_K^- C_K^T / S_K
x_K^+ = x_K^- + K_K innovation_K

P_K^+ = (I-K_K C_K)P_K^-(I-K_K C_K)^T
        + K_K R_Vx K_K^T
```

单位：`Vx/Vy [m/s]`、`Ax/Ay [m/s^2]`、`r [rad/s]`。作用：以运动学耦合形成独立 `Vy_K`。参数来源：冻结 K-KF V2.1。

### 3.3 F 传播公式

最终 standalone 状态传播：

```text
g_F(k) = Ay_IMU(k) - AVz_IMU(k)*Vx_source(k)      [m/s^2]
Vy_F(k) = Vy_F(k-1) + Ts*g_F(k)                   [m/s]
```

实现还保留：

```text
P_F(k) = P_F(k-1) + Q_F
```

但 `P_F/Q_F` 不进入最终 LifeSig 权重，不能作为最终已标定 covariance 结论。

reset 时：

```text
Vy_F = Vy_F0
P_F  = P0_F
propagation_age_steps = 0
```

作用：提供无测量校正的惯性传播轨迹和传播年龄。

### 3.4 Static quality prior 识别

对轨迹 `i∈{D,K,F}`、maneuver `j`：

```text
e_i,j(k) = Vy_i,j(k) - Vy_true,j(k)                       [m/s]
MSE_i,j = mean_k(e_i,j(k)^2)                              [(m/s)^2]
R_i = mean_j(MSE_i,j)                                     [(m/s)^2]
q_i_raw = 1/R_i                                           [s^2/m^2]
q_i = q_i_raw / sum_l(q_l_raw)                            [dimensionless]
```

作用：形成跨 maneuver 等权的静态轨迹质量先验。`Vy_true` 只在离线识别中使用。

### 3.5 正式健康量

```text
availability_D = update_valid_D && isfinite(Vy_D)
H_D = double(availability_D)

availability_K = update_valid_K && isfinite(Vy_K)
H_K = double(availability_K)

availability_F = age_valid_F
                 && isfinite(propagation_age_steps)
                 && propagation_age_steps >= 0
                 && isfinite(Vy_F)

H_F = double(availability_F)
      * exp(-(propagation_age_steps*Ts)/tau_F)
```

`H_i` 无量纲。D/K 表示数值可用性；F 同时表达传播年龄衰减。`tau_F` 来自五组非 holdout 数据的 age-conditioned error-risk 离线识别及 LOO 稳定性检查。

### 3.6 Score、权重与融合输出

```text
score_i = q_i*H_i
S = score_D + score_K + score_F

alpha_i = score_i/S,      when isfinite(S) && S>0

Vy_LS = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F
```

单位：`score/alpha/H/q` 均无量纲，`Vy_LS [m/s]`。有效输入项逐项求和，inactive 轨迹先置零，禁止 `0*NaN` 污染。

### 3.7 Fallback

```text
if ~(isfinite(S) && S>0):
    if has_last_valid:
        Vy_LS = last_valid_Vy_LS
    else:
        Vy_LS = 0
    alpha_D = alpha_K = alpha_F = 0
    fusion_valid = 0
    fallback_active = 1
```

fallback 只保证数值连续性，不表示当前输出是有效估计。

---

## 4. 最终冻结参数表

### 4.1 模型参数

| 参数 | 数值 | 单位 | 类型/来源 | 用途 |
|---|---:|---|---|---|
| `m` | 1860 | kg | 模型参数；D wrapper | 整车质量 |
| `Iz` | 2687.1 | kg·m² | 模型参数；D wrapper | 横摆转动惯量 |
| `a` | 1.18 | m | 模型参数；D wrapper | 质心至前轴距离 |
| `b` | 1.77 | m | 模型参数；D wrapper | 质心至后轴距离 |
| `track` | 1.575 | m | 模型参数；D wrapper | 轮距 |
| `Rw` | 0.393 | m | 模型参数；D wrapper | 车轮滚动半径；保留于参数结构 |
| `k_f` | 0.78181 | 1 | 模型适配参数；冻结 D-EKF | 前轴侧向力比例修正 |
| `k_r` | 1.09186 | 1 | 模型适配参数；冻结 D-EKF | 后轴侧向力比例修正 |

### 4.2 滤波器参数

| 模块 | 参数 | 数值 | 单位/解释 | 状态 |
|---|---|---:|---|---|
| D | `Ts_D` | 0.01 | s | FROZEN |
| D | `P0_D` | `diag([0.1,0.1])` | `[(m/s)^2,(rad/s)^2]` | FROZEN |
| D | `Q_D` | `diag([1e-4,1e-4])` | state covariance increment/step | FROZEN |
| D | `R_D` | `diag([1e-2,3.365172961808e-4])` | Ay/r measurement variance | FROZEN |
| D | `denomEps` | `1e-12` | numerical denominator guard | FROZEN |
| D | Ay assimilation | 20 | Hz | FROZEN A20 |
| D | r update/prediction | 100 | Hz | FROZEN |
| K | `Ts_K` | 0.01 | s | FROZEN |
| K | `P0_K` | `diag([0.1,0.1])` | `[(m/s)^2,(m/s)^2]` | FROZEN |
| K | `Q_K` | `diag([1e-4,1e-3])` | state covariance increment/step | FROZEN |
| K | `R_Vx` | `1e-4` | `(m/s)^2` | FROZEN |
| F | `Ts_F` | 0.01 | s | FROZEN |
| F | `Vy_F0` | 0 | m/s | 当前 reset/initial state |
| F | `P0_F=0.5` | — | `(m/s)^2` | TEST-ONLY runtime value；不是最终设计参数 |
| F | `Q_F=0.0025` | — | `(m/s)^2/step` | TEST-ONLY runtime value；不是最终设计参数 |

### 4.3 离线识别参数

| 参数 | 数值 | 单位 | 来源与状态 |
|---|---:|---|---|
| `q_D` | 0.8426184093257221 | 1 | 五组非 holdout、equal-maneuver raw-MSE inverse-risk；FROZEN |
| `q_K` | 0.14643969744669255 | 1 | 同上；FROZEN |
| `q_F` | 0.010941893227585452 | 1 | 同上；FROZEN |
| `tau_F` | 28.252990189369939 | s | F age-conditioned error-risk fit，LOO 稳定；FROZEN |
| LifeSig `Ts` | 0.01 | s | 公共 100 Hz contract；FROZEN |

五组识别工况为 `FWCAL_C01R1/C02/C03/C04/C05`，均为 `NON_HOLDOUT_RELIABILITY_CALIBRATION`。不得把 H01/H02/H03 作为识别来源。

---

## 5. 最终验证结果

### 5.1 实现验证

- `VALIDATED_RESULT`：LifeSig core regression `24/24 PASS`；新增 health 输出后，原八个主输出在 1000 次确定性随机对比中 bitwise equivalent。
- `VALIDATED_RESULT`：wrapper 和 integration target compile PASS。
- `VALIDATED_RESULT`：0.2 s smoke 为 21 个对齐 100 Hz 样本，runtime 与冻结公式 replay 最大差异为 0。
- 0.2 s smoke 只用于实现/接线验证，不作为论文性能结果。

### 5.2 16 s nominal 工况

工况：`16 s / 约20 m/s / 前轮0.02 rad / 0.4 Hz / 100 Hz`；角色为 `NON_HOLDOUT_NOMINAL_ENGINEERING_VALIDATION`。

运行完整性：

```text
samples = 1601
time = 0...16 s
dt = 0.01 s
all formal logs finite/aligned = YES
runtime-vs-formula replay max error = 0
availability drops [D,K,F] = [0,0,0]
fallback count = 0
max |sum(alpha)-1| = 2.2204460492503131e-16
```

### 5.3 性能表

以下全部为同一 16 s 数据上的 `DESCRIPTIVE_ONLY` 结果；没有预注册性能通过阈值，不得据此反向调参。

| 方法 | RMSE (m/s) | MAE (m/s) | MaxAbs (m/s) | Bias (m/s) | 论文角色 |
|---|---:|---:|---:|---:|---|
| D-EKF | 0.0364156191 | 0.0329971976 | 0.0612012290 | -0.0043966920 | 单轨迹结果 |
| K-KF | 0.2596277957 | 0.2479573926 | 0.3495978198 | -0.2479573926 | 单轨迹结果 |
| F propagation | 0.7473833228 | 0.6479730394 | 1.2660624094 | -0.6479730394 | 单轨迹结果 |
| Static-prior fusion | 0.0594092518 | 0.0492584530 | 0.1103502946 | -0.0471055910 | 无在线 health 的对照 |
| V2.5 fixed fusion | 0.0455061371 | 0.0365132915 | 0.0885646091 | -0.0286387533 | 冻结固定权重对照 |
| Final LifeSig fusion | 0.0576049567 | 0.0472265248 | 0.1075957990 | -0.0450517407 | 最终方法；DESCRIPTIVE_ONLY |

### 5.4 权重行为

```text
mean alpha_D = 0.84480592205575633
mean alpha_K = 0.14681986799459618
mean alpha_F = 0.0083742099496471791

H_F:     1 -> 0.56761509547270994
alpha_F: 0.01094189322758545 -> 0.0062403073461377309
```

该变化真实存在但幅度较小，因此最终分类为 `WEAKLY_ADAPTIVE`。

---

## 6. 最终能够写进论文的结论

1. `VALIDATED_RESULT`：在当前 16 s genuine nominal steering 工况下，D-EKF 的 `Vy` 精度最好，RMSE 为 `0.03642 m/s`。
2. `VALIDATED_RESULT`：LifeSig 的 runtime 输出与冻结公式逐样本完全一致，`Vy/H/alpha` replay 最大误差为 0。
3. `VALIDATED_RESULT`：LifeSig 相比 static-prior fusion 有小幅描述性改善，但没有证明优于 D-EKF 或冻结 V2.5 fixed fusion。
4. `VALIDATED_RESULT`：最终 nominal 行为为 weakly adaptive；连续变化主要来自 F age gate，而 D/K availability 在整段运行中始终为 1。
5. `VALIDATED_RESULT`：F propagation age 与 F squared error risk 在五组非 holdout 工况中表现出稳定单调关系；Pearson 约 `0.9745–0.9747`，Spearman 约 `1`。
6. `VALIDATED_RESULT`：静态质量先验在五组 calibration LOO 中保持 `D>K>F` 排名不变。
7. `NOT_VALIDATED`：真实 availability drop、传感器 NaN/Inf、显式 dropout、finite bias、signal freeze 和 CarSim 故障条件下的鲁棒性尚未验证。
8. `NOT_VALIDATED`：fallback 在真实 CarSim 故障中没有被触发；现有证据只包括单元测试数学语义。
9. `NOT_VALIDATED`：下游侧偏角计算和车辆稳定性控制闭环尚未实现或验证。

---

## 7. 不得写进论文的结论

- 不得称 LifeSig 为统计最优协方差融合、BLUE 或已考虑 cross-covariance 的最优融合。
- 不得称 LifeSig 精度优于所有单轨迹；nominal 下 D-EKF 明显优于 LifeSig。
- 不得称 LifeSig 已证明优于 V2.5 fixed fusion。
- 不得称 NIS 能稳定预测 `Vy` 误差；D/K 证据均不足。
- 不得称 `abs(r)` 已构成正式在线可靠性权重或已识别正式 `r0`。
- 不得称 pairwise disagreement 能稳定判断哪条轨迹失真。
- 不得称 covariance 已进入最终主权重。
- 不得定义或引用一个已验证的 `P_AF`；`P_AF=NOT_DEFINED`。
- 不得称 fallback 已经过真实 CarSim 故障、availability drop 或传感器失效验证。
- 不得把 unit-test fallback 写成 runtime fault-tolerance 结果。
- 不得称当前 availability 等价于物理可信度；它主要是混合的数值更新/传播有效语义。
- 不得称当前 nominal 无 availability drop 证明了故障检测能力。
- 不得称 `P0_F/Q_F` 已完成最终 covariance 标定并在当前 F core 中落地。
- 不得称 holdout generalization 已通过；H01/H02/H03 没有形成 usable formal holdout data。
- 不得称真实 `Vy` 是任何在线 estimator/fusion 输入。
- 不得称下游稳定性控制接口和闭环性能已经验证。

---

## 8. 可作为研究过程说明但不进入最终算法的内容

### 8.1 Covariance-only weighting

`ABANDONED_ROUTE`：D/K/F covariance 虽具有相同物理量纲，但数值尺度不兼容。直接 inverse-covariance weighting 使 D 平均权重约 `0.9955`，构成明显的 scale-dominated saturation。常数尺度校准只能降低而不能消除跨 maneuver 失配；最后的 affine calibration 参数在 LOO 中不稳定，并退化到边界。因此停止更复杂 covariance mapping，covariance 不进入最终主权重。

论文讨论可写为：**相同量纲不等于可直接比较的 confidence scale；共享信息和未建模 cross-covariance 也使简单 inverse-covariance 不能被解释为严格统计最优融合。**

### 8.2 NIS 与观测性

`DIAGNOSTIC_ONLY`：D normalized NIS 与 D squared error 的相关关系较弱且跨工况变化；K NIS 仅有弱解释力；`abs(r)` 与 K squared error 不是稳定正相关。`p_NIS` 和 `r0` 均无法从现有证据无歧义识别。因此 NIS 和 `abs(r)` 保留为诊断信号，不进入最终 score。

论文讨论可写为：**innovation consistency 与 state-error risk 不是同一统计对象；K 的 yaw excitation 具有结构可观测性意义，但现有数据不支持将其连续映射为在线误差可靠度。**

### 8.3 Disagreement attribution

`DIAGNOSTIC_ONLY`：pairwise disagreement 能说明轨迹不一致，涉及 F 的 disagreement 也与 F error 高度相关；但 D-K attribution 随 maneuver 改变，无法稳定判断“哪条轨迹错”。因此 disagreement 仅保留为一致性诊断，不用于正式权重或切换。

论文讨论可写为：**多估计器不一致本身不能解决故障归因；缺乏独立冗余或可识别 fault model 时，不应把 disagreement 直接转换为单轨迹可靠度。**

---

## 9. 论文需要使用的文件清单

### A. 写论文必须看（10 个以内）

1. `docs/THESIS_VY_METHOD_WRITING_HANDOFF.md`：论文方法、参数、结果和 claim 边界总入口。
2. `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7_FINAL_ACCEPTANCE.md`：最终冻结结论、实现和 runtime 证据。
3. `model/vy_dynamic_ekf_v1_17.m`：D 状态初始化、车辆参数、Q/R、多速率 A20 实际配置。
4. `model/vy_dynamic_ekf_step_v13.m`：D 动力学、测量模型和 EKF 更新核心。
5. `model/vy_kinematic_kf.m`：K 参数和初始化。
6. `model/vy_kinematic_kf_step.m`：K 状态模型、Vx 更新和 Joseph covariance。
7. `model/vy_feedback_propagation_step.m`：F 状态/协方差传播和 reset 公式。
8. `model/vy_lifesig_fusion_step.m`：最终 LifeSig、fallback 和 reset 的权威实现。
9. `results/vy_reliability_lifesig_v2_7a3r1_static_prior_freeze.csv`：最终 `q_D/q_K/q_F` 及来源。
10. `results/vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv`：最终 16 s 指标、权重和 replay 结果。

### B. 需要追溯时再看

- `docs/STAGE_VY_DEKF_V1_17_STATUS.md`：D 的 A20 选择和多工况统计。
- `model/vy_dynamic_ekf_step_v17.m`：需要追溯 D 的 Ay/r 多速率更新实现时阅读。
- `docs/STAGE_VY_KKF_V2_1H_FINAL_ACCEPTANCE.md`：K 数学、genuine steering observability 和冻结边界。
- `docs/STAGE_VY_FEEDBACK_TRACK_V2_4E_FINAL_ACCEPTANCE.md`：F 独立传播、delay/reset 和 test-only covariance 边界。
- `docs/STAGE_VY_FIXED_FUSION_V2_5H1_WEIGHT_ACCEPTANCE_FREEZE.md`：V2.5 fixed baseline 的 QP 来源。
- `docs/STAGE_VY_FIXED_FUSION_V2_5H2_IMPLEMENTATION_FREEZE.md`：V2.5 runtime weight 表示。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R1_STATIC_QUALITY_PRIOR.md`：prior MSE 与 LOO。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R3_HEALTH_PARAMETER_IDENTIFICATION.md`：`tau_F` 识别、LOO 和 `p_NIS/r0` 未识别原因。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A2R9_STATUS.md`：NIS/观测性/F age adequacy。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A2R10_STATUS.md`：disagreement attribution 证据。
- `docs/STAGE_VY_COVARIANCE_ADAPTIVE_FUSION_V2_6A3R6_STATUS.md`：covariance-only 路线停止依据。
- `results/vy_reliability_lifesig_v2_7a3r10_nominal.mat`：需要重新制图或复核逐样本曲线时使用。
- 五组 `results/vy_reliability_calibration_*.mat`：仅在复核离线 identification/adequacy 时使用。

### C. 完全不需要为了写论文去看

除非进行软件复现或故障追责，下列文件不属于论文资料：

- `results/*compile*.mat`、`results/*build*.mat`；
- `results/*_gates*.csv`、纯工程 gate MAT；
- `results/*_slx_diff_audit.csv`；
- `*_evidence.csv` 中只记录 compile/build/hash/进程的部分；A3R10 性能 evidence 例外；
- `docs/*BUILDER*`、`docs/*RUNTIME_ENV*`、`docs/*MATLAB_ENV*`；
- `docs/*PREFDIR*`、`docs/*STARTUP*`、SET-2/quarantine 文档；
- CarSim D:/G: 路径修复、solver DLL lineage、license 弹窗和 process forensic；
- builder handle 生命周期、port-handle API、Demux width、steering workspace 修复；
- batch re-entry、launcher/bootstrap、phase marker、authorization commit/status；
- H01/H02/H03 卡死、termination、CPU-spin、post-exit closure 文档；
- `model/build_*.m`、`model/validate_*.m`、纯运行入口 `model/run_*.m`；
- hash-only manifest、process list、临时日志、临时 preference 目录；
- 纯工程 debug 文档，例如名称含 `R1/R2/P0/P1/W1/W2/W3/W4` 且内容只处理工具链或生命周期问题的文件；
- 历史失败结果、旧零转向误标工况和被后续正式结果替代的阶段文档。

---

## 10. 论文写作最小资料包

### 方法来源文件

- `model/vy_dynamic_ekf_v1_17.m`、`model/vy_dynamic_ekf_step_v13.m`、`model/vy_dynamic_ekf_step_v17.m`：撰写 D-EKF 状态、动力学、测量、Ay/r 多速率更新和参数。
- `model/vy_kinematic_kf.m`、`model/vy_kinematic_kf_step.m`：撰写 K-KF 状态方程、Vx 更新、Joseph covariance 和 reset。
- `model/vy_feedback_propagation_step.m`：撰写 F propagation/reset。
- `model/vy_lifesig_fusion_step.m`：撰写最终 health、score、alpha、`Vy_LS` 和 fallback。

### 最终参数文件

- `results/vy_reliability_lifesig_v2_7a3r1_static_prior_freeze.csv`：提供冻结 `q_D/q_K/q_F`。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R3_HEALTH_PARAMETER_IDENTIFICATION.md`：提供冻结 `tau_F`、识别目标和 LOO 稳定性。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R6_NUMERICAL_IMPLEMENTATION_CONTRACT.md`：提供 fallback/reset 和数值保护契约。

### 最终性能结果文件

- `results/vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv`：论文性能表和权重统计的直接来源。
- `results/vy_reliability_lifesig_v2_7a3r10_nominal.mat`：论文时序曲线、权重曲线和逐样本复核来源。

### 最终 freeze 文件

- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7_FINAL_ACCEPTANCE.md`：最终 accepted/bounded claims。
- `results/vy_reliability_lifesig_v2_7_final_freeze_evidence.csv`：机器可读冻结值、哈希和 claim 状态。
- `docs/STAGE_VY_RELIABILITY_LIFESIG_V2_8A0_AVAILABILITY_FAULT_SEMANTICS_AUDIT.md`：论文局限性中 availability/fault 语义的权威边界。

### 参考论文

- `references/精度1applsci-15-01365-v2.pdf`：Combined Dynamic–Kinematic EKF 的直接相关文献，用于 D/K 互补思想、低横摆可观测性背景和 sideslip/Vy 估计综述；不得把其 DK-EKF 结构等同于本项目最终 LifeSig。
- `references/横纵向协同稳定性控制_许娟.pdf`：用于说明 `Vy/侧偏角` 在车辆稳定性控制中的下游作用。
- `references/冰雪路面条件下四轮轮毂驱动电动汽车横纵向稳定协同控制_李梓涵.pdf`：用于四轮独立驱动车辆稳定性控制背景和状态接口。
- `references/冰雪路面条件下基于数据-机理混合模型的车辆稳定性控制_杨博雄.pdf`：用于数据—机理融合与稳定性控制背景讨论。
- `references/稳定边界辨识张曦月.pdf`：仅在论文包含稳定边界/稳定域章节时使用。
- 两篇 WSS/IMU 纵向车速论文仅在整篇论文同时包含 `Vx` 估计章节时使用；对本 `Vy` 多轨迹方法章节不是必读资料。

---

## 最终最小集合

```text
THESIS_MUST_READ_FILES = [
  docs/THESIS_VY_METHOD_WRITING_HANDOFF.md,
  docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7_FINAL_ACCEPTANCE.md,
  model/vy_dynamic_ekf_v1_17.m,
  model/vy_dynamic_ekf_step_v13.m,
  model/vy_kinematic_kf.m,
  model/vy_kinematic_kf_step.m,
  model/vy_feedback_propagation_step.m,
  model/vy_lifesig_fusion_step.m,
  results/vy_reliability_lifesig_v2_7a3r1_static_prior_freeze.csv,
  results/vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv
]

THESIS_OPTIONAL_FILES = [
  docs/STAGE_VY_DEKF_V1_17_STATUS.md,
  model/vy_dynamic_ekf_step_v17.m,
  docs/STAGE_VY_KKF_V2_1H_FINAL_ACCEPTANCE.md,
  docs/STAGE_VY_FEEDBACK_TRACK_V2_4E_FINAL_ACCEPTANCE.md,
  docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R1_STATIC_QUALITY_PRIOR.md,
  docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R3_HEALTH_PARAMETER_IDENTIFICATION.md,
  docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A2R9_STATUS.md,
  docs/STAGE_VY_RELIABILITY_LIFESIG_V2_7A2R10_STATUS.md,
  docs/STAGE_VY_COVARIANCE_ADAPTIVE_FUSION_V2_6A3R6_STATUS.md,
  results/vy_reliability_lifesig_v2_7a3r10_nominal.mat,
  references/精度1applsci-15-01365-v2.pdf
]

THESIS_IGNORE_FILE_PATTERNS = [
  results/*compile*.mat,
  results/*build*.mat,
  results/*_gates*.csv,
  results/*_slx_diff_audit.csv,
  docs/*BUILDER*,
  docs/*PREFDIR*,
  docs/*STARTUP*,
  docs/*MATLAB_ENV*,
  docs/*RUNTIME_ENV*,
  model/build_*.m,
  model/validate_*.m,
  model/run_*.m,
  *phase_markers*,
  *authorization_committed*,
  *launcher*,
  *bootstrap*,
  *process_forensic*,
  *hash_only*
]
```
