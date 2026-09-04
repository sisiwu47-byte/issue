function y = vy_dynamic_ekf_v1_7(w, Ay_bias_v17, AVz_bias_v17)
%VY_DYNAMIC_EKF_V1_7 Oracle IMU-bias ablation wrapper.
% THIS IS AN ORACLE BIAS-REMOVAL ABLATION, NOT THE FINAL ONLINE ESTIMATOR.
% Bias subtraction is applied only between the raw virtual-IMU output and
% the unchanged D-EKF core. Q and R are fixed at the V1.6 Case 3 point.

persistent x P
if isempty(x), x = [0; 0]; end
if isempty(P), P = eye(2) * 0.1; end
assert(isscalar(Ay_bias_v17) && isfinite(Ay_bias_v17));
assert(isscalar(AVz_bias_v17) && isfinite(AVz_bias_v17));

w = w(:);
u = w(1:5);
zRaw = w(6:7);
zCorrected = zRaw - [Ay_bias_v17; AVz_bias_v17];
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393);
cfg = struct('dt',0.01,'Q',diag([1e-4,1e-4]), ...
    'R',diag([1e-2,3.365172961808e-4]), ...
    'denomEps',1e-12,'lambda',zeros(4,1));

[xNew,pNew,info] = vy_dynamic_ekf_step_v15_debug( ...
    x,P,u,zCorrected,par,cfg);
x = xNew;
P = pNew;

% Values 1:49 retain the V1.6 layout. Values 50:51 append the corrected
% measurement [Ay_corrected; AVz_corrected] without altering raw IMU logs.
y = zeros(51,1);
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
y(50:51) = zCorrected;
end
