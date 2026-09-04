# V2.7-A3R8 Simulink Wrapper and Integration Target

## Stage status

```text
V2.7-A3R8 BLOCKED BY HEALTH-SIGNAL INTERFACE CONTRACT
```

The stage stopped during the required read-only interface audit. No wrapper,
builder, validator, integration target, or test was created. MATLAB, Simulink,
`sim()`, and CarSim were not started.

## Confirmed A3R7 core interface

`model/vy_lifesig_fusion_step.m` has ten inputs and eight outputs.

Inputs:

```text
Vy_D
update_valid_D
Vy_K
update_valid_K
Vy_F
propagation_age_steps
age_valid_F
reset
last_valid_Vy_LS
has_last_valid
```

Outputs:

```text
Vy_LS
alpha_D
alpha_K
alpha_F
fusion_valid
fallback_active
last_valid_Vy_LS_next
has_last_valid_next
```

The core does not expose `H_D`, `H_K`, or `H_F`.

## Existing target facts

The independent reliability diagnostic target provides the required primitive
signals:

```text
Vy_D, update_valid_D
Vy_K, update_valid_K
Vy_F, propagation_age_steps, age_valid_F
reset
```

It logs D/K validity and F age diagnostics, but it contains no existing
runtime signal carrying the exact frozen `H_D`, `H_K`, or `H_F` values. The
A3R8 requirement explicitly asks the new integration target to log those
three health values.

## Exact contract conflict

A3R8 simultaneously requires:

1. the wrapper to own only the two last-valid memory values;
2. the wrapper not to repeat or modify fusion mathematics;
3. the target to log exact `H_D`, `H_K`, and `H_F`;
4. no modification of the A3R7 core within the enumerated allowed changes.

Computing the health values again in the wrapper or in separate target blocks
would duplicate A3R6/A3R7 formal health mathematics and create two sources of
truth. The existing core cannot supply them through its current output
contract. Therefore the requested wrapper and logging contract cannot both be
implemented without exceeding the authorized scope.

## Minimal future resolution

The preferred minimal remediation is an explicitly authorized,
diagnostic-output-only extension of `vy_lifesig_fusion_step`:

```text
additional outputs: H_D, H_K, H_F
```

The score, alpha, fused output, fallback, reset order, frozen priors,
`tau_F`, and memory transition would remain byte-for-byte equivalent in
mathematical behavior. The A3R7 unit test would be updated to verify the three
health outputs and regression-check all original eight outputs. A wrapper
could then delegate every computation to the core, retain only two DWork
values, expose the nine runtime outputs, and satisfy the logging requirement
without duplicated mathematics.

No such extension was performed because this stage did not explicitly
authorize modification of the A3R7 core interface.

## Integrity snapshot

| Artifact | SHA-256 |
|---|---|
| `model/vy_lifesig_fusion_step.m` | `B010F7DBDDDA47A236A74BD439B4E52BD5687FBDDF51D745D1A79CBF8FEBCECE` |
| `model/vx_vy_reliability_diagnostic_v2_7.slx` | `2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F` |
| `model/vy_fixed_weight_fusion_simulink_sfun.m` | `B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A` |
| `model/vy_feedback_propagation_simulink_sfun.m` | `AA3E9E79D81D1C3D8155D4FF04ED952357B0294E09DF868FEBC7E05753E64FD8` |
| A3R6 contract | `6EF8134E162B61F3E4DB494DEEFDC6D3465DB7EC9CB025095D44C423BAAE90CF` |
| A3R7 status | `EEA6E70E4032A2916B75A0B29B4B79109C70DD757532A8803E5972DA618FE7B5` |

At stop time:

```text
LifeSig wrapper = ABSENT
LifeSig integration target = ABSENT
SLX modification = NONE
MATLAB/Simulink compile = NOT RUN
sim() = NOT CALLED
CarSim runtime = NOT RUN
```
