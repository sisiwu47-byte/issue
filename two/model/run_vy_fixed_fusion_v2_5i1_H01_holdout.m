function report = run_vy_fixed_fusion_v2_5i1_H01_holdout()
%RUN_VY_FIXED_FUSION_V2_5I1_H01_HOLDOUT Execute only the frozen H01 holdout.
% One protected simulation call is present; no second execution or alternate target.

root=fileparts(fileparts(mfilename('fullpath'))); md=fullfile(root,'model');
modelName='vx_vy_fixed_fusion_v2_5'; target=fullfile(md,'vx_vy_fixed_fusion_v2_5.slx');
simFile=fullfile(md,'simfile.sim');
preregFile=fullfile(root,'results','vy_fixed_fusion_v2_5i_holdout_preexecution_registry.csv');
weightFile=fullfile(root,'results','vy_fixed_fusion_v2_5h2_runtime_weight_manifest.csv');
targetExpected='AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B';
coreExpected='4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C';
wrapperExpected='B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A';
set2Path=fullfile(root,'ddux','schemas','SL_PERFORMANCE_STARTUP.jsonrsa');

assert(isfile(preregFile)&&isfile(weightFile),'V25I1:Lineage','Frozen H01 preregistration/weight evidence is missing.');
pre=readtable(preregFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
assert(height(pre)==3&&all(pre.role=="HOLDOUT_VALIDATION"), ...
    'V25I1:Preregistration','H01-H03 preregistration is not the frozen three-row registry.');
h01=pre(pre.execution_order==1,:); assert(height(h01)==1,'V25I1:Identity','Execution order 1 must identify exactly one H01 row.');
runId=string(h01.run_id); assert(~any(pre.execution_order==2 & pre.run_id==runId)&&~any(pre.execution_order==3 & pre.run_id==runId), ...
    'V25I1:Identity','Frozen H01 identity overlaps H02/H03.');
assert(h01.original_status=="PLANNED_NOT_RUN"&&h01.runtime_authorization=="UNCONSUMED"&& ...
    h01.data_viewed=="FALSE"&&string(h01.runtime_count)=="0", ...
    'V25I1:Untouched','H01 is not untouched before runtime.');
for k=1:height(pre)
    p=fullfile(root,strrep(char(pre.formal_result_path(k)),'/',filesep));
    if pre.execution_order(k)==1, resultFile=p; else
        assert(~isfile(p)&&pre.data_viewed(k)=="FALSE"&&string(pre.runtime_count(k))=="0"&& ...
            pre.runtime_authorization(k)=="UNCONSUMED",'V25I1:Isolation','H02/H03 is not untouched.');
    end
end
assert(~isfile(resultFile),'V25I1:ResultExists','Formal H01 result already exists; overwrite is prohibited.');
assert(strcmpi(sha256(target),targetExpected),'V25I1:Target','Frozen formal target hash mismatch before simulation.');
w=readtable(weightFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string'); assert(height(w)==1&&w.weight_set_id=="V25_FIXED_WEIGHT_ALPHA_V1",'V25I1:Weights','Frozen weight set mismatch.');
alpha=[double(w.runtime_alpha_D),double(w.runtime_alpha_K),double(w.runtime_alpha_F)];
assert(isequal(alpha,[0.9004680917645591 0.09953190823544089 0])&&sum(alpha)==1,'V25I1:Weights','Frozen runtime alpha mismatch.');
assert(strcmpi(char(w.formal_target_sha256),targetExpected)&&strcmpi(char(w.fusion_core_sha256),coreExpected)&&strcmpi(char(w.fusion_wrapper_sha256),wrapperExpected), ...
    'V25I1:Weights','Weight-manifest lineage hash mismatch.');

amp=double(h01.steering_amplitude); freq=double(h01.steering_frequency); duration=double(h01.duration); rate=double(h01.estimator_rate);
report=struct(); report.stage='V2.5-I1 H01 first-and-only holdout runtime'; report.runId=char(runId); report.role='HOLDOUT_VALIDATION';
report.preregistration=table2struct(h01); report.runCard=struct('runId',char(runId),'role','HOLDOUT_VALIDATION', ...
    'originalRegistryRow',double(h01.original_registry_row),'steerAmplitudeRad',amp,'steerFrequencyHz',freq, ...
    'durationS',duration,'estimatorRateHz',rate,'waveform',char(h01.waveform), ...
    'frontSteeringPolicy',char(h01.front_steering_policy),'rearSteeringPolicy',char(h01.rear_steering_policy), ...
    'speedScope',char(h01.speed_scope),'truthAlignmentRule',char(h01.truth_alignment_rule), ...
    'evaluationWindowRule',char(h01.evaluation_window_rule));
report.weights=struct('weightSetId',char(w.weight_set_id),'alpha_D',alpha(1),'alpha_K',alpha(2),'alpha_F',alpha(3),'sum',sum(alpha));
report.targetSHA256=targetExpected; report.simCalled=false; report.simCallCount=0; report.runtimeAuthorization='UNCONSUMED';
report.simulationCompleted=false; report.carSimRun=false; report.runtimeError=struct('identifier','','message','','report','');
report.set2=struct('path',set2Path,'prelaunchRequiredAbsent',true,'runnerMoveDeletePerformed',false,'provenance','Launcher/prelaunch gate owns before-launch absence; runner does not move or delete SET-2.');
report.environment=struct('MATLABVersion',version,'PREFDIR',prefdir,'MATLAB_PREFDIR',getenv('MATLAB_PREFDIR'));
report.targetHashBefore=sha256(target); report.coreHashBefore=sha256(fullfile(md,'vy_fixed_weight_fusion_step.m')); report.wrapperHashBefore=sha256(fullfile(md,'vy_fixed_weight_fusion_simulink_sfun.m'));
oldPwd=pwd; oldPath=path; cleanupObj=onCleanup(@()cleanup(modelName,oldPwd,oldPath)); console=''; out=[];
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers'; solverDll=fullfile(solverDir,'carsim_64.dll'); solverSf=fullfile(solverDir,'Matlab84+');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(fullfile(solverSf,'Solver_SF.slx')),'V25I1:CarSim','Required D: CarSim runtime files are missing.');
    simText=fileread(simFile); report.carSim=struct('pwd','','activeSimfile',simFile,'progDir',macro_value(simText,'PROGDIR'), ...
        'dataDir',macro_value(simText,'DATADIR'),'solverExpected',solverDll,'solverActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'),'gRequestConsole',false);
    assert(strcmpi(report.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&&strcmpi(report.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&&~report.carSim.gRequestBefore, ...
        'V25I1:CarSim','CarSim configuration violates frozen D: policy.');
    addpath(md); addpath(solverDir); addpath(solverSf); cd(md); report.carSim.pwd=pwd; report.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    assert(strcmpi(report.carSim.activeSimfile,simFile),'V25I1:CarSim','MATLAB cwd does not select frozen model/simfile.sim.');
    load_system('Solver_SF'); load_system(target);
    fusion=[modelName '/Fixed Weight D K F Fusion']; params=parse_expr_list(get_param(fusion,'Parameters'));
    assert(isequal(params,alpha)&&strcmp(strtrim(get_param([modelName '/Gain22'],'Gain')),'180/pi'), ...
        'V25I1:Target','Formal target parameters do not match frozen H2 evidence.');
    logVariables={'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg', ...
        'reset_g0','avz_imu_g0','kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1','dekf_x_log','dekf_P_log','dekf_diag_log', ...
        'parallel_input_log','fusion_vy_d_log','fusion_vy_k_log','fusion_vy_f_log','fusion_f_P_log','fusion_f_diag_log','fusion_vy_fw_log','vy_true_log1','Vx_true_log'};
    assert(all(cellfun(@(n)numel(find_system(modelName,'SearchDepth',1,'BlockType','ToWorkspace','VariableName',n))==1,logVariables)), ...
        'V25I1:Logging','A required H01 runtime logger is missing.');
    mw=get_param(bdroot,'ModelWorkspace'); assignin(mw,'test_steer_amplitude',amp); assignin(mw,'test_steer_frequency',freq); assignin(mw,'vy_v17_mode_code',20);
    assignin('base','test_steer_amplitude',amp); assignin('base','test_steer_frequency',freq); assignin('base','vy_v17_mode_code',20);
    report.runCard.commandedAmplitudeRad=amp; report.runCard.commandedFrequencyHz=freq; report.runCard.StopTime=duration; report.runCard.rateHz=rate;
    fprintf('V25I1_RUN_CARD|id=%s|A=%.17g|f=%.17g|duration=%.17g|rate=%.17g|target=%s|result=%s\n',runId,amp,freq,duration,rate,target,resultFile);
    report.simCalled=true; report.simCallCount=1; report.runtimeAuthorization='CONSUMED';
    console=evalc("out=sim(modelName,'StopTime',sprintf('%.17g',duration),'ReturnWorkspaceOutputs','on','FastRestart','off');");
    report.consoleText=console; report.carSim.solverActual=solver_path_from_console(console); report.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    report.carSimRun=contains(console,'Termination at simulation time')&&strcmpi(report.carSim.solverActual,solverDll)&&~report.carSim.gRequestConsole;
    assert(report.carSimRun,'V25I1:CarSim','CarSim completion evidence is missing.');
    for k=1:numel(logVariables), n=logVariables{k}; report.raw.(n)=record_timeseries(out.get(n)); end
    report.simulationCompleted=true;
catch ME
    report.consoleText=console; report.runtimeError.identifier=ME.identifier; report.runtimeError.message=ME.message; report.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end
report.targetHashAfter=sha256(target); report.targetHashUnchanged=strcmpi(report.targetHashAfter,targetExpected);
report.coreHashAfter=sha256(fullfile(md,'vy_fixed_weight_fusion_step.m')); report.wrapperHashAfter=sha256(fullfile(md,'vy_fixed_weight_fusion_simulink_sfun.m'));
report.frozenHashesUnchanged=report.targetHashUnchanged&&strcmpi(report.coreHashAfter,coreExpected)&&strcmpi(report.wrapperHashAfter,wrapperExpected);
if report.simCalled
    save(resultFile,'report','-v7.3');
    info=dir(resultFile); report.formalResultPath=resultFile; report.formalResultSize=info.bytes; report.formalResultSHA256=sha256(resultFile);
    save(resultFile,'report','-v7.3');
end
cleanup(modelName,oldPwd,oldPath); clear cleanupObj
if ~report.simulationCompleted, error('V25I1:RuntimeFailed','H01 runtime failed after its one authorized simulation call: %s',report.runtimeError.message); end
fprintf('V25I1_RUNTIME_RETURN|id=%s|simCalled=%d|simCallCount=%d|completed=%d|carSim=%d|targetUnchanged=%d\n',runId,report.simCalled,report.simCallCount,report.simulationCompleted,report.carSimRun,report.targetHashUnchanged);
end

function x=parse_expr_list(s),p=strsplit(s,',');x=zeros(1,numel(p));for k=1:numel(p),x(k)=str2double(strtrim(p{k}));end,end
function r=record_timeseries(ts),assert(isa(ts,'timeseries'),'V25I1:LogType','Expected timeseries, got %s.',class(ts));r=struct('time',double(ts.Time(:)),'data',double(ts.Data),'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));end
function v=macro_value(txt,key),t=regexp(txt,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');assert(~isempty(t),'V25I1:CarSim','Missing CarSim entry %s.',key);v=strtrim(t{1});end
function p=solver_path_from_console(txt),t=regexp(txt,'Use vehicle solver:\s*([^\r\n]+)','tokens','once');if isempty(t),p='';else,p=strtrim(t{1});end,end
function cleanup(m,oldPwd,oldPath),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(oldPwd);path(oldPath);evalin('base','clear test_steer_amplitude test_steer_frequency vy_v17_mode_code');end
function h=sha256(file),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(b,2).',1,[]));clear c;end
