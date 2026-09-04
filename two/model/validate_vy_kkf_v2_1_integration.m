function report = validate_vy_kkf_v2_1_integration(buildReport)
%VALIDATE_VY_KKF_V2_1_INTEGRATION Compile/static audit without execution.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
assert(isstruct(buildReport) && isfile(buildReport.targetFile), ...
    'A valid V2.1-B build report is required.');

expectedCoreHash = '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244';
expectedWrapperHash = 'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4';
coreFile = fullfile(root, 'matlab', 'vy_kinematic_kf_step.m');
wrapperFile = fullfile(root, 'matlab', 'vy_kinematic_kf.m');
assert(strcmp(file_sha256(coreFile), expectedCoreHash), 'Frozen K-KF core changed.');
assert(strcmp(file_sha256(wrapperFile), expectedWrapperHash), 'Frozen K-KF wrapper changed.');

Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(root, 'results', 'simulink_cache_vy_kkf_v2_1b'), ...
    'CodeGenFolder', fullfile(root, 'results', 'simulink_codegen_vy_kkf_v2_1b'), ...
    'createDir', true);
load_system('Solver_SF');
load_system(buildReport.targetFile);
m = buildReport.modelName;
cleanup = onCleanup(@() close_models(m));

% Update Diagram is the only compilation action in this stage.
set_param(m, 'SimulationCommand', 'update');

parentCst = get_param(buildReport.subsystem, 'CompiledSampleTime');
axCst = get_param(buildReport.axSource, 'CompiledSampleTime');
ayCst = get_param(buildReport.aySource, 'CompiledSampleTime');
avzCst = get_param(buildReport.avzSource, 'CompiledSampleTime');
vxRawCst = get_param(buildReport.vxSource, 'CompiledSampleTime');
vxRateCst = get_param(buildReport.vxRateTransition, 'CompiledSampleTime');
assert(iscell(vxRateCst) && numel(vxRateCst) == 2, ...
    'Vx Rate Transition must expose distinct input/output sample times.');
vxRateInputCst = vxRateCst{1};
vxBoundaryCst = vxRateCst{2};

assert(isequal(parentCst, [0.01 0]), 'K-KF parent is not compiled at 100 Hz.');
assert(isequal(axCst, [0.01 0]), 'Ax_IMU boundary is not 100 Hz.');
assert(isequal(ayCst, [0.01 0]), 'Ay_IMU boundary is not 100 Hz.');
assert(isequal(avzCst, [0.01 0]), 'AVz_IMU boundary is not 100 Hz.');
assert(isequal(vxRawCst, [0.001 0]), 'Raw true Vx is not 1 kHz.');
assert(isequal(vxRateInputCst, [0.001 0]), ...
    'Vx Rate Transition input side is not 1 kHz.');
assert(isequal(vxBoundaryCst, [0.01 0]), 'Vx boundary is not 100 Hz.');

subPorts = get_param(buildReport.subsystem, 'PortHandles');
assert(numel(subPorts.Inport) == 3 && numel(subPorts.Outport) == 3 && ...
    numel(subPorts.Trigger) == 1, 'K-KF parent port topology mismatch.');

% Audit the real Function-Call structure in the target model.
functionCallTrigger = [buildReport.subsystem '/function'];
functionCallTriggerType = get_param(functionCallTrigger, 'TriggerType');
functionCallTriggerTypeOK = strcmp(functionCallTriggerType, 'function-call');
assert(functionCallTriggerTypeOK, ...
    'K-KF TriggerPort TriggerType must be function-call.');

expectedScheduler = [m '/K-KF 100Hz Scheduler'];
assert(strcmp(buildReport.scheduler, expectedScheduler), ...
    'K-KF scheduler path mismatch.');
schedulerMaskType = get_param(buildReport.scheduler, 'MaskType');
schedulerMaskTypeOK = strcmp(schedulerMaskType, 'Function-Call Generator');
assert(schedulerMaskTypeOK, ...
    'K-KF scheduler MaskType must be Function-Call Generator.');

% Update Diagram clears dimension/type properties when it returns. A full
% model compile is unavailable because the pre-existing CarSim block requests
% an unavailable G:\ solver DLL. Compile an exact in-memory copy of the K-KF
% Function-Call Subsystem instead; this does not save or execute a model.
interfaceAudit = compile_interface_harness(buildReport.subsystem);
inShapes = interfaceAudit.inputShapes;
outShapes = interfaceAudit.outputShapes;
inTypes = interfaceAudit.inputTypes;
outTypes = interfaceAudit.outputTypes;
assert(isequal(interfaceAudit.parentCst, [0.01 0]), ...
    'Isolated interface compile did not preserve the 100 Hz parent domain.');
assert(isequal(inShapes{1}, 3), 'u input dimension must be 3.');
assert(isequal(inShapes{2}, 1), 'Vx measurement dimension must be 1.');
assert(isequal(inShapes{3}, 1), 'reset dimension must be 1.');
assert(isequal(outShapes{1}, 2), 'x output dimension must be 2.');
assert(isequal(outShapes{2}, [2 2]), 'P output dimension must be 2x2.');
assert(isequal(outShapes{3}, 5), 'diagnostic output dimension must be 5.');
assert(all(strcmp(inTypes, 'double')) && all(strcmp(outTypes, 'double')), ...
    'All K-KF boundary ports must be double.');

% Exact connection and input-order audit.
imuMuxPorts = get_param(buildReport.imuMux, 'PortHandles');
assert_source(imuMuxPorts.Inport(1), buildReport.axSource);
assert_source(imuMuxPorts.Inport(2), buildReport.aySource);
assert_source(imuMuxPorts.Inport(3), buildReport.avzSource);
assert_source(subPorts.Inport(1), buildReport.imuMux);
assert_source(subPorts.Inport(2), buildReport.vxRateTransition);
assert_source(subPorts.Inport(3), buildReport.reset);
vxRtPorts = get_param(buildReport.vxRateTransition, 'PortHandles');
assert_source(vxRtPorts.Inport(1), buildReport.vxSource);
inputLogMuxPorts = get_param(buildReport.inputLogMux, 'PortHandles');
assert_source(inputLogMuxPorts.Inport(1), buildReport.axSource);
assert_source(inputLogMuxPorts.Inport(2), buildReport.aySource);
assert_source(inputLogMuxPorts.Inport(3), buildReport.avzSource);
assert_source(inputLogMuxPorts.Inport(4), buildReport.vxRateTransition);

schedulerSource = source_of_port(subPorts.Trigger(1));
schedulerConnectionOK = strcmp(schedulerSource, buildReport.scheduler);
assert(schedulerConnectionOK, ...
    'Function-call trigger source mismatch.');
assert(abs(str2double(get_param(buildReport.scheduler, 'sample_time')) - 0.01) <= eps(0.01), ...
    'Scheduler dialog sample time is not 0.01 s.');

assert(strcmp(get_param(buildReport.reset, 'Time'), '0.01') && ...
    strcmp(get_param(buildReport.reset, 'Before'), '1') && ...
    strcmp(get_param(buildReport.reset, 'After'), '0') && ...
    strcmp(get_param(buildReport.reset, 'SampleTime'), '0.01'), ...
    'Reset structure must be one first-call high followed by zero.');

chartScript = wrapper_chart_script(buildReport.wrapperBlock);
normalized = lower(regexprep(chartScript, '\s+', ''));
assert(contains(normalized, 'vy_kinematic_kf(u,z,resetflag)'), ...
    'Model does not call the frozen wrapper directly.');
forbidden = {'vy_true','dynamic_ekf','dekf','r_hat','reliability'};
for k = 1:numel(forbidden)
    assert(~contains(normalized, forbidden{k}), ...
        'Forbidden online dependency in K-KF wrapper chart: %s', forbidden{k});
end

logPaths = {[m '/K-KF u Log'],[m '/K-KF x Log'], ...
    [m '/K-KF P Log'],[m '/K-KF diag Log']};
expectedVars = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
for k = 1:numel(logPaths)
    assert(strcmp(get_param(logPaths{k}, 'VariableName'), expectedVars{k}), ...
        'Logging variable mismatch.');
    assert(strcmp(get_param(logPaths{k}, 'SaveFormat'), 'Timeseries'), ...
        'Logging format must be Timeseries.');
end

% Preserve compiled evidence before closing the model.
report = struct();
report.passed = true;
report.modelFile = buildReport.targetFile;
report.modelHash = file_sha256(buildReport.targetFile);
report.parentSubsystem = buildReport.subsystem;
report.functionCallTrigger = functionCallTrigger;
report.functionCallTriggerType = functionCallTriggerType;
report.functionCallTriggerTypeOK = functionCallTriggerTypeOK;
report.scheduler = buildReport.scheduler;
report.schedulerMaskType = schedulerMaskType;
report.schedulerMaskTypeOK = schedulerMaskTypeOK;
report.schedulerSource = schedulerSource;
report.schedulerConnectionOK = schedulerConnectionOK;
report.schedulerSampleTime = 0.01;
report.parentCst = parentCst;
report.axCst = axCst;
report.ayCst = ayCst;
report.avzCst = avzCst;
report.vxRawCst = vxRawCst;
report.vxRateInputCst = vxRateInputCst;
report.vxBoundaryCst = vxBoundaryCst;
report.inputShapes = inShapes;
report.outputShapes = outShapes;
report.inputTypes = inTypes;
report.outputTypes = outTypes;
report.interfaceCompileMethod = ...
    'Exact K-KF Function-Call Subsystem copied to unsaved in-memory compile harness';
report.interfaceHarnessParentCst = interfaceAudit.parentCst;
report.fullModelCompileBlockedByExistingCarSimDll = true;
report.fullModelCompileBlock = ...
    'Existing CarSim S-Function requests unavailable G:\carsim\Programs\solvers\carsim_64.dll';
report.inputOrder = {'Ax_IMU','Ay_IMU','AVz_IMU'};
report.measurement = 'true Vx through K-KF Vx RT 100Hz';
report.resetPath = buildReport.reset;
report.resetStaticVerified = true;
report.resetRuntimeVerified = false;
report.logs = expectedVars;
report.logColumns = { ...
    {'Ax_IMU','Ay_IMU','AVz_IMU','Vx_meas'}, ...
    {'vx_hat_K','vy_hat_K'}, ...
    {'P_2x2'}, ...
    {'NIS','obs_metric','innovation_vx','K11','K21'}};
report.trueVyConnected = false;
report.dekfDependency = false;
report.coreHash = file_sha256(coreFile);
report.wrapperHash = file_sha256(wrapperFile);
report.simCalled = false;
report.carSimRun = false;
report.runtimeExecutionVerified = false;
report.compiled100HzDomain = true;

clear cleanup
close_models(m);

% Frozen files are checked again after model closure.
for k = 1:numel(buildReport.frozenBefore)
    p = buildReport.frozenBefore(k).path;
    assert(strcmp(file_sha256(p), buildReport.frozenBefore(k).sha256), ...
        'Frozen hash changed during compile audit: %s', p);
end
report.frozenHashes = buildReport.frozenBefore;

save(fullfile(root, 'results', 'vy_kkf_v2_1b_compile_audit.mat'), 'report');
fprintf(['V2_1B_COMPILE_AUDIT_OK|parent=%s|Ax=%s|Ay=%s|AVz=%s|' ...
    'VxRaw=%s|VxBoundary=%s|sim=0|carsim=0\n'], ...
    mat2str(parentCst), mat2str(axCst), mat2str(ayCst), ...
    mat2str(avzCst), mat2str(vxRawCst), mat2str(vxBoundaryCst));
end

function shape = compiled_shape(portHandle)
raw = double(get_param(portHandle, 'CompiledPortDimensions'));
assert(~isempty(raw), 'Compiled port dimensions are unavailable.');
n = raw(1);
shape = raw(2:1+n);
if numel(shape) == 1
    shape = shape(1);
end
end

function audit = compile_interface_harness(subsystemTemplate)
harness = 'vy_kkf_v2_1b_compile_harness';
if bdIsLoaded(harness)
    close_system(harness, 0);
end
new_system(harness);
cleanup = onCleanup(@() close_harness(harness));
set_param(harness, 'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', 'FixedStep', '0.001');

sub = [harness '/K-KF 100Hz'];
gen = [harness '/K-KF 100Hz Scheduler'];
u = [harness '/u']; z = [harness '/z']; reset = [harness '/reset'];
tx = [harness '/x term']; tp = [harness '/P term']; td = [harness '/diag term'];
add_block(subsystemTemplate, sub, 'Position', [260 80 430 210]);
add_block('simulink/Ports & Subsystems/Function-Call Generator', gen, ...
    'Position', [80 25 205 60], 'sample_time', '0.01', ...
    'numberOfIterations', '1');
add_block('simulink/Sources/Constant', u, 'Position', [40 80 90 110], ...
    'Value', '[0;0;0]', 'SampleTime', '0.01');
add_block('simulink/Sources/Constant', z, 'Position', [40 125 90 155], ...
    'Value', '0', 'SampleTime', '0.01');
add_block('simulink/Sources/Constant', reset, 'Position', [40 170 90 200], ...
    'Value', '0', 'SampleTime', '0.01');
add_block('simulink/Sinks/Terminator', tx, 'Position', [500 90 520 110]);
add_block('simulink/Sinks/Terminator', tp, 'Position', [500 135 520 155]);
add_block('simulink/Sinks/Terminator', td, 'Position', [500 180 520 200]);
genPorts = get_param(gen, 'PortHandles');
subPorts = get_param(sub, 'PortHandles');
add_line(harness, genPorts.Outport(1), subPorts.Trigger(1), 'autorouting', 'on');
add_line(harness, 'u/1', 'K-KF 100Hz/1', 'autorouting', 'on');
add_line(harness, 'z/1', 'K-KF 100Hz/2', 'autorouting', 'on');
add_line(harness, 'reset/1', 'K-KF 100Hz/3', 'autorouting', 'on');
add_line(harness, 'K-KF 100Hz/1', 'x term/1', 'autorouting', 'on');
add_line(harness, 'K-KF 100Hz/2', 'P term/1', 'autorouting', 'on');
add_line(harness, 'K-KF 100Hz/3', 'diag term/1', 'autorouting', 'on');

feval(harness, [], [], [], 'compile');
ph = get_param(sub, 'PortHandles');
audit.inputShapes = cell(3,1); audit.outputShapes = cell(3,1);
audit.inputTypes = cell(3,1); audit.outputTypes = cell(3,1);
for k = 1:3
    audit.inputShapes{k} = compiled_shape(ph.Inport(k));
    audit.outputShapes{k} = compiled_shape(ph.Outport(k));
    audit.inputTypes{k} = get_param(ph.Inport(k), 'CompiledPortDataType');
    audit.outputTypes{k} = get_param(ph.Outport(k), 'CompiledPortDataType');
end
audit.parentCst = get_param(sub, 'CompiledSampleTime');
feval(harness, [], [], [], 'term');
clear cleanup
close_system(harness, 0);
end

function close_harness(harness)
if bdIsLoaded(harness)
    try
        feval(harness, [], [], [], 'term');
    catch
    end
    close_system(harness, 0);
end
end

function assert_source(destinationPort, expectedSource)
actual = source_of_port(destinationPort);
assert(strcmp(actual, expectedSource), ...
    'Connection source mismatch: expected %s, got %s.', expectedSource, actual);
end

function source = source_of_port(destinationPort)
line = get_param(destinationPort, 'Line');
assert(line >= 0, 'Destination port is unconnected.');
h = get_param(line, 'SrcBlockHandle');
assert(isscalar(h) && h > 0, 'Connection has no unique source.');
source = getfullname(h);
end

function script = wrapper_chart_script(blockPath)
rt = sfroot;
charts = rt.find('-isa', 'Stateflow.EMChart');
script = '';
for k = 1:numel(charts)
    if strcmp(charts(k).Path, blockPath)
        script = charts(k).Script;
        return
    end
end
error('K-KF wrapper chart not found.');
end

function close_models(m)
if bdIsLoaded(m)
    close_system(m, 0);
end
if bdIsLoaded('Solver_SF')
    close_system('Solver_SF', 0);
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
