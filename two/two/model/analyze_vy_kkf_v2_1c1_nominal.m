function report = analyze_vy_kkf_v2_1c1_nominal(resultFile)
%ANALYZE_VY_KKF_V2_1C1_NOMINAL Analyze saved C1 raw runtime evidence.

root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(resultFile)
    resultFile = fullfile(root, 'results', 'vy_kkf_v2_1c1_nominal.mat');
end
csvFile = fullfile(root, 'results', 'vy_kkf_v2_1c1_nominal.csv');
plotDir = fullfile(root, 'results', 'plots', 'vy_kkf_v2_1c1_nominal');
assert(isfile(resultFile), 'V2.1-C1 result MAT does not exist.');
saved = load(resultFile, 'report');
assert(isfield(saved, 'report') && isstruct(saved.report), ...
    'V2.1-C1 result MAT does not contain a report struct.');
report = saved.report;
assert(report.simulationCompleted, 'V2.1-C1 runtime did not complete.');

names = {'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
counts = zeros(1,4);
for k = 1:4
    rec = report.raw.(names{k});
    counts(k) = rec.sampleCount;
    assert(rec.sampleCount > 0, 'Runtime log is empty: %s', names{k});
    assert(all(diff(rec.time) > 0), 'Runtime time is not monotonic: %s', names{k});
end
t = report.raw.kkf_x_log1.time;
aligned = true;
for k = 1:4
    tk = report.raw.(names{k}).time;
    aligned = aligned && numel(tk) == numel(t) && ...
        max(abs(tk(:) - t(:))) <= 10*eps(max(1,max(abs(t))));
end
assert(aligned, 'Four K-KF runtime logs are not timestamp-aligned.');

u = sample_matrix(report.raw.kkf_u_log1.data, counts(1));
x = sample_matrix(report.raw.kkf_x_log1.data, counts(2));
P = covariance_samples(report.raw.kkf_P_log1.data, counts(3));
diagnostic = sample_matrix(report.raw.kkf_diag_log1.data, counts(4));
assert(size(u,2) == 4 && size(x,2) == 2 && size(diagnostic,2) == 5, ...
    'K-KF runtime log dimensions are invalid.');

vxTrueRaw = scalar_record(report.raw.vx_true_offline);
vyTrueRaw = scalar_record(report.raw.vy_true_offline);
assert(all(diff(vxTrueRaw.time) > 0) && all(diff(vyTrueRaw.time) > 0), ...
    'Offline true-signal timestamps are not monotonic.');
assert(t(1) >= vxTrueRaw.time(1) && t(end) <= vxTrueRaw.time(end) && ...
    t(1) >= vyTrueRaw.time(1) && t(end) <= vyTrueRaw.time(end), ...
    'K-KF timestamps extend outside offline truth logging coverage.');
vxTrue = interp1(vxTrueRaw.time, vxTrueRaw.data, t, 'linear');
vyTrue = interp1(vyTrueRaw.time, vyTrueRaw.data, t, 'linear');

resetRec = report.raw.kkf_reset_trace_c1;
resetData = sample_matrix(resetRec.data, resetRec.sampleCount);
resetHigh = resetData(:,1) > 0.5;
dt = diff(t);
report.timing = struct('sampleCount', numel(t), 'tStart', t(1), ...
    'tEnd', t(end), 'dtMin', min(dt), 'dtMedian', median(dt), ...
    'dtMax', max(dt), 'uniqueDt', uniquetol(dt, 1e-12, 'DataScale', 1), ...
    'abnormalDtCount', sum(abs(dt - 0.01) > 1e-12), ...
    'logSampleCounts', counts, 'logsAligned', aligned, ...
    'strictlyIncreasing', all(dt > 0));
report.reset = struct('sampleCount', resetRec.sampleCount, ...
    'highCount', sum(resetHigh), 'highTimestamps', resetRec.time(resetHigh));

vxError = x(:,1) - vxTrue;
vyError = x(:,2) - vyTrue;
report.metrics = struct();
report.metrics.primaryScope = 'full duration including initial transient';
report.metrics.vx = error_metrics(vxError);
report.metrics.vy = error_metrics(vyError);

lowR = abs(u(:,3)) <= 0.01;
higherR = ~lowR;
assert(any(lowR) && any(higherR), ...
    'Both low-r and higher-r partitions are required for C1 characterization.');
report.observability = struct();
report.observability.signal = 'online K-KF input AVz_IMU';
report.observability.threshold = 0.01;
report.observability.lowDefinition = 'abs(AVz_IMU) <= 0.01 rad/s';
report.observability.higherDefinition = 'abs(AVz_IMU) > 0.01 rad/s';
report.observability.low = partition_metrics(vyError, lowR);
report.observability.higher = partition_metrics(vyError, higherR);

nis = diagnostic(:,1);
nisReference = 3.8414588;
report.nis = struct('reference95', nisReference, ...
    'mean', mean(nis), 'median', median(nis), ...
    'percentile95', prctile(nis,95), 'maximum', max(nis), ...
    'fractionAtOrBelow95', mean(nis <= nisReference), ...
    'fractionAbove95', mean(nis > nisReference));

asymmetry = zeros(counts(3),1);
minEigenvalue = inf;
p11 = squeeze(P(1,1,:));
p22 = squeeze(P(2,2,:));
for k = 1:counts(3)
    pk = P(:,:,k);
    symmetryError = pk - pk.';
    asymmetry(k) = max(abs(symmetryError(:)));
    minEigenvalue = min(minEigenvalue, min(eig(0.5*(pk + pk.'))));
end
report.sanity = struct( ...
    'allXFinite', all(isfinite(x(:))), ...
    'allPFinite', all(isfinite(P(:))), ...
    'allDiagnosticFinite', all(isfinite(diagnostic(:))), ...
    'allTruthFinite', all(isfinite(vxTrue)) && all(isfinite(vyTrue)), ...
    'maxPAsymmetry', max(asymmetry), ...
    'minimumPEigenvalue', minEigenvalue, ...
    'minimumP11', min(p11), 'minimumP22', min(p22), ...
    'maximumP11', max(p11), 'maximumP22', max(p22), ...
    'p11Positive', all(p11 > 0), 'p22Positive', all(p22 > 0));

report.samples = struct('time', t, 'u', u, 'x', x, 'P', P, ...
    'diagnostic', diagnostic, 'vxTrue', vxTrue, 'vyTrue', vyTrue, ...
    'vxError', vxError, 'vyError', vyError, 'lowRFlag', lowR, ...
    'resetTime', resetRec.time, 'resetData', resetData(:,1));
report.offlineTruth = struct( ...
    'vxRawTime', vxTrueRaw.time, 'vxRawData', vxTrueRaw.data, ...
    'vyRawTime', vyTrueRaw.time, 'vyRawData', vyTrueRaw.data, ...
    'alignmentMethod', 'linear interpolation onto actual K-KF timestamps', ...
    'trueVyUse', 'offline validation only');

T = table(t, u(:,1), u(:,2), u(:,3), u(:,4), x(:,1), x(:,2), ...
    vxTrue, vyTrue, vxError, vyError, squeeze(P(1,1,:)), ...
    squeeze(P(1,2,:)), squeeze(P(2,1,:)), squeeze(P(2,2,:)), ...
    diagnostic(:,1), diagnostic(:,2), diagnostic(:,3), ...
    diagnostic(:,4), diagnostic(:,5), lowR, ...
    'VariableNames', {'time','Ax_IMU','Ay_IMU','AVz_IMU','Vx_meas', ...
    'Vx_K','Vy_K','Vx_true','Vy_true','Vx_error','Vy_error', ...
    'P11','P12','P21','P22','NIS','obs_metric','innovation_vx', ...
    'K11','K21','low_r_flag'});
writetable(T, csvFile);
report.csv = struct('path', csvFile, 'rowCount', height(T), ...
    'columnNames', {T.Properties.VariableNames}, ...
    'trueVyColumnUse', 'offline validation only');

if ~isfolder(plotDir)
    mkdir(plotDir);
end
report.plots = make_plots(plotDir, t, u, x, vxTrue, vyTrue, ...
    vxError, vyError, p11, p22, nis, nisReference, lowR);

report.gates = struct( ...
    'runtimeCompleted', report.simulationCompleted, ...
    'fourLogsAligned', report.timing.logsAligned, ...
    'runtime100Hz', abs(report.timing.dtMedian - 0.01) <= 1e-12, ...
    'resetHighExactlyOnce', report.reset.highCount == 1, ...
    'finite', report.sanity.allXFinite && report.sanity.allPFinite && ...
        report.sanity.allDiagnosticFinite && report.sanity.allTruthFinite, ...
    'covarianceSymmetric', report.sanity.maxPAsymmetry <= 1e-10, ...
    'covariancePositiveDiagonal', report.sanity.p11Positive && ...
        report.sanity.p22Positive, ...
    'covarianceNoMaterialNegativeEigenvalue', ...
        report.sanity.minimumPEigenvalue >= -1e-12, ...
    'partitionsPresent', any(lowR) && any(higherR), ...
    'csvComplete', height(T) == numel(t) && width(T) == 21, ...
    'eightPlotsCreated', numel(report.plots) == 8 && ...
        all(cellfun(@isfile, report.plots)), ...
    'frozenHashesUnchanged', report.frozenHashesUnchanged, ...
    'targetMetadataUnchanged', report.targetMetadataUnchanged, ...
    'simFileUnchanged', report.carSim.simFileUnchanged, ...
    'trueVyOfflineOnly', ~report.trueVyOnlineUsed, ...
    'noDekfDependency', ~report.dekfDependency, ...
    'noQrTuning', ~report.qrTuningPerformed);
gateValues = struct2cell(report.gates);
report.gates.allPassed = all(cellfun(@(v) logical(v), gateValues));
save(resultFile, 'report', '-v7.3');

fprintf(['V2_1C1_ANALYSIS_OK|N=%d|dtMedian=%.17g|reset=%d|' ...
    'VxRMSE=%.17g|VyRMSE=%.17g|lowN=%d|higherN=%d|' ...
    'NISmean=%.17g|PminEig=%.17g|plots=%d|gates=%d\n'], ...
    report.timing.sampleCount, report.timing.dtMedian, ...
    report.reset.highCount, report.metrics.vx.RMSE, report.metrics.vy.RMSE, ...
    report.observability.low.sampleCount, ...
    report.observability.higher.sampleCount, report.nis.mean, ...
    report.sanity.minimumPEigenvalue, numel(report.plots), ...
    report.gates.allPassed);
end

function metrics = error_metrics(error)
metrics = struct('RMSE', sqrt(mean(error.^2)), ...
    'MAE', mean(abs(error)), 'Bias', mean(error), ...
    'MaxAbsError', max(abs(error)));
end

function metrics = partition_metrics(error, mask)
metrics = error_metrics(error(mask));
metrics.sampleCount = sum(mask);
metrics.sampleFraction = mean(mask);
end

function scalar = scalar_record(rec)
matrix = sample_matrix(rec.data, rec.sampleCount);
assert(size(matrix,2) == 1, 'Offline true signal must be scalar.');
scalar = struct('time', rec.time, 'data', matrix(:,1));
end

function matrix = sample_matrix(data, sampleCount)
sz = size(data);
sampleDim = find(sz == sampleCount, 1, 'last');
assert(~isempty(sampleDim), 'Cannot identify the sample dimension.');
order = [sampleDim, setdiff(1:ndims(data), sampleDim, 'stable')];
matrix = reshape(permute(data, order), sampleCount, []);
end

function P = covariance_samples(data, sampleCount)
sz = size(data);
sampleDim = find(sz == sampleCount, 1, 'last');
assert(~isempty(sampleDim), 'Cannot identify covariance sample dimension.');
other = setdiff(1:ndims(data), sampleDim, 'stable');
assert(prod(sz(other)) == 4, 'Covariance log is not 2x2 per sample.');
P = reshape(permute(data, [other sampleDim]), 2, 2, sampleCount);
end

function paths = make_plots(plotDir, t, u, x, vxTrue, vyTrue, ...
    vxError, vyError, p11, p22, nis, nisReference, lowR)
paths = cell(8,1);

paths{1} = fullfile(plotDir, '01_kkf_inputs.png');
f = new_figure(); tl = tiledlayout(f,4,1,'TileSpacing','compact');
labels = {'Ax IMU (m/s^2)','Ay IMU (m/s^2)','AVz IMU (rad/s)','Vx meas (m/s)'};
for k = 1:4, nexttile(tl); plot(t,u(:,k),'LineWidth',1); grid on; ylabel(labels{k}); end
xlabel(tl,'Time (s)'); title(tl,'K-KF runtime inputs'); save_figure(f,paths{1});

paths{2} = fullfile(plotDir, '02_vx_estimate_vs_true.png');
f = new_figure(); plot(t,x(:,1),'LineWidth',1.2); hold on; plot(t,vxTrue,'--','LineWidth',1.1);
grid on; xlabel('Time (s)'); ylabel('Vx (m/s)'); title('K-KF Vx and true Vx');
legend('Vx K-KF','true Vx','Location','best'); save_figure(f,paths{2});

paths{3} = fullfile(plotDir, '03_vx_error.png');
f = new_figure(); plot(t,vxError,'LineWidth',1.1); grid on; xlabel('Time (s)');
ylabel('Vx error (m/s)'); title('Vx K-KF - true Vx'); yline(0,'k:'); save_figure(f,paths{3});

paths{4} = fullfile(plotDir, '04_vy_estimate_vs_true_offline.png');
f = new_figure(); plot(t,x(:,2),'LineWidth',1.2); hold on; plot(t,vyTrue,'--','LineWidth',1.1);
grid on; xlabel('Time (s)'); ylabel('Vy (m/s)');
title('K-KF Vy and true Vy (true Vy: offline validation only)');
legend('Vy K-KF','true Vy offline','Location','best'); save_figure(f,paths{4});

paths{5} = fullfile(plotDir, '05_vy_error.png');
f = new_figure(); plot(t,vyError,'LineWidth',1.1); grid on; xlabel('Time (s)');
ylabel('Vy error (m/s)'); title('Vy K-KF - true Vy (offline error)');
yline(0,'k:'); save_figure(f,paths{5});

paths{6} = fullfile(plotDir, '06_covariance_diagonal.png');
f = new_figure(); semilogy(t,p11,'LineWidth',1.1); hold on; semilogy(t,p22,'LineWidth',1.1);
grid on; xlabel('Time (s)'); ylabel('Posterior covariance'); title('K-KF covariance diagonal');
legend('P11','P22','Location','best'); save_figure(f,paths{6});

paths{7} = fullfile(plotDir, '07_nis.png');
f = new_figure(); plot(t,nis,'LineWidth',1); hold on; yline(nisReference,'r--','LineWidth',1.2);
grid on; xlabel('Time (s)'); ylabel('NIS'); title('Vx measurement NIS diagnostic');
legend('NIS','chi-square(1) 95% = 3.8414588','Location','best'); save_figure(f,paths{7});

paths{8} = fullfile(plotDir, '08_observability_partition.png');
f = new_figure(); tl = tiledlayout(f,2,1,'TileSpacing','compact');
nexttile(tl); plot(t,abs(u(:,3)),'LineWidth',1); hold on; yline(0.01,'r--','LineWidth',1.2);
grid on; ylabel('|AVz IMU| (rad/s)'); legend('|AVz IMU|','threshold 0.01','Location','best');
nexttile(tl); plot(t,vyError,'Color',[0.55 0.55 0.55],'LineWidth',0.8); hold on;
scatter(t(lowR),vyError(lowR),8,[0 0.45 0.74],'filled');
scatter(t(~lowR),vyError(~lowR),8,[0.85 0.33 0.10],'filled');
grid on; xlabel('Time (s)'); ylabel('Vy error (m/s)');
legend('all','low-r','higher-r','Location','best');
title(tl,'Offline observability partition using online AVz IMU'); save_figure(f,paths{8});
end

function f = new_figure()
f = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
end

function save_figure(f, path)
exportgraphics(f, path, 'Resolution', 150);
close(f);
end
