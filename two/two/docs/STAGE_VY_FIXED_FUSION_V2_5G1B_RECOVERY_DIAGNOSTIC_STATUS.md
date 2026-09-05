# V2.5-G1B Controlled CarSim Runtime Recovery Diagnostic Status

## 阶段结论

**V2.5-G1B CONTROLLED CARSIM RUNTIME RECOVERY DIAGNOSTIC PASSED**

R4 fresh default PREFDIR 恢复后，原 V2.5-G1B 唯一授权的真实 CarSim runtime
已使用一次。已知良好的 V2.5-D 控制配置在 `0.20 s` 正常完成，CarSim 使用
D: 安装的 solver/MEX，未复现 `0xC0000005`，并生成完整 runtime evidence。

本结果只证明 known-good 短时基础设施路径恢复，不是 calibration，也不能证明未来
16-s C01 replacement 一定成功。

## Authorization accounting

| Item | Result |
|---|---|
| authorized real-runtime count | `1` |
| `sim()` calls used | `1` |
| second `sim()` | `NO` |
| original G1B authorization | `CONSUMED` |
| calibration/holdout use | `NO` |
| data role | `RUNTIME_RECOVERY_DIAGNOSTIC` |

## Pre-runtime hard gates

运行前只读门禁：

```text
MATLAB_ENUM_OBJECT_COUNT=1
LIVE_MATLAB_PROCESS_COUNT=0
MATLAB_PREFDIR_PROCESS=<UNSET>
MATLAB_PREFDIR_USER=<UNSET>
MATLAB_PREFDIR_MACHINE=<UNSET>
PRE_SIM_GATE=PASS
```

R4 证据、fresh default PREFDIR、forensic backup 和 R2 clean isolation evidence 均存在。
R4 status/manifest/summary/inventory 哈希全部与已登记值一致。

runner 只增加了实际 `prefdir` evidence 与 exact-path assertion；analyzer 只增加对应
gate。控制参数、模型、CarSim dataset 和估计器逻辑均未修改。

## MATLAB startup and active PREFDIR

同一个 runtime session 在进入 runner 前输出：

```text
G1B_STARTUP_GATE|version=24.1.0.2537033 (R2024a)
G1B_PREFDIR_GATE|active=C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a|environment=<UNSET>|exact=1
```

active PREFDIR 精确为 R4 newly regenerated default：

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
```

它既不是：

```text
D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR
```

也不是：

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a_V25G1B_BAD_BACKUP_20260828T150506Z
```

未设置或覆盖 `MATLAB_PREFDIR`，未复制旧 settings。没有出现 `errors_warnings` 或
ApplicationService fatal startup error。

## Exact control condition

| Parameter | Value |
|---|---|
| target | `model/vx_vy_fixed_fusion_v2_5.slx` |
| target SHA-256 | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` |
| StopTime | `0.20 s` |
| steering amplitude | `0.02 rad` |
| steering frequency | `0.40 Hz` |
| waveform | sine |
| front steering | FL/FR same phase |
| rear steering | RL/RR = 0 |
| speed scope | existing verified approximately 20 m/s class |

未使用 `0.30 Hz`、`16 s` 或任何 `FWCAL_C01` row。

## Immediate pre-sim environment

唯一 `sim()` 邻接门禁原始摘要：

```text
role=RUNTIME_RECOVERY_DIAGNOSTIC
pwd=D:\UsersData\桌面\two\model
simfile=D:\UsersData\桌面\two\model\simfile.sim
simfileHash=A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA
PROGDIR=D:\carsim\CarSim2021.0_Prog\
DATADIR=D:\carsim\CarSim2021.0_Data\
solver=D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
mex=D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64
prefdirEnv=<UNSET>
activePrefdir=C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
StopTime=0.20
A=0.02
f=0.40
G request=NO
```

全部门禁 PASS 后，`sim()` 被调用一次，authorization 随即消费。

## CarSim runtime evidence

CarSim 控制台证据：

```text
Use vehicle solver: D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
CarSim 2021.0
Revision 153671, December 9, 2020
Termination at simulation time = 0.2 s.
```

runner completion evidence：

```text
V25G1B_RUNTIME_OK|role=RUNTIME_RECOVERY_DIAGNOSTIC|simCalled=1|completed=1|carSim=1|stop=0.20000000000000001|solver=D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll|gRequest=0|targetUnchanged=1
```

结果：

- MATLAB startup healthy；
- fresh default PREFDIR active；
- CarSim initialized successfully；
- simulation completed `0.20 s`；
- `0xC0000005` not observed；
- D: solver and D: MEX confirmed；
- G: request absent；
- runtime logs produced。

## Saved-evidence analyzer recovery

runtime 已完成且 MAT 已保存后，同一 combined batch 的 analyzer 在旧第 55 行遇到：

```text
MATLAB:m_improper_grouping
Invalid expression / unmatched delimiter
```

精确根因是 `struct(...)` 缺一个右括号。这是纯 evidence analyzer syntax defect，发生在
`V25G1B_RUNTIME_OK` 之后，不是 MATLAB startup、Simulink、CarSim 或 estimator runtime
错误。该 combined batch 因显式 error handling 以 exit code `1` 结束；MATLAB/CarSim
没有 crash。

只补充该右括号后，启动一个新的 analyzer-only MATLAB session 读取同一 MAT。该命令
未调用 runner、`sim()` 或 CarSim，exit code 为 `0`：

```text
V25G1B_ANALYSIS|gates=17/17|N=[21 21 21 21]|dt=0.01|feedbackApplied=0|replay=[0 0 0 0]|role=RUNTIME_RECOVERY_DIAGNOSTIC|passed=1|sim=0
G1B_SAVED_EVIDENCE_ANALYSIS_OK
```

因此最终证据处理链正常完成，且没有制造第二份 runtime evidence。

## Runtime integrity and semantics

| Gate | Evidence | Result |
|---|---|---|
| D samples | `21` | PASS |
| K samples | `21` | PASS |
| F samples | `21` | PASS |
| fusion samples | `21` | PASS |
| common mean dt | `0.01 s` | PASS |
| D/K/F/fusion timestamps | same index; pairwise max difference `0` | PASS |
| D Ay updates | `5` | PASS |
| D state/P/diag replay | all errors `<=1e-12`; reported state max `0` | PASS |
| K Ax/Ay/AVz/Vx samples | `21/21/21/21` | PASS |
| K state/P/diag replay | all errors `<=1e-12`; reported state max `0` | PASS |
| F feedbackApplied==1 | `0` | PASS |
| F Vy/P/diag replay | all errors `<=1e-12`; reported Vy max `0` | PASS |
| fusion current-sample replay | max difference `0` | PASS |
| D/K covariance | finite, symmetric, positive minimum eigenvalue | PASS |
| F covariance | finite and nonnegative | PASS |
| frozen integrity gate | unchanged | PASS |
| analyzer total | `17/17` | PASS |

未计算 calibration RMSE、candidate alpha、best track、weight ranking 或任何 truth-based
tuning。

## Evidence artifacts

| Artifact | SHA-256 |
|---|---|
| `results/vy_fixed_fusion_v2_5g1b_recovery_diagnostic.mat` | `030CE3FDE238641D046D9DC9DABF07AFE75BB00F38CB12E0181F6755C4A7CC12` |
| `model/run_vy_fixed_fusion_v2_5g1b_recovery_diagnostic.m` | `A0D48FEDAC7C29198EAB1B730C278B89E3BD8E4CCCAE60396E8A417FF0A5B3CA` |
| `model/analyze_vy_fixed_fusion_v2_5g1b_recovery_diagnostic.m` | `0FF7C6208ECD4AF6221AAC6464B777166E078CBA2309FBFEC942DE035ABE09DC` |

MAT role 固定为 `RUNTIME_RECOVERY_DIAGNOSTIC`，`calibrationEligible=false`，
`holdoutEligible=false`。该 MAT 永久排除于 V2.5-H calibration matrix。

## Frozen integrity

runtime 与 analyzer 完成后：

```text
POST_FROZEN_MISMATCH_COUNT=0
LIVE_MATLAB_PROCESS_COUNT=0
MATLAB_PREFDIR_PROCESS=<UNSET>
MATLAB_PREFDIR_USER=<UNSET>
MATLAB_PREFDIR_MACHINE=<UNSET>
```

关键冻结哈希：

| Artifact | SHA-256 | Status |
|---|---|---|
| fixed-fusion target | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | UNCHANGED |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | UNCHANGED |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | UNCHANGED |
| F core | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| parallel target | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |
| D target | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | UNCHANGED |
| K target | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | UNCHANGED |
| DK-EKF target | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | UNCHANGED |
| F target | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |

No estimator, SLX or CarSim dataset modification was required.

## Project state lock

- `FWCAL_C01 = FAILED_INFRASTRUCTURE / NO_USABLE_DATA`
- `FWCAL_C02–C05 = NOT RUN`
- holdout = `UNTOUCHED`
- `alpha_D / alpha_K / alpha_F = UNSELECTED`

## Required declarations

FRESH DEFAULT-PREFDIR MATLAB/SIMULINK RECOVERY REMAINS HEALTHY.

THE KNOWN-GOOD V2.5-D 0.20-S CARSIM RUNTIME PATH IS HEALTHY AGAIN.

CARSIM INITIALIZATION COMPLETED SUCCESSFULLY.

THE PRIOR C01 0xC0000005 FAILURE WAS NOT REPRODUCED UNDER THE KNOWN-GOOD CONTROL CONFIGURATION.

THIS DOES NOT PROVE THAT A 16-S C01 REPLACEMENT WILL SUCCEED.

NO ESTIMATOR / SLX / CARSIM DATASET CHANGE WAS REQUIRED.

DIAGNOSTIC DATA ARE EXCLUDED FROM CALIBRATION.

FWCAL_C01 REMAINS FAILED-INFRASTRUCTURE / NO_USABLE_DATA.

C02-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D/K/F REMAIN UNSELECTED.

C01 failure classification remains:

**TRANSIENT / EXTERNAL CARSIM RUNTIME-ENVIRONMENT FAILURE — NOT FURTHER RESOLVED**

READY FOR V2.5-G1C C01 REPLACEMENT REMEDIATION PREREGISTRATION
