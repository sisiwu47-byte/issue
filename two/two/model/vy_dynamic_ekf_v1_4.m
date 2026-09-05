function y = vy_dynamic_ekf_v1_4(w, R_Ay_v14, R_r_v14)
%VY_DYNAMIC_EKF_V1_4 Dedicated wrapper for the controlled V1.4 R sweep.
%
% Only the two diagonal measurement-covariance entries are supplied by the
% model workspace. The core EKF, Q, vehicle parameters, tire model, state
% equation, measurement equation, and diagnostics are unchanged from V1.3.

persistent x P

if isempty(x)
    x = [0; 0];
end
if isempty(P)
    P = eye(2) * 0.1;
end

assert(isscalar(R_Ay_v14) && isfinite(R_Ay_v14) && R_Ay_v14 > 0, ...
    'R_Ay_v14 must be a finite positive scalar.');
assert(isscalar(R_r_v14) && isfinite(R_r_v14) && R_r_v14 > 0, ...
    'R_r_v14 must be a finite positive scalar.');

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
cfg.R = diag([R_Ay_v14, R_r_v14]);
cfg.denomEps = 1e-12;
cfg.lambda = zeros(4, 1);

[xNew, pNew, info] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);
x = xNew;
P = pNew;

y = zeros(15, 1);
y(1:2) = xNew;
y(3) = pNew(1, 1);
y(4) = pNew(2, 2);
y(5) = info.NIS;
y(6:9) = info.Fy;
y(10:13) = info.alpha;
y(14:15) = info.innovation;
end
