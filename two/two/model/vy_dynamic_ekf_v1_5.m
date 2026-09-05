function y = vy_dynamic_ekf_v1_5(w, R_Ay_v15, R_r_v15)
%VY_DYNAMIC_EKF_V1_5 Diagnostic-only wrapper for covariance-budget audit.

persistent x P
if isempty(x), x = [0; 0]; end
if isempty(P), P = eye(2) * 0.1; end

assert(isscalar(R_Ay_v15) && isfinite(R_Ay_v15) && R_Ay_v15 > 0);
assert(isscalar(R_r_v15) && isfinite(R_r_v15) && R_r_v15 > 0);
w = w(:);
u = w(1:5);
z = w(6:7);

par.m = 1860;
par.Iz = 2687.1;
par.a = 1.18;
par.b = 1.77;
par.track = 1.575;
par.Rw = 0.393;

cfg.dt = 0.01;
cfg.Q = diag([1e-4, 1e-3]);
cfg.R = diag([R_Ay_v15, R_r_v15]);
cfg.denomEps = 1e-12;
cfg.lambda = zeros(4, 1);

[xNew, pNew, info] = vy_dynamic_ekf_step_v15_debug(x, P, u, z, par, cfg);
x = xNew;
P = pNew;

% First 15 values preserve the V1.4 layout. Values 16:45 are V1.5-only
% covariance diagnostics. Matrices use MATLAB column-major order.
y = zeros(45, 1);
y(1:2) = xNew;
y(3:4) = [pNew(1, 1); pNew(2, 2)];
y(5) = info.NIS;
y(6:9) = info.Fy;
y(10:13) = info.alpha;
y(14:15) = info.innovation;
y(16:17) = info.x_pred;
y(18:21) = info.F(:);
y(22:25) = info.H(:);
y(26:29) = info.P_prior(:);
y(30:33) = info.P_noQ(:);
y(34:37) = info.P_pred(:);
y(38:41) = info.S(:);
y(42:45) = info.K(:);
end
