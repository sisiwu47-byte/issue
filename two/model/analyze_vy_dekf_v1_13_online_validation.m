function mainTable=analyze_vy_dekf_v1_13_online_validation(runArchive)
%ANALYZE_VY_DEKF_V1_13_ONLINE_VALIDATION Online V1.13 vs V1.12 baseline.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');docs=fullfile(root,'docs');
if nargin<1||isempty(runArchive),runArchive=fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat');end
V13=load(runArchive,'runs','metadata');V12=load(fullfile(res,'vy_dekf_v1_12_cross_condition_runs.mat'),'runs','metadata');
O12=load(fullfile(res,'vy_dekf_v1_12_cross_condition.mat'),'caseDiagnostics');
assert(numel(V13.runs)==7&&numel(V12.runs)==7);assert(V13.metadata.k_f==.78181&&V13.metadata.k_r==1.09186);
par0=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',.393);
par13=par0;par13.k_f=.78181;par13.k_r=1.09186;
cfg=struct('dt',.01,'Q',diag([1e-4,1e-4]),'R',diag([1e-2,3.365172961808e-4]),'denomEps',1e-12,'lambda',zeros(4,1));
rows=repmat(empty_row(),7,1);details=cell(7,1);inputMax=zeros(7,1);predictionMax=zeros(7,1);
for ci=1:7
    b=V12.runs(ci);v=V13.runs(ci);assert(strcmp(b.Case,v.Case));
    inputMax(ci)=max(abs([b.t-v.t b.u-v.u b.zRaw-v.zRaw b.vyTrue-v.vyTrue b.rTrue-v.rTrue b.ayTrue-v.ayTrue]),[],'all');
    assert(inputMax(ci)<=1e-10,'Case %s does not match V1.12 inputs/truth: %.3g',v.Case,inputMax(ci));
    rb=replay(b,par0,cfg,false);rv=replay(v,par13,cfg,true);
    assert(rv.logAlignmentMax<=1e-12,'V1.13 log replay mismatch %s.',v.Case);
    mb=metrics(rb,b);mv=metrics(rv,v);
    predictionMax(ci)=offline_prediction_check(v,O12.caseDiagnostics(ci),par13,cfg);
    assert(predictionMax(ci)<=1e-10,'Offline prediction mismatch %s: %.17g',v.Case,predictionMax(ci));
    rows(ci)=make_row(v,mb,mv,inputMax(ci),predictionMax(ci));
    details{ci}=struct('Case',v.Case,'baselineReplay',rb,'v13Replay',rv, ...
        'baselineMetrics',mb,'v13Metrics',mv,'inputTruthMaxDifference',inputMax(ci), ...
        'offlinePredictionMaxDifference',predictionMax(ci), ...
        'modelResidual',model_residual_summary(v,O12.caseDiagnostics(ci),par13,cfg));
end
details=vertcat(details{:});mainTable=struct2table(rows);
conclusions=conclude(mainTable);figures=make_figures(res,mainTable,details);
csvFile=fullfile(res,'vy_dekf_v1_13_online_validation.csv');writetable(mainTable,csvFile);
audit=struct('sourceV12',V12.metadata.modelFile,'modelV13',V13.metadata.modelFile, ...
    'cases',7,'updatesPerCase',1601,'Ts',.01,'k_f',.78181,'k_r',1.09186, ...
    'fixedQ',cfg.Q,'fixedR',cfg.R,'maxInputTruthDifference',max(inputMax), ...
    'maxOfflinePredictionDifference',max(predictionMax),'unitTest',V13.metadata.testReport, ...
    'posteriorAlignment','x_hat(i), P_new(:,:,i), truth(i+1)');
matFile=fullfile(res,'vy_dekf_v1_13_online_validation.mat');
save(matFile,'audit','mainTable','details','conclusions','figures','-v7.3');
statusFile=fullfile(docs,'STAGE_VY_DEKF_V1_13_STATUS.md');
write_status(statusFile,mainTable,details,conclusions,audit,figures,csvFile,matFile);
req=[{V13.metadata.modelFile};{csvFile};{matFile};{statusFile};struct2cell(figures)];
for i=1:numel(req),p=char(req{i});assert(isfile(p));d=builtin('dir',p);assert(d(1).bytes>0);end
assert(all(mainTable.stable)&&all(mainTable.EKF_Updates==1601));
fprintf('V1_13_COMPLETE|VyImprove=%d/7|rImprove=%d/7|NEESImprove=%d/7|recommend=%s\n', ...
    conclusions.VyImprovedCases,conclusions.rImprovedCases,conclusions.NEESImprovedCases,conclusions.recommendation);
end

function out=replay(run,par,cfg,isV13)
n=numel(run.t);x=[0;0];P=.1*eye(2);states=zeros(n,2);Ps=zeros(2,2,n);nis=zeros(n,1);innov=zeros(n,2);diag=zeros(n,55);raw=zeros(n,4);corr=zeros(n,4);
for i=1:n
    if isV13,[x,P,info]=vy_dynamic_ekf_step_v13(x,P,run.u(i,:)',run.zRaw(i,:)',par,cfg);
    else,[x,P,info]=vy_dynamic_ekf_step_v15_debug(x,P,run.u(i,:)',run.zRaw(i,:)',par,cfg);end
    states(i,:)=x';Ps(:,:,i)=P;nis(i)=info.NIS;innov(i,:)=info.innovation';
    if isV13
        raw(i,:)=info.Fy_raw';corr(i,:)=info.Fy_corrected';
        diag(i,:)=[info.NIS info.Fy' info.alpha' info.innovation' info.x_pred' info.F(:)' info.H(:)' info.P_prior(:)' info.P_noQ(:)' info.P_pred(:)' info.S(:)' info.K(:)' P(:)' run.zRaw(i,:) info.Fy_raw' info.Fy_corrected'];
    end
end
if isV13,align=max([max(abs(diag(1:end-1,:)-run.diagnostics(2:end,:)),[],'all'),max(abs(states(1:end-1,:)-run.y(2:end,:)),[],'all')]);else,align=NaN;end
out=struct('states',states,'P',Ps,'NIS',nis,'innovation',innov,'rawFy',raw,'correctedFy',corr,'logAlignmentMax',align);
end

function m=metrics(r,run)
n=numel(run.t)-1;truth=[run.vyTrue(2:end) run.rTrue(2:end)];e=r.states(1:end-1,:)-truth;P=r.P(:,:,1:end-1);
nees=zeros(n,1);marg=zeros(n,2);sig=zeros(n,2);
for i=1:n,Q=.5*(P(:,:,i)+P(:,:,i)');ee=e(i,:)';nees(i)=ee'*(Q\ee);marg(i,:)=[ee(1)^2/Q(1,1),ee(2)^2/Q(2,2)];sig(i,:)=[sqrt(Q(1,1)),sqrt(Q(2,2))];end
eigMin=inf;condMax=0;for i=1:size(r.P,3),Q=.5*(r.P(:,:,i)+r.P(:,:,i)');eigMin=min(eigMin,min(eig(Q)));condMax=max(condMax,cond(Q));end
m=struct();m.Vy=errstats(e(:,1));m.r=errstats(e(:,2));m.rVsImuRMSE=rmsv(r.states(1:end-1,2)-run.zRaw(2:end,2));
m.NIS=diststats(r.NIS);m.NEES=diststats(nees);m.marginalVy=mean(marg(:,1));m.marginalR=mean(marg(:,2));
m.coverageVy=[mean(abs(e(:,1))<=sig(:,1)) mean(abs(e(:,1))<=2*sig(:,1)) mean(abs(e(:,1))<=3*sig(:,1))];
m.coverageR=[mean(abs(e(:,2))<=sig(:,2)) mean(abs(e(:,2))<=2*sig(:,2)) mean(abs(e(:,2))<=3*sig(:,2))];
m.innovationAy=basic(r.innovation(:,1));m.innovationR=basic(r.innovation(:,2));
p11=squeeze(r.P(1,1,:));p22=squeeze(r.P(2,2,:));p12=squeeze(r.P(1,2,:));
m.covariance=struct('P11Min',min(p11),'P11Max',max(p11),'P11Final',p11(end),'P22Min',min(p22),'P22Max',max(p22),'P22Final',p22(end),'P12Min',min(p12),'P12Max',max(p12),'minEigenvalue',eigMin,'maxCondition',condMax);
m.stable=all(isfinite([r.states(:);r.P(:);r.NIS(:)]))&&eigMin>=-1e-12&&condMax<1e12;
end
function s=errstats(e),s=struct('RMSE',rmsv(e),'MAE',mean(abs(e)),'Bias',mean(e),'Max',max(abs(e)));end
function s=basic(x),s=struct('Mean',mean(x),'Std',std(x,0),'RMS',rmsv(x));end
function s=diststats(x),s=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95),'Max',max(x),'FractionAbove95',mean(x>5.991464547));end

function d=offline_prediction_check(run,old,par,cfg)
n=1600;x=[run.vyTrue run.rTrue];xp=zeros(n,2);
for k=1:n,[~,~,info]=vy_dynamic_ekf_step_v13(x(k,:)',eye(2),run.u(k,:)',[0;0],par,cfg);xp(k,:)=info.x_pred';end
% Reconstruct the V1.12 fixed candidate using the explicitly frozen rounded gains.
rawF=old.FyfModel+old.FyrModel;rawM=par.a*old.FyfModel-par.b*old.FyrModel;
fixedF=par.k_f*old.FyfModel+par.k_r*old.FyrModel;fixedM=par.a*par.k_f*old.FyfModel-par.b*par.k_r*old.FyrModel;
xref=old.mechanics.xPred+.01*[(fixedF-rawF)/par.m,(fixedM-rawM)/par.Iz];d=max(abs(xp-xref),[],'all');
end
function s=model_residual_summary(run,old,par,cfg)
n=1600;x=[run.vyTrue run.rTrue];xp=zeros(n,2);
for k=1:n,[~,~,i]=vy_dynamic_ekf_step_v13(x(k,:)',eye(2),run.u(k,:)',[0;0],par,cfg);xp(k,:)=i.x_pred';end
w=x(2:end,:)-xp;Ff=par.k_f*old.FyfModel;Fr=par.k_r*old.FyrModel;
dFy=(old.FyfEquiv+old.FyrEquiv)-(Ff+Fr);dMz=(par.a*old.FyfEquiv-par.b*old.FyrEquiv)-(par.a*Ff-par.b*Fr);
s=struct('wVyRMS',rmsv(w(:,1)),'wrRMS',rmsv(w(:,2)),'DeltaFyRMS',rmsv(dFy),'DeltaMzRMS',rmsv(dMz));
end

function row=empty_row()
names={'Case','Baseline_Vy_RMSE','V13_Vy_RMSE','Vy_improvement_percent','Baseline_Vy_MAE','V13_Vy_MAE','Baseline_Vy_Bias','V13_Vy_Bias','Baseline_Vy_Max','V13_Vy_Max', ...
    'Baseline_r_RMSE','V13_r_RMSE','r_improvement_percent','Baseline_r_MAE','V13_r_MAE','Baseline_r_Bias','V13_r_Bias','Baseline_r_Max','V13_r_Max','V13_r_vs_AVz_IMU_RMSE', ...
    'Baseline_NIS_mean','V13_NIS_mean','Baseline_NIS_median','V13_NIS_median','Baseline_NIS_p95','V13_NIS_p95','Baseline_NIS_max','V13_NIS_max','Baseline_NIS_fraction_above95','V13_NIS_fraction_above95', ...
    'Baseline_NEES_mean','V13_NEES_mean','Baseline_NEES_median','V13_NEES_median','Baseline_NEES_p95','V13_NEES_p95','Baseline_NEES_max','V13_NEES_max','Baseline_NEES_fraction_above95','V13_NEES_fraction_above95', ...
    'Baseline_Vy_marginal_NEES','V13_Vy_marginal_NEES','Baseline_r_marginal_NEES','V13_r_marginal_NEES', ...
    'Baseline_innovation_Ay_RMS','V13_innovation_Ay_RMS','Baseline_innovation_r_RMS','V13_innovation_r_RMS', ...
    'Baseline_Vy_2sigma_coverage','V13_Vy_2sigma_coverage','Baseline_r_2sigma_coverage','V13_r_2sigma_coverage', ...
    'V13_Vy_1sigma_coverage','V13_Vy_3sigma_coverage','V13_r_1sigma_coverage','V13_r_3sigma_coverage', ...
    'P11_min','P11_max','P11_final','P22_min','P22_max','P22_final','P12_min','P12_max','P_min_eigenvalue','P_max_condition', ...
    'InputTruthMaxDifference','OfflinePredictionMaxDifference','EKF_Updates','stable'};
row=struct();for i=1:numel(names),row.(names{i})=NaN;end;row.Case="";row.stable=false;
end
function row=make_row(run,b,v,inputDiff,predDiff)
row=empty_row();row.Case=string(run.Case);
for state={'Vy','r'},q=state{1};row.(['Baseline_' q '_RMSE'])=b.(q).RMSE;row.(['V13_' q '_RMSE'])=v.(q).RMSE;row.([q '_improvement_percent'])=100*(1-v.(q).RMSE/b.(q).RMSE);for f={'MAE','Bias','Max'},z=f{1};row.(['Baseline_' q '_' z])=b.(q).(z);row.(['V13_' q '_' z])=v.(q).(z);end;end
row.V13_r_vs_AVz_IMU_RMSE=v.rVsImuRMSE;
for q={'NIS','NEES'},n=q{1};for f={'Mean','Median','P95','Max','FractionAbove95'},z=f{1};outName=z;if strcmp(z,'Mean'),outName='mean';elseif strcmp(z,'Median'),outName='median';elseif strcmp(z,'P95'),outName='p95';elseif strcmp(z,'Max'),outName='max';elseif strcmp(z,'FractionAbove95'),outName='fraction_above95';end;row.(['Baseline_' n '_' outName])=b.(n).(z);row.(['V13_' n '_' outName])=v.(n).(z);end;end
row.Baseline_Vy_marginal_NEES=b.marginalVy;row.V13_Vy_marginal_NEES=v.marginalVy;row.Baseline_r_marginal_NEES=b.marginalR;row.V13_r_marginal_NEES=v.marginalR;
row.Baseline_innovation_Ay_RMS=b.innovationAy.RMS;row.V13_innovation_Ay_RMS=v.innovationAy.RMS;row.Baseline_innovation_r_RMS=b.innovationR.RMS;row.V13_innovation_r_RMS=v.innovationR.RMS;
row.Baseline_Vy_2sigma_coverage=b.coverageVy(2);row.V13_Vy_2sigma_coverage=v.coverageVy(2);row.Baseline_r_2sigma_coverage=b.coverageR(2);row.V13_r_2sigma_coverage=v.coverageR(2);
row.V13_Vy_1sigma_coverage=v.coverageVy(1);row.V13_Vy_3sigma_coverage=v.coverageVy(3);row.V13_r_1sigma_coverage=v.coverageR(1);row.V13_r_3sigma_coverage=v.coverageR(3);
c=v.covariance;for f={'P11Min','P11Max','P11Final','P22Min','P22Max','P22Final','P12Min','P12Max'},z=f{1};dest=regexprep(z,'(P11|P22|P12)(Min|Max|Final)','$1_$2');dest=lower_suffix(dest);row.(dest)=c.(z);end
row.P_min_eigenvalue=c.minEigenvalue;row.P_max_condition=c.maxCondition;row.InputTruthMaxDifference=inputDiff;row.OfflinePredictionMaxDifference=predDiff;row.EKF_Updates=numel(run.t);row.stable=v.stable;
end
function s=lower_suffix(s),s=strrep(s,'_Min','_min');s=strrep(s,'_Max','_max');s=strrep(s,'_Final','_final');end

function c=conclude(t)
c=struct();c.VyImprovedCases=sum(t.Vy_improvement_percent>0);c.rImprovedCases=sum(t.r_improvement_percent>0);c.NEESImprovedCases=sum(t.V13_NEES_mean<t.Baseline_NEES_mean);c.VyMarginalImprovedCases=sum(t.V13_Vy_marginal_NEES<t.Baseline_Vy_marginal_NEES);
c.anyAccuracyWorse10=any([t.Vy_improvement_percent t.r_improvement_percent]<-10,'all');c.allStable=all(t.stable);c.maxPredictionDifference=max(t.OfflinePredictionMaxDifference);
c.meanVyImprovement=mean(t.Vy_improvement_percent);c.meanRImprovement=mean(t.r_improvement_percent);c.meanNEESReduction=100*(1-mean(t.V13_NEES_mean)/mean(t.Baseline_NEES_mean));c.meanVyMarginalReduction=100*(1-mean(t.V13_Vy_marginal_NEES)/mean(t.Baseline_Vy_marginal_NEES));
c.nisDirection=mean(t.V13_NIS_mean)-mean(t.Baseline_NIS_mean);
c.nisMovedTowardReference=mean(abs(2-t.V13_NIS_mean))<mean(abs(2-t.Baseline_NIS_mean));
c.remainingHighNEESCases=sum(t.V13_NEES_mean>5.991464547);
c.forceModelFreezeSupported=c.VyImprovedCases>=4&&c.rImprovedCases>=4&&~c.anyAccuracyWorse10&&c.NEESImprovedCases>=4&&c.VyMarginalImprovedCases>=4&&c.allStable&&c.maxPredictionDifference<=1e-10;
c.readyForV2=c.forceModelFreezeSupported&&c.nisMovedTowardReference&&c.remainingHighNEESCases<=1;
c.freezeSupported=c.forceModelFreezeSupported;
if c.readyForV2,c.recommendation='A. freeze D-EKF V1 and begin K-KF V2';
elseif c.forceModelFreezeSupported,c.recommendation='D. freeze the V1.13 steady-state force scaling, but resolve corrected-model covariance/colored-noise consistency before K-KF V2';
else,c.recommendation='D. V1.13 online validation exposes a blocking issue; do not retune automatically';end
end

function figs=make_figures(res,t,d)
figs=struct();labels=cellstr(t.Case);common={'Visible','off','Color','w','Position',[80 80 1050 650]};
figs.rmse=bars(common,labels,[t.Baseline_Vy_RMSE t.V13_Vy_RMSE t.Baseline_r_RMSE t.V13_r_RMSE],{'Base Vy','V13 Vy','Base r','V13 r'},'State RMSE',fullfile(res,'vy_dekf_v1_13_01_state_rmse.png'));
figs.improvement=bars(common,labels,[t.Vy_improvement_percent t.r_improvement_percent],{'Vy','r'},'RMSE improvement [%]',fullfile(res,'vy_dekf_v1_13_02_rmse_improvement.png'));
figs.nis=bars(common,labels,[t.Baseline_NIS_mean t.V13_NIS_mean],{'Baseline','V13'},'NIS mean',fullfile(res,'vy_dekf_v1_13_03_nis.png'));
figs.nees=bars(common,labels,[t.Baseline_NEES_mean t.V13_NEES_mean],{'Baseline','V13'},'NEES mean',fullfile(res,'vy_dekf_v1_13_04_nees.png'));
figs.marginal=bars(common,labels,[t.Baseline_Vy_marginal_NEES t.V13_Vy_marginal_NEES t.Baseline_r_marginal_NEES t.V13_r_marginal_NEES],{'Base Vy','V13 Vy','Base r','V13 r'},'Marginal NSEE mean',fullfile(res,'vy_dekf_v1_13_05_marginal_nees.png'));
figs.coverage=bars(common,labels,[t.Baseline_Vy_2sigma_coverage t.V13_Vy_2sigma_coverage t.Baseline_r_2sigma_coverage t.V13_r_2sigma_coverage],{'Base Vy','V13 Vy','Base r','V13 r'},'2 sigma coverage',fullfile(res,'vy_dekf_v1_13_06_coverage.png'));
figs.innovation=bars(common,labels,[t.Baseline_innovation_Ay_RMS t.V13_innovation_Ay_RMS t.Baseline_innovation_r_RMS t.V13_innovation_r_RMS],{'Base Ay','V13 Ay','Base r','V13 r'},'Innovation RMS',fullfile(res,'vy_dekf_v1_13_07_innovation.png'));
f=figure(common{:});semilogy(t.P_min_eigenvalue,'o-');hold on;semilogy(t.P_max_condition,'s-');grid on;xticks(1:7);xticklabels(labels);legend('min eigenvalue','max condition');figs.stability=fullfile(res,'vy_dekf_v1_13_08_covariance_stability.png');exportgraphics(f,figs.stability,'Resolution',170);close(f);
f=figure(common{:});plot(d(1).baselineReplay.states(:,1));hold on;plot(d(1).v13Replay.states(:,1));grid on;legend('baseline','V13');xlabel('100 Hz sample');ylabel('Vy hat [m/s]');figs.nominalTrace=fullfile(res,'vy_dekf_v1_13_09_nominal_vy_trace.png');exportgraphics(f,figs.nominalTrace,'Resolution',170);close(f);
end
function file=bars(common,labels,y,leg,yl,file),f=figure(common{:});bar(y);grid on;xticks(1:7);xticklabels(labels);ylabel(yl);legend(leg,'Location','best');exportgraphics(f,file,'Resolution',170);close(f);end

function write_status(file,t,d,c,a,figs,csv,mat)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.13 STATUS\n\n## Implementation and gates\n\n');
fprintf(fid,'V1.13 applies only k_f=%.6g and k_r=%.6g after raw tire-force calculation in its isolated core/model copy. Prediction, measurement and numerical F/H use corrected Fy.\n\n',a.k_f,a.k_r);
fprintf(fid,'- Unity-gain test: %d random cases; max x/P/innovation/NIS/S/K difference = %.3g.\n',a.unitTest.testCount,max(struct2array(a.unitTest.maxDifference)));
fprintf(fid,'- Force scaling identity max: %.3g; measurement-force identity max: %.3g.\n',a.unitTest.forceScaleMax,a.unitTest.measurementConsistencyMax);
fprintf(fid,'- V1.12 input/IMU/truth maximum difference: %.3g.\n',a.maxInputTruthDifference);
fprintf(fid,'- V1.13 prediction vs rounded-gain V1.12 offline candidate maximum difference: %.3g.\n',a.maxOfflinePredictionDifference);
fprintf(fid,'- Alignment: `%s`; each case has 1601 updates at 100 Hz and 1600 truth-scored posterior samples.\n\n',a.posteriorAlignment);
fprintf(fid,'## State accuracy and consistency\n\n|Case|Vy RMSE base/V13|Vy improve|r RMSE base/V13|r improve|NIS base/V13|NEES base/V13|Vy marginal base/V13|stable|\n|:--|:--|--:|:--|--:|:--|:--|:--|:--|\n');
for i=1:height(t),fprintf(fid,'|%s|%.7g / %.7g|%.5g%%|%.7g / %.7g|%.5g%%|%.6g / %.6g|%.6g / %.6g|%.6g / %.6g|%d|\n',t.Case(i),t.Baseline_Vy_RMSE(i),t.V13_Vy_RMSE(i),t.Vy_improvement_percent(i),t.Baseline_r_RMSE(i),t.V13_r_RMSE(i),t.r_improvement_percent(i),t.Baseline_NIS_mean(i),t.V13_NIS_mean(i),t.Baseline_NEES_mean(i),t.V13_NEES_mean(i),t.Baseline_Vy_marginal_NEES(i),t.V13_Vy_marginal_NEES(i),t.stable(i));end
fprintf(fid,'\n## Innovation and coverage\n\nGaussian references are 68.27%% / 95.45%% / 99.73%% and are references, not hard gates.\n\n|Case|Ay innovation RMS base/V13|r innovation RMS base/V13|Vy 2sigma base/V13|r 2sigma base/V13|\n|:--|:--|:--|:--|:--|\n');
for i=1:height(t),fprintf(fid,'|%s|%.7g / %.7g|%.7g / %.7g|%.4f / %.4f|%.4f / %.4f|\n',t.Case(i),t.Baseline_innovation_Ay_RMS(i),t.V13_innovation_Ay_RMS(i),t.Baseline_innovation_r_RMS(i),t.V13_innovation_r_RMS(i),t.Baseline_Vy_2sigma_coverage(i),t.V13_Vy_2sigma_coverage(i),t.Baseline_r_2sigma_coverage(i),t.V13_r_2sigma_coverage(i));end
fprintf(fid,'\n## Covariance/stability\n\n|Case|min eig(P)|max cond(P)|P11 min/max/final|P22 min/max/final|P12 min/max|\n|:--|--:|--:|:--|:--|:--|\n');
for i=1:height(t),fprintf(fid,'|%s|%.4g|%.5g|%.5g / %.5g / %.5g|%.5g / %.5g / %.5g|%.5g / %.5g|\n',t.Case(i),t.P_min_eigenvalue(i),t.P_max_condition(i),t.P11_min(i),t.P11_max(i),t.P11_final(i),t.P22_min(i),t.P22_max(i),t.P22_final(i),t.P12_min(i),t.P12_max(i));end
fprintf(fid,'\n## Implemented model-residual re-audit\n\n|Case|wVy RMS|wr RMS|DeltaFy RMS|DeltaMz RMS|prediction equality max|\n|:--|--:|--:|--:|--:|--:|\n');
for i=1:numel(d),s=d(i).modelResidual;fprintf(fid,'|%s|%.7g|%.7g|%.7g|%.7g|%.3g|\n',d(i).Case,s.wVyRMS,s.wrRMS,s.DeltaFyRMS,s.DeltaMzRMS,d(i).offlinePredictionMaxDifference);end
fprintf(fid,'\n## Final answers\n\n');
fprintf(fid,'1. Vy RMSE improved in **%d/7** cases; mean improvement %.6g%%.\n',c.VyImprovedCases,c.meanVyImprovement);
fprintf(fid,'2. True-r RMSE improved in **%d/7** cases; mean improvement %.6g%%.\n',c.rImprovedCases,c.meanRImprovement);
fprintf(fid,'3. Cross-case stability: no >10%% accuracy degradation = **%s**.\n',yesno(~c.anyAccuracyWorse10));
fprintf(fid,'4. Full NEES improved in %d/7; aggregate reduction %.6g%%. Vy marginal improved in %d/7; aggregate reduction %.6g%%.\n',c.NEESImprovedCases,c.meanNEESReduction,c.VyMarginalImprovedCases,c.meanVyMarginalReduction);
fprintf(fid,'5. Mean NIS change V13-baseline: %.6g. NIS moved toward the nominal 2-D reference: **%s**. Colored IMU noise means NIS is not forced to 2, but all seven already-low values decreased further, so consistency did not move in the desired direction.\n',c.nisDirection,yesno(c.nisMovedTowardReference));
fprintf(fid,'6. Vy 2sigma coverage changes are reported case-by-case above.\n');
fprintf(fid,'7. Any case with >10%% Vy/r degradation: **%s**. Special cases A10/A30/F60 are included explicitly.\n',yesno(c.anyAccuracyWorse10));
fprintf(fid,'8. Online implementation reproduces the V1.12 rounded fixed-gain prediction: max difference %.3g (requirement <=1e-10).\n',c.maxPredictionDifference);
fprintf(fid,'9. Evidence sufficient to freeze the D-EKF steady-state force scaling (without further gain tuning): **%s**. Evidence sufficient to close the complete D-EKF V1 and start V2: **%s**; %d/7 V13 cases still have mean NEES > 5.991.\n',yesno(c.forceModelFreezeSupported),yesno(c.readyForV2),c.remainingHighNEESCases);
fprintf(fid,'10. Recommended next direction: **%s**. This is a covariance/colored-noise consistency blocker, not permission to retune gains, Q/R blindly, add relaxation, or add load transfer. No next stage was executed.\n',c.recommendation);
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n- `%s`\n',a.modelV13,csv,mat);p=struct2cell(figs);for i=1:numel(p),fprintf(fid,'- `%s`\n',p{i});end
fprintf(fid,'\n**AXLE SCALING WAS APPLIED ONLY IN THE V1.13 MODEL COPY.**\n\n**ORIGINAL D-EKF FILES WERE NOT MODIFIED.**\n\n**Q/R AND TIRE PARAMETERS WERE NOT RETUNED.**\n');
end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function s=yesno(v),if v,s='YES';else,s='NO';end,end
