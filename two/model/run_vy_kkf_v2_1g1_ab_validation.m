function summary = run_vy_kkf_v2_1g1_ab_validation()
%RUN_VY_KKF_V2_1G1_AB_VALIDATION Run exactly the authorized G1 A/B cases.

root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx');
baseFile = fullfile(root,'model','vx_vy_kkf_v2_1.slx');
resultA = fullfile(root,'results','vy_kkf_v2_1g1_nominal_002.mat');
resultB = fullfile(root,'results','vy_kkf_v2_1g1_highyaw_004.mat');
solverDir = 'D:\carsim\CarSim2021.0_Prog\Programs\solvers';
solverSfDir = fullfile(solverDir,'Matlab84+');
modelName = 'vx_vy_kkf_v2_1g_steer';

expectedBase = 'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712';
expectedSteer = '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e';
assert(strcmp(file_sha256(baseFile),expectedBase),'Frozen base model hash mismatch.');
assert(strcmp(file_sha256(modelFile),expectedSteer),'G0 steering model hash mismatch.');

oldPath = path; oldFolder = pwd;
cleanup = onCleanup(@()cleanup_runtime(modelName,oldFolder,oldPath));
addpath(solverDir); addpath(solverSfDir); addpath(fullfile(root,'model'));
cd(fileparts(modelFile));
Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,'vy_kkf_v2_1g1_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_kkf_v2_1g1_codegen'),'createDir',true);
load_system('Solver_SF'); load_system(modelFile);

static = static_gate(modelName);
assert(static.pass,'G1 static steering gate failed.');
enable_port_logging([modelName '/Gain38'],'kkf_vx_true_g1');
enable_port_logging([modelName '/Gain11'],'kkf_vy_true_g1');
wks = get_param(modelName,'ModelWorkspace');

caseA = run_case(modelName,wks,0.02,'G1-A genuine 0.02 rad',baseFile,modelFile, ...
    expectedBase,expectedSteer,static);
save_case(resultA,caseA);
assert(caseA.simulationCompleted && caseA.carSimRun,'G1-A runtime failed; B was not run.');
assert(caseA.steeringGate.pass,'G1-A steering gate failed; B was not run.');

caseB = run_case(modelName,wks,0.04,'G1-B genuine 0.04 rad',baseFile,modelFile, ...
    expectedBase,expectedSteer,static);
save_case(resultB,caseB);
assert(caseB.simulationCompleted && caseB.carSimRun,'G1-B runtime failed.');
assert(caseB.steeringGate.pass,'G1-B steering gate failed.');

cleanup_runtime(modelName,oldFolder,oldPath); clear cleanup
assert(strcmp(file_sha256(baseFile),expectedBase),'Frozen base model changed after G1.');
assert(strcmp(file_sha256(modelFile),expectedSteer),'G0 steering model changed after G1.');
summary = struct('stage','V2.1-G1 genuine steering A/B runtime', ...
    'caseAFile',resultA,'caseBFile',resultB,'caseAValid',caseA.steeringGate.pass, ...
    'caseBValid',caseB.steeringGate.pass,'runtimeCount',2, ...
    'baseHashAfter',file_sha256(baseFile),'steerHashAfter',file_sha256(modelFile));
fprintf('V2_1G1_RUNTIME_OK|A=%d|B=%d|runs=2|base=%s|steer=%s\n', ...
    summary.caseAValid,summary.caseBValid,summary.baseHashAfter,summary.steerHashAfter);
end

function report = run_case(modelName,wks,amplitude,label,baseFile,modelFile,expectedBase,expectedSteer,static)
report = struct('stage',label,'stopTime_s',16,'condition',struct( ...
    'Vx_mps',20,'steerAmplitude_rad',amplitude,'steerFrequency_Hz',0.4), ...
    'simulationCompleted',false,'simCalled',false,'carSimRun',false, ...
    'runtimeError',struct('identifier','','message','','report',''), ...
    'trueVyOnlineUsed',false,'trueVyUse','offline validation only', ...
    'trueVxUse','temporary K-KF isolation measurement and offline reference', ...
    'qrP0TuningPerformed',false,'onlineBiasCorrectionImplemented',false, ...
    'fusionPerformed',false,'v2_2Started',false,'staticGate',static);
report.baseHashBefore = file_sha256(baseFile);
report.steerHashBefore = file_sha256(modelFile);
console = '';
try
    assignin(wks,'test_speed',20); assignin(wks,'test_steer_amplitude',amplitude);
    assignin(wks,'test_steer_frequency',0.4);
    assignin('base','test_speed',20); assignin('base','test_steer_amplitude',amplitude);
    assignin('base','test_steer_frequency',0.4);
    report.simCalled = true;
    console = evalc("out=sim(modelName,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off','SignalLogging','on','SignalLoggingName','logsout');");
    fprintf('%s',console);
    report.carSimRun = contains(console,'Use vehicle solver:') && ...
        contains(console,'Termination at simulation time = 16 s');
    names = {'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg', ...
        'steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg', ...
        'avz_imu_g0','reset_g0','kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
    raw = struct();
    for k=1:numel(names), raw.(names{k})=record(output_timeseries(out,names{k})); end
    raw.vx_true_offline = record(logged_timeseries(out,'kkf_vx_true_g1'));
    raw.vy_true_offline = record(logged_timeseries(out,'kkf_vy_true_g1'));
    report.raw = raw;
    report.simulationCompleted = true;
    report.steeringGate = steering_gate(raw,amplitude,0.4);
catch ME
    report.runtimeError.identifier=ME.identifier; report.runtimeError.message=ME.message;
    report.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
    report.steeringGate=struct('pass',false);
end
report.consoleText=console;
report.baseHashAfter=file_sha256(baseFile); report.steerHashAfter=file_sha256(modelFile);
report.baseHashUnchanged=strcmp(report.baseHashBefore,report.baseHashAfter) && strcmp(report.baseHashAfter,expectedBase);
report.steerHashUnchanged=strcmp(report.steerHashBefore,report.steerHashAfter) && strcmp(report.steerHashAfter,expectedSteer);
report.modelFilesUnchanged=report.baseHashUnchanged&&report.steerHashUnchanged;
if report.simulationCompleted
    report.steeringGate.pass=report.steeringGate.pass&&report.carSimRun&&report.modelFilesUnchanged;
end
end

function g = static_gate(m)
sw=[m '/Manual Switch1']; mux=[m '/Mux8']; gain=[m '/Gain22'];
ph=get_param(sw,'PortHandles'); src=cell(1,2);
for k=1:2, l=get_param(ph.Inport(k),'Line'); src{k}=getfullname(get_param(l,'SrcBlockHandle')); end
mph=get_param(mux,'PortHandles'); rear=zeros(1,2); ports=[6 8];
for k=1:2, l=get_param(mph.Inport(ports(k)),'Line'); h=get_param(l,'SrcBlockHandle'); rear(k)=str2double(get_param(h,'Value')); end
g=struct('input1Source',src{1},'input2Source',src{2},'sw',get_param(sw,'sw'), ...
    'currentSetting',get_param(sw,'CurrentSetting'),'gain22',get_param(gain,'Gain'), ...
    'rearMux8Values',rear,'selectedInput',2,'selectedSource',src{2});
g.pass=endsWith(src{1},'/Mux5')&&endsWith(src{2},'/Mux8')&&strcmp(g.sw,'0')&& ...
    strcmp(g.currentSetting,'0')&&strcmp(g.gain22,'180/pi')&&all(rear==0);
end

function g = steering_gate(r,amplitude,frequency)
fields={'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg', ...
    'steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg'};
t=cellfun(@(n)r.(n).time(:),fields,'UniformOutput',false);
v=cellfun(@(n)double(r.(n).data(:)),fields,'UniformOutput',false);
cmd=v{1}; deg=v{2}; fl=v{3}; fr=v{4}; rl=v{5}; rr=v{6}; nz=abs(cmd)>1e-10;
ratio=deg(nz)./cmd(nz); f=fit_frequency(t{1},cmd);
g=struct('sampleCounts',cellfun(@numel,t),'timesAligned',isequal(t{:}), ...
    'steerCmdMaxAbs_rad',max(abs(cmd)),'steerToCarSimMaxAbs_deg',max(abs(deg)), ...
    'flMaxAbs_deg',max(abs(fl)),'frMaxAbs_deg',max(abs(fr)), ...
    'rlMaxAbs_deg',max(abs(rl)),'rrMaxAbs_deg',max(abs(rr)), ...
    'flFrMaxAbsDiff',max(abs(fl-fr)),'flCommandMaxAbsDiff',max(abs(fl-deg)), ...
    'frCommandMaxAbsDiff',max(abs(fr-deg)),'radToDegRatioMedian',median(ratio), ...
    'radToDegRatioMaxError',max(abs(ratio-180/pi)),'frequency_Hz',f);
g.frontCommandApplied=g.timesAligned&&g.flFrMaxAbsDiff<1e-12&& ...
    g.flCommandMaxAbsDiff<1e-12&&g.frCommandMaxAbsDiff<1e-12&& ...
    g.flMaxAbs_deg>1e-8&&g.frMaxAbs_deg>1e-8;
g.rearZero=g.rlMaxAbs_deg<1e-12&&g.rrMaxAbs_deg<1e-12;
g.pass=abs(g.steerCmdMaxAbs_rad-amplitude)<1e-9&& ...
    abs(g.steerToCarSimMaxAbs_deg-amplitude*180/pi)<1e-9&& ...
    g.radToDegRatioMaxError<1e-10&&abs(f-frequency)<1e-5&& ...
    g.frontCommandApplied&&g.rearZero;
end

function enable_port_logging(blockPath,logName)
p=get_param(blockPath,'PortHandles'); assert(isscalar(p.Outport),'Expected scalar output.');
assert(get_param(p.Outport(1),'Line')>0,'Output line unavailable: %s',blockPath);
set_param(p.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',logName);
end
function r=record(ts),assert(isa(ts,'timeseries'),'Expected timeseries.');r=struct('time',double(ts.Time(:)),'data',double(ts.Data),'sampleCount',numel(ts.Time),'dataSize',size(ts.Data),'dataClass',class(ts.Data));end
function ts=output_timeseries(out,n),ts=out.get(n);assert(isa(ts,'timeseries'),'Missing/non-timeseries output: %s',n);end
function ts=logged_timeseries(out,n),d=out.get('logsout');e=d.getElement(n);assert(~isempty(e),'Missing logged signal: %s',n);ts=e.Values;assert(isa(ts,'timeseries'),'Logged signal is not timeseries.');end
function f=fit_frequency(t,y),f=fminbnd(@(q)freq_error(q,t,y),0.1,1.0);end
function e=freq_error(f,t,y),A=[sin(2*pi*f*t(:)),cos(2*pi*f*t(:))];z=A\y(:);e=norm(A*z-y(:))^2;end
function save_case(file,caseReport),report=caseReport;save(file,'report','-v7.3');end
function h=file_sha256(file),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=lower(reshape(dec2hex(b,2).',1,[]));clear c,end
function cleanup_runtime(m,folder,oldPath),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(folder);path(oldPath);evalin('base','clear test_speed test_steer_amplitude test_steer_frequency');end
