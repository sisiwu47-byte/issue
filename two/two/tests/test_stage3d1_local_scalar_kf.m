function tests = test_stage3d1_local_scalar_kf
%TEST_STAGE3D1_LOCAL_SCALAR_KF Static tests for Stage-2 local scalar KF formulas.
%
%   Covers WSS/IMU local filters with A = 1, H = 1 and Stage-2 gating rules:
%   - invalid measurement valid flag => prediction-only
%   - NaN/Inf z and invalid R are protected
%   - reset initialization values are accepted through xPrev and PPrev inputs

tests = functiontests(localfunctions);
end

function test_manual_numbers(testCase)
p = struct('denomEps', 1e-12);
xPrev = 10.0;
PPrev = 4.0;
Q = 1.0;
z = 14.0;
R = 4.0;
expectedPMinus = PPrev + Q;
expectedK = expectedPMinus / (expectedPMinus + R);
expectedXPlus = xPrev + expectedK * (z - xPrev);
expectedPPlus = (1 - expectedK) * expectedPMinus;

[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, true, p);

testCase.verifyEqual(xMinus, xPrev);
testCase.verifyEqual(PMinus, expectedPMinus);
testCase.verifyEqual(K, expectedK, 'RelTol', 1e-12);
testCase.verifyEqual(xPlus, expectedXPlus, 'RelTol', 1e-12);
testCase.verifyEqual(PPlus, expectedPPlus, 'RelTol', 1e-12);
end

function test_zero_innovation(testCase)
p = struct('denomEps', 1e-12);
xPrev = -3.2;
PPrev = 5.6;
Q = 0.2;
z = xPrev;
R = 0.9;

[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, true, p);
PMinusExpected = PPrev + Q;
KExpected = PMinusExpected / (PMinusExpected + R);
XPlusExpected = xPrev + KExpected * (z - xPrev);

testCase.verifyEqual(PMinus, PMinusExpected);
testCase.verifyEqual(K, KExpected, 'RelTol', 1e-12);
testCase.verifyEqual(xPlus, XPlusExpected, 'RelTol', 1e-12);
testCase.verifyEqual(xPlus, xMinus);
testCase.verifyEqual(PPlus, PMinus - KExpected * PMinus, 'RelTol', 1e-12);
end

function test_small_R_tends_to_one_gain(testCase)
p = struct('denomEps', 1e-12);
xPrev = 1.4;
PPrev = 0.4;
Q = 0.0;
z = 3.0;
R = 1e-9;
[xPlus, ~, ~, ~, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, true, p);

testCase.verifyLessThan(abs(K), 1);
testCase.verifyGreaterThan(K, 0.9999999);
testCase.verifyEqual(xPlus, (1 - K) * xPrev + K * z, 'RelTol', 1e-9);
end

function test_large_R_tends_to_zero_gain(testCase)
p = struct('denomEps', 1e-12);
xPrev = 8.0;
PPrev = 2.0;
Q = 0.0;
z = 20.0;
R = 1e12;
[xPlus, ~, ~, ~, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, true, p);

testCase.verifyLessThan(K, 1e-6);
testCase.verifyEqual(xPlus, xPrev, 'AbsTol', 1e-9);
end

function test_Q_increase_inflates_PMinus(testCase)
p = struct('denomEps', 1e-12);
xPrev = 2.0;
PPrev = 1.0;
R = 0.5;
Qlow = 1e-3;
Qhigh = 2e-2;
z = 2.3;

[~, PPlusLow, ~, PMinusLow] = local_scalar_kf_step(xPrev, PPrev, z, R, Qlow, true, p);
[~, PPlusHigh, ~, PMinusHigh] = local_scalar_kf_step(xPrev, PPrev, z, R, Qhigh, true, p);

testCase.verifyGreaterThan(PMinusHigh, PMinusLow);
testCase.verifyGreaterThan(PPlusHigh, PPlusLow);
testCase.verifyEqual(PMinusLow, PPrev + Qlow);
testCase.verifyEqual(PMinusHigh, PPrev + Qhigh);
end

function test_wss_invalid_measurement_is_skipped(testCase)
xPrev = 11.0;
PPrev = 0.01;
Q = 1e-4;
z = NaN;
R = 0.02;
wssValid = false;

[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, z, R, Q, wssValid);

testCase.verifyEqual(K, 0);
testCase.verifyEqual(xPlus, xMinus);
testCase.verifyEqual(PPlus, PMinus);
testCase.verifyEqual(xMinus, xPrev);
testCase.verifyEqual(PMinus, PPrev + Q);
testCase.verifyTrue(isfinite(xPlus));
testCase.verifyTrue(isfinite(PPlus));
end

function test_z_nan_is_blocked(testCase)
p = struct('denomEps', 1e-12);
xPrev = 4.0;
PPrev = 0.3;
Q = 1e-4;
R = 0.5;

[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, NaN, R, Q, true, p);
testCase.verifyEqual(K, 0);
testCase.verifyEqual(xPlus, xMinus);
testCase.verifyEqual(PPlus, PMinus);
testCase.verifyEqual(xMinus, xPrev);
testCase.verifyEqual(PMinus, PPrev + Q);
end

function test_z_inf_is_blocked(testCase)
p = struct('denomEps', 1e-12);
xPrev = -6.5;
PPrev = 0.3;
Q = 1e-4;
R = 0.5;

[xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, Inf, R, Q, true, p);
testCase.verifyEqual(K, 0);
testCase.verifyEqual(xPlus, xMinus);
testCase.verifyEqual(PPlus, PMinus);
testCase.verifyEqual(xMinus, xPrev);
testCase.verifyEqual(PMinus, PPrev + Q);
end

function test_illegal_R_is_protected(testCase)
p = struct('denomEps', 1e-12);
xPrev = 2.5;
PPrev = 0.7;
Q = 0.1;
z = 2.7;
badRs = [-1.0, 0.0, Inf];

for idx = 1:numel(badRs)
    [xPlus, PPlus, xMinus, PMinus, K] = local_scalar_kf_step(xPrev, PPrev, z, badRs(idx), Q, true, p);
    testCase.verifyEqual(K, 0);
    testCase.verifyEqual(xPlus, xMinus);
    testCase.verifyEqual(PPlus, PMinus);
    testCase.verifyEqual(xMinus, xPrev);
    testCase.verifyEqual(PMinus, PPrev + Q);
    testCase.verifyTrue(isfinite(xPlus));
    testCase.verifyTrue(isfinite(PPlus));
end
end

function test_reset_initialization_interfaces(testCase)
p = estimator_default_params();
vx0 = 13.2;

% WSS local KF init should accept external vx0/PW0.
[xWPlus, PWPlus, xWMinus, PWMinus, KW] = ...
    local_scalar_kf_step(vx0, p.PW0, vx0, p.R0, p.QW, false, p);
testCase.verifyEqual(xWMinus, vx0);
testCase.verifyEqual(PWMinus, p.PW0 + p.QW);
testCase.verifyEqual(KW, 0);
testCase.verifyEqual(xWPlus, xWMinus);
testCase.verifyEqual(PWPlus, PWMinus);
testCase.verifyTrue(isfinite(PWPlus));

% IMU local KF init should accept external vx0/PI0.
[xIPlus, PIPlus, xIMinus, PIMinus, KI] = ...
    local_scalar_kf_step(vx0, p.PI0, vx0, p.R0, p.QI, false, p);
testCase.verifyEqual(xIMinus, vx0);
testCase.verifyEqual(PIMinus, p.PI0 + p.QI);
testCase.verifyEqual(KI, 0);
testCase.verifyEqual(xIPlus, xIMinus);
testCase.verifyEqual(PIPlus, PIMinus);
testCase.verifyTrue(isfinite(PIPlus));
end
