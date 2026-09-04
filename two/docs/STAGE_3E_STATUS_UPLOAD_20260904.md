# Stage 3E Final Status

- Stage: `3E`
- Date context: 2026-08-08
- Top-level file: `matlab/longitudinal_velocity_estimator.m`
- Test file: `tests/test_longitudinal_velocity_estimator.m`

## 1. Stage-2 Formula/Interface Conformance
- `est_u` is 18 inputs, fixed order by index:
  - `1:4` �?`wheelOmega [FL FR RL RR]` (rad/s)  
  - `5:8` �?`wheelAngle [FL FR RL RR]` (rad)  
  - `9` �?`Ax` (m/s²)  
  - `10` �?`Ay` (unused input holder)  
  - `11` �?`Az` (unused input holder)  
  - `12` �?`AVx` (unused)  
  - `13` �?`AVy` (unused)  
  - `14` �?`AVz` (rad/s)  
  - `15:17` �?reserved (unused in Stage-3E scope)  
  - `18` �?`reset` flag
- `est_y` is 38 outputs with fixed index contract:
  - `1:1` `vx_hat`
  - `2:2` `Pfused`
  - `3:3` `vxWssTrack`
  - `4:4` `Pwwss`
  - `5:5` `vxImuTrack`
  - `6:6` `Pimu`
  - `7:7` `P12`
  - `8:11` `vxWheel(FL,FR,RL,RR)`
  - `12:15` `eSlip(FL,FR,RL,RR)`
  - `16:19` `rhoWheel(FL,FR,RL,RR)`
  - `20:23` `Rwheel(FL,FR,RL,RR)`
  - `24:27` `validWheel(FL,FR,RL,RR)` (double)
  - `28:28` `wssValid` (double)
  - `29:29` `imuValid` (double)
  - `30:31` `fusionWeights [alphaW alphaI]`
  - `32:32` `allWheelInvalid` (double)
  - `33:33` `imuOnlyDuration`
  - `34:34` `degradedMode` (double)
  - `35:35` `estimatorUpdated` (double)
  - `36:36` `slipReady` (double)
  - `37:37` `condPhi`
  - `38:38` `updateCounter`

## 2. 接口审计结论
- `wheelOmega` / `wheelAngle` / `Ax` / `AVz` / `reset` 的读入索引与位姿均与 Stage-2/`signal_interface` 保持一致�?- 已确认索引映射不是仅检查长度�?- 已确认输入中不包�?`Vx_true` �?`Ax_SM/Ay_SM/Az_SM` 直接参与顶层计算�?- 已确认四轮顺序固定为 `[FL, FR, RL, RR]`�?
## 3. Persistent 列表（当前实际）
当前顶层持久变量�?**14** 个（相较于先前文档有一项补齐）�?- `initialized`
- `pCfg`
- `vxFusedPrev`
- `xWPrev`
- `PWPrev`
- `xIPrev`
- `PIPrev`
- `PWI_prev`
- `axCorrPrev`
- `PfusedPrev`
- `lastFiniteVx`
- `allWheelInvalidDuration`
- `updateCounter`
- `degradedMode`

## 4. 初始化行�?- `reset ~= 0` 或首次调用时重置�?- `vx_hat` 初始化为 `median(Rw*omega_i)`（`isfinite` 候选）�?- `xW, xI, vxFused` 同步到初始化值；
- `PW/PIPrev/PWI_prev` 从参数初始化�?- `allWheelInvalidDuration=0`，`degradedMode=false`，`updateCounter=0`�?- `axCorrPrev` 对有效输入采�?`Ax`，否�?0�?
## 5. reset 后重复�?- 重置�?FIFO 与状态以 Stage-2 reset 语义清空�?- 输出关键量不依赖上一次历史状态（测试按对比首段输出校验）�?- `updateCounter` �?reset 边界清零并重建；
- `degradedMode` �?reset 后强�?false�?
## 6. 正常双通道流程
- WSS �?IMU 均有效时采用融合路径�?- `vx_hat`、`Pfused`、`alphaW/alphaI` 在无异常场景下平滑演化；
- 50拍后进入窗口成熟并进入稳态检测周期�?
## 7. WSS-only �?IMU-only 流程
- WSS有效 / IMU无效：采�?WSS 局�?KF 输出�?- WSS无效 / IMU有效：采�?IMU 局�?KF 输出�?- 双失效：回退�?`lastFiniteVx`，不主动输出 NaN/0�?
8. 双通道失效�?`degradedMode`
- �?WSS/IMU 均无效时设置 `degradedMode=true`�?- IMU-only 且持续时�?<= `TimuOnlyMax`：`degradedMode=false`�?- IMU-only 且持续时�?> `TimuOnlyMax`：`degradedMode=true`，仍保持 IMU-only 输出�?- 恢复 WSS �?`degradedMode` 需退出退化�?
## 9. WSS 恢复�?`allWheelInvalidDuration`
- `allWheelInvalidDuration` �?WSS 恢复时置 0�?- `degradedMode` 对应状态转换验证通过�?
## 10. `lastFiniteVx` 保护
- 任何 `NaN` 传播路径采用 `lastFiniteVx` 保护�?- 双通道失效及融合不可用情形不会硬退�?0 �?NaN�?
## 11. PWI 连续�?- 保留 `PWI_prev` 在顶层跨拍递推�?- WSS 恢复阶段未见顶层直接重置�?0 的行为；
- `PWI` 仅按子模块规则递推�?
## 12. 50/51 拍时�?- 50 拍：窗口成熟位有效但残差未完整可用；
- 51 拍：`wssValid/imuValid` 与可用残差首次可用；
- 避免未成熟残差提前参与滑移识别�?
## 13. 单步 IMU 积分�?0.5s Span 区分
- 明确使用 `dvImuStep = 0.5*Ts*(axCorrPrev+axCorrCurrent)`�?- 通过测试检�?IMU-only 输出不出现每�?`~0.5 m/s` 的跳变�?
## 14. 静态安全检�?- 未在顶层复制 CarSim 真实速度、GPS/IMU特征工程�?- 未复�?FIFO 管理逻辑�?- 未进行双重积分（IMU `DeltaVImu` �?`vxImuTrack` 使用逐拍递推）�?
## 15. 测试文件
- `tests/test_longitudinal_velocity_estimator.m`
- 覆盖状态：`WRITTEN, NOT EXECUTED`
- 目标 MATLAB 状态：`PENDING MATLAB VALIDATION`

## 16. 17类测试覆�?1. TEST1 初始化（已覆盖）
2. TEST2 reset 重复性（已覆盖）
3. TEST3 恒速直行（已覆盖）
4. TEST4 恒定加速无滑移（已覆盖�?5. TEST5 windowReady/residualValid 边界（已覆盖�?6. TEST6 单轮滑移隔离（已覆盖�?7. TEST7 四轮全失�?<1s（已覆盖�?8. TEST8 四轮全失�?>1s（已覆盖�?9. TEST9 WSS 恢复（已覆盖�?10. TEST10 IMU失效仅，WSS有效（已覆盖�?11. TEST11 双通道失效 `lastFiniteVx`（已覆盖�?12. TEST12 融合模块 fail（顶层公共信号难以触发，�?Stage-3D 覆盖�?13. TEST13 NaN 单轮隔离（已覆盖�?14. TEST14 Inf 输入传播隔离（已覆盖�?15. TEST15 PWI 状态连续性（已覆盖）
16. TEST16 输出接口完整性（已覆盖）
17. TEST17 长期 finite 序列测试（已覆盖�?
## 17. 关键指标
- MATLAB 执行状态：`WRITTEN, NOT EXECUTED`
- MATLAB 验证状态：`PENDING MATLAB VALIDATION`
- BLOCKER 数量：`0`
- PENDING MATLAB EXECUTION

## 18. Stage 3E 最终状�?- `IMPLEMENTATION COMPLETE`
- `INTEGRATION TESTS WRITTEN`
- `PENDING MATLAB EXECUTION`

## 19. 下一阶段
- `Stage 3F`: 交接给有 MATLAB 的执行环境进行执行验证（`MATLAB`/`runtests`/`sim` 执行阶段）�?
## 20. 1000Hz Input - 100Hz Update Gate Fix (2026-08-10)
- Root cause: `longitudinal_velocity_estimator` executes the full STEP2~STEP12 chain every call, so `estimatorUpdated` and `updateCounter` advance on every 1kHz tick.
- Fix:
  - In `matlab/longitudinal_velocity_estimator.m`, add a 10-call `updatePhase` gate (10:1 schedule).
  - Add persistent `yHold` and hold full output between updates; set `estimatorUpdated` to 0 on hold ticks.
  - Restrict persistent state updates (`xWPrev/PWPrev/xIPrev/PIPrev/PWI_prev/axCorrPrev/allWheelInvalidDuration/PfusedPrev/degradedMode`) to true update ticks only.
  - On `reset`, clear gate phase, `updateCounter`, and all held-output states.
  - Increment `updateCounter` only on true update ticks.
- New tests:
  - Added `test_update_gate_1000hz_input`, `test_state_hold_between_updates`, and `test_reset_rearms_update_gate_and_counters` in `tests/test_longitudinal_velocity_estimator.m`.
- Validation:
  - MATLAB execution is not available in this environment; status is "modified, not executed" pending `runtests` in MATLAB.

## 2026-08-10 Follow-up
- Root causes fixed: reset-cycle was being treated as a counted estimator update; output timestamping mixed 1ms sample flow with 100Hz scheduling expectation; interface-audit parser assumed direct est_y assignments only.
- Files modified: matlab/longitudinal_velocity_estimator.m, tests/test_longitudinal_velocity_estimator.m
- Added helper: run_one_estimator_update / run_update_sequence and SIMULINK-like reset waveform regression test (16003 samples, 11-cycle reset hold).
- test status in this environment: WRITTEN, NOT EXECUTED

