# V2.5-I2 H02 First-and-Only Formal Runtime Status

## Conclusion

`V2.5-I2 H02 FORMAL RUNTIME BLOCKED BEFORE AUTHORIZATION COMMIT`

The R0-frozen ASCII launcher was invoked exactly once. MATLAB reached the frozen bootstrap and successfully persisted `BOOTSTRAP_ENTERED` and `PROJECT_CD_OK`, then the dedicated runner failed before it could persist `RUNNER_ENTERED`, parse the preregistry, create `PRE_SIM_GATES_PASS`, or create the durable authorization commit.

No retry, fallback, direct MATLAB launch, direct runner execution, simulation, or H03 execution was performed.

## Formal invocation evidence

| Field | Evidence |
|---|---|
| run_id | `FWHOLD_H02` |
| formal launcher | `D:\V25_H02_BOOTSTRAP\launch_v25_i2_h02_formal.cmd` |
| formal launcher invocation count | `1` |
| launcher exit code | `1` |
| launcher SHA-256 | `92DC61AABC34DAF2A40A891296B65B176EE9E42A3031F2EB4A990685CC5A579B` |
| bootstrap SHA-256 | `9A4F389BD6B214798730891E01996CCD8219AA3236C2D92F5CE54D8F7C2ACB30` |
| runner SHA-256 | `D3218ED275508FD1F95F53C2F480081871331E9C9D9D978FFCAFEA6878F58844` |
| last durable phase | `PROJECT_CD_OK` |
| phase marker file | `results/vy_fixed_fusion_v2_5i2_H02_phase_markers.csv` |
| phase marker SHA-256 | `F4EC95718EA83D5689B8A395AF377F42BAFDE24FBBAF54060AB906684243C521` |
| phase marker size | `166` bytes |
| `SIM_AUTHORIZATION_COMMITTED` | `ABSENT` |
| H02 authorization | `UNCONSUMED` |
| formal H02 MAT | `ABSENT` |
| formal data status | `NO_USABLE_HOLDOUT_DATA` |

Durable phase sequence actually persisted:

1. `BOOTSTRAP_ENTERED`
2. `PROJECT_CD_OK`

`RUNNER_ENTERED` was not persisted.

## Exact pre-commit blocker

The dedicated runner failed at line 14:

```matlab
runnerHash=sha256(mfilename('fullpath'));
```

The local `sha256` helper attempted to open the extensionless value returned by `mfilename('fullpath')`:

```text
D:\UsersData\桌面\two\model\run_vy_fixed_fusion_v2_5i2_H02_holdout
```

MATLAB reported:

```text
Java exception occurred:
java.io.FileNotFoundException: D:\UsersData\桌面\two\model\run_vy_fixed_fusion_v2_5i2_H02_holdout
at run_vy_fixed_fusion_v2_5i2_H02_holdout>sha256 (line 144)
at run_vy_fixed_fusion_v2_5i2_H02_holdout (line 14)
at run_v25_i2_h02_formal (line 10)
```

Classification: `PRE_COMMIT_RUNNER_EVIDENCE_HASH_PATH_DEFECT`. This is an execution-entry/evidence helper defect, not estimator, fusion, model, CarSim, runtime-performance, or weight evidence.

A future separately authorized remediation may minimally make the runner hash the exact existing `.m` path, while preserving the one-shot commit-before-sim protocol. No such fix was performed in V2.5-I2, and the launcher must not be invoked again in this stage.

## Integrity and untouched state

| Frozen artifact | SHA-256 after failed launch | Result |
|---|---|---|
| formal target | `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B` | UNCHANGED |
| fusion core | `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C` | UNCHANGED |
| fusion wrapper | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` | UNCHANGED |
| runner | `D3218ED275508FD1F95F53C2F480081871331E9C9D9D978FFCAFEA6878F58844` | UNCHANGED |
| analyzer | `E0A56418F141FA02A5B6E487753365D00358D498FC9514D719024EC9CAF708C8` | UNCHANGED |
| immutable preregistry | `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6` | UNCHANGED |

- Live MATLAB after launcher exit: `0`.
- Active SET-2 after launcher exit: `ABSENT`; classification `NO_POSTRUNTIME_SET2_ARTIFACT`.
- `sim()` was not reached.
- CarSim was not run.
- No H02 acquisition, integrity, or metrics artifact was created.
- H03 remains `UNRUN / UNVIEWED / UNCONSUMED`; formal H03 MAT is absent.
- `V25_FIXED_WEIGHT_ALPHA_V1` was not modified.
- No original three-holdout or PARTIAL23 aggregate was computed.

## Stop state

The one permitted launcher invocation for this stage has been used. Because the failure occurred before durable authorization commit, H02 runtime authorization remains `UNCONSUMED`; however, the frozen one-launch/no-retry rule prohibits another launcher invocation in V2.5-I2. A separate progression/remediation decision is required.

NO SECOND H02 RUNTIME IS AUTHORIZED IN THIS STAGE.
