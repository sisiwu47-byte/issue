function metricsTable = analyze_vy_dekf_v1_10_tire_transient()
%ANALYZE_VY_DEKF_V1_10_TIRE_TRANSIENT Offline 6x6 relaxation ablation.

repoRoot=fileparts(fileparts(mfilename('fullpath')));resultsDir=fullfile(repoRoot,'results');
v19File=fullfile(resultsDir,'vy_dekf_v1_9_model_mismatch.mat');
v18File=fullfile(resultsDir,'vy_dekf_v1_8_nees_source.mat');
assert(isfile(v19File)&&isfile(v18File));
v19=load(v19File);v18=load(v18File,'process','metadataV17');
p=v18.process;mechanics=v19.mechanics;meta=v18.metadataV17;
assert(numel(p.t)==1600&&abs(p.dt-0.01)<=1e-12);
assert(isequal(meta.fixedQ,diag([1e-4,1e-4]))&& ...
    isequal(meta.fixedR,diag([1e-2,3.365172961808e-4])));
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575);
sigmaLevels=[0 0.5 1 2 4 8];nCases=36;

FyTrue=par.m*p.ayTrue;MzTrue=par.Iz*p.drTrueDt;
FyfEquiv=(MzTrue+par.b*FyTrue)/(par.a+par.b);
FyrEquiv=(par.a*FyTrue-MzTrue)/(par.a+par.b);
steer=p.frontMeanSteer;steerRate=gradient(steer,p.t);absRate=abs(steerRate);
rateBins=rank_quantile_id(absRate,3);highRateMask=rateBins==3;
trainMask=p.t>=3&p.t<8;validationMask=p.t>=8&p.t<=13;fullMask=true(size(p.t));
splitNames={'TRAIN','VALIDATION','FULL'};splitMasks={trainMask,validationMask,fullMask};

candidateData=cell(nCases,1);rawRows=cell(nCases*3,1);summaryRows=cell(nCases,1);
caseIndex=0;rowIndex=0;
for i=1:numel(sigmaLevels)
    for j=1:numel(sigmaLevels)
        caseIndex=caseIndex+1;sf=sigmaLevels(i);sr=sigmaLevels(j);
        c=vy_dekf_v1_10_transient_candidate(p,mechanics,sf,sr,par);
        c.deltaFy=FyTrue-c.FyTotal;c.deltaMz=MzTrue-c.Mz;
        c.FyfModel=sum(c.Fyb(:,1:2),2);c.FyrModel=sum(c.Fyb(:,3:4),2);
        c.deltaFyf=FyfEquiv-c.FyfModel;c.deltaFyr=FyrEquiv-c.FyrModel;
        candidateData{caseIndex}=c;
        for split=1:3
            rowIndex=rowIndex+1;
            rawRows{rowIndex}=metric_row(caseIndex,sf,sr,splitNames{split}, ...
                splitMasks{split},c,p,steer);
        end
        hsVy=rms_value(c.residual(highRateMask,1));hsR=rms_value(c.residual(highRateMask,2));
        [hFront,hRear]=hysteresis_pair(steer,steerRate,c.deltaFyf,c.deltaFyr);
        [peakVy,lagVy]=lag_peak(steer,c.residual(:,1),20);
        [peakR,lagR]=lag_peak(steer,c.residual(:,2),20);
        [peakRateVy,lagRateVy]=lag_peak(steerRate,c.residual(:,1),20);
        [peakRateR,lagRateR]=lag_peak(steerRate,c.residual(:,2),20);
        [peakAyVy,lagAyVy]=lag_peak(p.ayTrue,c.residual(:,1),20);
        [peakAyR,lagAyR]=lag_peak(p.ayTrue,c.residual(:,2),20);
        aVy=normalized_acf(c.residual(:,1)-mean(c.residual(:,1)),10);
        aR=normalized_acf(c.residual(:,2)-mean(c.residual(:,2)),10);
        summaryRows{caseIndex}=struct('Case',caseIndex,'sigma_f',sf,'sigma_r',sr, ...
            'tau_f_at_meanVx',sf/mean(abs(p.u(:,1))), ...
            'tau_r_at_meanVx',sr/mean(abs(p.u(:,1))), ...
            'HighRate_Vy_RMS',hsVy,'HighRate_r_RMS',hsR, ...
            'FrontHysteresisIndex',hFront,'RearHysteresisIndex',hRear, ...
            'CombinedHysteresisIndex',mean([hFront hRear]), ...
            'corrSteer_Vy',pearson(steer,c.residual(:,1)), ...
            'corrSteer_r',pearson(steer,c.residual(:,2)), ...
            'corrRate_Vy',pearson(steerRate,c.residual(:,1)), ...
            'corrRate_r',pearson(steerRate,c.residual(:,2)), ...
            'corrAy_Vy',pearson(p.ayTrue,c.residual(:,1)), ...
            'corrAy_r',pearson(p.ayTrue,c.residual(:,2)), ...
            'peakSteerCorr_Vy',peakVy,'peakSteerLag_Vy',lagVy, ...
            'peakSteerCorr_r',peakR,'peakSteerLag_r',lagR, ...
            'peakRateCorr_Vy',peakRateVy,'peakRateLag_Vy',lagRateVy, ...
            'peakRateCorr_r',peakRateR,'peakRateLag_r',lagRateR, ...
            'peakAyCorr_Vy',peakAyVy,'peakAyLag_Vy',lagAyVy, ...
            'peakAyCorr_r',peakAyR,'peakAyLag_r',lagAyR, ...
            'Vy_rho1',aVy(2),'Vy_rho10',aVy(11),'r_rho1',aR(2),'r_rho10',aR(11));
    end
end
metricsTable=struct2table(vertcat(rawRows{:}));
summaryTable=struct2table(vertcat(summaryRows{:}));

% Strict static-baseline recovery against V1.9.
baseCase=find(summaryTable.sigma_f==0&summaryTable.sigma_r==0,1);
baseCandidate=candidateData{baseCase};
baselineAudit=struct( ...
    'xPredMax',max(abs(baseCandidate.xPred-mechanics.xPredCurrent),[],'all'), ...
    'wModelMax',max(abs(baseCandidate.residual-v19.wCurrent),[],'all'), ...
    'DeltaFyMax',max(abs(baseCandidate.deltaFy-v19.deltaFyCurrent)), ...
    'DeltaMzMax',max(abs(baseCandidate.deltaMz-v19.deltaMzCurrent)));
assert(max(struct2array(baselineAudit))<=1e-10,'sigma=(0,0) failed V1.9 recovery.');

% Add split-specific reductions relative to the sigma=(0,0) baseline.
reductionPairs={'Vy_RMS','Vy_RMS_reduction_percent';'r_RMS','r_RMS_reduction_percent'; ...
    'Vy_p95_abs','Vy_p95_reduction_percent';'r_p95_abs','r_p95_reduction_percent'; ...
    'DeltaFy_RMS','DeltaFy_RMS_reduction_percent';'DeltaMz_RMS','DeltaMz_RMS_reduction_percent'; ...
    'DeltaFyf_RMS','DeltaFyf_RMS_reduction_percent';'DeltaFyr_RMS','DeltaFyr_RMS_reduction_percent'};
for q=1:size(reductionPairs,1),metricsTable.(reductionPairs{q,2})=zeros(height(metricsTable),1);end
for split=1:3
    mask=metricsTable.Split==string(splitNames{split});base=mask&metricsTable.sigma_f==0&metricsTable.sigma_r==0;
    for q=1:size(reductionPairs,1)
        source=reductionPairs{q,1};target=reductionPairs{q,2};bvalue=metricsTable.(source)(base);
        metricsTable.(target)(mask)=100*(bvalue-metricsTable.(source)(mask))/max(abs(bvalue),eps);
    end
end

baseSummary=summaryTable(baseCase,:);
summaryTable.HighRate_Vy_reduction_percent=100*(baseSummary.HighRate_Vy_RMS-summaryTable.HighRate_Vy_RMS)/baseSummary.HighRate_Vy_RMS;
summaryTable.HighRate_r_reduction_percent=100*(baseSummary.HighRate_r_RMS-summaryTable.HighRate_r_RMS)/baseSummary.HighRate_r_RMS;
summaryTable.Hysteresis_reduction_percent=100*(baseSummary.CombinedHysteresisIndex-summaryTable.CombinedHysteresisIndex)/baseSummary.CombinedHysteresisIndex;
summaryTable.AbsSteerCorr_Vy_reduction_percent=100*(abs(baseSummary.corrSteer_Vy)-abs(summaryTable.corrSteer_Vy))/abs(baseSummary.corrSteer_Vy);
summaryTable.AbsSteerCorr_r_reduction_percent=100*(abs(baseSummary.corrSteer_r)-abs(summaryTable.corrSteer_r))/abs(baseSummary.corrSteer_r);

ranking=rank_candidates(metricsTable,summaryTable);
selectedCase=ranking.selectedCase;
selected=candidateData{selectedCase};
quasi=quasi_steady_audit(p,steerRate,FyfEquiv,FyrEquiv,baseCandidate,selected);
sensitivity=sensitivity_audit(metricsTable,sigmaLevels);
conclusions=derive_conclusions_v110(metricsTable,summaryTable,ranking,quasi,sensitivity);

timeConstantTable=table(sigmaLevels(:),sigmaLevels(:)/mean(abs(p.u(:,1))), ...
    'VariableNames',{'sigma_m','tau_at_meanVx_s'});
audit=struct('sourceV19',v19File,'sourceV18',v18File,'samples',numel(p.t), ...
    'Ts',p.dt,'fixedQ',meta.fixedQ,'fixedR',meta.fixedR, ...
    'baselineRecovery',baselineAudit,'lagConvention', ...
    'positive lag L means input leads residual by L samples', ...
    'trainDefinition','3<=t<8 s','validationDefinition','8<=t<=13 s', ...
    'quasiSteadyRateThreshold',quasi.rateThreshold,'noOnlineChange',true);

csvFile=fullfile(resultsDir,'vy_dekf_v1_10_tire_transient.csv');
summaryCsv=fullfile(resultsDir,'vy_dekf_v1_10_candidate_summary.csv');
rankingCsv=fullfile(resultsDir,'vy_dekf_v1_10_ranking.csv');
writetable(metricsTable,csvFile);writetable(summaryTable,summaryCsv);
writetable(ranking.winnerTable,rankingCsv);
figures=create_v110_figures(metricsTable,summaryTable,candidateData,p, ...
    FyfEquiv,FyrEquiv,baseCase,selectedCase,steerRate,resultsDir);
matFile=fullfile(resultsDir,'vy_dekf_v1_10_tire_transient.mat');
save(matFile,'metricsTable','summaryTable','ranking','candidateData','quasi', ...
    'sensitivity','conclusions','timeConstantTable','audit','figures', ...
    'FyfEquiv','FyrEquiv','-v7.3');
statusFile=fullfile(repoRoot,'docs','STAGE_VY_DEKF_V1_10_STATUS.md');
write_v110_status(statusFile,metricsTable,summaryTable,ranking,quasi, ...
    sensitivity,conclusions,timeConstantTable,audit,figures,csvFile, ...
    summaryCsv,rankingCsv,matFile);
fprintf(['V1_10_ANALYSIS_OK|selected=(%.3g,%.3g)|material=%d|', ...
    'baseline=%.3g|next=%s\n'],summaryTable.sigma_f(selectedCase), ...
    summaryTable.sigma_r(selectedCase),conclusions.materiallySupported, ...
    max(struct2array(baselineAudit)),conclusions.nextDirection);
fprintf('NO TRANSIENT TIRE MODEL WAS APPLIED ONLINE.\n');
fprintf('NO TIRE PARAMETER WAS IDENTIFIED OR CHANGED.\n');
fprintf('THIS WAS AN OFFLINE RELAXATION-LENGTH ABLATION ONLY.\n');
end

function row=metric_row(caseId,sf,sr,split,mask,c,p,steer)
vy=series_stats(c.residual(mask,1));rr=series_stats(c.residual(mask,2));
fy=series_stats(c.deltaFy(mask));mz=series_stats(c.deltaMz(mask));
ff=series_stats(c.deltaFyf(mask));fr=series_stats(c.deltaFyr(mask));
[fpeak,flag]=lag_peak(steer(mask),c.deltaFyf(mask),20);
[rpeak,rlag]=lag_peak(steer(mask),c.deltaFyr(mask),20);
row=struct('Case',caseId,'sigma_f',sf,'sigma_r',sr,'Split',string(split),'N',sum(mask), ...
    'Vy_mean',vy.mean,'Vy_RMS',vy.RMS,'Vy_p95_abs',vy.p95,'Vy_max_abs',vy.max, ...
    'Vy_rho1',vy.rho1,'Vy_rho10',vy.rho10, ...
    'r_mean',rr.mean,'r_RMS',rr.RMS,'r_p95_abs',rr.p95,'r_max_abs',rr.max, ...
    'r_rho1',rr.rho1,'r_rho10',rr.rho10, ...
    'DeltaFy_mean',fy.mean,'DeltaFy_RMS',fy.RMS,'DeltaFy_p95_abs',fy.p95,'DeltaFy_max_abs',fy.max, ...
    'DeltaMz_mean',mz.mean,'DeltaMz_RMS',mz.RMS,'DeltaMz_p95_abs',mz.p95,'DeltaMz_max_abs',mz.max, ...
    'DeltaFyf_RMS',ff.RMS,'DeltaFyf_p95_abs',ff.p95, ...
    'DeltaFyf_corr_steer',pearson(steer(mask),c.deltaFyf(mask)), ...
    'DeltaFyf_peak_corr',fpeak,'DeltaFyf_peak_lag',flag, ...
    'DeltaFyr_RMS',fr.RMS,'DeltaFyr_p95_abs',fr.p95, ...
    'DeltaFyr_corr_steer',pearson(steer(mask),c.deltaFyr(mask)), ...
    'DeltaFyr_peak_corr',rpeak,'DeltaFyr_peak_lag',rlag);
end

function s=series_stats(v)
v=v(:);acf=normalized_acf(v-mean(v),10);
s=struct('mean',mean(v),'RMS',rms_value(v),'p95',percentile(abs(v),95), ...
    'max',max(abs(v)),'rho1',acf(2),'rho10',acf(11));
end

function [frontIndex,rearIndex]=hysteresis_pair(steer,rate,frontDefect,rearDefect)
frontIndex=hysteresis_index(steer,rate,frontDefect);
rearIndex=hysteresis_index(steer,rate,rearDefect);
end

function value=hysteresis_index(steer,rate,defect)
edges=linspace(min(steer),max(steer),13);differences=[];
for k=1:12
    in=steer>=edges(k)&steer<=edges(k+1);up=in&rate>0;down=in&rate<0;
    if sum(up)>=5&&sum(down)>=5
        differences(end+1)=mean(defect(up))-mean(defect(down)); %#ok<AGROW>
    end
end
value=rms_value(differences)/max(rms_value(defect),eps);
end

function ranking=rank_candidates(metrics,summary)
train=metrics(metrics.Split=="TRAIN",:);val=metrics(metrics.Split=="VALIDATION",:);
assert(isequal(train.Case,val.Case));
trainImprove=train.Vy_RMS_reduction_percent>0&train.r_RMS_reduction_percent>=0& ...
    train.DeltaFy_RMS_reduction_percent>0&train.DeltaMz_RMS_reduction_percent>=0;
valImprove=val.Vy_RMS_reduction_percent>0&val.r_RMS_reduction_percent>=0& ...
    val.DeltaFy_RMS_reduction_percent>0&val.DeltaMz_RMS_reduction_percent>=0;
recommendable=trainImprove&valImprove;
objectives=[val.Vy_RMS val.r_RMS val.DeltaFy_RMS val.DeltaMz_RMS ...
    summary.HighRate_Vy_RMS summary.CombinedHysteresisIndex];
pareto=false(height(val),1);indices=find(recommendable);
for ii=1:numel(indices)
    i=indices(ii);dominated=false;
    for jj=1:numel(indices)
        j=indices(jj);if j~=i&&all(objectives(j,:)<=objectives(i,:))&&any(objectives(j,:)<objectives(i,:)),dominated=true;break;end
    end
    pareto(i)=~dominated;
end
base=val(val.sigma_f==0&val.sigma_r==0,:);baseS=summary(summary.sigma_f==0&summary.sigma_r==0,:);
improvements=[val.Vy_RMS_reduction_percent val.r_RMS_reduction_percent ...
    val.DeltaFy_RMS_reduction_percent val.DeltaMz_RMS_reduction_percent ...
    summary.HighRate_Vy_reduction_percent summary.Hysteresis_reduction_percent];
score=median(improvements,2)-0.25*std(improvements,0,2);
score(~recommendable)=-inf;
paretoIndices=find(pareto);[~,order]=sort(score(paretoIndices),'descend');
paretoIndices=paretoIndices(order(1:min(3,numel(order))));
if isempty(paretoIndices)
    [~,selected]=max(score);if ~isfinite(score(selected)),selected=1;end
    paretoIndices=selected;
else,selected=paretoIndices(1);end
winnerNames={'minimum TRAIN Vy RMS','minimum VALIDATION Vy RMS', ...
    'minimum VALIDATION r RMS','minimum VALIDATION DeltaFy RMS', ...
    'minimum VALIDATION DeltaMz RMS','minimum high-rate Vy residual', ...
    'lowest combined hysteresis'};
[~,winnerCases]=min([train.Vy_RMS val.Vy_RMS val.r_RMS val.DeltaFy_RMS ...
    val.DeltaMz_RMS summary.HighRate_Vy_RMS summary.CombinedHysteresisIndex],[],1);
winnerRows=cell(7,1);
for k=1:7
    idx=winnerCases(k);winnerRows{k}=struct('Criterion',string(winnerNames{k}), ...
        'Case',idx,'sigma_f',summary.sigma_f(idx),'sigma_r',summary.sigma_r(idx));
end
ranking=struct('recommendableMask',recommendable,'paretoMask',pareto, ...
    'paretoCases',paretoIndices(:)','selectedCase',selected, ...
    'score',score,'winnerTable',struct2table(vertcat(winnerRows{:})), ...
    'baselineValidation',base,'baselineSummary',baseS, ...
    'selectionRule',['TRAIN and VALIDATION must improve Vy and DeltaFy ', ...
    'without degrading r or DeltaMz; Pareto objectives then use validation ', ...
    'Vy/r/Fy/Mz plus high-rate Vy and hysteresis']);
end

function quasi=quasi_steady_audit(p,rate,fef,fer,base,best)
nonzero=abs(p.frontMeanSteer)>1e-6;
threshold=percentile(abs(rate(nonzero)),25);
mask=abs(p.frontMeanSteer)>0.005&abs(rate)<=threshold;
assert(sum(mask)>0);
quasi=struct('N',sum(mask),'rateThreshold',threshold, ...
    'Current',quasi_model(mask,fef,fer,base), ...
    'Selected',quasi_model(mask,fef,fer,best));
end

function q=quasi_model(mask,fef,fer,c)
dff=fef-c.FyfModel;dfr=fer-c.FyrModel;
bf=[ones(sum(mask),1) fef(mask)]\c.FyfModel(mask);
br=[ones(sum(mask),1) fer(mask)]\c.FyrModel(mask);
q=struct('DeltaFyf_mean',mean(dff(mask)),'DeltaFyf_RMS',rms_value(dff(mask)), ...
    'DeltaFyr_mean',mean(dfr(mask)),'DeltaFyr_RMS',rms_value(dfr(mask)), ...
    'FrontGain',bf(2),'RearGain',br(2));
end

function s=sensitivity_audit(metrics,levels)
val=metrics(metrics.Split=="VALIDATION",:);
frontMean=zeros(numel(levels),1);rearMean=zeros(numel(levels),1);
for k=1:numel(levels)
    frontMean(k)=mean(val.Vy_RMS(val.sigma_f==levels(k)));
    rearMean(k)=mean(val.Vy_RMS(val.sigma_r==levels(k)));
end
s=struct('levels',levels,'frontMainEffect',frontMean,'rearMainEffect',rearMean, ...
    'frontRange',max(frontMean)-min(frontMean),'rearRange',max(rearMean)-min(rearMean), ...
    'moreSensitiveAxle',conditional((max(frontMean)-min(frontMean))>= ...
    (max(rearMean)-min(rearMean)),'sigma_f','sigma_r'));
end

function c=derive_conclusions_v110(metrics,summary,ranking,quasi,sensitivity)
sel=ranking.selectedCase;train=metrics(metrics.Split=="TRAIN",:);val=metrics(metrics.Split=="VALIDATION",:);
st=train(train.Case==sel,:);sv=val(val.Case==sel,:);ss=summary(summary.Case==sel,:);
c=struct('selectedCase',sel,'sigma_f',ss.sigma_f,'sigma_r',ss.sigma_r, ...
    'trainVyReduction',st.Vy_RMS_reduction_percent,'validationVyReduction',sv.Vy_RMS_reduction_percent, ...
    'validationRReduction',sv.r_RMS_reduction_percent, ...
    'validationFyReduction',sv.DeltaFy_RMS_reduction_percent, ...
    'validationMzReduction',sv.DeltaMz_RMS_reduction_percent, ...
    'frontReduction',sv.DeltaFyf_RMS_reduction_percent, ...
    'rearReduction',sv.DeltaFyr_RMS_reduction_percent, ...
    'highRateVyReduction',ss.HighRate_Vy_reduction_percent, ...
    'highRateRReduction',ss.HighRate_r_reduction_percent, ...
    'hysteresisReduction',ss.Hysteresis_reduction_percent, ...
    'steerCorrVyReduction',ss.AbsSteerCorr_Vy_reduction_percent, ...
    'steerCorrRReduction',ss.AbsSteerCorr_r_reduction_percent, ...
    'VyRho1',ss.Vy_rho1,'rRho1',ss.r_rho1, ...
    'sensitiveAxle',sensitivity.moreSensitiveAxle, ...
    'quasiFrontGainCurrent',quasi.Current.FrontGain, ...
    'quasiFrontGainSelected',quasi.Selected.FrontGain, ...
    'quasiRearGainCurrent',quasi.Current.RearGain, ...
    'quasiRearGainSelected',quasi.Selected.RearGain);
baseS=summary(summary.sigma_f==0&summary.sigma_r==0,:);
c.VyRho1ReductionPercent=100*(baseS.Vy_rho1-ss.Vy_rho1)/baseS.Vy_rho1;
c.rRho1ReductionPercent=100*(baseS.r_rho1-ss.r_rho1)/baseS.r_rho1;
c.frontTransientComponentSupported=c.trainVyReduction>0&&c.validationVyReduction>0&& ...
    (c.validationVyReduction>=20||c.validationFyReduction>=20)&& ...
    c.highRateVyReduction>0&&c.hysteresisReduction>0;
c.materiallySupported=c.frontTransientComponentSupported&& ...
    c.validationRReduction>=0&&c.validationMzReduction>=0&& ...
    c.steerCorrVyReduction>0&&c.highRateRReduction>=-5;
c.plausibleRegionExists=any(ranking.recommendableMask);
c.quasiSteadyMismatchRemains=abs(c.quasiFrontGainSelected-1)>=0.2|| ...
    abs(c.quasiRearGainSelected-1)>=0.2;
if c.materiallySupported
    c.nextDirection='A. formally implement transient tire model in an isolated next-stage copy';
elseif c.quasiSteadyMismatchRemains
    c.nextDirection='B. continue steady-state tire gain/shape diagnosis';
else
    c.nextDirection='C. inspect vertical load/load transfer with new evidence';
end
end

function [peak,bestLag]=lag_peak(input,residual,maxLag)
lags=(-maxLag:maxLag)';values=zeros(size(lags));
for k=1:numel(lags)
    L=lags(k);if L>=0,x=input(1:end-L);y=residual(1+L:end);
    else,q=-L;x=input(1+q:end);y=residual(1:end-q);end
    values(k)=pearson(x,y);
end
[~,idx]=max(abs(values));peak=values(idx);bestLag=lags(idx);
end

function value=conditional(test,a,b),if test,value=a;else,value=b;end,end
function value=rms_value(v),value=sqrt(mean(v.^2));end
function value=percentile(v,p),v=sort(v(isfinite(v)));pos=1+(numel(v)-1)*p/100;lo=floor(pos);hi=ceil(pos);w=pos-lo;value=v(lo)*(1-w)+v(hi)*w;end
function rho=normalized_acf(x,maxLag),x=x(:)-mean(x);den=x'*x;rho=zeros(maxLag+1,1);for k=0:maxLag,rho(k+1)=(x(1:end-k)'*x(1+k:end))/max(den,eps);end,end
function c=pearson(x,y),x=x(:);y=y(:);m=isfinite(x)&isfinite(y);x=x(m);y=y(m);if std(x)==0||std(y)==0,c=0;else,q=corrcoef(x,y);c=q(1,2);end,end
function bin=rank_quantile_id(v,count),[~,order]=sort(v(:));n=numel(v);cuts=round(linspace(0,n,count+1));bin=zeros(n,1);for k=1:count,bin(order(cuts(k)+1:cuts(k+1)))=k;end,end

function figures=create_v110_figures(metrics,summary,candidates,p,fef,fer,baseCase,selectedCase,rate,resultsDir)
levels=[0 0.5 1 2 4 8];val=metrics(metrics.Split=="VALIDATION",:);
figures=struct();
fig=figure('Visible','off','Color','w','Position',[40 40 1300 650]);tiledlayout(fig,1,2);
nexttile;grid_heatmap(val.Vy_RMS,levels,'Validation Vy residual RMS');
nexttile;grid_heatmap(val.r_RMS,levels,'Validation r residual RMS');
figures.validationState=save_figure(fig,resultsDir,'vy_dekf_v1_10_01_validation_state_heatmaps.png');

fig=figure('Visible','off','Color','w','Position',[40 40 1300 650]);tiledlayout(fig,1,2);
nexttile;grid_heatmap(val.DeltaFy_RMS,levels,'Validation DeltaFy RMS [N]');
nexttile;grid_heatmap(val.DeltaMz_RMS,levels,'Validation DeltaMz RMS [N m]');
figures.validationPhysical=save_figure(fig,resultsDir,'vy_dekf_v1_10_02_validation_force_heatmaps.png');

train=metrics(metrics.Split=="TRAIN",:);
fig=figure('Visible','off','Color','w','Position',[60 60 1100 700]);
scatter(train.Vy_RMS_reduction_percent,val.Vy_RMS_reduction_percent,60,summary.sigma_f,'filled');
hold on;xline(0,'--');yline(0,'--');grid on;colorbar;
xlabel('TRAIN Vy RMS reduction [%]');ylabel('VALIDATION Vy RMS reduction [%]');
title('Color = sigma_f [m]');
figures.trainValidation=save_figure(fig,resultsDir,'vy_dekf_v1_10_03_train_validation.png');

base=candidates{baseCase};best=candidates{selectedCase};
fig=figure('Visible','off','Color','w','Position',[40 40 1400 850]);tiledlayout(fig,2,1);
nexttile;plot(p.t,base.residual(:,1));hold on;plot(p.t,best.residual(:,1));grid on;
ylabel('Vy residual [m/s]');legend({'current','selected'});
nexttile;plot(p.t,base.residual(:,2));hold on;plot(p.t,best.residual(:,2));grid on;
ylabel('r residual [rad/s]');xlabel('Time [s]');legend({'current','selected'});
figures.residualTime=save_figure(fig,resultsDir,'vy_dekf_v1_10_04_selected_residual_time.png');

fig=figure('Visible','off','Color','w','Position',[40 40 1400 800]);tiledlayout(fig,2,2);
nexttile;scatter(fef,base.FyfModel,7,'.');hold on;identity_line(fef);grid on;xlabel('Fyf equiv');ylabel('Current Fyf');
nexttile;scatter(fef,best.FyfModel,7,'.');hold on;identity_line(fef);grid on;xlabel('Fyf equiv');ylabel('Selected Fyf');
nexttile;scatter(fer,base.FyrModel,7,'.');hold on;identity_line(fer);grid on;xlabel('Fyr equiv');ylabel('Current Fyr');
nexttile;scatter(fer,best.FyrModel,7,'.');hold on;identity_line(fer);grid on;xlabel('Fyr equiv');ylabel('Selected Fyr');
figures.axleScatter=save_figure(fig,resultsDir,'vy_dekf_v1_10_05_axle_scatter.png');

fig=figure('Visible','off','Color','w','Position',[40 40 1400 850]);tiledlayout(fig,2,1);
nexttile;plot(p.frontMeanSteer(rate>=0),best.deltaFyf(rate>=0),'.');hold on;
plot(p.frontMeanSteer(rate<0),best.deltaFyf(rate<0),'.');grid on;legend('increasing','decreasing');ylabel('Selected DeltaFyf');
nexttile;plot(p.frontMeanSteer(rate>=0),best.deltaFyr(rate>=0),'.');hold on;
plot(p.frontMeanSteer(rate<0),best.deltaFyr(rate<0),'.');grid on;ylabel('Selected DeltaFyr');xlabel('front mean steer');
figures.hysteresis=save_figure(fig,resultsDir,'vy_dekf_v1_10_06_selected_hysteresis.png');

fig=figure('Visible','off','Color','w','Position',[40 40 1300 650]);tiledlayout(fig,1,2);
nexttile;grid_heatmap(summary.HighRate_Vy_reduction_percent,levels,'High-rate Vy reduction [%]');
nexttile;grid_heatmap(summary.Hysteresis_reduction_percent,levels,'Hysteresis reduction [%]');
figures.dynamic=save_figure(fig,resultsDir,'vy_dekf_v1_10_07_dynamic_heatmaps.png');

fig=figure('Visible','off','Color','w','Position',[60 60 1100 700]);
scatter(val.Vy_RMS,val.r_RMS,55,summary.sigma_r,'filled');hold on;
scatter(val.Vy_RMS(selectedCase),val.r_RMS(selectedCase),140,'kp','filled');grid on;colorbar;
xlabel('Validation Vy RMS');ylabel('Validation r RMS');title('Color = sigma_r; star = selected');
figures.pareto=save_figure(fig,resultsDir,'vy_dekf_v1_10_08_validation_pareto.png');
end

function grid_heatmap(values,levels,titleText)
matrix=reshape(values,6,6).';imagesc(matrix);axis image;colorbar;
xticks(1:6);xticklabels(string(levels));yticks(1:6);yticklabels(string(levels));
xlabel('sigma_r [m]');ylabel('sigma_f [m]');title(titleText);
end

function identity_line(v),limits=[min(v) max(v)];plot(limits,limits,'--k');end
function file=save_figure(fig,dir,name),file=fullfile(dir,name);exportgraphics(fig,file,'Resolution',180);close(fig);end

function write_v110_status(file,metrics,summary,ranking,quasi,sensitivity,c,timeConstants,audit,figures,varargin)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.10 STATUS\n\n');
fprintf(fid,'## 范围与基线验收\n\n');
fprintf(fid,['本阶段仅使用 V1.8/V1.9 已有数据做 6x6 离线 relaxation-length ablation。', ...
    '未运行 CarSim/Simulink，未修改正式 D-EKF、Q/R、`tireForceLocal`、Fz、', ...
    '车辆参数或轮胎参数。\n\n']);
fprintf(fid,'- 样本数 %d，Ts=%.6g s。\n',audit.samples,audit.Ts);
fprintf(fid,'- TRAIN: `%s`；VALIDATION: `%s`。\n',audit.trainDefinition,audit.validationDefinition);
fprintf(fid,'- lag 定义：**%s**。\n',audit.lagConvention);
fprintf(fid,'- sigma=(0,0) vs V1.9: x_pred %.3g，w_model %.3g，DeltaFy %.3g，DeltaMz %.3g。\n', ...
    audit.baselineRecovery.xPredMax,audit.baselineRecovery.wModelMax, ...
    audit.baselineRecovery.DeltaFyMax,audit.baselineRecovery.DeltaMzMax);
fprintf(fid,'- 固定 `Q=diag([1e-4,1e-4])`，`R=diag([1e-2,3.365172961808e-4])`。\n');

fprintf(fid,'\n## Relaxation grid 与时间常数\n\n');
fprintf(fid,'|sigma [m]|tau at mean Vx [s]|\n|--:|--:|\n');
for k=1:height(timeConstants),fprintf(fid,'|%.6g|%.9g|\n',timeConstants.sigma_m(k),timeConstants.tau_at_meanVx_s(k));end

fprintf(fid,'\n## 七个单指标 winner（不等于综合推荐）\n\n');
fprintf(fid,'|Criterion|Case|sigma_f|sigma_r|\n|:--|--:|--:|--:|\n');
for k=1:height(ranking.winnerTable),fprintf(fid,'|%s|%d|%.6g|%.6g|\n', ...
    ranking.winnerTable.Criterion(k),ranking.winnerTable.Case(k), ...
    ranking.winnerTable.sigma_f(k),ranking.winnerTable.sigma_r(k));end

train=metrics(metrics.Split=="TRAIN",:);val=metrics(metrics.Split=="VALIDATION",:);
fprintf(fid,'\n## Pareto candidates\n\n');
fprintf(fid,'门槛：%s。\n\n',ranking.selectionRule);
fprintf(fid,'|Case|sigma_f|sigma_r|TRAIN Vy red|VAL Vy red|VAL r red|VAL Fy red|VAL Mz red|high-rate Vy red|hysteresis red|\n');
fprintf(fid,'|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n');
for id=ranking.paretoCases
    fprintf(fid,'|%d|%.6g|%.6g|%.6g%%|%.6g%%|%.6g%%|%.6g%%|%.6g%%|%.6g%%|%.6g%%|\n', ...
        id,summary.sigma_f(id),summary.sigma_r(id),train.Vy_RMS_reduction_percent(id), ...
        val.Vy_RMS_reduction_percent(id),val.r_RMS_reduction_percent(id), ...
        val.DeltaFy_RMS_reduction_percent(id),val.DeltaMz_RMS_reduction_percent(id), ...
        summary.HighRate_Vy_reduction_percent(id),summary.Hysteresis_reduction_percent(id));
end

id=c.selectedCase;ss=summary(id,:);st=train(id,:);sv=val(id,:);
fprintf(fid,'\n## 综合诊断候选\n\n');
fprintf(fid,'选择 Case %d: `sigma_f=%.6g m`, `sigma_r=%.6g m`。该点仅用于诊断，不是已辨识参数。\n\n',id,c.sigma_f,c.sigma_r);
fprintf(fid,'|Metric|TRAIN|VALIDATION|\n|:--|--:|--:|\n');
fprintf(fid,'|Vy RMS reduction|%.6g%%|%.6g%%|\n',st.Vy_RMS_reduction_percent,sv.Vy_RMS_reduction_percent);
fprintf(fid,'|r RMS reduction|%.6g%%|%.6g%%|\n',st.r_RMS_reduction_percent,sv.r_RMS_reduction_percent);
fprintf(fid,'|DeltaFy RMS reduction|%.6g%%|%.6g%%|\n',st.DeltaFy_RMS_reduction_percent,sv.DeltaFy_RMS_reduction_percent);
fprintf(fid,'|DeltaMz RMS reduction|%.6g%%|%.6g%%|\n',st.DeltaMz_RMS_reduction_percent,sv.DeltaMz_RMS_reduction_percent);
fprintf(fid,'|front axle RMS reduction|%.6g%%|%.6g%%|\n',st.DeltaFyf_RMS_reduction_percent,sv.DeltaFyf_RMS_reduction_percent);
fprintf(fid,'|rear axle RMS reduction|%.6g%%|%.6g%%|\n',st.DeltaFyr_RMS_reduction_percent,sv.DeltaFyr_RMS_reduction_percent);
fprintf(fid,'\n- high steering-rate Vy/r reduction: %.6g%% / %.6g%%。\n',ss.HighRate_Vy_reduction_percent,ss.HighRate_r_reduction_percent);
fprintf(fid,'- combined hysteresis reduction: %.6g%%。\n',ss.Hysteresis_reduction_percent);
fprintf(fid,'- |steering correlation| reduction Vy/r: %.6g%% / %.6g%%。\n',ss.AbsSteerCorr_Vy_reduction_percent,ss.AbsSteerCorr_r_reduction_percent);
fprintf(fid,'- residual rho1 Vy/r: %.9g / %.9g。\n',ss.Vy_rho1,ss.r_rho1);
if abs(ss.peakSteerLag_Vy)==20||abs(ss.peakSteerLag_r)==20|| ...
        abs(ss.peakRateLag_Vy)==20||abs(ss.peakRateLag_r)==20
    fprintf(fid,'- 至少一个 lag peak 命中 +/-20 边界，不解释为精确物理 delay。\n');
end

fprintf(fid,'\n## Quasi-steady subset\n\n');
fprintf(fid,'`|front steer|>0.005 rad` 且 `|steering rate|<=%.9g rad/s`，N=%d。\n\n',quasi.rateThreshold,quasi.N);
fprintf(fid,'|Model|DeltaFyf mean/RMS|DeltaFyr mean/RMS|front gain|rear gain|\n|:--|:--|:--|--:|--:|\n');
fprintf(fid,'|Current|%.7g / %.7g|%.7g / %.7g|%.7g|%.7g|\n', ...
    quasi.Current.DeltaFyf_mean,quasi.Current.DeltaFyf_RMS, ...
    quasi.Current.DeltaFyr_mean,quasi.Current.DeltaFyr_RMS, ...
    quasi.Current.FrontGain,quasi.Current.RearGain);
fprintf(fid,'|Selected|%.7g / %.7g|%.7g / %.7g|%.7g|%.7g|\n', ...
    quasi.Selected.DeltaFyf_mean,quasi.Selected.DeltaFyf_RMS, ...
    quasi.Selected.DeltaFyr_mean,quasi.Selected.DeltaFyr_RMS, ...
    quasi.Selected.FrontGain,quasi.Selected.RearGain);

fprintf(fid,'\n## V1.10 最终回答\n\n');
fprintf(fid,'1. 一阶 relaxation 是否显著改善 Vy prediction residual：**%s**（TRAIN %.6g%%，VALIDATION %.6g%%）。\n',yesno(c.validationVyReduction>=20),c.trainVyReduction,c.validationVyReduction);
fprintf(fid,'2. 是否显著改善 r residual：**%s**（VALIDATION %.6g%%）。\n',yesno(c.validationRReduction>=20),c.validationRReduction);
fprintf(fid,'3. 是否降低 DeltaFy：**%s**（VALIDATION %.6g%%）。\n',yesno(c.validationFyReduction>0),c.validationFyReduction);
fprintf(fid,'4. 是否降低 DeltaMz：**%s**（VALIDATION %.6g%%）。\n',yesno(c.validationMzReduction>0),c.validationMzReduction);
fprintf(fid,'5. 更敏感的参数：**%s**（front/rear main-effect range %.6g / %.6g）。\n',c.sensitiveAxle,sensitivity.frontRange,sensitivity.rearRange);
fprintf(fid,'6. front axle residual 是否改善：**%s**（%.6g%%）。\n',yesno(c.frontReduction>0),c.frontReduction);
fprintf(fid,'7. rear axle residual 是否改善：**%s**（%.6g%%）。\n',yesno(c.rearReduction>0),c.rearReduction);
fprintf(fid,'8. high steering-rate residual 是否下降：Vy/r %.6g%% / %.6g%%。\n',c.highRateVyReduction,c.highRateRReduction);
fprintf(fid,'9. hysteresis 是否下降：**%s**（%.6g%%）。\n',yesno(c.hysteresisReduction>0),c.hysteresisReduction);
fprintf(fid,'10. 高度有色 rho1 是否显著下降：**%s**。Vy/r=%.9g / %.9g，相对变化 %.6g%% / %.6g%%。\n', ...
    yesno(c.VyRho1ReductionPercent>=10||c.rRho1ReductionPercent>=10), ...
    c.VyRho1,c.rRho1,c.VyRho1ReductionPercent,c.rRho1ReductionPercent);
fprintf(fid,'11. 是否存在 TRAIN/VALIDATION 都改善的合理 sigma 区域：**%s**；候选数 %d。\n',yesno(c.plausibleRegionExists),sum(ranking.recommendableMask));
fprintf(fid,'12. quasi-steady 区域是否仍有显著 gain mismatch：**%s**；front %.6g -> %.6g，rear %.6g -> %.6g。\n',yesno(c.quasiSteadyMismatchRemains),c.quasiFrontGainCurrent,c.quasiFrontGainSelected,c.quasiRearGainCurrent,c.quasiRearGainSelected);
fprintf(fid,'13. 下一阶段：**%s**。\n',c.nextDirection);
fprintf(fid,'\n前轴/Vy 通道是否存在 transient 成分证据：**%s**。\n',yesno(c.frontTransientComponentSupported));
fprintf(fid,'当前四轮两状态候选是否满足整体 success criteria：**%s**。\n',yesno(c.materiallySupported));

fprintf(fid,'\n## 产物\n\n');for k=1:numel(varargin),fprintf(fid,'- `%s`\n',varargin{k});end
names=fieldnames(figures);for k=1:numel(names),fprintf(fid,'- `%s`\n',figures.(names{k}));end
fprintf(fid,'- `%s.m`\n',mfilename('fullpath'));
fprintf(fid,'- `%s`\n',fullfile(fileparts(mfilename('fullpath')),'vy_dekf_v1_10_transient_candidate.m'));
fprintf(fid,'\n**NO TRANSIENT TIRE MODEL WAS APPLIED ONLINE.**\n\n');
fprintf(fid,'**NO TIRE PARAMETER WAS IDENTIFIED OR CHANGED.**\n\n');
fprintf(fid,'**THIS WAS AN OFFLINE RELAXATION-LENGTH ABLATION ONLY.**\n');
clear cleanup;
end

function word=yesno(v),if v,word='是';else,word='否';end,end
