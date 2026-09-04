function comparisonTable = analyze_vy_dekf_v1_9_model_mismatch()
%ANALYZE_VY_DEKF_V1_9_MODEL_MISMATCH Offline force/geometry attribution.
% No CarSim/Simulink execution, parameter tuning, or online correction.

repoRoot=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(repoRoot,'results');
v18File=fullfile(resultsDir,'vy_dekf_v1_8_nees_source.mat');
v17File=fullfile(resultsDir,'vy_dekf_v1_7_bias_ablation.mat');
assert(isfile(v18File)&&isfile(v17File));
v18=load(v18File,'process','metadataV17','aySourceAudit');
v17=load(v17File,'runs'); p=v18.process; meta=v18.metadataV17;
assert(abs(p.dt-0.01)<=1e-12&&numel(p.t)==1600);
assert(isequal(meta.fixedQ,diag([1e-4,1e-4]))&& ...
    isequal(meta.fixedR,diag([1e-2,3.365172961808e-4])));
b0=find(strcmp({v17.runs.Case},'B0'),1);
b3=find(strcmp({v17.runs.Case},'B3'),1);
fixedDifference=max([max(abs(v17.runs(b0).u-v17.runs(b3).u),[],'all'), ...
    max(abs(v17.runs(b0).vyTrue-v17.runs(b3).vyTrue)), ...
    max(abs(v17.runs(b0).rTrue-v17.runs(b3).rTrue))]);
assert(fixedDifference<=1e-12,'B0/B3 process inputs or truth differ.');

n=numel(p.t);dt=0.01;m=1860;Iz=2687.1;a=1.18;b=1.77;track=1.575;
par=struct('m',m,'Iz',Iz,'a',a,'b',b,'track',track,'Rw',0.393);
cfg=struct('dt',dt,'Q',meta.fixedQ,'R',meta.fixedR, ...
    'denomEps',1e-12,'lambda',zeros(4,1));
mechanics=initialize_mechanics(n);
equivalence=zeros(n,1);currentReplay=zeros(n,1);
for k=1:n
    q=vy_dekf_v1_9_prediction_audit(p.xInput(k,:)',p.u(k,:)',par,cfg);
    [~,~,debug]=vy_dynamic_ekf_step_v15_debug( ...
        p.xInput(k,:)',eye(2),p.u(k,:)',[0;0],par,cfg);
    equivalence(k)=max(abs(q.xPredCurrent-debug.x_pred));
    currentReplay(k)=max(abs(q.xPredCurrent-p.xPred(k,:)'));
    mechanics=store_mechanics(mechanics,q,k);
end
equivalenceMax=max(equivalence);replayMax=max(currentReplay);
assert(equivalenceMax<=1e-12&&replayMax<=1e-12);

xPredCurrent=mechanics.xPredCurrent;
xPredFull=mechanics.xPredFull;
wCurrent=p.xTarget-xPredCurrent;
wFull=p.xTarget-xPredFull;
assert(max(abs(wCurrent-p.residual),[],'all')<=1e-12);
dCurrent=wCurrent/dt;dFull=wFull/dt;
comparisonTable=residual_comparison(wCurrent,wFull,dCurrent,dFull);

inputNames={'Steer_FL','Steer_FR','Steer_RL','Steer_RR', ...
    'FrontMeanSteer','Ay_true','r_true','dr_true_dt'};
inputValues=[p.u(:,2:5) p.frontMeanSteer p.ayTrue p.rTrue p.drTrueDt];
lagTable=lag_audit_table(inputNames,inputValues,dCurrent,dFull,20,dt);
correlationTable=residual_correlation_table(inputNames,inputValues,dCurrent,dFull);

% Ay_true is used directly; it is not reconstructed from dVy/dt+Vx*r.
FyTrue=m*p.ayTrue;
MzTrue=Iz*p.drTrueDt;
deltaFyCurrent=FyTrue-mechanics.FyTotalCurrent;
deltaFyFull=FyTrue-mechanics.FyTotalFull;
deltaMzCurrent=MzTrue-mechanics.MzCurrent;
deltaMzFull=MzTrue-mechanics.MzFull;
FyfEquiv=(MzTrue+b*FyTrue)/(a+b);
FyrEquiv=(a*FyTrue-MzTrue)/(a+b);
FyfModel=sum(mechanics.FybCurrent(:,1:2),2);
FyrModel=sum(mechanics.FybCurrent(:,3:4),2);
deltaFyf=FyfEquiv-FyfModel;
deltaFyr=FyrEquiv-FyrModel;
forceMomentTable=force_moment_summary(deltaFyCurrent,deltaFyFull, ...
    deltaMzCurrent,deltaMzFull,deltaFyf,deltaFyr,p);
axleTable=axle_attribution(FyfEquiv,FyrEquiv,FyfModel,FyrModel, ...
    deltaFyf,deltaFyr,p.frontMeanSteer,dt);

directionTable=direction_audit(p.frontMeanSteer,wCurrent,wFull, ...
    deltaFyCurrent,deltaFyFull,deltaMzCurrent,deltaMzFull,deltaFyf,deltaFyr);
steerRate=gradient(p.frontMeanSteer,p.t);
conditionTable=condition_audit(p,wCurrent,wFull,abs(steerRate));
geometryTable=geometry_magnitude(mechanics);
fxTable=fx_audit(mechanics.Fx);
hysteresisTable=hysteresis_audit(p.frontMeanSteer,steerRate,deltaFyf,deltaFyr);

conclusions=derive_conclusions(comparisonTable,forceMomentTable,axleTable, ...
    directionTable,conditionTable,geometryTable,lagTable,correlationTable, ...
    hysteresisTable,deltaFyCurrent,deltaFyFull,deltaMzCurrent,deltaMzFull, ...
    mechanics,FyTrue,MzTrue);
audit=struct('sourceV18',v18File,'sourceV17',v17File,'samples',n,'Ts',dt, ...
    'B0B3FixedMaxDifference',fixedDifference,'predictionEquivalenceMax', ...
    equivalenceMax,'V18ReplayMax',replayMax,'lagConvention', ...
    'positive lag L means input leads residual by L samples', ...
    'B3PrimaryOracleOnly',true,'B0ControlIdenticalProcessAudit',true, ...
    'cleanAySource',v18.aySourceAudit);

mainCsv=fullfile(resultsDir,'vy_dekf_v1_9_model_mismatch.csv');
forceCsv=fullfile(resultsDir,'vy_dekf_v1_9_force_moment.csv');
lagCsv=fullfile(resultsDir,'vy_dekf_v1_9_lags.csv');
correlationCsv=fullfile(resultsDir,'vy_dekf_v1_9_correlations.csv');
conditionCsv=fullfile(resultsDir,'vy_dekf_v1_9_conditions.csv');
geometryCsv=fullfile(resultsDir,'vy_dekf_v1_9_geometry_terms.csv');
axleCsv=fullfile(resultsDir,'vy_dekf_v1_9_axle_attribution.csv');
writetable(comparisonTable,mainCsv);writetable(forceMomentTable,forceCsv);
writetable(lagTable,lagCsv);writetable(correlationTable,correlationCsv);
writetable(conditionTable,conditionCsv);
writetable(geometryTable,geometryCsv);writetable(axleTable,axleCsv);
figures=create_v1_9_figures(p,dCurrent,dFull,deltaFyCurrent,deltaFyFull, ...
    deltaMzCurrent,deltaMzFull,FyfEquiv,FyrEquiv,FyfModel,FyrModel, ...
    deltaFyf,deltaFyr,steerRate,geometryTable,directionTable,resultsDir);
matFile=fullfile(resultsDir,'vy_dekf_v1_9_model_mismatch.mat');
save(matFile,'comparisonTable','forceMomentTable','lagTable','correlationTable', ...
    'axleTable','directionTable','conditionTable','geometryTable','fxTable', ...
    'hysteresisTable','mechanics','wCurrent','wFull','dCurrent','dFull', ...
    'deltaFyCurrent','deltaFyFull','deltaMzCurrent','deltaMzFull', ...
    'FyfEquiv','FyrEquiv','FyfModel','FyrModel','deltaFyf','deltaFyr', ...
    'steerRate','conclusions','audit','figures','-v7.3');
statusFile=fullfile(repoRoot,'docs','STAGE_VY_DEKF_V1_9_STATUS.md');
write_v1_9_status(statusFile,comparisonTable,forceMomentTable,lagTable, ...
    correlationTable,axleTable,directionTable,conditionTable,geometryTable, ...
    fxTable,hysteresisTable,conclusions,audit,figures,mainCsv,forceCsv, ...
    lagCsv,correlationCsv,conditionCsv,geometryCsv,axleCsv,matFile);
fprintf(['V1_9_ANALYSIS_OK|N=%d|equiv=%.3g|FyRed=%.6g|MzRed=%.6g|', ...
    'priority=%s\n'],n,equivalenceMax,conclusions.deltaFyReductionPercent, ...
    conclusions.deltaMzReductionPercent,conclusions.nextPriority);
fprintf('NO MODEL CORRECTION WAS APPLIED ONLINE.\nQ AND R WERE FIXED.\n');
fprintf('THIS WAS AN OFFLINE MODEL-MISMATCH ABLATION ONLY.\n');
end

function s=initialize_mechanics(n)
s=struct('alpha',zeros(n,4),'Fy',zeros(n,4),'Fx',zeros(n,4), ...
    'FybCurrent',zeros(n,4),'FybFull',zeros(n,4),'FxbFull',zeros(n,4), ...
    'FyTotalCurrent',zeros(n,1),'FyTotalFull',zeros(n,1), ...
    'MzCurrent',zeros(n,1),'MzFull',zeros(n,1), ...
    'vyDotCurrent',zeros(n,1),'rDotCurrent',zeros(n,1), ...
    'vyDotFull',zeros(n,1),'rDotFull',zeros(n,1), ...
    'xPredCurrent',zeros(n,2),'xPredFull',zeros(n,2), ...
    'rearCosForce',zeros(n,1),'fxSinForce',zeros(n,1),'otherForce',zeros(n,1), ...
    'rearCosMoment',zeros(n,1),'fxSinMoment',zeros(n,1), ...
    'trackMoment',zeros(n,1),'otherMoment',zeros(n,1));
end

function s=store_mechanics(s,q,k)
vectors={'alpha','Fy','Fx','FybCurrent','FybFull','FxbFull'};
for j=1:numel(vectors),s.(vectors{j})(k,:)=q.(vectors{j})';end
scalars={'FyTotalCurrent','FyTotalFull','MzCurrent','MzFull','vyDotCurrent', ...
    'rDotCurrent','vyDotFull','rDotFull','rearCosForce','fxSinForce', ...
    'otherForce','rearCosMoment','fxSinMoment','trackMoment','otherMoment'};
for j=1:numel(scalars),s.(scalars{j})(k)=q.(scalars{j});end
s.xPredCurrent(k,:)=q.xPredCurrent';s.xPredFull(k,:)=q.xPredFull';
end

function t=residual_comparison(wc,wf,dc,df)
models={'Current','FullGeometry'};states={'Vy','r'};rows=cell(4,1);z=0;
for m=1:2
    if m==1,w=wc;d=dc;else,w=wf;d=df;end
    for k=1:2
        z=z+1;row=series_row(w(:,k));row.Model=string(models{m});row.State=string(states{k});
        ds=series_row(d(:,k));row.derivative_mean=ds.mean;row.derivative_std=ds.std;
        row.derivative_RMS=ds.RMS;row.derivative_p95_abs=ds.p95_abs;
        row.derivative_max_abs=ds.max_abs;row.derivative_rho1=ds.rho1;
        row.derivative_rho10=ds.rho10;rows{z}=row;
    end
end
t=struct2table(vertcat(rows{:}));t.RMS_reduction_percent=zeros(height(t),1);
for k=1:2,t.RMS_reduction_percent(k+2)=100*(t.RMS(k)-t.RMS(k+2))/t.RMS(k);end
end

function row=series_row(v)
v=v(:);acf=normalized_acf(v-mean(v),10);
row=struct('mean',mean(v),'std',std(v,0),'RMS',rms_value(v), ...
    'p95_abs',percentile(abs(v),95),'max_abs',max(abs(v)), ...
    'rho1',acf(2),'rho10',acf(11));
end

function t=lag_audit_table(names,x,dc,df,maxLag,dt)
rows=cell(numel(names)*4,1);z=0;models={'Current','FullGeometry'};states={'dVy','dr'};
for m=1:2
    if m==1,d=dc;else,d=df;end
    for k=1:numel(names)
        for q=1:2
            z=z+1;[peak,lag]=lag_peak(x(:,k),d(:,q),maxLag);
            rows{z}=struct('Model',string(models{m}),'Input',string(names{k}), ...
                'Residual',string(states{q}),'PeakCorrelation',peak, ...
                'LagSamples',lag,'LagSeconds',lag*dt, ...
                'Direction',string(sign_word(peak)));
        end
    end
end
t=struct2table(vertcat(rows{:}));
end

function [peak,bestLag]=lag_peak(input,residual,maxLag)
lags=(-maxLag:maxLag)';values=zeros(size(lags));
for k=1:numel(lags)
    L=lags(k);
    if L>=0,x=input(1:end-L);y=residual(1+L:end);
    else,q=-L;x=input(1+q:end);y=residual(1:end-q);end
    values(k)=pearson(x,y);
end
[~,idx]=max(abs(values));peak=values(idx);bestLag=lags(idx);
end

function word=sign_word(v),if v>=0,word='positive';else,word='negative';end,end

function t=residual_correlation_table(names,x,dc,df)
rows=cell(numel(names)*2,1);z=0;
for k=1:numel(names)
    for q=1:2
        z=z+1;c0=pearson(x(:,k),dc(:,q));cf=pearson(x(:,k),df(:,q));
        rows{z}=struct('Input',string(names{k}), ...
            'Residual',string(conditional(q==1,'dVy','dr')), ...
            'CurrentZeroLag',c0,'FullZeroLag',cf, ...
            'AbsoluteCorrelationReductionPercent',100*(abs(c0)-abs(cf))/max(abs(c0),eps));
    end
end
t=struct2table(vertcat(rows{:}));
end

function t=force_moment_summary(dfyc,dfyf,dmzc,dmzf,dff,dfr,p)
names={'DeltaFy_current','DeltaFy_full','DeltaMz_current','DeltaMz_full','DeltaFyf','DeltaFyr'};
units={'N','N','N*m','N*m','N','N'};values={dfyc,dfyf,dmzc,dmzf,dff,dfr};rows=cell(6,1);
for k=1:6
    s=series_row(values{k});
    rows{k}=struct('Quantity',string(names{k}),'Unit',string(units{k}), ...
        'mean',s.mean,'RMS',s.RMS,'p95_abs',s.p95_abs,'max_abs',s.max_abs, ...
        'rho1',s.rho1,'rho10',s.rho10, ...
        'corr_front_mean_steer',pearson(values{k},p.frontMeanSteer), ...
        'corr_Ay_true',pearson(values{k},p.ayTrue), ...
        'corr_r_true',pearson(values{k},p.rTrue), ...
        'corr_dr_true_dt',pearson(values{k},p.drTrueDt));
end
t=struct2table(vertcat(rows{:}));
end

function t=axle_attribution(fef,fer,fmf,fmr,df,dr,steer,dt)
names={'Front','Rear'};equiv={fef,fer};model={fmf,fmr};defect={df,dr};rows=cell(2,1);
for k=1:2
    X=[ones(numel(equiv{k}),1) equiv{k}];beta=X\model{k};
    [peak,lag]=lag_peak(steer,defect{k},20);[modelPeak,modelLag]=lag_peak(equiv{k},model{k},20);
    rows{k}=struct('Axle',string(names{k}),'Equiv_RMS',rms_value(equiv{k}), ...
        'Model_RMS',rms_value(model{k}),'Defect_mean',mean(defect{k}), ...
        'Defect_RMS',rms_value(defect{k}),'Defect_p95_abs',percentile(abs(defect{k}),95), ...
        'Defect_max_abs',max(abs(defect{k})),'DefectSteerCorr0',pearson(steer,defect{k}), ...
        'DefectSteerPeakCorr',peak,'DefectSteerPeakLagSamples',lag, ...
        'DefectSteerPeakLagSeconds',lag*dt,'ModelVsEquivGain',beta(2), ...
        'ModelVsEquivOffset',beta(1),'ModelVsEquivCorr',pearson(equiv{k},model{k}), ...
        'EquivLeadsModelPeakCorr',modelPeak,'EquivLeadsModelLagSamples',modelLag, ...
        'EquivLeadsModelLagSeconds',modelLag*dt);
end
t=struct2table(vertcat(rows{:}));
end

function t=direction_audit(steer,wc,wf,dfyc,dfyf,dmzc,dmzf,dff,dfr)
groups={'left >0.002','near-zero <=0.002','right <-0.002'};
masks={steer>0.002,abs(steer)<=0.002,steer<-0.002};rows=cell(3,1);
for k=1:3
    mask=masks{k};
    rows{k}=struct('Group',string(groups{k}),'N',sum(mask), ...
        'wVy_current_mean',mean(wc(mask,1)),'wVy_current_RMS',rms_value(wc(mask,1)), ...
        'wr_current_mean',mean(wc(mask,2)),'wr_current_RMS',rms_value(wc(mask,2)), ...
        'wVy_full_mean',mean(wf(mask,1)),'wVy_full_RMS',rms_value(wf(mask,1)), ...
        'wr_full_mean',mean(wf(mask,2)),'wr_full_RMS',rms_value(wf(mask,2)), ...
        'DeltaFy_current_mean',mean(dfyc(mask)),'DeltaFy_current_RMS',rms_value(dfyc(mask)), ...
        'DeltaFy_full_mean',mean(dfyf(mask)),'DeltaFy_full_RMS',rms_value(dfyf(mask)), ...
        'DeltaMz_current_mean',mean(dmzc(mask)),'DeltaMz_current_RMS',rms_value(dmzc(mask)), ...
        'DeltaMz_full_mean',mean(dmzf(mask)),'DeltaMz_full_RMS',rms_value(dmzf(mask)), ...
        'DeltaFyf_mean',mean(dff(mask)),'DeltaFyf_RMS',rms_value(dff(mask)), ...
        'DeltaFyr_mean',mean(dfr(mask)),'DeltaFyr_RMS',rms_value(dfr(mask)));
end
t=struct2table(vertcat(rows{:}));
end

function t=condition_audit(p,wc,wf,absRate)
rows=cell(14,1);z=0;steer=p.maxAbsSteer;
masks={steer<=0.002,steer>0.002&steer<=0.01,steer>0.01};
labels={'low <=0.002','mid (0.002,0.01]','high >0.01'};
for k=1:3,z=z+1;rows{z}=condition_row('SteeringAmplitude',labels{k},masks{k},wc,wf);end
variables={abs(p.ayTrue),abs(p.drTrueDt)};sections={'AbsAyTrue','AbsDrTrueDt'};
for q=1:2
    bin=rank_quantile_id(variables{q},4);
    for k=1:4,z=z+1;rows{z}=condition_row(sections{q},sprintf('Q%d',k),bin==k,wc,wf);end
end
bin=rank_quantile_id(absRate,3);
for k=1:3,z=z+1;rows{z}=condition_row('AbsSteeringRate',sprintf('T%d',k),bin==k,wc,wf);end
t=struct2table(vertcat(rows{:}));
end

function row=condition_row(section,group,mask,wc,wf)
row=struct('Section',string(section),'Group',string(group),'N',sum(mask), ...
    'wVy_current_RMS',rms_value(wc(mask,1)),'wVy_full_RMS',rms_value(wf(mask,1)), ...
    'wr_current_RMS',rms_value(wc(mask,2)),'wr_full_RMS',rms_value(wf(mask,2)), ...
    'wVy_reduction_percent',100*(rms_value(wc(mask,1))-rms_value(wf(mask,1)))/max(rms_value(wc(mask,1)),eps), ...
    'wr_reduction_percent',100*(rms_value(wc(mask,2))-rms_value(wf(mask,2)))/max(rms_value(wc(mask,2)),eps));
end

function t=geometry_magnitude(s)
forceModelRms=rms_value(s.FyTotalCurrent);momentModelRms=rms_value(s.MzCurrent);
names={'A rear steering cosine','B Fx*sin(delta)','C track-width yaw moment','D other transform difference'};
force={s.rearCosForce,s.fxSinForce,zeros(size(s.trackMoment)),s.otherForce};
moment={s.rearCosMoment,s.fxSinMoment,s.trackMoment,s.otherMoment};rows=cell(4,1);
for k=1:4
    rows{k}=struct('Term',string(names{k}),'Force_RMS_N',rms_value(force{k}), ...
        'Force_percent_of_model_RMS',100*rms_value(force{k})/max(forceModelRms,eps), ...
        'Moment_RMS_Nm',rms_value(moment{k}), ...
        'Moment_percent_of_model_RMS',100*rms_value(moment{k})/max(momentModelRms,eps));
end
t=struct2table(vertcat(rows{:}));
end

function t=fx_audit(Fx)
names={'FL','FR','RL','RR'};rows=cell(4,1);
for k=1:4,rows{k}=struct('Wheel',string(names{k}), ...
    'RMS_Fx_N',rms_value(Fx(:,k)),'MaxAbs_Fx_N',max(abs(Fx(:,k))));end
t=struct2table(vertcat(rows{:}));
end

function t=hysteresis_audit(steer,rate,dff,dfr)
names={'Front','Rear'};values={dff,dfr};rows=cell(2,1);edges=linspace(min(steer),max(steer),13);
for q=1:2
    differences=[];
    for k=1:12
        mask=steer>=edges(k)&steer<=edges(k+1);up=mask&rate>0;down=mask&rate<0;
        if sum(up)>=5&&sum(down)>=5
            differences(end+1)=mean(values{q}(up))-mean(values{q}(down)); %#ok<AGROW>
        end
    end
    index=rms_value(differences)/max(rms_value(values{q}),eps);
    rows{q}=struct('Axle',string(names{q}),'ValidSteerBins',numel(differences), ...
        'IncreasingDecreasingMeanSeparationRMS',rms_value(differences), ...
        'NormalizedHysteresisIndex',index,'PossibleDynamicHysteresis',index>=0.2);
end
t=struct2table(vertcat(rows{:}));
end

function c=derive_conclusions(comp,force,axle,direction,condition,geometry,lag,corr,hyst, ...
    dfyc,dfyf,dmzc,dmzf,s,FyTrue,MzTrue)
c=struct();
c.deltaFyReductionPercent=100*(rms_value(dfyc)-rms_value(dfyf))/rms_value(dfyc);
c.deltaMzReductionPercent=100*(rms_value(dmzc)-rms_value(dmzf))/rms_value(dmzc);
c.vyResidualReductionPercent=comp.RMS_reduction_percent(comp.Model=="FullGeometry"&comp.State=="Vy");
c.rResidualReductionPercent=comp.RMS_reduction_percent(comp.Model=="FullGeometry"&comp.State=="r");
c.geometrySignificantVy=c.vyResidualReductionPercent>=20;
c.geometrySignificantR=c.rResidualReductionPercent>=20;
c.geometryMagnitudeSufficient=c.deltaFyReductionPercent>=20||c.deltaMzReductionPercent>=20;
frontCorr=corr(corr.Input=="FrontMeanSteer",:);
c.signedCorrelationReductionVy=frontCorr.AbsoluteCorrelationReductionPercent(frontCorr.Residual=="dVy");
c.signedCorrelationReductionR=frontCorr.AbsoluteCorrelationReductionPercent(frontCorr.Residual=="dr");
c.coloredResidualRemains=any(comp.rho1(comp.Model=="FullGeometry")>0.9);
fullLag=lag(lag.Model=="FullGeometry"&lag.Input=="FrontMeanSteer",:);
c.phaseLagRemains=any(abs(fullLag.LagSamples)>=1);
c.lagPeakAtSearchBoundary=any(abs(fullLag.LagSamples)==20);
left=direction(1,:);right=direction(3,:);
c.antisymmetricForce=opposite_and_balanced(left.DeltaFy_current_mean,right.DeltaFy_current_mean);
c.antisymmetricMoment=opposite_and_balanced(left.DeltaMz_current_mean,right.DeltaMz_current_mean);
c.antisymmetricConditionalBias=c.antisymmetricForce||c.antisymmetricMoment;
[~,k]=max(axle.Defect_RMS);c.largerAxle=char(axle.Axle(k));
forceRatio=rms_value(dfyc)/max(rms_value(FyTrue),eps);
momentRatio=rms_value(dmzc)/max(rms_value(MzTrue),eps);
c.totalForceRelativeDefect=forceRatio;c.yawMomentRelativeDefect=momentRatio;
if forceRatio>=0.2&&momentRatio>=0.2
    c.primaryPhysicalMismatch='both total lateral force and yaw moment';
elseif forceRatio>=momentRatio,c.primaryPhysicalMismatch='total lateral-force mismatch';
else,c.primaryPhysicalMismatch='yaw-moment mismatch';end
c.fxEssentiallyZero=max(abs(s.Fx),[],'all')<=1e-9;
c.maxGeometryForcePercent=max(geometry.Force_percent_of_model_RMS);
c.maxGeometryMomentPercent=max(geometry.Moment_percent_of_model_RMS);
c.hysteresisEvidence=any(hyst.PossibleDynamicHysteresis);
c.frontGain=axle.ModelVsEquivGain(axle.Axle=="Front");
c.rearGain=axle.ModelVsEquivGain(axle.Axle=="Rear");
c.gainMismatch=abs(c.frontGain-1)>=0.2||abs(c.rearGain-1)>=0.2;
if c.geometryMagnitudeSufficient,c.nextPriority='formally evaluate geometry correction';
elseif c.hysteresisEvidence||c.phaseLagRemains,c.nextPriority='tire transient/relaxation investigation';
elseif c.gainMismatch,c.nextPriority='tire steady-state gain/shape investigation';
else,c.nextPriority='other model terms; obtain vertical-load/load-transfer evidence';end
c.secondaryPriority=conditional(c.gainMismatch, ...
    'tire steady-state gain/shape audit after transient attribution', ...
    'vertical-load/load-transfer evidence if residual remains');
amp=condition(condition.Section=="SteeringAmplitude",:);
rate=condition(condition.Section=="AbsSteeringRate",:);
c.amplitudeGrowth=max([amp.wVy_current_RMS(end)/max(amp.wVy_current_RMS(1),eps), ...
    amp.wr_current_RMS(end)/max(amp.wr_current_RMS(1),eps)]);
c.rateGrowth=max([rate.wVy_current_RMS(end)/max(rate.wVy_current_RMS(1),eps), ...
    rate.wr_current_RMS(end)/max(rate.wr_current_RMS(1),eps)]);
c.strongerDependence=conditional(c.amplitudeGrowth>=c.rateGrowth, ...
    'steering amplitude','steering rate/dynamic transition');
c.numericalJacobianCannotExplainNominalDefect=true;
end

function yes=opposite_and_balanced(a,b)
yes=sign(a)*sign(b)<0&&abs(a+b)<=0.3*max(abs([a b]));
end

function word=yesno(v),if v,word='是';else,word='否';end,end
function value=conditional(test,a,b),if test,value=a;else,value=b;end,end
function value=rms_value(v),value=sqrt(mean(v.^2));end
function value=percentile(v,p),v=sort(v(isfinite(v)));pos=1+(numel(v)-1)*p/100;lo=floor(pos);hi=ceil(pos);w=pos-lo;value=v(lo)*(1-w)+v(hi)*w;end
function rho=normalized_acf(x,maxLag),x=x(:)-mean(x);den=x'*x;rho=zeros(maxLag+1,1);for k=0:maxLag,rho(k+1)=(x(1:end-k)'*x(1+k:end))/max(den,eps);end,end
function c=pearson(x,y),x=x(:);y=y(:);m=isfinite(x)&isfinite(y);x=x(m);y=y(m);if std(x)==0||std(y)==0,c=0;else,q=corrcoef(x,y);c=q(1,2);end,end
function bin=rank_quantile_id(v,count),[~,order]=sort(v(:));n=numel(v);cuts=round(linspace(0,n,count+1));bin=zeros(n,1);for k=1:count,bin(order(cuts(k)+1:cuts(k+1)))=k;end,end

function figures=create_v1_9_figures(p,dc,df,dfyc,dfyf,dmzc,dmzf, ...
    fef,fer,fmf,fmr,dff,dfr,rate,geometry,direction,resultsDir)
figures=struct();
fig=figure('Visible','off','Color','w','Position',[50 50 1400 850]);
tiledlayout(fig,2,1);
nexttile;plot(p.t,dc(:,1));hold on;plot(p.t,df(:,1));grid on;
ylabel('dVy defect [m/s^2]');legend('current','full');
nexttile;plot(p.t,dc(:,2));hold on;plot(p.t,df(:,2));grid on;
ylabel('dr defect [rad/s^2]');xlabel('Time [s]');
figures.derivative=save_figure(fig,resultsDir,'vy_dekf_v1_9_01_derivative_defects.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1400 850]);
tiledlayout(fig,2,1);
nexttile;plot(p.t,dfyc);hold on;plot(p.t,dfyf);grid on;
ylabel('Delta Fy [N]');legend('current','full');
nexttile;plot(p.t,dmzc);hold on;plot(p.t,dmzf);grid on;
ylabel('Delta Mz [N m]');xlabel('Time [s]');
figures.forceMoment=save_figure(fig,resultsDir,'vy_dekf_v1_9_02_force_moment_defects.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1400 700]);
tiledlayout(fig,1,2);
nexttile;scatter(fef,fmf,8,'.');hold on;plot_identity(fef);grid on;
xlabel('Fyf equiv');ylabel('Fyf model');
nexttile;scatter(fer,fmr,8,'.');hold on;plot_identity(fer);grid on;
xlabel('Fyr equiv');ylabel('Fyr model');
figures.axleScatter=save_figure(fig,resultsDir,'vy_dekf_v1_9_03_axle_equiv_vs_model.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1400 700]);
tiledlayout(fig,1,2);
nexttile;scatter(p.frontMeanSteer,dff,8,'.');grid on;
xlabel('front mean steer');ylabel('Delta Fyf');
nexttile;scatter(p.frontMeanSteer,dfr,8,'.');grid on;
xlabel('front mean steer');ylabel('Delta Fyr');
figures.axleDefect=save_figure(fig,resultsDir,'vy_dekf_v1_9_04_axle_defect_vs_steer.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1400 800]);
tiledlayout(fig,2,1);
nexttile;plot(p.frontMeanSteer(rate>=0),dff(rate>=0),'.');hold on;
plot(p.frontMeanSteer(rate<0),dff(rate<0),'.');grid on;
ylabel('Delta Fyf');legend('increasing','decreasing');
nexttile;plot(p.frontMeanSteer(rate>=0),dfr(rate>=0),'.');hold on;
plot(p.frontMeanSteer(rate<0),dfr(rate<0),'.');grid on;
ylabel('Delta Fyr');xlabel('front mean steer');
figures.hysteresis=save_figure(fig,resultsDir,'vy_dekf_v1_9_05_hysteresis.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1200 650]);
bar([geometry.Force_percent_of_model_RMS geometry.Moment_percent_of_model_RMS]);
grid on;xticks(1:height(geometry));xticklabels(cellstr(geometry.Term));xtickangle(15);
ylabel('% of current model RMS');legend('force','moment');
figures.geometry=save_figure(fig,resultsDir,'vy_dekf_v1_9_06_geometry_magnitude.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1100 650]);
bar([direction.DeltaFy_current_mean direction.DeltaMz_current_mean]);grid on;
xticks(1:3);xticklabels(cellstr(direction.Group));
legend('Delta Fy mean','Delta Mz mean');
figures.direction=save_figure(fig,resultsDir,'vy_dekf_v1_9_07_left_right_bias.png');

fig=figure('Visible','off','Color','w','Position',[50 50 1400 750]);
tiledlayout(fig,2,1);
nexttile;plot(p.t,dff);hold on;plot(p.t,dfr);grid on;
legend('Delta Fyf','Delta Fyr');ylabel('Axle defect [N]');
nexttile;plot(p.t,p.frontMeanSteer);grid on;
ylabel('front mean steer');xlabel('Time [s]');
figures.axleTime=save_figure(fig,resultsDir,'vy_dekf_v1_9_08_axle_defect_time.png');
end

function plot_identity(v)
limits=[min(v) max(v)];plot(limits,limits,'--k');
end

function file=save_figure(fig,dir,name)
file=fullfile(dir,name);exportgraphics(fig,file,'Resolution',180);close(fig);
end

function write_v1_9_status(file,comp,force,lag,corr,axle,direction,condition, ...
    geometry,fx,hyst,c,audit,figures,varargin)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.9 STATUS\n\n');
fprintf(fid,'## 范围与验收\n\n');
fprintf(fid,['V1.9 仅使用已有 V1.7/V1.8 数据做离线诊断；未运行 CarSim/Simulink，', ...
    '未修改 Q/R、在线 D-EKF、轮胎参数或任何模型修正。\n\n']);
fprintf(fid,'- 有效一步样本：%d，Ts=%.6g s。\n',audit.samples,audit.Ts);
fprintf(fid,'- B0/B3 过程输入和真值最大差异：%.3g；两者过程审计相同。\n',audit.B0B3FixedMaxDifference);
fprintf(fid,'- diagnostic helper vs verified debug x_pred 最大差异：%.3g。\n',audit.predictionEquivalenceMax);
fprintf(fid,'- helper vs V1.8 archived x_pred 最大差异：%.3g。\n',audit.V18ReplayMax);
fprintf(fid,'- lag 定义：**%s**。\n',audit.lagConvention);
fprintf(fid,'- B3 是主要 oracle-corrected diagnostic case，不是最终在线估计器；B0 仅作 control。\n');

fprintf(fid,'\n## KNOWN BEFORE V1.9（V1.8 结论）\n\n');
fprintf(fid,['- B3 NEES mean=17.5554，主要来自 Vy diagonal term。\n', ...
    '- 固定 IMU bias 不解释剩余 NEES。\n', ...
    '- 一步残差全局均值接近0，但高度有色且与 signed steering 强相关。\n', ...
    '- V1.8 未执行 DeltaFy/DeltaMz、前后轴或 full-geometry 归因。\n']);

fprintf(fid,'\n## NEWLY MEASURED IN V1.9\n\n');
fprintf(fid,'### Current vs full-geometry 一步残差\n\n');
fprintf(fid,'|Model|State|mean|RMS|p95 abs|max abs|rho1|rho10|RMS reduction|\n');
fprintf(fid,'|:--|:--|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(comp)
    fprintf(fid,'|%s|%s|%.9g|%.9g|%.9g|%.9g|%.6g|%.6g|%.6g%%|\n', ...
        comp.Model(k),comp.State(k),comp.mean(k),comp.RMS(k),comp.p95_abs(k), ...
        comp.max_abs(k),comp.rho1(k),comp.rho10(k),comp.RMS_reduction_percent(k));
end
fprintf(fid,'\n导数形式模型缺陷 `d_model=w_model/Ts`：\n\n');
fprintf(fid,'|Model|State|mean|std|RMS|p95 abs|max abs|rho1|rho10|\n');
fprintf(fid,'|:--|:--|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(comp)
    fprintf(fid,'|%s|%s|%.8g|%.8g|%.8g|%.8g|%.8g|%.6g|%.6g|\n', ...
        comp.Model(k),comp.State(k),comp.derivative_mean(k),comp.derivative_std(k), ...
        comp.derivative_RMS(k),comp.derivative_p95_abs(k), ...
        comp.derivative_max_abs(k),comp.derivative_rho1(k),comp.derivative_rho10(k));
end
fprintf(fid,'\n导数缺陷的 zero-lag signed correlation：\n\n');
fprintf(fid,'|Input|Residual|current|full|abs correlation reduction|\n');
fprintf(fid,'|:--|:--|--:|--:|--:|\n');
for k=1:height(corr)
    fprintf(fid,'|%s|%s|%.6g|%.6g|%.6g%%|\n',corr.Input(k),corr.Residual(k), ...
        corr.CurrentZeroLag(k),corr.FullZeroLag(k), ...
        corr.AbsoluteCorrelationReductionPercent(k));
end

fprintf(fid,'\n### 等效总力、横摆力矩和前后轴缺陷\n\n');
fprintf(fid,'`Fy_total_true_equiv=m*Ay_true`，没有重复用 `m*(dVy/dt+Vx*r)` 构造。`Mz_true_equiv=Iz*gradient(r_true)`。\n\n');
fprintf(fid,'|Quantity|Unit|mean|RMS|p95 abs|max abs|rho1|rho10|corr steer|corr Ay|corr r|corr dr|\n');
fprintf(fid,'|:--|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(force)
    fprintf(fid,'|%s|%s|%.8g|%.8g|%.8g|%.8g|%.5g|%.5g|%.5g|%.5g|%.5g|%.5g|\n', ...
        force.Quantity(k),force.Unit(k),force.mean(k),force.RMS(k), ...
        force.p95_abs(k),force.max_abs(k),force.rho1(k),force.rho10(k), ...
        force.corr_front_mean_steer(k),force.corr_Ay_true(k), ...
        force.corr_r_true(k),force.corr_dr_true_dt(k));
end
fprintf(fid,'\n前后轴重构是 bicycle-equivalent offline diagnostic，不是 CarSim 真实轮胎力，也不是新估计模型。\n\n');
fprintf(fid,'|Axle|equiv RMS|model RMS|defect mean|defect RMS|corr steer|peak corr|lag|gain|offset|model-equiv corr|\n');
fprintf(fid,'|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(axle)
    fprintf(fid,'|%s|%.8g|%.8g|%.8g|%.8g|%.6g|%.6g|%d|%.6g|%.6g|%.6g|\n', ...
        axle.Axle(k),axle.Equiv_RMS(k),axle.Model_RMS(k),axle.Defect_mean(k), ...
        axle.Defect_RMS(k),axle.DefectSteerCorr0(k),axle.DefectSteerPeakCorr(k), ...
        axle.DefectSteerPeakLagSamples(k),axle.ModelVsEquivGain(k), ...
        axle.ModelVsEquivOffset(k),axle.ModelVsEquivCorr(k));
end

fprintf(fid,'\n### Full-geometry 新增项量级\n\n');
fprintf(fid,'|Term|force RMS N|force/model|moment RMS Nm|moment/model|\n');
fprintf(fid,'|:--|--:|--:|--:|--:|\n');
for k=1:height(geometry)
    fprintf(fid,'|%s|%.9g|%.6g%%|%.9g|%.6g%%|\n',geometry.Term(k), ...
        geometry.Force_RMS_N(k),geometry.Force_percent_of_model_RMS(k), ...
        geometry.Moment_RMS_Nm(k),geometry.Moment_percent_of_model_RMS(k));
end
fprintf(fid,'\nFx 核查：\n\n|Wheel|RMS Fx N|max abs Fx N|\n|:--|--:|--:|\n');
for k=1:height(fx),fprintf(fid,'|%s|%.9g|%.9g|\n',fx.Wheel(k),fx.RMS_Fx_N(k),fx.MaxAbs_Fx_N(k));end
if c.fxEssentiallyZero
    fprintf(fid,'\n`lambda=zeros(4,1)` 下 Fx 数值上为0。full geometry 真正新增主要是后轮 steering cosine 和 `-y*Fxb` track yaw moment。\n');
end

fprintf(fid,'\n### 左右转向条件偏差\n\n');
fprintf(fid,'|Group|N|DeltaFy mean/RMS|DeltaMz mean/RMS|DeltaFyf mean/RMS|DeltaFyr mean/RMS|\n');
fprintf(fid,'|:--|--:|:--|:--|:--|:--|\n');
for k=1:height(direction)
    fprintf(fid,'|%s|%d|%.7g / %.7g|%.7g / %.7g|%.7g / %.7g|%.7g / %.7g|\n', ...
        direction.Group(k),direction.N(k),direction.DeltaFy_current_mean(k), ...
        direction.DeltaFy_current_RMS(k),direction.DeltaMz_current_mean(k), ...
        direction.DeltaMz_current_RMS(k),direction.DeltaFyf_mean(k), ...
        direction.DeltaFyf_RMS(k),direction.DeltaFyr_mean(k),direction.DeltaFyr_RMS(k));
end

fprintf(fid,'\n### 时滞、转向速率与 hysteresis\n\n');
sel=lag(lag.Model=="Current"&(lag.Input=="FrontMeanSteer"| ...
    lag.Input=="Ay_true"|lag.Input=="r_true"|lag.Input=="dr_true_dt"),:);
fprintf(fid,'|Input|Residual|peak corr|lag samples|lag seconds|\n');
fprintf(fid,'|:--|:--|--:|--:|--:|\n');
for k=1:height(sel)
    fprintf(fid,'|%s|%s|%.6g|%d|%.4g|\n',sel.Input(k),sel.Residual(k), ...
        sel.PeakCorrelation(k),sel.LagSamples(k),sel.LagSeconds(k));
end
fprintf(fid,'\n|Axle|valid bins|separation RMS|normalized hysteresis index|possible evidence|\n');
fprintf(fid,'|:--|--:|--:|--:|:--:|\n');
for k=1:height(hyst)
    fprintf(fid,'|%s|%d|%.7g|%.6g|%s|\n',hyst.Axle(k),hyst.ValidSteerBins(k), ...
        hyst.IncreasingDecreasingMeanSeparationRMS(k), ...
        hyst.NormalizedHysteresisIndex(k),yesno(hyst.PossibleDynamicHysteresis(k)));
end
rateRows=condition(condition.Section=="AbsSteeringRate",:);
fprintf(fid,'\nsteering-rate tertiles：\n\n|Group|N|wVy current/full RMS|wr current/full RMS|\n');
fprintf(fid,'|:--|--:|:--|:--|\n');
for k=1:height(rateRows)
    fprintf(fid,'|%s|%d|%.7g / %.7g|%.7g / %.7g|\n',rateRows.Group(k), ...
        rateRows.N(k),rateRows.wVy_current_RMS(k),rateRows.wVy_full_RMS(k), ...
        rateRows.wr_current_RMS(k),rateRows.wr_full_RMS(k));
end

fprintf(fid,'\n## V1.9 最终回答\n\n');
fprintf(fid,'1. 当前失配是否主要来自力/力矩几何遗漏：**%s**。DeltaFy/DeltaMz RMS reduction=%.6g%% / %.6g%%。\n',yesno(c.geometryMagnitudeSufficient),c.deltaFyReductionPercent,c.deltaMzReductionPercent);
fprintf(fid,'2. full geometry 是否显著降低 Vy residual：**%s**（%.6g%%）。\n',yesno(c.geometrySignificantVy),c.vyResidualReductionPercent);
fprintf(fid,'3. full geometry 是否显著降低 r residual：**%s**（%.6g%%）。\n',yesno(c.geometrySignificantR),c.rResidualReductionPercent);
fprintf(fid,'4. signed steering correlation 绝对值变化：Vy %.6g%%，r %.6g%%。\n',c.signedCorrelationReductionVy,c.signedCorrelationReductionR);
fprintf(fid,['5. full candidate 后是否仍存在非零相位结构/高度有色残差：', ...
    '**%s / %s**。'],yesno(c.phaseLagRemains),yesno(c.coloredResidualRemains));
if c.lagPeakAtSearchBoundary
    fprintf(fid,' 部分峰值命中 +/-20 样本边界，因此本阶段不把峰值 lag 解释为精确物理时延。\n');
else
    fprintf(fid,'\n');
end
fprintf(fid,'6. 左右转向是否存在近似反对称条件bias：**%s**。\n',yesno(c.antisymmetricConditionalBias));
fprintf(fid,'7. V1.10 优先方向：**%s**；次级线索：**%s**。\n',c.nextPriority,c.secondaryPriority);
fprintf(fid,'8. 当前误差首先表现为：**%s**（relative RMS %.6g / %.6g）。\n',c.primaryPhysicalMismatch,c.totalForceRelativeDefect,c.yawMomentRelativeDefect);
fprintf(fid,'9. bicycle-equivalent 前后轴分解中模型残差更大的车轴：**%s**。\n',c.largerAxle);
fprintf(fid,'10. geometry candidate 新增项量级是否足以解释当前残差：**%s**。最大 force/moment correction 为当前模型 RMS 的 %.6g%% / %.6g%%。\n',yesno(c.geometryMagnitudeSufficient),c.maxGeometryForcePercent,c.maxGeometryMomentPercent);
fprintf(fid,'11. 下一阶段最应检查：**%s**；然后检查 **%s**。名义 prediction 残差不使用 Jacobian，因此 numerical Jacobian 不是本轮缺陷的直接来源。\n',c.nextPriority,c.secondaryPriority);
fprintf(fid,'\n残差对 steering amplitude/rate 的增长比为 %.6g / %.6g，当前更强依赖 **%s**。\n',c.amplitudeGrowth,c.rateGrowth,c.strongerDependence);

fprintf(fid,'\n## 产物\n\n');
for k=1:numel(varargin),fprintf(fid,'- `%s`\n',varargin{k});end
names=fieldnames(figures);for k=1:numel(names),fprintf(fid,'- `%s`\n',figures.(names{k}));end
fprintf(fid,'- `%s.m`\n',mfilename('fullpath'));
fprintf(fid,'- `%s`\n',fullfile(fileparts(mfilename('fullpath')),'vy_dekf_v1_9_prediction_audit.m'));
fprintf(fid,'\n**NO MODEL CORRECTION WAS APPLIED ONLINE.**\n\n');
fprintf(fid,'**Q AND R WERE FIXED.**\n\n');
fprintf(fid,'**THIS WAS AN OFFLINE MODEL-MISMATCH ABLATION ONLY.**\n');
clear cleanup;
end
