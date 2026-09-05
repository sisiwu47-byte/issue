# Stage 3E2 Status

- Date: 2026-08-11
- Scope: Fix lock-on of wheel confidence under persistent slip and dual-criterion recovery.
- Stage files updated:
  - `matlab/estimator_default_params.m`
  - `matlab/slip_confidence_mapping.m`
  - `matlab/longitudinal_velocity_estimator.m`
  - `tests/test_estimator_default_params.m`
  - `tests/test_slip_confidence_mapping.m`
  - `tests/test_wheel_lock_recovery.m`

## 根因修复

1. 门控 off-by-one
- 统一将 1kHz 调度的门控定义为“倒计时到 0 更新”，`reset` 后立即清零并在下一拍更新。
- 更新后计数设为 `updateEvery - 1`，确保首个非 reset 样本即更新、后续严格 9 个 hold tick。

2. 功能测试时基
- 保持 `run_update_sequence` 的语义为每个测试样本返回一次“100Hz 逻辑更新结果”（内部通过 `run_one_estimator_update` 在最多 20 个 1ms 样本内等待一次真正更新）。
- 保留门控测试的 1ms 逐调用方式，避免混用。

3. interface_audit 解析
- `parse_index_token` 扩展到支持方括号、逗号、空白拼接与多区间 token，避免因打包风格变化造成 `est_y(1:38)` 误报为缺失。

4. 复位完整性
- top-level 门控、计数、持久状态、协方差、输出持有状态等已按 reset 清零；保留 `run_update_sequence` 覆盖场景。

## 本轮修复（仅三项测试）

- 100Hz 门控、`est_y` 维度、融合链路及控制器输入接口保持不变。  
- 新增绝对一致性判据：
  - `eAbs_low = 0.20 m/s`
  - `eAbs_high = 0.80 m/s`
  - `rhoAbs = 1` / 线性下降 / `0` 分段
  - `rhoRaw = min(rhoDelta, rhoAbs)`  
- 新增恢复滞回状态机：
  - `p.eDelta_recover = 0.10 m/s`
  - `p.eAbs_recover = 0.18 m/s`
  - `p.Nrecover = 30`
  - `wheelLocked` / `wheelRecoverCount` 持续变量仅在 100Hz 实际更新步长里更新。  
- `vxImuTrack` 计算已前移到 `eSlip` 与 `slip_confidence` 之间，用于 eAbs 计算，且不参与当前轮次的 WSS 有效性或置信度路径。  

## 当前轮修复（eAbs + 滑移锁定恢复修订）

- 修复 `slip_confidence_mapping` 在调用端的输出约束：主估计器改为按
  `[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs]` 接收，避免与
  `rhoDelta/rhoAbs/rhoRaw` 解码错位导致的错误解锁。  
- 明确 `eAbs` 映射与 `rhoAbs` 映射公式：`eAbs <= eAbs_low` 取 1，
  `eAbs >= eAbs_high` 取 0，中间线性下降。  
- 补齐 `tests/test_slip_confidence_mapping.m`：
  - `eAbs` 低阈值边界（0.20）；
  - 高 `eDelta` 低 `eAbs` 仍应失效；
  - 现有高 `eAbs` / 低 `eDelta` 反例覆盖保留。  

### 验收状态

- 未修改：`Ts_sim=0.001`、`Ts_est=0.01`、`updateEvery=10`、`est_u` 与
  `est_y` 长度与索引。  
- 运行结果未执行（当前环境未提供 MATLAB）。  

## 本轮修复（测试端对齐）

- 日期：2026-08-11
- 已完成修改：
  - `tests/test_wheel_lock_recovery.m`
    - 修正 `expand_update_profile` 的广播：`updateOmega`、`updateAngle`、`updateAx`、`updateAvz`、`updateReset` 由单点扩展到 10 个 1ms 样本。
    - 重构 `test_non_update_hold_cycle_stable`，将 hold 周期判定改为“`estimatorUpdated==0` 时与上一样本比较”，避免以首个 hold 样本作为参照的脆弱假设。
  - `tests/test_longitudinal_velocity_estimator.m`
    - `test_persistent_audit_vs_stage3e1` 增补 `wheelLocked`、`wheelRecoverCount` 持久变量并更新期望数量为 18。
    - `test_wss_recovery` 改为按 100Hz 更新节拍验证 30 次连续恢复更新要求：前 29 次保持无效，第 30 次允许恢复，避免把 1ms 调用误算为更新次数。
- 未改动核心算法实现文件；本轮仅对测试文件进行语义对齐。  

## 测试
- `tests/test_wheel_lock_recovery.m`: 新增 5 个针对性用例，覆盖：
  - `eDelta/eAbs` 双指标分离；
  - 锁定后高 eAbs 下不恢复；
  - 29/30 连续恢复计数；
  - 恢复中断后计数复位；
  - reset 清空锁状态；
  - 非更新 tick 持有稳定性。  
- `tests/test_slip_confidence_mapping.m`: 新增 eAbs 映射和严重滑移示例用例（高 eAbs/低 eDelta）。  
- `tests/test_estimator_default_params.m`: 新增 `eAbs_*` 与恢复参数字段与固定值校验。
