# V2.8-A25 — Minimal D-health and D-aware K-health integration status

## Verdict

`UNIFIED_HEALTH_DESIGN_PASS`

`READY_FOR_D_ONLY_DEGRADATION_VALIDATION = YES`

## D-health candidate

- `z_D=normalized_NIS`; causal window=`0.5 s` / `50 samples`.
- Healthy-only `z0_D=max(P99(N0),P99(N1))=0.09457507740501557`.
- `e_D=max(0,zbar_D-z0_D)`.
- `G_D=1/(1+e_D/z0_D)`; `H_D=availability_D*G_D`; `score_D=q_D*H_D`.
- No D1 error, true Vy, tuned scale, final threshold, or persistence rule enters the online candidate.

## Offline replay result

- N0 `G_D mean/min=1/1`; healthy preservation=`PASS`.
- N1 `G_D mean/P05/min=0.999698/1/0.908617`; fraction below `0.95=0.148%`; healthy preservation=`PASS`.
- D1 `G_D mean/P05/min=0.764330/0.368744/0.341508`; fraction below `0.95=49.05%`; D response=`PASS`.
- D1 candidate alpha_D mean changes from `0.944591` to `0.903942`; when `G_D<0.99`, from `0.926273` to `0.846365`.

## K-health regression and guard

- Frozen `d0/rho/lambda/Ts` are unchanged; only `e_K=G_D*max(0,d_DK-d0)` is introduced in the candidate.
- A17d aligned N0 gives `G_D=1` at every sample. Saved K-state replay max differences are `6.22e-15` (`I_K`) and `8.88e-16` (`G_K`).
- A17d `G_K<=0.5` time remains `7.89 s`; K protection regression=`PASS_EXACT_REGRESSION`.
- D1 whole-trace K-excess attribution reduction=`4.40%`; within `G_D<0.99` samples=`46.77%`; guard=`SUPPORTED`.
- D1 includes K degradation, so this is not D-bad/K-healthy final fusion validation.

## Scope and artifacts

- Offline Python only; new runtime count=`0`; diagnostic figure count=`0`.
- Frozen core SHA-256 remains `E6BE142BF2B2E5FE80A9376764759AB4E8D3454266791DE6C61B5778FFD9EA17`.
- Prototype: `matlab/vy_lifesig_unified_health_v2_8a25_candidate_step.m`.
- Evidence: `results/vy_lifesig_v2_8a25_unified_health_design/`.
- Formal next stage requires Case D (D bad/K healthy); simultaneous D/K and global robustness remain unsupported.
