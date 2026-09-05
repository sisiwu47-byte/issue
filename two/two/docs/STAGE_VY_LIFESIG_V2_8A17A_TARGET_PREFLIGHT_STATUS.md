# V2.8-A17a 独立 V2.8 target 绑定与 runtime preflight

## 最终状态

`TARGET_BINDING_PASS = YES`

`COMPILE_PREFLIGHT_PASS = NO`

`READY_FOR_SINGLE_RUNTIME_RECOVERY_VALIDATION = NO`

本阶段已停止。没有调用 `sim()`，没有执行 CarSim runtime，也没有进行第二次 compile。

## 独立 target 与绑定

- 独立 target：`model/vx_vy_lifesig_fusion_v2_8_recovery_validation.slx`
- target SHA-256：`C86D631F05C0942788BB4F67051608051A9AD95E22910DB3B61A271A498595BD`
- 实际 wrapper：`vy_lifesig_fusion_v2_8_simulink_sfun`
- 实际 core：`vy_lifesig_fusion_v2_8_step`
- `I_K` wrapper DWork 初值：`0`
- reset 继续使用原 V2.7 target 的既有 reset source；没有增加恢复或门控逻辑。

builder 已完成并持久化 `build_evidence.mat`。静态 target/interface/logging gate 为 PASS。

## 静态 runtime 日志契约

已确认独立 target 具备以下日志入口：

- offline evaluation：`rel_vy_true_100hz_log`
- tracks：`fusion_vy_d_log`、`fusion_vy_k_log`、`fusion_vy_f_log`
- LifeSig：`lifesig_vy_ls_log`
- weights：`lifesig_alpha_d_log`、`lifesig_alpha_k_log`、`lifesig_alpha_f_log`
- health：`lifesig_h_d_log`、`lifesig_h_k_log`、`lifesig_h_f_log`
- V2.8 K-health：`v28_lifesig_d_dk_log`、`v28_lifesig_i_k_log`、`v28_lifesig_g_k_log`
- yaw signals：`v28_avz_imu_log`、`v28_carsim_avz_rad_log`
- availability/update evidence：`rel_d_valid_log`、`kkf_diag_log1`、`rel_f_reliability_log`
- common time/reset：`rel_common_time_100hz_log`、`reset_g0`
- numerical status：`lifesig_fusion_valid_log`、`lifesig_fallback_active_log`

`Vy_true` 与 CarSim AVz 只作为离线评价/工况标签，不进入在线融合权重。

## 唯一 compile preflight

- 启动入口：正常 MATLAB desktop/AutomationServer 路径；未重复 A16 已失败的同一 `-batch` 启动。
- compile called：YES
- compile passed：NO
- compiled dimensions/types/sample-time captured：NO
- target hash unchanged across compile attempt：YES
- `sim()` called：NO
- CarSim runtime performed：NO

exact first compile error：

```text
Simulink:SFunctions:SFcnErrorStatus
'vx_vy_lifesig_fusion_v2_8_recovery_validation/CarSim S-Function'
中的 S-Function 'vs_sf' 报告错误:
Failed to start Solver:
You need a running copy of either CarSim Browser or
CarSim License Manager, with a CarSim solver license,
to use this math model.
```

CarSim 弹窗同时明确显示：`The run stopped at T = 0`。这是 compile-only S-function 初始化失败，不是一次授权 runtime。

## 冻结完整性

- V2.7 target：`65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0`
- V2.7 core：`3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA`
- V2.7 wrapper：`E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445`
- V2.8 core：`E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17`
- V2.8 wrapper：`AD7FB99E833042490A171515B962718384EC2AD5F8B661F771C9ACF99501A164`

以上均与进入 A17a 时的冻结值一致。

## Evidence

- `results/vy_lifesig_v2_8a17a_target_preflight/build_evidence.mat`
  - SHA-256：`6D8B098D41B582B512B0F83B199A9DE54E7564A4E16210702394793AE1F00827`
- `results/vy_lifesig_v2_8a17a_target_preflight/compile_preflight_evidence.mat`
  - SHA-256：`724E12831B0C55532168422D35C225358D106521E9D144108F994718BAFDEE37`
- `results/vy_lifesig_v2_8a17a_target_preflight/matlab_gui_preflight.log`
  - SHA-256：`5C9D9BF2363724A0DC9C66B7A8906AFD69B0AA5452DE10C4DE98B9DDB6FE8BCF`
- `results/vy_lifesig_v2_8a17a_target_preflight/matlab_gui_preflight_status.txt`
  - SHA-256：`2005400DD4272227FCE734760A9C633581FFC337EBFADCBAF9CF06E86A78F244`

## Blocker

独立 V2.8 target 的绑定和静态日志接口已经完成，但当前环境未提供可供 `vs_sf` 使用的运行中 CarSim Browser/License Manager Solver license，因此 compile-level dimensions/types/sample-time evidence无法取得。不得进入正式单次 recovery runtime。
