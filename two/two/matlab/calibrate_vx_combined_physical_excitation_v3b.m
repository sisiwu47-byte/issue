function result = calibrate_vx_combined_physical_excitation_v3b()
%CALIBRATE_VX_COMBINED_PHYSICAL_EXCITATION_V3B Tier-1 physical-only runner.
% FORMAL_RUNTIME=false
% SIM_INVOCATION_COMMITTED=NO
% Selection reads only Vx truth, wheel omega, the command and completion.

root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));addpath(fullfile(root,'model'));
freezeFile=fullfile(root,'results','vx_formal_validation','v3b','frozen_physical_excitation.json');
assert(~isfile(freezeFile),'VX:V3B:AlreadyFrozen','Physical excitation is already frozen.');
calRoot=fullfile(root,'results','vx_formal_validation','v3b','calibration');
if ~isfolder(calRoot),mkdir(calRoot);end
candidates=["T1_2P5","T1_2P0","T1_1P5"];
count=0;selected=[];lastGate=[];
for k=1:numel(candidates)
    candidate=candidates(k);outDir=fullfile(calRoot,char(candidate));
    if ~isfolder(outDir),mkdir(outDir);end
    physicalFile=fullfile(outDir,'physical_only.mat');
    gateFile=fullfile(outDir,'physical_gate.json');
    assert(~isfile(physicalFile)&&~isfile(gateFile),'VX:V3B:CalibrationExists', ...
        'Existing calibration evidence for %s prevents an accidental rerun.',candidate);
    [simIn,cfg]=configure_vx_physical_calibration_v3b(candidate);
    count=count+1;
    try
        P=run_one(simIn,cfg);
        gate=physical_gate(P.time,P.kappa,cfg.brakeRampEnd_s,cfg.brakeAnalysisEnd_s);
        P.gate=gate;save(physicalFile,'P','-v7.3');write_json(gateFile,gate);
    catch ME
        gate=struct('candidate',char(candidate),'simulationCompleted',false, ...
            'physicalPass',false,'errorIdentifier',ME.identifier,'errorMessage',ME.message);
        write_json(gateFile,gate);write_count(calRoot,count,'NO_PASS');rethrow(ME)
    end
    lastGate=gate;write_count(calRoot,count,ternary(gate.physicalPass,'PASS','CONTINUE'));
    fprintf('VX_V3B_PHYSICAL_GATE|candidate=%s|drive=[%.6f %.6f]|brake=[%.6f %.6f]|pass=%d\n', ...
        candidate,gate.driveDuration_s(1),gate.driveDuration_s(2), ...
        gate.brakeDuration_s(1),gate.brakeDuration_s(2),gate.physicalPass);
    if gate.physicalPass,selected=struct('cfg',cfg,'gate',gate);break,end
end
result=struct('physicalCalibrationSimCount',count,'selected',selected,'lastGate',lastGate);
if ~isempty(selected)
    freeze=make_freeze(selected.cfg,selected.gate,count);write_json(freezeFile,freeze);
    result.freeze=freeze;
else
    result.tier1AllFailed=true;
end
end

function P=run_one(simIn,cfg)
solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';sf=fullfile(solverDir,'Matlab84+');
lib=fullfile(sf,'Solver_SF.slx');dll=fullfile(solverDir,'carsim_64.dll');
assert(isfile(lib)&&isfile(dll),'VX:V3B:CarSimSolverMissing');addpath(solverDir);addpath(sf);
oldPwd=pwd;oldPath=path;[~,modelName]=fileparts(cfg.generatedModel);
c=onCleanup(@()cleanup_runtime(modelName,oldPwd,oldPath));
load_system(lib);load_system(cfg.generatedModel);cd(cfg.runtimeWorkingDirectory);
clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
simOut=sim(simIn);
vxLog=simOut.get('Vx_true_log');uLog=simOut.get('est_u_log');
assert(isa(vxLog,'timeseries')&&isa(uLog,'timeseries'),'VX:V3B:PhysicalLogs');
t=double(uLog.Time(:));U=orient_data(double(uLog.Data),numel(t),18);
vx=interp1(double(vxLog.Time(:)),double(vxLog.Data(:)),t,'linear',NaN);
omega=U(:,1:4);kappa=(0.393.*omega-vx)./max(abs(vx),1);
assert(t(end)>=15.999&&all(isfinite(vx))&&all(isfinite(omega),'all'), ...
    'VX:V3B:Incomplete','Physical calibration did not complete numerically through 16 s.');
P=struct('metadata',struct('stage','VX-V3B-PHYSICAL-CALIBRATION', ...
    'formalRuntime',false,'simInvocationCommitted','NO','candidate',cfg.candidate, ...
    'simulationCompleted',true),'time',t,'vxTrue',vx,'wheelOmega',omega, ...
    'kappa',kappa,'speedTime_s',cfg.speedTime_s,'speed_kmh',cfg.speed_kmh, ...
    'brakeRampEnd_s',cfg.brakeRampEnd_s,'brakeAnalysisEnd_s',cfg.brakeAnalysisEnd_s, ...
    'configuration',cfg);
clear c;cleanup_runtime(modelName,oldPwd,oldPath);
end

function gate=physical_gate(t,kappa,brakeRampEnd,brakeAnalysisEnd)
drive=[max_sustained(t,t>=3&t<7&kappa(:,3)>=0.10), ...
    max_sustained(t,t>=3&t<7&kappa(:,4)>=0.10)];
brake=[max_sustained(t,t>=9&t<brakeAnalysisEnd&kappa(:,3)<=-0.10), ...
    max_sustained(t,t>=9&t<brakeAnalysisEnd&kappa(:,4)<=-0.10)];
gate=struct('simulationCompleted',true,'driveWindow_s',[3 7], ...
    'brakeWindow_s',[9 brakeAnalysisEnd],'brakeRampEnd_s',brakeRampEnd, ...
    'driveDuration_s',drive,'brakeDuration_s',brake, ...
    'driveGatePass',all(drive>=0.10-1e-9),'brakeGatePass',all(brake>=0.10-1e-9));
gate.physicalPass=gate.driveGatePass&&gate.brakeGatePass;
end

function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end
b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1
    run=idx(b(k):b(k+1)-1);
    if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end
end
end

function freeze=make_freeze(cfg,gate,count)
freeze=struct('schemaVersion','VX_PHYSICAL_EXCITATION_V3B_1', ...
    'stage','VX-V3B','caseId','VX-CS','selectedTier','TIER1_REFERENCE_ONLY', ...
    'selectedCandidate',cfg.candidate,'speedTime_s',cfg.speedTime_s(:).', ...
    'speed_kmh',cfg.speed_kmh(:).','referenceUnit','km/h', ...
    'brakeRampEnd_s',cfg.brakeRampEnd_s,'brakeAnalysisEnd_s',cfg.brakeAnalysisEnd_s, ...
    'rearBrakeOverride',struct('enabled',false), ...
    'PHYSICAL_CALIBRATION_SIM_COUNT',count, ...
    'calibrationDriveSustainedDuration_s',gate.driveDuration_s, ...
    'calibrationBrakeSustainedDuration_s',gate.brakeDuration_s, ...
    'sourceHashes',cfg.frozenSourceHashes,'generatedHashes',cfg.generatedHashes, ...
    'controlSourceHashes',cfg.sourceControlHashes,'muRoadConstant',0.30, ...
    'PHYSICAL_EXCITATION_FROZEN','YES', ...
    'frozenAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
function X=orient_data(X,n,w)
X=squeeze(X);if size(X,1)~=n&&size(X,2)==n,X=X.';end
assert(size(X,1)==n&&size(X,2)==w,'VX:V3B:SignalShape');
end
function write_count(root,count,state)
write_json(fullfile(root,'physical_calibration_count.json'), ...
    struct('PHYSICAL_CALIBRATION_SIM_COUNT',count,'state',state,'FORMAL_RUNTIME_COUNT_CONTRIBUTION',0));
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:JsonWrite');c=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
end
function cleanup_runtime(modelName,oldPwd,oldPath)
if bdIsLoaded(modelName),close_system(modelName,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
cd(oldPwd);path(oldPath);
end
function out=ternary(c,a,b)
if c,out=a;else,out=b;end
end
