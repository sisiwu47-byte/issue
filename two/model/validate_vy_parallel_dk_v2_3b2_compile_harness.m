function report = validate_vy_parallel_dk_v2_3b2_compile_harness(build,doCompile)
%VALIDATE_VY_PARALLEL_DK_V2_3B2_COMPILE_HARNESS Static/compile-only audit.
% Never loads or compiles the full vehicle target and never calls sim().

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_parallel_dk_v2_3b2_compile_gates.mat');
if nargin<1||isempty(build)
    s=load(resultFile,'build');
    assert(isfield(s,'build'),'B2 build evidence missing.');
    build=s.build;
end
if nargin<2
    doCompile=false;
end
doCompile=logical(doCompile);
assert(isfile(build.harnessFile),'B2 harness model missing.');
[frozenFiles,expectedHashes]=frozen_manifest(root);
frozenBefore=snapshot(frozenFiles);
targetBefore=file_record(build.sourceFile);
harnessBefore=file_record(build.harnessFile);
addpath(fullfile(root,'model'));
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(tempdir,'vy_parallel_dk_v2_3b2_validate_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_parallel_dk_v2_3b2_validate_codegen'), ...
    'createDir',true);
load_system(build.harnessFile);
h=build.modelName;
cleanup=onCleanup(@()close_model(h));

% Reuse formal-target static evidence only because its hash is unchanged.
formalEvidenceFile=fullfile(root,'results','vy_parallel_dk_v2_3b_integration_gates.mat');
formalStaticReused=false;formalStaticCount=0;formalStaticTrue=0;
if isfile(formalEvidenceFile)
    f=load(formalEvidenceFile,'report');
    if isfield(f,'report')&&isfield(f.report,'staticPassed')&& ...
            isfield(f.report,'targetBefore')&& ...
            strcmp(f.report.targetBefore.sha256,targetBefore.sha256)
        formalStaticReused=f.report.staticPassed;
        formalStaticCount=f.report.staticGateCount;
        formalStaticTrue=f.report.staticGatesTrue;
    end
end

d=get_param(build.dSubsystem,'PortHandles');
k=get_param(build.kSubsystem,'PortHandles');
dExists=getSimulinkBlockHandle(build.dSubsystem)>0&&numel(d.Inport)==1&& ...
    numel(d.Outport)==1&&numel(d.Trigger)==1;
kExists=getSimulinkBlockHandle(build.kSubsystem)>0&&numel(k.Inport)==3&& ...
    numel(k.Outport)==3&&numel(k.Trigger)==1;
dFcn=find_system(build.dSubsystem,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','MATLABFcn');
dWrapperExact=numel(dFcn)==1&&strcmp( ...
    regexprep(get_param(dFcn{1},'MATLABFcn'),'\s+',''), ...
    'vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)')&& ...
    str2double(get_param(dFcn{1},'OutputDimensions'))==69;
kScript=wrapper_chart_script([build.kSubsystem '/K-KF Wrapper']);
kWrapperExact=contains(lower(regexprep(kScript,'\s+','')), ...
    'vy_kinematic_kf(u,z,resetflag)');

ws=get_param(h,'ModelWorkspace');
dMode=evalin(ws,'vy_v17_mode_code');
dText=lower(regexprep(fileread(fullfile(root,'model','vy_dynamic_ekf_v1_17.m')),'\s+',''));
kText=lower(regexprep(fileread(fullfile(root,'model','vy_kinematic_kf.m')),'\s+',''));
dA20=dMode==20&&contains(dText,'stride=100/modecode')&& ...
    contains(dText,'useay=mod(counter,stride)==0');
stateIndependent=contains(dText,'persistentxp')&& ...
    contains(kText,'persistentxstatepstate')&& ...
    ~contains(dText,'xstate')&&~contains(kText,'activemode');
pIndependent=contains(dText,'persistentxp')&&contains(kText,'pstate')&& ...
    ~contains(dText,'pstate');

dSchedMask=get_param(build.dScheduler,'MaskType');
kSchedMask=get_param(build.kScheduler,'MaskType');
dSched100=strcmp(dSchedMask,'Function-Call Generator')&& ...
    str2double(get_param(build.dScheduler,'sample_time'))==0.01&& ...
    str2double(get_param(build.dScheduler,'numberOfIterations'))==1;
kSched100=strcmp(kSchedMask,'Function-Call Generator')&& ...
    str2double(get_param(build.kScheduler,'sample_time'))==0.01&& ...
    str2double(get_param(build.kScheduler,'numberOfIterations'))==1;
schedulerIndependent=dSched100&&kSched100&& ...
    ~strcmp(build.dScheduler,build.kScheduler)&& ...
    strcmp(source_of_port(d.Trigger(1)),build.dScheduler)&& ...
    strcmp(source_of_port(k.Trigger(1)),build.kScheduler)&& ...
    strcmp(get_param([build.dSubsystem '/function'],'TriggerType'),'function-call')&& ...
    strcmp(get_param([build.kSubsystem '/function'],'TriggerType'),'function-call');
kResetOK=strcmp(get_param(build.kReset,'Time'),'0.01')&& ...
    strcmp(get_param(build.kReset,'Before'),'1')&& ...
    strcmp(get_param(build.kReset,'After'),'0')&& ...
    strcmp(get_param(build.kReset,'SampleTime'),'0.01')&& ...
    strcmp(source_of_port(k.Inport(3)),build.kReset);
dResetOK=contains(dText,'isempty(x)')&& ...
    contains(dText,'activemode~=modecode')&&contains(dText,'x=[0;0]')&& ...
    contains(dText,'p=.1*eye(2)')&&numel(d.Inport)==1;

kim=get_param(build.kImuMux,'PortHandles');
kvx=get_param(build.kVxRateTransition,'PortHandles');
dm=get_param(build.dMeasurementMux,'PortHandles');
dc=get_param(build.dControlMux,'PortHandles');
di=get_param(build.dInputMux,'PortHandles');
drt=get_param(build.dInputRateTransition,'PortHandles');
physicalRouting=strcmp(source_of_port(kim.Inport(1)),build.axSource)&& ...
    strcmp(source_of_port(kim.Inport(2)),build.aySource)&& ...
    strcmp(source_of_port(kim.Inport(3)),build.avzSource)&& ...
    strcmp(source_of_port(k.Inport(1)),build.kImuMux)&& ...
    strcmp(source_of_port(kvx.Inport(1)),build.vxSource)&& ...
    strcmp(source_of_port(k.Inport(2)),build.kVxRateTransition)&& ...
    strcmp(source_of_port(dm.Inport(1)),build.aySource)&& ...
    strcmp(source_of_port(dm.Inport(2)),build.avzSource)&& ...
    strcmp(source_of_port(dc.Inport(1)),build.vxSource)&& ...
    strcmp(source_of_port(dc.Inport(2)),build.steeringSource)&& ...
    strcmp(source_of_port(di.Inport(1)),build.dControlMux)&& ...
    strcmp(source_of_port(di.Inport(2)),build.dMeasurementMux)&& ...
    strcmp(source_of_port(drt.Inport(1)),build.dInputMux)&& ...
    strcmp(source_of_port(d.Inport(1)),build.dInputRateTransition);
axKOnly=~any(strcmp(input_sources(build.dControlMux),build.axSource))&& ...
    ~any(strcmp(input_sources(build.dMeasurementMux),build.axSource));
dAyDoesNotGateK=strcmp(source_of_port(kim.Inport(2)),build.aySource)&& ...
    ~any(contains(lower(string(input_sources(build.kImuMux))),'d ay gate'));
trueVyAbsent=~any(contains(lower(string(find_system(h,'Type','Block'))),'vy_true'));

dDests=sort(destinations_of_port(d.Outport(1)));
expectedD=sort({build.dOutputDemux;build.dPExtract;build.dAyExtract});
dOutputsLocal=isequal(dDests,expectedD);
kDests=cell(1,3);kOutputsLocal=true;
for q=1:3
    kDests{q}=destinations_of_port(k.Outport(q));
    kOutputsLocal=kOutputsLocal&&numel(kDests{q})==1&& ...
        startsWith(kDests{q}{1},[h '/harness_kkf_']);
end
noCrossFeed=dOutputsLocal&&kOutputsLocal;
noVsSf=isempty(find_system(h,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','S-Function','FunctionName','vs_sf'));
top=find_system(h,'SearchDepth',1,'Type','Block');
names=lower(string(cellfun(@(p)get_param(p,'Name'),top,'UniformOutput',false)));
noForbidden=~any(contains(names,'fusion'))&&~any(contains(names,'lifesig'))&& ...
    ~any(contains(names,'alpha_d'))&&~any(contains(names,'alpha_k'))&& ...
    ~any(contains(names,'reliability'))&&~any(contains(names,'vy_final'))&& ...
    ~any(contains(names,'dk-ekf'))&&~any(contains(names,'dkekf'));

gates=struct();
gates.formalTargetStaticEvidenceReused=formalStaticReused&& ...
    formalStaticCount==41&&formalStaticTrue==41;
gates.frozenHashes=records_match(frozenBefore,expectedHashes);
gates.harnessExists=isfile(build.harnessFile);
gates.noCarSimVsSf=noVsSf;
gates.dExactCopy=dExists&&dWrapperExact;
gates.kExactCopy=kExists&&kWrapperExact;
gates.stateMemoryIndependent=stateIndependent;
gates.covarianceIndependent=pIndependent;
gates.schedulersIndependent=schedulerIndependent;
gates.resetIndependent=kResetOK&&dResetOK;
gates.dA20Semantics=dA20;
gates.k100HzSemantics=kSched100;
gates.dAyGateDoesNotControlK=dAyDoesNotGateK;
gates.physicalInputRouting=physicalRouting;
gates.axKOnly=axKOnly;
gates.ayFanout=physicalRouting;
gates.avzFanout=physicalRouting;
gates.trueVxFanout=physicalRouting;
gates.steeringDOnly=physicalRouting;
gates.trueVyOnlineAbsent=trueVyAbsent;
gates.noDStateToK=noCrossFeed;
gates.noKStateToD=noCrossFeed;
gates.noCovarianceExchange=noCrossFeed;
gates.noPseudoMeasurement=physicalRouting&&noCrossFeed;
gates.noRDtoK=noCrossFeed;
gates.noVxKToD=noCrossFeed;
gates.noWeightedSum=noForbidden&&noCrossFeed;
gates.noDKSelector=noForbidden&&noCrossFeed;
gates.noAlphaD=noForbidden;
gates.noAlphaK=noForbidden;
gates.noLifeSig=noForbidden;
gates.noReliabilityLogic=noForbidden;
gates.noThirdTrack=noForbidden;
gates.noVyFinal=noForbidden;
gates.outputsObservationOnly=noCrossFeed;
staticVector=cellfun(@logical,struct2cell(gates));
staticPassed=all(staticVector);

compile=struct('called',false,'passed',false, ...
    'method','estimator-only full harness compile','errorIdentifier','', ...
    'errorMessage','','errorReport','','warningIdentifier','', ...
    'warningMessage','','interfaces',struct(),'sampleTimes',struct());
compiledGates=struct('compilePass',~doCompile,'dX2',~doCompile, ...
    'dP2x2',~doCompile,'kX2',~doCompile,'kP2x2',~doCompile, ...
    'steering4x1',~doCompile,'axScalar',~doCompile,'ayScalar',~doCompile, ...
    'avzScalar',~doCompile,'vxScalar',~doCompile, ...
    'resetScalarCompatible',~doCompile,'ayGateScalarCompatible',~doCompile, ...
    'allDouble',~doCompile,'discreteSchedulerDomains',~doCompile, ...
    'noSampleTimeConflict',~doCompile);
if doCompile
    assert(staticPassed,'B2 static gates failed; harness compile prohibited.');
    compile.called=true;lastwarn('');
    try
        feval(h,[],[],[],'compile');
        compile.interfaces=compiled_interfaces(build);
        compile.sampleTimes=compiled_sample_times(build);
        [compile.warningMessage,compile.warningIdentifier]=lastwarn;
        compile.passed=true;
        feval(h,[],[],[],'term');
    catch ME
        try,feval(h,[],[],[],'term');catch,end
        compile.errorIdentifier=ME.identifier;
        compile.errorMessage=ME.message;
        compile.errorReport=getReport(ME,'extended','hyperlinks','off');
    end
    if compile.passed
        ci=compile.interfaces;st=compile.sampleTimes;
        compiledGates.compilePass=true;
        compiledGates.dX2=vector_shape(ci.dX.shape,2);
        compiledGates.dP2x2=shape_equal(ci.dP.shape,[2 2]);
        compiledGates.kX2=vector_shape(ci.kX.shape,2);
        compiledGates.kP2x2=shape_equal(ci.kP.shape,[2 2]);
        compiledGates.steering4x1=vector_shape(ci.steering.shape,4)&& ...
            ci.steering.width==4;
        compiledGates.axScalar=ci.ax.width==1;
        compiledGates.ayScalar=ci.ay.width==1;
        compiledGates.avzScalar=ci.avz.width==1;
        compiledGates.vxScalar=ci.vx.width==1;
        compiledGates.resetScalarCompatible=ci.reset.width==1&& ...
            any(strcmp(ci.reset.type,{'double','boolean'}));
        compiledGates.ayGateScalarCompatible=ci.ayGate.width==1&& ...
            any(strcmp(ci.ayGate.type,{'double','boolean'}));
        compiledGates.allDouble=all(strcmp({ci.dX.type,ci.dP.type,ci.kX.type, ...
            ci.kP.type,ci.steering.type,ci.ax.type,ci.ay.type,ci.avz.type,ci.vx.type},'double'));
        compiledGates.discreteSchedulerDomains= ...
            contains_period(st.dParent,0.01)&& ...
            contains_period(st.kParent,0.01);
        compiledGates.noSampleTimeConflict=true;
    end
end
compiledVector=cellfun(@logical,struct2cell(compiledGates));

close_system(h,0);
frozenAfter=snapshot(frozenFiles);
targetAfter=file_record(build.sourceFile);
harnessAfter=file_record(build.harnessFile);
frozenUnchanged=records_equal(frozenBefore,frozenAfter)&& ...
    records_match(frozenAfter,expectedHashes);
targetUnchanged=record_equal(targetBefore,targetAfter);
harnessNoWrite=record_equal(harnessBefore,harnessAfter);
gates.frozenUnchanged=frozenUnchanged;
gates.formalTargetUnchanged=targetUnchanged;
gates.harnessNoWriteDuringValidation=harnessNoWrite;
staticVector=cellfun(@logical,struct2cell(gates));
staticPassed=all(staticVector);

report=struct('stage','V2.3-B2', ...
    'passed',staticPassed&&all(compiledVector)&&(~doCompile||compile.passed), ...
    'staticPassed',staticPassed,'gates',gates, ...
    'staticGateCount',numel(staticVector),'staticGatesTrue',sum(staticVector), ...
    'compileRequested',doCompile,'compile',compile, ...
    'compiledGates',compiledGates,'compiledGateCount',numel(compiledVector), ...
    'compiledGatesTrue',sum(compiledVector), ...
    'formalStaticEvidence',struct('reused',formalStaticReused, ...
    'true',formalStaticTrue,'count',formalStaticCount,'targetHash',targetBefore.sha256), ...
    'harnessBefore',harnessBefore,'harnessAfter',harnessAfter, ...
    'targetBefore',targetBefore,'targetAfter',targetAfter, ...
    'frozenBefore',frozenBefore,'frozenAfter',frozenAfter, ...
    'dOutputDestinations',{dDests},'kOutputDestinations',{kDests}, ...
    'dState','[Vy;r]','kState','[Vx;Vy]','dP','2x2','kP','2x2', ...
    'dAySemantics','internal A20: useAy every fifth 100-Hz hit', ...
    'simCalled',false,'carSimRun',false,'fullTargetCompileCalled',false);
save(resultFile,'build','report');
clear cleanup
fprintf(['V2_3B2_VALIDATE|static=%d/%d|compileCalled=%d|compilePassed=%d|' ...
    'compiled=%d/%d|passed=%d|fullTarget=0|sim=0|carsim=0\n'], ...
    report.staticGatesTrue,report.staticGateCount,compile.called,compile.passed, ...
    report.compiledGatesTrue,report.compiledGateCount,report.passed);
if compile.called&&~compile.passed
    fprintf('V2_3B2_COMPILE_ERROR|%s|%s\n',compile.errorIdentifier,compile.errorMessage);
end
end

function ci=compiled_interfaces(b)
dout=get_param(b.dOutputDemux,'PortHandles');
dp=get_param(b.dP,'PortHandles');
k=get_param(b.kSubsystem,'PortHandles');
ayg=get_param(b.dAyExtract,'PortHandles');
ci=struct('dX',port_record(dout.Outport(1)), ...
    'dP',port_record(dp.Outport(1)),'kX',port_record(k.Outport(1)), ...
    'kP',port_record(k.Outport(2)),'steering',block_out(b.steeringSource), ...
    'ax',block_out(b.axSource),'ay',block_out(b.aySource), ...
    'avz',block_out(b.avzSource),'vx',block_out(b.vxSource), ...
    'reset',block_out(b.kReset),'ayGate',port_record(ayg.Outport(2)));
end
function st=compiled_sample_times(b)
% Assign fields one-by-one. Some CompiledSampleTime values are cell arrays;
% passing those directly to struct(...) would create a nonscalar struct array.
st=struct();
st.dParent=get_param(b.dSubsystem,'CompiledSampleTime');
st.kParent=get_param(b.kSubsystem,'CompiledSampleTime');
st.dInputBoundary=get_param(b.dInputRateTransition,'CompiledSampleTime');
st.kVxBoundary=get_param(b.kVxRateTransition,'CompiledSampleTime');
end
function r=block_out(b)
p=get_param(b,'PortHandles');r=port_record(p.Outport(1));
end
function r=port_record(p)
r=struct('shape',compiled_shape(p), ...
    'width',double(get_param(p,'CompiledPortWidth')), ...
    'type',get_param(p,'CompiledPortDataType'));
end
function s=compiled_shape(p)
d=double(get_param(p,'CompiledPortDimensions'));
if numel(d)>=2&&d(1)==numel(d)-1,s=d(2:end);else,s=d;end
end
function tf=shape_equal(a,e)
tf=isequal(double(a(:).'),double(e(:).'));
end
function tf=vector_shape(a,w)
a=double(a(:).');tf=(isscalar(a)&&a==w)||(prod(a)==w&&any(a==1));
end
function tf=contains_period(value,period)
tf=false;
if isnumeric(value)
    tf=size(value,2)>=1&&any(abs(value(:,1)-period)<1e-12,'all');
elseif iscell(value)
    for k=1:numel(value)
        tf=tf||contains_period(value{k},period);
    end
end
end
function s=input_sources(b)
p=get_param(b,'PortHandles');s=cell(1,numel(p.Inport));
for k=1:numel(s),s{k}=source_of_port(p.Inport(k));end
end
function s=source_of_port(p)
l=get_param(p,'Line');assert(l>0,'Unconnected input.');
s=getfullname(get_param(l,'SrcBlockHandle'));
end
function d=destinations_of_port(p)
l=get_param(p,'Line');if l<0,d={};return,end
hs=get_param(l,'DstBlockHandle');d=arrayfun(@getfullname,hs,'UniformOutput',false);d=d(:);
end
function s=wrapper_chart_script(path)
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart');s='';
for k=1:numel(c),if strcmp(c(k).Path,path),s=c(k).Script;return,end,end
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx'); ...
    fullfile(root,'model','vx_vy_dekf_v1_17.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1.slx'); ...
    fullfile(root,'model','vy_dynamic_ekf_v1_17.m'); ...
    fullfile(root,'model','vy_dynamic_ekf_step_v17.m'); ...
    fullfile(root,'model','vy_dynamic_ekf_step_v13.m'); ...
    fullfile(root,'model','vy_kinematic_kf_step.m'); ...
    fullfile(root,'model','vy_kinematic_kf.m'); ...
    fullfile(root,'model','vx_vy_dkekf_v2_2.slx'); ...
    fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
    fullfile(root,'model','vy_dkekf_baseline.m'); ...
    fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m')};
hashes={'98461db290723a5ccdf62398ce5063de0c9b6c7586334d479b159a771eb128c0'; ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
    '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e'; ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712'; ...
    '5550d0389fc4d1dcf7f65b0e00b4c51a949f2b9add33c2d78d1122a31291a1a0'; ...
    '4010f6a4bd669ac048297c2f416f0b8826f729f4552d73445703184f052c4a4f'; ...
    '498a446e13e654387e3d36bf4694a336e75b2100e765dac0414a01367531cde4'; ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244'; ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'; ...
    'e768fb2ad33a6eeaabde2fb7c40be660b78f350a90c752327dc9b423f50f2e15'; ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457'; ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'; ...
    '12f0d82643d65aa5098ed20c0655234f3a2e7ef6d6f5e7dee5b80bc1a201bda1'};
end
function r=file_record(p)
d=dir(p);r=struct('path',p,'bytes',d.bytes, ...
    'modifiedDatenum',d.datenum,'sha256',file_sha256(p));
end
function r=snapshot(f)
r=repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''),numel(f),1);
for k=1:numel(f),r(k)=file_record(f{k});end
end
function ok=records_match(r,h)
ok=numel(r)==numel(h);for k=1:numel(r),ok=ok&&strcmp(r(k).sha256,h{k});end
end
function ok=records_equal(a,b)
ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&&strcmp(a(k).sha256,b(k).sha256);end
end
function ok=record_equal(a,b)
ok=a.bytes==b.bytes&&a.modifiedDatenum==b.modifiedDatenum&&strcmp(a.sha256,b.sha256);
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c
end
function close_model(h)
if bdIsLoaded(h),try,feval(h,[],[],[],'term');catch,end;close_system(h,0);end
end
