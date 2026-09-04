function report = run_vy_kkf_v2_1g0_steer_smoke()
%RUN_VY_KKF_V2_1G0_STEER_SMOKE Execute the one authorized 2 s G0 run.
root=fileparts(fileparts(mfilename('fullpath'))); resultFile=fullfile(root,'results','vy_kkf_v2_1g0_steer_smoke.mat');
source=fullfile(root,'model','vx_vy_kkf_v2_1.slx'); target=fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx');
report=struct('stage','V2.1-G0 active steering injection 2 s smoke','stopTime_s',2, ...
    'nominal',struct('Vx_mps',20,'steerAmplitude_rad',0.04,'steerFrequency_Hz',0.4), ...
    'simulationCompleted',false,'simCalled',false,'carSimRun',false, ...
    'runtimeError',struct('identifier','','message','','report',''));
report.frozenHashBefore=file_sha256(source); report.build=struct();
oldPath=path; oldPwd=pwd; mdl='vx_vy_kkf_v2_1g_steer'; clean=onCleanup(@()cleanup(mdl,oldPwd,oldPath)); console='';
try
 report.build=build_vy_kkf_v2_1g_steer();
 addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers'); addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+'); addpath(fullfile(root,'model')); cd(fullfile(root,'model'));
 load_system('Solver_SF'); load_system(target); w=get_param(mdl,'ModelWorkspace');
 assignin(w,'test_speed',20); assignin(w,'test_steer_amplitude',0.04); assignin(w,'test_steer_frequency',0.4);
 assignin('base','test_speed',20); assignin('base','test_steer_amplitude',0.04); assignin('base','test_steer_frequency',0.4);
 report.simCalled=true; console=evalc("out=sim(mdl,'StopTime','2','ReturnWorkspaceOutputs','on','FastRestart','off');"); fprintf('%s',console);
 report.carSimRun=contains(console,'Use vehicle solver:') && contains(console,'Termination at simulation time');
 names=report.build.logVariables; raw=struct(); for k=1:numel(names), raw.(names{k})=rec(out.get(names{k})); end; report.raw=raw; report.simulationCompleted=true;
catch ME
 report.runtimeError.identifier=ME.identifier; report.runtimeError.message=ME.message; report.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end
report.consoleText=console; report.frozenHashAfter=file_sha256(source); report.frozenHashUnchanged=strcmp(report.frozenHashBefore,report.frozenHashAfter); if isfile(target),report.newModelHash=file_sha256(target);else,report.newModelHash='';end
cleanup(mdl,oldPwd,oldPath); clear clean; save(resultFile,'report','-v7.3');
 if ~report.simulationCompleted, error('VY_KKF:G0RuntimeFailed','2 s smoke failed; evidence saved to %s',resultFile); end
 assert(report.frozenHashUnchanged,'Frozen model hash changed during G0.');
 assert(report.carSimRun,'CarSim runtime completion evidence was not found.');
end
function r=rec(ts), assert(isa(ts,'timeseries'),'Expected timeseries.'); r=struct('time',double(ts.Time(:)),'data',double(ts.Data),'sampleCount',numel(ts.Time),'dataSize',size(ts.Data)); end
function h=file_sha256(file), d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=lower(reshape(dec2hex(b,2).',1,[]));clear c,end
function cleanup(mdl,oldPwd,oldPath), if bdIsLoaded(mdl),close_system(mdl,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(oldPwd);path(oldPath);evalin('base','clear test_speed test_steer_amplitude test_steer_frequency');end
