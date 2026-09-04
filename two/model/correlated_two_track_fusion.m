function [vxFused, Pfused, alphaW, alphaI, PWI_minus, PWI_plus, Phi, condPhi, fusionValid] = ...
    correlated_two_track_fusion(xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p)
%CORRELATED_TWO_TRACK_FUSION Correlated fusion stage for WSS and IMU local KFs.
%
%   Stage-2 frozen scalar formulas (A = 1, H = 1):
%     PWI_minus(k) = PWI_plus(k-1) + Q_WI_common
%     Q_WI_common = (QW + QI) / 2
%     PWI_plus(k) = (1-KW_k) * PWI_minus(k) * (1-KI_k)
%
%     Phi = [PW, PWI; PWI, PI]
%     den = Phi(1,1) + Phi(2,2) - 2*Phi(1,2)
%     alphaW = (Phi(2,2) - Phi(1,2)) / den
%     alphaI = (Phi(1,1) - Phi(1,2)) / den
%
%     vxFused = alphaW*xW + alphaI*xI
%     Pfused = alphaW^2*PW + 2*alphaW*alphaI*PWI + alphaI^2*PI
%
%   No state is stored in this function; PWI_prev is passed in from caller.

if nargin < 10
    p = struct();
end
if nargin < 9
    error('correlated_two_track_fusion:InvalidInputCount', ...
        'Expected 10 inputs: xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p.');
end

% Stage-2 constants (frozen in map)
epsDen = get_scalar_field(p, 'eps_den', 1e-12);
P_min = get_scalar_field(p, 'P_min', 1e-12);
Pfused_min = get_scalar_field(p, 'Pfused_min', 1e-12);
epsCross = get_scalar_field(p, 'pwi_epsilon', 1e-12);

if isfield(p, 'QW') && isfinite(p.QW) && isfield(p, 'QI') && isfinite(p.QI)
    Q_WI_common = (p.QW + p.QI) / 2;
else
    Q_WI_common = 0;
end
if ~isfinite(Q_WI_common) || Q_WI_common < 0
    Q_WI_common = 0;
end

% Defaults
vxFused = NaN;
Pfused = NaN;
alphaW = NaN;
alphaI = NaN;
PWI_minus = NaN;
PWI_plus = NaN;
Phi = [NaN NaN; NaN NaN];
condPhi = NaN;
fusionValid = false;

% Local filter outputs are expected to be scalar and finite from stage-2 KF.
PWn = finite_or_zero(PW);
PIn = finite_or_zero(PI);
xWn = xW;
xIn = xI;
if ~isfinite(KW); KWn = 0; else; KWn = KW; end
if ~isfinite(KI); KIn = 0; else; KIn = KI; end
PWI_prev_n = finite_or_zero(PWI_prev);

% Ensure local variances are non-negative and non-zero for numerical safety.
PWn = max(PWn, 0);
PIn = max(PIn, 0);

% 14.x PWI prediction and correction:
PWI_minus = PWI_prev_n + Q_WI_common;

if ~isfinite(PWI_minus)
    PWI_minus = 0;
end
PWI_plus = (1 - KWn) * PWI_minus * (1 - KIn);
if ~isfinite(PWI_plus)
    PWI_plus = 0;
end

% Prepare Phi blocks (current-step P+ after local updates).
phi11 = max(PWn, P_min);
phi22 = max(PIn, P_min);

% Cauchy-Schwarz physical bound: |PWI| <= sqrt(PW*PI).
crossLimit = sqrt(max(phi11 * phi22, 0) + epsCross);
if crossLimit > 0
    if abs(PWI_plus) > crossLimit
        PWI_plus = sign(PWI_plus) * crossLimit;
    end
else
    PWI_plus = 0;
end

Phi = [phi11, PWI_plus; PWI_plus, phi22];
condPhi = cond(Phi);

if ~isfinite(condPhi)
    condPhi = Inf;
end

% Channel-availability gating:
wssValid = logical(wssValid);
imuValid = logical(imuValid);

if wssValid && imuValid
    % Case 1: both channels valid, perform correlated fusion.
    den = phi11 + phi22 - 2 * PWI_plus;
    if ~isfinite(den) || den <= epsDen
        den = epsDen;
        condPhi = max(condPhi, 1/epsDen);
    end

    alphaW = (phi22 - PWI_plus) / den;
    alphaI = (phi11 - PWI_plus) / den;
    s = alphaW + alphaI;

    if isfinite(s) && abs(s) > epsDen
        alphaW = alphaW / s;
        alphaI = alphaI / s;
    else
        % Fallback for pathological numerical condition.
        alphaW = 1;
        alphaI = 0;
    end

    if all(isfinite([alphaW, alphaI, xWn, xIn]))
        vxFused = alphaW * xWn + alphaI * xIn;
        Pfused = alphaW^2 * phi11 + 2 * alphaW * alphaI * PWI_plus + alphaI^2 * phi22;
        if ~isfinite(Pfused)
            Pfused = Pfused_min;
        end
        if Pfused < Pfused_min
            Pfused = Pfused_min;
        end
        fusionValid = true;
    end
    return;
end

if ~wssValid && imuValid
    % Case 2: WSS invalid, IMU valid.
    vxFused = xIn;
    Pfused = phi22;
    alphaW = 0;
    alphaI = 1;
    if all(isfinite([vxFused, Pfused]))
        fusionValid = true;
    end
    return;
end

if wssValid && ~imuValid
    % Case 3: WSS valid, IMU invalid.
    vxFused = xWn;
    Pfused = phi11;
    alphaW = 1;
    alphaI = 0;
    if all(isfinite([vxFused, Pfused]))
        fusionValid = true;
    end
    return;
end

% Case 4: both invalid -> do not synthesize new estimate here.
vxFused = NaN;
Pfused = NaN;
fusionValid = false;
if isnan(alphaW)
    alphaW = 0;
end
if isnan(alphaI)
    alphaI = 0;
end

end


function v = finite_or_zero(x)
% return finite scalar fallback to 0
if isfinite(x)
    v = x;
else
    v = 0;
end
end


function v = get_scalar_field(p, name, default)
if isstruct(p) && isfield(p, name) && isfinite(p.(name))
    v = p.(name);
else
    v = default;
end
end
