function run_vy_dekf_v1_12_cross_condition()
%RUN_VY_DEKF_V1_12_CROSS_CONDITION Run seven independent online baselines.
% Fixed axle gains are not present in the online model.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot,'results');
addpath(fullfile(repoRoot,'matlab'));
buildReport = build_vy_dekf_v1_12_model();
modelFile = buildReport.copyFile;

definitions = [ ...
    make_case('N',20,0.02,0.4); ...
    make_case('V15',15,0.02,0.4); ...
    make_case('V25',25,0.02,0.4); ...
    make_case('A10',20,0.01,0.4); ...
    make_case('A30',20,0.03,0.4); ...
    make_case('F20',20,0.02,0.2); ...
    make_case('F60',20,0.02,0.6)];

oldFolder = pwd; cd(fileparts(modelFile)); folderCleanup = onCleanup(@()cd(oldFolder));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(resultsDir,'simulink_cache_vy_v1_12'), ...
    'CodeGenFolder',fullfile(resultsDir,'simulink_codegen_vy_v1_12'),'createDir',true);
load_system('simulink'); load_system('Solver_SF'); load_system(modelFile);
[~,modelName] = fileparts(modelFile);
modelCleanup = onCleanup(@()close_models(modelName));
wks = get_param(modelName,'ModelWorkspace');

runs = repmat(empty_run(),numel(definitions),1);
for i=1:numel(definitions)
    def=definitions(i);
    assignin(wks,'test_speed',def.VxTarget);
    assignin(wks,'test_steer_amplitude',def.SteerAmplitude);
    assignin(wks,'test_steer_frequency',def.Frequency);
    assignin(wks,'Ay_bias_v17',0); assignin(wks,'AVz_bias_v17',0);
    assignin('base','test_speed',def.VxTarget);
    assignin('base','test_steer_amplitude',def.SteerAmplitude);
    assignin('base','test_steer_frequency',def.Frequency);
    assignin('base','Ay_bias_v17',0); assignin('base','AVz_bias_v17',0);
    clear('vy_dynamic_ekf_v1_7');
    fprintf('V1_12_CASE_START|%s|V=%.6g|A=%.6g|F=%.6g\n', ...
        def.Case,def.VxTarget,def.SteerAmplitude,def.Frequency);
    timer=tic;
    out=sim(modelName,'StopTime','16','ReturnWorkspaceOutputs','on', ...
        'FastRestart','off');
    runs(i)=extract_run(out,def);
    perCaseFile=fullfile(resultsDir,sprintf('vy_dekf_v1_12_run_%s.mat',def.Case));
    run=runs(i); %#ok<NASGU>
    save(perCaseFile,'run','def','-v7.3');
    fprintf('V1_12_CASE_DONE|%s|updates=%d|elapsed=%.3f|file=%s\n', ...
        def.Case,numel(runs(i).t),toc(timer),perCaseFile);
end

metadata=struct('modelFile',modelFile,'sourceModel',buildReport.sourceFile, ...
    'definitions',definitions,'stopTime',16,'estimatorPeriod',0.01, ...
    'expectedUpdates',1601,'fixedQ',buildReport.fixedQ,'fixedR',buildReport.fixedR, ...
    'onlineEstimatorExpression',buildReport.estimatorExpression, ...
    'onlineAxleScalingApplied',false,'onlineRelaxationApplied',false, ...
    'AyBiasRemoved',0,'AVzBiasRemoved',0,'allCasesIndependent',true);
archiveFile=fullfile(resultsDir,'vy_dekf_v1_12_cross_condition_runs.mat');
save(archiveFile,'runs','metadata','-v7.3');
close_system(modelName,0); close_system('Solver_SF',0);
clear modelCleanup folderCleanup;
analyze_vy_dekf_v1_12_cross_condition(archiveFile);
clear_base_variables();
end

function d=make_case(name,v,a,f)
d=struct('Case',name,'VxTarget',v,'SteerAmplitude',a,'Frequency',f);
end

function r=empty_run()
r=struct('Case','','VxTarget',0,'SteerAmplitude',0,'Frequency',0, ...
    't',[],'u',[],'zRaw',[],'y',[],'pDiag',[],'diagnostics',[], ...
    'vyTrue',[],'rTrue',[],'ayTrue',[]);
end

function run=extract_run(out,def)
[tU,u]=log_matrix(fetch_log(out,{'est_u_log1','outest_u_log1'}));
[tZ,z]=log_matrix(fetch_log(out,{'est_z_log1','out_est_z_log1'}));
[tY,y]=log_matrix(fetch_log(out,{'est_y_log1','outest_y_log1'}));
[tP,p]=log_matrix(fetch_log(out,{'est_P_log1','outest_P_log1'}));
[tD,d]=log_matrix(fetch_log(out,{'est_diag_log1','outest_diag_log1'}));
[tVy,vy]=log_matrix(fetch_log(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));
[tR,r]=log_matrix(fetch_log(out,{'vy_AVz_true_log'}));
[tAy,ay]=log_matrix(fetch_log(out,{'vy_Ay_true_log'}));
t=tZ(:); run=empty_run();
run.Case=def.Case;run.VxTarget=def.VxTarget;
run.SteerAmplitude=def.SteerAmplitude;run.Frequency=def.Frequency;run.t=t;
run.u=previous(tU,u(:,1:5),t);run.zRaw=z(:,1:2);
run.y=previous(tY,y(:,1:2),t);run.pDiag=previous(tP,p(:,1:2),t);
run.diagnostics=previous(tD,d(:,1:47),t);
run.vyTrue=linear(tVy,vy(:,1),t);run.rTrue=linear(tR,r(:,1),t);
run.ayTrue=linear(tAy,ay(:,1),t);
assert(numel(t)==1601 && abs(median(diff(t))-0.01)<=1e-12);
assert(max(abs(diff(t)-0.01))<=1e-10);
assert(all(isfinite([run.u run.zRaw run.y run.pDiag run.diagnostics ...
    run.vyTrue run.rTrue run.ayTrue]),'all'));
end

function value=fetch_log(out,aliases)
available=out.who;
for k=1:numel(aliases)
    if any(strcmp(available,aliases{k})),value=out.get(aliases{k});return;end
end
error('Required log missing: %s',strjoin(aliases,', '));
end

function [time,data]=log_matrix(value)
if isa(value,'timeseries'),time=double(value.Time(:));raw=double(value.Data);
elseif isa(value,'Simulink.SimulationData.Signal'),[time,data]=log_matrix(value.Values);return;
elseif isstruct(value)&&isfield(value,'time')&&isfield(value,'signals')
    time=double(value.time(:));raw=double(value.signals.values);
else,error('Unsupported log type: %s',class(value));end
raw=squeeze(raw);
if isvector(raw),data=raw(:);elseif size(raw,1)==numel(time),data=raw;
elseif size(raw,2)==numel(time),data=raw.';else,error('Time/data mismatch.');end
end

function v=previous(ts,x,t),v=interp1(ts(:),x,t(:),'previous','extrap');end
function v=linear(ts,x,t),v=interp1(ts(:),x,t(:),'linear','extrap');end
function close_models(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;end
function clear_base_variables(),evalin('base','clear test_speed test_steer_amplitude test_steer_frequency Ay_bias_v17 AVz_bias_v17');end
