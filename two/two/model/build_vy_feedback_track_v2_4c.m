function build = build_vy_feedback_track_v2_4c()
%BUILD_VY_FEEDBACK_TRACK_V2_4C Create standalone F-track integration target.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
resultFile = fullfile(root,'results','vy_feedback_track_v2_4c_integration_gates.mat');
modelName = 'vx_vy_feedback_track_v2_4';
targetFile = fullfile(modelDir,[modelName '.slx']);
coreFile = fullfile(modelDir,'vy_feedback_propagation_step.m');
wrapperFile = fullfile(modelDir,'vy_feedback_propagation_simulink_sfun.m');

coreExpected = '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF';
assert(strcmp(file_sha256(coreFile),coreExpected), ...
    'Frozen V2.4-B mathematical core hash mismatch.');
assert(isfile(wrapperFile),'V2.4-C Level-2 MATLAB S-function is missing.');
assert(~isfile(targetFile), ...
    'Standalone target already exists; builder will not overwrite it.');

[frozenFiles,frozenExpected] = frozen_manifest(root);
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'Frozen dependency mismatch before V2.4-C build.');

oldPath = path;
cleanupPath = onCleanup(@()path(oldPath));
addpath(modelDir);
if bdIsLoaded(modelName), close_system(modelName,0); end
new_system(modelName);
cleanupModel = onCleanup(@()close_if_loaded(modelName));

set_param(modelName, ...
    'SolverType','Fixed-step', ...
    'Solver','FixedStepDiscrete', ...
    'FixedStep','0.01', ...
    'StartTime','0', ...
    'StopTime','0.1', ...
    'Description',['V2.4-C STANDALONE F-TRACK. P0_F=0.5 and Q_F=0.0025 ' ...
    'are TEST-ONLY / UNTUNED / UNFROZEN integration values.']);

subsystem = [modelName '/F-Track 100Hz'];
scheduler = [modelName '/F-Track 100Hz Scheduler'];
wrapperBlock = [subsystem '/F-Track Stateful Boundary'];

add_block('simulink/Ports & Subsystems/Function-Call Subsystem',subsystem, ...
    'Position',[430 110 720 390]);
add_block('simulink/Ports & Subsystems/Function-Call Generator',scheduler, ...
    'Position',[195 45 345 80],'sample_time','0.01', ...
    'numberOfIterations','1');

sourceNames = {'Ay Source','AVz Source','Vx Source', ...
    'Vy Feedback Current','P Feedback Current','Feedback Valid Current'};
sourceValues = {'0','0','20','0','0.5','0'};
sourcePaths = cell(7,1);
for k=1:6
    sourcePaths{k} = [modelName '/' sourceNames{k}];
    add_block('simulink/Sources/Constant',sourcePaths{k}, ...
        'Position',[80 95+45*k 180 120+45*k], ...
        'Value',sourceValues{k},'SampleTime','0.01', ...
        'OutDataTypeStr','double');
end
sourcePaths{7} = [modelName '/Reset First Hit'];
add_block('simulink/Sources/Step',sourcePaths{7}, ...
    'Position',[80 410 180 440],'Time','0.01', ...
    'Before','1','After','0','SampleTime','0.01', ...
    'OutDataTypeStr','double');

outputNames = {'Vy_F','P_F','diag_F'};
outputPaths = cell(3,1);
for k=1:3
    outputPaths{k} = [modelName '/' outputNames{k}];
    add_block('simulink/Ports & Subsystems/Out1',outputPaths{k}, ...
        'Port',num2str(k),'Position',[820 155+75*k 850 175+75*k]);
end

internalLines = find_system(subsystem,'FindAll','on','SearchDepth',1, ...
    'Type','line');
for k=1:numel(internalLines), delete_line(internalLines(k)); end
set_param([subsystem '/In1'],'Name','Ay_IMU','Port','1', ...
    'Position',[25 55 55 71]);
set_param([subsystem '/Out1'],'Name','Vy_F','Port','1', ...
    'Position',[470 80 500 100]);
inputNames = {'AVz_IMU','Vx_source','Vy_feedback_current', ...
    'P_feedback_current','feedback_valid_current','reset'};
for k=1:6
    add_block('simulink/Ports & Subsystems/In1', ...
        [subsystem '/' inputNames{k}],'Port',num2str(k+1), ...
        'Position',[25 55+35*k 55 71+35*k]);
end
add_block('simulink/Ports & Subsystems/Out1',[subsystem '/P_F'], ...
    'Port','2','Position',[470 145 500 165]);
add_block('simulink/Ports & Subsystems/Out1',[subsystem '/diag_F'], ...
    'Port','3','Position',[470 210 500 230]);
set_param([subsystem '/function'],'Position',[205 10 275 40]);

add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', ...
    wrapperBlock,'FunctionName','vy_feedback_propagation_simulink_sfun', ...
    'Parameters','0.01,0,0.5,0.0025', ...
    'Position',[155 55 390 275]);

internalInputNames = [{'Ay_IMU'},inputNames];
for k=1:7
    add_line(subsystem,[internalInputNames{k} '/1'], ...
        sprintf('F-Track Stateful Boundary/%d',k),'autorouting','on');
end
for k=1:3
    add_line(subsystem,sprintf('F-Track Stateful Boundary/%d',k), ...
        [outputNames{k} '/1'],'autorouting','on');
end

schedulerPorts = get_param(scheduler,'PortHandles');
subsystemPorts = get_param(subsystem,'PortHandles');
add_line(modelName,schedulerPorts.Outport(1),subsystemPorts.Trigger(1), ...
    'autorouting','on');
for k=1:7
    sourcePorts = get_param(sourcePaths{k},'PortHandles');
    add_line(modelName,sourcePorts.Outport(1),subsystemPorts.Inport(k), ...
        'autorouting','on');
end
for k=1:3
    sinkPorts = get_param(outputPaths{k},'PortHandles');
    add_line(modelName,subsystemPorts.Outport(k),sinkPorts.Inport(1), ...
        'autorouting','on');
end

save_system(modelName,targetFile);
targetHash = file_sha256(targetFile);
wrapperHash = file_sha256(wrapperFile);
frozenAfter = hash_records(frozenFiles);
assert(records_equal(frozenBefore,frozenAfter) && ...
    hashes_match(frozenAfter,frozenExpected), ...
    'A frozen dependency changed during V2.4-C build.');

build = struct();
build.stage = 'V2.4-C';
build.modelName = modelName;
build.targetFile = targetFile;
build.targetHash = targetHash;
build.coreFile = coreFile;
build.coreHash = coreExpected;
build.wrapperFile = wrapperFile;
build.wrapperHash = wrapperHash;
build.subsystem = subsystem;
build.scheduler = scheduler;
build.wrapperBlock = wrapperBlock;
build.sourcePaths = sourcePaths;
build.outputPaths = outputPaths;
build.parameters = struct('Ts',0.01,'Vy_F0',0,'P0_F',0.5,'Q_F',0.0025, ...
    'testOnly',true,'tuned',false,'frozenForRuntime',false);
build.frozenBefore = frozenBefore;
build.frozenAfter = frozenAfter;
build.frozenUnchanged = true;
build.simCalled = false;
build.carSimRun = false;
save(resultFile,'build','-v7');

fprintf('V2_4C_BUILD|target=%s|core=%s|wrapper=%s|frozen=%d\n', ...
    upper(targetHash),upper(coreExpected),upper(wrapperHash), ...
    build.frozenUnchanged);
clear cleanupModel cleanupPath
close_if_loaded(modelName);
end

function [files,expected] = frozen_manifest(root)
files = {
    fullfile(root,'model','vy_feedback_propagation_step.m')
    fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx')
    fullfile(root,'model','vx_vy_dekf_v1_17.slx')
    fullfile(root,'model','vy_dynamic_ekf_v1_17.m')
    fullfile(root,'model','vy_dynamic_ekf_step_v17.m')
    fullfile(root,'model','vy_dynamic_ekf_step_v13.m')
    fullfile(root,'model','vx_vy_kkf_v2_1.slx')
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx')
    fullfile(root,'model','vy_kinematic_kf_step.m')
    fullfile(root,'model','vy_kinematic_kf.m')
    fullfile(root,'model','vx_vy_dkekf_v2_2.slx')
    fullfile(root,'model','vy_dkekf_baseline_step.m')
    fullfile(root,'model','vy_dkekf_baseline.m')
    fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m')};
expected = {
    '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'
    '98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0'
    '108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE'
    '5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0'
    '4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F'
    '498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4'
    'B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712'
    '59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E'
    '3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244'
    'F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4'
    'E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15'
    '6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457'
    '7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973'
    '12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1'};
end

function records = hash_records(files)
records = repmat(struct('path','','sha256',''),numel(files),1);
for k=1:numel(files)
    records(k).path = files{k};
    records(k).sha256 = upper(file_sha256(files{k}));
end
end

function ok = hashes_match(records,expected)
ok = numel(records)==numel(expected);
for k=1:numel(records)
    ok = ok && strcmp(records(k).sha256,expected{k});
end
end

function ok = records_equal(a,b)
ok = numel(a)==numel(b);
for k=1:numel(a)
    ok = ok && strcmp(a(k).path,b(k).path) && ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function close_if_loaded(modelName)
if bdIsLoaded(modelName), close_system(modelName,0); end
end

function h = file_sha256(file)
d = java.security.MessageDigest.getInstance('SHA-256');
s = java.io.FileInputStream(java.io.File(file));
ds = java.security.DigestInputStream(s,d);
c = onCleanup(@()ds.close());
while ds.read()~=-1
end
b = typecast(d.digest(),'uint8');
h = upper(reshape(dec2hex(b,2).',1,[]));
clear c
end
