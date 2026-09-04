# V2.7-A2R7 RELIABILITY DIAGNOSTIC SMOKE RUNTIME

## Verdict

**RELIABILITY_DIAGNOSTIC_SMOKE_PASS**

This was one short `NON_HOLDOUT_ENGINEERING_DIAGNOSTIC` run. It is not H01,
H02, or H03 and is not calibration or holdout evidence.

## Fixed condition

```text
StopTime              = 0.20 s
Vx                    = 20 m/s
front steering        = 0.02 rad, 0.4 Hz
rear steering         = 0
estimator rate        = 100 Hz
```

The target was executed from `D:\UsersData\桌面\two\model`, so the relative
`simfile.sim` resolved to the validated D: CarSim lineage.

## Runtime evidence

- One and only one `sim()` call; simulation completed normally.
- CarSim solver completion was observed using
  `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`.
- 21 aligned samples, `t=0…0.20 s`, `dt=0.01 s`.
- All required D/K/F logs, common 100-Hz time, and offline `Vy_true` were
  present, aligned, and finite.
- D logs: `Vy_D`, `P_D11`, `NIS_D`, `measurementDimension_D`, `useAy_D`,
  `update_valid_D`, `nis_valid_D`.
- K logs: `Vy_K`, `P_K22`, `NIS_K`, `abs(r)`, `update_valid_K`,
  `nis_valid_K`.
- F logs: `Vy_F`, `P_F`, `propagation_age_steps`, `age_valid`,
  `reset_valid`.

## Validity and F-age semantics

D/K validity signals were finite and consistent; no invalid or unexecuted
NIS=0 path was marked valid. This smoke contained no exact zero-NIS sample,
so the normal-zero case is retained as the A2R2 unit-tested contract rather
than claimed as a new runtime observation.

The F reliability log was interpreted according to the frozen A2R2 contract:
`reset_valid=1` means the finite reset input was consumed, not that reset is a
persistent pulse. The observed age sequence was exactly `0,1,2,…,20`, with
`age_valid=1` and `reset_valid=1` throughout. Thus the initial age-zero sample
provides reset-hit evidence, the first non-reset propagation is age 1, and
subsequent valid hits increment by one.

## Integrity and scope

- Diagnostic target SHA-256 before/after:
  `2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F`
  (unchanged).
- Frozen fixed-fusion target and D/K/F source hashes remained unchanged.
- No LifeSig calculation, Q/R or P0_F/Q_F adjustment, covariance mapping,
  fusion change, holdout run, or calibration acquisition occurred.
- The first batch attempt stopped before `sim()` because of a script-only Java
  hash helper typo; after correcting that helper, the single actual runtime
  was executed exactly once. No second simulation was performed.

Result MAT:
`results/vy_reliability_diagnostic_v2_7a2r7_smoke.mat`

## Decision

The reliability diagnostic target has a successful short engineering runtime
and logging capture. It is eligible for the next non-holdout reliability
diagnostic calibration-capture stage; it does not authorize holdout reruns or
parameter tuning.

READY FOR V2.7 RELIABILITY DIAGNOSTIC CALIBRATION CAPTURE
