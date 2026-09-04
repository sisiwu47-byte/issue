function build = build_vy_lifesig_fusion_v2_7a3r8()
%BUILD_VY_LIFESIG_FUSION_V2_7A3R8 Create independent integration target.
% The builder saves only the new target and never calls sim().

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
sourceFile=fullfile(md,'vx_vy_reliability_diagnostic_v2_7.slx');
targetFile=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r8_build.mat');
sourceExpected='2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F';
targetExpected='4C134667E94E4D56D53BC2B96D92D5693E74DE36A8CD68561B80811EFC5D6A79';
coreExpected='3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA';
wrapperExpected='E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445';
coreFile=fullfile(md,'vy_lifesig_fusion_step.m');
wrapperFile=fullfile(md,'vy_lifesig_fusion_simulink_sfun.m');

assert(strcmp(file_sha256(sourceFile),sourceExpected),'A3R8:SourceHashMismatch', ...
    'Reliability diagnostic source target hash mismatch.');
assert(strcmp(file_sha256(coreFile),coreExpected),'A3R8:CoreHashMismatch', ...
    'LifeSig core hash mismatch.');
assert(strcmp(file_sha256(wrapperFile),wrapperExpected),'A3R8:WrapperHashMismatch', ...
    'LifeSig wrapper hash mismatch.');
if isfile(targetFile)
    build=pack_existing_target(md,sourceFile,targetFile,resultFile, ...
        sourceExpected,targetExpected,coreFile,coreExpected,wrapperFile,wrapperExpected);
    return
end
assert(~isfile(targetFile),'A3R8:TargetExists', ...
    'LifeSig integration target already exists; builder will not overwrite it.');

sourceHashBefore=file_sha256(sourceFile);
copyfile(sourceFile,targetFile);
addpath(md);
load_system('simulink');
load_system(targetFile);
m='vx_vy_lifesig_fusion_v2_7';
cleanup=onCleanup(@()close_without_save(m));

dVy=log_source_port(m,'fusion_vy_d_log');
dValidVector=log_source_port(m,'rel_d_valid_log');
kVy=log_source_port(m,'fusion_vy_k_log');
kDiagVector=log_source_port(m,'kkf_diag_log1');
fVy=log_source_port(m,'fusion_vy_f_log');
fReliabilityVector=log_source_port(m,'rel_f_reliability_log');
resetPort=log_source_port(m,'reset_g0');

dDemux=[m '/D LifeSig Valid Demux'];
kDemux=[m '/K LifeSig Diagnostic Demux'];
fDemux=[m '/F LifeSig Reliability Demux'];
fusion=[m '/LifeSig D K F Fusion'];
add_block('simulink/Signal Routing/Demux',dDemux,'Outputs','[1 1]', ...
    'Position',[6480 100 6485 155]);
add_block('simulink/Signal Routing/Demux',kDemux, ...
    'Outputs','[1 1 1 1 1 1 1]','Position',[6480 220 6485 375]);
add_block('simulink/Signal Routing/Demux',fDemux,'Outputs','[1 1 1]', ...
    'Position',[6480 445 6485 520]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', ...
    fusion,'FunctionName','vy_lifesig_fusion_simulink_sfun', ...
    'Position',[6800 210 7060 500]);

connect_port(m,dValidVector,dDemux,1);
connect_port(m,kDiagVector,kDemux,1);
connect_port(m,fReliabilityVector,fDemux,1);
connect_port(m,dVy,fusion,1);
connect(m,dDemux,1,fusion,2);
connect_port(m,kVy,fusion,3);
connect(m,kDemux,6,fusion,4);
connect_port(m,fVy,fusion,5);
connect(m,fDemux,1,fusion,6);
connect(m,fDemux,2,fusion,7);
connect_port(m,resetPort,fusion,8);

logNames={'lifesig_vy_ls_log','lifesig_alpha_d_log', ...
    'lifesig_alpha_k_log','lifesig_alpha_f_log','lifesig_h_d_log', ...
    'lifesig_h_k_log','lifesig_h_f_log','lifesig_fusion_valid_log', ...
    'lifesig_fallback_active_log'};
logs=cell(numel(logNames),1);
for k=1:numel(logNames)
    logs{k}=add_ws(m,fusion,k,logNames{k}, ...
        [7240 70+52*k 7420 100+52*k]);
end

description=sprintf([get_param(m,'Description') '\n' ...
    'V2.7 LIFESIG INTEGRATION TARGET. Independent observation-only LifeSig fusion. ' ...
    'Formal fusion inputs are Vy_D/update_valid_D, Vy_K/update_valid_K, ' ...
    'Vy_F/propagation_age_steps/age_valid_F, and reset only. ' ...
    'NIS, yaw observability, disagreement, covariance, and online truth are excluded. ' ...
    'Existing F runtime parameters remain P0_F=0.5 and Q_F=0.0025.']);
set_param(m,'Description',description);
[~,steeringConfig]=ensure_steering_source_configuration(m);
inputSources={port_identity(dVy);[dDemux '#1'];port_identity(kVy); ...
    [kDemux '#6'];port_identity(fVy);[fDemux '#1'];[fDemux '#2']; ...
    port_identity(resetPort)};
currentFParameters=get_param([m '/F-Track 100Hz/F-Track Stateful Boundary'],'Parameters');
save_system(m,targetFile);
targetHash=file_sha256(targetFile);
close_system(m,0);
sourceHashAfter=file_sha256(sourceFile);
assert(strcmp(sourceHashBefore,sourceHashAfter)&&strcmp(sourceHashAfter,sourceExpected), ...
    'A3R8:SourceChanged','Reliability diagnostic source target changed.');

build=struct();build.stage='V2.7-A3R8';
build.sourceFile=sourceFile;build.sourceHashBefore=sourceHashBefore;
build.sourceHashAfter=sourceHashAfter;build.sourceUnchanged=true;
build.targetFile=targetFile;build.targetHash=targetHash;
build.coreFile=coreFile;build.coreHash=coreExpected;
build.wrapperFile=wrapperFile;build.wrapperHash=wrapperExpected;
build.fusionBlock=fusion;build.logNames=logNames(:);
build.inputSources=inputSources;
build.currentFParameters=currentFParameters;
build.steeringConfiguration=steeringConfig;
build.evidenceLifecycle='MATERIALIZED_BEFORE_MODEL_CLOSE';
build.targetRebuilt=true;
build.simCalled=false;build.carSimRun=false;
save(resultFile,'build','-v7');
fprintf('A3R8_BUILD|target=%s|sourceUnchanged=1|logs=%d|sim=0|carsim=0\n', ...
    targetHash,numel(logNames));
clear cleanup
end

function build=pack_existing_target(md,sourceFile,targetFile,resultFile, ...
    sourceExpected,targetExpected,coreFile,coreExpected,wrapperFile,wrapperExpected)
% Recover evidence for the already-saved R1 target without rebuilding it.
sourceHashBefore=file_sha256(sourceFile);
targetHashBefore=file_sha256(targetFile);
assert(existing_target_lineage_ok(targetHashBefore,targetExpected,resultFile), ...
    'A3R8:ExistingTargetHashMismatch', ...
    'Existing LifeSig integration target differs from the R1 frozen target.');

addpath(md);
solverRoot='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
addpath(solverRoot,fullfile(solverRoot,'Matlab84+'));
load_system('simulink');
load_system('Solver_SF');
load_system(targetFile);
m='vx_vy_lifesig_fusion_v2_7';
cleanup=onCleanup(@()close_without_save(m));

dVy=log_source_port(m,'fusion_vy_d_log');
dValidVector=log_source_port(m,'rel_d_valid_log');
kVy=log_source_port(m,'fusion_vy_k_log');
kDiagVector=log_source_port(m,'kkf_diag_log1');
fVy=log_source_port(m,'fusion_vy_f_log');
fReliabilityVector=log_source_port(m,'rel_f_reliability_log');
resetPort=log_source_port(m,'reset_g0');
dDemux=[m '/D LifeSig Valid Demux'];
kDemux=[m '/K LifeSig Diagnostic Demux'];
fDemux=[m '/F LifeSig Reliability Demux'];
fusion=[m '/LifeSig D K F Fusion'];
assert(getSimulinkBlockHandle(dDemux)>0&&getSimulinkBlockHandle(kDemux)>0&& ...
    getSimulinkBlockHandle(fDemux)>0&&getSimulinkBlockHandle(fusion)>0, ...
    'A3R8:ExistingTargetIncomplete','Existing LifeSig target is incomplete.');
[steeringConfigChanged,steeringConfig]=ensure_steering_source_configuration(m);
if steeringConfigChanged
    save_system(m,targetFile);
end

logNames={'lifesig_vy_ls_log','lifesig_alpha_d_log', ...
    'lifesig_alpha_k_log','lifesig_alpha_f_log','lifesig_h_d_log', ...
    'lifesig_h_k_log','lifesig_h_f_log','lifesig_fusion_valid_log', ...
    'lifesig_fallback_active_log'};
for k=1:numel(logNames)
    b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
        'BlockType','ToWorkspace','VariableName',logNames{k});
    assert(numel(b)==1,'A3R8:ExistingLogMissing', ...
        'Existing target log %s is missing or ambiguous.',logNames{k});
end

% Materialize every handle-derived identity while the model is still open.
inputSources={port_identity(dVy);[dDemux '#1'];port_identity(kVy); ...
    [kDemux '#6'];port_identity(fVy);[fDemux '#1'];[fDemux '#2']; ...
    port_identity(resetPort)};
sourceVectorIdentities={port_identity(dValidVector);port_identity(kDiagVector); ...
    port_identity(fReliabilityVector)};
currentFParameters=get_param([m '/F-Track 100Hz/F-Track Stateful Boundary'],'Parameters');
fusionFunction=get_param(fusion,'FunctionName');
materialized=struct('inputSources',{inputSources}, ...
    'sourceVectorIdentities',{sourceVectorIdentities}, ...
    'currentFParameters',currentFParameters,'fusionFunction',fusionFunction, ...
    'fusionBlock',fusion,'logNames',{logNames(:)}, ...
    'steeringConfiguration',steeringConfig);

close_system(m,0);
sourceHashAfter=file_sha256(sourceFile);
targetHashAfter=file_sha256(targetFile);
assert(strcmp(sourceHashBefore,sourceHashAfter)&&strcmp(sourceHashAfter,sourceExpected), ...
    'A3R8:SourceChanged','Reliability diagnostic source target changed.');
if ~steeringConfigChanged
    assert(strcmp(targetHashBefore,targetHashAfter), ...
        'A3R8:TargetChanged','Existing LifeSig target changed during evidence recovery.');
end

build=struct();build.stage='V2.7-A3R8R2';
build.sourceFile=sourceFile;build.sourceHashBefore=sourceHashBefore;
build.sourceHashAfter=sourceHashAfter;build.sourceUnchanged=true;
build.targetFile=targetFile;build.targetHash=targetHashAfter;
build.targetHashBefore=targetHashBefore;build.targetHashAfter=targetHashAfter;
build.targetUnchanged=strcmp(targetHashBefore,targetHashAfter);
build.targetRebuilt=false;build.targetSteeringConfigModified=steeringConfigChanged;
build.coreFile=coreFile;build.coreHash=coreExpected;
build.wrapperFile=wrapperFile;build.wrapperHash=wrapperExpected;
build.fusionBlock=materialized.fusionBlock;build.logNames=materialized.logNames;
build.inputSources=materialized.inputSources;
build.sourceVectorIdentities=materialized.sourceVectorIdentities;
build.currentFParameters=materialized.currentFParameters;
build.fusionFunction=materialized.fusionFunction;
build.steeringConfiguration=materialized.steeringConfiguration;
build.evidenceLifecycle='MATERIALIZED_BEFORE_MODEL_CLOSE';
build.simCalled=false;build.carSimRun=false;
save(resultFile,'build','-v7');
fprintf(['A3R8R2_BUILD_EVIDENCE|target=%s|targetUnchanged=%d|rebuilt=0|' ...
    'steeringConfigModified=%d|logs=%d|sim=0|carsim=0\n'], ...
    targetHashAfter,build.targetUnchanged,steeringConfigChanged,numel(logNames));
clear cleanup
end

function ok=existing_target_lineage_ok(actualHash,legacyExpected,resultFile)
ok=strcmp(actualHash,legacyExpected);
if ~ok&&isfile(resultFile)
    prior=load(resultFile,'build');
    ok=isfield(prior,'build')&&isfield(prior.build,'targetHash')&& ...
        strcmp(actualHash,prior.build.targetHash);
end
end

function [changed,cfg]=ensure_steering_source_configuration(m)
% Keep the proven variable-based steering semantics, with persistent defaults.
b=[m '/G0 Steer Cmd Rad'];
cfg=struct();
cfg.block=b;
cfg.amplitudeExpression=get_param(b,'Amplitude');
cfg.frequencyExpression=get_param(b,'Frequency');
cfg.sampleTime=get_param(b,'SampleTime');
assert(strcmp(cfg.amplitudeExpression,'test_steer_amplitude')&& ...
    strcmp(cfg.frequencyExpression,'2*pi*test_steer_frequency')&& ...
    strcmp(cfg.sampleTime,'0'),'A3R8:SteeringSourceDefinitionMismatch', ...
    'LifeSig target steering source differs from the proven diagnostic definition.');
w=get_param(m,'ModelWorkspace');
changed=ensure_model_workspace_scalar(w,'test_steer_amplitude',0.02);
changed=ensure_model_workspace_scalar(w,'test_steer_frequency',0.4)||changed;
cfg.amplitudeDefault=evalin(w,'test_steer_amplitude');
cfg.frequencyDefault=evalin(w,'test_steer_frequency');
cfg.workspace='ModelWorkspace';
cfg.definitionAccepted=cfg.amplitudeDefault==0.02&&cfg.frequencyDefault==0.4;
assert(cfg.definitionAccepted,'A3R8:SteeringWorkspaceInvalid', ...
    'LifeSig target steering workspace defaults are invalid.');
end

function changed=ensure_model_workspace_scalar(w,name,value)
exists=evalin(w,sprintf('exist(''%s'',''var'')',name))==1;
changed=true;
if exists
    current=evalin(w,name);
    changed=~(isnumeric(current)&&isscalar(current)&&isfinite(current)&&current==value);
end
if changed
    assignin(w,name,value);
end
end

function p=log_source_port(m,var)
b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace','VariableName',var);
assert(numel(b)==1,'A3R8:LogSourceAmbiguous', ...
    'Expected exactly one To Workspace source for %s.',var);
ph=get_param(b{1},'PortHandles');lh=get_param(ph.Inport(1),'Line');
assert(isscalar(lh)&&lh>0,'A3R8:LogDisconnected','Log %s is disconnected.',var);
p=get_param(lh,'SrcPortHandle');
assert(isscalar(p)&&p>0,'A3R8:LogSourceMissing','Log %s source is missing.',var);
end
function connect_port(m,sourcePort,destination,inputIndex)
dp=get_param(destination,'PortHandles');
add_line(m,sourcePort,dp.Inport(inputIndex),'autorouting','on');
end
function connect(m,source,outputIndex,destination,inputIndex)
sp=get_param(source,'PortHandles');dp=get_param(destination,'PortHandles');
add_line(m,sp.Outport(outputIndex),dp.Inport(inputIndex),'autorouting','on');
end
function p=add_ws(m,source,outputIndex,var,pos)
p=[m '/' var];
add_block('simulink/Sinks/To Workspace',p,'VariableName',var, ...
    'SaveFormat','Timeseries','Position',pos);
connect(m,source,outputIndex,p,1);
end
function id=port_identity(p)
b=get_param(p,'Parent');n=get_param(p,'PortNumber');
if isnumeric(n),n=num2str(n);end
id=[b '#' n];
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
