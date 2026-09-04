function [x_new, P_new, info] = vy_kinematic_kf_step(x, P, u, z, cfg)
%VY_KINEMATIC_KF_STEP One 100 Hz kinematic Kalman-filter step.
%#codegen
%
% State:       x = [vx; vy]                  [m/s]
% IMU input:   u = [Ax; Ay; yaw rate]        [m/s^2; m/s^2; rad/s]
% Measurement: z = Vx                       [m/s]

x = x(:);
u = u(:);

assert(numel(x) == 2, 'x must contain [vx; vy].');
assert(isequal(size(P), [2 2]), 'P must be 2x2.');
assert(numel(u) == 3, 'u must contain [Ax; Ay; yaw rate].');
assert(isscalar(z), 'z must be a scalar Vx measurement.');
assert(isscalar(cfg.Ts) && isfinite(cfg.Ts) && cfg.Ts > 0, ...
    'cfg.Ts must be positive and finite.');
assert(isequal(size(cfg.Q_K), [2 2]), 'cfg.Q_K must be 2x2.');
assert(isscalar(cfg.R_Vx) && isfinite(cfg.R_Vx) && cfg.R_Vx > 0, ...
    'cfg.R_Vx must be positive and finite.');
assert(all(isfinite(x)) && all(isfinite(P(:))) && all(isfinite(u)) && ...
    isfinite(z) && all(isfinite(cfg.Q_K(:))), ...
    'Filter inputs and covariance parameters must be finite.');

Ts = cfg.Ts;
ax = u(1);
ay = u(2);
r = u(3);

F = [1, r*Ts; -r*Ts, 1];
H = [1, 0];

x_pred = F*x + Ts*[ax; ay];
P_pred = F*P*F.' + cfg.Q_K;
P_pred = 0.5*(P_pred + P_pred.');

innovation = z - H*x_pred;
S = H*P_pred*H.' + cfg.R_Vx;
assert(isfinite(S) && S > 0, 'Innovation covariance must be positive.');

% S is scalar. Right division solves the gain without forming an inverse.
K = (P_pred*H.')/S;
x_new = x_pred + K*innovation;

% Joseph covariance update preserves symmetry and positive semidefiniteness.
I_KH = eye(2) - K*H;
P_new = I_KH*P_pred*I_KH.' + K*cfg.R_Vx*K.';
P_new = 0.5*(P_new + P_new.');

NIS = innovation^2/S;
obs_metric = abs(r);
updateValid = isfinite(innovation) && isfinite(S) && S > 0 && ...
    isfinite(NIS) && all(isfinite(x_new)) && all(isfinite(P_new(:)));

info = struct();
info.x_pred = x_pred;
info.P_pred = P_pred;
info.innovation = innovation;
info.S = S;
info.K = K;
info.NIS = NIS;
info.updateValid = updateValid;
info.obs_metric = obs_metric;
info.obs_flag = obs_metric > 0.01;
info.F = F;
info.H = H;
end
