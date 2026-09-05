# VX-V4-CS40

Corrected-initial-state diagnostic branch for the low-mu longitudinal acceleration/braking case.

Current status: `VX_CS40_PHYSICAL_GATE_CHANGED_AFTER_INITIAL_STATE_FIX`.

Key facts:
- CarSim initial speed token: `SV_VXS = 40 km/h`.
- Actual first finite CarSim `Vx = 11.111111 m/s = 40 km/h`.
- Old `72 -> 40 km/h` initial transient disappeared.
- Drive-slip physical gate `[3,7)`: FAIL, RL/RR `0/0 s`.
- Brake-slip physical gate `[9,12)`: PASS, RL/RR `2.731/2.731 s`.
- Old V3B raw/freeze remain unchanged.

This branch is diagnostic evidence only and is not yet a thesis-valid combined-slip case because the drive-slip physical gate failed.
