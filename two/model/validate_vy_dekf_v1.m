%% validate_vy_dekf_v1
% V1.2 baseline validation for the existing Vy Dynamic EKF logs.
%
% This script never loads, edits, or simulates a Simulink model. It only
% reads logs already present in the base workspace/SimulationOutput, or the
% archived SimulationOutput written by the baseline run.

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));
resultsDir = fullfile(repoRoot, 'results');
if ~isfolder(resultsDir)
    error('validate_vy_dekf_v1:MissingResultsDir', ...
        'Results directory does not exist: %s', resultsDir);
end

[logContainer, logSource] = locate_log_container(resultsDir);

[uLog, uName] = fetch_log(logContainer, ...
    {'est_u_log1', 'outest_u_log1'});
[zLog, zName] = fetch_log(logContainer, ...
    {'est_z_log1', 'out_est_z_log1'});
[yLog, yName] = fetch_log(logContainer, ...
    {'est_y_log1', 'outest_y_log1'});
[pLog, pName] = fetch_log(logContainer, ...
    {'est_P_log1', 'outest_P_log1'});
[diagLog, diagName] = fetch_log(logContainer, ...
    {'est_diag_log1', 'outest_diag_log1'});

[tU, u] = log_to_matrix(uLog, uName);
[tZ, z] = log_to_matrix(zLog, zName);
[tY, y] = log_to_matrix(yLog, yName);
[tP, pDiag] = log_to_matrix(pLog, pName);
[tDiag, diagnostics] = log_to_matrix(diagLog, diagName);

require_columns(u, 5, uName);
require_columns(z, 2, zName);
require_columns(y, 2, yName);
require_columns(pDiag, 2, pName);
require_columns(diagnostics, 9, diagName);

vx = u(:, 1);
steering = u(:, 2:5);
ay = z(:, 1);
avz = z(:, 2);
vyHat = y(:, 1);
rHat = y(:, 2);
pVy = pDiag(:, 1);
pR = pDiag(:, 2);
nis = diagnostics(:, 1);
fy = diagnostics(:, 2:5);
alpha = diagnostics(:, 6:9);

wheelNames = {'FL', 'FR', 'RL', 'RR'};
reportFile = fullfile(resultsDir, 'vy_dekf_v1_report.txt');
reportFid = fopen(reportFile, 'w');
if reportFid < 0
    error('validate_vy_dekf_v1:ReportOpenFailed', ...
        'Cannot open report file: %s', reportFile);
end
reportCleanup = onCleanup(@() fclose(reportFid));

emit(reportFid, 'Vy Dynamic EKF V1.2 baseline validation\n');
emit(reportFid, 'Log source: %s\n', logSource);
emit(reportFid, 'Required logs: %s, %s, %s, %s, %s\n\n', ...
    uName, zName, yName, pName, diagName);

emit(reportFid, '1. Input signal range report\n');
print_range(reportFid, 'Vx [m/s]', vx);
for k = 1:4
    print_range(reportFid, sprintf('Steer_%s [rad]', wheelNames{k}), ...
        steering(:, k));
end
print_range(reportFid, 'Ay [m/s^2]', ay);
print_range(reportFid, 'AVz [rad/s]', avz);
emit(reportFid, '\n');

emit(reportFid, '2. State estimate ranges\n');
print_range(reportFid, 'Vy_hat [m/s]', vyHat);
print_range(reportFid, 'r_hat [rad/s]', rHat);
emit(reportFid, '\n');

emit(reportFid, '3. Covariance ranges\n');
print_range(reportFid, 'P_vy', pVy);
print_range(reportFid, 'P_r', pR);
emit(reportFid, '\n');

ekfTs = 0.01;
tNisUpdate = (tDiag(1):ekfTs:(tDiag(end) + ekfTs / 10)).';
nisAtUpdate = interp1(tDiag, nis, tNisUpdate, 'previous', 'extrap');
nisFinite = finite_values(nisAtUpdate);
emit(reportFid, '4. NIS statistics\n');
emit(reportFid, 'NIS update samples = %d\n', numel(nisFinite));
emit(reportFid, 'NIS mean       = %.12g\n', mean(nisFinite));
emit(reportFid, 'NIS median     = %.12g\n', median(nisFinite));
emit(reportFid, 'NIS max        = %.12g\n', max(nisFinite));
emit(reportFid, 'NIS percentile95 = %.12g\n\n', ...
    percentile_linear(nisFinite, 95));

emit(reportFid, '5. Four-wheel model output ranges\n');
for k = 1:4
    print_range(reportFid, sprintf('Fy_%s [N]', wheelNames{k}), fy(:, k));
end
for k = 1:4
    print_range(reportFid, sprintf('alpha_%s [rad]', wheelNames{k}), ...
        alpha(:, k));
end
emit(reportFid, '\n');

dtU = median_positive_dt(tU);
dtZ = median_positive_dt(tZ);
dtY = median_positive_dt(tY);
dtP = median_positive_dt(tP);
dtDiag = median_positive_dt(tDiag);
emit(reportFid, '6. Logged update periods\n');
emit(reportFid, 'u log dt    = %.12g s\n', dtU);
emit(reportFid, 'z log dt    = %.12g s\n', dtZ);
emit(reportFid, 'y log dt    = %.12g s\n', dtY);
emit(reportFid, 'P log dt    = %.12g s\n', dtP);
emit(reportFid, 'diag log dt = %.12g s\n\n', dtDiag);

maxSteerByWheel = max(abs(steering), [], 1);
maxSteer = max(maxSteerByWheel);
maxAy = max(abs(finite_values(ay)));
maxAvz = max(abs(finite_values(avz)));
hasLateralExcitation = (maxAy > 0.5) || (maxAvz > 0.05) || ...
    (maxSteer > 0.01);
emit(reportFid, '7. Lateral-excitation sufficiency\n');
for k = 1:4
    emit(reportFid, 'max(abs(Steer_%s)) = %.12g rad\n', ...
        wheelNames{k}, maxSteerByWheel(k));
end
emit(reportFid, 'max(abs(any steering)) = %.12g rad\n', maxSteer);
emit(reportFid, 'max(abs(Ay))           = %.12g m/s^2\n', maxAy);
emit(reportFid, 'max(abs(AVz))          = %.12g rad/s\n', maxAvz);
if hasLateralExcitation
    emit(reportFid, 'CURRENT CASE HAS SUFFICIENT LATERAL EXCITATION FOR BASELINE VALIDATION\n\n');
else
    emit(reportFid, 'CURRENT CASE IS NOT SUFFICIENT FOR D-EKF LATERAL VALIDATION\n\n');
end

[hasVyTrue, vyTrueLog, vyTrueName] = fetch_optional_log(logContainer, ...
    {'vy_true_log1', 'Vy_true_log', 'vy_true_log'});
vyTrueOnEstimateTime = [];
vyError = [];
if hasVyTrue
    [tVyTrue, vyTrue] = log_to_matrix(vyTrueLog, vyTrueName);
    require_columns(vyTrue, 1, vyTrueName);
    vyTrueOnEstimateTime = interp1(tVyTrue, vyTrue(:, 1), tY, ...
        'linear', 'extrap');
    vyError = vyHat - vyTrueOnEstimateTime;
    compareMask = isfinite(vyError);
    compareError = vyError(compareMask);
    emit(reportFid, '8. Offline CarSim Vy comparison (not an EKF input)\n');
    emit(reportFid, 'True Vy log: %s\n', vyTrueName);
    emit(reportFid, 'Vy error bias = %.12g m/s\n', mean(compareError));
    emit(reportFid, 'Vy error MAE  = %.12g m/s\n', mean(abs(compareError)));
    emit(reportFid, 'Vy error RMSE = %.12g m/s\n', ...
        sqrt(mean(compareError.^2)));
    emit(reportFid, 'Vy max error  = %.12g m/s\n\n', ...
        max(abs(compareError)));
else
    emit(reportFid, '8. Offline CarSim Vy comparison\n');
    emit(reportFid, 'No existing true Vy log was found; none was added.\n\n');
end

rHatOnMeasurementTime = interp1(tY, rHat, tZ, 'previous', 'extrap');
yawRateError = rHatOnMeasurementTime - avz;
yawRateErrorFinite = finite_values(yawRateError);
emit(reportFid, '9. IMU AVz versus D-EKF r_hat\n');
emit(reportFid, 'r error bias = %.12g rad/s\n', mean(yawRateErrorFinite));
emit(reportFid, 'r error MAE  = %.12g rad/s\n', ...
    mean(abs(yawRateErrorFinite)));
emit(reportFid, 'r error RMSE = %.12g rad/s\n', ...
    sqrt(mean(yawRateErrorFinite.^2)));
emit(reportFid, 'r max error  = %.12g rad/s\n\n', ...
    max(abs(yawRateErrorFinite)));

figureVisibility = 'off';
if usejava('desktop')
    figureVisibility = 'on';
end

fig1 = figure('Name', 'Vy D-EKF state comparisons and errors', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig1, 4, 1, 'TileSpacing', 'compact');
nexttile;
plot(tY, vyHat, 'LineWidth', 1.0);
hold on;
if hasVyTrue
    plot(tY, vyTrueOnEstimateTime, '--', 'LineWidth', 1.0);
    legend('Vy hat', 'CarSim true Vy', 'Location', 'best');
else
    legend('Vy hat', 'Location', 'best');
end
grid on;
ylabel('Vy [m/s]');
title('CarSim Vy and D-EKF Vy estimate');
nexttile;
if hasVyTrue
    plot(tY, vyError, 'LineWidth', 0.9);
else
    plot(tY, nan(size(tY)));
end
grid on;
ylabel('Vy error [m/s]');
title('Vy hat - CarSim Vy');
nexttile;
plot(tZ, avz, 'LineWidth', 1.0);
hold on;
plot(tZ, rHatOnMeasurementTime, '--', 'LineWidth', 1.0);
grid on;
legend('AVz measured', 'r hat', 'Location', 'best');
ylabel('Yaw rate [rad/s]');
title('Measured AVz and D-EKF yaw rate');
nexttile;
plot(tZ, yawRateError, 'LineWidth', 0.9);
grid on;
xlabel('Time [s]');
ylabel('r error [rad/s]');
title('r hat - AVz measured');
statesFigureFile = fullfile(resultsDir, 'vy_dekf_v1_state_errors.png');
exportgraphics(fig1, statesFigureFile, 'Resolution', 160);

fig2 = figure('Name', 'Vy D-EKF covariance and NIS', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact');
nexttile;
plot(tP, [pVy, pR], 'LineWidth', 1.0);
grid on;
legend('P vy', 'P r', 'Location', 'best');
ylabel('Variance');
title('State covariance diagonal');
nexttile;
plot(tNisUpdate, nisAtUpdate, 'LineWidth', 0.9);
grid on;
xlabel('Time [s]');
ylabel('NIS');
title('NIS at true 100 Hz D-EKF updates');
covarianceFigureFile = fullfile(resultsDir, 'vy_dekf_v1_covariance_nis.png');
exportgraphics(fig2, covarianceFigureFile, 'Resolution', 160);

fig3 = figure('Name', 'Vy D-EKF measured inputs', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig3, 3, 1, 'TileSpacing', 'compact');
nexttile;
plot(tU, steering, 'LineWidth', 0.9);
grid on;
legend(wheelNames, 'Location', 'best');
ylabel('Steer [rad]');
title('Four-wheel steering');
nexttile;
plot(tZ, ay, 'LineWidth', 0.9);
grid on;
ylabel('Ay [m/s^2]');
title('Lateral acceleration');
nexttile;
plot(tZ, avz, 'LineWidth', 0.9);
grid on;
xlabel('Time [s]');
ylabel('AVz [rad/s]');
title('Yaw rate measurement');
inputsFigureFile = fullfile(resultsDir, 'vy_dekf_v1_inputs.png');
exportgraphics(fig3, inputsFigureFile, 'Resolution', 160);

fig4 = figure('Name', 'Vy D-EKF tire-model diagnostics', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig4, 2, 1, 'TileSpacing', 'compact');
nexttile;
plot(tDiag, fy, 'LineWidth', 0.8);
grid on;
legend(wheelNames, 'Location', 'best');
ylabel('Fy [N]');
title('Four-wheel model lateral force');
nexttile;
plot(tDiag, alpha, 'LineWidth', 0.8);
grid on;
legend(wheelNames, 'Location', 'best');
xlabel('Time [s]');
ylabel('alpha [rad]');
title('Four-wheel model slip angle');
tireFigureFile = fullfile(resultsDir, 'vy_dekf_v1_tire_model.png');
exportgraphics(fig4, tireFigureFile, 'Resolution', 160);

emit(reportFid, '10. Generated outputs\n');
emit(reportFid, 'Report: %s\n', reportFile);
emit(reportFid, 'State comparisons/errors figure: %s\n', statesFigureFile);
emit(reportFid, 'Covariance/NIS figure: %s\n', covarianceFigureFile);
emit(reportFid, 'Measured inputs figure: %s\n', inputsFigureFile);
emit(reportFid, 'Tire-model figure: %s\n', tireFigureFile);

if strcmp(figureVisibility, 'off')
    close(fig1);
    close(fig2);
    close(fig3);
    close(fig4);
end

clear reportCleanup;

%% Local helpers
function [container, sourceDescription] = locate_log_container(resultsDir)
container = [];
sourceDescription = '';
if evalin('base', 'exist(''out'', ''var'')')
    container = evalin('base', 'out');
    sourceDescription = 'base workspace variable out';
elseif evalin('base', 'exist(''simOut'', ''var'')')
    container = evalin('base', 'simOut');
    sourceDescription = 'base workspace variable simOut';
else
    archiveFile = fullfile(resultsDir, 'vy_dekf_v1_simout.mat');
    if ~isfile(archiveFile)
        error('validate_vy_dekf_v1:MissingLogs', ...
            ['No base-workspace out/simOut variable and no archived ', ...
             'SimulationOutput found at %s.'], archiveFile);
    end
    loaded = load(archiveFile);
    if isfield(loaded, 'simOut')
        container = loaded.simOut;
    elseif isfield(loaded, 'out')
        container = loaded.out;
    else
        container = loaded;
    end
    sourceDescription = archiveFile;
end
end

function [value, matchedName] = fetch_log(container, aliases)
[found, value, matchedName] = fetch_optional_log(container, aliases);
if ~found
    error('validate_vy_dekf_v1:MissingRequiredLog', ...
        'Required log was not found. Accepted names: %s', ...
        strjoin(aliases, ', '));
end
end

function [found, value, matchedName] = fetch_optional_log(container, aliases)
found = false;
value = [];
matchedName = '';
for k = 1:numel(aliases)
    name = aliases{k};
    if evalin('base', sprintf('exist(''%s'', ''var'')', name))
        value = evalin('base', name);
        matchedName = name;
        found = true;
        return;
    end
    if isa(container, 'Simulink.SimulationOutput')
        available = container.who;
        if any(strcmp(available, name))
            value = container.get(name);
            matchedName = name;
            found = true;
            return;
        end
    elseif isstruct(container) && isfield(container, name)
        value = container.(name);
        matchedName = name;
        found = true;
        return;
    elseif isa(container, 'Simulink.SimulationData.Dataset')
        try
            element = container.get(name);
            if ~isempty(element)
                value = element;
                matchedName = name;
                found = true;
                return;
            end
        catch
        end
    end
end
end

function [time, data] = log_to_matrix(logValue, logName)
if isa(logValue, 'timeseries')
    time = double(logValue.Time(:));
    raw = logValue.Data;
elseif isa(logValue, 'Simulink.SimulationData.Signal')
    [time, data] = log_to_matrix(logValue.Values, logName);
    return;
elseif isa(logValue, 'Simulink.SimulationData.Dataset')
    if logValue.numElements ~= 1
        error('validate_vy_dekf_v1:AmbiguousDataset', ...
            'Log %s is a Dataset with %d elements.', ...
            logName, logValue.numElements);
    end
    [time, data] = log_to_matrix(logValue.getElement(1), logName);
    return;
elseif istimetable(logValue)
    time = seconds(logValue.Properties.RowTimes - ...
        logValue.Properties.RowTimes(1));
    raw = logValue.Variables;
elseif isstruct(logValue) && isfield(logValue, 'time') && ...
        isfield(logValue, 'signals')
    time = double(logValue.time(:));
    raw = logValue.signals.values;
elseif isnumeric(logValue)
    raw = logValue;
    time = (0:size(raw, 1) - 1).';
else
    error('validate_vy_dekf_v1:UnsupportedLogType', ...
        'Unsupported type for %s: %s', logName, class(logValue));
end

raw = double(raw);
raw = squeeze(raw);
nTime = numel(time);
if isvector(raw)
    data = raw(:);
elseif ndims(raw) == 2
    if size(raw, 1) == nTime
        data = raw;
    elseif size(raw, 2) == nTime
        data = raw.';
    else
        error('validate_vy_dekf_v1:TimeDataMismatch', ...
            'Time/data size mismatch for %s: time=%d, data=%s.', ...
            logName, nTime, mat2str(size(raw)));
    end
else
    timeDimension = find(size(raw) == nTime, 1, 'last');
    if isempty(timeDimension)
        error('validate_vy_dekf_v1:TimeDataMismatch', ...
            'Cannot find the time dimension for %s.', logName);
    end
    order = [timeDimension, setdiff(1:ndims(raw), timeDimension, 'stable')];
    data = reshape(permute(raw, order), nTime, []);
end
end

function require_columns(data, minimumColumns, logName)
if size(data, 2) < minimumColumns
    error('validate_vy_dekf_v1:LogWidth', ...
        'Log %s has %d columns; at least %d are required.', ...
        logName, size(data, 2), minimumColumns);
end
end

function values = finite_values(values)
values = values(isfinite(values));
if isempty(values)
    error('validate_vy_dekf_v1:NoFiniteData', ...
        'A required signal contains no finite samples.');
end
end

function print_range(fid, label, values)
values = finite_values(values);
emit(fid, '%-22s min=% .12g  max=% .12g  max(abs)=% .12g\n', ...
    label, min(values), max(values), max(abs(values)));
end

function dt = median_positive_dt(time)
delta = diff(time(:));
delta = delta(isfinite(delta) & delta > 0);
if isempty(delta)
    dt = NaN;
else
    dt = median(delta);
end
end

function value = percentile_linear(values, percentile)
values = sort(finite_values(values));
if numel(values) == 1
    value = values(1);
    return;
end
position = 1 + (numel(values) - 1) * percentile / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
weight = position - lowerIndex;
value = values(lowerIndex) * (1 - weight) + values(upperIndex) * weight;
end

function emit(fid, formatText, varargin)
fprintf(formatText, varargin{:});
fprintf(fid, formatText, varargin{:});
end
