%% analyze_vy_dekf_v1_3_consistency
% Statistical characterization only. This script reads existing V1.3
% logs and never loads, simulates, or modifies a Simulink model. It does
% not apply the candidate R and does not change Q.

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));
resultsDir = fullfile(repoRoot, 'results');
[container, logSource] = locate_log_container(resultsDir);

zLog = fetch_log(container, {'est_z_log1', 'out_est_z_log1'});
diagLog = fetch_log(container, {'est_diag_log1', 'outest_diag_log1'});
ayTrueLog = fetch_log(container, {'vy_Ay_true_log'});
avzTrueLog = fetch_log(container, {'vy_AVz_true_log'});

[tZ, z] = log_to_matrix(zLog, 'est_z_log1');
[tDiag, diagnostics] = log_to_matrix(diagLog, 'est_diag_log1');
[tAyTrue, ayTrueRaw] = log_to_matrix(ayTrueLog, 'vy_Ay_true_log');
[tAvzTrue, avzTrueRaw] = log_to_matrix(avzTrueLog, 'vy_AVz_true_log');

require_columns(z, 2, 'est_z_log1');
require_columns(diagnostics, 11, 'est_diag_log1');
require_columns(ayTrueRaw, 1, 'vy_Ay_true_log');
require_columns(avzTrueRaw, 1, 'vy_AVz_true_log');

% The IMU log is the required 100 Hz common time axis.
t = tZ(:);
ayImu = z(:, 1);
avzImu = z(:, 2);
ayTrue = interp1(tAyTrue, ayTrueRaw(:, 1), t, 'linear', 'extrap');
avzTrue = interp1(tAvzTrue, avzTrueRaw(:, 1), t, 'linear', 'extrap');

% The true logs are taken after the existing unit conversions:
% Gain36 = 9.8 for Ay and Gain10 = pi/180 for AVz.
eAy = ayImu - ayTrue;
eR = avzImu - avzTrue;
assert(all(isfinite([eAy; eR])), 'Sensor-error vectors contain NaN/Inf.');

ayStats = summarize_error(eAy);
rStats = summarize_error(eR);
biasAy = ayStats.mean;
biasR = rStats.mean;
noiseAy = eAy - biasAy;
noiseR = eR - biasR;
varNoiseAy = var(noiseAy, 0);
varNoiseR = var(noiseR, 0);

maxLag = 20;
rhoAy = normalized_acf(noiseAy, maxLag);
rhoR = normalized_acf(noiseR, maxLag);
lags = (0:maxLag).';

% diag_out layout in V1.3:
% [NIS, Fy(4), alpha(4), innovation_Ay, innovation_r].
nis = interp1(tDiag, diagnostics(:, 1), t, 'previous', 'extrap');
innovationAy = interp1(tDiag, diagnostics(:, 10), t, ...
    'previous', 'extrap');
innovationR = interp1(tDiag, diagnostics(:, 11), t, ...
    'previous', 'extrap');
innovationAyStats = summarize_basic(innovationAy);
innovationRStats = summarize_basic(innovationR);

nisFinite = finite_values(nis);
nisMean = mean(nisFinite);
nisMedian = median(nisFinite);
nisP95 = percentile_linear(nisFinite, 95);
nisMax = max(nisFinite);
chi2Upper95 = 5.991464547;
nisFractionBelow95 = mean(nisFinite <= chi2Upper95);

currentR = diag([1e-2, 1e-2]);
rSensorCandidate = diag([varNoiseAy, varNoiseR]);
currentStd = sqrt(diag(currentR));
candidateStd = sqrt(diag(rSensorCandidate));
ratioAy = safe_ratio(currentR(1, 1), varNoiseAy);
ratioR = safe_ratio(currentR(2, 2), varNoiseR);

reportFile = fullfile(resultsDir, ...
    'vy_dekf_v1_3_sensor_statistics.txt');
fid = fopen(reportFile, 'w');
if fid < 0
    error('analyze_vy_dekf_v1_3:ReportOpenFailed', ...
        'Cannot open report: %s', reportFile);
end
cleanupReport = onCleanup(@() fclose(fid));

emit(fid, 'Vy D-EKF V1.3 statistical consistency characterization\n');
emit(fid, 'Log source: %s\n', logSource);
emit(fid, 'Common time axis: %d samples, median dt %.12g s\n', ...
    numel(t), median(diff(t)));
emit(fid, 'Ay_true source: CarSim Ay followed by Gain36 = 9.8 [m/s^2]\n');
emit(fid, 'AVz_true source: CarSim AVz followed by Gain10 = pi/180 [rad/s]\n');
emit(fid, 'No Q/R/model/filter parameter was changed.\n\n');

emit(fid, 'A. Ay sensor error e_Ay = Ay_IMU - Ay_true\n');
print_error_stats(fid, ayStats, 'm/s^2');
emit(fid, '\n');

emit(fid, 'B. AVz sensor error e_r = AVz_IMU - AVz_true\n');
print_error_stats(fid, rStats, 'rad/s');
emit(fid, '\n');

emit(fid, 'C. Bias-separated empirical noise variance (sample variance, N-1)\n');
emit(fid, 'bias_Ay       = %.15g m/s^2\n', biasAy);
emit(fid, 'bias_r        = %.15g rad/s\n', biasR);
emit(fid, 'var(noise_Ay) = %.15g (m/s^2)^2\n', varNoiseAy);
emit(fid, 'var(noise_r)  = %.15g (rad/s)^2\n\n', varNoiseR);

emit(fid, 'D/E/F. Current R and sensor candidate (candidate is NOT applied)\n');
emit(fid, 'current R = diag([%.15g, %.15g])\n', currentR(1, 1), currentR(2, 2));
emit(fid, 'R_sensor_candidate = diag([%.15g, %.15g])\n', ...
    varNoiseAy, varNoiseR);
emit(fid, 'sqrt(current R_Ay)   = %.15g m/s^2\n', currentStd(1));
emit(fid, 'sqrt(candidate R_Ay) = %.15g m/s^2\n', candidateStd(1));
emit(fid, 'sqrt(current R_r)    = %.15g rad/s\n', currentStd(2));
emit(fid, 'sqrt(candidate R_r)  = %.15g rad/s\n', candidateStd(2));
emit(fid, 'current_R_Ay / candidate_R_Ay = %.15g\n', ratioAy);
emit(fid, 'current_R_r  / candidate_R_r  = %.15g\n\n', ratioR);

emit(fid, 'G. noise_Ay normalized autocorrelation\n');
print_selected_acf(fid, rhoAy);
emit(fid, '\n');
emit(fid, 'H. noise_r normalized autocorrelation\n');
print_selected_acf(fid, rhoR);
emit(fid, '\n');

emit(fid, 'I. innovation Ay channel\n');
print_basic_stats(fid, innovationAyStats, 'm/s^2');
emit(fid, '\n');
emit(fid, 'J. innovation r channel\n');
print_basic_stats(fid, innovationRStats, 'rad/s');
emit(fid, '\n');

emit(fid, 'K. NIS consistency (measurement dimension m=2)\n');
emit(fid, 'theoretical expected mean ~= 2\n');
emit(fid, 'chi-square 95%% upper threshold = %.12g\n', chi2Upper95);
emit(fid, 'NIS mean       = %.15g\n', nisMean);
emit(fid, 'NIS median     = %.15g\n', nisMedian);
emit(fid, 'NIS p95        = %.15g\n', nisP95);
emit(fid, 'NIS max        = %.15g\n', nisMax);
emit(fid, 'fraction NIS <= chi2_95 = %.15g (%.9g%%)\n\n', ...
    nisFractionBelow95, 100 * nisFractionBelow95);

emit(fid, 'L. Interpretation\n');
if nisMean < 0.2 * 2 && ratioAy > 1 && ratioR > 1
    emit(fid, ['YES: the extremely low NIS is statistically consistent ', ...
        'with current R being larger than the empirical zero-mean ', ...
        'sensor-error variance.\n']);
else
    emit(fid, ['The measured statistics do not by themselves support a ', ...
        'clear oversized-R interpretation.\n']);
end
emit(fid, ['This does not prove that R is the only cause: model error, Q, ', ...
    'innovation dynamics, bias, and colored noise also affect NIS.\n']);
emit(fid, ['The 20 Hz low-pass filter creates temporal correlation, so ', ...
    'R_sensor_candidate must not be applied automatically as white-noise R.\n']);
emit(fid, 'No candidate R was written to a model or MATLAB wrapper.\n');

figureVisibility = 'off';
if usejava('desktop')
    figureVisibility = 'on';
end

fig1 = figure('Name', 'V1.3 IMU sensor errors', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig1, 4, 1, 'TileSpacing', 'compact');
nexttile;
plot(t, ayTrue, 'LineWidth', 0.9);
hold on;
plot(t, ayImu, '--', 'LineWidth', 0.9);
grid on;
legend('Ay true', 'Ay IMU', 'Location', 'best');
ylabel('m/s^2');
title('Ay before and after virtual IMU');
nexttile;
plot(t, eAy, 'LineWidth', 0.9);
grid on;
ylabel('e Ay [m/s^2]');
title('Ay sensor error');
nexttile;
plot(t, avzTrue, 'LineWidth', 0.9);
hold on;
plot(t, avzImu, '--', 'LineWidth', 0.9);
grid on;
legend('AVz true', 'AVz IMU', 'Location', 'best');
ylabel('rad/s');
title('AVz before and after virtual IMU');
nexttile;
plot(t, eR, 'LineWidth', 0.9);
grid on;
xlabel('Time [s]');
ylabel('e r [rad/s]');
title('Yaw-rate sensor error');
sensorErrorFigure = fullfile(resultsDir, ...
    'vy_dekf_v1_3_sensor_errors.png');
exportgraphics(fig1, sensorErrorFigure, 'Resolution', 160);

fig2 = figure('Name', 'V1.3 sensor-noise autocorrelation', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact');
nexttile;
stem(lags, rhoAy, 'filled');
grid on;
xlabel('Lag [100 Hz samples]');
ylabel('rho');
title('noise Ay normalized autocorrelation');
nexttile;
stem(lags, rhoR, 'filled');
grid on;
xlabel('Lag [100 Hz samples]');
ylabel('rho');
title('noise r normalized autocorrelation');
autocorrelationFigure = fullfile(resultsDir, ...
    'vy_dekf_v1_3_autocorrelation.png');
exportgraphics(fig2, autocorrelationFigure, 'Resolution', 160);

fig3 = figure('Name', 'V1.3 D-EKF innovations', 'Color', 'w', ...
    'Visible', figureVisibility);
tiledlayout(fig3, 2, 1, 'TileSpacing', 'compact');
nexttile;
plot(t, innovationAy, 'LineWidth', 0.9);
grid on;
ylabel('innovation Ay [m/s^2]');
title('Ay innovation at 100 Hz updates');
nexttile;
plot(t, innovationR, 'LineWidth', 0.9);
grid on;
xlabel('Time [s]');
ylabel('innovation r [rad/s]');
title('Yaw-rate innovation at 100 Hz updates');
innovationFigure = fullfile(resultsDir, ...
    'vy_dekf_v1_3_innovations.png');
exportgraphics(fig3, innovationFigure, 'Resolution', 160);

fig4 = figure('Name', 'V1.3 NIS consistency', 'Color', 'w', ...
    'Visible', figureVisibility);
plot(t, nis, 'LineWidth', 0.9);
hold on;
yline(chi2Upper95, '--r', 'chi2 95% upper');
yline(2, ':k', 'expected mean');
grid on;
xlabel('Time [s]');
ylabel('NIS');
title('D-EKF NIS at 100 Hz updates');
nisFigure = fullfile(resultsDir, 'vy_dekf_v1_3_nis.png');
exportgraphics(fig4, nisFigure, 'Resolution', 160);

emit(fid, '\nGenerated files\n');
emit(fid, '%s\n', reportFile);
emit(fid, '%s\n', sensorErrorFigure);
emit(fid, '%s\n', autocorrelationFigure);
emit(fid, '%s\n', innovationFigure);
emit(fid, '%s\n', nisFigure);

if strcmp(figureVisibility, 'off')
    close(fig1);
    close(fig2);
    close(fig3);
    close(fig4);
end
clear cleanupReport;

%% Local functions
function [container, sourceDescription] = locate_log_container(resultsDir)
if evalin('base', 'exist(''out'', ''var'')')
    container = evalin('base', 'out');
    sourceDescription = 'base workspace variable out';
elseif evalin('base', 'exist(''simOut'', ''var'')')
    container = evalin('base', 'simOut');
    sourceDescription = 'base workspace variable simOut';
else
    archiveFile = fullfile(resultsDir, 'vy_dekf_v1_3_simout.mat');
    if ~isfile(archiveFile)
        error('analyze_vy_dekf_v1_3:MissingLogs', ...
            'V1.3 SimulationOutput archive is missing: %s', archiveFile);
    end
    loaded = load(archiveFile);
    if isfield(loaded, 'simOut')
        container = loaded.simOut;
    else
        container = loaded;
    end
    sourceDescription = archiveFile;
end
end

function value = fetch_log(container, aliases)
for k = 1:numel(aliases)
    name = aliases{k};
    if evalin('base', sprintf('exist(''%s'', ''var'')', name))
        value = evalin('base', name);
        return;
    end
    if isa(container, 'Simulink.SimulationOutput') && ...
            any(strcmp(container.who, name))
        value = container.get(name);
        return;
    end
    if isstruct(container) && isfield(container, name)
        value = container.(name);
        return;
    end
end
error('analyze_vy_dekf_v1_3:MissingLog', ...
    'Required log not found. Accepted names: %s', strjoin(aliases, ', '));
end

function [time, data] = log_to_matrix(value, name)
if isa(value, 'timeseries')
    time = double(value.Time(:));
    raw = double(value.Data);
elseif isa(value, 'Simulink.SimulationData.Signal')
    [time, data] = log_to_matrix(value.Values, name);
    return;
elseif isstruct(value) && isfield(value, 'time') && isfield(value, 'signals')
    time = double(value.time(:));
    raw = double(value.signals.values);
else
    error('analyze_vy_dekf_v1_3:UnsupportedLog', ...
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
    error('analyze_vy_dekf_v1_3:LogSize', ...
        'Time/data size mismatch for %s.', name);
end
end

function require_columns(data, count, name)
if size(data, 2) < count
    error('analyze_vy_dekf_v1_3:LogWidth', ...
        '%s has %d columns; %d required.', name, size(data, 2), count);
end
end

function stats = summarize_error(errorValues)
values = finite_values(errorValues);
stats = summarize_basic(values);
stats.min = min(values);
stats.max = max(values);
stats.p95Absolute = percentile_linear(abs(values), 95);
end

function stats = summarize_basic(values)
values = finite_values(values);
stats.mean = mean(values);
stats.std = std(values, 0);
stats.variance = var(values, 0);
stats.rms = sqrt(mean(values.^2));
end

function rho = normalized_acf(values, maxLag)
values = finite_values(values(:));
values = values - mean(values);
denominator = sum(values.^2);
if denominator <= eps
    rho = [1; zeros(maxLag, 1)];
    return;
end
rho = zeros(maxLag + 1, 1);
for lag = 0:maxLag
    rho(lag + 1) = sum(values(1:end-lag) .* values(1+lag:end)) ...
        / denominator;
end
end

function print_error_stats(fid, stats, unitText)
emit(fid, 'mean     = %.15g %s\n', stats.mean, unitText);
emit(fid, 'std      = %.15g %s\n', stats.std, unitText);
emit(fid, 'variance = %.15g (%s)^2\n', stats.variance, unitText);
emit(fid, 'RMS      = %.15g %s\n', stats.rms, unitText);
emit(fid, 'min      = %.15g %s\n', stats.min, unitText);
emit(fid, 'max      = %.15g %s\n', stats.max, unitText);
emit(fid, 'p95(abs(error)) = %.15g %s\n', stats.p95Absolute, unitText);
end

function print_basic_stats(fid, stats, unitText)
emit(fid, 'mean     = %.15g %s\n', stats.mean, unitText);
emit(fid, 'std      = %.15g %s\n', stats.std, unitText);
emit(fid, 'variance = %.15g (%s)^2\n', stats.variance, unitText);
emit(fid, 'RMS      = %.15g %s\n', stats.rms, unitText);
end

function print_selected_acf(fid, rho)
emit(fid, 'rho(1)  = %.15g\n', rho(2));
emit(fid, 'rho(2)  = %.15g\n', rho(3));
emit(fid, 'rho(5)  = %.15g\n', rho(6));
emit(fid, 'rho(10) = %.15g\n', rho(11));
end

function values = finite_values(values)
values = values(isfinite(values));
if isempty(values)
    error('analyze_vy_dekf_v1_3:NoFiniteData', ...
        'A required signal contains no finite samples.');
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

function ratio = safe_ratio(numerator, denominator)
if denominator <= realmin
    ratio = Inf;
else
    ratio = numerator / denominator;
end
end

function emit(fid, formatText, varargin)
fprintf(formatText, varargin{:});
fprintf(fid, formatText, varargin{:});
end
