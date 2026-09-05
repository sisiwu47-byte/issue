function smoke = run_vy_lifesig_fusion_v2_7a3r9_smoke()
%RUN_VY_LIFESIG_FUSION_V2_7A3R9_SMOKE One authorized 0.20-s smoke runtime.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
target=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
simFile=fullfile(md,'simfile.sim');
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r9_smoke.mat');
model='vx_vy_lifesig_fusion_v2_7';
targetExpected='65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0';
coreFile=fullfile(md,'vy_lifesig_fusion_step.m');
wrapperFile=fullfile(md,'vy_lifesig_fusion_simulink_sfun.m');
coreExpected='3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA';
wrapperExpected='E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445';
assert(~isfile(resultFile),'A3R9:ResultExists', ...
    'A3R9 smoke evidence already exists; a second runtime is not authorized.');

smoke=struct();smoke.stage='V2.7-A3R9';
smoke.role='NON_HOLDOUT_ENGINEERING_DIAGNOSTIC';
smoke.condition=struct('stopTime_s',0.20,'speed_mps',20, ...
    'steerAmplitude_rad',0.02,'steerFrequency_Hz',0.4,'rate_Hz',100);
smoke.simCalled=false;smoke.simInvocationCount=0;
smoke.simulationCompleted=false;smoke.carSimRun=false;
smoke.runtimeError=struct('identifier','','message','','report','');
smoke.consoleText='';smoke.raw=struct();
smoke.targetHashBefore=sha256(target);smoke.coreHashBefore=sha256(coreFile);
smoke.wrapperHashBefore=sha256(wrapperFile);
assert(strcmp(smoke.targetHashBefore,targetExpected)&& ...
    strcmp(smoke.coreHashBefore,coreExpected)&&strcmp(smoke.wrapperHashBefore,wrapperExpected), ...
    'A3R9:FrozenHashMismatch','A3R9 target/core/wrapper hash mismatch.');

oldPwd=pwd;oldPath=path;cleanupObj=onCleanup(@()cleanup(model,oldPwd,oldPath));
console='';
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
    solverSfDir=fullfile(solverDir,'Matlab84+');
    solverDll=fullfile(solverDir,'carsim_64.dll');
    solverLibrary=fullfile(solverSfDir,'Solver_SF.slx');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(solverLibrary), ...
        'A3R9:CarSimFileMissing','Required D: CarSim runtime file is missing.');
    simText=fileread(simFile);
    smoke.carSim=struct('pwd','','activeSimfile',simFile, ...
        'progDir',macro_value(simText,'PROGDIR'), ...
        'dataDir',macro_value(simText,'DATADIR'), ...
        'solverExpected',solverDll,'solverActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'), ...
        'gRequestConsole',false);
    assert(strcmpi(smoke.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(smoke.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&& ...
        ~smoke.carSim.gRequestBefore,'A3R9:CarSimLineageMismatch', ...
        'Active simfile is not the accepted D: CarSim lineage.');

    addpath(md);addpath(solverDir);addpath(solverSfDir);
    Simulink.fileGenControl('set','CacheFolder', ...
        fullfile(tempdir,'vy_lifesig_v2_7a3r9_cache'), ...
        'CodeGenFolder',fullfile(tempdir,'vy_lifesig_v2_7a3r9_codegen'), ...
        'createDir',true);
    cd(md);smoke.carSim.pwd=pwd;smoke.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    assert(strcmpi(smoke.carSim.activeSimfile,simFile),'A3R9:WorkingDirectoryMismatch', ...
        'Runtime cwd does not select model/simfile.sim.');
    load_system('Solver_SF');load_system(target);

    requiredLogs={'lifesig_vy_ls_log','lifesig_alpha_d_log', ...
        'lifesig_alpha_k_log','lifesig_alpha_f_log','lifesig_h_d_log', ...
        'lifesig_h_k_log','lifesig_h_f_log','lifesig_fusion_valid_log', ...
        'lifesig_fallback_active_log','fusion_vy_d_log','rel_d_valid_log', ...
        'fusion_vy_k_log','kkf_diag_log1','fusion_vy_f_log', ...
        'rel_f_reliability_log','rel_common_time_100hz_log', ...
        'rel_vy_true_100hz_log','reset_g0','steer_cmd_rad', ...
        'steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg', ...
        'steer_rl_carsim_deg','steer_rr_carsim_deg'};
    smoke.requiredLogs=requiredLogs(:);
    smoke.static=static_preflight(model,requiredLogs);
    assert(smoke.static.passed,'A3R9:StaticPreflightFailed', ...
        'LifeSig smoke static preflight failed.');

    w=get_param(model,'ModelWorkspace');
    assignin(w,'test_speed',20);assignin(w,'test_steer_amplitude',0.02);
    assignin(w,'test_steer_frequency',0.4);assignin(w,'vy_v17_mode_code',20);
    assignin('base','test_speed',20);assignin('base','test_steer_amplitude',0.02);
    assignin('base','test_steer_frequency',0.4);assignin('base','vy_v17_mode_code',20);
    clear vy_dynamic_ekf_v1_17_reliability_numeric vy_kinematic_kf

    smoke.simCalled=true;smoke.simInvocationCount=1;
    console=evalc("out=sim(model,'StopTime','0.20','ReturnWorkspaceOutputs','on','FastRestart','off');");
    fprintf('%s',console);smoke.consoleText=console;
    smoke.carSim.solverActual=solver_path_from_console(console);
    smoke.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    smoke.carSimRun=contains(console,'Termination at simulation time')&& ...
        strcmpi(smoke.carSim.solverActual,solverDll)&&~smoke.carSim.gRequestConsole;
    assert(smoke.carSimRun,'A3R9:CarSimCompletionMissing', ...
        'Authorized CarSim runtime completion evidence is missing.');
    for k=1:numel(requiredLogs)
        name=requiredLogs{k};smoke.raw.(name)=record_timeseries(out.get(name));
    end
    smoke.simulationCompleted=true;
catch ME
    smoke.consoleText=console;smoke.runtimeError.identifier=ME.identifier;
    smoke.runtimeError.message=ME.message;
    smoke.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end

cleanup(model,oldPwd,oldPath);clear cleanupObj
smoke.targetHashAfter=sha256(target);smoke.coreHashAfter=sha256(coreFile);
smoke.wrapperHashAfter=sha256(wrapperFile);
smoke.hashesUnchanged=strcmp(smoke.targetHashBefore,smoke.targetHashAfter)&& ...
    strcmp(smoke.coreHashBefore,smoke.coreHashAfter)&& ...
    strcmp(smoke.wrapperHashBefore,smoke.wrapperHashAfter);
save(resultFile,'smoke','-v7.3');
if ~smoke.simulationCompleted
    error('A3R9:RuntimeFailed','A3R9 runtime failed; evidence saved to %s.\n%s', ...
        resultFile,smoke.runtimeError.report);
end
assert(smoke.hashesUnchanged,'A3R9:HashChanged', ...
    'LifeSig target/core/wrapper changed during smoke runtime.');
fprintf('A3R9_RUNTIME|sim=1|completed=1|carsim=1|targetUnchanged=1|logs=%d\n', ...
    numel(requiredLogs));
end

function audit=static_preflight(m,requiredLogs)
cmd=[m '/G0 Steer Cmd Rad'];fusion=[m '/LifeSig D K F Fusion'];
audit=struct();audit.amplitude=get_param(cmd,'Amplitude');
audit.frequency=get_param(cmd,'Frequency');audit.sampleTime=get_param(cmd,'SampleTime');
audit.wrapper=get_param(fusion,'FunctionName');
audit.logsPresent=all(cellfun(@(n)numel(find_system(m,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','ToWorkspace','VariableName',n))==1,requiredLogs));
audit.passed=strcmp(audit.amplitude,'test_steer_amplitude')&& ...
    strcmp(audit.frequency,'2*pi*test_steer_frequency')&& ...
    strcmp(audit.sampleTime,'0')&& ...
    strcmp(audit.wrapper,'vy_lifesig_fusion_simulink_sfun')&&audit.logsPresent;
end

function r=record_timeseries(ts)
assert(isa(ts,'timeseries'),'A3R9:LogType','Expected timeseries, got %s.',class(ts));
r=struct('time',double(ts.Time(:)),'data',double(ts.Data), ...
    'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));
end
function value=macro_value(text,key)
token=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(token),'A3R9:CarSimMacroMissing','CarSim entry missing: %s',key);
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
evalin('base',['clear test_speed test_steer_amplitude ' ...
    'test_steer_frequency vy_v17_mode_code']);
end
function hash=sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=upper(reshape(dec2hex(bytes,2).',1,[]));
clear c
end
