function y = vy_dynamic_ekf_v1_6(w, Q_vy_v16, Q_r_v16)
%VY_DYNAMIC_EKF_V1_6 Diagnostic wrapper for controlled discrete-Q sweep.
%
% R is frozen to V1.4 Case 2. Only Q(1,1) and Q(2,2) are supplied as
% controlled sweep parameters. The formal EKF mathematics are unchanged.

persistent x P
if isempty(x), x = [0; 0]; end
if isempty(P), P = eye(2) * 0.1; end
assert(isscalar(Q_vy_v16) && isfinite(Q_vy_v16) && Q_vy_v16 > 0);
assert(isscalar(Q_r_v16) && isfinite(Q_r_v16) && Q_r_v16 > 0);

w = w(:);
u = w(1:5);
z = w(6:7);
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393);
cfg = struct('dt',0.01,'Q',diag([Q_vy_v16,Q_r_v16]), ...
    'R',diag([1e-2,3.365172961808e-4]), ...
    'denomEps',1e-12,'lambda',zeros(4,1));

[xNew,pNew,info] = vy_dynamic_ekf_step_v15_debug(x,P,u,z,par,cfg);
x = xNew;
P = pNew;

% Values 1:45 retain the V1.5 layout. Values 46:49 append complete P_new
% in MATLAB column-major order [P11;P21;P12;P22].
y = zeros(49,1);
y(1:2) = xNew;
y(3:4) = [pNew(1,1);pNew(2,2)];
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
y(46:49) = pNew(:);
end
