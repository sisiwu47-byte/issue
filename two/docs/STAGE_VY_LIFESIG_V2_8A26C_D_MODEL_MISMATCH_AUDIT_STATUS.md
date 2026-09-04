# V2.8-A26c D-EKF Physical Model-Mismatch Parameter Audit Status

`D_MODEL_MISMATCH_PARAMETER_AUDIT_PASS`

- Offline only; new physics runtime count `0`.
- A26b saved-config D replay maxDiff: `1.6210854880682746e-10` (`PASS`).
- Audited candidates: `k_f`, `k_r`, and `Iz`; three preregistered severities each.
- Top candidate: D-EKF front-axle lateral-force gain `k_f`.
- Selected A/B/C: `0.78181 / 0.0390905 / 0.78181` (`-95%` B mismatch).
- Selected D/K B RMSE: `0.383518/0.294638 m/s`; ratio `1.301656`.
- normalized-NIS B mean: `2.89311` versus nominal `0.0376011` (`76.9423x`).
- Numerical validity: `PASS`; update-valid `100%`, finite covariance/state, K data unchanged.
- Selection: first/minimum preregistered severity satisfying `D/K >= 1.2`; Proposed fusion RMSE was not used.
- `k_f` multiplies front `tireForceLocal` lateral-force output in D prediction and Ay prediction; it is not CarSim mu.
- `READY_FOR_FINAL_D_MODEL_MISMATCH_RUNTIME = YES`.

