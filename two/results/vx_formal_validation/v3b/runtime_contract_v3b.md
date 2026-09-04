# VX V3B Runtime Contract — Combined Slip

## Immutable boundaries

1. Preserve all V3 raw/results/status files. Do not overwrite or relabel the failed V3 `VX-DR`.
2. V3A is superseded before any V3A formal runtime; do not run `VX-DS` from V3A.
3. Do not modify `model/*.slx`, estimator code, frozen estimator parameters, or CarSim source datasets.
4. V3B calibration may modify only generated validation copies and physical excitation.
5. Calibration and formal evidence are separate. Calibration sims are counted in `PHYSICAL_CALIBRATION_SIM_COUNT`; only the later frozen `VX-CS` sim increments `FORMAL_RUNTIME_COUNT`.

## Calibration selection rule

Candidate selection may use only actual CarSim Vx, wheel omega, applied command/profile, and numerical completion. Do not compute or inspect estimator RMSE, rho, validWheel, alpha, or plots until the physical excitation is frozen.

For every calibration candidate compute

`kappa_i=(0.393*omega_i-Vx_true)/max(abs(Vx_true),1)`.

Drive gate: both RL/RR sustain `kappa>=+0.10` for >=0.10 s in `[3,7)`.

Brake gate: both RL/RR sustain `kappa<=-0.10` for >=0.10 s after 9 s and before the candidate brake-ramp end + 0.5 s.

### Tier 1 — reference-only

Keep `[0,3,7,9] -> [40,40,70,70] km/h` unchanged. Try brake ramp durations, in order:

- 2.5 s: append `(11.5,40),(16,40)`;
- 2.0 s: append `(11.0,40),(16,40)`;
- 1.5 s: append `(10.5,40),(16,40)`.

Stop at the first candidate where both drive and brake gates pass. Do not run later candidates.

### Tier 2 — rear signed-torque excitation

Tier 2 is authorized only after all Tier 1 candidates fail and only if the generated validation model exposes an unambiguous signed RL/RR wheel-torque command path without source-model edits.

Before Tier 2, read historical physical evidence only:

- `tests/results_case_F.mat`;
- `tests/results_case_G.mat`;
- `tests/tiaocan/validate_online_kH60_FG.m`;
- `tests/save_case_E_result.m`.

Historical G lock/degradation reference interval: `[4.709,9.175] s`. Save a compact audit of actual four torque channels and wheel kappa; do not treat the old result as formal evidence.

Tier 2 negative rear command magnitudes, in order: 800, 1200, 1600 Nm per rear wheel, derived from existing controller `Qmax=1600 Nm`. During the brake excitation, apply the negative command only in a generated validation copy and preserve `abs(Twheel_cmd)<=1600 Nm`. Stop at first physical-gate pass.

If the signed rear command route is ambiguous, do not guess. Report `MANUAL_GUI_ACTION_REQUIRED` with the exact unresolved route.

## Freeze gate

The first physically passing candidate must be written to `results/vx_formal_validation/v3b/frozen_physical_excitation.json` before estimator-performance analysis or any formal V3B runtime.

Required freeze fields:

- selected tier and candidate;
- exact speed profile;
- exact brake analysis end;
- exact RL/RR override details if Tier 2;
- low-mu control identity/hash/token;
- source/generated model hashes;
- calibration sim count;
- drive/brake sustained durations;
- `PHYSICAL_EXCITATION_FROZEN=YES`.

Once written, do not change the excitation after seeing formal estimator metrics.

## Formal VX-CS runtime

Exactly one new formal simulation is allowed after freeze. The runner must refuse to execute if the freeze file is absent, malformed, or its source/generated hashes no longer match.

Required raw signals remain V3-compatible:

- `R.time`;
- `R.vxTrue`;
- `R.estU` N-by-18;
- `R.estY` N-by-38;
- `R.Ax=R.estU(:,9)`;
- `R.steerCommand`;
- `R.configuration`;
- metadata including `stage='VX-V3B'`, `caseId='VX-CS'`, freeze-file hash, formalRuntime=true.

Formal physical gates are recomputed from the fresh raw runtime. If either gate fails in the fresh formal repeat, preserve it and stop; do not return to calibration.

## Formal estimator metrics

Use V3 definitions without retuning:

- overall WSS/IMU/Fusion RMSE, MAE, MaxAbs, Bias;
- DRIVE_SLIP phase WSS/IMU/Fusion RMSE, mean alpha_W/I, detection, wheel recovery, alpha_W 90/95 recovery;
- BRAKE_SLIP phase same metrics;
- missing events remain `NOT_DETECTED` / `NOT_REACHED`.

Final representative table rows after VX-CS pass: `VX-ND`, `VX-ST`, `VX-CS`.

Final mechanism table has exactly two rows from the same V3B runtime: `DRIVE_SLIP`, `BRAKE_SLIP`.

FIG-01 remains the accepted V3 VX-ND source. FIG-02 uses only V3B VX-CS and may export only if both fresh formal physical gates pass.
