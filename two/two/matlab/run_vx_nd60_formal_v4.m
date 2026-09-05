function R = run_vx_nd60_formal_v4()
%RUN_VX_ND60_FORMAL_V4 Execute the only authorized ND60 formal runtime.

root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
[simIn,cfg]=configure_vx_nd60_formal_v4();stageRoot=fullfile(root,'results','vx_formal_validation','v4_nd60_formal');
runtimeDir=fullfile(stageRoot,'runtime');if ~isfolder(runtimeDir),mkdir(runtimeDir);end
rawFile=fullfile(runtimeDir,'VX_ND60_formal_raw.mat');metadataFile=fullfile(runtimeDir,'VX_ND60_metadata.json');
commitFile=fullfile(runtimeDir,'VX_ND60_runtime_commit.txt');consoleFile=fullfile(runtimeDir,'VX_ND60_runtime_console.log');
assert(~isfile(rawFile)&&~isfile(metadataFile)&&~isfile(commitFile),'VX:ND60:RuntimeExists','ND60 formal runtime is already committed; rerun forbidden.');
protected=capture_protected(root);write_json(fullfile(stageRoot,'protected_evidence_snapshot.json'),protected);
solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');solverLibrary=fullfile(sf,'Solver_SF.slx');solverDll=fullfile(solverDir,'carsim_64.dll');
assert(isfile(solverLibrary)&&isfile(solverDll),'VX:ND60:CarSimSolverMissing');addpath(solverDir);addpath(sf);oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);c=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
load_system(solverLibrary);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);verify_hashes(cfg);write_commit(commitFile,cfg);
clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
consoleText='';try,consoleText=evalc("simOut=sim(simIn);");catch ME,write_console(consoleFile,consoleText,ME);rethrow(ME),end
names={'Vx_true_log','est_u_log','est_y_log'};logs=struct();for k=1:numel(names),logs.(names{k})=simOut.get(names{k});assert(isa(logs.(names{k}),'timeseries'),'VX:ND60:SignalType');end
t=double(logs.est_y_log.Time(:));estY=orient_data(double(logs.est_y_log.Data),numel(t),38,'est_y_log');u0=orient_data(double(logs.est_u_log.Data),numel(logs.est_u_log.Time),18,'est_u_log');
estU=interp1(double(logs.est_u_log.Time(:)),u0,t,'linear',NaN);vxTrue=interp1(double(logs.Vx_true_log.Time(:)),double(logs.Vx_true_log.Data(:)),t,'linear',NaN);
firstFinite=find(isfinite(vxTrue),1,'first');assert(~isempty(firstFinite),'VX:ND60:NoTruth');actualInitialMps=vxTrue(firstFinite);actualInitialKmh=3.6*actualInitialMps;initialGate=abs(actualInitialKmh-60)<=0.5;
finiteFusion=all(isfinite(estY(:,1)));finiteWss=all(isfinite(estY(:,3)));finiteImu=all(isfinite(estY(:,5)));estimatorFinite=finiteFusion&&finiteWss&&finiteImu;
if initialGate&&estimatorFinite,formalVerdict='VX_ND60_FORMAL_PASS';elseif ~initialGate,formalVerdict='VX_ND60_INITIAL_STATE_GATE_FAIL';else,formalVerdict='VX_ND60_ESTIMATOR_FINITE_GATE_FAIL';end
verify_hashes(cfg);verify_protected(protected);metadata=struct('stage','VX-V4-ND60-FORMAL','caseId','VX-ND60','formalRuntime',true,'formalRuntimeCountContribution',1, ...
    'simulationCompleted',true,'actualInitialVxMps',actualInitialMps,'actualInitialVxKmh',actualInitialKmh,'initialStateGatePass',initialGate, ...
    'fusionFinite',finiteFusion,'adaptiveWssFinite',finiteWss,'imuFinite',finiteImu,'estimatorFiniteGatePass',estimatorFinite, ...
    'old72to60TransientDisappeared',initialGate,'oldEvidenceUnchanged',true,'sourceEstimatorParametersUnchanged',true, ...
    'verdict',formalVerdict,'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
R=struct('time',t,'vxTrue',vxTrue,'estU',estU,'estY',estY,'Ax',estU(:,9),'configuration',cfg,'metadata',metadata);save(rawFile,'R','-v7.3');write_json(metadataFile,metadata);write_console(consoleFile,consoleText,[]);
fprintf('VX_ND60_FORMAL|initial=%.12g_mps|%.12g_kmh|finite=%d|%s\n',actualInitialMps,actualInitialKmh,estimatorFinite,formalVerdict);assert(strcmp(formalVerdict,'VX_ND60_FORMAL_PASS'),'VX:ND60:FormalGate',formalVerdict);clear c;cleanup_runtime(modelName,oldPwd,oldPath);
end

function verify_hashes(cfg)
n=fieldnames(cfg.sourceFiles);for k=1:numel(n),assert(strcmp(sha256_file(cfg.sourceFiles.(n{k})),cfg.sourceHashes.(n{k})),'VX:ND60:SourceHash');end
assert(strcmp(sha256_file(cfg.generatedModel),cfg.generatedModelHash)&&strcmp(sha256_file(cfg.runAll),cfg.controlHashes.runAll)&&strcmp(sha256_file(cfg.simfile),cfg.controlHashes.simfile)&&strcmp(sha256_file(cfg.controlManifestFile),cfg.controlHashes.manifest),'VX:ND60:LineageHash');
end
function p=capture_protected(root)
files=struct('v3Raw',fullfile(root,'results','vx_formal_validation','v3','runtime','VX_ND_formal_raw.mat'),'v3bRaw',fullfile(root,'results','vx_formal_validation','v3b','runtime','VX_CS_formal_raw.mat'),'v4Raw',fullfile(root,'results','vx_formal_validation','v4_cs40','runtime','VX_CS40_raw.mat'),'v4bFreeze',fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration','frozen_physical_excitation.json'),'v4cRaw',fullfile(root,'results','vx_formal_validation','v4c_cs40_formal','runtime','VX_CS40_formal_raw.mat'),'v4cDerived',fullfile(root,'results','vx_formal_validation','v4c_cs40_formal','VX_CS40_traditional_wss.mat'));
n=fieldnames(files);hashes=struct();for k=1:numel(n),assert(isfile(files.(n{k})),'VX:ND60:ProtectedMissing');hashes.(n{k})=sha256_file(files.(n{k}));end;p=struct('files',files,'sha256',hashes,'capturedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
function verify_protected(p),n=fieldnames(p.files);for k=1:numel(n),assert(strcmp(sha256_file(p.files.(n{k})),p.sha256.(n{k})),'VX:ND60:ProtectedChanged');end,end
function X=orient_data(X,n,w,name),X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end;assert(size(X,1)==n&&size(X,2)==w,'VX:ND60:SignalShape','%s must be N-by-%d.',name,w);end
function write_commit(file,cfg),fid=fopen(file,'wt');assert(fid>=0,'VX:ND60:CommitWrite');c=onCleanup(@()fclose(fid));fprintf(fid,'STAGE=VX-V4-ND60-FORMAL\nCASE=VX-ND60\nFORMAL_RUNTIME_COMMITTED=YES\nFORMAL_RUNTIME_COUNT_CONTRIBUTION=1\nSV_VXS_KMH=%.17g\nMU_ROAD_CONSTANT=%.17g\n',cfg.initialSpeedValue,cfg.muRoadConstant);clear c,end
function write_console(file,text,failure),if numel(text)>20000,text=text(end-19999:end);end;fid=fopen(file,'wt');assert(fid>=0,'VX:ND60:ConsoleWrite');c=onCleanup(@()fclose(fid));fwrite(fid,text);if ~isempty(failure),fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message);end;clear c,end
function write_json(file,value),fid=fopen(file,'wt');assert(fid>=0,'VX:ND60:JsonWrite');c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c,end
function hash=sha256_file(file),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));q=java.security.DigestInputStream(s,d);c=onCleanup(@()q.close());while q.read()~=-1,end;hash=upper(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));clear c,end
function cleanup_runtime(modelName,oldPwd,oldPath),if bdIsLoaded(modelName),close_system(modelName,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(oldPwd);path(oldPath);end
