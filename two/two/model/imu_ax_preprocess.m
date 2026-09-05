function axOut = imu_ax_preprocess(axCarsim, whiteNoise, biasInput, resetFlag)
%IMU_AX_PREPROCESS Virtual longitudinal-acceleration IMU prerequisite.
%#codegen
%
% Inputs and output are in m/s^2. The implementation intentionally mirrors
% the existing Ay virtual IMU: 100 Hz, additive bias/white noise, a 20 Hz
% first-order low-pass filter, finite guards, and an explicit reset input.

persistent yPrev

Ts = 0.01;
fc = 20.0;

if ~isfinite(axCarsim)
    axCarsim = 0;
end
if ~isfinite(whiteNoise)
    whiteNoise = 0;
end
if ~isfinite(biasInput)
    biasInput = 0;
end
if ~isfinite(resetFlag)
    resetFlag = 0;
end

axMeasured = axCarsim + biasInput + whiteNoise;
tau = 1/(2*pi*fc);
alpha = Ts/(tau + Ts);

if isempty(yPrev) || resetFlag > 0.5
    yPrev = axMeasured;
end

axOut = yPrev + alpha*(axMeasured - yPrev);
yPrev = axOut;
end
