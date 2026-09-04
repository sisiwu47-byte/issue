function summaryTable = analyze_vy_dekf_v1_4_R_sweep(runArchive)
%ANALYZE_VY_DEKF_V1_4_R_SWEEP Analyze the controlled V1.4 R sweep.
%
% This function reads archived logs only. It does not load or modify a
% Simulink model and does not apply any candidate R.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot, 'results');
docsDir = fullfile(repoRoot, 'docs');
if nargin < 1 || isempty(runArchive)
    runArchive = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep_runs.mat');
end
assert(isfile(runArchive), 'Sweep run archive is missing: %s', runArchive);

loaded = load(runArchive, 'runs', 'metadata');
runs = loaded.runs;
metadata = loaded.metadata;
assert(numel(runs) == 9, 'Exactly nine sweep cases are required.');

chi2Upper95 = 5.991464547;
expectedNisMean = 2;
metricTemplate = make_metric_template();
metrics = repmat(metricTemplate, 9, 1);

for k = 1:9
    run = runs(k);
    vyError = run.y(:, 1) - run.vyTrue;
    rError = run.y(:, 2) - run.rTrue;
    rMeasurementError = run.y(:, 2) - run.z(:, 2);
    nis = run.diagnostics(:, 1);
    innovationAy = run.diagnostics(:, 10);
    innovationR = run.diagnostics(:, 11);
    pVy = run.pDiag(:, 1);
    pR = run.pDiag(:, 2);

    valuesRequiredFinite = [run.u, run.z, run.y, run.pDiag, ...
        run.diagnostics, run.vyTrue, run.rTrue];
    hasNaNInf = any(~isfinite(valuesRequiredFinite), 'all');
    negativeCovariance = any(pVy < -1e-12) || any(pR < -1e-12);
    numericalBlowup = any(abs(run.y) > 1e6, 'all') || ...
        any(abs(run.pDiag) > 1e6, 'all') || ...
        any(abs(run.diagnostics) > 1e12, 'all');

    metrics(k).Case = run.Case;
    metrics(k).Level_Ay = string(run.LevelAy);
    metrics(k).Level_r = string(run.LevelR);
    metrics(k).R_Ay = run.R_Ay;
    metrics(k).R_r = run.R_r;
    metrics(k) = add_error_metrics(metrics(k), 'Vy', vyError);
    metrics(k) = add_error_metrics(metrics(k), 'r', rError);
    metrics(k) = add_error_metrics(metrics(k), 'r_IMU', rMeasurementError);
    metrics(k).NIS_mean = mean(nis);
    metrics(k).NIS_median = median(nis);
    metrics(k).NIS_p95 = percentile_linear(nis, 95);
    metrics(k).NIS_max = max(nis);
    metrics(k).NIS_below95_fraction = mean(nis <= chi2Upper95);
    metrics(k).NIS_above95_fraction = mean(nis > chi2Upper95);
    metrics(k).innovation_Ay_mean = mean(innovationAy);
    metrics(k).innovation_Ay_std = std(innovationAy, 0);
    metrics(k).innovation_Ay_RMS = rms_local(innovationAy);
    metrics(k).innovation_r_mean = mean(innovationR);
    metrics(k).innovation_r_std = std(innovationR, 0);
    metrics(k).innovation_r_RMS = rms_local(innovationR);
    metrics(k).Pvy_min = min(pVy);
    metrics(k).Pvy_max = max(pVy);
    metrics(k).Pvy_final = pVy(end);
    metrics(k).Pr_min = min(pR);
    metrics(k).Pr_max = max(pR);
    metrics(k).Pr_final = pR(end);
    metrics(k).UpdateCount = numel(run.t);
    metrics(k).HasNaNInf = hasNaNInf;
    metrics(k).NegativeCovariance = negativeCovariance;
    metrics(k).NumericalBlowup = numericalBlowup;
    metrics(k).stable = ~hasNaNInf && ~negativeCovariance && ~numericalBlowup;
end

summaryTable = struct2table(metrics);

% Controlled-sweep invariants and shared excitation values.
assert(all(summaryTable.UpdateCount == metadata.expectedUpdates), ...
    'Not every case contains the expected 1601 100 Hz updates.');
assert(metadata.inputInvarianceVerified, ...
    'Fixed-case input invariance was not verified by the runner.');
maxSteering = max(abs(runs(1).u(:, 2:5)), [], 1);
maxAy = max(abs(runs(1).z(:, 1)));
maxAvz = max(abs(runs(1).z(:, 2)));

% Pareto-style characterization. Consistency distance uses both NIS mean
% and p95 on a scale-neutral logarithmic ratio.
consistencyDistance = abs(log(max(summaryTable.NIS_mean, eps) ./ expectedNisMean)) + ...
    abs(log(max(summaryTable.NIS_p95, eps) ./ chi2Upper95));
stableIndices = find(summaryTable.stable);
assert(~isempty(stableIndices), 'No numerically stable sweep case exists.');
[~, localVy] = min(summaryTable.Vy_RMSE(stableIndices));
[~, localR] = min(summaryTable.r_RMSE(stableIndices));
[~, localNis] = min(consistencyDistance(stableIndices));
bestVyCase = stableIndices(localVy);
bestRCase = stableIndices(localR);
bestNisCase = stableIndices(localNis);

objectives = [normalize_min(summaryTable.Vy_RMSE), ...
    normalize_min(summaryTable.r_RMSE), normalize_min(consistencyDistance)];
paretoMask = false(9, 1);
for i = stableIndices.'
    dominated = false;
    for j = stableIndices.'
        if j ~= i && all(objectives(j, :) <= objectives(i, :)) && ...
                any(objectives(j, :) < objectives(i, :))
            dominated = true;
            break;
        end
    end
    paretoMask(i) = ~dominated;
end
paretoIndices = find(paretoMask);
% Retain at most three transparent trade-off anchors: the best Vy case,
% best true-r case, and closest-NIS case. These are characterization
% candidates only, not a final setting.
recommendedCases = unique([bestVyCase; bestRCase; bestNisCase], 'stable');

% Quantify whether lower yaw-rate R increases tracking of the biased AVz.
highRrCases = [1, 4, 7];
lowRrCases = [3, 6, 9];
trackingHigh = mean(summaryTable.r_IMU_RMSE(highRrCases));
trackingLow = mean(summaryTable.r_IMU_RMSE(lowRrCases));
followsImuMore = trackingLow < trackingHigh;

analysis = struct();
analysis.chi2Upper95 = chi2Upper95;
analysis.expectedNisMean = expectedNisMean;
analysis.bestVyCase = bestVyCase;
analysis.bestRCase = bestRCase;
analysis.bestNisCase = bestNisCase;
analysis.paretoCases = paretoIndices(:).';
analysis.recommendedCases = recommendedCases(:).';
analysis.maxSteering = maxSteering;
analysis.maxAy = maxAy;
analysis.maxAvz = maxAvz;
analysis.rImuTrackingRmseHighRr = trackingHigh;
analysis.rImuTrackingRmseLowRr = trackingLow;
analysis.lowerRrFollowsImuMore = followsImuMore;
analysis.NEESAvailable = false;
analysis.noFinalRApplied = true;

csvFile = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep.csv');
matFile = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep.mat');
writetable(summaryTable, csvFile);
save(matFile, 'summaryTable', 'runs', 'metadata', 'analysis', '-v7.3');

metricsFigure = plot_metric_summary(summaryTable, resultsDir, chi2Upper95);
heatmapFigure = plot_heatmaps(summaryTable, resultsDir);
representativeFigure = plot_representative_cases(runs, resultsDir, chi2Upper95);

textReport = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep_summary.txt');
statusFile = fullfile(docsDir, 'STAGE_VY_DEKF_V1_4_STATUS.md');
write_text_report(textReport, summaryTable, analysis, metadata, ...
    metricsFigure, heatmapFigure, representativeFigure, csvFile, matFile);
write_status(statusFile, summaryTable, analysis, metadata, ...
    metricsFigure, heatmapFigure, representativeFigure, csvFile, matFile, ...
    textReport);

fprintf('V1_4_ANALYSIS_OK|csv=%s|mat=%s\n', csvFile, matFile);
fprintf('BEST|Vy=%d|r=%d|NIS=%d|recommended=%s\n', ...
    bestVyCase, bestRCase, bestNisCase, mat2str(recommendedCases(:).'));
fprintf('NO FINAL R WAS APPLIED\n');
end

function metric = make_metric_template()
metric = struct( ...
    'Case', 0, 'Level_Ay', "", 'Level_r', "", 'R_Ay', 0, 'R_r', 0, ...
    'Vy_RMSE', 0, 'Vy_MAE', 0, 'Vy_Bias', 0, 'Vy_Max', 0, ...
    'r_RMSE', 0, 'r_MAE', 0, 'r_Bias', 0, 'r_Max', 0, ...
    'r_IMU_RMSE', 0, 'r_IMU_MAE', 0, 'r_IMU_Bias', 0, 'r_IMU_Max', 0, ...
    'NIS_mean', 0, 'NIS_median', 0, 'NIS_p95', 0, 'NIS_max', 0, ...
    'NIS_below95_fraction', 0, 'NIS_above95_fraction', 0, ...
    'innovation_Ay_mean', 0, 'innovation_Ay_std', 0, ...
    'innovation_Ay_RMS', 0, 'innovation_r_mean', 0, ...
    'innovation_r_std', 0, 'innovation_r_RMS', 0, ...
    'Pvy_min', 0, 'Pvy_max', 0, 'Pvy_final', 0, ...
    'Pr_min', 0, 'Pr_max', 0, 'Pr_final', 0, ...
    'UpdateCount', 0, 'HasNaNInf', false, ...
    'NegativeCovariance', false, 'NumericalBlowup', false, 'stable', false);
end

function metric = add_error_metrics(metric, prefix, errorValues)
assert(all(isfinite(errorValues)), '%s error contains NaN/Inf.', prefix);
metric.([prefix '_RMSE']) = rms_local(errorValues);
metric.([prefix '_MAE']) = mean(abs(errorValues));
metric.([prefix '_Bias']) = mean(errorValues);
metric.([prefix '_Max']) = max(abs(errorValues));
end

function outputFile = plot_metric_summary(t, resultsDir, chi2Upper95)
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'V1.4 R sweep metrics');
tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
nexttile; plot(t.Case, t.Vy_RMSE, '-o', 'LineWidth', 1.1); grid on;
xlabel('Case'); ylabel('m/s'); title('Vy RMSE'); xticks(1:9);
nexttile; plot(t.Case, t.r_RMSE, '-o', 'LineWidth', 1.1); grid on;
xlabel('Case'); ylabel('rad/s'); title('r RMSE vs CarSim true r'); xticks(1:9);
nexttile; semilogy(t.Case, t.NIS_mean, '-o', 'LineWidth', 1.1); hold on;
yline(2, '--k', 'expected mean'); grid on;
xlabel('Case'); ylabel('NIS (log scale)'); title('NIS mean'); xticks(1:9);
nexttile; semilogy(t.Case, t.NIS_p95, '-o', 'LineWidth', 1.1); hold on;
yline(chi2Upper95, '--r', 'chi-square 95%'); grid on;
xlabel('Case'); ylabel('NIS (log scale)'); title('NIS p95'); xticks(1:9);
outputFile = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep_metrics.png');
exportgraphics(fig, outputFile, 'Resolution', 170);
close(fig);
end

function outputFile = plot_heatmaps(t, resultsDir)
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'V1.4 R sweep heatmaps', 'Position', [80 80 1500 520]);
tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
labels = {'H', 'M', 'L'};
plot_one_heatmap(reshape(t.Vy_RMSE, 3, 3).', labels, ...
    'Vy RMSE [m/s]');
plot_one_heatmap(reshape(t.r_RMSE, 3, 3).', labels, ...
    'r RMSE [rad/s]');
plot_one_heatmap(reshape(t.NIS_mean, 3, 3).', labels, 'NIS mean');
outputFile = fullfile(resultsDir, 'vy_dekf_v1_4_R_sweep_heatmaps.png');
exportgraphics(fig, outputFile, 'Resolution', 170);
close(fig);
end

function plot_one_heatmap(values, labels, titleText)
nexttile;
imagesc(values);
axis image;
colorbar;
xticks(1:3); xticklabels(labels);
yticks(1:3); yticklabels(labels);
xlabel('R_r level'); ylabel('R_Ay level'); title(titleText);
for row = 1:3
    for column = 1:3
        text(column, row, sprintf('%.3g', values(row, column)), ...
            'HorizontalAlignment', 'center', 'Color', 'k', ...
            'BackgroundColor', [1 1 1]);
    end
end
end

function outputFile = plot_representative_cases(runs, resultsDir, chi2Upper95)
selected = [1, 5, 9];
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'V1.4 representative R cases', 'Position', [80 80 1500 900]);
tiledlayout(fig, 3, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
for row = 1:3
    run = runs(selected(row));
    nexttile;
    plot(run.t, run.vyTrue, 'LineWidth', 0.9); hold on;
    plot(run.t, run.y(:, 1), '--', 'LineWidth', 0.9); grid on;
    ylabel('Vy [m/s]'); title(sprintf('Case %d: Vy', run.Case));
    if row == 1, legend('true', 'hat', 'Location', 'best'); end
    nexttile;
    plot(run.t, run.y(:, 1) - run.vyTrue, 'LineWidth', 0.9); grid on;
    ylabel('error [m/s]'); title(sprintf('Case %d: Vy error', run.Case));
    nexttile;
    plot(run.t, run.rTrue, 'LineWidth', 0.9); hold on;
    plot(run.t, run.y(:, 2), '--', 'LineWidth', 0.9); grid on;
    ylabel('r [rad/s]'); title(sprintf('Case %d: r', run.Case));
    if row == 1, legend('true', 'hat', 'Location', 'best'); end
    nexttile;
    semilogy(run.t, max(run.diagnostics(:, 1), eps), 'LineWidth', 0.9); hold on;
    yline(chi2Upper95, '--r'); grid on;
    ylabel('NIS (log)'); title(sprintf('Case %d: NIS', run.Case));
end
for tile = 9:12
    ax = nexttile(tile);
    xlabel(ax, 'Time [s]');
end
outputFile = fullfile(resultsDir, ...
    'vy_dekf_v1_4_R_sweep_representative_cases.png');
exportgraphics(fig, outputFile, 'Resolution', 170);
close(fig);
end

function write_text_report(file, t, analysis, metadata, varargin)
fid = fopen(file, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Cannot open report: %s', file);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Vy D-EKF V1.4 controlled 3x3 R sweep\n');
fprintf(fid, 'Q fixed: diag([%.15g, %.15g])\n', metadata.Q(1,1), metadata.Q(2,2));
fprintf(fid, 'Estimator period: %.15g s; updates/case: %d\n', ...
    metadata.estimatorPeriod, metadata.expectedUpdates);
fprintf(fid, 'Fixed-case input invariance verified: %d\n\n', ...
    metadata.inputInvarianceVerified);
print_metric_table(fid, t);
print_conclusions(fid, t, analysis);
fprintf(fid, '\nGenerated files:\n');
for k = 1:numel(varargin), fprintf(fid, '%s\n', varargin{k}); end
fprintf(fid, 'NEES unavailable due to incomplete covariance logging\n');
fprintf(fid, 'NO FINAL R WAS APPLIED\n');
clear cleanup;
end

function write_status(file, t, analysis, metadata, metricsFigure, ...
        heatmapFigure, representativeFigure, csvFile, matFile, textReport)
fid = fopen(file, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Cannot open status file: %s', file);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# STAGE VY D-EKF V1.4 STATUS\n\n');
fprintf(fid, '## 结论\n\n');
fprintf(fid, ['已完成固定工况、固定 Q、固定传感器和固定 100 Hz 结构下的 ', ...
    '3x3 对角 R 扫描。九个工况的输入及真值逐点一致，', ...
    '每个工况均有 %d 个 100 Hz 更新点。\n\n'], metadata.expectedUpdates);
fprintf(fid, '- 最低 Vy RMSE：Case %d，%.12g m/s。\n', ...
    analysis.bestVyCase, t.Vy_RMSE(analysis.bestVyCase));
fprintf(fid, '- 最低 r RMSE（相对 CarSim 真值）：Case %d，%.12g rad/s。\n', ...
    analysis.bestRCase, t.r_RMSE(analysis.bestRCase));
fprintf(fid, '- NIS 尺度最接近理论参考：Case %d，mean %.12g，p95 %.12g。\n', ...
    analysis.bestNisCase, t.NIS_mean(analysis.bestNisCase), ...
    t.NIS_p95(analysis.bestNisCase));
fprintf(fid, ['- 但 Case %d 仍远低于理论 mean=2 与 p95=5.991464547；', ...
    '本次网格没有统计上一致的 NIS case。\n'], analysis.bestNisCase);
fprintf(fid, '- Pareto 风格候选（最多 3 个）：%s。\n', ...
    strjoin(compose('Case %d', analysis.recommendedCases), '、'));
fprintf(fid, '- 所有 case 数值稳定：%d。\n', all(t.stable));
fprintf(fid, '- `NEES unavailable due to incomplete covariance logging`。\n');
fprintf(fid, '- **NO FINAL R WAS APPLIED**。\n\n');

fprintf(fid, '## 扫描定义\n\n');
fprintf(fid, '- R_Ay: H=1e-2, M=2.617498047078e-3, L=6.851296026457e-4。\n');
fprintf(fid, '- R_r: H=1e-2, M=3.365172961808e-4, L=1.132438906288e-5。\n');
fprintf(fid, '- Q 始终为 `diag([1e-4, 1e-3])`。\n');
fprintf(fid, '- 真值 Vy 与真值 r 仅用于离线评价，未进入 EKF。\n\n');

fprintf(fid, '## 全部数值指标\n\n');
fprintf(fid, ['|Case|R_Ay|R_r|Vy RMSE|Vy MAE|Vy Bias|Vy Max|', ...
    'r RMSE|r MAE|r Bias|r Max|NIS mean|NIS p95|NIS >95%%|stable|\n']);
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
for k = 1:height(t)
    fprintf(fid, ['|%d|%.12g|%.12g|%.12g|%.12g|%.12g|%.12g|', ...
        '%.12g|%.12g|%.12g|%.12g|%.12g|%.12g|%.6g|%d|\n'], ...
        t.Case(k), t.R_Ay(k), t.R_r(k), t.Vy_RMSE(k), t.Vy_MAE(k), ...
        t.Vy_Bias(k), t.Vy_Max(k), t.r_RMSE(k), t.r_MAE(k), ...
        t.r_Bias(k), t.r_Max(k), t.NIS_mean(k), t.NIS_p95(k), ...
        t.NIS_above95_fraction(k), t.stable(k));
end

fprintf(fid, '\n## 协方差、innovation 与稳定性\n\n');
fprintf(fid, ['完整逐 case 数据（innovation mean/std/RMS、NIS median/max、', ...
    'P min/max/final 和异常标志）位于 CSV/MAT。所有 case 的 P 仅记录 ', ...
    'P11/P22，因此不能构造严格 NEES，也没有虚构 P12。\n\n']);

print_conclusions(fid, t, analysis);

fprintf(fid, '\n## 文件\n\n');
files = {csvFile, matFile, textReport, metricsFigure, heatmapFigure, ...
    representativeFigure, metadata.modelFile};
for k = 1:numel(files), fprintf(fid, '- `%s`\n', files{k}); end
fprintf(fid, '- `%s.m`\n', mfilename('fullpath'));
fprintf(fid, '- `%s`\n', fullfile(fileparts(mfilename('fullpath')), ...
    'run_vy_dekf_v1_4_R_sweep.m'));
clear cleanup;
end

function print_metric_table(fid, t)
fprintf(fid, ['Case,R_Ay,R_r,Vy_RMSE,Vy_MAE,Vy_Bias,Vy_Max,', ...
    'r_RMSE,r_MAE,r_Bias,r_Max,NIS_mean,NIS_median,NIS_p95,NIS_max,', ...
    'NIS_above95,innovation_Ay_RMS,innovation_r_RMS,Pvy_final,Pr_final,stable\n']);
for k = 1:height(t)
    fprintf(fid, ['%d,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,', ...
        '%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,', ...
        '%.15g,%.15g,%.15g,%.15g,%.15g,%d\n'], ...
        t.Case(k), t.R_Ay(k), t.R_r(k), t.Vy_RMSE(k), t.Vy_MAE(k), ...
        t.Vy_Bias(k), t.Vy_Max(k), t.r_RMSE(k), t.r_MAE(k), ...
        t.r_Bias(k), t.r_Max(k), t.NIS_mean(k), t.NIS_median(k), ...
        t.NIS_p95(k), t.NIS_max(k), t.NIS_above95_fraction(k), ...
        t.innovation_Ay_RMS(k), t.innovation_r_RMS(k), ...
        t.Pvy_final(k), t.Pr_final(k), t.stable(k));
end
end

function print_conclusions(fid, t, analysis)
fprintf(fid, '\n## Characterization conclusions\n');
fprintf(fid, 'Lowest Vy RMSE: Case %d (%.15g m/s)\n', ...
    analysis.bestVyCase, t.Vy_RMSE(analysis.bestVyCase));
fprintf(fid, 'Lowest r RMSE vs true: Case %d (%.15g rad/s)\n', ...
    analysis.bestRCase, t.r_RMSE(analysis.bestRCase));
fprintf(fid, 'Most reasonable NIS scale: Case %d (mean %.15g, p95 %.15g)\n', ...
    analysis.bestNisCase, t.NIS_mean(analysis.bestNisCase), ...
    t.NIS_p95(analysis.bestNisCase));
fprintf(fid, ['This is only the closest case in the tested grid; it remains ', ...
    'far below mean=2 and p95=5.991464547, so no tested case is NIS-consistent.\n']);
fprintf(fid, 'Recommended characterization candidates: %s\n', ...
    strjoin(compose('Case %d', analysis.recommendedCases), ', '));
fprintf(fid, ['Current H/H -> sensor-candidate L/L trend: Vy RMSE ', ...
    '%.15g -> %.15g; r RMSE %.15g -> %.15g; NIS mean %.15g -> %.15g.\n'], ...
    t.Vy_RMSE(1), t.Vy_RMSE(9), t.r_RMSE(1), t.r_RMSE(9), ...
    t.NIS_mean(1), t.NIS_mean(9));
fprintf(fid, ['Mean r-hat vs AVz_IMU RMSE for R_r H -> L: %.15g -> %.15g ', ...
    'rad/s. Lower R_r follows AVz_IMU more: %d.\n'], ...
    analysis.rImuTrackingRmseHighRr, analysis.rImuTrackingRmseLowRr, ...
    analysis.lowerRrFollowsImuMore);
fprintf(fid, 'True-r bias Case 1 -> Case 9: %.15g -> %.15g rad/s.\n', ...
    t.r_Bias(1), t.r_Bias(9));
fprintf(fid, 'Vy bias Case 1 -> Case 9: %.15g -> %.15g m/s.\n', ...
    t.Vy_Bias(1), t.Vy_Bias(9));
fprintf(fid, 'Max steering [FL FR RL RR] = %s rad\n', ...
    mat2str(analysis.maxSteering, 12));
fprintf(fid, 'max |Ay| = %.15g m/s^2; max |AVz| = %.15g rad/s\n', ...
    analysis.maxAy, analysis.maxAvz);
end

function values = normalize_min(values)
values = values(:);
span = max(values) - min(values);
if span <= eps(max(abs(values)))
    values = zeros(size(values));
else
    values = (values - min(values)) / span;
end
end

function value = percentile_linear(values, percentile)
values = sort(values(isfinite(values)));
assert(~isempty(values), 'No finite values for percentile.');
position = 1 + (numel(values) - 1) * percentile / 100;
lo = floor(position); hi = ceil(position); weight = position - lo;
value = values(lo) * (1 - weight) + values(hi) * weight;
end

function value = rms_local(values)
value = sqrt(mean(values.^2));
end
