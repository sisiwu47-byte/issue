# V2.5-C0 Holdout Campaign Final Closure

## Final status

**V2.5 HOLDOUT CAMPAIGN CLOSED**

本阶段仅冻结既有证据和科学边界；未启动 MATLAB、Simulink 或 CarSim，未运行任何 holdout，未修改模型、算法、权重或 Q/R，未覆盖历史证据。

## Frozen fixed-weight baseline

V2.5 fixed-weight fusion implementation and calibration remain frozen.

- Formal target: `model/vx_vy_fixed_fusion_v2_5.slx`
- Target SHA-256: `AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- Fusion core SHA-256: `4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C`
- Fusion wrapper SHA-256: `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A`
- Calibration manifest: `results/vy_fixed_fusion_v2_5g2_calibration_acquisition_manifest.csv` (SHA-256 `8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275`)
- Weight manifest: `results/vy_fixed_fusion_v2_5h2_runtime_weight_manifest.csv` (SHA-256 `E409692637168719AE3B0537D49F81DC2AFB50A67D111A7C40793A76B18700EC`)

Frozen runtime weights are exactly:

```text
alpha_D = 0.9004680917645591
alpha_K = 0.09953190823544089
alpha_F = 0
```

No holdout-derived weight adjustment is allowed.

## Holdout outcomes

### H01

- Status: `CLOSED_FAILED_ACQUISITION`
- Authorization: `CONSUMED_FOR_NO_RETRY`
- Formal data: `NO_USABLE_HOLDOUT_DATA`
- No rerun, replacement, or condition substitution is allowed.
- Evidence: `docs/STAGE_VY_FIXED_FUSION_V2_5I1_F2_PARTIAL_HOLDOUT_CONTINUATION_AMENDMENT.md`

### H02

- Status: `POST_COMMIT_PERSISTENT_STALL_TERMINATED`
- Authorization: `CONSUMED`
- Formal data: `NO_USABLE_HOLDOUT_DATA`
- No second H02 runtime is authorized.
- Evidence: `docs/STAGE_VY_FIXED_FUSION_V2_5I2_A3_W3_STUCK_PROCESS_TERMINATION_CLOSURE.md`

### H03

- Status: `POST_COMMIT_CPU_SPIN_TERMINATED`
- Authorization: `CONSUMED`
- Formal data: `NO_USABLE_HOLDOUT_DATA`
- Root cause: `UNRESOLVED`
- No second H03 runtime is authorized.
- Evidence: `docs/STAGE_VY_FIXED_FUSION_V2_5I3_W4_H03_TERMINATION_CLOSURE.md`

H03 cannot provide `SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE` because no usable formal dataset was produced.

## Aggregate and scientific interpretation

- Original three-holdout aggregate: `INCOMPLETE_DUE_TO_MISSING_FORMAL_DATA`
- `PARTIAL23`: `NOT_COMPUTABLE`
- Holdout generalization classification: `NOT_AVAILABLE`

不得将上述状态改写为算法性能 PASS/FAIL，也不得解释为 estimator/fusion performance insufficiency。Holdout acquisition failures are infrastructure/acquisition outcomes, not estimator or fusion performance evidence.

不得基于 H01/H02/H03：

- 调整 fixed weights；
- 调整 Q/R；
- 修改模型或算法；
- 形成 generalization claim；
- 计算 PARTIAL23 或原 three-holdout aggregate。

## Next-development decision

```text
NEXT_MAINLINE = V2.6 COVARIANCE-BASED ADAPTIVE FUSION
Q/R_RETUNING_NOW = NOT_JUSTIFIED_BY_CURRENT_HOLDOUT_EVIDENCE
RUNTIME_INFRASTRUCTURE = SEPARATE_ENGINEERING_DIAGNOSTIC_REQUIRED_BEFORE_FUTURE_FORMAL_HOLDOUTS
```

Future runtime troubleshooting must use a non-formal, non-unique-authorized diagnostic condition and must not reuse H01/H02/H03 identities or authorizations.

Machine-readable closure evidence: `results/vy_fixed_fusion_v2_5c0_holdout_campaign_closure.csv`.
