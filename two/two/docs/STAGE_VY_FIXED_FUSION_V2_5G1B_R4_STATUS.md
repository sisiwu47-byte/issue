# V2.5-G1B-R4 Controlled Default-PREFDIR Regeneration Status

## 阶段结论

**V2.5-G1B-R4 CONTROLLED DEFAULT-PREFDIR REGENERATION & STARTUP VALIDATION PASSED**

旧 default PREFDIR 已完整建档并在同一文件系统内原子改名为 forensic backup；
全部 11,810 个可读普通文件在 rename 前后逐文件 SHA-256 精确一致。保持
`MATLAB_PREFDIR=UNSET` 后，MATLAB 在 expected default path 自动生成 fresh PREFDIR，
MATLAB startup 与基础 Simulink load 均通过，`errors_warnings` fatal startup failure 未复现。

本阶段没有加载项目模型、调用 `sim()`、运行 CarSim 或 calibration。

## MATLAB process hard gate

恢复 R4 时实时枚举结果：

```text
MATLAB_ENUM_OBJECT_COUNT = 1
LIVE_MATLAB_PROCESS_COUNT = 0
STALE_EXITED_OBJECT_IGNORED = PID 29492, HasExited=True
```

PID 29492 不再是当前存活进程。只有 `currently existing + HasExited=False` 的进程
会被计为 blocker，因此 R4 process hard gate PASS。未执行 `taskkill`、
`Stop-Process` 或任何强制终止。

**THE PREVIOUS MATLAB PROCESS BLOCKER WAS A STALE / EXITED PROCESS OBJECT, NOT A CURRENT LIVE MATLAB PROCESS.**

## Exact PREFDIR paths

| Role | Exact path |
|---|---|
| old failed default before rename | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` |
| forensic backup | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a_V25G1B_BAD_BACKUP_20260828T150506Z` |
| fresh regenerated default | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` |
| R2 isolation evidence | `D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR` |

R2 isolation directory 未被 rename、delete、reuse 或复制到 fresh default；其角色仍为
`ISOLATION_DIAGNOSTIC_EVIDENCE`。

## Old PREFDIR preservation manifest

在任何 rename/startup 前生成完整 recursive manifest：

| Evidence | Value |
|---|---|
| manifest | `results/vy_fixed_fusion_v2_5g1b_r4_old_prefdir_manifest.csv` |
| manifest SHA-256 | `6608DCB3E02B12F7B89EBD93E8AF5890C854096D80D01AAB383561383B822BFA` |
| summary | `results/vy_fixed_fusion_v2_5g1b_r4_old_prefdir_summary.csv` |
| summary SHA-256 | `43A9B4567387972CDB833CDA60638FA02D05CDBE4943A4CD4F3EBE66FEA79AD2` |
| regular files | `11,810` |
| directories | `805` |
| total regular-file bytes | `160,541,772` |
| hashable files | `11,810` |
| unreadable files | `0` |
| enumeration errors | `0` |
| links/junctions | `0` |
| root owner | `BUILTIN\Administrators` |
| filesystem | same `C:` NTFS volume |

manifest 为每个 entry 保存 relative path、类型、大小、creation/mtime、attributes、
SHA-256、hash/read status；不存在跨 junction 递归。

## Same-filesystem atomic rename

rename 前所有 hard gates 均通过：

- live MATLAB count `0`；
- process/user/machine `MATLAB_PREFDIR` 全部 UNSET；
- exact old path exists；
- manifest/summary hash exact；
- unique destination absent；
- old/backup parent exact相同。

执行一次：

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
→
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a_V25G1B_BAD_BACKUP_20260828T150506Z
```

未 delete、copy-and-delete 或修改旧目录内容。

## Backup pre/post verification

| Gate | Pre | Post | 结果 |
|---|---:|---:|---|
| regular file count | 11,810 | 11,810 | PASS |
| directory count | 805 | 805 | PASS |
| total bytes | 160,541,772 | 160,541,772 | PASS |
| hash match count | 11,810 | 11,810 | PASS |
| hash mismatch | 0 | 0 | PASS |
| missing files | 0 | 0 | PASS |
| unexpected files | 0 | 0 | PASS |
| missing directories | 0 | 0 | PASS |
| unexpected directories | 0 | 0 | PASS |
| owner match | — | `True` | PASS |
| ACL/SDDL match | — | `True` | PASS |

**THE FAILED DEFAULT PREFDIR WAS PRESERVED IN FULL AS A FORENSIC BACKUP.**

**PRE/POST BACKUP HASH VERIFICATION PASSED.**

forensic backup 后续不得 edit、merge、copy back 或 delete。

## Fresh default pre-start gate

唯一 startup probe 前：

```text
LIVE MATLAB PROCESS COUNT = 0
expected default PREFDIR exists = False
forensic backup exists = True
backup files/directories = 11810 / 805
R2 clean PREFDIR untouched = True
process MATLAB_PREFDIR = UNSET
user MATLAB_PREFDIR = UNSET
machine MATLAB_PREFDIR = UNSET
all project/reference hashes = UNCHANGED
```

全部门禁 PASS 后才启动 MATLAB。

## Sole startup-only probe

R4 startup authorization 使用一次且仅一次。新 MATLAB child PID 为 `4788`，工作目录为
`D:\SystemMigration\Temp`，child environment 中没有 `MATLAB_PREFDIR` key。

等价命令：

```powershell
D:\matlab\bin\matlab.exe -batch "disp('MATLAB_STARTUP_OK'); disp(version); fprintf('ACTIVE_PREFDIR=%s\n',prefdir); fprintf('SIMULINK_LICENSE=%d\n',license('test','Simulink')); load_system('simulink'); disp('SIMULINK_LOAD_OK'); close_system('simulink',0);"
```

原始 evidence：

```text
PROCESS_LAUNCH_ATTEMPTED=YES
CHILD_PID=4788
EXIT_CODE=0

STDOUT_BEGIN
MATLAB_STARTUP_OK
24.1.0.2537033 (R2024a)
ACTIVE_PREFDIR=C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
SIMULINK_LICENSE=1
SIMULINK_LOAD_OK
STDOUT_END

STDERR_BEGIN
STDERR_END
```

| Startup gate | Result |
|---|---|
| MATLAB process started | PASS |
| `MATLAB_STARTUP_OK` | PASS |
| version reported | `24.1.0.2537033 (R2024a)` |
| active PREFDIR exact expected fresh path | PASS |
| active PREFDIR differs from R2 clean path | PASS |
| active PREFDIR differs from backup path | PASS |
| exit code | `0` |
| Simulink license | `1` |
| `SIMULINK_LOAD_OK` | PASS |
| stderr fatal error | NO |
| `errors_warnings` fatal error | NO |
| ApplicationService fatal error | NO |

**MATLAB_PREFDIR REMAINED UNSET.**

**MATLAB CREATED A FRESH DEFAULT PREFDIR.**

**MATLAB STARTUP PASSED.**

**SIMULINK BASE LOAD PASSED.**

**THE errors_warnings STARTUP FAILURE DID NOT RECUR.**

## Fresh default PREFDIR inventory

MATLAB 自动创建的 fresh default evidence：

| Item | Value |
|---|---|
| path | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` |
| creation time | `2026-08-28 23:07:00.9599963 +08:00` |
| last-write time at inventory | `2026-08-28 23:07:27.5356972 +08:00` |
| regular files | `12` |
| directories | `1` |
| total bytes | `322,225` |
| owner | `BUILTIN\Administrators` |
| inventory | `results/vy_fixed_fusion_v2_5g1b_r4_fresh_prefdir_inventory.csv` |
| inventory SHA-256 | `0634D9510EDC2582D166F4995E5EECE6F44C6F179E5F59A04A6F57427A1467D6` |

inventory 包含 root metadata、所有 entry、settings-related 标记、大小、时间、attributes
与可读普通文件 SHA-256。没有执行任何 old-to-fresh copy/merge。

**NO OLD SETTINGS WERE COPIED INTO THE FRESH PREFDIR.**

## R2 evidence and permanent environment

R2 clean directory post-check：11 files、1 directory、364,852 bytes，R2 report 后更新
文件数 `0`。R2 report SHA-256 仍为：
`41E64D6746E547A1CEF5AF4E4F6A51E0917E5E925259E1B92EE077B56FD56CCB`。

startup 后 process/user/machine 三个 scope 的 `MATLAB_PREFDIR` 仍全部 UNSET；没有使用
`setx` 或 permanent override。

## Frozen project integrity

| Artifact | SHA-256 | 状态 |
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
| `model/simfile.sim` | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | UNCHANGED |
| V2.5-F plan | `97E3D7C9C3F35853372702A8CC545FEB02D9C182CEC012D47BA177D19673F230` | UNCHANGED |
| V2.5-F suite | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` | UNCHANGED |
| V2.5-F registry | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` | UNCHANGED |
| R1 report | `6732ABC5CE3C6E6AB550DD1175FD02ADF744ED86B156934EA9A28076B3D791B4` | UNCHANGED |
| R2 report | `41E64D6746E547A1CEF5AF4E4F6A51E0917E5E925259E1B92EE077B56FD56CCB` | UNCHANGED |
| R3 report | `2ED82CB63398282F925817B4F7DC851DD54976F313102440A37586887707FA12` | UNCHANGED |

## Project state

- `FWCAL_C01 = FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- `FWCAL_C02–C05 = NOT RUN`
- holdout = `UNTOUCHED`
- `alpha_D / alpha_K / alpha_F = UNSELECTED`
- original V2.5-G1B 0.20-s real-runtime authorization = `UNCONSUMED`

R4 只恢复 MATLAB/Simulink 基础 startup health；没有证明 exact corrupt item，未验证
CarSim，也未授权 C01 retry。

## Required declarations

THE FAILED DEFAULT PREFDIR WAS PRESERVED IN FULL AS A FORENSIC BACKUP.

PRE/POST BACKUP HASH VERIFICATION PASSED.

MATLAB_PREFDIR REMAINED UNSET.

MATLAB CREATED A FRESH DEFAULT PREFDIR.

MATLAB STARTUP PASSED.

SIMULINK BASE LOAD PASSED.

THE errors_warnings STARTUP FAILURE DID NOT RECUR.

NO OLD SETTINGS WERE COPIED INTO THE FRESH PREFDIR.

NO CARSIM RUNTIME WAS ATTEMPTED.

THE ORIGINAL V2.5-G1B REAL-RUNTIME AUTHORIZATION REMAINS UNCONSUMED.

READY TO RESUME V2.5-G1B CONTROLLED CARSIM RUNTIME RECOVERY DIAGNOSTIC
