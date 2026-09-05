# V2.7-A2R2 MINIMAL RELIABILITY INTERFACE IMPLEMENTATION

## 范围

本阶段仅实现 A2R1 已冻结的诊断接口。未加载项目 Simulink 模型，未运行 `sim()`、CarSim 或 calibration runtime，未修改 D/K/F 状态方程、Q/R、P0_F/Q_F、scheduler 或 fusion。P0_F=0 与现行 F core `P0_F>0` 契约 blocker 保持不变。

## 实际修改文件

| 文件 | SHA-256 |
|---|---|
| `model/vy_dynamic_ekf_step_v13.m` | `ADC56DF50B0C11F90074639D1825FBF8173B4E0AC4135D9618FB8D085F3EB928` |
| `model/vy_dynamic_ekf_step_v17.m` | `8D3EED4EA85E5E4B26D02473171D2E65E4472A374E6E9AA16797A6D92CEBD49E` |
| `model/vy_dynamic_ekf_v1_17.m` | `1AE909CF8118663F859EBC9F844374D97AB4238F701745EAC49A380498CE8AE5` |
| `model/vy_kinematic_kf_step.m` | `383A5A63AC11C3F43BAE1CA7B6993A1C181363F970CD1BA347D4FF8521727740` |
| `model/vy_kinematic_kf.m` | `73A06F593E0D52B3A168445060F6CA68B35D2F710A913DD16213CDC71FF92298` |
| `model/vy_feedback_propagation_simulink_sfun.m` | `AA3E9E79D81D1C3D8155D4FF04ED952357B0294E09DF868FEBC7E05753E64FD8` |
| `tests/test_vy_dynamic_ekf_v17_multirate.m` | `3DD35FA3200FC5056694E9F175DEFBB61CB885FF0AD94186BCD734F051618ECA` |
| `tests/test_vy_kinematic_kf_wrapper.m` | `2E5A36BE9A7AF1F82F3248990867FDB2B1BCF76314E66F2E29F2BF2A1A255690` |
| `model/test_vy_feedback_propagation_v2_4b.m` | `CEEB7FB165011456A996449C76AB7D9D2E8CEF7847CEB37FD71BD869DBE7C5C3` |

## Exact new contract

### D

`vy_dynamic_ekf_step_v13/v17` 在成功完成 finite、合法分母、finite state/covariance 的选定更新后设置 `info.updateValid=true`；invalid、异常回退或未执行更新保持 false。正常零 innovation/NIS=0 不会被判 invalid。`vy_dynamic_ekf_v1_17` 保留历史 69 元素 `y` 数值输出，并通过可选第二输出提供：

```text
reliability.update_valid_D
reliability.nis_valid_D
reliability.measurementDimension_D
reliability.useAy_D
reliability.NIS_D
```

### K

`vy_kinematic_kf_step` 在 finite innovation、`S>0`、finite NIS/x/P 的成功更新后设置 `info.updateValid=true`。wrapper 保留原 `x_new/P_new/diag_out(5)`，通过可选第四输出提供：

```text
reliability.update_valid_K
reliability.nis_valid_K
reliability.S_K
reliability.NIS_K
reliability.obs_metric_K
reliability.reset_input_K
```

`NIS_K` 与 `abs(r)`仍是独立证据；S_K 仅作为可选审计输出，没有改变原数值路径。

### F

S-function 保留 `Vy_F`、`P_F` 和原 3 元 `diag_F`，新增第 4 个诊断输出 `[propagation_age_steps; age_valid; reset_valid]`，并新增 DWork `propagation_age_steps`：

```text
reset hit                          -> age_steps=0
first valid non-reset propagation -> age_steps=previous+1=1
subsequent valid hit               -> age_steps=previous+1
age_valid=1                       -> finite state/inputs/output and P_F>=0
reset_valid=1                     -> current reset input finite and consumed
```

无效/非 finite/传播失败时 `age_valid=0`，不得伪装为高可靠。F 数学 core 未修改，也未新增 innovation/NIS。

## 测试与回归证据

实际执行命令（单一 MATLAB batch session，仅 D/K 单元回归）：

```text
D:\matlab\bin\matlab.exe -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); addpath(fullfile(pwd,'tests')); r1=test_vy_dynamic_ekf_v17_multirate(); r2=test_vy_kinematic_kf_wrapper(); disp('A2R2_DK_UNIT_OK'); exit(0)"
```

原有数值回归：

- `V1_17_TEST_PASS|N=120|A100=0|prediction=0|A50=6/11|A20=5/21`
- `K_KF_WRAPPER_TEST_OK|tests=9|resetXErr=0|resetPErr=0|diag=5`

这证明新增 `info.updateValid` 与可选 reliability 输出没有改变 D 的原有 step/prediction 数值，也没有改变 K 的原有 x/P/5 元 diag 数值。另对 F S-function 做了静态审计：第 4 诊断端口、age DWork、reset age=0、逐拍递增及 valid 检查均存在；未执行长时间 10,000-step F 测试以避免重复高成本运行，F core 本身未改动。

执行纪律记录：曾启动一次合并 D/K/F 的 MATLAB batch 进程以尝试一次性回归；该进程在 F 侧未产出结果并停滞。确认属于本轮启动的两个 MATLAB PID 后已停止它们，未启动第二次 F runtime、未运行 Simulink/CarSim。随后仅重取受影响的 D/K 轻量回归，得到上述 PASS；F 仅保留静态审计证据。因此该停滞被归类为测试进程/证据路径问题，不作为 estimator 算法失败证据。

## 是否具备后续 capture 条件

D/K 的 valid 与可选 S_K 已可由 MATLAB wrapper 获取，F 的 age/valid/reset 已在 S-function 边界实现。后续非-holdout reliability capture 可使用这些接口；仍需在独立 target logging 阶段接入新增端口，并处理现有 F `P0_F>0` contract blocker。当前没有进行任何 runtime 或新 calibration acquisition。

**READY FOR V2.7 RELIABILITY DIAGNOSTIC CAPTURE**
