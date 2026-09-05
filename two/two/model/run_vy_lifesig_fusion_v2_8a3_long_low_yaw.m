function runtime = run_vy_lifesig_fusion_v2_8a3_long_low_yaw()
%RUN... One authorized V2.8-A3 22-s runtime using independent CarSim control.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
controlDir=fullfile(root,'results','vy_lifesig_v2_8a3_carsim_control');
simFile=fullfile(controlDir,'simfile.sim');controlPar=fullfile(controlDir,'Run_all.par');
sharedPar='D:\carsim\CarSim2021.0_Data\Results\Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517\Run_all.par';
target=fullfile(md,'vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx');
resultFile=fullfile(root,'results','vy_lifesig_v2_8a3_long_low_yaw_runtime.mat');
model='vx_vy_lifesig_fusion_v2_8a2_long_low_yaw';
targetExpected='576019D260B8BD412F93827BE29F74FEFCBABB8FD23DF0735CA372067EABF829';
sharedExpected='2FA959F8137B6014F87BC70F1F7716308E92FF22B8E4E7BD6CCC4179EA16C114';
assert(~isfile(resultFile),'V28A3:RuntimeExists', ...
    'A3 runtime evidence exists; no second A3 runtime is authorized.');

runtime=struct();runtime.stage='V2.8-A3';
runtime.role='NON_HOLDOUT_LONG_LOW_YAW_ESTIMATOR_VALIDATION';
runtime.condition=struct('stopTime_s',22,'speed_mps',20,'rate_Hz',100, ...
    'initialStraight_s',2,'steerAmplitude_rad',0.02,'steerFrequency_Hz',0.4, ...
    'sinePeriods',1,'excitationEnd_s',4.5,'postExcitationStraight_s',17.5);
runtime.simCalled=false;runtime.simInvocationCount=0;runtime.authorization='UNCONSUMED';
runtime.simReturned=false;runtime.fullSimulationOutputSaved=false;
runtime.logsSaved=false;runtime.durationComplete=false;runtime.simulationCompleted=false;
runtime.carSimRun=false;runtime.raw=struct();runtime.consoleText='';
runtime.runtimeError=struct('identifier','','message','','report','');
runtime.targetHashBefore=sha256(target);runtime.sharedParHashBefore=sha256(sharedPar);
runtime.controlParHashBefore=sha256(controlPar);runtime.simfileHashBefore=sha256(simFile);
assert(strcmp(runtime.targetHashBefore,targetExpected),'V28A3:TargetHashMismatch', ...
    'Long-low-yaw target hash mismatch.');
assert(strcmp(runtime.sharedParHashBefore,sharedExpected),'V28A3:SharedParHashMismatch', ...
    'Shared CarSim Run_all.par differs from the frozen A2R1 evidence.');
runtime.controlAudit=audit_control_copy(sharedPar,controlPar,simFile);
assert(runtime.controlAudit.passed,'V28A3:IndependentControlInvalid', ...
    'Independent CarSim run-control differs by more than TSTOP 16 -> 22.');

oldPwd=pwd;oldPath=path;cleanupObj=onCleanup(@()cleanup(model,oldPwd,oldPath));
console='';out=[];
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
    solverSfDir=fullfile(solverDir,'Matlab84+');solverDll=fullfile(solverDir,'carsim_64.dll');
    solverLibrary=fullfile(solverSfDir,'Solver_SF.slx');
    assert(isfile(simFile)&&isfile(controlPar)&&isfile(solverDll)&&isfile(solverLibrary), ...
        'V28A3:RuntimeFileMissing','Independent control or D: solver file is missing.');
    simText=fileread(simFile);
    runtime.carSim=struct('controlDir',controlDir,'activeSimfile',simFile, ...
        'progDir',macro_value(simText,'PROGDIR'),'dataDir',macro_value(simText,'DATADIR'), ...
        'input',directive_value(simText,'INPUT'),'solverExpected',solverDll, ...
        'solverActual','','terminationTime',NaN,'gRequest',contains(lower(simText),'g:\carsim'));
    assert(strcmpi(runtime.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(runtime.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&& ...
        strcmp(runtime.carSim.input,'Run_all.par')&&~runtime.carSim.gRequest, ...
        'V28A3:CarSimLineageMismatch','Independent simfile does not retain D: lineage.');

    addpath(md);addpath(solverDir);addpath(solverSfDir);
    Simulink.fileGenControl('set','CacheFolder', ...
        fullfile(tempdir,'vy_lifesig_v2_8a3_long_low_yaw_cache'), ...
        'CodeGenFolder',fullfile(tempdir,'vy_lifesig_v2_8a3_long_low_yaw_codegen'), ...
        'createDir',true);
    cd(controlDir);runtime.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    load_system('Solver_SF');load_system(target);
    runtime.modelStopTime=str2double(get_param(model,'StopTime'));
    assert(runtime.modelStopTime>=22&&runtime.controlAudit.controlTstop>=22, ...
        'V28A3:StopTimePreflight','Simulink or independent CarSim stop time is below 22 s.');

    requiredLogs={'rel_common_time_100hz_log','steer_cmd_rad','long_low_yaw_r_log', ...
        'rel_vy_true_100hz_log','fusion_vy_d_log','fusion_vy_k_log', ...
        'long_low_yaw_k_error_log','long_low_yaw_d_error_log', ...
        'steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg', ...
        'steer_rl_carsim_deg','steer_rr_carsim_deg'};
    runtime.requiredLogs=requiredLogs(:);
    runtime.static=static_preflight(model,requiredLogs);
    assert(runtime.static.passed,'V28A3:StaticPreflightFailed', ...
        'A3 target/profile/logging preflight failed.');
    w=get_param(model,'ModelWorkspace');
    assignin(w,'test_speed',20);assignin(w,'vy_v17_mode_code',20);
    assignin('base','test_speed',20);assignin('base','vy_v17_mode_code',20);
    clear vy_dynamic_ekf_v1_17_reliability_numeric vy_kinematic_kf

    runtime.simCalled=true;runtime.simInvocationCount=1;runtime.authorization='CONSUMED';
    runtime.preSimCommitTime=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS Z'));
    save(resultFile,'runtime','-v7.3');
    console=evalc("out=sim(model,'StopTime','22','ReturnWorkspaceOutputs','on','FastRestart','off');");
    runtime.simReturned=true;runtime.consoleText=console;fprintf('%s',console);

    % Save the complete SimulationOutput before any duration/completion gate.
    save(resultFile,'runtime','out','-v7.3');runtime.fullSimulationOutputSaved=true;
    for k=1:numel(requiredLogs)
        name=requiredLogs{k};runtime.raw.(name)=record_timeseries(out.get(name));
    end
    runtime.logsSaved=numel(fieldnames(runtime.raw))==numel(requiredLogs);
    runtime.carSim.solverActual=solver_path_from_console(console);
    runtime.carSim.terminationTime=termination_time_from_console(console);
    commonTime=runtime.raw.rel_common_time_100hz_log.time;
    runtime.observedTime=struct('start',commonTime(1),'end',commonTime(end), ...
        'samples',numel(commonTime),'dtMean',mean(diff(commonTime)));
    runtime.durationComplete=runtime.observedTime.samples==2201&& ...
        abs(runtime.observedTime.start)<=1e-12&&abs(runtime.observedTime.end-22)<=1e-9&& ...
        max(abs(diff(commonTime)-0.01))<=1e-9;
    runtime.carSimRun=abs(runtime.carSim.terminationTime-22)<=1e-9&& ...
        strcmpi(runtime.carSim.solverActual,solverDll);
    runtime.simulationCompleted=runtime.simReturned&&runtime.fullSimulationOutputSaved&& ...
        runtime.logsSaved&&runtime.durationComplete&&runtime.carSimRun;
    save(resultFile,'runtime','out','-v7.3');
catch ME
    runtime.consoleText=console;runtime.runtimeError.identifier=ME.identifier;
    runtime.runtimeError.message=ME.message;
    runtime.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
    if exist('out','var')&&~isempty(out)
        try,save(resultFile,'runtime','out','-v7.3');catch,end
    else
        save(resultFile,'runtime','-v7.3');
    end
end

cleanup(model,oldPwd,oldPath);clear cleanupObj
runtime.targetHashAfter=sha256(target);runtime.sharedParHashAfter=sha256(sharedPar);
runtime.controlParHashAfter=sha256(controlPar);runtime.simfileHashAfter=sha256(simFile);
runtime.hashesUnchanged=strcmp(runtime.targetHashBefore,runtime.targetHashAfter)&& ...
    strcmp(runtime.sharedParHashBefore,runtime.sharedParHashAfter)&& ...
    strcmp(runtime.controlParHashBefore,runtime.controlParHashAfter)&& ...
    strcmp(runtime.simfileHashBefore,runtime.simfileHashAfter);
if exist('out','var')&&~isempty(out),save(resultFile,'runtime','out','-v7.3');
else,save(resultFile,'runtime','-v7.3');end
if ~runtime.simulationCompleted
    error('V28A3:RuntimeFailed', ...
        'The sole A3 runtime failed; no rerun is authorized. Evidence: %s\n%s', ...
        resultFile,runtime.runtimeError.report);
end
assert(runtime.hashesUnchanged,'V28A3:HashChanged', ...
    'Target, shared control, or independent control changed during runtime.');
fprintf(['V28_A3_RUNTIME|sim=1|authorization=CONSUMED|returned=1|outSaved=1|' ...
    'logs=%d|samples=%d|end=%.17g|carsim=1|hashes=1\n'], ...
    numel(fieldnames(runtime.raw)),runtime.observedTime.samples,runtime.observedTime.end);
end

function audit=audit_control_copy(shared,control,simFile)
a=read_bytes(shared);b=read_bytes(control);audit=struct();
audit.sharedBytes=numel(a);audit.controlBytes=numel(b);audit.sameLength=numel(a)==numel(b);
if audit.sameLength,audit.diffIndices=find(a~=b);else,audit.diffIndices=[];end
sa=char(a(:).');sb=char(b(:).');
audit.sharedTstop=token_number(sa,'(?m)^TSTOP\s+([0-9.]+)\s*$');
audit.controlTstop=token_number(sb,'(?m)^TSTOP\s+([0-9.]+)\s*$');
simText=fileread(simFile);audit.simfileInput=directive_value(simText,'INPUT');
audit.diffCount=numel(audit.diffIndices);
audit.onlyTstopChanged=audit.sameLength&&audit.diffCount==2&& ...
    audit.sharedTstop==16&&audit.controlTstop==22;
audit.passed=audit.onlyTstopChanged&&strcmp(audit.simfileInput,'Run_all.par');
end

function audit=static_preflight(m,requiredLogs)
cmd=[m '/G0 Steer Cmd Rad'];w=get_param(m,'ModelWorkspace');
profile=evalin(w,'long_low_yaw_steer_profile');t=profile(:,1);u=profile(:,2);
audit=struct('sourceType',get_param(cmd,'BlockType'),'variable',get_param(cmd,'VariableName'), ...
    'sampleTime',get_param(cmd,'SampleTime'),'profileSamples',numel(t), ...
    'postZeroExact',all(u(t>=4.5)==0),'maxAbs',max(abs(u)));
audit.logsPresent=all(cellfun(@(n)numel(find_system(m,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','ToWorkspace','VariableName',n))==1,requiredLogs));
audit.passed=strcmp(audit.sourceType,'FromWorkspace')&& ...
    strcmp(audit.variable,'long_low_yaw_steer_profile')&&strcmp(audit.sampleTime,'0.01')&& ...
    audit.profileSamples==2201&&audit.postZeroExact&& ...
    audit.maxAbs<=0.02+eps(0.02)&&audit.maxAbs>=0.999*0.02&&audit.logsPresent;
end

function r=record_timeseries(ts)
assert(isa(ts,'timeseries'),'V28A3:LogType','Expected timeseries, got %s.',class(ts));
r=struct('time',double(ts.Time(:)),'data',double(ts.Data), ...
    'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));
end
function x=read_bytes(path)
fid=fopen(path,'rb');assert(fid>0,'Cannot open %s.',path);c=onCleanup(@()fclose(fid));
x=fread(fid,inf,'*uint8');clear c
end
function v=token_number(text,expression)
t=regexp(text,expression,'tokens','once');assert(~isempty(t),'Control token missing.');v=str2double(t{1});
end
function value=macro_value(text,key)
t=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(t),'CarSim macro missing: %s',key);value=strtrim(t{1});
end
function value=directive_value(text,key)
t=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(t),'CarSim directive missing: %s',key);value=strtrim(t{1});
end
function p=solver_path_from_console(text)
t=regexp(text,'Use vehicle solver:\s*([^\r\n]+)','tokens','once');
if isempty(t),p='';else,p=strtrim(t{1});end
end
function t=termination_time_from_console(text)
x=regexp(text,'Termination at simulation time\s*=\s*([0-9.eE+-]+)','tokens','once');
if isempty(x),t=NaN;else,t=str2double(x{1});end
end
function cleanup(m,oldPwd,oldPath)
if bdIsLoaded(m),close_system(m,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
cd(oldPwd);path(oldPath);evalin('base','clear test_speed vy_v17_mode_code');
end
function hash=sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
