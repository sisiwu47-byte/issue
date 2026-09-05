function report = build_ax_imu_prereq_v2_1_model()
%BUILD_AX_IMU_PREREQ_V2_1_MODEL Create an isolated Ax_IMU-only model copy.
%
% This builder does not create or connect a K-KF and never saves vx.slx.

root = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(root, 'model', 'vx.slx');
targetFile = fullfile(root, 'model', 'vx_ax_imu_prereq_v2_1.slx');
assert(isfile(sourceFile), 'Missing source model: %s', sourceFile);

sourceInfoBefore = dir(sourceFile);
sourceHashBefore = file_sha256(sourceFile);
copyfile(sourceFile, targetFile, 'f');

addpath(fullfile(root, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(root, 'results', 'simulink_cache_ax_imu_prereq_v2_1'), ...
    'CodeGenFolder', fullfile(root, 'results', 'simulink_codegen_ax_imu_prereq_v2_1'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(targetFile);
[~, modelName] = fileparts(targetFile);

newNames = {'Ax IMU Input RT 100Hz','Ax IMU Sensor 100Hz', ...
    'Ax IMU White Noise','Ax IMU Bias','Ax IMU Reset', ...
    'Ax IMU Goto','Ax IMU Log','Ax Clean 100Hz Log'};
for k = 1:numel(newNames)
    assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
        'Name', newNames{k})), 'Prerequisite block already exists: %s', newNames{k});
end

% Resolve the existing Ay sensor and its three auxiliary source templates
% by tracing the exact Ay_IMU output line. This avoids dependence on the
% localized subsystem name.
ayLine = find_named_lines(modelName, 'Ay_IMU');
assert(numel(ayLine) == 1, 'Expected exactly one Ay_IMU line.');
aySensorHandle = get_param(ayLine, 'SrcBlockHandle');
aySensorPath = getfullname(aySensorHandle);
ayPorts = get_param(aySensorHandle, 'PortHandles');
assert(numel(ayPorts.Inport) == 4 && numel(ayPorts.Outport) == 1, ...
    'Ay sensor template must have four inputs and one output.');
templatePaths = cell(3,1);
for k = 1:3
    lineHandle = get_param(ayPorts.Inport(k+1), 'Line');
    templatePaths{k} = getfullname(get_param(lineHandle, 'SrcBlockHandle'));
end

axSourcePath = [modelName '/Gain28'];
assert(getSimulinkBlockHandle(axSourcePath) > 0, 'Missing clean Ax source Gain28.');
assert(abs(str2double(get_param(axSourcePath, 'Gain')) - 9.8) <= eps(9.8), ...
    'Gain28 must retain the g-to-m/s^2 conversion gain 9.8.');

rtPath = [modelName '/Ax IMU Input RT 100Hz'];
sensorPath = [modelName '/Ax IMU Sensor 100Hz'];
noisePath = [modelName '/Ax IMU White Noise'];
biasPath = [modelName '/Ax IMU Bias'];
resetPath = [modelName '/Ax IMU Reset'];
gotoPath = [modelName '/Ax IMU Goto'];
logPath = [modelName '/Ax IMU Log'];
cleanLogPath = [modelName '/Ax Clean 100Hz Log'];

add_block('simulink/Signal Attributes/Rate Transition', rtPath, ...
    'Position', [3330 900 3435 930], ...
    'OutPortSampleTime', '0.01', ...
    'Integrity', 'on', 'Deterministic', 'on', 'InitialCondition', '0');
add_block(aySensorPath, sensorPath, 'Position', [3610 870 3745 970]);
add_block(templatePaths{1}, noisePath, 'Position', [3480 900 3520 930]);
set_param(noisePath, 'Seed', '20260820');
add_block(templatePaths{2}, biasPath, 'Position', [3480 935 3520 965]);
add_block(templatePaths{3}, resetPath, 'Position', [3480 970 3520 1000]);
add_block('simulink/Signal Routing/Goto', gotoPath, ...
    'Position', [3910 875 3995 905], 'GotoTag', 'Ax_IMU', ...
    'TagVisibility', 'local');
add_block('simulink/Sinks/To Workspace', logPath, ...
    'Position', [3910 920 4025 950], ...
    'VariableName', 'ax_imu_prereq_log1', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', cleanLogPath, ...
    'Position', [3480 840 3620 870], ...
    'VariableName', 'ax_clean_100hz_prereq_log1', 'SaveFormat', 'Timeseries');

% Replace only the copied chart implementation. The original Ay chart is
% untouched. Persistent state and reset behavior live in the standalone,
% unit-tested imu_ax_preprocess.m function.
rt = sfroot;
charts = rt.find('-isa', 'Stateflow.EMChart');
targetChart = [];
for k = 1:numel(charts)
    if strcmp(charts(k).Path, sensorPath)
        targetChart = charts(k);
        break
    end
end
assert(~isempty(targetChart), 'Copied Ax sensor MATLAB Function chart not found.');
targetChart.Script = sprintf([ ...
    'function axOut = imu_ax_preprocess_chart(axCarsim, whiteNoise, biasInput, resetFlag)\n' ...
    '%%#codegen\n' ...
    'axOut = imu_ax_preprocess(axCarsim, whiteNoise, biasInput, resetFlag);\n' ...
    'end\n']);

sourcePorts = get_param(axSourcePath, 'PortHandles');
rtPorts = get_param(rtPath, 'PortHandles');
sensorPorts = get_param(sensorPath, 'PortHandles');
noisePorts = get_param(noisePath, 'PortHandles');
biasPorts = get_param(biasPath, 'PortHandles');
resetPorts = get_param(resetPath, 'PortHandles');
gotoPorts = get_param(gotoPath, 'PortHandles');
logPorts = get_param(logPath, 'PortHandles');
cleanLogPorts = get_param(cleanLogPath, 'PortHandles');

add_line(modelName, sourcePorts.Outport(1), rtPorts.Inport(1), 'autorouting', 'on');
add_line(modelName, rtPorts.Outport(1), sensorPorts.Inport(1), 'autorouting', 'on');
add_line(modelName, rtPorts.Outport(1), cleanLogPorts.Inport(1), 'autorouting', 'on');
add_line(modelName, noisePorts.Outport(1), sensorPorts.Inport(2), 'autorouting', 'on');
add_line(modelName, biasPorts.Outport(1), sensorPorts.Inport(3), 'autorouting', 'on');
add_line(modelName, resetPorts.Outport(1), sensorPorts.Inport(4), 'autorouting', 'on');
outputLine = add_line(modelName, sensorPorts.Outport(1), gotoPorts.Inport(1), ...
    'autorouting', 'on');
set_param(outputLine, 'Name', 'Ax_IMU');
add_line(modelName, sensorPorts.Outport(1), logPorts.Inport(1), 'autorouting', 'on');

wks = get_param(modelName, 'ModelWorkspace');
assignin(wks, 'ax_imu_prereq_Ts', 0.01);
assignin(wks, 'ax_imu_prereq_fc', 20.0);
assignin(wks, 'ax_imu_prereq_bias', 0.02);
assignin(wks, 'ax_imu_prereq_noise_variance', 2.5e-5);

set_param(modelName, 'Dirty', 'on');
save_system(modelName, targetFile);
close_system(modelName, 0);
close_system('Solver_SF', 0);

sourceInfoAfter = dir(sourceFile);
sourceHashAfter = file_sha256(sourceFile);
assert(strcmp(sourceHashBefore, sourceHashAfter), 'Source vx.slx changed.');
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes, 'Source vx.slx size changed.');

report = struct();
report.sourceFile = sourceFile;
report.targetFile = targetFile;
report.sourceHashBefore = sourceHashBefore;
report.sourceHashAfter = sourceHashAfter;
report.sensorPath = sensorPath;
report.cleanAxSource = axSourcePath;
report.signalName = 'Ax_IMU';
report.Ts = 0.01;
report.fc = 20.0;
report.bias = 0.02;
report.whiteNoiseVariance = 2.5e-5;
report.whiteNoiseSeed = 20260820;
report.noKkfCreated = true;

fprintf('AX_IMU_BUILD_OK|copy=%s|sensor=%s|signal=Ax_IMU\n', ...
    targetFile, sensorPath);
fprintf('SOURCE_HASH|%s\n', sourceHashAfter);
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
