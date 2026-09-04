function y = vy_dynamic_ekf_v1_17_reliability_numeric(w,modeCode)
%VY_DYNAMIC_EKF_V1_17_RELIABILITY_NUMERIC Numeric Simulink boundary.
% Preserves the historical 69-element D-EKF output exactly and appends only
% the two A2R1 validity diagnostics required by the reliability capture
% target. The estimator equations and persistent state remain owned by the
% frozen wrapper called below.

[base,reliability] = vy_dynamic_ekf_v1_17(w,modeCode);
y = zeros(71,1);
y(1:69) = base;
y(70) = double(reliability.update_valid_D);
y(71) = double(reliability.nis_valid_D);
end
