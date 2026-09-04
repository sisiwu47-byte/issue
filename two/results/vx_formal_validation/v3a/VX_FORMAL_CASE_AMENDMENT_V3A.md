# VX Formal Case Amendment V3A — Thesis Scope Narrowing to Drive-Slip

## Purpose

This amendment is created **after** the completed V3 primary runtimes and therefore does not rewrite or overwrite `VX_FORMAL_CASE_MANIFEST_V3.md`. The original V3 preregistration and its failed `VX-DR` braking physical gate remain permanent evidence.

Current frozen facts from `docs/STAGE_VX_V3_FORMAL_RUNTIME_STATUS.md`:

- `VX-ND`: accepted current-version formal runtime.
- `VX-ST`: accepted as `STEERING_DYNAMIC_VALIDATION`; rear-steering gate failed.
- `VX-DR`: accepted raw runtime but overall physical gate failed.
- `VX-DR` acceleration gate: PASS; RL/RR positive-slip sustained `1.906/1.906 s`, mean `alpha_W=0.096373`, detection `0.008 s`, wheel recovery `0.838 s`.
- `VX-DR` braking gate: FAIL; RL/RR sustained `0/0 s`, `NOT_DETECTED`.

## Scientific interpretation of the failed combined case

The failed braking gate demonstrates that the reusable A20b-MU03 control plus a `70 -> 40 km/h` reference is **not by itself a reproducible rear-wheel brake-lock configuration**. Historical G only provides a behavior template; its MAT file does not preserve a traceable braking excitation/configuration lineage. Therefore V3A does not assume that a new `VX-BL` run would create brake lock.

Conversely, the current V3 `VX-DR` runtime directly demonstrates that the same A20b-MU03 control can reproducibly create rear-wheel positive drive slip under acceleration. This gives `VX-DS` a current-version physical basis that `VX-BL` does not currently have.

## Thesis-scope decision

For the minimum defensible thesis validation set, the low-adhesion mechanism case is narrowed to a dedicated drive-slip/recovery case:

- keep `VX-ND` as normal longitudinal-dynamic evidence;
- keep `VX-ST` with claim ceiling `STEERING_DYNAMIC_VALIDATION`;
- replace `VX-DR` as the **thesis representative low-mu mechanism case** with new `VX-DS`;
- retain the completed `VX-DR` as diagnostic/negative evidence and do not erase or relabel it;
- do **not** run `VX-BL` in V3A;
- brake-lock robustness remains outside the current formal claim unless a future separately preregistered, traceable braking excitation is established.

This scope change is based on physical reproducibility and evidence lineage, not on estimator RMSE or figure appearance.

## New V3A formal case: VX-DS

Scientific question: during a reproducible low-adhesion drive-slip event, does wheel health decrease, WSS contribution fall, fusion remain usable, and wheel/fusion weight recover after acceleration ceases?

Frozen command:

- reference unit: `km/h`;
- `[0,3) s`: `40 km/h` baseline;
- `[3,8) s`: smooth `40 -> 70 km/h` acceleration;
- `[8,16] s`: `70 km/h` recovery plateau;
- steering: `0`;
- CarSim control source: existing A20b-MU03 copied control;
- required control token: `MU_ROAD_CONSTANT=0.30`;
- no source `.slx`, estimator, frozen parameter or CarSim source-dataset modification.

Frozen windows:

- overall: `[0.60,16.00]`;
- baseline: `[0.60,3.00)`;
- drive-slip/degradation: `[3.00,8.00)`;
- recovery: `[8.00,16.00]`.

Physical gate, using raw actual wheel speed and CarSim truth only:

`kappa_i = (0.393*omega_i - Vx_true)/max(abs(Vx_true),1)`.

`VX-DS PHYSICAL_GATE_PASS` requires **both RL and RR** to sustain `kappa >= +0.10` for at least `0.10 s` inside `[3,8)`.

Estimator outputs (`rho`, `validWheel`, `alpha_W/I`) are responses to report, not substitutes for this gate.

## Run authorization

Exactly one new `VX-DS` formal `sim` invocation is authorized after static/configuration checks pass. Do not rerun `VX-ND`, `VX-ST`, or `VX-DR`. Do not run `VX-BL`.

If `VX-DS` physical gate fails, preserve the result and stop. Do not change the gate, windows, estimator, frozen parameters, speed profile, or mu token to obtain a pass.

## Thesis outputs after VX-DS

If `VX-DS` passes its physical gate:

- final representative performance table rows: `VX-ND`, `VX-ST`, `VX-DS`;
- final degradation/recovery table: one `VX-DS` row/section with drive-slip and recovery metrics;
- `VX-FIG-01`: retain `VX-ND` source;
- `VX-FIG-02`: use `VX-DS` as the only mechanism source, with three panels: Vx truth/WSS/IMU/Fusion; `rho_RL/rho_RR`; `alpha_W/alpha_I`;
- do not describe current-version formal evidence as validating braking lock.

The original V3 `VX-DR` result remains archived as `COMBINED_CASE_PHYSICAL_GATE_FAIL / ACCEL_PASS / BRAKE_FAIL` and is not a thesis representative performance row after V3A acceptance.
