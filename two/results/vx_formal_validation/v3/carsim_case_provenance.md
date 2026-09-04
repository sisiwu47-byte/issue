# CarSim Case Provenance for VX V3

## Static audit result

The vehicle/run/road/control identities needed to build the V3 cases are locatable from local files. No GUI action is required to identify or copy them. This is configuration provenance; runtime behavior must still be demonstrated by current Vx formal evidence.

| item | exact local identity | classification |
|---|---|---|
| current CarSim package | `model/vx.cpar`, SHA-256 `4FCE6AF958495B7307F3F48B40DE8A6863DAFE4E00C903D7B829C0E74E175CD2` | `CURRENT_IMPLEMENTATION_CONFIGURATION` |
| companion package | `model/Agent_chassis.cpar`, SHA-256 `E994B01106E5127BCBF77C5399FE573CE28F3A063F67996DC8788F75BE81BEAA` | `CURRENT_IMPLEMENTATION_CONFIGURATION` |
| run dataset | `Runs\\Run_d05bfc0b-97ca-48c5-b21f-3525f5950963.par` | resolved |
| vehicle | `Vehicle_1948dce2-4b34-42aa-8c90-ff8a11ae7f14`, `C-Class, Electric source` | resolved |
| steering system | `StrSys2_460503eb-d669-441b-a769-41e4a541887d`, `C-Class, 4WS` | resolved configuration identity; actual rear motion still requires runtime proof |
| powertrain | `4WD_32c72a7a-c260-4794-8d2a-5f755cb8e0df`, `150 kW, 6-spd., 4.1 Ratio #1` | resolved |
| brake system | `Brk4W_24c07e14-cfc1-49a5-9b66-5d900c8e18e4`, `C-Class (Hbk): MC Press, No ABS`; `OPT_ABS_CTRL=0` | resolved system identity only; not a proven wheel-lock excitation |
| procedure | `Proc_2cb512de-d419-4586-abec-b095521e6be3`, `DLC Low Friction` | resolved |
| road surface | `Road_014f1dcf-7ba1-4901-b58f-2eee953737d4`, `casadi0` | resolved |
| friction map | `RdMu_d71e1177-4da5-4b2d-ad7d-decb01c69ad9`, displayed dataset label `0.35` | resolved identity |
| I/O | import `Import_572c2be7-5a44-412b-842d-8d18e8267169`; export `Export_b76c02c4-f329-4671-b5fd-efa878d20cbd` | resolved |

The embedded current runs in both `.cpar` packages have `TSTOP=16`, `MU_ROAD_COMBINE=MULTIPLY`, and `MU_ROAD_CONSTANT=0.8`. Their key identities match even though the archive and embedded-run hashes differ.

## Directly reusable headless control sources

| use | source pair | hashes | evidence boundary |
|---|---|---|---|
| `VX-ND`, `VX-ST` | `results/vy_lifesig_v2_8a20_limited_cross_condition/carsim_control_C1/{simfile.sim,Run_all.par}` | simfile `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`; control `1E3F016EEB9D79AA06A013A359C74B32AC94550F07145DA93ED1C698F9AA4BBB` | nominal configuration lineage |
| `VX-DR`; V3A `VX-DS` | `results/vy_lifesig_v2_8a20b_mu03_diagnostic/carsim_control_MU03/{simfile.sim,Run_all.par}` | simfile `D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A`; control `8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8` | low-mu configuration; current V3 runtime additionally proved reproducible rear drive-slip under acceleration |
| `VX-BL` | none currently traceable | none | **NOT A REUSABLE FORMAL CONFIGURATION**; do not infer brake lock from mu=0.30 plus a 70->40 speed reference |

The configurator copies source pairs into case-specific validation directories and does not alter the source controls, current `.cpar` packages, estimator, or frozen parameters.

## V3 runtime clarification

The completed current-version `VX-DR` runtime establishes an important asymmetric result:

- acceleration phase: rear positive-slip gate PASS, RL/RR sustained `1.906/1.906 s`;
- braking phase: rear braking-degradation gate FAIL, RL/RR sustained `0/0 s`, `NOT_DETECTED`.

Therefore the A20b-MU03 control is now empirically supported for a dedicated drive-slip case, but **not** for a brake-lock case. A future brake-lock validation would require a separately traceable braking excitation/configuration and new preregistration.

## Road/mu interpretation boundary

Local files identify the road dataset and scalar tokens `0.8` and `0.30`. They also show `MU_ROAD_COMBINE=MULTIPLY` while the friction-map dataset is displayed as `0.35`. Therefore the configured scalar-token provenance is resolved, but an independently measured effective tire-road coefficient is not identified by these files and must not be claimed.

## F/G audit boundary

`tests/results_case_F.mat` and `tests/results_case_G.mat` contain historical 16 s time histories consistent with rear-wheel drive-slip and braking degradation. However, neither MAT carries a CarSim dataset/run hash, estimator hash, parameter hash, or source configuration. Both retain polluted generic metadata; the G file retains acceleration-oriented command metadata despite its braking trajectory. Historical tuning scripts only read the MATs and use old parameter declarations; they do not reconstruct the missing G braking excitation.

Hence:

- F/G remain `HISTORICAL_BEHAVIOR_TEMPLATE` only;
- F has current physical corroboration through V3 acceleration behavior, but its old MAT is still not current formal evidence;
- G does not provide a reproducible brake-lock configuration;
- V3A selects `VX-DS` for the thesis representative degradation/recovery case and does not authorize `VX-BL`.
