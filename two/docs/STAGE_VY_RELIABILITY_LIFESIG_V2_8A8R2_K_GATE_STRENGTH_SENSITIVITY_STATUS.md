# V2.8-A8R2 K-health Gate Strength Sensitivity Status

`2 — GATE_FORM_INSUFFICIENT`

Read-only replay of the frozen `4.70--22.00 s` A3 physical-low-yaw window
shows monotonic benefit from stronger attenuation:

| Case | RMSE [m/s] | Mean alpha_K | Max alpha_K |
|---|---:|---:|---:|
| `G_K` | 0.12261568 | 0.109349 | 0.147297 |
| `G_K^2` | 0.09801441 | 0.086010 | 0.147297 |
| `G_K^3` | 0.08382147 | 0.070966 | 0.147297 |
| ideal K-off | 0.01259078 | 0 | 0 |

The current gate is too weak where active, but exponentiation cannot affect
the `196/1731` samples for which `G_K=1`. The Case-C maximum error occurs at
`t=21.43 s`, with `G_K=1` and K error `-1.70633 m/s`; consequently Case B and
Case C retain the same `0.26342719 m/s` MaxAbs. The dominant remaining issue is
therefore gate-form coverage, not an exponent-strength setting.

All five frozen FWCAL normal maneuvers have `G_K=1` throughout, so Cases A/B/C
have zero output change, zero alpha change, and zero mis-trigger. Ideal K-off
was not applied outside the offline low-yaw upper-bound ablation.

No runtime or frozen-file modification occurred. Full evidence is in
`results/vy_lifesig_v2_8a8r2_k_gate_strength_sensitivity/`.
