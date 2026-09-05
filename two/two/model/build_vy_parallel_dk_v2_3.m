function build = build_vy_parallel_dk_v2_3()
%BUILD_VY_PARALLEL_DK_V2_3 Build the V2.3-B parallel D/K target only.
% The frozen genuine-steering K-KF model is copied byte-for-byte first.
% Only the new copy is edited and saved. No compile, sim, or CarSim run is
% performed here.

root = fileparts(fileparts(mfilename('fullpath')));
md = fullfile(root, 'model');
sourceFile = fullfile(md, 'vx_vy_kkf_v2_1g_steer.slx');
donorFile = fullfile(md, 'vx_vy_dekf_v1_17.slx');
targetFile = fullfile(md, 'vx_vy_parallel_dk_v2_3.slx');

[frozenFiles, expectedHashes] = frozen_manifest(root);
frozenBefore = snapshot(frozenFiles);
assert(records_match(frozenBefore, expectedHashes), ...
    'A frozen V2.3-B source/dependency hash differs from its baseline.');

copyfile(sourceFile, targetFile, 'f');
addpath(md);
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(tempdir, 'vy_parallel_dk_v2_3b_cache'), ...
    'CodeGenFolder', fullfile(tempdir, 'vy_parallel_dk_v2_3b_codegen'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(donorFile);
load_system(targetFile);
[~, m] = fileparts(targetFile);
[~, donor] = fileparts(donorFile);
cleanup = onCleanup(@() close_models(m, donor));

% Frozen K-KF and genuine-steering paths must already exist in the copy.
kSub = [m '/K-KF 100Hz'];
kScheduler = [m '/K-KF 100Hz Scheduler'];
kReset = [m '/K-KF Reset First Call'];
kImuMux = [m '/K-KF IMU Mux'];
kVxRt = [m '/K-KF Vx RT 100Hz'];
steerCmd = [m '/G0 Steer Cmd Rad'];
gain22 = [m '/Gain22'];
mux8 = [m '/Mux8'];
manualSwitch = [m '/Manual Switch1'];
rearPlantZero = [m '/Constant10'];
required = {kSub,kScheduler,kReset,kImuMux,kVxRt,steerCmd, ...
    gain22,mux8,manualSwitch,rearPlantZero};
for k = 1:numel(required)
    assert(getSimulinkBlockHandle(required{k}) > 0, ...
        'Required frozen K/steering block is missing: %s', required{k});
end
assert(strcmp(strtrim(get_param(gain22,'Gain')), '180/pi'), ...
    'Frozen Gain22 is not the single rad-to-deg conversion.');
assert(strcmp(source_of_port(get_param(gain22,'PortHandles').Inport(1)), steerCmd), ...
    'The genuine rad steering source does not drive Gain22.');
assert(strcmp(source_of_port(get_param(manualSwitch,'PortHandles').Inport(2)), mux8), ...
    'Manual Switch1 input 2 is not the genuine Mux8 leg.');
assert(strcmp(get_param(manualSwitch,'CurrentSetting'), '0'), ...
    'Manual Switch1 does not select input 2/Mux8.');
assert_sources(mux8, [2 4], gain22);
assert_zero_sources(mux8, [6 8]);

% Resolve common physical sources by their audited signal names. This avoids
% coupling to estimator outputs and does not depend on localized block names.
axSource = unique_signal_source(m, 'Ax_IMU');
aySource = unique_signal_source(m, 'Ay_IMU');
avzSource = unique_signal_source(m, 'AVz_IMU');
vxSource = [m '/Gain38'];
assert(getSimulinkBlockHandle(vxSource) > 0 && ...
    strcmp(strtrim(get_param(vxSource,'Gain')), '1/3.6'), ...
    'Audited true-Vx physical source Gain38 is missing or changed.');

% Copy the frozen D-EKF subsystem, its independent function-call generator,
% and its own 100-Hz input boundary. No estimator equations are recreated.
dSub = [m '/Parallel D-EKF 100Hz'];
dScheduler = [m '/Parallel D-EKF 100Hz Scheduler'];
dInputRt = [m '/Parallel D-EKF Input RT 100Hz'];
assert(getSimulinkBlockHandle(dSub) < 0 && ...
    getSimulinkBlockHandle(dScheduler) < 0 && ...
    getSimulinkBlockHandle(dInputRt) < 0, ...
    'Parallel D-EKF blocks unexpectedly already exist in the source copy.');
add_block([donor '/Vy D-EKF 100Hz'], dSub, ...
    'Position', [4250 180 4470 330]);
add_block([donor '/D-EKF 100Hz Scheduler'], dScheduler, ...
    'Position', [4010 120 4160 155]);
add_block([donor '/D-EKF Input RT 100Hz'], dInputRt, ...
    'Position', [3990 245 4150 280]);

% A20 is the frozen D-EKF operating mode: r updates at 100 Hz and the
% joint [Ay;r] update is enabled every fifth hit (20 Hz).
wks = get_param(m, 'ModelWorkspace');
assignin(wks, 'vy_v17_mode_code', 20);

% Observation-only routing around the frozen subsystem.
dSteerMux = [m '/Parallel D Steering Mux'];
dRearZero = [m '/Parallel D Rear Steer Zero Rad'];
dControlMux = [m '/Parallel D Control Mux'];
dMeasurementMux = [m '/Parallel D Measurement Mux'];
dInputMux = [m '/Parallel D Input Mux'];
dOutputDemux = [m '/Parallel D Output Demux'];
dPExtractDemux = [m '/Parallel D Full P Extract'];
dPReshape = [m '/Parallel D P 2x2'];
dPDiagTerm = [m '/Parallel D Pdiag Terminator'];
dPHeadTerm = [m '/Parallel D P Head Terminator'];
dPTailTerm = [m '/Parallel D P Tail Terminator'];

add_block('simulink/Signal Routing/Mux', dSteerMux, ...
    'Position', [3650 400 3655 505], 'Inputs', '4');
add_block('simulink/Sources/Constant', dRearZero, ...
    'Position', [3450 475 3510 505], 'Value', '0', ...
    'OutDataTypeStr', 'double');
add_block('simulink/Signal Routing/Mux', dControlMux, ...
    'Position', [3750 300 3755 385], 'Inputs', '[1 4]');
add_block('simulink/Signal Routing/Mux', dMeasurementMux, ...
    'Position', [3750 540 3755 610], 'Inputs', '2');
add_block('simulink/Signal Routing/Mux', dInputMux, ...
    'Position', [3860 310 3865 590], 'Inputs', '[5 2]');
add_block('simulink/Signal Routing/Demux', dOutputDemux, ...
    'Position', [4580 180 4585 330], 'Outputs', '[2 2 65]');
add_block('simulink/Signal Routing/Demux', dPExtractDemux, ...
    'Position', [4580 365 4585 470], 'Outputs', '[45 4 20]');
add_block('simulink/Math Operations/Reshape', dPReshape, ...
    'Position', [4700 400 4805 435], ...
    'OutputDimensionality', 'Customize', 'OutputDimensions', '[2 2]');
add_block('simulink/Sinks/Terminator', dPDiagTerm, ...
    'Position', [4680 255 4700 275]);
add_block('simulink/Sinks/Terminator', dPHeadTerm, ...
    'Position', [4680 360 4700 380]);
add_block('simulink/Sinks/Terminator', dPTailTerm, ...
    'Position', [4680 455 4700 475]);

connect(m, steerCmd, 1, dSteerMux, 1);
connect(m, steerCmd, 1, dSteerMux, 2);
connect(m, dRearZero, 1, dSteerMux, 3);
connect(m, dRearZero, 1, dSteerMux, 4);
connect(m, vxSource, 1, dControlMux, 1);
connect(m, dSteerMux, 1, dControlMux, 2);
connect(m, aySource, 1, dMeasurementMux, 1);
connect(m, avzSource, 1, dMeasurementMux, 2);
connect(m, dControlMux, 1, dInputMux, 1);
connect(m, dMeasurementMux, 1, dInputMux, 2);
connect(m, dInputMux, 1, dInputRt, 1);
connect(m, dInputRt, 1, dSub, 1);
connect_trigger(m, dScheduler, dSub);
connect(m, dSub, 1, dOutputDemux, 1);
connect(m, dSub, 1, dPExtractDemux, 1);
connect(m, dOutputDemux, 2, dPDiagTerm, 1);
connect(m, dPExtractDemux, 1, dPHeadTerm, 1);
connect(m, dPExtractDemux, 2, dPReshape, 1);
connect(m, dPExtractDemux, 3, dPTailTerm, 1);

% Independent estimator logs. K logs already exist in the frozen source and
% retain their accepted names; only D and shared-input logs are added.
dXLog = add_ws(m, dOutputDemux, 1, 'dekf_x_log', ...
    [4870 185 5000 215]);
dPLog = add_ws(m, dPReshape, 1, 'dekf_P_log', ...
    [4870 400 5000 430]);
dDiagLog = add_ws(m, dOutputDemux, 3, 'dekf_diag_log', ...
    [4870 295 5000 325]);

parallelInputMux = [m '/Parallel Physical Input Log Mux'];
parallelInputLog = [m '/parallel_input_log'];
add_block('simulink/Signal Routing/Mux', parallelInputMux, ...
    'Position', [4300 600 4305 805], 'Inputs', '[1 1 1 1 4 1]');
add_block('simulink/Sinks/To Workspace', parallelInputLog, ...
    'Position', [4480 680 4620 715], 'VariableName', ...
    'parallel_input_log', 'SaveFormat', 'Timeseries', ...
    'MaxDataPoints', '100000');
connect(m, axSource, 1, parallelInputMux, 1);
connect(m, aySource, 1, parallelInputMux, 2);
connect(m, avzSource, 1, parallelInputMux, 3);
connect(m, vxSource, 1, parallelInputMux, 4);
connect(m, dSteerMux, 1, parallelInputMux, 5);
connect(m, kReset, 1, parallelInputMux, 6);
connect(m, parallelInputMux, 1, parallelInputLog, 1);

% The copied D wrapper must remain the exact frozen call boundary.
dFcnBlocks = find_system(dSub, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'BlockType', 'MATLABFcn');
assert(numel(dFcnBlocks) == 1, 'Frozen D-EKF MATLAB Fcn boundary is ambiguous.');
dFcn = dFcnBlocks{1};
assert(strcmp(regexprep(get_param(dFcn,'MATLABFcn'),'\s+',''), ...
    'vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)'), ...
    'Copied D-EKF wrapper expression differs from the frozen donor.');
assert(str2double(get_param(dFcn,'OutputDimensions')) == 69, ...
    'Copied D-EKF raw output width is not 69.');

% The frozen K log contract must remain present and unrenamed.
kLogPaths = {[m '/K-KF x Log'],[m '/K-KF P Log'],[m '/K-KF diag Log']};
kLogVars = {'kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
for k = 1:numel(kLogPaths)
    assert(getSimulinkBlockHandle(kLogPaths{k}) > 0 && ...
        strcmp(get_param(kLogPaths{k},'VariableName'), kLogVars{k}), ...
        'Frozen K-KF log contract changed: %s', kLogVars{k});
end

save_system(m, targetFile);
close_system(m, 0);
close_system(donor, 0);
close_system('Solver_SF', 0);
clear cleanup

frozenAfter = snapshot(frozenFiles);
assert(records_equal(frozenBefore, frozenAfter) && ...
    records_match(frozenAfter, expectedHashes), ...
    'A frozen object changed while building the parallel copy.');

build = struct();
build.stage = 'V2.3-B';
build.sourceFile = sourceFile;
build.donorFile = donorFile;
build.targetFile = targetFile;
build.modelName = m;
build.sourceHashBefore = frozenBefore(2).sha256;
build.sourceHashAfter = frozenAfter(2).sha256;
build.targetHash = file_sha256(targetFile);
build.frozenBefore = frozenBefore;
build.frozenAfter = frozenAfter;
build.donorSubsystem = [donor '/Vy D-EKF 100Hz'];
build.dSubsystem = dSub;
build.dScheduler = dScheduler;
build.dInputRateTransition = dInputRt;
build.dWrapperBlock = dFcn;
build.dSteeringMux = dSteerMux;
build.dRearZero = dRearZero;
build.dControlMux = dControlMux;
build.dMeasurementMux = dMeasurementMux;
build.dInputMux = dInputMux;
build.dOutputDemux = dOutputDemux;
build.dPExtractDemux = dPExtractDemux;
build.dPReshape = dPReshape;
build.kSubsystem = kSub;
build.kScheduler = kScheduler;
build.kReset = kReset;
build.kImuMux = kImuMux;
build.kVxRateTransition = kVxRt;
build.axSource = axSource;
build.aySource = aySource;
build.avzSource = avzSource;
build.vxSource = vxSource;
build.steerSource = steerCmd;
build.gain22 = gain22;
build.mux8 = mux8;
build.manualSwitch = manualSwitch;
build.rearPlantZero = rearPlantZero;
build.dLogs = {dXLog,dPLog,dDiagLog};
build.kLogs = kLogPaths;
build.parallelInputMux = parallelInputMux;
build.parallelInputLog = parallelInputLog;
build.parallelInputColumns = {'Ax_IMU','Ay_IMU','AVz_IMU', ...
    'Vx_true','steer_FL_rad','steer_FR_rad','steer_RL_rad', ...
    'steer_RR_rad','K_reset'};
build.dResetSemantics = ['independent wrapper lifecycle: empty persistent ' ...
    'or mode change; A20 fixed mode'];
build.kResetSemantics = 'independent explicit first-hit Step';
build.simCalled = false;
build.carSimRun = false;

fprintf('V2_3B_BUILD_OK|target=%s|hash=%s|sourceUnchanged=1|sim=0|carsim=0\n', ...
    targetFile, build.targetHash);
end

function connect(m, src, outNumber, dst, inNumber)
sp = get_param(src, 'PortHandles');
dp = get_param(dst, 'PortHandles');
add_line(m, sp.Outport(outNumber), dp.Inport(inNumber), 'autorouting', 'on');
end

function connect_trigger(m, scheduler, subsystem)
sp = get_param(scheduler, 'PortHandles');
dp = get_param(subsystem, 'PortHandles');
add_line(m, sp.Outport(1), dp.Trigger(1), 'autorouting', 'on');
end

function path = add_ws(m, src, outNumber, variable, position)
path = [m '/' variable];
add_block('simulink/Sinks/To Workspace', path, 'Position', position, ...
    'VariableName', variable, 'SaveFormat', 'Timeseries', ...
    'MaxDataPoints', '100000');
connect(m, src, outNumber, path, 1);
end

function assert_sources(mux, ports, expectedSource)
p = get_param(mux, 'PortHandles');
for k = 1:numel(ports)
    assert(strcmp(source_of_port(p.Inport(ports(k))), expectedSource), ...
        'Unexpected source at %s input %d.', mux, ports(k));
end
end

function assert_zero_sources(mux, ports)
p = get_param(mux, 'PortHandles');
for k = 1:numel(ports)
    src = source_of_port(p.Inport(ports(k)));
    assert(strcmp(get_param(src,'BlockType'),'Constant') && ...
        str2double(get_param(src,'Value')) == 0, ...
        'Expected zero source at %s input %d.', mux, ports(k));
end
end

function source = source_of_port(port)
line = get_param(port, 'Line');
assert(line > 0, 'Required input port is unconnected.');
source = getfullname(get_param(line, 'SrcBlockHandle'));
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
assert(numel(sources) == 1, ...
    'Expected exactly one physical source for signal %s.', signalName);
sourcePath = sources{1};
end

function [files, hashes] = frozen_manifest(root)
files = { ...
    fullfile(root,'model','vx_vy_dekf_v1_17.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1.slx'); ...
    fullfile(root,'model','vy_dynamic_ekf_v1_17.m'); ...
    fullfile(root,'model','vy_dynamic_ekf_step_v17.m'); ...
    fullfile(root,'model','vy_dynamic_ekf_step_v13.m'); ...
    fullfile(root,'model','vy_kinematic_kf_step.m'); ...
    fullfile(root,'model','vy_kinematic_kf.m'); ...
    fullfile(root,'model','vx_vy_dkekf_v2_2.slx'); ...
    fullfile(root,'model','vx_vy_dkekf_v2_2d_nominal.slx'); ...
    fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
    fullfile(root,'model','vy_dkekf_baseline.m'); ...
    fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m')};
hashes = { ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
    '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e'; ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712'; ...
    '5550d0389fc4d1dcf7f65b0e00b4c51a949f2b9add33c2d78d1122a31291a1a0'; ...
    '4010f6a4bd669ac048297c2f416f0b8826f729f4552d73445703184f052c4a4f'; ...
    '498a446e13e654387e3d36bf4694a336e75b2100e765dac0414a01367531cde4'; ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244'; ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'; ...
    'e768fb2ad33a6eeaabde2fb7c40be660b78f350a90c752327dc9b423f50f2e15'; ...
    'a17e7609d2248c832a80f773660941b68025e3a38cfc1f3938cbca2bd0165e5b'; ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457'; ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'; ...
    '12f0d82643d65aa5098ed20c0655234f3a2e7ef6d6f5e7dee5b80bc1a201bda1'};
end

function records = snapshot(files)
records = repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''), ...
    numel(files), 1);
for k = 1:numel(files)
    d = dir(files{k});
    assert(~isempty(d), 'Frozen file missing: %s', files{k});
    records(k) = struct('path',files{k},'bytes',d.bytes, ...
        'modifiedDatenum',d.datenum,'sha256',file_sha256(files{k}));
end
end

function ok = records_match(records, hashes)
ok = numel(records) == numel(hashes);
for k = 1:numel(records)
    ok = ok && strcmp(records(k).sha256, hashes{k});
end
end

function ok = records_equal(a, b)
ok = numel(a) == numel(b);
for k = 1:numel(a)
    ok = ok && a(k).bytes == b(k).bytes && ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function hash = file_sha256(path)
d = java.security.MessageDigest.getInstance('SHA-256');
s = java.io.FileInputStream(java.io.File(path));
ds = java.security.DigestInputStream(s,d);
c = onCleanup(@()ds.close());
while ds.read() ~= -1, end
bytes = typecast(d.digest(),'uint8');
hash = lower(reshape(dec2hex(bytes,2).',1,[]));
clear c
end

function close_models(m, donor)
if bdIsLoaded(m), close_system(m,0); end
if bdIsLoaded(donor), close_system(donor,0); end
if bdIsLoaded('Solver_SF'), close_system('Solver_SF',0); end
end
