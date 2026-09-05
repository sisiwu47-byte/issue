# V2.7-A3R6 Numerical Fallback and Implementation Contract Freeze

## Stage conclusion

```text
V2.7-A3R6 NUMERICAL FALLBACK AND IMPLEMENTATION CONTRACT FREEZE PASSED
```

This stage freezes the numerical and state-memory contract only. No `.m` or
`.slx` implementation was created or modified, and no MATLAB, Simulink,
CarSim, or `sim()` execution was performed.

## Frozen parameters and normal health path

The exact A3R1/A3R3 parameters are retained:

```text
q_D = 0.8426184093257221
q_K = 0.14643969744669255
q_F = 0.010941893227585452

tau_F = 28.252990189369939 s
Ts = 0.01 s
```

Availability and health are:

```text
availability_D = update_valid_D && isfinite(Vy_D)
H_D = double(availability_D)

availability_K = update_valid_K && isfinite(Vy_K)
H_K = double(availability_K)

availability_F = age_valid_F
                 && isfinite(propagation_age_steps)
                 && propagation_age_steps >= 0
                 && isfinite(Vy_F)

H_F = double(availability_F)
      * exp(-(propagation_age_steps*Ts)/tau_F)
```

The explicit `finite(Vy_F)` requirement is a numerical usability guard. It is
not new reliability evidence and does not alter the frozen age-health model.

For each track:

```text
score_i = q_i * H_i
S = score_D + score_K + score_F
```

Because all q values are finite and strictly positive, and each accepted
health is finite in `[0,1]`, every score is finite and nonnegative.

## NaN-safe normal evaluation

The implementation must not evaluate a vector expression such as
`sum(alpha .* Vy)` when an inactive track contains NaN, because IEEE
arithmetic makes `0*NaN=NaN`. Freeze the evaluation semantics as:

```text
Vy_term_i = score_i*Vy_i   only if the track is active and Vy_i is finite
Vy_term_i = 0              otherwise
numerator = sum(Vy_term_i)
```

If `isfinite(S) && S>0`:

```text
alpha_i = score_i / S
Vy_LS = numerator / S
fusion_valid = 1
fallback_active = 0

last_valid_Vy_LS = Vy_LS
has_last_valid = 1
```

No arbitrary epsilon is applied to S. On this normal branch:

```text
alpha_i >= 0
sum(alpha) = 1 within ordinary floating-point roundoff
Vy_LS is finite
```

## Fallback contract

If `S` is nonfinite or `S<=0`, the normal normalized fusion is unavailable.
Freeze:

```text
if has_last_valid:
    Vy_LS = last_valid_Vy_LS
else:
    Vy_LS = 0

alpha_D = 0
alpha_K = 0
alpha_F = 0
fusion_valid = 0
fallback_active = 1
```

The fallback branch does not update `last_valid_Vy_LS` or
`has_last_valid`. Its output exists only for numerical continuity and must
never be interpreted as a currently valid fused estimate. Alpha is explicitly
zero rather than a fabricated normalized fallback weight.

## Reset and persistent-state order

The implementation owns only:

```text
last_valid_Vy_LS : finite scalar [m/s]
has_last_valid   : logical
```

Initialization is `has_last_valid=0`; the numerical value stored in
`last_valid_Vy_LS` is irrelevant until the flag is set.

On an asserted reset event, processing order is frozen as:

1. clear `has_last_valid` and reset the stored numeric value to zero;
2. evaluate the current hit's D/K/F inputs through the normal health path;
3. if current inputs produce finite `S>0`, emit a normal valid output and
   establish it as the new last-valid value on the same hit;
4. otherwise emit the no-history fallback (`Vy_LS=0`, all alpha zero,
   `fusion_valid=0`, `fallback_active=1`).

Thus reset clears stale history but does not force a valid current hit into
fallback.

## Minimal signal contract

Candidate core inputs:

```text
Vy_D                  double scalar [m/s]
update_valid_D        logical-compatible scalar
Vy_K                  double scalar [m/s]
update_valid_K        logical-compatible scalar
Vy_F                  double scalar [m/s]
propagation_age_steps finite nonnegative scalar when age_valid_F=1
age_valid_F           logical-compatible scalar
reset                 logical-compatible scalar
```

Frozen parameters are `q_D/q_K/q_F`, `tau_F`, and `Ts`. Candidate outputs:

```text
Vy_LS             double scalar [m/s]
alpha_D/K/F       double scalars
fusion_valid      logical-compatible scalar
fallback_active   logical-compatible scalar
```

The fusion core executes on the common 100-Hz contract. No estimator state,
covariance, or diagnostic path is modified.

## Required A3R7 unit-test cases

The implementation must cover at least:

1. all three tracks valid: exact formula and normalized alpha;
2. one valid track: that track receives alpha one;
3. D, K, and F invalid independently: inactive alpha/term is zero;
4. invalid track carries NaN Vy: output remains finite and unpolluted;
5. all tracks invalid before any valid result: zero invalid fallback;
6. all tracks invalid after a valid result: last-value hold with invalid flag;
7. repeated fallback: last-valid memory is unchanged;
8. reset with invalid current inputs: history cleared and zero fallback;
9. reset with valid current inputs: same-hit normal output replaces history;
10. F age 0/1/later hits: exact exponential behavior;
11. regression that NIS, `abs(r)`, disagreement, covariance, and `Vy_true`
    cannot affect formal weights.

## Frozen scientific boundaries

- NIS_D/NIS_K, `abs(r)`, pairwise disagreement, and covariance remain
  `DIAGNOSTIC_ONLY` and do not enter the formal score.
- Online `Vy_true`, maneuver ID, future samples, and holdout switching remain
  forbidden.
- `P_AF = NOT_DEFINED`; no fused covariance is produced or claimed.
- No epsilon, new threshold, health parameter, Q/R tuning, or fused-RMSE
  optimization is introduced.

READY FOR V2.7-A3R7 LIFESIG FUSION CORE IMPLEMENTATION AND UNIT TEST
