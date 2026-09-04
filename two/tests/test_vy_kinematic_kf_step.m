function report = test_vy_kinematic_kf_step()
%TEST_VY_KINEMATIC_KF_STEP Unit tests for the V2.1-A K-KF core.

cfg = baseline_cfg();
tol = 1e-12;
tests = 0;

% 1-2: zero-yaw propagation and zero observability metric.
x = [20; 1.25];
P = diag([0.1, 0.1]);
u = [0; 0; 0];
z = 20;
[xNew, PNew, info] = vy_kinematic_kf_step(x, P, u, z, cfg);
assert(max(abs(info.x_pred - x)) <= tol, 'r=0 propagation mismatch.');
tests = tests + 1;
assert(info.obs_metric == 0 && ~info.obs_flag, 'r=0 observability mismatch.');
tests = tests + 1;

% 3: nonzero yaw rate and exact state-transition matrix.
r = -0.37;
u2 = [0.4; -0.2; r];
[~, ~, info2] = vy_kinematic_kf_step(x, P, u2, 19.8, cfg);
expectedF = [1, r*cfg.Ts; -r*cfg.Ts, 1];
assert(max(abs(info2.F(:) - expectedF(:))) <= tol, 'F mismatch.');
assert(abs(info2.obs_metric - abs(r)) <= tol && info2.obs_flag, ...
    'Nonzero-r observability mismatch.');
tests = tests + 1;

% 4: H must be exactly [1 0].
assert(isequal(info.H, [1 0]), 'H must be exactly [1 0].');
tests = tests + 1;

% 5-6: covariance symmetry and positive definiteness.
symmetryError = max(abs(PNew - PNew.'), [], 'all');
assert(symmetryError <= tol, 'P is not symmetric.');
tests = tests + 1;
assert(min(eig(PNew)) > 0, 'P is not positive definite.');
tests = tests + 1;

% 7: independent Joseph-form reconstruction.
I_KH = eye(2) - info.K*info.H;
expectedP = I_KH*info.P_pred*I_KH.' + ...
    info.K*cfg.R_Vx*info.K.';
expectedP = 0.5*(expectedP + expectedP.');
assert(max(abs(PNew(:) - expectedP(:))) <= 1e-14, ...
    'Joseph covariance update mismatch.');
tests = tests + 1;

% 8: innovation, S, gain, NIS, states, and covariance remain finite.
numericValues = [xNew; PNew(:); info.x_pred; info.P_pred(:); ...
    info.innovation; info.S; info.K; info.NIS; info.obs_metric; ...
    info.F(:); info.H(:)];
assert(all(isfinite(numericValues)), 'NaN/Inf detected.');
tests = tests + 1;

% 9: scalar NIS definition.
assert(abs(info.NIS - info.innovation^2/info.S) <= tol, 'NIS mismatch.');
tests = tests + 1;

% 10: acceleration input order and Euler prediction.
expectedPred = expectedF*x + cfg.Ts*u2(1:2);
assert(max(abs(info2.x_pred - expectedPred)) <= tol, ...
    'Ax/Ay input order or Euler prediction mismatch.');
tests = tests + 1;

% 11: only the scalar longitudinal-speed measurement is accepted.
didReject = false;
try
    vy_kinematic_kf_step(x, P, u, [20; 1], cfg);
catch
    didReject = true;
end
assert(didReject, 'Vector measurement must be rejected.');
tests = tests + 1;

% 12: static interface isolation check.
corePath = which('vy_kinematic_kf_step');
coreText = lower(fileread(corePath));
assert(nargin('vy_kinematic_kf_step') == 5, 'Core interface must have five inputs.');
assert(~contains(coreText, 'vy_true'), 'Offline lateral truth entered the core.');
assert(~contains(coreText, 'dynamic_ekf') && ~contains(coreText, 'dekf'), ...
    'Core contains a forbidden dynamic-filter dependency.');
tests = tests + 1;

% 13: deterministic randomized sequence robustness.
rng(20260826, 'twister');
xSeq = [20; 0];
PSeq = diag([0.1, 0.1]);
sequenceMinEigenvalue = inf;
for k = 1:500
    uSeq = [0.5*randn; 0.8*randn; 0.3*randn];
    zSeq = 20 + 0.2*sin(0.01*k) + 0.01*randn;
    [xSeq, PSeq, seqInfo] = ...
        vy_kinematic_kf_step(xSeq, PSeq, uSeq, zSeq, cfg);
    sequenceMinEigenvalue = min(sequenceMinEigenvalue, min(eig(PSeq)));
    assert(all(isfinite([xSeq; PSeq(:); seqInfo.NIS])), ...
        'Randomized sequence produced NaN/Inf.');
    assert(max(abs(PSeq - PSeq.'), [], 'all') <= tol, ...
        'Randomized sequence covariance lost symmetry.');
end
assert(sequenceMinEigenvalue > 0, ...
    'Randomized sequence covariance lost positive definiteness.');
tests = tests + 1;

report = struct();
report.passed = true;
report.tests = tests;
report.minEigenvalue = min(eig(PNew));
report.maxSymmetryError = symmetryError;
report.josephMaxError = max(abs(PNew(:) - expectedP(:)));
report.H = info.H;
report.zeroYawObsMetric = info.obs_metric;
report.nonzeroYawObsMetric = info2.obs_metric;
report.sequenceSteps = 500;
report.sequenceMinEigenvalue = sequenceMinEigenvalue;

fprintf(['K_KF_CORE_TEST_OK|tests=%d|minEig=%.15g|symErr=%.15g|' ...
    'josephErr=%.15g\n'], tests, report.minEigenvalue, ...
    report.maxSymmetryError, report.josephMaxError);
end

function cfg = baseline_cfg()
cfg = struct();
cfg.Ts = 0.01;
cfg.Q_K = diag([1e-4, 1e-3]);
cfg.R_Vx = 1e-4;
end
