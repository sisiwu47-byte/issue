# V2.5-G1C C01 Replacement Remediation Preregistration

## Stage decision

**V2.5-G1C C01 REPLACEMENT REMEDIATION PREREGISTRATION ACCEPTED**

本阶段仅创建独立 append-only remediation layer，为原基础设施失败 run
`FWCAL_C01` 预注册 exact-condition replacement `FWCAL_C01R1`。没有启动 MATLAB、
调用 `sim()`、运行 CarSim、生成 calibration MAT、查看性能或计算权重。

## 1. Original C01 historical status

原 V2.5-F preregistration row 保持 byte-for-byte unchanged；其中初始状态仍是
`PLANNED_NOT_RUN`，因为原 registry 被定义为不可变 preregistration artifact。独立且同样
不可变的 V2.5-G failure evidence 永久记录实际后验状态：

| Field | Permanent value |
|---|---|
| run_id | `FWCAL_C01` |
| role | `CALIBRATION_ONLY` |
| historical runtime status | `FAILED_INFRASTRUCTURE` |
| usable_calibration_data | `NO` |
| sim_authorization | `CONSUMED` |
| replacement_run_id | `FWCAL_C01R1` |
| failure stage | `CARSIM_INITIALIZATION` |
| failure code | `0xC0000005` |
| failure classification | `TRANSIENT / EXTERNAL CARSIM RUNTIME-ENVIRONMENT FAILURE — NOT FURTHER RESOLVED` |

原 C01 的一个且仅一个 `sim()` 已调用；CarSim/S-function 初始化阶段崩溃，没有产生
runtime log、result MAT、Vy_D/K/F/truth performance data 或任何 alpha fitting input。
原 failure evidence、状态文档和 runner evidence 均未修改、删除、改名或覆盖。

## 2. Why replacement is methodologically allowed

V2.5-G1B known-good `0.20 s` runtime diagnostic 在 R4 fresh default PREFDIR 下已 PASS，
证明当前 known-good CarSim runtime path 恢复健康。它没有改变原 C01 的失败历史，也没有
产生 calibration performance evidence。

因此允许 same-condition replacement 的理由仅是：原 C01 在基础设施初始化阶段失败并且
没有可用性能数据。replacement 不是根据 RMSE、track ranking、估计器表现或 maneuver
结果选择，不构成 performance cherry-picking 或 maneuver retuning。

## 3. Append-only remediation lineage

独立 registry：

`results/vy_fixed_fusion_v2_5g1c_remediation_registry.csv`

SHA-256：

`C112249565DB5DCBAFE0A04D27FA7593E6F427DB26072CD3803D7E9E70D4E7A7`

首次创建内容严格为一条 replacement row：

| Field | Value |
|---|---|
| run_id | `FWCAL_C01R1` |
| role | `CALIBRATION_ONLY` |
| status | `PLANNED_NOT_RUN` |
| replaces_run_id | `FWCAL_C01` |
| replacement_generation | `1` |
| replacement_reason | `FAILED_INFRASTRUCTURE_NO_USABLE_DATA` |
| original_run_status | `FAILED_INFRASTRUCTURE` |
| original_sim_authorization_status | `CONSUMED` |
| original_usable_data | `NO` |
| original_performance_data_available | `NO` |
| performance_based_condition_change | `NO` |
| condition_changed_from_original | `NO` |
| future_sim_authorization_status | `NOT_YET_AUTHORIZED` |
| created_stage | `V2.5-G1C` |

该 registry 是 append-only remediation layer。未来 acquisition/status 必须使用新的后验
artifact，不能覆盖该 preregistration row。`FWCAL_C01R1` ID 不得复用于其他条件。

## 4. Exact original/replacement maneuver comparison

| Parameter | Original FWCAL_C01 | Replacement FWCAL_C01R1 | Result |
|---|---|---|---|
| role | `CALIBRATION_ONLY` | `CALIBRATION_ONLY` | exact |
| steering amplitude | `0.02 rad` | `0.02 rad` | exact |
| steering frequency | `0.30 Hz` | `0.30 Hz` | exact |
| duration | `16 s` | `16 s` | exact |
| estimator rate | `100 Hz` | `100 Hz` | exact |
| waveform | sine | sine | exact |
| front steering | FL/FR same phase | `FL_FR_SAME_PHASE` | exact |
| rear steering | RL/RR zero | `RL_RR_ZERO` | exact |
| speed scope | current verified approximately 20 m/s class | `VERIFIED_APPROX_20_MPS_CLASS` | inherited exact scope |
| model | `model/vx_vy_fixed_fusion_v2_5.slx` | same | exact |
| model SHA-256 | `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE` | same | exact |

没有改变 amplitude、frequency、duration、waveform、wheel routing、speed scope 或
evaluation policy。

## 5. Truth alignment and evaluation inheritance

FWCAL_C01R1 直接继承原 V2.5-F registry tokens：

```text
truth_alignment_rule = TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT
evaluation_window_rule = [0_16]
```

`[0_16]` 表示完整 `[0,16] s`，包含 initialization transient。没有引入新的 trimming、
time shift、cross-correlation alignment、extrapolation 或 per-track alignment。

## 6. Reserved result path

未来结果路径冻结为：

```text
results/vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat
```

G1C 检查结果：

```text
reserved path unique = YES
reserved path exists = NO
result_sha256 = NOT_GENERATED
```

没有创建空 MAT 占位，也没有删除、覆盖或重命名任何既有结果。

## 7. Future runtime environment policy

FWCAL_C01R1 未来 acquisition 必须继承：

```text
MATLAB_PREFDIR = UNSET / inherited default
active PREFDIR = C:\Users\21180\AppData\Roaming\MathWorks\MATLAB\R2024a
cwd = D:\UsersData\桌面\two\model
active simfile = D:\UsersData\桌面\two\model\simfile.sim
PROGDIR = D:\carsim\CarSim2021.0_Prog\
DATADIR = D:\carsim\CarSim2021.0_Data\
solver = D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll
G request = NO
```

不得使用 R2 isolation PREFDIR、forensic backup PREFDIR 或任何 `MATLAB_PREFDIR`
override。本阶段只登记 policy，没有启动 MATLAB 验证。

## 8. Future one-runtime authorization discipline

G1C 不授予 runtime：

```text
FWCAL_C01R1.future_sim_authorization_status = NOT_YET_AUTHORIZED
```

只有未来 V2.5-G1D 可以单独授予 one-and-only-one `sim()`。如果 future runner 在
`sim()` 前发生外围错误，只有 `sim()` 尚未调用时才能修外围代码；一旦 `sim()` 调用，
授权立即消费，无论 PASS 或 crash 均不得重跑 C01R1。再次 infrastructure failure 时不得
自动创建 C01R2、跳到 C02-C05 或修改 maneuver。

## 9. Original registry and suite integrity

| Artifact | SHA-256 | Status |
|---|---|---|
| V2.5-F plan document | `97E3D7C9C3F35853372702A8CC545FEB02D9C182CEC012D47BA177D19673F230` | UNCHANGED |
| V2.5-F suite plan CSV | `AA3784A3CFCDAF8D048D743109477A773267140B693D71FF141E2E1BD58C489E` | UNCHANGED |
| V2.5-F run registry CSV | `92B052D8450F432510C31035CDBE5A38BFE8CD7614691E3BE305D4D45CB9CFBE` | UNCHANGED |
| C01 failure status | `371A6961A63742B75A34A1DD6F9715D610BA3C5DA422B86F1AD125D0ED9062F9` | UNCHANGED |
| G1 forensic status | `D50F5F438AAA213EAF197A105AF3C5A76132C72E09B133A0F487972E09ABA91A` | UNCHANGED |
| G1B diagnostic MAT | `030CE3FDE238641D046D9DC9DABF07AFE75BB00F38CB12E0181F6755C4A7CC12` | UNCHANGED |
| G1B diagnostic status | `4C3EA774732CDB163B32BC39A7AE93D1BE38F922C69E7BD8DBC557EBB2CAA6C7` | UNCHANGED |

原 V2.5-F plan/registry 没有 append、row edit、status edit 或 replacement row。

## 10. C02-C05 holdout and alpha locks

- `FWCAL_C02–C05`：四条 `CALIBRATION_ONLY / PLANNED_NOT_RUN` row 均未改变；runtime count `0`。
- `FWHOLD_H01–H03`：三条 `HOLDOUT_VALIDATION / PLANNED_NOT_RUN` row 均未改变。
- holdout runtime count：`0`。
- holdout result MAT count：`0`。
- holdout performance viewed：`NO`。
- `alpha_D / alpha_K / alpha_F = UNSELECTED`。
- V2.5-H alpha/weight result count：`0`。

results 中已有带 `alpha` 文件名的四张 D-EKF 图是轮胎侧偏角历史证据，不是
fixed-fusion `alpha_D/K/F` 权重结果。

## 11. Machine-readable gates

Gate evidence：

`results/vy_fixed_fusion_v2_5g1c_preregistration_gates.csv`

SHA-256：

`40676D452D47483644EA87FFE61ADFDBC942ECBD052D631875F368307DA18CAB`

结果：

```text
gateCount = 36
gatesTrue = 36/36
reserved result exists = NO
live MATLAB process count = 0
```

全部 lineage、condition、inheritance、immutability、holdout、alpha、zero-execution 和
frozen-integrity gates PASS。

## 12. Frozen integrity

后置 SHA-256 mismatch count：`0`。

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
| model simfile | `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA` | UNCHANGED |

## Required declarations

FWCAL_C01 REMAINS PERMANENTLY RECORDED AS FAILED-INFRASTRUCTURE / NO-USABLE-DATA.

FWCAL_C01R1 IS PRE-REGISTERED AS AN EXACT-CONDITION REPLACEMENT.

FWCAL_C01R1 REPLACES FWCAL_C01 ONLY BECAUSE THE ORIGINAL RUN PRODUCED NO USABLE PERFORMANCE DATA.

NO MANEUVER PARAMETER WAS CHANGED BASED ON PERFORMANCE.

THE REPLACEMENT ROLE IS CALIBRATION_ONLY.

THE REPLACEMENT STATUS IS PLANNED_NOT_RUN.

THE REPLACEMENT REAL-RUNTIME AUTHORIZATION HAS NOT YET BEEN GRANTED.

THE ORIGINAL V2.5-F REGISTRIES REMAIN IMMUTABLE.

C02-C05 REMAIN UNRUN.

HOLDOUT REMAINS UNTOUCHED.

ALPHA_D / ALPHA_K / ALPHA_F REMAIN UNSELECTED.

NO MATLAB / SIMULATION / CARSIM / OPTIMIZATION WAS PERFORMED IN G1C.

READY FOR V2.5-G1D FWCAL_C01R1 REPLACEMENT CALIBRATION ACQUISITION
