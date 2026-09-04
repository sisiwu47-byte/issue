function report = test_vy_kinematic_kf_wrapper()
%TEST_VY_KINEMATIC_KF_WRAPPER Unit tests for persistent/reset behavior.

tol = 1e-12;
tests = 0;
u = [0.3; -0.15; 0.12];
z = 20.0;

cfg = struct('Ts', 0.01, ...
    'Q_K', diag([1e-4, 1e-3]), 'R_Vx', 1e-4);
x0 = [z; 0];
P0 = diag([0.1, 0.1]);
[xExpected, PExpected, infoExpected] = ...
    vy_kinematic_kf_step(x0, P0, u, z, cfg);

clear vy_kinematic_kf
[x1, P1, d1, rel1] = vy_kinematic_kf(u, z, 1);
assert(max(abs(x1 - xExpected)) <= tol, 'Wrapper reset state mismatch.');
assert(max(abs(P1(:) - PExpected(:))) <= tol, 'Wrapper reset P mismatch.');
tests = tests + 1;
assert(rel1.update_valid_K && rel1.nis_valid_K && isfinite(rel1.S_K), ...
    'K reliability validity/S diagnostic mismatch.');
tests = tests + 1;

% A legitimate zero innovation must remain a valid update, not be confused
% with the invalid-NIS fallback condition.
[~, ~, infoZeroSeed] = vy_kinematic_kf_step(x0, P0, u, z, cfg);
[~, ~, infoZero] = vy_kinematic_kf_step(x0, P0, u, infoZeroSeed.x_pred(1), cfg);
assert(abs(infoZero.NIS) <= tol && infoZero.updateValid, ...
    'Zero innovation was not retained as a valid update.');
tests = tests + 1;

expectedDiag = [infoExpected.NIS; infoExpected.obs_metric; ...
    infoExpected.innovation; infoExpected.K(1); infoExpected.K(2)];
assert(isequal(size(d1), [5 1]) && max(abs(d1 - expectedDiag)) <= tol, ...
    'diag_out layout mismatch.');
tests = tests + 1;

[x2, P2, d2] = vy_kinematic_kf(u, z, 0);
assert(all(isfinite([x2; P2(:); d2])), 'Persistent update produced NaN/Inf.');
assert(max(abs(P2(:) - P1(:))) > 1e-10, 'Persistent covariance did not advance.');
tests = tests + 1;

% An explicit reset must reproduce the first-sample result exactly and
% prevent state contamination from the prior call sequence.
[xReset, PReset, dReset] = vy_kinematic_kf(u, z, 1);
assert(max(abs(xReset - x1)) <= tol, 'Explicit reset did not isolate state.');
assert(max(abs(PReset(:) - P1(:))) <= tol, 'Explicit reset did not isolate P.');
assert(max(abs(dReset - d1)) <= tol, 'Explicit reset diagnostics mismatch.');
tests = tests + 1;

% Empty persistent storage must initialize identically even without a high
% reset input on the first call of a new run.
clear vy_kinematic_kf
[xFresh, PFresh, dFresh] = vy_kinematic_kf(u, z, 0);
assert(max(abs(xFresh - x1)) <= tol && ...
    max(abs(PFresh(:) - P1(:))) <= tol && max(abs(dFresh - d1)) <= tol, ...
    'Fresh-run initialization mismatch.');
tests = tests + 1;

assert(nargin('vy_kinematic_kf') == 3, 'Wrapper interface must have three inputs.');
wrapperText = lower(fileread(which('vy_kinematic_kf')));
assert(~contains(wrapperText, 'vy_true'), 'Offline lateral truth entered wrapper.');
assert(~contains(wrapperText, 'dynamic_ekf') && ~contains(wrapperText, 'dekf'), ...
    'Wrapper contains a forbidden dynamic-filter dependency.');
tests = tests + 1;

assert(abs(d1(2) - abs(u(3))) <= tol, 'Wrapper obs_metric mismatch.');
assert(d1(2) > 0.01, 'Diagnostic threshold test setup is invalid.');
tests = tests + 1;

report = struct();
report.passed = true;
report.tests = tests;
report.resetStateMaxError = max(abs(xReset - x1));
report.resetCovarianceMaxError = max(abs(PReset(:) - P1(:)));
report.diagLength = numel(d1);
report.NIS = d1(1);
report.obsMetric = d1(2);
report.K11 = d1(4);
report.K21 = d1(5);

fprintf(['K_KF_WRAPPER_TEST_OK|tests=%d|resetXErr=%.15g|' ...
    'resetPErr=%.15g|diag=%d\n'], tests, report.resetStateMaxError, ...
    report.resetCovarianceMaxError, report.diagLength);
end
