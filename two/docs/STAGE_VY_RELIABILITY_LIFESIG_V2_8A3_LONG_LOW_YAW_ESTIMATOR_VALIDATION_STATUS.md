# V2.8-A3 Long Low-Yaw Estimator Validation Status

## Stage verdict

`LOW_YAW_RUNTIME_INSUFFICIENT`

The one authorized V2.8-A3 simulation completed to 22 s and produced complete,
aligned evidence.  However, the run did not produce a sufficiently long
continuous interval below the literature-derived candidate boundary
`|r| < 0.01 rad/s`.  The longest such interval was only 1.09 s.  Therefore the
observed K-KF error cannot be promoted to a validated claim of sustained
low-yaw drift.

## Authorization and execution

- A2 remained closed and was not rerun.
- A3 `sim()` invocation count: 1.
- A3 runtime authorization: consumed.
- No rerun is authorized or was performed.
- MATLAB batch exited after the offline analyzer intentionally rejected the
  continuous-low-yaw sufficiency gate; this was not a simulation failure.
- No residual A3 MATLAB/helper/CarSim solver process remained after exit.

## Independent 22-s run control

- Simulink requested and returned 22 s.
- CarSim console: `Termination at simulation time = 22 s.`
- CarSim solver:
  `D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`.
- Shared run-control remained unchanged:
  `2FA959F8137B6014F87BC70F1F7716308E92FF22B8E4E7BD6CCC4179EA16C114`.
- Independent `Run_all.par`:
  `40FADB13A5B4826309830A6061DBC881CCAB2B94A8F53E7473EA3ED1C4D650A8`.
- Shared and independent run-control files have equal length and exactly two
  differing bytes, corresponding to `TSTOP 16` -> `TSTOP 22`.
- Independent `simfile.sim`:
  `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`.
- Long-low-yaw target remained unchanged:
  `576019D260B8BD412F93827BE29F74FEFCBABB8FD23DF0735CA372067EABF829`.

## Runtime integrity

- Samples: 2201.
- Time range: 0 to 22 s.
- Sample interval: 0.01 s.
- Full `SimulationOutput` was saved before the duration gate.
- Required logs saved: 13/13.
- D/K error-log replay was exact within the frozen analyzer tolerance.
- Steering command after 4.5 s was exactly zero within `1e-14`.

## Low-yaw coverage after 4.5 s

| Partition | Total duration (s) | Longest continuous duration (s) | Longest window (s) |
|---|---:|---:|---:|
| `|r| < 0.005 rad/s` | 8.81 | 0.16 | 12.23--12.39 |
| `|r| < 0.010 rad/s` | 16.55 | 1.09 | 6.35--7.44 |
| `|r| < 0.020 rad/s` | 17.46 | 17.46 | 4.54--22.00 |

The 0.02 rad/s partition is a descriptive sensitivity partition and is not a
substitute for the candidate 0.01 rad/s near-unobservable boundary.

## Descriptive D/K results in the longest `|r| < 0.01 rad/s` window

| Metric | D-EKF | K-KF |
|---|---:|---:|
| RMSE (m/s) | 0.00428055206419522 | 0.440747687785642 |
| MAE (m/s) | 0.00409550040885458 | 0.439982477970554 |
| MaxAbs (m/s) | 0.00707992180384865 | 0.484137583165647 |
| Bias (m/s) | -0.00409550040885458 | -0.439982477970554 |
| Error start (m/s) | -0.00432809060763443 | -0.401285400374751 |
| Error end (m/s) | -0.00363410935133164 | -0.483598004999229 |
| End-start drift (m/s) | 0.000693981256302785 | -0.0823126046244778 |
| Linear slope (m/s/s) | -0.000341872742535201 | -0.0814426878675748 |

These values are descriptive evidence of poor K-KF behavior in a short
low-yaw interval.  They do not establish a sustained-low-yaw gate or prove
the causal mechanism, because the required continuous interval was absent.

## Evidence

- Runtime MAT:
  `results/vy_lifesig_v2_8a3_long_low_yaw_runtime.mat`
  (`FA1BAB75DB7EF33B634E649704D7950166BEA5184E1496F57AB953C7B32AC771`).
- Analysis MAT:
  `results/vy_lifesig_v2_8a3_long_low_yaw_analysis.mat`
  (`92A18A9D77D8F91CEF1AF3088F0104C5C025859A1CFD3939BEF2561E6A92ADD5`).
- Summary CSV:
  `results/vy_lifesig_v2_8a3_long_low_yaw_summary.csv`
  (`36A825C94FAAE2F0FB719E6ECD7EC5952FAF41C2CDA489EB7F58478828EB39BE`).

## Frozen scope

No K gate, LifeSig logic, D/K/F estimator, Q/R, static prior, or `tau_F` was
modified.  No second A3 runtime was performed.
