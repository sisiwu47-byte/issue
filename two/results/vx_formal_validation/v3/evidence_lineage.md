# VX V3 Evidence Lineage

## Current implementation freeze

| artifact | SHA-256 | role |
|---|---|---|
| `model/vx.slx` | `7D01E24D44903C836B4738FBAC480ED039B2188C3C96C4B3218274446F50D516` | current GUI-post-state model source |
| `model/longitudinal_velocity_estimator.m` | `68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107` | current estimator core |
| `model/estimator_default_params.m` | `09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4` | current parameter source |
| `model/longitudinal_velocity_estimator_simulink.m` | `93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061` | current wrapper |
| `model/vx.cpar` | `4FCE6AF958495B7307F3F48B40DE8A6863DAFE4E00C903D7B829C0E74E175CD2` | current CarSim package |
| `model/Agent_chassis.cpar` | `E994B01106E5127BCBF77C5399FE573CE28F3A063F67996DC8788F75BE81BEAA` | companion CarSim package |

Every future V3 result must store the hashes observed immediately before and after its runtime. A mismatch blocks `FORMAL_CURRENT_VERSION_VALIDATION` classification.

## Reused configuration lineage

- A20-C1 source code SHA-256: `40D7794F3E24CEC4A12952A7F6C2BE1A33D3C9EA901C596D9AC5BAEC6FB46B7D`.
- A24-N1 confirmation code SHA-256: `C4934B145DFA9E85D74CDE9B897BF893EB3AD4DD9A24DC14DC19C767EE4165AC`.
- A20-C1 nominal control SHA-256: `1E3F016EEB9D79AA06A013A359C74B32AC94550F07145DA93ED1C698F9AA4BBB`.
- A20b-MU03 control SHA-256: `8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8`.
- shared headless `simfile.sim` SHA-256: `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`.

Reuse classification is `REUSABLE_CONFIGURATION_SOURCE`. The Vy estimator outputs and metrics from these runs are not Vx validation results.

## Historical behavior templates

| artifact | SHA-256 | allowed use |
|---|---|---|
| `tests/results_case_F.mat` | `ACA61FA4C7C4D703887D57DBFC59B7234A23EAD6D9ADF4B95DED359B999445B1` | qualitative drive-slip/recovery template and fallback shape only |
| `tests/results_case_G.mat` | `CDC65C8AD7D29F0A92371BC65E170EF21E128D05F5B364CA6B0735C3973D2660` | qualitative brake-lock/recovery template and fallback shape only |

These are `HISTORICAL_BEHAVIOR_TEMPLATE`, not reusable formal configurations and not current formal evidence.

## Formal lineage state

- `FORMAL_RUNTIME_COUNT = 0`
- `FORMAL_CURRENT_VERSION_VALIDATION = NONE`
- old VX-V1 `validation_case_manifest.md` remains unchanged as a historical plan;
- old VX-V1 snapshots contain earlier model hashes and are superseded for V3 model identity by this handoff; their parameter/interface discussion remains historical context only;
- V3 becomes the preregistered entry point before any formal runtime;
- future runtimes must create new raw results under `results/vx_formal_validation/v3/runtime/` and must never overwrite A–H or Vy evidence.
