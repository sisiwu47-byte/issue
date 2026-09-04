# V2.5-H2 Fixed-Weight Implementation Freeze

## Stage conclusion

**V2.5-H2 FIXED-WEIGHT IMPLEMENTATION FREEZE PASSED**

The H1-accepted candidate was written into the formal fixed-fusion SLX dialog parameters using the only authorized numerical boundary projection. No new optimization, calibration fitting, holdout access, Simulink simulation, or CarSim runtime was performed.

## Weight lineage

Weight set ID: `V25_FIXED_WEIGHT_ALPHA_V1`

Raw H1 QP solution (preserved exactly):

- `alpha_D_raw = 0.9004680917645591`
- `alpha_K_raw = 0.09953190823500144`
- `alpha_F_raw = 4.39495370645866e-13`

Runtime representation (computed in MATLAB double precision):

- `alpha_D_runtime = 0.9004680917645591`
- `alpha_K_runtime = 1.0 - alpha_D_runtime = 0.09953190823544089`
- `alpha_F_runtime = 0`
- runtime sum = `1` exactly in the validation execution
- projection delta = `[0, 4.394540287222526e-13, -4.39495370645866e-13]`
- projection max abs = `4.39495370645866e-13 <= 1e-12`

This is `NUMERICAL_BOUNDARY_PROJECTION`, not re-optimization, retuning, holdout adjustment, or manual weight change. The raw candidate remains separately recorded in the H/H1 artifacts.

## Implementation change

Only the formal SLX fusion S-function dialog parameters were changed:

`vx_vy_fixed_fusion_v2_5/Fixed Weight D K F Fusion`

from the TEST-ONLY integration values `[1/3, 1/3, 1/3]` to:

`[0.9004680917645591, 1-0.9004680917645591, 0]`

The fusion equation and interface remain unchanged:

`Vy_FW = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F`

with input order D/K/F, 3 scalar inputs, and 1 scalar output. The F-track remains present, executed, and logged; its coefficient is exactly zero in this global fixed-weight baseline. F remains standalone with feedback disabled.

Formal target hash after implementation:

`model/vx_vy_fixed_fusion_v2_5.slx` — `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`

Before implementation it was `801FC3650B80416B13346200D296F654A25E36BD01AABBFD3CCC983D086258EE`; the only intentional change was the fusion dialog weight parameter.

Core and wrapper remain unchanged:

- fusion core: `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- fusion wrapper: `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`

## Validation evidence

- deterministic known-case core checks: max error `0`
- 100 random finite core checks: max error `0`
- F-zero invariance: output variation `0`
- estimator-only compile: passed
- compile termination: passed
- existing harness file: unchanged (no save)
- no covariance, reliability, LifeSig, observability, adaptive, switching, selector, truth, or fusion-feedback logic added

The complete machine-readable gate set is in `results/vy_fixed_fusion_v2_5h2_implementation_gates.csv`.

## Offline calibration replay and scope

The H1 raw candidate and runtime boundary representation are linked in `results/vy_fixed_fusion_v2_5h2_runtime_weight_manifest.csv`. Existing calibration MATs and the calibration acquisition manifest were not modified. This stage does not re-evaluate calibration quality and does not change the frozen candidate based on replay metrics.

Scope metadata remains:

- `scope_speed_class = VERIFIED_APPROX_20_MPS_CLASS`
- `scope_weight_type = GLOBAL_CONSTANT_FIXED_WEIGHT`
- `F_track_mode = STANDALONE`

## Holdout lock

H01-H03 remain `PLANNED_NOT_RUN`; their result MATs are absent and `data_viewed=FALSE`. No holdout data were read, run, or used. The formal implementation is now immutable for holdout validation.

THE H1 RAW QP SOLUTION WAS NOT RE-OPTIMIZED OR RETUNED.

THE RUNTIME REPRESENTATION ONLY PROJECTS THE ACCEPTED NUMERICAL ACTIVE-BOUNDARY SOLUTION ONTO THE EXACT SIMPLEX EDGE.

THE PROJECTION IS AT MACHINE-PRECISION SCALE.

ALPHA_F IS EXACTLY ZERO IN THE FIXED-WEIGHT RUNTIME BASELINE.

THE F-TRACK REMAINS PRESENT, EXECUTED, AND LOGGED; IT IS NOT REMOVED FROM THE ARCHITECTURE.

THE F-TRACK REMAINS STANDALONE WITH FEEDBACK DISABLED.

NO COVARIANCE, RELIABILITY, LIFESIG, OBSERVABILITY, OR ADAPTIVE WEIGHTING WAS ADDED.

NO HOLDOUT DATA WERE RUN, READ, OR USED.

THE FORMAL FIXED-WEIGHT IMPLEMENTATION IS NOW IMMUTABLE FOR HOLDOUT VALIDATION.

READY FOR V2.5-I HOLDOUT VALIDATION PRE-EXECUTION FREEZE
