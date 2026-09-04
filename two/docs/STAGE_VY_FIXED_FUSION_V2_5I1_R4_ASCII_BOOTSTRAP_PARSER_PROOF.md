# V2.5-I1-R4 ASCII Bootstrap Launcher & CSV Parser Proof

## 结论

**V2.5-I1-R4 ASCII BOOTSTRAP LAUNCHER & CSV PARSER PROOF PASSED**

R1 的 launcher quoting failure、R2 的 inconclusive process capture、R3 的中文路径 CMD launcher failure 均作为历史证据保留，未改写。R4 使用纯 ASCII 目录 `D:\V25_H01_BOOTSTRAP`，避免 Windows launcher 解析中文工作目录；MATLAB 启动后由 probe 在 MATLAB 内部切换到原始项目目录 `D:\UsersData\桌面\two\model`。

## R4 实际证据

- R4 launch count = 1。
- launcher exit code = 0；stderr 为空。
- stdout 依次包含 `R4_PROBE_ENTERED`、`R4_PROJECT_CD_OK`、`R4_READTABLE_ATTEMPT`、`R4_READTABLE_COMPLETED`、`R4_PARSER_PROBE_OK`。
- MATLAB `pwd` 精确为 `D:\UsersData\桌面\two\model`。
- 原始 immutable preregistry 直接读取，`readtable` 完成，parsed width = 32，正式列名保留，required fields = TRUE。
- `execution_order==1` 唯一选中 `FWHOLD_H01`，role=`HOLDOUT_VALIDATION`；条件为 0.025 rad / 0.35 Hz / 16 s / 100 Hz / `SINE_FRONT_EQUAL_REAR_ZERO`。
- formal target 未加载，`sim_called=FALSE`，CarSim 未启动，holdout runtime data 未读取。

自报告位于 `results/vy_fixed_fusion_v2_5i1_r4_matlab_probe_result.csv`；综合证据位于 `results/vy_fixed_fusion_v2_5i1_r4_ascii_bootstrap_parser_evidence.csv`。

## 执行入口冻结

当前 runner 哈希为 `B8BD1148E78B06C0075A2536812E252DEDDF91AF36132F7AB6BE9F7370D4B66E`，analyzer 哈希为 `2A25B62815574B3F1DC53BCC52239A6711181AF6435B98B2907DDCB9B570E29E`；immutable preregistry 哈希为 `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`。未来 H01 bootstrap `run_v25_i1_h01_formal.m` 与 `launch_v25_i1_h01_formal.cmd` 已创建并静态冻结，但在 R4 未执行；其执行状态为 `CREATED_AND_FROZEN_NOT_EXECUTED`。R4 后不再进行 parser probe。

H01 formal runtime authorization 仍为 `UNCONSUMED`，formal H01 MAT 不存在；H02/H03 仍未运行、未查看。R4 未加载正式 target、未调用 `sim()`、未启动 CarSim、未读取 holdout 性能数据。

下一阶段必须重新授权，才能通过 R4 冻结的 ASCII bootstrap 启动 H01 first-and-only formal runtime。
