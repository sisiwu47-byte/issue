function report = validate_vy_feedback_track_v2_4d0_runtime_interface(build,doCompile)
%VALIDATE_VY_FEEDBACK_TRACK_V2_4D0_RUNTIME_INTERFACE Static/compile-only audit.

root = fileparts(fileparts(mfilename('fullpath')));
resultFile = fullfile(root,'results','vy_feedback_track_v2_4d0_interface_gates.mat');
if nargin<1 || isempty(build)
    assert(isfile(resultFile), ...
        'Existing V2.4-D0 build report is missing. Run the builder explicitly.');
    s = load(resultFile,'build');
    assert(isfield(s,'build'),'V2.4-D0 result MAT has no build report.');
    build = s.build;
end
if nargin<2, doCompile = false; end

sourceExpected = '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84';
coreExpected = '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF';
wrapperExpected = '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0';
sourceBefore = file_record(build.sourceFile);
runtimeBefore = file_record(build.runtimeFile);
[frozenFiles,frozenExpected] = frozen_manifest(root);
frozenBefore = hash_records(frozenFiles);

oldPath = path;
oldVars = build.variableNames;
cleanup = onCleanup(@()cleanup_all(build,oldPath,oldVars));
addpath(fullfile(root,'model'));
Simulink.fileGenControl('set','CacheFolder', ...
    fullfile(tempdir,'vy_feedback_track_v2_4d0_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_feedback_track_v2_4d0_codegen'), ...
    'createDir',true);
load_system(build.sourceFile);
load_system(build.runtimeFile);

sourceSubsystem = [build.sourceName build.subsystemRelative];
runtimeSubsystem = [build.runtimeName build.subsystemRelative];
sourceWrapper = [build.sourceName build.wrapperRelative];
runtimeWrapper = [build.runtimeName build.wrapperRelative];
sourceScheduler = [build.sourceName build.schedulerRelative];
runtimeScheduler = [build.runtimeName build.schedulerRelative];
sourceSubPorts = get_param(sourceSubsystem,'PortHandles');
runtimeSubPorts = get_param(runtimeSubsystem,'PortHandles');

expectedSources = cellfun(@(n)[build.runtimeName '/' n], ...
    build.sourceBlockNames,'UniformOutput',false);
actualSources = cell(7,1);
routeOK = false(7,1);
sourceSingleDestination = false(7,1);
sourceTypeOK = false(7,1);
variableNameOK = false(7,1);
sampleTimeOK = false(7,1);
interpolateOff = false(7,1);
holdFinal = false(7,1);
for k=1:7
    p = expectedSources{k};
    sourceTypeOK(k) = strcmp(get_param(p,'BlockType'),'FromWorkspace');
    variableNameOK(k) = strcmp(get_param(p,'VariableName'),build.variableNames{k});
    sampleTimeOK(k) = abs(str2double(get_param(p,'SampleTime'))-0.01)<1e-15;
    interpolateOff(k) = strcmpi(get_param(p,'Interpolate'),'off');
    holdFinal(k) = strcmpi(get_param(p,'OutputAfterFinalValue'), ...
        'Holding final value');
    actualSources{k} = source_of_port(runtimeSubPorts.Inport(k));
    routeOK(k) = strcmp(actualSources{k},expectedSources{k});
    sourcePorts = get_param(p,'PortHandles');
    line = get_param(sourcePorts.Outport(1),'Line');
    dst = get_param(line,'DstPortHandle');
    sourceSingleDestination(k) = numel(dst)==1&&dst(1)==runtimeSubPorts.Inport(k);
end

sourceWrapperExists = getSimulinkBlockHandle(sourceWrapper)>0;
runtimeWrapperExists = getSimulinkBlockHandle(runtimeWrapper)>0;
wrapperPathsPreserved = sourceWrapperExists&&runtimeWrapperExists;
functionNameUnchanged = wrapperPathsPreserved&& ...
    strcmp(get_param(sourceWrapper,'FunctionName'), ...
    get_param(runtimeWrapper,'FunctionName'))&& ...
    strcmp(get_param(runtimeWrapper,'FunctionName'), ...
    'vy_feedback_propagation_simulink_sfun');
sourceParams = normalize_text(get_param(sourceWrapper,'Parameters'));
runtimeParams = normalize_text(get_param(runtimeWrapper,'Parameters'));
dialogParametersUnchanged = strcmp(sourceParams,runtimeParams)&& ...
    strcmp(runtimeParams,'0.01,0,0.5,0.0025');

inputCountSeven = numel(sourceSubPorts.Inport)==7&& ...
    numel(runtimeSubPorts.Inport)==7;
outputCountThree = numel(sourceSubPorts.Outport)==3&& ...
    numel(runtimeSubPorts.Outport)==3;
schedulerUnchanged = compare_scheduler(sourceScheduler,runtimeScheduler);
scheduler100Hz = strcmp(get_param(runtimeScheduler,'MaskType'), ...
    'Function-Call Generator')&& ...
    abs(str2double(get_param(runtimeScheduler,'sample_time'))-0.01)<1e-15&& ...
    str2double(get_param(runtimeScheduler,'numberOfIterations'))==1;

stimulus = build.stimulus;
t = double(stimulus.time(:));
signals = {stimulus.Ay,stimulus.AVz,stimulus.Vx,stimulus.VyFeedback, ...
    stimulus.PFeedback,stimulus.feedbackValid,stimulus.reset};
allTwentyOne = numel(t)==21&&abs(t(1))<1e-15&& ...
    abs(t(end)-0.20)<1e-15&&all(abs(diff(t)-0.01)<1e-15)&& ...
    all(cellfun(@(x)numel(x)==numel(t),signals));
identicalTimestamps = allTwentyOne;
resetMultiplePulses = isequal(find(double(stimulus.reset(:))~=0).',[1 16]);
validMultiplePulses = isequal(find(double(stimulus.feedbackValid(:))~=0).',[1 9 16]);
feedbackStateMultipleValues = stimulus.VyFeedback(1)~=build.parameters.Vy_F0&& ...
    stimulus.VyFeedback(9)==1&&stimulus.VyFeedback(16)==5;
feedbackPMultipleValues = stimulus.PFeedback(1)~=build.parameters.P0_F&& ...
    stimulus.PFeedback(9)==0.25&&stimulus.PFeedback(16)==0.75;

allBlocks = find_system(build.runtimeName,'Type','Block');
normalizedBlocks = lower(strjoin(allBlocks,' '));
wrapperText = lower(fileread(build.wrapperFile));
noDKBlocks = ~contains(normalizedBlocks,'d-ekf')&& ...
    ~contains(normalizedBlocks,'k-kf')&&~contains(normalizedBlocks,'dk-ekf')&& ...
    isempty(regexp(wrapperText,'\<vy_d\>|\<vy_k\>|\<p_d\>|\<p_k\>','once'));
noFusion = ~contains(normalizedBlocks,'fusion')&& ...
    isempty(regexp(wrapperText,'\<alpha\w*\>|\<vy_fused\>|\<vy_final\>|weighted sum','once'));
noLifeSig = ~contains(normalizedBlocks,'lifesig')&& ...
    ~contains(normalizedBlocks,'reliability')&& ...
    ~contains(wrapperText,'lifesig')&&~contains(wrapperText,'reliability');
noTrueVy = ~contains(normalizedBlocks,'true vy')&& ...
    isempty(regexp(wrapperText,'\<truevy\>|\<true_vy\>|true vy','once'));
functionNames = block_function_names(allBlocks);
noCarSim = ~any(strcmp(functionNames,'vs_sf'))&& ...
    sum(strcmp(functionNames,'vy_feedback_propagation_simulink_sfun'))==1;
description = get_param(build.runtimeName,'Description');
parametersTestOnly = contains(description,'TEST-ONLY')&& ...
    contains(description,'UNTUNED')&&contains(description,'UNFROZEN')&& ...
    build.parameters.testOnly&&~build.parameters.tuned&& ...
    ~build.parameters.frozenForRuntime;

gates = struct();
gates.runtimeValidationCopyExists = isfile(build.runtimeFile);
gates.acceptedStandaloneHashExact = strcmp(sourceBefore.sha256,sourceExpected);
gates.frozenCoreHashExact = strcmp(file_sha256(build.coreFile),coreExpected);
gates.sFunctionHashExact = strcmp(file_sha256(build.wrapperFile),wrapperExpected);
gates.wrapperBlockPathPreserved = wrapperPathsPreserved;
gates.functionNameUnchanged = functionNameUnchanged;
gates.sFunctionInputCountSeven = inputCountSeven;
gates.sFunctionOutputCountThree = outputCountThree;
gates.schedulerUnchanged = schedulerUnchanged;
gates.scheduler100Hz = scheduler100Hz;
gates.sevenDeterministicSourcesExist = all(sourceTypeOK)&&all(variableNameOK);
gates.allSourceRoutesExact = all(routeOK);
gates.noInputPortPermutation = all(routeOK);
gates.AyRoutesPort1 = routeOK(1);
gates.AVzRoutesPort2 = routeOK(2);
gates.VxRoutesPort3 = routeOK(3);
gates.VyFeedbackRoutesPort4 = routeOK(4);
gates.PFeedbackRoutesPort5 = routeOK(5);
gates.feedbackValidRoutesPort6 = routeOK(6);
gates.resetRoutesPort7 = routeOK(7);
gates.noSourceSemanticFanout = all(sourceSingleDestination);
gates.identicalSourceTimestampsExpressible = identicalTimestamps;
gates.multipleResetPulsesExpressible = resetMultiplePulses;
gates.multipleFeedbackValidPulsesExpressible = validMultiplePulses;
gates.feedbackStateMultipleValuesExpressible = feedbackStateMultipleValues;
gates.feedbackPMultipleValuesExpressible = feedbackPMultipleValues;
gates.noInterpolationAndDiscreteZOH = all(interpolateOff)&& ...
    all(sampleTimeOK)&&all(holdFinal);
gates.noDKBlocks = noDKBlocks;
gates.noFusion = noFusion;
gates.noLifeSigOrReliability = noLifeSig;
gates.noTrueVy = noTrueVy;
gates.noCarSim = noCarSim;
gates.P0QUnchanged = dialogParametersUnchanged;
gates.P0QTestOnlyUntunedUnfrozen = parametersTestOnly;
gates.acceptedSourceTargetUntouched = strcmp(sourceBefore.sha256,sourceExpected)&& ...
    sourceBefore.bytes==build.sourceBefore.bytes;
staticValues = cell2mat(struct2cell(gates));
staticPassed = numel(staticValues)==35&&all(staticValues);

structural = struct();
structural.wrapperBlockParametersIdentical = compare_block_properties( ...
    sourceWrapper,runtimeWrapper,{'BlockType','FunctionName','Parameters'});
structural.inputOutputCountsIdentical = inputCountSeven&&outputCountThree;
structural.schedulerParametersIdentical = schedulerUnchanged;
structural.functionCallRouteIdentical = compare_trigger_route( ...
    sourceSubsystem,sourceScheduler,runtimeSubsystem,runtimeScheduler);
structural.internalBlocksIdentical = isequal( ...
    subsystem_block_signature(sourceSubsystem,build.sourceName), ...
    subsystem_block_signature(runtimeSubsystem,build.runtimeName));
structural.internalLinesIdentical = isequal( ...
    subsystem_line_signature(sourceSubsystem,build.sourceName), ...
    subsystem_line_signature(runtimeSubsystem,build.runtimeName));
structural.outputRoutesIdentical = compare_output_routes( ...
    sourceSubsystem,build.sourceName,runtimeSubsystem,build.runtimeName);
structural.onlyTopLevelStimulusSourcesDiffer = root_structure_except_sources( ...
    build.sourceName,build.runtimeName,build.sourceBlockNames);
structural.estimatorIntegrationStructureUnchanged = all( ...
    cell2mat(struct2cell(structural)));

precompilePassed = staticPassed&&structural.estimatorIntegrationStructureUnchanged;
compile = empty_compile_evidence();
compiledGates = struct();
if doCompile
    if precompilePassed
        assign_stimulus(build.variableNames,stimulus);
        compile.called = true;
        try
            lastwarn('');
            feval(build.runtimeName,[],[],[],'compile');
            compile.passed = true;
            compile.interfaces = compiled_interfaces(runtimeSubsystem);
            compile.sampleTimes = compiled_sample_times( ...
                runtimeSubsystem,runtimeWrapper,runtimeScheduler);
            compile.evidenceCaptured = true;
            [compile.warningMessage,compile.warningIdentifier] = lastwarn;
            feval(build.runtimeName,[],[],[],'term');
            compile.terminationReached = true;
        catch ME
            try
                feval(build.runtimeName,[],[],[],'term');
                compile.terminationReached = true;
            catch
            end
            compile.errorIdentifier = ME.identifier;
            compile.errorMessage = ME.message;
            compile.errorReport = getReport(ME,'extended','hyperlinks','off');
        end
    else
        compile.errorIdentifier = 'V2_4D0:PrecompileGateFailed';
        compile.errorMessage = 'Compile not called because static or structural gates failed.';
    end
end

if compile.evidenceCaptured
    in = compile.interfaces.inputs;
    out = compile.interfaces.outputs;
    compiledGates.compileCalled = compile.called;
    compiledGates.compilePassed = compile.passed;
    compiledGates.terminationReached = compile.terminationReached;
    compiledGates.evidenceCaptured = compile.evidenceCaptured;
    compiledGates.sevenInputScalarDouble = numel(in)==7&& ...
        all(arrayfun(@(x)x.width==1&&strcmp(x.type,'double'),in));
    compiledGates.VyOutputScalarDouble = out(1).width==1&&strcmp(out(1).type,'double');
    compiledGates.POutputScalarDouble = out(2).width==1&&strcmp(out(2).type,'double');
    compiledGates.diagOutputThreeByOneDouble = out(3).width==3&& ...
        isequal(out(3).shape,[3 1])&&strcmp(out(3).type,'double');
    compiledGates.schedulerSampleTime100Hz = ...
        isequal(compile.sampleTimes.schedulerConfigured,[0.01 0]);
    compiledGates.functionCallSampleTime100Hz = ...
        contains_period(compile.sampleTimes.subsystem,0.01)|| ...
        contains_period(compile.sampleTimes.wrapper,0.01);
    compiledGates.noDimensionTypeSampleTimeConflict = compile.passed;
end
if isempty(fieldnames(compiledGates))
    compiledValues = [];
else
    compiledValues = cell2mat(struct2cell(compiledGates));
end

clear cleanup
cleanup_all(build,oldPath,oldVars);
sourceAfter = file_record(build.sourceFile);
runtimeAfter = file_record(build.runtimeFile);
frozenAfter = hash_records(frozenFiles);
sourceUntouched = records_equal(sourceBefore,sourceAfter)&& ...
    strcmp(sourceAfter.sha256,sourceExpected);
runtimeNoWrite = records_equal(runtimeBefore,runtimeAfter);
frozenUnchanged = records_equal(frozenBefore,frozenAfter)&& ...
    hashes_match(frozenAfter,frozenExpected);

report = struct();
report.stage = 'V2.4-D0';
report.gates = gates;
report.gateCount = numel(staticValues);
report.gatesTrue = sum(staticValues);
report.staticPassed = staticPassed;
report.structural = structural;
report.precompilePassed = precompilePassed;
report.compile = compile;
report.compiledGates = compiledGates;
report.compiledGateCount = numel(compiledValues);
report.compiledGatesTrue = sum(compiledValues);
report.compiledPassed = ~doCompile||(~isempty(compiledValues)&&all(compiledValues));
report.passed = precompilePassed&&report.compiledPassed&& ...
    sourceUntouched&&runtimeNoWrite&&frozenUnchanged;
report.actualSources = actualSources;
report.variableNames = build.variableNames;
report.stimulus = stimulus;
report.parameters = build.parameters;
report.sourceBefore = sourceBefore;
report.sourceAfter = sourceAfter;
report.runtimeBefore = runtimeBefore;
report.runtimeAfter = runtimeAfter;
report.sourceUntouched = sourceUntouched;
report.runtimeNoWriteDuringValidation = runtimeNoWrite;
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.frozenUnchanged = frozenUnchanged;
report.estimatorIntegrationStructureUnchanged = ...
    structural.estimatorIntegrationStructureUnchanged;
report.simCalled = false;
report.carSimRun = false;
report.runtimeAuthorizationConsumed = false;
save(resultFile,'build','report','-v7');

fprintf(['V2_4D0_VALIDATE|static=%d/%d|structure=%d|compileCalled=%d|' ...
    'compile=%d|compiled=%d/%d|term=%d|passed=%d|sim=0|carsim=0\n'], ...
    report.gatesTrue,report.gateCount, ...
    report.estimatorIntegrationStructureUnchanged,compile.called,compile.passed, ...
    report.compiledGatesTrue,report.compiledGateCount, ...
    compile.terminationReached,report.passed);
if ~report.passed
    error('V2_4D0:InterfaceGateFailed', ...
        'V2.4-D0 interface gate failed: %s',compile.errorMessage);
end
end

function assign_stimulus(names,s)
data = {s.Ay,s.AVz,s.Vx,s.VyFeedback,s.PFeedback,s.feedbackValid,s.reset};
for k=1:7
    assignin('base',names{k},[double(s.time(:)) double(data{k}(:))]);
end
end

function compile = empty_compile_evidence()
compile = struct('called',false,'passed',false,'terminationReached',false, ...
    'evidenceCaptured',false,'interfaces',struct(),'sampleTimes',struct(), ...
    'warningMessage','','warningIdentifier','','errorIdentifier','', ...
    'errorMessage','','errorReport','');
end

function interfaces = compiled_interfaces(subsystem)
p = get_param(subsystem,'PortHandles');
interfaces = struct();
interfaces.inputs = repmat(struct('shape',[],'width',0,'type',''),7,1);
interfaces.outputs = repmat(struct('shape',[],'width',0,'type',''),3,1);
for k=1:7, interfaces.inputs(k)=compiled_port(p.Inport(k)); end
for k=1:3, interfaces.outputs(k)=compiled_port(p.Outport(k)); end
end

function item = compiled_port(port)
d = double(get_param(port,'CompiledPortDimensions'));
if numel(d)>=2&&d(1)==numel(d)-1, shape=d(2:end); else, shape=d; end
item = struct('shape',shape,'width', ...
    double(get_param(port,'CompiledPortWidth')), ...
    'type',get_param(port,'CompiledPortDataType'));
end

function st = compiled_sample_times(subsystem,wrapper,scheduler)
st = struct();
st.subsystem = get_param(subsystem,'CompiledSampleTime');
st.wrapper = get_param(wrapper,'CompiledSampleTime');
st.schedulerConfigured = [str2double(get_param(scheduler,'sample_time')) 0];
end

function tf = contains_period(value,period)
tf = false;
if isnumeric(value)
    v = double(value);
    if isvector(v)&&~isempty(v), tf=any(abs(v(1:2:end)-period)<1e-12); end
elseif iscell(value)
    for k=1:numel(value), tf=tf||contains_period(value{k},period); end
end
end

function ok = compare_scheduler(a,b)
ok = compare_block_properties(a,b, ...
    {'BlockType','MaskType','sample_time','numberOfIterations'});
end

function ok = compare_block_properties(a,b,properties)
ok = true;
for k=1:numel(properties)
    ok=ok&&isequal(get_param(a,properties{k}),get_param(b,properties{k}));
end
end

function ok = compare_trigger_route(sourceSub,sourceScheduler,runtimeSub,runtimeScheduler)
sp = get_param(sourceSub,'PortHandles'); rp = get_param(runtimeSub,'PortHandles');
ok = strcmp(source_of_port(sp.Trigger(1)),sourceScheduler)&& ...
    strcmp(source_of_port(rp.Trigger(1)),runtimeScheduler)&& ...
    strcmp(get_param([sourceSub '/function'],'TriggerType'),'function-call')&& ...
    strcmp(get_param([runtimeSub '/function'],'TriggerType'),'function-call');
end

function sig = subsystem_block_signature(subsystem,modelName)
blocks = find_system(subsystem,'LookUnderMasks','all','FollowLinks','on', ...
    'SearchDepth',1,'Type','Block');
sig = cell(numel(blocks),1);
props = {'BlockType','Port','FunctionName','Parameters','TriggerType'};
for i=1:numel(blocks)
    parts = cell(numel(props),1);
    for j=1:numel(props)
        try
            parts{j} = char(string(get_param(blocks{i},props{j})));
        catch
            parts{j} = '';
        end
    end
    sig{i}=strjoin([{relative_path(blocks{i},modelName)};parts],'|');
end
sig=sort(sig);
end

function sig = subsystem_line_signature(subsystem,modelName)
lines = find_system(subsystem,'FindAll','on','SearchDepth',1,'Type','line');
sig = {};
for i=1:numel(lines)
    sb=get_param(lines(i),'SrcBlockHandle'); sp=get_param(lines(i),'SrcPortHandle');
    db=get_param(lines(i),'DstBlockHandle'); dp=get_param(lines(i),'DstPortHandle');
    if sb==-1||sp==-1, continue, end
    for j=1:numel(db)
        if db(j)==-1||dp(j)==-1, continue, end
        srcPortType = get_param(sp,'PortType');
        srcPortNumber = char(string(get_param(sp,'PortNumber')));
        dstPortType = get_param(dp(j),'PortType');
        dstPortNumber = char(string(get_param(dp(j),'PortNumber')));
        sig{end+1,1}=sprintf('%s|%s:%s>%s|%s:%s', ...
            relative_path(getfullname(sb),modelName), ...
            srcPortType,srcPortNumber, ...
            relative_path(getfullname(db(j)),modelName), ...
            dstPortType,dstPortNumber); %#ok<AGROW>
    end
end
sig=sort(sig);
end

function ok = compare_output_routes(sourceSub,sourceName,runtimeSub,runtimeName)
sp=get_param(sourceSub,'PortHandles'); rp=get_param(runtimeSub,'PortHandles');
ok=numel(sp.Outport)==3&&numel(rp.Outport)==3;
for k=1:3
    a=destination_of_port(sp.Outport(k)); b=destination_of_port(rp.Outport(k));
    a=cellfun(@(x)relative_path(x,sourceName),a,'UniformOutput',false);
    b=cellfun(@(x)relative_path(x,runtimeName),b,'UniformOutput',false);
    ok=ok&&isequal(sort(a),sort(b));
end
end

function ok = root_structure_except_sources(sourceName,runtimeName,sourceBlockNames)
a=find_system(sourceName,'SearchDepth',1,'Type','Block');
b=find_system(runtimeName,'SearchDepth',1,'Type','Block');
a=remove_source_blocks(a,sourceName,sourceBlockNames);
b=remove_source_blocks(b,runtimeName,sourceBlockNames);
sa=cellfun(@(x)root_block_signature(x,sourceName),a,'UniformOutput',false);
sb=cellfun(@(x)root_block_signature(x,runtimeName),b,'UniformOutput',false);
ok=isequal(sort(sa),sort(sb));
end

function blocks = remove_source_blocks(blocks,modelName,names)
excluded=cellfun(@(n)[modelName '/' n],names,'UniformOutput',false);
blocks=blocks(~ismember(blocks,excluded));
end

function s = root_block_signature(block,modelName)
props={'BlockType','Port','MaskType','sample_time','numberOfIterations'};
values=cell(numel(props),1);
for k=1:numel(props)
    try
        values{k} = char(string(get_param(block,props{k})));
    catch
        values{k} = '';
    end
end
s=strjoin([{relative_path(block,modelName)};values],'|');
end

function p = relative_path(full,modelName)
p=char(full);
if startsWith(p,modelName), p=p(numel(modelName)+1:end); end
end

function source = source_of_port(port)
line=get_param(port,'Line');
assert(line~=-1,'Expected connected input/trigger port.');
source=getfullname(get_param(line,'SrcBlockHandle'));
end

function destinations = destination_of_port(port)
line=get_param(port,'Line');
assert(line~=-1,'Expected connected output port.');
dst=get_param(line,'DstBlockHandle');
destinations=cell(numel(dst),1);
for k=1:numel(dst), destinations{k}=getfullname(dst(k)); end
end

function names = block_function_names(blocks)
names={};
for k=1:numel(blocks)
    try
        n=get_param(blocks{k},'FunctionName');
        if ~isempty(n), names{end+1,1}=n; end %#ok<AGROW>
    catch
    end
end
end

function text = normalize_text(text)
text=regexprep(text,'\s+','');
end

function cleanup_all(build,oldPath,vars)
path(oldPath);
for n={build.runtimeName,build.sourceName}
    if bdIsLoaded(n{1})
        try, feval(n{1},[],[],[],'term'); catch, end
        close_system(n{1},0);
    end
end
for k=1:numel(vars)
    try, evalin('base',['clear ' vars{k}]); catch, end
end
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
records=repmat(struct('path','','bytes',0,'sha256',''),numel(files),1);
for k=1:numel(files), records(k)=file_record(files{k}); end
end

function ok = hashes_match(records,expected)
ok=numel(records)==numel(expected);
for k=1:numel(records), ok=ok&&strcmp(records(k).sha256,expected{k}); end
end

function ok = records_equal(a,b)
ok=numel(a)==numel(b);
for k=1:numel(a)
    ok=ok&&strcmp(a(k).path,b(k).path)&&a(k).bytes==b(k).bytes&& ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function record = file_record(file)
d=dir(file);
record=struct('path',file,'bytes',d.bytes,'sha256',file_sha256(file));
end

function h = file_sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(file));
ds=java.security.DigestInputStream(s,d);
c=onCleanup(@()ds.close());
while ds.read()~=-1, end
b=typecast(d.digest(),'uint8');
h=upper(reshape(dec2hex(b,2).',1,[]));
clear c
end
