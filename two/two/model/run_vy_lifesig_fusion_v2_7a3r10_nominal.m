function runtime = run_vy_lifesig_fusion_v2_7a3r10_nominal()
%RUN_VY_LIFESIG_FUSION_V2_7A3R10_NOMINAL One authorized 16-s validation.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
target=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
simFile=fullfile(md,'simfile.sim');
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r10_nominal.mat');
model='vx_vy_lifesig_fusion_v2_7';
targetExpected='65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0';
coreFile=fullfile(md,'vy_lifesig_fusion_step.m');
wrapperFile=fullfile(md,'vy_lifesig_fusion_simulink_sfun.m');
coreExpected='3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA';
wrapperExpected='E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445';
assert(~isfile(resultFile),'A3R10:ResultExists', ...
    'A3R10 evidence already exists; a second runtime is not authorized.');

compileFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r8_compile.mat');
smokeFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r9_smoke.mat');
C=load(compileFile,'report');S=load(smokeFile,'smoke');
assert(C.report.passed&&S.smoke.passed,'A3R10:PrerequisiteNotAccepted', ...
    'A3R8 compile acceptance or A3R9 smoke acceptance is missing.');

runtime=struct();runtime.stage='V2.7-A3R10';
runtime.role='NON_HOLDOUT_NOMINAL_ENGINEERING_VALIDATION';
runtime.condition=struct('stopTime_s',16,'speed_mps',20, ...
    'steerAmplitude_rad',0.02,'steerFrequency_Hz',0.4,'rate_Hz',100);
runtime.prerequisites=struct('A3R8CompilePassed',true,'A3R9SmokePassed',true);
runtime.simCalled=false;runtime.simInvocationCount=0;
runtime.simulationCompleted=false;runtime.carSimRun=false;
runtime.runtimeError=struct('identifier','','message','','report','');
runtime.consoleText='';runtime.raw=struct();
runtime.targetHashBefore=sha256(target);runtime.coreHashBefore=sha256(coreFile);
runtime.wrapperHashBefore=sha256(wrapperFile);
assert(strcmp(runtime.targetHashBefore,targetExpected)&& ...
    strcmp(runtime.coreHashBefore,coreExpected)&&strcmp(runtime.wrapperHashBefore,wrapperExpected), ...
    'A3R10:FrozenHashMismatch','A3R10 target/core/wrapper hash mismatch.');

oldPwd=pwd;oldPath=path;cleanupObj=onCleanup(@()cleanup(model,oldPwd,oldPath));
console='';
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
    solverSfDir=fullfile(solverDir,'Matlab84+');
    solverDll=fullfile(solverDir,'carsim_64.dll');
    solverLibrary=fullfile(solverSfDir,'Solver_SF.slx');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(solverLibrary), ...
        'A3R10:CarSimFileMissing','Required D: CarSim runtime file is missing.');
    simText=fileread(simFile);
    runtime.carSim=struct('pwd','','activeSimfile',simFile, ...
        'progDir',macro_value(simText,'PROGDIR'), ...
        'dataDir',macro_value(simText,'DATADIR'), ...
        'solverExpected',solverDll,'solverActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'), ...
        'gRequestConsole',false);
    assert(strcmpi(runtime.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(runtime.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&& ...
        ~runtime.carSim.gRequestBefore,'A3R10:CarSimLineageMismatch', ...
        'Active simfile is not the accepted D: CarSim lineage.');

    addpath(md);addpath(solverDir);addpath(solverSfDir);
    Simulink.fileGenControl('set','CacheFolder', ...
        fullfile(tempdir,'vy_lifesig_v2_7a3r10_cache'), ...
        'CodeGenFolder',fullfile(tempdir,'vy_lifesig_v2_7a3r10_codegen'), ...
        'createDir',true);
    cd(md);runtime.carSim.pwd=pwd;runtime.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    assert(strcmpi(runtime.carSim.activeSimfile,simFile),'A3R10:WorkingDirectoryMismatch', ...
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
    runtime.requiredLogs=requiredLogs(:);
    runtime.static=static_preflight(model,requiredLogs);
    assert(runtime.static.passed,'A3R10:StaticPreflightFailed', ...
        'LifeSig nominal static preflight failed.');

    w=get_param(model,'ModelWorkspace');
    assignin(w,'test_speed',20);assignin(w,'test_steer_amplitude',0.02);
    assignin(w,'test_steer_frequency',0.4);assignin(w,'vy_v17_mode_code',20);
    assignin('base','test_speed',20);assignin('base','test_steer_amplitude',0.02);
    assignin('base','test_steer_frequency',0.4);assignin('base','vy_v17_mode_code',20);
    clear vy_dynamic_ekf_v1_17_reliability_numeric vy_kinematic_kf

    runtime.simCalled=true;runtime.simInvocationCount=1;
    console=evalc("out=sim(model,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');");
    fprintf('%s',console);runtime.consoleText=console;
    runtime.carSim.solverActual=solver_path_from_console(console);
    runtime.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    runtime.carSimRun=contains(console,'Termination at simulation time')&& ...
        strcmpi(runtime.carSim.solverActual,solverDll)&&~runtime.carSim.gRequestConsole;
    assert(runtime.carSimRun,'A3R10:CarSimCompletionMissing', ...
        'Authorized CarSim runtime completion evidence is missing.');
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
runtime.targetHashAfter=sha256(target);runtime.coreHashAfter=sha256(coreFile);
runtime.wrapperHashAfter=sha256(wrapperFile);
runtime.hashesUnchanged=strcmp(runtime.targetHashBefore,runtime.targetHashAfter)&& ...
    strcmp(runtime.coreHashBefore,runtime.coreHashAfter)&& ...
    strcmp(runtime.wrapperHashBefore,runtime.wrapperHashAfter);
save(resultFile,'runtime','-v7.3');
if ~runtime.simulationCompleted
    error('A3R10:RuntimeFailed','A3R10 runtime failed; evidence saved to %s.\n%s', ...
        resultFile,runtime.runtimeError.report);
end
assert(runtime.hashesUnchanged,'A3R10:HashChanged', ...
    'LifeSig target/core/wrapper changed during nominal runtime.');
fprintf('A3R10_RUNTIME|sim=1|completed=1|carsim=1|targetUnchanged=1|logs=%d\n', ...
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
assert(isa(ts,'timeseries'),'A3R10:LogType','Expected timeseries, got %s.',class(ts));
r=struct('time',double(ts.Time(:)),'data',double(ts.Data), ...
    'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));
end
function value=macro_value(text,key)
token=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(token),'A3R10:CarSimMacroMissing','CarSim entry missing: %s',key);
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
