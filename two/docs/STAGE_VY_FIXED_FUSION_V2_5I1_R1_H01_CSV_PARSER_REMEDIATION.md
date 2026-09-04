# V2.5-I1-R1 H01 CSV Parser Remediation

## 状态

**V2.5-I1-R1 CSV PARSER REMEDIATION BLOCKED**

本轮仅修复专用 H01 runner/analyzer 的 CSV 解析契约。原 H01 R0 批处理在 `sim()` 之前失败，根因是 MATLAB 默认 `readtable` 对预执行注册表发生分隔符/模式推断，导致列名退化为 `VarN`，`pre.role` 无法解析。

## 已完成的最小修改

- `model/run_vy_fixed_fusion_v2_5i1_H01_holdout.m`
- `model/analyze_vy_fixed_fusion_v2_5i1_H01_holdout.m`

上述四处 CSV 读取均显式使用逗号分隔、`VariableNamingRule='preserve'` 和 `TextType='string'`；没有增加位置列回退，也没有改变运行、模型、权重或 H01 条件逻辑。

原 R0 哈希作为历史证据保留：runner `05E15D23CEB9A2F3B60772311D4858C75DDE1F161647884655BDE26635AF739D`，analyzer `052F2BA6BB7285E7056417C235F8782F994EE0B2980433DF268474556B53C0DC`。本轮新执行入口哈希为 runner `B8BD1148E78B06C0075A2536812E252DEDDF91AF36132F7AB6BE9F7370D4B66E`、analyzer `2A25B62815574B3F1DC53BCC52239A6711181AF6435B98B2907DDCB9B570E29E`。

静态读取原始 CSV 表头确认 32 列、逗号分隔；预注册表哈希仍为 `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`，H01 选中行应为唯一 `FWHOLD_H01` / `HOLDOUT_VALIDATION`。

## 唯一 parser-only 探针

按授权只启动了一次 MATLAB batch 探针。该探针未加载正式 Simulink target、未调用 `sim()`、未启动 CarSim、未读取 holdout MAT。由于 PowerShell/MATLAB 引号转义使命令字符串在 MATLAB 解析前出现 unterminated-string syntax error，进程以 exit code 1 退出，`readtable` 断言未执行。根据“一次探针、失败不得重跑”约束，本轮不再启动 MATLAB。

`simCallCount=0`；H01 formal runtime MAT 不存在；H01 authorization 仍为 `UNCONSUMED`；H02/H03 仍未运行、未查看；当前 live MATLAB process count 为 0。

## 完整性

目标模型 `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`、fusion core `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`、wrapper `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` 均保持不变。预注册表未修改，R0 evidence 未覆盖。

## 后续最小动作

需要在新的授权轮次中修正 batch 命令的外层引号并重新执行一次 parser-only 探针；在此之前不得进入 H01 runtime。不得将本轮标记为 R1 refreeze 通过。
