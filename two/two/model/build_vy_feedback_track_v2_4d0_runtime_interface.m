function build = build_vy_feedback_track_v2_4d0_runtime_interface()
%BUILD_VY_FEEDBACK_TRACK_V2_4D0_RUNTIME_INTERFACE Create test-source-only copy.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
resultFile = fullfile(root,'results','vy_feedback_track_v2_4d0_interface_gates.mat');
sourceName = 'vx_vy_feedback_track_v2_4';
runtimeName = 'vx_vy_feedback_track_v2_4d_runtime';
sourceFile = fullfile(modelDir,[sourceName '.slx']);
runtimeFile = fullfile(modelDir,[runtimeName '.slx']);

sourceExpected = '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84';
coreExpected = '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF';
wrapperExpected = '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0';
coreFile = fullfile(modelDir,'vy_feedback_propagation_step.m');
wrapperFile = fullfile(modelDir,'vy_feedback_propagation_simulink_sfun.m');

assert(isfile(sourceFile),'Accepted V2.4-C standalone target is missing.');
assert(strcmp(file_sha256(sourceFile),sourceExpected), ...
    'Accepted V2.4-C standalone target hash mismatch.');
assert(strcmp(file_sha256(coreFile),coreExpected), ...
    'Frozen feedback-propagation core hash mismatch.');
assert(strcmp(file_sha256(wrapperFile),wrapperExpected), ...
    'Accepted feedback-propagation S-function hash mismatch.');
assert(~isfile(runtimeFile), ...
    'V2.4-D0 runtime validation copy already exists; builder will not overwrite it.');

[frozenFiles,frozenExpected] = frozen_manifest(root);
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'Frozen dependency mismatch before V2.4-D0 build.');
sourceBefore = file_record(sourceFile);

oldPath = path;
cleanupPath = onCleanup(@()path(oldPath));
addpath(modelDir);
close_if_loaded(runtimeName);
close_if_loaded(sourceName);
load_system(sourceFile);
save_system(sourceName,runtimeFile);
close_if_loaded(runtimeName);
close_if_loaded(sourceName);
load_system(runtimeFile);
cleanupModel = onCleanup(@()close_if_loaded(runtimeName));

sourceBlockNames = {
    'Ay Source'
    'AVz Source'
    'Vx Source'
    'Vy Feedback Current'
    'P Feedback Current'
    'Feedback Valid Current'
    'Reset First Hit'};
variableNames = {
    'ftrack_test_Ay'
    'ftrack_test_AVz'
    'ftrack_test_Vx'
    'ftrack_test_Vy_feedback'
    'ftrack_test_P_feedback'
    'ftrack_test_feedback_valid'
    'ftrack_test_reset'};
sourcePaths = cell(7,1);
destinations = zeros(7,1);

for k = 1:7
    sourcePaths{k} = [runtimeName '/' sourceBlockNames{k}];
    oldPorts = get_param(sourcePaths{k},'PortHandles');
    oldLine = get_param(oldPorts.Outport(1),'Line');
    assert(oldLine~=-1,'Existing stimulus source is not connected.');
    dst = get_param(oldLine,'DstPortHandle');
    assert(numel(dst)==1&&dst(1)~=-1, ...
        'Existing stimulus source does not have one semantic destination.');
    destinations(k) = dst(1);
    position = get_param(sourcePaths{k},'Position');
    delete_line(oldLine);
    delete_block(sourcePaths{k});
    add_block('simulink/Sources/From Workspace',sourcePaths{k}, ...
        'Position',position, ...
        'VariableName',variableNames{k}, ...
        'SampleTime','0.01', ...
        'Interpolate','off', ...
        'OutputAfterFinalValue','Holding final value');
    newPorts = get_param(sourcePaths{k},'PortHandles');
    add_line(runtimeName,newPorts.Outport(1),destinations(k), ...
        'autorouting','on');
end

save_system(runtimeName,runtimeFile);
runtimeHash = file_sha256(runtimeFile);
sourceAfter = file_record(sourceFile);
frozenAfter = hash_records(frozenFiles);
assert(records_equal(frozenBefore,frozenAfter)&& ...
    hashes_match(frozenAfter,frozenExpected), ...
    'A frozen dependency changed during V2.4-D0 build.');
assert(records_equal(sourceBefore,sourceAfter)&& ...
    strcmp(sourceAfter.sha256,sourceExpected), ...
    'Accepted V2.4-C standalone target changed during V2.4-D0 build.');

stimulus = deterministic_stimulus();
build = struct();
build.stage = 'V2.4-D0';
build.sourceName = sourceName;
build.runtimeName = runtimeName;
build.sourceFile = sourceFile;
build.runtimeFile = runtimeFile;
build.sourceHash = sourceExpected;
build.runtimeHash = runtimeHash;
build.coreFile = coreFile;
build.coreHash = coreExpected;
build.wrapperFile = wrapperFile;
build.wrapperHash = wrapperExpected;
build.subsystemRelative = '/F-Track 100Hz';
build.wrapperRelative = '/F-Track 100Hz/F-Track Stateful Boundary';
build.schedulerRelative = '/F-Track 100Hz Scheduler';
build.sourceBlockNames = sourceBlockNames;
build.variableNames = variableNames;
build.sourcePaths = sourcePaths;
build.stimulus = stimulus;
build.parameters = struct('Ts',0.01,'Vy_F0',0,'P0_F',0.5,'Q_F',0.0025, ...
    'testOnly',true,'tuned',false,'frozenForRuntime',false);
build.sourceBefore = sourceBefore;
build.sourceAfter = sourceAfter;
build.frozenBefore = frozenBefore;
build.frozenAfter = frozenAfter;
build.frozenUnchanged = true;
build.simCalled = false;
build.carSimRun = false;
save(resultFile,'build','-v7');

fprintf(['V2_4D0_BUILD|runtime=%s|source=%s|sources=7|' ...
    'interpolate=off|frozen=1|sim=0|carsim=0\n'], ...
    runtimeHash,sourceExpected);
clear cleanupModel cleanupPath
close_if_loaded(runtimeName);
end

function stimulus = deterministic_stimulus()
t = (0:0.01:0.20).';
n = numel(t);
stimulus = struct();
stimulus.time = t;
stimulus.Ay = ones(n,1);
stimulus.AVz = 0.1*ones(n,1);
stimulus.Vx = 20*ones(n,1);
stimulus.VyFeedback = zeros(n,1);
stimulus.PFeedback = 0.5*ones(n,1);
stimulus.feedbackValid = zeros(n,1);
stimulus.reset = zeros(n,1);
stimulus.VyFeedback(1) = 2.0;
stimulus.PFeedback(1) = 0.8;
stimulus.feedbackValid(1) = 1;
stimulus.reset(1) = 1;
stimulus.VyFeedback(9) = 1.0;
stimulus.PFeedback(9) = 0.25;
stimulus.feedbackValid(9) = 1;
stimulus.VyFeedback(16) = 5.0;
stimulus.PFeedback(16) = 0.75;
stimulus.feedbackValid(16) = 1;
stimulus.reset(16) = 1;
end

function [files,expected] = frozen_manifest(root)
files = {
    fullfile(root,'model','vx_vy_feedback_track_v2_4.slx')
    fullfile(root,'model','vy_feedback_propagation_step.m')
    fullfile(root,'model','vy_feedback_propagation_simulink_sfun.m')
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
    '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84'
    '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'
    '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0'
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
records = repmat(struct('path','','bytes',0,'sha256',''),numel(files),1);
for k=1:numel(files), records(k)=file_record(files{k}); end
end

function ok = hashes_match(records,expected)
ok = numel(records)==numel(expected);
for k=1:numel(records), ok=ok&&strcmp(records(k).sha256,expected{k}); end
end

function ok = records_equal(a,b)
ok = numel(a)==numel(b);
for k=1:numel(a)
    ok=ok&&strcmp(a(k).path,b(k).path)&&a(k).bytes==b(k).bytes&& ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function record = file_record(file)
d = dir(file);
record = struct('path',file,'bytes',d.bytes,'sha256',file_sha256(file));
end

function close_if_loaded(modelName)
if bdIsLoaded(modelName), close_system(modelName,0); end
end

function h = file_sha256(file)
d = java.security.MessageDigest.getInstance('SHA-256');
s = java.io.FileInputStream(java.io.File(file));
ds = java.security.DigestInputStream(s,d);
c = onCleanup(@()ds.close());
while ds.read()~=-1, end
b = typecast(d.digest(),'uint8');
h = upper(reshape(dec2hex(b,2).',1,[]));
clear c
end
