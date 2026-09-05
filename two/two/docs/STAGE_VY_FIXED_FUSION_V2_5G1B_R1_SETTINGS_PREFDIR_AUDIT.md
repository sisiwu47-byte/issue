# V2.5-G1B-R1 MATLAB Settings / PREFDIR Remediation Audit

## 阶段结论

**V2.5-G1B-R1 MATLAB SETTINGS / PREFDIR AUDIT INCONCLUSIVE — CLEAN-PREFDIR ISOLATION REQUIRED**

归因分类：

**F. NO STATIC DEFECT IDENTIFIED — CLEAN-PREFDIR ISOLATION DIAGNOSTIC REQUIRED**

本轮静态审计没有发现足以把
`failed to load settings errors_warnings plugin` 明确归因到用户 PREFDIR
损坏、用户权限、残留锁、安装侧插件缺失或其他确定文件系统原因的证据。
默认 PREFDIR 仍是最值得隔离的共同变量，但现有证据不支持直接宣称其已损坏。

## 执行边界

- 本轮未调用 `D:\matlab\bin\matlab.exe`，未启动新的 MATLAB 进程。
- 未加载 Simulink，未调用 `sim()`，未加载或运行 CarSim。
- 未创建、删除、重命名或写入任何 PREFDIR/settings/cache 文件。
- 未修改 MATLAB 安装目录、模型、算法、runner、结果 MAT 或冻结 artifact。
- 审计期间始终可见一个本轮开始前已存在的 MATLAB 进程：PID `29492`，
  启动时间 `2026-08-27 12:23:44.9031024 +08:00`，`Responding=True`，无窗口标题。
  本轮未终止、控制或复用该进程。

## 基础环境

| 变量 | 实际值 | 判定 |
|---|---|---|
| `MATLAB_PREFDIR` | 未设置 | 使用 MATLAB 默认用户 preference policy |
| `USERPROFILE` | `C:\Users\21180` | 存在 |
| `APPDATA` | `C:\Users\21180\AppData\Roaming` | 存在 |
| `LOCALAPPDATA` | `C:\Users\21180\AppData\Local` | 存在 |
| `TEMP` | `D:\SystemMigration\Temp` | 存在 |
| `TMP` | `D:\SystemMigration\Temp` | 存在 |
| `HOMEDRIVE` | `C:` | 存在 |
| `HOMEPATH` | `\Users\21180` | 与 `HOMEDRIVE` 合并后解析为现有用户目录 |
| `USERNAME` | `21180` | 正常 |
| MATLAB PATH 1 | `D:\matlab\runtime\win64` | 存在 |
| MATLAB PATH 2 | `D:\matlab\bin` | 存在 |

磁盘可用空间：`C:` 为 `38,449,397,760` bytes；`D:`（同时承载 TEMP）为
`153,705,357,312` bytes。没有磁盘空间不足证据。

## 默认 preference/settings 目录识别

发现的 MATLAB release 用户目录只有 R2024a：

| 路径 | 创建时间 | 目录 mtime | 文件数 | 子目录数 | 总字节数 |
|---|---:|---:|---:|---:|---:|
| `C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a` | 2026-08-23 22:01:06 | 2026-08-27 13:28:00 | 11,810 | 805 | 160,541,772 |
| `C:\Users\21180\AppData\Local\MathWorks\MATLAB\R2024a` | 2026-08-23 22:01:07 | 2026-08-25 08:22:03 | 2 | 0 | 9,819,142 |

`LIKELY_ACTIVE_PREFDIR = C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a`

置信度：高。依据是 `MATLAB_PREFDIR` 未设置、仅发现 R2024a release 目录，且该目录
包含与最近 MATLAB 使用时间一致的 preference/settings 更新。

Local release 目录仅包含：

- `graphicsState.bin`：2 bytes，SHA-256
  `96A296D224F285C67BEE93C30F8A309157F0DAA35DC5B87E410B78630A09CFC7`
- `toolbox_cache-24.1.0-1685216323-win64.xml`：9,819,140 bytes，SHA-256
  `ED75F7010C5577D9CFE64E170364C2951CB1E98B34C63757A0B6D3362306600B`

## 关键 settings 文件清单

| 文件 | bytes | mtime (+08:00) | SHA-256 |
|---|---:|---|---|
| `cefInit.mlsettings` | 3,120 | 2026-08-27 13:27:47 | `B1046A13CF485B27C54E4326CC9621A1B7ECA1D5F43ED56265CA20ECCF45D55C` |
| `matlab.mlsettings` | 11,599 | 2026-08-27 13:27:34 | `0E519CCBE4CABB14BBD4A605E322B3191F5F1F8ECD9ACB461116472F79FE04A7` |
| `matlabprefs.mat` | 249 | 2026-08-23 22:02:14 | `D2041F3A09197D31570F7675BAED98BB9A21FF58A7EC8AFBBD1DAFEA99DD22E3` |
| `migratePref.txt` | 1 | 2026-08-23 22:01:13 | `F67AB10AD4E4C53121B6A5FE4DA9C10DDEE905B978D3788D2723D7BFACBE28A9` |
| `parallel.mlsettings` | 3,567 | 2026-08-23 22:01:30 | `F5FB61D6D6340F523EAF762AE577ACD0CF159505D17959DE95645B539F30E3CB` |
| `Simulink.mlsettings` | 5,455 | 2026-08-27 13:27:33 | `AB2BB0D6444491B50803F3D91A2DA5CFDF14007904BFBB0D877F77F449C6D938` |
| `slhistory.mlsettings` | 3,270 | 2026-08-27 13:28:00 | `C887D8FED560E7B4C3194FACF2DC66BE85763DE1E2CCC6C7FCEDAD47D943FE87` |
| `VisibleSettings.json` | 24 | 2026-08-23 22:02:11 | `BCA56B465A072D13F0677230E1950F73BA3798A129D7A110FE73AA6912B6F847` |
| `sdiprefs.json` | 8,559 | 2026-08-28 12:29:58 | `EB485EE54583EA75D584A39D891AD5C04F3FBB26BAD6ACCF63DD74C98DAC577A` |
| `signalanalyzerprefs.json` | 1,125 | 2026-08-28 12:29:58 | `2EBFC3EE9BF28C19EC831717165349005FA7243221AC600E400A7F525AEB2774` |
| `stmprefs.json` | 8,560 | 2026-08-28 12:29:58 | `61B981FF08C45EB36C98F4EDA5D5921C909F081BFCDFAFCC545FC975B4483AC4` |
| `epfwk_cache-24.1.0.2537033-7203099541395556032.json` | 445,922 | 2026-08-28 13:53:04 | `50FC4DDD1691C3E00FE0B52291465AB50F77B96E0F66BC7433566746A2F9CEBB` |

`epfwk_cache` 是最后一次完整成功结果更新时间之后唯一更新的关键 PREFDIR 文件，
但只读 JSON 解析通过，根对象包含 `entries`、`packageUris`、`version` 三个字段。
其 mtime 本身不是损坏证据。更重要的是，后续 C01 进程仍成功越过 MATLAB startup
并进入 CarSim，因此该次 cache 更新不足以单独解释后来的 settings startup failure。

## 异常、锁与权限检查

- active PREFDIR 中唯一零字节文件为 `MLintDefaultSettings.txt`；其创建/mtime 均为
  `2026-08-23 22:01:07`，早于多次已知成功 MATLAB 执行，不能作为本次故障证据。
- 未发现真正的 `*.lock`、`*.lck`、`*.tmp`、`*.journal` 或同类残留状态文件。
  搜索命中的两个 `lock.svg` 是 ServiceHost UI 图标，不是锁文件。
- future timestamp 数量：0。
- reparse point/junction 数量：0。
- 未发现路径指向不存在位置、permission-denied 或读取失败证据。
- active PREFDIR、APPDATA、LOCALAPPDATA、TEMP 均无 Deny ACE，目录无 ReadOnly 属性。
- 用户 `Lenovo\21180` 对 APPDATA/LOCALAPPDATA 具有 `FullControl`；active PREFDIR
  同样授予该用户 `FullControl`。沙箱组具有 Modify 权限。所有者为
  `BUILTIN\Administrators`，但没有伴随访问拒绝或不可达证据。

因此未识别 B 类用户 profile/permission defect，也未识别 C 类 stale lock/temp defect。

## MATLAB 安装侧 settings/plugin 审计

精确文件名搜索未找到单独命名为 `errors_warnings` 的安装文件；只读二进制检索确认
逻辑字符串 `errors_warnings` 存在于 `settingscore.dll`。直接相关组件和 manifest
均存在、非零、可读：

| 文件 | bytes | SHA-256 |
|---|---:|---|
| `D:\matlab\bin\win64\settingscore.dll` | 5,158,400 | `C17C1814A8220E5C7342722FCE757EAD6CC99B78278F077CE5CB7FBFB78B4765` |
| `D:\matlab\bin\win64\app_service_host\jsd\services_host\mwApplicationService.dll` | 561,000 | `081BA4FCBA835A91401837B8A01E41CEAC4B4C7413FB8580FAABA90C76EF04FD` |
| `D:\matlab\bin\win64\cppms_cache_manifests\mwApplicationService.bpf` | 133 | `F0D95CEE38ABDFD991ECC2E58540AC96722ECD9F67B366CE8D6C0C7860B6A5F9` |
| `D:\matlab\bin\win64\factory_settings\desktop_startup_settings\mwDesktopStartupSettings.dll` | 161,128 | `31F1B78D30CB239E7486DFE90A0E06761245A01CC36BAF94AE6BF4719CEA7B9E` |
| `D:\matlab\bin\win64\factory_settings\jsd\startup_settings\mwJsdStartupSettings.dll` | 164,712 | `FE79159A12715616C59C33FC4B978834EBC52EB7A49548801B9690659C7D8B75` |
| `D:\matlab\bin\win64\matlab_startup_plugins\prefdirwarning\libmw_prefdirwarning.dll` | 107,880 | `4728658AD510D45DF4F5263269E0A23E7EF82E48878A6F083012F7D14B47387E` |
| `D:\matlab\bin\win64\builtins\parallel\cluster\builtins\mwwarningscollector_builtinimpl.dll` | 92,520 | `D286E6191CE60947368DC0D945C637E78EECB860F52FF910ED903B2F82213639` |
| `D:\matlab\bin\win64\factory_settings\alm\project_services\mwsettings_factory.dll` | 169,832 | `BC700ED9FBA3A3C513DD59C06273A90EE3B69F1231872982A4CDA6AA41F92132` |

相关 BPF manifest 均能解析出实际存在的目标 DLL。除 `settingscore.dll` 没有独立
Authenticode 签名外，检查的 ApplicationService、desktop/JSD startup settings 和
prefdirwarning DLL 均返回有效 MathWorks 签名。缺少独立签名本身不构成损坏证据，
本轮也没有厂商基线 hash 可据此证明 `settingscore.dll` 已变更。

因此未发现 D 类安装侧组件缺失、零字节或不可读证据，也不建议在当前证据下重装或修复 MATLAB。

## 日志与时间线

Windows Application Error 日志在 `2026-08-28 14:35–16:10 +08:00` 范围内
没有匹配事件。现有 MathWorks ServiceHost 日志包含 ApplicationService 注册/注销和
历史 transport/settings 活动，但没有识别到与 G1B/R0 对应的精确
`failed to load settings errors_warnings plugin` 记录。

| 时间 (+08:00) | 事件 | 证据与解释 |
|---|---|---|
| 2026-08-28 12:29:57 | V2.5-D 0.20-s runtime 结果首次生成 | 完整成功的 MATLAB/Simulink/CarSim 参考 |
| 2026-08-28 13:52:12 | V2.5-D result MAT 最后更新 | SHA-256 `63F233D9B0B444EDCA7C332F522AF9A588EB3A9C6F0E5FD9718CA5BEA09184F8` |
| 2026-08-28 13:53:04 | `epfwk_cache` 更新 | JSON 解析通过；mtime 不是损坏证明 |
| 2026-08-28 14:42:59 | FWCAL_C01 在 `carsim_64.dll` 发生 0xC0000005 | MATLAB 已越过 startup；这是 CarSim runtime failure，不是 settings startup failure |
| 2026-08-28 15:03:57 前 | G1B 首次 settings startup failure | 状态文档创建时间提供上界；未到 runner/Simulink/CarSim |
| 2026-08-28 15:52:33 前 | R0 第二次 settings startup failure | 状态文档创建时间提供上界；同样未到 MATLAB command engine |

C01 crash artifact：
`D:\SystemMigration\Temp\matlab_crash_dump.4772-1`，SHA-256
`4945CC9A7370F58FDAEFC9D27C4038A97819693971B90C7BA0522E51F8FC0CAF`。
它只证明 C01 的 CarSim DLL access violation。没有证据证明 C01 导致 PREFDIR/settings 损坏，
也没有识别到 C01 之后写入关键 PREFDIR 文件的静态时间戳。

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

## 项目状态锁定

- `FWCAL_C01 = FAILED_INFRASTRUCTURE / NO_USABLE_CALIBRATION_DATA`
- `FWCAL_C02–C05 = NOT RUN`
- holdout = `UNTOUCHED`
- `alpha_D / alpha_K / alpha_F = UNSELECTED`
- G1B real-runtime authorization = `UNCONSUMED`

## 下一最小阶段

仅允许：

**V2.5-G1B-R2 ISOLATED CLEAN-PREFDIR STARTUP DIAGNOSTIC**

R2 应保留默认 PREFDIR untouched，创建全新的隔离 diagnostic PREFDIR，仅执行一次
startup-only probe，从而区分 default user settings state 与 installation-side startup。
不得再次直接使用默认 PREFDIR 重复同一 startup probe。

## 必需声明

DEFAULT PREFDIR HAS NOT BEEN MODIFIED.

NO MATLAB PROCESS WAS STARTED.

NO CARSIM CONCLUSION WAS DRAWN.

THE G1B REAL-RUNTIME AUTHORIZATION REMAINS UNCONSUMED.
