# V2.5-I1 H01 Formal Holdout Status

## Final status

**V2.5-I1 H01 FORMAL HOLDOUT RUNTIME BLOCKED AFTER AUTHORIZATION CONSUMPTION**

The R4-frozen ASCII bootstrap was invoked exactly once for `FWHOLD_H01`. Two MATLAB processes (PIDs 19516 and 20708) were observed from approximately 00:12:02 to 00:12:47. The processes then exited, but the dedicated runner did not persist its formal report MAT. Two MATLAB diagnostic `.dmr` files were created during the session:

- `D:\SystemMigration\Temp\fdc4-9d28-81be-cd20.dmr` — 1,937,408 bytes, SHA-256 `A6EEA195F5AB6E6F5044C14B2FF7E6DAD7753E75A2856BD9F8CD0DB368EAEB1E`
- `D:\SystemMigration\Temp\5665-dcd1-9edf-ffc1.dmr` — 2,297,856 bytes, SHA-256 `C5D771CFC27DA455D9DD278B8C9C1B96F55AA29D895374C030EF2C5810F8C77F`

Because the runner writes its report only after a normal return path, the durable evidence cannot prove the exact `sim()` boundary (pre-sim failure versus MATLAB/CarSim runtime hard termination). The only formal launcher authorization is therefore treated as consumed for no-retry safety; `simCallCount` is recorded as `NOT_PERSISTED`, not fabricated as a numeric value. No second launcher or H01 `sim()` is permitted.

## Runtime and analysis state

- H01 formal MAT: **NOT EXIST**
- simulation completed: **UNKNOWN**
- CarSim run: **UNKNOWN**
- analyzer: **NOT RUN** (no immutable MAT available)
- H01 authorization: **CONSUMED_FOR_NO_RETRY**
- H02/H03: **UNRUN / UNVIEWED / UNCONSUMED**
- live MATLAB process count after exit: `0`
- SET-2 after exit: absent; no post-runtime artifact was generated in the project tree

No holdout performance metrics were calculated, no alpha/QP/retuning was performed, and no model/core/wrapper/preregistry was modified.

## Frozen hashes

- formal target: `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- runner: `B8BD1148E78B06C0075A2536812E252DEDDF91AF36132F7AB6BE9F7370D4B66E`
- analyzer: `2A25B62815574B3F1DC53BCC52239A6711181AF6435B98B2907DDCB9B570E29E`
- preregistry: `ED7E83BD4D291FCDB6CFBECCED77C49C4E3A1315D25D02FF5AA4B4CDCC2330F6`
- fusion core: `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- fusion wrapper: `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`

The exact prelaunch and post-launch evidence is in `results/vy_fixed_fusion_v2_5i1_H01_acquisition_record.csv` and `results/vy_fixed_fusion_v2_5i1_H01_integrity_gates.csv`. This stage stops here; H02/H03 cannot start.
