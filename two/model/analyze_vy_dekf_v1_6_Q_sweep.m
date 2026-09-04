function summaryTable=analyze_vy_dekf_v1_6_Q_sweep(runArchive)
%ANALYZE_VY_DEKF_V1_6_Q_SWEEP Analyze accuracy and consistency vs Q.
% Offline only: no model or estimator parameter is modified.

repoRoot=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(repoRoot,'results');
if nargin<1||isempty(runArchive)
    runArchive=fullfile(resultsDir,'vy_dekf_v1_6_Q_sweep_runs.mat');
end
loaded=load(runArchive,'runs','metadata'); runs=loaded.runs; metadata=loaded.metadata;
assert(numel(runs)==9 && isequal([runs.Case],1:9));
R=metadata.fixedR; chi95=5.991464547;
rowCells=cell(9,1); auditCells=cell(9,1);

for k=1:9
    run=runs(k); Q=diag([run.Q_vy run.Q_r]);
    [d,states,pNew,replayDifference]=replay_case(run,Q,R);
    assert(replayDifference<=1e-12,'Replay mismatch in Case %d.',run.Case);
    audit=derive_audit(d,pNew,Q,R);
    audit.tAll=run.t;
    audit.replayState=states;
    audit.replayAlignmentMax=replayDifference;

    % Causal truth alignment: update i is visible at the next 100 Hz output
    % and is compared to truth/IMU at that output time. This yields 1600
    % evaluable updates while all covariance budgets retain 1601 updates.
    alignedStates=states(1:end-1,:);
    audit.tAligned=run.t(2:end);
    audit.vyTrueAligned=run.vyTrue(2:end);
    audit.rTrueAligned=run.rTrue(2:end);
    audit.avzImuAligned=run.z(2:end,2);
    audit.vyError=alignedStates(:,1)-audit.vyTrueAligned;
    audit.rError=alignedStates(:,2)-audit.rTrueAligned;
    audit.rImuError=alignedStates(:,2)-audit.avzImuAligned;

    alignedP=pNew(:,:,1:end-1);
    audit.NEES=zeros(numel(audit.tAligned),1);
    for sample=1:numel(audit.NEES)
        P=0.5*(alignedP(:,:,sample)+alignedP(:,:,sample)');
        e=[audit.vyError(sample);audit.rError(sample)];
        [~,cholFlag]=chol(P);
        if cholFlag==0
            audit.NEES(sample)=e'*(P\e);
        else
            audit.NEES(sample)=NaN;
        end
    end

    eigenMin=zeros(numel(run.t),1); conditionNumber=zeros(numel(run.t),1);
    for sample=1:numel(run.t)
        P=0.5*(pNew(:,:,sample)+pNew(:,:,sample)');
        eigenMin(sample)=min(eig(P));
        conditionNumber(sample)=cond(P);
    end
    audit.eigenMin=eigenMin;
    audit.conditionNumber=conditionNumber;
    p11=diagonal_series(pNew,1); p22=diagonal_series(pNew,2);
    p12=squeeze(pNew(1,2,:)); p21=squeeze(pNew(2,1,:));
    allValues=[states d reshape(permute(pNew,[3 1 2]),numel(run.t),[])];
    hasNaNInf=any(~isfinite(allValues),'all')||any(~isfinite(audit.NEES));
    negativeEigenvalue=any(eigenMin < -1e-12);
    numericalExplosion=any(abs(states)>1e6,'all')||any(abs(pNew)>1e6,'all')|| ...
        any(conditionNumber>1e12)||any(~isfinite(conditionNumber));
    stable=~hasNaNInf&&~negativeEigenvalue&&~numericalExplosion;

    row=struct('Case',run.Case,'Level_Qvy',string(run.LevelVy), ...
        'Level_Qr',string(run.LevelR),'Q_vy',run.Q_vy,'Q_r',run.Q_r, ...
        'BudgetUpdates',numel(run.t),'TruthAlignedUpdates',numel(audit.tAligned));
    row=add_error(row,'Vy',audit.vyError);
    row=add_error(row,'r',audit.rError);
    row=add_error(row,'r_IMU',audit.rImuError);
    row=add_four(row,'NIS',audit.NIS);
    row.NIS_above95=mean(audit.NIS>chi95);
    row=add_four(row,'NEES',audit.NEES);
    row.NEES_above95=mean(audit.NEES>chi95);
    row=add_basic(row,'innovation_Ay',audit.innovation(:,1));
    row=add_basic(row,'innovation_r',audit.innovation(:,2));
    row.Q11_over_Ppred11=audit.Q11_over_Ppred11_median;
    row.Q22_over_Ppred22=audit.Q22_over_Ppred22_median;
    row.HPH11_over_S11=audit.HPH11_over_S11_median;
    row.RAy_over_S11=audit.RAy_over_S11_median;
    row.HPH22_over_S22=audit.HPH22_over_S22_median;
    row.Rr_over_S22=audit.Rr_over_S22_median;
    row.S11_over_varInnovationAy=audit.S11_over_varInnovationAy;
    row.S22_over_varInnovationR=audit.S22_over_varInnovationR;
    row.P11_min=min(p11);row.P11_max=max(p11);row.P11_final=p11(end);
    row.P22_min=min(p22);row.P22_max=max(p22);row.P22_final=p22(end);
    row.P12_min=min(p12);row.P12_max=max(p12);
    row.P21_min=min(p21);row.P21_max=max(p21);
    row.min_eigenvalue_P=min(eigenMin);
    row.max_condition_number_P=max(conditionNumber);
    row.HasNaNInf=hasNaNInf;row.NegativeEigenvalue=negativeEigenvalue;
    row.NumericalExplosion=numericalExplosion;row.stable=stable;
    row.replay_alignment_max_abs=replayDifference;
    row.S_identity_max_abs=audit.SidentityMax;
    row.Ppred_identity_max_abs=audit.PpredIdentityMax;
    rowCells{k}=row; auditCells{k}=audit;
end

rows=vertcat(rowCells{:}); audits=vertcat(auditCells{:});
summaryTable=struct2table(rows);
assert(all(summaryTable.stable),'At least one Q case is numerically unstable.');

[~,bestVy]=min(summaryTable.Vy_RMSE);
[~,bestR]=min(summaryTable.r_RMSE);
nisDistance=consistency_distance(summaryTable.NIS_mean,summaryTable.NIS_p95,chi95);
neesDistance=consistency_distance(summaryTable.NEES_mean,summaryTable.NEES_p95,chi95);
[~,bestNIS]=min(nisDistance); [~,bestNEES]=min(neesDistance);
baselineVy=summaryTable.Vy_RMSE(1); baselineR=summaryTable.r_RMSE(1);
eligible=summaryTable.stable & summaryTable.Vy_RMSE<=1.05*baselineVy & ...
    summaryTable.r_RMSE<=1.05*baselineR & abs(summaryTable.Vy_Bias)<= ...
    max(1.25*abs(summaryTable.Vy_Bias(1)),1e-6) & ...
    abs(summaryTable.r_Bias)<=max(1.25*abs(summaryTable.r_Bias(1)),1e-6);
budgetDistance=abs(log(max(summaryTable.S11_over_varInnovationAy,eps)))+ ...
    abs(log(max(summaryTable.S22_over_varInnovationR,eps)));
eligibleIndices=find(eligible);
if isempty(eligibleIndices),eligibleIndices=find(summaryTable.stable);end
[~,localBudget]=min(budgetDistance(eligibleIndices));
bestBudget=eligibleIndices(localBudget);
recommended=unique([bestVy;bestR;bestBudget],'stable');
recommended=recommended(1:min(3,numel(recommended)));

case9=9;
furtherLowerSuggested=summaryTable.NIS_mean(case9)<0.2 && ...
    summaryTable.Q11_over_Ppred11(case9)>0.5 && ...
    summaryTable.Q22_over_Ppred22(case9)>0.5 && ...
    summaryTable.Vy_RMSE(case9)<=1.1*baselineVy && ...
    summaryTable.r_RMSE(case9)<=1.1*baselineR && ...
    summaryTable.NEES_mean(case9)<10;
rangeExceeded=summaryTable.Vy_RMSE(case9)>1.2*baselineVy || ...
    summaryTable.r_RMSE(case9)>1.2*baselineR || ...
    summaryTable.NEES_mean(case9)>10 || ~summaryTable.stable(case9);

selection=struct('bestVy',bestVy,'bestR',bestR,'bestNIS',bestNIS, ...
    'bestNEES',bestNEES,'bestBudget',bestBudget, ...
    'recommended',recommended(:).','furtherLowerSuggested',furtherLowerSuggested, ...
    'rangeExceeded',rangeExceeded,'noFinalQApplied',true);
csvFile=fullfile(resultsDir,'vy_dekf_v1_6_Q_sweep.csv');
matFile=fullfile(resultsDir,'vy_dekf_v1_6_Q_sweep.mat');
writetable(summaryTable,csvFile);
save(matFile,'summaryTable','runs','audits','metadata','selection','-v7.3');
figures=create_figures(summaryTable,runs,audits,resultsDir,chi95);
statusFile=fullfile(repoRoot,'docs','STAGE_VY_DEKF_V1_6_STATUS.md');
write_status(statusFile,summaryTable,metadata,selection,figures,csvFile,matFile,runArchive);
fprintf('V1_6_ANALYSIS_OK|csv=%s|mat=%s|recommended=%s|lower_more=%d\n', ...
    csvFile,matFile,mat2str(recommended(:).'),furtherLowerSuggested);
fprintf('NO FINAL Q WAS APPLIED.\n');
end

function [d,states,pNew,maxDifference]=replay_case(run,Q,R)
x=[0;0];P=0.1*eye(2);n=numel(run.t);
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',0.393);
cfg=struct('dt',0.01,'Q',Q,'R',R,'denomEps',1e-12,'lambda',zeros(4,1));
d=zeros(n,41);states=zeros(n,2);pNew=zeros(2,2,n);wrapperDiag=zeros(n,45);
for i=1:n
    [x,P,info]=vy_dynamic_ekf_step_v15_debug(x,P,run.u(i,:)',run.z(i,:)',par,cfg);
    states(i,:)=x';pNew(:,:,i)=P;
    d(i,:)=[info.NIS info.Fy' info.alpha' info.innovation' info.x_pred' ...
        info.F(:)' info.H(:)' info.P_prior(:)' info.P_noQ(:)' ...
        info.P_pred(:)' info.S(:)' info.K(:)'];
    wrapperDiag(i,:)=[d(i,:) P(:)'];
end
maxDifference=max([max(abs(wrapperDiag(1:end-1,:)-run.diagnostics(2:end,:)),[],'all'), ...
    max(abs(states(1:end-1,:)-run.y(2:end,:)),[],'all')]);
end

function audit=derive_audit(d,pNew,Q,R)
audit=struct();audit.NIS=d(:,1);audit.innovation=d(:,10:11);
audit.F=matrix_series(d(:,14:17));audit.H=matrix_series(d(:,18:21));
audit.Pprior=matrix_series(d(:,22:25));audit.PnoQ=matrix_series(d(:,26:29));
audit.Ppred=matrix_series(d(:,30:33));audit.S=matrix_series(d(:,34:37));
audit.K=matrix_series(d(:,38:41));audit.Pnew=pNew;n=size(d,1);
audit.Sstate=zeros(2,2,n);sError=zeros(n,1);pError=zeros(n,1);
for i=1:n
    audit.Sstate(:,:,i)=audit.H(:,:,i)*audit.Ppred(:,:,i)*audit.H(:,:,i)';
    sError(i)=max(abs(audit.S(:,:,i)-(audit.Sstate(:,:,i)+R)),[],'all');
    pError(i)=max(abs(audit.Ppred(:,:,i)-(audit.PnoQ(:,:,i)+Q)),[],'all');
end
audit.SidentityMax=max(sError);audit.PpredIdentityMax=max(pError);
assert(audit.SidentityMax<=1e-12&&audit.PpredIdentityMax<=1e-12);
p11=diagonal_series(audit.Ppred,1);p22=diagonal_series(audit.Ppred,2);
s11=diagonal_series(audit.S,1);s22=diagonal_series(audit.S,2);
hph11=diagonal_series(audit.Sstate,1);hph22=diagonal_series(audit.Sstate,2);
audit.qRatio11=Q(1,1)./p11;audit.qRatio22=Q(2,2)./p22;
audit.hphRatio11=hph11./s11;audit.hphRatio22=hph22./s22;
audit.rRatio11=R(1,1)./s11;audit.rRatio22=R(2,2)./s22;
audit.Q11_over_Ppred11_median=median(audit.qRatio11);
audit.Q22_over_Ppred22_median=median(audit.qRatio22);
audit.HPH11_over_S11_median=median(audit.hphRatio11);
audit.HPH22_over_S22_median=median(audit.hphRatio22);
audit.RAy_over_S11_median=median(audit.rRatio11);
audit.Rr_over_S22_median=median(audit.rRatio22);
audit.S11_over_varInnovationAy=mean(s11)/var(audit.innovation(:,1),0);
audit.S22_over_varInnovationR=mean(s22)/var(audit.innovation(:,2),0);
end

function M=matrix_series(rows)
n=size(rows,1);M=zeros(2,2,n);for i=1:n,M(:,:,i)=reshape(rows(i,:),2,2);end
end
function v=diagonal_series(M,i),v=squeeze(M(i,i,:));end
function row=add_error(row,prefix,e)
row.([prefix '_RMSE'])=sqrt(mean(e.^2));row.([prefix '_MAE'])=mean(abs(e));
row.([prefix '_Bias'])=mean(e);row.([prefix '_Max'])=max(abs(e));
end
function row=add_four(row,prefix,v)
v=v(isfinite(v));row.([prefix '_mean'])=mean(v);row.([prefix '_median'])=median(v);
row.([prefix '_p95'])=percentile(v,95);row.([prefix '_max'])=max(v);
end
function row=add_basic(row,prefix,v)
row.([prefix '_mean'])=mean(v);row.([prefix '_std'])=std(v,0);
row.([prefix '_RMS'])=sqrt(mean(v.^2));
end
function value=percentile(v,p)
v=sort(v(isfinite(v)));pos=1+(numel(v)-1)*p/100;lo=floor(pos);hi=ceil(pos);w=pos-lo;
value=v(lo)*(1-w)+v(hi)*w;
end
function d=consistency_distance(mu,p95,threshold)
d=abs(log(max(mu,eps)/2))+abs(log(max(p95,eps)/threshold));
end

function files=create_figures(t,runs,audits,resultsDir,chi95)
labels={'H','M','L'};
fig=figure('Visible','off','Color','w','Position',[50 50 1400 1000]);
tiledlayout(fig,2,2,'TileSpacing','compact');
one_heatmap(t.Vy_RMSE,'Vy RMSE [m/s]',labels);
one_heatmap(t.r_RMSE,'true-r RMSE [rad/s]',labels);
one_heatmap(t.NIS_mean,'NIS mean',labels);
one_heatmap(t.NEES_mean,'NEES mean',labels);
files.performance=fullfile(resultsDir,'vy_dekf_v1_6_performance_heatmaps.png');
exportgraphics(fig,files.performance,'Resolution',170);close(fig);

fig=figure('Visible','off','Color','w','Position',[50 50 1400 1000]);
tiledlayout(fig,2,2,'TileSpacing','compact');
one_heatmap(t.Q11_over_Ppred11,'median Q11/Ppred11',labels);
one_heatmap(t.Q22_over_Ppred22,'median Q22/Ppred22',labels);
one_heatmap(t.S11_over_varInnovationAy,'mean(S11)/var(nu Ay)',labels);
one_heatmap(t.S22_over_varInnovationR,'mean(S22)/var(nu r)',labels);
files.covariance=fullfile(resultsDir,'vy_dekf_v1_6_covariance_heatmaps.png');
exportgraphics(fig,files.covariance,'Resolution',170);close(fig);

selected=[1 5 9];
fig=figure('Visible','off','Color','w','Position',[20 30 2100 1100]);
tiledlayout(fig,3,6,'TileSpacing','compact','Padding','compact');
for row=1:3
    k=selected(row);a=audits(k);time=a.tAligned;
    nexttile;plot(time,a.vyTrueAligned);hold on;plot(time,a.replayState(1:end-1,1),'--');grid on;
    title(sprintf('Case %d Vy',k));if row==1,legend('true','hat');end
    nexttile;plot(time,a.vyError);grid on;title('Vy error');
    nexttile;plot(time,a.rTrueAligned);hold on;plot(time,a.replayState(1:end-1,2),'--');grid on;title('true r / hat');
    nexttile;semilogy(a.tAll,max(a.NIS,eps));hold on;yline(chi95,'--r');grid on;title('NIS');
    nexttile;semilogy(time,max(a.NEES,eps));hold on;yline(chi95,'--r');grid on;title('NEES');
    nexttile;semilogy(a.tAll,max([diagonal_series(a.Pnew,1) diagonal_series(a.Pnew,2)],eps));grid on;title('P11 / P22');
end
files.representative=fullfile(resultsDir,'vy_dekf_v1_6_representative_cases.png');
exportgraphics(fig,files.representative,'Resolution',170);close(fig);
end

function one_heatmap(values,titleText,labels)
nexttile;matrix=reshape(values,3,3).';imagesc(matrix);axis image;colorbar;
xticks(1:3);xticklabels(labels);yticks(1:3);yticklabels(labels);
xlabel('Q_r level');ylabel('Q_vy level');title(titleText);
for r=1:3,for c=1:3,text(c,r,sprintf('%.4g',matrix(r,c)), ...
    'HorizontalAlignment','center','BackgroundColor','w');end,end
end

function write_status(file,t,metadata,s,figures,csvFile,matFile,runArchive)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.6 STATUS\n\n');
fprintf(fid,'## 冻结项与验收\n\n');
fprintf(fid,['九组仿真均使用固定 `R=diag([1e-2,3.365172961808e-4])`，', ...
    '每组包含 %d 个实际 100 Hz 更新。协方差预算使用全部更新；', ...
    '状态精度和 NEES 使用 %d 个与真值因果对齐的更新。九组输入逐点一致。\n\n'], ...
    metadata.expectedUpdates,metadata.truthAlignedUpdates);
fprintf(fid,'- 正式/debug 核心一致性测试：%d 组，最大差异 0。\n',metadata.equivalenceReport.testCount);
fprintf(fid,'- 所有 case 数值稳定：%d。\n',all(t.stable));
fprintf(fid,'- **NO FINAL Q WAS APPLIED.**\n');
fprintf(fid,'- **R WAS FIXED TO: `diag([1e-2,3.365172961808e-4])`.**\n');
fprintf(fid,'- **ONLY DISCRETE-TIME Q WAS VARIED.**\n\n');

fprintf(fid,'## 结果表\n\n');
fprintf(fid,['|Case|Q_vy|Q_r|Vy RMSE|Vy Bias|r RMSE|r Bias|NIS mean|NIS p95|', ...
    'NEES mean|NEES p95|Q11/Ppred11|Q22/Ppred22|S11/var(nuAy)|S22/var(nur)|stable|\n']);
fprintf(fid,'|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
for k=1:height(t)
    fprintf(fid,['|%d|%.6g|%.6g|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|', ...
        '%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%d|\n'],t.Case(k),t.Q_vy(k),t.Q_r(k), ...
        t.Vy_RMSE(k),t.Vy_Bias(k),t.r_RMSE(k),t.r_Bias(k),t.NIS_mean(k), ...
        t.NIS_p95(k),t.NEES_mean(k),t.NEES_p95(k),t.Q11_over_Ppred11(k), ...
        t.Q22_over_Ppred22(k),t.S11_over_varInnovationAy(k), ...
        t.S22_over_varInnovationR(k),t.stable(k));
end

fprintf(fid,'\n## 选择结论\n\n');
fprintf(fid,'A. Vy RMSE 最小：Case %d，%.12g m/s。\n',s.bestVy,t.Vy_RMSE(s.bestVy));
fprintf(fid,'B. true-r RMSE 最小：Case %d，%.12g rad/s。\n',s.bestR,t.r_RMSE(s.bestR));
fprintf(fid,'C. NIS 数量级最接近理论参考：Case %d，mean %.12g，p95 %.12g。\n', ...
    s.bestNIS,t.NIS_mean(s.bestNIS),t.NIS_p95(s.bestNIS));
fprintf(fid,'D. NEES 数量级最接近理论参考：Case %d，mean %.12g，p95 %.12g。\n', ...
    s.bestNEES,t.NEES_mean(s.bestNEES),t.NEES_p95(s.bestNEES));
fprintf(fid,['E. 在 RMSE/Bias 未明显恶化的约束下，covariance-budget 改善最明显：', ...
    'Case %d，S11/var=%.12g，S22/var=%.12g。\n'],s.bestBudget, ...
    t.S11_over_varInnovationAy(s.bestBudget),t.S22_over_varInnovationR(s.bestBudget));
fprintf(fid,'最多三个候选：%s。候选仅用于下一阶段判断，未写入正式 Q。\n', ...
    strjoin(compose('Case %d',s.recommended),'、'));

fprintf(fid,'\n## 是否扩展扫描范围\n\n');
if s.rangeExceeded
    fprintf(fid,'Case 9 已出现精度/NEES/稳定性越界迹象，不建议继续降低 Q。\n');
elseif s.furtherLowerSuggested
    fprintf(fid,['Case 9 的 NIS 仍低且 Q/Ppred 比例仍高，精度、NEES 和稳定性未越界；', ...
        '只建议下一轮进一步降低 Q 的受控扫描，**本阶段未执行扩展扫描**。\n']);
else
    fprintf(fid,'Case 9 没有同时满足继续降低 Q 的条件，本阶段不建议扩展范围。\n');
end

fprintf(fid,'\n## 数值稳定性\n\n');
fprintf(fid,['完整 CSV 包含 P11/P22 min/max/final、P12/P21 min/max、', ...
    '最小特征值、最大条件数、NaN/Inf/负特征值/爆炸标志及 innovation 全部统计。\n']);
fprintf(fid,'S 与 Ppred 恒等式最大误差分别为 `%s`、`%s`；日志重放对齐误差为 `%s`。\n', ...
    mat2str(t.S_identity_max_abs.',4),mat2str(t.Ppred_identity_max_abs.',4), ...
    mat2str(t.replay_alignment_max_abs.',4));

fprintf(fid,'\n## 文件\n\n');
fprintf(fid,'- `%s`\n- `%s`\n- `%s`\n',csvFile,matFile,runArchive);
names=fieldnames(figures);for k=1:numel(names),fprintf(fid,'- `%s`\n',figures.(names{k}));end
matlabDir=fileparts(mfilename('fullpath'));
fprintf(fid,'- `%s`\n',metadata.modelFile);
fprintf(fid,'- `%s.m`\n',mfilename('fullpath'));
fprintf(fid,'- `%s`\n',fullfile(matlabDir,'run_vy_dekf_v1_6_Q_sweep.m'));
fprintf(fid,'- `%s`\n',fullfile(matlabDir,'vy_dynamic_ekf_v1_6.m'));
fprintf(fid,'\n**NO FINAL Q WAS APPLIED.**\n\n');
fprintf(fid,'**R WAS FIXED TO: `diag([1e-2,3.365172961808e-4])`.**\n\n');
fprintf(fid,'**ONLY DISCRETE-TIME Q WAS VARIED.**\n');
clear cleanup;
end
