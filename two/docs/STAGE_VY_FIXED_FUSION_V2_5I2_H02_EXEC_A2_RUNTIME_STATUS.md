# V2.5-I2 H02 EXEC_A2 Formal Runtime Status

## Conclusion

**V2.5-I2 H02 EXEC_A2 FORMAL RUNTIME BLOCKED BEFORE AUTHORIZATION COMMIT**

- Statistical run ID: `FWHOLD_H02`
- Execution attempt ID: `FWHOLD_H02_EXEC_A2`
- Role: `PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`
- Frozen condition: `0.035 rad / 0.35 Hz / 16 s / 100 Hz`
- A2 launcher invocation count: `1`
- Launcher exit code: `1`
- Last durable phase: `PREREGISTRY_PARSED`
- `SIM_AUTHORIZATION_COMMITTED`: `ABSENT`
- H02 authorization: `UNCONSUMED`
- Formal H02 MAT: `ABSENT`
- Formal data status: `NO_USABLE_HOLDOUT_DATA`
- Analyzer invocation: `0`
- H03: `UNRUN / UNVIEWED / UNCONSUMED`

## Exact blocker

The active runner stopped at line 83 before `PRE_SIM_GATES_PASS`:

```text
V25I2:Static
Frozen target parameters mismatch.
```

The failing aggregate condition is:

```matlab
report.static.pass && isequal(report.static.weights, alpha)
```

`static_preflight` defines `report.static.pass` from the parsed fusion parameter count, parsed F-track parameter count, and exact `Gain22 == 180/pi` check. The failed attempt did not persist the individual subcondition values. Therefore the durable evidence identifies the exact aggregate static gate but cannot distinguish which subcondition failed. No parser probe, model change, fallback launch, or retry was performed.

The runner's final line emitted the wrapper message `Unique runtime failed after durable authorization commit`, but that wording is not the authorization state. The authoritative filesystem evidence is unambiguous: no commit file exists, no `SIM_AUTHORIZATION_COMMITTED` phase exists, and execution never reached the unique `sim()` call.

## Durable evidence

The A2 phase file is `results/vy_fixed_fusion_v2_5i2_H02_exec_a2_phase_markers.csv`, SHA-256 `198B630905D6610C6C2C5C92DE59030FD68F7E499F2054099F3F501BFF43698F`, size 376 bytes. Its complete durable lineage is:

1. `BOOTSTRAP_ENTERED`
2. `PROJECT_CD_OK`
3. `RUNNER_ENTERED`
4. `PREREGISTRY_PARSED`

No `PRE_SIM_GATES_PASS`, commit, `SIM_AUTHORIZATION_COMMITTED`, `SIM_RETURNED`, `FORMAL_MAT_SAVED`, or analyzer phase exists.

Launcher evidence:

| Artifact | Size | SHA-256 |
|---|---:|---|
| `FWHOLD_H02_EXEC_A2_stdout.txt` | 0 | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `FWHOLD_H02_EXEC_A2_stderr.txt` | 306 | `61ABC6C62B648597CBD58B82CB7C5BE6247109BDDD7FB324EE0B0949A32C373C` |
| `FWHOLD_H02_EXEC_A2_exitcode.txt` | 3 | `F1B2F662800122BED0FF255693DF89C4487FBDCF453D3524A42D4EC20C3D9C04` |
| `FWHOLD_H02_EXEC_A2_launcher_status.txt` | 37 | `68ADE3E7FC825B9073169B85D157B4DEBDB1FBF723D186DBB63FB304295FA350` |

## Integrity and isolation

- Historical A1 phase SHA-256 remains `F4EC95718EA83D5689B8A395AF377F42BAFDE24FBBAF54060AB906684243C521`.
- Formal target remains `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`.
- Fusion core remains `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`.
- Fusion wrapper remains `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`.
- Runner and analyzer remain at their frozen P2 hashes.
- Live MATLAB count after exit: `0`.
- Live CarSim solver count after exit: `0`.
- Active SET-2: `ABSENT`; hygiene result is `NO_POSTRUNTIME_SET2_ARTIFACT`.
- No H03 formal MAT, commit, phase marker, or runtime evidence was created.

## Stop state

The A2 launcher authorization was used exactly once. Because failure occurred before the durable authorization commit, H02 runtime authorization remains `UNCONSUMED`; nevertheless, this stage permits no retry or second launcher. Independent remediation/progression authorization is required before any further H02 action.

**NO SECOND A2 LAUNCHER OR H02 RUNTIME WAS EXECUTED. H03 REMAINS UNTOUCHED.**
