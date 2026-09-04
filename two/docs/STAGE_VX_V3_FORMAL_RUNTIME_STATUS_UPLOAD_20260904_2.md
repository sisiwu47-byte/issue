# Stage VX-V3 Formal Runtime Status

## Verdict

`VX_DR_PHYSICAL_GATE_FAIL`

- `FORMAL_RUNTIME_COUNT = 5` committed `sim` invocations.
- `FORMAL_ACCEPTED_RESULT_COUNT = 3` (`VX-ND`, `VX-ST`, `VX-DR`).
- Two earlier VX-ND execution-layer failures are preserved: one compile failure before CarSim integration and one completed simulation whose single-point steering log could not initially be packaged.
- `READY_FOR_VX_FALLBACK_CONFIGURATION = YES`
- `READY_FOR_VX_FINAL_ACCEPTANCE = NO`
- `VX-DS/VX-BL runtime = NOT_RUN`

## Primary results

| case | status | WSS RMSE | IMU RMSE | Fusion RMSE | Fusion MAE | Fusion MaxAbs |
|---|---|---:|---:|---:|---:|---:|
| `VX-ND` | `FORMAL_RUNTIME_COMPLETE` | 0.177956 | 0.249115 | 0.163815 | 0.130521 | 0.257806 |
| `VX-ST` | `FORMAL_RUNTIME_COMPLETE / STEERING_DYNAMIC_VALIDATION` | 0.006164 | 0.009767 | 0.005952 | 0.005699 | 0.010373 |
| `VX-DR` | `FORMAL_RUNTIME_COMPLETE / PHYSICAL_GATE_FAIL` | 0.177860 | 0.305651 | 0.230301 | 0.199963 | 0.295453 |

Units for errors are `m/s`.

## Physical gates

- VX-ST rear steering: `FAIL`; actual peak absolute angles `[FL,FR,RL,RR] = [0.0249716, 0.00003143, 0.0249712, 0.00003116] rad`. Both rear wheels did not demonstrate genuine dynamic steering, so the claim ceiling is `STEERING_DYNAMIC_VALIDATION`.
- VX-DR acceleration gate: `PASS`; RL/RR sustained positive-slip durations are `1.906/1.906 s`, mean `alpha_W=0.096373`, detection response `0.008 s`, wheel recovery `0.838 s`.
- VX-DR braking gate: `FAIL`; RL/RR sustained braking-degradation durations are `0/0 s`, detection is `NOT_DETECTED`. This physical failure alone activates the preregistered fallback boundary.

## Outputs and stop boundary

- TABLE-01: `results/vx_formal_validation/v3/runtime/VX_TABLE_01_representative_condition_performance.csv`
- TABLE-02: `results/vx_formal_validation/v3/runtime/VX_TABLE_02_degradation_recovery_dynamics.csv`
- FIG-01: code retained; image not generated because the stage stopped at the DR gate.
- FIG-02: code retained; export blocked by the DR physical gate.

No frozen algorithm/parameter, source `.slx`, or CarSim source dataset was modified. The next authorized action is fallback configuration only; this stage does not extend the configurator and does not run fallback cases.
