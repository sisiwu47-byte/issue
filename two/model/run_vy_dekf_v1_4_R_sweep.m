function run_vy_dekf_v1_4_R_sweep()
%RUN_VY_DEKF_V1_4_R_SWEEP Run the controlled 3-by-3 measurement-R sweep.
%
% Every case uses the same V1.4 model, 16 s lateral maneuver, Q, sensors,
% vehicle parameters, 100 Hz execution structure, and true-Vx input. The
% persistent wrapper state is cleared before every simulation. No selected
% R is saved back into the model.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot, 'results');
modelFile = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1_4.slx');
assert(isfile(modelFile), 'V1.4 model is missing: %s', modelFile);

% The CarSim S-Function resolves simfile.sim from the current directory.
% Use the model directory, which contains the already-established D:-drive
% V1 lateral-case simfile. The obsolete repository-root simfile points to
% a non-existent G: installation and must not be used or modified.
originalFolder = pwd;
cd(fileparts(modelFile));
cleanupFolder = onCleanup(@() cd(originalFolder));

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(resultsDir, 'simulink_cache_vy_v1_4'), ...
    'CodeGenFolder', fullfile(resultsDir, 'simulink_codegen_vy_v1_4'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(modelFile);
[~, modelName] = fileparts(modelFile);
cleanupModel = onCleanup(@() close_models(modelName));
cleanupBaseVariables = onCleanup(@() clear_sweep_variables());

wrapperBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
wrapperExpression = get_param(wrapperBlock, 'MATLABFcn');
assert(strcmp(strrep(wrapperExpression, ' ', ''), ...
    'vy_dynamic_ekf_v1_4(u,R_Ay_v14,R_r_v14)'), ...
    'Unexpected V1.4 wrapper expression: %s', wrapperExpression);

modelWks = get_param(modelName, 'ModelWorkspace');
R_Ay_levels = [1e-2, 2.617498047078e-3, 6.851296026457e-4];
R_r_levels = [1e-2, 3.365172961808e-4, 1.132438906288e-5];
levelNames = {'H', 'M', 'L'};

caseDefinitions = repmat(struct( ...
    'Case', 0, 'LevelAy', '', 'LevelR', '', 'R_Ay', 0, 'R_r', 0), 9, 1);
caseIndex = 0;
for ayIndex = 1:3
    for rIndex = 1:3
        caseIndex = caseIndex + 1;
        caseDefinitions(caseIndex).Case = caseIndex;
        caseDefinitions(caseIndex).LevelAy = levelNames{ayIndex};
        caseDefinitions(caseIndex).LevelR = levelNames{rIndex};
        caseDefinitions(caseIndex).R_Ay = R_Ay_levels(ayIndex);
        caseDefinitions(caseIndex).R_r = R_r_levels(rIndex);
    end
end

runs = repmat(empty_run(), 9, 1);
referenceInputs = struct();

for k = 1:9
    def = caseDefinitions(k);
    assignin(modelWks, 'R_Ay_v14', def.R_Ay);
    assignin(modelWks, 'R_r_v14', def.R_r);
    % Interpreted MATLAB Function resolves non-u symbols in the base
    % workspace. Mirror the controlled test parameters there explicitly;
    % cleanupBaseVariables guarantees that they do not persist afterward.
    assignin('base', 'R_Ay_v14', def.R_Ay);
    assignin('base', 'R_r_v14', def.R_r);

    % Required hard reset: no state or covariance can leak across cases.
    clear('vy_dynamic_ekf_v1_4');
    fprintf(['V1_4_CASE_START|case=%d|levels=%s%s|', ...
        'R_Ay=%.15g|R_r=%.15g\n'], ...
        k, def.LevelAy, def.LevelR, def.R_Ay, def.R_r);
    caseTimer = tic;
    simOut = sim(modelName, 'StopTime', '16', ...
        'ReturnWorkspaceOutputs', 'on');
    runs(k) = extract_run(simOut, def);
    fprintf('V1_4_CASE_DONE|case=%d|samples=%d|elapsed=%.3f\n', ...
        k, numel(runs(k).t), toc(caseTimer));

    if k == 1
        referenceInputs.t = runs(k).t;
        referenceInputs.u = runs(k).u;
        referenceInputs.z = runs(k).z;
        referenceInputs.vyTrue = runs(k).vyTrue;
        referenceInputs.rTrue = runs(k).rTrue;
    else
        assert_same_case(referenceInputs, runs(k), k);
    end
end

metadata = struct();
metadata.modelFile = modelFile;
metadata.wrapperExpression = wrapperExpression;
metadata.Q = diag([1e-4, 1e-3]);
metadata.R_Ay_levels = R_Ay_levels;
metadata.R_r_levels = R_r_levels;
metadata.caseDefinitions = caseDefinitions;
metadata.stopTime = 16;
metadata.estimatorPeriod = 0.01;
metadata.expectedUpdates = 1601;
metadata.inputInvarianceVerified = true;
metadata.trueVyUsedOfflineOnly = true;
metadata.NEESAvailable = false;

runArchive = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep_runs.mat');
save(runArchive, 'runs', 'metadata', '-v7.3');
fprintf('V1_4_RUN_ARCHIVE|%s\n', runArchive);

% Discard the final in-memory L/L workspace values. On-disk V1.4 remains
% at the neutral H/H baseline created by build_vy_dekf_v1_4_model.
close_system(modelName, 0);
close_system('Solver_SF', 0);
clear cleanupModel;
clear cleanupBaseVariables;

analyze_vy_dekf_v1_4_R_sweep(runArchive);
clear cleanupFolder;
end

function run = empty_run()
run = struct('Case', 0, 'LevelAy', '', 'LevelR', '', ...
    'R_Ay', 0, 'R_r', 0, 't', [], 'u', [], 'z', [], 'y', [], ...
    'pDiag', [], 'diagnostics', [], 'vyTrue', [], 'rTrue', []);
end

function run = extract_run(simOut, def)
[tU, u] = log_matrix(fetch_log(simOut, ...
    {'est_u_log1', 'outest_u_log1'}), 'est_u_log1');
[tZ, z] = log_matrix(fetch_log(simOut, ...
    {'est_z_log1', 'out_est_z_log1'}), 'est_z_log1');
[tY, y] = log_matrix(fetch_log(simOut, ...
    {'est_y_log1', 'outest_y_log1'}), 'est_y_log1');
[tP, pDiag] = log_matrix(fetch_log(simOut, ...
    {'est_P_log1', 'outest_P_log1'}), 'est_P_log1');
[tD, diagnostics] = log_matrix(fetch_log(simOut, ...
    {'est_diag_log1', 'outest_diag_log1'}), 'est_diag_log1');
[tVy, vyTrue] = log_matrix(fetch_log(simOut, ...
    {'vy_true_log1', 'Vy_true_log', 'vy_true_log'}), 'vy_true_log1');
[tR, rTrue] = log_matrix(fetch_log(simOut, ...
    {'vy_AVz_true_log'}), 'vy_AVz_true_log');

assert(size(u, 2) >= 5, 'u log must contain five columns.');
assert(size(z, 2) >= 2, 'z log must contain two columns.');
assert(size(y, 2) >= 2, 'state log must contain two columns.');
assert(size(pDiag, 2) >= 2, 'P log must contain P11 and P22.');
assert(size(diagnostics, 2) >= 11, ...
    'V1.4 diagnostic log must include innovations (11 columns).');

t = tZ(:);
run = empty_run();
run.Case = def.Case;
run.LevelAy = def.LevelAy;
run.LevelR = def.LevelR;
run.R_Ay = def.R_Ay;
run.R_r = def.R_r;
run.t = t;
run.u = sample_previous(tU, u(:, 1:5), t);
run.z = z(:, 1:2);
run.y = sample_previous(tY, y(:, 1:2), t);
run.pDiag = sample_previous(tP, pDiag(:, 1:2), t);
run.diagnostics = sample_previous(tD, diagnostics(:, 1:11), t);
run.vyTrue = sample_linear(tVy, vyTrue(:, 1), t);
run.rTrue = sample_linear(tR, rTrue(:, 1), t);
end

function assert_same_case(reference, run, caseNumber)
assert(isequal(size(reference.t), size(run.t)) && ...
    max(abs(reference.t - run.t)) <= 1e-12, ...
    'Case %d has a different time axis.', caseNumber);
signals = {'u', 'z', 'vyTrue', 'rTrue'};
for k = 1:numel(signals)
    name = signals{k};
    difference = abs(reference.(name) - run.(name));
    assert(all(isfinite(difference), 'all') && max(difference, [], 'all') <= 1e-10, ...
        'Case %d changed fixed signal %s (max diff %.15g).', ...
        caseNumber, name, max(difference, [], 'all'));
end
end

function value = fetch_log(container, aliases)
available = container.who;
for k = 1:numel(aliases)
    if any(strcmp(available, aliases{k}))
        value = container.get(aliases{k});
        return;
    end
end
error('run_vy_dekf_v1_4:MissingLog', ...
    'Required log missing. Accepted aliases: %s', strjoin(aliases, ', '));
end

function [time, data] = log_matrix(value, name)
if isa(value, 'timeseries')
    time = double(value.Time(:));
    raw = double(value.Data);
elseif isa(value, 'Simulink.SimulationData.Signal')
    [time, data] = log_matrix(value.Values, name);
    return;
elseif isstruct(value) && isfield(value, 'time') && isfield(value, 'signals')
    time = double(value.time(:));
    raw = double(value.signals.values);
else
    error('run_vy_dekf_v1_4:UnsupportedLog', ...
        'Unsupported log type for %s: %s', name, class(value));
end
raw = squeeze(raw);
if isvector(raw)
    data = raw(:);
elseif size(raw, 1) == numel(time)
    data = raw;
elseif size(raw, 2) == numel(time)
    data = raw.';
else
    error('run_vy_dekf_v1_4:LogSize', ...
        'Time/data size mismatch for %s.', name);
end
end

function sampled = sample_previous(sourceTime, sourceData, targetTime)
sampled = interp1(sourceTime(:), sourceData, targetTime(:), ...
    'previous', 'extrap');
end

function sampled = sample_linear(sourceTime, sourceData, targetTime)
sampled = interp1(sourceTime(:), sourceData, targetTime(:), ...
    'linear', 'extrap');
end

function close_models(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if bdIsLoaded('Solver_SF')
    close_system('Solver_SF', 0);
end
end

function clear_sweep_variables()
evalin('base', 'clear R_Ay_v14 R_r_v14');
end
