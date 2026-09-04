function report = test_vy_dkekf_baseline_step()
%TEST_VY_DKEKF_BASELINE_STEP Unit tests for the unified V2.2-B core.

[par, cfg, Ts, P0] = baseline_configuration();
tol = 1e-12;
tests = 0;
x = [20; 0.35; 0.12];
P = P0;
Ax = 0.4;
steer = [0.035; 0.035; 0; 0];
zVx = 20.1;
zr = 0.115;
zAy = 0.7;

[xNew, PNew, info] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, zVx, zr, zAy, true, Ts, par, cfg);

% 1-2: one shared state and covariance.
assert(isequal(size(xNew), [3 1]), 'State must be 3x1 [Vx; Vy; r].');
tests = tests + 1;
assert(isequal(size(PNew), [3 3]) && ...
    info.sharedStateDimension == 3 && ...
    isequal(info.sharedCovarianceDimension, [3 3]), ...
    'Covariance must be one shared 3x3 matrix.');
tests = tests + 1;

% 3: deterministic repeatability.
[xRepeat, PRepeat, repeatInfo] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, zVx, zr, zAy, true, Ts, par, cfg);
assert(isequal(xNew, xRepeat) && isequal(PNew, PRepeat) && ...
    isequal(info.F, repeatInfo.F), 'Core is not deterministically repeatable.');
tests = tests + 1;

% 4: exact Vx prediction and analytic first Jacobian row.
expectedVxPred = x(1) + Ts*(Ax + x(3)*x(2));
assert(abs(info.x_pred(1)-expectedVxPred) <= tol && ...
    max(abs(info.A(1,:) - [0 x(3) x(2)])) <= tol, ...
    'Vx_dot or its Jacobian row is incorrect.');
tests = tests + 1;

% 5-6: frozen D-EKF lateral prediction and Ay equation equivalence.
parD = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
cfgD = struct('dt',Ts,'Q',diag([1e-4,1e-4]), ...
    'R',diag([1e-2,3.365172961808e-4]), ...
    'denomEps',1e-12,'lambda',zeros(4,1));
uD = [x(1); steer];
[~, ~, frozenInfo] = vy_dynamic_ekf_step_v17( ...
    x(2:3), P(2:3,2:3), uD, [zAy; zr], parD, cfgD, false);
lateralEquivalenceError = max(abs( ...
    info.x_pred(2:3) - frozenInfo.x_pred));
assert(lateralEquivalenceError <= 1e-12, ...
    'Unified lateral prediction differs from frozen D-EKF.');
tests = tests + 1;

xAy = [x(1); frozenInfo.x_pred];
[~, ~, ayEquivalenceInfo] = vy_dkekf_baseline_step( ...
    xAy, P, Ax, steer, zVx, zr, zAy, false, Ts, par, cfg);
ayEquivalenceError = abs( ...
    ayEquivalenceInfo.h_Ay_input - frozenInfo.h_pred(1));
assert(ayEquivalenceError <= 1e-12, ...
    'Unified Ay equation differs from frozen D-EKF.');
tests = tests + 1;

% 7-8: exact direct-measurement Jacobians.
assert(isequal(info.H_Vx, [1 0 0]), 'H_Vx must equal [1 0 0].');
tests = tests + 1;
assert(isequal(info.H_r, [0 0 1]), 'H_r must equal [0 0 1].');
tests = tests + 1;

% 9-10: independent finite-difference checks over signed and low-Vx cases.
states = [20,  0.35,  0.12; ...
          20, -0.45,  0.16; ...
          20,  0.55, -0.18; ...
          20, -0.65, -0.14; ...
           3,  0.20,  0.08; ...
           5, -0.25, -0.09].';
steers = [ 0.000,  0.000, 0, 0; ...
           0.040,  0.040, 0, 0; ...
          -0.040, -0.040, 0, 0; ...
           0.025, -0.015, 0, 0; ...
           0.020,  0.020, 0, 0; ...
          -0.030, -0.030, 0, 0].';
predictionJacobianMaxError = 0;
ayJacobianMaxError = 0;
for k = 1:size(states,2)
    xCase = states(:,k);
    dCase = steers(:,k);
    [~, ~, caseInfo] = vy_dkekf_baseline_step( ...
        xCase, P, Ax, dCase, xCase(1), xCase(3), 0, ...
        false, Ts, par, cfg);
    Afd = independent_jacobian(@(q) eval_f( ...
        q, P, Ax, dCase, Ts, par, cfg), xCase, 2e-5);
    Hfd = independent_jacobian(@(q) eval_hay( ...
        q, P, Ax, dCase, Ts, par, cfg), xCase, 2e-5);
    predictionJacobianMaxError = max(predictionJacobianMaxError, ...
        max(abs(caseInfo.A(:)-Afd(:))));
    ayJacobianMaxError = max(ayJacobianMaxError, ...
        max(abs(caseInfo.H_Ay_input(:)-Hfd(:))));
end
jacobianTolerance = 5e-4;
assert(predictionJacobianMaxError <= jacobianTolerance, ...
    'Prediction Jacobian finite-difference check failed.');
tests = tests + 1;
assert(ayJacobianMaxError <= jacobianTolerance, ...
    'Ay Jacobian finite-difference check failed.');
tests = tests + 1;

% 11-13: independent scalar update reference calculations.
[vxX, vxP] = reference_scalar_update(info.x_pred, info.P_pred, ...
    zVx, info.x_pred(1), info.H_Vx, cfg.R_Vx);
assert(max(abs(vxX-info.Vx.x_post)) <= tol && ...
    max(abs(vxP(:)-info.Vx.P_post(:))) <= tol, ...
    'Vx scalar update reference mismatch.');
tests = tests + 1;

[rX, rP] = reference_scalar_update(info.r.x_prior, info.r.P_prior, ...
    zr, info.r.x_prior(3), info.H_r, cfg.R_r);
assert(max(abs(rX-info.r.x_post)) <= tol && ...
    max(abs(rP(:)-info.r.P_post(:))) <= tol, ...
    'Yaw-rate scalar update reference mismatch.');
tests = tests + 1;

[ayX, ayP] = reference_scalar_update(info.Ay.x_prior, info.Ay.P_prior, ...
    zAy, info.Ay.h, info.H_Ay, cfg.R_Ay);
assert(max(abs(ayX-info.Ay.x_post)) <= tol && ...
    max(abs(ayP(:)-info.Ay.P_post(:))) <= tol, ...
    'Ay scalar update reference mismatch.');
tests = tests + 1;

% 14: doAyUpdate=false must leave the post-r state/P exactly untouched.
[xNoAy1, PNoAy1, noAyInfo1] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, zVx, zr, -100, false, Ts, par, cfg);
[xNoAy2, PNoAy2, noAyInfo2] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, zVx, zr, 100, false, Ts, par, cfg);
assert(isequal(xNoAy1, xNoAy2) && isequal(PNoAy1, PNoAy2) && ...
    isequal(xNoAy1, noAyInfo1.r.x_post) && ...
    isequal(PNoAy1, noAyInfo1.r.P_post) && ...
    ~noAyInfo1.Ay.updateApplied && ~noAyInfo2.Ay.updateApplied, ...
    'doAyUpdate=false did not skip Ay exactly.');
tests = tests + 1;

% 15: all applied covariance updates use Joseph form.
josephMaxError = max([ ...
    joseph_error(info.Vx, cfg.R_Vx), ...
    joseph_error(info.r, cfg.R_r), ...
    joseph_error(info.Ay, cfg.R_Ay)]);
assert(josephMaxError <= 1e-14, 'Joseph covariance reconstruction failed.');
tests = tests + 1;

% 16-18: symmetry, PSD, and finite outputs.
symmetryError = max(abs(PNew-PNew.'), [], 'all');
assert(symmetryError <= tol, 'P is not symmetric.');
tests = tests + 1;
assert(min(eig(PNew)) >= -1e-12, 'P is not positive semidefinite.');
tests = tests + 1;
assert(all(isfinite([xNew; PNew(:); info.x_pred; info.P_pred(:); ...
    info.F(:); info.H_Ay(:); info.Vx.NIS; info.r.NIS; info.Ay.NIS])), ...
    'NaN/Inf detected in core outputs.');
tests = tests + 1;

% 19: deterministic 500-step covariance/numerical robustness sequence.
rng(20260826, 'twister');
xSeq = [20; 0; 0];
PSeq = P0;
sequenceMinEigenvalue = inf;
sequenceMaxSymmetryError = 0;
for k = 1:500
    phase = 2*pi*0.4*(k-1)*Ts;
    d = [0.04*sin(phase); 0.04*sin(phase); 0; 0];
    axk = 0.15*cos(0.013*k);
    zvxk = 20 + 0.25*sin(0.007*k) + 0.002*randn;
    zrk = 0.15*sin(phase) + 0.001*randn;
    zayk = 0.8*sin(phase) + 0.01*randn;
    useAy = mod(k-1,5) == 0;
    [xSeq, PSeq, seqInfo] = vy_dkekf_baseline_step( ...
        xSeq, PSeq, axk, d, zvxk, zrk, zayk, useAy, Ts, par, cfg);
    sequenceMinEigenvalue = min(sequenceMinEigenvalue, min(eig(PSeq)));
    sequenceMaxSymmetryError = max(sequenceMaxSymmetryError, ...
        max(abs(PSeq-PSeq.'), [], 'all'));
    assert(all(isfinite([xSeq; PSeq(:); seqInfo.f; seqInfo.F(:)])), ...
        'Robustness sequence produced NaN/Inf.');
end
assert(sequenceMinEigenvalue >= -1e-12 && ...
    sequenceMaxSymmetryError <= tol, ...
    'Robustness sequence lost covariance PSD/symmetry.');
tests = tests + 1;

% 20-25: static isolation/fairness gates.
corePath = which('vy_dkekf_baseline_step');
coreText = lower(fileread(corePath));
assert(~contains(coreText, 'vy_true'), 'TRUE Vy entered the online core.');
tests = tests + 1;
assert(~contains(coreText, 'inv('), 'Core must not use inv().');
tests = tests + 1;
dynText = extract_function(coreText, ...
    'function [f, out] = dk_dynamics', ...
    'function a = dynamics_jacobian');
assert(~contains(dynText, 'z_vx') && contains(dynText, 'vx = x(1)'), ...
    'True-Vx measurement bypassed state x(1) in lateral dynamics.');
tests = tests + 1;
assert(~contains(dynText, 'z_r') && ~contains(dynText, 'avz'), ...
    'Yaw-rate measurement leaked into prediction.');
tests = tests + 1;
assert(~contains(dynText, 'z_ay') && ~contains(dynText, 'ay_imu'), ...
    'Ay measurement leaked into prediction.');
tests = tests + 1;
assert(~contains(coreText, 'fusion') && ~contains(coreText, 'lifesig') && ...
    ~contains(coreText, 'adaptive covariance'), ...
    'Forbidden fusion/LifeSig/adaptive logic entered the core.');
tests = tests + 1;

report = struct();
report.passed = true;
report.tests = tests;
report.stateOrdering = '[Vx; Vy; r]';
report.sharedCovarianceSize = size(PNew);
report.lateralEquivalenceMaxError = lateralEquivalenceError;
report.ayEquivalenceMaxError = ayEquivalenceError;
report.predictionJacobianMaxError = predictionJacobianMaxError;
report.ayJacobianMaxError = ayJacobianMaxError;
report.jacobianTolerance = jacobianTolerance;
report.josephMaxError = josephMaxError;
report.maxSymmetryError = symmetryError;
report.sequenceSteps = 500;
report.sequenceMinEigenvalue = sequenceMinEigenvalue;
report.sequenceMaxSymmetryError = sequenceMaxSymmetryError;
report.Q_DK = cfg.Q_DK;
report.R = [cfg.R_Vx cfg.R_r cfg.R_Ay];
report.P0_DK = P0;
report.fairness = struct( ...
    'trueVyOnlineInput', false, ...
    'trueVxMeasurementOnly', true, ...
    'trueVxDirectLateralInput', false, ...
    'AVzMeasurementOnly', true, ...
    'AyMeasurementOnly', true, ...
    'AxPredictionInput', true, ...
    'sharedState', true, ...
    'sharedCovariance3x3', true, ...
    'outputFusion', false, ...
    'LifeSig', false, ...
    'adaptiveFusion', false);

fprintf(['DK_EKF_CORE_TEST_OK|tests=%d|latEq=%.17g|ayEq=%.17g|' ...
    'predJac=%.17g|ayJac=%.17g|minEig500=%.17g|sym500=%.17g\n'], ...
    tests, lateralEquivalenceError, ayEquivalenceError, ...
    predictionJacobianMaxError, ayJacobianMaxError, ...
    sequenceMinEigenvalue, sequenceMaxSymmetryError);
end

function [par, cfg, Ts, P0] = baseline_configuration()
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
Ts = 0.01;
cfg = struct('Q_DK',diag([1e-4,1e-4,1e-4]), ...
    'R_Vx',1e-4,'R_r',3.365172961808e-4,'R_Ay',1e-2, ...
    'jacobianStep',1e-6,'denomEps',1e-12,'lambda',zeros(4,1));
P0 = diag([0.1,0.1,0.1]);
end

function f = eval_f(x, P, Ax, steer, Ts, par, cfg)
[~, ~, info] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, x(1), x(3), 0, false, Ts, par, cfg);
f = info.f;
end

function h = eval_hay(x, P, Ax, steer, Ts, par, cfg)
[~, ~, info] = vy_dkekf_baseline_step( ...
    x, P, Ax, steer, x(1), x(3), 0, false, Ts, par, cfg);
h = info.h_Ay_input;
end

function J = independent_jacobian(fun, x, relativeStep)
f0 = fun(x);
J = zeros(numel(f0), numel(x));
for j = 1:numel(x)
    h = relativeStep*max(1,abs(x(j)));
    xp = x;
    xm = x;
    xp(j) = xp(j)+h;
    xm(j) = xm(j)-h;
    J(:,j) = (fun(xp)-fun(xm))/(2*h);
end
end

function [xPost, PPost] = reference_scalar_update(xPrior, PPrior, z, h, H, R)
S = H*PPrior*H.'+R;
K = (PPrior*H.')/S;
xPost = xPrior+K*(z-h);
I_KH = eye(3)-K*H;
PPost = I_KH*PPrior*I_KH.'+K*R*K.';
PPost = 0.5*(PPost+PPost.');
end

function err = joseph_error(updateInfo, R)
I_KH = eye(3)-updateInfo.K*updateInfo.H;
expected = I_KH*updateInfo.P_prior*I_KH.' + ...
    updateInfo.K*R*updateInfo.K.';
expected = 0.5*(expected+expected.');
err = max(abs(expected-updateInfo.P_post), [], 'all');
end

function section = extract_function(text, startMarker, endMarker)
startIndex = strfind(text, startMarker);
assert(~isempty(startIndex), 'Source-audit start marker missing.');
tail = text(startIndex(1):end);
endIndex = strfind(tail, endMarker);
assert(~isempty(endIndex), 'Source-audit end marker missing.');
section = tail(1:endIndex(1)-1);
end
