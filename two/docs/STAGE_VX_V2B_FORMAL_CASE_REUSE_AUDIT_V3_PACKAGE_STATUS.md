# VX-V2B Formal Case Reuse Audit & V3 Package Status

## Verdict

`VX_V2B_FORMAL_CASE_REUSE_AUDIT_V3_PACKAGE_PASS`

- `FORMAL_RUNTIME_COUNT = 0`
- `READY_FOR_VX_V3_CONFIGURATION = YES`
- `SIMULINK_CASES_SCRIPTABLE = YES`
- `MANUAL_GUI_ACTION_COUNT = 0`
- estimator/core parameter change: `NO`
- formal runtime performed: `NO`

## Closed findings

- Current model, estimator, parameter, wrapper, 38-output interface, and CarSim package identities are hash-pinned in `case_handoff.json`.
- `VX-ND`, `VX-ST`, and `VX-DR` profiles, windows, signals, metrics, physical gates, and fallback rule are preregistered.
- A20-C1/A24-N1 provide a reusable steering-profile/control lineage; the independent V3 profile is `vx_st_profile_a20_c1.json`.
- A20b-MU03 provides a reusable low-mu control file with local `MU_ROAD_CONSTANT=0.30`.
- F/G are retained only as `HISTORICAL_BEHAVIOR_TEMPLATE`; no reusable formal CarSim configuration was found in or beside those MAT files.
- `configure_vx_formal_case_v3.m` creates case-specific model/control copies under results and does not save changes to `model/vx.slx`.
- V3 plotting scripts retain the frozen Vy thesis style and remain blocked until genuine formal MAT evidence exists.

## Remaining runtime-only facts

- genuine rear steering in `VX-ST`;
- acceleration and braking physical gates in `VX-DR`;
- estimator performance and recovery metrics;
- independently measured effective tire-road coefficient beyond the saved CarSim dataset/token combination.

These are not GUI blockers and are not claimed as validated.
