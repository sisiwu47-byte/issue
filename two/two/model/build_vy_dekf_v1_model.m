function report = build_vy_dekf_v1_model()
%BUILD_VY_DEKF_V1_MODEL Create the V1 D-EKF model copy with a true 100 Hz task.
%
% The source model is never saved. The existing interpreted MATLAB
% function that calls vy_dynamic_ekf(u) is copied into a 100 Hz
% Function-Call Subsystem. Explicit Rate Transition blocks bridge the
% 1 kHz vehicle model and the 100 Hz estimator task in both directions.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoRoot, 'model');
sourceFile = fullfile(modelDir, 'vx.slx');
copyFile = fullfile(modelDir, 'vx_vy_dekf_v1.slx');

assert(isfile(sourceFile), 'Source model is missing: %s', sourceFile);

sourceInfoBefore = dir(sourceFile);
sourceHashBefore = file_sha256(sourceFile);

copyfile(sourceFile, copyFile, 'f');

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

cacheDir = fullfile(repoRoot, 'results', 'simulink_cache_vy_v1');
codegenDir = fullfile(repoRoot, 'results', 'simulink_codegen_vy_v1');
Simulink.fileGenControl('set', 'CacheFolder', cacheDir, ...
    'CodeGenFolder', codegenDir, 'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(copyFile);
[~, modelName] = fileparts(copyFile);

estimatorBlocks = find_system(modelName, ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', ...
    'BlockType', 'MATLABFcn');
isTarget = false(size(estimatorBlocks));
for k = 1:numel(estimatorBlocks)
    isTarget(k) = contains(get_param(estimatorBlocks{k}, 'MATLABFcn'), ...
        'vy_dynamic_ekf');
end
targetBlocks = estimatorBlocks(isTarget);
assert(numel(targetBlocks) == 1, ...
    'Expected one vy_dynamic_ekf wrapper block; found %d.', ...
    numel(targetBlocks));
oldEstimator = targetBlocks{1};

oldPosition = get_param(oldEstimator, 'Position');
oldPorts = get_param(oldEstimator, 'PortHandles');
assert(numel(oldPorts.Inport) == 1 && numel(oldPorts.Outport) == 1, ...
    'The existing D-EKF wrapper must have one input and one output.');

inputLine = get_param(oldPorts.Inport(1), 'Line');
outputLine = get_param(oldPorts.Outport(1), 'Line');
assert(inputLine >= 0 && outputLine >= 0, ...
    'The existing D-EKF wrapper must be fully connected.');
sourcePort = get_param(inputLine, 'SrcPortHandle');
destinationPorts = get_param(outputLine, 'DstPortHandle');
sourceBlock = getfullname(get_param(inputLine, 'SrcBlockHandle'));
destinationBlocks = get_param(outputLine, 'DstBlockHandle');
destinationBlockNames = arrayfun(@getfullname, destinationBlocks, ...
    'UniformOutput', false);

subsystemPath = [modelName '/Vy D-EKF 100Hz'];
inputRatePath = [modelName '/D-EKF Input RT 100Hz'];
outputRatePath = [modelName '/D-EKF Output RT 1kHz'];
generatorPath = [modelName '/D-EKF 100Hz Scheduler'];

assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
    'Name', 'Vy D-EKF 100Hz')), 'V1 rate-domain blocks already exist.');

subPosition = oldPosition + [-10, -25, 130, 25];
inputRatePosition = oldPosition + [-150, 0, -70, 0];
outputRatePosition = oldPosition + [190, 0, 280, 0];
generatorPosition = oldPosition + [0, -130, 120, -90];

add_block('simulink/Ports & Subsystems/Function-Call Subsystem', ...
    subsystemPath, 'Position', subPosition);
add_block('simulink/Signal Attributes/Rate Transition', ...
    inputRatePath, 'Position', inputRatePosition, ...
    'OutPortSampleTime', '0.01', ...
    'Integrity', 'on', ...
    'Deterministic', 'on', ...
    'InitialCondition', '0');
add_block('simulink/Signal Attributes/Rate Transition', ...
    outputRatePath, 'Position', outputRatePosition, ...
    'OutPortSampleTime', '0.001', ...
    'Integrity', 'on', ...
    'Deterministic', 'on', ...
    'InitialCondition', '0');
add_block('simulink/Ports & Subsystems/Function-Call Generator', ...
    generatorPath, 'Position', generatorPosition, ...
    'sample_time', '0.01', ...
    'numberOfIterations', '1');

internalLines = find_system(subsystemPath, 'FindAll', 'on', ...
    'SearchDepth', 1, 'Type', 'line');
for k = 1:numel(internalLines)
    delete_line(internalLines(k));
end

internalEstimator = [subsystemPath '/vy_dynamic_ekf'];
add_block(oldEstimator, internalEstimator, ...
    'Position', [150, 75, 290, 125]);
set_param(internalEstimator, 'SampleTime', '-1');
set_param([subsystemPath '/In1'], 'Position', [30, 88, 60, 102]);
set_param([subsystemPath '/Out1'], 'Position', [380, 88, 410, 102]);
set_param([subsystemPath '/function'], 'Position', [185, 20, 255, 50]);

add_line(subsystemPath, 'In1/1', 'vy_dynamic_ekf/1', 'autorouting', 'on');
add_line(subsystemPath, 'vy_dynamic_ekf/1', 'Out1/1', 'autorouting', 'on');

delete_line(inputLine);
delete_line(outputLine);
delete_block(oldEstimator);

inputRatePorts = get_param(inputRatePath, 'PortHandles');
outputRatePorts = get_param(outputRatePath, 'PortHandles');
subsystemPorts = get_param(subsystemPath, 'PortHandles');
generatorPorts = get_param(generatorPath, 'PortHandles');

add_line(modelName, sourcePort, inputRatePorts.Inport(1), 'autorouting', 'on');
add_line(modelName, inputRatePorts.Outport(1), subsystemPorts.Inport(1), ...
    'autorouting', 'on');
add_line(modelName, generatorPorts.Outport(1), subsystemPorts.Trigger(1), ...
    'autorouting', 'on');
add_line(modelName, subsystemPorts.Outport(1), outputRatePorts.Inport(1), ...
    'autorouting', 'on');
for k = 1:numel(destinationPorts)
    add_line(modelName, outputRatePorts.Outport(1), destinationPorts(k), ...
        'autorouting', 'on');
end

set_param(modelName, 'Dirty', 'on');
save_system(modelName, copyFile);
close_system(modelName, 0);
close_system('Solver_SF', 0);

sourceInfoAfter = dir(sourceFile);
sourceHashAfter = file_sha256(sourceFile);
assert(strcmp(sourceHashBefore, sourceHashAfter), ...
    'Source vx.slx changed unexpectedly.');
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes, ...
    'Source vx.slx size changed unexpectedly.');

report = struct();
report.sourceFile = sourceFile;
report.copyFile = copyFile;
report.sourceHashBefore = sourceHashBefore;
report.sourceHashAfter = sourceHashAfter;
report.oldEstimator = oldEstimator;
report.inputSource = sourceBlock;
report.outputDestinations = destinationBlockNames;
report.newSubsystem = subsystemPath;
report.inputRateTransition = inputRatePath;
report.outputRateTransition = outputRatePath;
report.scheduler = generatorPath;
report.internalEstimator = internalEstimator;

fprintf('BUILD_OK|copy=%s\n', copyFile);
fprintf('SOURCE_HASH|%s\n', sourceHashAfter);
fprintf('OLD_BLOCK|%s\n', oldEstimator);
fprintf('NEW_BLOCK|%s\n', internalEstimator);
fprintf('RATE_PATH|%s -> %s -> %s -> %s\n', ...
    inputRatePath, subsystemPath, outputRatePath, destinationBlockNames{1});
end

function hashText = file_sha256(filePath)
digest = java.security.MessageDigest.getInstance('SHA-256');
fileStream = java.io.FileInputStream(java.io.File(filePath));
digestStream = java.security.DigestInputStream(fileStream, digest);
cleanup = onCleanup(@() digestStream.close());
while digestStream.read() ~= -1
end
bytes = typecast(digest.digest(), 'uint8');
hashText = lower(reshape(dec2hex(bytes, 2).', 1, []));
clear cleanup;
end
