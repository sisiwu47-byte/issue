function y = vy_dynamic_ekf_v1_3(w)
%VY_DYNAMIC_EKF_V1_3 V1.3 diagnostic-only wrapper for the D-EKF.
%
% Inputs and estimator configuration are identical to vy_dynamic_ekf.m.
% The only change is two additional diagnostic outputs containing the
% measurement innovation. The core EKF, Q, R, vehicle parameters, tire
% model, state equation, and measurement equation are unchanged.
%
% w(1:5) = [Vx; Steer_FL; Steer_FR; Steer_RL; Steer_RR]
% w(6:7) = [Ay_IMU; AVz_IMU]
%
% y(1:2)   = [Vy_hat; r_hat]
% y(3:4)   = [P11; P22]
% y(5:13)  = [NIS; Fy_FL; Fy_FR; Fy_RL; Fy_RR; ...
%             alpha_FL; alpha_FR; alpha_RL; alpha_RR]
% y(14:15) = [innovation_Ay; innovation_r]

persistent x P

if isempty(x)
    x = [0; 0];
end
if isempty(P)
    P = eye(2) * 0.1;
end

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
cfg.R = diag([1e-2, 1e-2]);
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
