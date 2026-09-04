# V2.5-I1-R2 H01 CSV Parser Revalidation

## 最终状态

**V2.5-I1-R2 H01 CSV PARSER-ONLY REVALIDATION BLOCKED**

R1 的失败证据保持不变：R1 probe count 为 1，失败发生在 launcher quoting、早于 `readtable`。R2 是单独授权的一次 parser-only diagnostic；本轮未修改 runner、analyzer、immutable preregistry 或任何模型。

## R2 执行

已先创建独立脚本 `model/probe_vy_fixed_fusion_v2_5i1_r2_csv_parser.m`，其中仅定位 immutable CSV、以显式逗号/保留列名/string 选项调用 `readtable`，并断言 32 列、正式字段及唯一 H01 行。脚本哈希为 `8EC2212B3CD856B14B3E5CF8DBFFA7EE9F2E5DB7640CEE130569CCAF53C1C321`。

随后按简化 launcher contract 从 `D:\UsersData\桌面\two\model` 启动一次 `D:\matlab\bin\matlab.exe -batch probe_vy_fixed_fusion_v2_5i1_r2_csv_parser`。该启动尝试未返回 PID、退出码或有效 stdout/stderr；捕获文件均为空，也没有 `R2_PARSED_WIDTH`、正式列名或 `R2_PARSER_PROBE_OK` 输出。因此无法证明 MATLAB 进入探针、执行 `readtable` 或完成 schema/row assertions。当前 live MATLAB process count 为 0。按“一次 R2 probe、失败不得第二次 launch”约束，本阶段不再重试。

## 未消费与禁止项

没有加载 formal Simulink target，没有调用 `sim()`，没有启动 CarSim，没有读取 holdout 数据；`simCallCount=0`。H01 formal runtime authorization 仍为 `UNCONSUMED`，H01 formal MAT 不存在；H02/H03 仍未运行、未查看。不得进入 H01 runtime，也不得创建 active execution-entry freeze。

## 当前哈希

- runner（R1 patched）：`B8BD1148E78B06C0075A2536812E252DEDDF91AF36132F7AB6BE9F7370D4B66E`
- analyzer（R1 patched）：`2A25B62815574B3F1DC53BCC52239A6711181AF6435B98B2907DDCB9B570E29E`
- immutable preregistry：`ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`
- formal target：`AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- fusion core：`4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- fusion wrapper：`B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`

R2 的具体字段记录见 `results/vy_fixed_fusion_v2_5i1_r2_csv_parser_probe_evidence.csv`。需要新的明确授权后，才能针对 launcher/process-capture 阻塞设计下一次诊断；本阶段不运行 H01。
