# `MPC_Demo_wuguzhang.slx` 纵向速度估计器信号接口

## 0. 文件用途

本文件只规定阶段 1 纵向速度估计器需要的物理信号、CarSim 变量名、正方向、固定轮序、采样频率和函数输入输出布局。

不描述 MPC 内部预测模型、约束、代价函数或日志向量。

---

## 1. 坐标系与正方向

所有输入在进入估计器前必须已经转换为下表的统一约定：

| 物理信号 | CarSim 变量 | 正方向 |
|:---|:---|:---|
| 纵向加速度 | `Ax` | 前进为正 |
| 横向加速度 | `Ay` | 左转/向左为正 |
| 垂向加速度 | `Az` | 向上为正 |
| 侧倾角速度 | `AVx` | 绕 +X 轴右手定则，车身右倾为正 |
| 俯仰角速度 | `AVy` | 绕 +Y 轴右手定则，车头上扬为正 |
| 横摆角速度 | `AVz` | 左转为正，绕 +Z 轴右手定则 |
| 左前轮转角 | `Steer_L1` | 左转为正 |
| 右前轮转角 | `Steer_R1` | 左转为正 |
| 左后轮转角 | `Steer_L2` | 左转为正 |
| 右后轮转角 | `Steer_R2` | 左转为正 |
| 左前轮角速度 | `AVy_L1` | 车辆前进时为正 |
| 右前轮角速度 | `AVy_R1` | 车辆前进时为正 |
| 左后轮角速度 | `AVy_L2` | 车辆前进时为正 |
| 右后轮角速度 | `AVy_R2` | 车辆前进时为正 |

原始 IMU 比力接口：

| 物理信号 | CarSim 变量 | 说明 |
|:---|:---|:---|
| X 向原始比力 | `Ax_SM` | 包含重力影响，仅记录/诊断，阶段1主算法不直接积分 |
| Y 向原始比力 | `Ay_SM` | 包含重力影响，仅记录/诊断，阶段1主算法不直接积分 |
| Z 向原始比力 | `Az_SM` | 包含重力影响，仅记录/诊断，阶段1主算法不直接积分 |

说明：

```text
Ax/Ay/Az：处理后车辆加速度，不含重力分量。
Ax_SM/Ay_SM/Az_SM：原始比力，包含重力影响。
两组信号不得混用。
```

---

## 2. 固定轮序

所有四轮数组统一为：

```text
[FL, FR, RL, RR]
```

统一变量：

```matlab
wheelOmega = [AVy_L1;
              AVy_R1;
              AVy_L2;
              AVy_R2]; % rad/s

wheelAngle = [Steer_L1;
              Steer_R1;
              Steer_L2;
              Steer_R2]; % rad
```

用户已确认：所有以 `1,2,3,4` 表示四个车轮的内部变量也按 `[FL,FR,RL,RR]` 解释。

旧模型中的：

```text
[WEEL1, WEEL3, WEEL2, WEEL4]
```

若继续使用，其物理映射同样固定为：

```text
[FL, FR, RL, RR]
```

但新估计器优先使用语义明确的 `Steer_L1/Steer_R1/Steer_L2/Steer_R2`。

---

## 3. 信号采样频率

| 信号组 | 原始更新频率 | 估计器处理方式 |
|---|---:|---|
| CarSim 车辆模型真值 | 1000 Hz | 只用于评价，不进入在线估计 |
| `Ax/Ay/Az` | 100 Hz | 与估计器同频直接使用 |
| `AVx/AVy/AVz` | 100 Hz | 与估计器同频直接使用 |
| 四轮角速度 | 100 Hz | 与估计器同频直接使用 |
| 四轮转角 | 100 Hz | 与估计器同频直接使用 |
| `Ax_SM/Ay_SM/Az_SM` | 100 Hz | 只记录/诊断 |

固定：

```matlab
Ts_sim  = 0.001; % s
Ts_est  = 0.01;  % s，100 Hz
Ts_ctrl = 0.02;  % s
```

阶段 1 不进行额外插值。若估计器函数被 1000 Hz 调用，则每 10 个调用更新一次，其余调用保持上次结果。

---

## 4. 在线估计器必需输入

| 统一变量 | CarSim/模型信号 | 维数 | 在线用途 |
|---|---|---:|---|
| `wheelOmega` | `AVy_L1/AVy_R1/AVy_L2/AVy_R2` | 4×1 | 四轮候选速度、滑移识别 |
| `wheelAngle` | `Steer_L1/Steer_R1/Steer_L2/Steer_R2` | 4×1 | 4WIS 几何修正 |
| `accelBody` | `Ax/Ay/Az` | 3×1 | 有限窗速度增量、IMU 递推轨迹 |
| `gyroBody` | `AVx/AVy/AVz` | 3×1 | Rodrigues 相对姿态更新、轮心横摆修正 |
| `specificForce` | `Ax_SM/Ay_SM/Az_SM` | 3×1 | 记录和一致性诊断，不参与阶段1主融合 |
| `reset` | 新增逻辑信号 | 1 | 清空所有 persistent 状态 |

阶段 1 内部固定：

```matlab
vy_prior = 0;
vz_prior = 0;
```

因此 `vy_prior` 不作为外部输入，也不得接入 CarSim 当前真实 `Vy`。

绝对滚转角、俯仰角和航向角不是阶段 1 主算法必需输入。`Pitch` 可记录供后续原始比力重力补偿版使用，但不进入当前双通道融合。

---

## 5. 仅用于评价/标定的真值

| 统一变量 | 模型信号 | 用途 |
|---|---|---|
| `vx_true` | `Vx` | 车速误差评价、阶段2残差方差标定 |
| `vy_true` | `Vy` | 阶段2构造 `Ax` 独立参考，不进入在线估计 |
| `ax_true_ref` | 由 `vx_true`、`vy_true`、`AVz` 计算 | 阶段2加速度残差标定 |
| `slipTrue(1:4)` | CarSim 四轮真实滑移率/滑移状态 | 只用于识别指标评价，可选 |

严格约束：

```text
vx_true、vy_true、slipTrue 不得放入 longitudinal_velocity_estimator 的在线输入向量。
```

---

## 6. 必需车辆参数

```matlab
vehicle.a           = 1.18;
vehicle.b           = 1.77;
vehicle.track       = 1.575;
vehicle.wheelRadius = 0.393;
vehicle.gravity     = 9.8;
```

不需要车辆质量、惯量、轮胎模型参数或 MPC 参数。

---

## 7. 顶层函数输入向量

固定输入长度为 18：

```matlab
est_u = zeros(18,1);

est_u(1:4)   = wheelOmega;                % FL FR RL RR, rad/s
est_u(5:8)   = wheelAngle;                % FL FR RL RR, rad
est_u(9:11)  = [Ax; Ay; Az];              % 处理后车辆加速度, m/s^2
est_u(12:14) = [AVx; AVy; AVz];           % p q r, rad/s
est_u(15:17) = [Ax_SM; Ay_SM; Az_SM];     % 原始比力，仅诊断
est_u(18)    = reset;                     % logical/double 0或1
```

禁止把以下信号加入在线输入：

```text
Vx、Vy、真实滑移率、路面附着系数、四轮驱动扭矩、MPC预测量。
```

---

## 8. 顶层函数输出向量

固定输出长度为 38：

```matlab
est_y = zeros(38,1);

est_y(1)      = vx_hat;
est_y(2)      = P_fused;
est_y(3)      = vx_wss_local;
est_y(4)      = P_wss_local;
est_y(5)      = vx_imu_local;
est_y(6)      = P_imu_local;
est_y(7)      = P12;

est_y(8:11)   = wheelSpeedCandidate;  % FL FR RL RR, m/s
est_y(12:15)  = slipIndicator;        % FL FR RL RR
est_y(16:19)  = confidence;           % FL FR RL RR
est_y(20:23)  = Rwheel;               % FL FR RL RR
est_y(24:27)  = double(wheelValid);   % FL FR RL RR

est_y(28)     = double(lifeWss);
est_y(29)     = double(lifeImu);
est_y(30:31)  = fusionWeights;        % [WSS IMU]
est_y(32)     = double(allWheelInvalid);
est_y(33)     = imuOnlyDuration;
est_y(34)     = double(degradedMode);
est_y(35)     = double(estimatorUpdated);
est_y(36)     = double(slipReady);
est_y(37)     = condPhi;
est_y(38)     = updateCounter;
```

输出单位：

```text
速度：m/s
速度方差： (m/s)^2
滑移指标：m/s
轮速协方差： (m/s)^2
imuOnlyDuration：s
```

---

## 9. 与现有 MPC 的接口

现有 MPC 读取：

```matlab
vx = u(33);
```

分两阶段接入：

### 阶段 A：估计器独立验证

```text
MPC u(33) <- vx_true
vx_hat 只记录、画图和计算误差
```

### 阶段 B：估计—控制闭环验证

```text
MPC u(33) <- vx_hat
vx_true 只用于评价
```

估计器不得直接修改 MPC 代码。

---

## 10. 噪声接口与随机种子

阶段 1：

```text
不加噪声，直接使用 CarSim 输出。
```

阶段 2：

```text
由无滑移残差数据计算 Rwheel0 和 RAx。
```

阶段 3：

```matlab
noise.enable = true;
noise.seed   = 20260805;
```

向四轮角速度与处理后 `Ax` 分别注入独立高斯白噪声。噪声注入必须放在估计器输入端之前，不能污染 `vx_true/vy_true`。

---

## 11. 数据日志要求

运行脚本至少记录：

```text
time
vx_true
vx_hat
vx_wss_local
vx_imu_local
P_fused、P_wss_local、P_imu_local、P12
四轮角速度、四轮转角
Ax/Ay/Az、AVx/AVy/AVz
Ax_SM/Ay_SM/Az_SM
四轮候选速度
四轮滑移指标、可信度、协方差、有效标志
两个 Life Signal
融合权重
allWheelInvalid、imuOnlyDuration、degradedMode
```

阶段 2 额外记录：

```text
vy_true
五点差分得到的 dvx_true/dt
ax_true_ref = dvx_true/dt - AVz*vy_true
每轮 WSS 速度残差
Ax 残差
```
