function report = run_vy_parallel_dk_v2_3d_nominal_validation()
%RUN_VY_PARALLEL_DK_V2_3D_NOMINAL_VALIDATION One authorized 16-s run.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
target=fullfile(md,'vx_vy_parallel_dk_v2_3.slx');simFile=fullfile(md,'simfile.sim');
outFile=fullfile(root,'results','vy_parallel_dk_v2_3d_nominal_validation.mat');
model='vx_vy_parallel_dk_v2_3';
assert(~isfile(outFile),'V2.3-D result already exists; duplicate 16-s runtime refused.');
report=struct('stage','V2.3-D parallel D/K 16-s genuine nominal validation', ...
    'stopTimeRequested_s',16,'nominal',struct('Vx_mps',20, ...
    'steerAmplitude_rad',0.02,'steerFrequency_Hz',0.4,'rearSteer_rad',[0 0]), ...
    'simCalled',false,'simulationCompleted',false,'carSimRun',false, ...
    'runtimeError',struct('identifier','','message','','report',''), ...
    'raw',struct(),'consoleText','');
[frozenFiles,expectedHashes]=frozen_manifest(root);
report.frozenBefore=hash_files(frozenFiles);
assert(hashes_match(report.frozenBefore,expectedHashes), ...
    'Frozen hash mismatch before V2.3-D runtime.');
report.targetHashBefore=sha256(target);
assert(strcmpi(report.targetHashBefore, ...
    '98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0'), ...
    'Formal parallel target hash mismatch before V2.3-D runtime.');

formalFile=fullfile(root,'results','vy_parallel_dk_v2_3b_integration_gates.mat');
harnessFile=fullfile(root,'results','vy_parallel_dk_v2_3b2_compile_gates.mat');
cFile=fullfile(root,'results','vy_parallel_dk_v2_3c_preflight.mat');
assert(isfile(formalFile)&&isfile(harnessFile)&&isfile(cFile), ...
    'Required V2.3-B/B2/C evidence is missing.');
F=load(formalFile,'report');H=load(harnessFile,'report');C=load(cFile,'report');
assert(F.report.staticPassed&&F.report.staticGateCount==41&&F.report.staticGatesTrue==41);
assert(H.report.staticPassed&&H.report.staticGateCount==38&&H.report.staticGatesTrue==38&& ...
    H.report.compile.passed&&H.report.compiledGateCount==15&&H.report.compiledGatesTrue==15);
assert(C.report.analysis.pass,'Accepted V2.3-C runtime evidence is invalid.');
report.priorEvidence=struct('formalStatic',[41 41],'harnessStatic',[38 38], ...
    'compiled',[15 15],'v23cPassed',true);

oldPwd=pwd;oldPath=path;clean=onCleanup(@()cleanup(model,oldPwd,oldPath));console='';
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers';
    solverSfDir=fullfile(solverDir,'Matlab84+');solverDll=fullfile(solverDir,'carsim_64.dll');
    solverLibrary=fullfile(solverSfDir,'Solver_SF.slx');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(solverLibrary), ...
        'Required D: CarSim runtime file is missing.');
    simText=fileread(simFile);
    report.carSim=struct('pwd','','activeSimfile',simFile, ...
        'progDir',macro_value(simText,'PROGDIR'),'dataDir',macro_value(simText,'DATADIR'), ...
        'solverExpected',solverDll,'solverActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'),'gRequestConsole',false);
    assert(strcmpi(report.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(report.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&& ...
        ~report.carSim.gRequestBefore,'Active simfile is not the accepted D: configuration.');
    addpath(md);addpath(solverDir);addpath(solverSfDir);
    Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,'vy_parallel_dk_v2_3d_cache'), ...
        'CodeGenFolder',fullfile(tempdir,'vy_parallel_dk_v2_3d_codegen'),'createDir',true);
    cd(md);report.carSim.pwd=pwd;report.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    assert(strcmpi(report.carSim.activeSimfile,simFile),'MATLAB cwd does not select model/simfile.sim.');
    load_system('Solver_SF');load_system(target);
    logVariables={'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg', ...
        'steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg', ...
        'reset_g0','avz_imu_g0','kkf_u_log1','kkf_x_log1','kkf_P_log1', ...
        'kkf_diag_log1','dekf_x_log','dekf_P_log','dekf_diag_log', ...
        'parallel_input_log','Vx_true_log','vy_true_log1','avz_log1'};
    report.static=static_preflight(model,logVariables);
    assert(report.static.pass,'V2.3-D target/log/routing/truth static preflight failed.');
    w=get_param(model,'ModelWorkspace');
    assignin(w,'test_speed',20);assignin(w,'test_steer_amplitude',0.02);
    assignin(w,'test_steer_frequency',0.4);assignin(w,'vy_v17_mode_code',20);
    assignin('base','test_speed',20);assignin('base','test_steer_amplitude',0.02);
    assignin('base','test_steer_frequency',0.4);assignin('base','vy_v17_mode_code',20);
    clear vy_dynamic_ekf_v1_17 vy_kinematic_kf
    report.simCalled=true;
    console=evalc("out=sim(model,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');");
    fprintf('%s',console);report.consoleText=console;
    report.carSim.solverActual=solver_path_from_console(console);
    report.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    report.carSimRun=contains(console,'Termination at simulation time = 16 s')&& ...
        strcmpi(report.carSim.solverActual,solverDll)&&~report.carSim.gRequestConsole;
    assert(report.carSimRun,'Authorized 16-s CarSim completion evidence missing.');
    for k=1:numel(logVariables)
        name=logVariables{k};report.raw.(name)=record_timeseries(out.get(name));
    end
    report.stopTimeActual_s=max(report.raw.dekf_x_log.time(end),report.raw.kkf_x_log1.time(end));
    report.simulationCompleted=true;
catch ME
    report.consoleText=console;report.runtimeError.identifier=ME.identifier;
    report.runtimeError.message=ME.message;
    report.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end
cleanup(model,oldPwd,oldPath);clear clean
report.targetHashAfter=sha256(target);
report.targetHashUnchanged=strcmpi(report.targetHashBefore,report.targetHashAfter);
report.frozenAfter=hash_files(frozenFiles);
report.allFrozenHashesUnchanged=hashes_match(report.frozenAfter,expectedHashes);
save(outFile,'report','-v7.3');
if ~report.simulationCompleted
    error('VY_PARALLEL_DK:V23DRuntimeFailed', ...
        'V2.3-D runtime failed; evidence saved to %s',outFile);
end
assert(report.targetHashUnchanged&&report.allFrozenHashesUnchanged, ...
    'A formal/frozen file changed during V2.3-D.');
fprintf(['V23D_RUNTIME_OK|simCalled=%d|completed=%d|carSim=%d|stop=%.17g|' ...
    'solver=%s|gRequest=%d|targetUnchanged=%d\n'],report.simCalled, ...
    report.simulationCompleted,report.carSimRun,report.stopTimeActual_s, ...
    report.carSim.solverActual,report.carSim.gRequestBefore||report.carSim.gRequestConsole, ...
    report.targetHashUnchanged);
end

function audit=static_preflight(m,names)
audit=struct();audit.logVariables=names;audit.logPaths=cell(size(names));loggingOK=true;
for k=1:numel(names)
    b=find_system(m,'SearchDepth',1,'BlockType','ToWorkspace','VariableName',names{k});
    audit.logPaths{k}=b;loggingOK=loggingOK&&numel(b)==1;
end
audit.loggingOK=loggingOK;
audit.truth=struct('Vx',source_info(m,'Vx_true_log'),'Vy',source_info(m,'vy_true_log1'), ...
    'rDeg',source_info(m,'avz_log1'),'units',struct('Vx','m/s','Vy','m/s', ...
    'rLogged','deg/s','rOfflineConverted','rad/s'));
audit.truthProvenanceOK=endsWith(audit.truth.Vx.sourceBlock,'/Gain38')&& ...
    endsWith(audit.truth.Vy.sourceBlock,'/Gain11')&& ...
    endsWith(audit.truth.rDeg.sourceBlock,'/Demux4')&&audit.truth.rDeg.sourcePort==2&& ...
    strcmp(get_param([m '/Gain38'],'Gain'),'1/3.6')&&strcmp(get_param([m '/Gain11'],'Gain'),'1/3.6');
audit.kAxSource=source_of([m '/K-KF IMU Mux'],1);
audit.kAySource=source_of([m '/K-KF IMU Mux'],2);
audit.kAvzSource=source_of([m '/K-KF IMU Mux'],3);
audit.kVxSource=source_of([m '/K-KF Vx RT 100Hz'],1);
audit.dVxSource=source_of([m '/Parallel D Control Mux'],1);
audit.dSteeringSource=source_of([m '/Parallel D Control Mux'],2);
audit.dAySource=source_of([m '/Parallel D Measurement Mux'],1);
audit.dAvzSource=source_of([m '/Parallel D Measurement Mux'],2);
audit.sharedSources=cell(1,6);
for k=1:6,audit.sharedSources{k}=source_of([m '/Parallel Physical Input Log Mux'],k);end
audit.dSteerWheelSources=cell(1,4);
for k=1:4,audit.dSteerWheelSources{k}=source_of([m '/Parallel D Steering Mux'],k);end
audit.dScheduler=source_of_trigger([m '/Parallel D-EKF 100Hz']);
audit.kScheduler=source_of_trigger([m '/K-KF 100Hz']);
audit.schedulersIndependent=~strcmp(audit.dScheduler,audit.kScheduler);
audit.sharedRoutingOK=strcmp(audit.kAxSource,audit.sharedSources{1})&& ...
    strcmp(audit.kAySource,audit.sharedSources{2})&&strcmp(audit.kAvzSource,audit.sharedSources{3})&& ...
    strcmp(audit.kVxSource,audit.sharedSources{4})&&strcmp(audit.dVxSource,audit.sharedSources{4})&& ...
    strcmp(audit.dAySource,audit.sharedSources{2})&&strcmp(audit.dAvzSource,audit.sharedSources{3})&& ...
    strcmp(audit.dSteeringSource,[m '/Parallel D Steering Mux'])&& ...
    strcmp(audit.sharedSources{5},[m '/Parallel D Steering Mux']);
audit.steeringWheelRoutingOK=strcmp(audit.dSteerWheelSources{1},[m '/G0 Steer Cmd Rad'])&& ...
    strcmp(audit.dSteerWheelSources{2},[m '/G0 Steer Cmd Rad'])&& ...
    strcmp(audit.dSteerWheelSources{3},[m '/Parallel D Rear Steer Zero Rad'])&& ...
    strcmp(audit.dSteerWheelSources{4},[m '/Parallel D Rear Steer Zero Rad']);
cmd=[m '/G0 Steer Cmd Rad'];gain=[m '/Gain22'];sw=[m '/Manual Switch1'];
audit.steerSource=struct('amplitude',get_param(cmd,'Amplitude'), ...
    'frequency',get_param(cmd,'Frequency'),'phase',get_param(cmd,'Phase'));
audit.radToDegGain=get_param(gain,'Gain');
audit.manualSwitch=struct('sw',get_param(sw,'sw'),'currentSetting',get_param(sw,'CurrentSetting'));
audit.genuineSteeringDefinitionOK=strcmp(audit.steerSource.amplitude,'test_steer_amplitude')&& ...
    strcmp(audit.steerSource.frequency,'2*pi*test_steer_frequency')&& ...
    strcmp(strtrim(audit.radToDegGain),'180/pi')&&strcmp(audit.manualSwitch.sw,'0')&& ...
    strcmp(audit.manualSwitch.currentSetting,'0');
audit.trueVyOnline=false;
audit.pass=audit.loggingOK&&audit.truthProvenanceOK&&audit.sharedRoutingOK&& ...
    audit.steeringWheelRoutingOK&&audit.schedulersIndependent&& ...
    audit.genuineSteeringDefinitionOK&&~audit.trueVyOnline;
end
function s=source_info(m,varName)
b=find_system(m,'SearchDepth',1,'BlockType','ToWorkspace','VariableName',varName);
assert(numel(b)==1,'Expected one To Workspace source for %s.',varName);
ph=get_param(b{1},'PortHandles');line=get_param(ph.Inport(1),'Line');assert(line>0);
src=get_param(line,'SrcBlockHandle');srcPort=get_param(line,'SrcPortHandle');
pn=get_param(srcPort,'PortNumber');if ischar(pn)||isstring(pn),pn=str2double(pn);else,pn=double(pn);end
s=struct('variable',varName,'logBlock',b{1},'sourceBlock',getfullname(src),'sourcePort',pn);
end
function src=source_of(block,port)
ph=get_param(block,'PortHandles');lh=get_param(ph.Inport(port),'Line');assert(lh>0);
src=getfullname(get_param(lh,'SrcBlockHandle'));
end
function src=source_of_trigger(block)
ph=get_param(block,'PortHandles');lh=get_param(ph.Trigger(1),'Line');assert(lh>0);
src=getfullname(get_param(lh,'SrcBlockHandle'));
end
function r=record_timeseries(ts)
assert(isa(ts,'timeseries'),'Expected timeseries, got %s.',class(ts));
r=struct('time',double(ts.Time(:)),'data',double(ts.Data),'sampleCount',numel(ts.Time), ...
    'dataSize',size(ts.Data),'dataClass',class(ts.Data));
end
function value=macro_value(text,key)
token=regexp(text,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');
assert(~isempty(token),'CarSim config entry missing: %s',key);value=strtrim(token{1});
end
function p=solver_path_from_console(text)
token=regexp(text,'Use vehicle solver:\s*([^\r\n]+)','tokens','once');
if isempty(token),p='';else,p=strtrim(token{1});end
end
function cleanup(m,oldPwd,oldPath)
if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
cd(oldPwd);path(oldPath);evalin('base',['clear test_speed test_steer_amplitude ' ...
    'test_steer_frequency vy_v17_mode_code']);
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx'); ...
    fullfile(root,'model','vx_vy_dekf_v1_17.slx');fullfile(root,'model','vy_dynamic_ekf_v1_17.m'); ...
    fullfile(root,'model','vy_dynamic_ekf_step_v17.m');fullfile(root,'model','vy_dynamic_ekf_step_v13.m'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1.slx');fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx'); ...
    fullfile(root,'model','vy_kinematic_kf_step.m');fullfile(root,'model','vy_kinematic_kf.m'); ...
    fullfile(root,'model','vx_vy_dkekf_v2_2.slx');fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
    fullfile(root,'model','vy_dkekf_baseline.m');fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m')};
hashes={'98461db290723a5ccdf62398ce5063de0c9b6c7586334d479b159a771eb128c0'; ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
    '5550d0389fc4d1dcf7f65b0e00b4c51a949f2b9add33c2d78d1122a31291a1a0'; ...
    '4010f6a4bd669ac048297c2f416f0b8826f729f4552d73445703184f052c4a4f'; ...
    '498a446e13e654387e3d36bf4694a336e75b2100e765dac0414a01367531cde4'; ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712'; ...
    '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e'; ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244'; ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'; ...
    'e768fb2ad33a6eeaabde2fb7c40be660b78f350a90c752327dc9b423f50f2e15'; ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457'; ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'; ...
    '12f0d82643d65aa5098ed20c0655234f3a2e7ef6d6f5e7dee5b80bc1a201bda1'};
end
function records=hash_files(files)
records=repmat(struct('path','','sha256',''),numel(files),1);
for k=1:numel(files),records(k)=struct('path',files{k},'sha256',sha256(files{k}));end
end
function ok=hashes_match(records,expected)
ok=numel(records)==numel(expected);for k=1:numel(records),ok=ok&&strcmpi(records(k).sha256,expected{k});end
end
function h=sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
b=typecast(d.digest(),'uint8');h=lower(reshape(dec2hex(b,2).',1,[]));clear c
end
