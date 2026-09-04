function report = validate_vy_reliability_diagnostic_v2_7a2r4()
%VALIDATE_VY_RELIABILITY_DIAGNOSTIC_V2_7A2R4 Model-load/update preflight.
% This validator never calls sim() and never saves the model.

root = fileparts(fileparts(mfilename('fullpath')));
md = fullfile(root,'model');
targetFile = fullfile(md,'vx_vy_reliability_diagnostic_v2_7.slx');
resultFile = fullfile(root,'results', ...
    'vy_reliability_diagnostic_v2_7a2r4_model_load_update.mat');
expectedTargetHash = ...
    '636FFA96F034829FD2EF9E4A2F335537B4DEC0F41424B9DA949BB2C7D4165499';

assert(isfile(targetFile),'Reliability diagnostic target is missing.');
addpath(md);
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

report = struct();
report.stage = 'V2.7-A2R4';
report.targetFile = targetFile;
report.targetHashBefore = file_sha256(targetFile);
report.targetHashExpected = expectedTargetHash;
report.targetHashBeforeOK = strcmp(report.targetHashBefore,expectedTargetHash);
report.modelLoaded = false;
report.compileCalled = false;
report.compilePassed = false;
report.terminationReached = false;
report.compiledEvidenceCaptured = false;
report.simCalled = false;
report.carSimRun = false;
report.firstErrorIdentifier = '';
report.firstErrorMessage = '';
report.firstErrorReport = '';
report.static = struct('dContractOK',false,'kContractOK',false, ...
    'fContractOK',false,'schedulersOK',false, ...
    'requiredLogsPresent',false);

[~,m] = fileparts(targetFile);
validationNames = {'test_speed','test_steer_amplitude', ...
    'test_steer_frequency','vy_v17_mode_code'};
baseState = cellfun(@base_value,validationNames,'UniformOutput',false);
cleanup = onCleanup(@()cleanup_all(m,baseState));

try
    load_system('simulink');
    load_system('Solver_SF');
    load_system(targetFile);
    report.modelLoaded = true;
    validationValues = {20,0.02,0.4,20};
    modelWorkspace = get_param(m,'ModelWorkspace');
    for k=1:numel(validationNames)
        assignin(modelWorkspace,validationNames{k},validationValues{k});
        assignin('base',validationNames{k},validationValues{k});
    end
    report.static.validationWorkspace = cell2struct( ...
        validationValues,validationNames,2);

    dFcn = [m '/Parallel D-EKF 100Hz/vy_dynamic_ekf'];
    dDemux = [m '/Parallel D Output Demux'];
    kWrapper = [m '/K-KF 100Hz/K-KF Wrapper'];
    fBoundary = [m '/F-Track 100Hz/F-Track Stateful Boundary'];
    fSub = [m '/F-Track 100Hz'];
    schedulers = {[m '/Parallel D-EKF 100Hz Scheduler']; ...
        [m '/K-KF 100Hz Scheduler']; [m '/F-Track 100Hz Scheduler']};

    report.static.dExpression = get_param(dFcn,'MATLABFcn');
    report.static.dOutputDimensions = get_param(dFcn,'OutputDimensions');
    report.static.dDemuxOutputs = get_param(dDemux,'Outputs');
    report.static.kScript = wrapper_chart_script(kWrapper);
    report.static.fBoundaryOutputCount = ...
        numel(get_param(fBoundary,'PortHandles').Outport);
    report.static.fSubsystemOutputCount = ...
        numel(get_param(fSub,'PortHandles').Outport);
    report.static.fParameters = get_param(fBoundary,'Parameters');
    report.static.schedulerMaskTypes = cellfun(@(p)get_param(p,'MaskType'), ...
        schedulers,'UniformOutput',false);
    report.static.schedulerSampleTimes = cellfun(@scheduler_sample_time, ...
        schedulers,'UniformOutput',false);

    ws = find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
        'BlockType','ToWorkspace');
    vars = get_param(ws,'VariableName');
    if ischar(vars), vars={vars}; end
    report.static.workspaceVariables = sort(vars(:));
    requiredLogs = {'fusion_vy_d_log';'dekf_P_log';'dekf_diag_log'; ...
        'rel_d_valid_log';'fusion_vy_k_log';'kkf_P_log1'; ...
        'kkf_diag_log1';'fusion_vy_f_log';'fusion_f_P_log'; ...
        'rel_f_reliability_log';'rel_vy_true_100hz_log'; ...
        'rel_common_time_100hz_log'};
    report.static.requiredLogs = requiredLogs;
    report.static.requiredLogsPresent = all(ismember(requiredLogs,vars));
    report.static.dContractOK = ...
        strcmp(strtrim(report.static.dExpression), ...
        'vy_dynamic_ekf_v1_17_reliability_numeric(u,vy_v17_mode_code)') && ...
        strcmp(strtrim(report.static.dOutputDimensions),'71') && ...
        strcmp(regexprep(report.static.dDemuxOutputs,'\s+',''),'[22652]');
    report.static.kContractOK = contains(report.static.kScript, ...
        'diag_out = zeros(7,1);') && ...
        contains(report.static.kScript,'reliability.update_valid_K') && ...
        contains(report.static.kScript,'reliability.nis_valid_K');
    report.static.fContractOK = report.static.fBoundaryOutputCount==4 && ...
        report.static.fSubsystemOutputCount==4 && ...
        strcmp(strtrim(report.static.fParameters),'0.01,0,0.5,0.0025');
    report.static.schedulersOK = all(cellfun(@(x)strcmp(x, ...
        'Function-Call Generator'),report.static.schedulerMaskTypes)) && ...
        all(cellfun(@(x)strcmp(strtrim(x),'0.01'), ...
        report.static.schedulerSampleTimes));

    report.compileCalled = true;
    feval(m,[],[],[],'compile');
    report.compilePassed = true;

    report.compiled = struct();
    report.compiled.dFcn = compiled_interface(dFcn);
    report.compiled.dDemux = compiled_interface(dDemux);
    report.compiled.kSubsystem = compiled_interface([m '/K-KF 100Hz']);
    report.compiled.kWrapper = compiled_interface(kWrapper);
    report.compiled.fSubsystem = compiled_interface(fSub);
    report.compiled.fBoundary = compiled_interface(fBoundary);
    report.compiled.dScheduler = compiled_sample(schedulers{1});
    report.compiled.kScheduler = compiled_sample(schedulers{2});
    report.compiled.fScheduler = compiled_sample(schedulers{3});
    report.compiledEvidenceCaptured = true;

    feval(m,[],[],[],'term');
    report.terminationReached = true;
catch ME
    report.firstErrorIdentifier = ME.identifier;
    report.firstErrorMessage = ME.message;
    report.firstErrorReport = getReport(ME,'extended','hyperlinks','off');
    try
        if bdIsLoaded(m)
            feval(m,[],[],[],'term');
            report.terminationReached = true;
        end
    catch
    end
end

report.targetHashAfter = file_sha256(targetFile);
report.targetHashAfterOK = strcmp(report.targetHashAfter,expectedTargetHash);
report.targetHashUnchanged = strcmp(report.targetHashBefore,report.targetHashAfter);
report.passed = report.targetHashBeforeOK && report.targetHashAfterOK && ...
    report.targetHashUnchanged && report.modelLoaded && ...
    report.static.dContractOK && report.static.kContractOK && ...
    report.static.fContractOK && report.static.schedulersOK && ...
    report.static.requiredLogsPresent && report.compilePassed && ...
    report.terminationReached && report.compiledEvidenceCaptured && ...
    ~report.simCalled && ~report.carSimRun;
save(resultFile,'report','-v7');

fprintf(['V27A2R4_PREFLIGHT|load=%d|compileCalled=%d|compile=%d|' ...
    'term=%d|compiled=%d|logs=%d|passed=%d|sim=%d|carsim=%d\n'], ...
    report.modelLoaded,report.compileCalled,report.compilePassed, ...
    report.terminationReached,report.compiledEvidenceCaptured, ...
    report.static.requiredLogsPresent,report.passed, ...
    report.simCalled,report.carSimRun);
if ~report.passed
    fprintf('FIRST_ERROR_ID=%s\n',report.firstErrorIdentifier);
    fprintf('FIRST_ERROR=%s\n',report.firstErrorMessage);
    error('V2_7A2R4:PreflightFailed','Reliability target preflight failed.');
end
clear cleanup
end

function s=scheduler_sample_time(p)
s='';
try
    s=get_param(p,'sample_time');
catch
    data=get_param(p,'InstanceData');
    for k=1:numel(data)
        if strcmp(data(k).Name,'sample_time'),s=data(k).Value;return,end
    end
end
end

function out=compiled_interface(p)
out=struct();
out.dimensions=get_param(p,'CompiledPortDimensions');
out.dataTypes=get_param(p,'CompiledPortDataTypes');
out.sampleTimes=compiled_sample(p);
end

function out=compiled_sample(p)
try
    out=get_param(p,'CompiledSampleTime');
catch ME
    out=struct('unavailable',true,'identifier',ME.identifier,'message',ME.message);
end
end

function script=wrapper_chart_script(path)
rt=sfroot;
charts=rt.find('-isa','Stateflow.EMChart');
script='';
for k=1:numel(charts)
    if strcmp(charts(k).Path,path)
        script=charts(k).Script;
        return
    end
end
end

function state=base_value(name)
state=struct('name',name,'existed',false,'value',[]);
state.existed=evalin('base',sprintf('exist(''%s'',''var'')',name))~=0;
if state.existed
    state.value=evalin('base',name);
end
end

function cleanup_all(m,baseState)
close_without_save(m);
for k=1:numel(baseState)
    state=baseState{k};
    if state.existed
        assignin('base',state.name,state.value);
    else
        evalin('base',['clear ' state.name]);
    end
end
end

function close_without_save(m)
if bdIsLoaded(m)
    try,close_system(m,0);catch,end
end
if bdIsLoaded('Solver_SF')
    try,close_system('Solver_SF',0);catch,end
end
end

function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');
hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
