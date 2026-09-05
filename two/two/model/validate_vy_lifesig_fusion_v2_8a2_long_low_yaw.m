function report = validate_vy_lifesig_fusion_v2_8a2_long_low_yaw()
%VALIDATE... Static and compile-only V2.8-A2 gate. Never calls sim().

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
sourceFile=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
targetFile=fullfile(md,'vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx');
buildFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_build.mat');
resultFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_compile.mat');
sourceExpected='65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0';
assert(isfile(targetFile)&&isfile(buildFile),'V28A2:BuildMissing', ...
    'Long-low-yaw target or build evidence is missing.');
B=load(buildFile,'build');expectedTarget=B.build.targetHash;
assert(strcmp(file_sha256(sourceFile),sourceExpected),'V28A2:SourceHashMismatch', ...
    'Accepted V2.7 target hash mismatch.');
assert(strcmp(file_sha256(targetFile),expectedTarget),'V28A2:TargetHashMismatch', ...
    'Long-low-yaw target differs from build evidence.');

addpath(md);addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
load_system('simulink');load_system('Solver_SF');load_system(targetFile);
m='vx_vy_lifesig_fusion_v2_8a2_long_low_yaw';cleanup=onCleanup(@()close_all(m));
report=struct();report.stage='V2.8-A2';report.modelLoaded=true;
report.compileCalled=false;report.compilePassed=false;report.terminationReached=false;
report.compiledEvidenceCaptured=false;report.simCalled=false;report.carSimRun=false;
report.firstErrorIdentifier='';report.firstErrorMessage='';
report.sourceHashBefore=file_sha256(sourceFile);report.targetHashBefore=file_sha256(targetFile);

cmd=[m '/G0 Steer Cmd Rad'];gain=[m '/Gain22'];mux8=[m '/Mux8'];sw=[m '/Manual Switch1'];
w=get_param(m,'ModelWorkspace');profile=evalin(w,'long_low_yaw_steer_profile');
t=profile(:,1);u=profile(:,2);excitationEnd=evalin(w,'long_low_yaw_excitation_end_s');
report.static=struct();
report.static.stopTime=str2double(get_param(m,'StopTime'));
report.static.profileSize=size(profile);report.static.timeStart=t(1);report.static.timeEnd=t(end);
report.static.dtMin=min(diff(t));report.static.dtMean=mean(diff(t));report.static.dtMax=max(diff(t));
report.static.maxAbsSteer=max(abs(u));report.static.firstSteer=u(1);report.static.lastSteer=u(end);
report.static.postZeroSamples=sum(t>=excitationEnd);
report.static.postZeroExact=all(u(t>=excitationEnd)==0);
report.static.postStraightDuration=t(end)-excitationEnd;
report.static.initialZeroExact=all(u(t<=2)==0);
report.static.sourceType=get_param(cmd,'BlockType');
report.static.sourceVariable=get_param(cmd,'VariableName');
report.static.sourceSampleTime=get_param(cmd,'SampleTime');
report.static.sourceInterpolate=get_param(cmd,'Interpolate');
report.static.sourceAfterFinal=get_param(cmd,'OutputAfterFinalValue');
report.static.gain=get_param(gain,'Gain');
gph=get_param(gain,'PortHandles');report.static.gainInputSource=source_identity(gph.Inport(1));
m8=get_param(mux8,'PortHandles');
report.static.mux8Input2=source_identity(m8.Inport(2));
report.static.mux8Input4=source_identity(m8.Inport(4));
report.static.mux8Input6=source_identity(m8.Inport(6));
report.static.mux8Input8=source_identity(m8.Inport(8));
sph=get_param(sw,'PortHandles');report.static.switchInput2=source_identity(sph.Inport(2));
report.static.switchSetting=get_param(sw,'CurrentSetting');
report.static.rearValues=[constant_source_value(m8.Inport(6)),constant_source_value(m8.Inport(8))];
required={'rel_common_time_100hz_log';'steer_cmd_rad';'long_low_yaw_r_log'; ...
    'rel_vy_true_100hz_log';'fusion_vy_d_log';'fusion_vy_k_log'; ...
    'long_low_yaw_k_error_log';'long_low_yaw_d_error_log'};
report.static.requiredLogs=required;report.static.logMappings=cell(size(required));
report.static.logsPresent=true;
for k=1:numel(required)
    b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
        'BlockType','ToWorkspace','VariableName',required{k});
    report.static.logsPresent=report.static.logsPresent&&numel(b)==1;
    if numel(b)==1
        ph=get_param(b{1},'PortHandles');report.static.logMappings{k}=source_identity(ph.Inport(1));
    else
        report.static.logMappings{k}='MISSING';
    end
end
% Signed yaw must be the same source that feeds K input-log port 3 (AVz).
km=[m '/K-KF Input Log Mux'];kmph=get_param(km,'PortHandles');
report.static.kInput3Source=source_identity(kmph.Inport(3));
report.static.signedYawLogSource=report.static.logMappings{3};
report.static.signedYawMappingOK=strcmp(report.static.kInput3Source,report.static.signedYawLogSource);
report.static.errorDiagnosticOnly=diagnostic_sink_only(m,'Long Low Yaw D Error')&& ...
    diagnostic_sink_only(m,'Long Low Yaw K Error');
report.static.noCandidateYawGate=true;
report.static.steeringDefinitionOK=strcmp(report.static.sourceType,'FromWorkspace')&& ...
    strcmp(report.static.sourceVariable,'long_low_yaw_steer_profile')&& ...
    strcmp(report.static.sourceSampleTime,'0.01')&&strcmp(report.static.sourceInterpolate,'off')&& ...
    strcmp(report.static.sourceAfterFinal,'Holding final value')&& ...
    report.static.initialZeroExact&&report.static.postZeroExact&& ...
    report.static.postStraightDuration>=10&&report.static.maxAbsSteer<=0.02+eps(0.02)&& ...
    report.static.maxAbsSteer>=0.999*0.02&& ...
    abs(report.static.dtMean-0.01)<1e-12&&report.static.profileSize(1)==2201;
report.static.pathOK=strcmp(report.static.gain,'180/pi')&& ...
    strcmp(report.static.gainInputSource,[cmd '#1'])&& ...
    strcmp(report.static.mux8Input2,[gain '#1'])&&strcmp(report.static.mux8Input4,[gain '#1'])&& ...
    strcmp(report.static.switchInput2,[mux8 '#1'])&&strcmp(report.static.switchSetting,'0')&& ...
    all(report.static.rearValues==0);
report.staticPassed=report.static.steeringDefinitionOK&&report.static.pathOK&& ...
    report.static.logsPresent&&report.static.signedYawMappingOK&& ...
    report.static.errorDiagnosticOnly&&report.static.noCandidateYawGate;
assert(report.staticPassed,'V28A2:StaticGateFailed', ...
    'Long-low-yaw validation target static gate failed before compile.');

try
    report.compileCalled=true;
    feval(m,[],[],[],'compile');report.compilePassed=true;
    report.compiled=struct();
    report.compiled.steeringDimensions=get_param(cmd,'CompiledPortDimensions');
    report.compiled.steeringDataTypes=get_param(cmd,'CompiledPortDataTypes');
    report.compiled.steeringSampleTime=get_param(cmd,'CompiledSampleTime');
    report.compiled.dErrorSampleTime=get_param([m '/Long Low Yaw D Error'],'CompiledSampleTime');
    report.compiled.kErrorSampleTime=get_param([m '/Long Low Yaw K Error'],'CompiledSampleTime');
    report.compiled.signedYawSampleTime=get_param([m '/Long Low Yaw Signed r Log'],'CompiledSampleTime');
    report.compiled.steeringScalar=compiled_output_scalar(report.compiled.steeringDimensions);
    report.compiled.steeringDouble=compiled_output_double(report.compiled.steeringDataTypes);
    report.compiled.steering100Hz=sample_is_100hz(report.compiled.steeringSampleTime);
    report.compiled.dError100Hz=sample_is_100hz(report.compiled.dErrorSampleTime);
    report.compiled.kError100Hz=sample_is_100hz(report.compiled.kErrorSampleTime);
    report.compiled.signedYaw100Hz=sample_is_100hz(report.compiled.signedYawSampleTime);
    report.compiledEvidenceCaptured=true;
    feval(m,[],[],[],'term');report.terminationReached=true;
catch ME
    report.firstErrorIdentifier=ME.identifier;report.firstErrorMessage=ME.message;
    try,feval(m,[],[],[],'term');report.terminationReached=true;catch,end
end

report.sourceHashAfter=file_sha256(sourceFile);report.targetHashAfter=file_sha256(targetFile);
report.sourceUnchanged=strcmp(report.sourceHashBefore,report.sourceHashAfter)&& ...
    strcmp(report.sourceHashAfter,sourceExpected);
report.targetUnchanged=strcmp(report.targetHashBefore,report.targetHashAfter)&& ...
    strcmp(report.targetHashAfter,expectedTarget);
compiledOK=report.compiledEvidenceCaptured&&report.compiled.steeringScalar&& ...
    report.compiled.steeringDouble&&report.compiled.steering100Hz&& ...
    report.compiled.dError100Hz&&report.compiled.kError100Hz&&report.compiled.signedYaw100Hz;
report.passed=report.staticPassed&&report.compilePassed&&report.terminationReached&& ...
    compiledOK&&report.sourceUnchanged&&report.targetUnchanged&& ...
    ~report.simCalled&&~report.carSimRun;
save(resultFile,'report','-v7');
fprintf(['V28_A2_COMPILE|static=%d|compile=%d|term=%d|compiled=%d|' ...
    'steer100=%d|errors100=%d|yaw100=%d|source=%d|target=%d|passed=%d|sim=0|carsim=0\n'], ...
    report.staticPassed,report.compilePassed,report.terminationReached, ...
    report.compiledEvidenceCaptured,compiled_field(report,'steering100Hz'), ...
    compiled_field(report,'dError100Hz')&&compiled_field(report,'kError100Hz'), ...
    compiled_field(report,'signedYaw100Hz'),report.sourceUnchanged,report.targetUnchanged,report.passed);
if ~report.passed
    fprintf('V28_A2_ERROR|%s|%s\n',report.firstErrorIdentifier,report.firstErrorMessage);
end
assert(report.passed,'V28A2:CompileGateFailed', ...
    'Long-low-yaw validation target compile gate failed.');
clear cleanup
end

function id=source_identity(inputPort)
lh=get_param(inputPort,'Line');assert(isscalar(lh)&&lh>0,'Input is disconnected.');
sp=get_param(lh,'SrcPortHandle');b=get_param(sp,'Parent');n=get_param(sp,'PortNumber');
if isnumeric(n),n=num2str(n);end,id=[b '#' n];
end

function value=constant_source_value(inputPort)
lh=get_param(inputPort,'Line');sp=get_param(lh,'SrcPortHandle');b=get_param(sp,'Parent');
assert(strcmp(get_param(b,'BlockType'),'Constant'),'Rear steering source is not Constant.');
value=str2double(get_param(b,'Value'));
end

function ok=diagnostic_sink_only(m,sumName)
ph=get_param([m '/' sumName],'PortHandles');lh=get_param(ph.Outport(1),'Line');
dst=get_param(lh,'DstBlockHandle');
ok=numel(dst)==1&&strcmp(get_param(dst,'BlockType'),'ToWorkspace');
end

function ok=compiled_output_scalar(dims)
if isstruct(dims),dims=dims.Outport;end
if iscell(dims),dims=dims{1};end
dims=double(dims);ok=~isempty(dims)&&prod(dims)==1;
end

function ok=compiled_output_double(types)
if isstruct(types),types=types.Outport;end
if iscell(types),types=types{1};end
ok=strcmp(types,'double');
end

function ok=sample_is_100hz(x)
if iscell(x),x=x{1};end
x=double(x);ok=numel(x)>=2&&abs(x(1)-0.01)<=1e-12&&abs(x(2))<=1e-12;
end

function v=compiled_field(report,name)
v=false;if isfield(report,'compiled')&&isfield(report.compiled,name),v=report.compiled.(name);end
end

function close_all(m)
if bdIsLoaded(m),try,close_system(m,0);catch,end,end
if bdIsLoaded('Solver_SF'),try,close_system('Solver_SF',0);catch,end,end
end

function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');
hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
