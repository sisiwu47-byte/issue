function [x_new, P_new, info] = vy_dkekf_baseline( ...
    Ax_IMU, steering, z_Vx, z_r, z_Ay, doAyUpdate, resetFlag)
%VY_DKEKF_BASELINE Persistent wrapper for the unified V2.2-B baseline.
%
% resetFlag initializes [Vx; Vy; r] to [z_Vx; 0; 0] and P to 0.1*I.
% The reset sample then follows the same prediction/update path as all
% subsequent samples. No lateral-speed truth is accepted by this wrapper.

persistent xState PState

assert(isscalar(resetFlag) && isfinite(resetFlag), ...
    'resetFlag must be a finite scalar.');
[par, cfg, Ts, P0] = baseline_configuration();

if isempty(xState) || isempty(PState) || resetFlag > 0.5
    xState = [z_Vx; 0; 0];
    PState = P0;
end

[x_new, P_new, info] = vy_dkekf_baseline_step( ...
    xState, PState, Ax_IMU, steering, z_Vx, z_r, z_Ay, ...
    doAyUpdate, Ts, par, cfg);
xState = x_new;
PState = P_new;
end

function [par, cfg, Ts, P0] = baseline_configuration()
% Values are direct frozen D-EKF V1.17 / K-KF V2.1 mappings, not tuning.
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
Ts = 0.01;
cfg = struct();
cfg.Q_DK = diag([1e-4, 1e-4, 1e-4]);
cfg.R_Vx = 1e-4;
cfg.R_r = 3.365172961808e-4;
cfg.R_Ay = 1e-2;
cfg.jacobianStep = 1e-6;
cfg.denomEps = 1e-12;
cfg.lambda = zeros(4,1);
P0 = diag([0.1, 0.1, 0.1]);
end
