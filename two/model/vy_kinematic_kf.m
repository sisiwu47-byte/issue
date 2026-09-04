function [x_new, P_new, diag_out, reliability] = vy_kinematic_kf(u, z, resetFlag)
%VY_KINEMATIC_KF Persistent wrapper for the V2.1 baseline core.
%#codegen
%
% u         = [Ax_IMU; Ay_IMU; AVz_IMU]
% z         = scalar Vx measurement
% resetFlag > 0.5 reinitializes x and P before processing this sample.
%
% diag_out = [NIS; obs_metric; innovation_vx; K11; K21]

persistent xState PState

u = u(:);
assert(numel(u) == 3, 'u must contain [Ax_IMU; Ay_IMU; AVz_IMU].');
assert(isscalar(z) && isfinite(z), 'z must be a finite scalar.');
assert(isscalar(resetFlag) && isfinite(resetFlag), ...
    'resetFlag must be a finite scalar.');

cfg = struct();
cfg.Ts = 0.01;
cfg.Q_K = diag([1e-4, 1e-3]);
cfg.R_Vx = 1e-4;

P0 = diag([0.1, 0.1]);

if isempty(xState) || isempty(PState) || resetFlag > 0.5
    % Initialize longitudinal speed from the available Vx measurement and
    % use the stage-1 lateral prior vy=0. The current sample is then passed
    % through the same prediction/update path as every later sample.
    xState = [z; 0];
    PState = P0;
end

[x_new, P_new, info] = vy_kinematic_kf_step(xState, PState, u, z, cfg);
xState = x_new;
PState = P_new;

diag_out = zeros(5,1);
diag_out(1) = info.NIS;
diag_out(2) = info.obs_metric;
diag_out(3) = info.innovation;
diag_out(4) = info.K(1);
diag_out(5) = info.K(2);
if nargout>3
    reliability=struct('update_valid_K',logical(info.updateValid), ...
        'nis_valid_K',logical(info.updateValid), ...
        'NIS_K',double(info.NIS),'S_K',double(info.S), ...
        'obs_metric_K',double(info.obs_metric), ...
        'reset_input_K',logical(resetFlag>0.5));
end
end
