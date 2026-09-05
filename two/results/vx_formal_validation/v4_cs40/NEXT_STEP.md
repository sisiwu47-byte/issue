# VX-V4-CS40 next step

Do not generate thesis performance/mechanism figures from `VX_CS40_raw.mat` as a successful combined-slip case yet.

Reason: corrected initial speed is valid, but the drive-slip physical gate failed (`RL/RR = 0/0 s`) while the brake-slip gate passed (`2.731/2.731 s`).

Next scientific task: preregister a new corrected-initial-state physical-only acceleration excitation calibration that preserves `SV_VXS=40 km/h`, `MU_ROAD_CONSTANT=0.30`, zero steering, frozen estimator/source parameters, and the successful brake segment. Select the first candidate that passes the rear drive-slip kinematic gate using physical signals only. Only after freezing that excitation should one fresh formal runtime and thesis plotting be allowed.
