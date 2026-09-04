# Stage 3D Status

- Stage: `3D`
- Previous stage: `3D2A`
- MATLAB status: `PENDING MATLAB VALIDATION`
- Test execution status: `WRITTEN, NOT EXECUTED`
- Next stage: `Stage 3E`
- BLOCKER count: `0`

## 1. Updated/verified files
- `matlab/local_scalar_kf_step.m`
- `matlab/correlated_two_track_fusion.m`
- `tests/test_correlated_two_track_fusion.m`

## 2. Local KF formula (Stage-2 frozen)
- Scalar prediction/update structure is `x = xPrev` and `PMinus = PPrev + Q`.
- Local update gain is `K = PMinus / (PMinus + R)` when measurement is valid and finite.
- Posterior:
  - `xPlus = xMinus + K * (z - xMinus)`
  - `PPlus = (1 - K) * PMinus`
- Invalid measurement/invalid variance paths keep prediction-only outputs.

## 3. PWI recursion
- Frozen prediction:
  - `PWI_minus = PWI_plus_prev + Q_WI_common`
  - `Q_WI_common = (QW + QI) / 2`
- Frozen update:
  - `PWI_plus = (1 - KW) * PWI_minus * (1 - KI)`
- Validity gates are inherited by `KW/KI` through local KF update behavior (`K=0` for invalid channel).

## 4. Phi
- `Phi = [PW, PWI_plus; PWI_plus, PI]`

## 5. Correlated fusion weights
- `den = phi11 + phi22 - 2*phi12`
- `alphaW = (phi22 - phi12) / den`
- `alphaI = (phi11 - phi12) / den`
- `alphaW + alphaI = 1` is enforced by normalization in code.
- No intentional hard clipping of `alphaW/alphaI` to `[0,1]` is added in this stage.

## 6. Pfused
- Both channels valid:
  - `Pfused = alphaW^2 * PW + 2*alphaW*alphaI*PWI_plus + alphaI^2 * PI`
- Single-channel fallbacks:
  - WSS valid only: `Pfused = PW`
  - IMU valid only: `Pfused = PI`
- Both invalid: `Pfused = NaN`
- `Pfused_min` floor is applied after computed covariance.

## 7. 单通道退化
- WSS invalid + IMU valid:
  - `alphaW = 0`, `alphaI = 1`, `vxFused = xI`, `Pfused = PI`, `fusionValid = true`
- WSS valid + IMU invalid:
  - `alphaW = 1`, `alphaI = 0`, `vxFused = xW`, `Pfused = PW`, `fusionValid = true`

## 8. 双通道全失效返回语义
- `wssValid = false`, `imuValid = false`:
  - `fusionValid = false`
  - `vxFused = NaN`
  - `Pfused = NaN`

## 10. Phi / PWI numeric protection
- Non-finite or negative variances are guarded to finite physical values.
- `den <= eps_den` uses a protected denominator.
- `condPhi` is output as condition monitor.
- Cauchy-Schwarz bound is enforced:
  - `|PWI_plus| <= sqrt(PW * PI + eps)`
- No explicit inverse function `inv(Phi)` is used in the stage-3D fused implementation.

## 11. 最终融合对象
- 最终融合对象是**局部KF后验**:
  - `xW = xW_plus`
  - `xI = xI_plus`
- It does not use raw upstream signals (`vxWssTrack`, `vxImuTrack`) directly in the final weighted stage.

## 12. Independent inverse-variance comparison
- This stage confirms non-independent fusion behavior.
- Correlated fusion uses `PWI_plus` and does not simplify to independent inverse-variance form (`alpha_k = Phi^{-1}1 / (1^T Phi^{-1}1)` scalar equivalent).

## 13. Stage outcome
- `IMPLEMENTATION COMPLETE`
- `TESTS WRITTEN`
- `PENDING MATLAB EXECUTION`

## 14. Next stage (do not start in this thread)
- Stage 3E: top-level longitudinal speed estimator
  - 初始化
  - reset
  - 四轮运动学
  - Stage 3B 窗口模块
  - Stage 3C 可信度与 WSS 轨迹
  - IMU 递推轨迹
  - 两个局部 KF
  - PWI 状态保存
  - 相关融合
  - 单/双通道状态机
  - allWheelInvalidDuration
  - degradedMode
  - last finite vxFused 保护
  - 统一输出接口
