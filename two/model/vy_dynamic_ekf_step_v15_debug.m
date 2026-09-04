function [x_new, P_new, info] = vy_dynamic_ekf_step_v15_debug(x, P, u, z, par, cfg)
%VY_DYNAMIC_EKF_STEP_V15_DEBUG Diagnostic-only copy for V1.5 audit.
%
% The mathematical operations are intentionally identical to the formal
% vy_dynamic_ekf_step implementation. Only additional diagnostic fields
% are retained in info for covariance-budget analysis.
%
% [x_new, P_new, diag] = vy_dynamic_ekf_step(x, P, u, z, par, cfg)
%
% State:
%   x = [vy; r]
% Input:
%   u = [vx_hat; Steer_FL; Steer_FR; Steer_RL; Steer_RR]
% Measurement:
%   z = [Ay; AVz]
%
% Outputs:
%   x_new  - updated state
%   P_new  - updated covariance (Joseph form)
%   diag   - diagnostics struct:
%            innovation, S, K, NIS, alpha_*, Fy_*, Fx_*

narginchk(6, 6);

% ------------------------------------------------------------------
% Input sanitizing and defaults

x = safe_vector2(x, [0; 0]);
if isempty(P)
    P = eye(2);
end
P = safe_posdef2(P);
P_prior = P;

u = safe_vector5(u, zeros(5, 1));
z = safe_vector2(z, [0; 0]);

vx_hat = u(1);
deltaFL = u(2);
deltaFR = u(3);
deltaRL = u(4);
deltaRR = u(5);

m = safe_scalar_field(par, 'm', 1860);
Iz = safe_scalar_field(par, 'Iz', 2687.1);
a = safe_scalar_field(par, 'a', 1.18);
b = safe_scalar_field(par, 'b', 1.77);
track = safe_scalar_field(par, 'track', 1.575);

dt = safe_scalar_field(cfg, 'dt', 0.01);
if dt <= 0
    dt = safe_scalar_field(cfg, 'Ts', safe_scalar_field(cfg, 'Ts_est', 0.01));
end
if ~isfinite(dt) || dt <= 0
    dt = 0.01;
end

Q = safe_matrix2(cfg, 'Q', 1e-6 * eye(2));
R = safe_matrix2(cfg, 'R', diag([1e-2; 1e-2]));

epsDiff = safe_scalar_field(cfg, 'epsDiff', sqrt(eps));
if epsDiff <= 0 || ~isfinite(epsDiff)
    epsDiff = sqrt(eps);
end

denomEps = safe_scalar_field(cfg, 'denomEps', 1e-12);

lambda = safe_vector4_field(cfg, 'lambda', [0; 0; 0; 0]);

if isstruct(par) && isfield(par, 'fz') && numel(par.fz) >= 4
    fz = par.fz(:);
    fz = reshape(fz(1:4), [4, 1]);
else
    g = 9.81;
    fzFrontVehicle = m * g * b / max(a + b, eps);
    fzRearVehicle = m * g * a / max(a + b, eps);
    fz = [fzFrontVehicle; fzFrontVehicle; fzRearVehicle; fzRearVehicle] / 2;
end

% ------------------------------------------------------------------
% Dynamics and EKF prediction

% Nominal prediction at x.
[f, ~, ~, ~] = vy_dynamics(x, vx_hat, deltaFL, deltaFR, deltaRL, deltaRR, ...
    m, Iz, a, b, track, fz, lambda);
x_pred = x + dt * f;
if any(~isfinite(x_pred))
    x_pred = x;
end

g_fun = @(xLocal) discrete_transition(xLocal, vx_hat, deltaFL, deltaFR, deltaRL, deltaRR, ...
    m, Iz, a, b, track, fz, lambda, dt);
F = numeric_jacobian(g_fun, x, epsDiff);

P_noQ = F * P_prior * F';
P_pred = P_noQ + Q;
P_pred = enforce_psd(P_pred);

% ------------------------------------------------------------------
% Measurement model at prediction and Jacobian

[h_pred, alpha_m, Fy_m, Fx_m] = vy_measurement(x_pred, vx_hat, ...
    deltaFL, deltaFR, deltaRL, deltaRR, m, a, b, track, fz, lambda, cfg);

h_fun = @(xLocal) vy_measurement(xLocal, vx_hat, ...
    deltaFL, deltaFR, deltaRL, deltaRR, m, a, b, track, fz, lambda, cfg);
H = numeric_jacobian(h_fun, x_pred, epsDiff);

% ------------------------------------------------------------------
% EKF measurement update

innovation = z - h_pred;
K = zeros(2);
S = H * P_pred * H' + R;
S = 0.5 * (S + S');
P_new = P_pred;
NIS = 0;

validMeas = all(isfinite(innovation)) && all(isfinite(S(:))) && isfinite_det2(S, denomEps);

if validMeas
    % Joseph update for numerical stability
    try
        S_inv = inv(S);
        K = (P_pred * H') * S_inv;
        x_new = x_pred + K * innovation;
        I = eye(2);
        P_new = (I - K * H) * P_pred * (I - K * H)' + K * R * K';
        P_new = enforce_psd(P_new);
        NIS = innovation' * S_inv * innovation;
        if ~isfinite(NIS)
            NIS = 0;
        end
    catch
        x_new = x_pred;
        P_new = P_pred;
        K = zeros(2);
        NIS = 0;
    end
else
    x_new = x_pred;
end

if any(~isfinite(x_new))
    x_new = x_pred;
end

if any(~isfinite(P_new(:)))
    P_new = P_pred;
end

% Diagnostics (use nominal slip/forces returned from x_pred for readability)
info = struct();
info.innovation = innovation;
info.x_pred = x_pred;
info.F = F;
info.H = H;
info.P_prior = P_prior;
info.P_noQ = P_noQ;
info.P_pred = P_pred;
info.S = S;
info.K = K;
info.NIS = NIS;

info.alpha_FL = alpha_m(1);
info.alpha_FR = alpha_m(2);
info.alpha_RL = alpha_m(3);
info.alpha_RR = alpha_m(4);

info.Fy_FL = Fy_m(1);
info.Fy_FR = Fy_m(2);
info.Fy_RL = Fy_m(3);
info.Fy_RR = Fy_m(4);

info.Fx_FL = Fx_m(1);
info.Fx_FR = Fx_m(2);
info.Fx_RL = Fx_m(3);
info.Fx_RR = Fx_m(4);

info.alpha = [alpha_m(1); alpha_m(2); alpha_m(3); alpha_m(4)];
info.Fy = [Fy_m(1); Fy_m(2); Fy_m(3); Fy_m(4)];
info.Fx = [Fx_m(1); Fx_m(2); Fx_m(3); Fx_m(4)];

end


% ========================================================================
% Local helpers

function y = safe_vector2(v, defaultVal)
    if isempty(v)
        y = defaultVal(:);
        return;
    end
    v = v(:);
    if numel(v) < 2
        y = defaultVal(:);
        return;
    end
    y = v(1:2);
    y(~isfinite(y)) = 0;
end


function y = safe_vector4_field(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName)
        v = s.(fieldName);
    else
        v = defaultVal;
    end
    v = v(:);
    if numel(v) < 4
        y = defaultVal(:);
    else
        y = v(1:4);
    end
    y(~isfinite(y)) = 0;
end


function y = safe_vector5(v, defaultVal)
    if isempty(v)
        y = defaultVal(:);
        return;
    end
    v = v(:);
    if numel(v) < 5
        y = defaultVal(:);
        return;
    end
    y = v(1:5);
    y(~isfinite(y)) = 0;
end


function val = safe_scalar_field(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName)
        val = s.(fieldName);
        if isfinite(val)
            return;
        end
    end
    val = defaultVal;
end


function M = safe_matrix2(s, fieldName, defaultVal)
    if isstruct(s) && isfield(s, fieldName)
        M = s.(fieldName);
    else
        M = defaultVal;
    end

    if isscalar(M)
        M = abs(M) * eye(2);
    else
        M = M(1:2, 1:2);
    end

    if any(size(M) ~= [2, 2]) || any(~isfinite(M(:)))
        M = defaultVal;
    end

    M = 0.5 * (M + M');
    M = max(M, 0);
    if any(diag(M) <= 0)
        M(logical(eye(2))) = max(diag(M), 1e-12);
    end
end


function P = safe_posdef2(P)
    if isempty(P)
        P = eye(2);
        return;
    end
    P = P(1:2, 1:2);
    if any(~isfinite(P(:)))
        P = eye(2);
        return;
    end
    P = 0.5 * (P + P');
    if abs(det(P)) < 1e-16
        P = P + 1e-9 * eye(2);
    end
    [V, D] = eig(P);
    d = max(0, real(diag(D)));
    if all(d >= 0)
        P = V * diag(d) * V';
    else
        P = eye(2);
    end
    P = 0.5 * (P + P');
end


function P = enforce_psd(P)
    if any(~isfinite(P(:)))
        P = eye(2);
    end
    P = 0.5 * (P + P');
    [V, D] = eig(P);
    d = real(diag(D));
    d(d < 0) = 0;
    P = V * diag(d) * V';
    P = 0.5 * (P + P');
end


function [f, alpha, Fy, Fx] = vy_dynamics(x, vx_hat, dFL, dFR, dRL, dRR, ...
    m, Iz, a, b, track, fz, lambda)

    [alpha, Fy, Fx] = side_forces(x, vx_hat, dFL, dFR, dRL, dRR, a, b, track, fz, lambda);

    vyDot = (Fy(1) * cos(dFL) + Fy(2) * cos(dFR) + Fy(3) + Fy(4)) / m - vx_hat * x(2);
    rDot = (a * (Fy(1) * cos(dFL) + Fy(2) * cos(dFR)) - b * (Fy(3) + Fy(4))) / Iz;

    f = [vyDot; rDot];

    if ~all(isfinite(f))
        f = [0; 0];
    end

end


function g = discrete_transition(x, vx_hat, dFL, dFR, dRL, dRR, ...
    m, Iz, a, b, track, fz, lambda, dt)
    [f, ~, ~, ~] = vy_dynamics(x, vx_hat, dFL, dFR, dRL, dRR, m, Iz, a, b, track, fz, lambda);
    g = x + dt * f;
    if any(~isfinite(g))
        g = x;
    end
end


function [h, alpha, Fy, Fx] = vy_measurement(x, vx_hat, dFL, dFR, dRL, dRR, m, a, b, track, fz, lambda, cfg)
    [alpha, Fy, Fx] = side_forces(x, vx_hat, dFL, dFR, dRL, dRR, a, b, track, fz, lambda);

    h1 = (Fy(1) * cos(dFL) + Fy(2) * cos(dFR) + Fy(3) + Fy(4)) / m;
    h2 = x(2);
    h = [h1; h2];

    if ~all(isfinite(h))
        h = [0; 0];
    end

end


function J = numeric_jacobian(fun, x0, epsDiff)
    f0 = fun(x0);
    nx = numel(x0);
    ny = numel(f0);
    J = zeros(ny, nx);
    for i = 1:nx
        step = epsDiff * max(1, abs(x0(i)));
        if step == 0 || ~isfinite(step)
            step = epsDiff;
        end

        xp = x0;
        xm = x0;
        xp(i) = xp(i) + step;
        xm(i) = xm(i) - step;

        fp = fun(xp);
        fm = fun(xm);

        if any(~isfinite(fp)) || any(~isfinite(fm))
            J(:, i) = 0;
        else
            J(:, i) = (fp - fm) / (2 * step);
        end
    end
end


function ok = isfinite_det2(M, epsDet)
    ok = all(isfinite(M(:))) && all(isfinite(eig(M))) && (det(M) > epsDet);
end


function [alpha, Fy, Fx] = side_forces(x, vx_hat, dFL, dFR, dRL, dRR, a, b, track, fz, lambda)

    vx = vx_hat;
    r = x(2);
    vy = x(1);

    alpha = zeros(4, 1);
    Fy = zeros(4, 1);
    Fx = zeros(4, 1);

    denomFL = vx - r * track / 2;
    denomFR = vx + r * track / 2;
    denomRL = vx - r * track / 2;
    denomRR = vx + r * track / 2;

    alpha(1) = dFL - atan2(vy + a * r, denomFL);
    alpha(2) = dFR - atan2(vy + a * r, denomFR);
    alpha(3) = dRL - atan2(vy - b * r, denomRL);
    alpha(4) = dRR - atan2(vy - b * r, denomRR);

    if any(~isfinite(alpha))
        alpha = zeros(4, 1);
    end

    for i = 1:4
        fzWheel = fz(i);
        lambdaWheel = lambda(i);
        isFront = (i <= 2);
        [Fy(i), Fx(i)] = call_tire_force(alpha(i), lambdaWheel, fzWheel, isFront);
    end

    Fy(~isfinite(Fy)) = 0;
    Fx(~isfinite(Fx)) = 0;
    Fy = real(Fy);
    Fx = real(Fx);
end


function [Fy, Fx] = call_tire_force(alpha, lambda, fz, isFront)
    if ~isfinite(fz)
        fz = 1;
    end

    if ~isfinite(alpha)
        alpha = 0;
    end

    if ~isfinite(lambda)
        lambda = 0;
    end

    hasFunc = exist('tireForceLocal', 'file') == 2;
    if hasFunc
        try
            [Fy, Fx] = tireForceLocal(alpha, lambda, fz, isFront);
            if isfinite(Fy) && isfinite(Fx)
                return;
            end
        catch
        end
    end

    % Fallback local tire model if external model is not available.
    Calpha = 4e4;
    if isFront
        Calpha = 4.2e4;
    else
        Calpha = 4.8e4;
    end

    Fy = -Calpha * alpha * min(max(fz, 1), 1e4) / 1000;
    Fx = 0;
end
