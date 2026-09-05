function R = run_vx_formal_validation_v3b(caseId)
%RUN_VX_FORMAL_VALIDATION_V3B Execute the one authorized fresh VX-CS run.

arguments
    caseId (1,1) string = "VX-CS"
end
caseId=upper(strrep(strtrim(caseId),'_','-'));
assert(caseId=="VX-CS",'VX:V3B:Case','Only VX-CS is supported.');
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
[simIn,cfg]=configure_vx_formal_case_v3b(caseId);
runtimeDir=fullfile(root,'results','vx_formal_validation','v3b','runtime');
if ~isfolder(runtimeDir),mkdir(runtimeDir);end
rawFile=fullfile(runtimeDir,'VX_CS_formal_raw.mat');
metadataFile=fullfile(runtimeDir,'VX_CS_metadata.json');
commitFile=fullfile(runtimeDir,'VX_CS_runtime_commit.txt');
consoleFile=fullfile(runtimeDir,'VX_CS_runtime_console.log');
assert(~isfile(rawFile)&&~isfile(commitFile),'VX:V3B:RuntimeExists', ...
    'VX-CS has already been committed; formal rerun is forbidden.');

solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');
solverLibrary=fullfile(sf,'Solver_SF.slx');solverDll=fullfile(solverDir,'carsim_64.dll');
assert(isfile(solverLibrary)&&isfile(solverDll),'VX:V3B:CarSimSolverMissing');
addpath(solverDir);addpath(sf);oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);
c=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
load_system(solverLibrary);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);
verify_hashes(root,cfg);
provenance=struct('stage','VX-V3B','caseId','VX-CS','formalRuntime',true, ...
    'simInvocationCommitted',true,'formalRuntimeCountContribution',1, ...
    'commitTimeLocal',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')), ...
    'freezeFileSha256',cfg.freezeFileSha256,'selectedTier',cfg.selectedTier, ...
    'selectedCandidate',cfg.selectedCandidate,'profile',cfg.speedReference, ...
    'sourceHashes',cfg.sourceHashes,'generatedHashes',cfg.generatedHashes);
write_commit(commitFile,provenance);

clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
consoleText='';
try
    consoleText=evalc("simOut=sim(simIn);");
catch ME
    write_console(consoleFile,consoleText,ME);rethrow(ME)
end
names={'Vx_true_log','est_u_log','est_y_log'};logs=struct();
for k=1:numel(names)
    logs.(names{k})=simOut.get(names{k});
    assert(isa(logs.(names{k}),'timeseries'),'VX:V3B:SignalType');
end
t=double(logs.est_y_log.Time(:));
estY=orient_data(double(logs.est_y_log.Data),numel(t),38,'est_y_log');
u0=orient_data(double(logs.est_u_log.Data),numel(logs.est_u_log.Time),18,'est_u_log');
estU=interp1(double(logs.est_u_log.Time(:)),u0,t,'linear',NaN);
vxTrue=interp1(double(logs.Vx_true_log.Time(:)),double(logs.Vx_true_log.Data(:)),t,'linear',NaN);
assert(t(end)>=15.999&&all(isfinite(vxTrue)),'VX:V3B:Incomplete');
verify_hashes(root,cfg);
R=struct();R.metadata=struct('stage','VX-V3B','caseId','VX-CS', ...
    'formalRuntime',true,'formalRuntimeCountContribution',1, ...
    'simulationCompleted',true,'simInvocationCommitted',true, ...
    'freezeFileSha256',cfg.freezeFileSha256,'sourceHashes',cfg.sourceHashes, ...
    'generatedHashes',cfg.generatedHashes, ...
    'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
R.time=t;R.vxTrue=vxTrue;R.estU=estU;R.estY=estY;R.Ax=estU(:,9);
R.steerCommand=zeros(size(t));R.configuration=cfg;
save(rawFile,'R','-v7.3');write_json(metadataFile,R.metadata);write_console(consoleFile,consoleText,[]);
A=analyze_vx_formal_validation_v3b('VX-CS'); %#ok<NASGU>
clear c;cleanup_runtime(modelName,oldPwd,oldPath);
end

function verify_hashes(root,cfg)
source=struct('model',fullfile(root,'model','vx.slx'), ...
    'estimator',fullfile(root,'model','longitudinal_velocity_estimator.m'), ...
    'parameter',fullfile(root,'model','estimator_default_params.m'), ...
    'wrapper',fullfile(root,'model','longitudinal_velocity_estimator_simulink.m'));
n=fieldnames(source);for k=1:numel(n),assert(strcmp(sha256_file(source.(n{k})),cfg.sourceHashes.(n{k})),'VX:V3B:SourceHash');end
assert(strcmp(sha256_file(cfg.generatedModel),cfg.generatedHashes.model)&& ...
    strcmp(sha256_file(cfg.simfile),cfg.generatedHashes.simfile)&& ...
    strcmp(sha256_file(cfg.runAll),cfg.generatedHashes.runAll)&& ...
    strcmp(sha256_file(cfg.freezeFile),cfg.freezeFileSha256),'VX:V3B:FrozenHash');
end
function X=orient_data(X,n,w,name)
X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end
assert(size(X,1)==n&&size(X,2)==w,'VX:V3B:SignalShape','%s must be N-by-%d.',name,w);
end
function write_commit(file,p)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:CommitWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'STAGE=VX-V3B\nCASE=VX-CS\nSIM_INVOCATION_COMMITTED=YES\n');
fprintf(fid,'FORMAL_RUNTIME_COUNT_CONTRIBUTION=1\nTIME_LOCAL=%s\n',p.commitTimeLocal);
fprintf(fid,'FREEZE_FILE_SHA256=%s\nSELECTED_TIER=%s\nSELECTED_CANDIDATE=%s\n', ...
    p.freezeFileSha256,p.selectedTier,p.selectedCandidate);clear c
end
function write_console(file,text,failure)
if numel(text)>20000,text=text(end-19999:end);end
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:ConsoleWrite');c=onCleanup(@()fclose(fid));fwrite(fid,text);
if ~isempty(failure),fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message);end;clear c
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:JsonWrite');c=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
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
