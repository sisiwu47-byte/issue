# VX-ND60 formal status

- Stage: `VX-V4-ND60-FORMAL`
- Verdict: `VX_ND60_FORMAL_PASS`
- Formal runtime count: 1
- Control: `SV_VXS=60 km/h`, `MU_ROAD_CONSTANT=0.80`, `TSTOP=16 s`, steering `0 rad`.
- Actual initial Vx: 16.6666666667 m/s (60 km/h), initial gate PASS.
- Estimator finite gate: PASS (Fusion / Adaptive WSS / IMU).
- Old 72->60 km/h initial transient disappeared: YES.
- Traditional WSS RMSE: 0.179592765914 m/s; Fusion RMSE: 0.0264882432191 m/s; improvement: 0.153104522695 m/s.
- Source vx.slx, estimator, parameters, and V3/V3B/V4/V4B/V4C evidence remained unchanged.
- Remote sync note: two bounded fetch attempts failed because GitHub was unreachable; the last locally verified main baseline was retained.
