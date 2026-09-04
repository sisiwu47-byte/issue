# V2.4-D2 Reset Timeline Fix Validation Status

## 阶段结论

`V2.4-D2 RESET TIMELINE FIX VALIDATION PASSED`

V2.4-D 总体状态：

`V2.4-D FEEDBACK / PROPAGATION STANDALONE RUNTIME VALIDATION ACCEPTED AFTER RUNNER TIMELINE FIX`

## 实际变更与运行边界

本阶段只创建/修改了 runner、离线 analyzer、本次新结果和本状态文档：

- `model/run_vy_feedback_track_v2_4d2_reset_fix.m`
- `model/analyze_vy_feedback_track_v2_4d2_reset_fix.m`
- `results/vy_feedback_track_v2_4d2_reset_fix_validation.mat`
- `docs/STAGE_VY_FEEDBACK_TRACK_V2_4D2_STATUS.md`

未创建或修改任何 SLX。未 rebuild，未调用 `save_system`，未修改 frozen core 或 S-function。没有 D/K 轨迹、融合、LifeSig、真实 Vy 或 CarSim。

唯一被测修复是 runner 的测试输入时间轴：

```matlab
tick = (0:20).';
t = tick * Ts;
```

所有事件均由固定 MATLAB 1-based sample index 设置；没有用浮点时间相等判断寻找事件。

## 执行纪律

首次 batch 在 `sim()` 之前通过了时间轴硬门禁，但 runner 的纯 evidence 汇总使用 `cell2mat` 混合数值/逻辑标量而退出。该次没有生成新结果文件，也没有调用仿真。只将 evidence 汇总改为逐字段布尔合取后，启动新的 batch；后者是唯一实际调用 `sim()` 的 D2 runtime。没有第三次 runtime。

实际 MATLAB 命令：

```powershell
& 'D:\matlab\bin\matlab.exe' -batch "cd('D:\UsersData\桌面\two'); addpath(fullfile(pwd,'model')); try, runtime=run_vy_feedback_track_v2_4d2_reset_fix(); analysis=analyze_vy_feedback_track_v2_4d2_reset_fix(); disp('V2_4D2_RUNTIME_AND_ANALYSIS_OK'); catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end; exit(0)"
```

最终 batch exit code 为 0，并打印 `V2_4D2_RUNTIME_AND_ANALYSIS_OK`。

## Pre-sim 时间轴与输入硬门禁

| 项目 | 实际证据 | 结果 |
|---|---:|---|
| 新时间轴 / 原失败 runtime 实际 F timestamps | 21 / 21 samples | PASS |
| `maxAbsTimeDiff` | 0 s | PASS |
| `isequal(tNew,tPrevious)` | true | PASS |
| index 16 `tNew` | 0.14999999999999999 s | PASS |
| index 16 previous actual F hit | 0.14999999999999999 s | PASS |
| index 16 difference | 0 s | PASS |
| container | double matrix `[time value]` | PASS |
| seven sources use same time vector | true | PASS |
| strictly increasing | true | PASS |
| duplicate timestamps | 0 | PASS |
| reset nonzero indices | `[1;16]` | PASS |
| feedback-valid nonzero indices | `[1;9;16]` | PASS |
| reset source `Interpolate` | off | PASS |

固定输入为 `Ay_IMU=1.0`、`AVz_IMU=0.1`、`Vx_source=20.0`，故非 reset hit 的 `prop_term=-1.0 m/s^2`、`deltaVy=-0.01 m/s`。index 9 feedback 为 `(Vy,P)=(1.0,0.25)`；index 16 为 `(5.0,0.75)`。index 1 延续原测试的 `(2.0,0.8)`。

## Runtime 基础证据

| 项目 | 实际值 | 结果 |
|---|---:|---|
| `simCalled` | 1 | PASS |
| `simulationCompleted` | 1 | PASS |
| CarSim | 0 | PASS |
| samples | 21 | PASS |
| start / end | 0 / 0.20000000000000001 s | PASS |
| dt min | 0.0099999999999999811 s | PASS |
| dt mean | 0.01 s | PASS |
| dt max | 0.010000000000000009 s | PASS |
| actual rate | 100 Hz | PASS |
| missing hits / duplicate timestamps | 0 / 0 | PASS |
| analyzer gates | 24 / 24 | PASS |
| outputs finite | true | PASS |
| P nonnegative | true | PASS |

`P0_F=0.5`、`Q_F=0.0025` 未调整，继续登记为 **TEST-ONLY / UNTUNED / UNFROZEN**。

## 关键事件表

| index | actual time (s) | reset | current valid | current Vy fb | current P fb | Vy_F | P_F | prop_term | deltaVy | feedbackApplied |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 1 | 1 | 2 | 0.8 | 0 | 0.5 | 0 | 0 | 0 |
| 2 | 0.01 | 0 | 0 | 0 | 0.5 | -0.01 | 0.5025 | -1 | -0.01 | 0 |
| 9 | 0.08 | 0 | 1 | 1 | 0.25 | -0.08 | 0.52 | -1 | -0.01 | 0 |
| 10 | 0.09 | 0 | 0 | 0 | 0.5 | 0.99 | 0.2525 | -1 | -0.01 | 1 |
| 11 | 0.10 | 0 | 0 | 0 | 0.5 | 0.98 | 0.255 | -1 | -0.01 | 0 |
| 16 | 0.14999999999999999 | 1 | 1 | 5 | 0.75 | 0 | 0.5 | 0 | 0 | 0 |
| 17 | 0.16 | 0 | 0 | 0 | 0.5 | -0.01 | 0.5025 | -1 | -0.01 | 0 |

由此确认：

- t=0 initial reset：PASS。
- t=0.01 reset hit 的 current feedback 未被捕获：PASS。
- t=0.08 current feedback non-direct-feedthrough：PASS。
- t=0.09 one-sample delayed feedback：PASS。
- t=0.10 propagation continuity：PASS。
- t=0.15 second reset priority：PASS，且 `Vy_F=Vy_F0=0`、`P_F=P0_F=0.5`、`diag=[0;0;0]`。
- t=0.16 reset-delay clear：PASS，且 `feedbackApplied=0`。

没有独立 port-7 signal logger。第二次 reset delivery 由三层联合证据确认：source breakpoint 与 actual scheduler timestamp 逐位相同；D1 已确认 input 7 direct-feedthrough/arbitrary-hit reset 语义；runtime 在 index 16 出现唯一 reset signature。因此：

`SECOND RESET DELIVERY TO F-TRACK IS VERIFIED BEHAVIORALLY AND TEMPORALLY.`

## Frozen-core exact replay 与 one-hit 语义

离线 replay 使用本次 corrected runtime 的实际输入，按相同 index 调用 frozen `vy_feedback_propagation_step`，没有 timestamp/index shift：

| replay gate | max absolute difference | 结果 |
|---|---:|---|
| Vy_F | 0 | PASS |
| P_F | 0 | PASS |
| diagnostics | 0 | PASS |

阈值为 `1e-12`。21 个 actual 100-Hz timestamps、exact replay 以及既有 Outputs/Update 结构共同证明：

`ONE 100-HZ HIT = ONE COMMITTED F-TRACK STATE/COVARIANCE ADVANCE: PASS.`

## Hash 完整性

| 文件/角色 | SHA-256 | 状态 |
|---|---|---|
| runtime validation model | `B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A` | UNCHANGED |
| accepted V2.4-C target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |
| frozen F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| accepted F S-function | `2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0` | UNCHANGED |
| frozen parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |
| original failed V2.4-D MAT | `5B1376DCA2884636E675B5AAAD2266707D136DFF85C804B921E209A49D9A5C8C` | PRESERVED |
| original V2.4-D status | `05C1BC3C25912D8BA521DA5BC3270817FD510F25F818D161D9657832BC543359` | PRESERVED |
| new D2 result MAT | `EB0F3C69E0C3F8C2009933AD90453E7FE1356FD48F080C17383409BD52E87DB8` | NEW EVIDENCE |

Runner 在 runtime 前后逐项核对 frozen D-EKF、K-KF、DK-EKF 及其 core/wrapper/adapter；16/16 frozen dependency hashes 均与基线相同。独立 post-run PowerShell SHA-256 复核同样为 16/16 match。

## 最终声明

ORIGINAL V2.4-D FAILURE WAS CAUSED BY FROM-WORKSPACE BREAKPOINT / FUNCTION-CALL FLOATING-TIME MISALIGNMENT.

NO F-TRACK MATHEMATICS OR SIMULINK INTEGRATION CHANGE WAS REQUIRED.

SECOND RESET DELIVERY IS NOW VERIFIED.

ONE-SAMPLE FEEDBACK DELAY REMAINS VERIFIED.

RESET PRIORITY AND DELAY CLEARING ARE VERIFIED.

EXACT REPLAY PASSED.

ONE-HIT / ONE-COMMIT PASSED.

NO D/K COUPLING WAS INTRODUCED.

NO FUSION WAS PERFORMED.

NO LIFESIG WAS IMPLEMENTED.

Q_F AND P0_F REMAIN TEST-ONLY / UNTUNED / UNFROZEN.

NO CARSIM WAS USED.

READY FOR V2.4-E FEEDBACK / PROPAGATION TRACK FINAL ACCEPTANCE & IMPLEMENTATION FREEZE
