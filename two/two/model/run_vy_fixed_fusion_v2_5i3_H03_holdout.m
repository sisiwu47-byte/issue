function report = run_vy_fixed_fusion_v2_5i3_H03_holdout()
%RUN_VY_FIXED_FUSION_V2_5I3_H03_HOLDOUT Dedicated one-shot FWHOLD_H03 runner.
% Authorization is durably committed and read back before the only sim call.

root=fileparts(fileparts(mfilename('fullpath'))); md=fullfile(root,'model');
modelName='vx_vy_fixed_fusion_v2_5'; target=fullfile(md,[modelName '.slx']);
preregFile=fullfile(root,'results','vy_fixed_fusion_v2_5i_holdout_preexecution_registry.csv');
weightFile=fullfile(root,'results','vy_fixed_fusion_v2_5h2_runtime_weight_manifest.csv');
phaseFile=fullfile(root,'results','vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv');
commitFile=fullfile(root,'results','vy_fixed_fusion_v2_5i3_H03_sim_authorization_committed.csv');
targetExpected='AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B';
coreExpected='4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C';
wrapperExpected='B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A';
runnerFile=[mfilename('fullpath') '.m'];
assert(isfile(runnerFile),'V25I3:RunnerSelfPathMissing','Runner file not found: %s',runnerFile);
runnerHash=sha256(runnerFile);
assert(isfile(phaseFile),'V25I3:Bootstrap','Durable bootstrap markers are missing.');
assert(~isfile(commitFile),'V25I3:Authorization','Authorization commit already exists; no runtime is permitted.');
append_phase(phaseFile,'RUNNER_ENTERED','FWHOLD_H03',runnerHash);

required={'run_id','role','original_registry_row','original_status','runtime_authorization','execution_order', ...
    'steering_amplitude','steering_frequency','duration','estimator_rate','waveform','front_steering_policy', ...
    'rear_steering_policy','speed_scope','truth_alignment_rule','evaluation_window_rule','formal_result_path', ...
    'data_viewed','runtime_count','weight_set_id','runtime_alpha_D','runtime_alpha_K','runtime_alpha_F','target_path','target_sha256'};
pre=readtable(preregFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
assert(width(pre)==32&&all(ismember(required,pre.Properties.VariableNames))&&~any(startsWith(string(pre.Properties.VariableNames),'Var')), ...
    'V25I3:Preregistration','Frozen preregistration schema mismatch.');
h03=pre(pre.execution_order==3,:); assert(height(h03)==1&&h03.run_id=="FWHOLD_H03",'V25I3:Identity','Execution order 3 is not exact FWHOLD_H03.');
assert(h03.role=="HOLDOUT_VALIDATION"&&double(h03.original_registry_row)==9&&h03.original_status=="PLANNED_NOT_RUN"&& ...
    h03.runtime_authorization=="UNCONSUMED"&&double(h03.runtime_count)==0&&h03.data_viewed=="FALSE", ...
    'V25I3:Untouched','FWHOLD_H03 is not untouched.');
assert(double(h03.steering_amplitude)==0.030&&double(h03.steering_frequency)==0.45&&double(h03.duration)==16&& ...
    double(h03.estimator_rate)==100&&h03.waveform=="SINE_FRONT_EQUAL_REAR_ZERO"&& ...
    h03.front_steering_policy=="FL_FR_SAME_PHASE"&&h03.rear_steering_policy=="RL_RR_ZERO", ...
    'V25I3:Condition','Frozen FWHOLD_H03 condition mismatch.');
resultFile=fullfile(root,strrep(char(h03.formal_result_path),'/',filesep));
assert(~isfile(resultFile),'V25I3:ResultExists','Formal FWHOLD_H03 result already exists.');
for q=1:height(pre)
    if pre.execution_order(q)~=3
        p=fullfile(root,strrep(char(pre.formal_result_path(q)),'/',filesep));
        assert(~isfile(p)&&double(pre.runtime_count(q))==0&&pre.data_viewed(q)=="FALSE",'V25I3:Isolation','Another holdout is not untouched.');
    end
end
append_phase(phaseFile,'PREREGISTRY_PARSED','FWHOLD_H03',char(h03.formal_result_path));

w=readtable(weightFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
alpha=[double(w.runtime_alpha_D),double(w.runtime_alpha_K),double(w.runtime_alpha_F)];
assert(height(w)==1&&w.weight_set_id=="V25_FIXED_WEIGHT_ALPHA_V1"&& ...
    isequal(alpha,[0.9004680917645591 0.09953190823544089 0])&&sum(alpha)==1, ...
    'V25I3:Weights','Frozen runtime weights mismatch.');
assert(strcmpi(char(w.formal_target_sha256),targetExpected)&&strcmpi(char(w.fusion_core_sha256),coreExpected)&& ...
    strcmpi(char(w.fusion_wrapper_sha256),wrapperExpected),'V25I3:Weights','Weight lineage mismatch.');
assert(strcmpi(sha256(target),targetExpected)&&strcmpi(char(h03.target_sha256),targetExpected), ...
    'V25I3:Target','Formal target hash mismatch.');
assert(h03.target_path=="model/vx_vy_fixed_fusion_v2_5.slx",'V25I3:Target','Frozen target path mismatch.');

amp=double(h03.steering_amplitude); freq=double(h03.steering_frequency); duration=double(h03.duration); rate=double(h03.estimator_rate);
report=struct('stage','V2.5-I3','runId','FWHOLD_H03','role','PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE', ...
    'scientificRole','SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE', ...
    'preregistration',table2struct(h03),'runnerSHA256',runnerHash,'targetSHA256',targetExpected, ...
    'weights',struct('weightSetId','V25_FIXED_WEIGHT_ALPHA_V1','alpha_D',alpha(1),'alpha_K',alpha(2),'alpha_F',alpha(3),'sum',sum(alpha)), ...
    'phaseMarkerPath',phaseFile,'authorizationCommitPath',commitFile,'simCalled',false,'simCallCount',0, ...
    'runtimeAuthorization','UNCONSUMED','simulationCompleted',false,'carSimRun',false, ...
    'runtimeError',struct('identifier','','message','','report',''));
report.environment=struct('MATLABVersion',version,'PREFDIR',prefdir,'MATLAB_PREFDIR',getenv('MATLAB_PREFDIR'));
report.targetHashBefore=sha256(target); report.coreHashBefore=sha256(fullfile(md,'vy_fixed_weight_fusion_step.m'));
report.wrapperHashBefore=sha256(fullfile(md,'vy_fixed_weight_fusion_simulink_sfun.m'));
oldPwd=pwd; oldPath=path; cleanupObj=onCleanup(@()cleanup(modelName,oldPwd,oldPath)); console=''; out=[];
try
    solverDir='D:\carsim\CarSim2021.0_Prog\Programs\solvers'; solverDll=fullfile(solverDir,'carsim_64.dll');
    solverSf=fullfile(solverDir,'Matlab84+');solverMex=fullfile(solverSf,'vs_sf.mexw64');solverLib=fullfile(solverSf,'Solver_SF.slx');simFile=fullfile(md,'simfile.sim');
    assert(isfile(simFile)&&isfile(solverDll)&&isfile(solverMex)&&isfile(solverLib),'V25I3:CarSim','Required D: runtime files are missing.');
    simText=fileread(simFile); report.carSim=struct('pwd','','activeSimfile',simFile,'progDir',macro_value(simText,'PROGDIR'), ...
        'dataDir',macro_value(simText,'DATADIR'),'solverExpected',solverDll,'solverActual','','mexExpected',solverMex,'mexActual','', ...
        'gRequestBefore',contains(lower(simText),'g:\carsim'),'gRequestConsole',false);
    assert(strcmpi(report.carSim.progDir,'D:\carsim\CarSim2021.0_Prog\')&& ...
        strcmpi(report.carSim.dataDir,'D:\carsim\CarSim2021.0_Data\')&&~report.carSim.gRequestBefore, ...
        'V25I3:CarSim','CarSim path policy mismatch.');
    addpath(md);addpath(solverDir);addpath(solverSf);cd(md);report.carSim.pwd=pwd;report.carSim.activeSimfile=fullfile(pwd,'simfile.sim');
    report.carSim.mexActual=which('vs_sf');
    assert(strcmpi(pwd,md)&&strcmpi(report.carSim.activeSimfile,simFile)&&strcmpi(report.carSim.mexActual,solverMex),'V25I3:Environment','Project cwd/simfile/MEX mismatch.');
    load_system('Solver_SF');load_system(target);
    report.static=static_preflight(modelName);report.fParameters=report.static.fParameters;
    assert(report.static.pass&&isequal(report.static.weights,alpha),'V25I3:Static','Frozen target parameters mismatch.');
    logs={'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg', ...
        'reset_g0','avz_imu_g0','kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1','dekf_x_log','dekf_P_log','dekf_diag_log', ...
        'parallel_input_log','fusion_vy_d_log','fusion_vy_k_log','fusion_vy_f_log','fusion_f_P_log','fusion_f_diag_log','fusion_vy_fw_log','vy_true_log1','Vx_true_log'};
    assert(all(cellfun(@(n)numel(find_system(modelName,'SearchDepth',1,'BlockType','ToWorkspace','VariableName',n))==1,logs)), ...
        'V25I3:Logging','Required runtime logger missing.');report.logVariables=logs;
    mw=get_param(modelName,'ModelWorkspace');assignin(mw,'test_steer_amplitude',amp);assignin(mw,'test_steer_frequency',freq);assignin(mw,'vy_v17_mode_code',20);
    assignin('base','test_steer_amplitude',amp);assignin('base','test_steer_frequency',freq);assignin('base','vy_v17_mode_code',20);
    report.runCard=struct('runId','FWHOLD_H03','amplitudeRad',amp,'frequencyHz',freq,'durationS',duration,'rateHz',rate, ...
        'waveform',char(h03.waveform),'frontPolicy',char(h03.front_steering_policy),'rearPolicy',char(h03.rear_steering_policy), ...
        'speedScope',char(h03.speed_scope),'truthAlignment',char(h03.truth_alignment_rule),'evaluationWindow',char(h03.evaluation_window_rule));
    report.immediatePreSim=struct('pwd',pwd,'activeSimfile',report.carSim.activeSimfile,'progDir',report.carSim.progDir, ...
        'dataDir',report.carSim.dataDir,'solver',solverDll,'mex',solverMex,'targetSHA256',sha256(target),'runnerSHA256',runnerHash,'gRequest','NO');
    append_phase(phaseFile,'PRE_SIM_GATES_PASS','FWHOLD_H03',targetExpected);
    write_commit(commitFile,'FWHOLD_H03',targetExpected,runnerHash,'V25_FIXED_WEIGHT_ALPHA_V1',alpha,resultFile);
    c=readtable(commitFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
    assert(height(c)==1&&c.run_id=="FWHOLD_H03"&&c.authorization_state=="CONSUMED"&& ...
        strcmpi(c.target_sha256,targetExpected)&&double(c.alpha_D)==alpha(1)&&double(c.alpha_K)==alpha(2)&&double(c.alpha_F)==alpha(3), ...
        'V25I3:CommitReadback','Authorization commit read-back failed.');
    report.authorizationCommitSHA256=sha256(commitFile);report.runtimeAuthorization='CONSUMED';
    append_phase(phaseFile,'SIM_AUTHORIZATION_COMMITTED','FWHOLD_H03',report.authorizationCommitSHA256);
    report.simCalled=true;report.simCallCount=1;
    console=evalc("out=sim(modelName,'StopTime',sprintf('%.17g',duration),'ReturnWorkspaceOutputs','on','FastRestart','off');");
    append_phase(phaseFile,'SIM_RETURNED','FWHOLD_H03','unique sim returned');
    report.consoleText=console;report.carSim.solverActual=solver_path_from_console(console);report.carSim.gRequestConsole=contains(lower(console),'g:\carsim');
    report.carSimRun=contains(console,'Termination at simulation time')&&strcmpi(report.carSim.solverActual,solverDll)&&~report.carSim.gRequestConsole;
    assert(report.carSimRun,'V25I3:CarSim','CarSim completion evidence missing.');
    for k=1:numel(logs),n=logs{k};report.raw.(n)=record_timeseries(out.get(n));end
    report.simulationCompleted=true;
catch ME
    report.consoleText=console;report.runtimeError.identifier=ME.identifier;report.runtimeError.message=ME.message;report.runtimeError.report=getReport(ME,'extended','hyperlinks','off');
end
report.targetHashAfter=sha256(target);report.coreHashAfter=sha256(fullfile(md,'vy_fixed_weight_fusion_step.m'));report.wrapperHashAfter=sha256(fullfile(md,'vy_fixed_weight_fusion_simulink_sfun.m'));
report.frozenHashesUnchanged=strcmpi(report.targetHashAfter,targetExpected)&&strcmpi(report.coreHashAfter,coreExpected)&&strcmpi(report.wrapperHashAfter,wrapperExpected);
if report.simulationCompleted&&report.carSimRun&&report.frozenHashesUnchanged
    assert(~isfile(resultFile),'V25I3:ResultExists','Formal result appeared before save.');save(resultFile,'report','-v7.3');
    info=dir(resultFile);append_phase(phaseFile,'FORMAL_MAT_SAVED','FWHOLD_H03',sprintf('%s|%d',sha256(resultFile),info.bytes));
end
cleanup(modelName,oldPwd,oldPath);clear cleanupObj
if ~report.simulationCompleted,error('V25I3:RuntimeFailed','Unique runtime failed after durable authorization commit: %s',report.runtimeError.message);end
end

function a=static_preflight(m)
fusion=[m '/Fixed Weight D K F Fusion'];fSub=[m '/F-Track 100Hz'];
weights=parse_expr_list(get_param(fusion,'Parameters'));fp=parse_expr_list(get_param([fSub '/F-Track Stateful Boundary'],'Parameters'));
a=struct('weights',weights,'fParameters',struct('Ts',fp(1),'Vy_F0',fp(2),'P0_F',fp(3),'Q_F',fp(4)), ...
    'pass',numel(weights)==3&&numel(fp)==4&&strcmp(strtrim(get_param([m '/Gain22'],'Gain')),'180/pi'));
end
function write_commit(file,runId,targetHash,runnerHash,weightSet,alpha,resultFile)
assert(~isfile(file),'V25I3:CommitExists','Commit marker already exists.');fid=fopen(file,'w');assert(fid>=0,'V25I3:CommitWrite','Cannot create commit marker.');
fprintf(fid,'run_id,timestamp,stage,target_sha256,runner_sha256,weight_set_id,alpha_D,alpha_K,alpha_F,formal_result_path,pre_sim_gates_status,authorization_state,next_expected_action\n');
fprintf(fid,'%s,%s,V2.5-I3,%s,%s,%s,%.17g,%.17g,%.17g,%s,PASS,CONSUMED,UNIQUE_SIM_CALL\n',runId,datestr(now,30),targetHash,runnerHash,weightSet,alpha(1),alpha(2),alpha(3),strrep(resultFile,'\','/'));
assert(fclose(fid)==0,'V25I3:CommitClose','Commit marker close failed.');d=dir(file);assert(isfile(file)&&d.bytes>0,'V25I3:CommitDurability','Commit marker did not persist.');
end
function append_phase(file,phase,runId,detail)
isNew=~isfile(file);fid=fopen(file,'a');assert(fid>=0,'V25I3:PhaseWrite','Cannot append phase marker.');if isNew,fprintf(fid,'timestamp,phase,run_id,detail\n');end
fprintf(fid,'%s,%s,%s,"%s"\n',datestr(now,30),phase,runId,strrep(char(detail),'"','""'));assert(fclose(fid)==0,'V25I3:PhaseClose','Phase marker close failed.');d=dir(file);assert(d.bytes>0,'V25I3:PhaseDurability','Phase marker did not persist.');
end
function x=parse_expr_list(s)
p=strsplit(char(s),',');x=zeros(1,numel(p));
for k=1:numel(p),x(k)=parse_restricted_expr(strtrim(p{k}));end
end
function v=parse_restricted_expr(s)
s=char(s);pos=skip_expr_ws(s,1);
if pos>numel(s),error('V25I3:StaticParameterParse','Empty static parameter expression.');end
[v,pos]=parse_expr_sum(s,pos);pos=skip_expr_ws(s,pos);
if pos<=numel(s),error('V25I3:StaticParameterParse','Unexpected character at position %d.',pos);end
require_finite_expr(v);
end
function [v,pos]=parse_expr_sum(s,pos)
[v,pos]=parse_expr_term(s,pos);
while true
    pos=skip_expr_ws(s,pos);
    if pos>numel(s)||~any(s(pos)=='+-'),break,end
    op=s(pos);[rhs,pos]=parse_expr_term(s,pos+1);
    if op=='+',v=v+rhs;else,v=v-rhs;end
    require_finite_expr(v);
end
end
function [v,pos]=parse_expr_term(s,pos)
[v,pos]=parse_expr_factor(s,pos);
while true
    pos=skip_expr_ws(s,pos);
    if pos>numel(s)||~any(s(pos)=='*/'),break,end
    op=s(pos);[rhs,pos]=parse_expr_factor(s,pos+1);
    if op=='*'
        v=v*rhs;
    else
        if rhs==0,error('V25I3:StaticParameterParse','Division by zero is not allowed.');end
        v=v/rhs;
    end
    require_finite_expr(v);
end
end
function [v,pos]=parse_expr_factor(s,pos)
pos=skip_expr_ws(s,pos);
if pos>numel(s),error('V25I3:StaticParameterParse','Expected a factor.');end
if any(s(pos)=='+-')
    op=s(pos);[v,pos]=parse_expr_primary(s,pos+1);
    if op=='-',v=-v;end
    require_finite_expr(v);
else
    [v,pos]=parse_expr_primary(s,pos);
end
end
function [v,pos]=parse_expr_primary(s,pos)
pos=skip_expr_ws(s,pos);
if pos>numel(s),error('V25I3:StaticParameterParse','Expected a primary expression.');end
if s(pos)=='('
    [v,pos]=parse_expr_sum(s,pos+1);pos=skip_expr_ws(s,pos);
    if pos>numel(s)||s(pos)~=')',error('V25I3:StaticParameterParse','Missing closing parenthesis.');end
    pos=pos+1;require_finite_expr(v);return
end
if isstrprop(s(pos),'alpha')
    first=pos;while pos<=numel(s)&&(isstrprop(s(pos),'alphanum')||s(pos)=='_'),pos=pos+1;end
    identifier=s(first:pos-1);
    if ~strcmp(identifier,'pi'),error('V25I3:StaticParameterParse','Unknown identifier: %s',identifier);end
    v=pi;return
end
token=regexp(s(pos:end),'^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?','match','once');
if isempty(token),error('V25I3:StaticParameterParse','Expected a finite numeric literal or pi at position %d.',pos);end
v=str2double(token);require_finite_expr(v);pos=pos+numel(token);
end
function pos=skip_expr_ws(s,pos)
while pos<=numel(s)&&(s(pos)==' '||s(pos)==char(9)),pos=pos+1;end
end
function require_finite_expr(v)
if ~isfinite(v),error('V25I3:StaticParameterParse','Static parameter expression must remain finite.');end
end
function r=record_timeseries(ts),assert(isa(ts,'timeseries'),'V25I3:LogType','Expected timeseries.');r=struct('time',double(ts.Time(:)),'data',double(ts.Data),'sampleCount',numel(ts.Time),'dataSize',size(ts.Data));end
function v=macro_value(txt,key),t=regexp(txt,['(?m)^' key '\s+([^\r\n]+)'],'tokens','once');assert(~isempty(t),'V25I3:CarSim','Missing %s.',key);v=strtrim(t{1});end
function p=solver_path_from_console(txt),t=regexp(txt,'Use vehicle solver:\s*([^\r\n]+)','tokens','once');if isempty(t),p='';else,p=strtrim(t{1});end,end
function cleanup(m,oldPwd,oldPath),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;cd(oldPwd);path(oldPath);evalin('base','clear test_steer_amplitude test_steer_frequency vy_v17_mode_code');end
function h=sha256(file),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(b,2).',1,[]));clear c;end
