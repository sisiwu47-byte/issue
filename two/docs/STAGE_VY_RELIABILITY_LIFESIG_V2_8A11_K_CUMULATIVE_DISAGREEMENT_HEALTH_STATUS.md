# V2.8-A11 K Cumulative-disagreement Health Status

`A — OUTPERFORMS_CURRENT_A8_OFFLINE`

The causal cumulative-disagreement replay improves the dedicated A3 physical
low-yaw result for every supplied `lambda`. RMSE decreases from current A8
`0.122616 m/s` to `0.057504`, `0.044048`, `0.035343`, `0.028271`, and
`0.024974 m/s` for `lambda=0.5/1/2/5/10 1/m`. Ideal K-off remains
`0.012591 m/s`; the strongest tested case is therefore not claimed to be fully
equivalent to ideal isolation, especially in MaxAbs.

Normal-data evidence is mixed: C01R1/C03/C04/C05 never exceed the frozen
disagreement boundary, but C02 has 16 exceedance samples. With no integral
reset/leak, this creates a persistent false K-weight reduction, conservatively
bounded at `G_K>=0.989919` and worst-case absolute normalized-alpha change
`<=0.002533` for `lambda=10`.

Thus cumulative disagreement is promising and superior to current A8 in this
offline record, but no lambda or implementation is frozen. Recovery semantics
and C02 normal impact require separate formulation. No runtime or source
modification occurred.

Full evidence is in:
`results/vy_lifesig_v2_8a11_k_cumulative_disagreement_health/`.
