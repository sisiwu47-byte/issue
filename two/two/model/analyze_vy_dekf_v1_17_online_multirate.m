function mainTable=analyze_vy_dekf_v1_17_online_multirate(runArchive)
%ANALYZE_VY_DEKF_V1_17_ONLINE_MULTIRATE Final D-EKF V1 validation.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');docs=fullfile(root,'docs');
if nargin<1||isempty(runArchive),runArchive=fullfile(res,'vy_dekf_v1_17_online_multirate_runs.mat');end
V=load(runArchive,'runs','metadata');B=load(fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat'),'runs','metadata');
assert(numel(V.runs)==21&&V.metadata.completedRuns==21&&numel(B.runs)==7);
assert(isequal(V.metadata.fixedQ,diag([1e-4,1e-4]))&&isequal(V.metadata.fixedR,diag([1e-2,3.365172961808e-4])));
rows=cell(21,1);details=cell(21,1);inputMax=0;a100Max=0;
for i=1:21
    run=V.runs(i);bi=find(strcmp({B.runs.Case},run.Case),1);base=B.runs(bi);
    d=input_difference(run,base);inputMax=max(inputMax,d);assert(d<=1e-10,'Input/truth mismatch %s %s: %.3g',run.Case,run.Mode,d);
    eq=NaN;if strcmp(run.Mode,'A100'),eq=a100_difference(run,base);a100Max=max(a100Max,eq);assert(eq<=1e-10,'A100 online mismatch %s: %.3g',run.Case,eq);end
    met=metrics(run);rows{i}=make_row(run,met,d,eq);details{i}=struct('Case',run.Case,'Mode',run.Mode,'metrics',met);
end
mainTable=struct2table(vertcat(rows{:}));details=vertcat(details{:});mainTable=add_comparisons(mainTable);
offlineMax=offline_equality(mainTable,fullfile(res,'vy_dekf_v1_16_update_rate_ablation.csv'));
highDynamicTable=high_dynamic(details);decision=decide(mainTable);figures=make_figures(res,mainTable,highDynamicTable);
csvFile=fullfile(res,'vy_dekf_v1_17_online_multirate.csv');writetable(mainTable,csvFile);
highCsv=fullfile(res,'vy_dekf_v1_17_high_dynamic.csv');writetable(highDynamicTable,highCsv);
audit=struct('modelFile',V.metadata.modelFile,'sourceModel',V.metadata.sourceModel,'cases',7,'modes',3,'simulations',21, ...
    'updatesPerSimulation',1601,'scoredPerSimulation',1600,'Ts',.01,'predictionHz',100,'yawUpdateHz',100, ...
    'fixedQ',V.metadata.fixedQ,'fixedR',V.metadata.fixedR,'k_f',V.metadata.k_f,'k_r',V.metadata.k_r, ...
    'posteriorAlignment','x_hat(i), P_new(:,:,i), truth(i+1)','maxInputTruthDifference',inputMax, ...
    'maxA100OnlineDifference',a100Max,'maxV116OfflineMetricDifference',offlineMax,'unitTest',V.metadata.testReport, ...
    'oldModelsModified',false,'onlyAyAssimilationRateChanged',true);
matFile=fullfile(res,'vy_dekf_v1_17_online_multirate.mat');save(matFile,'audit','mainTable','highDynamicTable','details','decision','figures','-v7.3');
statusFile=fullfile(docs,'STAGE_VY_DEKF_V1_17_STATUS.md');write_status(statusFile,mainTable,highDynamicTable,decision,audit,figures,csvFile,matFile,highCsv);
req=[{V.metadata.modelFile};{csvFile};{matFile};{highCsv};{statusFile};struct2cell(figures)];for i=1:numel(req),p=char(req{i});assert(isfile(p));q=dir(p);assert(q(1).bytes>0);end
assert(all(mainTable.stable)&&a100Max<=1e-10&&inputMax<=1e-10&&offlineMax<=1e-8);
fprintf('V1_17_COMPLETE|selected=%s|A20pass=%d|A50pass=%d|freeze=1|offlineMax=%.3g\n',decision.selectedMode,decision.A20.pass,decision.A50.pass,offlineMax);
end

function d=input_difference(a,b)
d=max(abs([a.t-b.t a.u-b.u a.zRaw-b.zRaw a.vyTrue-b.vyTrue a.rTrue-b.rTrue a.ayTrue-b.ayTrue]),[],'all');
end
function d=a100_difference(a,b)
d=max([max(abs(a.y-b.y),[],'all'),max(abs(a.pDiag-b.pDiag),[],'all'),max(abs(a.diagnostics(:,1:55)-b.diagnostics),[],'all')]);
end
function d=offline_equality(T,file)
O=readtable(file,'TextType','string');O=O(ismember(O.Configuration,["A100","A50","A20"]),:);d=0;
fields={'Vy_RMSE','r_RMSE','NEES_mean','Vy_marginal_NSEE_mean','r_marginal_NSEE_mean','gamma_vy','gamma_r','Vy_2sigma_coverage','r_2sigma_coverage','P11_mean','P22_mean'};
for i=1:height(T),j=find(O.Case==T.Case(i)&O.Configuration==T.Mode(i),1);assert(~isempty(j));for k=1:numel(fields),f=fields{k};d=max(d,abs(T.(f)(i)-O.(f)(j)));end;end
end

function m=metrics(run)
D=run.diagnostics(2:end,:);x=run.y(2:end,1:2);truth=[run.vyTrue(2:end) run.rTrue(2:end)];e=x-truth;
P=matseries(D(:,42:45));Pprior=matseries(D(:,30:33));useAy=D(:,56)>.5;dim=D(:,59);assert(all(dim(useAy)==2)&all(dim(~useAy)==1));
s=state_summary(e,P);m=struct();m.error=e;m.P=P;m.dynamic=dynamic(run);m.Vy=errstats(e(:,1));m.r=errstats(e(:,2));
m.NEES=s.NEES;m.VyMarginal=s.marginal(1);m.rMarginal=s.marginal(2);m.gamma=s.gamma;m.coverageVy=s.coverage(:,1)';m.coverageR=s.coverage(:,2)';
m.NIS2D=dist(D(useAy,60));m.NIS1D=dist(D(~useAy,61));m.loggedAyUpdates=sum(useAy);m.loggedROnly=sum(~useAy);
stride=100/run.ModeCode;m.expectedAyUpdates=floor(1600/stride)+1;m.expectedROnly=1601-m.expectedAyUpdates;
m.innovationAy=innovation_stats(D(useAy,10),D(useAy,34));m.innovationR=innovation_stats(D(:,11),D(:,37));
p11=squeeze(P(1,1,:));p22=squeeze(P(2,2,:));pp11=squeeze(Pprior(1,1,:));pp22=squeeze(Pprior(2,2,:));
m.cVy=p11./pp11;m.cR=p22./pp22;m.P11Mean=mean(p11);m.P22Mean=mean(p22);m.contractionVy=dist(m.cVy);m.contractionR=dist(m.cR);
m.minEigen=s.minEigen;m.maxCondition=s.maxCondition;m.stable=s.stable&&all(isfinite([D(:);x(:)]));
end
function d=dynamic(run)
d=struct('absAy',abs(run.ayTrue(2:end)),'absSteerRate',abs(gradient(mean(run.u(2:end,2:3),2),.01)),'absDr',abs(gradient(run.rTrue(2:end),.01)));
end
function s=state_summary(e,P)
n=size(e,1);ne=zeros(n,1);ma=zeros(n,2);sig=zeros(n,2);mine=inf;maxc=0;
for i=1:n,Q=.5*(P(:,:,i)+P(:,:,i)');ee=e(i,:)';ne(i)=ee'*(Q\ee);ma(i,:)=[ee(1)^2/Q(1,1) ee(2)^2/Q(2,2)];sig(i,:)=sqrt(diag(Q))';mine=min(mine,min(eig(Q)));maxc=max(maxc,cond(Q));end
s.NEES=dist_nees(ne);s.marginal=mean(ma,1);s.gamma=[var(e(:,1),0)/mean(squeeze(P(1,1,:))) var(e(:,2),0)/mean(squeeze(P(2,2,:)))];
s.coverage=zeros(3,2);for k=1:3,s.coverage(k,:)=[mean(abs(e(:,1))<=k*sig(:,1)) mean(abs(e(:,2))<=k*sig(:,2))];end
s.minEigen=mine;s.maxCondition=maxc;s.stable=all(isfinite([e(:);P(:);ne]))&&mine>=-1e-12&&maxc<1e12;
end
function s=innovation_stats(v,S)
q=v./sqrt(max(S,eps));a=acf(q,10);s=struct('Mean',mean(v),'Std',std(v,0),'RMS',rmsv(v),'StandardizedStd',std(q,0),'Rho1',a(1),'Rho5',a(5),'Rho10',a(10));
end
function row=make_row(run,m,inputDiff,a100Diff)
row=struct('Case',string(run.Case),'Mode',string(run.Mode),'ModeCode',run.ModeCode,'EKF_prediction_updates',1601,'yaw_rate_updates',1601, ...
    'Ay_assimilation_updates',m.expectedAyUpdates,'Ay_logged_scored_updates',m.loggedAyUpdates,'r_only_logged_scored_updates',m.loggedROnly, ...
    'Vy_RMSE',m.Vy.RMSE,'Vy_MAE',m.Vy.MAE,'Vy_Bias',m.Vy.Bias,'Vy_Max_error',m.Vy.Max, ...
    'r_RMSE',m.r.RMSE,'r_MAE',m.r.MAE,'r_Bias',m.r.Bias,'r_Max_error',m.r.Max, ...
    'Vy_RMSE_change_vs_A100_percent',NaN,'r_RMSE_change_vs_A100_percent',NaN, ...
    'NEES_mean',m.NEES.Mean,'NEES_median',m.NEES.Median,'NEES_p95',m.NEES.P95,'NEES_fraction_above95',m.NEES.FractionAbove95, ...
    'Vy_marginal_NSEE_mean',m.VyMarginal,'r_marginal_NSEE_mean',m.rMarginal,'gamma_vy',m.gamma(1),'gamma_r',m.gamma(2), ...
    'Vy_1sigma_coverage',m.coverageVy(1),'Vy_2sigma_coverage',m.coverageVy(2),'Vy_3sigma_coverage',m.coverageVy(3), ...
    'r_1sigma_coverage',m.coverageR(1),'r_2sigma_coverage',m.coverageR(2),'r_3sigma_coverage',m.coverageR(3), ...
    'NIS_2D_mean',m.NIS2D.Mean,'NIS_2D_median',m.NIS2D.Median,'NIS_2D_p95',m.NIS2D.P95,'NIS_2D_count',m.NIS2D.Count, ...
    'NIS_r_only_mean',m.NIS1D.Mean,'NIS_r_only_median',m.NIS1D.Median,'NIS_r_only_p95',m.NIS1D.P95,'NIS_r_only_count',m.NIS1D.Count, ...
    'Ay_innovation_RMS',m.innovationAy.RMS,'Ay_standardized_innovation_std',m.innovationAy.StandardizedStd,'Ay_rho1',m.innovationAy.Rho1,'Ay_innovation_rho1',m.innovationAy.Rho1,'Ay_innovation_rho5',m.innovationAy.Rho5,'Ay_innovation_rho10',m.innovationAy.Rho10, ...
    'r_innovation_RMS',m.innovationR.RMS,'r_standardized_innovation_std',m.innovationR.StandardizedStd,'r_innovation_rho1',m.innovationR.Rho1,'r_innovation_rho5',m.innovationR.Rho5,'r_innovation_rho10',m.innovationR.Rho10, ...
    'P11_post_over_prior',m.contractionVy.Mean,'P11_prior_to_post_ratio_mean',m.contractionVy.Mean,'P11_prior_to_post_ratio_median',m.contractionVy.Median,'P22_prior_to_post_ratio_mean',m.contractionR.Mean, ...
    'P11_mean',m.P11Mean,'P22_mean',m.P22Mean,'P_min_eigenvalue',m.minEigen,'P_max_condition',m.maxCondition, ...
    'InputTruthMaxDifference',inputDiff,'A100OnlineMaxDifference',a100Diff,'stable',m.stable);
end
function T=add_comparisons(T)
cs=unique(T.Case,'stable');for i=1:numel(cs),b=T(T.Case==cs(i)&T.Mode=="A100",:);ix=find(T.Case==cs(i));for j=ix',T.Vy_RMSE_change_vs_A100_percent(j)=100*(T.Vy_RMSE(j)/b.Vy_RMSE-1);T.r_RMSE_change_vs_A100_percent(j)=100*(T.r_RMSE(j)/b.r_RMSE-1);end;end
end
function T=high_dynamic(details)
names=["absAy","absSteerRate","absDr"];modes=["A100","A50","A20"];rows=cell(9,1);q=0;
for vi=1:3
    allx=[];for i=1:numel(details),if strcmp(details(i).Mode,'A100'),allx=[allx;details(i).metrics.dynamic.(names(vi))];end;end;cut=pct(allx,75);
    for mi=1:3
        ee=[];PP=[];for i=1:numel(details),if strcmp(details(i).Mode,modes(mi)),mask=details(i).metrics.dynamic.(names(vi))>=cut;ee=[ee;details(i).metrics.error(mask,:)];PP=cat(3,PP,details(i).metrics.P(:,:,mask));end;end
        s=state_summary(ee,PP);q=q+1;rows{q}=struct('Subset',names(vi)+"_Q4",'Mode',modes(mi),'Threshold',cut,'N',size(ee,1),'Vy_RMSE',rmsv(ee(:,1)),'NEES_mean',s.NEES.Mean,'Vy_marginal_NSEE',s.marginal(1),'gamma_vy',s.gamma(1),'Vy_2sigma_coverage',s.coverage(2,1));
    end
end
T=struct2table(vertcat(rows{:}));
end

function c=decide(T)
c=struct();c.A100=check_mode(T,"A100");c.A20=check_mode(T,"A20");c.A50=check_mode(T,"A50");
if c.A20.pass,c.selectedMode="A20";c.selected=c.A20;elseif c.A50.pass,c.selectedMode="A50";c.selected=c.A50;else,c.selectedMode="A100";c.selected=check_mode(T,"A100");end
c.freezeDEKFV1=true;c.nextStage="V2 K-KF";
end
function q=check_mode(T,mode)
b=T(T.Mode=="A100",:);v=T(T.Mode==mode,:);[~,ib]=sort(b.Case);[~,iv]=sort(v.Case);b=b(ib,:);v=v(iv,:);
vyChange=v.Vy_RMSE_change_vs_A100_percent;rChange=v.r_RMSE_change_vs_A100_percent;
neesCase=100*(1-v.NEES_mean./b.NEES_mean);margCase=100*(1-v.Vy_marginal_NSEE_mean./b.Vy_marginal_NSEE_mean);
gammaCase=100*(1-v.gamma_vy./b.gamma_vy);coverageCase=v.Vy_2sigma_coverage-b.Vy_2sigma_coverage;
q=struct('mode',mode,'allStable',all(v.stable),'maxVyRMSEChange',max(v.Vy_RMSE_change_vs_A100_percent),'maxRRMSEChange',max(v.r_RMSE_change_vs_A100_percent), ...
    'meanVyRMSEChange',mean(vyChange),'medianVyRMSEChange',median(vyChange),'meanRRMSEChange',mean(rChange),'medianRRMSEChange',median(rChange), ...
    'NEESReduction',100*(1-mean(v.NEES_mean)/mean(b.NEES_mean)),'VyMarginalReduction',100*(1-mean(v.Vy_marginal_NSEE_mean)/mean(b.Vy_marginal_NSEE_mean)), ...
    'gammaVyReduction',100*(1-mean(v.gamma_vy)/mean(b.gamma_vy)),'VyCoverageChange',mean(coverageCase), ...
    'meanNEESCaseReduction',mean(neesCase),'medianNEESCaseReduction',median(neesCase), ...
    'meanVyMarginalCaseReduction',mean(margCase),'medianVyMarginalCaseReduction',median(margCase), ...
    'meanGammaVyCaseReduction',mean(gammaCase),'medianGammaVyCaseReduction',median(gammaCase), ...
    'medianVyCoverageChange',median(coverageCase));
specialNames=["V25","A30","F60"];q.highDynamicNEESReductions=zeros(1,3);for si=1:3,ii=find(v.Case==specialNames(si),1);q.highDynamicNEESReductions(si)=100*(1-v.NEES_mean(ii)/b.NEES_mean(ii));end
if mode=="A100",q.pass=true;else,q.pass=q.allStable&&q.maxVyRMSEChange<=5&&q.maxRRMSEChange<=5&&q.VyMarginalReduction>=20&&all(q.highDynamicNEESReductions>=20)&&q.VyCoverageChange>=.05;end
end

function figs=make_figures(res,T,H)
figs=struct();cases=unique(T.Case,'stable');modes=unique(T.Mode,'stable');common={'Visible','off','Color','w','Position',[70 70 1180 680]};
figs.rmse=gplot(common,T,cases,modes,'Vy_RMSE','Vy RMSE [m/s]',fullfile(res,'vy_dekf_v1_17_01_vy_rmse.png'));
figs.nees=gplot(common,T,cases,modes,'NEES_mean','full NEES mean',fullfile(res,'vy_dekf_v1_17_02_nees.png'));
figs.marginal=gplot(common,T,cases,modes,'Vy_marginal_NSEE_mean','Vy marginal NSEE',fullfile(res,'vy_dekf_v1_17_03_vy_marginal.png'));
figs.gamma=gplot(common,T,cases,modes,'gamma_vy','gamma Vy',fullfile(res,'vy_dekf_v1_17_04_gamma.png'));
figs.coverage=gplot(common,T,cases,modes,'Vy_2sigma_coverage','Vy 2sigma coverage',fullfile(res,'vy_dekf_v1_17_05_coverage.png'));
figs.contraction=gplot(common,T,cases,modes,'P11_prior_to_post_ratio_mean','mean P11 post/prior',fullfile(res,'vy_dekf_v1_17_06_contraction.png'));
figs.color=gplot(common,T,cases,modes,'Ay_innovation_rho1','assimilated Ay innovation rho1',fullfile(res,'vy_dekf_v1_17_07_ay_rho1.png'));
subs=unique(H.Subset,'stable');figs.high=gplot(common,H,subs,modes,'Vy_marginal_NSEE','high-dynamic Vy marginal NSEE',fullfile(res,'vy_dekf_v1_17_08_high_dynamic.png'),'Subset','Mode');
figs.stability=gplot(common,T,cases,modes,'P_max_condition','max cond(P)',fullfile(res,'vy_dekf_v1_17_09_stability.png'));
end
function file=gplot(common,T,rows,cols,var,yl,file,rowField,colField)
if nargin<8,rowField='Case';colField='Mode';end;Y=zeros(numel(rows),numel(cols));for i=1:numel(cols),q=T(T.(colField)==cols(i),:);[~,ix]=ismember(rows,q.(rowField));Y(:,i)=q.(var)(ix);end
f=figure(common{:});bar(Y);grid on;xticks(1:numel(rows));xticklabels(cellstr(rows));legend(cellstr(cols),'Location','best');ylabel(yl);exportgraphics(f,file,'Resolution',170);close(f);
end

function write_status(file,T,H,c,a,figs,csv,mat,highCsv)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.17 STATUS\n\n## Implementation and validation gates\n\n');
fprintf(fid,'V1.17 changes only the Ay assimilation schedule in an isolated model copy. Prediction and yaw-rate measurement updates remain at 100 Hz. Alignment: `%s`.\n\n',a.posteriorAlignment);
fprintf(fid,'- 120 random A100 single-step tests: max difference %.3g (requirement <=1e-12).\n',max(struct2array(a.unitTest.maxA100Difference)));
fprintf(fid,'- A50/A20 prediction max difference from A100: %.3g.\n',a.unitTest.predictionMaxDifference);
fprintf(fid,'- Seven cases x three modes = 21 simulations; 1601 online calls and 1600 scored posterior samples per simulation.\n');
fprintf(fid,'- Input/IMU/truth max difference: %.3g; A100 online state/P/diagnostic max difference from V1.13: %.3g.\n',a.maxInputTruthDifference,a.maxA100OnlineDifference);
fprintf(fid,'- Online metrics vs V1.16 offline replay max difference: %.3g.\n',a.maxV116OfflineMetricDifference);
fprintf(fid,'- Actual full-call Ay counts are A100/A50/A20 = 1601/801/321. Logged truth-scored counts are 1600/800/320 because the verified Rate Transition alignment discards the initial held row.\n\n');
fprintf(fid,'## Seven-case core results\n\n|Case|Mode|Vy RMSE|Vy change|r RMSE|r change|NEES|Vy NSEE|r NSEE|gamma Vy|gamma r|Vy 2sigma|r 2sigma|P11 post/prior|Ay std innov|Ay rho1|stable|\n|:--|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|:--|\n');
for i=1:height(T),fprintf(fid,'|%s|%s|%.7g|%+.5g%%|%.7g|%+.5g%%|%.6g|%.6g|%.6g|%.6g|%.6g|%.5f|%.5f|%.6g|%.6g|%.6g|%d|\n',T.Case(i),T.Mode(i),T.Vy_RMSE(i),T.Vy_RMSE_change_vs_A100_percent(i),T.r_RMSE(i),T.r_RMSE_change_vs_A100_percent(i),T.NEES_mean(i),T.Vy_marginal_NSEE_mean(i),T.r_marginal_NSEE_mean(i),T.gamma_vy(i),T.gamma_r(i),T.Vy_2sigma_coverage(i),T.r_2sigma_coverage(i),T.P11_post_over_prior(i),T.Ay_standardized_innovation_std(i),T.Ay_rho1(i),T.stable(i));end
fprintf(fid,'\nThe CSV also contains MAE, bias, maximum error, 1/3-sigma coverage, covariance stability, and dimension-separated NIS fields.\n\n');
fprintf(fid,'\nGaussian coverage references: 68.27%% / 95.45%% / 99.73%%; these are references, not hard gates.\n\n');
fprintf(fid,'## Dimension-correct NIS and assimilated innovation color\n\n2-D Ay+r NIS reference mean is about 2; 1-D r-only NIS reference mean is about 1. They are reported separately.\n\n|Case|Mode|NIS 2D mean/count|NIS r-only mean/count|Ay innov RMS/std-epsilon|Ay rho1/5/10|r innov RMS|\n|:--|:--|:--|:--|:--|:--|--:|\n');
for i=1:height(T),fprintf(fid,'|%s|%s|%.5g / %d|%.5g / %d|%.6g / %.5g|%.4g / %.4g / %.4g|%.6g|\n',T.Case(i),T.Mode(i),T.NIS_2D_mean(i),T.NIS_2D_count(i),T.NIS_r_only_mean(i),T.NIS_r_only_count(i),T.Ay_innovation_RMS(i),T.Ay_standardized_innovation_std(i),T.Ay_innovation_rho1(i),T.Ay_innovation_rho5(i),T.Ay_innovation_rho10(i),T.r_innovation_RMS(i));end
fprintf(fid,'\n## Combined high-dynamic top quartiles\n\n|Subset|Mode|N|Vy RMSE|full NEES|Vy marginal|gamma Vy|Vy 2sigma|\n|:--|:--|--:|--:|--:|--:|--:|--:|\n');for i=1:height(H),fprintf(fid,'|%s|%s|%d|%.7g|%.6g|%.6g|%.6g|%.5f|\n',H.Subset(i),H.Mode(i),H.N(i),H.Vy_RMSE(i),H.NEES_mean(i),H.Vy_marginal_NSEE(i),H.gamma_vy(i),H.Vy_2sigma_coverage(i));end
fprintf(fid,'\n## V25 / A30 / F60 focus\n\n|Case|Mode|Vy RMSE change|r RMSE change|full NEES|Vy marginal|gamma Vy|Vy 2sigma|\n|:--|:--|--:|--:|--:|--:|--:|--:|\n');sp=T(ismember(T.Case,["V25","A30","F60"]),:);for i=1:height(sp),fprintf(fid,'|%s|%s|%+.5g%%|%+.5g%%|%.6g|%.6g|%.6g|%.5f|\n',sp.Case(i),sp.Mode(i),sp.Vy_RMSE_change_vs_A100_percent(i),sp.r_RMSE_change_vs_A100_percent(i),sp.NEES_mean(i),sp.Vy_marginal_NSEE_mean(i),sp.gamma_vy(i),sp.Vy_2sigma_coverage(i));end
fprintf(fid,'\n## Seven-case mean / median changes relative to A100\n\n|Mode|Vy RMSE mean/median|r RMSE mean/median|full NEES reduction mean/median|Vy marginal reduction mean/median|gamma Vy reduction mean/median|Vy 2sigma increase mean/median|\n|:--|:--|:--|:--|:--|:--|:--|\n');for name={'A100','A50','A20'},q0=c.(name{1});fprintf(fid,'|%s|%+.5g%% / %+.5g%%|%+.5g%% / %+.5g%%|%.5g%% / %.5g%%|%.5g%% / %.5g%%|%.5g%% / %.5g%%|%+.5f / %+.5f|\n',name{1},q0.meanVyRMSEChange,q0.medianVyRMSEChange,q0.meanRRMSEChange,q0.medianRRMSEChange,q0.meanNEESCaseReduction,q0.medianNEESCaseReduction,q0.meanVyMarginalCaseReduction,q0.medianVyMarginalCaseReduction,q0.meanGammaVyCaseReduction,q0.medianGammaVyCaseReduction,q0.VyCoverageChange,q0.medianVyCoverageChange);end
fprintf(fid,'\n## Predeclared decision rule\n\n|Mode|Pass|Max Vy/r RMSE change|Mean Vy/r RMSE change|NEES reduction|Vy marginal reduction|gamma Vy reduction|Vy 2sigma change|V25/A30/F60 NEES reductions|\n|:--|:--|:--|:--|--:|--:|--:|--:|:--|\n');
for name={'A20','A50'},q=c.(name{1});fprintf(fid,'|%s|%s|%+.4g%% / %+.4g%%|%+.4g%% / %+.4g%%|%.5g%%|%.5g%%|%.5g%%|%+.5f|%.4g%% / %.4g%% / %.4g%%|\n',name{1},yesno(q.pass),q.maxVyRMSEChange,q.maxRRMSEChange,q.meanVyRMSEChange,q.meanRRMSEChange,q.NEESReduction,q.VyMarginalReduction,q.gammaVyReduction,q.VyCoverageChange,q.highDynamicNEESReductions);end
q=c.selected;fprintf(fid,'\n## Final answers\n\n');
fprintf(fid,'1. A20 reproduces the V1.16 offline trend: **%s**; online/offline aggregate-metric max difference %.3g (descriptive replay tolerance 1e-8; the mandatory A100 online equivalence gate remains 1e-10).\n',yesno(a.maxV116OfflineMetricDifference<=1e-8),a.maxV116OfflineMetricDifference);
fprintf(fid,'2. A50 decision-rule pass: **%s**; its detailed tradeoffs are in the decision table.\n',yesno(c.A50.pass));
fprintf(fid,'3. Selected mode under the predeclared rule: **%s**.\n',c.selectedMode);
fprintf(fid,'4. Selected-mode mean/max Vy RMSE change relative to A100: %+.6g%% / %+.6g%%.\n',q.meanVyRMSEChange,q.maxVyRMSEChange);
fprintf(fid,'5. Selected-mode mean/max true-r RMSE change: %+.6g%% / %+.6g%%.\n',q.meanRRMSEChange,q.maxRRMSEChange);
fprintf(fid,'6. Aggregate full NEES reduction: %.6g%%.\n',q.NEESReduction);
fprintf(fid,'7. Aggregate Vy marginal NSEE reduction: %.6g%%.\n',q.VyMarginalReduction);
fprintf(fid,'8. Aggregate gamma Vy reduction: %.6g%%.\n',q.gammaVyReduction);
fprintf(fid,'9. Mean Vy 2sigma coverage change: %+.6g (absolute fraction).\n',q.VyCoverageChange);
fprintf(fid,'10. V25/A30/F60 retain visible high-dynamic inconsistency after improvement; their full-NEES reductions are %.5g%% / %.5g%% / %.5g%%. This is a frozen known limitation.\n',q.highDynamicNEESReductions);
fprintf(fid,'11. Remaining prior inconsistency and colored residual are recorded as D-EKF V1 known limitations for later reliability/fusion handling; no further D-EKF model/covariance tuning is authorized.\n');
fprintf(fid,'12. **FREEZE D-EKF V1 — FINAL Ay ASSIMILATION MODE: %s.** Next development stage: **V2 K-KF**; V1.18 must not be created.\n',c.selectedMode);
fprintf(fid,'\n**SELECTED MODE = %s**\n\n**FREEZE D-EKF V1**\n\nRemaining known limitations:\n\n- high-dynamic prior inconsistency;\n- colored Ay innovation;\n- simplified tire transient/load behavior.\n\nThese limitations do not authorize V1.18.\n',c.selectedMode);
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n',a.modelFile,csv,mat,highCsv);p=struct2cell(figs);for i=1:numel(p),fprintf(fid,'- `%s`\n',p{i});end
fprintf(fid,'\n**V1.13 AXLE GAINS REMAIN FROZEN.**\n\n**V1.13 Q/R REMAIN FROZEN.**\n\n**ONLY Ay MEASUREMENT ASSIMILATION RATE WAS CHANGED.**\n\n**D-EKF PREDICTION AND YAW-RATE UPDATE REMAIN AT 100 Hz.**\n\n**V1.17 IS THE FINAL D-EKF V1 DEVELOPMENT STAGE.**\n');
end

function M=matseries(x),n=size(x,1);M=zeros(2,2,n);for i=1:n,M(:,:,i)=reshape(x(i,:),2,2);end;end
function s=errstats(e),s=struct('RMSE',rmsv(e),'MAE',mean(abs(e)),'Bias',mean(e),'Max',max(abs(e)));end
function s=dist(x),if isempty(x),s=struct('Mean',NaN,'Median',NaN,'P95',NaN,'Count',0);else,s=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95),'Count',numel(x));end;end
function s=dist_nees(x),s=dist(x);s.FractionAbove95=mean(x>5.991464547);end
function a=acf(x,L),x=x(:)-mean(x);z=x'*x;a=zeros(L,1);for i=1:L,if numel(x)>i,a(i)=x(1:end-i)'*x(1+i:end)/max(z,eps);end;end;end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function s=yesno(v),if v,s='YES';else,s='NO';end,end
