function run_vy_dekf_v1_5_covariance_audit()
%RUN_VY_DEKF_V1_5_COVARIANCE_AUDIT Run Cases 1/2/9 without tuning Q or R.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot, 'results');
modelFile = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1_5.slx');
assert(isfile(modelFile), 'V1.5 model missing: %s', modelFile);
addpath(fullfile(repoRoot, 'matlab'));
addpath(fullfile(repoRoot, 'tests'));

% Mandatory gate. Any mismatch throws before Simulink/CarSim is loaded.
equivalenceReport = test_vy_dynamic_ekf_step_v15_debug_equivalence();
assert(equivalenceReport.passed && equivalenceReport.tolerance == 1e-12);

originalFolder = pwd;
cd(fileparts(modelFile));
cleanupFolder = onCleanup(@() cd(originalFolder));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(resultsDir, 'simulink_cache_vy_v1_5'), ...
    'CodeGenFolder', fullfile(resultsDir, 'simulink_codegen_vy_v1_5'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(modelFile);
[~, modelName] = fileparts(modelFile);
cleanupModel = onCleanup(@() close_models(modelName));
cleanupBase = onCleanup(@() clear_test_variables());

wrapperBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
wrapperExpression = get_param(wrapperBlock, 'MATLABFcn');
assert(strcmp(strrep(wrapperExpression, ' ', ''), ...
    'vy_dynamic_ekf_v1_5(u,R_Ay_v15,R_r_v15)'));
modelWks = get_param(modelName, 'ModelWorkspace');

definitions = struct( ...
    'Case', {1, 2, 9}, ...
    'R_Ay', {1e-2, 1e-2, 6.851296026457e-4}, ...
    'R_r', {1e-2, 3.365172961808e-4, 1.132438906288e-5});
runs = repmat(empty_run(), 3, 1);
reference = struct();

for k = 1:3
    def = definitions(k);
    assignin(modelWks, 'R_Ay_v15', def.R_Ay);
    assignin(modelWks, 'R_r_v15', def.R_r);
    assignin('base', 'R_Ay_v15', def.R_Ay);
    assignin('base', 'R_r_v15', def.R_r);
    clear('vy_dynamic_ekf_v1_5');
    fprintf('V1_5_CASE_START|case=%d|R_Ay=%.15g|R_r=%.15g\n', ...
        def.Case, def.R_Ay, def.R_r);
    timer = tic;
    simOut = sim(modelName, 'StopTime', '16', ...
        'ReturnWorkspaceOutputs', 'on');
    runs(k) = extract_run(simOut, def);
    fprintf('V1_5_CASE_DONE|case=%d|updates=%d|elapsed=%.3f\n', ...
        def.Case, numel(runs(k).t), toc(timer));
    if k == 1
        reference = fixed_signals(runs(k));
    else
        verify_fixed_signals(reference, runs(k), def.Case);
    end
end

metadata = struct();
metadata.modelFile = modelFile;
metadata.sourceModel = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1_4.slx');
metadata.wrapperExpression = wrapperExpression;
metadata.Q = diag([1e-4, 1e-3]);
metadata.definitions = definitions;
metadata.stopTime = 16;
metadata.estimatorPeriod = 0.01;
metadata.expectedUpdates = 1601;
metadata.inputInvarianceVerified = true;
metadata.equivalenceReport = equivalenceReport;
metadata.noQOrRChanged = true;

archiveFile = fullfile(resultsDir, ...
    'vy_dekf_v1_5_covariance_audit_runs.mat');
save(archiveFile, 'runs', 'metadata', '-v7.3');
fprintf('V1_5_RUN_ARCHIVE|%s\n', archiveFile);

close_system(modelName, 0);
close_system('Solver_SF', 0);
clear cleanupModel cleanupBase;
analyze_vy_dekf_v1_5_covariance_audit(archiveFile);
clear cleanupFolder;
end

function run = empty_run()
run = struct('Case', 0, 'R_Ay', 0, 'R_r', 0, 't', [], 'u', [], ...
    'z', [], 'y', [], 'pDiag', [], 'diagnostics', [], ...
    'vyTrue', [], 'rTrue', []);
end

function run = extract_run(out, def)
[tU, u] = log_matrix(fetch_log(out, {'est_u_log1','outest_u_log1'}));
[tZ, z] = log_matrix(fetch_log(out, {'est_z_log1','out_est_z_log1'}));
[tY, y] = log_matrix(fetch_log(out, {'est_y_log1','outest_y_log1'}));
[tP, p] = log_matrix(fetch_log(out, {'est_P_log1','outest_P_log1'}));
[tD, d] = log_matrix(fetch_log(out, {'est_diag_log1','outest_diag_log1'}));
[tVy, vy] = log_matrix(fetch_log(out, ...
    {'vy_true_log1','Vy_true_log','vy_true_log'}));
[tR, r] = log_matrix(fetch_log(out, {'vy_AVz_true_log'}));
assert(size(d, 2) >= 41, 'V1.5 diagnostic width must be at least 41.');
t = tZ(:);
run = empty_run();
run.Case = def.Case;
run.R_Ay = def.R_Ay;
run.R_r = def.R_r;
run.t = t;
run.u = previous(tU, u(:,1:5), t);
run.z = z(:,1:2);
run.y = previous(tY, y(:,1:2), t);
run.pDiag = previous(tP, p(:,1:2), t);
run.diagnostics = previous(tD, d(:,1:41), t);
run.vyTrue = linear(tVy, vy(:,1), t);
run.rTrue = linear(tR, r(:,1), t);
assert(numel(t) == 1601 && all(isfinite([run.u run.z run.y ...
    run.pDiag run.diagnostics run.vyTrue run.rTrue]), 'all'));
end

function fixed = fixed_signals(run)
fixed = struct('t', run.t, 'u', run.u, 'z', run.z, ...
    'vyTrue', run.vyTrue, 'rTrue', run.rTrue);
end

function verify_fixed_signals(reference, run, caseNumber)
fields = fieldnames(reference);
for k = 1:numel(fields)
    name = fields{k};
    difference = abs(reference.(name) - run.(name));
    assert(max(difference, [], 'all') <= 1e-10, ...
        'Case %d changed fixed signal %s.', caseNumber, name);
end
end

function value = fetch_log(out, aliases)
available = out.who;
for k = 1:numel(aliases)
    if any(strcmp(available, aliases{k}))
        value = out.get(aliases{k}); return;
    end
end
error('Required log missing: %s', strjoin(aliases, ', '));
end

function [time, data] = log_matrix(value)
if isa(value, 'timeseries')
    time = double(value.Time(:)); raw = double(value.Data);
elseif isa(value, 'Simulink.SimulationData.Signal')
    [time, data] = log_matrix(value.Values); return;
elseif isstruct(value) && isfield(value,'time') && isfield(value,'signals')
    time = double(value.time(:)); raw = double(value.signals.values);
else
    error('Unsupported log type: %s', class(value));
end
raw = squeeze(raw);
if isvector(raw), data = raw(:);
elseif size(raw,1) == numel(time), data = raw;
elseif size(raw,2) == numel(time), data = raw.';
else, error('Time/data size mismatch.');
end
end

function value = previous(ts, x, t)
value = interp1(ts(:), x, t(:), 'previous', 'extrap');
end

function value = linear(ts, x, t)
value = interp1(ts(:), x, t(:), 'linear', 'extrap');
end

function close_models(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
if bdIsLoaded('Solver_SF'), close_system('Solver_SF', 0); end
end

function clear_test_variables()
evalin('base', 'clear R_Ay_v15 R_r_v15');
end
