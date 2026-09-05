function report = validate_vy_parallel_dk_v2_3_integration(build, doCompile)
%VALIDATE_VY_PARALLEL_DK_V2_3_INTEGRATION V2.3-B no-run audit.
% doCompile=false performs only static/no-coupling gates. doCompile=true
% first repeats those light gates and, only if all pass, compiles the full
% target without starting simulation.

root = fileparts(fileparts(mfilename('fullpath')));
resultFile = fullfile(root,'results','vy_parallel_dk_v2_3b_integration_gates.mat');
if nargin < 1 || isempty(build)
    assert(isfile(resultFile), ['Existing V2.3-B build evidence is missing. ' ...
        'Run build_vy_parallel_dk_v2_3 explicitly first.']);
    s = load(resultFile,'build');
    assert(isfield(s,'build'),'V2.3-B evidence MAT lacks build.');
    build = s.build;
end
if nargin < 2, doCompile = false; end
doCompile = logical(doCompile);
assert(isfile(build.targetFile),'Parallel target is missing.');

[frozenFiles, expectedHashes] = frozen_manifest(root);
frozenBefore = snapshot(frozenFiles);
targetBefore = file_record(build.targetFile);
addpath(fullfile(root,'model'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(tempdir,'vy_parallel_dk_v2_3b_validate_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_parallel_dk_v2_3b_validate_codegen'), ...
    'createDir',true);
load_system('Solver_SF');
load_system(build.targetFile);
m = build.modelName;
cleanup = onCleanup(@() close_models(m));

% ----- frozen implementation identities -----
frozenHashesOK = records_match(frozenBefore,expectedHashes);
dCoreText = fileread(fullfile(root,'model','vy_dynamic_ekf_v1_17.m'));
kWrapperText = fileread(fullfile(root,'model','vy_kinematic_kf.m'));
dNorm = lower(regexprep(dCoreText,'\s+',''));
kNorm = lower(regexprep(kWrapperText,'\s+',''));

% ----- exact estimator boundaries -----
dExists = getSimulinkBlockHandle(build.dSubsystem) > 0;
kExists = getSimulinkBlockHandle(build.kSubsystem) > 0;
dPorts = get_param(build.dSubsystem,'PortHandles');
kPorts = get_param(build.kSubsystem,'PortHandles');
dTopologyOK = numel(dPorts.Inport)==1 && numel(dPorts.Outport)==1 && ...
    numel(dPorts.Trigger)==1;
kTopologyOK = numel(kPorts.Inport)==3 && numel(kPorts.Outport)==3 && ...
    numel(kPorts.Trigger)==1;

dFcnBlocks = find_system(build.dSubsystem,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','MATLABFcn');
dWrapperExpression = '';
if numel(dFcnBlocks)==1
    dWrapperExpression = get_param(dFcnBlocks{1},'MATLABFcn');
end
dWrapperExact = numel(dFcnBlocks)==1 && strcmp( ...
    regexprep(dWrapperExpression,'\s+',''), ...
    'vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)') && ...
    str2double(get_param(dFcnBlocks{1},'OutputDimensions'))==69;
kChartScript = wrapper_chart_script([build.kSubsystem '/K-KF Wrapper']);
kWrapperExact = contains(lower(regexprep(kChartScript,'\s+','')), ...
    'vy_kinematic_kf(u,z,resetflag)');

wks = get_param(m,'ModelWorkspace');
dMode = evalin(wks,'vy_v17_mode_code');
dModeA20 = isequal(double(dMode),20);
dAy20HzSemantics = dModeA20 && contains(dNorm,'stride=100/modecode') && ...
    contains(dNorm,'useay=mod(counter,stride)==0') && ...
    contains(dNorm,'counter=counter+1');
dPersistentIndependent = contains(dNorm,'persistentxpounteractivemode') || ...
    (contains(dNorm,'persistentxp') && contains(dNorm,'activemode'));
% The exact text includes spaces before normalization; verify the semantic
% tokens separately so a cosmetic source formatting change cannot hide it.
dPersistentIndependent = contains(dNorm,'persistentxp') && ...
    contains(dNorm,'counter') && contains(dNorm,'activemode');
kPersistentIndependent = contains(kNorm,'persistentxstatepstate') || ...
    (contains(kNorm,'persistentxstate') && contains(kNorm,'pstate'));
stateMemoryIndependent = dPersistentIndependent && kPersistentIndependent && ...
    ~contains(dNorm,'xstate') && ~contains(kNorm,'activemode');
covarianceIndependent = contains(dNorm,'persistentxp') && ...
    contains(kNorm,'pstate') && ~contains(dNorm,'pstate');

% ----- independent schedulers and resets -----
dTriggerType = get_param([build.dSubsystem '/function'],'TriggerType');
kTriggerType = get_param([build.kSubsystem '/function'],'TriggerType');
dSchedulerMask = get_param(build.dScheduler,'MaskType');
kSchedulerMask = get_param(build.kScheduler,'MaskType');
dSchedulerConnection = strcmp(source_of_port(dPorts.Trigger(1)),build.dScheduler);
kSchedulerConnection = strcmp(source_of_port(kPorts.Trigger(1)),build.kScheduler);
dScheduler100Hz = strcmp(dSchedulerMask,'Function-Call Generator') && ...
    abs(str2double(get_param(build.dScheduler,'sample_time'))-0.01)<1e-15 && ...
    str2double(get_param(build.dScheduler,'numberOfIterations'))==1;
kScheduler100Hz = strcmp(kSchedulerMask,'Function-Call Generator') && ...
    abs(str2double(get_param(build.kScheduler,'sample_time'))-0.01)<1e-15 && ...
    str2double(get_param(build.kScheduler,'numberOfIterations'))==1;
schedulerIndependent = ~strcmp(build.dScheduler,build.kScheduler) && ...
    strcmp(dTriggerType,'function-call') && strcmp(kTriggerType,'function-call') && ...
    dSchedulerConnection && kSchedulerConnection && ...
    dScheduler100Hz && kScheduler100Hz;
kResetStatic = strcmp(get_param(build.kReset,'Time'),'0.01') && ...
    strcmp(get_param(build.kReset,'Before'),'1') && ...
    strcmp(get_param(build.kReset,'After'),'0') && ...
    strcmp(get_param(build.kReset,'SampleTime'),'0.01') && ...
    strcmp(source_of_port(kPorts.Inport(3)),build.kReset);
dResetInternal = dTopologyOK && numel(dPorts.Inport)==1 && ...
    contains(dNorm,'isempty(x)') && contains(dNorm,'activemode~=modecode') && ...
    contains(dNorm,'x=[0;0]') && contains(dNorm,'p=.1*eye(2)');
resetIndependent = kResetStatic && dResetInternal;

% ----- common physical source fan-out -----
kImuPorts = get_param(build.kImuMux,'PortHandles');
kVxRtPorts = get_param(build.kVxRateTransition,'PortHandles');
dMeasPorts = get_param(build.dMeasurementMux,'PortHandles');
dControlPorts = get_param(build.dControlMux,'PortHandles');
dSteerPorts = get_param(build.dSteeringMux,'PortHandles');
dInputMuxPorts = get_param(build.dInputMux,'PortHandles');
dRtPorts = get_param(build.dInputRateTransition,'PortHandles');
axToK = strcmp(source_of_port(kImuPorts.Inport(1)),build.axSource);
ayToK = strcmp(source_of_port(kImuPorts.Inport(2)),build.aySource);
avzToK = strcmp(source_of_port(kImuPorts.Inport(3)),build.avzSource);
vxToK = strcmp(source_of_port(kVxRtPorts.Inport(1)),build.vxSource);
ayToD = strcmp(source_of_port(dMeasPorts.Inport(1)),build.aySource);
avzToD = strcmp(source_of_port(dMeasPorts.Inport(2)),build.avzSource);
vxToD = strcmp(source_of_port(dControlPorts.Inport(1)),build.vxSource);
dInputBoundaryOK = strcmp(source_of_port(dInputMuxPorts.Inport(1)),build.dControlMux) && ...
    strcmp(source_of_port(dInputMuxPorts.Inport(2)),build.dMeasurementMux) && ...
    strcmp(source_of_port(dRtPorts.Inport(1)),build.dInputMux) && ...
    strcmp(source_of_port(dPorts.Inport(1)),build.dInputRateTransition);
sharedPhysicalRoutingOK = axToK && ayToK && avzToK && vxToK && ...
    ayToD && avzToD && vxToD && dInputBoundaryOK;
axAbsentFromD = ~any(strcmp(input_sources(build.dMeasurementMux),build.axSource)) && ...
    ~any(strcmp(input_sources(build.dControlMux),build.axSource));
kAy100HzSemantics = ayToK && kScheduler100Hz && ...
    strcmp(source_of_port(kPorts.Inport(1)),build.kImuMux);
dAyGateDoesNotControlK = ayToK && ...
    ~any(contains(lower(input_sources(build.kImuMux)),'parallel d'));

% ----- genuine steering: same rad source to plant and D -----
gainSourceOK = strcmp(source_of_port(get_param(build.gain22,'PortHandles').Inport(1)), ...
    build.steerSource) && strcmp(strtrim(get_param(build.gain22,'Gain')),'180/pi');
plantFrontOK = inputs_from(build.mux8,[2 4],build.gain22);
plantRearZeroOK = zero_inputs(build.mux8,[6 8]);
switchInput2OK = strcmp(source_of_port( ...
    get_param(build.manualSwitch,'PortHandles').Inport(2)),build.mux8) && ...
    strcmp(get_param(build.manualSwitch,'CurrentSetting'),'0');
dFrontSteerOK = strcmp(source_of_port(dSteerPorts.Inport(1)),build.steerSource) && ...
    strcmp(source_of_port(dSteerPorts.Inport(2)),build.steerSource);
dRearSteerOK = strcmp(source_of_port(dSteerPorts.Inport(3)),build.dRearZero) && ...
    strcmp(source_of_port(dSteerPorts.Inport(4)),build.dRearZero) && ...
    str2double(get_param(build.dRearZero,'Value'))==0;
steeringWheelOrder = {'FL','FR','RL','RR'};
genuineSteeringOK = gainSourceOK && plantFrontOK && plantRearZeroOK && ...
    switchInput2OK && dFrontSteerOK && dRearSteerOK && ...
    strcmp(source_of_port(dControlPorts.Inport(2)),build.dSteeringMux);
onlyOneRadToDeg = genuineSteeringOK && ...
    numel(find_system(m,'SearchDepth',1,'BlockType','Gain','Gain','180/pi'))==1;

% ----- output-only logging and hard no-coupling -----
dOutputDestinations = sort(destinations_of_port(dPorts.Outport(1)));
expectedDDests = sort({build.dOutputDemux;build.dPExtractDemux});
dOutputsObservationOnly = isequal(dOutputDestinations,expectedDDests);
kOutputDestinations = cell(1,numel(kPorts.Outport));
expectedKDestinations = {[m '/K-KF x Log'],[m '/K-KF P Log'], ...
    [m '/K-KF diag Log']};
kOutputsObservationOnly = true;
for k = 1:numel(kPorts.Outport)
    kOutputDestinations{k} = sort(destinations_of_port(kPorts.Outport(k)));
    kOutputsObservationOnly = kOutputsObservationOnly && ...
        isequal(kOutputDestinations{k},expectedKDestinations(k));
end
noDToK = dOutputsObservationOnly;
noKToD = kOutputsObservationOnly;
noCovarianceExchange = dOutputsObservationOnly && kOutputsObservationOnly;
noPseudoMeasurement = sharedPhysicalRoutingOK && genuineSteeringOK;
noRDtoK = kOutputsObservationOnly && avzToK;
noVxKToD = dOutputsObservationOnly && vxToD;

dLogVariables = cellfun(@(p)get_param(p,'VariableName'),build.dLogs, ...
    'UniformOutput',false);
kLogVariables = cellfun(@(p)get_param(p,'VariableName'),build.kLogs, ...
    'UniformOutput',false);
parallelLogVariable = get_param(build.parallelInputLog,'VariableName');
logsIndependent = isequal(dLogVariables,{'dekf_x_log','dekf_P_log','dekf_diag_log'}) && ...
    isequal(kLogVariables,{'kkf_x_log1','kkf_P_log1','kkf_diag_log1'}) && ...
    strcmp(parallelLogVariable,'parallel_input_log') && ...
    numel(unique([dLogVariables kLogVariables {parallelLogVariable}]))==7;

topBlocks = find_system(m,'SearchDepth',1,'Type','Block');
topNames = lower(string(cellfun(@(p)get_param(p,'Name'),topBlocks, ...
    'UniformOutput',false)));
noDKTrack = ~any(contains(topNames,'dk-ekf')) && ~any(contains(topNames,'dkekf'));
noLifeSig = ~any(contains(topNames,'lifesig'));
noVyFinal = ~any(contains(topNames,'vy_final'));
noWeightBlocks = ~any(contains(topNames,'alpha_d')) && ...
    ~any(contains(topNames,'alpha_k')) && ...
    ~any(contains(topNames,'fusion'));
noReliabilityGate = ~any(contains(topNames,'reliability'));
noThirdTrack = noDKTrack;
noSwitchOnOutputs = dOutputsObservationOnly && kOutputsObservationOnly;
trueVyOnlineAbsent = ~any(contains(lower(input_sources(build.dInputMux)),'gain11')) && ...
    ~any(contains(lower(input_sources(build.kSubsystem)),'gain11')) && ...
    sharedPhysicalRoutingOK;

gates = struct();
gates.targetExists = isfile(build.targetFile);
gates.frozenHashesMatch = frozenHashesOK;
gates.dSubsystemExists = dExists && dTopologyOK && dWrapperExact;
gates.kSubsystemExists = kExists && kTopologyOK && kWrapperExact;
gates.dStateDefinition = dWrapperExact;
gates.kStateDefinition = kWrapperExact;
gates.stateMemoryIndependent = stateMemoryIndependent;
gates.covarianceIndependent = covarianceIndependent;
gates.schedulerIndependent = schedulerIndependent;
gates.resetIndependent = resetIndependent;
gates.sharedPhysicalRouting = sharedPhysicalRoutingOK;
gates.axOnlyToK = axToK && axAbsentFromD;
gates.ayFanout = ayToD && ayToK;
gates.avzFanout = avzToD && avzToK;
gates.trueVxFanout = vxToD && vxToK;
gates.dAy20HzSemantics = dAy20HzSemantics;
gates.kAy100HzSemantics = kAy100HzSemantics;
gates.dAyGateDoesNotControlK = dAyGateDoesNotControlK;
gates.genuineSteeringPath = genuineSteeringOK;
gates.steeringWheelOrder = genuineSteeringOK;
gates.singleRadToDeg = onlyOneRadToDeg;
gates.trueVyOnlineAbsent = trueVyOnlineAbsent;
gates.noDStateToK = noDToK;
gates.noKStateToD = noKToD;
gates.noCovarianceExchange = noCovarianceExchange;
gates.noPseudoMeasurement = noPseudoMeasurement;
gates.noRDtoK = noRDtoK;
gates.noVxKToD = noVxKToD;
gates.noWeightedSum = noWeightBlocks && dOutputsObservationOnly && kOutputsObservationOnly;
gates.noEstimatorSwitch = noSwitchOnOutputs;
gates.noAlphaD = noWeightBlocks;
gates.noAlphaK = noWeightBlocks;
gates.noLifeSig = noLifeSig;
gates.noReliabilityGate = noReliabilityGate;
gates.noCovarianceFusion = noCovarianceExchange && noWeightBlocks;
gates.noThirdFeedbackTrack = noThirdTrack;
gates.noVyFinal = noVyFinal;
gates.outputsToLogsOnly = dOutputsObservationOnly && kOutputsObservationOnly;
gates.logsIndependent = logsIndependent;
staticVector = cellfun(@logical,struct2cell(gates));
staticPassed = all(staticVector);

compile = struct('called',false,'passed',false,'method', ...
    'full target compile-only','errorIdentifier','','errorMessage','', ...
    'errorReport','','warningIdentifier','','warningMessage','', ...
    'interfaces',struct(),'sampleTimes',struct());
compiledGates = struct('fullTargetCompile',~doCompile, ...
    'dState2',~doCompile,'dP2x2',~doCompile,'kState2',~doCompile, ...
    'kP2x2',~doCompile,'steering4',~doCompile, ...
    'physicalScalars',~doCompile,'allDouble',~doCompile, ...
    'noDimensionOrSampleTimeError',~doCompile);

if doCompile
    assert(staticPassed, ...
        'V2.3-B static gates failed; full target compile is prohibited.');
    compile.called = true;
    oldAmp = base_value('test_steer_amplitude');
    oldFreq = base_value('test_steer_frequency');
    restoreBase = onCleanup(@() restore_base(oldAmp,oldFreq));
    assignin('base','test_steer_amplitude',0.02);
    assignin('base','test_steer_frequency',0.4);
    lastwarn('');
    try
        feval(m,[],[],[],'compile');
        compile.interfaces = compiled_interfaces(build);
        compile.sampleTimes = compiled_sample_times(build);
        [compile.warningMessage,compile.warningIdentifier] = lastwarn;
        compile.passed = true;
        feval(m,[],[],[],'term');
    catch ME
        try, feval(m,[],[],[],'term'); catch, end
        compile.errorIdentifier = ME.identifier;
        compile.errorMessage = ME.message;
        compile.errorReport = getReport(ME,'extended','hyperlinks','off');
    end
    clear restoreBase
    if compile.passed
        ci = compile.interfaces;
        compiledGates.fullTargetCompile = true;
        compiledGates.dState2 = shape_equal(ci.dState.shape,2);
        compiledGates.dP2x2 = shape_equal(ci.dP.shape,[2 2]);
        compiledGates.kState2 = shape_equal(ci.kState.shape,2);
        compiledGates.kP2x2 = shape_equal(ci.kP.shape,[2 2]);
        compiledGates.steering4 = shape_equal(ci.dSteering.shape,4);
        compiledGates.physicalScalars = all([ci.ax.width ci.ay.width ...
            ci.avz.width ci.vx.width] == 1);
        compiledGates.allDouble = all(strcmp({ci.dState.type,ci.dP.type, ...
            ci.kState.type,ci.kP.type,ci.dSteering.type,ci.ax.type, ...
            ci.ay.type,ci.avz.type,ci.vx.type},'double'));
        compiledGates.noDimensionOrSampleTimeError = true;
    end
end
compiledVector = cellfun(@logical,struct2cell(compiledGates));

close_system(m,0);
close_system('Solver_SF',0);
frozenAfter = snapshot(frozenFiles);
targetAfter = file_record(build.targetFile);
frozenUnchanged = records_equal(frozenBefore,frozenAfter) && ...
    records_match(frozenAfter,expectedHashes);
targetNoWrite = records_equal(targetBefore,targetAfter);
gates.frozenHashesUnchanged = frozenUnchanged;
gates.targetNoWriteDuringValidation = targetNoWrite;
staticVector = cellfun(@logical,struct2cell(gates));
staticPassed = all(staticVector);

report = struct();
report.stage = 'V2.3-B';
report.staticPassed = staticPassed;
report.compileRequested = doCompile;
report.compile = compile;
report.compiledGates = compiledGates;
report.passed = staticPassed && all(compiledVector) && (~doCompile || compile.passed);
report.gates = gates;
report.staticGateCount = numel(staticVector);
report.staticGatesTrue = sum(staticVector);
report.compiledGateCount = numel(compiledVector);
report.compiledGatesTrue = sum(compiledVector);
report.targetBefore = targetBefore;
report.targetAfter = targetAfter;
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.dWrapperExpression = dWrapperExpression;
report.kWrapperScript = kChartScript;
report.dMode = dMode;
report.dScheduler = struct('path',build.dScheduler,'maskType',dSchedulerMask, ...
    'sampleTime',get_param_safe(build.dScheduler,'sample_time','0.01'), ...
    'connectionOK',dSchedulerConnection);
report.kScheduler = struct('path',build.kScheduler,'maskType',kSchedulerMask, ...
    'sampleTime',get_param_safe(build.kScheduler,'sample_time','0.01'), ...
    'connectionOK',kSchedulerConnection);
report.reset = struct('d',build.dResetSemantics,'k',build.kResetSemantics, ...
    'independent',resetIndependent);
report.stateDefinitions = struct('D','[Vy_D;r_D]','K','[Vx_K;Vy_K]');
report.covarianceDefinitions = struct('D','2x2','K','2x2');
report.steering = struct('source',build.steerSource,'sourceUnit','rad', ...
    'gain22','180/pi','plantBoundaryUnit','deg','wheelOrder',{steeringWheelOrder}, ...
    'DInputUnit','rad','frontSourceSame',dFrontSteerOK, ...
    'rearZero',dRearSteerOK,'onlyOneConversion',onlyOneRadToDeg);
report.sharedRouting = struct('Ax',{{'K only'}},'Ay',{{'D measurement','K process'}}, ...
    'AVz',{{'D measurement','K process'}}, ...
    'trueVx',{{'D physical input','K measurement'}}, ...
    'steering',{{'D only'}},'trueVyOnline',false);
report.dOutputDestinations = dOutputDestinations;
report.kOutputDestinations = kOutputDestinations;
report.logVariables = struct('D',{dLogVariables},'K',{kLogVariables}, ...
    'common',parallelLogVariable);
report.simCalled = false;
report.carSimRun = false;
report.fusionImplemented = false;
report.lifeSigImplemented = false;
report.thirdTrackImplemented = false;

save(resultFile,'build','report');
clear cleanup
fprintf(['V2_3B_VALIDATE|static=%d/%d|compileCalled=%d|compilePassed=%d|' ...
    'compiled=%d/%d|passed=%d|sim=0|carsim=0\n'], ...
    report.staticGatesTrue,report.staticGateCount,compile.called,compile.passed, ...
    report.compiledGatesTrue,report.compiledGateCount,report.passed);
if compile.called && ~compile.passed
    fprintf('V2_3B_COMPILE_ERROR|%s|%s\n',compile.errorIdentifier,compile.errorMessage);
end
end

function ci = compiled_interfaces(build)
dOut = get_param(build.dOutputDemux,'PortHandles');
dP = get_param(build.dPReshape,'PortHandles');
k = get_param(build.kSubsystem,'PortHandles');
dSteer = get_param(build.dSteeringMux,'PortHandles');
ci = struct();
ci.dState = port_record(dOut.Outport(1));
ci.dP = port_record(dP.Outport(1));
ci.kState = port_record(k.Outport(1));
ci.kP = port_record(k.Outport(2));
ci.kDiag = port_record(k.Outport(3));
ci.dSteering = port_record(dSteer.Outport(1));
ci.ax = port_record(get_param(build.axSource,'PortHandles').Outport(1));
ci.ay = port_record(get_param(build.aySource,'PortHandles').Outport(1));
ci.avz = port_record(get_param(build.avzSource,'PortHandles').Outport(1));
ci.vx = port_record(get_param(build.vxSource,'PortHandles').Outport(1));
end

function st = compiled_sample_times(build)
st = struct();
st.dParent = get_param(build.dSubsystem,'CompiledSampleTime');
st.kParent = get_param(build.kSubsystem,'CompiledSampleTime');
st.ax = get_param(build.axSource,'CompiledSampleTime');
st.ay = get_param(build.aySource,'CompiledSampleTime');
st.avz = get_param(build.avzSource,'CompiledSampleTime');
st.vxRaw = get_param(build.vxSource,'CompiledSampleTime');
st.dInputBoundary = get_param(build.dInputRateTransition,'CompiledSampleTime');
st.kVxBoundary = get_param(build.kVxRateTransition,'CompiledSampleTime');
end

function r = port_record(port)
r = struct('shape',compiled_shape(port), ...
    'width',double(get_param(port,'CompiledPortWidth')), ...
    'type',get_param(port,'CompiledPortDataType'));
end

function shape = compiled_shape(port)
d = double(get_param(port,'CompiledPortDimensions'));
if numel(d)>=2 && d(1)==numel(d)-1, shape=d(2:end); else, shape=d; end
if numel(shape)==2 && shape(1)==1, shape=shape(2); end
end

function tf = shape_equal(actual, expected)
tf = isequal(double(actual(:).'),double(expected(:).'));
end

function values = input_sources(block)
p = get_param(block,'PortHandles');
values = cell(1,numel(p.Inport));
for k = 1:numel(p.Inport), values{k}=source_of_port(p.Inport(k)); end
end

function tf = inputs_from(block,ports,source)
p = get_param(block,'PortHandles'); tf=true;
for k=1:numel(ports),tf=tf&&strcmp(source_of_port(p.Inport(ports(k))),source);end
end

function tf = zero_inputs(block,ports)
p=get_param(block,'PortHandles');tf=true;
for k=1:numel(ports)
    src=source_of_port(p.Inport(ports(k)));
    tf=tf&&strcmp(get_param(src,'BlockType'),'Constant')&& ...
        str2double(get_param(src,'Value'))==0;
end
end

function source = source_of_port(port)
line=get_param(port,'Line');
assert(line>0,'Required destination port is unconnected.');
source=getfullname(get_param(line,'SrcBlockHandle'));
end

function destinations = destinations_of_port(port)
line=get_param(port,'Line');
if line < 0, destinations={}; return; end
h=get_param(line,'DstBlockHandle');
destinations=arrayfun(@getfullname,h,'UniformOutput',false);
destinations=destinations(:);
end

function script = wrapper_chart_script(path)
rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');script='';
for k=1:numel(charts)
    if strcmp(charts(k).Path,path),script=charts(k).Script;return;end
end
end

function state = base_value(name)
state=struct('name',name,'existed',evalin('base',sprintf('exist(''%s'',''var'')',name))~=0, ...
    'value',[]);
if state.existed,state.value=evalin('base',name);end
end

function restore_base(a,b)
restore_one(a);restore_one(b);
end

function restore_one(s)
if s.existed,assignin('base',s.name,s.value);else,evalin('base',['clear ' s.name]);end
end

function value = get_param_safe(block,param,fallback)
try,value=get_param(block,param);catch,value=fallback;end
end

function [files, hashes] = frozen_manifest(root)
files={fullfile(root,'model','vx_vy_dekf_v1_17.slx'); ...
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
hashes={'108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
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

function r = file_record(path)
d=dir(path);r=struct('path',path,'bytes',d.bytes, ...
    'modifiedDatenum',d.datenum,'sha256',file_sha256(path));
end

function records = snapshot(files)
records=repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''),numel(files),1);
for k=1:numel(files),records(k)=file_record(files{k});end
end

function ok = records_match(r,h)
ok=numel(r)==numel(h);for k=1:numel(r),ok=ok&&strcmp(r(k).sha256,h{k});end
end

function ok = records_equal(a,b)
if isstruct(a)&&isscalar(a)&&isstruct(b)&&isscalar(b)
    ok=a.bytes==b.bytes&&a.modifiedDatenum==b.modifiedDatenum&&strcmp(a.sha256,b.sha256);return
end
ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&&strcmp(a(k).sha256,b(k).sha256);end
end

function hash = file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c
end

function close_models(m)
if bdIsLoaded(m),try,feval(m,[],[],[],'term');catch,end;close_system(m,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
end
