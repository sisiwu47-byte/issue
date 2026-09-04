# STAGE 3E1 IMPLEMENTATION STATUS

- Top-level filename: `matlab/longitudinal_velocity_estimator.m`
- Function interface:
  - Input: `est_u` (at least 18x1, Stage-2 fixed order)
  - Output: `est_y` (38x1)
- Input size (from Stage-2 freeze/signal interface):
  - `wheelOmega = est_u(1:4)`
  - `wheelAngle = est_u(5:8)`
  - `Ax = est_u(9)`
  - `AVx,AVy,AVz = est_u(12:14)`
  - `reset = est_u(18)`
- Output mapping: follows `docs/STAGE_2_FORMULA_MAP.md` `est_y` order 1..38.

## 1) Persistent状态
- `initialized`
- `pCfg`
- `vxFusedPrev`
- `xWPrev`
- `PWPrev`
- `xIPrev`
- `PIPrev`
- `PWI_prev`
- `axCorrPrev`
- `lastFiniteVx`
- `allWheelInvalidDuration`
- `updateCounter`
- `degradedMode`

## 2) 初始化
- 首次调用或 `reset != 0` 时执行 Stage-2 初始化。
- `vx0 = median(p.Rw * omega_i)`，仅使用 `isfinite` 的四轮速度。
- 四轮全无效时按保护策略设为 `0` 并完成状态重置。
- 置 `vxFusedPrev = xWPrev = xIPrev = vx0`。
- 置 `PWPrev = p.PW0, PIPrev = p.PI0, PWI_prev = p.PWI0`。
- 置 `allWheelInvalidDuration = 0`，`degradedMode = false`，`updateCounter = 0`。
- 重置时将 `window_delta_velocity_indicator` 以 `reset=1` 调用以清空其 FIFO。

## 3) 100 Hz 执行顺序（逐条）
1. 读入 `est_u`，提取固定输入。
2. `four_wheel_kinematic_speed(wheelOmega, wheelAngle, yawRate, vyPrior, p)`。
3. `window_delta_velocity_indicator(Ax, AVz, vyPrior, vxWheel, validGeom, resetFlag, p)`。
4. `slip_confidence_mapping(eSlip, residualValid, validGeom, p)`。
5. `wss_track_builder(vxWheel, Rwheel, validWheel)`。
6. 形成 IMU 单拍积分轨迹。
7. 判定 `imuValid`（基于 IMU 生存性与轨迹有效性）；不因 `wssValid` 变化。
8. WSS 本地 KF：`local_scalar_kf_step(xWPrev, PWPrev, vxWssTrack, RwssEquivalent, p.QW, wssValid, p)`。
9. IMU 本地 KF：`local_scalar_kf_step(xIPrev, PIPrev, vxImuTrack, R_imu_step, p.QI, imuValid, p)`。
10. 相关融合：`correlated_two_track_fusion(xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p)`。
11. 对 `fusionValid` 与双通道状态机结果做顶层保护。
12. 更新跨拍状态与 `PWI_prev`，更新 `allWheelInvalidDuration` 与 `degradedMode`。

## 4) IMU单拍递推公式
- `axCorrCurrent = Ax + AVz * vyPrior`，`vyPrior = 0`。
- `dvImuStep = 0.5*Ts_est*(axCorrPrev + axCorrCurrent)`（复位周期设 `0`）。
- `vxImuTrack = vxFusedPrev + dvImuStep`。
- `axCorrPrev <- axCorrCurrent`。
- 明确未使用 `DeltaVImu`（0.5s 窗）替代该单拍递推。

## 5) WSS链调用顺序
- `validGeom` -> `residualValid` -> `rhoWheel/Rwheel/validWheel` -> `vxWssTrack/RwssEquivalent/alphaWheel/wssValid`。
- `residualValid` 明确作为滑移映射有效性入口；未混淆为 `windowReady`。

## 6) 两个局部KF
- WSS: 用 `wssValid` 作为 `measurementValid`。
- IMU: 用 `imuValid` 作为 `measurementValid`。
- 采用现有 `local_scalar_kf_step`，未复制 KF 公式。

## 7) PWI 保存时序
- 每拍调用相关融合后保存 `PWI_plus -> PWI_prev`。
- 无论哪种通道失效均按相关融合规则更新，不在 WSS 恢复后手动清零。

## 8) 两通道失效状态机
- Case A: `wssValid && imuValid` -> 融合结果。
- Case B: `~wssValid && imuValid` -> 用 IMU 本地输出。
- Case C: `wssValid && ~imuValid` -> 用 WSS 本地输出。
- Case D: `~wssValid && ~imuValid` -> 使用 `lastFiniteVx`，不输出 NaN。

## 9) allWheelInvalidDuration
- 当 `~wssValid && imuValid` 时累加 `+Ts_est`。
- 当 `wssValid` 时清零。
- `~wssValid && ~imuValid` 时保持不变。

## 10) degradedMode
- `wssValid=true`：`degradedMode=false`。
- `~wssValid && imuValid`：`degradedMode = (allWheelInvalidDuration > TimuOnlyMax)`。
- `~wssValid && ~imuValid`：`degradedMode=true`。
- `reset` 周期强制 `degradedMode=false`。

## 11) lastFiniteVx
- 始终保留上一次合法控制估计。
- 顶层输出 `vx_hat` 在双通道无效/异常时回退到 `lastFiniteVx`。
- 仅在本拍 `vx_hat` 合法后更新。

## 12) fusionValid 异常
- `fusionValid=false` 时不直接写 NaN 到控制输出。
- 通过 Case D 回退到 `lastFiniteVx`。

## 13) 静态检查
- `Vx_true`：未出现。
- `GPS`：未出现。
- `Ax_SM/Ay_SM/Az_SM`：未作为计算输入使用。
- 四轮顺序 `[FL, FR, RL, RR]`：保持。
- 重复实现四轮运动学：未出现（仅调用 `four_wheel_kinematic_speed`）。
- 重复 FIFO：未出现（仅依赖 `window_delta_velocity_indicator` 的内部持久状态）。
- 重复 rho 映射：未出现（仅调用 `slip_confidence_mapping`）。
- 重复相关融合：未出现（仅调用 `correlated_two_track_fusion`）。
- IMU 递推未复用 `DeltaVImu`。
- 未检测到双重积分：单拍轨迹与窗口积分职责分离。
- 无代数环：`vxImuTrack` 仅依赖上拍 `vxFusedPrev`。
- 所有递推状态来自上一拍持久变量。
- `wssValid=false` 时未将 `NaN vxWssTrack` 输入局部KF（`measurementValid=false` 保护）。
- 双通道无效时输出回退到 `lastFiniteVx`，`est_y(1)` 保持有限。
- 顶层未引入独立逆方差融合。
- `PWI` 未被无故置零。

## 14) MATLAB 验证状态
- `MATLAB_VALIDATION = PENDING MATLAB VALIDATION`（按本线程约束未运行 `matlab/runtests/sim`）。

## 15) INTERFACE_BLOCKER
- `INTERFACE_BLOCKER = 0`
- `BLOCKER 数量 = 0`

## 16) 下一阶段
- 下一阶段：`Stage 3E2`（顶层集成测试）。
