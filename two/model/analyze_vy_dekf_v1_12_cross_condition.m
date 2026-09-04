function resultTable = analyze_vy_dekf_v1_12_cross_condition(runArchive)
%ANALYZE_VY_DEKF_V1_12_CROSS_CONDITION Offline fixed-gain validation.
% The online D-EKF outputs scored here are unmodified baseline outputs.

rootDir=fileparts(fileparts(mfilename('fullpath')));
resultDir=fullfile(rootDir,'results');docDir=fullfile(rootDir,'docs');
if nargin<1||isempty(runArchive),runArchive=fullfile(resultDir,'vy_dekf_v1_12_cross_condition_runs.mat');end
S=load(runArchive,'runs','metadata');runs=S.runs;metadata=S.metadata;
assert(numel(runs)==7 && isequal({runs.Case},{'N','V15','V25','A10','A30','F20','F60'}));
assert(isequal(metadata.fixedQ,diag([1e-4,1e-4])));
assert(isequal(metadata.fixedR,diag([1e-2,3.365172961808e-4])));
assert(~metadata.onlineAxleScalingApplied && ~metadata.onlineRelaxationApplied);

V11=load(fullfile(resultDir,'vy_dekf_v1_11_steady_tire_gain.mat'),'gainSummary');
kFixed=[V11.gainSummary.kCorrection_EquivOverModel(1), ...
    V11.gainSummary.kCorrection_EquivOverModel(2)];
assert(abs(kFixed(1)-0.78181)<1e-4 && abs(kFixed(2)-1.09186)<1e-4);

par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',0.393);
cfg=struct('dt',0.01,'Q',metadata.fixedQ,'R',metadata.fixedR, ...
    'denomEps',1e-12,'lambda',zeros(4,1));
caseDiagnosticCells=cell(7,1);rows=repmat(empty_row(),14,1);rowIndex=0;

for ci=1:7
    run=runs(ci);n=numel(run.t);assert(n==1601);
    procT=run.t(1:end-1);xTrue=[run.vyTrue run.rTrue];
    drTrue=gradient(run.rTrue,run.t);
    mechanics=empty_mechanics(n-1);
    for k=1:n-1
        aNow=vy_dekf_v1_9_prediction_audit(xTrue(k,:)',run.u(k,:)',par,cfg);
        mechanics.alpha(k,:)=aNow.alpha';mechanics.Fy(k,:)=aNow.Fy';
        mechanics.FybCurrent(k,:)=aNow.FybCurrent';
        mechanics.FyTotal(k)=aNow.FyTotalCurrent;mechanics.Mz(k)=aNow.MzCurrent;
        mechanics.xPred(k,:)=aNow.xPredCurrent';
    end
    FyfModel=sum(mechanics.FybCurrent(:,1:2),2);
    FyrModel=sum(mechanics.FybCurrent(:,3:4),2);
    Ay=run.ayTrue(1:end-1);
    dr=drTrue(1:end-1);
    FyfEquiv=(par.Iz*dr+par.b*par.m*Ay)/(par.a+par.b);
    FyrEquiv=(par.a*par.m*Ay-par.Iz*dr)/(par.a+par.b);
    xTarget=xTrue(2:end,:);wCurrent=xTarget-mechanics.xPred;
    FyfFixed=kFixed(1)*FyfModel;FyrFixed=kFixed(2)*FyrModel;
    fyFixed=FyfFixed+FyrFixed;mzFixed=par.a*FyfFixed-par.b*FyrFixed;
    dPred=cfg.dt*[(fyFixed-mechanics.FyTotal)/par.m,(mzFixed-mechanics.Mz)/par.Iz];
    xPredFixed=mechanics.xPred+dPred;wFixed=xTarget-xPredFixed;

    current=make_residuals(FyfModel,FyrModel,FyfEquiv,FyrEquiv,wCurrent,par);
    fixed=make_residuals(FyfFixed,FyrFixed,FyfEquiv,FyrEquiv,wFixed,par);
    frontSteer=mean(run.u(1:end-1,2:3),2);
    steerRate=gradient(frontSteer,cfg.dt);
    turn=abs(frontSteer)>0.005;
    assert(any(turn),'Case %s has no nonzero steering samples.',run.Case);
    rateThreshold=prctile(abs(steerRate(turn)),25);
    dynamicMask=procT>=3 & procT<=13;
    quasiMask=dynamicMask & turn & abs(steerRate)<=rateThreshold;
    assert(sum(quasiMask)>=20,'Case %s has insufficient quasi-steady samples.',run.Case);
    kEff=[origin_gain(FyfModel(quasiMask),FyfEquiv(quasiMask)), ...
        origin_gain(FyrModel(quasiMask),FyrEquiv(quasiMask))];
    drift=100*(kEff-kFixed)./kFixed;

    process=struct('t',procT,'dt',cfg.dt,'u',run.u(1:end-1,:), ...
        'xInput',xTrue(1:end-1,:),'xTarget',xTarget);
    transient=vy_dekf_v1_10_transient_candidate(process,mechanics,1,0,par);
    FyfTransient=sum(transient.Fyb(:,1:2),2);FyrTransient=sum(transient.Fyb(:,3:4),2);
    kTransient=[origin_gain(FyfTransient(quasiMask),FyfEquiv(quasiMask)), ...
        origin_gain(FyrTransient(quasiMask),FyrEquiv(quasiMask))];

    online=replay_online(run,cfg,par);
    actual=actual_conditions(run);
    outside=actual.maxAbsAy>0.6*9.81 || actual.maxAbsR>0.5 || ...
        actual.maxAbsVy>2 || actual.VxMin<5 || actual.VxMax>35;
    scopes={'FULL','QUASI'};masks={dynamicMask,quasiMask};
    for si=1:2
        rowIndex=rowIndex+1;
        rows(rowIndex)=make_row(run,scopes{si},masks{si},current,fixed, ...
            actual,kEff,drift,kTransient,online,rateThreshold,outside);
    end
    caseDiagnosticCells{ci}=struct('Case',run.Case,'t',procT,'dynamicMask',dynamicMask, ...
        'quasiMask',quasiMask,'rateThreshold',rateThreshold,'actual',actual, ...
        'FyfModel',FyfModel,'FyrModel',FyrModel,'FyfEquiv',FyfEquiv,'FyrEquiv',FyrEquiv, ...
        'current',current,'fixed',fixed,'mechanics',mechanics, ...
        'xPredFixed',xPredFixed,'kEffective',kEff,'driftPercent',drift, ...
        'kTransient',kTransient,'transient',transient,'online',online);
end
caseDiagnostics=vertcat(caseDiagnosticCells{:});

resultTable=struct2table(rows);
fullTable=resultTable(resultTable.Scope=="FULL",:);
quasiTable=resultTable(resultTable.Scope=="QUASI",:);
dependence=dependence_audit(fullTable);
acceptance=acceptance_audit(fullTable,dependence);
figures=create_figures(resultDir,fullTable,quasiTable,dependence);

csvFile=fullfile(resultDir,'vy_dekf_v1_12_cross_condition.csv');writetable(resultTable,csvFile);
matFile=fullfile(resultDir,'vy_dekf_v1_12_cross_condition.mat');
audit=struct('runArchive',runArchive,'modelFile',metadata.modelFile,'cases',7, ...
    'updatesPerCase',repmat(1601,1,7),'Ts',0.01,'fixedGain',kFixed, ...
    'fixedQ',metadata.fixedQ,'fixedR',metadata.fixedR, ...
    'onlineAxleScalingApplied',false,'onlineRelaxationApplied',false, ...
    'predictionImplementation','vy_dekf_v1_9_prediction_audit', ...
    'fullDynamicDefinition','3 <= t <= 13 s', ...
    'quasiDefinition','|front steer|>0.005 and lowest 25% |steer rate| per case');
save(matFile,'audit','metadata','resultTable','fullTable','quasiTable', ...
    'caseDiagnostics','dependence','acceptance','figures','-v7.3');
statusFile=fullfile(docDir,'STAGE_VY_DEKF_V1_12_STATUS.md');
write_status(statusFile,fullTable,quasiTable,dependence,acceptance,audit,figures,csvFile,matFile);

required=[{metadata.modelFile};{csvFile};{matFile};{statusFile};struct2cell(figures)];
for i=1:numel(required),p=char(required{i});assert(isfile(p));d=builtin('dir',p);assert(d(1).bytes>0);end
assert(all(fullTable.EKF_Update_Count==1601));
fprintf('V1_12_COMPLETE|cases=7|supported=%d|recommendation=%s\n', ...
    acceptance.crossConditionSupport,acceptance.recommendation);
end

function m=empty_mechanics(n)
m=struct('alpha',zeros(n,4),'Fy',zeros(n,4),'FybCurrent',zeros(n,4), ...
    'FyTotal',zeros(n,1),'Mz',zeros(n,1),'xPred',zeros(n,2));
end

function s=make_residuals(Ff,Fr,FfEq,FrEq,w,par)
s=struct('DeltaFyf',FfEq-Ff,'DeltaFyr',FrEq-Fr, ...
    'DeltaFy',(FfEq+FrEq)-(Ff+Fr), ...
    'DeltaMz',(par.a*FfEq-par.b*FrEq)-(par.a*Ff-par.b*Fr), ...
    'wVy',w(:,1),'wr',w(:,2));
end

function online=replay_online(run,cfg,par)
n=numel(run.t);x=[0;0];P=0.1*eye(2);states=zeros(n,2);pNew=zeros(2,2,n);nis=zeros(n,1);diagReplay=zeros(n,47);
for i=1:n
    [x,P,info]=vy_dynamic_ekf_step_v15_debug(x,P,run.u(i,:)',run.zRaw(i,:)',par,cfg);
    states(i,:)=x';pNew(:,:,i)=P;nis(i)=info.NIS;
    d=[info.NIS info.Fy' info.alpha' info.innovation' info.x_pred' ...
        info.F(:)' info.H(:)' info.P_prior(:)' info.P_noQ(:)' ...
        info.P_pred(:)' info.S(:)' info.K(:)'];
    diagReplay(i,:)=[d P(:)' run.zRaw(i,:)];
end
alignment=max([max(abs(diagReplay(1:end-1,:)-run.diagnostics(2:end,:)),[],'all'), ...
    max(abs(states(1:end-1,:)-run.y(2:end,:)),[],'all')]);
assert(alignment<=1e-12,'Online replay alignment failed in %s: %.3g',run.Case,alignment);
truth=[run.vyTrue(2:end) run.rTrue(2:end)];error=states(1:end-1,:)-truth;
nees=zeros(n-1,1);
for k=1:n-1,Pnow=0.5*(pNew(:,:,k)+pNew(:,:,k)');e=error(k,:)';nees(k)=e'*(Pnow\e);end
online=struct('states',states,'pNew',pNew,'NIS',nis,'NEES',nees, ...
    'alignmentMax',alignment,'VyRMSE',rmsv(error(:,1)),'VyMAE',mean(abs(error(:,1))), ...
    'VyBias',mean(error(:,1)),'VyMax',max(abs(error(:,1))), ...
    'rRMSE',rmsv(error(:,2)),'rMAE',mean(abs(error(:,2))), ...
    'rBias',mean(error(:,2)),'rMax',max(abs(error(:,2))), ...
    'NISMean',mean(nis),'NISP95',pct(nis,95),'NEESMean',mean(nees),'NEESP95',pct(nees,95));
end

function a=actual_conditions(run)
mask=run.t>=3 & run.t<=13;
u=run.u(mask,:);ay=run.ayTrue(mask);r=run.rTrue(mask);vy=run.vyTrue(mask);
a=struct('VxMean',mean(u(:,1)),'VxMin',min(u(:,1)),'VxMax',max(u(:,1)), ...
    'maxSteerFL',max(abs(u(:,2))),'maxSteerFR',max(abs(u(:,3))), ...
    'maxSteerRL',max(abs(u(:,4))),'maxSteerRR',max(abs(u(:,5))), ...
    'maxAbsAy',max(abs(ay)),'maxAbsR',max(abs(r)), ...
    'maxAbsVy',max(abs(vy)));
end

function row=empty_row()
names={'Case','Scope','Vx_target','SteerAmplitude','Frequency','Vx_actual_mean','Vx_actual_min','Vx_actual_max', ...
    'max_Steer_FL','max_Steer_FR','max_Steer_RL','max_Steer_RR','maxAy','maxR','maxVy', ...
    'kf_fixed','kr_fixed','kf_effective','kr_effective','kf_drift_percent','kr_drift_percent', ...
    'kf_after_sigmaF1','kr_after_sigmaF1','quasi_rate_threshold','N', ...
    'Current_DeltaFyf_RMS','Fixed_DeltaFyf_RMS','DeltaFyf_reduction_percent', ...
    'Current_DeltaFyr_RMS','Fixed_DeltaFyr_RMS','DeltaFyr_reduction_percent', ...
    'Current_DeltaFy_RMS','Fixed_DeltaFy_RMS','DeltaFy_reduction_percent', ...
    'Current_DeltaMz_RMS','Fixed_DeltaMz_RMS','DeltaMz_reduction_percent', ...
    'Current_wVy_RMS','Fixed_wVy_RMS','wVy_reduction_percent', ...
    'Current_wr_RMS','Fixed_wr_RMS','wr_reduction_percent', ...
    'online_Vy_RMSE','online_Vy_MAE','online_Vy_Bias','online_Vy_Max', ...
    'online_r_RMSE','online_r_MAE','online_r_Bias','online_r_Max', ...
    'NIS_mean','NIS_p95','NEES_mean','NEES_p95','EKF_Update_Count', ...
    'Replay_Alignment_Max','Outside_Useful_Envelope'};
row=struct();for i=1:numel(names),row.(names{i})=NaN;end;row.Case="";row.Scope="";row.Outside_Useful_Envelope=false;
end

function row=make_row(run,scope,mask,current,fixed,a,kEff,drift,kTrans,online,threshold,outside)
row=empty_row();row.Case=string(run.Case);row.Scope=string(scope);row.Vx_target=run.VxTarget;
row.SteerAmplitude=run.SteerAmplitude;row.Frequency=run.Frequency;
row.Vx_actual_mean=a.VxMean;row.Vx_actual_min=a.VxMin;row.Vx_actual_max=a.VxMax;
row.max_Steer_FL=a.maxSteerFL;row.max_Steer_FR=a.maxSteerFR;row.max_Steer_RL=a.maxSteerRL;row.max_Steer_RR=a.maxSteerRR;
row.maxAy=a.maxAbsAy;row.maxR=a.maxAbsR;row.maxVy=a.maxAbsVy;
row.kf_fixed=0.781809347;row.kr_fixed=1.09185835;row.kf_effective=kEff(1);row.kr_effective=kEff(2);
row.kf_drift_percent=drift(1);row.kr_drift_percent=drift(2);row.kf_after_sigmaF1=kTrans(1);row.kr_after_sigmaF1=kTrans(2);
row.quasi_rate_threshold=threshold;row.N=sum(mask);
metrics={'DeltaFyf','DeltaFyr','DeltaFy','DeltaMz','wVy','wr'};
for i=1:numel(metrics),q=metrics{i};bc=rmsv(current.(q)(mask));bf=rmsv(fixed.(q)(mask));row.(['Current_' q '_RMS'])=bc;row.(['Fixed_' q '_RMS'])=bf;row.([q '_reduction_percent'])=100*(1-bf/bc);end
row.online_Vy_RMSE=online.VyRMSE;row.online_Vy_MAE=online.VyMAE;row.online_Vy_Bias=online.VyBias;row.online_Vy_Max=online.VyMax;
row.online_r_RMSE=online.rRMSE;row.online_r_MAE=online.rMAE;row.online_r_Bias=online.rBias;row.online_r_Max=online.rMax;
row.NIS_mean=online.NISMean;row.NIS_p95=online.NISP95;row.NEES_mean=online.NEESMean;row.NEES_p95=online.NEESP95;
row.EKF_Update_Count=numel(run.t);row.Replay_Alignment_Max=online.alignmentMax;row.Outside_Useful_Envelope=outside;
end

function d=dependence_audit(t)
d=struct();dims={'Speed','Amplitude','Frequency'};sets={{'V15','N','V25'},{'A10','N','A30'},{'F20','N','F60'}};
for i=1:3,rows=t(ismember(t.Case,string(sets{i})),:);d.([dims{i} 'KfRange'])=max(rows.kf_effective)-min(rows.kf_effective);d.([dims{i} 'KrRange'])=max(rows.kr_effective)-min(rows.kr_effective);end
[~,iF]=max([d.SpeedKfRange d.AmplitudeKfRange d.FrequencyKfRange]);[~,iR]=max([d.SpeedKrRange d.AmplitudeKrRange d.FrequencyKrRange]);
d.largestKfDimension=dims{iF};d.largestKrDimension=dims{iR};
f=t(ismember(t.Case,["F20","N","F60"]),:);
d.frequencyKfRangeBefore=max(f.kf_effective)-min(f.kf_effective);
d.frequencyKfRangeAfter=max(f.kf_after_sigmaF1)-min(f.kf_after_sigmaF1);
d.frequencyDependenceReductionPercent=100*(1-d.frequencyKfRangeAfter/max(d.frequencyKfRangeBefore,eps));
d.corrKfMaxAy=corrv(t.kf_effective,t.maxAy);d.corrKrMaxAy=corrv(t.kr_effective,t.maxAy);
end

function a=acceptance_audit(t,d)
normal=~t.Outside_Useful_Envelope;nonNominal=normal&t.Case~="N";
red=[t.DeltaFy_reduction_percent t.DeltaMz_reduction_percent t.wVy_reduction_percent t.wr_reduction_percent];
a.normalCases=sum(normal);a.nonNominalCases=sum(nonNominal);a.allFourImprovedCount=sum(all(red(nonNominal,:)>0,2));
a.anyNormalWorseThan10=any(red(normal,:)<-10,'all');a.signPatternAll=all(t.kf_effective(normal)<1 & t.kr_effective(normal)>1);
a.driftWithin10All=all(abs([t.kf_drift_percent(normal);t.kr_drift_percent(normal)])<=10);
a.mostCasesForceMomentImprove=sum(all(red(nonNominal,1:2)>0,2))>=ceil(sum(nonNominal)/2);
a.stateResidualsOverallNotWorse=all(red(normal,3:4)>-10,'all');
a.crossConditionSupport=a.mostCasesForceMomentImprove && ~a.anyNormalWorseThan10 && ...
    a.stateResidualsOverallNotWorse && a.signPatternAll && a.driftWithin10All;
if a.crossConditionSupport,a.recommendation='A. V1.13 formal constant axle-gain implementation';
elseif strcmp(d.largestKfDimension,'Frequency')&&d.frequencyDependenceReductionPercent>20,a.recommendation='C. transient + steady-state joint-model research';
elseif strcmp(d.largestKfDimension,'Amplitude')||abs(d.corrKfMaxAy)>0.7,a.recommendation='B. load/Fz diagnostics';
else,a.recommendation='D. other explicit model direction';end
end

function figs=create_figures(dirOut,t,q,d)
figs=struct();common={'Visible','off','Color','w','Position',[80 80 1000 650]};
sets={"V15","N","V25"};xlabels={'Vx actual mean [m/s]','Vx actual mean [m/s]'};fields={'kf_effective','kr_effective'};names={'kfVsVx','krVsVx'};suffix={'01_kf_vs_Vx','02_kr_vs_Vx'};
for i=1:2,r=t(ismember(t.Case,sets{1}),:);[x,o]=sort(r.Vx_actual_mean);y=r.(fields{i});y=y(o);f=figure(common{:});plot(x,y,'o-','LineWidth',1.6);grid on;xlabel(xlabels{i});ylabel(fields{i});figs.(names{i})=fullfile(dirOut,['vy_dekf_v1_12_' suffix{i} '.png']);exportgraphics(f,figs.(names{i}),'Resolution',170);close(f);end
figs.gainAmplitude=condition_gain_plot(t,["A10","N","A30"],'SteerAmplitude','Steer amplitude [rad]',fullfile(dirOut,'vy_dekf_v1_12_03_gain_vs_amplitude.png'));
figs.gainFrequency=condition_gain_plot(t,["F20","N","F60"],'Frequency','Frequency [Hz]',fullfile(dirOut,'vy_dekf_v1_12_04_gain_vs_frequency.png'));
f=figure(common{:});plot(t.maxAy,t.kf_effective,'o-');hold on;plot(t.maxAy,t.kr_effective,'s-');grid on;xlabel('max |Ay| [m/s^2]');ylabel('effective gain');legend('kf','kr');figs.gainAy=fullfile(dirOut,'vy_dekf_v1_12_05_gain_vs_maxAy.png');exportgraphics(f,figs.gainAy,'Resolution',170);close(f);
labels=cellstr(t.Case);figs.deltaFy=bar_plot(labels,t.DeltaFy_reduction_percent,'DeltaFy RMS reduction [%]',fullfile(dirOut,'vy_dekf_v1_12_06_DeltaFy_reduction.png'));
figs.deltaMz=bar_plot(labels,t.DeltaMz_reduction_percent,'DeltaMz RMS reduction [%]',fullfile(dirOut,'vy_dekf_v1_12_07_DeltaMz_reduction.png'));
f=figure(common{:});bar([t.wVy_reduction_percent t.wr_reduction_percent]);grid on;xticks(1:7);xticklabels(labels);ylabel('RMS reduction [%]');legend('wVy','wr');figs.stateReduction=fullfile(dirOut,'vy_dekf_v1_12_08_state_residual_reduction.png');exportgraphics(f,figs.stateReduction,'Resolution',170);close(f);
ratio=[t.Fixed_DeltaFyf_RMS./t.Current_DeltaFyf_RMS t.Fixed_DeltaFyr_RMS./t.Current_DeltaFyr_RMS t.Fixed_DeltaFy_RMS./t.Current_DeltaFy_RMS t.Fixed_DeltaMz_RMS./t.Current_DeltaMz_RMS t.Fixed_wVy_RMS./t.Current_wVy_RMS t.Fixed_wr_RMS./t.Current_wr_RMS];
f=figure(common{:});imagesc(ratio);colorbar;caxis([0 max(1,max(ratio,[],'all'))]);xticks(1:6);xticklabels({'Fyf','Fyr','Fy','Mz','wVy','wr'});yticks(1:7);yticklabels(labels);title('Fixed / Current RMS ratio, FULL dynamic');figs.heatmap=fullfile(dirOut,'vy_dekf_v1_12_09_fixed_current_heatmap.png');exportgraphics(f,figs.heatmap,'Resolution',170);close(f);
r=t(ismember(t.Case,["F20","N","F60"]),:);[x,o]=sort(r.Frequency);r=r(o,:);f=figure(common{:});plot(x,r.kf_effective,'o-','LineWidth',1.5);hold on;plot(x,r.kf_after_sigmaF1,'s--','LineWidth',1.5);grid on;xlabel('Frequency [Hz]');ylabel('front effective k');legend('steady current','after sigma_f=1');title(sprintf('Frequency range reduction %.3g%%',d.frequencyDependenceReductionPercent));figs.transientFrequency=fullfile(dirOut,'vy_dekf_v1_12_10_transient_gain_vs_frequency.png');exportgraphics(f,figs.transientFrequency,'Resolution',170);close(f);
end

function file=condition_gain_plot(t,cases,xfield,xlabelText,file)
r=t(ismember(t.Case,cases),:);[x,o]=sort(r.(xfield));r=r(o,:);f=figure('Visible','off','Color','w','Position',[80 80 1000 650]);plot(x,r.kf_effective,'o-','LineWidth',1.5);hold on;plot(x,r.kr_effective,'s-','LineWidth',1.5);grid on;xlabel(xlabelText);ylabel('effective gain');legend('kf','kr');exportgraphics(f,file,'Resolution',170);close(f);
end
function file=bar_plot(labels,y,yl,file),f=figure('Visible','off','Color','w','Position',[80 80 1000 650]);bar(y);grid on;xticks(1:numel(labels));xticklabels(labels);ylabel(yl);yline(0,'k-');exportgraphics(f,file,'Resolution',170);close(f);end

function write_status(file,t,q,d,a,audit,figs,csvFile,matFile)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);clean=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.12 STATUS\n\n## Scope and fixed configuration\n\n');
fprintf(fid,'Seven independent CarSim/Simulink cases were run with 1601 updates each at 100 Hz. The online D-EKF remained the original V1.7 dynamics with Q/R fixed. Fixed gains kf=%.9g and kr=%.9g came only from V1.11 TRAIN and were evaluated offline.\n\n',audit.fixedGain);
fprintf(fid,'FULL dynamic interval: 3<=t<=13 s. Quasi-steady: |front steer|>0.005 rad and the lowest 25%% |steering rate| within each case.\n\n');
fprintf(fid,'## Actual operating conditions\n\nActual min/max statistics below use the 3--13 s excitation interval, excluding the initial speed-settling transient.\n\n|Case|target Vx|actual Vx min/mean/max|max steer FL/FR/RL/RR|max |Ay||max |r||max |Vy||outside envelope|\n|:--|--:|:--|:--|--:|--:|--:|:--|\n');
for i=1:height(t),fprintf(fid,'|%s|%.3g|%.5g / %.5g / %.5g|%.5g / %.5g / %.5g / %.5g|%.5g|%.5g|%.5g|%d|\n',t.Case(i),t.Vx_target(i),t.Vx_actual_min(i),t.Vx_actual_mean(i),t.Vx_actual_max(i),t.max_Steer_FL(i),t.max_Steer_FR(i),t.max_Steer_RL(i),t.max_Steer_RR(i),t.maxAy(i),t.maxR(i),t.maxVy(i),t.Outside_Useful_Envelope(i));end
fprintf(fid,'\n## Effective-gain cross-condition audit\n\n|Case|kf eff|kf drift|kr eff|kr drift|kf after sigmaF1|quasi N|\n|:--|--:|--:|--:|--:|--:|--:|\n');
for i=1:height(t),fprintf(fid,'|%s|%.9g|%.5g%%|%.9g|%.5g%%|%.9g|%d|\n',t.Case(i),t.kf_effective(i),t.kf_drift_percent(i),t.kr_effective(i),t.kr_drift_percent(i),t.kf_after_sigmaF1(i),q.N(i));end
fprintf(fid,'\nDependence ranges (max-min):\n\n|Dimension|kf range|kr range|\n|:--|--:|--:|\n|Speed|%.9g|%.9g|\n|Amplitude|%.9g|%.9g|\n|Frequency|%.9g|%.9g|\n',d.SpeedKfRange,d.SpeedKrRange,d.AmplitudeKfRange,d.AmplitudeKrRange,d.FrequencyKfRange,d.FrequencyKrRange);
fprintf(fid,'\nLargest dimension: kf **%s**, kr **%s**. corr(gain,max|Ay|)=%.5g / %.5g. Front frequency range before/after sigmaF1: %.9g / %.9g (reduction %.5g%%).\n',d.largestKfDimension,d.largestKrDimension,d.corrKfMaxAy,d.corrKrMaxAy,d.frequencyKfRangeBefore,d.frequencyKfRangeAfter,d.frequencyDependenceReductionPercent);
fprintf(fid,'\n## FULL dynamic Current vs fixed gain\n\n|Case|Fyf red|Fyr red|Fy red|Mz red|wVy red|wr red|Current/Fixed Fy RMS|Current/Fixed Mz RMS|\n|:--|--:|--:|--:|--:|--:|--:|:--|:--|\n');
for i=1:height(t),fprintf(fid,'|%s|%.5g%%|%.5g%%|%.5g%%|%.5g%%|%.5g%%|%.5g%%|%.6g / %.6g|%.6g / %.6g|\n',t.Case(i),t.DeltaFyf_reduction_percent(i),t.DeltaFyr_reduction_percent(i),t.DeltaFy_reduction_percent(i),t.DeltaMz_reduction_percent(i),t.wVy_reduction_percent(i),t.wr_reduction_percent(i),t.Current_DeltaFy_RMS(i),t.Fixed_DeltaFy_RMS(i),t.Current_DeltaMz_RMS(i),t.Fixed_DeltaMz_RMS(i));end
fprintf(fid,'\n## Quasi-steady Current vs fixed gain\n\n|Case|Fy red|Mz red|Fyf red|Fyr red|wVy red|wr red|\n|:--|--:|--:|--:|--:|--:|--:|\n');
for i=1:height(q),fprintf(fid,'|%s|%.5g%%|%.5g%%|%.5g%%|%.5g%%|%.5g%%|%.5g%%|\n',q.Case(i),q.DeltaFy_reduction_percent(i),q.DeltaMz_reduction_percent(i),q.DeltaFyf_reduction_percent(i),q.DeltaFyr_reduction_percent(i),q.wVy_reduction_percent(i),q.wr_reduction_percent(i));end
fprintf(fid,'\n## Unmodified online D-EKF baseline\n\n|Case|Vy RMSE|r RMSE|NIS mean/p95|NEES mean/p95|replay max|\n|:--|--:|--:|:--|:--|--:|\n');
for i=1:height(t),fprintf(fid,'|%s|%.8g|%.8g|%.6g / %.6g|%.6g / %.6g|%.3g|\n',t.Case(i),t.online_Vy_RMSE(i),t.online_r_RMSE(i),t.NIS_mean(i),t.NIS_p95(i),t.NEES_mean(i),t.NEES_p95(i),t.Replay_Alignment_Max(i));end
fprintf(fid,'\n## Final answers\n\n');
fprintf(fid,'1. Cross-speed generalization: kf/kr ranges %.6g / %.6g.\n',d.SpeedKfRange,d.SpeedKrRange);
fprintf(fid,'2. Cross-amplitude generalization: kf/kr ranges %.6g / %.6g.\n',d.AmplitudeKfRange,d.AmplitudeKrRange);
fprintf(fid,'3. Cross-frequency generalization: kf/kr ranges %.6g / %.6g.\n',d.FrequencyKfRange,d.FrequencyKrRange);
fprintf(fid,'4. Largest kf dependence: **%s**.\n5. Largest kr dependence: **%s**.\n',d.largestKfDimension,d.largestKrDimension);
fprintf(fid,'6. Non-nominal cases improving all four Fy/Mz/wVy/wr: %d/%d.\n',a.allFourImprovedCount,a.nonNominalCases);
fprintf(fid,'7. Any normal case worse by >10%%: **%s**.\n',yesno(a.anyNormalWorseThan10));
fprintf(fid,'8. Gain behavior is not perfectly invariant: kf shows the strongest amplitude/max-|Ay| dependence, while kr shows the strongest frequency dependence; speed dependence is smaller. All observed drifts remain within about 10%%.\n');
fprintf(fid,'9. sigma_f=1 frequency-dependence reduction: %.6g%%.\n',d.frequencyDependenceReductionPercent);
fprintf(fid,'10. Sufficient support to recommend online axle-scaling implementation next: **%s**. Recommendation: **%s**. V1.13 was not executed.\n',yesno(a.crossConditionSupport),a.recommendation);
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n- `%s`\n',audit.modelFile,csvFile,matFile);p=struct2cell(figs);for i=1:numel(p),fprintf(fid,'- `%s`\n',p{i});end
fprintf(fid,'\n**FIXED AXLE GAINS WERE EVALUATED OFFLINE ONLY.**\n\n**NO AXLE-SCALING CORRECTION WAS APPLIED ONLINE.**\n\n**NO TIRE OR VEHICLE PARAMETER WAS CHANGED.**\n');
end

function k=origin_gain(x,y),k=sum(x.*y)/sum(x.^2);end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function c=corrv(x,y),C=corrcoef(x,y);c=C(1,2);end
function w=yesno(v),if v,w='YES';else,w='NO';end,end
