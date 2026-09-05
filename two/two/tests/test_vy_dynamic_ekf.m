function tests = test_vy_dynamic_ekf
%TEST_VY_DYNAMIC_EKF Basic tests for the lateral-velocity dynamic EKF step.

tests = functiontests(localfunctions);

end


function test_no_nan_and_outputs_finite(testCase)
    [par, cfg] = default_ekf_params();

    x = [0.2; 0.01];
    P = eye(2) * 0.1;
    u = [12.0; 0.02; -0.01; 0.00; 0.015];
    z = [0.05; 0.012];

    [x_new, P_new, diag] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);

    testCase.verifyTrue(all(isfinite(x_new)), 'x_new contains NaN/Inf.');
    testCase.verifyTrue(all(isfinite(P_new(:))), 'P_new contains NaN/Inf.');
    testCase.verifyTrue(all(isfinite(diag.innovation(:))), 'innovation contains NaN/Inf.');
    testCase.verifyTrue(all(isfinite(diag.S(:))), 'S contains NaN/Inf.');
    testCase.verifyTrue(isfinite(diag.NIS), 'NIS is not finite.');
    forceVals = [diag.alpha_FL; diag.alpha_FR; diag.alpha_RL; diag.alpha_RR; ...
        diag.Fy_FL; diag.Fy_FR; diag.Fy_RL; diag.Fy_RR; ...
        diag.Fx_FL; diag.Fx_FR; diag.Fx_RL; diag.Fx_RR];
    testCase.verifyTrue(all(isfinite(forceVals)), 'force/output diagnostic contains NaN/Inf.');
end


function test_covariance_symmetry(testCase)
    [par, cfg] = default_ekf_params();

    x = [0.0; -0.005];
    P = [0.5, 0.03; 0.03, 0.2];
    u = [18; 0.01; -0.005; 0.004; -0.002];
    z = [0.1; 0.0];

    [~, P_new, ~] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);

    testCase.verifyLessThan(norm(P_new - P_new', 'fro'), 1e-9, ...
        'P_new is not symmetric.');
    testCase.verifyGreaterThanOrEqual(min(eig(P_new)), -1e-9, ...
        'P_new is significantly non-PSD.');
end


function test_nis_present(testCase)
    [par, cfg] = default_ekf_params();

    x = [0.3; 0.02];
    P = eye(2);
    u = [15; 0.03; -0.02; 0.01; 0.0];
    z = [0.06; 0.015];

    [~, ~, diag] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);

    testCase.verifyEqual(numel(diag.NIS), 1);
    testCase.verifyTrue(isfinite(diag.NIS));
    testCase.verifyGreaterThanOrEqual(diag.NIS, 0);
end


function test_measurement_h1_matches_sumFy_over_m_for_zero_state(testCase)
    [par, cfg] = default_ekf_params();

    x = [0; 0];
    P = eye(2) * 0.1;
    vx = 15;
    deltas = 0;
    u = [vx; deltas; deltas; deltas; deltas];
    z = [0; 0];

    [~, ~, diag] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);

    h1_meas = -diag.innovation(1);
    h1_expected = (diag.Fy_FL * cos(deltas) + diag.Fy_FR * cos(deltas) + diag.Fy_RL + diag.Fy_RR) / par.m;

    testCase.verifyLessThanOrEqual(abs(h1_meas - h1_expected), 1e-9);
    testCase.verifyTrue(isfinite(h1_meas));
    testCase.verifyTrue(isfinite(h1_expected));
end


function test_single_step_stability(testCase)
    [par, cfg] = default_ekf_params();

    x = [0.0; 0.0];
    P = eye(2) * 0.5;

    N = 200;
    maxState = 0;

    for k = 1:N
        steerL = 0.02 * sin(0.1 * k);
        steerR = -0.02 * cos(0.07 * k);
        vx = 20 + 2 * sin(0.03 * k);

        u = [vx; steerL; steerR; steerL / 2; -steerR / 2];
        z = [0.04 * sin(0.2 * k); 0.01 * cos(0.15 * k)];

        [x, P, diag] = vy_dynamic_ekf_step(x, P, u, z, par, cfg);

        testCase.verifyTrue(all(isfinite(x)), 'State became non-finite.');
        testCase.verifyTrue(all(isfinite(P(:))), 'Covariance became non-finite.');
        testCase.verifyLessThan(norm(x), 200, 'Single-step stability failed: state exploded.');
        testCase.verifyLessThan(norm(P, 'fro'), 1e3, 'Covariance exploded.');
        testCase.verifyTrue(isfinite(diag.NIS), 'NIS non-finite during iteration.');

        maxState = max(maxState, norm(x));
    end

    testCase.verifyLessThan(maxState, 200);
end


function [par, cfg] = default_ekf_params()
    par = struct();
    par.m = 1860;
    par.Iz = 2687.1;
    par.a = 1.18;
    par.b = 1.77;
    par.track = 1.575;
    par.Rw = 0.393;

    cfg = struct();
    cfg.dt = 0.01;
    cfg.Q = diag([1e-4, 1e-3]);
    cfg.R = diag([1e-2, 1e-2]);
    cfg.denomEps = 1e-12;
    cfg.lambda = zeros(4, 1);
end
