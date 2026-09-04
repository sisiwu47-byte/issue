function report = run_vy_kkf_v2_1e_highyaw()
%RUN_VY_KKF_V2_1E_HIGHYAW Run the one authorized 16 s high-yaw case.

root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root, 'model', 'vx_vy_kkf_v2_1.slx');
modelDir = fileparts(modelFile);
resultFile = fullfile(root, 'results', 'vy_kkf_v2_1e_highyaw.mat');
simFile = fullfile(modelDir, 'simfile.sim');
solverDir = 'D:\carsim\CarSim2021.0_Prog\Programs\solvers';
solverSfDir = fullfile(solverDir, 'Matlab84+');
solverDll = fullfile(solverDir, 'carsim_64.dll');
solverLibrary = fullfile(solverSfDir, 'Solver_SF.slx');

frozen = { ...
    fullfile(root, 'model', 'vx.slx'), ...
    fullfile(root, 'model', 'vx_ax_imu_prereq_v2_1.slx'), ...
    modelFile, ...
    fullfile(root, 'model', 'vx_vy_dekf_v1_17.slx'), ...
    fullfile(root, 'matlab', 'vy_kinematic_kf_step.m'), ...
    fullfile(root, 'matlab', 'vy_kinematic_kf.m')};
expected = { ...
    '754a94d85bd50f89ae453c544903dea90b7f9d57d6e7706869f9f674fb0464eb', ...
    '226238301763460f4b609b0249d61b720c6510dd561923c5d066c33e5967f439', ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712', ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae', ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244', ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'};

assert(isfile(modelFile), 'Frozen V2.1 target model is missing.');
assert(isfile(simFile), 'Existing CarSim simfile.sim is missing.');
assert(isfile(solverDll), 'D:\\carsim solver DLL is missing.');
assert(isfile(solverLibrary), 'D:\\carsim Solver_SF.slx is missing.');

report = struct();
report.stage = 'V2.1-E Higher-Yaw Excitation Validation';
report.stopTime = 16;
report.condition = struct('Vx_mps', 20, 'steerAmplitude_rad', 0.04, ...
    'steerFrequency_Hz', 0.4, 'caseCount', 1);
report.simulationCompleted = false;
report.runtimeError = struct('identifier', '', 'message', '', 'report', '');
report.simCalled = false;
report.carSimRun = false;
report.trueVyOnlineUsed = false;
report.trueVyUse = 'offline validation only';
report.trueVxUse = 'temporary K-KF isolation measurement and offline reference';
report.dekfDependency = false;
report.qrP0TuningPerformed = false;
report.onlineBiasCorrectionImplemented = false;
report.fusionPerformed = false;
report.v2_2Started = false;
report.frozenBefore = hash_files(frozen);
report.targetFileBefore = file_record(modelFile);
for k = 1:numel(frozen)
    assert(strcmp(report.frozenBefore(k).sha256, expected{k}), ...
        'Frozen baseline mismatch before runtime: %s', frozen{k});
end

simText = fileread(simFile);
report.carSim = struct();
report.carSim.simFile = simFile;
report.carSim.simFileHashBefore = file_sha256(simFile);
report.carSim.solverDll = solverDll;
report.carSim.solverDllExists = isfile(solverDll);
report.carSim.solverLibrary = solverLibrary;
report.carSim.solverLibraryExists = isfile(solverLibrary);
report.carSim.progDir = macro_value(simText, 'PROGDIR');
report.carSim.dataDir = macro_value(simText, 'DATADIR');
report.carSim.historicalGDriveRequestPresent = contains(lower(simText), 'g:\carsim');
assert(strcmpi(report.carSim.progDir, 'D:\carsim\CarSim2021.0_Prog\'), ...
    'Existing simfile does not use the authorized D:\\carsim PROGDIR.');
assert(~report.carSim.historicalGDriveRequestPresent, ...
    'Existing simfile still requests the historical G:\\carsim runtime.');

oldPath = path;
oldFolder = pwd;
modelName = 'vx_vy_kkf_v2_1';
runtimeCleanup = onCleanup(@() cleanup_runtime(modelName, oldFolder, oldPath));
simConsoleText = '';

try
    addpath(solverDir);
    addpath(solverSfDir);
    addpath(fullfile(root, 'matlab'));
    cd(modelDir);

    Simulink.fileGenControl('set', ...
        'CacheFolder', fullfile(tempdir, 'vy_kkf_v2_1e_cache'), ...
        'CodeGenFolder', fullfile(tempdir, 'vy_kkf_v2_1e_codegen'), ...
        'createDir', true);
    load_system('Solver_SF');
    load_system(modelFile);

    wks = get_param(modelName, 'ModelWorkspace');
    assignin(wks, 'test_speed', report.condition.Vx_mps);
    assignin(wks, 'test_steer_amplitude', report.condition.steerAmplitude_rad);
    assignin(wks, 'test_steer_frequency', report.condition.steerFrequency_Hz);
    assignin('base', 'test_speed', report.condition.Vx_mps);
    assignin('base', 'test_steer_amplitude', report.condition.steerAmplitude_rad);
    assignin('base', 'test_steer_frequency', report.condition.steerFrequency_Hz);

    enable_port_logging([modelName '/K-KF Reset First Call'], ...
        'kkf_reset_trace_e');
    enable_port_logging([modelName '/Gain38'], 'kkf_vx_true_e');
    enable_port_logging([modelName '/Gain11'], 'kkf_vy_true_e');

    report.runtimeLogging = struct( ...
        'resetBlock', [modelName '/K-KF Reset First Call'], ...
        'trueVxBlock', [modelName '/Gain38'], ...
        'trueVyBlock', [modelName '/Gain11'], ...
        'runtimeOnlyNoSave', true);

    report.simCalled = true;
    simConsoleText = evalc([ ...
        'out = sim(modelName, ''StopTime'', ''16'', ' ...
        '''ReturnWorkspaceOutputs'', ''on'', ''FastRestart'', ''off'', ' ...
        '''SignalLogging'', ''on'', ''SignalLoggingName'', ''logsout'');']);
    report.carSimRun = true;
    fprintf('%s', simConsoleText);

    names = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
    raw = struct();
    for k = 1:numel(names)
        raw.(names{k}) = timeseries_record(output_timeseries(out, names{k}));
    end
    raw.kkf_reset_trace_e = timeseries_record( ...
        logged_timeseries(out, 'kkf_reset_trace_e'));
    raw.vx_true_offline = timeseries_record( ...
        logged_timeseries(out, 'kkf_vx_true_e'));
    raw.vy_true_offline = timeseries_record( ...
        logged_timeseries(out, 'kkf_vy_true_e'));
    report.raw = raw;
    report.simulationCompleted = true;
catch ME
    report.runtimeError.identifier = ME.identifier;
    report.runtimeError.message = ME.message;
    report.runtimeError.report = getReport(ME, 'extended', 'hyperlinks', 'off');
end

report.warnings = warning_evidence(simConsoleText);
cleanup_runtime(modelName, oldFolder, oldPath);
clear runtimeCleanup

report.frozenAfter = hash_files(frozen);
report.targetFileAfter = file_record(modelFile);
report.carSim.simFileHashAfter = file_sha256(simFile);
report.carSim.simFileUnchanged = strcmp( ...
    report.carSim.simFileHashBefore, report.carSim.simFileHashAfter);
report.frozenHashesUnchanged = true;
for k = 1:numel(frozen)
    same = strcmp(report.frozenBefore(k).sha256, report.frozenAfter(k).sha256);
    baseline = strcmp(report.frozenAfter(k).sha256, expected{k});
    report.frozenHashesUnchanged = report.frozenHashesUnchanged && same && baseline;
end
report.targetMetadataUnchanged = ...
    report.targetFileBefore.bytes == report.targetFileAfter.bytes && ...
    report.targetFileBefore.modifiedDatenum == report.targetFileAfter.modifiedDatenum;
save(resultFile, 'report', '-v7.3');

if ~report.simulationCompleted
    fprintf(2, 'V2_1E_RUNTIME_ERROR|%s|%s\n', ...
        report.runtimeError.identifier, report.runtimeError.message);
    error('VY_KKF:V2_1ERuntimeFailed', ...
        'V2.1-E runtime failed; evidence saved to %s.', resultFile);
end
assert(report.frozenHashesUnchanged, 'A frozen file changed during E runtime.');
assert(report.targetMetadataUnchanged, 'Target model metadata changed during E runtime.');
assert(report.carSim.simFileUnchanged, 'CarSim simfile changed during E runtime.');
fprintf(['V2_1E_RUNTIME_OK|stop=16|Klogs=%d/%d/%d/%d|' ...
    'trueRaw=%d/%d|warnings=%d|hash=%d\n'], ...
    report.raw.kkf_u_log1.sampleCount, report.raw.kkf_x_log1.sampleCount, ...
    report.raw.kkf_P_log1.sampleCount, report.raw.kkf_diag_log1.sampleCount, ...
    report.raw.vx_true_offline.sampleCount, ...
    report.raw.vy_true_offline.sampleCount, ...
    report.warnings.derivativeBlockCount, report.frozenHashesUnchanged);
end

function enable_port_logging(blockPath, logName)
ports = get_param(blockPath, 'PortHandles');
assert(isscalar(ports.Outport), 'Expected one output port: %s', blockPath);
line = get_param(ports.Outport(1), 'Line');
assert(line > 0, 'Output line is unavailable: %s', blockPath);
set_param(ports.Outport(1), 'DataLogging', 'on', ...
    'DataLoggingNameMode', 'Custom', 'DataLoggingName', logName);
end

function rec = timeseries_record(ts)
assert(isa(ts, 'timeseries'), 'Expected a timeseries runtime log.');
rec = struct('time', double(ts.Time(:)), 'data', double(ts.Data), ...
    'sampleCount', numel(ts.Time), 'dataClass', class(ts.Data), ...
    'dataSize', size(ts.Data));
end

function ts = output_timeseries(out, name)
try
    ts = out.get(name);
catch ME
    error('VY_KKF:MissingRuntimeLog', ...
        'Simulation output is missing %s: %s', name, ME.message);
end
assert(isa(ts, 'timeseries'), '%s is not a timeseries.', name);
end

function ts = logged_timeseries(out, name)
try
    logsout = out.get('logsout');
catch ME
    error('VY_KKF:MissingSignalDataset', ...
        'Simulation output does not contain logsout: %s', ME.message);
end
element = logsout.getElement(name);
assert(~isempty(element), 'Runtime-only signal was not logged: %s', name);
ts = element.Values;
assert(isa(ts, 'timeseries'), 'Logged signal is not a timeseries: %s', name);
end

function evidence = warning_evidence(consoleText)
matches = regexp(consoleText, ...
    'vx_vy_kkf_v2_1/Derivative(?:\d+)?', 'match');
blocks = unique(matches, 'stable');
evidence = struct();
evidence.derivativeBlockCount = numel(blocks);
evidence.derivativeBlocks = blocks;
evidence.derivativeWarningsOccurred = ~isempty(blocks);
evidence.simulationTerminatedByWarning = false;
evidence.consoleText = consoleText;
end

function value = macro_value(text, key)
token = regexp(text, ['(?m)^' key '\s+([^\r\n]+)'], 'tokens', 'once');
assert(~isempty(token), 'CarSim config entry is missing: %s', key);
value = strtrim(token{1});
end

function hashes = hash_files(files)
hashes = repmat(struct('path','','sha256',''), numel(files), 1);
for k = 1:numel(files)
    hashes(k).path = files{k};
    hashes(k).sha256 = file_sha256(files{k});
end
end

function record = file_record(filePath)
info = dir(filePath);
record = struct('path', filePath, 'bytes', info.bytes, ...
    'modifiedDatenum', info.datenum, 'sha256', file_sha256(filePath));
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

function cleanup_runtime(modelName, oldFolder, oldPath)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if bdIsLoaded('Solver_SF')
    close_system('Solver_SF', 0);
end
cd(oldFolder);
path(oldPath);
evalin('base', ['clear test_speed test_steer_amplitude ' ...
    'test_steer_frequency']);
end
