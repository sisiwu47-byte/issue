# D-EKF V1.3 Statistical Consistency Characterization

- 日期：2026-08-25
- 输入模型：`model/vx_vy_dekf_v1.slx`
- 输出模型：`model/vx_vy_dekf_v1_3.slx`
- 工况：沿用V1.2/V1正式横向激励，16 s
- D-EKF执行节拍：0.01 s（100 Hz）
- 实际更新数：1601
- 阶段性质：characterization only

## 禁止项验收

本阶段未修改：

- `matlab/vy_dynamic_ekf_step.m`
- `matlab/tireForceLocal.m`
- 原 `matlab/vy_dynamic_ekf.m`
- `cfg.Q = diag([1e-4,1e-3])`
- `cfg.R = diag([1e-2,1e-2])`
- 车辆参数
- 轮胎参数/模型
- D-EKF状态方程
- D-EKF量测方程
- 100 Hz Function-Call/Rate Transition结构
- CarSim真实Vx输入方式
- 横向转向工况
- Ay/AVz虚拟IMU滤波器

V1原模型SHA-256在任务前后均为：

`E053942BD29B91A35F4D18E146FE5F62C86D308E9790137BDF24DF53F485C7C5`

## V1.3模型副本改动

### 传感器前真值日志

1. `vy_Ay_true_log`
   - 源：`Gain36` 输出
   - 物理链：CarSim `Ay` -> `x 9.8`
   - 位置：虚拟IMU bias/noise/20 Hz低通之前
   - 单位：m/s^2
   - 日志频率：100 Hz
2. `vy_AVz_true_log`
   - 源：`Gain10` 输出
   - 物理链：CarSim `AVz` -> `x pi/180`
   - 位置：虚拟IMU bias/noise/20 Hz低通之前
   - 单位：rad/s
   - 日志频率：100 Hz

现有 `avz_log1` 连接于 `Demux4(2)`，位于 `Gain10=pi/180`
之前，仍为deg/s，因此本阶段没有错误复用该日志。

### Innovation诊断输出

为避免改动V1共享包装器，新建：

- `matlab/vy_dynamic_ekf_v1_3.m`

该包装器的输入、持久状态、车辆参数、Q、R和核心调用与
`vy_dynamic_ekf.m` 保持一致，仅将输出从13维扩展为15维：

```text
y(14) = info.innovation(1) = innovation_Ay
y(15) = info.innovation(2) = innovation_r
```

`Demux12` 由 `[2 2 9]` 扩展为 `[2 2 11]`。原 `est_diag_log1`
保留前9列含义，第10/11列为innovation Ay/r。

## 仿真与数据完整性

- 100 Hz Function-Call Subsystem `CompiledSampleTime = [0.01 0]`
- 实际D-EKF更新数：1601
- `est_z_log1`：1601 x 2
- `vy_Ay_true_log`：1601 x 1
- `vy_AVz_true_log`：1601 x 1
- `est_diag_log1`：16001 x 11（1 kHz保持日志）
- 必要日志全部有限，无NaN/Inf
- 仿真成功到达16 s
- 仿真存档：`results/vy_dekf_v1_3_simout.mat`

## 统计方法

共同时间轴为IMU的100 Hz时间轴，共1601个样本：

```text
e_Ay = Ay_IMU - Ay_true
e_r  = AVz_IMU - AVz_true
```

- `std`/`variance` 使用N-1样本定义。
- bias为误差均值。
- noise为误差减厺bbias。
- 自相关为去均值后、以lag-0能量归一的0--20阶ACF。
- NIS和innovation只在100 Hz真实更新点取样，不重复统计1 kHz保持值。

## A. Ay真实传感器误差

| 指标 | 数值 |
|---|---:|
| bias/mean | 0.0199543721203506 m/s^2 |
| std | 0.0261749804707791 m/s^2 |
| variance | 0.000685129602645665 (m/s^2)^2 |
| RMS | 0.0329071212782739 m/s^2 |
| min | -0.0326975754393932 m/s^2 |
| max | 0.0746380142801749 m/s^2 |
| p95 absolute error | 0.0666471389933115 m/s^2 |

## B. AVz真实传感器误差

| 指标 | 数值 |
|---|---:|
| bias/mean | 0.00495438488292912 rad/s |
| std | 0.00336517296180815 rad/s |
| variance | 1.13243890628846e-05 (rad/s)^2 |
| RMS | 0.00598859293229581 rad/s |
| min | -0.00710862206114766 rad/s |
| max | 0.0171020384114568 rad/s |
| p95 absolute error | 0.010636125326668 rad/s |

## C. 厺bbias后方差

```text
var(noise_Ay) = 0.000685129602645665 (m/s^2)^2
var(noise_r)  = 1.13243890628846e-05 (rad/s)^2
```

因为减去常数bias不改变样本方差，该值与误差列表中的variance相同。

## D. 当前R

```text
R_Ay = 0.01
R_r  = 0.01
current standard deviation = [0.1 m/s^2, 0.1 rad/s]
```

## E. R_sensor_candidate（未应用）

```text
R_sensor_candidate = diag([
    0.000685129602645665,
    1.13243890628846e-05
])
```

候选标准差：

- Ay：0.0261749804707791 m/s^2
- r：0.00336517296180815 rad/s

## F. current R / candidate R

- Ay：14.5957786109146
- r：883.049844408359

## G. noise_Ay自相关

| lag | rho |
|---:|---:|
| 1 | 0.991841387041222 |
| 2 | 0.987429768394301 |
| 5 | 0.976404154110426 |
| 10 | 0.947486898823519 |

Ay误差在10个样本（0.1 s）后仍高度相关。该结果不能解释为独立白噪声，
其中包含20 Hz低通、横向动态相位滞后和有色噪声成分。

## H. noise_r自相关

| lag | rho |
|---:|---:|
| 1 | 0.529151694109494 |
| 2 | 0.329764562366549 |
| 5 | 0.14465128363872 |
| 10 | 0.11355119489508 |

AVz误差的时间相关弱于Ay，但仍不是严格白噪声。

## I. innovation Ay

| 指标 | 数值 |
|---|---:|
| mean | -0.00478008307127427 m/s^2 |
| std | 0.00790920302783682 m/s^2 |
| variance | 6.25554925355432e-05 (m/s^2)^2 |
| RMS | 0.00923935138099357 m/s^2 |

## J. innovation r

| 指标 | 数值 |
|---|---:|
| mean | 0.00254050885043168 rad/s |
| std | 0.00795269653908591 rad/s |
| variance | 6.3245382242789e-05 (rad/s)^2 |
| RMS | 0.00834626046728745 rad/s |

## K. NIS一致性

- 量测维数：2
- 理论参考均值：约2
- chi-square 95% upper：5.991464547

| 指标 | 数值 |
|---|---:|
| mean | 0.00775100961991785 |
| median | 0.00491865904910987 |
| p95 | 0.0236705600295659 |
| max | 0.0501623699417825 |
| fraction NIS <= 5.991464547 | 1.0（100%） |

## L. 明确判断

**是：当前NIS极低与R设置明显大于本工况下的经验零均值传感器误差方差相符。**

证据：

- NIS均值0.00775远低于理论参考2。
- 当前Ay R约为候选Ay方差的14.6倍。
- 当前r R约为候选r方差的883倍。
- 所有NIS样本均低于chi-square 95%上界。

但这不证明R过大是唯一原因。Q、模型误差、创新动力学、固定bias和
显著的时间相关性均会影响NIS。特别是Ay候选方差包含滤波滞后和工况
动态误差，不能直接视为独立白噪声协方差。

**本阶段没有将 `R_sensor_candidate` 写入任何模型或包装器，没有调Q，没有进入K-KF。**

## 生成文件

- 模型副本：`model/vx_vy_dekf_v1_3.slx`
- 构建脚本：`matlab/build_vy_dekf_v1_3_model.m`
- 专用诊断包装器：`matlab/vy_dynamic_ekf_v1_3.m`
- 分析脚本：`matlab/analyze_vy_dekf_v1_3_consistency.m`
- 仿真日志：`results/vy_dekf_v1_3_simout.mat`
- 数值报告：`results/vy_dekf_v1_3_sensor_statistics.txt`
- 传感器误差图：`results/vy_dekf_v1_3_sensor_errors.png`
- 自相关图：`results/vy_dekf_v1_3_autocorrelation.png`
- innovation图：`results/vy_dekf_v1_3_innovations.png`
- NIS图：`results/vy_dekf_v1_3_nis.png`
