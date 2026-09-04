# Vy Dynamic EKF V1.2 基线验证状态

- 日期：2026-08-25
- 检查模型：`model/vx.slx`
- 联合仿真：CarSim 2021.0，16 s，工况 `Yaw Control Diff., DLC w/ Low Mu`
- 执行范围：只读检查、原样运行一次、新增离线验证脚本和结果文件
- 未修改：`model/vx.slx`、`matlab/vy_dynamic_ekf_step.m`、`matlab/tireForceLocal.m`、Q、R、轮胎模型、状态方程、车辆参数和任何信号连线

## A. u 五个元素真实来源

`Vy Dynamic EKF` 的实际 Simulink 块为 `vx/估计vy`，调用
`vy_dynamic_ekf(u)`，其单一 7 维输入由 `Mux9` 合并。前 5 维是
`Mux10 = [Vx, Mux11]`。

1. `u(1) = Vx`
   - `From32`，Goto 标签 `Vx`；
   - `Goto63 <- Gain38 <- Demux4(9)`；
   - CarSim 导出通道 `Vx`，`Gain38 = 1/3.6`；
   - 实际是 CarSim 真实纵向速度，转换后单位 m/s。
2. `u(2) = Steer_FL`
   - `From37`，Goto 标签 `WEEL1`；
   - `Demux6(1)` = CarSim `Steer_L1`；
   - `L1` 为左前轮 FL。
3. `u(3) = Steer_FR`
   - `From40`，Goto 标签 `WEEL2`；
   - `Demux6(3)` = CarSim `Steer_R1`；
   - `R1` 为右前轮 FR。
4. `u(4) = Steer_RL`
   - `From38`，Goto 标签 `WEEL3`；
   - `Demux6(2)` = CarSim `Steer_L2`；
   - `L2` 为左后轮 RL。
5. `u(5) = Steer_RR`
   - `From41`，Goto 标签 `WEEL4`；
   - `Demux6(4)` = CarSim `Steer_R2`；
   - `R2` 为右后轮 RR。

CarSim 导出表中四元素原始顺序为
`[Steer_L1, Steer_L2, Steer_R1, Steer_R2]`；模型通过
`Demux6` 以 `1,3,2,4` 顺序取出，最终传入 EKF 的顺序为
`[FL, FR, RL, RR]`。四元素向量在拆分前经过
`Gain17 = pi/180`，因此 EKF 入口单位为 rad。

**结论：图中四路 `WHEEL/WEEL` 信号是车轮转角，不是车轮角速度。**

## B. z 两个元素真实来源

1. `z(1) = Ay_IMU`
   - CarSim 导出通道 `Ay`，`Demux5(10)`；
   - `Gain36 = 9.8`，将 CarSim g 单位转为 m/s^2；
   - 进入 `ay传感器` 虚拟 IMU；
   - 传感器叠加 bias `0.02 m/s^2` 和 100 Hz 白噪声
     `variance = 0.000025`，再经 20 Hz 一阶低通；
   - 最终单位 m/s^2。
2. `z(2) = AVz_IMU`
   - CarSim 导出通道 `AVz`，位于首个 12 元素向量的第 2 路；
   - `Gain10 = pi/180`，将 deg/s 转为 rad/s；
   - 进入 `AVz传感器` 虚拟 IMU；
   - 传感器叠加 bias `0.005 rad/s` 和 100 Hz 白噪声
     `variance = 0.000025`，再经 20 Hz 一阶低通；
   - 最终单位 rad/s。

## C. EKF 真实执行周期

- CarSim `simfile.sim`：`EXT_MODEL_STEP = 0.001 s`。
- `vx/估计vy` 块声明采样时间：`-1`（继承）。
- Simulink 编译后 `CompiledSampleTime = [0.001 0]`。
- 仿真日志：`est_y_log1`、`est_P_log1`、`est_diag_log1` 均为
  `0.001 s`；`est_z_log1` 为 `0.01 s`。

**实际 EKF 每 0.001 s 执行一次（1 kHz），不是 0.01 s（100 Hz）。**

## D. 当前工况输入与状态统计

### 输入

| 信号 | min | max | max(abs) |
|---|---:|---:|---:|
| Vx [m/s] | 19.982036905 | 20 | 20 |
| Steer_FL [rad] | -6.60812370213e-08 | 0 | 6.60812370213e-08 |
| Steer_FR [rad] | 0 | 6.60812370213e-08 | 6.60812370213e-08 |
| Steer_RL [rad] | -1.02136743507e-10 | 1.29755975749e-08 | 1.29755975749e-08 |
| Steer_RR [rad] | -1.29755975749e-08 | 1.02136743507e-10 | 1.29755975749e-08 |
| Ay [m/s^2] | 0.00789137793886 | 0.0321020384115 | 0.0321020384115 |
| AVz [rad/s] | -0.00710862206115 | 0.0171020384115 | 0.0171020384115 |

### 估计、协方差和 NIS

| 量 | min | max |
|---|---:|---:|
| Vy_hat [m/s] | -0.00581068207084 | 0.00022271115696 |
| r_hat [rad/s] | -0.00329500448689 | 0.00881738169215 |
| P_vy | 0.000188475952718 | 0.000550032307886 |
| P_r | 0.00191009689923 | 0.00883268333348 |

| NIS 指标 | 数值 |
|---|---:|
| mean | 0.00205573201805 |
| median | 0.00138431772097 |
| max | 0.0194285230251 |
| 95 percentile | 0.00631567132293 |

### 四轮模型输出

| 信号 | min | max | max(abs) |
|---|---:|---:|---:|
| Fy_FL [N] | -12.0557100043 | 15.2741510286 | 15.2741510286 |
| Fy_FR [N] | -12.0389887404 | 15.2844767424 | 15.2844767424 |
| Fy_RL [N] | -17.9356291105 | 62.0902869408 | 62.0902869408 |
| Fy_RR [N] | -17.9405315201 | 62.0525091395 | 62.0525091395 |
| alpha_FL [rad] | -9.61021231103e-05 | 0.000121804860132 | 0.000121804860132 |
| alpha_FR [rad] | -9.59686374479e-05 | 0.000121887354042 | 0.000121887354042 |
| alpha_RL [rad] | -0.000299470110226 | 0.00104485434819 | 0.00104485434819 |
| alpha_RR [rad] | -0.000299552223781 | 0.00104421159371 | 0.00104421159371 |

## E. 横向激励充分性

- `max(abs(any steering)) = 6.60812370213e-08 rad < 0.01 rad`
- `max(abs(Ay)) = 0.0321020384115 m/s^2 < 0.5 m/s^2`
- `max(abs(AVz)) = 0.0171020384115 rad/s < 0.05 rad/s`

**CURRENT CASE IS NOT SUFFICIENT FOR D-EKF LATERAL VALIDATION**

本次不开始调整 Q/R。

## F. 发现的接口和验证问题

1. **EKF 节拍错误**：块实际以 1 kHz 调用，而虚拟 IMU 数据只以
   100 Hz 更新，因此同一个 z 样本会被 EKF 在多个 1 ms 步中重复使用。
2. **内部时间参数与调用节拍不匹配**：包装器设置 `cfg.dt = 0.01`，但
   `vy_dynamic_ekf_step.m` 查找的字段为 `cfg.Ts` 或 `cfg.Ts_est`，当前因
   缺少这两个字段而回退到默认 `0.01 s`。所以每 1 ms 调用一次时，
   每次内部状态预测仍按 10 ms 积分。本次仅报告，未修改。
3. **当前工况无有效转向输入**：虽然 CarSim 运行名称包含 `DLC`，但
   四轮实际转角量级仅 `1e-8 rad`；Ay/AVz 也低于验证阈值，当前
   输出无法验证横向动态估计能力。
4. **信号标签拼写**：实际 Goto/From 标签是 `WEEL1...WEEL4`，不是
   `WHEEL_1...WHEEL_4`。物理映射正确，但命名容易造成误判。
5. **MATLAB 路径依赖**：新启动的干净 MATLAB 会话中三个函数未预先
   加入搜索路径；本次仿真明确加入 `matlab/` 后，实际解析为：
   - `D:\UsersData\桌面\two\matlab\vy_dynamic_ekf.m`
   - `D:\UsersData\桌面\two\matlab\vy_dynamic_ekf_step.m`
   - `D:\UsersData\桌面\two\matlab\tireForceLocal.m`
6. `vy_dynamic_ekf_step.m` 中不存在硬编码 `validMeas = false;`。实际代码是
   基于 innovation、S 和 2x2 行列式有效性的动态判断。
7. 用户描述的 `outest_*` 在当前 `SimulationOutput` 中实际字段为
   `out.est_u_log1`、`out.est_z_log1`、`out.est_y_log1`、
   `out.est_P_log1`、`out.est_diag_log1`。验证脚本同时兼容两种命名。

## 真实 Vy 离线对比

模型已有 `vy_true_log1`，来自 CarSim `Vy` 经 `Gain11 = 1/3.6`，单位
m/s。该信号只连接 `To Workspace9`，没有进入 EKF。离线比较结果：

- bias = -0.00274641061493 m/s
- MAE = 0.00274661581018 m/s
- RMSE = 0.00284282663599 m/s

由于当前工况没有足够横向激励，不能用这些误差数值宣称
D-EKF 横向验证通过。

## G. 生成文件

- 验证脚本：`matlab/validate_vy_dekf_v1.m`
- 仿真日志副本：`results/vy_dekf_v1_simout.mat`
- 文本报告：`results/vy_dekf_v1_report.txt`
- 状态与 NIS：`results/vy_dekf_v1_states_nis.png`
- 协方差与输入：`results/vy_dekf_v1_covariance_inputs.png`
- 四轮 Fy 与 alpha：`results/vy_dekf_v1_tire_model.png`

## 验收结果

- 联合仿真成功到达 16 s。
- 五个必需日志均存在且非空。
- 验证脚本可兼容 `timeseries`、`SimulationOutput`、
  `SimulationData.Signal/Dataset`、带 `time/signals.values` 的结构体和数值矩阵。
- 验证脚本已在 MATLAB R2024a 实际运行通过，报告和三张图均生成且非空。
