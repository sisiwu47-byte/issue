function [selectedNames,screenTable,paretoTable]=analyze_vy_dekf_v1_15_covariance_calibration(mode,archive)
%ANALYZE_VY_DEKF_V1_15_COVARIANCE_CALIBRATION Pareto screen/final audit.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');docs=fullfile(root,'docs');
if nargin<1||isempty(mode),mode='final';end
if nargin<2||isempty(archive),archive=fullfile(res,'vy_dekf_v1_15_covariance_calibration_runs.mat');end
S=load(archive);screenTable=score_runs(S.calibrationRuns);summary=config_summary(screenTable);
[paretoTable,selectedNames]=pareto_select(summary);
screenCsv=fullfile(res,'vy_dekf_v1_15_calibration_screen.csv');writetable(screenTable,screenCsv);
summaryCsv=fullfile(res,'vy_dekf_v1_15_calibration_config_summary.csv');writetable(summary,summaryCsv);
if strcmpi(mode,'select')
    fprintf('V1_15_PARETO_SELECTED|%s\n',strjoin(cellstr(selectedNames),','));return
end
assert(isfield(S,'fullRuns'));fullTable=score_runs(S.fullRuns);assert(height(fullTable)==numel(S.metadata.fullConfigs)*7);
decision=final_decision(fullTable,selectedNames);figures=make_figures(res,screenTable,summary,fullTable,decision);
csvFile=fullfile(res,'vy_dekf_v1_15_covariance_calibration.csv');writetable(fullTable,csvFile);
matFile=fullfile(res,'vy_dekf_v1_15_covariance_calibration.mat');
audit=struct('modelFile',S.metadata.buildAudit.target,'sourceModel',S.metadata.buildAudit.source, ...
    'k_f',.78181,'k_r',1.09186,'calibrationSimulationCount',36,'fullSimulationCount',numel(S.fullRuns), ...
    'totalSimulationCount',36+numel(S.fullRuns),'updatesPerRun',1601,'scoredSamplesPerRun',1600, ...
    'calibrationInputMax',S.metadata.calibrationInputMax,'fullInputMax',S.metadata.fullInputMax, ...
    'baselineArchiveMax',max(S.metadata.baselineArchiveMax,S.metadata.fullBaselineArchiveMax),'baselineOutputMax',max(S.metadata.baselineOutputMax,S.metadata.fullBaselineOutputMax), ...
    'posteriorAlignment','x_hat(i), P_new(:,:,i), truth(i+1)','onlyDiagonalQR',true,'coloredNoiseModelAdded',false);
save(matFile,'audit','fullTable','screenTable','summary','paretoTable','selectedNames','decision','figures','-v7.3');
statusFile=fullfile(docs,'STAGE_VY_DEKF_V1_15_STATUS.md');
write_status(statusFile,S.metadata,screenTable,summary,paretoTable,fullTable,decision,audit,figures,csvFile,matFile,screenCsv,summaryCsv);
req=[{S.metadata.buildAudit.target};{csvFile};{matFile};{statusFile};struct2cell(figures)];
for i=1:numel(req),p=char(req{i});assert(isfile(p));d=dir(p);assert(d(1).bytes>0);end
assert(all(fullTable.EKF_Updates==1601)&&all(fullTable.Scored_samples==1600));
fprintf('V1_15_COMPLETE|decision=%s|chosen=%s|selected=%s\n',decision.freezeDecision,decision.chosenConfiguration,strjoin(cellstr(selectedNames),','));
end

function T=score_runs(runs)
n=numel(runs);assert(n>0);M=repmat(metrics(runs(1)),n,1);
for i=2:n,M(i)=metrics(runs(i));end
base=containers.Map();for i=1:n,if strcmp(M(i).Configuration,'C0'),base(char(M(i).Case))=M(i);end,end
for i=1:n
    b=base(char(M(i).Case));M(i).Vy_improvement_vs_V13=100*(1-M(i).Vy_RMSE/b.Vy_RMSE);M(i).r_improvement_vs_V13=100*(1-M(i).r_RMSE/b.r_RMSE);
end
T=struct2table(M);order={'Case','Configuration','Q_vy','Q_r','R_Ay','R_r','Vy_RMSE','Vy_improvement_vs_V13','Vy_MAE','Vy_Bias','Vy_Max_error','r_RMSE','r_improvement_vs_V13','r_MAE','r_Bias','r_Max_error','r_hat_vs_AVz_IMU_RMSE','NIS_mean','NIS_median','NIS_p95','NIS_max','NIS_fraction_above_5_991','scalar_Ay_mean','scalar_Ay_median','scalar_Ay_p95','scalar_r_mean','scalar_r_median','scalar_r_p95','standardized_Ay_std','standardized_r_std','standardized_Ay_rho1','standardized_Ay_rho5','standardized_Ay_rho10','standardized_r_rho1','standardized_r_rho5','standardized_r_rho10','NEES_mean','NEES_median','NEES_p95','NEES_max','NEES_fraction_above_5_991','Vy_marginal_NSEE_mean','Vy_marginal_NSEE_median','Vy_marginal_NSEE_p95','r_marginal_NSEE_mean','r_marginal_NSEE_median','r_marginal_NSEE_p95','gamma_vy','gamma_r','Vy_1sigma_coverage','Vy_2sigma_coverage','Vy_3sigma_coverage','r_1sigma_coverage','r_2sigma_coverage','r_3sigma_coverage','Ce_eig_major','Ce_eig_minor','Pbar_eig_major','Pbar_eig_minor','principal_axis_difference_deg','min_P_eigenvalue','max_P_condition','stable','EKF_Updates','Scored_samples'};
T=T(:,order);
end

function m=metrics(r)
D=r.diagnostics(2:end,:);n=size(D,1);assert(n==1600);x=r.y(2:end,:);truth=[r.vyTrue(2:end) r.rTrue(2:end)];e=x-truth;
nu=D(:,10:11);nis=D(:,1);P=matseries(D(:,42:45));Sm=matseries(D(:,34:37));epsi=zeros(n,2);nees=zeros(n,1);marg=zeros(n,2);sig=zeros(n,2);mine=inf;maxc=0;
for k=1:n
    Pk=.5*(P(:,:,k)+P(:,:,k)');Sk=.5*(Sm(:,:,k)+Sm(:,:,k)');[L,flag]=chol(Sk,'lower');assert(flag==0);epsi(k,:)=(L\nu(k,:)')';ee=e(k,:)';nees(k)=ee'*(Pk\ee);marg(k,:)=[ee(1)^2/Pk(1,1),ee(2)^2/Pk(2,2)];sig(k,:)=[sqrt(Pk(1,1)),sqrt(Pk(2,2))];mine=min(mine,min(eig(Pk)));maxc=max(maxc,cond(Pk));
end
sc=[nu(:,1).^2./squeeze(Sm(1,1,:)),nu(:,2).^2./squeeze(Sm(2,2,:))];Ce=cov(e);Pb=mean(P,3);el=ellipse(Ce,Pb);
vy=err(e(:,1));rr=err(e(:,2));ns=dist(nis);ne=dist(nees);mv=dist(marg(:,1));mr=dist(marg(:,2));sa=dist(sc(:,1));sr=dist(sc(:,2));aa=acf(epsi(:,1),10);ar=acf(epsi(:,2),10);
m=struct('Case',string(r.Case),'Configuration',string(r.Configuration),'Q_vy',r.Q(1,1),'Q_r',r.Q(2,2),'R_Ay',r.R(1,1),'R_r',r.R(2,2), ...
    'Vy_RMSE',vy.RMSE,'Vy_improvement_vs_V13',NaN,'Vy_MAE',vy.MAE,'Vy_Bias',vy.Bias,'Vy_Max_error',vy.Max, ...
    'r_RMSE',rr.RMSE,'r_improvement_vs_V13',NaN,'r_MAE',rr.MAE,'r_Bias',rr.Bias,'r_Max_error',rr.Max,'r_hat_vs_AVz_IMU_RMSE',rmsv(x(:,2)-r.zRaw(2:end,2)), ...
    'NIS_mean',ns.Mean,'NIS_median',ns.Median,'NIS_p95',ns.P95,'NIS_max',ns.Max,'NIS_fraction_above_5_991',ns.Fraction, ...
    'scalar_Ay_mean',sa.Mean,'scalar_Ay_median',sa.Median,'scalar_Ay_p95',sa.P95,'scalar_r_mean',sr.Mean,'scalar_r_median',sr.Median,'scalar_r_p95',sr.P95, ...
    'standardized_Ay_std',std(epsi(:,1),0),'standardized_r_std',std(epsi(:,2),0),'standardized_Ay_rho1',aa(1),'standardized_Ay_rho5',aa(5),'standardized_Ay_rho10',aa(10),'standardized_r_rho1',ar(1),'standardized_r_rho5',ar(5),'standardized_r_rho10',ar(10), ...
    'NEES_mean',ne.Mean,'NEES_median',ne.Median,'NEES_p95',ne.P95,'NEES_max',ne.Max,'NEES_fraction_above_5_991',ne.Fraction, ...
    'Vy_marginal_NSEE_mean',mv.Mean,'Vy_marginal_NSEE_median',mv.Median,'Vy_marginal_NSEE_p95',mv.P95,'r_marginal_NSEE_mean',mr.Mean,'r_marginal_NSEE_median',mr.Median,'r_marginal_NSEE_p95',mr.P95, ...
    'gamma_vy',var(e(:,1),0)/mean(squeeze(P(1,1,:))),'gamma_r',var(e(:,2),0)/mean(squeeze(P(2,2,:))), ...
    'Vy_1sigma_coverage',mean(abs(e(:,1))<=sig(:,1)),'Vy_2sigma_coverage',mean(abs(e(:,1))<=2*sig(:,1)),'Vy_3sigma_coverage',mean(abs(e(:,1))<=3*sig(:,1)), ...
    'r_1sigma_coverage',mean(abs(e(:,2))<=sig(:,2)),'r_2sigma_coverage',mean(abs(e(:,2))<=2*sig(:,2)),'r_3sigma_coverage',mean(abs(e(:,2))<=3*sig(:,2)), ...
    'Ce_eig_major',el.eCe(1),'Ce_eig_minor',el.eCe(2),'Pbar_eig_major',el.eP(1),'Pbar_eig_minor',el.eP(2),'principal_axis_difference_deg',el.diff, ...
    'min_P_eigenvalue',mine,'max_P_condition',maxc,'stable',all(isfinite([x(:);P(:);nis]))&&mine>0&&maxc<1e12,'EKF_Updates',numel(r.t),'Scored_samples',n);
end

function S=config_summary(T)
names=unique(T.Configuration,'stable');rows=cell(numel(names),1);high=ismember(T.Case,["V25","A30","F60"]);
for i=1:numel(names)
    q=T(T.Configuration==names(i),:);h=T(T.Configuration==names(i)&high,:);isBase=names(i)=="C0";
    rows{i}=struct('Configuration',names(i),'Q_vy',q.Q_vy(1),'Q_r',q.Q_r(1),'R_Ay',q.R_Ay(1),'R_r',q.R_r(1), ...
        'Worst_Vy_improvement',min(q.Vy_improvement_vs_V13),'Worst_r_improvement',min(q.r_improvement_vs_V13),'Mean_Vy_improvement',mean(q.Vy_improvement_vs_V13),'Mean_r_improvement',mean(q.r_improvement_vs_V13), ...
        'HighCase_Vy_marginal',mean(h.Vy_marginal_NSEE_mean),'HighCase_NEES',mean(h.NEES_mean),'Median_gamma_vy',median(q.gamma_vy),'Median_gamma_r',median(q.gamma_r), ...
        'Mean_NIS',mean(q.NIS_mean),'Mean_eps_Ay_std',mean(q.standardized_Ay_std),'Mean_eps_r_std',mean(q.standardized_r_std),'Median_axis_difference',median(q.principal_axis_difference_deg), ...
        'AllStable',all(q.stable),'Rejected',~isBase&&(any(q.Vy_improvement_vs_V13 < -10)||any(q.r_improvement_vs_V13 < -10)||~all(q.stable)),'Pareto',false,'Selected',false);
end
S=struct2table(vertcat(rows{:}));
end

function [P,selected]=pareto_select(S)
cand=S(~S.Rejected&S.Configuration~="C0",:);n=height(cand);assert(n>0);obj=zeros(n,7);
obj(:,1)=cand.HighCase_Vy_marginal;obj(:,2)=cand.HighCase_NEES;obj(:,3)=abs(log(max(cand.Median_gamma_vy,eps)));obj(:,4)=abs(log(max(cand.Median_gamma_r,eps)));obj(:,5)=-min(cand.Mean_NIS,2);obj(:,6)=abs(log(max(cand.Mean_eps_Ay_std,eps)))+abs(log(max(cand.Mean_eps_r_std,eps)));obj(:,7)=cand.Median_axis_difference;
isP=true(n,1);for i=1:n,for j=1:n,if j~=i&&all(obj(j,:)<=obj(i,:))&&any(obj(j,:)<obj(i,:)),isP(i)=false;break;end,end,end
P=cand(isP,:);S.Pareto(ismember(S.Configuration,P.Configuration))=true;
po=obj(isP,:);[~,ix]=sortrows(po,[1 2 3 4 5 6 7]);selected=P.Configuration(ix(1));
if height(P)>1
    rem=P.Configuration~=selected;R=P(rem,:);ro=po(rem,:);worst=max(-R.Worst_Vy_improvement,-R.Worst_r_improvement);[~,jx]=sortrows([worst ro],[1 2 3 4 5 6 7 8]);selected=[selected;R.Configuration(jx(1))];
end
P.Selected=ismember(P.Configuration,selected);
end

function d=final_decision(T,selected)
b=T(T.Configuration=="C0",:);names=selected(:);rows=cell(numel(names),1);highCases=["V25","A30","F60"];
for i=1:numel(names)
    q=T(T.Configuration==names(i),:);h=q(ismember(q.Case,highCases),:);hb=b(ismember(b.Case,highCases),:);
    rows{i}=struct('Configuration',names(i),'AllStable',all(q.stable),'AnyWorse10',any(q.Vy_improvement_vs_V13<-10|q.r_improvement_vs_V13<-10), ...
        'MeanVyImprovement',mean(q.Vy_improvement_vs_V13),'MeanRImprovement',mean(q.r_improvement_vs_V13),'HighNEESReduction',100*(1-mean(h.NEES_mean)/mean(hb.NEES_mean)), ...
        'HighVyMarginalReduction',100*(1-mean(h.Vy_marginal_NSEE_mean)/mean(hb.Vy_marginal_NSEE_mean)),'MedianGammaVy',median(q.gamma_vy),'MedianGammaR',median(q.gamma_r), ...
        'MedianNIS',median(q.NIS_mean),'MeanEpsAy',mean(q.standardized_Ay_std),'MeanEpsR',mean(q.standardized_r_std),'MedianAxis',median(q.principal_axis_difference_deg), ...
        'MeanAbsRho1',mean(abs([q.standardized_Ay_rho1;q.standardized_r_rho1])));
end
R=struct2table(vertcat(rows{:}));eligible=R.AllStable&~R.AnyWorse10;
if any(eligible),E=R(eligible,:);[~,ix]=sortrows([ -E.HighVyMarginalReduction -E.HighNEESReduction abs(log(max(E.MedianGammaVy,eps))) abs(log(max(E.MedianGammaR,eps))) -min(E.MedianNIS,2) E.MedianAxis],[1 2 3 4 5 6]);chosen=E(ix(1),:);else,chosen=R(1,:);end
baseAxis=median(b.principal_axis_difference_deg);baseGammaVy=median(b.gamma_vy);baseGammaR=median(b.gamma_r);baseNIS=median(b.NIS_mean);baseEpsAy=mean(b.standardized_Ay_std);baseEpsR=mean(b.standardized_r_std);
gVyBetter=abs(log(chosen.MedianGammaVy))<abs(log(baseGammaVy));gRBetter=abs(log(chosen.MedianGammaR))<abs(log(baseGammaR));nisLeftExtreme=chosen.MedianNIS>0.1&&chosen.MedianNIS>2*baseNIS;axisBetter=chosen.MedianAxis<.8*baseAxis;
epsAyBetter=abs(log(chosen.MeanEpsAy))<abs(log(baseEpsAy));epsRBetter=abs(log(chosen.MeanEpsR))<abs(log(baseEpsR));
freeze=chosen.AllStable&&~chosen.AnyWorse10&&chosen.MeanVyImprovement>=-2&&chosen.MeanRImprovement>=-2&&chosen.HighNEESReduction>=30&&chosen.HighVyMarginalReduction>=30&&gVyBetter&&gRBetter&&nisLeftExtreme&&epsAyBetter&&epsRBetter&&axisBetter;
d=struct('candidateSummary',R,'chosenConfiguration',char(chosen.Configuration),'freezeDecision',conditional(freeze,'FREEZE D-EKF V1','DO NOT FREEZE D-EKF V1'), ...
    'freeze',freeze,'gammaVyImproved',gVyBetter,'gammaRImproved',gRBetter,'nisLeftExtreme',nisLeftExtreme,'standardizedAyImproved',epsAyBetter,'standardizedRImproved',epsRBetter,'standardizedScaleImproved',epsAyBetter&&epsRBetter,'axisImproved',axisBetter, ...
    'coloredResidualRemains',chosen.MeanAbsRho1>.2,'baselineMedianAxis',baseAxis,'baselineMedianNIS',baseNIS,'baselineMedianGammaVy',baseGammaVy,'baselineMedianGammaR',baseGammaR,'baselineEpsAy',baseEpsAy,'baselineEpsR',baseEpsR);
end

function f=make_figures(res,screen,S,full,d)
f=struct();common={'Visible','off','Color','w','Position',[80 80 1200 680]};labs=cellstr(S.Configuration);f.screen=bars(common,labs,[S.HighCase_Vy_marginal S.HighCase_NEES],{'Vy marginal','full NEES'},'Calibration high-case consistency',fullfile(res,'vy_dekf_v1_15_01_calibration_high_nees.png'));
cfg=unique(full.Configuration,'stable');cases=unique(full.Case,'stable');
f.rmse=group_plot(common,full,cfg,cases,'Vy_RMSE','Vy RMSE',fullfile(res,'vy_dekf_v1_15_02_vy_rmse.png'));
f.nis=group_plot(common,full,cfg,cases,'NIS_mean','NIS mean',fullfile(res,'vy_dekf_v1_15_03_nis.png'));
f.nees=group_plot(common,full,cfg,cases,'NEES_mean','NEES mean',fullfile(res,'vy_dekf_v1_15_04_nees.png'));
f.gamma=group_pair(common,full,cfg,cases,'gamma_vy','gamma_r','gamma empirical/P',fullfile(res,'vy_dekf_v1_15_05_gamma.png'));
f.epsilon=group_pair(common,full,cfg,cases,'standardized_Ay_std','standardized_r_std','standardized innovation std',fullfile(res,'vy_dekf_v1_15_06_standardized_innovation.png'));
f.axis=group_plot(common,full,cfg,cases,'principal_axis_difference_deg','axis difference [deg]',fullfile(res,'vy_dekf_v1_15_07_axis.png'));
q=full(full.Configuration==string(d.chosenConfiguration),:);fig=figure(common{:});plot(q.standardized_Ay_rho1,'o-');hold on;plot(q.standardized_r_rho1,'s-');grid on;xticks(1:height(q));xticklabels(cellstr(q.Case));legend('Ay rho1','r rho1');ylabel('standardized innovation rho1');f.colored=fullfile(res,'vy_dekf_v1_15_08_colored_residual.png');exportgraphics(fig,f.colored,'Resolution',170);close(fig);
end
function file=group_plot(common,T,cfg,cases,var,yl,file),Y=zeros(numel(cases),numel(cfg));for i=1:numel(cfg),q=T(T.Configuration==cfg(i),:);[~,ix]=ismember(cases,q.Case);Y(:,i)=q.(var)(ix);end;fig=figure(common{:});bar(Y);grid on;xticks(1:numel(cases));xticklabels(cellstr(cases));legend(cellstr(cfg),'Interpreter','none','Location','best');ylabel(yl);exportgraphics(fig,file,'Resolution',170);close(fig);end
function file=group_pair(common,T,cfg,cases,v1,v2,yl,file),Y=zeros(numel(cases),2*numel(cfg));leg=cell(1,2*numel(cfg));for i=1:numel(cfg),q=T(T.Configuration==cfg(i),:);[~,ix]=ismember(cases,q.Case);Y(:,2*i-1)=q.(v1)(ix);Y(:,2*i)=q.(v2)(ix);leg{2*i-1}=[char(cfg(i)) ' A'];leg{2*i}=[char(cfg(i)) ' r'];end;fig=figure(common{:});bar(Y);grid on;xticks(1:numel(cases));xticklabels(cellstr(cases));legend(leg,'Interpreter','none','Location','best');ylabel(yl);exportgraphics(fig,file,'Resolution',170);close(fig);end
function file=bars(common,labs,Y,leg,yl,file),fig=figure(common{:});bar(Y);grid on;xticks(1:numel(labs));xticklabels(labs);xtickangle(25);legend(leg,'Location','best');ylabel(yl);exportgraphics(fig,file,'Resolution',170);close(fig);end

function write_status(file,meta,screen,S,P,F,d,a,figs,csv,mat,screenCsv,summaryCsv)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));A=meta.anchors;
fprintf(fid,'# STAGE VY D-EKF V1.15 STATUS\n\n## Fixed scope and anchors\n\nV1.15 performed the final planned structured diagonal covariance calibration on an isolated V1.15 model copy. Alignment: `%s`.\n\n',a.posteriorAlignment);
fprintf(fid,'|Case|empirical Ay variance|empirical r variance|\n|:--|--:|--:|\n');for i=1:numel(A.varAy),fprintf(fid,'|%s|%.8g|%.8g|\n',A.caseNames(i),A.varAy(i),A.varR(i));end
fprintf(fid,'\n- R_emp = diag([%.9g, %.9g])\n- R_cons = diag([%.9g, %.9g])\n- Wrapper C0/V1.13 120-step equality max: %.3g.\n- Vehicle/log input equality across configurations: calibration %.3g, full %.3g; C0 vs V1.13 archive input/output %.3g / %.3g.\n- Simulations: %d calibration + %d full = %d. Each run has 1601 updates and 1600 scored posterior samples.\n\n',A.R_emp_Ay,A.R_emp_r,A.R_cons_Ay,A.R_cons_r,meta.unit.maxOutputDifference,a.calibrationInputMax,a.fullInputMax,a.baselineArchiveMax,a.baselineOutputMax,a.calibrationSimulationCount,a.fullSimulationCount,a.totalSimulationCount);
fprintf(fid,'## Four-case calibration screen\n\n|Configuration|Qvy/Qr|RAy/Rr|worst Vy/r improve|high Vy marginal|high NEES|median gamma Vy/r|mean NIS|axis|reject|Pareto|selected|\n|:--|:--|:--|:--|--:|--:|:--|--:|--:|:--|:--|:--|\n');
for i=1:height(S),fprintf(fid,'|%s|%.3g / %.3g|%.4g / %.4g|%.4g%% / %.4g%%|%.5g|%.5g|%.4g / %.4g|%.4g|%.4g|%d|%d|%d|\n',S.Configuration(i),S.Q_vy(i),S.Q_r(i),S.R_Ay(i),S.R_r(i),S.Worst_Vy_improvement(i),S.Worst_r_improvement(i),S.HighCase_Vy_marginal(i),S.HighCase_NEES(i),S.Median_gamma_vy(i),S.Median_gamma_r(i),S.Mean_NIS(i),S.Median_axis_difference(i),S.Rejected(i),ismember(S.Configuration(i),P.Configuration),ismember(S.Configuration(i),P.Configuration(P.Selected)));end
fprintf(fid,'\nNo single weighted cost was used. Candidates first passed the >10%% state-error/stability gates, then non-dominated points were identified. The selected pair represents consistency-first and accuracy-robust Pareto boundaries.\n\n');
fprintf(fid,'## Full seven-case validation\n\n|Case|Config|Vy RMSE (improve)|r RMSE (improve)|NIS mean/p95|eps std Ay/r|NEES mean/p95|marg Vy/r|gamma Vy/r|2sigma Vy/r|axis|min eig/max cond|stable|\n|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|--:|:--|:--|\n');
for i=1:height(F),fprintf(fid,'|%s|%s|%.6g (%+.3g%%)|%.6g (%+.3g%%)|%.5g / %.5g|%.4g / %.4g|%.5g / %.5g|%.4g / %.4g|%.4g / %.4g|%.4f / %.4f|%.4g|%.3g / %.4g|%d|\n',F.Case(i),F.Configuration(i),F.Vy_RMSE(i),F.Vy_improvement_vs_V13(i),F.r_RMSE(i),F.r_improvement_vs_V13(i),F.NIS_mean(i),F.NIS_p95(i),F.standardized_Ay_std(i),F.standardized_r_std(i),F.NEES_mean(i),F.NEES_p95(i),F.Vy_marginal_NSEE_mean(i),F.r_marginal_NSEE_mean(i),F.gamma_vy(i),F.gamma_r(i),F.Vy_2sigma_coverage(i),F.r_2sigma_coverage(i),F.principal_axis_difference_deg(i),F.min_P_eigenvalue(i),F.max_P_condition(i),F.stable(i));end
R=d.candidateSummary;ch=R(R.Configuration==string(d.chosenConfiguration),:);
fprintf(fid,'\n## Final freeze decision\n\nChosen robust Pareto configuration: **%s**. Decision: **%s**.\n\n',d.chosenConfiguration,d.freezeDecision);
fprintf(fid,'1. Stable in all seven cases: **%s**.\n',yesno(ch.AllStable));
fprintf(fid,'2. Mean Vy RMSE improvement vs V1.13: **%+.6g%%**; no case worse than 10%%: **%s**.\n',ch.MeanVyImprovement,yesno(~ch.AnyWorse10));
fprintf(fid,'3. Mean true-r RMSE improvement vs V1.13: **%+.6g%%**.\n',ch.MeanRImprovement);
fprintf(fid,'4. V25/A30/F60 full-NEES reduction: **%.6g%%**; Vy-marginal reduction: **%.6g%%**.\n',ch.HighNEESReduction,ch.HighVyMarginalReduction);
fprintf(fid,'5. Median gamma Vy: %.6g (baseline %.6g), improved: **%s**.\n',ch.MedianGammaVy,d.baselineMedianGammaVy,yesno(d.gammaVyImproved));
fprintf(fid,'6. Median gamma r: %.6g (baseline %.6g), improved: **%s**.\n',ch.MedianGammaR,d.baselineMedianGammaR,yesno(d.gammaRImproved));
fprintf(fid,'7. Median NIS: %.6g (baseline %.6g), left extreme 0.01--0.1 scale: **%s**.\n',ch.MedianNIS,d.baselineMedianNIS,yesno(d.nisLeftExtreme));
fprintf(fid,'8. Standardized innovation std moved toward one: Ay **%s** (%.6g -> %.6g), r **%s** (%.6g -> %.6g). Both channels improved: **%s**.\n',yesno(d.standardizedAyImproved),d.baselineEpsAy,ch.MeanEpsAy,yesno(d.standardizedRImproved),d.baselineEpsR,ch.MeanEpsR,yesno(d.standardizedScaleImproved));
fprintf(fid,'9. Median principal-axis difference: %.6g deg (baseline %.6g deg), clearly improved: **%s**.\n',ch.MedianAxis,d.baselineMedianAxis,yesno(d.axisImproved));
fprintf(fid,'10. Colored standardized residual remains: **%s**; mean |rho1| %.6g. This is a remaining reliability/robustness-layer limitation, not permission for another D-EKF tuning grid.\n',yesno(d.coloredResidualRemains),ch.MeanAbsRho1);
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n',csv,mat,screenCsv,summaryCsv);q=struct2cell(figs);for i=1:numel(q),fprintf(fid,'- `%s`\n',q{i});end
fprintf(fid,'\n**V1.13 AXLE GAINS REMAIN FROZEN.**\n\n**ONLY DIAGONAL Q/R COVARIANCE WAS CALIBRATED.**\n\n**NO COLORED-NOISE MODEL WAS ADDED.**\n\n**NO OTHER D-EKF MODEL PARAMETER WAS CHANGED.**\n');
end

function M=matseries(x),n=size(x,1);M=zeros(2,2,n);for i=1:n,M(:,:,i)=reshape(x(i,:),2,2);end;end
function s=err(x),s=struct('RMSE',rmsv(x),'MAE',mean(abs(x)),'Bias',mean(x),'Max',max(abs(x)));end
function s=dist(x),s=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95),'Max',max(x),'Fraction',mean(x>5.991464547));end
function a=acf(x,L),x=x-mean(x);z=x'*x;a=zeros(L,1);for k=1:L,a(k)=x(1:end-k)'*x(1+k:end)/max(z,eps);end;end
function e=ellipse(C,P),[Vc,Dc]=eig(.5*(C+C'));[~,i]=max(diag(Dc));[Vp,Dp]=eig(.5*(P+P'));[~,j]=max(diag(Dp));ac=atan2d(Vc(2,i),Vc(1,i));ap=atan2d(Vp(2,j),Vp(1,j));e=struct('eCe',sort(eig(C),'descend')','eP',sort(eig(P),'descend')','diff',abs(mod(ac-ap+90,180)-90));end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function s=yesno(v),if v,s='YES';else,s='NO';end;end
function s=conditional(v,a,b),if v,s=a;else,s=b;end;end
