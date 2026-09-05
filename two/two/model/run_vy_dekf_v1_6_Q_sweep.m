function run_vy_dekf_v1_6_Q_sweep()
%RUN_VY_DEKF_V1_6_Q_SWEEP Controlled 3-by-3 discrete process-Q sweep.

repoRoot=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(repoRoot,'results');
modelFile=fullfile(repoRoot,'model','vx_vy_dekf_v1_6.slx');
assert(isfile(modelFile),'V1.6 model missing.');
addpath(fullfile(repoRoot,'matlab'));
addpath(fullfile(repoRoot,'tests'));
equivalenceReport=test_vy_dynamic_ekf_step_v15_debug_equivalence();
assert(equivalenceReport.passed);

originalFolder=pwd; cd(fileparts(modelFile));
cleanupFolder=onCleanup(@()cd(originalFolder));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(resultsDir,'simulink_cache_vy_v1_6'), ...
    'CodeGenFolder',fullfile(resultsDir,'simulink_codegen_vy_v1_6'), ...
    'createDir',true);
load_system('simulink'); load_system('Solver_SF'); load_system(modelFile);
[~,modelName]=fileparts(modelFile);
cleanupModel=onCleanup(@()close_models(modelName));
cleanupBase=onCleanup(@()clear_test_variables());
block=[modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
expression=get_param(block,'MATLABFcn');
assert(strcmp(strrep(expression,' ',''), ...
    'vy_dynamic_ekf_v1_6(u,Q_vy_v16,Q_r_v16)'));
modelWks=get_param(modelName,'ModelWorkspace');

qVyLevels=[1e-4,3e-5,1e-5];
qRLevels=[1e-3,3e-4,1e-4];
levelNames={'H','M','L'};
definitions=repmat(struct('Case',0,'LevelVy','','LevelR','', ...
    'Q_vy',0,'Q_r',0),9,1);
index=0;
for i=1:3
    for j=1:3
        index=index+1;
        definitions(index)=struct('Case',index,'LevelVy',levelNames{i}, ...
            'LevelR',levelNames{j},'Q_vy',qVyLevels(i),'Q_r',qRLevels(j));
    end
end

runs=repmat(empty_run(),9,1);
reference=struct();
for k=1:9
    def=definitions(k);
    assignin(modelWks,'Q_vy_v16',def.Q_vy);
    assignin(modelWks,'Q_r_v16',def.Q_r);
    assignin('base','Q_vy_v16',def.Q_vy);
    assignin('base','Q_r_v16',def.Q_r);
    clear('vy_dynamic_ekf_v1_6');
    fprintf('V1_6_CASE_START|case=%d|levels=%s%s|Q_vy=%.15g|Q_r=%.15g\n', ...
        def.Case,def.LevelVy,def.LevelR,def.Q_vy,def.Q_r);
    timer=tic;
    out=sim(modelName,'StopTime','16','ReturnWorkspaceOutputs','on');
    runs(k)=extract_run(out,def);
    fprintf('V1_6_CASE_DONE|case=%d|updates=%d|elapsed=%.3f\n', ...
        def.Case,numel(runs(k).t),toc(timer));
    if k==1, reference=fixed_signals(runs(k));
    else, verify_fixed(reference,runs(k),def.Case); end
end

metadata=struct();
metadata.modelFile=modelFile;
metadata.sourceModel=fullfile(repoRoot,'model','vx_vy_dekf_v1_5.slx');
metadata.wrapperExpression=expression;
metadata.fixedR=diag([1e-2,3.365172961808e-4]);
metadata.qVyLevels=qVyLevels;
metadata.qRLevels=qRLevels;
metadata.definitions=definitions;
metadata.stopTime=16;
metadata.estimatorPeriod=0.01;
metadata.expectedUpdates=1601;
metadata.truthAlignedUpdates=1600;
metadata.inputInvarianceVerified=true;
metadata.equivalenceReport=equivalenceReport;
metadata.onlyDiscreteQVaried=true;
archiveFile=fullfile(resultsDir,'vy_dekf_v1_6_Q_sweep_runs.mat');
save(archiveFile,'runs','metadata','-v7.3');
fprintf('V1_6_RUN_ARCHIVE|%s\n',archiveFile);
close_system(modelName,0); close_system('Solver_SF',0);
clear cleanupModel cleanupBase;
analyze_vy_dekf_v1_6_Q_sweep(archiveFile);
clear cleanupFolder;
end

function run=empty_run()
run=struct('Case',0,'LevelVy','','LevelR','','Q_vy',0,'Q_r',0, ...
    't',[],'u',[],'z',[],'y',[],'pDiag',[],'diagnostics',[], ...
    'vyTrue',[],'rTrue',[]);
end

function run=extract_run(out,def)
[tU,u]=log_matrix(fetch_log(out,{'est_u_log1','outest_u_log1'}));
[tZ,z]=log_matrix(fetch_log(out,{'est_z_log1','out_est_z_log1'}));
[tY,y]=log_matrix(fetch_log(out,{'est_y_log1','outest_y_log1'}));
[tP,p]=log_matrix(fetch_log(out,{'est_P_log1','outest_P_log1'}));
[tD,d]=log_matrix(fetch_log(out,{'est_diag_log1','outest_diag_log1'}));
[tVy,vy]=log_matrix(fetch_log(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));
[tR,r]=log_matrix(fetch_log(out,{'vy_AVz_true_log'}));
assert(size(d,2)>=45,'V1.6 diagnostic log must have 45 columns.');
t=tZ(:); run=empty_run();
run.Case=def.Case; run.LevelVy=def.LevelVy; run.LevelR=def.LevelR;
run.Q_vy=def.Q_vy; run.Q_r=def.Q_r; run.t=t;
run.u=previous(tU,u(:,1:5),t); run.z=z(:,1:2);
run.y=previous(tY,y(:,1:2),t); run.pDiag=previous(tP,p(:,1:2),t);
run.diagnostics=previous(tD,d(:,1:45),t);
run.vyTrue=linear(tVy,vy(:,1),t); run.rTrue=linear(tR,r(:,1),t);
assert(numel(t)==1601 && all(isfinite([run.u run.z run.y run.pDiag ...
    run.diagnostics run.vyTrue run.rTrue]),'all'));
end

function fixed=fixed_signals(run)
fixed=struct('t',run.t,'u',run.u,'z',run.z, ...
    'vyTrue',run.vyTrue,'rTrue',run.rTrue);
end

function verify_fixed(reference,run,caseNumber)
names=fieldnames(reference);
for k=1:numel(names)
    difference=abs(reference.(names{k})-run.(names{k}));
    assert(max(difference,[],'all')<=1e-10, ...
        'Case %d changed fixed signal %s.',caseNumber,names{k});
end
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
if isvector(raw),data=raw(:);
elseif size(raw,1)==numel(time),data=raw;
elseif size(raw,2)==numel(time),data=raw.';
else,error('Time/data mismatch.');end
end

function v=previous(ts,x,t),v=interp1(ts(:),x,t(:),'previous','extrap');end
function v=linear(ts,x,t),v=interp1(ts(:),x,t(:),'linear','extrap');end
function close_models(m)
if bdIsLoaded(m),close_system(m,0);end
if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end
end
function clear_test_variables(),evalin('base','clear Q_vy_v16 Q_r_v16');end
