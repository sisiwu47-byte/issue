function report = run_vy_kkf_v2_1c0_preflight()
%RUN_VY_KKF_V2_1C0_PREFLIGHT Run the authorized 0.20 s no-save smoke test.

root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root, 'model', 'vx_vy_kkf_v2_1.slx');
modelDir = fileparts(modelFile);
resultFile = fullfile(root, 'results', 'vy_kkf_v2_1c0_preflight.mat');
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
report.stage = 'V2.1-C0 Nominal Runtime Preflight';
report.stopTime = 0.20;
report.nominal = struct('Vx_mps', 20, 'steerAmplitude_rad', 0.02, ...
    'steerFrequency_Hz', 0.4);
report.simulationCompleted = false;
report.runtimeError = struct('identifier', '', 'message', '', 'report', '');
report.simCalled = false;
report.carSimRun = false;
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
report.carSim.outputPrefix = macro_value(simText, ...
    'SET_MACRO \$\(OUTPUT_FILE_PREFIX\)\$');
report.carSim.historicalGDriveRequestPresent = contains(lower(simText), 'g:\carsim');
assert(strcmpi(report.carSim.progDir, 'D:\carsim\CarSim2021.0_Prog\'), ...
    'Existing simfile does not use the authorized D:\\carsim PROGDIR.');
assert(~report.carSim.historicalGDriveRequestPresent, ...
    'Existing simfile still requests the historical G:\\carsim runtime.');

oldPath = path;
oldFolder = pwd;
modelName = 'vx_vy_kkf_v2_1';
runtimeCleanup = onCleanup(@() cleanup_runtime(modelName, oldFolder, oldPath));

try
    addpath(solverDir);
    addpath(solverSfDir);
    addpath(fullfile(root, 'matlab'));
    cd(modelDir);

    cacheRoot = fullfile(tempdir, 'vy_kkf_v2_1c0_cache');
    codegenRoot = fullfile(tempdir, 'vy_kkf_v2_1c0_codegen');
    Simulink.fileGenControl('set', 'CacheFolder', cacheRoot, ...
        'CodeGenFolder', codegenRoot, 'createDir', true);
    load_system('Solver_SF');
    load_system(modelFile);

    wks = get_param(modelName, 'ModelWorkspace');
    assignin(wks, 'test_speed', report.nominal.Vx_mps);
    assignin(wks, 'test_steer_amplitude', report.nominal.steerAmplitude_rad);
    assignin(wks, 'test_steer_frequency', report.nominal.steerFrequency_Hz);
    assignin('base', 'test_speed', report.nominal.Vx_mps);
    assignin('base', 'test_steer_amplitude', report.nominal.steerAmplitude_rad);
    assignin('base', 'test_steer_frequency', report.nominal.steerFrequency_Hz);

    resetBlock = [modelName '/K-KF Reset First Call'];
    resetPorts = get_param(resetBlock, 'PortHandles');
    resetLine = get_param(resetPorts.Outport(1), 'Line');
    assert(resetLine > 0, 'K-KF reset output line is unavailable.');
    set_param(resetPorts.Outport(1), 'DataLogging', 'on', ...
        'DataLoggingNameMode', 'Custom', ...
        'DataLoggingName', 'kkf_reset_trace_c0');

    report.simCalled = true;
    out = sim(modelName, 'StopTime', '0.20', ...
        'ReturnWorkspaceOutputs', 'on', 'FastRestart', 'off', ...
        'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
    report.carSimRun = true;

    names = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
    logs = struct();
    for k = 1:numel(names)
        ts = simulation_output_timeseries(out, names{k});
        logs.(names{k}) = timeseries_record(ts);
    end
    resetTs = reset_timeseries(out);
    logs.kkf_reset_trace_c0 = timeseries_record(resetTs);
    report.logs = logs;
    report = analyze_runtime(report);
    report.simulationCompleted = true;
catch ME
    report.runtimeError.identifier = ME.identifier;
    report.runtimeError.message = ME.message;
    report.runtimeError.report = getReport(ME, 'extended', 'hyperlinks', 'off');
end

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
save(resultFile, 'report');

if ~report.simulationCompleted
    fprintf(2, 'V2_1C0_RUNTIME_ERROR|%s|%s\n', ...
        report.runtimeError.identifier, report.runtimeError.message);
    error('VY_KKF:V2_1C0RuntimeFailed', ...
        'V2.1-C0 runtime failed; evidence saved to %s.', resultFile);
end

assert(report.gates.allPassed, 'One or more V2.1-C0 runtime gates failed.');
fprintf(['V2_1C0_RUNTIME_OK|samples=%d|dtMedian=%.17g|' ...
    'resetHigh=%d|hashUnchanged=%d\n'], ...
    report.logs.kkf_x_log1.sampleCount, ...
    report.timing.dtMedian, report.reset.highCount, ...
    report.frozenHashesUnchanged);
end

function report = analyze_runtime(report)
names = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
counts = zeros(1,4);
for k = 1:4
    rec = report.logs.(names{k});
    counts(k) = rec.sampleCount;
    assert(rec.sampleCount > 0, 'Runtime log is empty: %s', names{k});
    assert(all(diff(rec.time) > 0), 'Runtime log time is not monotonic: %s', names{k});
end
referenceTime = report.logs.kkf_x_log1.time;
aligned = true;
for k = 1:4
    t = report.logs.(names{k}).time;
    aligned = aligned && numel(t) == numel(referenceTime) && ...
        max(abs(t(:) - referenceTime(:))) <= 10*eps(max(1,max(abs(referenceTime))));
end

dt = diff(referenceTime);
report.timing = struct();
report.timing.sampleCount = numel(referenceTime);
report.timing.tStart = referenceTime(1);
report.timing.tEnd = referenceTime(end);
report.timing.dtMin = min(dt);
report.timing.dtMedian = median(dt);
report.timing.dtMax = max(dt);
report.timing.uniqueDt = uniquetol(dt, 1e-12, 'DataScale', 1);
report.timing.abnormalIntervalCount = sum(abs(dt - 0.01) > 1e-12);
report.timing.logSampleCounts = counts;
report.timing.logsAligned = aligned;

reset = report.logs.kkf_reset_trace_c0;
resetData = sample_matrix(reset.data, reset.sampleCount);
resetHigh = resetData(:,1) > 0.5;
report.reset = struct('sampleCount', reset.sampleCount, ...
    'highCount', sum(resetHigh), ...
    'highTimestamps', reset.time(resetHigh));

x = sample_matrix(report.logs.kkf_x_log1.data, counts(2));
diagData = sample_matrix(report.logs.kkf_diag_log1.data, counts(4));
P = covariance_samples(report.logs.kkf_P_log1.data, counts(3));
asym = zeros(counts(3),1);
minEig = inf;
diagPositive = true;
for k = 1:counts(3)
    pk = P(:,:,k);
    symmetryError = pk - pk.';
    asym(k) = max(abs(symmetryError(:)));
    diagPositive = diagPositive && all(diag(pk) > 0);
    minEig = min(minEig, min(eig(0.5*(pk + pk.'))));
end
report.sanity = struct();
report.sanity.allXFinite = all(isfinite(x(:)));
report.sanity.allPFinite = all(isfinite(P(:)));
report.sanity.allDiagFinite = all(isfinite(diagData(:)));
report.sanity.maxPAsymmetry = max(asym);
report.sanity.pDiagonalPositive = diagPositive;
report.sanity.minimumPEigenvalue = minEig;

report.gates = struct();
report.gates.fourLogsPresent = all(counts > 0);
report.gates.fourLogsAligned = aligned;
report.gates.runtime100Hz = abs(report.timing.dtMedian - 0.01) <= 1e-12;
report.gates.resetHighExactlyOnce = report.reset.highCount == 1;
report.gates.allFinite = report.sanity.allXFinite && ...
    report.sanity.allPFinite && report.sanity.allDiagFinite;
report.gates.pSymmetric = report.sanity.maxPAsymmetry <= 1e-10;
report.gates.pDiagonalPositive = report.sanity.pDiagonalPositive;
report.gates.pNoMaterialNegativeEigenvalue = ...
    report.sanity.minimumPEigenvalue >= -1e-12;
vals = struct2cell(report.gates);
report.gates.allPassed = all(cellfun(@(v) logical(v), vals));
end

function rec = timeseries_record(ts)
assert(isa(ts, 'timeseries'), 'Expected a timeseries runtime log.');
rec = struct('time', double(ts.Time(:)), 'data', double(ts.Data), ...
    'sampleCount', numel(ts.Time));
end

function ts = simulation_output_timeseries(out, name)
try
    ts = out.get(name);
catch ME
    error('VY_KKF:MissingRuntimeLog', ...
        'Simulation output is missing %s: %s', name, ME.message);
end
assert(isa(ts, 'timeseries'), '%s is not a timeseries.', name);
end

function ts = reset_timeseries(out)
try
    logsout = out.get('logsout');
catch ME
    error('VY_KKF:MissingResetDataset', ...
        'Simulation output does not contain logsout: %s', ME.message);
end
element = logsout.getElement('kkf_reset_trace_c0');
assert(~isempty(element), 'Runtime reset trace was not logged.');
ts = element.Values;
assert(isa(ts, 'timeseries'), 'Runtime reset trace is not a timeseries.');
end

function matrix = sample_matrix(data, sampleCount)
sz = size(data);
sampleDim = find(sz == sampleCount, 1, 'last');
assert(~isempty(sampleDim), 'Cannot identify the sample dimension.');
order = [sampleDim, setdiff(1:ndims(data), sampleDim, 'stable')];
matrix = reshape(permute(data, order), sampleCount, []);
end

function P = covariance_samples(data, sampleCount)
sz = size(data);
assert(numel(sz) >= 3 && any(sz == sampleCount), ...
    'Cannot identify covariance sample dimension.');
sampleDim = find(sz == sampleCount, 1, 'last');
other = setdiff(1:ndims(data), sampleDim, 'stable');
assert(prod(sz(other)) == 4, 'Covariance log is not 2x2 per sample.');
tmp = permute(data, [other sampleDim]);
P = reshape(tmp, 2, 2, sampleCount);
end

function value = macro_value(text, key)
expr = ['(?m)^' key '\s+([^\r\n]+)'];
token = regexp(text, expr, 'tokens', 'once');
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
