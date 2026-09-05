function [xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step( ...
    xPrev, PPrev, z, R, Q, measurementValid, p)
%LOCAL_SCALAR_KF_STEP Scalar prediction/update step for Stage-2 local filters.
%
%   [xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step( ...
%       xPrev, PPrev, z, R, Q, measurementValid, p)
%
%   Stage-2 formulas (A = 1, H = 1):
%     xMinus = xPrev
%     PMinus = PPrev + Q
%     K      = PMinus / (PMinus + R)
%     xPlus  = xMinus + K * (z - xMinus)
%     PPlus  = (1 - K) * PMinus
%
%   The function is intentionally scalar/pure and does not keep state.
%   If measurementValid is false, or if R/z are invalid/non-positive, the
%   measurement update is skipped (prediction-only behavior).

if nargin < 6
    error('local_scalar_kf_step:InvalidInputCount', ...
        'Expected at least 6 inputs: xPrev, PPrev, z, R, Q, measurementValid.');
end
if nargin < 7
    p = struct();
end

epsDen = 1e-12;
if isstruct(p) && isfield(p, 'denomEps') && isfinite(p.denomEps) && p.denomEps > 0
    epsDen = p.denomEps;
end

% Default outputs and finite guard.
xMinus = xPrev;
if ~isfinite(xMinus)
    xMinus = 0;
end

PMinus = PPrev;
if ~isfinite(PMinus) || PMinus < 0
    PMinus = 0;
end

if ~isfinite(Q) || Q < 0
    Q = 0;
end

PMinus = PMinus + Q;
if ~isfinite(PMinus) || PMinus < 0
    PMinus = 0;
end

xPlus = xMinus;
PPlus = PMinus;
K = 0;

% Stage-2 local KF measurement-availability gate.
if ~logical(measurementValid)
    return;
end

% Reject invalid measurement variance or sample.
if ~isfinite(R) || ~isfinite(z) || R <= 0
    return;
end

if ~isfinite(PMinus) || PMinus < 0
    PMinus = 0;
    PPlus = PMinus;
    return;
end

den = PMinus + R;
if ~isfinite(den) || den <= epsDen
    K = 0;
    PPlus = PMinus;
    return;
end

K = PMinus / den;
if ~isfinite(K) || K < 0
    K = 0;
    PPlus = PMinus;
    return;
end

if K > 1
    K = 1;
end

xPlus = xMinus + K * (z - xMinus);
if ~isfinite(xPlus)
    xPlus = xMinus;
end

PPlus = (1 - K) * PMinus;
if PPlus < 0
    PPlus = 0;
end

if ~isfinite(PPlus)
    % Keep conservative but finite.
    PPlus = max(PMinus, 0);
end
end
