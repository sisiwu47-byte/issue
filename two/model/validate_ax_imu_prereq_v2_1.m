function report = validate_ax_imu_prereq_v2_1()
%VALIDATE_AX_IMU_PREREQ_V2_1 Build, compile, and briefly run Ax_IMU only.

root = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(root, 'results');
addpath(fullfile(root, 'matlab'));
addpath(fullfile(root, 'tests'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

unit = test_imu_ax_preprocess();
assert(unit.passed, 'Ax_IMU unit test failed.');
build = build_ax_imu_prereq_v2_1_model();

Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(resultDir, 'simulink_cache_ax_imu_prereq_v2_1'), ...
    'CodeGenFolder', fullfile(resultDir, 'simulink_codegen_ax_imu_prereq_v2_1'), ...
    'createDir', true);
load_system('Solver_SF');
load_system(build.targetFile);
[~, modelName] = fileparts(build.targetFile);

set_param(modelName, 'SimulationCommand', 'update');
sensorCst = get_param(build.sensorPath, 'CompiledSampleTime');
assert(isequal(sensorCst, [0.01 0]), ...
    'Ax_IMU sensor CompiledSampleTime is not [0.01 0].');

axLines = find_named_lines(modelName, 'Ax_IMU');
assert(~isempty(axLines), 'Expected at least one Ax_IMU signal branch.');
axSources = cell(numel(axLines),1);
for k = 1:numel(axLines)
    axSources{k} = getfullname(get_param(axLines(k), 'SrcBlockHandle'));
end
assert(all(strcmp(axSources, build.sensorPath)), ...
    'Every Ax_IMU branch must originate from the new sensor.');
src = build.sensorPath;

sensorPorts = get_param(build.sensorPath, 'PortHandles');
inputLine = get_param(sensorPorts.Inport(1), 'Line');
inputSource = getfullname(get_param(inputLine, 'SrcBlockHandle'));
assert(endsWith(inputSource, '/Ax IMU Input RT 100Hz'), ...
    'Ax_IMU clean input does not pass through the 100 Hz rate transition.');

assert(isempty(find_system(modelName, 'RegExp', 'on', ...
    'Name', '(?i).*K[-_ ]?KF.*')), 'K-KF block must not exist.');
set_param(modelName, 'SimulationCommand', 'stop');

[axImuLog, axCleanLog] = run_isolated_harness(build.sensorPath);
assert(isa(axImuLog, 'timeseries') && isa(axCleanLog, 'timeseries'), ...
    'Ax prerequisite logs must be timeseries.');
assert(numel(axImuLog.Time) >= 20, 'Short validation log has too few samples.');
assert(abs(median(diff(double(axImuLog.Time))) - 0.01) <= 1e-12, ...
    'Ax_IMU log is not sampled at 100 Hz.');
assert(all(isfinite(double(axImuLog.Data(:)))), 'Ax_IMU log contains NaN/Inf.');
assert(all(isfinite(double(axCleanLog.Data(:)))), 'Clean Ax log contains NaN/Inf.');

close_system(modelName, 0);
close_system('Solver_SF', 0);

sourceHashAfterValidation = file_sha256(build.sourceFile);
assert(strcmp(sourceHashAfterValidation, build.sourceHashBefore), ...
    'Source vx.slx changed during validation.');

report = struct();
report.passed = true;
report.unit = unit;
report.build = build;
report.sensorCompiledSampleTime = sensorCst;
report.axImuSignalCount = numel(axLines);
report.axImuSource = src;
report.axInputSource = inputSource;
report.logSampleCount = numel(axImuLog.Time);
report.logMedianDt = median(diff(double(axImuLog.Time)));
report.logFinite = true;
report.noKkfCreated = true;
report.sourceHashAfterValidation = sourceHashAfterValidation;
report.axImuTime = double(axImuLog.Time(:));
report.axImuData = double(axImuLog.Data(:));
report.axCleanTime = double(axCleanLog.Time(:));
report.axCleanData = double(axCleanLog.Data(:));

save(fullfile(resultDir, 'ax_imu_prereq_v2_1_validation.mat'), 'report');
fprintf(['AX_IMU_VALIDATION_OK|CST=%s|samples=%d|dt=%.12g|' ...
    'finite=1|no_kkf=1\n'], mat2str(sensorCst), report.logSampleCount, ...
    report.logMedianDt);
end

function [axImuLog, axCleanLog] = run_isolated_harness(sensorTemplate)
% Execute only the Ax sensor, without the external CarSim solver.
harness = 'ax_imu_prereq_v2_1_harness';
if bdIsLoaded(harness)
    close_system(harness, 0);
end
new_system(harness);
cleanup = onCleanup(@() close_harness(harness));
set_param(harness, 'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', 'FixedStep', '0.01', 'StopTime', '0.20');

sensor = [harness '/Ax IMU Sensor 100Hz'];
clean = [harness '/Clean Ax'];
noise = [harness '/White Noise Input'];
bias = [harness '/Bias Input'];
reset = [harness '/Reset Input'];
outLog = [harness '/Ax IMU Log'];
cleanLog = [harness '/Clean Ax Log'];

add_block(sensorTemplate, sensor, 'Position', [260 80 400 180]);
add_block('simulink/Sources/Constant', clean, ...
    'Position', [40 75 90 105], 'Value', '1.0', 'SampleTime', '0.01');
add_block('simulink/Sources/Constant', noise, ...
    'Position', [40 115 90 145], 'Value', '0.0', 'SampleTime', '0.01');
add_block('simulink/Sources/Constant', bias, ...
    'Position', [40 155 90 185], 'Value', '0.02', 'SampleTime', '0.01');
add_block('simulink/Sources/Step', reset, ...
    'Position', [40 195 90 225], 'Time', '0.01', ...
    'Before', '1', 'After', '0', 'SampleTime', '0.01');
add_block('simulink/Sinks/To Workspace', outLog, ...
    'Position', [480 90 590 120], ...
    'VariableName', 'ax_imu_harness_log', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', cleanLog, ...
    'Position', [130 30 240 60], ...
    'VariableName', 'ax_clean_harness_log', 'SaveFormat', 'Timeseries');

add_line(harness, 'Clean Ax/1', 'Ax IMU Sensor 100Hz/1', 'autorouting', 'on');
add_line(harness, 'Clean Ax/1', 'Clean Ax Log/1', 'autorouting', 'on');
add_line(harness, 'White Noise Input/1', 'Ax IMU Sensor 100Hz/2', 'autorouting', 'on');
add_line(harness, 'Bias Input/1', 'Ax IMU Sensor 100Hz/3', 'autorouting', 'on');
add_line(harness, 'Reset Input/1', 'Ax IMU Sensor 100Hz/4', 'autorouting', 'on');
add_line(harness, 'Ax IMU Sensor 100Hz/1', 'Ax IMU Log/1', 'autorouting', 'on');

clear imu_ax_preprocess
out = sim(harness, 'ReturnWorkspaceOutputs', 'on');
axImuLog = out.get('ax_imu_harness_log');
axCleanLog = out.get('ax_clean_harness_log');
assert(max(abs(double(axImuLog.Data(:)) - 1.02)) <= 1e-12, ...
    'Isolated harness did not preserve clean Ax plus bias.');
clear cleanup
close_system(harness, 0);
end

function close_harness(harness)
if bdIsLoaded(harness)
    close_system(harness, 0);
end
end

function lineHandles = find_named_lines(modelName, signalName)
allLines = find_system(modelName, 'FindAll', 'on', 'Type', 'line');
lineHandles = [];
for k = 1:numel(allLines)
    try
        if strcmp(get_param(allLines(k), 'Name'), signalName)
            lineHandles(end+1) = allLines(k); %#ok<AGROW>
        end
    catch
    end
end
end

function hashText = file_sha256(filePath)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(filePath));
digestStream = java.security.DigestInputStream(stream, digest);
cleanup = onCleanup(@() digestStream.close());
while digestStream.read() ~= -1
end
bytes = typecast(digest.digest(), 'uint8');
hashText = lower(reshape(dec2hex(bytes, 2).', 1, []));
clear cleanup
end
