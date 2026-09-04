function [rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping(eSlip, residualValid, validGeom, p, eAbs)
%SLIP_CONFIDENCE_MAPPING Compute WSS confidence with optional absolute criterion.
%   [rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
%   slip_confidence_mapping(eSlip, residualValid, validGeom, p, eAbs)
%
%   Output mapping:
%     - rhoDelta from eSlip via e_low/e_high linear segments.
%     - rhoAbs   from eAbs  via eAbs_low/eAbs_high linear segments (optional).
%     - rhoRaw   = min(rhoDelta, rhoAbs).
%     - Rwheel   derived from rhoRaw.
%     - validWheel: rhoRaw > rho_hard and residual/geometry validity.
%
%   If 4 inputs are used, rhoRaw = rhoDelta to preserve legacy behavior.

if nargin < 4 || nargin > 5
    error('slip_confidence_mapping:InvalidInputCount', ...
          'Expected 4 or 5 input arguments.');
end

if ~isstruct(p)
    error('slip_confidence_mapping:InvalidParams', 'p must be a struct.');
end

if nargin == 4
    useAbs = false;
else
    useAbs = true;
end

requiredFields = {'e_low', 'e_high', 'rho_hard', 'R0', 'R_min', 'R_max', 'epsilon'};
if useAbs
    requiredFields(end + (1:2)) = {'eAbs_low', 'eAbs_high'};
end
if ~all(isfield(p, requiredFields))
    error('slip_confidence_mapping:MissingParams', ...
          'p must contain e_low, e_high, rho_hard, R0, R_min, R_max, epsilon.');
end

e_low = p.e_low;
e_high = p.e_high;
rho_hard = p.rho_hard;
R0 = p.R0;
R_min = p.R_min;
R_max = p.R_max;
epsParam = p.epsilon;

if useAbs
    eAbs_low = p.eAbs_low;
    eAbs_high = p.eAbs_high;
end

if nargin == 5
    eAbs = eAbs(:);
end

if ~(isscalar(e_low) && isfinite(e_low) && isscalar(e_high) && ...
        isfinite(e_high) && e_high > e_low)
    error('slip_confidence_mapping:InvalidSlipThreshold', ...
          'p.e_low and p.e_high must be finite scalars with e_high > e_low.');
end

if useAbs
    if ~(isscalar(eAbs_low) && isfinite(eAbs_low) && ...
            isscalar(eAbs_high) && isfinite(eAbs_high) && ...
            eAbs_high > eAbs_low)
        error('slip_confidence_mapping:InvalidAbsThreshold', ...
              'p.eAbs_low and p.eAbs_high must be finite scalars with eAbs_high > eAbs_low.');
    end
end

if ~(isscalar(rho_hard) && isfinite(rho_hard) && rho_hard >= 0 && rho_hard <= 1)
    error('slip_confidence_mapping:InvalidRhoHard', ...
          'p.rho_hard must be a finite scalar in [0, 1].');
end

if ~(isscalar(R0) || (isvector(R0) && numel(R0) == 4))
    error('slip_confidence_mapping:InvalidR0', ...
          'p.R0 must be a scalar or 4x1 vector.');
end
if any(~isfinite(R0)) || any(R0 <= 0)
    error('slip_confidence_mapping:InvalidR0', ...
          'p.R0 must be finite and > 0.');
end

if ~(isscalar(R_min) && isfinite(R_min) && R_min > 0)
    error('slip_confidence_mapping:InvalidRMin', ...
          'p.R_min must be finite and > 0.');
end
if ~(isscalar(R_max) && isfinite(R_max) && R_max >= R_min)
    error('slip_confidence_mapping:InvalidRMax', ...
          'p.R_max must be finite and >= p.R_min.');
end
if ~(isscalar(epsParam) && isfinite(epsParam) && epsParam > 0)
    error('slip_confidence_mapping:InvalidEpsilon', ...
          'p.epsilon must be a finite scalar > 0.');
end

eSlip = eSlip(:);
residualValid = logical(residualValid(:));
validGeom = logical(validGeom(:));
if nargin == 5
    eAbs = eAbs(:);
end

if numel(eSlip) ~= 4 || numel(residualValid) ~= 4 || numel(validGeom) ~= 4 ...
        || (nargin == 5 && numel(eAbs) ~= 4)
    error('slip_confidence_mapping:InvalidWheelSize', ...
          'eSlip, residualValid, validGeom must be 4x1 vectors in order [FL, FR, RL, RR].');
end

rhoRaw = zeros(4, 1);
rhoDelta = zeros(4, 1);
rhoAbs = ones(4, 1);
Rwheel = ones(4, 1) * R_max;
validWheel = false(4, 1);

if isscalar(R0)
    R0 = repmat(R0, 4, 1);
else
    R0 = R0(:);
end

for i = 1:4
    if residualValid(i) && validGeom(i) && isfinite(eSlip(i))
        if eSlip(i) <= e_low
            rhoDelta_i = 1;
        elseif eSlip(i) < e_high
            rhoDelta_i = (e_high - eSlip(i)) / (e_high - e_low);
        else
            rhoDelta_i = 0;
        end
        rhoDelta_i = min(max(rhoDelta_i, 0), 1);
        rhoDelta(i) = rhoDelta_i;
    end

    if useAbs
        if isfinite(eAbs(i))
            if eAbs(i) <= eAbs_low
                rhoAbs_i = 1;
            elseif eAbs(i) < eAbs_high
                rhoAbs_i = (eAbs_high - eAbs(i)) / (eAbs_high - eAbs_low);
            else
                rhoAbs_i = 0;
            end
            rhoAbs_i = min(max(rhoAbs_i, 0), 1);
            rhoAbs(i) = rhoAbs_i;
        else
            rhoAbs(i) = 0;
        end
    end

    rhoRaw_i = min(rhoDelta(i), rhoAbs(i));
    rhoRaw(i) = rhoRaw_i;

    R_i = R0(i) / (rhoRaw_i + epsParam);
    if ~isfinite(R_i) || R_i < R_min
        R_i = R_min;
    elseif R_i > R_max
        R_i = R_max;
    end
    Rwheel(i) = R_i;

    if rhoRaw_i > rho_hard && residualValid(i) && validGeom(i)
        validWheel(i) = true;
    end
end

% Guard against unexpected NaN/Inf propagation.
if ~all(isfinite(Rwheel)) || any(~isfinite(R0))
    Rwheel(~isfinite(Rwheel)) = R_max;
end

end
