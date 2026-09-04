# V2.5-G1B-R2 Isolated Clean-PREFDIR Startup Diagnostic

## 阶段结论

**V2.5-G1B-R2 ISOLATED CLEAN-PREFDIR STARTUP DIAGNOSTIC PASSED**

唯一一次授权的 isolated clean-PREFDIR startup-only probe 正常启动 MATLAB，确认
active PREFDIR 精确等于新建的隔离目录，基础 Simulink license/load 通过，并以
exit code `0` 正常退出。没有复现 `failed to load settings errors_warnings plugin`。

因此：

**MATLAB AND SIMULINK BASE STARTUP ARE HEALTHY UNDER AN ISOLATED CLEAN PREFDIR.**

**THE DEFAULT USER PREFDIR / SETTINGS STATE IS NOW STRONGLY IMPLICATED.**

**THIS DOES NOT IDENTIFY THE EXACT CORRUPT DEFAULT-PREFDIR ITEM.**

该隔离实验只证明 clean user-settings environment 改变了 startup outcome；它没有证明
具体哪个默认 settings 文件损坏，没有证明 C01 crash 导致 PREFDIR 损坏，也没有验证
CarSim、项目模型或 real-runtime 环境。

## 授权边界与执行次数

- R2 新 MATLAB process 数量：`1`。
- 新子进程 PID：`31324`。
- MATLAB startup probe：`1/1`，授权已用完，不允许第二次 R2 start。
- `sim()`：`0`。
- project runner/model load/compile：`0`。
- CarSim load/runtime：`0`。
- calibration/holdout/alpha calculation：`0`。
- 探针正常退出，未留下 PID `31324`。
- 仅剩本轮开始前已存在的 MATLAB PID `29492`，启动时间
  `2026-08-27 12:23:44.9031024 +08:00`；本轮未控制或复用该进程。

## 启动前证据

| 项目 | 值 |
|---|---|
| MATLAB executable | `D:\matlab\bin\matlab.exe` |
| executable SHA-256 | `E717C21CC33170584F474DDA03FEF013CA03EFEE63B9C84AF0D684584DB8589B` |
| likely default PREFDIR | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` |
| diagnostic candidate existed before R2 | `NO` |
| clean diagnostic PREFDIR | `D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR` |
| diagnostic directory created | `2026-08-28 22:25:10.3528489 +08:00` |
| initial file count | `0` |
| initial subdirectory count | `0` |
| ACL | inherited Modify for authenticated/sandbox users; Deny ACE count `0` |
| process-scope `MATLAB_PREFDIR` before probe | UNSET |
| persistent user-scope `MATLAB_PREFDIR` before probe | UNSET |
| persistent machine-scope `MATLAB_PREFDIR` before probe | UNSET |

该目录位于系统 TEMP，不在默认 MATLAB PREFDIR、MATLAB installation、CarSim 或项目
`model/results/docs` 目录内。默认 PREFDIR 未重命名、移动、删除、重置或编辑。

## 唯一 startup-only probe

子进程环境只对 PID `31324` 临时设置：

```text
MATLAB_PREFDIR=D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR
```

等价执行命令：

```powershell
D:\matlab\bin\matlab.exe -batch "disp('MATLAB_STARTUP_OK'); disp(version); fprintf('ACTIVE_PREFDIR=%s\n',prefdir); fprintf('SIMULINK_LICENSE=%d\n',license('test','Simulink')); load_system('simulink'); disp('SIMULINK_LOAD_OK'); close_system('simulink',0);"
```

工作目录为 `D:\SystemMigration\Temp`。命令中没有项目 `cd/addpath`、项目 runner、
项目 target、compile/update、`sim()` 或 CarSim 调用。

## 原始 probe evidence

```text
PROCESS_LAUNCH_ATTEMPTED=YES
CHILD_PID=31324
PROBE_TIMEOUT=NO
EXIT_CODE=0

STDOUT_BEGIN
MATLAB_STARTUP_OK
24.1.0.2537033 (R2024a)
ACTIVE_PREFDIR=D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR
SIMULINK_LICENSE=1
SIMULINK_LOAD_OK
STDOUT_END

STDERR_BEGIN
STDERR_END
```

| Gate | Evidence | 结果 |
|---|---|---|
| process launch attempted | `YES` | PASS |
| normal exit | exit code `0` | PASS |
| `MATLAB_STARTUP_OK` | present | PASS |
| MATLAB version | `24.1.0.2537033 (R2024a)` | PASS |
| `ACTIVE_PREFDIR` | exact clean path | PASS |
| canonical active path | `D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR` | PASS |
| Simulink license | `1` | PASS |
| `load_system('simulink')` | `SIMULINK_LOAD_OK` present | PASS |
| fatal startup error | absent | PASS |
| `errors_warnings` failure | absent | PASS |
| ApplicationService error | absent | PASS |
| settings-related stderr | absent; stderr empty | PASS |

## Clean PREFDIR post-run inventory

隔离目录被保留，未删除。MATLAB/Simulink 基础启动后：

```text
file count       = 11
subdirectory count = 1
total bytes      = 364852
```

完整 top-level 概要：

| 相对路径 | 类型 | bytes | SHA-256/说明 |
|---|---|---:|---|
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | file | 343,621 | `CD18ADA8F71345AC1F9638F3F96663B45DA3B2145AC94F09A77A116C9953D664` |
| `matlab.prf` | file | 50 | startup-generated preference file |
| `matlabPkey.p12` | file | 1,515 | startup-generated key material |
| `migratePref.txt` | file | 1 | `F67AB10AD4E4C53121B6A5FE4DA9C10DDEE905B978D3788D2723D7BFACBE28A9` |
| `MLintDefaultSettings.txt` | file | 0 | empty-file SHA `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `sdiprefs.json` | file | 8,559 | `250C8EA4A9B719AA1BC7C6666D6E2805E60DA6F21E20093E2009B0F336B85D15` |
| `signalanalyzerprefs.json` | file | 1,125 | `6E64549F8DE9940F8559720D56B090987D9A21B7FEA8E58869ABC65055986B69` |
| `stmprefs.json` | file | 8,560 | `F783E5A5DB32FD84779D689A01ACA5CDCC33A8421D2F89DC8E62986E6AACADD8` |
| `thisMatlab.pem` | file | 1,216 | startup-generated certificate material |
| `VisibleSettings.json` | file | 12 | `6284F6E4DDF8DECE42777B93ACD426B976E99423575294FD71ADCCEDDDC5C7E8` |
| `sl_toolstrip_plugins/` | directory | — | contains one file |
| `sl_toolstrip_plugins/preferences.json` | file | 193 | `02362484111F6CDF1534D44948EB23E23E636795A990D12D90C2CDFE98D1599C` |

零字节 `MLintDefaultSettings.txt` 同样由 clean startup 自动生成，因此 R1 默认 PREFDIR 中
同名零字节文件不是本次 startup failure 的充分解释。

## 默认 PREFDIR post-check

默认目录仍存在，目录 mtime 仍为 `2026-08-27 13:28:00.8495970 +08:00`。
R1 关键文件全部保持 byte-level hash 与 mtime 不变：

| 文件 | SHA-256 | 状态 |
|---|---|---|
| `cefInit.mlsettings` | `B1046A13CF485B27C54E4326CC9621A1B7ECA1D5F43ED56265CA20ECCF45D55C` | UNCHANGED |
| `matlab.mlsettings` | `0E519CCBE4CABB14BBD4A605E322B3191F5F1F8ECD9ACB461116472F79FE04A7` | UNCHANGED |
| `matlabprefs.mat` | `D2041F3A09197D31570F7675BAED98BB9A21FF58A7EC8AFBBD1DAFEA99DD22E3` | UNCHANGED |
| `Simulink.mlsettings` | `AB2BB0D6444491B50803F3D91A2DA5CFDF14007904BFBB0D877F77F449C6D938` | UNCHANGED |
| `slhistory.mlsettings` | `C887D8FED560E7B4C3194FACF2DC66BE85763DE1E2CCC6C7FCEDAD47D943FE87` | UNCHANGED |
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | `50FC4DDD1691C3E00FE0B52291465AB50F77B96E0F66BC7433566746A2F9CEBB` | UNCHANGED |
| `MLintDefaultSettings.txt` | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` | UNCHANGED |

探针结束后 process/user/machine 三个 scope 的 `MATLAB_PREFDIR` 仍全部 UNSET；未调用
`setx`，没有创建永久 user/system environment variable。

## 冻结完整性

| Artifact | SHA-256 | 状态 |
|---|---|---|
| `model/vx_vy_fixed_fusion_v2_5.slx` | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | UNCHANGED |
| `model/vy_fixed_weight_fusion_step.m` | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | UNCHANGED |
| `model/vy_fixed_weight_fusion_simulink_sfun.m` | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | UNCHANGED |
| `model/vy_feedback_propagation_step.m` | `80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF` | UNCHANGED |
| `model/vx_vy_parallel_dk_v2_3.slx` | `98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0` | UNCHANGED |
| `model/vx_vy_dekf_v1_17.slx` | `108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE` | UNCHANGED |
| `model/vx_vy_kkf_v2_1.slx` | `B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712` | UNCHANGED |
| `model/vx_vy_dkekf_v2_2.slx` | `E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15` | UNCHANGED |
| `model/vx_vy_feedback_track_v2_4.slx` | `951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84` | UNCHANGED |
| `model/simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | UNCHANGED |
| V2.5-F plan | `97E3D7C9C3F35853372702A8CC545FEB02D9C182CEC012D47BA177D19673F230` | UNCHANGED |
| V2.5-F suite CSV | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` | UNCHANGED |
| V2.5-F registry CSV | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` | UNCHANGED |
| R1 audit report | `6732ABC5CE3C6E6AB550DD1175FD02ADF744ED86B156934EA9A28076B3D791B4` | UNCHANGED |

## 项目状态锁定

- `FWCAL_C01 = FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- `FWCAL_C02–C05 = NOT RUN`
- holdout = `UNTOUCHED`
- `alpha_D / alpha_K / alpha_F = UNSELECTED`
- G1B 0.20-s real-runtime authorization = `UNCONSUMED`

## 下一阶段

唯一允许的下一阶段：

**V2.5-G1B-R3 DEFAULT-PREFDIR REMEDIATION DECISION / CONTROLLED RECOVERY PLAN**

R3 用于决定如何保留原 settings evidence，以及如何建立可重复的正式 MATLAB startup
policy。R2 不授权直接以 clean PREFDIR 运行 G1B CarSim diagnostic，也不授权删除或重置
默认 PREFDIR。

## 必需声明

THE DEFAULT PREFDIR WAS NOT MODIFIED.

NO CARSIM RUNTIME WAS ATTEMPTED.

THE G1B REAL-RUNTIME AUTHORIZATION REMAINS UNCONSUMED.
