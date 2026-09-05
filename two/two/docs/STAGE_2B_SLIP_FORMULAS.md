# Stage 2B: 四轮滑移与有限时间窗速度增量一致性算法

## 1. 算法目标
- 以四轮独立虚拟传感器候选速度构造车身纵向速度残差。
- 采用 0.5 s 有限时间窗（50 点）纵向速度增量一致性判断四轮滑移状态。
- 由每轮残差映射到连续可信度，再由可信度得到每轮自适应测量方差。
- 由有效轮组进行 WSS 通道内部融合。
- 提供全轮失效与 IMU-only 退化逻辑所需状态，供两通道上层融合使用。

## 2. 输入信号及维数
- `wheelOmega`：`4×1`，`[FL,FR,RL,RR]`，单位 rad/s，顺序固定。
  - `wheelOmega = [AVy_L1; AVy_R1; AVy_L2; AVy_R2]`
- `wheelAngle`：`4×1`，`[FL,FR,RL,RR]`，单位 rad。
  - `wheelAngle = [Steer_L1; Steer_R1; Steer_L2; Steer_R2]`
- `accelBody`：`[Ax; Ay; Az]`，单位 m/s²，`Ax` 为去重力后的机体系前向加速度。
- `gyroBody`：`[AVx; AVy; AVz]`，单位 rad/s。
- `reset`：标量，`0/1`。

## 3. 固定参数
- `Ts_est = 0.01 s`
- `Twindow = 0.5 s`
- `Nwindow = 50`
- `TimuOnlyMax = 1.0 s`
- `Rw = 0.393 m`
- `a = 1.18 m`
- `b = 1.77 m`
- `d = 1.575 m`
- `x_w = [+a, +a, -b, -b]`
- `y_w = [+d/2, -d/2, +d/2, -d/2]`
- `ρ_hard = 0.05`（初始固定）
- `ε = 1e-8`
- `cosΔ_min = 0.20`

## 4. 四轮几何坐标
- 轮序固定为：`[FL, FR, RL, RR]`
- 轮心坐标（车身）
  - `FL: (x,y) = (+a, +d/2)`
  - `FR: (x,y) = (+a, -d/2)`
  - `RL: (x,y) = (-b, +d/2)`
  - `RR: (x,y) = (-b, -d/2)`
- 车体坐标定义
  - `+X` 前进
  - `+Y` 左
  - `+Z` 上
  - `AVz>0` 左转
  - 转角正方向左转
  - 车轮前进时角速度为正

## 5. 四轮车速候选公式
- 先算每轮轮边切向速度
  - `v_t,i = Rw * ω_i`
- 纵向速度候选反算（一般式）
  - `v_t,i = (v_x - AVz * y_i) cosδ_i + (v_y_prior + AVz * x_i) sinδ_i`
  - `v_x_wheel,i = AVz * y_i + (v_t,i - (v_y_prior + AVz * x_i) sinδ_i) / cosδ_i`
- 阶段1固定：`v_y_prior = 0`
  - `v_x_wheel,i = AVz * y_i + (Rw * ω_i - AVz * x_i * sinδ_i) / cosδ_i`
- 向量索引写法（i=1..4 分别对应 FL,FR,RL,RR）
  - `x_w = [x_1, x_2, x_3, x_4]`
  - `y_w = [y_1, y_2, y_3, y_4]`
  - `δ = [δ_1, δ_2, δ_3, δ_4]`
  - `ω = [ω_1, ω_2, ω_3, ω_4]`
  - `v_t = Rw * ω`
  - `v_wheel = AVz*y_w + (v_t - AVz*x_w.*sin(δ))./cos(δ)`
- cos 值保护
  - `abs(cosδ_i) < cosΔ_min` 时，`v_x_wheel,i` 当拍置 `NaN`，`valid_i=false`。
- 数值与单位约束
  - `ω_i` 输入单位必须是 rad/s。
  - `δ_i` 输入单位必须是 rad。
  - `v_x_wheel,i` 输出单位为 m/s。

## 6. FIFO结构
- IMU 增量 FIFO：`axCorrFIFO`，长度 `Nwindow`。
- WSS 候选速度 FIFO：`vxWheelFIFO`，尺寸 `4 × Nwindow`。
- 写入与移除策略
  - 每次估计更新将最新值写入队尾。
  - 当长度超过 `Nwindow` 时移除队首，保留最近 50 个。
- 索引定义（估计步 k）
  - `k_start = max(1, k-Nwindow+1)`
  - `count_k = number of samples currently in FIFO (1..Nwindow)`
- 可用于决策的窗口长度
  - `count_k == Nwindow` 时窗口满。

## 7. IMU速度增量
- 校正加速度
  - `a_x_corr(k) = Ax(k) + AVz(k) * v_y_prior(k)`
  - 阶段1：`v_y_prior = 0`，因此 `a_x_corr(k)=Ax(k)`
- 局部梯形积分
  - `Δv_imu_step(k) = 0.5 * Ts_est * (a_x_corr(k-1) + a_x_corr(k))`
- 窗口累计
  - `Δv_imu(k) = sum(Δv_imu_step entries in FIFO window)`
- 当 FIFO 长度不足时
  - 使用当前已有样本累计。

## 8. WSS速度增量
- 第一项：更新每轮候选并存入 `vxWheelFIFO`。
- 二项差分（窗口定义为可用历史长度）
  - 窗口满：`Δv_wheel_i(k) = vx_wheel_i(k) - vx_wheel_i(k-Nwindow)`
  - 窗口未满：`Δv_wheel_i` 不进入正式滑移判断。
- 符号为向量时
  - `Δv_wheel(k) = vx_wheel(k) - vx_wheel(k-Nwindow)`
  - 仅在 `slipReady=true` 时有效。

## 9. 四轮一致性残差
- 逐轮一致性残差
  - `e_i(k) = |Δv_wheel_i(k) - Δv_imu(k)|`
- 逐轮输出：`[e_FL, e_FR, e_RL, e_RR]`
- 与 IMU 窗口长度一致的前提
  - `slipReady=true` 时才作为滑移判据。

## 10. 连续可信度
- 采用唯一分段函数
  - `ρ_i=1` 当 `e_i <= e_low`
  - `ρ_i=(e_high - e_i)/(e_high - e_low)` 当 `e_low < e_i < e_high`
  - `ρ_i=0` 当 `e_i >= e_high`
- `ρ_i` 取值范围由 `0` 到 `1`。
- 初期或窗口未准备好时：`ρ_i` 初始为 `1`。

## 11. 自适应方差
- 映射
  - `R_i = sat(R0_i/(ρ_i + ε), R_min, R_max)`
- sat 定义
  - `sat(u,a,b) = b` 当 `u>b`
  - `sat(u,a,b) = a` 当 `u<a`
  - `sat(u,a,b) = u` 当 `a<=u<=b`
- 统一索引形式
  - `R_wheel = [R_1,R_2,R_3,R_4]^T`
  - `i=1..4` 对应 `[FL,FR,RL,RR]`

## 12. 硬隔离
- 基于阈值硬隔离
  - `valid_i = signalFinite_i && (abs(cosδ_i) >= cosΔ_min) && (ρ_i > ρ_hard)`
- 当 `ρ_i <= ρ_hard`，该轮本拍不参与 WSS 内部融合。
- `signalFinite_i` 包含 `ω_i`, `δ_i`, `Ax`, `AVz` 的有限值检查。

## 13. WSS内部融合
- 有效集合
  - `V_k = { i | valid_i = true }`
- 融合权重（仅对有效集合）
  - `q_i = 1 / R_i`
  - `α_i = q_i / sum(q_j), j in V_k`
- 融合速度
  - `vx_wss = sum(α_i * v_x_wheel_i), i in V_k`
- 等效方差
  - `R_wss = (sum(q_i, i in V_k))^{-1}`
- 失效情况
  - `V_k = ∅` 时 `wssValid=false`
  - `vx_wss` 保持上一次日志值
  - `R_wss = R_wheel_max`
- 不允许操作
  - 当 `V_k=∅` 禁止用四轮 `ρ_i≈0` 再做归一化。

## 14. 窗口启动阶段
- 定义 `windowReady = (count_k == Nwindow)`
- `Nwindow` 个样本内执行规则
  - `windowReady = false`
  - `slipReady = false`
  - 四轮 `ρ_i` 用阶段1定义的初始值
  - 残差不驱动硬隔离
  - 不执行全轮失效升降级切换
- 视为滑移链未启动，待 `windowReady=true` 后再产出正式滑移指标与硬隔离。

## 15. 初始化/reset
- `vx0 = median([Rw*ω_fl, Rw*ω_fr, Rw*ω_rl, Rw*ω_rr], finite only)`
- 重置时操作
  - 清空 `axCorrFIFO` 与 `vxWheelFIFO`
  - `windowReady = false`
  - `slipReady = false`
  - 保存当前 `Ax` 为 `a_x_prev`
  - 保存当前 `AVz` 为 `gyroZ_prev`
  - 初始化四轮历史候选速度为空（或 NaN）
  - 清零 `imuOnlyDuration`
  - `ρ_i` 初始化为 `1`
  - `valid_i` 初始化为 `signalFinite_i && abs(cosδ_i)>=cosΔ_min`
  - 姿态增量中间状态置零（保留为后续 3D 接口用值）
- 仅在下一次有效估计输入后重建主状态。

## 16. 全轮失效状态机
- `wssValid = (~isempty(V_k))`
- 当 `wssValid=false` 且 IMU 通道有效时
  - `imuOnlyDuration += Ts_est`
- 条件分支
  - `imuOnlyDuration <= 1.0 s`：`degradedMode = false`
  - `imuOnlyDuration > 1.0 s`：`degradedMode = true`
- 当任一轮重新满足 `valid_i`，`wssValid=true`，则 `imuOnlyDuration = 0`
- 输出值要求
  - `vx` 禁止硬置零
  - IMU-only 分支继续输出 IMU 递推值

## 17. 异常保护
- NaN/Inf 保护
  - 任何输入为 NaN 或 Inf：该输入对应轮设为无效。
  - 若 `Ax` 或 `AVz` 无效，IMU 通道本拍生命信号可置 false。
- cos 防护
  - `abs(cosδ_i)<cosΔ_min` 时直接置无效，不做除法。
- 窗口未满保护
  - `count_k < Nwindow` 时不使用滑移残差进行正式硬隔离。
- 低速边界保护
  - `vLow = 0.30 m/s` 为低速阈值参考，仅用于上层或后续低速策略。
  - 低速时仍运行残差链，不引入传统即时滑移率。

## 18. 临时待标定参数
- 本阶段允许使用实现规格的临时默认值
  - `e_low = 0.15 m/s`（阶段1临时）
  - `e_high = 0.50 m/s`（阶段1临时）
  - `ρ_hard = 0.05`
  - `R0_i = Rwheel0_tmp = 1e-4`
  - `R_min = RwheelMin = 1e-6`
  - `R_max = RwheelMax = 1e4`
  - `cosΔ_min = 0.20`
  - `v_low = 0.30 m/s`
- 任何参数未定标时不得以曲线效果为依据临时抬高或降低。
- 标定来源约束
  - 仅允许由无滑移段统计与阶段2流程覆盖。

## 19. 原论文方法与本文修改方法对应关系
- 原论文中 WSS/IMU 统一为多轮一致性与滑移识别机制，本项目沿用“分轮独立判断”与“失效时降级”思想。
- 本项目固定替换为“0.5 s 有限时间窗纵向速度增量一致性”。
- 使用 `|Δv_wheel_i - Δv_imu|` 作为四轮滑移指标，不采用三维速度模长残差。
- 原始比力与重力模长判据仅保留为后续 3D 接口扩展，不进入本阶段纵向主残差。
- 4 轮全部失效时不触发新一套结构；直接执行 IMU-only 维持策略并计时退化。

## 20. Stage 2C需要读取的最终变量列表
- `wheelOmega`，`wheelAngle`，`Ax`，`AVz`（`4×1` 输入信号）
- `v_x_wheel_i`（`4×1`，候选纵向速度）
- `Delta_v_wheel_i`（`4×1`，每轮窗口差分残差输入）
- `Delta_v_imu`（标量）
- `slipIndicator`（`[e_FL,e_FR,e_RL,e_RR]`）
- `confidence`（`4×1`）
- `Rwheel`（`4×1`）
- `wheelValid`（`4×1`）
- `wssValid`（标量）
- `slipReady`（标量布尔）
- `vx_wss`，`R_wss`（WSS通道输出）
- `imuOnlyDuration`（标量）
- `degradedMode`（标量布尔）

## SPEC_CONFLICTS
- 无。
