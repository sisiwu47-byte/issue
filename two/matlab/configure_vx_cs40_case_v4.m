function [simIn,cfg] = configure_vx_cs40_case_v4()
%CONFIGURE_VX_CS40_CASE_V4 Prepare corrected-initial-speed validation copy.
% This function does not invoke simulation or modify any source/evidence file.

root=fileparts(fileparts(mfilename('fullpath')));
source=struct('model',fullfile(root,'model','vx.slx'), ...
    'estimator',fullfile(root,'model','longitudinal_velocity_estimator.m'), ...
    'parameter',fullfile(root,'model','estimator_default_params.m'), ...
    'wrapper',fullfile(root,'model','longitudinal_velocity_estimator_simulink.m'));
frozen=struct('model','7D01E24D44903C836B4738FBAC480ED039B2188C3C96C4B3218274446F50D516', ...
    'estimator','68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107', ...
    'parameter','09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4', ...
    'wrapper','93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061');
names=fieldnames(source);
for k=1:numel(names)
    assert(strcmp(sha256_file(source.(names{k})),frozen.(names{k})), ...
        'VX:V4:FrozenSourceHash','Frozen %s hash changed.',names{k});
end

v4Root=fullfile(root,'results','vx_formal_validation','v4_cs40');
controlDir=fullfile(v4Root,'carsim_control_CS40');
manifestFile=fullfile(controlDir,'control_manifest.json');
manifest=jsondecode(fileread(manifestFile));
runAll=fullfile(controlDir,'Run_all.par');simfile=fullfile(controlDir,'simfile.sim');
assert(strcmp(sha256_file(runAll),manifest.runAllSha256)&& ...
    strcmp(sha256_file(simfile),manifest.simfileSha256),'VX:V4:ControlHash');
text=fileread(runAll);
activeInitialSpeed=token_number(text,'SV_VXS');
activeMu=token_number(text,'MU_ROAD_CONSTANT');
activeStopTime=token_number(text,'TSTOP');
assert(strcmp(manifest.initialSpeedToken,'SV_VXS')&&strcmp(manifest.initialSpeedUnit,'km/h'), ...
    'VX:V4:InitialSpeedMetadata');
assert(abs(activeInitialSpeed-40)<=0.1,'VX:V4:PreInitialSpeedGate', ...
    'CURRENT_CARSIM_RUN_NOT_SAVED_AS_40_KMH');
assert(abs(activeMu-0.30)<=1e-12,'VX:V4:PreMuGate','MU_ROAD_CONSTANT is not 0.30.');
assert(abs(activeStopTime-16)<=1e-12,'VX:V4:PreStopTimeGate','TSTOP is not 16 s.');

speedTime=[0;3;7;9;11.5;16];speedKmh=[40;40;70;70;40;40];
modelDir=fullfile(v4Root,'configured','model');if ~isfolder(modelDir),mkdir(modelDir);end
modelName='vx_cs40_v4';modelFile=fullfile(modelDir,[modelName '.slx']);
if bdIsLoaded(modelName),close_system(modelName,0);end
copyfile(source.model,modelFile,'f');load_system(modelFile);
c=onCleanup(@()close_if_loaded(modelName));
referenceBlock=Simulink.ID.getFullName(sprintf('%s:438',modelName));
set_param(referenceBlock,'TimeValues',mat2str(speedTime,17), ...
    'OutValues',mat2str(speedKmh,17),'tsamp','0.001');
set_param(modelName,'StopTime','16');
steerSource=Simulink.ID.getFullName(sprintf('%s:79',modelName));
replace_with_zero(modelName,steerSource);disable_unused_duplicate_wheel_tags(modelName);
save_system(modelName);
simIn=Simulink.SimulationInput(modelName);
simIn=simIn.setModelParameter('StopTime','16','ReturnWorkspaceOutputs','on');
oldEvidence=struct( ...
    'v3bRawFile',fullfile(root,'results','vx_formal_validation','v3b','runtime','VX_CS_formal_raw.mat'), ...
    'v3bRawSha256','9939966224F1362759A14596B0A1351DC7CB00235F55E06A99D82CBCA9C21CA7', ...
    'v3bFreezeFile',fullfile(root,'results','vx_formal_validation','v3b','frozen_physical_excitation.json'), ...
    'v3bFreezeSha256','BA30E364FA41531187DE1BB4C678EB0C68B559A2504FD79B8337899E97E5C86B');
assert(strcmp(sha256_file(oldEvidence.v3bRawFile),oldEvidence.v3bRawSha256)&& ...
    strcmp(sha256_file(oldEvidence.v3bFreezeFile),oldEvidence.v3bFreezeSha256), ...
    'VX:V4:OldEvidenceHash');
cfg=struct('stage','VX-V4-CS40','caseId','VX-CS40','configurationOnly',true, ...
    'simulationInvoked',false,'referenceUnit','km/h','referenceWasDividedBy3p6',false, ...
    'speedReference',struct('speedTime_s',speedTime,'speed_kmh',speedKmh), ...
    'steeringRad',0,'stopTime_s',16,'muRoadConstant',activeMu, ...
    'initialSpeedToken','SV_VXS','initialSpeedValue',activeInitialSpeed, ...
    'initialSpeedUnit','km/h','preRunInitialSpeedGatePass',abs(activeInitialSpeed-40)<=0.1, ...
    'preRunMuGatePass',abs(activeMu-0.30)<=1e-12,'sourceModel',source.model, ...
    'generatedModel',modelFile,'runtimeWorkingDirectory',controlDir, ...
    'runAll',runAll,'simfile',simfile,'controlManifestFile',manifestFile, ...
    'controlManifest',manifest,'frozenSourceHashes',frozen,'oldEvidence',oldEvidence, ...
    'generatedHashes',struct('model',sha256_file(modelFile), ...
    'runAll',sha256_file(runAll),'simfile',sha256_file(simfile), ...
    'manifest',sha256_file(manifestFile)));
save(fullfile(v4Root,'configured','case_configuration.mat'),'cfg');
clear c;close_if_loaded(modelName);
end

function replace_with_zero(modelName,oldBlock)
pos=get_param(oldBlock,'Position');ports=get_param(oldBlock,'PortHandles');
line=get_param(ports.Outport(1),'Line');assert(line~=-1,'VX:V4:SteeringRoute');
dst=get_param(line,'DstPortHandle');name=get_param(oldBlock,'Name');
delete_line(line);delete_block(oldBlock);newBlock=[modelName '/' name];
add_block('simulink/Sources/Constant',newBlock,'Position',pos,'Value','0');
p=get_param(newBlock,'PortHandles');add_line(modelName,p.Outport(1),dst(1),'autorouting','on');
end
function disable_unused_duplicate_wheel_tags(modelName)
blocks={'Goto72','Goto73','Goto74','Goto75'};tags={'R_FL','R_FR','R_RL','R_RR'};
allFrom=find_system(modelName,'LookUnderMasks','all','FollowLinks','on','BlockType','From');
for k=1:4
    b=[modelName '/' blocks{k}];assert(getSimulinkBlockHandle(b)~=-1&&strcmp(get_param(b,'GotoTag'),tags{k}),'VX:V4:DuplicateTagAudit');
    used=allFrom(cellfun(@(x)strcmp(get_param(x,'GotoTag'),tags{k}),allFrom));
    assert(isempty(used),'VX:V4:DuplicateTagUsed');set_param(b,'Commented','on');
end
end
function value=token_number(text,name)
token=regexp(text,['(?m)^' regexptranslate('escape',name) '[ \t]+([-+0-9.eE]+)[ \t]*(?=\r?$)'],'tokens','once');
assert(~isempty(token),'VX:V4:MissingToken','Missing token %s.',name);value=str2double(token{1});
assert(isfinite(value),'VX:V4:InvalidToken','Invalid numeric token %s.',name);
end
function hash=sha256_file(file)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));
q=java.security.DigestInputStream(s,d);c=onCleanup(@()q.close());while q.read()~=-1,end
hash=upper(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));clear c
end
function close_if_loaded(name)
if bdIsLoaded(name),close_system(name,0);end
end
