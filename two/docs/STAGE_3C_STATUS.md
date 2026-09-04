# Stage 3C Final Status

- Stage: `3C`
- Stage-2 formula source: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB validation state: `PENDING MATLAB VALIDATION`
- Test execution state: `WRITTEN, NOT EXECUTED`
- BLOCKER count: `0`

## 1. Stage 3C算法文件
- `matlab/slip_confidence_mapping.m`
- `matlab/wss_track_builder.m`

## 2. 测试文件
- `tests/test_slip_confidence_mapping.m`
- `tests/test_wss_track_builder.m`

## 3. 可信度公式
- 分段映射（按四轮顺序 `[FL, FR, RL, RR]`）：
  - `rho_i = 1`, 当 `e_i <= e_low`
  - `rho_i = (e_high - e_i)/(e_high - e_low)`, 当 `e_low < e_i < e_high`
  - `rho_i = 0`, 当 `e_i >= e_high`
- 约束：
  - `0 <= rho_i <= 1`

## 4. 自适应方差
- `R_i = sat(R0_i/(rho_i + epsilon), R_min, R_max)`

## 5. 硬隔离规则
- 固定为：
  - `rho_i > rho_hard`：有效
  - `rho_i <= rho_hard`：无效
- 实际无效来源还包括：
  - `residualValid(i) = false`
  - `validGeom(i) = false`
  - 非有限 `eSlip(i)`

## 6. WSS内部融合
- 有效权重定义：
  - `q_i = 1 / R_i`
  - `alpha_i = q_i / sum(q_valid)`
- 轨迹与等效方差：
  - `vxWssTrack = sum(alpha_i * vxWheel_i)`（仅在有效轮上）
  - `RwssEquivalent = 1 / sum(q_valid)`（仅在有效轮上）

## 7. 四轮全部无效
- `V_k` 为空时固定行为：
  - `wssValid = false`
  - `vxWssTrack = NaN`
  - 下游必须以 `wssValid` 作为测量更新门控，不能将无效 `vxWssTrack` 用于局部 KF 测量更新

## 8. 阶段结论
- IMPLEMENTATION COMPLETE
- TESTS WRITTEN
- PENDING MATLAB EXECUTION
- PENDING MATLAB VALIDATION

## 9. 下一阶段
- Stage 3D
  - 3D1：两个局部标量KF
  - 3D2：PWI互协方差 + Phi + 相关融合
