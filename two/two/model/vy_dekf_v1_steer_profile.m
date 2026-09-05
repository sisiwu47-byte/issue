function steering = vy_dekf_v1_steer_profile(time)
%VY_DEKF_V1_STEER_PROFILE Smooth front-wheel steering baseline input.
%
% Output order is [FL; FR; RL; RR] in radians. The profile is zero before
% 3 s and after 13 s. Between those times it applies a 0.4 Hz, 0.02 rad
% front-wheel sine with 0.5 s raised-cosine fade-in/fade-out. Rear-wheel
% steering remains zero.

steering = zeros(4, 1);
if ~isscalar(time) || ~isfinite(time)
    return;
end

startTime = 3.0;
stopTime = 13.0;
rampDuration = 0.5;
amplitude = 0.02;
frequency = 0.4;

if time < startTime || time > stopTime
    return;
end

if time < startTime + rampDuration
    rampPhase = (time - startTime) / rampDuration;
    envelope = 0.5 * (1 - cos(pi * rampPhase));
elseif time > stopTime - rampDuration
    rampPhase = (time - (stopTime - rampDuration)) / rampDuration;
    envelope = 0.5 * (1 + cos(pi * rampPhase));
else
    envelope = 1.0;
end

frontAngle = amplitude * envelope * ...
    sin(2 * pi * frequency * (time - startTime));
steering(1) = frontAngle;
steering(2) = frontAngle;
end
