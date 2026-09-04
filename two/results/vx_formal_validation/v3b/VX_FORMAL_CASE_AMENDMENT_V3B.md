# VX Formal Case Amendment V3B — Combined Drive/Brake Slip

## Why V3B exists

V3 remains permanent evidence and is not rewritten. Its combined low-mu case `VX-DR` proved rear drive slip during acceleration but did not produce rear brake slip during the braking phase. That failure means the original physical excitation was insufficient; it does not show that a combined drive/brake-slip validation is scientifically inappropriate.

V3A narrowed the thesis mechanism claim to drive slip only. V3B supersedes V3A before any V3A formal runtime is executed. The new goal is stronger and cleaner: obtain one reproducible low-adhesion acceleration/deceleration case that contains both a rear drive-slip event and a rear brake-slip event, then freeze that physical excitation and run exactly one new formal estimator validation.

## Separation of calibration and formal validation

V3B has two distinct stages.

1. `PHYSICAL_EXCITATION_CALIBRATION`: non-formal simulations may change only plant excitation in a generated validation copy. They may inspect only raw physical signals needed to establish the two kinematic gates. Estimator RMSE, rho, alpha, or figure quality must not be used to choose the excitation.
2. `FORMAL_VX_CS_RUNTIME`: after the first passing physical excitation is frozen to a machine-readable file and hashed, exactly one new formal runtime is allowed. Estimator metrics are evaluated only after that freeze.

Calibration simulations must be counted separately and must never increment `FORMAL_RUNTIME_COUNT`.

## Frozen invariant part

- source model: `model/vx.slx`, unchanged;
- estimator/core/frozen parameters: unchanged;
- steering: zero;
- road/control source: A20b-MU03 lineage already used by V3;
- required token: `MU_ROAD_CONSTANT=0.30`;
- reference unit: km/h; do not divide profile values by 3.6 before SID 438;
- drive phase remains identical to the V3 phase that already passed.

## V3B candidate case ID

New formal case ID: `VX-CS` (`combined slip`).

Base profile:

- `[0,3)`: 40 km/h baseline;
- `[3,7)`: 40 -> 70 km/h acceleration;
- `[7,9)`: 70 km/h plateau/recovery;
- from `9 s`: 70 -> 40 km/h braking demand;
- after braking ramp: 40 km/h to 16 s;
- steering = 0.

The only calibration variable in Tier 1 is braking-ramp duration. Candidate order is fixed before calibration:

1. `2.5 s` (`9.0 -> 11.5 s`),
2. `2.0 s` (`9.0 -> 11.0 s`),
3. `1.5 s` (`9.0 -> 10.5 s`).

Use the first candidate that passes both rear brake-slip gates. Do not continue to a stronger candidate after a pass.

Rationale: the original V3 `70 -> 40 km/h` over 4 s requests about 2.08 m/s^2 average deceleration, while the saved low-mu control token is 0.30. The shorter candidates intentionally raise braking demand above the original case without modifying estimator logic or source CarSim data.

## Physical gates used during calibration and formal validation

Use actual raw wheel speed and CarSim truth only:

`kappa_i = (0.393*omega_i - Vx_true) / max(abs(Vx_true),1)`.

Drive-slip gate:

- both RL and RR sustain `kappa >= +0.10` for at least `0.10 s` inside `[3,7)`.

Brake-slip gate:

- both RL and RR sustain `kappa <= -0.10` for at least `0.10 s` after `9 s` and before the selected brake-ramp end plus `0.5 s`.

A candidate is physically acceptable only if both gates pass and the simulation remains numerically valid through 16 s.

## Tier 2 only if all reference-only candidates fail

Do not invent a braking command immediately. First audit the historical F/G evidence and the generated-model torque route.

Allowed evidence:

- `tests/results_case_F.mat`;
- `tests/results_case_G.mat`;
- `tests/tiaocan/validate_online_kH60_FG.m`;
- `tests/save_case_E_result.m`;
- generated validation-copy signal connectivity only.

Historical G's known degraded/locked interval is `[4.709,9.175] s`. Report the actual saved four torque channels and rear-wheel kappa in that interval. Historical F/G remain behavior evidence; their results are not formal V3B evidence.

If and only if a signed rear-wheel torque command route is statically traceable without editing the source model, Tier 2 may create an override in the generated validation copy. The deterministic magnitude sequence is based on the controller's existing `Qmax=1600 Nm` bound:

- 800 Nm magnitude per rear wheel,
- 1200 Nm,
- 1600 Nm.

Use negative signed torque during the braking excitation and preserve an absolute wheel-command clamp of 1600 Nm. Use the first candidate passing the physical gates. Do not inspect estimator metrics during this selection.

If no unambiguous rear signed-torque route exists, stop with `MANUAL_GUI_ACTION_REQUIRED`; do not guess or modify `model/*.slx`.

## Freeze before formal runtime

After the first calibration candidate passes, write:

`results/vx_formal_validation/v3b/frozen_physical_excitation.json`

It must contain:

- selected tier;
- exact speed time/value arrays;
- if used, exact rear brake override timing/magnitude and located block/port identities;
- physical calibration count;
- drive/brake gate durations from calibration;
- source and generated hashes;
- control source hashes/token;
- `PHYSICAL_EXCITATION_FROZEN=YES`.

The formal configurator must refuse to run without this file.

## New formal runtime

Exactly one fresh `VX-CS` formal sim invocation is authorized after freeze. It must reproduce the frozen physical excitation without further adjustment.

Formal fixed analysis phases come from the frozen excitation file:

- baseline `[0.60,3.00)`;
- drive-slip `[3.00,7.00)`;
- inter-phase recovery `[7.00,9.00)`;
- brake-slip from `9.00 s` to the frozen brake analysis end;
- final recovery from the frozen brake analysis end to `16.00 s`.

Estimator response metrics use the existing V3 definitions. Missing estimator events remain `NOT_DETECTED`/`NOT_REACHED`.

## Thesis use if VX-CS passes

- representative performance table: `VX-ND`, `VX-ST`, `VX-CS`;
- degradation/recovery table: two mechanism rows from the same `VX-CS` runtime: DRIVE_SLIP and BRAKE_SLIP;
- FIG-01 remains V3 `VX-ND`;
- FIG-02 source becomes V3B `VX-CS`, with speed estimates, rho_RL/RR, and alpha_W/I, with phase boundaries shown;
- preserve V3 `VX-DR` as archived failed physical-excitation evidence, not a thesis representative row;
- V3A is superseded and must not be executed.
