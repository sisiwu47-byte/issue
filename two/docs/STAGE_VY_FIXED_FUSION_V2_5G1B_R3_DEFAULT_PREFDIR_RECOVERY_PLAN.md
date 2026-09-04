# V2.5-G1B-R3 Default-PREFDIR Controlled Recovery Plan

## 阶段结论

**V2.5-G1B-R3 DEFAULT-PREFDIR CONTROLLED RECOVERY PLAN ACCEPTED**

本阶段只冻结恢复决策和未来操作顺序，没有实施恢复、启动 MATLAB、变更 PREFDIR、
加载项目或运行 CarSim。

R1 未发现 installation-side 明确缺陷；R2 使用同一 MATLAB installation 和一个全新
isolated PREFDIR 时，MATLAB 与基础 Simulink 均正常启动。因此当前证据边界是：

**THE DEFAULT USER PREFDIR / SETTINGS STATE IS STRONGLY IMPLICATED BY THE CLEAN-PREFDIR CONTROL TEST.**

**THE EXACT CORRUPT ITEM REMAINS UNIDENTIFIED.**

不得把任何单独 JSON、cache、`.mlsettings` 或 `errors_warnings` 文件描述为已证明损坏。

## 已确认的旧 default PREFDIR

R1/R3 文件系统 evidence 能唯一识别当前 release 的默认用户目录：

| 项目 | 值 |
|---|---|
| exact path | `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` |
| release | `R2024a` |
| exists | `YES` |
| creation time | `2026-08-23 22:01:06.6431055 +08:00` |
| directory last-write time | `2026-08-27 13:28:00.8495970 +08:00` |
| regular file count | `11,810` |
| subdirectory count | `805` |
| total regular-file bytes | `160,541,772` |

Process/user/machine 三个 scope 的 `MATLAB_PREFDIR` 当前均为 UNSET。R4 的正式恢复目标
继续保持该 policy，不得使用 `setx` 或长期指向其他目录。

## 恢复策略候选审计

| 候选 | 风险 | 可回滚性 | 证据支持 | 项目复现性影响 | 对无关 MATLAB 用户设置的影响 | 决策 |
|---|---|---|---|---|---|---|
| A. 逐个删除/编辑 settings 文件 | 高：根因文件未知，容易删错或遗漏组合状态 | 中低：除非逐文件完整备份，否则难以还原状态 | 弱；R1 未定位具体损坏项 | 差：恢复步骤依赖猜测和机器特定文件 | 可能选择性破坏个人设置 | **REJECTED** |
| B. 永久 project-specific `MATLAB_PREFDIR` | 中：会形成第二套长期 settings policy，掩盖默认环境故障 | 高：取消变量即可，但生产与默认环境分叉 | 中：R2 证明隔离目录能启动，但只证明诊断隔离 | 差到中：项目运行依赖额外环境变量，偏离 V2.5-D 成功策略 | 默认个人设置被绕过；长期出现双环境 | **NOT RECOMMENDED** |
| C. 完整保全旧 default PREFDIR，再让 MATLAB 自动生成 fresh default | 中：需严格控制目录改名和一次启动，但不删除内容 | 高：旧目录完整保留，可通过明确回滚恢复 | 强：直接利用 R2 的 clean-settings 对照结论 | 最佳：恢复 `MATLAB_PREFDIR=UNSET`，最接近成功 V2.5-D policy | fresh 环境暂不含旧个人偏好，但旧偏好完整保存在 backup | **RECOMMENDED** |
| D. MATLAB reinstall | 高成本、高扰动，可能影响 license/add-ons/toolchain | 中低：安装状态恢复复杂 | 弱；R2 已证明相同 installation 可正常启动并加载 Simulink | 差：引入大范围环境变化 | 高：影响所有 MATLAB 使用场景 | **NOT JUSTIFIED** |

正式推荐：

**C. BACKUP OLD DEFAULT PREFDIR + REGENERATE FRESH DEFAULT PREFDIR**

该方案不猜具体坏文件、不重装 MATLAB、不删除旧 settings，并恢复历史成功环境采用的
默认 `MATLAB_PREFDIR=UNSET` policy。

## R2 diagnostic PREFDIR 的固定角色

```text
D:\SystemMigration\Temp\V25G1B_R2_CLEAN_PREFDIR
ROLE = ISOLATION_DIAGNOSTIC_EVIDENCE
```

该目录不得升级为 project production PREFDIR，不得用于 CarSim、calibration 或项目
runtime，不得复制项目 preferences 进去，也不得成为永久 `MATLAB_PREFDIR`。

R3 只读核对：

- 目录存在；11 files、1 subdirectory、364,852 bytes。
- 最新文件 mtime 为 `2026-08-28 22:27:40.4774836 +08:00`，早于 R2 report mtime。
- R2 report 生成后更新的 clean-PREFDIR 文件数量为 `0`。
- R2 report SHA-256：
  `41E64D6746E547A1CEF5AF4E4F6A51E0917E5E925259E1B92EE077B56FD56CCB`，UNCHANGED。

## R4 前置停止条件

未来 R4 在任何变更前必须同时满足：

1. exact old path 仍为上文 R2024a 路径，且文件数、目录数与关键 hash 没有未解释变化；
2. process/user/machine `MATLAB_PREFDIR` 均为 UNSET；
3. 所有 MATLAB 进程均已正常关闭；若仍存在 PID 或目录占用，R4 必须停止，不得强制改名；
4. backup destination 不存在；
5. R2 diagnostic PREFDIR 保持 untouched；
6. 项目冻结 hash 仍一致；
7. R4 已明确授权一次 preservation/rename 和一次 startup-only probe。

当前仍存在的历史 MATLAB PID `29492` 不是 R3 创建的。R3 不终止它；R4 在开始
preservation 前必须重新核对并要求所有 MATLAB 进程退出。

## 旧 PREFDIR 完整 preservation 规范

**THE OLD DEFAULT PREFDIR WILL BE PRESERVED IN FULL BEFORE ANY RECOVERY ACTION.**

R4 必须先生成不可变 recursive manifest。每个条目至少包含：

| 字段 | 要求 |
|---|---|
| `relative_path` | 相对于旧 R2024a 根目录；不得只存绝对路径 |
| `entry_type` | regular file / directory / reparse point |
| `size_bytes` | regular file 实际大小 |
| `creation_time_utc` | 可解析 UTC 时间 |
| `last_write_time_utc` | 可解析 UTC 时间 |
| `attributes` | Windows file attributes |
| `sha256` | 每个可读 regular file；目录留空 |
| `hash_status` | `OK` 或 exact read/hash error |

另需记录：

- root exact path、release、owner 和完整 ACL/SDDL；
- total regular file count、total directory count、total bytes；
- manifest 自身 SHA-256、生成时间、工具/命令；
- unreadable/reparse entries 的完整列表；任何未解释 read/hash error 都应阻塞 R4。

推荐 future manifest：

```text
results/vy_fixed_fusion_v2_5g1b_r4_old_default_prefdir_manifest.csv
```

manifest 必须在 rename 前完成并验证，旧目录不得直接 delete。

## Forensic backup 命名与原子改名规则

backup 必须位于同一父目录、同一文件系统：

```text
PARENT = C:\Users\21180\AppData\Roaming\MathWorks\MATLAB
SOURCE = R2024a
BACKUP = R2024a_V25G1B_BAD_BACKUP_YYYYMMDDTHHMMSSZ
```

规则：

- timestamp 使用执行时 UTC，确保名称稳定、唯一且不含 Windows 非法字符；
- 先确认 backup exact path 不存在；禁止复用或覆盖旧 backup；
- 优先使用同文件系统 atomic rename，不复制、不修改文件内容；
- rename 后核对 backup 的总数、总字节、relative paths 和所有可读文件 SHA-256
  与 pre-rename manifest 完全一致；
- expected default path 必须在 probe 前不存在；若它提前重新出现，立即停止调查；
- 如果原子 rename 不可行，R4 不得直接删除 source。只能先做完整 copy preservation、
  依据同一 manifest 验证 byte-level 完整性，再请求对 source 进行独立、明确授权的
  可逆 relocation；在 source 仍占据 expected default path 时不得启动 regeneration probe。

R3 不执行 rename、copy 或 backup creation。

## R4 controlled regeneration procedure

**THE RECOMMENDED RECOVERY IS FRESH DEFAULT-PREFDIR REGENERATION WITH MATLAB_PREFDIR LEFT UNSET.**

未来 R4 的固定顺序：

1. 完成上述 preflight、process gate、旧目录 manifest 与同盘 atomic rename。
2. 验证 old backup 完整，且 expected default path 不存在。
3. 再次验证 process/user/machine `MATLAB_PREFDIR` 全部 UNSET；禁止 `setx`。
4. 记录启动前 expected default path `exists=NO`。
5. 从非项目 neutral working directory 只启动一次 MATLAB child process。
6. 只执行 startup marker、version、`prefdir`、Simulink license、
   `load_system('simulink')`、`close_system('simulink',0)`。
7. 禁止项目 `cd/addpath`、project target、compile/update、`sim()` 和 CarSim。
8. 进程结束后记录 fresh default path creation time、完整 tree/inventory、关键 settings
   文件、hash、ACL 和永久环境变量状态。

等价的唯一 probe 内容：

```matlab
disp('MATLAB_STARTUP_OK');
disp(version);
fprintf('ACTIVE_PREFDIR=%s\n',prefdir);
fprintf('SIMULINK_LICENSE=%d\n',license('test','Simulink'));
load_system('simulink');
disp('SIMULINK_LOAD_OK');
close_system('simulink',0);
```

`ACTIVE_PREFDIR` 必须 canonical-exact 等于：

```text
C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
```

并且不得等于 R2 clean diagnostic path 或 old backup path。

## R4 PASS / FAIL criteria

PASS 必须全部满足：

- startup 前 expected default path 不存在；startup 后由 MATLAB 新建；
- `MATLAB_STARTUP_OK` present；
- exit code `0`；
- `ACTIVE_PREFDIR` exact fresh expected default path；
- Simulink license `1`；
- `SIMULINK_LOAD_OK` present；
- no fatal startup error；
- no `errors_warnings` failure；
- no ApplicationService fatal error；
- old forensic backup 与 pre-rename manifest 一致；
- persistent `MATLAB_PREFDIR` 仍 UNSET。

R4 PASS 时只能结论：

**FRESH DEFAULT PREFDIR STARTUP HEALTH RESTORED.**

不得由此宣称 CarSim 已恢复。

如果 fresh default 仍出现 `failed to load settings errors_warnings plugin`，或 active path
不正确，则 R4 立即 FAIL/BLOCK：不得再 rename、再创建 default、再 startup、reinstall
或继续 CarSim。应重新审计 clean-vs-default 的 invocation、TEMP、path creation 和 global state 差异。

## 旧 settings 与回滚规则

- fresh default PASS 后禁止把旧 PREFDIR 内容整体复制回来。
- vehicle project recovery 保持 fresh default settings；个人偏好恢复必须作为独立任务逐项处理。
- 若 fresh default regeneration 产生不可接受问题，先正常关闭 MATLAB，再把新 default
  目录作为 evidence 改名为唯一 sibling：
  `R2024a_V25G1B_FRESH_FAILED_YYYYMMDDTHHMMSSZ`。
- 不得覆盖、合并或删除 old forensic backup。
- rollback 前后都验证 manifest/hash，并写明动机和命令。
- 只有另行明确授权时，才可把 old backup 原子改回 `R2024a`；该 rollback 仅恢复旧
  用户状态，不代表修复 startup failure。

R3 不执行任何 rollback。

## 恢复后的阶段顺序

```text
R3 recovery plan
→ R4 controlled default-PREFDIR regeneration + startup-only validation
→ if R4 PASS: resume original V2.5-G1B one 0.20-s known-good CarSim diagnostic
→ if G1B PASS: G1C C01 replacement remediation preregistration
→ FWCAL_C01R1 exact preregistered replacement condition
→ only then resume calibration acquisition
```

不得跳过 G1B。R4 startup-only 不消费原 G1B real-runtime authorization。

未来 `FWCAL_C01R1` 只能在 R4 PASS 且 G1B PASS 后预注册，并保持：

- amplitude `0.02 rad`；
- frequency `0.30 Hz`；
- duration `16 s`；
- same waveform、speed scope、evaluation rule；
- 明确标注 `REPLACES FAILED-INFRASTRUCTURE FWCAL_C01`。

## 当前状态锁定

- `FWCAL_C01 = FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- `FWCAL_C02–C05 = NOT RUN`
- holdout = `UNTOUCHED`
- `alpha_D / alpha_K / alpha_F = UNSELECTED`
- original G1B 0.20-s real-runtime authorization = `UNCONSUMED`
- MATLAB reinstall = `NOT JUSTIFIED`
- CarSim reinstall = `NOT JUSTIFIED`
- surgical settings deletion/random cache rename = `NOT EVIDENCE-BASED`

## R3 完整性

| Artifact | SHA-256 | 状态 |
|---|---|---|
| R2 report | `41E64D6746E547A1CEF5AF4E4F6A51E0917E5E925259E1B92EE077B56FD56CCB` | UNCHANGED |
| `model/vx_vy_fixed_fusion_v2_5.slx` | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | UNCHANGED |
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

默认 PREFDIR 及 R2 clean diagnostic PREFDIR 均保持 untouched。

## 必需声明

THE DEFAULT USER PREFDIR / SETTINGS STATE IS STRONGLY IMPLICATED BY THE CLEAN-PREFDIR CONTROL TEST.

THE EXACT CORRUPT ITEM REMAINS UNIDENTIFIED.

THE OLD DEFAULT PREFDIR WILL BE PRESERVED IN FULL BEFORE ANY RECOVERY ACTION.

THE RECOMMENDED RECOVERY IS FRESH DEFAULT-PREFDIR REGENERATION WITH MATLAB_PREFDIR LEFT UNSET.

THE R2 CLEAN DIAGNOSTIC PREFDIR WILL NOT BE USED AS THE PROJECT PRODUCTION ENVIRONMENT.

NO MATLAB OR CARSIM PROCESS WAS STARTED IN R3.

THE ORIGINAL G1B REAL-RUNTIME AUTHORIZATION REMAINS UNCONSUMED.

READY FOR V2.5-G1B-R4 CONTROLLED DEFAULT-PREFDIR REGENERATION & STARTUP VALIDATION
