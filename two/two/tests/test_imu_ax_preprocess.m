function report = test_imu_ax_preprocess()
%TEST_IMU_AX_PREPROCESS Unit checks for the Ax_IMU prerequisite.

Ts = 0.01;
fc = 20.0;
tau = 1/(2*pi*fc);
alpha = Ts/(tau + Ts);
tol = 1e-12;

clear imu_ax_preprocess
y0 = imu_ax_preprocess(1.0, 0.1, 0.2, 1.0);
assert(abs(y0 - 1.3) <= tol, 'Reset must initialize to the measured input.');

y1 = imu_ax_preprocess(2.0, 0.1, 0.2, 0.0);
y1Expected = 1.3 + alpha*(2.3 - 1.3);
assert(abs(y1 - y1Expected) <= tol, 'First-order low-pass update mismatch.');

y2 = imu_ax_preprocess(3.0, -0.2, 0.4, 1.0);
assert(abs(y2 - 3.2) <= tol, 'Explicit reset did not replace filter state.');

y3 = imu_ax_preprocess(3.0, -0.2, 0.4, 0.0);
assert(abs(y3 - 3.2) <= tol, 'Constant measurement should remain constant.');

clear imu_ax_preprocess
yFinite = imu_ax_preprocess(NaN, Inf, -Inf, NaN);
assert(isfinite(yFinite) && yFinite == 0, 'Finite guards failed.');

clear imu_ax_preprocess
y = zeros(200,1);
for k = 1:numel(y)
    y(k) = imu_ax_preprocess(double(k > 1), 0, 0, double(k == 1));
end
assert(all(isfinite(y)), 'Output contains NaN or Inf.');
assert(all(diff(y(2:end)) >= -tol), 'Step response must be monotonic.');
assert(abs(y(end) - 1) < 1e-10, 'Step response did not converge.');

report = struct();
report.passed = true;
report.Ts = Ts;
report.fc = fc;
report.alpha = alpha;
report.bias = 0.02;
report.whiteNoiseVariance = 2.5e-5;
report.tests = 7;

fprintf('AX_IMU_UNIT_TEST_OK|tests=%d|Ts=%.12g|fc=%.12g|alpha=%.15g\n', ...
    report.tests, report.Ts, report.fc, report.alpha);
end
