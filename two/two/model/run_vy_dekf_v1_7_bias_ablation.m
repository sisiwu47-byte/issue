function run_vy_dekf_v1_7_bias_ablation()
%RUN_VY_DEKF_V1_7_BIAS_ABLATION Run four controlled oracle-bias cases.
% THIS IS AN ORACLE BIAS-REMOVAL ABLATION, NOT THE FINAL ONLINE ESTIMATOR.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot,'results');
addpath(fullfile(repoRoot,'matlab'));
addpath(fullfile(repoRoot,'tests'));
equivalenceReport = test_vy_dynamic_ekf_step_v15_debug_equivalence();
assert(equivalenceReport.passed);
buildReport = build_vy_dekf_v1_7_model();
modelFile = buildReport.copyFile;

originalFolder = pwd;
cd(fileparts(modelFile));
cleanupFolder = onCleanup(@()cd(originalFolder));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(resultsDir,'simulink_cache_vy_v1_7'), ...
    'CodeGenFolder',fullfile(resultsDir,'simulink_codegen_vy_v1_7'), ...
    'createDir',true);
load_system('simulink');
load_system('Solver_SF');
load_system(modelFile);
[~,modelName] = fileparts(modelFile);
cleanupModel = onCleanup(@()close_models(modelName));
cleanupBase = onCleanup(@()clear_test_variables());
block = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
expression = get_param(block,'MATLABFcn');
assert(strcmp(strrep(expression,' ',''), ...
    'vy_dynamic_ekf_v1_7(u,Ay_bias_v17,AVz_bias_v17)'));
modelWks = get_param(modelName,'ModelWorkspace');

definitions = [ ...
    struct('Case','B0','Description','no bias removal', ...
        'AyBiasRemoved',0,'AVzBiasRemoved',0); ...
    struct('Case','B1','Description','Ay bias only', ...
        'AyBiasRemoved',0.02,'AVzBiasRemoved',0); ...
    struct('Case','B2','Description','AVz bias only', ...
        'AyBiasRemoved',0,'AVzBiasRemoved',0.005); ...
    struct('Case','B3','Description','both biases', ...
        'AyBiasRemoved',0.02,'AVzBiasRemoved',0.005)];

runs = repmat(empty_run(),4,1);
reference = struct();
for k = 1:4
    def = definitions(k);
    assignin(modelWks,'Ay_bias_v17',def.AyBiasRemoved);
    assignin(modelWks,'AVz_bias_v17',def.AVzBiasRemoved);
    assignin('base','Ay_bias_v17',def.AyBiasRemoved);
    assignin('base','AVz_bias_v17',def.AVzBiasRemoved);
    clear('vy_dynamic_ekf_v1_7');
    fprintf(['V1_7_CASE_START|case=%s|Ay_removed=%.15g|', ...
        'AVz_removed=%.15g\n'],def.Case,def.AyBiasRemoved, ...
        def.AVzBiasRemoved);
    timer = tic;
    out = sim(modelName,'StopTime','16','ReturnWorkspaceOutputs','on');
    runs(k) = extract_run(out,def);
    fprintf('V1_7_CASE_DONE|case=%s|updates=%d|elapsed=%.3f\n', ...
        def.Case,numel(runs(k).t),toc(timer));
    if k == 1
        reference = fixed_signals(runs(k));
    else
        verify_fixed(reference,runs(k),def.Case);
    end
end

metadata = struct();
metadata.modelFile = modelFile;
metadata.sourceModel = buildReport.sourceFile;
metadata.wrapperExpression = expression;
metadata.fixedQ = diag([1e-4,1e-4]);
metadata.fixedR = diag([1e-2,3.365172961808e-4]);
metadata.definitions = definitions;
metadata.stopTime = 16;
metadata.estimatorPeriod = 0.01;
metadata.expectedUpdates = 1601;
metadata.truthAlignedUpdates = 1600;
metadata.inputInvarianceVerified = true;
metadata.equivalenceReport = equivalenceReport;
metadata.oracleBiasAblationOnly = true;
metadata.noFinalBiasCompensationApplied = true;
archiveFile = fullfile(resultsDir, ...
    'vy_dekf_v1_7_bias_ablation_runs.mat');
save(archiveFile,'runs','metadata','-v7.3');
fprintf('V1_7_RUN_ARCHIVE|%s\n',archiveFile);
close_system(modelName,0);
close_system('Solver_SF',0);
clear cleanupModel cleanupBase;
analyze_vy_dekf_v1_7_bias_ablation(archiveFile);
clear cleanupFolder;
end

function run = empty_run()
run = struct('Case','','Description','','AyBiasRemoved',0, ...
    'AVzBiasRemoved',0,'t',[],'u',[],'zRaw',[],'zCorrectedLogged',[], ...
    'y',[],'pDiag',[],'diagnostics',[],'vyTrue',[],'rTrue',[]);
end

function run = extract_run(out,def)
[tU,u] = log_matrix(fetch_log(out,{'est_u_log1','outest_u_log1'}));
[tZ,z] = log_matrix(fetch_log(out,{'est_z_log1','out_est_z_log1'}));
[tY,y] = log_matrix(fetch_log(out,{'est_y_log1','outest_y_log1'}));
[tP,p] = log_matrix(fetch_log(out,{'est_P_log1','outest_P_log1'}));
[tD,d] = log_matrix(fetch_log(out,{'est_diag_log1','outest_diag_log1'}));
[tVy,vy] = log_matrix(fetch_log(out, ...
    {'vy_true_log1','Vy_true_log','vy_true_log'}));
[tR,r] = log_matrix(fetch_log(out,{'vy_AVz_true_log'}));
assert(size(d,2) >= 47,'V1.7 diagnostic log must have 47 columns.');
t = tZ(:);
run = empty_run();
run.Case = def.Case;
run.Description = def.Description;
run.AyBiasRemoved = def.AyBiasRemoved;
run.AVzBiasRemoved = def.AVzBiasRemoved;
run.t = t;
run.u = previous(tU,u(:,1:5),t);
run.zRaw = z(:,1:2);
run.y = previous(tY,y(:,1:2),t);
run.pDiag = previous(tP,p(:,1:2),t);
run.diagnostics = previous(tD,d(:,1:47),t);
run.zCorrectedLogged = run.diagnostics(:,46:47);
run.vyTrue = linear(tVy,vy(:,1),t);
run.rTrue = linear(tR,r(:,1),t);
assert(numel(t) == 1601);
assert(all(isfinite([run.u run.zRaw run.zCorrectedLogged run.y ...
    run.pDiag run.diagnostics run.vyTrue run.rTrue]),'all'));
end

function fixed = fixed_signals(run)
fixed = struct('t',run.t,'u',run.u,'zRaw',run.zRaw, ...
    'vyTrue',run.vyTrue,'rTrue',run.rTrue);
end

function verify_fixed(reference,run,caseName)
names = fieldnames(reference);
for k = 1:numel(names)
    difference = abs(reference.(names{k}) - run.(names{k}));
    assert(max(difference,[],'all') <= 1e-10, ...
        'Case %s changed fixed signal %s.',caseName,names{k});
end
end

function value = fetch_log(out,aliases)
available = out.who;
for k = 1:numel(aliases)
    if any(strcmp(available,aliases{k}))
        value = out.get(aliases{k});
        return;
    end
end
error('Required log missing: %s',strjoin(aliases,', '));
end

function [time,data] = log_matrix(value)
if isa(value,'timeseries')
    time = double(value.Time(:)); raw = double(value.Data);
elseif isa(value,'Simulink.SimulationData.Signal')
    [time,data] = log_matrix(value.Values); return;
elseif isstruct(value) && isfield(value,'time') && isfield(value,'signals')
    time = double(value.time(:)); raw = double(value.signals.values);
else
    error('Unsupported log type: %s',class(value));
end
raw = squeeze(raw);
if isvector(raw), data = raw(:);
elseif size(raw,1) == numel(time), data = raw;
elseif size(raw,2) == numel(time), data = raw.';
else, error('Time/data mismatch.');
end
end

function v = previous(ts,x,t), v = interp1(ts(:),x,t(:),'previous','extrap'); end
function v = linear(ts,x,t), v = interp1(ts(:),x,t(:),'linear','extrap'); end
function close_models(m)
if bdIsLoaded(m), close_system(m,0); end
if bdIsLoaded('Solver_SF'), close_system('Solver_SF',0); end
end
function clear_test_variables()
evalin('base','clear Ay_bias_v17 AVz_bias_v17');
end
