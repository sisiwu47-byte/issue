# Stage 1 Interface Audit (Read-Only)
- Timestamp: 2026-08-06 16:41:55
- `load_system`: success -> MPC_Demo_wuguzhang

## 1. Model configuration and MATLAB/Simulink API checks
- Solver: ode1
- SolverType: Fixed-step
- FixedStep: 0.001
- StopTime: 16
- StartTime: 0.001
- FixedStepMode: N/A
- SampleTimeConstraint: Unconstrained
- MaxStep: auto
- MinStep: auto
- SimulationMode: normal
- AlgebraicLoopMsg: warning
- SystemTargetFile: grt.tlc
- ReturnWorkspaceOutputs: on
- `set_param(..., update)`: failed ('MPC_Demo_wuguzhang/CarSim S-Function' 中的 S-Function 'vs_sf' 报告错误:
Error: Unable to find the simfile.
)
- `Simulink.BlockDiagram.getInitialState`: failed ('MPC_Demo_wuguzhang/CarSim S-Function' 中的 S-Function 'vs_sf' 报告错误:
Error: Unable to find the simfile.
)

## 2. Target Signal Existence / Source-Target / Dimension / Data type / Sample Time
### Ax
- status: MISSING
### Ay
- status: MISSING
### Az
- status: MISSING
### Ax_SM
- status: MISSING
### Ay_SM
- status: MISSING
### Az_SM
- status: MISSING
### AVx
- status: MISSING
### AVy
- status: MISSING
### AVz
- status: MISSING
### Pitch
- status: MISSING
### Steer_L1
- status: MISSING
### Steer_R1
- status: MISSING
### Steer_L2
- status: MISSING
### Steer_R2
- status: MISSING
### AVy_L1
- status: MISSING
### AVy_R1
- status: MISSING
### AVy_L2
- status: MISSING
### AVy_R2
- status: MISSING
### Vx
- status: FOUND
- block-name candidates: MPC_Demo_wuguzhang/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/质心侧偏角二阶参考模型/限幅模块/Vx
- source blocks: MPC_Demo_wuguzhang/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/质心侧偏角二阶参考模型/限幅模块/Vx
- target blocks: unresolved
- dimensions: []
- data types: N/A
- sample time: []

### Vy
- status: FOUND
- block-name candidates: MPC_Demo_wuguzhang/Gain11/1; MPC_Demo_wuguzhang/Gain11/Vy; MPC_Demo_wuguzhang/Goto11/Vy; MPC_Demo_wuguzhang/MATLAB Function/Vy
- source blocks: MPC_Demo_wuguzhang/Gain11; MPC_Demo_wuguzhang/MATLAB Function/Vy
- target blocks: unresolved
- dimensions: []
- data types: N/A
- sample time: []

### reset
- status: MISSING
## 3. Four-wheel order check for [FL, FR, RL, RR]
### AVy
- status: missing one or more signals
### Steer
- status: missing one or more signals

## 4. Candidate placement for Interpreted MATLAB Function estimator
- no existing `MATLAB Function` blocks.
- no subsystem with estimator-related keyword match found by name.

## 5. 1000 Hz model vs 100 Hz estimator interface
- Model-level fixed-step settings already listed in Section 1.
- Ax: sample time unresolved
- Ay: sample time unresolved
- Az: sample time unresolved
- AVx: sample time unresolved
- AVy: sample time unresolved
- AVz: sample time unresolved
- Ax_SM: sample time unresolved
- Ay_SM: sample time unresolved
- Az_SM: sample time unresolved
- Steer_L1: sample time unresolved
- Steer_R1: sample time unresolved
- Steer_L2: sample time unresolved
- Steer_R2: sample time unresolved
- AVy_L1: sample time unresolved
- AVy_R1: sample time unresolved
- AVy_L2: sample time unresolved
- AVy_R2: sample time unresolved
- explicit RateTransition/Downsample/ZeroOrderHold blocks: none discovered by block type scan.

## 6. Vx 真值流向
- source: MPC_Demo_wuguzhang/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/MATLAB Function/Vx; MPC_Demo_wuguzhang/参考模型模块3/质心侧偏角二阶参考模型/限幅模块/Vx
- target: unresolved

## 7. Missing signals only
- missing: Ax, Ay, Az, Ax_SM, Ay_SM, Az_SM, AVx, AVy, AVz, Pitch, Steer_L1, Steer_R1, Steer_L2, Steer_R2, AVy_L1, AVy_R1, AVy_L2, AVy_R2, reset
