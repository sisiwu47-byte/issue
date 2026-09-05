function [simIn,cfg] = configure_vx_physical_calibration_v3b(candidate)
%CONFIGURE_VX_PHYSICAL_CALIBRATION_V3B Build one physical-only V3B copy.
% FORMAL_RUNTIME=false
% SIM_INVOCATION_COMMITTED=NO
% This function does not call sim and never saves model/vx.slx.

arguments
    candidate (1,1) string
end
candidate=upper(strtrim(candidate));
candidates=struct('T1_2P5',11.5,'T1_2P0',11.0,'T1_1P5',10.5);
assert(isfield(candidates,candidate),'VX:V3B:Candidate', ...
    'Tier-1 candidates are T1_2P5, T1_2P0 and T1_1P5.');
brakeRampEnd=candidates.(candidate);

root=fileparts(fileparts(mfilename('fullpath')));
sourceModel=fullfile(root,'model','vx.slx');
sourceFiles=struct( ...
    'model',sourceModel, ...
    'estimator',fullfile(root,'model','longitudinal_velocity_estimator.m'), ...
    'parameter',fullfile(root,'model','estimator_default_params.m'), ...
    'wrapper',fullfile(root,'model','longitudinal_velocity_estimator_simulink.m'));
frozen=struct( ...
    'model','7D01E24D44903C836B4738FBAC480ED039B2188C3C96C4B3218274446F50D516', ...
    'estimator','68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107', ...
    'parameter','09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4', ...
    'wrapper','93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061');
names=fieldnames(sourceFiles);
for k=1:numel(names)
    assert(strcmp(sha256_file(sourceFiles.(names{k})),frozen.(names{k})), ...
        'VX:V3B:FrozenHash','Frozen %s hash differs.',names{k});
end

speedTime=[0;3;7;9;brakeRampEnd;16];
speedKmh=[40;40;70;70;40;40];
configuredRoot=fullfile(root,'results','vx_formal_validation','v3b', ...
    'configured','calibration',char(candidate));
modelDir=fullfile(configuredRoot,'model');
controlDir=fullfile(configuredRoot,'carsim_control');
if ~isfolder(modelDir),mkdir(modelDir);end
if ~isfolder(controlDir),mkdir(controlDir);end
modelName=['vx_cal_v3b_' char(candidate)];
modelFile=fullfile(modelDir,[modelName '.slx']);
if bdIsLoaded(modelName),close_system(modelName,0);end
copyfile(sourceModel,modelFile,'f');
load_system(modelFile);
cleanupObject=onCleanup(@()close_if_loaded(modelName));

referenceBlock=Simulink.ID.getFullName(sprintf('%s:438',modelName));
set_param(referenceBlock,'TimeValues',mat2str(speedTime,17), ...
    'OutValues',mat2str(speedKmh,17),'tsamp','0.001');
set_param(modelName,'StopTime','16');
steerSource=Simulink.ID.getFullName(sprintf('%s:79',modelName));
replace_with_zero(modelName,steerSource);
disable_unused_duplicate_wheel_tags(modelName);

controlSource=fullfile(root,'results','vy_lifesig_v2_8a20b_mu03_diagnostic', ...
    'carsim_control_MU03');
sourceControl=struct('runAll','8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8', ...
    'simfile','D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A');
assert(strcmp(sha256_file(fullfile(controlSource,'Run_all.par')),sourceControl.runAll), ...
    'VX:V3B:ControlHash','Low-mu Run_all source hash differs.');
assert(strcmp(sha256_file(fullfile(controlSource,'simfile.sim')),sourceControl.simfile), ...
    'VX:V3B:ControlHash','Low-mu simfile source hash differs.');
copyfile(fullfile(controlSource,'Run_all.par'),fullfile(controlDir,'Run_all.par'),'f');
copyfile(fullfile(controlSource,'simfile.sim'),fullfile(controlDir,'simfile.sim'),'f');
runAll=fullfile(controlDir,'Run_all.par');
controlText=fileread(runAll);
tok=regexp(controlText,'(?m)^MU_ROAD_CONSTANT[ \t]+([0-9.]+)[ \t]*(?=\r?$)','tokens','once');
assert(~isempty(tok)&&abs(str2double(tok{1})-0.30)<1e-12, ...
    'VX:V3B:Mu','MU_ROAD_CONSTANT must be 0.30.');
controlText=regexprep(controlText,'(?m)^TSTOP[ \t]+[^\r\n]+','TSTOP 16');
write_text(runAll,controlText);
save_system(modelName);

simIn=Simulink.SimulationInput(modelName);
simIn=simIn.setModelParameter('StopTime','16','ReturnWorkspaceOutputs','on');
cfg=struct('stage','VX-V3B-PHYSICAL-CALIBRATION','candidate',char(candidate), ...
    'formalRuntime',false,'simInvocationCommitted','NO', ...
    'speedTime_s',speedTime,'speed_kmh',speedKmh, ...
    'brakeRampEnd_s',brakeRampEnd,'brakeAnalysisEnd_s',brakeRampEnd+0.5, ...
    'referenceUnit','km/h','muRoadConstant',0.30,'sourceModel',sourceModel, ...
    'generatedModel',modelFile,'runtimeWorkingDirectory',controlDir, ...
    'simfile',fullfile(controlDir,'simfile.sim'),'runAll',runAll, ...
    'frozenSourceHashes',frozen,'sourceControlHashes',sourceControl, ...
    'generatedHashes',struct('model',sha256_file(modelFile), ...
    'simfile',sha256_file(fullfile(controlDir,'simfile.sim')), ...
    'runAll',sha256_file(runAll)));
save(fullfile(configuredRoot,'case_configuration.mat'),'cfg');
clear cleanupObject
close_if_loaded(modelName);
end

function replace_with_zero(modelName,oldBlock)
pos=get_param(oldBlock,'Position');ports=get_param(oldBlock,'PortHandles');
line=get_param(ports.Outport(1),'Line');assert(line~=-1,'VX:V3B:SteerRoute');
dst=get_param(line,'DstPortHandle');name=get_param(oldBlock,'Name');
delete_line(line);delete_block(oldBlock);newBlock=[modelName '/' name];
add_block('simulink/Sources/Constant',newBlock,'Position',pos,'Value','0');
p=get_param(newBlock,'PortHandles');add_line(modelName,p.Outport(1),dst(1),'autorouting','on');
end

function disable_unused_duplicate_wheel_tags(modelName)
blocks={'Goto72','Goto73','Goto74','Goto75'};tags={'R_FL','R_FR','R_RL','R_RR'};
allFrom=find_system(modelName,'LookUnderMasks','all','FollowLinks','on','BlockType','From');
for k=1:4
    b=[modelName '/' blocks{k}];
    assert(getSimulinkBlockHandle(b)~=-1&&strcmp(get_param(b,'GotoTag'),tags{k}), ...
        'VX:V3B:DuplicateTagAudit');
    used=allFrom(cellfun(@(x)strcmp(get_param(x,'GotoTag'),tags{k}),allFrom));
    assert(isempty(used),'VX:V3B:DuplicateTagUsed');set_param(b,'Commented','on');
end
end

function write_text(file,value)
fid=fopen(file,'wb');assert(fid>=0,'VX:V3B:Write');c=onCleanup(@()fclose(fid));
fwrite(fid,unicode2native(value,'UTF-8'),'uint8');clear c
end
function hash=sha256_file(file)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));
q=java.security.DigestInputStream(s,d);c=onCleanup(@()q.close());while q.read()~=-1,end
hash=upper(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));clear c
end
function close_if_loaded(name)
if bdIsLoaded(name),close_system(name,0);end
end
