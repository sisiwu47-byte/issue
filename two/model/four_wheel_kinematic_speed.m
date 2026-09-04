function [vxWheel, validGeom] = four_wheel_kinematic_speed(omegaWheel, deltaWheel, yawRate, vyPrior, p)
%FOUR_WHEEL_KINEMATIC_SPEED Kinematic candidate longitudinal speed from four independent wheels.
%   [vxWheel, validGeom] = four_wheel_kinematic_speed(omegaWheel, deltaWheel, yawRate, vyPrior, p)
%   calculates the four wheel-speed candidates in order [FL, FR, RL, RR].
%
%   Units: omega [rad/s], delta [rad], yawRate [rad/s], Rw [m].
%   Output vxWheel is m/s, validGeom is logical validity per wheel.

if nargin ~= 5
    error('four_wheel_kinematic_speed:InvalidInputCount', ...
          'Expected 5 input arguments.');
end

if ~isstruct(p)
    error('four_wheel_kinematic_speed:InvalidParams', 'p must be a struct.');
end

if ~all(isfield(p, {'Rw', 'a', 'b', 'd', 'cos_delta_min'}))
    error('four_wheel_kinematic_speed:InvalidParams', ...
          'p must contain fields Rw, a, b, d, cos_delta_min.');
end

if ~isnumeric(omegaWheel) || ~isnumeric(deltaWheel) || ~isnumeric(yawRate) || ~isnumeric(vyPrior)
    error('four_wheel_kinematic_speed:InvalidNumericInput', ...
          'Inputs omegaWheel/deltaWheel/yawRate/vyPrior must be numeric.');
end

omegaWheel = omegaWheel(:);
deltaWheel = deltaWheel(:);

if numel(omegaWheel) ~= 4 || numel(deltaWheel) ~= 4
    error('four_wheel_kinematic_speed:InvalidWheelSize', ...
          'omegaWheel and deltaWheel must be 4x1 vectors in order [FL, FR, RL, RR].');
end

vxWheel = NaN(4, 1);
validGeom = false(4, 1);

xWheel = [p.a; p.a; -p.b; -p.b];
yWheel = [p.d / 2; -p.d / 2; p.d / 2; -p.d / 2];

if ~(isscalar(yawRate) && isfinite(yawRate))
    % Global yawRate failure: all wheels invalid
    return;
end

if ~isscalar(vyPrior)
    % Per spec, local vy prior must be scalar; if invalid, all wheels invalid
    return;
end

for i = 1:4
    omega_i = omegaWheel(i);
    delta_i = deltaWheel(i);

    if ~isfinite(omega_i) || ~isfinite(delta_i)
        continue;
    end

    if abs(cos(delta_i)) < p.cos_delta_min
        continue;
    end

    wheelSpeedCandidate = p.Rw * omega_i;
    vxWheel(i) = yawRate * yWheel(i) + ...
        (wheelSpeedCandidate - (vyPrior + yawRate * xWheel(i)) * sin(delta_i)) / cos(delta_i);

    if isfinite(vxWheel(i))
        validGeom(i) = true;
    end
end

