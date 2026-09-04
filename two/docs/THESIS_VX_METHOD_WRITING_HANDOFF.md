# 纵向车速 Vx 估计方法论文写作资料清洗与交接

本文档是纵向车速估计部分唯一的论文写作主交接文件。内容仅来自当前项目中已有的 `docs/`、`results/`、`model/`、`tests/` 和参考文献证据；未重新运行 MATLAB、Simulink 或 CarSim，未修改模型、算法、参数或结果数据。

证据状态统一使用以下标签：

- `FINAL_METHOD`：当前源代码实际采用的方法或参数。
- `VALIDATED_RESULT`：已有真实 MATLAB/Simulink/CarSim 输出直接支持的结果。
- `DIAGNOSTIC_ONLY`：只能用于解释或诊断，不能作为最终性能结论。
- `NOT_VALIDATED`：已经实现或写入文档，但没有当前版本的运行证据。
- `ABANDONED_ROUTE`：开发中考察过、但不属于最终方案的路线。

---

## 1. 最终研究主线

### 1.1 本部分要解决的问题

`FINAL_METHOD`

本部分面向四轮独立驱动、四轮独立转向车辆，在不使用 GPS/GNSS、CarSim 真实纵向速度或真实滑移率作为在线输入的前提下，利用四轮轮速、四轮实际转角、车辆纵向加速度和横摆角速度估计车辆质心纵向速度 `vx_hat`。

需要解决的核心矛盾是：

1. 轮速能提供绝对速度信息，但在驱动滑移、制动抱死和低附着工况下会产生系统误差；
2. IMU 纵向加速度不直接受轮胎滑移影响，但积分轨迹存在零偏和累积漂移；
3. 四轮独立转向时，各轮滚动方向速度不能直接等同于质心纵向速度，需要考虑转角和横摆运动进行几何修正；
4. 两条局部估计轨迹具有公共过程不确定性，最终融合不能简单假定相互独立。

### 1.2 三条内部轨迹分别承担的作用

Vx 部分没有 Vy 方法中的 D/K/F 三轨迹结构。当前代码实际存在下列三条功能轨迹，其中只有后两条局部 KF 输出参加最终融合：

1. **轮健康检测 IMU 轨迹 `vxImuTrackDetect`**：`FINAL_METHOD`
   - 由上一拍基线融合速度和单步 IMU 速度增量构成；
   - 仅用于计算轮速候选与 IMU 的绝对一致性误差 `eAbs`；
   - 不直接进入最终速度融合。

2. **WSS 轨迹 `vxWssTrack` / WSS 局部 KF 状态 `xW`**：`FINAL_METHOD`
   - 四轮轮速经过 4WIS 几何修正后形成四个质心纵向速度候选；
   - 根据有限窗增量一致性、绝对一致性、锁定恢复状态和自适应测量方差筛选、加权；
   - 形成具有绝对速度参考能力的 WSS 虚拟传感器轨迹。

3. **独立 IMU 融合轨迹 `vxImuTrackFusion` / IMU 局部 KF 状态 `xI`**：`FINAL_METHOD`
   - 首次由有效 WSS 绝对速度初始化；
   - 初始化后不再由 `vxFusedPrev` 每拍重新锚定，而是使用偏置校正后的 `Ax` 独立递推；
   - 在轮速退化时承担主要速度维持作用。

### 1.3 最终可靠性融合解决的问题

`FINAL_METHOD`

Vx 最终融合不是 Vy 的 LifeSig 三轨迹融合，而是两通道相关融合：

- WSS、IMU 两个局部 KF 分别给出后验状态和方差；
- 递推两个局部估计之间的互协方差 `PWI`；
- 根据纵向动态强度和四轮健康度，只在最终融合层膨胀 WSS 有效协方差；
- 使用包含互协方差的最小方差权重融合 WSS 与 IMU 局部后验；
- 通道失效时退化为单通道输出，两通道均失效时保持上一有限速度。

它解决的是“正常状态依赖轮速绝对参考、轮速退化时转向 IMU、同时避免忽略相关性”的问题。项目中没有把该融合命名为 LifeSig，也没有证据支持把它写成 LifeSig 框架。

### 1.4 与后续车辆稳定性控制的接口

`FINAL_METHOD`

- 现有 MPC 控制器代码从 `u(33)` 读取纵向速度；设计接口为 `MPC u(33) <- vx_hat`。
- `vx_hat` 还应作为后续侧向速度 `Vy`、质心侧偏角及车辆稳定性控制计算的纵向速度基准。
- 质心侧偏角可在后续章节由 `beta = atan2(Vy_hat, vx_hat)` 或其小角度近似构造，但该计算不属于当前 Vx 估计器。

`NOT_VALIDATED`

当前活动的 `model/vx.slx` 中，旧纵向估计器块及 `vx_hat` Goto 处于 commented 状态，当前侧向估计链仍能读取 CarSim `Vx`。因此，不能宣称当前模型已经完成 `vx_hat -> MPC/Vy estimator` 的闭环替代验证。

---

## 2. 最终实际采用的方法

### 2.1 四轮 WSS 几何修正

`FINAL_METHOD`

- **输入**：四轮角速度、四轮转角、横摆角速度，轮序固定为 `[FL, FR, RL, RR]`。
- **输出**：四个质心纵向速度候选 `vxWheel(1:4)` 和几何有效标志。
- **状态量**：无，为纯运动学计算。
- **核心思想**：使用车轮位置、转角和横摆速度，把车轮滚动方向速度反解为质心纵向速度。
- **采样周期**：估计器真实更新周期 `Ts=0.01 s`。
- **冻结参数**：`Rw=0.393 m`、`a=1.18 m`、`b=1.77 m`、轮距 `d=1.575 m`、`vyPrior=0`、`cos_delta_min=0.20`。

### 2.2 双一致性滑移识别与锁定恢复

`FINAL_METHOD`

- **输入**：四轮速度候选、`Ax`、`AVz`、几何有效标志、复位信号。
- **输出**：有限窗增量误差 `eSlip`、绝对误差 `eAbs`、`rhoDelta`、`rhoAbs`、最终轮级置信度 `rhoWheel`、锁定状态和轮级有效标志。
- **状态量**：0.5 s FIFO、上一拍纵向加速度、每轮 `wheelLocked`、每轮 `wheelRecoverCount`。
- **核心思想**：
  1. 比较 0.5 s 内轮速速度增量与 IMU 纵向速度增量；
  2. 比较当前轮速候选与单步 IMU 检测轨迹；
  3. 两种置信度取最小值；
  4. 严重不一致时锁定车轮，只有双误差连续满足恢复阈值 30 个更新拍后才解锁。
- **采样周期**：100 Hz；窗口 50 个更新间隔。
- **冻结参数**：`e_low=eAbs_low=0.15 m/s`，`e_high=eAbs_high=0.50 m/s`，`rho_hard=0.05`，`eDelta_recover=eAbs_recover=0.12 m/s`，`Nrecover=30`。

当前代码的有限窗判据是**纵向标量增量差**。它没有实现早期规格中描述的三维 Rodrigues 姿态旋转和三维速度增量范数。论文必须按当前源代码写，不能把未实现的三维版本包装成最终算法。

### 2.3 WSS 虚拟传感器轨迹

`FINAL_METHOD`

- **输入**：四轮速度候选、轮级置信度、轮级有效标志。
- **输出**：`vxWssTrack`、等效测量方差 `RwssEquivalent`、轮级组合权重、`wssValid`。
- **状态量**：WSS 轨迹构造函数本身无内部状态。
- **核心思想**：置信度降低时增大单轮测量方差，只对有效轮进行逆方差归一化；四轮均无效时 WSS 通道退出融合。
- **采样周期**：100 Hz。
- **冻结参数**：`R0=1e-4 (m/s)^2`、`R_min=1e-6 (m/s)^2`、`R_max=1e4 (m/s)^2`、`epsilon=1e-8`。

### 2.4 独立偏置校正 IMU 轨迹

`FINAL_METHOD`

- **输入**：处理后的 CarSim `Ax`、当前阶段固定的 `vyPrior=0`、横摆角速度、首次可用绝对速度。
- **输出**：`vxImuTrackFusion`、累计轨迹方差 `PimuTrack`、`imuValid`。
- **状态量**：上一拍 IMU 轨迹速度、上一拍偏置校正加速度、上一拍累计轨迹方差、初始化标志。
- **核心思想**：首次使用 WSS 轨迹初始化绝对速度，之后使用偏置校正纵向加速度独立梯形积分，避免每拍重新使用当前融合速度而增加轨迹耦合。
- **采样周期**：100 Hz。
- **冻结参数**：`biasAxCal=0.02178105 m/s^2`；当前生效 `R_Ax=1.248708981650e-3 (m/s^2)^2`；`R_imuc_floor=R_imuc=1e-8 (m/s)^2`；加速度异常保护 `50 m/s^2`。

### 2.5 两个局部标量 Kalman 滤波器

`FINAL_METHOD`

- **输入**：WSS/IMU 轨迹及其测量方差。
- **输出**：`xW,PW,KW` 和 `xI,PI,KI`。
- **状态量**：两个标量纵向速度后验及其方差。
- **核心思想**：采用 `A=H=1` 的随机游走模型，避免在局部滤波器中再次使用已经进入轨迹构造的加速度。
- **采样周期**：100 Hz。
- **冻结参数**：`QW=1e-4 (m/s)^2/step`、`QI=2e-3 (m/s)^2/step`、`PW0=PI0=1e-4 (m/s)^2`。

### 2.6 互协方差相关融合及融合层协方差修正

`FINAL_METHOD`

- **输入**：两个局部 KF 后验、局部增益、上一拍互协方差、通道有效标志、`Ax`、四轮置信度和有效标志。
- **输出**：`vx_hat`、`P_fused`、`alphaW`、`alphaI`、内部 `PWI` 和条件数诊断。
- **状态量**：上一拍互协方差 `PWI_prev`、上一拍基线融合状态。
- **核心思想**：
  1. 用公共过程噪声递推局部估计互协方差；
  2. 用纵向动态因子 `sA` 和轮速健康因子 `sH` 膨胀最终融合使用的 WSS 方差；
  3. 在含互协方差的 2×2 协方差矩阵上计算相关融合权重。
- **采样周期**：100 Hz。
- **冻结参数**：`PWI0=0`、`a0=0.10 m/s^2`、`a1=2.706246 m/s^2`、`kA=30`、`kH=18`。

`DIAGNOSTIC_ONLY`

参数结构中的 `kD_fuse=0.08`、`kH_fuse=1.0` 和 `dWI_cap=0.50` 不控制当前最终输出；实际值由顶层函数中的 `a0/a1/kA/kH` 硬编码决定。

### 2.7 fallback、reset 与调用调度

`FINAL_METHOD`

- 外部按 1 kHz 调用，顶层以 `updateEvery=10` 实现 100 Hz 真正更新，其余调用保持上一整帧输出。
- 复位时清空顶层状态、窗口 FIFO、计数器、轮锁定状态和输出保持状态；初始速度取四轮 `Rw*omega` 有限值中位数。
- WSS 与 IMU 均有效：相关融合。
- 仅 WSS 有效：输出 `xW`。
- 仅 IMU 有效：输出 `xI`；持续超过 1 s 后内部 `degradedMode=true`。
- 两通道均无效：保持 `lastFiniteVx`，不主动输出零或 NaN。

`NOT_VALIDATED`

内部 fallback/degraded 逻辑已有测试代码，但没有发现当前最终代码版本的正式 MATLAB 测试报告，也没有真实 CarSim availability drop 或传感器故障仿真结果。

---

## 3. 论文必须保留的公式

### 3.1 四轮速度候选

\[
v_{x,i}^{WSS}=r y_i+
\frac{R_w\omega_i-(v_y^{prior}+r x_i)\sin\delta_i}
{\cos\delta_i},
\qquad v_y^{prior}=0.
\]

- `i`：FL、FR、RL、RR；
- `v_{x,i}^{WSS}`：第 `i` 轮反解的质心纵向速度，m/s；
- `R_w`：有效滚动半径，m；
- `omega_i`：车轮角速度，rad/s；
- `delta_i`：车轮转角，rad；
- `r`：横摆角速度，rad/s；
- `x_i,y_i`：车轮相对质心位置，m。

**作用**：修正四轮转向和横摆运动造成的轮速投影差异。  
**来源**：刚体运动学经典公式，按 4WIS 结构适配；车辆参数来自现有模型。

### 3.2 有限窗增量一致性

\[
\Delta v_{IMU,k}=
\sum_{j=k-N+1}^{k}
\frac{a_{x,j-1}+a_{x,j}}{2}T_s,
\]

\[
\Delta v_{WSS,i,k}=
v_{x,i,k}^{WSS}-v_{x,i,k-N}^{WSS},
\]

\[
e_{\Delta,i,k}=
\left|\Delta v_{WSS,i,k}-\Delta v_{IMU,k}\right|.
\]

- `Delta v_IMU`、`Delta v_WSS`、`e_Delta`：m/s；
- `N=50`，`Ts=0.01 s`，窗口长度 0.5 s。

**作用**：识别窗口内轮速速度变化与车身惯性速度变化不一致的车轮。  
**来源**：WSS/IMU 滑移识别文献思想；当前纵向标量形式属于本文实现适配。

### 3.3 绝对一致性与双置信度

\[
v_{I,k}^{det}=
\hat v_{x,k-1}^{base}+
\frac{T_s}{2}(a_{x,k-1}+a_{x,k}),
\]

\[
e_{abs,i,k}=\left|v_{x,i,k}^{WSS}-v_{I,k}^{det}\right|.
\]

对任一误差 `e` 采用分段线性映射：

\[
\rho(e)=
\begin{cases}
1,&e\le e_{low},\\
\dfrac{e_{high}-e}{e_{high}-e_{low}},&e_{low}<e<e_{high},\\
0,&e\ge e_{high}.
\end{cases}
\]

\[
\rho_i=\min(\rho_{\Delta,i},\rho_{abs,i}).
\]

- `e_abs`：m/s；`rho`：无量纲。

**作用**：增量判据检测变化不一致，绝对判据防止持续滑移后增量差重新变小导致误恢复。  
**来源**：分段置信度来自项目规格；双指标取最小值及锁定恢复是本文工程修改，当前未找到独立参考文献。

### 3.4 轮级自适应方差与 WSS 组合

\[
R_{i,k}=\operatorname{clip}
\left(
\frac{R_0}{\rho_{i,k}+\varepsilon},
R_{min},R_{max}
\right),
\]

\[
\gamma_i=\frac{R_i^{-1}}
{\sum_{j\in\mathcal V_k}R_j^{-1}},
\]

\[
z_{W,k}=\sum_{i\in\mathcal V_k}\gamma_i v_{x,i,k}^{WSS},
\qquad
R_{W,k}=\left(\sum_{i\in\mathcal V_k}R_i^{-1}\right)^{-1}.
\]

- `R_i`、`R_W`：`(m/s)^2`；
- `gamma_i`：无量纲。

**作用**：连续降低可疑车轮权重，并把有效车轮组合成 WSS 虚拟传感器。  
**来源**：经典逆方差组合；轮级方差随置信度变化为项目规格方法。

### 3.5 独立 IMU 传播轨迹

\[
a_{I,k}=A_{x,k}-b_{Ax},
\]

\[
z_{I,k}=z_{I,k-1}+
\frac{T_s}{2}(a_{I,k-1}+a_{I,k}),
\]

\[
P_{I,track,k}=P_{I,track,k-1}+
\frac{T_s^2}{2}R_{Ax}.
\]

- `a_I`：m/s²；
- `z_I`：m/s；
- `P_I,track`：`(m/s)^2`；
- `b_Ax=0.02178105 m/s^2`。

**作用**：构造在轮速退化时可独立传播的惯性速度轨迹。  
**来源**：梯形积分为经典公式；偏置和噪声方差为本文离线标定量。

### 3.6 两个局部标量 KF

对 `i in {W,I}`：

\[
x_{i,k}^{-}=x_{i,k-1}^{+},
\qquad
P_{i,k}^{-}=P_{i,k-1}^{+}+Q_i,
\]

\[
K_{i,k}=\frac{P_{i,k}^{-}}
{P_{i,k}^{-}+R_{i,k}},
\]

\[
x_{i,k}^{+}=x_{i,k}^{-}+
K_{i,k}(z_{i,k}-x_{i,k}^{-}),
\]

\[
P_{i,k}^{+}=(1-K_{i,k})P_{i,k}^{-}.
\]

**作用**：分别得到 WSS 和 IMU 局部后验。  
**来源**：经典标量 Kalman 滤波；`QW/QI` 为本文整定。

### 3.7 互协方差递推

\[
Q_{WI}=\frac{Q_W+Q_I}{2},
\]

\[
P_{WI,k}^{-}=P_{WI,k-1}^{+}+Q_{WI},
\]

\[
P_{WI,k}^{+}=
(1-K_{W,k})P_{WI,k}^{-}(1-K_{I,k}).
\]

- `P_WI`、`Q_WI`：`(m/s)^2`。

**作用**：保留两个局部滤波器因公共过程不确定性形成的相关性。  
**来源**：多虚拟传感器纵向车速融合文献相关融合公式的标量适配；`Q_WI` 取平均值是当前项目实现选择。

### 3.8 融合层 WSS 有效方差修正

\[
u_A=\operatorname{clip}
\left(\frac{|A_x|-a_0}{a_1-a_0},0,1\right),
\]

\[
s_A=3u_A^2-2u_A^3,
\]

\[
h_W=\frac{1}{4}\sum_{i=1}^{4}
\rho_i I_i^{valid},
\qquad
s_H=(1-h_W)^2,
\]

\[
P_{W,fuse}=P_W
\left(1+k_A s_A+k_H s_H\right).
\]

- `u_A,s_A,h_W,s_H`：无量纲；
- `a0,a1`：m/s²；
- `P_W,fuse`：`(m/s)^2`。

**作用**：强纵向动态或轮健康下降时，降低 WSS 在最终融合中的占比，但不改变轮级识别和 WSS 局部 KF。  
**来源**：本文启发式修正及离线整定；未找到正式参考文献。

### 3.9 相关最小方差融合

\[
\Phi_k=
\begin{bmatrix}
P_{W,fuse,k}&P_{WI,k}\\
P_{WI,k}&P_{I,k}
\end{bmatrix},
\]

\[
\alpha_k=\frac{\Phi_k^{-1}\mathbf 1}
{\mathbf 1^T\Phi_k^{-1}\mathbf 1},
\]

等价标量形式为：

\[
\alpha_W=\frac{P_I-P_{WI}}
{P_{W,fuse}+P_I-2P_{WI}},
\qquad
\alpha_I=\frac{P_{W,fuse}-P_{WI}}
{P_{W,fuse}+P_I-2P_{WI}},
\]

\[
\hat v_x=\alpha_Wx_W+\alpha_Ix_I,
\]

\[
P_f=\alpha_W^2P_{W,fuse}
+2\alpha_W\alpha_IP_{WI}
+\alpha_I^2P_I.
\]

**作用**：在局部估计相关的条件下计算最终速度和方差。  
**来源**：多虚拟传感器纵向车速融合文献中的互协方差最小方差融合公式。

### 3.10 fallback 逻辑

\[
\hat v_x=
\begin{cases}
\alpha_Wx_W+\alpha_Ix_I,&s_W=1,s_I=1,\\
x_W,&s_W=1,s_I=0,\\
x_I,&s_W=0,s_I=1,\\
\hat v_{x,lastFinite},&s_W=0,s_I=0.
\end{cases}
\]

**作用**：避免传感器失效时输出突变、零值或非有限数。  
**来源**：项目状态机设计。  
**验证状态**：`NOT_VALIDATED`，当前没有真实 CarSim 故障注入验证。

---

## 4. 最终冻结参数表

### 4.1 模型参数

| 参数 | 最终值 | 单位 | 来源 | 状态 |
|---|---:|---|---|---|
| 质心至前轴 `a` | 1.18 | m | 现有车辆模型 | `FINAL_METHOD` |
| 质心至后轴 `b` | 1.77 | m | 现有车辆模型 | `FINAL_METHOD` |
| 统一轮距 `d` | 1.575 | m | 现有车辆模型 | `FINAL_METHOD` |
| 有效滚动半径 `Rw` | 0.393 | m | CarSim/控制器参数 | `FINAL_METHOD` |
| 侧向速度先验 `vyPrior` | 0 | m/s | 当前阶段固定假设 | `FINAL_METHOD` |
| Simulink/CarSim 步长 | 0.001 | s | 现有模型 | `FINAL_METHOD` |
| 估计更新周期 `Ts_est` | 0.01 | s | 设计固定 | `FINAL_METHOD` |
| MPC 周期 | 0.02 | s | 现有控制器 | `FINAL_METHOD` |

### 4.2 滤波器与融合参数

| 参数 | 最终值 | 单位 | 来源 | 状态 |
|---|---:|---|---|---|
| `QW` | `1.0e-4` | `(m/s)^2/step` | 本文整定 | `FINAL_METHOD` |
| `QI` | `2.0e-3` | `(m/s)^2/step` | 本文整定 | `FINAL_METHOD` |
| `PW0` | `1.0e-4` | `(m/s)^2` | 固定初值 | `FINAL_METHOD` |
| `PI0` | `1.0e-4` | `(m/s)^2` | 固定初值 | `FINAL_METHOD` |
| `PWI0` | `0` | `(m/s)^2` | 固定初值 | `FINAL_METHOD` |
| `R0` | `1.0e-4` | `(m/s)^2` | 轮速方差基准 | `FINAL_METHOD`、标定依据不足 |
| `R_min` | `1.0e-6` | `(m/s)^2` | 数值保护 | `FINAL_METHOD` |
| `R_max` | `1.0e4` | `(m/s)^2` | 硬隔离上限 | `FINAL_METHOD` |
| `R_Ax` | `1.248708981650e-3` | `(m/s^2)^2` | 本文离线标定/第二次赋值 | `FINAL_METHOD` |
| `a0` | 0.10 | m/s² | 本文整定 | `FINAL_METHOD` |
| `a1` | 2.706246 | m/s² | 本文整定 | `FINAL_METHOD` |
| `kA` | 30 | — | 本文整定 | `FINAL_METHOD`、当前版本未在线复验 |
| `kH` | 18 | — | 本文整定 | `FINAL_METHOD`、当前版本未在线复验 |
| IMU-only 降级阈值 | 1.0 | s | 状态机设定 | `FINAL_METHOD` |

### 4.3 离线识别与轮健康参数

| 参数 | 最终值 | 单位 | 来源 | 状态 |
|---|---:|---|---|---|
| 滑移窗口 `Twindow` | 0.5 | s | 方法固定 | `FINAL_METHOD` |
| 窗口样本 `Nwindow` | 50 | step | `Twindow/Ts_est` | `FINAL_METHOD` |
| `e_low` | 0.15 | m/s | 本文整定 | `FINAL_METHOD` |
| `e_high` | 0.50 | m/s | 本文整定 | `FINAL_METHOD` |
| `eAbs_low` | 0.15 | m/s | 本文整定 | `FINAL_METHOD` |
| `eAbs_high` | 0.50 | m/s | 本文整定 | `FINAL_METHOD` |
| `rho_hard` | 0.05 | — | 本文整定 | `FINAL_METHOD` |
| `eDelta_recover` | 0.12 | m/s | 本文整定 | `FINAL_METHOD` |
| `eAbs_recover` | 0.12 | m/s | 本文整定 | `FINAL_METHOD` |
| `Nrecover` | 30 | update | 恢复滞回 | `FINAL_METHOD` |
| `biasAxCal` | 0.02178105 | m/s² | A/E 数据标定注释 | `FINAL_METHOD`、标定报告不足 |
| `cos_delta_min` | 0.20 | — | 数值保护 | `FINAL_METHOD` |
| `accelSanityMax` | 50 | m/s² | 异常值保护 | `FINAL_METHOD` |

`DIAGNOSTIC_ONLY`

- 参数文件中先出现 `R_Ax=1.53664e-3`，随后被 `1.248708981650e-3` 覆盖；论文只能使用后者。
- `v_low=0.30 m/s` 已定义但当前顶层未发现实际低速收敛逻辑，不应作为已生效方法参数重点描述。

---

## 5. 最终验证结果

### 5.1 结果证据边界

`VALIDATED_RESULT`

现有 A–H MAT 文件包含 16 s 的真实 Simulink/CarSim 输出：`est_u_data(16001×18)`、`est_y_data(16001×38)`、`Vx_true_data`、四轮转矩及时间轴。每组检测到 1599 个真正的估计更新点，更新间隔中位数为 0.01 s。因此可以确认保存结果对应的纵向估计器曾在线运行，而不是仅离线重放公式。

`NOT_VALIDATED`

MAT 文件没有保存 `QW/QI/a0/a1/kA/kH` 参数快照。现有“最终验证”脚本声明 A–H 在线结果使用 `a0=0.10、a1=2.706246、kA=70、kH=60`，但当前代码已改为 `kA=30、kH=18`。因此：

- 下表是**保存历史在线版本**的真实性能；
- 不能把下表直接标注为当前 `kA=30、kH=18` 版本的最终性能；
- 当前参数版本尚需重新产生带参数快照的正式结果后才能闭环冻结。

### 5.2 16 s 全局性能表

统一评价区间为 `t >= 0.6 s`；单位均为 m/s。

| 工况 | 可确认的速度轨迹 | WSS RMSE | IMU RMSE | Fused RMSE | Fused MAE | Fused MaxAbs | Fused Bias |
|---|---|---:|---:|---:|---:|---:|---:|
| A | 约 60 km/h 匀速 | 0.002830 | 0.017577 | 0.001787 | 0.001770 | 0.002181 | +0.001770 |
| B | 约 60→100 km/h 加速 | 0.120817 | 0.037938 | 0.011149 | 0.010064 | 0.023218 | +0.002978 |
| C | 约 100→60 km/h 减速 | 0.126267 | 0.024702 | 0.009566 | 0.005871 | 0.043750 | -0.000222 |
| D | 约 60→100→60 km/h 组合 | 0.174390 | 0.038407 | 0.015522 | 0.011520 | 0.052530 | -0.008936 |
| E | 约 40 km/h 匀速 | 0.000865 | 0.016278 | 0.000240 | 0.000205 | 0.000689 | +0.000035 |
| F | 约 40→70 km/h，后轮滑移 | 0.139395 | 0.031706 | 0.010526 | 0.006449 | 0.042735 | -0.001965 |
| G | 约 70→40 km/h，后轮锁定 | 0.078741 | 0.019552 | 0.011755 | 0.007365 | 0.033175 | +0.003068 |
| H | 约 40→70→40 km/h 组合 | 0.160082 | 0.031104 | 0.014836 | 0.010523 | 0.042735 | -0.004267 |

`VALIDATED_RESULT`

表中 Bias 按已有 MAT 的 100 Hz 更新点、`t>=0.6 s` 评价区间直接计算为 `mean(vx_hat-vx_true)`，未运行 MATLAB/Simulink/CarSim，也未生成新仿真。它仍属于保存历史在线版本的结果，不能归因于当前 `kA=30、kH=18` 参数版本。

### 5.3 滑移/锁定及恢复区间

`VALIDATED_RESULT`

| 工况及区段 | WSS RMSE | IMU RMSE | Fused RMSE | Fused MAE | Fused MaxAbs | Fused Bias | 平均 `alphaW` |
|---|---:|---:|---:|---:|---:|---:|---:|
| F 后轮滑移/锁定 5.778–7.999 s | 0.261937 | 0.048391 | 0.024932 | 0.022823 | 0.042735 | -0.022823 | 0.144781 |
| F 恢复 7.999–10.000 s | 0.004668 | 0.017220 | 0.003431 | 0.003379 | 0.009712 | +0.003283 | 0.938239 |
| G 后轮锁定 4.709–9.175 s | 0.131499 | 0.028391 | 0.018017 | 0.016886 | 0.033175 | +0.014522 | 0.170382 |
| G 恢复 9.175–11.175 s | 0.000881 | 0.003796 | 0.000683 | 0.000618 | 0.001527 | +0.000558 | 0.935938 |

这些结果支持“保存历史版本在轮速退化时降低 WSS 权重，并在恢复后重新提高 WSS 权重”。它们不证明当前 `kA=30、kH=18` 已在线复现同样结果。

### 5.4 实现验证与性能验证的区分

- 100 Hz 更新计数、38 维日志、有限输出：`VALIDATED_RESULT`，因为 A–H MAT 有真实运行数据。
- 顶层纯 MATLAB 单元测试：`NOT_VALIDATED`；测试文件存在，但状态文档明确记载 `WRITTEN, NOT EXECUTED`，且部分输出索引已与当前代码不一致。
- 0.2 s smoke：Vx 项目没有可作为最终论文证据的对应正式文件；即使存在短时 smoke，也只能归类为 `DIAGNOSTIC_ONLY`，不能作为性能结果。
- 当前 `kA=30、kH=18` 在线版本：`NOT_VALIDATED`。
- 当前 `vx_hat -> MPC u(33)` 闭环：`NOT_VALIDATED`。

### 5.5 工况元数据限制

`DIAGNOSTIC_ONLY`

A–H MAT 中的结构体字段被通用保存模板污染：所有 `caseName` 均为 `E`，`mu_commanded` 均保存为 0.3，`v0/v1` 字段也不是每个文件的真实轨迹描述。因此论文只能使用由真实 `Vx_true` 轨迹确认的速度过程；高/低附着标签和具体附着系数必须另有可信配置证据后才能正式写入。

---

## 6. 最终能够写进论文的结论

1. `FINAL_METHOD`：构建了四轮独立几何修正、轮级双一致性识别、自适应 WSS 轨迹、独立 IMU 轨迹、两个局部标量 KF 和互协方差相关融合的纵向车速估计结构。
2. `VALIDATED_RESULT`：保存的历史在线版本在 A–H 八个 16 s 工况中均以 100 Hz 更新并保持有限输出。
3. `VALIDATED_RESULT`：在已有八工况全局评价中，保存版本的融合 RMSE 均低于对应 WSS 和 IMU 局部 RMSE。
4. `VALIDATED_RESULT`：F/G 后轮退化阶段平均 WSS 权重分别降至约 0.145 和 0.170，恢复阶段回升到约 0.94，说明在线权重确实随轮健康状态变化。
5. `VALIDATED_RESULT`：F/G 退化区间的融合 RMSE 明显低于 WSS 局部 RMSE，并低于 IMU 局部 RMSE。
6. `FINAL_METHOD`：互协方差被显式递推，最终融合不是假定局部估计独立的简单逆方差融合。
7. `NOT_VALIDATED`：现有结果未证明当前硬编码 `kA=30、kH=18` 的代码版本具有上述相同性能。
8. `NOT_VALIDATED`：当前尚未完成真实 availability drop、传感器故障、四轮全失效和估计—控制闭环的 CarSim 验证。

---

## 7. 不得写进论文的结论

以下表述均没有当前证据支持：

1. 不得称当前 `kA=30、kH=18` 为“已通过八工况最终验证”。
2. 不得把保存 A–H 结果明确归因于当前参数版本，因为 MAT 未保存参数快照，验证脚本声明的是另一组 `kA/kH`。
3. 不得称融合为“全局统计最优”或“严格最优协方差融合”；最终 WSS 方差包含启发式动态/健康度膨胀，且标定证据不完整。
4. 不得称融合在所有时间区间都优于两个单轨迹；结论仅能使用已计算的全局和指定分段指标。
5. 不得称有限窗判据已经实现三维 Rodrigues 姿态补偿；当前源代码只实现纵向标量增量差。
6. 不得称 `eAbs`、轮锁定恢复或 `kA/kH` 修正具有现成文献理论保证；它们目前属于本文工程修改。
7. 不得称 `R0`、`e_low/e_high`、恢复阈值已经由正式无滑移统计过程完成论文级标定。
8. 不得称 IMU 偏置 `0.02178105 m/s^2` 已在多工况或实车上传感器标定；现有注释仅说明来自 A/E 标定。
9. 不得称 fallback、IMU-only 1 s 降级或双通道失效已经通过真实 CarSim 故障注入验证。
10. 不得称 `degradedMode`、`PWI` 和 `condPhi` 已按规格从当前 38 维输出对外记录；当前输出索引已被临时诊断量复用。
11. 不得称当前 `vx.slx` 已把 `vx_hat` 接入 MPC `u(33)` 或侧向速度估计器。
12. 不得把所有 MAT 文件中的 `mu_commanded=0.3` 当作每个工况的真实路面附着系数。
13. 不得宣称已经完成正常 4WIS 转向、单轮滑移、对开路面、四轮同时滑移、IMU NaN 或正式含噪声 CarSim 性能验证。
14. 不得宣称实车精度、实时硬件性能、任意附着路面泛化能力或控制稳定性提升。

---

## 8. 可作为研究过程说明但不进入最终算法的内容

### 8.1 简单独立逆方差融合为什么未采用

`ABANDONED_ROUTE`

WSS 与 IMU 局部估计共享车辆过程不确定性，且检测 IMU 轨迹与基线融合速度存在结构联系。若直接忽略互协方差，会把两条轨迹视为独立信息源，可能低估融合不确定性。最终方法因此保留 `PWI` 递推和相关融合公式。

论文讨论部分可以说明“忽略相关性的逆方差融合不满足当前架构假设”，但不需要展开早期开发编号或测试流水账。

### 8.2 仅用窗口增量判据的局限

`DIAGNOSTIC_ONLY`

持续滑移时，轮速与 IMU 的窗口增量差可能重新变小，造成轮置信度错误恢复。当前方法增加 `eAbs` 和锁定恢复滞回，属于针对该现象的工程修正。论文可用于解释设计动机，但不能声称已形成普适的统计检验理论。

### 8.3 仅按加速度修正 WSS 权重的局限

`DIAGNOSTIC_ONLY`

强动态不必然等同于轮速失真，因此最终修正同时考虑 `sA` 与基于轮级置信度的 `sH`。该结论可放在方法讨论中，用于说明为何不能只凭 `abs(Ax)` 判定 WSS 可靠性。

### 8.4 旧参数扫描与旧在线版本

`ABANDONED_ROUTE`

项目中存在 `kA=70、kH=60`、`kD/kH` 网格扫描和多种离线重放脚本。这些资料可以用于追溯当前设计来源，但不能作为最终算法描述。论文正文只写当前源代码实际生效的 `kA=30、kH=18`，同时把其在线验证状态明确标为未完成。

### 8.5 早期三维 Rodrigues 方案

`ABANDONED_ROUTE`

规格文档描述过三维速度增量和 Rodrigues 相对姿态更新，但当前最终执行函数没有该实现。除非后续重新实现并验证，否则论文只能在相关工作或设计演化讨论中简短提及，不能列为最终算法步骤。

---

## 9. 论文需要使用的文件清单

### A. 写论文必须看（不超过 10 个）

1. `model/longitudinal_velocity_estimator.m`
   - 当前最终执行架构、独立 IMU 轨迹、锁定恢复、融合层方差膨胀、fallback 和实际输出映射。
2. `model/estimator_default_params.m`
   - 当前真正生效的车辆、滤波、滑移识别和数值保护参数。
3. `model/window_delta_velocity_indicator.m`
   - 当前实际有限窗纵向标量增量公式及 FIFO 时序。
4. `model/slip_confidence_mapping.m`
   - `rhoDelta/rhoAbs/rhoRaw` 和轮级自适应方差公式。
5. `model/correlated_two_track_fusion.m`
   - 互协方差、相关融合权重、融合方差和通道退化公式。
6. `docs/STAGE_2A_FUSION_FORMULAS.md`
   - 相关融合方法的最简论文公式来源映射。
7. `docs/STAGE_3E2_STATUS.md`
   - `eAbs`、锁定恢复和 100 Hz 门控的最终设计说明；参数值必须以当前代码为准。
8. `tests/results_case_A.mat` 至 `tests/results_case_H.mat`
   - 已有 16 s 在线性能和轮健康权重变化的原始数据；必须整体作为一组使用。
9. `tests/tiaocan/validate_final_ABCE.m`、`validate_online_kH60_FG.m`
   - 用于理解保存结果的评价窗口、工况标签和历史参数版本，不用于定义当前参数。
10. `specs/signal_interface.md`
   - 在线输入、真值隔离和 `MPC u(33)` 设计接口；注意当前输出索引与源代码冲突。

### B. 需要追溯时再看

- `specs/implementation_spec.md`：追溯最初方法约束、参考论文映射和计划验证矩阵。
- `docs/STAGE_2B_SLIP_FORMULAS.md`、`docs/STAGE_2_FORMULA_MAP.md`：追溯轮速/IMU 滑移识别理论来源。
- `docs/STAGE_3A_STATUS.md` 至 `docs/STAGE_3D2A_IMPLEMENTATION_STATUS.md`：追溯各纯函数的公式冻结，但不要当作运行结果。
- `docs/STAGE_3E_STATUS.md`、`docs/STAGE_3E1_IMPLEMENTATION_STATUS.md`：追溯顶层 reset、调度和失效模式；其输出接口描述已部分过时。
- `tests/test_four_wheel_kinematic_speed.m`、`test_stage2_wss_candidate_and_window.m`、`test_slip_confidence_mapping.m`、`test_wss_track_builder.m`、`test_correlated_two_track_fusion.m`：追溯预期边界条件；无正式执行报告。
- `tests/tiaocan/scan_kA_after_QI_fixed_BCDH.m`、`scan_kH_FG.m`：追溯 `QI/kA/kH` 的离线候选来源；属于离线识别证据，不是当前在线验证。
- `tests/fusion_health_scan_results.csv`：追溯较早的融合健康参数扫描；不应直接作为最终性能表。
- `model/vx.slx.original`：只在追溯历史纵向估计器接线时查看，不能代表当前活动模型。

### C. 完全不需要为了写论文去看

以下类型应从论文写作资料包中排除：

- `*.slxc` 编译缓存；
- `*_compile*.mat`、`*_build*.mat`、compile harness；
- 仅含哈希、文件清单、路径或工程门禁的 `*_evidence.csv`；
- `*_slx_diff_audit.csv`、semantic diff、prefdir diff、inventory；
- batch re-entry、completion watch、stall forensics、termination closure；
- CarSim 路径修复、MATLAB 启动错误、prefdir/设置修复；
- builder 生命周期、缓存清理、GUI recovery、进程快照；
- runtime authorization、run card、phase marker、hash-only freeze；
- `.autosave`、`.asv`、临时模型副本和临时调参脚本；
- `tests/V1_backup/` 中的候选或备份实现；
- 与 Vy 的 A3R8R1/A3R8R2 等纯工程 debug 文档；
- 所有 `STAGE_VY_*` 文件，除非论文正在写 Vy 章节；它们不属于 Vx 方法证据；
- `model/vx.slx` 中与后续 Vy D-EKF/K-KF/LifeSig 开发有关的日志和状态文件；
- `estimator_test.mat`、`estimator_analysis.mat`：未形成可追溯的 Vx 最终参数/指标清单，论文价值低于 A–H 原始数据。

---

## 10. 最终“论文写作最小资料包”

### 方法来源文件

1. `model/longitudinal_velocity_estimator.m`
   - 写最终流程、轨迹关系、调度、锁定恢复、融合层修正和 fallback。
2. `model/window_delta_velocity_indicator.m`
   - 写有限窗增量一致性公式，防止误用规格中的三维未实现版本。
3. `model/slip_confidence_mapping.m`
   - 写双置信度和自适应轮级方差。
4. `model/correlated_two_track_fusion.m`
   - 写局部估计互协方差和相关融合公式。
5. `docs/STAGE_2A_FUSION_FORMULAS.md`
   - 对照基础参考论文中的局部 KF、互协方差和融合公式。

### 最终参数文件

6. `model/estimator_default_params.m`
   - 提取所有生效参数；注意 `R_Ax` 使用第二次赋值，`kA/kH` 不在该文件而在顶层硬编码。

### 最终性能结果文件

7. `tests/results_case_A.mat` 至 `tests/results_case_H.mat`
   - 生成 WSS/IMU/Fused 曲线、RMSE/MAE/MaxAbs 表和 F/G 权重恢复图；必须注明是历史在线版本，参数快照缺失。
8. `tests/tiaocan/validate_final_ABCE.m` 与 `tests/tiaocan/validate_online_kH60_FG.m`
   - 只用于确认评价窗口、工况名称和历史结果对应的旧参数声明。

### 最终 freeze 文件

9. `docs/STAGE_3E2_STATUS.md`
   - 当前 Vx 项目最接近顶层最终状态的文档；只能作为辅助，最终事实以源代码为准。

当前项目没有发现可同时冻结“源代码哈希、参数快照、模型接线和 A–H 性能”的单一 Vx final-freeze 文件。这一缺口必须在论文中通过限定措辞处理，不能用旧状态文档代替。

### 参考论文

10. `references/精读1Longitudinal_Vehicle_Speed_Estimation_for_Four-Wheel-Independently-Actuated_Electric_Vehicles_Based_on_Multi-Sensor_Fusion*.pdf`
    - 用于局部 Kalman 滤波、互协方差递推和相关最小方差融合的理论来源。
11. `references/精读2Vehicle velocity estimation based on WSS_IMU with wheel slip recognition*.pdf`
    - 用于四轮独立滑移识别、WSS/IMU 速度增量一致性和失效轮降权思想的理论来源。

---

## 最终清洗结论

```text
THESIS_MUST_READ_FILES = [
  "model/longitudinal_velocity_estimator.m",
  "model/estimator_default_params.m",
  "model/window_delta_velocity_indicator.m",
  "model/slip_confidence_mapping.m",
  "model/correlated_two_track_fusion.m",
  "docs/STAGE_2A_FUSION_FORMULAS.md",
  "docs/STAGE_3E2_STATUS.md",
  "tests/results_case_A.mat ... tests/results_case_H.mat",
  "tests/tiaocan/validate_final_ABCE.m",
  "tests/tiaocan/validate_online_kH60_FG.m"
]

THESIS_OPTIONAL_FILES = [
  "specs/implementation_spec.md",
  "specs/signal_interface.md",
  "docs/STAGE_2B_SLIP_FORMULAS.md",
  "docs/STAGE_2_FORMULA_MAP.md",
  "docs/STAGE_3A_STATUS.md ... docs/STAGE_3D2A_IMPLEMENTATION_STATUS.md",
  "tests/test_*velocity*.m",
  "tests/test_slip_confidence_mapping.m",
  "tests/test_correlated_two_track_fusion.m",
  "tests/tiaocan/scan_kA_after_QI_fixed_BCDH.m",
  "tests/tiaocan/scan_kH_FG.m",
  "tests/fusion_health_scan_results.csv",
  "model/vx.slx.original"
]

THESIS_IGNORE_FILE_PATTERNS = [
  "*.slxc",
  "*.autosave",
  "*.asv",
  "*_compile*",
  "*_build*",
  "*_slx_diff_audit.csv",
  "*semantic_diff*.csv",
  "*prefdir*.csv",
  "*inventory*.csv",
  "*phase_marker*.csv",
  "*runtime_authorization*.csv",
  "*run_card*.csv",
  "*stall*",
  "*termination*",
  "*startup_error*",
  "tests/V1_backup/*",
  "docs/STAGE_VY_*",
  "results/vy_*"
]
```
