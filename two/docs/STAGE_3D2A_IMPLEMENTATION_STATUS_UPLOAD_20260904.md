# Stage 3D2A Status

- Stage: `3D2A`
- Stage-2 formula source: `docs/STAGE_2_FORMULA_MAP.md`
- MATLAB state: `PENDING MATLAB VALIDATION`
- BLOCKER count: `0`
- Next stage: `Stage 3D2B`（相关融合单元测试）

## 1. New/updated files
- `matlab/correlated_two_track_fusion.m`

## 2. Function interface
- `[vxFused, Pfused, alphaW, alphaI, PWI_minus, PWI_plus, Phi, condPhi, fusionValid] = ...
  correlated_two_track_fusion(xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p)`

## 3. PWI_minus formula
- `PWI_minus = PWI_prev + Q_WI_common`
- `Q_WI_common = (QW + QI) / 2`
- Non-finite or negative `PWI_prev` and invalid `Q_WI_common` are protected (fallback to 0).

## 4. PWI_plus formula
- `PWI_plus = (1-KW) * PWI_minus * (1-KI)`
- This directly uses stage-2 frozen `KW_k` / `KI_k` values from local scalar KFs.
- If one channel is invalid, local update gate gives `K = 0`, so `PWI_plus` naturally keeps predicted behavior.

## 5. 公共过程噪声
- `Q_WI_common = (QW + QI)/2` (from Stage-2 map).
- Fallback to `0` when `QW/QI` unavailable or non-finite.

## 6. KW/KI在互协方差中的作用
- `KW` and `KI` are used only in:
  - `PWI_plus = (1-KW) * PWI_minus * (1-KI)`.
- No extra gating is injected beyond local-kf validity effects.

## 7. Phi定义
- `Phi = [PW  PWI_plus; PWI_plus PI]`
- `Phi` built from current-step local outputs `PW/PI` (after local variance protection).

## 8. alpha定义
- Closed-form scalar equivalent of `Phi^{-1}1/(1^T Phi^{-1}1)`:
  - `den = phi11 + phi22 - 2*phi12`
  - `alphaW = (phi22 - phi12) / den`
  - `alphaI = (phi11 - phi12) / den`
- No use of `inv(Phi)`.
- Normalized by `alphaW+alphaI` to keep `alphaW + alphaI = 1`.
- No clipping to `[0,1]` is introduced.

## 9. vxFused定义
- Both valid:
  - `vxFused = alphaW*xW + alphaI*xI`
- WSS only:
  - `vxFused = xW`
- IMU only:
  - `vxFused = xI`
- Both invalid:
  - `vxFused = NaN` (no new estimate generated in this stage).

## 10. Pfused定义
- Both valid:
  - `Pfused = alphaW^2*PW + 2*alphaW*alphaI*PWI_plus + alphaI^2*PI`
- WSS only: `Pfused = PW`
- IMU only: `Pfused = PI`
- Both invalid: `Pfused = NaN`
- Applied Stage-2 minimum floor: `Pfused_min` (default `1e-12`).

## 11. 单通道状态
- Case B (`wssValid=false`, `imuValid=true`):
  - `alphaW = 0`, `alphaI = 1`
- Case C (`wssValid=true`, `imuValid=false`):
  - `alphaW = 1`, `alphaI = 0`
- `PWI_plus`仍按`KW/KI`公式更新（无效端 `K=0` 时退化到预测保持）。

## 12. 双通道无效返回语义
- `wssValid=false` and `imuValid=false`:
  - `fusionValid = false`
  - `vxFused = NaN`, `Pfused = NaN`
  - 不输出/合成 0 速度，不引入 `Vx_true`。

## 13. 数值保护
- Non-finite `PW/PI/PWPrev/KW/KI/PWI_prev` -> 有界回退（默认 `0` 或受限最小值）。
- 负协方差使用 `max(..., 0)` 后进入 `P_min`。
- `den <= eps_den`（默认 `1e-12`）时使用 `den=eps_den`，并记录 `condPhi`。
- `PWI` 做 Cauchy–Schwarz 限幅：`|PWI| <= sqrt(PW*PI + eps)`。
- `Pfused` 不小于 `Pfused_min`，`Pfused` 非有限时设为 `Pfused_min`。
- 不裁剪 `alphaW/alphaI` 到 `[0,1]`。

## 14. PWI物理界
- `PWI` 初始化/保护：
  - 由 `PWI_prev` 传入。
  - 保持 `PWI_plus` 满足物理约束 `|PWI| <= sqrt(PW*PI)`（含 `eps`）。
- `Phi` 对称构造：`Phi(1,2)=Phi(2,1)`.

## 15. 负融合权重
- 允许出现（不进行手工裁剪）；仅确保 `alphaW + alphaI ≈ 1`。

## 16. reset/PWI0接口
- 本函数为纯函数；不含 persistent 重置状态机。
- 接口保留 `PWI_prev` 由顶层复位后传入。
- `p.PWI0` 未在本函数内部强制重置。

## 17. 尚未实现（下一阶段）
- 顶层 `longitudinal_velocity_estimator`
- 顶层 `reset` 状态机/持续状态管理
- IMU轨迹递推逻辑（顶层组织）
- degradedMode、`allWheelInvalidDuration`、`degradedMode` 计时逻辑
- GPS/BDS 融合路径
