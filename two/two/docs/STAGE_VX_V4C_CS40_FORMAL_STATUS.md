# VX-V4C-CS40 formal validation status

- Stage: `VX-V4C-CS40-FORMAL`
- Verdict: `VX_CS40_V4C_FORMAL_PASS`
- Formal runtime count: 1 (frozen V4B candidate A1 only)
- Actual initial Vx: 11.1111111111 m/s (40 km/h), gate PASS
- Drive RL/RR sustained duration: 1.552000 / 1.552000 s, gate PASS
- Brake RL/RR sustained duration: 2.731000 / 2.731000 s, gate PASS
- Estimator finite gate: PASS (Fusion / Adaptive WSS / IMU)
- Overall Traditional WSS RMSE: 17.6200664734 m/s
- Overall Fusion RMSE: 0.0154850250352 m/s
- Drive Traditional/Fusion RMSE: 2.91899141052 / 0.0163490632773 m/s
- Brake Traditional/Fusion RMSE: 26.6786786237 / 0.0244167969782 m/s
- V4B text evidence archive commit: `3e04be0de7a8844cf1f94b498649e779007afb18` (four text files only)
- Local V4B A1 physical MAT SHA256: `36FD8DE63C43F5A3C9CB58FB327AF211CFCB3203E34782C0DC26E65FAD0C97E3`
- Protection: V3B, V4-CS40, V4B calibration, source vx.slx, estimator and parameters unchanged.
- Calibration evidence was not used as formal estimator performance evidence.
