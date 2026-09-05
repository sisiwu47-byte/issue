function summary = run_vx_cs40_drive_calibration_v4b()
%RUN_VX_CS40_DRIVE_CALIBRATION_V4B Run preregistered physical-only sequence.
% Selection reads only completion, Vx truth, rear omega, physical kappa and gates.

root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
stageRoot=fullfile(root,'results','vx_formal_validation','v4b_cs40_drive_calibration');
if ~isfolder(stageRoot),mkdir(stageRoot);end
freezeFile=fullfile(stageRoot,'frozen_physical_excitation.json');
summaryFile=fullfile(stageRoot,'calibration_summary.json');
assert(~isfile(freezeFile)&&~isfile(summaryFile),'VX:V4B:StageCommitted', ...
    'V4B calibration has already been committed; rerun is forbidden.');
candidates={'A1','A2','A3'}; records=cell(1,3); selected='NONE'; runtimeCount=0;
for j=1:numel(candidates)
    id=candidates{j}; [simIn,cfg]=configure_vx_cs40_drive_calibration_v4b(id);
    candidateDir=fullfile(stageRoot,'calibration',id);if ~isfolder(candidateDir),mkdir(candidateDir);end
    physicalFile=fullfile(candidateDir,[id '_physical_only.mat']);
    gateFile=fullfile(candidateDir,[id '_physical_gate.json']);
    commitFile=fullfile(candidateDir,[id '_runtime_commit.txt']);
    consoleFile=fullfile(candidateDir,[id '_runtime_console.log']);
    assert(~isfile(physicalFile)&&~isfile(gateFile)&&~isfile(commitFile), ...
        'VX:V4B:CandidateExists','Candidate %s was already executed.',id);
    assert(cfg.preRunInitialSpeedGatePass&&cfg.preRunMuGatePass,'VX:V4B:PreRunGate');
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');
    solverLibrary=fullfile(sf,'Solver_SF.slx');solverDll=fullfile(solverDir,'carsim_64.dll');
    assert(isfile(solverLibrary)&&isfile(solverDll),'VX:V4B:CarSimSolverMissing');
    addpath(solverDir);addpath(sf);oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);
    cleanup=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
    load_system(solverLibrary);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);
    verify_hashes(root,cfg);write_commit(commitFile,cfg);runtimeCount=runtimeCount+1;
    consoleText='';
    try
        consoleText=evalc("simOut=sim(simIn);");
    catch ME
        write_console(consoleFile,consoleText,ME);
        rec=base_record(cfg,runtimeCount);rec.simulationCompleted=false;rec.failureIdentifier=ME.identifier;
        rec.failureMessage=ME.message;rec.verdict='NUMERICAL_COMPLETION_FAIL';records{j}=rec;
        write_json(gateFile,rec);summary=finish_summary(stageRoot,records,candidates,runtimeCount,selected,rec.verdict);
        rethrow(ME)
    end
    vxLog=simOut.get('Vx_true_log');uLog=simOut.get('est_u_log');
    assert(isa(vxLog,'timeseries')&&isa(uLog,'timeseries'),'VX:V4B:SignalType');
    t=double(vxLog.Time(:));vxTrue=double(vxLog.Data(:));
    u0=orient_data(double(uLog.Data),numel(uLog.Time),18,'est_u_log');
    omega=interp1(double(uLog.Time(:)),u0(:,1:4),t,'linear',NaN);
    firstFinite=find(isfinite(vxTrue),1,'first');assert(~isempty(firstFinite),'VX:V4B:NoTruth');
    actualInitialMps=vxTrue(firstFinite);actualInitialKmh=3.6*actualInitialMps;
    initialGate=abs(actualInitialKmh-40)<=0.5;
    kappa=(0.393.*omega-vxTrue)./max(abs(vxTrue),1);
    driveDur=[max_sustained(t,t>=3&t<7&kappa(:,3)>=0.10),max_sustained(t,t>=3&t<7&kappa(:,4)>=0.10)];
    brakeDur=[max_sustained(t,t>=9&t<12&kappa(:,3)<=-0.10),max_sustained(t,t>=9&t<12&kappa(:,4)<=-0.10)];
    driveGate=all(driveDur>=0.10-1e-9);brakeGate=all(brakeDur>=0.10-1e-9);
    verify_hashes(root,cfg);
    rec=base_record(cfg,runtimeCount);rec.simulationCompleted=true;
    rec.actualInitialVxMps=actualInitialMps;rec.actualInitialVxKmh=actualInitialKmh;
    rec.initialStateGatePass=initialGate;rec.driveRearSustainedDuration_s=driveDur;
    rec.driveGatePass=driveGate;rec.brakeRearSustainedDuration_s=brakeDur;
    rec.brakeGatePass=brakeGate;rec.combinedPhysicalPass=initialGate&&driveGate&&brakeGate;
    if ~initialGate,rec.verdict='INITIAL_STATE_GATE_FAIL';
    elseif rec.combinedPhysicalPass,rec.verdict='COMBINED_PHYSICAL_PASS';
    else,rec.verdict='PHYSICAL_GATE_FAIL';end
    physical=struct('stage',rec.stage,'candidateId',id,'time_s',t,'vxTrue_mps',vxTrue, ...
        'rearWheelOmega_radps',omega(:,3:4),'rearKappa',kappa(:,3:4), ...
        'speedTime_s',cfg.speedTime_s,'speed_kmh',cfg.speed_kmh,'steeringRad',0, ...
        'initialSpeed_kmh',40,'muRoadConstant',0.30,'physicalGate',rec);
    save(physicalFile,'physical','-v7.3');write_json(gateFile,rec);write_console(consoleFile,consoleText,[]);
    records{j}=rec;
    fprintf('VX_V4B_CANDIDATE|%s|initial=%.9g_kmh|drive=[%.6f %.6f]|brake=[%.6f %.6f]|%s\n', ...
        id,actualInitialKmh,driveDur,brakeDur,rec.verdict);
    clear cleanup;cleanup_runtime(modelName,oldPwd,oldPath);
    if ~initialGate
        summary=finish_summary(stageRoot,records,candidates,runtimeCount,selected,'INITIAL_STATE_GATE_FAIL');
        error('VX:V4B:InitialStateGate','Candidate %s initial-state gate failed.',id);
    end
    if rec.combinedPhysicalPass
        selected=id;freeze=make_freeze(cfg,rec,physicalFile,gateFile);
        write_json(freezeFile,freeze);
        summary=finish_summary(stageRoot,records,candidates,runtimeCount,selected, ...
            'VX_CS40_V4B_PHYSICAL_EXCITATION_FREEZE_PASS');
        write_status(root,summary,freezeFile);return
    end
end
summary=finish_summary(stageRoot,records,candidates,runtimeCount,selected, ...
    'VX_CS40_V4B_REFERENCE_ONLY_ACCELERATION_CALIBRATION_FAIL');
write_status(root,summary,'NOT_CREATED');
end

function rec=base_record(cfg,count)
rec=struct('stage','VX-V4B-CS40-DRIVE-CALIBRATION','candidateId',cfg.candidateId, ...
    'runtimeOrdinal',count,'physicalOnlyCalibration',true,'selectionUsedEstimatorMetrics',false, ...
    'speedTime_s',cfg.speedTime_s,'speed_kmh',cfg.speed_kmh,'initialSpeedToken','SV_VXS', ...
    'initialSpeed_kmh',40,'muRoadConstant',0.30,'steeringRad',0,'brakeProfileUnchanged',true, ...
    'rearTorqueOverrideUsed',false,'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
function freeze=make_freeze(cfg,rec,physicalFile,gateFile)
freeze=struct('stage',rec.stage,'verdict','VX_CS40_V4B_PHYSICAL_EXCITATION_FREEZE_PASS', ...
    'selectedCandidate',rec.candidateId,'speedTime_s',cfg.speedTime_s,'speed_kmh',cfg.speed_kmh, ...
    'initialSpeed_kmh',40,'actualInitialVxMps',rec.actualInitialVxMps, ...
    'actualInitialVxKmh',rec.actualInitialVxKmh,'muRoadConstant',0.30,'steeringRad',0, ...
    'driveRearSustainedDuration_s',rec.driveRearSustainedDuration_s, ...
    'brakeRearSustainedDuration_s',rec.brakeRearSustainedDuration_s, ...
    'initialStateGatePass',rec.initialStateGatePass,'driveGatePass',rec.driveGatePass, ...
    'brakeGatePass',rec.brakeGatePass,'controlHashes',cfg.controlHashes, ...
    'sourceHashes',cfg.frozenSourceHashes,'generatedModelHash',cfg.generatedModelHash, ...
    'physicalEvidenceFile',physicalFile,'physicalGateFile',gateFile, ...
    'physicalEvidenceSha256',sha256_file(physicalFile),'physicalGateSha256',sha256_file(gateFile), ...
    'formalEstimatorValidationRun',false,'frozenAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
function summary=finish_summary(stageRoot,records,candidates,count,selected,verdict)
executed=false(1,numel(candidates));compact=cell(1,count);q=0;
for k=1:numel(records),if ~isempty(records{k}),executed(k)=true;q=q+1;compact{q}=records{k};end,end
summary=struct('stage','VX-V4B-CS40-DRIVE-CALIBRATION','calibrationRuntimeCount',count, ...
    'candidateOrder',{candidates},'candidateExecuted',executed,'selectedCandidate',selected, ...
    'records',{compact},'formalEstimatorValidationRuntimeCount',0,'verdict',verdict, ...
    'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
write_json(fullfile(stageRoot,'calibration_summary.json'),summary);
end
function write_status(root,summary,freezePath)
file=fullfile(root,'docs','STAGE_VX_V4B_CS40_DRIVE_CALIBRATION_STATUS.md');
fid=fopen(file,'wt');assert(fid>=0,'VX:V4B:StatusWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'# VX-V4B CS40 drive calibration status\n\n');
fprintf(fid,'- Classification: PHYSICAL-ONLY CALIBRATION\n- Verdict: `%s`\n',summary.verdict);
fprintf(fid,'- Calibration runtime count: %d\n- Formal estimator validation runtime count: 0\n',summary.calibrationRuntimeCount);
fprintf(fid,'- Candidate order: A1 -> A2 -> A3; first combined physical PASS stops the sequence.\n');
fprintf(fid,'- Executed: A1=%s, A2=%s, A3=%s\n',yn(summary.candidateExecuted(1)),yn(summary.candidateExecuted(2)),yn(summary.candidateExecuted(3)));
fprintf(fid,'- Selected candidate: `%s`\n- Freeze: `%s`\n',summary.selectedCandidate,freezePath);
fprintf(fid,'- Candidate selection used only completion, CarSim Vx, rear omega, kappa and physical gates.\n');
fprintf(fid,'- Frozen estimator, parameters, source vx.slx, initial speed, mu, steering and brake segment were not changed.\n');clear c
end
function s=yn(v),if v,s='EXECUTED';else,s='NOT_EXECUTED';end,end
function verify_hashes(root,cfg)
source=struct('model',fullfile(root,'model','vx.slx'), ...
    'estimator',fullfile(root,'model','longitudinal_velocity_estimator.m'), ...
    'parameter',fullfile(root,'model','estimator_default_params.m'), ...
    'wrapper',fullfile(root,'model','longitudinal_velocity_estimator_simulink.m'));
n=fieldnames(source);for k=1:numel(n),assert(strcmp(sha256_file(source.(n{k})),cfg.frozenSourceHashes.(n{k})),'VX:V4B:SourceHash');end
assert(strcmp(sha256_file(cfg.generatedModel),cfg.generatedModelHash)&& ...
    strcmp(sha256_file(cfg.runAll),cfg.controlHashes.runAll)&& ...
    strcmp(sha256_file(cfg.simfile),cfg.controlHashes.simfile)&& ...
    strcmp(sha256_file(cfg.controlManifestFile),cfg.controlHashes.manifest),'VX:V4B:GeneratedHash');
end
function X=orient_data(X,n,w,name)
X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end
assert(size(X,1)==n&&size(X,2)==w,'VX:V4B:SignalShape','%s must be N-by-%d.',name,w);
end
function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end;b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end,end
end
function write_commit(file,cfg)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4B:CommitWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'STAGE=VX-V4B-CS40-DRIVE-CALIBRATION\nCANDIDATE=%s\nSIM_INVOCATION_COMMITTED=YES\n',cfg.candidateId);
fprintf(fid,'PHYSICAL_ONLY=YES\nSV_VXS_KMH=%.17g\nMU_ROAD_CONSTANT=%.17g\n',cfg.initialSpeedValue,cfg.muRoadConstant);clear c
end
function write_console(file,text,failure)
if numel(text)>20000,text=text(end-19999:end);end;fid=fopen(file,'wt');assert(fid>=0,'VX:V4B:ConsoleWrite');
c=onCleanup(@()fclose(fid));fwrite(fid,text);if ~isempty(failure),fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message);end;clear c
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V4B:JsonWrite');c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
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
