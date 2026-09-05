# V2.5-I3-R2 H03 Phase-Lineage Minimal Remediation & Refreeze

## 结论

**V2.5-I3-R2 H03 PHASE-LINEAGE REMEDIATION PASSED**

R2 仅修改 H03 runner 与 analyzer 的 phase-file literal，使其与 R0 intended execution lineage 及 R1 ASCII bootstrap 一致。P0 blocked evidence、R0/R1 status、bootstrap、launcher、模型、权重、registry 和其他历史文件均未覆盖。

## Intended execution lineage

本地 R0/R1 冻结证据确认：

- intended execution attempt：`FWHOLD_H03_EXEC_R0`
- unified phase path：
  `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv`
- unified commit path：
  `results/vy_fixed_fusion_v2_5i3_H03_sim_authorization_committed.csv`
- formal MAT：
  `results/vy_fixed_fusion_v2_5i_fwhold_h03.mat`

实际 source 现已一致：

- runner：`exec_r0_phase_markers.csv`
- analyzer：`exec_r0_phase_markers.csv`
- ASCII bootstrap：`exec_r0_phase_markers.csv`

旧的 `exec_a3_phase_markers.csv` 不再被 H03 runner/analyzer 引用。

## Hash refreeze

| 文件 | old SHA-256 | new SHA-256 | 结果 |
|:--|:--|:--|:--|
| `model/run_vy_fixed_fusion_v2_5i3_H03_holdout.m` | `AB65E8D5DCDEE92EA8AC53AEFE1BFDC97CD4FC7BD8390C17E8656DD90EB631C2` | `F4F0612E32942C31C16B41D46C251C820F7E8786AD05D7AD7A1F77EF43DAFC73` | phase literal only |
| `model/analyze_vy_fixed_fusion_v2_5i3_H03_holdout.m` | `B6DE7B43EAEB154BF59EE906F8A08343217AED1CAEB0B5955BBE357D54182823` | `2B780F82D0622482D4B199ECB8B39E0DF584BF93EEDBE6CAFC2663657F9E66ED` | phase literal only |
| `D:\V25_H03_BOOTSTRAP\run_v25_i3_h03_exec_r0_formal.m` | `43FFD09AD9F5F9E1F421FCA9A786B43A25EA7BE43E4385CC3248256C85B718DE` | same | unchanged |
| `D:\V25_H03_BOOTSTRAP\launch_v25_i3_h03_exec_r0_formal.cmd` | `66747BF4EF3E260545369D78FBEF1AFE4B5F40247F586D84A8AABBA29EFEDC29` | same | unchanged |

冻结被测 lineage 未变：

- target：`AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- core：`4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- wrapper：`B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`
- fixed weights、condition、registry：unchanged

## Static gates

- runner/analyzer/bootstrap phase path：统一，`PASS`
- commit path：统一，`PASS`
- runner self-hash：仍显式使用 `.m`
- bounded non-eval parser：保留
- commit write/close/read-back precedes the only `sim()`：保留
- executable `sim()` call sites：`1`
- retry/fallback：`0`
- bootstrap direct `sim()`：`0`
- launcher MATLAB launch count：`1`

## Pre-run state

- phase：`ABSENT`
- commit：`ABSENT`
- formal H03 MAT：`ABSENT`
- launcher stdout/stderr/exitcode/status：`ABSENT`
- H03 authorization：`UNCONSUMED`
- H03：`UNRUN / UNVIEWED / UNCONSUMED`
- H01：永久关闭
- H02：永久关闭，authorization 已消费

R2 未启动 MATLAB、Simulink、CarSim 或 launcher，未创建 phase marker、commit 或 formal MAT。

证据：`results/vy_fixed_fusion_v2_5i3_r2_phase_lineage_remediation.csv`
