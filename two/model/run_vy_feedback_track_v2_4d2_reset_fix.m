function runtime = run_vy_feedback_track_v2_4d2_reset_fix()
%RUN_VY_FEEDBACK_TRACK_V2_4D2_RESET_FIX One corrected 0.20-s diagnostic run.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
resultDir = fullfile(root,'results');
modelName = 'vx_vy_feedback_track_v2_4d_runtime';
modelFile = fullfile(modelDir,[modelName '.slx']);
resultFile = fullfile(resultDir,'vy_feedback_track_v2_4d2_reset_fix_validation.mat');
originalResultFile = fullfile(resultDir,'vy_feedback_track_v2_4d_standalone.mat');
wrapperBlock = [modelName '/F-Track 100Hz/F-Track Stateful Boundary'];
scheduler = [modelName '/F-Track 100Hz Scheduler'];

modelExpected = 'B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A';
coreExpected = '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF';
wrapperExpected = '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0';
originalResultExpected = '5B1376DCA2884636E675B5AAAD2266707D136DFF85C804B921E209A49D9A5C8C';

assert(~isfile(resultFile), ...
    'V2.4-D2 result already exists; another diagnostic runtime is prohibited.');
assert(isfile(originalResultFile)&& ...
    strcmp(file_sha256(originalResultFile),originalResultExpected), ...
    'Original failed V2.4-D evidence is missing or changed.');
originalResultBefore = file_record(originalResultFile);
modelBefore = file_record(modelFile);
assert(strcmp(modelBefore.sha256,modelExpected), ...
    'Runtime validation model hash mismatch before D2.');
assert(strcmp(file_sha256(fullfile(modelDir,'vy_feedback_propagation_step.m')), ...
    coreExpected),'Frozen F-track core hash mismatch before D2.');
assert(strcmp(file_sha256(fullfile(modelDir, ...
    'vy_feedback_propagation_simulink_sfun.m')),wrapperExpected), ...
    'Accepted F-track S-function hash mismatch before D2.');
[frozenFiles,frozenExpected] = frozen_manifest(root);
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'Frozen dependency mismatch before D2.');

oldPath = path;
cleanup = onCleanup(@()cleanup_model(modelName,oldPath));
addpath(modelDir);
Simulink.fileGenControl('set','CacheFolder', ...
    fullfile(tempdir,'vy_feedback_track_v2_4d2_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_feedback_track_v2_4d2_codegen'), ...
    'createDir',true);
load_system(modelFile);

assert(strcmp(get_param(wrapperBlock,'FunctionName'), ...
    'vy_feedback_propagation_simulink_sfun'), ...
    'F-track S-function boundary changed.');
params = parse_parameters(get_param(wrapperBlock,'Parameters'));
assert(abs(params.Ts-0.01)<1e-15, ...
    'D2 requires the existing Ts=0.01 s dialog parameter.');
assert(strcmp(get_param(scheduler,'MaskType'),'Function-Call Generator')&& ...
    abs(str2double(get_param(scheduler,'sample_time'))-params.Ts)<1e-15&& ...
    str2double(get_param(scheduler,'numberOfIterations'))==1, ...
    'F-track scheduler is not the accepted 100-Hz generator.');

sourceNames = {
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
sourceGate = true(7,1);
for k=1:7
    block = [modelName '/' sourceNames{k}];
    sourceGate(k) = strcmp(get_param(block,'BlockType'),'FromWorkspace')&& ...
        strcmp(get_param(block,'VariableName'),variableNames{k})&& ...
        strcmpi(get_param(block,'Interpolate'),'off')&& ...
        abs(str2double(get_param(block,'SampleTime'))-params.Ts)<1e-15&& ...
        strcmpi(get_param(block,'OutputAfterFinalValue'),'Holding final value');
end
assert(all(sourceGate),'A D2 From Workspace source configuration changed.');

previous = load(originalResultFile,'runtime');
tPrevious = double(previous.runtime.logs.Vy_F.time(:));
tick = (0:20).';
tNew = double(tick)*params.Ts;
alignment = struct();
alignment.previousSampleCount = numel(tPrevious);
alignment.newSampleCount = numel(tNew);
alignment.maxAbsTimeDiff = max(abs(tNew-tPrevious));
alignment.isequal = isequal(tNew,tPrevious);
alignment.index16New = tNew(16);
alignment.index16Previous = tPrevious(16);
alignment.index16Difference = tNew(16)-tPrevious(16);
alignment.passed = alignment.previousSampleCount==21&& ...
    alignment.newSampleCount==21&&alignment.maxAbsTimeDiff==0&&alignment.isequal;
fprintf(['V2_4D2_PREFLIGHT_TIME|N=%d/%d|maxAbs=%.17g|isequal=%d|' ...
    'i16=[%.17g %.17g]|diff=%.17g\n'], ...
    alignment.newSampleCount,alignment.previousSampleCount, ...
    alignment.maxAbsTimeDiff,alignment.isequal,alignment.index16New, ...
    alignment.index16Previous,alignment.index16Difference);
assert(alignment.passed, ...
    'Corrected integer-tick timestamps do not exactly match prior F hits.');

inputs = deterministic_inputs(tick,tNew,params);
inputGate = validate_inputs(inputs,params,tPrevious);
assert(inputGate.passed,'D2 deterministic input preflight failed.');
independence = independence_audit(modelName);
assert(all(cell2mat(struct2cell(independence))), ...
    'Standalone independence gate failed before D2 simulation.');
fprintf(['V2_4D2_PREFLIGHT_INPUTS|container=double_matrix|N=21|' ...
    'sameTime=1|strict=1|duplicates=0|reset=%s|valid=%s|' ...
    'resetTimes=%s|interpolate=off\n'], ...
    mat2str(find(inputs.reset~=0).'), ...
    mat2str(find(inputs.feedbackValid~=0).'), ...
    mat2str(inputs.time(inputs.reset~=0).',17));

simIn = Simulink.SimulationInput(modelName);
inputData = {inputs.Ay,inputs.AVz,inputs.Vx,inputs.VyFeedback, ...
    inputs.PFeedback,inputs.feedbackValid,inputs.reset};
for k=1:7
    simIn = simIn.setVariable(variableNames{k}, ...
        [inputs.time inputData{k}]);
end
simIn = simIn.setModelParameter( ...
    'StartTime','0','StopTime','0.20', ...
    'ReturnWorkspaceOutputs','on', ...
    'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset', ...
    'SaveTime','on','TimeSaveName','tout');

runtime = struct();
runtime.stage = 'V2.4-D2';
runtime.modelName = modelName;
runtime.modelFile = modelFile;
runtime.resultFile = resultFile;
runtime.originalResultFile = originalResultFile;
runtime.modelBefore = modelBefore;
runtime.originalResultBefore = originalResultBefore;
runtime.parameters = params;
runtime.parameters.testOnly = true;
runtime.parameters.tuned = false;
runtime.parameters.frozenForRuntime = false;
runtime.alignment = alignment;
runtime.inputPreflight = inputGate;
runtime.inputs = inputs;
runtime.variableNames = variableNames;
runtime.independence = independence;
runtime.frozenBefore = frozenBefore;
runtime.simCalled = true;
runtime.runtimeAuthorizationConsumed = true;
runtime.simulationCompleted = false;
runtime.carSimRun = false;

try
    simOut = sim(simIn); % The only authorized V2.4-D2 sim() call.
catch ME
    runtime.simulationErrorIdentifier = ME.identifier;
    runtime.simulationErrorMessage = ME.message;
    runtime.simulationErrorReport = getReport(ME,'extended','hyperlinks','off');
    save(resultFile,'runtime','-v7');
    rethrow(ME);
end
runtime.simulationCompleted = true;
runtime.logs.Vy_F = output_signal(simOut,1,'Vy_F',1);
runtime.logs.P_F = output_signal(simOut,2,'P_F',1);
runtime.logs.diag_F = output_signal(simOut,3,'diag_F',3);
runtime.actualStopTime = runtime.logs.Vy_F.time(end);

clear simOut
clear cleanup
cleanup_model(modelName,oldPath);
runtime.modelAfter = file_record(modelFile);
runtime.originalResultAfter = file_record(originalResultFile);
runtime.frozenAfter = hash_records(frozenFiles);
runtime.modelUnchanged = records_equal(runtime.modelBefore,runtime.modelAfter)&& ...
    strcmp(runtime.modelAfter.sha256,modelExpected);
runtime.originalResultUnchanged = records_equal( ...
    runtime.originalResultBefore,runtime.originalResultAfter)&& ...
    strcmp(runtime.originalResultAfter.sha256,originalResultExpected);
runtime.frozenUnchanged = records_equal(frozenBefore,runtime.frozenAfter)&& ...
    hashes_match(runtime.frozenAfter,frozenExpected);
assert(runtime.modelUnchanged,'Runtime validation model changed during D2.');
assert(runtime.originalResultUnchanged,'Original failed evidence changed during D2.');
assert(runtime.frozenUnchanged,'A frozen dependency changed during D2.');
save(resultFile,'runtime','-v7');

fprintf(['V2_4D2_RUN|simCalled=1|completed=%d|samples=%d/%d/%d|' ...
    't=[%.17g %.17g]|model=%d|original=%d|frozen=%d|carsim=0\n'], ...
    runtime.simulationCompleted,numel(runtime.logs.Vy_F.time), ...
    numel(runtime.logs.P_F.time),numel(runtime.logs.diag_F.time), ...
    runtime.logs.Vy_F.time(1),runtime.logs.Vy_F.time(end), ...
    runtime.modelUnchanged,runtime.originalResultUnchanged, ...
    runtime.frozenUnchanged);
end

function inputs = deterministic_inputs(tick,t,params)
n = numel(t);
inputs = struct();
inputs.tick = tick;
inputs.time = t;
inputs.Ay = ones(n,1);
inputs.AVz = 0.1*ones(n,1);
inputs.Vx = 20*ones(n,1);
inputs.VyFeedback = zeros(n,1);
inputs.PFeedback = params.P0_F*ones(n,1);
inputs.feedbackValid = zeros(n,1);
inputs.reset = zeros(n,1);
inputs.VyFeedback(1)=2.0; inputs.PFeedback(1)=0.8;
inputs.feedbackValid(1)=1; inputs.reset(1)=1;
inputs.VyFeedback(9)=1.0; inputs.PFeedback(9)=0.25;
inputs.feedbackValid(9)=1;
inputs.VyFeedback(16)=5.0; inputs.PFeedback(16)=0.75;
inputs.feedbackValid(16)=1; inputs.reset(16)=1;
end

function gate = validate_inputs(inputs,params,tPrevious)
fields={'Ay','AVz','Vx','VyFeedback','PFeedback','feedbackValid','reset'};
n=numel(inputs.time);
sameTime=true; finite=true;
for k=1:numel(fields)
    x=inputs.(fields{k});
    sameTime=sameTime&&numel(x)==n;
    finite=finite&&all(isfinite(x));
end
gate=struct();
gate.containerType = 'double matrix [time value]';
gate.sampleCount = n;
gate.sameTimeVector = sameTime&&isequal(inputs.time,tPrevious);
gate.strictlyIncreasing = all(diff(inputs.time)>0);
gate.duplicateCount = sum(diff(inputs.time)==0);
gate.allFinite = finite&&all(isfinite(inputs.time));
gate.resetIndicesExact = isequal(find(inputs.reset~=0),[1;16]);
gate.feedbackValidIndicesExact = isequal(find(inputs.feedbackValid~=0),[1;9;16]);
gate.resetBreakpoint16Exact = inputs.time(16)==tPrevious(16);
gate.physicalInputsExact = all(inputs.Ay==1)&&all(inputs.AVz==0.1)&& ...
    all(inputs.Vx==20);
gate.feedbackValuesExact = inputs.VyFeedback(1)==2&& ...
    inputs.PFeedback(1)==0.8&&inputs.VyFeedback(9)==1&& ...
    inputs.PFeedback(9)==0.25&&inputs.VyFeedback(16)==5&& ...
    inputs.PFeedback(16)==0.75&&inputs.VyFeedback(1)~=params.Vy_F0&& ...
    inputs.PFeedback(1)~=params.P0_F;
gate.passed = n==21 && gate.sameTimeVector && gate.strictlyIncreasing && ...
    gate.duplicateCount==0 && gate.allFinite && gate.resetIndicesExact && ...
    gate.feedbackValidIndicesExact && gate.resetBreakpoint16Exact && ...
    gate.physicalInputsExact && gate.feedbackValuesExact;
end

function params = parse_parameters(text)
values=str2double(strsplit(regexprep(text,'\s+',''),','));
assert(numel(values)==4&&all(isfinite(values)), ...
    'Unable to read the F-track dialog parameters.');
params=struct('Ts',values(1),'Vy_F0',values(2), ...
    'P0_F',values(3),'Q_F',values(4));
end

function signal = output_signal(simOut,index,name,width)
yout=simOut.get('yout');
assert(isa(yout,'Simulink.SimulationData.Dataset'), ...
    'Root output yout is not a Dataset.');
element=yout.get(index);
assert(~isempty(element)&&isa(element.Values,'timeseries'), ...
    'Runtime output %s is missing or is not a timeseries.',name);
time=double(element.Values.Time(:));
raw=squeeze(double(element.Values.Data));
if width==1
    assert(numel(raw)==numel(time),'Scalar output %s size mismatch.',name);
    data=reshape(raw,[],1);
elseif size(raw,1)==numel(time)
    data=reshape(raw,numel(time),[]);
elseif size(raw,ndims(raw))==numel(time)
    data=reshape(raw,[],numel(time)).';
else
    error('V2_4D2:OutputShape','Cannot normalize output %s.',name);
end
assert(size(data,2)==width,'Runtime output %s width mismatch.',name);
signal=struct('name',name,'time',time,'data',data, ...
    'originalDataSize',size(element.Values.Data));
end

function audit = independence_audit(modelName)
blocks=find_system(modelName,'Type','Block');
text=lower(strjoin(blocks,' '));
functionNames={};
for k=1:numel(blocks)
    try
        value=get_param(blocks{k},'FunctionName');
        if ~isempty(value), functionNames{end+1,1}=value; end %#ok<AGROW>
    catch
    end
end
audit=struct();
audit.noDEKF=~contains(text,'d-ekf')&&~contains(text,'vy_d')&&~contains(text,'p_d');
audit.noKKF=~contains(text,'k-kf')&&~contains(text,'vy_k')&&~contains(text,'p_k');
audit.noDKEKF=~contains(text,'dk-ekf');
audit.noFusion=~contains(text,'fusion')&&~contains(text,'weighted sum')&& ...
    ~contains(text,'alpha');
audit.noLifeSig=~contains(text,'lifesig')&&~contains(text,'reliability');
audit.noTrueVy=~contains(text,'true vy')&&~contains(text,'true_vy');
audit.noCarSim=~any(strcmp(functionNames,'vs_sf'));
end

function cleanup_model(modelName,oldPath)
path(oldPath);
if bdIsLoaded(modelName), close_system(modelName,0); end
end

function [files,expected] = frozen_manifest(root)
files={
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
expected={
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

function records=hash_records(files)
records=repmat(struct('path','','bytes',0,'sha256',''),numel(files),1);
for k=1:numel(files), records(k)=file_record(files{k}); end
end

function ok=hashes_match(records,expected)
ok=numel(records)==numel(expected);
for k=1:numel(records), ok=ok&&strcmp(records(k).sha256,expected{k}); end
end

function ok=records_equal(a,b)
ok=numel(a)==numel(b);
for k=1:numel(a)
    ok=ok&&strcmp(a(k).path,b(k).path)&&a(k).bytes==b(k).bytes&& ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function record=file_record(file)
d=dir(file);
record=struct('path',file,'bytes',d.bytes,'sha256',file_sha256(file));
end

function h=file_sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(file));
ds=java.security.DigestInputStream(s,d);
c=onCleanup(@()ds.close());
while ds.read()~=-1, end
b=typecast(d.digest(),'uint8');
h=upper(reshape(dec2hex(b,2).',1,[]));
clear c
end
