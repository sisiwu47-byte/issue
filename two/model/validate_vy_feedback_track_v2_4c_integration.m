function report = validate_vy_feedback_track_v2_4c_integration(build,doCompile)
%VALIDATE_VY_FEEDBACK_TRACK_V2_4C_INTEGRATION Static/compile-only audit.

root = fileparts(fileparts(mfilename('fullpath')));
resultFile = fullfile(root,'results','vy_feedback_track_v2_4c_integration_gates.mat');
if nargin<1 || isempty(build)
    assert(isfile(resultFile), ...
        'Existing V2.4-C build report is missing. Run the builder explicitly.');
    s = load(resultFile,'build');
    assert(isfield(s,'build'),'V2.4-C result MAT has no build report.');
    build = s.build;
end
if nargin<2, doCompile = false; end

targetBefore = file_record(build.targetFile);
[frozenFiles,frozenExpected] = frozen_manifest(root);
frozenBefore = hash_records(frozenFiles);
frozenBeforeOK = hashes_match(frozenBefore,frozenExpected);

oldPath = path;
cleanup = onCleanup(@()cleanup_model(build.modelName,oldPath));
addpath(fullfile(root,'model'));
Simulink.fileGenControl('set','CacheFolder', ...
    fullfile(tempdir,'vy_feedback_track_v2_4c_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_feedback_track_v2_4c_codegen'), ...
    'createDir',true);
load_system(build.targetFile);
m = build.modelName;

wrapperText = fileread(build.wrapperFile);
wrapperLower = lower(wrapperText);
coreText = fileread(build.coreFile);
coreLower = lower(coreText);
outputsText = extract_section(wrapperLower,'function outputs(block)', ...
    'function update(block)');
updateText = extract_section(wrapperLower,'function update(block)', ...
    'function [ts, vy_f0, p0_f, q_f] = parameters(block)');
initializeText = extract_section(wrapperLower, ...
    'function initialize_conditions(block)','function outputs(block)');
postText = extract_section(wrapperLower, ...
    'function post_propagation_setup(block)', ...
    'function initialize_conditions(block)');

subHandle = getSimulinkBlockHandle(build.subsystem);
schedulerHandle = getSimulinkBlockHandle(build.scheduler);
wrapperHandle = getSimulinkBlockHandle(build.wrapperBlock);
subExists = subHandle>0;
schedulerExists = schedulerHandle>0;
wrapperBlockExists = wrapperHandle>0;
subPorts = get_param(build.subsystem,'PortHandles');

coreHash = file_sha256(build.coreFile);
wrapperHash = file_sha256(build.wrapperFile);
coreHashExact = strcmp(coreHash, ...
    '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF');
coreStateless = isempty(regexp(coreLower, ...
    '\<persistent\>|\<global\>|assignin|evalin','once'));
wrapperCallsCoreOnce = numel(strfind(wrapperLower, ...
    'vy_feedback_propagation_step('))==1;
wrapperHashMatchesBuild = strcmp(wrapperHash,build.wrapperHash);
mathCopyTokens = {'prop_term','deltavy','vy_base','p_base', ...
    'ay_imu -','avz_imu*','p_base +','p_base+'};
wrapperNoMathCopy = ~any(cellfun(@(x)contains(wrapperLower,x),mathCopyTokens));

requiredDworks = {'vy_prev','p_prev','vy_feedback_z1', ...
    'p_feedback_z1','feedback_valid_z1'};
fiveDworks = contains(postText,'block.numdworks = 5') && ...
    all(cellfun(@(x)contains(postText,['.name = ''' x '''']),requiredDworks));
dworkScalar = count_token(postText,'.dimensions = 1')==5;
dworkDouble = count_token(postText,'.datatypeid = 0')==5;
dworkDiscrete = count_token(postText,'.usedasdiscstate = true')==5;
dworkUnique = numel(unique(requiredDworks))==5;

sevenInputs = contains(wrapperLower,'block.numinputports = 7');
threeOutputs = contains(wrapperLower,'block.numoutputports = 3');
inputDimsScalar = contains(wrapperLower,'block.inputport(k).dimensions = 1');
outputDimsExact = contains(wrapperLower,'block.outputport(1).dimensions = 1')&& ...
    contains(wrapperLower,'block.outputport(2).dimensions = 1')&& ...
    contains(wrapperLower,'block.outputport(3).dimensions = [3 1]');
ioDouble = contains(wrapperLower,'block.inputport(k).datatypeid = 0')&& ...
    contains(wrapperLower,'block.outputport(k).datatypeid = 0');

physicalDirect = all(cellfun(@(x)contains(wrapperLower,x),{
    'block.inputport(1).directfeedthrough = true'
    'block.inputport(2).directfeedthrough = true'
    'block.inputport(3).directfeedthrough = true'}));
feedbackNonDirect = all(cellfun(@(x)contains(wrapperLower,x),{
    'block.inputport(4).directfeedthrough = false'
    'block.inputport(5).directfeedthrough = false'
    'block.inputport(6).directfeedthrough = false'}));
resetDirect = contains(wrapperLower, ...
    'block.inputport(7).directfeedthrough = true');
outputsNoCurrentFeedback = ~contains(outputsText,'inputport(4)')&& ...
    ~contains(outputsText,'inputport(5)')&&~contains(outputsText,'inputport(6)');
outputsReadsDelayedTriple = contains(outputsText,'dwork(3).data')&& ...
    contains(outputsText,'dwork(4).data')&&contains(outputsText,'dwork(5).data');
outputsZeroStateCommit = isempty(regexp(outputsText, ...
    'block\.dwork\([1-5]\)\.data\s*=','once'));

updateReadsCurrentTriple = contains(updateText,'inputport(4).data')&& ...
    contains(updateText,'inputport(5).data')&&contains(updateText,'inputport(6).data');
updateCommitsOutputs = contains(updateText, ...
    'dwork(1).data = block.outputport(1).data')&& ...
    contains(updateText,'dwork(2).data = block.outputport(2).data');
updateOneCommitStructure = count_token(updateText, ...
    'dwork(1).data = block.outputport(1).data')==1&& ...
    count_token(updateText,'dwork(2).data = block.outputport(2).data')==1;
feedbackAtomicCapture = count_token(updateText,'inputport(4).data')==1&& ...
    count_token(updateText,'inputport(5).data')==1&& ...
    count_token(updateText,'inputport(6).data')==1;
resetClearsDelayValid = contains(updateText,'dwork(5).data = 0')&& ...
    contains(updateText,'if resetactive')&&contains(updateText,'return');
resetInitializesDelayPair = contains(updateText,'dwork(3).data = vy_f0')&& ...
    contains(updateText,'dwork(4).data = p0_f');
initializeAllMemory = contains(initializeText,'dwork(1).data = vy_f0')&& ...
    contains(initializeText,'dwork(2).data = p0_f')&& ...
    contains(initializeText,'dwork(3).data = vy_f0')&& ...
    contains(initializeText,'dwork(4).data = p0_f')&& ...
    contains(initializeText,'dwork(5).data = 0');

allBlocks = find_system(m,'Type','Block');
blockTypes = cellfun(@(b)get_param(b,'BlockType'),allBlocks,'UniformOutput',false);
noExtraDelayBlock = ~any(ismember(blockTypes,{'UnitDelay','Memory','Delay'}));
onlyFiveMemoryStates = fiveDworks&&noExtraDelayBlock;

schedulerMask = get_param(build.scheduler,'MaskType');
scheduler100Hz = strcmp(schedulerMask,'Function-Call Generator')&& ...
    abs(str2double(get_param(build.scheduler,'sample_time'))-0.01)<1e-15&& ...
    str2double(get_param(build.scheduler,'numberOfIterations'))==1;
triggerPath = [build.subsystem '/function'];
triggerFunctionCall = strcmp(get_param(triggerPath,'TriggerType'),'function-call');
schedulerConnection = strcmp(source_of_port(subPorts.Trigger(1)),build.scheduler);
subsystemIOExact = numel(subPorts.Inport)==7&&numel(subPorts.Outport)==3&& ...
    numel(subPorts.Trigger)==1;

actualInputSources = cell(7,1); inputConnections = false(7,1);
for k=1:7
    actualInputSources{k} = source_of_port(subPorts.Inport(k));
    inputConnections(k) = strcmp(actualInputSources{k},build.sourcePaths{k});
end
actualOutputDestinations = cell(3,1); outputConnections = false(3,1);
for k=1:3
    actualOutputDestinations{k} = destination_of_port(subPorts.Outport(k));
    outputConnections(k) = any(strcmp(actualOutputDestinations{k},build.outputPaths{k}));
end

wrapperBlockCorrect = strcmp(get_param(build.wrapperBlock,'BlockType'), ...
    'M-S-Function')&&strcmp(get_param(build.wrapperBlock,'FunctionName'), ...
    'vy_feedback_propagation_simulink_sfun');
dialogParameters = regexprep(get_param(build.wrapperBlock,'Parameters'),'\s+','');
dialogParametersExact = strcmp(dialogParameters,'0.01,0,0.5,0.0025');
modelDescription = get_param(m,'Description');
testOnlyMarked = contains(modelDescription,'TEST-ONLY')&& ...
    contains(modelDescription,'UNTUNED')&&contains(modelDescription,'UNFROZEN')&& ...
    build.parameters.testOnly&&~build.parameters.tuned&& ...
    ~build.parameters.frozenForRuntime;

normalizedModel = lower(strjoin(allBlocks,' '));
noDKDependency = ~contains(normalizedModel,'d-ekf')&& ...
    ~contains(normalizedModel,'k-kf')&&~contains(normalizedModel,'dk-ekf')&& ...
    isempty(regexp(wrapperLower,'\<vy_d\>|\<vy_k\>|\<p_d\>|\<p_k\>|\<r_d\>|\<vx_k\>','once'));
noFusion = ~contains(normalizedModel,'fusion')&& ...
    isempty(regexp(wrapperLower,'\<alpha\w*\>|\<vy_fused\>|\<vy_final\>|weighted sum','once'));
noLifeSigReliability = ~contains(normalizedModel,'lifesig')&& ...
    ~contains(normalizedModel,'reliability')&&~contains(wrapperLower,'lifesig')&& ...
    ~contains(wrapperLower,'reliability');
noTrueVy = ~contains(normalizedModel,'true vy')&& ...
    isempty(regexp(wrapperLower,'\<truevy\>|\<true_vy\>|true vy','once'));
functionNames = {};
for k=1:numel(allBlocks)
    try
        name = get_param(allBlocks{k},'FunctionName');
        if ~isempty(name), functionNames{end+1,1}=name; end %#ok<AGROW>
    catch
    end
end
noCarSim = ~any(strcmp(functionNames,'vs_sf'))&& ...
    sum(strcmp(functionNames,'vy_feedback_propagation_simulink_sfun'))==1;
noSimAPI = ~contains(wrapperLower,'sim(')&&~contains(wrapperLower,'load_system')&& ...
    ~contains(wrapperLower,'set_param');
diagOrderingFixed = contains(coreLower,'1: prop_term')&& ...
    contains(coreLower,'2: deltavy')&&contains(coreLower,'3: feedbackapplied')&& ...
    contains(outputsText,'[vy_f, p_f, diag_f] = vy_feedback_propagation_step')&& ...
    contains(outputsText,'outputport(3).data = diag_f');

gates = struct();
gates.targetExists = isfile(build.targetFile);
gates.wrapperFileExists = isfile(build.wrapperFile);
gates.targetHashMatchesBuild = strcmp(targetBefore.sha256,build.targetHash);
gates.coreHashExact = coreHashExact;
gates.coreStateless = coreStateless;
gates.wrapperHashMatchesBuild = wrapperHashMatchesBuild;
gates.wrapperCallsFrozenCoreOnce = wrapperCallsCoreOnce;
gates.wrapperNoMathCopy = wrapperNoMathCopy;
gates.requiredFiveDworks = fiveDworks;
gates.dworkScalar = dworkScalar;
gates.dworkDouble = dworkDouble;
gates.dworkDiscrete = dworkDiscrete;
gates.dworkNamesUnique = dworkUnique;
gates.sevenInputs = sevenInputs;
gates.threeOutputs = threeOutputs;
gates.inputDimensionsScalar = inputDimsScalar;
gates.outputDimensionsExact = outputDimsExact;
gates.ioTypesDouble = ioDouble;
gates.physicalInputsDirectFeedthrough = physicalDirect;
gates.currentFeedbackNonDirectFeedthrough = feedbackNonDirect;
gates.resetDirectFeedthrough = resetDirect;
gates.outputsIgnoreCurrentFeedback = outputsNoCurrentFeedback;
gates.outputsUseDelayedFeedbackTriple = outputsReadsDelayedTriple;
gates.outputsStateCommitCountZero = outputsZeroStateCommit;
gates.updateReadsCurrentFeedbackTriple = updateReadsCurrentTriple;
gates.updateCommitsVyAndP = updateCommitsOutputs;
gates.updateOneStateCommitStructure = updateOneCommitStructure;
gates.feedbackTripleAtomicCapture = feedbackAtomicCapture;
gates.resetClearsFeedbackValidDelay = resetClearsDelayValid;
gates.resetInitializesDelayedPair = resetInitializesDelayPair;
gates.initializeConditionsAllMemory = initializeAllMemory;
gates.noAdditionalDelayBlock = noExtraDelayBlock;
gates.onlyFiveIndependentMemoryStates = onlyFiveMemoryStates;
gates.subsystemExists = subExists;
gates.schedulerExists = schedulerExists;
gates.scheduler100Hz = scheduler100Hz;
gates.triggerFunctionCall = triggerFunctionCall;
gates.schedulerLocalConnection = schedulerConnection;
gates.subsystemInterfaceCounts = subsystemIOExact;
gates.allInputConnectionsExact = all(inputConnections);
gates.allOutputConnectionsExact = all(outputConnections);
gates.wrapperBlockCorrect = wrapperBlockExists&&wrapperBlockCorrect;
gates.dialogParametersExact = dialogParametersExact;
gates.parametersMarkedTestOnly = testOnlyMarked;
gates.noDKDependency = noDKDependency;
gates.noFusion = noFusion;
gates.noLifeSigOrReliability = noLifeSigReliability;
gates.noTrueVyOnline = noTrueVy;
gates.noCarSim = noCarSim;
gates.noSimulationAPI = noSimAPI;
gates.diagnosticOrderingFixed = diagOrderingFixed;
gates.frozenHashesBeforeExact = frozenBeforeOK;
staticValues = cell2mat(struct2cell(gates));
staticPassed = all(staticValues);

compile = empty_compile_evidence();
compiledGates = struct();
if doCompile
    compile.called = true;
    if staticPassed
        try
            lastwarn('');
            feval(m,[],[],[],'compile');
            compile.passed = true;
            compile.interfaces = compiled_interfaces(build.subsystem);
            compile.sampleTimes = compiled_sample_times(build);
            compile.evidenceCaptured = true;
            [compile.warningMessage,compile.warningIdentifier] = lastwarn;
            feval(m,[],[],[],'term');
            compile.terminationReached = true;
        catch ME
            try
                feval(m,[],[],[],'term');
                compile.terminationReached = true;
            catch
            end
            compile.errorIdentifier = ME.identifier;
            compile.errorMessage = ME.message;
            compile.errorReport = getReport(ME,'extended','hyperlinks','off');
        end
    else
        compile.errorIdentifier = 'V2_4C:StaticGateFailed';
        compile.errorMessage = 'Compile not called because static gates failed.';
    end
end

if compile.evidenceCaptured
    in = compile.interfaces.inputs; out = compile.interfaces.outputs;
    inputScalarDouble = numel(in)==7&&all(arrayfun(@(x)x.width==1&& ...
        strcmp(x.type,'double'),in));
    outputStateDouble = out(1).width==1&&strcmp(out(1).type,'double');
    outputCovDouble = out(2).width==1&&strcmp(out(2).type,'double');
    outputDiagDouble = out(3).width==3&&strcmp(out(3).type,'double');
    sample100Hz = contains_period(compile.sampleTimes.subsystem,0.01)|| ...
        contains_period(compile.sampleTimes.wrapper,0.01);
    compiledGates.compileCalled = compile.called;
    compiledGates.compilePassed = compile.passed;
    compiledGates.terminationReached = compile.terminationReached;
    compiledGates.evidenceCaptured = compile.evidenceCaptured;
    compiledGates.inputScalarDouble = inputScalarDouble;
    compiledGates.outputVyScalarDouble = outputStateDouble;
    compiledGates.outputPScalarDouble = outputCovDouble;
    compiledGates.outputDiagThreeDouble = outputDiagDouble;
    compiledGates.sampleTime100Hz = sample100Hz;
    compiledGates.functionCallRelationshipValid = scheduler100Hz&& ...
        triggerFunctionCall&&schedulerConnection;
    compiledGates.noSampleTimeConflict = compile.passed;
    compiledGates.noAlgebraicLoop = compile.passed&&feedbackNonDirect;
end
if isempty(fieldnames(compiledGates))
    compiledValues = [];
else
    compiledValues = cell2mat(struct2cell(compiledGates));
end

clear cleanup
cleanup_model(build.modelName,oldPath);
targetAfter = file_record(build.targetFile);
frozenAfter = hash_records(frozenFiles);
targetNoWrite = strcmp(targetBefore.sha256,targetAfter.sha256)&& ...
    targetBefore.bytes==targetAfter.bytes;
frozenUnchanged = records_equal(frozenBefore,frozenAfter)&& ...
    hashes_match(frozenAfter,frozenExpected);

report = struct();
report.stage = 'V2.4-C';
report.gates = gates;
report.gateCount = numel(staticValues);
report.gatesTrue = sum(staticValues);
report.staticPassed = staticPassed;
report.compile = compile;
report.compiledGates = compiledGates;
report.compiledGateCount = numel(compiledValues);
report.compiledGatesTrue = sum(compiledValues);
report.passed = staticPassed&&targetNoWrite&&frozenUnchanged&& ...
    (~doCompile||(compile.passed&&compile.terminationReached&& ...
    compile.evidenceCaptured&&all(compiledValues)));
report.actualInputSources = actualInputSources;
report.actualOutputDestinations = actualOutputDestinations;
report.directFeedthrough = struct('Ay',true,'AVz',true,'Vx',true, ...
    'VyFeedbackCurrent',false,'PFeedbackCurrent',false, ...
    'feedbackValidCurrent',false,'reset',true);
report.parameters = build.parameters;
report.coreHash = coreHash;
report.wrapperHash = wrapperHash;
report.targetBefore = targetBefore;
report.targetAfter = targetAfter;
report.targetNoWrite = targetNoWrite;
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.frozenUnchanged = frozenUnchanged;
report.simCalled = false;
report.carSimRun = false;
save(resultFile,'build','report','-v7');

fprintf('V2_4C_VALIDATE|static=%d/%d|compileCalled=%d|compile=%d|compiled=%d/%d|term=%d|passed=%d|sim=0|carsim=0\n', ...
    report.gatesTrue,report.gateCount,compile.called,compile.passed, ...
    report.compiledGatesTrue,report.compiledGateCount, ...
    compile.terminationReached,report.passed);
if doCompile && ~report.passed
    error('V2_4C:IntegrationGateFailed', ...
        'V2.4-C integration gate failed: %s',compile.errorMessage);
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

function st = compiled_sample_times(build)
st = struct();
st.subsystem = get_param(build.subsystem,'CompiledSampleTime');
st.wrapper = get_param(build.wrapperBlock,'CompiledSampleTime');
st.schedulerConfigured = [str2double(get_param(build.scheduler,'sample_time')) 0];
end

function tf = contains_period(value,period)
tf = false;
if isnumeric(value)
    if isvector(value)&&numel(value)>=1
        tf = any(abs(double(value(1:2:end))-period)<1e-12);
    end
elseif iscell(value)
    for k=1:numel(value), tf=tf||contains_period(value{k},period); end
end
end

function section = extract_section(text,startToken,endToken)
a = strfind(text,startToken); b = strfind(text,endToken);
assert(~isempty(a)&&~isempty(b),'Required wrapper source section is missing.');
b = b(find(b>a(1),1,'first'));
assert(~isempty(b),'Required wrapper source section boundary is missing.');
section = text(a(1):b-1);
end

function n = count_token(text,token)
n = numel(strfind(text,token));
end

function source = source_of_port(port)
line = get_param(port,'Line');
assert(line~=-1,'Expected connected input/trigger port.');
src = get_param(line,'SrcBlockHandle');
source = getfullname(src);
end

function destinations = destination_of_port(port)
line = get_param(port,'Line');
assert(line~=-1,'Expected connected output port.');
dst = get_param(line,'DstBlockHandle');
destinations = cell(numel(dst),1);
for k=1:numel(dst), destinations{k}=getfullname(dst(k)); end
end

function record = file_record(file)
d = dir(file);
record = struct('path',file,'bytes',d.bytes,'sha256',file_sha256(file));
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
    records(k).sha256 = file_sha256(files{k});
end
end

function ok = hashes_match(records,expected)
ok = numel(records)==numel(expected);
for k=1:numel(records), ok=ok&&strcmp(records(k).sha256,expected{k}); end
end

function ok = records_equal(a,b)
ok = numel(a)==numel(b);
for k=1:numel(a)
    ok=ok&&strcmp(a(k).path,b(k).path)&&strcmp(a(k).sha256,b(k).sha256);
end
end

function cleanup_model(modelName,oldPath)
path(oldPath);
if bdIsLoaded(modelName)
    try, feval(modelName,[],[],[],'term'); catch, end
    close_system(modelName,0);
end
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
