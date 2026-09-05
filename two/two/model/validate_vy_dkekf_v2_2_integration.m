function report = validate_vy_dkekf_v2_2_integration(buildReport,compileEvidence)
%VALIDATE_VY_DKEKF_V2_2_INTEGRATION No-write V2.2-C1 audit.
% The default path consumes the existing build report and model. It never
% rebuilds, copies, or saves the target model.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_dkekf_v2_2c1_integration.mat');
if nargin<1||isempty(buildReport)
    assert(isfile(resultFile),['Existing C1 build report missing. Run ' ...
        'build_vy_dkekf_v2_2 explicitly before validation.']);
    s=load(resultFile,'buildReport');
    assert(isfield(s,'buildReport'),'C1 MAT does not contain buildReport.');
    buildReport=s.buildReport;
end
targetFile=buildReport.targetFile;
assert(isfile(targetFile),'Existing DK-EKF target model is missing.');
targetBefore=file_record(targetFile);

[frozenFiles,expectedHashes]=frozen_manifest(root);
frozenBefore=snapshot(frozenFiles);
frozenHashesOK=records_match(frozenBefore,expectedHashes);

oldPath=path;oldFolder=pwd;
cleanup=onCleanup(@()cleanup_models(buildReport.modelName,oldFolder,oldPath));
addpath(fullfile(root,'model'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder', ...
    fullfile(tempdir,'vy_dkekf_v2_2c1_cache'),'CodeGenFolder', ...
    fullfile(tempdir,'vy_dkekf_v2_2c1_codegen'),'createDir',true);
load_system('Solver_SF');load_system(targetFile);m=buildReport.modelName;

subExists=getSimulinkBlockHandle(buildReport.subsystem)>0;
subPorts=get_param(buildReport.subsystem,'PortHandles');
triggerPath=[buildReport.subsystem '/function'];
triggerType=get_param(triggerPath,'TriggerType');
triggerTypeOK=strcmp(triggerType,'function-call');
schedulerMaskType=get_param(buildReport.scheduler,'MaskType');
schedulerMaskTypeOK=strcmp(schedulerMaskType,'Function-Call Generator');
schedulerConnectionOK=strcmp(source_of_port(subPorts.Trigger(1)),buildReport.scheduler);
schedulerRateOK=abs(str2double(get_param(buildReport.scheduler,'sample_time'))-0.01)<1e-15&& ...
    str2double(get_param(buildReport.scheduler,'numberOfIterations'))==1;

resetStaticOK=strcmp(get_param(buildReport.reset,'Time'),'0.01')&& ...
    strcmp(get_param(buildReport.reset,'Before'),'1')&& ...
    strcmp(get_param(buildReport.reset,'After'),'0')&& ...
    strcmp(get_param(buildReport.reset,'SampleTime'),'0.01');
firstHitDesignedAtZero=schedulerRateOK&&resetStaticOK;
ayPulseParams=struct('period',get_param(buildReport.ayPulse,'Period'), ...
    'pulseWidth',get_param(buildReport.ayPulse,'PulseWidth'), ...
    'phaseDelay',get_param(buildReport.ayPulse,'PhaseDelay'), ...
    'sampleTime',get_param(buildReport.ayPulse,'SampleTime'));
ay20HzSchedulerOK=abs(str2double(ayPulseParams.period)-0.05)<1e-15&& ...
    abs(str2double(ayPulseParams.pulseWidth)-20)<1e-15&& ...
    abs(str2double(ayPulseParams.phaseDelay))<1e-15&& ...
    abs(str2double(ayPulseParams.sampleTime)-0.01)<1e-15;

expectedSources={buildReport.axSource;buildReport.steeringRateTransition; ...
    buildReport.vxRateTransition;buildReport.avzSource;buildReport.aySource; ...
    buildReport.ayPulse;buildReport.reset};
actualSources=cell(7,1);connectionOK=false(7,1);
for k=1:7
    actualSources{k}=source_of_port(subPorts.Inport(k));
    connectionOK(k)=strcmp(actualSources{k},expectedSources{k});
end
steerRtPorts=get_param(buildReport.steeringRateTransition,'PortHandles');
steeringSourceOK=strcmp(source_of_port(steerRtPorts.Inport(1)),buildReport.steeringSource);
vxRtPorts=get_param(buildReport.vxRateTransition,'PortHandles');
vxMeasurementSourceOK=strcmp(source_of_port(vxRtPorts.Inport(1)),buildReport.vxSource);

boundaryBlockType=get_param(buildReport.wrapperBlock,'BlockType');
boundaryFunction=get_param(buildReport.wrapperBlock,'FunctionName');
boundaryBlockOK=strcmp(boundaryBlockType,'M-S-Function')&& ...
    strcmp(boundaryFunction,'vy_dkekf_baseline_simulink_sfun');
adapterPath=which('vy_dkekf_baseline_simulink_sfun');
adapterText=fileread(adapterPath);
adapterHash=file_sha256(adapterPath);
adapterHashOK=strcmp(adapterHash, ...
    '12f0d82643d65aa5098ed20c0655234f3a2e7ef6d6f5e7dee5b80bc1a201bda1');
executionSemantics=audit_adapter_source(adapterText);
normalized=lower(regexprep(adapterText,'\s+',''));
trueVyAbsent=~contains(normalized,'vy_true')&&numel(subPorts.Inport)==7;
noOutputFusion=~contains(normalized,'fusion')&& ...
    ~any(contains(lower(actualSources),'k-kf 100hz'));
noLifeSig=~contains(normalized,'lifesig');
noAdaptiveFusion=~contains(normalized,'adaptive');

corePath=which('vy_dkekf_baseline_step');wrapperPath=which('vy_dkekf_baseline');
coreHash=file_sha256(corePath);wrapperHash=file_sha256(wrapperPath);
coreWrapperFrozenOK=strcmp(coreHash, ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457')&& ...
    strcmp(wrapperHash, ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973');
coreText=lower(fileread(corePath));
dynText=extract_function(coreText,'function [f, out] = dk_dynamics', ...
    'function a = dynamics_jacobian');
noTrueVxBypass=contains(dynText,'vx = x(1)')&&~contains(dynText,'z_vx');

expectedVars={'dkekf_u_log1','dkekf_x_log1','dkekf_P_log1','dkekf_diag_log1'};
logBlocks={ [m '/DK-EKF u Log'],[m '/DK-EKF x Log'], ...
    [m '/DK-EKF P Log'],[m '/DK-EKF diag Log']};
logVariables=cellfun(@(b)get_param(b,'VariableName'),logBlocks,'UniformOutput',false);
requiredLogsOK=isequal(logVariables,expectedVars);

compileEvidenceReused=nargin>=2&&~isempty(compileEvidence);
if compileEvidenceReused
    assert(isfield(compileEvidence,'compileHarness')&& ...
        compileEvidence.compileHarness.passed, ...
        'Reusable compile evidence must contain a passing compile audit.');
    assert(strcmp(compileEvidence.targetBefore.sha256,targetBefore.sha256)&& ...
        strcmp(compileEvidence.targetAfter.sha256,targetBefore.sha256), ...
        'Reusable compile evidence target hash does not match current target.');
    assert(strcmp(compileEvidence.adapterHash,adapterHash)&& ...
        ~compileEvidence.simCalled&&~compileEvidence.carSimRun, ...
        'Reusable compile evidence adapter/run discipline mismatch.');
    formalCompile=compileEvidence.formalTargetCompile;
    harness=compileEvidence.compileHarness;
else
    formalCompile=struct('called',true,'passed',false,'errorIdentifier','', ...
        'errorMessage','','errorReport','');
    try
        feval(m,[],[],[],'compile');
        harness=compiled_interface_audit(buildReport.subsystem, ...
            'Formal target compile/update diagram');
        formalCompile.passed=true;
        feval(m,[],[],[],'term');
    catch ME
        try,feval(m,[],[],[],'term');catch,end
        formalCompile.errorIdentifier=ME.identifier;
        formalCompile.errorMessage=ME.message;
        formalCompile.errorReport=getReport(ME,'extended','hyperlinks','off');
        if is_carsim_dependency_error(ME)
            try
                harness=compile_interface_harness(buildReport.subsystem);
            catch HE
                harness=failed_compile_audit(HE, ...
                    'Exact subsystem copy in unsaved in-memory compile harness');
            end
        else
            harness=failed_compile_audit(ME,'Formal target compile/update diagram');
        end
    end
end
inputShapes=harness.inputShapes;outputShapes=harness.outputShapes;
inputTypes=harness.inputTypes;outputTypes=harness.outputTypes;
expectedInputShapes={1,[4 1],1,1,1,1,1};
inputInterfaceOK=harness.passed&&all(strcmp(inputTypes,'double'));
for k=1:7,inputInterfaceOK=inputInterfaceOK&& ...
        input_shape_equal(inputShapes{k},expectedInputShapes{k});end
xDimensionOK=harness.passed&&shape_equal(outputShapes{1},[3 1])&& ...
    strcmp(outputTypes{1},'double');
pDimensionOK=harness.passed&&shape_equal(outputShapes{2},[3 3])&& ...
    strcmp(outputTypes{2},'double');
diagDimensionOK=harness.passed&&shape_equal(outputShapes{3},[7 1])&& ...
    buildReport.diagWidth==7&&strcmp(outputTypes{3},'double');

close_system(m,0);close_system('Solver_SF',0);
frozenAfter=snapshot(frozenFiles);
frozenUnchanged=records_equal(frozenBefore,frozenAfter)&& ...
    records_match(frozenAfter,expectedHashes);
targetAfter=file_record(targetFile);
targetNoWrite=targetBefore.bytes==targetAfter.bytes&& ...
    targetBefore.modifiedDatenum==targetAfter.modifiedDatenum&& ...
    strcmp(targetBefore.sha256,targetAfter.sha256);

gates=struct();
gates.targetModelExists=isfile(targetFile);
gates.frozenSourceHashes=frozenHashesOK&&frozenUnchanged;
gates.coreWrapperHashes=coreWrapperFrozenOK;
gates.subsystemExists=subExists&&boundaryBlockOK;
gates.functionCallTrigger=triggerTypeOK;
gates.scheduler100Hz=schedulerMaskTypeOK&&schedulerRateOK&&schedulerConnectionOK;
gates.firstHitDesignedAtZero=firstHitDesignedAtZero;
gates.axConnected=connectionOK(1);
gates.ayConnected=connectionOK(5);
gates.avzConnected=connectionOK(4);
gates.trueVxMeasurementConnected=connectionOK(3)&&vxMeasurementSourceOK;
gates.trueVyOnlineAbsent=trueVyAbsent;
gates.doAyInputExists=connectionOK(6);
gates.ayScheduler20Hz=ay20HzSchedulerOK;
gates.resetExists=connectionOK(7)&&resetStaticOK;
gates.xDimension3=xDimensionOK;
gates.pDimension3x3=pDimensionOK;
gates.diagnosticsDimension=diagDimensionOK;
gates.requiredLogs=requiredLogsOK;
gates.noOutputFusion=noOutputFusion;
gates.noLifeSig=noLifeSig;
gates.noAdaptiveFusion=noAdaptiveFusion;
gates.noTrueVxBypass=noTrueVxBypass;
gates.frozenReferencesResolve=boundaryBlockOK&&adapterHashOK&& ...
    executionSemantics.safe&&coreWrapperFrozenOK;
gates.compileEquivalentHarness=harness.passed&&inputInterfaceOK;
gates.targetNoWrite=targetNoWrite;
gates.steeringSourceConnected=connectionOK(2)&&steeringSourceOK;
values=struct2cell(gates);gateVector=cellfun(@(v)logical(v),values);

report=struct('stage','V2.2-C1','passed',all(gateVector), ...
    'gates',gates,'gateCount',numel(gateVector),'gatesTrue',sum(gateVector), ...
    'targetBefore',targetBefore,'targetAfter',targetAfter, ...
    'frozenBefore',frozenBefore,'frozenAfter',frozenAfter, ...
    'triggerType',triggerType,'schedulerMaskType',schedulerMaskType, ...
    'schedulerConnectionOK',schedulerConnectionOK, ...
    'ayPulseParameters',ayPulseParams,'actualInputSources',{actualSources}, ...
    'boundaryBlockType',boundaryBlockType,'boundaryFunction',boundaryFunction, ...
    'adapterPath',adapterPath,'adapterHash',adapterHash, ...
    'executionSemantics',executionSemantics, ...
    'coreHash',coreHash,'wrapperHash',wrapperHash, ...
    'inputShapes',{inputShapes},'outputShapes',{outputShapes}, ...
    'inputTypes',{inputTypes},'outputTypes',{outputTypes}, ...
    'formalTargetCompile',formalCompile,'compileHarness',harness, ...
    'compileEvidenceReused',compileEvidenceReused, ...
    'logVariables',{logVariables}, ...
    'simCalled',false,'carSimRun',false);
clear cleanup
fprintf('V2_2C1_VALIDATE|gates=%d/%d|passed=%d|targetNoWrite=%d|compile=%d\n', ...
    report.gatesTrue,report.gateCount,report.passed,targetNoWrite,harness.passed);
end

function audit=compile_interface_harness(template)
h='vy_dkekf_v2_2c1_compile_harness';if bdIsLoaded(h),close_system(h,0);end
new_system(h);c=onCleanup(@()close_harness(h));
sub=[h '/DK-EKF Baseline'];gen=[h '/Scheduler'];
add_block(template,sub,'Position',[260 60 500 310]);
add_block('simulink/Ports & Subsystems/Function-Call Generator',gen, ...
    'Position',[50 20 180 50],'sample_time','0.01','numberOfIterations','1');
values={'0','zeros(4,1)','20','0','0','1','1'};
for k=1:7
    b=[h sprintf('/in%d',k)];add_block('simulink/Sources/Constant',b, ...
        'Position',[50 60+35*k 120 80+35*k],'Value',values{k});
end
for k=1:3
    b=[h sprintf('/out%d',k)];add_block('simulink/Sinks/Terminator',b, ...
        'Position',[580 75+60*k 600 95+60*k]);
end
gp=get_param(gen,'PortHandles');sp=get_param(sub,'PortHandles');
add_line(h,gp.Outport(1),sp.Trigger(1),'autorouting','on');
for k=1:7,add_line(h,sprintf('in%d/1',k),sprintf('DK-EKF Baseline/%d',k),'autorouting','on');end
for k=1:3,add_line(h,sprintf('DK-EKF Baseline/%d',k),sprintf('out%d/1',k),'autorouting','on');end
feval(h,[],[],[],'compile');
audit=compiled_interface_audit(sub, ...
    'Exact subsystem copy in unsaved in-memory compile harness');
feval(h,[],[],[],'term');clear c;close_harness(h);
end
function audit=compiled_interface_audit(sub,method)
sp=get_param(sub,'PortHandles');audit=struct('passed',true, ...
    'inputShapes',{{}},'outputShapes',{{}},'inputTypes',{{}},'outputTypes',{{}}, ...
    'method',method,'errorIdentifier','','errorMessage','','errorReport','');
audit.inputShapes=cell(1,7);audit.inputTypes=cell(1,7);
audit.outputShapes=cell(1,3);audit.outputTypes=cell(1,3);
for k=1:7,audit.inputShapes{k}=compiled_shape(sp.Inport(k));audit.inputTypes{k}=get_param(sp.Inport(k),'CompiledPortDataType');end
for k=1:3,audit.outputShapes{k}=compiled_shape(sp.Outport(k));audit.outputTypes{k}=get_param(sp.Outport(k),'CompiledPortDataType');end
end
function audit=failed_compile_audit(ME,method)
audit=struct('passed',false,'inputShapes',{cell(1,7)}, ...
    'outputShapes',{cell(1,3)},'inputTypes',{cell(1,7)}, ...
    'outputTypes',{cell(1,3)},'method',method, ...
    'errorIdentifier',ME.identifier,'errorMessage',ME.message, ...
    'errorReport',getReport(ME,'extended','hyperlinks','off'));
end
function tf=is_carsim_dependency_error(ME)
diagnostic=lower([ME.identifier ' ' ME.message]);
tokens={'carsim','solver_sf','vs_solver','vs_sf','vehicle sim'};
tf=any(cellfun(@(s)contains(diagnostic,s),tokens));
end
function shape=compiled_shape(port)
d=get_param(port,'CompiledPortDimensions');
if numel(d)>=2&&d(1)==numel(d)-1,shape=d(2:end);else,shape=d;end
if isscalar(shape)&&shape==1,shape=1;end
end
function close_harness(h)
if bdIsLoaded(h),try,feval(h,[],[],[],'term');catch,end;close_system(h,0);end
end
function tf=shape_equal(actual,expected)
tf=isequal(double(actual(:).'),double(expected(:).'));
end
function tf=input_shape_equal(actual,expected)
tf=shape_equal(actual,expected);
if ~tf&&isscalar(actual)&&isvector(expected)
    tf=double(actual)==prod(double(expected));
end
end
function audit=audit_adapter_source(source)
sourceNorm=lower(source);
outputsStart=regexp(sourceNorm,'function outputs\(block\)','once');
updateStart=regexp(sourceNorm,'function update\(block\)','once');
configStart=regexp(sourceNorm,'function \[par, cfg, ts, p0\]','once');
sectionsResolved=~isempty(outputsStart)&&~isempty(updateStart)&&~isempty(configStart)&& ...
    outputsStart<updateStart&&updateStart<configStart;
if sectionsResolved
    outputsText=sourceNorm(outputsStart:updateStart-1);
    updateText=sourceNorm(updateStart:configStart-1);
else
    outputsText='';updateText='';
end
callsFrozenCore=contains(outputsText,'vy_dkekf_baseline_step(');
callsPersistentWrapper=~isempty(regexp(sourceNorm, ...
    '(?<!step)\<vy_dkekf_baseline\s*\(','once'));
outputsWritesState=contains(outputsText,'block.dwork(1).data =')|| ...
    contains(outputsText,'block.dwork(2).data =');
updateXCommitCount=numel(strfind(updateText,'block.dwork(1).data ='));
updatePCommitCount=numel(strfind(updateText,'block.dwork(2).data ='));
updateCommitsState=updateXCommitCount==1&&updatePCommitCount==1;
inheritedSampleTime=contains(regexprep(sourceNorm,'\s+',''), ...
    'block.sampletimes=[-10]');
tokens={'dk_dynamics(','dynamics_jacobian(','scalar_joseph_update(', ...
    'ay_value_and_jacobian(','tire_call('};
containsCopiedMath=any(cellfun(@(s)contains(sourceNorm,s),tokens));
safe=sectionsResolved&&callsFrozenCore&&~callsPersistentWrapper&& ...
    ~outputsWritesState&&updateCommitsState&&inheritedSampleTime&& ...
    ~containsCopiedMath;
audit=struct('safe',safe,'sectionsResolved',sectionsResolved, ...
    'callsFrozenCore',callsFrozenCore, ...
    'callsPersistentWrapper',callsPersistentWrapper, ...
    'outputsWritesState',outputsWritesState, ...
    'updateCommitsState',updateCommitsState, ...
    'updateXCommitCount',updateXCommitCount, ...
    'updatePCommitCount',updatePCommitCount, ...
    'inheritedSampleTime',inheritedSampleTime, ...
    'containsCopiedEkfMath',containsCopiedMath);
end
function source=source_of_port(port)
line=get_param(port,'Line');assert(line>0,'Destination input is unconnected.');
source=getfullname(get_param(line,'SrcBlockHandle'));
end
function section=extract_function(text,startMarker,endMarker)
s=strfind(text,startMarker);assert(~isempty(s),'Core dynamic function marker missing.');
tail=text(s(1):end);e=strfind(tail,endMarker);assert(~isempty(e),'Core Jacobian marker missing.');
section=tail(1:e(1)-1);
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx.slx');fullfile(root,'model','vx_ax_imu_prereq_v2_1.slx'); ...
    fullfile(root,'model','vx_vy_dekf_v1_17.slx');fullfile(root,'model','vx_vy_kkf_v2_1.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx');fullfile(root,'model','vy_kinematic_kf_step.m'); ...
    fullfile(root,'model','vy_kinematic_kf.m');fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
    fullfile(root,'model','vy_dkekf_baseline.m')};
hashes={'754a94d85bd50f89ae453c544903dea90b7f9d57d6e7706869f9f674fb0464eb'; ...
    '226238301763460f4b609b0249d61b720c6510dd561923c5d066c33e5967f439'; ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712'; ...
    '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e'; ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244'; ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'; ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457'; ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'};
end
function s=snapshot(files),s=repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''),numel(files),1);for k=1:numel(files),s(k)=file_record(files{k});end,end
function r=file_record(path),d=dir(path);r=struct('path',path,'bytes',d.bytes,'modifiedDatenum',d.datenum,'sha256',file_sha256(path));end
function ok=records_match(r,h),ok=numel(r)==numel(h);for k=1:numel(r),ok=ok&&strcmp(r(k).sha256,h{k});end,end
function ok=records_equal(a,b),ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&&strcmp(a(k).sha256,b(k).sha256);end,end
function hash=file_sha256(path),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c,end
function cleanup_models(m,folder,oldPath),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(folder);path(oldPath);end
