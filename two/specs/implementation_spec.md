# 4WID/4WIS 车辆纵向速度估计器实施规格

## 0. 文档目的

本文件用于指导 Codex 在现有 `MPC_Demo_wuguzhang.slx` 工程中，仅通过新增或修改 `.m` 文件，实现阶段 1 的纵向速度估计器。

阶段 1 的目标是先完成、验证以下双通道方案：

```text
通道 1：四轮独立滑移可信度 WSS 车速轨迹
通道 2：上一拍融合估计 + IMU 纵向加速度递推轨迹
                 ↓
两个局部标量 Kalman 滤波器
                 ↓
考虑局部估计互协方差的最小方差融合
                 ↓
               vx_hat
```

本阶段明确不使用 GPS/GNSS。若后续发现长时间四轮同时滑移时纯 IMU 递推不能满足要求，再单独增加原论文中的 GPS-BD 虚拟传感器。

现有 `MPC_Demo3_wuguzhang.m` 只用于提取估计器所需的车辆几何参数、轮胎有效半径和控制器纵向速度入口，不得把 MPC 的 QP、轮胎力模型、约束、权重或日志结构搬入估计器。

---

## 1. 文献依据与本文适配

### 1.1 基础融合方法

基础文献：

`Longitudinal Vehicle Speed Estimation for Four-Wheel-Independently-Actuated Electric Vehicles Based on Multi-Sensor Fusion`

阶段 1 保留其以下方法：

1. 每个虚拟传感器生成一条纵向速度轨迹；
2. 每条轨迹分别经过局部 Kalman 滤波；
3. 按文献式 (26) 递推局部滤波器之间的互协方差；
4. 按文献式 (28) 计算最小方差融合权重；
5. 按文献式 (29) 计算融合估计协方差；
6. 按 Life Signal 判断通道是否参与融合。

原文虚拟传感器编号与本阶段编号的映射为：

```text
本阶段通道 1 = 原文 Virtual Sensor-2（轮速/电机转速）
本阶段通道 2 = 原文 Virtual Sensor-3（上一拍融合估计 + IMU 加速度）
原文 Virtual Sensor-1（GPS-BD + IMU）在阶段 1 关闭
```

### 1.2 四轮滑移处理方法

参考文献：

`Vehicle velocity estimation based on WSS/IMU with wheel slip recognition`

保留的思想为：

1. 四个车轮分别判断，不设置固定参考轮；
2. 无滑移时，轮速速度增量与 IMU 速度增量应保持一致；
3. 滑移车轮降低权重，严重滑移时隔离；
4. 四轮均失效时，WSS 通道退出融合，由 IMU 通道短时维持速度。

由于当前仿真平台能够提供车身坐标系下、已经去除重力分量的车辆加速度 `Ax/Ay/Az`，阶段 1 不直接复现原文的“重力模长判据”，而固定采用：

```text
有限时间窗三维速度增量一致性判据
```

不得由 Codex 改回简单的瞬时轮加速度差，也不得改成需要当前真实 `vx` 的传统滑移率判据。

### 1.3 实现优先级

发生冲突时，按以下顺序执行：

```text
本 implementation_spec.md
> signal_interface.md
> 用户确认的信号定义和正方向
> 现有 Simulink 实际接口
> 基础融合文献
> WSS/IMU 滑移识别文献
```

Codex 不得自行选择其他滤波器、其他滑移识别方法或其他融合结构。

---

## 2. 固定车辆参数

只录入当前估计器需要的参数：

```matlab
vehicle.a           = 1.18;   % m，质心到前轴
vehicle.b           = 1.77;   % m，质心到后轴
vehicle.track       = 1.575;  % m，统一轮距
vehicle.wheelRadius = 0.393;  % m，有效滚动半径
vehicle.gravity     = 9.8;    % m/s^2，仅用于诊断/原始比力校验
```

车轮位置固定为：

| 车轮 | `x_i` | `y_i` |
|---|---:|---:|
| FL | `+a` | `+track/2` |
| FR | `+a` | `-track/2` |
| RL | `-b` | `+track/2` |
| RR | `-b` | `-track/2` |

当前阶段不使用：

```text
车辆质量、横摆惯量、车轮惯量、质心高度、悬架参数、
轮胎侧偏刚度、路面附着系数、四轮扭矩、MPC 权重和约束。
```

---

## 3. 固定坐标系、轮序与符号

### 3.1 车身坐标系

```text
+X：车辆前进方向
+Y：车辆左侧
+Z：车辆上方
p、q、r：分别绕 +X、+Y、+Z 轴，遵循右手定则
r > 0：车辆左转
车轮转角 delta > 0：车轮向左转
车辆前进时四轮角速度均为正
```

### 3.2 固定轮序

所有四轮数组统一为：

```text
[FL, FR, RL, RR]
```

不得在任何函数中使用其他排列。

---

## 4. 固定采样频率与调用方式

```matlab
Ts_sim   = 0.001;  % s，CarSim/车辆模型真值 1000 Hz
Ts_est   = 0.01;   % s，估计器固定 100 Hz
Ts_ctrl  = 0.02;   % s，现有 MPC 周期
Twindow  = 0.5;    % s，滑移识别窗口
Nwindow  = 50;     % Twindow / Ts_est
```

估计器通过 `Interpreted MATLAB Function` 调用，顶层接口固定为：

```matlab
function y = longitudinal_velocity_estimator(u)
```

若顶层函数每 `0.001 s` 被调用：

1. 每 10 个仿真步执行一次估计更新；
2. 其余仿真步保持上一次输出；
3. 更新间隔必须由 `Ts_est/Ts_sim` 计算，不得把数字 10 写死；
4. MPC 每 `0.02 s` 读取最近一次 `vx_hat`。

---

## 5. 传感器数据定义

### 5.1 处理后车辆加速度

```matlab
accelBody = [Ax; Ay; Az]; % m/s^2
```

`Ax/Ay/Az` 已确认是车身坐标系下的处理后车辆加速度，不含重力分量。

纵向分量满足：

```math
A_x = \dot v_x-rv_y
```

因此：

```math
\dot v_x=A_x+r v_y
```

阶段 1 固定：

```matlab
vy_prior = 0;
axEffective = Ax + r*vy_prior; % 阶段1等于 Ax
```

不得使用 CarSim 当前真实 `Vy` 代替 `vy_prior`。后续侧向速度估计器完成后，才允许改为上一拍 `vy_hat`。

### 5.2 原始 IMU 比力

CarSim 还提供：

```matlab
specificForce = [Ax_SM; Ay_SM; Az_SM];
```

这些信号包含重力影响，可直接作为“原始比力输入”，但不能不经姿态变换和重力补偿就直接积分为速度。

阶段 1 的主滑移指标和主速度递推固定使用已经去除重力的 `Ax/Ay/Az`。`Ax_SM/Ay_SM/Az_SM` 只用于：

1. 记录和对比；
2. 检查处理后加速度是否一致；
3. 为后续严格复现原文重力模长判据预留接口。

Codex 不得在阶段 1 中把 `Ax_SM/Ay_SM/Az_SM` 与 `Ax/Ay/Az` 混合进入同一积分公式。

### 5.3 三轴角速度

```matlab
gyroBody = [AVx; AVy; AVz]; % [p q r], rad/s
```

---

## 6. 四轮几何修正与候选纵向速度

对第 `i` 个车轮：

```math
v_{c,i}=
\begin{bmatrix}
v_x-r y_i\\
v_y+r x_i
\end{bmatrix}
```

车轮滚动方向速度为：

```math
v_{t,i}=(v_x-r y_i)\cos\delta_i+(v_y+r x_i)\sin\delta_i
```

WSS 测得：

```math
v_{t,i}^{WSS}=R_w\omega_i
```

由此反解第 `i` 个车轮给出的质心纵向速度候选值：

```math
v_{x,i}^{WSS}=r y_i+
\frac{R_w\omega_i-(v_y^{prior}+r x_i)\sin\delta_i}
{\cos\delta_i}
```

阶段 1 固定 `v_y^{prior}=0`。

数值保护：

```matlab
cosDeltaMin = 0.20;
```

若 `abs(cos(delta_i)) < cosDeltaMin`，该轮本拍直接标记为无效，不允许除以接近零的 `cos(delta_i)`。

---

## 7. 有限时间窗速度增量一致性判据

### 7.1 固定积分方法

不得更改以下实现：

```text
姿态更新：Rodrigues 公式/旋转矩阵指数映射
角速度取值：相邻两拍中值
速度积分：梯形积分
窗口管理：FIFO 滑动窗口
窗口长度：0.5 s，共 50 个估计器采样间隔
```

### 7.2 相对姿态更新

窗口起点记为 `k-Nwindow`，定义：

```math
C_0=I_3
```

对窗口内每个间隔 `j`：

```math
\bar\omega_j=\frac{\omega_{j-1}+\omega_j}{2}
```

```math
\Delta\phi_j=\bar\omega_j T_s
```

```math
C_j=C_{j-1}\operatorname{Exp}([\Delta\phi_j]_\times)
```

`Exp` 必须采用 Rodrigues 公式；当 `||DeltaPhi|| < 1e-8` 时采用二阶小角度展开，禁止直接除以零。

`C_j` 的定义固定为：将第 `j` 拍车身坐标系中的向量转换到窗口起点车身坐标系。

### 7.3 IMU 速度增量

处理后加速度在窗口起点坐标系中的表示：

```math
a_j^0=C_j a_j^b
```

IMU 三维速度增量：

```math
\Delta v_{IMU}^0=
\sum_{j=1}^{Nwindow}
\frac{a_{j-1}^0+a_j^0}{2}T_s
```

### 7.4 每轮 WSS 速度增量

阶段 1 构造：

```math
v_{i,k}^{b}=
\begin{bmatrix}
v_{x,i,k}^{WSS}\\
v_{y,k}^{prior}\\
0
\end{bmatrix}
```

窗口内第 `i` 个车轮的速度增量：

```math
\Delta v_{WSS,i}^{0}
=C_Nv_{i,k}^{b}-v_{i,k-Nwindow}^{b}
```

### 7.5 四轮滑移指标

```math
e_i=\left\|\Delta v_{WSS,i}^{0}-\Delta v_{IMU}^{0}\right\|_2
```

分别输出：

```text
[e_FL, e_FR, e_RL, e_RR]
```

窗口尚未填满时：

```text
slipReady = false
四轮 confidence 暂设为 1
不进行硬隔离
```

不得把当前 `vx_true`、当前真实滑移率或当前真实 `Vy` 放入滑移指标。

---

## 8. 连续可信度与硬隔离

### 8.1 固定映射

```math
\rho_i=
\begin{cases}
1,&e_i\le e_{low}\\
\dfrac{e_{high}-e_i}{e_{high}-e_{low}},&e_{low}<e_i<e_{high}\\
0,&e_i\ge e_{high}
\end{cases}
```

固定：

```matlab
rhoHard = 0.05;
epsilon = 1e-8;
```

硬有效标志：

```matlab
wheelValid(i) = signalFinite(i) && ...
                abs(cos(delta(i))) >= cosDeltaMin && ...
                confidence(i) > rhoHard;
```

### 8.2 阶段 1 临时阈值

只为代码跑通，暂用：

```matlab
eLow_tmp  = 0.15; % m/s，非最终论文参数
eHigh_tmp = 0.50; % m/s，非最终论文参数
```

阶段 2 必须由无滑移数据重新标定：

```math
s_e=1.4826\operatorname{MAD}(e_{normal})
```

```math
e_{low}=\operatorname{median}(e_{normal})+3s_e
```

```math
e_{high}=\operatorname{median}(e_{normal})+8s_e
```

并强制：

```matlab
eHigh = max(eHigh, eLow + 1e-3);
```

Codex 只执行上述规则，不得凭仿真曲线自行调阈值。

---

## 9. 四轮测量协方差与 WSS 轨迹

### 9.1 每轮协方差

```math
R_{i,k}=\operatorname{clip}
\left(
\frac{R_{i,0}}{\rho_{i,k}+\varepsilon},
R_{min},R_{max}
\right)
```

阶段 1 临时数值：

```matlab
Rwheel0_tmp = 1e-4; % (m/s)^2，仅数值运行
RwheelMin   = 1e-6;
RwheelMax   = 1e4;
```

阶段 2 后，`Rwheel0` 必须由每轮无滑移速度残差方差获得。

### 9.2 WSS 通道内部融合

有效轮集合：

```math
\mathcal V_k=\{i\mid wheelValid_i=1\}
```

若集合非空：

```math
\gamma_i=\frac{R_i^{-1}}{\sum_{j\in\mathcal V_k}R_j^{-1}}
```

```math
z_{WSS,k}=\sum_{i\in\mathcal V_k}\gamma_i v_{x,i,k}^{WSS}
```

```math
R_{WSS,k}=\left(\sum_{i\in\mathcal V_k}R_i^{-1}\right)^{-1}
```

若四轮均无效：

```text
LifeSig_WSS = 0
z_WSS 保持上一次数值，仅用于日志
R_WSS = RwheelMax
不得把四个接近零的可信度重新归一化
```

---

## 10. IMU 递推轨迹

定义：

```math
\dot v_x=A_x+r v_y^{prior}
```

阶段 1：

```math
v_y^{prior}=0
```

采用相邻两拍梯形积分：

```math
z_{IMU,k}=\hat v_{x,k-1}^{fused}
+\frac{a_{x,eff,k-1}+a_{x,eff,k}}{2}T_s
```

其测量方差固定采用维数一致的离散形式：

```math
R_{IMU,k}=P_{fused,k-1}
+\frac{T_s^2}{2}R_{Ax}
```

其中 `R_Ax` 为纵向加速度噪声方差。

通道有效条件：

```matlab
LifeSig_IMU = all(isfinite([Ax, AVz])) && abs(Ax) < accelSanityMax;
accelSanityMax = 50; % m/s^2，仅异常值保护
```

---

## 11. 两个局部标量 Kalman 滤波器

为了避免轨迹内部已经包含加速度时重复使用同一加速度作为状态控制输入，阶段 1 的两个局部滤波器固定使用标量随机游走模型：

```math
x_k=x_{k-1}+w_{k-1}
```

固定：

```math
A=1,\quad H_1=H_2=1,\quad \Gamma=1
```

对每个有效通道 `i`：

```math
\hat x_{i,k}^{-}=\hat x_{i,k-1}^{+}
```

```math
P_{i,k}^{-}=P_{i,k-1}^{+}+Q_v
```

```math
K_{i,k}=\frac{P_{i,k}^{-}}{P_{i,k}^{-}+R_{i,k}}
```

```math
\hat x_{i,k}^{+}=\hat x_{i,k}^{-}
+K_{i,k}(z_{i,k}-\hat x_{i,k}^{-})
```

```math
P_{i,k}^{+}=(1-K_{i,k})P_{i,k}^{-}
```

若某通道本拍无效：

```text
不执行该通道测量更新；
保持时间更新结果；
该通道不参与本拍融合。
```

临时过程噪声：

```matlab
Qv_tmp = 1e-4; % (m/s)^2，每拍；阶段2后再标定
```

---

## 12. 互协方差递推与最小方差融合

### 12.1 互协方差

初始化：

```matlab
P12_0 = 0;
```

两通道均有效时，严格采用基础文献式 (26) 的标量形式：

```math
P_{12,k}^{-}=P_{12,k-1}^{+}+Q_v
```

```math
P_{12,k}^{+}
=(1-K_{1,k})P_{12,k}^{-}(1-K_{2,k})
```

并令：

```math
P_{21,k}=P_{12,k}
```

若仅一个通道有效，本拍不计算双通道权重，直接使用有效通道。

### 12.2 双通道融合权重

```math
\Phi_k=
\begin{bmatrix}
P_{1,k} & P_{12,k}\\
P_{12,k} & P_{2,k}
\end{bmatrix}
```

数值正则化：

```matlab
Phi = (Phi + Phi.')/2 + 1e-10*eye(2);
```

```math
\alpha_k=
\frac{\Phi_k^{-1}\mathbf 1}
{\mathbf 1^T\Phi_k^{-1}\mathbf 1}
```

```math
\hat v_{x,k}=\alpha_{1,k}\hat x_{1,k}
+\alpha_{2,k}\hat x_{2,k}
```

```math
P_{fused,k}=\alpha_k^T\Phi_k\alpha_k
```

实现要求：

1. 优先使用线性方程求解，不显式调用 `inv`；
2. 若 `rcond(Phi) < 1e-12`，使用 `pinv(Phi)`；
3. 不得把负权重强制截断为零，因为原相关融合方法可能产生负权重；
4. 必须记录权重和条件数用于诊断。

### 12.3 单通道模式

```text
WSS 有效、IMU 无效：vx_hat = x_WSS，权重 [1,0]
WSS 无效、IMU 有效：vx_hat = x_IMU，权重 [0,1]
两者均无效：保持上一拍 vx_hat，立即 degradedMode=true
```

---

## 13. 初始化、复位与低速处理

### 13.1 初始速度

不得固定为零。首次有效输入时：

```matlab
wheelLinearSpeed = vehicle.wheelRadius .* wheelOmega;
vx0 = median(wheelLinearSpeed(isfinite(wheelLinearSpeed)));
```

注意：`median` 的对象必须是线速度 `Rw*omega`，不能直接对 `rad/s` 角速度取中位数后当作 `m/s`。

### 13.2 初始协方差

```matlab
P0Floor = 1e-4;
P0 = max(var(wheelLinearSpeed, 1), P0Floor);
```

初始化：

```matlab
xWss  = vx0;
xImu  = vx0;
vxHat = vx0;
Pwss  = P0;
Pimu  = P0;
Pfused = P0;
P12   = 0;
```

### 13.3 复位

`reset ~= 0` 时清空所有 persistent 状态、FIFO 窗口、计数器和失效计时器，并在下一次有效样本重新初始化。

### 13.4 低速保护

固定：

```matlab
vLow = 0.30; % m/s
```

低速下仍运行估计器，但：

1. 不计算传统滑移率；
2. 保留有限窗增量一致性指标；
3. 若四轮线速度绝对值均小于 `vLow` 且 `abs(Ax)<0.1`，允许输出缓慢收敛到零，但不得突然清零。

---

## 14. 四轮全失效与降级模式

固定：

```matlab
TimuOnlyMax = 1.0; % s
```

当四轮均无效但 IMU 通道有效：

```text
持续时间 <= 1.0 s：继续用 IMU 通道输出，degradedMode=false
持续时间 > 1.0 s：继续用 IMU 通道输出，degradedMode=true
```

无论是否进入降级模式：

1. 不得把车速突然置零；
2. `P_imu` 和 `P_fused` 必须继续随过程噪声增长；
3. 输出 `imuOnlyDuration`；
4. 上层控制器可依据 `degradedMode` 决定是否收紧约束，但本阶段估计器不直接修改 MPC。

---

## 15. 信号方差与噪声处理流程

### 15.1 阶段 1：代码跑通

```text
CarSim 输出不加噪声；
使用本文件给定的数值下限和临时协方差；
只验证接口、维数、状态复位、通道切换和数值稳定性。
```

### 15.2 阶段 2：无滑移数据标定

该阶段的思路可用，但必须计算“残差方差”，不能对随工况变化的原始信号直接求样本方差。

#### 每轮速度残差

在无滑移数据中：

```math
r_{w,i}=v_{x,i}^{WSS}-v_x^{true}
```

```math
R_{i,0}=\max(\operatorname{var}(r_{w,i}),R_{wheelFloor})
```

#### 纵向加速度残差

用真值构造独立参考：

```math
a_{x,ref}=\dot v_x^{true}-r v_y^{true}
```

`dot(vx_true)` 固定采用 5 点中心差分：

```math
\dot v_x[k]=
\frac{v_x[k-2]-8v_x[k-1]+8v_x[k+1]-v_x[k+2]}
{12T_{sim}}
```

首尾各 2 个样本丢弃。

```math
r_{Ax}=A_x-a_{x,ref}
```

```math
R_{Ax}=\max(\operatorname{var}(r_{Ax}),R_{AxFloor})
```

固定数值下限：

```matlab
RwheelFloor = 1e-6; % (m/s)^2
RAxFloor    = 1e-6; % (m/s^2)^2
```

说明：若 CarSim 信号本身完全无噪声，阶段 2 得到的是数值离散误差和接口处理误差的“等效方差”，不能宣称为真实传感器噪声。

### 15.3 阶段 3：正式含噪声仿真

采用阶段 2 得到的标准差：

```matlab
sigmaWheel_i = sqrt(Rwheel0_i) / vehicle.wheelRadius; % 转回 rad/s
sigmaAx      = sqrt(RAx);
```

分别向各传感器输入加入独立高斯白噪声：

```matlab
omegaMeas_i = omegaTrue_i + sigmaWheel_i*randn;
AxMeas      = AxTrue      + sigmaAx*randn;
```

要求：

1. 使用固定随机种子，保证回归测试可重复；
2. 四轮噪声默认相互独立；
3. 不得用同一随机序列同时污染 WSS 和 IMU；
4. 同一套 `Rwheel0`、`RAx` 同时用于噪声注入和滤波器协方差；
5. 这套流程适合仿真算法对比，但不等同于真实传感器标定。

---

## 16. 必须生成的 `.m` 文件

Codex 至少生成：

```text
velocity_estimator_default_params.m
longitudinal_velocity_estimator.m
wheel_speed_candidates_4wis.m
relative_rotation_rodrigues.m
window_delta_velocity_indicator.m
slip_confidence_mapping.m
wss_track_builder.m
local_scalar_kf_step.m
correlated_two_track_fusion.m
reset_velocity_estimator_state.m（若顶层函数内部复位不足）
calibrate_velocity_estimator_variances.m
inject_velocity_sensor_noise.m
run_velocity_estimator_simulation.m
plot_velocity_estimator_results.m
evaluate_velocity_estimator_results.m
```

阶段 1 不得修改 `.slx`。若发现当前 Simulink 没有接入某个已确认信号，只报告需要接线的位置，不擅自重构模型。

---

## 17. 顶层输出要求

至少输出：

```text
vx_hat
P_fused
vx_wss_local
P_wss_local
vx_imu_local
P_imu_local
P12
四轮候选车速
四轮滑移指标
四轮可信度
四轮自适应协方差
四轮有效标志
WSS/IMU Life Signal
融合权重
allWheelInvalid
imuOnlyDuration
degradedMode
estimatorUpdated
slipReady
```

---

## 18. 验证工况

必须依次验证：

1. 静止与低速起步；
2. 无滑移直线匀速；
3. 正常加速和制动；
4. 正常 4WIS 转向；
5. 单轮驱动滑移；
6. 单轮制动抱死；
7. 同轴双轮滑移；
8. 对开路面；
9. 四轮同时滑移不超过 1 s；
10. 四轮同时滑移超过 1 s；
11. 处理后加速度异常/NaN；
12. 含噪声回归测试。

评价指标：

```math
RMSE(v_x),\quad MAE(v_x),\quad \max|e_{v_x}|
```

若提供四轮真实滑移状态，还应计算：

```text
识别准确率、误判率、漏判率、首次识别延迟、恢复时间。
```

---

## 19. 禁止事项

Codex 不得：

1. 使用 `vx_true` 或 `Vy_true` 参与在线估计；
2. 将真实滑移率作为滑移识别输入；
3. 用当前融合结果反过来构造同一拍 WSS 测量，形成代数环；
4. 把四轮轮速简单平均而忽略独立可信度；
5. 四轮全部无效时仍强制归一化轮速权重；
6. 将 `Ax_SM/Ay_SM/Az_SM` 不经补偿直接积分；
7. 自行换成 EKF、UKF、粒子滤波、模糊融合或简单逆方差独立融合；
8. 自行修改 `Ts_est`、`Twindow`、积分方法和轮序；
9. 为获得更好曲线自行调阈值；
10. 修改 MPC 内部算法。
