function steering = vy_dekf_v1_12_steer_profile(time, amplitude, frequency)
%VY_DEKF_V1_12_STEER_PROFILE Parameterized V1.12 cross-condition input.
% Output order: [FL; FR; RL; RR] [rad]. The established 3--13 s
% excitation window and 0.5 s raised-cosine fade-in/fade-out are retained.

steering = zeros(4,1);
if ~isscalar(time) || ~isfinite(time) || ...
        ~isscalar(amplitude) || ~isfinite(amplitude) || amplitude < 0 || ...
        ~isscalar(frequency) || ~isfinite(frequency) || frequency <= 0
    return;
end

startTime = 3.0;
stopTime = 13.0;
rampDuration = 0.5;
if time < startTime || time > stopTime
    return;
end
if time < startTime + rampDuration
    phase = (time-startTime)/rampDuration;
    envelope = 0.5*(1-cos(pi*phase));
elseif time > stopTime-rampDuration
    phase = (time-(stopTime-rampDuration))/rampDuration;
    envelope = 0.5*(1+cos(pi*phase));
else
    envelope = 1.0;
end
frontAngle = amplitude*envelope*sin(2*pi*frequency*(time-startTime));
steering(1:2) = frontAngle;
end
