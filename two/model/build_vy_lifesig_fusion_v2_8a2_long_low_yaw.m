function build = build_vy_lifesig_fusion_v2_8a2_long_low_yaw()
%BUILD_VY_LIFESIG_FUSION_V2_8A2_LONG_LOW_YAW Build an independent target.
% The deterministic steering input contains one complete sine period and
% then holds exact zero.  This builder never calls sim().

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
sourceFile=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
targetFile=fullfile(md,'vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx');
resultFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_build.mat');
sourceExpected='65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0';
assert(isfile(sourceFile),'V28A2:SourceMissing','Accepted V2.7 target is missing.');
assert(strcmp(file_sha256(sourceFile),sourceExpected),'V28A2:SourceHashMismatch', ...
    'Accepted V2.7 target hash differs from the frozen value.');
if isfile(targetFile)
    assert(~isfile(resultFile)&&strcmp(file_sha256(targetFile),sourceExpected), ...
        'V28A2:TargetExists', ...
        ['Independent target already exists and is not the verified pristine ' ...
         'copy left by a pre-build audit failure.']);
end

sourceHashBefore=file_sha256(sourceFile);
if ~isfile(targetFile),copyfile(sourceFile,targetFile);end
addpath(md);load_system('simulink');load_system(targetFile);
m='vx_vy_lifesig_fusion_v2_8a2_long_low_yaw';
cleanup=onCleanup(@()close_without_save(m));

% Deterministic 100-Hz profile: 2 s straight, one 0.4-Hz sine period,
% followed by 17.5 s of exact-zero road-wheel steering command.
Ts=0.01;stopTime=22.0;straightBefore=2.0;amplitude=0.02;frequency=0.4;
period=1/frequency;excitationEnd=straightBefore+period;
t=(0:round(stopTime/Ts))'*Ts;u=zeros(size(t));
active=t>straightBefore & t<excitationEnd;
u(active)=amplitude*sin(2*pi*frequency*(t(active)-straightBefore));
u(t<=straightBefore | t>=excitationEnd)=0;
profile=[t u];
assert(size(profile,1)==2201&&all(diff(t)>0)&&max(abs(diff(t)-Ts))<1e-12, ...
    'V28A2:ProfileTimeInvalid','Long-low-yaw profile time base is invalid.');
sampledMax=max(abs(u));
assert(sampledMax<=amplitude+eps(amplitude)&&sampledMax>=0.999*amplitude, ...
    'V28A2:ProfileAmplitudeInvalid', ...
    'Sampled sine does not represent the specified 0.02-rad amplitude.');
assert(all(u(t>=excitationEnd)==0),'V28A2:PostSteerNotZero', ...
    'Steering is not exact zero after the excitation period.');
assert(stopTime-excitationEnd>=10,'V28A2:LowYawWindowTooShort', ...
    'Post-excitation straight interval is shorter than 10 s.');

cmd=[m '/G0 Steer Cmd Rad'];
oldPosition=get_param(cmd,'Position');
oldPH=get_param(cmd,'PortHandles');oldLine=get_param(oldPH.Outport(1),'Line');
assert(isscalar(oldLine)&&oldLine>0,'V28A2:SteerSourceDisconnected', ...
    'Accepted steering source is disconnected.');
dstPH=get_param(oldLine,'DstPortHandle');
destinations=materialize_destinations(dstPH);
delete_line(oldLine);delete_block(cmd);
add_block('simulink/Sources/From Workspace',cmd, ...
    'Position',oldPosition,'VariableName','long_low_yaw_steer_profile', ...
    'SampleTime','0.01','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value');
w=get_param(m,'ModelWorkspace');
assignin(w,'long_low_yaw_steer_profile',profile);
assignin(w,'long_low_yaw_sample_time',Ts);
assignin(w,'long_low_yaw_stop_time',stopTime);
assignin(w,'long_low_yaw_initial_straight_s',straightBefore);
assignin(w,'long_low_yaw_steer_amplitude_rad',amplitude);
assignin(w,'long_low_yaw_steer_frequency_hz',frequency);
assignin(w,'long_low_yaw_excitation_end_s',excitationEnd);
newPH=get_param(cmd,'PortHandles');
for k=1:numel(destinations)
    dp=get_param(destinations(k).block,'PortHandles');
    add_line(m,newPH.Outport(1),dp.Inport(destinations(k).port), ...
        'autorouting','on');
end

% Add observation-only signed-yaw and error logs.  Vy_true is used only by
% these diagnostic sinks and never enters D, K, F, or LifeSig computation.
dVy=log_source_port(m,'fusion_vy_d_log');
kVy=log_source_port(m,'fusion_vy_k_log');
truth=log_source_port(m,'rel_vy_true_100hz_log');
kInputMux=[m '/K-KF Input Log Mux'];kMuxPH=get_param(kInputMux,'PortHandles');
signedYaw=source_port(kMuxPH.Inport(3));
add_ws_from_port(m,signedYaw,'Long Low Yaw Signed r Log', ...
    'long_low_yaw_r_log',[7600 560 7800 590]);
add_error_log(m,dVy,truth,'Long Low Yaw D Error', ...
    'Long Low Yaw D Error Log','long_low_yaw_d_error_log',[7600 630 7640 670],[7800 630 8000 660]);
add_error_log(m,kVy,truth,'Long Low Yaw K Error', ...
    'Long Low Yaw K Error Log','long_low_yaw_k_error_log',[7600 710 7640 750],[7800 710 8000 740]);

set_param(m,'StopTime',num2str(stopTime,'%.17g'));
set_param(m,'Description',sprintf([get_param(m,'Description') '\n' ...
    'V2.8-A2 NON-HOLDOUT LONG-LOW-YAW VALIDATION TARGET. 100-Hz steering: ' ...
    '2.0 s exact zero, one 0.02-rad 0.4-Hz sine period, then 17.5 s exact zero. ' ...
    'Vy_true and D/K errors are observation-only diagnostics. No K gate is implemented.']));

static=static_audit(m,profile,sourceExpected);
save_system(m,targetFile);
targetHash=file_sha256(targetFile);
close_system(m,0);
sourceHashAfter=file_sha256(sourceFile);
assert(strcmp(sourceHashBefore,sourceHashAfter)&&strcmp(sourceHashAfter,sourceExpected), ...
    'V28A2:FrozenSourceChanged','Accepted V2.7 target changed during build.');

build=struct();build.stage='V2.8-A2';
build.role='NON_HOLDOUT_LONG_LOW_YAW_OBSERVABILITY_VALIDATION';
build.sourceFile=sourceFile;build.sourceHashBefore=sourceHashBefore;
build.sourceHashAfter=sourceHashAfter;build.sourceUnchanged=true;
build.targetFile=targetFile;build.targetHash=targetHash;
build.profileVariable='long_low_yaw_steer_profile';build.profile=profile;
build.Ts=Ts;build.stopTime=stopTime;build.initialStraight=straightBefore;
build.amplitudeRad=amplitude;build.frequencyHz=frequency;
build.excitationEnd=excitationEnd;build.postExcitationStraight=stopTime-excitationEnd;
build.destinations=destinations;build.static=static;
build.requiredLogs={'rel_common_time_100hz_log';'steer_cmd_rad'; ...
    'long_low_yaw_r_log';'rel_vy_true_100hz_log';'fusion_vy_d_log'; ...
    'fusion_vy_k_log';'long_low_yaw_k_error_log';'long_low_yaw_d_error_log'};
build.kInputLogOrdering={'Ax';'Ay';'AVz_signed_yaw_rate';'Vx'};
build.candidateYawBoundaryImplemented=false;
build.simCalled=false;build.carSimRun=false;
save(resultFile,'build','-v7');
fprintf(['V28_A2_BUILD|target=%s|samples=%d|excitation=[%.2f,%.2f]|' ...
    'postZero=%.2f|logs=%d|sim=0|carsim=0\n'],targetHash,size(profile,1), ...
    straightBefore,excitationEnd,stopTime-excitationEnd,numel(build.requiredLogs));
clear cleanup
end

function destinations=materialize_destinations(handles)
handles=handles(:);destinations=repmat(struct('block','','port',0),numel(handles),1);
for k=1:numel(handles)
    assert(handles(k)>0,'V28A2:InvalidDestination','Invalid steering destination port.');
    destinations(k).block=get_param(handles(k),'Parent');
    destinations(k).port=double(get_param(handles(k),'PortNumber'));
end
end

function p=log_source_port(m,var)
b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace','VariableName',var);
assert(numel(b)==1,'V28A2:LogSourceAmbiguous', ...
    'Expected exactly one To Workspace block for %s.',var);
ph=get_param(b{1},'PortHandles');p=source_port(ph.Inport(1));
end

function p=source_port(inputPort)
lh=get_param(inputPort,'Line');
assert(isscalar(lh)&&lh>0,'V28A2:InputDisconnected','Required input is disconnected.');
p=get_param(lh,'SrcPortHandle');
assert(isscalar(p)&&p>0,'V28A2:SourceMissing','Required input source is missing.');
end

function add_ws_from_port(m,src,name,var,pos)
b=[m '/' name];
add_block('simulink/Sinks/To Workspace',b,'VariableName',var, ...
    'SaveFormat','Timeseries','Position',pos);
ph=get_param(b,'PortHandles');add_line(m,src,ph.Inport(1),'autorouting','on');
end

function add_error_log(m,estimate,truth,sumName,logName,var,sumPos,logPos)
s=[m '/' sumName];l=[m '/' logName];
add_block('simulink/Math Operations/Sum',s,'Inputs','+-','Position',sumPos);
add_block('simulink/Sinks/To Workspace',l,'VariableName',var, ...
    'SaveFormat','Timeseries','Position',logPos);
sph=get_param(s,'PortHandles');lph=get_param(l,'PortHandles');
add_line(m,estimate,sph.Inport(1),'autorouting','on');
add_line(m,truth,sph.Inport(2),'autorouting','on');
add_line(m,sph.Outport(1),lph.Inport(1),'autorouting','on');
end

function audit=static_audit(m,profile,sourceExpected)
cmd=[m '/G0 Steer Cmd Rad'];gain=[m '/Gain22'];mux8=[m '/Mux8'];
sw=[m '/Manual Switch1'];
audit=struct();audit.sourceHashExpected=sourceExpected;
audit.sourceBlockType=get_param(cmd,'BlockType');
audit.sourceVariable=get_param(cmd,'VariableName');
audit.sourceSampleTime=get_param(cmd,'SampleTime');
audit.sourceInterpolate=get_param(cmd,'Interpolate');
audit.sourceAfterFinal=get_param(cmd,'OutputAfterFinalValue');
audit.profileSamples=size(profile,1);audit.profileMaxAbs=max(abs(profile(:,2)));
audit.profileFinalValue=profile(end,2);
audit.gain=get_param(gain,'Gain');
gph=get_param(gain,'PortHandles');audit.gainSource=source_identity(gph.Inport(1));
m8=get_param(mux8,'PortHandles');
audit.mux8Sources=cell(8,1);
for k=1:8,audit.mux8Sources{k}=source_identity(m8.Inport(k));end
sph=get_param(sw,'PortHandles');
audit.switchInput1=source_identity(sph.Inport(1));
audit.switchInput2=source_identity(sph.Inport(2));
audit.switchSetting=get_param(sw,'CurrentSetting');
audit.rearValues=[constant_source_value(m8.Inport(6)),constant_source_value(m8.Inport(8))];
audit.frontPathOK=strcmp(audit.gain,'180/pi')&&strcmp(audit.gainSource,[cmd '#1'])&& ...
    strcmp(audit.mux8Sources{2},[gain '#1'])&&strcmp(audit.mux8Sources{4},[gain '#1'])&& ...
    strcmp(audit.switchInput2,[mux8 '#1'])&&strcmp(audit.switchSetting,'0');
audit.rearZero=all(audit.rearValues==0);
required={'rel_common_time_100hz_log','steer_cmd_rad','long_low_yaw_r_log', ...
    'rel_vy_true_100hz_log','fusion_vy_d_log','fusion_vy_k_log', ...
    'long_low_yaw_k_error_log','long_low_yaw_d_error_log'};
audit.requiredLogs=required(:);audit.logsPresent=true;
for k=1:numel(required)
    b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
        'BlockType','ToWorkspace','VariableName',required{k});
    audit.logsPresent=audit.logsPresent&&numel(b)==1;
end
audit.truthDiagnosticOnly=diagnostic_sink_only(m,'Long Low Yaw D Error')&& ...
    diagnostic_sink_only(m,'Long Low Yaw K Error');
audit.noCandidateYawGate=true;
audit.passed=strcmp(audit.sourceBlockType,'FromWorkspace')&& ...
    strcmp(audit.sourceVariable,'long_low_yaw_steer_profile')&& ...
    strcmp(audit.sourceSampleTime,'0.01')&&strcmp(audit.sourceInterpolate,'off')&& ...
    strcmp(audit.sourceAfterFinal,'Holding final value')&& ...
    audit.profileMaxAbs<=0.02+eps(0.02)&&audit.profileMaxAbs>=0.999*0.02&& ...
    audit.profileFinalValue==0&& ...
    audit.frontPathOK&&audit.rearZero&&audit.logsPresent&&audit.truthDiagnosticOnly;
assert(audit.passed,'V28A2:StaticAuditFailed','Long-low-yaw target static audit failed.');
end

function ok=diagnostic_sink_only(m,sumName)
ph=get_param([m '/' sumName],'PortHandles');lh=get_param(ph.Outport(1),'Line');
dst=get_param(lh,'DstBlockHandle');
ok=numel(dst)==1&&strcmp(get_param(dst,'BlockType'),'ToWorkspace');
end

function value=constant_source_value(inputPort)
lh=get_param(inputPort,'Line');sp=get_param(lh,'SrcPortHandle');b=get_param(sp,'Parent');
assert(strcmp(get_param(b,'BlockType'),'Constant'),'V28A2:RearSourceNotConstant', ...
    'Rear steering source is not a Constant block.');
value=str2double(get_param(b,'Value'));
end

function id=source_identity(inputPort)
lh=get_param(inputPort,'Line');assert(isscalar(lh)&&lh>0,'Input is disconnected.');
sp=get_param(lh,'SrcPortHandle');b=get_param(sp,'Parent');n=get_param(sp,'PortNumber');
if isnumeric(n),n=num2str(n);end,id=[b '#' n];
end

function close_without_save(m)
if bdIsLoaded(m),try,close_system(m,0);catch,end,end
end

function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');
hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
