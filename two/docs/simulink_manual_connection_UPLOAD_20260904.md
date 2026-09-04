# VX-V1 Simulink Manual Action

`MANUAL_GUI_ACTION_REQUIRED`

Static inspection shows that the current Vx estimator MATLAB Function block and the `vx_hat` route are commented in `model/vx.slx`. The T1 rear-steer path also cannot be confirmed without viewing the model. Per project rules, no `.slx` file was changed and no GUI was automated.

## Required manual steps

1. In MATLAB, manually open `D:\UsersData\桌面\two\model\vx.slx`.
2. Locate the MATLAB Function/Interpreted MATLAB Function block whose expression is `longitudinal_velocity_estimator_simulink(u)` (static SID 313). Remove the comment/disable state, without editing its function or changing the estimator logic.
3. Confirm its input Mux is exactly 18 elements in the current contract: wheel speeds 1:4, actual wheel steering angles 5:8, Ax/Ay/Az 9:11, AVx/AVy/AVz 12:14, reserved signals 15:17, reset 18. Do not connect CarSim true Vx to any estimator input.
4. Locate the existing Goto block tagged `vx_hat` (static SID 274, `Goto7`) and remove its comment/disable state. Confirm the active estimator output is output 1 of the 38-vector Demux.
5. Trace every active `From` block currently using tags `Vx` or `vx_carsim`. Record whether the downstream controller input `u(33)` and the downstream Vy/side-slip estimator Vx input still receive CarSim truth or receive `vx_hat`. Do not change controller dimensions.
6. If the frozen architecture requires estimated Vx downstream, manually route the existing `vx_hat` tag to those already-defined Vx consumer ports; do not create GPS inputs and do not alter controller or estimator algorithms. Save the model only after checking that no unrelated block changed.
7. For T1, trace estimator inputs 5:8 to the four actual wheel-angle signals `[FL, FR, RL, RR]`. Confirm that RL/RR are genuine commanded/measured rear-steer signals during `[3,13] s`, not constant-zero placeholders. If this cannot be established, keep T1 blocked.
8. Enable logging for the 18-vector estimator input, the 38-vector estimator output, CarSim reference Vx, Ax, steering input, four actual wheel angles, and the D1/D2 drive/brake commands. Use the names required by `validation_case_manifest.md` when packaging the result.
9. Save the reviewed model under the approved current formal-runtime model identity. Because any save changes the `.slx` hash, update `parameter_snapshot.md` and the formal packaging hash only after a deliberate review; do not reuse the old hash silently.
10. Reply `VX_GUI_CONFIRMATION_COMPLETE` together with: saved model path, whether estimator/output route is active, downstream routing (`controller u(33)` and Vy input), and whether T1 rear steer is genuine.

Do not run N1/N2/T1/D1/D2 until steps 1–9 are complete. Historical A-H files do not satisfy this GUI gate.
