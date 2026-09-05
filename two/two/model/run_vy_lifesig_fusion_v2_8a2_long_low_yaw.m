function runtime = run_vy_lifesig_fusion_v2_8a2_long_low_yaw()
%RUN... Execute the first-and-only authorized 22-s V2.8-A2 runtime.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
target=fullfile(md,'vx_vy_lifesig_fusion_v2_8a2_long_low_yaw.slx');
simFile=fullfile(md,'simfile.sim');
compileFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_compile.mat');
resultFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_runtime.mat');
model='vx_vy_lifesig_fusion_v2_8a2_long_low_yaw';
targetExpected='576019D260B8BD412F93827BE29F74FEFCBABB8FD23DF0735CA372067EABF829';
sourceFile=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
sourceExpected='65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0';
assert(~isfile(resultFile),'V28A2:RuntimeEvidenceExists', ...
    'V2.8-A2 runtime evidence already exists; no second runtime is authorized.');
assert(isfile(compileFile),'V28A2:CompileEvidenceMissing','Compile evidence is missing.');
C=load(compileFile,'report');
assert(C.report.passed,'V28A2:CompileNotAccepted','V2.8-A2 compile gate is not accepted.');

runtime=struct();runtime.stage='V2.8-A2';
runtime.role='NON_HOLDOUT_LONG_LOW_YAW_OBSERVABILITY_VALIDATION';
runtime.condition=struct('stopTime_s',22,'speed_mps',20,'rate_Hz',100, ...
    'initialStraight_s',2,'steerAmplitude_rad',0.02, ...
    'steerFrequency_Hz',0.4,'sinePeriods',1,'excitationEnd_s',4.5, ...
    'postExcitationStraight_s',17.5);
runtime.simCalled=false;runtime.simInvocationCount=0;
runtime.authorization='UNCONSUMED';runtime.simulationCompleted=false;
runtime.carSimRun=false;runtime.consoleText='';runtime.raw=struct();
runtime.runtimeError=struct('identifier','','message','','report','');
runtime.targetHashBefore=sha256(target);runtime.sourceHashBefore=sha256(sourceFile);
assert(strcmp(runtime.targetHashBefore,targetExpected)&& ...
    strcmp(runtime.sourceHashBefore,sourceExpected),'V28A2:FrozenHashMismatch', ...
    'V2.8-A2 target or frozen V2.7 source hash mismatch.');

oldPwd=pwd;oldPath=path;cleanupObj=onCleanup(@()cleanup(model,oldPwd,oldPath));
console='';
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
    solverSfDir=fullfile(solverDir,'Matlab84+');solverDll=fullfile(solverDir,'carsim_64.dll');
    solverLibrary=fullfile(solverSfDir,'Solver_SF.slx');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(solverLibrary), ...
        'V28A2:CarSimFileMissing','Required D: CarSim runtime file is missing.');
    simText=fileread(simFile);
    runtime.carSim=struct('pwd','','activeSimfile',simFile, ...
        'progDir',macro_value(simText,'PROGDIR'),'dataDir',macro_value(simText,'DATADIR'), ...
        'solverExpected',solverDll,'solverActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'),'gRequestConsole',false);
    assert(strcmpi(runtime.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(runtime.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&& ...
        ~runtime.carSim.gRequestBefore,'V28A2:CarSimLineageMismatch', ...
        'Active simfile is not the accepted D: CarSim lineage.');

    addpath(md);addpath(solverDir);addpath(solverSfDir);
    Simulink.fileGenControl('set','CacheFolder', ...
        fullfile(tempdir,'vy_lifesig_v2_8a2_long_low_yaw_cache'), ...
        'CodeGenFolder',fullfile(tempdir,'vy_lifesig_v2_8a2_long_low_yaw_codegen'), ...
        'createDir',true);
    cd(md);runtime.carSim.pwd=pwd;runtime.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    assert(strcmpi(runtime.carSim.activeSimfile,simFile),'V28A2:WorkingDirectoryMismatch', ...
        'Runtime cwd does not select model/simfile.sim.');
    load_system('Solver_SF');load_system(target);

    requiredLogs={'rel_common_time_100hz_log','steer_cmd_rad','long_low_yaw_r_log', ...
        'rel_vy_true_100hz_log','fusion_vy_d_log','fusion_vy_k_log', ...
        'long_low_yaw_k_error_log','long_low_yaw_d_error_log', ...
        'steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg', ...
        'steer_rl_carsim_deg','steer_rr_carsim_deg'};
    runtime.requiredLogs=requiredLogs(:);
    runtime.static=static_preflight(model,requiredLogs);
    assert(runtime.static.passed,'V28A2:StaticPreflightFailed', ...
        'Long-low-yaw runtime preflight failed before sim().');
    runtime.profile=runtime.static.profile;

    w=get_param(model,'ModelWorkspace');
    assignin(w,'test_speed',20);assignin(w,'vy_v17_mode_code',20);
    assignin('base','test_speed',20);assignin('base','vy_v17_mode_code',20);
    clear vy_dynamic_ekf_v1_17_reliability_numeric vy_kinematic_kf

    % Durable consumption evidence immediately precedes the sole sim() site.
    runtime.simCalled=true;runtime.simInvocationCount=1;
    runtime.authorization='CONSUMED';runtime.preSimCommitTime=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS Z'));
    save(resultFile,'runtime','-v7.3');
    console=evalc("out=sim(model,'StopTime','22','ReturnWorkspaceOutputs','on','FastRestart','off');");
    fprintf('%s',console);runtime.consoleText=console;
    runtime.carSim.solverActual=solver_path_from_console(console);
    runtime.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    runtime.carSimRun=contains(console,'Termination at simulation time = 22')&& ...
        strcmpi(runtime.carSim.solverActual,solverDll)&&~runtime.carSim.gRequestConsole;
    assert(runtime.carSimRun,'V28A2:CarSimCompletionMissing', ...
        'Authorized 22-s CarSim completion evidence is missing.');
    for k=1:numel(requiredLogs)
        name=requiredLogs{k};runtime.raw.(name)=record_timeseries(out.get(name));
    end
    runtime.simulationCompleted=true;
catch ME
    runtime.consoleText=console;runtime.runtimeError.identifier=ME.identifier;
    runtime.runtimeError.message=ME.message;
    runtime.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end

cleanup(model,oldPwd,oldPath);clear cleanupObj
runtime.targetHashAfter=sha256(target);runtime.sourceHashAfter=sha256(sourceFile);
runtime.hashesUnchanged=strcmp(runtime.targetHashBefore,runtime.targetHashAfter)&& ...
    strcmp(runtime.sourceHashBefore,runtime.sourceHashAfter)&& ...
    strcmp(runtime.targetHashAfter,targetExpected)&&strcmp(runtime.sourceHashAfter,sourceExpected);
save(resultFile,'runtime','-v7.3');
if ~runtime.simulationCompleted
    error('V28A2:RuntimeFailed', ...
        'The sole V2.8-A2 runtime failed; no rerun is authorized. Evidence: %s\n%s', ...
        resultFile,runtime.runtimeError.report);
end
assert(runtime.hashesUnchanged,'V28A2:HashChanged', ...
    'V2.8-A2 target or frozen V2.7 source changed during runtime.');
fprintf('V28_A2_RUNTIME|sim=1|authorization=CONSUMED|completed=1|carsim=1|hashes=1|logs=%d\n', ...
    numel(requiredLogs));
end

function audit=static_preflight(m,requiredLogs)
audit=struct();cmd=[m '/G0 Steer Cmd Rad'];
audit.sourceType=get_param(cmd,'BlockType');audit.variable=get_param(cmd,'VariableName');
audit.sampleTime=get_param(cmd,'SampleTime');audit.interpolate=get_param(cmd,'Interpolate');
w=get_param(m,'ModelWorkspace');profile=evalin(w,'long_low_yaw_steer_profile');
audit.profile=profile;audit.profileSize=size(profile);t=profile(:,1);u=profile(:,2);
audit.stopTime=str2double(get_param(m,'StopTime'));
audit.timeOK=numel(t)==2201&&abs(t(1))<1e-15&&abs(t(end)-22)<1e-12&& ...
    max(abs(diff(t)-0.01))<1e-12;
audit.steeringOK=all(u(t<=2)==0)&&all(u(t>=4.5)==0)&& ...
    max(abs(u))<=0.02+eps(0.02)&&max(abs(u))>=0.999*0.02;
audit.logsPresent=all(cellfun(@(n)numel(find_system(m,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','ToWorkspace','VariableName',n))==1,requiredLogs));
audit.passed=strcmp(audit.sourceType,'FromWorkspace')&& ...
    strcmp(audit.variable,'long_low_yaw_steer_profile')&&strcmp(audit.sampleTime,'0.01')&& ...
    strcmp(audit.interpolate,'off')&&audit.stopTime==22&&audit.timeOK&& ...
    audit.steeringOK&&audit.logsPresent;
end

function r=record_timeseries(ts)
assert(isa(ts,'timeseries'),'V28A2:LogType','Expected timeseries, got %s.',class(ts));
r=struct('time',double(ts.Time(:)),'data',double(ts.Data), ...
    'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));
end

function value=macro_value(text,key)
token=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(token),'V28A2:CarSimMacroMissing','CarSim entry missing: %s',key);
value=strtrim(token{1});
end

function p=solver_path_from_console(text)
token=regexp(text,'Use vehicle solver:\s*([^\r\n]+)','tokens','once');
if isempty(token),p='';else,p=strtrim(token{1});end
end

function cleanup(m,oldPwd,oldPath)
if bdIsLoaded(m),close_system(m,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
cd(oldPwd);path(oldPath);
evalin('base','clear test_speed vy_v17_mode_code');
end

function hash=sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=upper(reshape(dec2hex(bytes,2).',1,[]));
clear c
end
