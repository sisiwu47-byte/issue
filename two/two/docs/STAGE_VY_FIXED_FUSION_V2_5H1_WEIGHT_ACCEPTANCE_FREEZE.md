# V2.5-H1 Fixed-Weight Candidate Acceptance & Freeze

## Stage conclusion

**V2.5-H1 FIXED-WEIGHT CANDIDATE ACCEPTED AND FROZEN**

This stage performed evidence acceptance and scope freeze only. No new optimization, MATLAB/Simulink runtime, CarSim run, holdout access, or model modification was performed.

## Immutable candidate source

- calibration manifest: `results/vy_fixed_fusion_v2_5g2_calibration_acquisition_manifest.csv`
- manifest SHA-256: `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`
- exact calibration rows: `FWCAL_C01R1`, `FWCAL_C02`, `FWCAL_C03`, `FWCAL_C04`, `FWCAL_C05`
- H result MAT SHA-256: `C2CE140D53EE8CE2069488505E7480D5A689E0454F2B016169A2EC74498073FC`
- QP CSV SHA-256: `7DCF4E14D57DC616B45BBB195D516204948AA55B71D4962686711649138D0385`
- identifiability CSV SHA-256: `6867E38395052E4336D6C2801C66CA0455820672F85925993D73CD1794943099`
- LOO CSV SHA-256: `396183BB02DC7B95E5F4A71A2862B81C005B97515FB76973742516AE596EFC72`
- bootstrap CSV SHA-256: `6D031DD4D56501118AF19393F2732C7CEE6880E273AE329F2D4884D1D164460D`
- per-maneuver metrics SHA-256: `1F530898FE0CA21C3DFB2D967775A7C472FB16CE6FD23A5075668018B1EF2FAF`

All source files were read-only verified against the H evidence. No calibration MAT or manifest was changed.

## Raw QP solution and boundary interpretation

The raw QP values are preserved exactly:

- `alpha_D_raw = 0.9004680917645591`
- `alpha_K_raw = 0.09953190823500144`
- `alpha_F_raw = 4.39495370645866e-13`
- raw sum = `1`

The accepted boundary interpretation is explicit and separate:

- `alpha_D = 0.9004680917645591`
- `alpha_K = 0.09953190823500144`
- `alpha_F_boundary = 0`
- boundary sum = `0.9999999999995606`
- boundary sum residual = `-4.39426273146637e-13`

This is roundoff-level residual only. The raw QP solution was not silently renormalized or replaced.

The active lower-bound solution is accepted as a valid simplex boundary solution. No positive floor, ridge, entropy term, equal-weight prior, or manual adjustment was introduced.

## Acceptance evidence

- solver: `quadprog`, `interior-point-convex`
- exit flag: `1`
- iterations: `8`
- objective: `0.006783869483537023`
- equality residual: `0`
- KKT: PASS
- reduced rank: `2`
- `cond(X) = 12.79439434408395`
- reduced Hessian condition number: `130.3505558104789`
- maximum LOO component shift: `0.05198340184377356`
- whole-maneuver bootstrap: 1000 replicates, seed `20260829`
- bootstrap stability gate: PASS
- classification: `IDENTIFIABLE_AND_STABLE`

The detailed evidence remains in the immutable H result artifacts. This stage did not recompute the objective or rerun `quadprog`.

## Frozen representation

The machine-readable frozen representation is:

`results/vy_fixed_fusion_v2_5h1_weight_freeze_manifest.csv`

Manifest SHA-256 is recorded after creation. It freezes both the raw-QP values and the explicit boundary interpretation, with provenance back to the H QP/identifiability evidence. It does not alter the fixed-fusion MATLAB function, wrapper, workspace parameters, or Simulink model.

## Scope locks

- fixed-fusion implementation: unchanged
- all calibration runtime MATs: unchanged
- calibration acquisition manifest: unchanged
- holdout H01-H03: `PLANNED_NOT_RUN`, result MAT absent, `data_viewed=FALSE`
- no holdout data were read, run, or used
- no new simulation or CarSim run was performed
- no Q/R tuning, covariance weighting, adaptive weighting, fusion feedback, LifeSig, or `Vy_final` was introduced

V2.5-H1 FIXED-WEIGHT CANDIDATE ACCEPTANCE PASSED.

THE RAW QP SOLUTION AND BOUNDARY INTERPRETATION ARE BOTH PRESERVED.

THE FROZEN WEIGHT REPRESENTATION IS READY FOR THE NEXT HOLDOUT PRE-REGISTRATION/EXECUTION STAGE.
