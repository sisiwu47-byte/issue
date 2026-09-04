# STAGE VX-V2 — Formal Runtime Validation Status

## Verdict

- `VERDICT = MANUAL_GUI_ACTION_REQUIRED`
- `FORMAL_RUNTIME_COUNT = 0`
- `N1 = NOT_RUN`
- `N2 = NOT_RUN`
- `T1 = NOT_RUN`
- `D1 = NOT_RUN`
- `D2 = NOT_RUN`
- `READY_FOR_VX_FINAL_ACCEPTANCE = NO`

Formal runtime was stopped at the required pre-run static gate. No historical A-H result was reused and no evaluation window, parameter, or algorithm was changed.

## Static result

The estimator, 18/38 interface and required logs are active. Stage-A controller feedback correctly remains CarSim truth. However, the saved model contains only a constant 72 km/h active reference, no traceable T1 steering source, and no traceable D1/D2 low-adhesion RL/RR degradation configurations. Details are in `results/vx_formal_validation/gui_postcheck_v2.md`.

## Required manual GUI actions

1. Open `D:\UsersData\桌面\two\model\vx.slx`; keep estimator SID 313, Demux/output route, Goto SID 274, and logs SID 310–312 active. Do not edit estimator code or frozen parameters.
2. In the active speed-reference block Repeating Sequence Interpolated2 (SID 438), prepare the exact frozen profiles used by the formal cases: N1 `[0,16]/[60,60]`; N2 `[0,3,8,13,16]/[60,60,100,60,60]`; T1 `[0,16]/[72,72]`; D1 `[0,3,8,16]/[40,40,70,70]`; D2 `[0,3,8,16]/[70,70,40,40]` (time in s, speed in km/h). Do not alter the frozen phase boundaries.
3. Provide a saved, uniquely identifiable model/variant/configuration for each case, or an existing named configuration that can be selected headlessly without editing `.slx` during runtime. Record the exact identifier for N1/N2/T1/D1/D2.
4. For T1, connect or select the genuine 4WIS steering source: amplitude `0.02 rad`, frequency `0.4 Hz`, active only on `[3,13] s`. Confirm that actual RL and RR wheel angles are nonzero dynamic outputs and that the steering command plus all four actual wheel angles are logged.
5. For D1 and D2, select/save the actual CarSim road dataset with `mu=0.3`. Configure D1 as RL/RR drive-slip excitation and D2 as RL/RR braking-lock excitation on `[3,8] s`, with the excitation removed at `8 s` so recovery is physically possible. Record the dataset/run names and drive/brake command signal names.
6. Keep MPC/controller `u(33)` on CarSim truth for this independent-estimator formal validation. `vx_hat` remains logged; do not switch to closed-loop estimated-speed feedback in VX-V2.
7. Save the final reviewed model/configurations. Reply `VX_V2_GUI_CASES_READY` with the five configuration identifiers, T1 steering source/log names, D1/D2 CarSim dataset names, and affected-wheel confirmation.

After that reply, the model hash and case identities must be frozen into the parameter snapshot and runtime packager before the first formal run.
