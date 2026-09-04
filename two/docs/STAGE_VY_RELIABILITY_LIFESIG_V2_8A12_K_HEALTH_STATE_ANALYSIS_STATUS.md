# V2.8-A12 K Health-state Recovery Analysis Status

`B — LEAKY_INTEGRATOR_MOST_SUITABLE_STATE_CLASS`

Offline A3/A8 replay shows that pure integration supplies the strongest
low-yaw suppression but never recovers. The `rho=0.995` leaky variant is the
best recoverable state for lambda `0.5--5` and remains close to the pure
integrator at lambda `10`. A `0.5 s` trailing window becomes marginally best at
lambda `10`, but the sliding-window class is more sensitive to the supplied
window/lambda choices.

No observed normal segment follows the A3 low-yaw window, so recovery is not
empirically validated. Analytic zero-excess continuation confirms that leaky
states recover smoothly and windows clear in finite time; pure integration
does not recover. Four FWCAL maneuvers remain exactly unaffected. C02 has 16
threshold exceedances; recoverable states bound and remove the resulting
suppression instead of retaining it permanently.

Only the state-variable class priority is recorded. No rho, window, lambda, or
formal algorithm is frozen. No runtime or source modification occurred.

Full evidence is in:
`results/vy_lifesig_v2_8a12_k_health_state_analysis/`.
