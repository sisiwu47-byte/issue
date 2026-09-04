# Stage 2C Formula Map (Closure Edition)

## 1. 阶段范围与目标
本文件是 Stage 2C 的单一数学依据，用于后续 MATLAB 实现。  
执行链仅包含两条纵向速度估计通道（WSS 与 IMU）与相关融合，不使用 GPS/BDS。  
任何实现必须直接按本文档“变量、顺序、公式、边界、状态机、保护项”落地，不得外推论文或再做方法选择。

## 2. 固定系统结构
- 两条有效估计通道：
  - WSS 通道：4WIS 候选速度 → 有限窗一致性滑移识别 → 连续可信度 → 自适应方差 → 四轮内部融合 → `vxWssTrack`。
  - IMU 通道：`axCorr` 梯形积分递推 → `vxImuTrack`。
- 两条通道输出各自进入标量 KF（WSS、IMU 本地 KF）。
- 两本地 KF 保留互协方差 `PWI`，进入 2×2 相关融合。
- 输出 `vxFused` 由相关融合或单通道退化规则给出。
- 不使用 `CarSim vx` 作为估计输入，不引入 GPS/IMU 重力版本主链，不新增观测器/滤波器。

## 3. 坐标与索引定义
- 车体坐标：`+X` 前，`+Y` 左，`+Z` 上；`r=AVz`，左转为正。
- 角速度：
  - `AVx = p`，`AVy = q`，`AVz = r`。
- 轮序固定：`[FL, FR, RL, RR]`（1..4）。
- 轮心坐标（m）：
  - `x_w = [+a, +a, -b, -b]`
  - `y_w = [+d/2, -d/2, +d/2, -d/2]`
- 轮转角：`delta = [Steer_L1, Steer_R1, Steer_L2, Steer_R2]^T`。
- 车速通道状态机输入索引仅限于：
  - `wheelOmega(4)` -> `[AVy_L1, AVy_R1, AVy_L2, AVy_R2]`
  - `wheelAngle(4)` -> `[Steer_L1, Steer_R1, Steer_L2, Steer_R2]`
  - `Ax, AVz`（100 Hz）

## 4. 固定参数（Stage 2C）
- `Ts_est = 0.01 s`
- `Twindow = 0.5 s`
- `Nwindow = 50`
- `TimuOnlyMax = 1.0 s`
- `Rw = 0.393 m`
- `a = 1.18 m`
- `b = 1.77 m`
- `d = 1.575 m`
- `vehicle.wheelRadius = Rw`
- `vehicle.track = d`
- `x_w, y_w` 按第 3 节定义。

## 5. 临时校准参数（待离线标定）
以下参数必须在 Stage 3 之后由回归指标统一填定，不得在 Stage 2C 之后再临时改动。

| 参数 | 当前临时值 | 单位 | 合理范围 | 标定数据来源 | 是否影响结构 |
|---|---:|---|---|---|---|
| `e_low` | `0.15` | m/s | 0~1 | Stage2 仿真无滑移段统计 | 不影响 |
| `e_high` | `0.50` | m/s | `e_low < e_high` | Stage2 仿真无滑移段统计 | 不影响 |
| `rho_hard` | `0.05` | - | 0~1 | Stage2 验证（滑移突变场景） | 不影响 |
| `R0` | `1e-4` | (m/s)^2 | >0 | Stage2 静态段方差反演 | 影响 `RwSS` 与 KF 收敛速度 |
| `R_min` | `1e-6` | (m/s)^2 | >0 | 与 `R0` 同步 | 不影响 |
| `R_max` | `1e4` | (m/s)^2 | 远大于正常值 | 与异常工况经验边界 | 不影响 |
| `cos_delta_min` | `0.20` | - | `0~1` | Stage2 失效测试 | 不影响 |
| `v_low` | `0.30` | m/s | >0 | Stage2 低速工况验证 | 可影响阈值策略（保留位） |
| `QW` | `1e-4` | (m/s)^2 | >0 | Stage2 匹配 RMSE 后定 | 影响 WSS KF |
| `QI` | `1e-4` | (m/s)^2 | >0 | Stage2 匹配 RMSE 后定 | 影响 IMU KF |
| `PW0` | `1e-4` | (m/s)^2 | >0 | Stage2 仿真 | 初始不确定性 |
| `PI0` | `1e-4` | (m/s)^2 | >0 | Stage2 仿真 | 初始不确定性 |
| `PWI0` | `0` | (m/s)^2 | 允许 0~PWPI | Stage2 仿真 | 融合初始耦合 |
| `R_imuc` | `1e-3` | (m/s)^2 | >0 | Stage2 数据标定 | IMU 通道测量噪声主值 |
| `R_imuc_floor` | `1e-8` | (m/s)^2 | >0 | 与 `R_imuc` 同步 | IMU 测量方差底阈 |
| `accelSanityMax` | `50` | m/s² | [20,100] | Stage2 数据约束 | 不影响 |

补充：`Q_WI_common` 为 Stage 2A/2 的互协方差过程项统一记号，默认取 `Q_WI_common = (QW + QI)/2`（仅标量推导项，不引入新结构）。

## 6. 输入与输出（信号接口）
### 当前输入
- `wheelOmega(4)`，`wheelAngle(4)`，`Ax`，`AVx`，`AVy`，`AVz`，`reset`（从 `est_u` 映射而来，见 Section 18）。
- 参考：`wheelOmega = [AVy_L1, AVy_R1, AVy_L2, AVy_R2]`  
  `wheelAngle = [Steer_L1, Steer_R1, Steer_L2, Steer_R2]`

### 当前输出（建议与 `est_y` 对齐）
- `est_y(1)=vxFused`
- `est_y(2)=Pfused`
- `est_y(3)=vx_wss_local`
- `est_y(4)=Pwss_local`
- `est_y(5)=vx_imu_local`
- `est_y(6)=P_imu_local`
- `est_y(7)=PWI`
- `est_y(8:11)=vxWheel(4)`
- `est_y(12:15)=eSlip(4)`
- `est_y(16:19)=rhoWheel(4)`
- `est_y(20:23)=Rwss(4)`
- `est_y(24:27)=double(validWheel(4))`
- `est_y(28)=double(wssValid)`
- `est_y(29)=double(imuValid)`
- `est_y(30:31)=fusionWeights [alphaW alphaI]`
- `est_y(32)=double(allWheelInvalid)`
- `est_y(33)=imuOnlyDuration`
- `est_y(34)=double(degradedMode)`
- `est_y(35)=double(estimatorUpdated)`
- `est_y(36)=double(slipReady)`
- `est_y(37)=condPhi`
- `est_y(38)=updateCounter`

## 7. WSS 候选速度（4WIS 反算）
### 7.1 逐轮切向速度
标量/每轮（4×1）：

`v_t,i = Rw * omega_i`

单位：`m/s`。

### 7.2 候选纵向速度（一般式）
`v_x,i^{WSS} = r*y_i + (v_t,i - (v_y^{prior}+r*x_i)\sin\delta_i)/\cos\delta_i`

### 7.3 阶段1固定
`v_y_prior = 0`：

`v_x,i^{WSS} = r*y_i + (Rw*omega_i - r*x_i*sin(delta_i))/cos(delta_i)`

### 7.4 cos 保护
- 若 `abs(cos(delta_i)) < cos_delta_min`，当前拍 `vxWheel(i)=NaN`，`valid_i=false`，不参与后续。
- `cos_delta_min = 0.20`。

### 7.5 变量属性
- `vxWheel`: 4×1，单位 m/s，当前拍值，persistent 缓存历史候选（用于窗口差分）。

## 8. FIFO 与有限窗（严格 50 点）
### 8.1 FIFO 成员
- `axCorrFIFO(1..Nwindow)`：长度 Nwindow 标量 FIFO（`NaN` 可记录并由有效性闸控）。
- `vxWheelFIFO(4×Nwindow)`：每轮候选速度 FIFO。
- `count`：当前可用样本数（1..Nwindow）。
- `windowReady = (count == Nwindow)`。
- `slipReady = windowReady`（仅在窗口满后生效；未满时仅进行初始化轨迹，不输出正式滑移判断）。

### 8.2 FIFO 更新
- 当前拍先写入队尾，再超长移除队首（保留最近 Nwindow）。
- 该定义避免对当前拍引用未来状态，满足无代数环要求。

## 9. IMU 处理加速度与窗口增量
### 9.1 纠正加速度
当前拍：

`axCorr(k) = Ax(k) + AVz(k)*vy_prior(k)`

阶段1：

`vy_prior(k)=0`，故 `axCorr(k)=Ax(k)`。

### 9.2 首拍与重置后的 `axCorr(k-1)`
- `reset` 时：`axCorrPrev = (Ax 有限 ? Ax : 0)`。
- 若首拍发生 NaN/Inf：`axCorr = 0`（并触发 `imuValid=false`）。

### 9.3 梯形增量
`dvImuStep(k) = 0.5 * Ts_est * (axCorr(k-1)+axCorr(k))`

### 9.4 IMU 窗口增量
`DeltaVImu(k)=sum(dvImuStep entries in FIFO)`  
窗口未满时以现有样本个数求和。

### 9.5 IMU通道有效性
`imuLife = all(isfinite([Ax,AVz,axCorr])) && abs(Ax) < accelSanityMax`

若 `imuLife=false`，本拍 `imuValid=false`，IMU 通道本拍不参与测量更新。

## 10. WSS 窗口增量与滑移残差
### 10.1 WSS 滑移增量
当 `windowReady=true`：

`DeltaVWheel_i(k)=vxWheel_i(k)-vxWheel_i(k-Nwindow)`，向量化为 4×1。

窗口未满时：`slipReady=false`，该残差不驱动状态更新，仅执行历史填充。

### 10.2 一致性残差
`eSlip_i(k) = abs(DeltaVWheel_i(k)-DeltaVImu(k))`，向量化 4×1。

### 10.3 连续可信度（硬边界）
对于 `slipReady=true`：

`rho_i = 1, e_i <= e_low`  
`rho_i = (e_high-e_i)/(e_high-e_low), e_low < e_i < e_high`  
`rho_i = 0, e_i >= e_high`

窗口未满时：`rho_i = 1`（固定启动值）。

### 10.4 分轮方差映射
`Rwheel_i = clip(R0_i/(rho_i + epsilon), R_min, R_max)`  
`epsilon = 1e-8`。

### 10.5 硬隔离（当前拍）
`validWheel_i = signalFinite_i && abs(cos(delta_i)) >= cos_delta_min && rho_i > rho_hard`

其中 `signalFinite_i` 至少包含：
- `omega_i` 有限
- `delta_i` 有限
- `Ax` 有限
- `AVz` 有限

### 10.6 WSS 内部有效集合
`V_k = {i | validWheel_i = 1}`，为 4×1 的布尔集合。

### 10.7 WSS 内部融合
若 `V_k` 非空：

`q_i = 1/Rwheel_i`，`i∈V_k`  
`gamma_i = q_i / sum(q_j), j∈V_k`  
`vxWssTrack = sum(gamma_i*vxWheel_i, i∈V_k)`  
`RwssEquivalent = 1 / sum(q_i, i∈V_k)`

若 `V_k` 为空：

`wssValid = false`；`vxWssTrack` 不更新（保留上一次有限值）；`RwssEquivalent = R_max`。

明确：**禁止**把 `validWheel_i` 全部为 0 的情形改作归一化（即不能重归一化为全 1/0）。

## 11. 100 Hz 执行顺序与数据依赖检查（无代数环）
每个估计周期 `k` 固定顺序：

STEP 0 复位/输入合法性  
1. 读取当前 100 Hz 输入：`Ax, AVz, wheelOmega(4), wheelAngle(4)`。  
2. 计算 `vxWheel(4)`（含 cos 保护）。  
3. 计算 `axCorr(k)`。  
4. 计算 `dvImuStep(k)`（需 `axCorr(k-1)`）。  
5. 更新 FIFO（`axCorrFIFO`, `vxWheelFIFO`）。  
6. 得到 `windowReady / slipReady`。窗口未满不做正式滑移。  
7. 窗口满后计算 `DeltaVImu(k), DeltaVWheel_i(k), eSlip_i(k)`。  
8. 由 `eSlip_i` 计算 `rhoWheel_i, Rwheel_i, validWheel_i`。  
9. `V_k` 非空→WSS 融合；空则 `wssValid=false`。  
10. IMU 轨迹：`vxImuTrack(k)=vxFused(k-1)+0.5*Ts_est*(axCorr(k-1)+axCorr(k))`。  
11. 本地 WSS KF 更新。  
12. 本地 IMU KF 更新。  
13. 更新本地方差与互协方差 `PWI`（按当前通道有效性）。  
14. 构造 `Phi = [ [PW, PWI; PWI, PI] ]`。  
15. 计算融合权重。  
16. 计算融合速度与方差。  
17. 更新上一拍状态：`vxFused(k-1)、axCorrPrev、FIFO、channel 状态、allWheelInvalidDuration`。  
18. 输出诊断与 `degradedMode`。

代数闭环检查：
- `vxImuTrack(k)` 使用 `vxFused(k-1)`，不是 `vxFused(k)`，因此无 `k`→`k` 环。
- 相关融合使用本拍本地 KF 输出 `xW_k^+,xI_k^+` 与上一拍递推的 `Phi`，无隐式反求解。
- `vxFused` 不参与当拍 `vxWheel` 或 `Rwheel` 计算，避免通道间代数闭环。

## 12. WSS 通道本地 KF（标量）
### 状态定义
- 先验预测：`xW^- = xW_prev`，`PW^- = PW_prev + QW`
- 卡尔曼增益：`KW = PW^- / (PW^- + RwssEquivalent)`（若 `imuValid=false` 或 `wssValid=false` 则不更新）
- 更新：`xW^+ = xW^- + KW*(vxWssTrack - xW^-)`
- 方差：`PW^+ = (1-KW)*PW^-`

`wssValid=false` 时采用：
- `xW^+ = xW^-`
- `PW^+ = PW^-`

## 13. IMU 通道本地 KF（标量）
### 状态定义
- 先验预测：`xI^- = xI_prev`，`PI^- = PI_prev + QI`
- 卡尔曼增益：`KI = PI^- / (PI^- + RI)`（`RI = R_IMU`，详见第 14 节）
- 更新：`xI^+ = xI^- + KI*(vxImuTrack - xI^-)`
- 方差：`PI^+ = (1-KI)*PI^-`

`imuValid=false` 时采用：
- `xI^+ = xI^-`
- `PI^+ = PI^-`

IMU 测量方差固定或计算：
- `RI = R_imuc`（先验接口参数）  
- `R_IMU = max(Pfused_prev + (Ts_est^2/2)*R_Ax, R_imuc_floor)`  
其中 `R_Ax = (stage2a/2b 约定) RAxFloor = 1e-6`，当前阶段以 `R_imuc` 为主输入参数，并保留 `R_Ax` 作为接口兼容位。

## 14. 互协方差递推（展开）
### 14.1 使用的上一拍项
以 `k-1` 后验值推进：

`PWI_minus(k) = PWI_plus(k-1) + Q_WI_common`

### 14.2 两本地增益进入

`PWI_plus(k) = (1-KW_k)*PWI_minus(k)*(1-KI_k)`

- `KW_k=0` 当 `wssValid=false`
- `KI_k=0` 当 `imuValid=false`

### 14.3 对称性与有效性
`PWI_plus` 实时对称标量；因此 `P21 = P12 = PWI_plus`。  
若两通道均无效：保持 `PWI_plus = PWI_minus`（即仅走过程项，不执行测量约束衰减），避免无效测量将互协方差错误收敛到 0。

### 14.4 单通道恢复后的重入
当某通道从无效恢复为有效：
- 仍使用上式，`K=0→非0` 的门槛转移自然注入互协方差耦合；
- 无需额外“重置”跨协方差（避免突变）；
- `PWI` 仅受 `Q_WI_common` 与当前有效增益调制。

## 15. 相关融合（2×2）
### 15.1 Phi 与权重
`Phi = [PW, PWI; PWI, PI]`，`phi11=PW`, `phi22=PI`, `phi12=PWI`。  
当两通道有效时：

`den = phi11 + phi22 - 2*phi12`  
`alphaW = (phi22 - phi12)/den`  
`alphaI = (phi11 - phi12)/den`

### 15.2 融合
- 两通道均有效：  
`vxFused = alphaW*xW + alphaI*xI`  
`Pfused = alphaW^2*PW + 2*alphaW*alphaI*PWI + alphaI^2*PI`
- `wssValid=1, imuValid=0`：`alphaW=1, alphaI=0`, `vxFused=xW`, `Pfused=PW`
- `wssValid=0, imuValid=1`：`alphaW=0, alphaI=1`, `vxFused=xI`, `Pfused=PI`
- `wssValid=0, imuValid=0`：`vxFused`、`Pfused` 保持上一次有限状态；`degradedMode=true`。

### 15.3 数值保护（严格）
- 数值保护参数（固定）：`eps_den = 1e-12`，`P_min = 1e-12`，`Pfused_min = 1e-12`。
- `den <= eps_den` 或 `den` 非有限：
  - `condPhi = cond(Phi)` 置大值；
  - 使用 `den=eps_den` 近似，或用对角加小量 `1e-10` 进行正则化。
- 若 `Pfused < Pfused_min`：`Pfused = Pfused_min`（并给诊断）。
- 若 `abs(PWI) > sqrt(PW*PI + eps)`：`PWI` 夹紧到 `sign(PWI)*sqrt(PW*PI)`（Cauchy-Schwarz 界）并记录保护计数。
- 若 `alphaW,alphaI` 为 NaN/Inf：退回单通道权重模式（依据通道有效标志），不得直接切换到逆方差独立融合。

## 16. 通道状态机（4 种 CASE）
定义：
- `wssValid`：`~isempty(V_k)`
- `imuValid`：`imuLife && IMU 通道内未触发 NaN/Inf 保护`
- `allWheelInvalidDuration`（计时器）  
- `allWheelInvalid`：`wssValid==false`

CASE 1：WSS有效、IMU有效  
→ 按相关融合输出 `vxFused`。

CASE 2：WSS无效、IMU有效  
→ 单通道 IMU 本地估计输出（`vxFused=xI`）与 `Pfused=PI`。

CASE 3：WSS有效、IMU无效  
→ 单通道 WSS 本地估计输出（`vxFused=xW`）与 `Pfused=PW`。

CASE 4：WSS无效、IMU无效  
→ `vxFused` 保持最后有限值，不置零；`degradedMode=true`。

### 冲突统一说明
Stage2A 曾有“二者均无效仍使用 IMU 递推”的措辞。  
本阶段固定为：`case4` 不依赖无效 IMU 递推，保持最后有限输出并进入降级。

## 17. 全轮失效计时与 degradedMode
### 17.1 计时条件
若 `wssValid==false && imuValid==true`：

`allWheelInvalidDuration(k)=allWheelInvalidDuration(k-1)+Ts_est`

其余情形清零：
- `wssValid==true`：立即 `=0`
- `imuValid==false`：直接进入 CASE4，不再累加 IMU-only 时长。

### 17.2 警告阈值
若 `allWheelInvalidDuration <= TimuOnlyMax`：`degradedMode=false`。  
若 `> TimuOnlyMax`：`degradedMode=true`。

### 17.3 输出要求
- `allWheelInvalid`（诊断）= `wssValid==false`（IMU 是否有效由 `imuValid` 决定）
- `imuOnlyDuration` 与 `degradedMode` 在 `est_y` 同步输出。

## 18. 初始化与 Reset（必须完整）
`reset != 0` 时执行统一流程：
- `vxFused = vx0`
- `xW = vx0`
- `xI = vx0`
- `PW = PW0`
- `PI = PI0`
- `Pfused = max(PW0, PI0)`
- `PWI = PWI0`
- FIFO 清空，`count=0`，`windowReady=false`，`slipReady=false`
- `axCorrPrev = (Ax 有限 ? Ax : 0)`
- 四轮历史候选初始化为 `NaN`
- `rhoWheel = ones(4,1)`
- `validWheel = [false;false;false;false]`
- `wssValid=false`，`imuValid=false`（待本拍合法性后更新）
- `allWheelInvalidDuration = 0`
- `degradedMode = false`
- 姿态扩展状态归零（保留接口位，当前阶段主链不使用）
- `estimatorUpdated = 0`（首拍或复位后可在更新成功后置 1）
- `updateCounter` +1（或重置为 0 后递增）
- `vx0 = median(Rw*omega_i, finite only)`。

## 19. NaN/Inf 与数值异常处理
- 输入级：
  - 任一当前输入不是有限值：对应量标记 `signalFinite=false`；
  - 相关通道进入无效，相关候选/测量置 `NaN`。
- 加速度异常：
  - `abs(Ax) > accelSanityMax` 触发 `imuValid=false`。
- 方差/协方差异常：
  - 小于 0 时钳位；
  - 非有限值替换为上限；
  - `phi11/phi22` 非正值时先 `max(value, P_min)` 再进入融合。
- FIFO 期初：
  - 未满时不执行滑移正式驱动。

## 20. Rodgues/三轴接口策略
- Stage2B 结论：本阶段主链不使用 `Ax_SM/Ay_SM/Az_SM`；主纵向残差不需要姿态旋转。
- 不在主估计链执行 Rodrigues。
- 保留 `Ax_SM/Ay_SM/Az_SM` 与姿态中间状态为后续接口/扩展位，不驱动 Stage2 主估计。

## 21. 两层融合分离与不可混淆要求
- WSS 内部融合只在 `V_k` 上按轮有效性和 `Rwheel` 进行。
- 相关融合只在两通道层级上按 `Phi` 和 `alphaW/alphaI` 进行。
- 不得把 `RwssEquivalent` 当成两通道融合噪声直接替代相关融合。

## 22. 变量状态表
### A. 当前输入（非 persistent）
- `wheelOmega(4)`，[rad/s]，当前拍
- `wheelAngle(4)`，[rad]，当前拍
- `Ax, AVx, AVy, AVz`，[m/s²,rad/s]
- `reset`

### B. 当前输出（当前拍）
- `vxFused`,`Pfused`,`vxWssTrack`,`RwssEquivalent`,`xI`,`vxImuTrack`,`PWI`,`wheelSpeedCandidate`,`eSlip`,`rhoWheel`,`Rwheel`,`validWheel`,`wssValid`,`imuValid`,`alphaW`,`alphaI`,`allWheelInvalid`,`imuOnlyDuration`,`degradedMode`,`condPhi`,`estimatorUpdated`,`slipReady`

### C. 固定参数
- 第 4 节参数。

### D. 临时标定参数
- 第 5 节参数。

### E. persistent 状态
- `vxFusedPrev`, `xW`, `PW`, `xI`, `PI`, `PWI`, `axCorrPrev`
- `vxWheelFIFO(4,Nwindow)`, `axCorrFIFO(Nwindow)`, `count`, `windowReady`
- `wssValid`, `imuValid`, `slipReady`
- `allWheelInvalidDuration`,`degradedMode`,`updateCounter`
- `vxWheelHistory(4,4)`（如用于 `k-Nwindow` 直接索引）
- `rhoWheel`,`validWheel`（持久化观察量）

### F. 诊断输出
- `LifeSig_WSS`,`LifeSig_IMU`（对应各通道有效性）
- `condPhi`,`updateCounter`,`estimatorUpdated`

### G. 仅评价变量（不得作为主链输入）
- `vx_true`,`vy_true`,`slipTrue(4)`，仅用于回归误差计算。

### H. Stage 1 不使用的预留变量
- `Ax_SM,Ay_SM,Az_SM`（保留），Rodrigues 旋转中间状态。

## 23. 后续 MATLAB 文件映射（建议唯一实现清单）
1. 参数初始化：`velocity_estimator_default_params.m`
2. 四轮运动学候选：`wheel_speed_candidates_4wis.m`
3. FIFO 与有限窗管理：`window_delta_velocity_indicator.m`
4. 可信度与方差：`slip_confidence_mapping.m`
5. WSS 内部融合：`wss_track_builder.m`
6. IMU轨迹与通道 KF：`local_scalar_kf_step.m`（拆分为 WSS/IMU 两次调用）
7. 互协方差与相关融合：`correlated_two_track_fusion.m`
8. 顶层估计器：`longitudinal_velocity_estimator.m`
9. reset 与状态管理：`reset_velocity_estimator_state.m`
10. 仿真后处理：`run_velocity_estimator_simulation.m`
11. 结果绘图：`plot_velocity_estimator_results.m`
12. 输出接口说明（非代码）：`docs/simulink_manual_connection.md`

## 24. 测试映射
- `tests/test_stage2_formula_guardian.m`：参数、边界、步序闭合测试（含无代数环校验）
- `tests/test_stage2_wss_candidate_and_window.m`：`vxWheel`、cos 保护、`DeltaVWheel`、滑移门控
- `tests/test_stage2_imu_track_and_fifo.m`：`axCorr` 初始化/首拍、窗口积分
- `tests/test_stage2_local_kf_and_pwi.m`：WSS/IMU 单个与双通道 KF、`PWI` 有效性
- `tests/test_stage2_correlated_fusion_modes.m`：Case1~Case4 分支、`degradedMode`
- `tests/test_stage2_reset_and_invalidation.m`：`reset`、NaN/Inf、四轮失效计时与保持上次值
- `tests/test_stage2_integration_regression.m`：回归流程（RMSE/MAE/MaxErr）

## 25. 原论文公式对应
- Paper 式(26)：`alpha_k = Phi^{-1}1/(1^T Phi^{-1}1)`  
  本阶段按 2×2 标量展开（第 15 节）。
- Paper 式(28)：`x_fused = alpha^T x`，`P_fused = alpha^T Phi alpha`  
  本阶段按当前两通道实现（第 15 节）。
- Paper 式(29)：状态/协方差更新结构延伸为局部 KF+互协方差链  
  本阶段按 Stage 2A 统一并闭合（第 12~14 节）。

## 26. 本项目修改公式
- 采用阶段1约束 `vy_prior=0`，不使用真实侧向速度。
- 主链不使用重力解算 `Ax_SM/Ay_SM/Az_SM`。
- IMU 轨迹测量输入固定为上拍融合值（非上拍 IMU 状态），严格避免同拍代数环。
- 两层融合严格分离（WSS 内部 vs 相关融合）。
- 四轮全无效时保持上次值（非置零）、`degradedMode=true`。

## 27. UNRESOLVED_BLOCKERS
本阶段无未闭合阻塞项：`0`。  
矛盾点“case4 是否继续 IMU 递推”已按本文件规则统一为不使用无效 IMU 递推，故不作为 blockers。

## 28. SPEC_CONFLICTS 检查
- `implementation_spec.md` 与 `signal_interface.md` 的 100Hz 输入/输出约定、坐标、参数、轮序均已采用并落实。
- 目前未发现未解决冲突；仅在“协方差命名/R_Ax”方面采用主规约（`R_AxFloor` 用于接口保留，测量噪声由 `R_imuc` 与接口层参数主导）。
