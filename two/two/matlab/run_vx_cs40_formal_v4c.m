function R = run_vx_cs40_formal_v4c()
%RUN_VX_CS40_FORMAL_V4C Execute exactly one estimator formal runtime.

root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
[simIn,cfg]=configure_vx_cs40_formal_v4c();
stageRoot=fullfile(root,'results','vx_formal_validation','v4c_cs40_formal');
runtimeDir=fullfile(stageRoot,'runtime');
if ~isfolder(runtimeDir),mkdir(runtimeDir);end
rawFile=fullfile(runtimeDir,'VX_CS40_formal_raw.mat');
metadataFile=fullfile(runtimeDir,'VX_CS40_metadata.json');
commitFile=fullfile(runtimeDir,'VX_CS40_runtime_commit.txt');
consoleFile=fullfile(runtimeDir,'VX_CS40_runtime_console.log');
assert(~isfile(rawFile)&&~isfile(commitFile)&&~isfile(metadataFile), ...
    'VX:V4C:RuntimeExists','V4C formal runtime is already committed; rerun is forbidden.');
protected=capture_protected_evidence(root);
write_json(fullfile(stageRoot,'protected_evidence_snapshot.json'),protected);
solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');
solverLibrary=fullfile(sf,'Solver_SF.slx');solverDll=fullfile(solverDir,'carsim_64.dll');
assert(isfile(solverLibrary)&&isfile(solverDll),'VX:V4C:CarSimSolverMissing');
addpath(solverDir);addpath(sf);oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);
c=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
load_system(solverLibrary);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);
verify_hashes(cfg);write_commit(commitFile,cfg);
clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
consoleText='';
try
    consoleText=evalc("simOut=sim(simIn);");
catch ME
    write_console(consoleFile,consoleText,ME);rethrow(ME)
end
names={'Vx_true_log','est_u_log','est_y_log'};logs=struct();
for k=1:numel(names)
    logs.(names{k})=simOut.get(names{k});assert(isa(logs.(names{k}),'timeseries'),'VX:V4C:SignalType');
end
t=double(logs.est_y_log.Time(:));
estY=orient_data(double(logs.est_y_log.Data),numel(t),38,'est_y_log');
u0=orient_data(double(logs.est_u_log.Data),numel(logs.est_u_log.Time),18,'est_u_log');
estU=interp1(double(logs.est_u_log.Time(:)),u0,t,'linear',NaN);
vxTrue=interp1(double(logs.Vx_true_log.Time(:)),double(logs.Vx_true_log.Data(:)),t,'linear',NaN);
firstFinite=find(isfinite(vxTrue),1,'first');assert(~isempty(firstFinite),'VX:V4C:NoTruth');
actualInitialMps=vxTrue(firstFinite);actualInitialKmh=3.6*actualInitialMps;
initialGate=abs(actualInitialKmh-40)<=0.5;
kappa=(0.393.*estU(:,1:4)-vxTrue)./max(abs(vxTrue),1);
driveDur=[max_sustained(t,t>=3&t<7&kappa(:,3)>=0.10),max_sustained(t,t>=3&t<7&kappa(:,4)>=0.10)];
brakeDur=[max_sustained(t,t>=9&t<12&kappa(:,3)<=-0.10),max_sustained(t,t>=9&t<12&kappa(:,4)<=-0.10)];
driveGate=all(driveDur>=0.10-1e-9);brakeGate=all(brakeDur>=0.10-1e-9);
finiteFusion=all(isfinite(estY(:,1)));finiteWss=all(isfinite(estY(:,3)));finiteImu=all(isfinite(estY(:,5)));
estimatorFinite=finiteFusion&&finiteWss&&finiteImu;
verify_protected_evidence(protected);
if initialGate&&driveGate&&brakeGate&&estimatorFinite
    formalVerdict='VX_CS40_V4C_FORMAL_PASS';
elseif ~initialGate,formalVerdict='VX_CS40_V4C_INITIAL_STATE_GATE_FAIL';
elseif ~driveGate,formalVerdict='VX_CS40_V4C_DRIVE_GATE_FAIL';
elseif ~brakeGate,formalVerdict='VX_CS40_V4C_BRAKE_GATE_FAIL';
else,formalVerdict='VX_CS40_V4C_ESTIMATOR_FINITE_GATE_FAIL';end
verify_hashes(cfg);
metadata=struct('stage','VX-V4C-CS40-FORMAL','caseId','VX-CS40','formalRuntime',true, ...
    'formalRuntimeCountContribution',1,'selectedFrozenCandidate','A1', ...
    'simulationCompleted',true,'actualInitialVxMps',actualInitialMps, ...
    'actualInitialVxKmh',actualInitialKmh,'initialStateGatePass',initialGate, ...
    'driveRearSustainedDuration_s',driveDur,'driveGatePass',driveGate, ...
    'brakeRearSustainedDuration_s',brakeDur,'brakeGatePass',brakeGate, ...
    'fusionFinite',finiteFusion,'adaptiveWssFinite',finiteWss,'imuFinite',finiteImu, ...
    'estimatorFiniteGatePass',estimatorFinite,'verdict',formalVerdict, ...
    'calibrationRuntimeUsedAsPerformanceEvidence',false, ...
    'oldEvidenceUnchanged',true,'sourceEstimatorParametersUnchanged',true, ...
    'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
R=struct('time',t,'vxTrue',vxTrue,'estU',estU,'estY',estY,'Ax',estU(:,9), ...
    'configuration',cfg,'metadata',metadata);
save(rawFile,'R','-v7.3');write_json(metadataFile,metadata);write_console(consoleFile,consoleText,[]);
fprintf('VX_V4C_FORMAL|initial=%.9g_kmh|drive=[%.6f %.6f]|brake=[%.6f %.6f]|%s\n', ...
    actualInitialKmh,driveDur,brakeDur,formalVerdict);
assert(strcmp(formalVerdict,'VX_CS40_V4C_FORMAL_PASS'),'VX:V4C:FormalGate',formalVerdict);
clear c;cleanup_runtime(modelName,oldPwd,oldPath);
end

function verify_hashes(cfg)
n=fieldnames(cfg.sourceFiles);for k=1:numel(n),assert(strcmp(sha256_file(cfg.sourceFiles.(n{k})),cfg.sourceHashes.(n{k})),'VX:V4C:SourceHash');end
assert(strcmp(sha256_file(cfg.generatedModel),cfg.generatedModelHash)&& ...
    strcmp(sha256_file(cfg.runAll),cfg.controlHashes.runAll)&& ...
    strcmp(sha256_file(cfg.simfile),cfg.controlHashes.simfile)&& ...
    strcmp(sha256_file(cfg.controlManifestFile),cfg.controlHashes.manifest)&& ...
    strcmp(sha256_file(cfg.freezeFile),cfg.freezeFileSha256)&& ...
    strcmp(sha256_file(cfg.v4bCaseConfigurationFile),cfg.v4bCaseConfigurationSha256), ...
    'VX:V4C:LineageHash');
end
function p=capture_protected_evidence(root)
files=struct( ...
    'v3bRaw',fullfile(root,'results','vx_formal_validation','v3b','runtime','VX_CS_formal_raw.mat'), ...
    'v3bFreeze',fullfile(root,'results','vx_formal_validation','v3b','frozen_physical_excitation.json'), ...
    'v4Raw',fullfile(root,'results','vx_formal_validation','v4_cs40','runtime','VX_CS40_raw.mat'), ...
    'v4bFreeze',fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration','frozen_physical_excitation.json'), ...
    'v4bSummary',fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration','calibration_summary.json'), ...
    'v4bGate',fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration','calibration','A1','A1_physical_gate.json'), ...
    'v4bPhysical',fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration','calibration','A1','A1_physical_only.mat'), ...
    'v4bStatus',fullfile(root,'docs','STAGE_VX_V4B_CS40_DRIVE_CALIBRATION_STATUS.md'));
n=fieldnames(files);hashes=struct();for k=1:numel(n),assert(isfile(files.(n{k})),'VX:V4C:ProtectedMissing');hashes.(n{k})=sha256_file(files.(n{k}));end
p=struct('files',files,'sha256',hashes,'capturedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
function verify_protected_evidence(p)
n=fieldnames(p.files);for k=1:numel(n),assert(strcmp(sha256_file(p.files.(n{k})),p.sha256.(n{k})),'VX:V4C:ProtectedChanged');end
end
function X=orient_data(X,n,w,name)
X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end
assert(size(X,1)==n&&size(X,2)==w,'VX:V4C:SignalShape','%s must be N-by-%d.',name,w);
end
function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end;b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end,end
end
function write_commit(file,cfg)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4C:CommitWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'STAGE=VX-V4C-CS40-FORMAL\nCASE=VX-CS40\nFORMAL_RUNTIME_COMMITTED=YES\n');
fprintf(fid,'FORMAL_RUNTIME_COUNT_CONTRIBUTION=1\nSELECTED_FROZEN_CANDIDATE=%s\n',cfg.selectedCandidate);
fprintf(fid,'FREEZE_SHA256=%s\nGENERATED_MODEL_SHA256=%s\n',cfg.freezeFileSha256,cfg.generatedModelHash);clear c
end
function write_console(file,text,failure)
if numel(text)>20000,text=text(end-19999:end);end;fid=fopen(file,'wt');assert(fid>=0,'VX:V4C:ConsoleWrite');
c=onCleanup(@()fclose(fid));fwrite(fid,text);if ~isempty(failure),fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message);end;clear c
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4C:JsonWrite');c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
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
