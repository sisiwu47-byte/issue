# V2.8-A17d 单次退化—恢复最终验证状态

## 最终判定

`SINGLE_RUNTIME_DEGRADATION_RECOVERY_PASS`

- `RUNTIME_COUNT = 1`
- `PARAMETER_RETUNING = NO`
- `ALGORITHM_MODIFICATION = NO`
- 唯一一次 `sim()/CarSim` 已自然返回；后续分析、CSV 与绘图均只读取已保存的 raw evidence，没有再次运行车辆模型。

## 冻结对象与工况

- target：`model/vx_vy_lifesig_fusion_v2_8_degradation_recovery.slx`
- target SHA-256：`9BE6048ACA51F721528660F240CCB6E0FCA6004A3CC39798BF5F63C3BC52CE0F`
- V2.8 core SHA-256：`E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17`
- V2.8 wrapper SHA-256：`AD7FB99E833042490A171515B962718384EC2AD5F8B661F771C9ACF99501A164`
- `rho = 0.995`
- `lambda = 10`
- `d0 = 0.3467656927489074 m/s`
- `Ts = 0.01 s`
- A：`0 <= t < 5.0 s`，`0.02 rad / 0.4 Hz`
- B：`5.0 <= t < 22.5 s`，zero steering command
- C：`22.5 <= t <= 40.5 s`，`0.02 rad / 0.4 Hz`
- Simulink StopTime / CarSim TSTOP：`40.5 s`

## Runtime 与数据完整性

- 样本数：`4051`
- 时间：`0 ... 40.5 s`
- `dt`：min `0.00999999999999801 s`，mean `0.01 s`，max `0.010000000000005116 s`
- 非有限数：`0`
- `I_K`：min `0`，max `2.5115100019465`
- `G_K`：min `1.23780048663663e-11`，max `1`
- `alpha_D/K/F` 最小值均非负；最大权重和误差 `|sum(alpha)-1| = 9.992007221626409e-16`
- availability drop：D `0`，K `0`，F `0`
- fallback count：`0`
- V2.8 frozen core 逐样本 replay 最大误差：`0`
- V2.7 Original LifeSig 独立离线 replay：Vy、alpha、fusion-valid、fallback 最大误差均为 `0`

## Commanded phase 指标

单位均为 `m/s`；Bias 为 `estimate - Vy_true`。

| Phase | Method | RMSE | MAE | MaxAbs | Bias |
|---|---|---:|---:|---:|---:|
| A | D | 0.0374407 | 0.0337343 | 0.0635938 | -0.00680701 |
| A | K | 0.173362 | 0.157475 | 0.265858 | -0.157475 |
| A | Original | 0.0474483 | 0.0386190 | 0.0929913 | -0.0307541 |
| A | Proposed | 0.0474483 | 0.0386190 | 0.0929913 | -0.0307541 |
| B | D | 0.00518822 | 0.00447454 | 0.0392352 | -0.00384249 |
| B | K | 1.07478 | 0.981980 | 1.75454 | -0.981980 |
| B | Original | 0.168533 | 0.154842 | 0.272656 | -0.154842 |
| B | Proposed | 0.0266178 | 0.0217783 | 0.0636838 | -0.0217783 |
| C | D | 0.0384548 | 0.0350141 | 0.0650116 | -0.00424989 |
| C | K | 0.492911 | 0.416143 | 1.76655 | -0.416143 |
| C | Original | 0.0902620 | 0.0740798 | 0.270730 | -0.0740798 |
| C | Proposed | 0.0540810 | 0.0440232 | 0.113296 | -0.0361196 |

A 段后部稳定基线固定为 `3.0 <= t < 5.0 s`，没有为改善结果重新筛选；该窗口的正常 `alpha_K` 均值为 `0.14665099803602072`。

## Physical low-yaw（仅离线 CarSim AVz 标签）

- 定义：`|CarSim AVz| < 0.01 rad/s`
- B 段覆盖率：`99.3714%`
- 首次进入：`5.11 s`
- 最后退出：`22.49 s`
- 最长连续窗口：`5.11 ... 22.49 s`
- 最长连续时长：`17.38 s`

| Method | RMSE | MAE | MaxAbs | Bias |
|---|---:|---:|---:|---:|
| D | 0.00459032 | 0.00431192 | 0.0201651 | -0.00405772 |
| K | 1.07802 | 0.986726 | 1.75454 | -0.986726 |
| Original | 0.169062 | 0.155743 | 0.272656 | -0.155743 |
| Proposed | 0.0266803 | 0.0218383 | 0.0636838 | -0.0218383 |

zero steering command 没有被直接等同于 physical low-yaw；上述窗口完全由离线 CarSim AVz 标记得到。

## B 段退化保护

- `G_K < 0.99`：`t = 6.56 s`，相对 B 开始延迟 `1.56 s`
- `G_K <= 0.50`：`t = 7.89 s`，延迟 `2.89 s`
- `alpha_K <= 0.05`：`t = 8.40 s`，延迟 `3.40 s`
- `alpha_K <= 0.02`：`t = 9.18 s`，延迟 `4.18 s`
- B 段 Proposed 相对 Original：RMSE 降低 `84.2062%`，MAE 降低 `85.9351%`
- physical low-yaw 窗口：RMSE 降低 `84.2186%`，MAE 降低 `85.9780%`
- `d_DK` 首四分之一均值 `0.412879`，末四分之一均值 `1.55181`
- `I_K` 从 `0` 累积至 B 段最大 `2.44124`
- `G_K` 从 `1` 降至 B 段最小 `2.49946e-11`
- `alpha_K` 从 `0.146700` 降至 B 段最小 `4.31854e-12`

证据支持因果链：`d_DK` 增加 → `I_K` 累积 → `G_K` 下降 → `alpha_K` 下降 → K 污染减少。判据不要求 Proposed 优于 D-EKF。

## C 段真实恢复

- `d_DK <= d0` 的 C 段比例：`61.5769%`
- `d_DK`：C 初始 1 s 均值 `1.36417` → 末 1 s 均值 `0.313103`
- `I_K`：`2.43966` → `0.00106209`
- `G_K`：`3.65920e-11` → `0.989436`
- `alpha_K`：`6.32327e-12` → `0.146332`
- `G_K >= 0.90` 且持续 1 s：C 开始后 `12.91 s`
- `G_K >= 0.95` 且持续 1 s：C 开始后 `14.34 s`
- `G_K >= 0.99`：首次越过发生于 C 开始后 `17.59 s`，但未持续 1 s；结论为 `NOT_REACHED_WITHIN_RUNTIME`
- `alpha_K >= 90%` A 段稳定基线且持续 1 s：C 开始后 `12.49 s`
- `alpha_K >= 95%` A 段稳定基线且持续 1 s：C 开始后 `13.80 s`

真实 runtime 数据显示 disagreement 降低、积分状态泄漏恢复、`G_K` 回升以及 K 权重回升，满足恢复趋势要求；没有用解析公式替代实际恢复证据。

## Evidence

- raw runtime：`results/vy_lifesig_v2_8a17d_degradation_recovery/raw_runtime_evidence.mat`
  - SHA-256：`EDB0F7DACAAFE1CA5512BD219B7C60EFD51DBF513DCB608593603CA6060E5F07`
- analysis evidence：`results/vy_lifesig_v2_8a17d_degradation_recovery/analysis_evidence.mat`
  - SHA-256：`6C77673536A5FAD05337DB4A57F39E03CD13BC34B9E7010C69E794865A375965`
- full timeseries SHA-256：`7CEB37FCDF2C10812D5EB79E73EDACB582458869352CD7C416800C206426FC1B`
- phase metrics SHA-256：`9314A2E17948A04DB01044FE6453F765104824901C011FD35323BC43D9E55FEE`
- physical low-yaw metrics SHA-256：`136EFC0FD6471DA4E810336846AE95215CA58EF56C9F712286CF0D1014C25DC8`
- degradation response SHA-256：`AE7268BF5A1DA2AFAF24368064BBD32AFAC4B40176A69FF3FD985CF68FDC9B13`
- recovery metrics SHA-256：`33C5D4E3C23D468E1C69B306F99D175C4A8E1D5C23E34862F65C094E1BFBAAE6`
- V2.7 replay validation SHA-256：`E387EA02B3714963FEBD70D8AFFE7B768252E91FAF939A8E3AB8F5D8221C9D47`
- durable runtime commit SHA-256：`4745175BF607CFA5FD3CACF35C9A303839076E7EF55EFADC33DB8E9E1AB11EC3`

四张核心图均已生成 PNG 与 SVG：Vy estimation、health evolution、fusion weights、absolute error comparison。

## 冻结结论

本次单一在线运行完整覆盖正常进入、K 退化保护和真实恢复。Proposed LifeSig 在退化段显著降低 K 污染；正常 A 段与 Original 完全一致；恢复 C 段出现了实际、可量化的 `I_K/G_K/alpha_K` 恢复趋势。所有结论均来自这一次已保存 runtime，未调参、未修改算法、未进行第二次运行。
