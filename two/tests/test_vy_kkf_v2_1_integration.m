function report = test_vy_kkf_v2_1_integration()
%TEST_VY_KKF_V2_1_INTEGRATION No-write compile/static audit of V2.1-B.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'matlab'));
addpath(fullfile(root, 'tests'));

scripts = { ...
    fullfile(root, 'matlab', 'validate_vy_kkf_v2_1_integration.m'), ...
    [mfilename('fullpath') '.m']};
for k = 1:numel(scripts)
    text = fileread(scripts{k});
    assert(isempty(regexp(text, '(?<![A-Za-z])sim\s*\(', 'once')), ...
        'Execution call is forbidden in V2.1-B: %s', scripts{k});
    assert(isempty(regexpi(text, 'SimulationCommand\s*''\s*,\s*''start', 'once')), ...
        'SimulationCommand start is forbidden in V2.1-B: %s', scripts{k});
end

buildReportFile = fullfile(root, 'results', ...
    'vy_kkf_v2_1b_build_report.mat');
if ~isfile(buildReportFile)
    error(['Existing V2.1-B build report is required. Run ' ...
        'build_vy_kkf_v2_1_model explicitly before the integration test.']);
end
savedBuild = load(buildReportFile, 'report');
assert(isfield(savedBuild, 'report') && isstruct(savedBuild.report), ...
    'Existing V2.1-B build report does not contain a valid report struct.');
build = savedBuild.report;
validation = validate_vy_kkf_v2_1_integration(build);
assert(validation.passed, 'V2.1-B compile audit failed.');

gates = struct();
gates.modelCreated = isfile(build.targetFile);
gates.sourcePrereqHashUnchanged = frozen_ok(build, 'vx_ax_imu_prereq_v2_1.slx');
gates.vxHashUnchanged = frozen_ok(build, 'vx.slx');
gates.dekfHashUnchanged = frozen_ok(build, 'vx_vy_dekf_v1_17.slx');
gates.functionCallSubsystem = ...
    validation.functionCallTriggerTypeOK && ...
    validation.schedulerMaskTypeOK && ...
    validation.schedulerConnectionOK;
gates.parent100Hz = isequal(validation.parentCst, [0.01 0]);
gates.ax100Hz = isequal(validation.axCst, [0.01 0]);
gates.ay100Hz = isequal(validation.ayCst, [0.01 0]);
gates.avz100Hz = isequal(validation.avzCst, [0.01 0]);
gates.vxBoundary100Hz = isequal(validation.vxBoundaryCst, [0.01 0]);
gates.vxRateBoundary = isequal(validation.vxRawCst, [0.001 0]);
gates.inputOrder = isequal(validation.inputOrder, {'Ax_IMU','Ay_IMU','AVz_IMU'});
gates.xDimension = isequal(validation.outputShapes{1}, 2);
gates.pDimension = isequal(validation.outputShapes{2}, [2 2]);
gates.diagDimension = isequal(validation.outputShapes{3}, 5);
gates.resetStructure = validation.resetStaticVerified && ~validation.resetRuntimeVerified;
gates.noTrueVy = ~validation.trueVyConnected;
gates.noDekf = ~validation.dekfDependency;
gates.coreFrozen = strcmp(validation.coreHash, ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244');
gates.wrapperFrozen = strcmp(validation.wrapperHash, ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4');
gates.noExecutionCall = ~validation.simCalled;
gates.noCarSim = ~validation.carSimRun;

gateNames = fieldnames(gates);
for k = 1:numel(gateNames)
    assert(gates.(gateNames{k}), 'Hard gate failed: %s', gateNames{k});
end

report = struct();
report.passed = true;
report.gates = gates;
report.gateCount = numel(gateNames);
report.build = build;
report.validation = validation;
report.simCalled = false;
report.carSimRun = false;
save(fullfile(root, 'results', 'vy_kkf_v2_1b_integration_test.mat'), 'report');

fprintf('V2_1B_INTEGRATION_TEST_OK|gates=%d|sim=0|carsim=0\n', ...
    report.gateCount);
end

function ok = frozen_ok(build, fileName)
ok = false;
for k = 1:numel(build.frozenBefore)
    [~, n, e] = fileparts(build.frozenBefore(k).path);
    if strcmp([n e], fileName)
        ok = strcmp(build.frozenBefore(k).sha256, build.frozenAfter(k).sha256);
        return
    end
end
end
