# VX-V1 Evidence Separation

- Snapshot date: 2026-09-02
- `FORMAL_RUNTIME_COUNT = 0`

## CURRENT_IMPLEMENTATION

The current executable lineage is frozen by `parameter_snapshot.md` and `interface_snapshot.md`. Formal results must match the estimator, parameter, wrapper and model hashes recorded there.

## HISTORICAL_VALIDATION

| Historical file | SHA-256 | Classification |
|---|---|---|
| `tests/results_case_A.mat` | `78BFDC86D880DFA7D1197A1662A5E433F4E2C97C082639029187768192519CFA` | `HISTORICAL_VALIDATION` |
| `tests/results_case_B.mat` | `6A5FA6E820DD1AD4C79808073413F4B123537263DE293AC5742AAF42C31521AB` | `HISTORICAL_VALIDATION` |
| `tests/results_case_C.mat` | `BB0D02FA9BACF1EBD807AC80F6041E8439E82C01A67C757A26F8427CCC45E718` | `HISTORICAL_VALIDATION` |
| `tests/results_case_D.mat` | `6AA9A7CC0EE29E8191815D7CD77294AE1CEE43ED9D4C8816677ADE7EA46AC453` | `HISTORICAL_VALIDATION` |
| `tests/results_case_E.mat` | `DD2FF6DEA712E06ABF614828251641852B9A7A5524DCA7E0F772C765FAA8B2CA` | `HISTORICAL_VALIDATION` |
| `tests/results_case_F.mat` | `ACA61FA4C7C4D703887D57DBFC59B7234A23EAD6D9ADF4B95DED359B999445B1` | `HISTORICAL_VALIDATION` |
| `tests/results_case_G.mat` | `CDC65C8AD7D29F0A92371BC65E170EF21E128D05F5B364CA6B0735C3973D2660` | `HISTORICAL_VALIDATION` |
| `tests/results_case_H.mat` | `177B22033F70A3D24083FD22DF0DB302EB9D5644E76E37D8410BF409DBC12E58` | `HISTORICAL_VALIDATION` |

These MAT files do not carry the current estimator hash, parameter hash, model hash, or the VX-V1 manifest version. Their surrounding analysis records use historical `kA=70`, `kH=60`, whereas the current implementation hard-codes `kA=30`, `kH=18`. They therefore remain an engineering matrix and are not formal evidence for the current version.

## FORMAL_CURRENT_VERSION_VALIDATION

No artifact currently belongs to this class. Only `VX_N1_formal.mat`, `VX_N2_formal.mat`, `VX_T1_formal.mat`, `VX_D1_formal.mat`, and `VX_D2_formal.mat` created through `package_vx_formal_runtime_result.m` with matching hashes and frozen windows may enter this class.
