# V2.8-A16 K-health 正式 LifeSig 集成与无运行回归

## 最终判定

```text
IMPLEMENTATION_REGRESSION_PASS
```

独立 V2.8 core/wrapper 已实现 A15 冻结公式，冻结 V2.7 文件未修改。

## 新实现

- `matlab/vy_lifesig_fusion_v2_8_step.m`：纯状态转移 core；
- `matlab/vy_lifesig_fusion_v2_8_simulink_sfun.m`：独立 V2.8 wrapper；
- `tests/test_vy_lifesig_fusion_v2_8a16.m`：纯 MATLAB 单元/回归测试；
- `tests/validate_vy_lifesig_fusion_v2_8a16_offline.py`：无 Simulink 静态与逐样本验证。

Core 显式输入/输出 `I_K` 状态，wrapper 以第三个 DWork 持有它。
`I_K` 初值为 0；reset 在当拍计算前清除 `I_K` 与 last-valid 历史。
非有限 D/K 输入不会将 NaN/Inf 注入状态；原 fallback 、归一化、D/F
health、`q_D/q_K/q_F` 与 `tau_F` 语义保持不变。

## A15 逐样本回归

重放窗口：`4.70--22.00 s`，1731 samples。

| 量 | 最大绝对差异 |
|---|---:|
| `Vy_LS` | 2.7755575615628914e-17 m/s |
| `I_K` | 0 |
| `G_K` | 0 |
| `alpha_D` | 2.220446049250313e-16 |
| `alpha_K` | 5.551115123125783e-17 |
| `alpha_F` | 2.6020852139652106e-18 |

9/9 门禁 PASS。对 115 个 `I_K=0` 且 `d_DK<=d0` 的样本，V2.8
复现原 LifeSig，最大输出差异 `2.0816681711721685e-17 m/s`。

正常 FWCAL 结论与 A15 一致：C01R1/C03/C04 完全不变，C02/C05
保留已披露的微小非零扰动；最大输出变化 `0.0002823247504146779 m/s`，
最大 `alpha_K` 变化 `0.0008285839738473022`。

## 环境边界

唯一一次纯 MATLAB 单元测试 batch 在进入 `checkcode`/测试前失败：

```text
failed to load settings errors_warnings plugin
```

本阶段没有第二次启动 MATLAB，没有加载 Simulink，没有调用 `sim()`，
没有运行 CarSim。因此本阶段 PASS 是“无运行静态+逐样本回归”，
不伪装为已执行 MATLAB core 或 Simulink compile 证据。

## 完整性

| 文件 | SHA-256 |
|---|---|
| V2.8 core | `E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17` |
| V2.8 wrapper | `AD7FB99E833042490A171515B962718384EC2AD5F8B661F771C9ACF99501A164` |
| MATLAB test | `8E404D514640E694EDBDA2F03C6EB5F701F78332B44086E4E61E2731D8525855` |
| offline validator | `CBE0C0AB66BFDF571BED03E11C54874E45D397E633F05F34F55DB59C5EC76D6F` |
| frozen V2.7 core | `3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA` |
| frozen V2.7 wrapper | `E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445` |
| frozen V2.7 target | `65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0` |

## 单次 runtime readiness

```text
READY_FOR_SINGLE_RUNTIME_RECOVERY_VALIDATION = NO
```

原因：新 core/wrapper 和无运行回归已通过，但尚未将 wrapper 绑定到
独立 V2.8 `.slx` target，也尚未执行 compile preflight。下一最小阶段是：

```text
INDEPENDENT_V2_8_TARGET_BINDING_AND_COMPILE_PREFLIGHT
```

