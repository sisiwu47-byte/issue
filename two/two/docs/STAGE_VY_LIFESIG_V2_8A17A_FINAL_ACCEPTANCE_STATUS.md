# V2.8-A17a 独立 V2.8 target 绑定与 runtime preflight 最终状态

## 最终判定

`TARGET_BINDING_PASS = YES`

`COMPILE_PREFLIGHT_PASS = YES`

`READY_FOR_SINGLE_RUNTIME_RECOVERY_VALIDATION = YES`

本阶段没有调用 `sim()`，没有执行正式 CarSim runtime。

## Target 绑定

- Target：`model/vx_vy_lifesig_fusion_v2_8_recovery_validation.slx`
- SHA-256：`C86D631F05C0942788BB4F67051608051A9AD95E22910DB3B61A271A498595BD`
- Wrapper：`vy_lifesig_fusion_v2_8_simulink_sfun`
- Core：`vy_lifesig_fusion_v2_8_step`
- `I_K` 初值：`0`
- reset 沿用既有 V2.7 reset source；未增加新恢复或门控逻辑。

静态绑定、接口和日志检查全部通过。正式 runtime 所需的 `Vy_true`、D/K/F、`Vy_LS`、`d_DK`、`I_K`、`G_K`、三路 alpha、`AVz_IMU`、CarSim AVz、update/availability 及 common time 均已存在对应日志。`Vy_true` 和 CarSim AVz 仅作为离线评价/工况标签。

## Compile preflight

首次历史 compile 因当时 CarSim Browser/License Manager 未运行而失败；该 evidence 保持不覆盖。

环境发生实质变化后，复用同一独立 target，在已有 MATLAB 与 CarSim Browser 会话中执行了一次 append-only compile recheck：

- compile called：YES
- compile passed：YES
- termination reached：YES
- static gate：PASS
- compiled data types：PASS
- compiled sample time：100 Hz PASS
- target hash unchanged：YES
- `sim()`：未调用
- CarSim runtime：未执行

保存的 `CompiledPortDimensions` 为 Level-2 S-function 展平编码：

- 8 个输入端口：16 个 `1`，即每端口 `[1 1]`
- 11 个输出端口：22 个 `1`，即每端口 `[1 1]`

原 recheck validator 将展平元素数误当作端口数，导致 `dims=0`。该问题仅属于 evidence parser。使用相同已保存 compile evidence 重新解析后：

- resolved input ports：8，全部 scalar
- resolved output ports：11，全部 scalar
- dimensions：PASS

修复 parser 后没有再次 compile。

## 冻结完整性

- V2.7 target：`65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0`
- V2.7 core：`3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA`
- V2.7 wrapper：`E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445`
- V2.8 core：`E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17`
- V2.8 wrapper：`AD7FB99E833042490A171515B962718384EC2AD5F8B661F771C9ACF99501A164`

全部保持 unchanged。

## Append-only evidence

- `compile_preflight_evidence_recheck.mat`
  - SHA-256：`5965A3ED21AD592FFAB04164C38A0BB56D7A1DFF443A5B8BA72B8C83D87A8EB0`
- `compile_preflight_acceptance_from_saved_evidence.mat`
  - SHA-256：`5169439ADF92F6D3A8F9BB873C0E9FFE11212FD0B5EE8E83E3E0AD87FAFA751D`
- `compile_preflight_saved_evidence_acceptance.log`
  - SHA-256：`75736D810EAC6754DF2C9DDAC20E2C5C5F3E04A50AD5D3D4D009F26627227A2D`
- `matlab_gui_compile_recheck.log`
  - SHA-256：`ED96921EA6507502585EAFFDA03941BFFFBFCCC3BA7F1A100ED4B90F7A042CD6`

历史失败 evidence 未覆盖，target 未重建。
