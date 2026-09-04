# V2.5-I1-R3 Launcher / Self-Reporting CSV Parser Proof

## 最终状态

**V2.5-I1-R3 LAUNCHER/PARSER PROOF BLOCKED**

R1 与 R2 历史状态保持不变：R1 为 launcher quoting failure before `readtable`，R2 为 inconclusive launcher/process capture。本轮 R3 只创建了新的 self-reporting probe 与简单 `.cmd` launcher，未修改 runner、analyzer、预注册表或任何模型。

## R3 probe 与 launcher

探针 `model/probe_vy_fixed_fusion_v2_5i1_r3_csv_parser.m` 的哈希为 `7AA48B489B42B94B1873176DF8C8B85966C0EA46985E7F6A70D566A0334A07A7`。它包含显式逗号、保留列名和 string 类型的 `readtable` 契约，以及 self-report try/catch；不加载模型、不调用 Simulink/CarSim、不读取 holdout MAT。

launcher `model/launch_vy_fixed_fusion_v2_5i1_r3_csv_parser.cmd` 的哈希为 `5E6B4283FCA49685E78D433BCC8C7A87F7D8E0D6385543A2A86AEB7C6B82EE9A`。按授权只执行一次。实际 cmd 输出显示工作目录命令未被正确解析，路径 `D:\UsersData\桌面\two\model` 在命令 shell 中出现 UTF-8/非 ASCII 路径解析错误，随后 `EC` 行也未形成有效结果。MATLAB 未进入 probe：无 `R3_PROBE_ENTERED`、无 `readtable` 标记、无 self-report、stdout/stderr/exitcode 文件均未生成。

因此精确分类为 **LAUNCHER_NOT_ENTERED**，不能推断 MATLAB startup、CSV parser 或 schema 失败。按 R3“一次 launch、不得第二次 probe”约束，本阶段不重试、不改 launcher、不运行 H01。

## 未消费的运行授权

没有 formal target load，没有 `sim()`，没有 CarSim，没有 holdout 数据读取；`simCallCount=0`。H01 formal runtime authorization 仍为 `UNCONSUMED`，formal H01 MAT 不存在；H02/H03 仍未运行、未查看。

## 完整性

runner `B8BD1148E78B06C0075A2536812E252DEDDF91AF36132F7AB6BE9F7370D4B66E`、analyzer `2A25B62815574B3F1DC53BCC52239A6711181AF6435B98B2907DDCB9B570E29E`、immutable preregistry `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6` 均保持不变；R1/R2 evidence/status 未覆盖。

R3 记录见 `results/vy_fixed_fusion_v2_5i1_r3_launcher_parser_evidence.csv`。需要新的授权才能针对 launcher 的非 ASCII 工作目录解析问题设计后续诊断；在此之前不得进入 H01 runtime。
