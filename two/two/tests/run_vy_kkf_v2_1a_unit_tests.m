function report = run_vy_kkf_v2_1a_unit_tests()
%RUN_VY_KKF_V2_1A_UNIT_TESTS Run only the pure MATLAB V2.1-A tests.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'matlab'));
addpath(fullfile(root, 'tests'));

core = test_vy_kinematic_kf_step();
wrapper = test_vy_kinematic_kf_wrapper();
assert(core.passed && wrapper.passed, 'V2.1-A unit-test suite failed.');

report = struct();
report.passed = true;
report.core = core;
report.wrapper = wrapper;
report.totalTests = core.tests + wrapper.tests;
report.simulinkUsed = false;
report.carSimUsed = false;

save(fullfile(root, 'results', 'vy_kkf_v2_1a_unit_tests.mat'), 'report');
fprintf('V2_1A_TEST_SUITE_OK|total=%d|simulink=0|carsim=0\n', ...
    report.totalTests);
end
