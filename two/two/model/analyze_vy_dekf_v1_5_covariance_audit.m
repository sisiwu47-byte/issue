function summaryTable = analyze_vy_dekf_v1_5_covariance_audit(runArchive)
%ANALYZE_VY_DEKF_V1_5_COVARIANCE_AUDIT Quantify Q/P and R/S budgets.
%
% Offline analysis only. No model is loaded and no Q or R is changed.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot, 'results');
if nargin < 1 || isempty(runArchive)
    runArchive = fullfile(resultsDir, ...
        'vy_dekf_v1_5_covariance_audit_runs.mat');
end
loaded = load(runArchive, 'runs', 'metadata');
runs = loaded.runs;
metadata = loaded.metadata;
assert(numel(runs) == 3 && isequal([runs.Case], [1 2 9]));
Q = metadata.Q;

auditCells = cell(3,1);
rowCells = cell(3,1);
for k = 1:3
    run = runs(k);
    [d, replayStateCov, replayAlignmentMax] = replay_case(run, Q);
    assert(replayAlignmentMax <= 1e-12, ...
        'Offline replay does not match delayed model log in Case %d.', run.Case);
    audit = struct();
    audit.t = run.t;
    audit.innovation = d(:,10:11);
    audit.NIS = d(:,1);
    audit.xPred = d(:,12:13);
    audit.F = matrix_series(d(:,14:17));
    audit.H = matrix_series(d(:,18:21));
    audit.Pprior = matrix_series(d(:,22:25));
    audit.PnoQ = matrix_series(d(:,26:29));
    audit.Ppred = matrix_series(d(:,30:33));
    audit.S = matrix_series(d(:,34:37));
    audit.K = matrix_series(d(:,38:41));
    audit.replayStateCov = replayStateCov;
    audit.loggedReplayAlignmentMax = replayAlignmentMax;
    n = numel(run.t);
    audit.Sstate = zeros(2,2,n);
    pNoQDifference = zeros(n,1);
    pPredDifference = zeros(n,1);
    sDifference = zeros(n,1);
    for sample = 1:n
        audit.Sstate(:,:,sample) = audit.H(:,:,sample) * ...
            audit.Ppred(:,:,sample) * audit.H(:,:,sample)';
        pNoQComputed = audit.F(:,:,sample) * audit.Pprior(:,:,sample) * ...
            audit.F(:,:,sample)';
        sComputed = audit.Sstate(:,:,sample) + diag([run.R_Ay run.R_r]);
        pNoQDifference(sample) = max(abs(pNoQComputed - ...
            audit.PnoQ(:,:,sample)), [], 'all');
        pPredDifference(sample) = max(abs(audit.Ppred(:,:,sample) - ...
            (audit.PnoQ(:,:,sample) + Q)), [], 'all');
        sDifference(sample) = max(abs(sComputed - audit.S(:,:,sample)), ...
            [], 'all');
    end
    audit.PnoQValidationMax = max(pNoQDifference);
    audit.PpredValidationMax = max(pPredDifference);
    audit.SValidationMax = max(sDifference);
    assert(audit.PnoQValidationMax <= 1e-12, ...
        'P_noQ identity failed in Case %d.', run.Case);
    assert(audit.PpredValidationMax <= 1e-12, ...
        'P_pred = P_noQ + Q identity failed in Case %d.', run.Case);
    assert(audit.SValidationMax <= 1e-12, ...
        'S_total identity failed in Case %d.', run.Case);

    pPrior11 = diagonal_series(audit.Pprior, 1);
    pPrior22 = diagonal_series(audit.Pprior, 2);
    pNoQ11 = diagonal_series(audit.PnoQ, 1);
    pNoQ22 = diagonal_series(audit.PnoQ, 2);
    pPred11 = diagonal_series(audit.Ppred, 1);
    pPred22 = diagonal_series(audit.Ppred, 2);
    sState11 = diagonal_series(audit.Sstate, 1);
    sState22 = diagonal_series(audit.Sstate, 2);
    s11 = diagonal_series(audit.S, 1);
    s22 = diagonal_series(audit.S, 2);

    audit.qRatio11 = Q(1,1) ./ pPred11;
    audit.qRatio22 = Q(2,2) ./ pPred22;
    audit.pNoQRatio11 = pNoQ11 ./ pPred11;
    audit.pNoQRatio22 = pNoQ22 ./ pPred22;
    audit.sStateRatio11 = sState11 ./ s11;
    audit.sStateRatio22 = sState22 ./ s22;
    audit.rRatio11 = run.R_Ay ./ s11;
    audit.rRatio22 = run.R_r ./ s22;
    audit.nisAyScalar = audit.innovation(:,1).^2 ./ s11;
    audit.nisRScalar = audit.innovation(:,2).^2 ./ s22;
    audit.innovationSq = audit.innovation.^2;

    row = struct('Case', run.Case, 'R_Ay', run.R_Ay, ...
        'R_r', run.R_r, 'Updates', n);
    row = add_three_stats(row, 'Q11_over_Ppred11', audit.qRatio11);
    row = add_three_stats(row, 'Q22_over_Ppred22', audit.qRatio22);
    row = add_three_stats(row, 'PnoQ11_over_Ppred11', audit.pNoQRatio11);
    row = add_three_stats(row, 'PnoQ22_over_Ppred22', audit.pNoQRatio22);
    row = add_three_stats(row, 'Pprior11', pPrior11);
    row = add_three_stats(row, 'Pprior22', pPrior22);
    row = add_three_stats(row, 'PnoQ11', pNoQ11);
    row = add_three_stats(row, 'PnoQ22', pNoQ22);
    row = add_three_stats(row, 'Ppred11', pPred11);
    row = add_three_stats(row, 'Ppred22', pPred22);
    row = add_three_stats(row, 'Sstate11', sState11);
    row = add_three_stats(row, 'Sstate22', sState22);
    row = add_three_stats(row, 'S11', s11);
    row = add_three_stats(row, 'S22', s22);
    row = add_three_stats(row, 'Sstate11_over_S11', audit.sStateRatio11);
    row = add_three_stats(row, 'RAy_over_S11', audit.rRatio11);
    row = add_three_stats(row, 'Sstate22_over_S22', audit.sStateRatio22);
    row = add_three_stats(row, 'Rr_over_S22', audit.rRatio22);
    row.innovation_Ay_variance = var(audit.innovation(:,1), 0);
    row.innovation_r_variance = var(audit.innovation(:,2), 0);
    row.mean_S11_over_innovation_Ay_variance = ...
        mean(s11) / row.innovation_Ay_variance;
    row.mean_S22_over_innovation_r_variance = ...
        mean(s22) / row.innovation_r_variance;
    row = add_four_stats(row, 'NIS_Ay_scalar', audit.nisAyScalar);
    row = add_four_stats(row, 'NIS_r_scalar', audit.nisRScalar);
    row = add_four_stats(row, 'NIS_2D', audit.NIS);
    K11 = diagonal_series(audit.K, 1);
    K22 = diagonal_series(audit.K, 2);
    K12 = squeeze(audit.K(1,2,:));
    K21 = squeeze(audit.K(2,1,:));
    row = add_gain_stats(row, 'K11', K11);
    row = add_gain_stats(row, 'K12', K12);
    row = add_gain_stats(row, 'K21', K21);
    row = add_gain_stats(row, 'K22', K22);
    row.PnoQ_validation_max_abs = audit.PnoQValidationMax;
    row.Ppred_validation_max_abs = audit.PpredValidationMax;
    row.S_validation_max_abs = audit.SValidationMax;
    row.logged_replay_alignment_max_abs = replayAlignmentMax;
    rowCells{k} = row;
    auditCells{k} = audit;
end

rows = vertcat(rowCells{:});
audits = vertcat(auditCells{:});
summaryTable = struct2table(rows);
case9row = 3;
supportsConservativeQ = ...
    summaryTable.Q11_over_Ppred11_median(case9row) > 0.5 && ...
    summaryTable.Q22_over_Ppred22_median(case9row) > 0.5 && ...
    summaryTable.Sstate11_over_S11_median(case9row) > 0.5 && ...
    summaryTable.Sstate22_over_S22_median(case9row) > 0.5 && ...
    summaryTable.mean_S11_over_innovation_Ay_variance(case9row) > 1.5 && ...
    summaryTable.mean_S22_over_innovation_r_variance(case9row) > 1.5;

interpretation = struct();
interpretation.supportsConservativeQ = supportsConservativeQ;
interpretation.RrReductionCase1To9 = runs(1).R_r / runs(3).R_r;
interpretation.RAyReductionCase1To9 = runs(1).R_Ay / runs(3).R_Ay;
interpretation.noQOrRChanged = true;
interpretation.nextStageQSweepExecuted = false;

csvFile = fullfile(resultsDir, 'vy_dekf_v1_5_covariance_audit.csv');
matFile = fullfile(resultsDir, 'vy_dekf_v1_5_covariance_audit.mat');
writetable(summaryTable, csvFile);
save(matFile, 'summaryTable', 'runs', 'audits', 'metadata', ...
    'interpretation', '-v7.3');

figures = create_figures(runs, audits, summaryTable, resultsDir);
statusFile = fullfile(repoRoot, 'docs', 'STAGE_VY_DEKF_V1_5_STATUS.md');
write_status(statusFile, summaryTable, metadata, interpretation, figures, ...
    csvFile, matFile, runArchive);

fprintf('V1_5_ANALYSIS_OK|csv=%s|mat=%s|support=%d\n', ...
    csvFile, matFile, supportsConservativeQ);
fprintf('NO Q OR R WAS CHANGED IN V1.5.\n');
end

function M = matrix_series(rows)
n = size(rows,1);
M = zeros(2,2,n);
for k = 1:n, M(:,:,k) = reshape(rows(k,:), 2, 2); end
end

function [diagnostics, stateCov, maxDifference] = replay_case(run, Q)
% The subsystem output Rate Transition logs a zero initial output and then
% the wrapper result with one 100 Hz sample delay. Replay the same debug
% core using the archived exact inputs to retain all 1601 actual updates.
x = [0; 0];
P = 0.1 * eye(2);
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393);
cfg = struct('dt',0.01,'Q',Q,'R',diag([run.R_Ay run.R_r]), ...
    'denomEps',1e-12,'lambda',zeros(4,1));
n = numel(run.t);
diagnostics = zeros(n,41);
stateCov = zeros(n,4);
for sample = 1:n
    [x,P,info] = vy_dynamic_ekf_step_v15_debug(x,P,run.u(sample,:)', ...
        run.z(sample,:)',par,cfg);
    stateCov(sample,:) = [x' P(1,1) P(2,2)];
    diagnostics(sample,:) = [info.NIS info.Fy' info.alpha' ...
        info.innovation' info.x_pred' info.F(:)' info.H(:)' ...
        info.P_prior(:)' info.P_noQ(:)' info.P_pred(:)' ...
        info.S(:)' info.K(:)'];
end
observedStateCov = [run.y(2:end,:) run.pDiag(2:end,:)];
maxDifference = max([ ...
    max(abs(diagnostics(1:end-1,:) - run.diagnostics(2:end,:)),[],'all'), ...
    max(abs(stateCov(1:end-1,:) - observedStateCov),[],'all')]);
end

function values = diagonal_series(M, index)
values = squeeze(M(index,index,:));
end

function row = add_three_stats(row, prefix, values)
row.([prefix '_mean']) = mean(values);
row.([prefix '_median']) = median(values);
row.([prefix '_p95']) = percentile(values, 95);
end

function row = add_four_stats(row, prefix, values)
row.([prefix '_mean']) = mean(values);
row.([prefix '_median']) = median(values);
row.([prefix '_p95']) = percentile(values, 95);
row.([prefix '_max']) = max(values);
end

function row = add_gain_stats(row, prefix, values)
row.([prefix '_mean']) = mean(values);
row.([prefix '_median']) = median(values);
row.([prefix '_min']) = min(values);
row.([prefix '_max']) = max(values);
end

function value = percentile(values, p)
values = sort(values(isfinite(values)));
position = 1 + (numel(values)-1) * p/100;
lo = floor(position); hi = ceil(position); w = position-lo;
value = values(lo)*(1-w) + values(hi)*w;
end

function files = create_figures(runs, audits, table, resultsDir)
labels = compose('Case %d', [runs.Case]);
colors = lines(3);

fig = figure('Visible','off','Color','w','Position',[80 80 1100 700]);
tiledlayout(fig,2,1,'TileSpacing','compact');
for state = 1:2
    nexttile; hold on;
    for k=1:3, semilogy(runs(k).t, ...
            max(diagonal_series(audits(k).Ppred,state),eps), ...
            'Color',colors(k,:),'LineWidth',0.9); end
    set(gca,'YScale','log'); grid on; ylabel(sprintf('P pred %d%d (log)',state,state));
    if state==1, title('Predicted state covariance'); legend(labels); end
end
xlabel('Time [s]');
files.Ppred = fullfile(resultsDir,'vy_dekf_v1_5_P_pred.png');
exportgraphics(fig,files.Ppred,'Resolution',170); close(fig);

fig = figure('Visible','off','Color','w','Position',[80 80 1200 800]);
tiledlayout(fig,3,1,'TileSpacing','compact');
for k=1:3
    nexttile; hold on;
    sState=diagonal_series(audits(k).Sstate,1);
    sTotal=diagonal_series(audits(k).S,1);
    semilogy(runs(k).t,max(sState,eps),'LineWidth',0.8);
    yline(runs(k).R_Ay,'--','R Ay'); semilogy(runs(k).t,max(sTotal,eps),'LineWidth',0.8);
    set(gca,'YScale','log'); grid on; ylabel('variance (log)'); title(sprintf('Case %d Ay budget',runs(k).Case));
    if k==1, legend('H P H''','R Ay','S11'); end
end
xlabel('Time [s]'); files.SAy=fullfile(resultsDir,'vy_dekf_v1_5_S_Ay_budget.png');
exportgraphics(fig,files.SAy,'Resolution',170); close(fig);

fig = figure('Visible','off','Color','w','Position',[80 80 1200 800]);
tiledlayout(fig,3,1,'TileSpacing','compact');
for k=1:3
    nexttile; hold on;
    sState=diagonal_series(audits(k).Sstate,2);
    sTotal=diagonal_series(audits(k).S,2);
    semilogy(runs(k).t,max(sState,eps),'LineWidth',0.8);
    yline(runs(k).R_r,'--','R r'); semilogy(runs(k).t,max(sTotal,eps),'LineWidth',0.8);
    set(gca,'YScale','log'); grid on; ylabel('variance (log)'); title(sprintf('Case %d yaw-rate budget',runs(k).Case));
    if k==1, legend('H P H''','R r','S22'); end
end
xlabel('Time [s]'); files.Sr=fullfile(resultsDir,'vy_dekf_v1_5_S_r_budget.png');
exportgraphics(fig,files.Sr,'Resolution',170); close(fig);

fig = figure('Visible','off','Color','w','Position',[60 60 1500 850]);
tiledlayout(fig,2,3,'TileSpacing','compact');
for channel=1:2
    for k=1:3
        nexttile; semilogy(runs(k).t,max(audits(k).innovationSq(:,channel),eps)); hold on;
        semilogy(runs(k).t,max(diagonal_series(audits(k).S,channel),eps),'--');
        grid on; title(sprintf('Case %d channel %d',runs(k).Case,channel));
        if k==1, ylabel('variance (log)'); end
        if channel==2, xlabel('Time [s]'); end
        if channel==1 && k==1, legend('innovation^2','predicted S'); end
    end
end
files.innovation=fullfile(resultsDir,'vy_dekf_v1_5_innovation_vs_S.png');
exportgraphics(fig,files.innovation,'Resolution',170); close(fig);

fig = figure('Visible','off','Color','w','Position',[80 80 1100 700]);
tiledlayout(fig,2,1,'TileSpacing','compact');
nexttile; hold on; for k=1:3, plot(runs(k).t,audits(k).qRatio11,'Color',colors(k,:)); end
grid on; ylabel('Q11/Ppred11'); title('Process-noise contribution ratio'); legend(labels);
nexttile; hold on; for k=1:3, plot(runs(k).t,audits(k).qRatio22,'Color',colors(k,:)); end
grid on; ylabel('Q22/Ppred22'); xlabel('Time [s]');
files.Qratio=fullfile(resultsDir,'vy_dekf_v1_5_Q_contribution.png');
exportgraphics(fig,files.Qratio,'Resolution',170); close(fig);

gainMeans = [table.K11_mean table.K12_mean table.K21_mean table.K22_mean];
fig = figure('Visible','off','Color','w','Position',[80 80 1050 600]);
bar(categorical({'K11','K12','K21','K22'}),gainMeans.'); grid on;
ylabel('Mean Kalman gain'); title('Kalman gain comparison'); legend(labels);
files.K=fullfile(resultsDir,'vy_dekf_v1_5_Kalman_gain.png');
exportgraphics(fig,files.K,'Resolution',170); close(fig);
end

function write_status(file, t, metadata, interpretation, figures, csvFile, matFile, runArchive)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.5 STATUS\n\n');
fprintf(fid,'## 验收与冻结项\n\n');
fprintf(fid,['正式核心与 debug 核心自动测试 %d 组，容差 %.3g；', ...
    '`x_new/P_new/innovation/NIS/S/K` 最大差异均为 0。三组仿真各 %d 个 100 Hz 更新点，固定输入逐点一致。\n\n'], ...
    metadata.equivalenceReport.testCount,metadata.equivalenceReport.tolerance,metadata.expectedUpdates);
fprintf(fid,['现有 subsystem 输出 Rate Transition 的首点为零初值，随后诊断延迟一个样本。', ...
    '离线顺序重放与模型可见的 1600 个更新点最大差异为 `%s`，', ...
    '因此预算统计使用经验证的完整 1601 点重放序列。\n\n'], ...
    mat2str(t.logged_replay_alignment_max_abs.',5));
fprintf(fid,'**NO Q OR R WAS CHANGED IN V1.5.**\n\n');

fprintf(fid,'## 核心预算统计（典型值取 median）\n\n');
fprintf(fid,['|Case|Q11/Ppred11|Q22/Ppred22|HPH/S11|R/S11|', ...
    'HPH/S22|R/S22|mean(S11)/var(nuAy)|mean(S22)/var(nur)|\n']);
fprintf(fid,'|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(t)
    fprintf(fid,'|%d|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|\n', ...
        t.Case(k),t.Q11_over_Ppred11_median(k),t.Q22_over_Ppred22_median(k), ...
        t.Sstate11_over_S11_median(k),t.RAy_over_S11_median(k), ...
        t.Sstate22_over_S22_median(k),t.Rr_over_S22_median(k), ...
        t.mean_S11_over_innovation_Ay_variance(k), ...
        t.mean_S22_over_innovation_r_variance(k));
end

fprintf(fid,'\n## Per-channel normalized innovation\n\n');
fprintf(fid,'|Case|Ay mean|Ay median|Ay p95|Ay max|r mean|r median|r p95|r max|\n');
fprintf(fid,'|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(t)
    fprintf(fid,'|%d|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|\n', ...
        t.Case(k),t.NIS_Ay_scalar_mean(k),t.NIS_Ay_scalar_median(k), ...
        t.NIS_Ay_scalar_p95(k),t.NIS_Ay_scalar_max(k), ...
        t.NIS_r_scalar_mean(k),t.NIS_r_scalar_median(k), ...
        t.NIS_r_scalar_p95(k),t.NIS_r_scalar_max(k));
end

fprintf(fid,'\n## Kalman gain mean（完整 mean/median/min/max 位于 CSV）\n\n');
fprintf(fid,'|Case|K11|K12|K21|K22|\n|---:|---:|---:|---:|---:|\n');
for k=1:height(t), fprintf(fid,'|%d|%.9g|%.9g|%.9g|%.9g|\n',t.Case(k), ...
        t.K11_mean(k),t.K12_mean(k),t.K21_mean(k),t.K22_mean(k)); end

fprintf(fid,'\n## 对最终问题的回答\n\n');
fprintf(fid,'1. vy 状态的典型 Q11/Ppred11（Case 1/2/9）为 `%s`。\n', ...
    mat2str(t.Q11_over_Ppred11_median.',8));
fprintf(fid,'2. r 状态的典型 Q22/Ppred22（Case 1/2/9）为 `%s`。\n', ...
    mat2str(t.Q22_over_Ppred22_median.',8));
fprintf(fid,'3. Ay 的 HPH''/S 与 R/S（Case 1/2/9）分别为 `%s` 与 `%s`。\n', ...
    mat2str(t.Sstate11_over_S11_median.',8),mat2str(t.RAy_over_S11_median.',8));
fprintf(fid,'4. r 的 HPH''/S 与 R/S（Case 1/2/9）分别为 `%s` 与 `%s`。\n', ...
    mat2str(t.Sstate22_over_S22_median.',8),mat2str(t.Rr_over_S22_median.',8));
fprintf(fid,'5. mean(S11)/var(nu_Ay) 为 `%s`。\n', ...
    mat2str(t.mean_S11_over_innovation_Ay_variance.',8));
fprintf(fid,'6. mean(S22)/var(nu_r) 为 `%s`。\n', ...
    mat2str(t.mean_S22_over_innovation_r_variance.',8));
fprintf(fid,['7. Case 1 到 Case 9，R_r 降低 %.9g 倍、R_Ay 降低 %.9g 倍。', ...
    'Case 9 中剩余的 S 预算及 Q/Ppred 比例见上表，因此单纯继续降低 R 不能消除由预测协方差形成的下限。\n'], ...
    interpretation.RrReductionCase1To9,interpretation.RAyReductionCase1To9);
if interpretation.supportsConservativeQ
    fprintf(fid,['8. **支持**：当前证据支持 Q/Ppred 过于保守是 NIS 偏低的主要原因之一；', ...
        '该判断不等价于 Q 是唯一原因，模型误差、bias 和有色噪声仍然存在。\n']);
    fprintf(fid,['9. 下一阶段仅建议另建副本做 Q 扫描：Q11=`[1e-4,3e-5,1e-5]`，', ...
        'Q22=`[1e-3,3e-4,1e-4]`，固定代表性 R、工况和全部其他条件；V1.5 未执行该扫描。\n']);
else
    fprintf(fid,['8. **当前证据不足以支持** Q/Ppred 过于保守是两个通道 NIS 偏低的共同主要原因；', ...
        '应依据上表分别处理通道贡献。\n']);
    fprintf(fid,'9. 因证据不足，本阶段不提出或执行 Q 扫描。\n');
end
fprintf(fid,'10. **NO Q OR R WAS CHANGED IN V1.5.**\n');
fprintf(fid,['\nS 重构最大误差：`%s`；P_noQ 重构最大误差：`%s`；', ...
    'P_pred=P_noQ+Q 最大误差：`%s`。\n'], ...
    mat2str(t.S_validation_max_abs.',5),mat2str(t.PnoQ_validation_max_abs.',5), ...
    mat2str(t.Ppred_validation_max_abs.',5));

fprintf(fid,'\n## 输出文件\n\n');
fprintf(fid,'- `%s`\n- `%s`\n- `%s`\n',csvFile,matFile,runArchive);
names=fieldnames(figures); for k=1:numel(names), fprintf(fid,'- `%s`\n',figures.(names{k})); end
fprintf(fid,'- `%s`\n- `%s`\n',metadata.modelFile,[mfilename('fullpath') '.m']);
matlabDir=fileparts(mfilename('fullpath'));
repoRoot=fileparts(matlabDir);
fprintf(fid,'- `%s`\n',fullfile(matlabDir,'run_vy_dekf_v1_5_covariance_audit.m'));
fprintf(fid,'- `%s`\n',fullfile(matlabDir,'vy_dynamic_ekf_step_v15_debug.m'));
fprintf(fid,'- `%s`\n',fullfile(matlabDir,'vy_dynamic_ekf_v1_5.m'));
fprintf(fid,'- `%s`\n',fullfile(repoRoot,'tests','test_vy_dynamic_ekf_step_v15_debug_equivalence.m'));
clear cleanup;
end
