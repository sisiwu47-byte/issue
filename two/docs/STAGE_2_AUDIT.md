# STAGE 2 审核

1. 总结论：FAIL

A. PASS（`docs/STAGE_2_FORMULA_MAP.md:21-24` 固定参数齐全，包括 `Ts_est=0.01`、`Twindow=0.5`、`Nwindow=50`、`TimuOnlyMax=1.0`、`Rw=0.393`；并在 `36` 行和 `76` 行固定 `vy_prior=0`）
B. PASS（`docs/STAGE_2_FORMULA_MAP.md:9-10` 明确为 `[FL, FR, RL, RR]`）
C. PASS（`docs/STAGE_2_FORMULA_MAP.md:9-10,117` 明确 `wheelOmega=[AVy_L1,AVy_R1,AVy_L2,AVy_R2]`、`wheelAngle=[Steer_L1,Steer_R1,Steer_L2,Steer_R2]`）
D. PASS（`docs/STAGE_2_FORMULA_MAP.md:69-83` 给出候选公式、独立转角、`AVz` 项及每轮 `e_i`）
E. PASS（`docs/STAGE_2_FORMULA_MAP.md:127-175` 有连续/硬隔离与 WSS 融合与方差）
F. PASS（`docs/STAGE_2_FORMULA_MAP.md:161,166-172` 给出分段置信、`rho_hard`、`R_i`、`z_WSS`、`R_WSS`）
G. PASS（`docs/STAGE_2_FORMULA_MAP.md:177-184` 的递推公式等价于用户要求形式，且已注明 `vy_prior=0`）
H. PASS（`docs/STAGE_2_FORMULA_MAP.md:195-230` 给出预测/增益/更新/后验更新与初值入口）
I. PASS（`docs/STAGE_2_FORMULA_MAP.md:214-238,242-246` 给出 `P12` 递推、2×2 `Φ`、相关权重、融合、单通道降阶）
J. PASS（`docs/STAGE_2_FORMULA_MAP.md:250-256,19,72` 给出失效计时、阈值分支、退化标志和几何/cos 防护）
K. PASS（`docs/STAGE_2_FORMULA_MAP.md:82-93,114,271-274,250-252` 给出 FIFO 更新、未满窗积分、IMU/WSS 增量、降级规则、`vx_hat` 不置零）
L. FAIL（详见下）
M. PASS（`docs/STAGE_2_FORMULA_MAP.md:34-35,295-299,313-318`）
N. FAIL（`docs/STAGE_2_FORMULA_MAP.md`）

## 失败项说明

- L 失败
  - 章节：`## 6. 异常与防护`
  - 缺失内容：已覆盖输入缺失、`NaN`、`cosδ` 与通道空，但未覆盖
    1) 低速保护逻辑（实现规格里有 `vLow=0.30` 与 `abs(Ax)<0.1` 的退化约束）；
    2) 非正定/非正协方差的显式保护（如 `P<=0` 的夹紧与重置）；
    3) `Φ` 近奇异时的数值保护（`rcond(Phi)` 与 `pinv`/线性求解分支）。
  - 修正要求：补充到 `## 6. 异常与防护` 中的可执行子项。
  - 缺失归属：**融合公式部分**

- N 失败
  - 章节：`## 4. 固定参数表`、`## 4. 离散公式`、`## 8. 两者整合`、`## 8. 仍未确定/待调参项`
  - 缺失内容：
    1) `R_{i,0}`、`R_min`、`R_max`、`epsilon`、`Q_v`、`R_Ax` 在正文中有引用但无初始赋值（仅在待定项提到未调参）；
    2) `R_i`、`R_WSS`、`R_IMU` 的量纲链路未在本文件内封闭；
    3) `signalFinite_i`、`C_N`、`omega_j`、`signalFinite_i` 等变量定义与首次赋值时刻未显式给出。
  - 修正要求：在 `## 4/8/6` 增加完整参数定义表，明确每个符号的单位、默认值和首次赋值时刻。
  - 缺失归属：**仅参数数值缺失**

## 下一步建议

- 执行阶段2A、2B、2C
