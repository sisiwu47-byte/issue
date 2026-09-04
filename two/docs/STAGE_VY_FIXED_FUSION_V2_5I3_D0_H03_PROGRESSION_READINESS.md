# V2.5-I3-D0 H03 Progression & CarSim Runtime Readiness Decision

## Decision

**MANUAL_CARSIM_SOLVER_LICENSE_CONFIRMATION_REQUIRED**

本阶段严格只读。未启动 MATLAB、H03 launcher 或仿真，未读取 H03 performance/data，未修改模型、权重、Q/R 或 registry。

## H02 closure

W3 closure 已确认：

- H02 = `CLOSED AFTER AUTHORIZATION COMMIT`
- runtime classification = `POST_COMMIT_PERSISTENT_STALL_TERMINATED`
- H02 authorization = `CONSUMED`（永久）
- last durable phase = `SIM_AUTHORIZATION_COMMITTED`
- `SIM_RETURNED` = `ABSENT`
- formal H02 MAT = `ABSENT`
- formal data = `NO_USABLE_HOLDOUT_DATA`
- no second H02 runtime authorized

## H03 untouched

results 目录未发现 H03/FWHOLD_H03 的 runtime MAT、phase、commit 或 formal artifact；因此 H03 保持：

`UNRUN / UNVIEWED / UNCONSUMED`

未发现 H03 formal MAT。

## Local runtime readiness evidence

- live MATLAB：`0`
- `MATLAB_PREFDIR`：`UNSET`
- CarSim Browser 类进程：观察到 5 个 `FCBrowser` 进程；其可执行路径无法通过当前只读接口可靠读取
- 可识别的 CarSim License Manager/solver entitlement 状态：`UNCONFIRMED`
- `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll` 存在，SHA-256 `A53EE59C5754933AFC0E361C93DA1B5B70AA755A7F21C122979D7588FF04CF9D`
- `D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+\vs_sf.mexw64` 存在，SHA-256 `6C00C5572DFA4DA512603C6BA24B36151479B36AD127E566937B95E19208C74C`
- `model/simfile.sim` 存在，SHA-256 `A50912CE50F59B216A4CF939228E63A0F27B9818C52A2ABE493345C53FA7A2EA`；其 `PROGDIR` 与 `DATADIR` 均指向 D: CarSim lineage
- active SET-2：`ABSENT`

DLL/MEX 和 D: simfile lineage 只能证明文件与路径存在，不能证明当前 CarSim Solver license 可用。当前识别到的 Windows `LicenseManager` 服务不是 CarSim Solver entitlement 的充分证据。由于本地没有可读、明确的 CarSim Solver license 状态，不能输出 READY。

## Scientific role freeze

未来 H03 即使成功，也只能作为：

`SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`

不得替代 H01/H02、计算 PARTIAL23、计算原 three-holdout aggregate、给出原 generalization classification，或用于调权。

## Required next action

请用户在 CarSim Browser/License Manager 中人工确认 Solver license 可用后，再单独进行 H03 execution-entry preparation。本阶段不运行 H03。
