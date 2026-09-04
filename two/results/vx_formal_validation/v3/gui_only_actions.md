# VX V3 GUI-only Actions

`MANUAL_GUI_ACTION_COUNT = 0`

The static audit located case-control files, road/vehicle/run identities, the A20-C1 steering definition, the active speed-reference block, and the current CarSim input path. `matlab/configure_vx_formal_case_v3.m` creates case-specific validation copies and control directories without saving changes to `model/vx.slx`.

The following are runtime physical gates, not GUI setup actions:

- proving actual `delta_RL/delta_RR` motion in `VX-ST`;
- proving rear drive-slip behavior in the `VX-DR` acceleration phase;
- proving rear braking/lock behavior in the `VX-DR` braking phase;
- identifying an independently measured effective tire-road coefficient beyond the saved CarSim dataset/token combination.

No generalized “please confirm configuration” action is left for the user.
