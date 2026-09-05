function R = run_vx_cs40_validation_v4()
%RUN_VX_CS40_VALIDATION_V4 Execute the one authorized corrected-state test.

root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
[simIn,cfg]=configure_vx_cs40_case_v4();
runtimeDir=fullfile(root,'results','vx_formal_validation','v4_cs40','runtime');
if ~isfolder(runtimeDir),mkdir(runtimeDir);end
rawFile=fullfile(runtimeDir,'VX_CS40_raw.mat');metadataFile=fullfile(runtimeDir,'VX_CS40_metadata.json');
consoleFile=fullfile(runtimeDir,'VX_CS40_runtime_console.log');commitFile=fullfile(runtimeDir,'VX_CS40_runtime_commit.txt');
assert(~isfile(rawFile)&&~isfile(metadataFile)&&~isfile(commitFile), ...
    'VX:V4:RuntimeExists','VX-CS40 was already committed; rerun is forbidden.');
solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');
solverLibrary=fullfile(sf,'Solver_SF.slx');solverDll=fullfile(solverDir,'carsim_64.dll');
assert(isfile(solverLibrary)&&isfile(solverDll),'VX:V4:CarSimSolverMissing');
addpath(solverDir);addpath(sf);oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);
c=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
load_system(solverLibrary);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);
verify_hashes(root,cfg);write_commit(commitFile,cfg);
clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
consoleText='';
try
    consoleText=evalc("simOut=sim(simIn);");
catch ME
    write_console(consoleFile,consoleText,ME);rethrow(ME)
end
names={'Vx_true_log','est_u_log','est_y_log'};logs=struct();
for k=1:numel(names)
    logs.(names{k})=simOut.get(names{k});assert(isa(logs.(names{k}),'timeseries'),'VX:V4:SignalType');
end
t=double(logs.est_y_log.Time(:));estY=orient_data(double(logs.est_y_log.Data),numel(t),38,'est_y_log');
u0=orient_data(double(logs.est_u_log.Data),numel(logs.est_u_log.Time),18,'est_u_log');
estU=interp1(double(logs.est_u_log.Time(:)),u0,t,'linear',NaN);
vxTrue=interp1(double(logs.Vx_true_log.Time(:)),double(logs.Vx_true_log.Data(:)),t,'linear',NaN);
firstFinite=find(isfinite(vxTrue),1,'first');assert(~isempty(firstFinite),'VX:V4:NoTruth');
actualInitialMps=vxTrue(firstFinite);actualInitialKmh=3.6*actualInitialMps;
initialGate=abs(actualInitialKmh-40)<=0.5;
kappa=(0.393.*estU(:,1:4)-vxTrue)./max(abs(vxTrue),1);
driveDur=[max_sustained(t,t>=3&t<7&kappa(:,3)>=0.10),max_sustained(t,t>=3&t<7&kappa(:,4)>=0.10)];
brakeDur=[max_sustained(t,t>=9&t<12&kappa(:,3)<=-0.10),max_sustained(t,t>=9&t<12&kappa(:,4)<=-0.10)];
driveGate=all(driveDur>=0.10-1e-9);brakeGate=all(brakeDur>=0.10-1e-9);
finiteEstimator=all(isfinite(estY(:,[1 3 5])),'all');
verify_hashes(root,cfg);
metadata=struct('stage','VX-V4-CS40','caseId','VX-CS40','simulationCompleted',true, ...
    'runtimeCountContribution',1,'initialSpeedToken',cfg.initialSpeedToken, ...
    'initialSpeedValue',cfg.initialSpeedValue,'initialSpeedUnit',cfg.initialSpeedUnit, ...
    'preRunInitialSpeedGatePass',cfg.preRunInitialSpeedGatePass, ...
    'preRunMuGatePass',cfg.preRunMuGatePass,'actualInitialVxMps',actualInitialMps, ...
    'actualInitialVxKmh',actualInitialKmh,'postRunInitialSpeedGatePass',initialGate, ...
    'driveRearSustainedDuration_s',driveDur,'driveGatePass',driveGate, ...
    'brakeRearSustainedDuration_s',brakeDur,'brakeGatePass',brakeGate, ...
    'finiteEstimatorOutput',finiteEstimator, ...
    'old72to40TransientDisappeared',initialGate, ...
    'oldV3bRawUnchanged',true,'oldV3bFreezeUnchanged',true, ...
    'estimatorUnchanged',true,'parametersUnchanged',true,'sourceVxSlxUnchanged',true, ...
    'verdict',verdict(initialGate,driveGate,brakeGate,finiteEstimator), ...
    'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
R=struct('metadata',metadata,'time',t,'vxTrue',vxTrue,'estU',estU,'estY',estY, ...
    'Ax',estU(:,9),'configuration',cfg);
save(rawFile,'R','-v7.3');write_json(metadataFile,metadata);write_console(consoleFile,consoleText,[]);
fprintf('VX_CS40_RESULT|initial=%.9g_mps|%.9g_kmh|drive=[%.6f %.6f]|brake=[%.6f %.6f]|verdict=%s\n', ...
    actualInitialMps,actualInitialKmh,driveDur,brakeDur,metadata.verdict);
if ~initialGate,error('VX:V4:InitialStateGate','VX_CS40_INITIAL_STATE_GATE_FAIL');end
if ~(driveGate&&brakeGate),error('VX:V4:PhysicalGate','VX_CS40_PHYSICAL_GATE_CHANGED_AFTER_INITIAL_STATE_FIX');end
assert(finiteEstimator,'VX:V4:EstimatorFinite','Estimator output is non-finite.');
clear c;cleanup_runtime(modelName,oldPwd,oldPath);
end

function verify_hashes(root,cfg)
source=struct('model',fullfile(root,'model','vx.slx'), ...
    'estimator',fullfile(root,'model','longitudinal_velocity_estimator.m'), ...
    'parameter',fullfile(root,'model','estimator_default_params.m'), ...
    'wrapper',fullfile(root,'model','longitudinal_velocity_estimator_simulink.m'));
n=fieldnames(source);for k=1:numel(n),assert(strcmp(sha256_file(source.(n{k})),cfg.frozenSourceHashes.(n{k})),'VX:V4:SourceHash');end
assert(strcmp(sha256_file(cfg.generatedModel),cfg.generatedHashes.model)&& ...
    strcmp(sha256_file(cfg.runAll),cfg.generatedHashes.runAll)&& ...
    strcmp(sha256_file(cfg.simfile),cfg.generatedHashes.simfile)&& ...
    strcmp(sha256_file(cfg.controlManifestFile),cfg.generatedHashes.manifest),'VX:V4:GeneratedHash');
assert(strcmp(sha256_file(cfg.oldEvidence.v3bRawFile),cfg.oldEvidence.v3bRawSha256)&& ...
    strcmp(sha256_file(cfg.oldEvidence.v3bFreezeFile),cfg.oldEvidence.v3bFreezeSha256),'VX:V4:OldEvidenceHash');
end
function X=orient_data(X,n,w,name)
X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end
assert(size(X,1)==n&&size(X,2)==w,'VX:V4:SignalShape','%s must be N-by-%d.',name,w);
end
function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end;b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end,end
end
function out=verdict(initial,drive,brake,finite)
if ~initial,out='VX_CS40_INITIAL_STATE_GATE_FAIL';elseif ~(drive&&brake),out='VX_CS40_PHYSICAL_GATE_CHANGED_AFTER_INITIAL_STATE_FIX';elseif ~finite,out='VX_CS40_ESTIMATOR_NONFINITE';else,out='VX_CS40_CORRECTED_INITIAL_STATE_TEST_PASS';end
end
function write_commit(file,cfg)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4:CommitWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'STAGE=VX-V4-CS40\nCASE=VX-CS40\nSIM_INVOCATION_COMMITTED=YES\nRUNTIME_COUNT_CONTRIBUTION=1\n');
fprintf(fid,'INITIAL_SPEED_TOKEN=%s\nINITIAL_SPEED_VALUE=%.17g\nINITIAL_SPEED_UNIT=%s\n',cfg.initialSpeedToken,cfg.initialSpeedValue,cfg.initialSpeedUnit);clear c
end
function write_console(file,text,failure)
if numel(text)>20000,text=text(end-19999:end);end;fid=fopen(file,'wt');assert(fid>=0,'VX:V4:ConsoleWrite');
c=onCleanup(@()fclose(fid));fwrite(fid,text);if ~isempty(failure),fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message);end;clear c
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4:JsonWrite');c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
end
function hash=sha256_file(file)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));
q=java.security.DigestInputStream(s,d);c=onCleanup(@()q.close());while q.read()~=-1,end
hash=upper(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));clear c
end
function cleanup_runtime(modelName,oldPwd,oldPath)
if bdIsLoaded(modelName),close_system(modelName,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
cd(oldPwd);path(oldPath);
end
