function report = analyze_vy_kkf_v2_1d_bias_attribution()
%ANALYZE_VY_KKF_V2_1D_BIAS_ATTRIBUTION Offline deterministic-bias replay.

root = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(root, 'results', 'vy_kkf_v2_1c1_nominal.mat');
resultFile = fullfile(root, 'results', 'vy_kkf_v2_1d_bias_attribution.mat');
csvFile = fullfile(root, 'results', 'vy_kkf_v2_1d_bias_attribution.csv');
plotDir = fullfile(root, 'results', 'plots', ...
    'vy_kkf_v2_1d_bias_attribution');

frozen = { ...
    fullfile(root, 'model', 'vx.slx'), ...
    fullfile(root, 'model', 'vx_ax_imu_prereq_v2_1.slx'), ...
    fullfile(root, 'model', 'vx_vy_kkf_v2_1.slx'), ...
    fullfile(root, 'model', 'vx_vy_dekf_v1_17.slx'), ...
    fullfile(root, 'matlab', 'vy_kinematic_kf_step.m'), ...
    fullfile(root, 'matlab', 'vy_kinematic_kf.m')};
expected = { ...
    '754a94d85bd50f89ae453c544903dea90b7f9d57d6e7706869f9f674fb0464eb', ...
    '226238301763460f4b609b0249d61b720c6510dd561923c5d066c33e5967f439', ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712', ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae', ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244', ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'};

assert(isfile(sourceFile), 'C1 source MAT is missing.');
saved = load(sourceFile, 'report');
assert(isfield(saved, 'report') && isfield(saved.report, 'samples'), ...
    'C1 source MAT does not contain analyzed samples.');
c1 = saved.report;
s = c1.samples;
t = double(s.time(:));
u = double(s.u);
xOnline = double(s.x);
POnline = double(s.P);
diagOnline = double(s.diagnostic);
vyTrue = double(s.vyTrue(:));
assert(size(u,2) == 4 && size(xOnline,2) == 2 && ...
    size(diagOnline,2) == 5 && size(POnline,3) == numel(t), ...
    'C1 analyzed sample dimensions are invalid.');
assert(all(diff(t) > 0), 'C1 timestamps are not strictly increasing.');

report = struct();
report.stage = 'V2.1-D IMU Bias Attribution Offline Replay';
report.source = struct('file', sourceFile, 'sampleCount', numel(t), ...
    'tStart', t(1), 'tEnd', t(end), ...
    'measurement', 'C1 Vx_meas (temporary true-Vx isolation measurement)', ...
    'trueVyUse', 'offline metrics only');
report.scope = struct('offlineReplayOnly', true, 'simCalled', false, ...
    'carSimRun', false, 'trueVyFedToFilter', false, ...
    'onlineBiasCorrectionImplemented', false, ...
    'qrP0TuningPerformed', false, 'dekfOutputUsed', false, ...
    'fusionPerformed', false, 'v2_2Started', false);
report.configuredBias = struct('Ax_mps2', 0.02, ...
    'Ay_mps2', 0.02, 'AVz_radps', 0.005);
report.frozenBefore = hash_files(frozen);
for k = 1:numel(frozen)
    assert(strcmp(report.frozenBefore(k).sha256, expected{k}), ...
        'Frozen baseline mismatch before replay: %s', frozen{k});
end

% B0 must exactly replay the frozen online implementation before any
% counterfactual bias case is evaluated.
[xB0, PB0, diagB0] = replay_case(u(:,1:3), u(:,4));
report.equivalence = struct( ...
    'threshold', 1e-12, ...
    'maxAbsXDiff', max(abs(xB0(:) - xOnline(:))), ...
    'maxAbsPDiff', max(abs(PB0(:) - POnline(:))), ...
    'maxAbsDiagDiff', max(abs(diagB0(:) - diagOnline(:))));
report.equivalence.passed = ...
    report.equivalence.maxAbsXDiff <= report.equivalence.threshold && ...
    report.equivalence.maxAbsPDiff <= report.equivalence.threshold && ...
    report.equivalence.maxAbsDiagDiff <= report.equivalence.threshold;

if ~report.equivalence.passed
    report.stopState = 'V2.1-D BLOCKED: BASELINE REPLAY NOT EQUIVALENT';
    report.frozenAfter = hash_files(frozen);
    report.frozenHashesUnchanged = compare_hashes( ...
        report.frozenBefore, report.frozenAfter, expected);
    save(resultFile, 'report', '-v7.3');
    error('VY_KKF:V2_1DReplayNotEquivalent', '%s', report.stopState);
end

caseIds = {'B0'; 'B1'; 'B2'; 'B3'; 'B4'};
caseDescriptions = { ...
    'original C1 inputs'; ...
    'remove Ay deterministic bias only'; ...
    'remove AVz deterministic bias only'; ...
    'remove Ay and AVz deterministic bias'; ...
    'remove all configured deterministic IMU biases'};
cases = repmat(struct(), 5, 1);
for k = 1:5
    uTest = u(:,1:3);
    switch caseIds{k}
        case 'B1'
            uTest(:,2) = uTest(:,2) - 0.02;
        case 'B2'
            uTest(:,3) = uTest(:,3) - 0.005;
        case 'B3'
            uTest(:,2) = uTest(:,2) - 0.02;
            uTest(:,3) = uTest(:,3) - 0.005;
        case 'B4'
            uTest(:,1) = uTest(:,1) - 0.02;
            uTest(:,2) = uTest(:,2) - 0.02;
            uTest(:,3) = uTest(:,3) - 0.005;
    end
    if k == 1
        xReplay = xB0; PReplay = PB0; diagReplay = diagB0;
    else
        [xReplay, PReplay, diagReplay] = replay_case(uTest, u(:,4));
    end
    vyError = xReplay(:,2) - vyTrue;
    cases(k).id = caseIds{k};
    cases(k).description = caseDescriptions{k};
    cases(k).input = uTest;
    cases(k).x = xReplay;
    cases(k).P = PReplay;
    cases(k).diagnostic = diagReplay;
    cases(k).vyError = vyError;
    cases(k).metrics = error_metrics(vyError);
    p22 = squeeze(PReplay(2,2,:));
    cases(k).metrics.FinalVyError = vyError(end);
    cases(k).metrics.P22_Final = p22(end);
    cases(k).metrics.P22_Max = max(p22);
end

b0Rmse = cases(1).metrics.RMSE;
b0FinalAbs = abs(cases(1).metrics.FinalVyError);
for k = 1:5
    cases(k).metrics.RMSE_ReductionPct = ...
        100*(b0Rmse - cases(k).metrics.RMSE)/b0Rmse;
    cases(k).metrics.FinalDriftReductionPct = ...
        100*(b0FinalAbs - abs(cases(k).metrics.FinalVyError))/b0FinalAbs;
end
report.cases = cases;

biasVyDot = 0.02 - 0.005.*u(:,4);
biasVyIntegral = cumtrapz(t, biasVyDot);
baselineVyError = cases(1).vyError;
corrMatrix = corrcoef(biasVyIntegral, baselineVyError);
report.theoretical = struct( ...
    'definition', 'cumtrapz(t, 0.02 - 0.005*Vx_meas)', ...
    'biasVyDot', biasVyDot, ...
    'biasVyIntegral', biasVyIntegral, ...
    'finalTheoreticalBiasDrift', biasVyIntegral(end), ...
    'baselineFinalVyError', baselineVyError(end), ...
    'finalDifferenceBaselineMinusTheory', ...
        baselineVyError(end) - biasVyIntegral(end), ...
    'trajectoryRMSE', sqrt(mean((baselineVyError-biasVyIntegral).^2)), ...
    'correlationCoefficient', corrMatrix(1,2));

report.attribution = struct( ...
    'AyFinalContribution_B0MinusB1', ...
        cases(1).metrics.FinalVyError - cases(2).metrics.FinalVyError, ...
    'AVzFinalContribution_B0MinusB2', ...
        cases(1).metrics.FinalVyError - cases(3).metrics.FinalVyError, ...
    'AyAVzFinalContribution_B0MinusB3', ...
        cases(1).metrics.FinalVyError - cases(4).metrics.FinalVyError, ...
    'AllBiasFinalContribution_B0MinusB4', ...
        cases(1).metrics.FinalVyError - cases(5).metrics.FinalVyError, ...
    'AxAdditionalFinalEffect_B3MinusB4', ...
        cases(4).metrics.FinalVyError - cases(5).metrics.FinalVyError, ...
    'AxAdditionalRMSEEffect_B3MinusB4', ...
        cases(4).metrics.RMSE - cases(5).metrics.RMSE);

report.csv = write_summary_csv(csvFile, cases, report.theoretical);
if ~isfolder(plotDir), mkdir(plotDir); end
report.plots = make_plots(plotDir, t, xOnline, vyTrue, cases, ...
    biasVyIntegral);
report.frozenAfter = hash_files(frozen);
report.frozenHashesUnchanged = compare_hashes( ...
    report.frozenBefore, report.frozenAfter, expected);
assert(report.frozenHashesUnchanged, 'A frozen file changed during replay.');
report.stopState = 'V2.1-D BIAS ATTRIBUTION COMPLETED';
save(resultFile, 'report', '-v7.3');

fprintf(['V2_1D_OK|N=%d|xdiff=%.17g|Pdiff=%.17g|diagdiff=%.17g|' ...
    'B0final=%.17g|B3final=%.17g|B4final=%.17g|' ...
    'theoryFinal=%.17g|corr=%.17g|plots=%d|hash=%d\n'], ...
    numel(t), report.equivalence.maxAbsXDiff, ...
    report.equivalence.maxAbsPDiff, report.equivalence.maxAbsDiagDiff, ...
    cases(1).metrics.FinalVyError, cases(4).metrics.FinalVyError, ...
    cases(5).metrics.FinalVyError, ...
    report.theoretical.finalTheoreticalBiasDrift, ...
    report.theoretical.correlationCoefficient, numel(report.plots), ...
    report.frozenHashesUnchanged);
end

function [xLog, PLog, diagLog] = replay_case(u, z)
assert(size(u,1) == numel(z) && size(u,2) == 3, ...
    'Replay input dimensions are invalid.');
clear vy_kinematic_kf
n = size(u,1);
xLog = zeros(n,2);
PLog = zeros(2,2,n);
diagLog = zeros(n,5);
for k = 1:n
    resetFlag = double(k == 1);
    [xk, Pk, dk] = vy_kinematic_kf(u(k,:).', z(k), resetFlag);
    xLog(k,:) = xk.';
    PLog(:,:,k) = Pk;
    diagLog(k,:) = dk.';
end
clear vy_kinematic_kf
end

function metrics = error_metrics(error)
metrics = struct('RMSE', sqrt(mean(error.^2)), ...
    'MAE', mean(abs(error)), 'Bias', mean(error), ...
    'MaxAbsError', max(abs(error)));
end

function info = write_summary_csv(csvFile, cases, theory)
n = numel(cases) + 1;
caseName = strings(n,1);
description = strings(n,1);
values = nan(n,9);
for k = 1:numel(cases)
    m = cases(k).metrics;
    caseName(k) = cases(k).id;
    description(k) = cases(k).description;
    values(k,:) = [m.RMSE m.MAE m.Bias m.MaxAbsError ...
        m.FinalVyError m.P22_Final m.P22_Max ...
        m.RMSE_ReductionPct m.FinalDriftReductionPct];
end
caseName(n) = "THEORY";
description(n) = "integral of 0.02 - 0.005*Vx_meas";
theoryFinal = nan(n,1); baselineFinal = nan(n,1);
finalDifference = nan(n,1); theoryRmse = nan(n,1); theoryCorr = nan(n,1);
theoryFinal(n) = theory.finalTheoreticalBiasDrift;
baselineFinal(n) = theory.baselineFinalVyError;
finalDifference(n) = theory.finalDifferenceBaselineMinusTheory;
theoryRmse(n) = theory.trajectoryRMSE;
theoryCorr(n) = theory.correlationCoefficient;
T = table(caseName, description, values(:,1), values(:,2), values(:,3), ...
    values(:,4), values(:,5), values(:,6), values(:,7), values(:,8), ...
    values(:,9), theoryFinal, baselineFinal, finalDifference, theoryRmse, ...
    theoryCorr, 'VariableNames', {'case','description','Vy_RMSE','Vy_MAE', ...
    'Vy_Bias','Vy_MaxAbsError','FinalVyError','P22_Final','P22_Max', ...
    'RMSE_ReductionPct','FinalDriftReductionPct', ...
    'Theory_FinalBiasDrift','Theory_BaselineFinalVyError', ...
    'Theory_FinalDifference','Theory_TrajectoryRMSE', ...
    'Theory_Correlation'});
writetable(T, csvFile);
info = struct('path', csvFile, 'rowCount', height(T), ...
    'columnNames', {T.Properties.VariableNames}, ...
    'theorySummaryRow', 'THEORY');
end

function paths = make_plots(plotDir, t, xOnline, vyTrue, cases, theory)
paths = cell(4,1);
paths{1} = fullfile(plotDir, '01_online_vs_baseline_replay.png');
f = new_figure(); tl = tiledlayout(f,2,1,'TileSpacing','compact');
nexttile(tl); plot(t,xOnline(:,1),'LineWidth',1.3); hold on;
plot(t,cases(1).x(:,1),'--','LineWidth',1.1); grid on; ylabel('Vx (m/s)');
legend('online C1','B0 offline replay','Location','best');
nexttile(tl); plot(t,xOnline(:,2),'LineWidth',1.3); hold on;
plot(t,cases(1).x(:,2),'--','LineWidth',1.1); grid on;
ylabel('Vy (m/s)'); xlabel('Time (s)');
legend('online C1','B0 offline replay','Location','best');
title(tl,'C1 online vs B0 exact offline replay'); save_figure(f,paths{1});

paths{2} = fullfile(plotDir, '02_vy_bias_case_trajectories.png');
f = new_figure(); plot(t,vyTrue,'k--','LineWidth',1.4); hold on;
for k = 1:numel(cases), plot(t,cases(k).x(:,2),'LineWidth',1.05); end
grid on; xlabel('Time (s)'); ylabel('Vy (m/s)');
title('Vy bias replay trajectories (true Vy: offline metrics only)');
legend('true Vy offline','B0','B1 no Ay bias','B2 no AVz bias', ...
    'B3 no Ay+AVz bias','B4 no all configured bias','Location','best');
save_figure(f,paths{2});

paths{3} = fullfile(plotDir, '03_vy_bias_case_errors.png');
f = new_figure(); hold on;
for k = 1:numel(cases), plot(t,cases(k).vyError,'LineWidth',1.05); end
grid on; yline(0,'k:'); xlabel('Time (s)'); ylabel('Vy error (m/s)');
title('Offline Vy errors for deterministic-bias replay cases');
legend('B0','B1 no Ay bias','B2 no AVz bias','B3 no Ay+AVz bias', ...
    'B4 no all configured bias','Location','best'); save_figure(f,paths{3});

paths{4} = fullfile(plotDir, '04_theoretical_bias_attribution.png');
f = new_figure(); plot(t,cases(1).vyError,'LineWidth',1.3); hold on;
plot(t,theory,'--','LineWidth',1.3); grid on; xlabel('Time (s)');
ylabel('Vy contribution / error (m/s)');
title('Baseline Vy error vs integrated deterministic IMU bias');
legend('B0 baseline Vy error','cumtrapz(0.02 - 0.005 Vx meas)', ...
    'Location','best'); save_figure(f,paths{4});
end

function f = new_figure()
f = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
end

function save_figure(f, path)
exportgraphics(f, path, 'Resolution', 150);
close(f);
end

function hashes = hash_files(files)
hashes = repmat(struct('path','','sha256',''), numel(files), 1);
for k = 1:numel(files)
    hashes(k).path = files{k};
    hashes(k).sha256 = file_sha256(files{k});
end
end

function unchanged = compare_hashes(before, after, expected)
unchanged = true;
for k = 1:numel(before)
    unchanged = unchanged && strcmp(before(k).sha256, after(k).sha256) && ...
        strcmp(after(k).sha256, expected{k});
end
end

function hashText = file_sha256(filePath)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(filePath));
digestStream = java.security.DigestInputStream(stream, digest);
cleanup = onCleanup(@() digestStream.close());
while digestStream.read() ~= -1
end
bytes = typecast(digest.digest(), 'uint8');
hashText = lower(reshape(dec2hex(bytes, 2).', 1, []));
clear cleanup
end
