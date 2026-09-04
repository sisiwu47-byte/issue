# VX V3 Formal Runtime Contract

## Immutable pre-run gates

1. Run only a case produced by `model/configure_vx_formal_case_v3.m`.
2. Verify source model, estimator, parameter, and wrapper hashes against `case_handoff.json` immediately before simulation.
3. Keep controller reference units in `km/h`; do not divide V3 profile values by `3.6`.
4. Do not modify estimator logic or frozen parameters, including `QI=0.002`, `kA=30`, `kH=18`, `QW=0.0001`, `Rw=0.393`, `Ts_est=0.01 s`, and `Ts_sim=0.001 s`.
5. Use the manifest's time windows without post-run movement.
6. Historical A-H and Vy runtime outputs may establish configuration lineage only; they cannot satisfy a V3 runtime.

## Execution order and fallback lock

Primary cases are `VX-ND`, `VX-ST`, and `VX-DR`. Exactly one primary runtime per case is intended. `VX-DS` and `VX-BL` are forbidden unless one completed `VX-DR` runtime fails at least one preregistered physical gate. If both VX-DR physical gates pass, fallback runtime count must remain zero.

## Required raw signals

All signals must be saved without figure-time recomputation of unavailable channels.

| source | required data | interpretation |
|---|---|---|
| `Vx_true_log` | CarSim Vx and time | reference only, never estimator input |
| `est_u_log` | columns `1:4` wheel omega, `5:8` actual wheel angle, `9` Ax, `14` AVz, and time | physical gates and input evidence |
| `est_y_log` | all 38 columns and time | formal current output map; key columns: Fusion `1`, WSS `3`, IMU `5`, rho `16:19`, validWheel `24:27`, alpha `30:31`, update flag `35`, counter `38` |
| case profile | exact speed and steering arrays | command provenance |
| configuration | source and derived model/control hashes; dataset IDs; working directory | evidence lineage |

Only samples with estimator update flag `est_y(:,35)>0.5`, finite truth, and `t` inside the preregistered window are used for estimator metrics.

## Metrics fixed before runtime

For error `e = estimate - Vx_true`, compute WSS, IMU, and Fusion `RMSE=sqrt(mean(e^2))`, `MAE=mean(abs(e))`, `MaxAbs=max(abs(e))`, and `Bias=mean(e)`. Report overall metrics for all primary cases and the frozen phase metrics.

For each `VX-DR` degradation phase also report:

- WSS, IMU, and Fusion RMSE;
- mean `alpha_W` and mean `alpha_I`;
- physical-gate sustained-duration result for RL/RR;
- detection response time: phase start to the first update where both affected wheels are invalid (`validWheel_RL=validWheel_RR=0`) or both have `rho<=0.05`; if absent, `NOT_DETECTED`;
- wheel unlock/recovery time: recovery-window start to the first of 30 consecutive 100 Hz updates where both RL/RR are valid;
- `alpha_W` recovery 90% and 95%: recovery-window start to the first of 30 consecutive updates with `alpha_W >= 0.90` or `0.95` times the baseline mean `alpha_W` from `[0.60,3.00)`.

No missing event may be replaced by the end of the window; report `NOT_REACHED`.

## Physical gates

Use `kappa_i=(0.393*omega_i-Vx_true)/max(abs(Vx_true),1)` on the raw physical signals.

- VX-ST: save and check all four actual wheel angles. A rear-steering claim requires dynamic nonzero RL/RR actual angles with correct timing; otherwise label only `STEERING_DYNAMIC_VALIDATION`.
- VX-DR acceleration: RL and RR each sustain `kappa>=0.10` for at least `0.10 s` in `[3,7)`.
- VX-DR braking: RL and RR each sustain `kappa<=-0.10` for at least `0.10 s` in `[9,13)`.

The two VX-DR kinematic gates alone decide whether fallback is permitted. Estimator performance cannot trigger fallback.

## Evidence commit and outputs

Before calling `sim`, create a case-specific commit record with case ID, UTC/local timestamp, all source/derived hashes, exact profiles, frozen windows, and `SIM_INVOCATION_COMMITTED=YES`. After return, save:

- `runtime/<CASE_ID>_formal_raw.mat` containing scalar `R` with `metadata.formalRuntime=true` and `metadata.caseId`;
- `runtime/<CASE_ID>_metadata.json`;
- one concise console log;
- metrics CSV row(s) and physical-gate result;
- post-run hashes.

Increment `FORMAL_RUNTIME_COUNT` only after an actual formal simulation invocation has been committed. Preparation, static checks, plotting, and historical-file reads do not increment it.

## Thesis outputs after accepted runtimes

- `VX-TABLE-01`: primary cases only, WSS/IMU/Fusion RMSE plus Fusion MAE and MaxAbs; Bias stays in evidence even if omitted from the compact thesis table.
- `VX-TABLE-02`: only VX-DR acceleration/braking degradation and recovery dynamics, or preregistered fallback rows if and only if fallback was activated.
- `VX-FIG-01`: `VX-ND` normal dynamic estimation.
- `VX-FIG-02`: `VX-DR` combined degradation/recovery; do not render it as a successful mechanism demonstration if a required physical gate failed.
