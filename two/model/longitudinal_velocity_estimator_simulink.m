function ySim = longitudinal_velocity_estimator_simulink(u)
%LONGITUDINAL_VELOCITY_ESTIMATOR_SIMULINK
% Simulink interface wrapper for longitudinal_velocity_estimator.
%
% Internal estimator semantics are unchanged.
% NaN/Inf diagnostic outputs are replaced ONLY at the Simulink boundary,
% because Interpreted MATLAB Function requires finite double output.
%
% Input:
%   u    : 18x1 estimator input
%
% Output:
%   ySim : 38x1 finite double vector

u = double(u(:));

if numel(u) ~= 18
    error( ...
        'longitudinal_velocity_estimator_simulink:InvalidInputSize', ...
        'Input u must contain exactly 18 elements.');
end

% Run the validated estimator.
yRaw = longitudinal_velocity_estimator(u);

yRaw = double(yRaw(:));

if numel(yRaw) ~= 38
    error( ...
        'longitudinal_velocity_estimator_simulink:InvalidOutputSize', ...
        'Estimator output must contain exactly 38 elements.');
end

% Preserve estimator result internally, but convert non-finite diagnostic
% values to a finite placeholder for the Simulink interface.
ySim = yRaw;

bad = ~isfinite(ySim);
ySim(bad) = 0;

end