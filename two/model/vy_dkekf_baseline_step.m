function [x_new, P_new, info] = vy_dkekf_baseline_step( ...
    x, P, Ax_IMU, steering, z_Vx, z_r, z_Ay, doAyUpdate, Ts, par, cfg)
%VY_DKEKF_BASELINE_STEP Unified three-state dynamic-kinematic EKF step.
%
% State ordering: x = [Vx; Vy; r].
% Prediction input: Ax_IMU and four road-wheel steering angles [rad].
% Measurements: z_Vx [m/s], z_r [rad/s], z_Ay [m/s^2].
% Update order: prediction, Vx, yaw rate, then optional Ay.
%
% The lateral force, Vy-dot, r-dot, and Ay equations preserve the frozen
% D-EKF V1.17 operation order. Vx is always x(1) inside those equations.

narginchk(11, 11);
x = x(:);
steering = steering(:);
assert(numel(x) == 3 && all(isfinite(x)), ...
    'x must be finite [Vx; Vy; r].');
assert(isequal(size(P), [3 3]) && all(isfinite(P(:))), ...
    'P must be a finite 3x3 matrix.');
assert(isscalar(Ax_IMU) && isfinite(Ax_IMU), ...
    'Ax_IMU must be finite and scalar.');
assert(numel(steering) == 4 && all(isfinite(steering)), ...
    'steering must contain finite [FL; FR; RL; RR] angles in rad.');
assert(isscalar(z_Vx) && isscalar(z_r) && isscalar(z_Ay) && ...
    all(isfinite([z_Vx; z_r; z_Ay])), ...
    'Measurements must be finite scalars.');
assert(isscalar(doAyUpdate) && ...
    (islogical(doAyUpdate) || isfinite(doAyUpdate)), ...
    'doAyUpdate must be a finite scalar logical flag.');
assert(isscalar(Ts) && isfinite(Ts) && Ts > 0, ...
    'Ts must be positive and finite.');
validate_configuration(par, cfg);
doAyUpdate = logical(doAyUpdate);

P_prior = 0.5*(P + P.');
[f, dynamicsInfo] = dk_dynamics(x, Ax_IMU, steering, par, cfg);
x_pred = x + Ts*f;

A = dynamics_jacobian(x, Ax_IMU, steering, par, cfg);
F = eye(3) + Ts*A;
P_pred = F*P_prior*F.' + cfg.Q_DK;
P_pred = 0.5*(P_pred + P_pred.');

[hAyInput, H_Ay_input] = ay_value_and_jacobian(x, steering, par, cfg);
[hAyPred, H_Ay_pred] = ay_value_and_jacobian(x_pred, steering, par, cfg);

H_Vx = [1 0 0];
[x_vx, P_vx, vxInfo] = scalar_joseph_update( ...
    x_pred, P_pred, z_Vx, x_pred(1), H_Vx, cfg.R_Vx, cfg.denomEps);

H_r = [0 0 1];
[x_r, P_r, rInfo] = scalar_joseph_update( ...
    x_vx, P_vx, z_r, x_vx(3), H_r, cfg.R_r, cfg.denomEps);

[hAy, H_Ay] = ay_value_and_jacobian(x_r, steering, par, cfg);
if doAyUpdate
    [x_new, P_new, ayInfo] = scalar_joseph_update( ...
        x_r, P_r, z_Ay, hAy, H_Ay, cfg.R_Ay, cfg.denomEps);
    ayInfo.updateApplied = true;
else
    x_new = x_r;
    P_new = P_r;
    ayInfo = skipped_measurement_info( ...
        x_r, P_r, z_Ay, hAy, H_Ay, cfg.R_Ay);
end

P_new = 0.5*(P_new + P_new.');

info = struct();
info.x_pred = x_pred;
info.P_prior = P_prior;
info.P_pred = P_pred;
info.f = f;
info.A = A;
info.F = F;
info.H_Vx = H_Vx;
info.H_r = H_r;
info.H_Ay = H_Ay;
info.H_Ay_input = H_Ay_input;
info.H_Ay_pred = H_Ay_pred;
info.h_Ay = hAy;
info.h_Ay_input = hAyInput;
info.h_Ay_pred = hAyPred;
info.Vx = vxInfo;
info.r = rInfo;
info.Ay = ayInfo;
info.alpha = dynamicsInfo.alpha;
info.Fy = dynamicsInfo.Fy;
info.Fy_raw = dynamicsInfo.Fy_raw;
info.Fx = dynamicsInfo.Fx;
info.frontFy = dynamicsInfo.frontFy;
info.rearFy = dynamicsInfo.rearFy;
info.lateralVxSource = 'state x(1)';
info.sharedStateDimension = 3;
info.sharedCovarianceDimension = [3 3];
end

function [f, out] = dk_dynamics(x, Ax_IMU, steering, par, cfg)
vx = x(1);
vy = x(2);
r = x(3);
[alpha, Fy, Fx, FyRaw] = frozen_forces(x, steering, par, cfg);
frontFy = Fy(1)*cos(steering(1)) + Fy(2)*cos(steering(2));
rearFy = Fy(3) + Fy(4);

% Frozen equations, with the former exogenous vx replaced by state x(1).
vxDot = Ax_IMU + r*vy;
vyDot = (Fy(1)*cos(steering(1)) + ...
    Fy(2)*cos(steering(2)) + Fy(3) + Fy(4))/par.m - vx*r;
rDot = (par.a*(Fy(1)*cos(steering(1)) + ...
    Fy(2)*cos(steering(2))) - par.b*(Fy(3) + Fy(4)))/par.Iz;
f = [vxDot; vyDot; rDot];
assert(all(isfinite(f)), 'Non-finite DK-EKF prediction.');

out = struct('alpha', alpha, 'Fy', Fy, 'Fx', Fx, ...
    'Fy_raw', FyRaw, 'frontFy', frontFy, 'rearFy', rearFy);
end

function A = dynamics_jacobian(x, Ax_IMU, steering, par, cfg)
% The first row is analytic. The two frozen nonlinear tire-force rows use
% centered finite differences with respect to all three shared states.
A = zeros(3);
A(1,:) = [0, x(3), x(2)];
for j = 1:3
    step = cfg.jacobianStep*max(1, abs(x(j)));
    xp = x;
    xm = x;
    xp(j) = xp(j) + step;
    xm(j) = xm(j) - step;
    fp = dk_dynamics(xp, Ax_IMU, steering, par, cfg);
    fm = dk_dynamics(xm, Ax_IMU, steering, par, cfg);
    A(2:3,j) = (fp(2:3) - fm(2:3))/(2*step);
end
end

function [hAy, H] = ay_value_and_jacobian(x, steering, par, cfg)
hAy = frozen_ay_measurement(x, steering, par, cfg);
H = zeros(1,3);
for j = 1:3
    step = cfg.jacobianStep*max(1, abs(x(j)));
    xp = x;
    xm = x;
    xp(j) = xp(j) + step;
    xm(j) = xm(j) - step;
    hp = frozen_ay_measurement(xp, steering, par, cfg);
    hm = frozen_ay_measurement(xm, steering, par, cfg);
    H(j) = (hp - hm)/(2*step);
end
end

function hAy = frozen_ay_measurement(x, steering, par, cfg)
[~, Fy] = frozen_forces(x, steering, par, cfg);
hAy = (Fy(1)*cos(steering(1)) + ...
    Fy(2)*cos(steering(2)) + Fy(3) + Fy(4))/par.m;
assert(isfinite(hAy), 'Non-finite Ay prediction.');
end

function [alpha, Fy, Fx, FyRaw] = frozen_forces(x, steering, par, cfg)
vx = x(1);
vy = x(2);
r = x(3);
den = [vx-r*par.track/2; vx+r*par.track/2; ...
    vx-r*par.track/2; vx+r*par.track/2];
alpha = [steering(1)-atan2(vy+par.a*r, den(1)); ...
    steering(2)-atan2(vy+par.a*r, den(2)); ...
    steering(3)-atan2(vy-par.b*r, den(3)); ...
    steering(4)-atan2(vy-par.b*r, den(4))];

if isfield(par, 'fz') && numel(par.fz) >= 4
    fz = par.fz(:);
    fz = fz(1:4);
else
    g = 9.81;
    ff = par.m*g*par.b/max(par.a+par.b, eps);
    fr = par.m*g*par.a/max(par.a+par.b, eps);
    fz = [ff; ff; fr; fr]/2;
end

FyRaw = zeros(4,1);
Fx = zeros(4,1);
for i = 1:4
    [FyRaw(i), Fx(i)] = tire_call( ...
        alpha(i), cfg.lambda(i), fz(i), i <= 2);
end
Fy = FyRaw.*[par.k_f; par.k_f; par.k_r; par.k_r];
assert(all(isfinite([alpha; Fy; Fx; FyRaw])), ...
    'Non-finite frozen tire-force calculation.');
end

function [Fy, Fx] = tire_call(alpha, lambda, fz, isFront)
if exist('tireForceLocal', 'file') == 2
    [Fy, Fx] = tireForceLocal(alpha, lambda, fz, isFront);
    if isfinite(Fy) && isfinite(Fx)
        return
    end
end
if isFront
    C = 4.2e4;
else
    C = 4.8e4;
end
Fy = -C*alpha*min(max(fz,1),1e4)/1000;
Fx = 0;
end

function [xPost, PPost, out] = scalar_joseph_update( ...
    xPrior, PPrior, z, h, H, R, denomEps)
innovation = z - h;
S = H*PPrior*H.' + R;
assert(isfinite(S) && S > denomEps, ...
    'Scalar innovation covariance must be positive and finite.');
K = (PPrior*H.')/S;
xPost = xPrior + K*innovation;
I_KH = eye(3) - K*H;
PPost = I_KH*PPrior*I_KH.' + K*R*K.';
PPost = 0.5*(PPost + PPost.');

out = struct('innovation', innovation, 'S', S, 'K', K, ...
    'NIS', innovation^2/S, 'H', H, 'h', h, ...
    'x_prior', xPrior, 'P_prior', PPrior, ...
    'x_post', xPost, 'P_post', PPost, 'updateApplied', true);
end

function out = skipped_measurement_info(xPrior, PPrior, z, h, H, R)
S = H*PPrior*H.' + R;
out = struct('innovation', z-h, 'S', S, 'K', zeros(3,1), ...
    'NIS', NaN, 'H', H, 'h', h, ...
    'x_prior', xPrior, 'P_prior', PPrior, ...
    'x_post', xPrior, 'P_post', PPrior, 'updateApplied', false);
end

function validate_configuration(par, cfg)
requiredPar = {'m','Iz','a','b','track','k_f','k_r'};
for i = 1:numel(requiredPar)
    name = requiredPar{i};
    assert(isfield(par, name) && isscalar(par.(name)) && ...
        isfinite(par.(name)), 'Missing or invalid vehicle parameter: %s.', name);
end
assert(par.m > 0 && par.Iz > 0 && par.k_f > 0 && par.k_r > 0, ...
    'Mass, inertia, and axle force gains must be positive.');
requiredCfg = {'Q_DK','R_Vx','R_r','R_Ay','jacobianStep', ...
    'denomEps','lambda'};
for i = 1:numel(requiredCfg)
    assert(isfield(cfg, requiredCfg{i}), ...
        'Missing DK-EKF configuration field: %s.', requiredCfg{i});
end
assert(isequal(size(cfg.Q_DK), [3 3]) && all(isfinite(cfg.Q_DK(:))), ...
    'cfg.Q_DK must be finite 3x3.');
assert(all([cfg.R_Vx cfg.R_r cfg.R_Ay cfg.jacobianStep cfg.denomEps] > 0) && ...
    all(isfinite([cfg.R_Vx cfg.R_r cfg.R_Ay cfg.jacobianStep cfg.denomEps])), ...
    'Measurement variances and numerical thresholds must be positive.');
assert(numel(cfg.lambda) == 4 && all(isfinite(cfg.lambda(:))), ...
    'cfg.lambda must contain four finite wheel slip ratios.');
end
