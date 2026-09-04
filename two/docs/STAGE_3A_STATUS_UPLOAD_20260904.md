# STAGE 3A 状态

## 新增文件
- `matlab/estimator_default_params.m`
- `matlab/four_wheel_kinematic_speed.m`
- `tests/test_estimator_default_params.m`
- `tests/test_four_wheel_kinematic_speed.m`
- `docs/STAGE_3A_STATUS.md`

## 函数接口
- `estimator_default_params() -> p`
- `[vxWheel, validGeom] = four_wheel_kinematic_speed(omegaWheel, deltaWheel, yawRate, vyPrior, p)`
  - `omegaWheel`: 4×1 `[FL, FR, RL, RR]`
  - `deltaWheel`: 4×1 `[FL, FR, RL, RR]`
  - `yawRate`: scalar
  - `vyPrior`: scalar
  - `p`: 参数结构体
  - `vxWheel`: 4×1 `[FL, FR, RL, RR]`，单位 m/s
  - `validGeom`: 4×1 logical，逐轮几何有效性

## 使用的 Stage 2 公式
- `docs/STAGE_2_FORMULA_MAP.md`
  - 节 3：轮位与轮索引固定顺序 `[FL, FR, RL, RR]`
  - 节 4：固定参数值
  - 节 6：`x_w, y_w` 定义与转角输入映射
  - 节 7.2：`v_t,i = Rw * omega_i`
  - 节 7.2：`v_x,i = r*y_i + (v_t,i - (v_y^{prior} + r*x_i) sin(delta_i))/cos(delta_i)`
  - 节 7.4：`abs(cos(delta_i)) < cos_delta_min` 时置无效

## 固定参数（写入 `p`）
- `Ts_est = 0.01`
- `Twindow = 0.5`
- `Nwindow = 50`
- `TimuOnlyMax = 1.0`
- `Rw = 0.393`
- `a = 1.18`
- `b = 1.77`
- `d = 1.575`
- `e_low = 0.15`
- `e_high = 0.50`
- `rho_hard = 0.05`
- `R0 = 1e-4`
- `R_min = 1e-6`
- `R_max = 1e4`
- `cos_delta_min = 0.20`
- `v_low = 0.30`
- `QW = 1e-4`
- `QI = 1e-4`
- `PW0 = 1e-4`
- `PI0 = 1e-4`
- `PWI0 = 0`

## 临时标定参数
- 无；`docs/STAGE_2_FORMULA_MAP.md` 未出现 `TEMPORARY CALIBRATION PARAMETER` 标记。

## 测试脚本
- `tests/test_estimator_default_params.m`
- `tests/test_four_wheel_kinematic_speed.m`

## 静态检查结果
- 文件存在与非空：通过
- 文件名与函数名一致性：通过
  - `estimator_default_params.m` / `estimator_default_params`
  - `four_wheel_kinematic_speed.m` / `four_wheel_kinematic_speed`
- 禁词扫描（`Vx_true`/`GPS`/`gps`/`quadprog`/`MPC`/`sim(`）：通过
- 关键断言/约束：已加入参数文件内一致性检查
  - `Ts_est > 0`
  - `Twindow > 0`
  - `Nwindow == round(Twindow/Ts_est)`
  - `Rw > 0`
  - `e_high > e_low`
  - `R_min > 0`
  - `R_max >= R_min`
  - `0 <= rho_hard <= 1`
  - 其它固定参数有限性与正值关系
- 代码行数
  - `matlab/estimator_default_params.m`: 93
  - `matlab/four_wheel_kinematic_speed.m`: 56
  - `tests/test_estimator_default_params.m`: 36
  - `tests/test_four_wheel_kinematic_speed.m`: 96

## MATLAB测试状态
- PENDING MATLAB VALIDATION
- 本机无 MATLAB/Simulink/CarSim，不执行 `matlab`、`runtests`、`sim`

## 尚未实现（固定不实现项）
- FIFO
- 有限窗速度增量
- 滑移残差
- 连续可信度
- 自适应协方差
- WSS内部融合
- 局部KF
- PWI互协方差
- 最终相关融合
- 顶层估计器

## 下一阶段
- Stage 3B

