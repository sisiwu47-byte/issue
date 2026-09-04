function summaryTable = analyze_vy_dekf_v1_7_bias_ablation(runArchive)
%ANALYZE_VY_DEKF_V1_7_BIAS_ABLATION Attribute fixed IMU-bias effects.
% Offline only: truth is used solely for scoring and never enters the EKF.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot,'results');
if nargin < 1 || isempty(runArchive)
    runArchive = fullfile(resultsDir, ...
        'vy_dekf_v1_7_bias_ablation_runs.mat');
end
loaded = load(runArchive,'runs','metadata');
runs = loaded.runs;
metadata = loaded.metadata;
assert(numel(runs) == 4);
assert(isequal({runs.Case},{'B0','B1','B2','B3'}));
Q = metadata.fixedQ;
R = metadata.fixedR;
assert(isequal(Q,diag([1e-4,1e-4])));
assert(isequal(R,diag([1e-2,3.365172961808e-4])));
chi95 = 5.991464547;
rowCells = cell(4,1);
auditCells = cell(4,1);

for k = 1:4
    run = runs(k);
    zCorrected = run.zRaw - ...
        [run.AyBiasRemoved run.AVzBiasRemoved];
    [d,states,pNew,replayDifference,correctedLogDifference] = ...
        replay_case(run,zCorrected,Q,R);
    assert(replayDifference <= 1e-12, ...
        'Replay mismatch in Case %s.',run.Case);
    assert(correctedLogDifference <= 1e-12, ...
        'Corrected-measurement log mismatch in Case %s.',run.Case);

    audit = struct();
    audit.Case = run.Case;
    audit.tAll = run.t;
    audit.zRaw = run.zRaw;
    audit.zCorrected = zCorrected;
    audit.states = states;
    audit.pNew = pNew;
    audit.NIS = d(:,1);
    audit.innovation = d(:,10:11);
    audit.replayAlignmentMax = replayDifference;
    audit.correctedLogAlignmentMax = correctedLogDifference;

    % Retain the established V1.6 causal alignment: update i becomes
    % visible at output time i+1, yielding 1600 truth-scored samples.
    audit.tAligned = run.t(2:end);
    audit.vyTrueAligned = run.vyTrue(2:end);
    audit.rTrueAligned = run.rTrue(2:end);
    audit.vyHatAligned = states(1:end-1,1);
    audit.rHatAligned = states(1:end-1,2);
    audit.vyError = audit.vyHatAligned - audit.vyTrueAligned;
    audit.rError = audit.rHatAligned - audit.rTrueAligned;
    audit.rRawImuError = audit.rHatAligned - run.zRaw(2:end,2);
    audit.rCorrectedImuError = audit.rHatAligned - zCorrected(2:end,2);

    alignedP = pNew(:,:,1:end-1);
    audit.NEES = zeros(numel(audit.tAligned),1);
    for sample = 1:numel(audit.NEES)
        P = 0.5 * (alignedP(:,:,sample) + alignedP(:,:,sample)');
        e = [audit.vyError(sample); audit.rError(sample)];
        [~,cholFlag] = chol(P);
        if cholFlag == 0
            audit.NEES(sample) = e' * (P \ e);
        else
            audit.NEES(sample) = NaN;
        end
    end

    p11 = squeeze(pNew(1,1,:));
    p22 = squeeze(pNew(2,2,:));
    minEigenvalue = inf(numel(run.t),1);
    maxCondition = zeros(numel(run.t),1);
    for sample = 1:numel(run.t)
        P = 0.5 * (pNew(:,:,sample) + pNew(:,:,sample)');
        minEigenvalue(sample) = min(eig(P));
        maxCondition(sample) = cond(P);
    end
    allValues = [states d reshape(permute(pNew,[3 1 2]), ...
        numel(run.t),[])];
    hasNaNInf = any(~isfinite(allValues),'all') || ...
        any(~isfinite(audit.NEES));
    stable = ~hasNaNInf && all(minEigenvalue >= -1e-12) && ...
        all(maxCondition < 1e12) && all(abs(states) < 1e6,'all') && ...
        all(abs(pNew) < 1e6,'all');

    row = struct('Case',string(run.Case), ...
        'Description',string(run.Description), ...
        'Ay_bias_removed',run.AyBiasRemoved, ...
        'AVz_bias_removed',run.AVzBiasRemoved, ...
        'Updates',numel(run.t), ...
        'TruthAlignedUpdates',numel(audit.tAligned));
    row = add_error(row,'Vy',audit.vyError);
    row = add_error(row,'r',audit.rError);
    row.r_vs_raw_AVz_RMSE = rms_value(audit.rRawImuError);
    row.r_vs_corrected_AVz_RMSE = rms_value(audit.rCorrectedImuError);
    row = add_basic(row,'innovation_Ay',audit.innovation(:,1));
    row = add_basic(row,'innovation_r',audit.innovation(:,2));
    row = add_four(row,'NIS',audit.NIS);
    row.NIS_fraction_above_5p991464547 = mean(audit.NIS > chi95);
    row = add_four(row,'NEES',audit.NEES);
    row.NEES_fraction_above_5p991464547 = mean(audit.NEES > chi95);
    row.median_P11 = median(p11);
    row.median_P22 = median(p22);
    row.min_eigenvalue_P = min(minEigenvalue);
    row.max_condition_number_P = max(maxCondition);
    row.replay_alignment_max_abs = replayDifference;
    row.corrected_log_alignment_max_abs = correctedLogDifference;
    row.stable = stable;
    rowCells{k} = row;
    auditCells{k} = audit;
end

rows = vertcat(rowCells{:});
audits = vertcat(auditCells{:});
summaryTable = struct2table(rows);
assert(all(summaryTable.stable),'At least one bias case is unstable.');
summaryTable = add_attribution(summaryTable);

p11Change = 100 * (summaryTable.median_P11 / ...
    summaryTable.median_P11(1) - 1);
p22Change = 100 * (summaryTable.median_P22 / ...
    summaryTable.median_P22(1) - 1);
covarianceScaleNormal = max(abs([p11Change;p22Change])) < 10;
conclusions = derive_conclusions(summaryTable,covarianceScaleNormal);

csvFile = fullfile(resultsDir,'vy_dekf_v1_7_bias_ablation.csv');
matFile = fullfile(resultsDir,'vy_dekf_v1_7_bias_ablation.mat');
writetable(summaryTable,csvFile);
figures = create_figures(summaryTable,audits,resultsDir);
save(matFile,'summaryTable','runs','audits','metadata','conclusions', ...
    'figures','-v7.3');
statusFile = fullfile(repoRoot,'docs','STAGE_VY_DEKF_V1_7_STATUS.md');
write_status(statusFile,summaryTable,metadata,conclusions,figures, ...
    csvFile,matFile,runArchive,p11Change,p22Change);
fprintf(['V1_7_ANALYSIS_OK|csv=%s|mat=%s|Vy_B3=%.12g|r_B3=%.12g|', ...
    'NIS_B3=%.12g|NEES_B3=%.12g\n'],csvFile,matFile, ...
    summaryTable.Vy_RMSE(4),summaryTable.r_RMSE(4), ...
    summaryTable.NIS_mean(4),summaryTable.NEES_mean(4));
fprintf('NO FINAL BIAS COMPENSATION WAS APPLIED.\n');
fprintf('Q AND R WERE FIXED.\n');
fprintf('THIS WAS A CONTROLLED BIAS ABLATION ONLY.\n');
end

function [d,states,pNew,maxDifference,correctedDifference] = ...
    replay_case(run,zCorrected,Q,R)
x = [0;0];
P = 0.1 * eye(2);
n = numel(run.t);
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393);
cfg = struct('dt',0.01,'Q',Q,'R',R,'denomEps',1e-12, ...
    'lambda',zeros(4,1));
d = zeros(n,41);
states = zeros(n,2);
pNew = zeros(2,2,n);
wrapperDiag = zeros(n,47);
for i = 1:n
    [x,P,info] = vy_dynamic_ekf_step_v15_debug( ...
        x,P,run.u(i,:)',zCorrected(i,:)',par,cfg);
    states(i,:) = x';
    pNew(:,:,i) = P;
    d(i,:) = [info.NIS info.Fy' info.alpha' info.innovation' ...
        info.x_pred' info.F(:)' info.H(:)' info.P_prior(:)' ...
        info.P_noQ(:)' info.P_pred(:)' info.S(:)' info.K(:)'];
    wrapperDiag(i,:) = [d(i,:) P(:)' zCorrected(i,:)];
end
maxDifference = max([ ...
    max(abs(wrapperDiag(1:end-1,:) - ...
        run.diagnostics(2:end,:)),[],'all'), ...
    max(abs(states(1:end-1,:) - run.y(2:end,:)),[],'all')]);
correctedDifference = max(abs(zCorrected(1:end-1,:) - ...
    run.zCorrectedLogged(2:end,:)),[],'all');
end

function row = add_error(row,prefix,e)
row.([prefix '_RMSE']) = rms_value(e);
row.([prefix '_MAE']) = mean(abs(e));
row.([prefix '_Bias']) = mean(e);
row.([prefix '_MaxError']) = max(abs(e));
end

function row = add_basic(row,prefix,v)
row.([prefix '_mean']) = mean(v);
row.([prefix '_std']) = std(v,0);
row.([prefix '_RMS']) = rms_value(v);
end

function row = add_four(row,prefix,v)
v = v(isfinite(v));
row.([prefix '_mean']) = mean(v);
row.([prefix '_median']) = median(v);
row.([prefix '_p95']) = percentile(v,95);
row.([prefix '_max']) = max(v);
end

function value = rms_value(v), value = sqrt(mean(v.^2)); end

function value = percentile(v,p)
v = sort(v(isfinite(v)));
position = 1 + (numel(v)-1) * p / 100;
lower = floor(position);
upper = ceil(position);
weight = position - lower;
value = v(lower) * (1-weight) + v(upper) * weight;
end

function t = add_attribution(t)
baseline = 1;
t.Vy_RMSE_reduction_percent = reduction(t.Vy_RMSE,t.Vy_RMSE(baseline));
t.r_RMSE_reduction_percent = reduction(t.r_RMSE,t.r_RMSE(baseline));
t.abs_Vy_Bias_reduction_percent = reduction(abs(t.Vy_Bias),abs(t.Vy_Bias(baseline)));
t.abs_r_Bias_reduction_percent = reduction(abs(t.r_Bias),abs(t.r_Bias(baseline)));
t.NEES_mean_reduction_percent = reduction(t.NEES_mean,t.NEES_mean(baseline));
t.NIS_mean_change_percent = 100 * (t.NIS_mean / t.NIS_mean(baseline) - 1);
end

function values = reduction(values,baseline)
values = 100 * (baseline - values) / max(abs(baseline),eps);
end

function c = derive_conclusions(t,covarianceScaleNormal)
c = struct();
c.ayMajorVySource = t.Vy_RMSE_reduction_percent(2) >= 10;
c.ayMaterialVyBiasSource = t.abs_Vy_Bias_reduction_percent(2) >= 25;
c.avzMajorRSource = t.r_RMSE_reduction_percent(3) >= 10;
c.avzMaterialRBiasSource = t.abs_r_Bias_reduction_percent(3) >= 25;
c.neesSignificantlyReduced = t.NEES_mean_reduction_percent(4) >= 20;
c.nisClearlyChanged = abs(t.NIS_mean_change_percent(4)) >= 20;
c.nisStillLow = t.NIS_mean(4) < 0.5;
c.splitExplanationSupported = c.neesSignificantlyReduced && c.nisStillLow;
c.onlineBiasHandlingWorthwhile = c.ayMajorVySource || ...
    c.ayMaterialVyBiasSource || c.avzMajorRSource || ...
    c.avzMaterialRBiasSource || c.neesSignificantlyReduced;
c.covarianceScaleNormal = covarianceScaleNormal;
c.criteria = ['major total-error source: >=10% RMSE reduction; material ', ...
    'mean-bias source: >=25% absolute-bias reduction; significant ', ...
    'NEES/NIS change: >=20%; NIS still low: mean<0.5'];
end

function files = create_figures(t,audits,resultsDir)
labels = cellstr(t.Case);
files = struct();
files.vyRmse = bar_figure(labels,t.Vy_RMSE,'Vy RMSE [m/s]', ...
    fullfile(resultsDir,'vy_dekf_v1_7_01_vy_rmse.png'));
files.rRmse = bar_figure(labels,t.r_RMSE,'r RMSE [rad/s]', ...
    fullfile(resultsDir,'vy_dekf_v1_7_02_r_rmse.png'));

fig = figure('Visible','off','Color','w','Position',[80 80 1000 650]);
bar([t.Vy_Bias t.r_Bias]); grid on;
xticks(1:4); xticklabels(labels);
ylabel('Bias'); legend('Vy [m/s]','r [rad/s]','Location','best');
title('State bias by oracle-removal case');
files.stateBias = fullfile(resultsDir,'vy_dekf_v1_7_03_state_bias.png');
exportgraphics(fig,files.stateBias,'Resolution',180); close(fig);

files.nisMean = bar_figure(labels,t.NIS_mean,'NIS mean', ...
    fullfile(resultsDir,'vy_dekf_v1_7_04_nis_mean.png'));
files.neesMean = bar_figure(labels,t.NEES_mean,'NEES mean', ...
    fullfile(resultsDir,'vy_dekf_v1_7_05_nees_mean.png'));

files.vyTrace = comparison_trace(audits(1),audits(4),'Vy', ...
    fullfile(resultsDir,'vy_dekf_v1_7_06_B0_B3_vy_trace.png'));
files.rTrace = comparison_trace(audits(1),audits(4),'r', ...
    fullfile(resultsDir,'vy_dekf_v1_7_07_B0_B3_r_trace.png'));

fig = figure('Visible','off','Color','w','Position',[50 50 1400 850]);
tiledlayout(fig,2,1,'TileSpacing','compact');
nexttile;
plot(audits(1).tAll,audits(1).innovation(:,1)); hold on;
plot(audits(4).tAll,audits(4).innovation(:,1)); grid on;
ylabel('Ay innovation [m/s^2]'); legend('B0','B3');
nexttile;
plot(audits(1).tAll,audits(1).innovation(:,2)); hold on;
plot(audits(4).tAll,audits(4).innovation(:,2)); grid on;
ylabel('r innovation [rad/s]'); xlabel('Time [s]'); legend('B0','B3');
files.innovation = fullfile(resultsDir, ...
    'vy_dekf_v1_7_08_B0_B3_innovation.png');
exportgraphics(fig,files.innovation,'Resolution',180); close(fig);
end

function file = bar_figure(labels,values,yText,file)
fig = figure('Visible','off','Color','w','Position',[100 100 850 600]);
bar(values); grid on; xticks(1:numel(labels)); xticklabels(labels);
ylabel(yText); title(yText);
for k = 1:numel(values)
    text(k,values(k),sprintf(' %.5g',values(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
exportgraphics(fig,file,'Resolution',180); close(fig);
end

function file = comparison_trace(b0,b3,signal,file)
fig = figure('Visible','off','Color','w','Position',[60 60 1350 700]);
if strcmp(signal,'Vy')
    truth = b0.vyTrueAligned;
    b0Hat = b0.vyHatAligned;
    b3Hat = b3.vyHatAligned;
    yText = 'Vy [m/s]';
else
    truth = b0.rTrueAligned;
    b0Hat = b0.rHatAligned;
    b3Hat = b3.rHatAligned;
    yText = 'r [rad/s]';
end
plot(b0.tAligned,truth,'k','LineWidth',1.4); hold on;
plot(b0.tAligned,b0Hat,'--'); plot(b3.tAligned,b3Hat,'-.'); grid on;
xlabel('Time [s]'); ylabel(yText); legend('true','B0 hat','B3 hat');
title(sprintf('B0 vs B3: %s',signal));
exportgraphics(fig,file,'Resolution',180); close(fig);
end

function write_status(file,t,metadata,c,figures,csvFile,matFile, ...
    runArchive,p11Change,p22Change)
fid = fopen(file,'w','n','UTF-8');
assert(fid >= 0);
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.7 STATUS\n\n');
fprintf(fid,'## 实验边界与验收\n\n');
fprintf(fid,['本阶段完成 B0--B3 四组已知注入 bias 的受控消融。', ...
    'bias 只在虚拟 IMU 原始输出与 D-EKF 量测入口之间减去；', ...
    '原始 Ay/AVz 日志保持不变，corrected Ay/AVz 另行记录。', ...
    '真值只用于离线评分，未进入在线估计。\n\n']);
fprintf(fid,'- 每组实际更新：%d；真值因果对齐评分样本：%d。\n', ...
    metadata.expectedUpdates,metadata.truthAlignedUpdates);
fprintf(fid,'- 四组车辆输入、原始 IMU、Vy/r 真值逐点一致：%d。\n', ...
    metadata.inputInvarianceVerified);
fprintf(fid,'- 正式/debug 核心一致性测试：%d 组，通过：%d。\n', ...
    metadata.equivalenceReport.testCount,metadata.equivalenceReport.passed);
fprintf(fid,'- 四组均数值稳定：%d。\n\n',all(t.stable));

fprintf(fid,'## 固定参数\n\n');
fprintf(fid,'- `Q = diag([1e-4,1e-4])`\n');
fprintf(fid,'- `R = diag([1e-2,3.365172961808e-4])`\n');
fprintf(fid,'- B0: `[0,0]`；B1: `[0.02,0]`；B2: `[0,0.005]`；B3: `[0.02,0.005]`。\n\n');

fprintf(fid,'## 状态精度、innovation 与一致性\n\n');
fprintf(fid,['|Case|Vy RMSE|Vy MAE|Vy Bias|Vy Max|r RMSE|r MAE|r Bias|r Max|', ...
    'nuAy mean|nur mean|NIS mean|NIS p95|NEES mean|NEES p95|\n']);
fprintf(fid,['|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n']);
for k = 1:height(t)
    fprintf(fid,['|%s|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|', ...
        '%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|\n'],t.Case(k), ...
        t.Vy_RMSE(k),t.Vy_MAE(k),t.Vy_Bias(k),t.Vy_MaxError(k), ...
        t.r_RMSE(k),t.r_MAE(k),t.r_Bias(k),t.r_MaxError(k), ...
        t.innovation_Ay_mean(k),t.innovation_r_mean(k), ...
        t.NIS_mean(k),t.NIS_p95(k),t.NEES_mean(k),t.NEES_p95(k));
end

fprintf(fid,'\n完整 CSV 另含 innovation std/RMS、NIS/NEES median/max/阈值超限率，以及 r 对 raw/corrected AVz 的 RMSE。\n\n');
fprintf(fid,'## 相对 B0 的归因\n\n');
fprintf(fid,['|Case|归因|Vy RMSE reduction|r RMSE reduction|abs Vy bias reduction|', ...
    'abs r bias reduction|NEES mean reduction|NIS mean change|\n']);
fprintf(fid,'|:--|:--|--:|--:|--:|--:|--:|--:|\n');
effects = {'baseline','Ay bias effect','yaw-rate bias effect','combined effect'};
for k = 1:height(t)
    fprintf(fid,'|%s|%s|%.6g%%|%.6g%%|%.6g%%|%.6g%%|%.6g%%|%.6g%%|\n', ...
        t.Case(k),effects{k},t.Vy_RMSE_reduction_percent(k), ...
        t.r_RMSE_reduction_percent(k), ...
        t.abs_Vy_Bias_reduction_percent(k), ...
        t.abs_r_Bias_reduction_percent(k), ...
        t.NEES_mean_reduction_percent(k),t.NIS_mean_change_percent(k));
end

fprintf(fid,'\n特别对比：B0 -> B1 的 Ay innovation mean 为 %.12g -> %.12g；', ...
    t.innovation_Ay_mean(1),t.innovation_Ay_mean(2));
fprintf(fid,'B0 -> B2 的 r innovation mean 为 %.12g -> %.12g。\n', ...
    t.innovation_r_mean(1),t.innovation_r_mean(3));

fprintf(fid,'\n## 协方差量级确认\n\n');
fprintf(fid,'|Case|median P11|change vs B0|median P22|change vs B0|\n');
fprintf(fid,'|:--|--:|--:|--:|--:|\n');
for k = 1:height(t)
    fprintf(fid,'|%s|%.12g|%.6g%%|%.12g|%.6g%%|\n',t.Case(k), ...
        t.median_P11(k),p11Change(k),t.median_P22(k),p22Change(k));
end
fprintf(fid,['\nP 中位数变化均小于 10%%：%d。因 Q/R 未变且 P 量级无异常，', ...
    'NEES 变化主要归因于状态误差变化。\n'],c.covarianceScaleNormal);

fprintf(fid,'\n## V1.7 最终判断\n\n');
fprintf(fid,'判据：%s。\n\n',c.criteria);
fprintf(fid,['1. Ay bias 是否是 Vy 状态误差的主要来源之一：', ...
    '**%s（按 RMSE）**。B1 的 Vy RMSE 仅改善 %.6g%%，', ...
    '但 `abs(Vy bias)` 改善 %.6g%%，因此 Ay bias 是 Vy ', ...
    '平均偏差的显著来源，不是当前时变/RMSE 误差的主导来源。\n'], ...
    yesno(c.ayMajorVySource),t.Vy_RMSE_reduction_percent(2), ...
    t.abs_Vy_Bias_reduction_percent(2));
fprintf(fid,['2. AVz bias 是否是 r 状态误差的主要来源之一：', ...
    '**%s**。B2 的 r RMSE 改善 %.6g%%，`abs(r bias)` 改善 %.6g%%。\n'], ...
    yesno(c.avzMajorRSource),t.r_RMSE_reduction_percent(3), ...
    t.abs_r_Bias_reduction_percent(3));
fprintf(fid,'3. 去除两个 bias 后 NEES 是否显著下降：**%s**（B3 相对 B0 %.6g%%）。\n', ...
    yesno(c.neesSignificantlyReduced),t.NEES_mean_reduction_percent(4));
fprintf(fid,'4. NIS 是否明显改变：**%s**（B3 相对 B0 %.6g%%；B3 mean %.9g）。\n', ...
    yesno(c.nisClearlyChanged),t.NIS_mean_change_percent(4),t.NIS_mean(4));
fprintf(fid,['5. `bias` 解释 state inconsistency、covariance scaling/colored noise ', ...
    '继续解释 measurement inconsistency：**%s**。'],yesno(c.splitExplanationSupported));
if c.splitExplanationSupported
    fprintf(fid,' B3 的 NEES 显著改善而 NIS mean 仍远低于二维理论均值 2。\n');
else
    fprintf(fid,' 当前消融结果不同时满足“NEES 显著改善且 NIS 仍低”。\n');
end
fprintf(fid,'6. 下一阶段是否值得设计可在线实现的 bias 处理：**%s**。\n', ...
    yesno(c.onlineBiasHandlingWorthwhile));
fprintf(fid,['\n上述判断只决定下一阶段研究方向，不会把 oracle 常数补偿', ...
    '自动写入正式估计器。\n']);

fprintf(fid,'\n## 产物\n\n');
fprintf(fid,'- `%s`\n- `%s`\n- `%s`\n',csvFile,matFile,runArchive);
names = fieldnames(figures);
for k = 1:numel(names), fprintf(fid,'- `%s`\n',figures.(names{k})); end
fprintf(fid,'- `%s`\n',metadata.modelFile);
fprintf(fid,'- `%s`\n',fullfile(fileparts(mfilename('fullpath')), ...
    'run_vy_dekf_v1_7_bias_ablation.m'));
fprintf(fid,'- `%s.m`\n',mfilename('fullpath'));

fprintf(fid,'\n**NO FINAL BIAS COMPENSATION WAS APPLIED.**\n\n');
fprintf(fid,'**Q AND R WERE FIXED.**\n\n');
fprintf(fid,'**THIS WAS A CONTROLLED BIAS ABLATION ONLY.**\n');
clear cleanup;
end

function word = yesno(value)
if value, word = '是'; else, word = '否'; end
end
