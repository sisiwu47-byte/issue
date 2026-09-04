# V2.8-A10 K Low-yaw Temporal-health Analysis Status

`A — EFFECTIVE_K_HEALTH_SUPPRESSION_INSUFFICIENT`

The requested causal `AVz_IMU` low-yaw duration state was reconstructed from
the full A8 replay before evaluating the frozen `4.70--22.00 s` physical
low-yaw window. Despite 95.03% online low-yaw duty, 69 reset interruptions
limit `T_lowyaw` to a `1.10 s` maximum and `0.218 s` mean.

The strongest tested time gate (`tau_test=1 s`) yields RMSE `0.147235 m/s`,
worse than current A8 (`0.122616 m/s`). Results weaken monotonically for
`tau_test=2/5/10 s`. Ideal K-off remains `0.012591 m/s`, demonstrating that
the output is recoverable if K is isolated.

Thus the A9 degradation is temporally cumulative, but the proposed strict
consecutive-duration memory does not capture it reliably and is not the
missing mechanism responsible for current A8 performance. No parameter is
selected or frozen. No runtime or source modification occurred.

Full evidence is in:
`results/vy_lifesig_v2_8a10_k_temporal_health_analysis/`.
