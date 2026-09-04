function report = run_vy_dkekf_v2_2b_unit_tests()
%RUN_VY_DKEKF_V2_2B_UNIT_TESTS Run pure-MATLAB V2.2-B acceptance tests.

testsDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testsDir);
modelDir = fullfile(projectRoot,'model');
resultsDir = fullfile(projectRoot,'results');
addpath(modelDir);
addpath(testsDir);

core = test_vy_dkekf_baseline_step();
wrapper = test_vy_dkekf_baseline_wrapper();
report = struct();
report.stage = 'V2.2-B';
report.passed = core.passed && wrapper.passed;
report.core = core;
report.wrapper = wrapper;
report.testCount = core.tests + wrapper.tests;
report.simCalled = false;
report.carSimRun = false;
report.timestamp = datetime('now','TimeZone','local');

assert(report.passed, 'V2.2-B unit tests did not pass.');
resultPath = fullfile(resultsDir,'vy_dkekf_v2_2b_unit_tests.mat');
save(resultPath,'report');
fprintf(['V2_2B_UNIT_TESTS_OK|tests=%d|passed=%d|' ...
    'simCalled=%d|carSimRun=%d|result=%s\n'], ...
    report.testCount, report.passed, report.simCalled, ...
    report.carSimRun, resultPath);
end
