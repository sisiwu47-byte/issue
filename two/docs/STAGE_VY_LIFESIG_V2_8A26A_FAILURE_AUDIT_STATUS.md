# V2.8-A26a D-only validation failure audit status

## Verdict

`A26A_FAILURE_AUDIT_PASS`  
`A26_FAILURE_CLASSIFICATION = CASE_B_D_DEGRADATION_TOO_WEAK`  
`READY_FOR_CORRECTED_D_ONLY_RUNTIME = YES`

## Excitation and K diagnosis

- A/B/C steering is the same continuous `0.02 rad / 0.4 Hz` sine; maximum profile error is below `7e-16 rad`.
- B: yaw mean absolute/RMS `0.0786834/0.0872716 rad/s`; Ay mean absolute/RMS `1.50237/1.66435 m/s^2`; Vx mean `19.9791 m/s`.
- Physical low yaw (`|r|<0.01 rad/s`): B coverage `4.8%`, longest interval `0.05 s`.
- B K RMSE/MAE/MaxAbs/Bias: `0.294638/0.293344/0.349362/-0.293344 m/s`.
- K-cause classification: `OTHER — SAME_CONDITION_PERSISTENT_NEGATIVE_BIAS`; bias accounts for `99.1235%` of MSE. Low yaw and insufficient excitation are rejected.

## D mismatch and recovery

- D-only `par.k_f`: A/B/C `0.78181/1.0/0.78181` (`+27.9083%` B intensity); no K/F/plant effect.
- B D RMSE is `28.7892%` above C but `32.2243%` below A; mean normalized-NIS is `105.662%` above C. Formal D degradation is too weak/inconsistent.
- C mismatch restoration is correct and `G_D=1` over the first C second. Recovery is `NOT_ESTABLISHED` because the B degradation/alpha-D premise was absent, not because of runtime length, smoothing delay, or C excitation.

## Existing baseline and corrected scenario

- Reusable evidence exists: A17d phase A, continuous `0.02 rad / 0.4 Hz` sine, K/D RMSE `0.173362/0.0374407 m/s`; usable as a nominal excitation baseline, with A26 C as the longer same-waveform reference.
- One corrected scenario is frozen: plant `mu=0.8`, same steering and A/B/C windows, D-only `par.k_f=0.78181/0.390905/0.78181`; the B value is exactly half nominal and was not searched.
- `NEW_RUNTIME_COUNT=0`; health, Q/R/P0, K parameters, estimator/model, and acceptance rules are unchanged.
