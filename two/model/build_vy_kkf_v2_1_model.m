function report = build_vy_kkf_v2_1_model()
%BUILD_VY_KKF_V2_1_MODEL Build the isolated V2.1-B integration model.
%
% This function only creates a model copy and edits that copy. It does not
% update/compile the diagram and does not execute the model.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root, 'model');
sourceFile = fullfile(modelDir, 'vx_ax_imu_prereq_v2_1.slx');
targetFile = fullfile(modelDir, 'vx_vy_kkf_v2_1.slx');
vxFile = fullfile(modelDir, 'vx.slx');
dekfFile = fullfile(modelDir, 'vx_vy_dekf_v1_17.slx');
coreFile = fullfile(root, 'matlab', 'vy_kinematic_kf_step.m');
wrapperFile = fullfile(root, 'matlab', 'vy_kinematic_kf.m');

required = {sourceFile, vxFile, dekfFile, coreFile, wrapperFile};
for k = 1:numel(required)
    assert(isfile(required{k}), 'Required file is missing: %s', required{k});
end

before = snapshot(required);
copyfile(sourceFile, targetFile, 'f');

addpath(fullfile(root, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(root, 'results', 'simulink_cache_vy_kkf_v2_1b'), ...
    'CodeGenFolder', fullfile(root, 'results', 'simulink_codegen_vy_kkf_v2_1b'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(targetFile);
[~, modelName] = fileparts(targetFile);

names = {'K-KF 100Hz','K-KF 100Hz Scheduler','K-KF IMU Mux', ...
    'K-KF Vx RT 100Hz','K-KF Reset First Call','K-KF Input Log Mux', ...
    'K-KF u Log','K-KF x Log','K-KF P Log','K-KF diag Log'};
for k = 1:numel(names)
    assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
        'Name', names{k})), 'Integration block already exists: %s', names{k});
end

axSource = unique_signal_source(modelName, 'Ax_IMU');
aySource = unique_signal_source(modelName, 'Ay_IMU');
avzSource = unique_signal_source(modelName, 'AVz_IMU');
vxSource = [modelName '/Gain38'];
assert(getSimulinkBlockHandle(vxSource) > 0, 'true Vx source Gain38 is missing.');
assert(strcmp(get_param(vxSource, 'Gain'), '1/3.6'), ...
    'Gain38 must retain the km/h-to-m/s conversion.');

% The prerequisite model has no reusable function-call event. Add a local,
% independent 100 Hz event without altering any existing controller path.
subPath = [modelName '/K-KF 100Hz'];
schedulerPath = [modelName '/K-KF 100Hz Scheduler'];
imuMuxPath = [modelName '/K-KF IMU Mux'];
vxRtPath = [modelName '/K-KF Vx RT 100Hz'];
resetPath = [modelName '/K-KF Reset First Call'];
inputLogMuxPath = [modelName '/K-KF Input Log Mux'];
uLogPath = [modelName '/K-KF u Log'];
xLogPath = [modelName '/K-KF x Log'];
pLogPath = [modelName '/K-KF P Log'];
diagLogPath = [modelName '/K-KF diag Log'];

add_block('simulink/Ports & Subsystems/Function-Call Subsystem', subPath, ...
    'Position', [3670 1190 3850 1325]);
add_block('simulink/Ports & Subsystems/Function-Call Generator', schedulerPath, ...
    'Position', [3440 1100 3565 1135], ...
    'sample_time', '0.01', 'numberOfIterations', '1');
add_block('simulink/Signal Routing/Mux', imuMuxPath, ...
    'Position', [3485 1180 3490 1260], 'Inputs', '3');
add_block('simulink/Signal Attributes/Rate Transition', vxRtPath, ...
    'Position', [3370 1280 3495 1315], ...
    'OutPortSampleTime', '0.01', 'Integrity', 'on', ...
    'Deterministic', 'on', 'InitialCondition', '0');
add_block('simulink/Sources/Step', resetPath, ...
    'Position', [3470 1340 3520 1370], ...
    'Time', '0.01', 'Before', '1', 'After', '0', 'SampleTime', '0.01');
add_block('simulink/Signal Routing/Mux', inputLogMuxPath, ...
    'Position', [3895 1150 3900 1250], 'Inputs', '4');
add_block('simulink/Sinks/To Workspace', uLogPath, ...
    'Position', [3990 1160 4110 1190], ...
    'VariableName', 'kkf_u_log1', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', xLogPath, ...
    'Position', [3990 1260 4110 1290], ...
    'VariableName', 'kkf_x_log1', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', pLogPath, ...
    'Position', [3990 1300 4110 1330], ...
    'VariableName', 'kkf_P_log1', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', diagLogPath, ...
    'Position', [3990 1340 4110 1370], ...
    'VariableName', 'kkf_diag_log1', 'SaveFormat', 'Timeseries');

% Configure the Function-Call Subsystem ports and call only the frozen
% wrapper. No filter mathematics is duplicated inside the model.
internalLines = find_system(subPath, 'FindAll', 'on', ...
    'SearchDepth', 1, 'Type', 'line');
for k = 1:numel(internalLines)
    delete_line(internalLines(k));
end
set_param([subPath '/In1'], 'Name', 'u', 'Port', '1', ...
    'Position', [25 72 55 88]);
set_param([subPath '/Out1'], 'Name', 'x_hat', 'Port', '1', ...
    'Position', [405 70 435 90]);
add_block('simulink/Ports & Subsystems/In1', [subPath '/Vx_meas'], ...
    'Port', '2', 'Position', [25 117 55 133]);
add_block('simulink/Ports & Subsystems/In1', [subPath '/resetFlag'], ...
    'Port', '3', 'Position', [25 162 55 178]);
add_block('simulink/Ports & Subsystems/Out1', [subPath '/P'], ...
    'Port', '2', 'Position', [405 115 435 135]);
add_block('simulink/Ports & Subsystems/Out1', [subPath '/diag_out'], ...
    'Port', '3', 'Position', [405 160 435 180]);
set_param([subPath '/function'], 'Position', [175 15 245 45]);

wrapperBlock = [subPath '/K-KF Wrapper'];
add_block(axSource, wrapperBlock, 'Position', [150 75 310 180]);
set_param(wrapperBlock, 'SystemSampleTime', '-1');
rt = sfroot;
charts = rt.find('-isa', 'Stateflow.EMChart');
targetChart = [];
for k = 1:numel(charts)
    if strcmp(charts(k).Path, wrapperBlock)
        targetChart = charts(k);
        break
    end
end
assert(~isempty(targetChart), 'K-KF MATLAB Function chart was not created.');
targetChart.Script = sprintf([ ...
    'function [x_new,P_new,diag_out] = kkf_wrapper(u,z,resetFlag)\n' ...
    '%%#codegen\n' ...
    '[x_new,P_new,diag_out] = vy_kinematic_kf(u,z,resetFlag);\n' ...
    'end\n']);

add_line(subPath, 'u/1', 'K-KF Wrapper/1', 'autorouting', 'on');
add_line(subPath, 'Vx_meas/1', 'K-KF Wrapper/2', 'autorouting', 'on');
add_line(subPath, 'resetFlag/1', 'K-KF Wrapper/3', 'autorouting', 'on');
add_line(subPath, 'K-KF Wrapper/1', 'x_hat/1', 'autorouting', 'on');
add_line(subPath, 'K-KF Wrapper/2', 'P/1', 'autorouting', 'on');
add_line(subPath, 'K-KF Wrapper/3', 'diag_out/1', 'autorouting', 'on');

axPort = get_param(axSource, 'PortHandles');
ayPort = get_param(aySource, 'PortHandles');
avzPort = get_param(avzSource, 'PortHandles');
vxPort = get_param(vxSource, 'PortHandles');
imuMuxPort = get_param(imuMuxPath, 'PortHandles');
vxRtPort = get_param(vxRtPath, 'PortHandles');
resetPort = get_param(resetPath, 'PortHandles');
subPort = get_param(subPath, 'PortHandles');
schedulerPort = get_param(schedulerPath, 'PortHandles');
inputLogMuxPort = get_param(inputLogMuxPath, 'PortHandles');
uLogPort = get_param(uLogPath, 'PortHandles');
xLogPort = get_param(xLogPath, 'PortHandles');
pLogPort = get_param(pLogPath, 'PortHandles');
diagLogPort = get_param(diagLogPath, 'PortHandles');

add_line(modelName, axPort.Outport(1), imuMuxPort.Inport(1), 'autorouting', 'on');
add_line(modelName, ayPort.Outport(1), imuMuxPort.Inport(2), 'autorouting', 'on');
add_line(modelName, avzPort.Outport(1), imuMuxPort.Inport(3), 'autorouting', 'on');
add_line(modelName, vxPort.Outport(1), vxRtPort.Inport(1), 'autorouting', 'on');
add_line(modelName, imuMuxPort.Outport(1), subPort.Inport(1), 'autorouting', 'on');
add_line(modelName, vxRtPort.Outport(1), subPort.Inport(2), 'autorouting', 'on');
add_line(modelName, resetPort.Outport(1), subPort.Inport(3), 'autorouting', 'on');
add_line(modelName, schedulerPort.Outport(1), subPort.Trigger(1), 'autorouting', 'on');

add_line(modelName, axPort.Outport(1), inputLogMuxPort.Inport(1), 'autorouting', 'on');
add_line(modelName, ayPort.Outport(1), inputLogMuxPort.Inport(2), 'autorouting', 'on');
add_line(modelName, avzPort.Outport(1), inputLogMuxPort.Inport(3), 'autorouting', 'on');
add_line(modelName, vxRtPort.Outport(1), inputLogMuxPort.Inport(4), 'autorouting', 'on');
add_line(modelName, inputLogMuxPort.Outport(1), uLogPort.Inport(1), 'autorouting', 'on');
add_line(modelName, subPort.Outport(1), xLogPort.Inport(1), 'autorouting', 'on');
add_line(modelName, subPort.Outport(2), pLogPort.Inport(1), 'autorouting', 'on');
add_line(modelName, subPort.Outport(3), diagLogPort.Inport(1), 'autorouting', 'on');

save_system(modelName, targetFile);
close_system(modelName, 0);
close_system('Solver_SF', 0);

after = snapshot(required);
assert_snapshots_equal(before, after);

report = struct();
report.sourceFile = sourceFile;
report.targetFile = targetFile;
report.frozenBefore = before;
report.frozenAfter = after;
report.modelName = modelName;
report.subsystem = subPath;
report.scheduler = schedulerPath;
report.schedulerSampleTime = 0.01;
report.imuMux = imuMuxPath;
report.vxRateTransition = vxRtPath;
report.reset = resetPath;
report.inputLogMux = inputLogMuxPath;
report.wrapperBlock = wrapperBlock;
report.axSource = axSource;
report.aySource = aySource;
report.avzSource = avzSource;
report.vxSource = vxSource;
report.logVariables = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
report.simCalled = false;
report.carSimRun = false;

save(fullfile(root, 'results', 'vy_kkf_v2_1b_build_report.mat'), 'report');
fprintf('V2_1B_BUILD_OK|model=%s|subsystem=%s|scheduler=%s\n', ...
    targetFile, subPath, schedulerPath);
end

function sourcePath = unique_signal_source(modelName, signalName)
lines = find_system(modelName, 'FindAll', 'on', 'Type', 'line');
sources = {};
for k = 1:numel(lines)
    try
        if strcmp(get_param(lines(k), 'Name'), signalName)
            h = get_param(lines(k), 'SrcBlockHandle');
            if isscalar(h) && h > 0
                sources{end+1} = getfullname(h); %#ok<AGROW>
            end
        end
    catch
    end
end
sources = unique(sources);
assert(numel(sources) == 1, 'Signal %s must have one unique source.', signalName);
sourcePath = sources{1};
end

function s = snapshot(paths)
s = repmat(struct('path','','bytes',0,'sha256',''), numel(paths), 1);
for k = 1:numel(paths)
    d = dir(paths{k});
    s(k).path = paths{k};
    s(k).bytes = d.bytes;
    s(k).sha256 = file_sha256(paths{k});
end
end

function assert_snapshots_equal(a, b)
assert(numel(a) == numel(b), 'Snapshot size changed.');
for k = 1:numel(a)
    assert(strcmp(a(k).path, b(k).path), 'Snapshot path changed.');
    assert(a(k).bytes == b(k).bytes, 'Frozen file size changed: %s', a(k).path);
    assert(strcmp(a(k).sha256, b(k).sha256), ...
        'Frozen file hash changed: %s', a(k).path);
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
