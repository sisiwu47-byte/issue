# V2.8-A17b Single Runtime Degradation–Recovery Validation

## Main verdict

`SINGLE_RUNTIME_VALIDATION_FAIL — PRE-RUNTIME CONDITION GATE`

`RUNTIME_COUNT = 0`

`PARAMETER_RETUNING = NO`

本次唯一 runtime 授权保持 `UNCONSUMED`。没有调用 `sim()`，没有启动 CarSim runtime。

## Pre-runtime condition audit

正式目标：

- `model/vx_vy_lifesig_fusion_v2_8_recovery_validation.slx`
- SHA-256：`C86D631F05C0942788BB4F67051608051A9AD95E22910DB3B61A271A498595BD`

A17a builder 从冻结的 `model/vx_vy_lifesig_fusion_v2_7.slx` 复制该目标，仅执行以下改变：

- LifeSig wrapper 绑定到 `vy_lifesig_fusion_v2_8_simulink_sfun`；
- 增加 `d_DK`、`I_K`、`G_K`、AVz 及相关日志。

builder 没有修改 steering source、steering profile、StopTime 或 run-control。目标 hash 仍与 A17a build evidence 一致。

因此当前 A17a target 保留 V2.7 nominal steering：

```text
front road-wheel steering = 0.02*sin(2*pi*0.4*t) rad
```

该输入是连续正弦激励，只包含周期性的瞬时过零，不能形成专用的长时间低横摆退化段，也不能形成退化后的正常恢复段。

| Required phase | Existing A17a target |
|---|---|
| A. normal lateral-motion entry | YES — continuous nominal sine |
| B. sustained low-yaw K degradation | NO |
| C. post-degradation normal recovery | NO |

## Existing long-low-yaw condition

既有独立 A2/A3 profile 为：

```text
0.00–2.00 s     exact-zero steering
2.00–4.50 s     one complete 0.02-rad / 0.4-Hz sine period
4.50–22.00 s    exact-zero steering
```

该工况能够形成持续低横摆退化；现有 A3 evidence 的物理低横摆最长窗口为 `4.70–22.00 s`。但是低横摆一直持续到 runtime 结束，没有随后恢复到正常横向激励的阶段。A12 既有审计也明确记录：A3 low-yaw window 后不存在真实 normal recovery segment。

此外，A2/A3 target 尚未绑定正式 V2.8 online K-health core/wrapper，因此不能直接作为 A17b 的完整 degradation–recovery runtime target。

## Gate decision

当前任何已冻结 target 都不能在一次车辆运行中同时提供：

```text
normal → sustained K degradation → normal recovery
```

因此不得消费本次唯一 runtime 授权。要进入正式 A17b runtime，必须先建立一个新的独立 validation condition，使长低横摆段之后重新施加正常横向激励，同时保持 V2.8 算法、参数和冻结 baseline 不变。该工况准备属于后续独立 pre-runtime target/config stage，不能在本阶段运行中临时修改。

## Frozen integrity

- `rho = 0.995` unchanged
- `lambda = 10` unchanged
- `d0 = 0.3467656927489074 m/s` unchanged
- `Ts = 0.01 s` unchanged
- `q_D/q_K/q_F` unchanged
- `tau_F` unchanged
- D/K/F estimator、fallback、V2.7 target/core/wrapper unchanged

未生成 `phase_metrics.csv`、`recovery_metrics.csv`、`full_timeseries.csv` 或 runtime figures，因为没有合法的 degradation–recovery runtime 数据。
