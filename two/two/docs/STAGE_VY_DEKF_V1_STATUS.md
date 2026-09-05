# D-EKF V1 节拍修复、横向工况与正式验证状态

- 日期：2026-08-25
- 原始模型：`model/vx.slx`
- 输出副本：`model/vx_vy_dekf_v1.slx`
- MATLAB：R2024a
- CarSim：2021.0
- 仿真时长：16 s
- 主模型/CarSim基础节拍：0.001 s
- D-EKF目标节拍：0.01 s

## 不可变项验收

本阶段未修改：

- `matlab/vy_dynamic_ekf_step.m`
- `matlab/tireForceLocal.m`
- Q
- R
- 轮胎模型
- 车辆参数
- D-EKF状态方程
- D-EKF量测方程
- `vx_hat`/真实Vx选择（仍使用CarSim真实Vx）
- Ay/AVz虚拟IMU结构
- 真实Vy与EKF的连线（真实Vy仍只用于离线评估）

原始 `model/vx.slx` SHA-256：

`754A94D85BD50F89AE453C544903DEA90B7F9D57D6E7706869F9F674FB0464EB`

本轮完成后原模型长度与时间戳仍为：

- 458490 bytes
- 2026-08-25 01:13:22

## 阶段A：D-EKF执行节拍修复

### 修复前

- 顶层包装块：`vx/估计vy`
- 函数：`vy_dynamic_ekf(u)`
- 块采样时间：继承 `-1`
- 编译后实际采样时间：`[0.001 0]`
- 16 s内约16000次执行

### 修复后多速率结构

```text
Mux9 (1 kHz combined u/z)
  -> D-EKF Input RT 100Hz
  -> Vy D-EKF 100Hz (Function-Call Subsystem)
       -> vy_dynamic_ekf(u)
  -> D-EKF Output RT 1kHz
  -> Demux12 / existing 1 kHz held-output logs
```

调度块：

- `D-EKF 100Hz Scheduler`
- 类型：Function-Call Generator
- `sample_time = 0.01`
- `numberOfIterations = 1`

输入速率转换：

- `D-EKF Input RT 100Hz`
- `OutPortSampleTime = 0.01`
- `Integrity = on`
- `Deterministic = on`

输出速率转换：

- `D-EKF Output RT 1kHz`
- `OutPortSampleTime = 0.001`
- `Integrity = on`
- `Deterministic = on`
- 100 Hz更新之间保持上一次D-EKF输出

### CompiledSampleTime证据

- `Vy D-EKF 100Hz` Function-Call Subsystem：`[0.01 0]`
- 内部 `vy_dynamic_ekf` 块：`[-1 -1]`

内部块的 `[-1 -1]` 是Simulink对Function-Call Subsystem内触发继承块的
标准表示，不是1 kHz。Simulink禁止在Function-Call Subsystem内将该块
再显式设为0.01，因为它必须随父级函数调用执行。父级编译采样
时间 `[0.01 0]` 和运行更新计数共同证明真实执行频率为100 Hz。

### 16 s直线回归

- 联合仿真成功到达16 s
- D-EKF实际更新点：1601（包含t=0和t=16 s）
- 1 kHz保持型日志样本：16001
- `x`/输出有限
- P有限
- 诊断量有限
- 无NaN/Inf
- 日志完整
- 回归日志：`results/vy_dekf_v1_stageA_simout.mat`

## 阶段B：真实CarSim横向激励工况

### 原工况转角近似为零的原因

- `Manual Switch1` 当前 `sw=0`，选中的CarSim 12路Import分支为 `Mux8`。
- `Mux8` 第2、4路前轮转向原来同时来自 `Gain22`。
- `Gain22 = 180/pi`，但其输入未连接，因此前轮转向Import命令为0。
- `Mux8` 第6、8路后轮转向原来来自零常量。
- 因此CarSim输出实际四轮转角只剩数值级的 `1e-8 rad`。

### 新建转向激励块

仅在 `vx_vy_dekf_v1.slx` 副本中新增：

- `D-EKF Test Time`：0.001 s Digital Clock
- `D-EKF Lateral Profile`：调用 `vy_dekf_v1_steer_profile(u)`
- `D-EKF Steer rad2deg`：`180/pi`
- `D-EKF Steer Demux`：按 `[FL, FR, RL, RR]` 拆分

修改连线：

- `Mux8(2) <- FL`
- `Mux8(4) <- FR`
- `Mux8(6) <- RL`
- `Mux8(8) <- RR`

其他轮端力矩/Import通道保持原连线。没有给EKF单独伪造转角；
命令先进入CarSim车辆，EKF仍使用CarSim返回的实际四轮转角。

### 转向曲线

- `t < 3 s`：0
- `3 <= t <= 13 s`：前轮0.02 rad峰值、0.4 Hz正弦
- 3.0--3.5 s：0.5 s升余弦平滑淡入
- 12.5--13.0 s：0.5 s升余弦平滑淡出
- `t > 13 s`：0
- 后轮命令：0

CarSim Import转向通道使用deg，因此模型明确经 `180/pi` 从rad转为deg；
没有假设CarSim命令与EKF转角单位相同。

CarSim当前运行标题仍包含 `DLC w/ Low Mu`，但实际生效的
`Run_all.par` 道路摩擦倍数为 `MU_ROAD_CONSTANT = 0.8`，属于正常/中等附着；
本轮没有修改CarSim道路或车辆参数。

### 横向激励实际结果

| 信号 | max(abs) |
|---|---:|
| Steer_FL | 0.0199765941472 rad |
| Steer_FR | 0.0199756904323 rad |
| Steer_RL | 2.44923939812e-05 rad |
| Steer_RR | 2.44865092436e-05 rad |
| Ay_IMU | 2.35632456596 m/s^2 |
| AVz_IMU | 0.132280384246 rad/s |

Vx范围：19.976794858--20 m/s。

三个激励判据均达到：

- 前轮转角 > 0.01 rad
- Ay > 0.5 m/s^2
- AVz > 0.05 rad/s

**CURRENT CASE HAS SUFFICIENT LATERAL EXCITATION FOR BASELINE VALIDATION**

## 阶段C：D-EKF V1正式结果

### Vy误差（CarSim真实Vy仅离线参考）

| 指标 | 数值 |
|---|---:|
| RMSE | 0.03753115591 m/s |
| MAE | 0.0266834718798 m/s |
| Bias | -0.00310066475871 m/s |
| Max Error | 0.0786151237377 m/s |

### r误差（D-EKF r_hat与100 Hz AVz_IMU比较）

| 指标 | 数值 |
|---|---:|
| RMSE | 0.00672084792763 rad/s |
| MAE | 0.00538040871707 rad/s |
| Bias | -0.00226060035894 rad/s |
| Max Error | 0.0186315104422 rad/s |

### NIS（1601个真实100 Hz更新点）

| 指标 | 数值 |
|---|---:|
| mean | 0.00775721755667 |
| median | 0.0049634619682 |
| max | 0.0501623699418 |
| 95 percentile | 0.023563905991 |

### 有限性与日志

- 联合仿真无终止错误
- D-EKF实际更新次数：1601
- `est_u_log1`、`est_z_log1`、`est_y_log1`、`est_P_log1`、
  `est_diag_log1`、`vy_true_log1` 全部存在
- 所有必需日志无NaN/Inf
- x/P/诊断量保持有限
- 1 kHz输出日志在100 Hz更新之间正确保持

## 创建和修改文件

### Simulink副本

- `model/vx_vy_dekf_v1.slx`

### MATLAB脚本/辅助函数

- `matlab/build_vy_dekf_v1_model.m`
- `matlab/configure_vy_dekf_v1_lateral_case.m`
- `matlab/vy_dekf_v1_steer_profile.m`
- `matlab/validate_vy_dekf_v1.m`（已更新）

### 结果

- `results/vy_dekf_v1_stageA_simout.mat`
- `results/vy_dekf_v1_simout.mat`
- `results/vy_dekf_v1_report.txt`
- `results/vy_dekf_v1_state_errors.png`
- `results/vy_dekf_v1_covariance_nis.png`
- `results/vy_dekf_v1_inputs.png`
- `results/vy_dekf_v1_tire_model.png`

## 最终A--J结论

### A. CompiledSampleTime

- 修复前：`[0.001 0]`
- 修复后100 Hz Function-Call Subsystem：`[0.01 0]`
- 内部包装块：`[-1 -1]`（标准函数调用继承，等价于父级100 Hz）

### B. 16 s内实际EKF更新次数

- 1601次，不是16001次

### C. Simulink块改动

- 移除副本顶层原 `估计vy` 包装块
- 在 `Vy D-EKF 100Hz` Function-Call Subsystem内放入同一
  `vy_dynamic_ekf(u)` 包装块
- 新增100 Hz Function-Call Generator
- 新增1 kHz->100 Hz输入Rate Transition
- 新增100 Hz->1 kHz输出Rate Transition
- 新增Digital Clock、平滑转向曲线块、rad/deg增益和四路Demux
- 仅重连 `Mux8` 的4个CarSim转向Import端口

### D. 实际四轮最大转角

- FL：0.0199765941472 rad
- FR：0.0199756904323 rad
- RL：2.44923939812e-05 rad
- RR：2.44865092436e-05 rad

### E. max |Ay|

- 2.35632456596 m/s^2

### F. max |AVz|

- 0.132280384246 rad/s

### G. Vy误差

- RMSE：0.03753115591 m/s
- MAE：0.0266834718798 m/s
- Bias：-0.00310066475871 m/s
- Max Error：0.0786151237377 m/s

### H. r误差

- RMSE：0.00672084792763 rad/s
- MAE：0.00538040871707 rad/s
- Bias：-0.00226060035894 rad/s
- Max Error：0.0186315104422 rad/s

### I. NIS

- mean：0.00775721755667
- median：0.0049634619682
- max：0.0501623699418
- 95 percentile：0.023563905991

### J. 主要输出路径

- 模型副本：`D:\UsersData\桌面\two\model\vx_vy_dekf_v1.slx`
- 验证脚本：`D:\UsersData\桌面\two\matlab\validate_vy_dekf_v1.m`
