function [eSlip, DeltaVWheel, DeltaVImu, windowReady, slipReady, residualValid, imuLife, LifeSig_IMU, LifeSig_WSS] = ...
    window_delta_velocity_indicator(Ax, yawRate, vyPrior, vxWheel, validGeom, reset, p)
%WINDOW_DELTA_VELOCITY_INDICATOR Stage 3B finite-window IMU/WSS consistency chain.
%   Implements:
%   - axCorr(k) = Ax(k) + yawRate(k)*vyPrior(k)
%   - dvImuStep(k) = 0.5*Ts_est*(axCorr(k-1)+axCorr(k))
%   - DeltaVImu from FIFO-integrated IMU interval increments
%   - DeltaVWheel_i(k)=vxWheel_i(k)-vxWheel_i(k-Nwindow)
%   - eSlip_i = abs(DeltaVWheel_i - DeltaVImu)
%
%   Interface fixed as Stage 2 test-stage mapping.

if nargin ~= 7
    error('window_delta_velocity_indicator:InvalidInputCount', ...
          'Expected 7 input arguments.');
end

if ~isstruct(p)
    error('window_delta_velocity_indicator:InvalidParams', 'p must be a struct.');
end

requiredFields = {'Ts_est', 'Nwindow'};
if ~all(isfield(p, requiredFields))
    error('window_delta_velocity_indicator:MissingParams', ...
          'p must contain Ts_est and Nwindow.');
end

if ~(isscalar(p.Ts_est) && isfinite(p.Ts_est) && p.Ts_est > 0)
    error('window_delta_velocity_indicator:InvalidTs', 'p.Ts_est must be finite > 0.');
end

if ~(isscalar(p.Nwindow) && isfinite(p.Nwindow) && p.Nwindow == floor(p.Nwindow) && p.Nwindow > 0)
    error('window_delta_velocity_indicator:InvalidNwindow', ...
          'p.Nwindow must be a positive integer.');
end

if ~isnumeric(Ax) || ~isnumeric(yawRate) || ~isnumeric(vyPrior) || ...
        ~isnumeric(vxWheel) || ...
        ~(isnumeric(validGeom) || islogical(validGeom)) || ...
        ~(isnumeric(reset) || islogical(reset))
    error('window_delta_velocity_indicator:InvalidInputType', ...
          ['Ax/yawRate/vyPrior/vxWheel must be numeric; ', ...
           'validGeom/reset must be numeric or logical.']);
end

vxWheel = vxWheel(:);
validGeom = logical(validGeom(:));

if numel(vxWheel) ~= 4 || numel(validGeom) ~= 4
    error('window_delta_velocity_indicator:InvalidWheelSize', ...
          'vxWheel and validGeom must be 4x1 in order [FL, FR, RL, RR].');
end

if ~isscalar(Ax) || ~isscalar(yawRate) || ~isscalar(vyPrior) || ~isscalar(reset)
    error('window_delta_velocity_indicator:InvalidScalarInput', ...
          'Ax/yawRate/vyPrior/reset must be scalar.');
end

Nwindow = p.Nwindow;
Ts_est  = p.Ts_est;

persistent count
persistent totalCount
persistent dvImuFIFO
persistent vxWheelFIFO
persistent axCorrPrev
if isempty(count)
    count = 0;
    totalCount = 0;
    dvImuFIFO = NaN(1, Nwindow);
    vxWheelFIFO = NaN(4, Nwindow + 1);
    axCorrPrev = 0;
end

% Reset behavior follows Stage 2 freeze section.
if reset ~= 0
    count = 0;
    totalCount = 0;
    dvImuFIFO(:) = NaN;
    vxWheelFIFO(:) = NaN;
    if isfinite(Ax)
        axCorrPrev = Ax;
    else
        axCorrPrev = 0;
    end

    eSlip = NaN(4, 1);
    DeltaVWheel = NaN(4, 1);
    DeltaVImu = NaN;
    residualValid = false(4, 1);
    windowReady = false;
    slipReady = false;
    imuLife = false;
    LifeSig_IMU = 0;
    LifeSig_WSS = false(4, 1);
    return;
end

% ---------- Corrected IMU acceleration ----------
% Stage 2: axCorr(k)=Ax(k)+yawRate(k)*vy_prior(k)
if isfinite(Ax) && isfinite(yawRate) && isfinite(vyPrior)
    axCorr = Ax + yawRate * vyPrior;
else
    axCorr = 0;
end

if isfield(p, 'accelSanityMax') && isfinite(p.accelSanityMax)
    imuLife = all(isfinite([Ax, yawRate, vyPrior, axCorr])) && (abs(Ax) < p.accelSanityMax);
else
    imuLife = all(isfinite([Ax, yawRate, vyPrior, axCorr]));
end

% ---------- Window bookkeeping ----------
totalCount = totalCount + 1;
if totalCount > Nwindow
    count = Nwindow;
else
    count = totalCount;
end
windowReady = (count == Nwindow);
slipReady = windowReady;

% Update IMU FIFO (interval increments). First-packet initialization follows
% Stage 2: axCorrPrev = (Ax finite ? Ax : 0) and dvImu uses axCorr(k-1).
dvImuStep = 0.5 * Ts_est * (axCorrPrev + axCorr);
dvImuFIFO = [dvImuFIFO(2:end), dvImuStep];
if ~imuLife
    dvImuFIFO(:) = 0;
end
axCorrPrev = axCorr;

% Update WSS wheel FIFO (each column stores candidate history).
vxWheelFIFO = [vxWheelFIFO(:, 2:end), vxWheel];

% ---------- IMU window increment ----------
% Use the same physical span as wheel window by computing only after
% totalCount > Nwindow to match the additional wheel-history sample needed.
if windowReady && totalCount > Nwindow && imuLife
    DeltaVImu = sum(dvImuFIFO);
else
    DeltaVImu = NaN;
end
LifeSig_IMU = imuLife && windowReady && totalCount > Nwindow && isfinite(DeltaVImu);

% ---------- Wheel window increment ----------
% Stage 2 strict order: [FL, FR, RL, RR]
DeltaVWheel = NaN(4, 1);
residualValid = false(4, 1);
if windowReady && totalCount > Nwindow
    % current (newest) is column Nwindow+1, historical sample k-Nwindow is col1
    DeltaVWheel = vxWheelFIFO(:, end) - vxWheelFIFO(:, 1);

    histPairValid = isfinite(vxWheelFIFO(:, 1)) & isfinite(vxWheelFIFO(:, end)) & validGeom;
    residualValid = histPairValid;
    DeltaVWheel(~residualValid) = NaN;
end

% ---------- eSlip ----------
eSlip = NaN(4, 1);
if LifeSig_IMU && all(~isnan(DeltaVWheel))
    eSlip = abs(DeltaVWheel - DeltaVImu);
    eSlip(~residualValid) = NaN;
elseif LifeSig_IMU
    for i = 1:4
        if residualValid(i)
            eSlip(i) = abs(DeltaVWheel(i) - DeltaVImu);
        end
    end
else
    eSlip(:) = NaN;
end

LifeSig_WSS = residualValid;

