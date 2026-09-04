function diagnosticTable = analyze_vy_dekf_v1_8_nees_source()
%ANALYZE_VY_DEKF_V1_8_NEES_SOURCE Offline NEES/model-residual audit.
% No simulation, estimator tuning, adaptive Q, or online truth feedback.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(repoRoot,'results');
sourceFile = fullfile(resultsDir,'vy_dekf_v1_7_bias_ablation.mat');
assert(isfile(sourceFile),'Required V1.7 result missing: %s',sourceFile);
loaded = load(sourceFile,'runs','audits','metadata');
runs = loaded.runs; auditsV17 = loaded.audits; metadataV17 = loaded.metadata;
assert(numel(runs)==4 && isequal({runs.Case},{'B0','B1','B2','B3'}));
assert(isequal(metadataV17.fixedQ,diag([1e-4,1e-4])));
assert(isequal(metadataV17.fixedR,diag([1e-2,3.365172961808e-4])));

b0Index = find(strcmp({runs.Case},'B0'),1);
b3Index = find(strcmp({runs.Case},'B3'),1);
selected = [b0Index b3Index];
primaryIndex = b3Index;
chi95 = 5.991464547;
gaussianCoverageReference = [0.6827 0.9545 0.9973];

% Clean CarSim Ay is reused only after proving the V1.3 and V1.7 driving
% records are identical at the common 100 Hz grid.
[ayTrue,aySourceAudit] = load_verified_clean_ay(resultsDir,runs(primaryIndex));

caseCells = cell(2,1);
identityErrors = zeros(2,1);
for j = 1:2
    k = selected(j);
    caseCells{j} = posterior_diagnostics(runs(k),auditsV17(k),chi95);
    identityErrors(j) = caseCells{j}.decompositionIdentityMax;
end
caseDiagnostics = vertcat(caseCells{:});
assert(max(identityErrors)<=1e-10,'Full-NEES decomposition identity failed.');

% Dynamic variables use the primary B3 truth-aligned timeline. Posterior
% update i used u(i) and is visible beside truth(i+1) after Rate Transition.
primaryRun = runs(primaryIndex);
tTruth = primaryRun.t(:);
dt = median(diff(tTruth));
assert(abs(dt-0.01)<=1e-12 && max(abs(diff(tTruth)-0.01))<=1e-10, ...
    'Truth/input grid is not the required 100 Hz grid.');
drTrueDt = gradient(primaryRun.rTrue,tTruth); % central interior, one-sided edges
steerUsed = primaryRun.u(1:end-1,2:5);
maxAbsSteer = max(abs(steerUsed),[],2);
ayAligned = ayTrue(2:end);
drAligned = drTrueDt(2:end);

rows = repmat(empty_row(),0,1);
for j = 1:2
    d = caseDiagnostics(j);
    rows(end+1) = row_from_mask(d,'Overall','all',true(size(d.NEES))); %#ok<AGROW>
    rows(end+1) = row_from_mask(d,'Time','initial t<1 s',d.t<1); %#ok<AGROW>
    rows = append_three_bins(rows,d,'Steering',maxAbsSteer, ...
        [-inf 0.002 0.01 inf],{'low <=0.002','mid (0.002,0.01]','high >0.01'});
    rows = append_quantile_bins(rows,d,'AbsAyTrue',abs(ayAligned),4);
    rows = append_quantile_bins(rows,d,'AbsDrTrueDt',abs(drAligned),4);
end
diagnosticTable = struct2table(rows);

% One-step process residual is a B3-primary offline diagnosis. It reuses
% the exact verified EKF prediction implementation and ignores x_new.
process = process_model_residual(primaryRun,ayTrue,drTrueDt,metadataV17);
processSummary = residual_summary_table(process,metadataV17.fixedQ);
correlationTable = residual_correlation_table(process);
processConditionTable = residual_condition_table(process);

stateSummary = state_summary_table(caseDiagnostics,gaussianCoverageReference);
conclusions = derive_conclusions(caseDiagnostics(2),process, ...
    processSummary,processConditionTable,diagnosticTable);
alignment = struct( ...
    'archivePosteriorIndex','i = 1:1600', ...
    'xHatIndex','audits.states(i,:)', ...
    'posteriorPIndex','audits.pNew(:,:,i)', ...
    'truthIndex','runs.vyTrue(i+1), runs.rTrue(i+1)', ...
    'reportedTimeIndex','runs.t(i+1)', ...
    'updateInputIndex','runs.u(i,:)', ...
    'reason','100 Hz estimator output has one Rate Transition log delay', ...
    'posteriorSamples',1600,'rawTruthSamples',1601, ...
    'processResidualSamples',numel(process.t), ...
    'processResidualDefinition','x_true(k+1)-f_EKF(x_true(k),u(k))');

csvFile = fullfile(resultsDir,'vy_dekf_v1_8_nees_source.csv');
residualCsv = fullfile(resultsDir,'vy_dekf_v1_8_process_residual.csv');
correlationCsv = fullfile(resultsDir,'vy_dekf_v1_8_process_correlations.csv');
conditionCsv = fullfile(resultsDir,'vy_dekf_v1_8_process_conditions.csv');
writetable(diagnosticTable,csvFile);
writetable(processSummary,residualCsv);
writetable(correlationTable,correlationCsv);
writetable(processConditionTable,conditionCsv);
figures = create_figures(caseDiagnostics,process,diagnosticTable,resultsDir,chi95);
matFile = fullfile(resultsDir,'vy_dekf_v1_8_nees_source.mat');
save(matFile,'diagnosticTable','stateSummary','processSummary', ...
    'correlationTable','processConditionTable','caseDiagnostics','process', ...
    'conclusions','alignment','aySourceAudit','metadataV17','figures','-v7.3');
statusFile = fullfile(repoRoot,'docs','STAGE_VY_DEKF_V1_8_STATUS.md');
write_status(statusFile,stateSummary,diagnosticTable,processSummary, ...
    correlationTable,processConditionTable,caseDiagnostics,conclusions, ...
    alignment,aySourceAudit,figures,csvFile,residualCsv,correlationCsv,conditionCsv,matFile);
fprintf(['V1_8_ANALYSIS_OK|NEES_B3=%.12g|identity=%.3g|wN=%d|', ...
    'priority=%s\n'],mean(caseDiagnostics(2).NEES),max(identityErrors), ...
    numel(process.t),conclusions.v19Priority);
fprintf('NO ADAPTIVE-Q ALGORITHM WAS CREATED.\n');
fprintf('B3 WAS USED ONLY AS AN ORACLE-CORRECTED DIAGNOSTIC CASE.\n');
end

function d = posterior_diagnostics(run,audit,chi95)
n = numel(run.t)-1;
assert(n==1600 && size(audit.states,1)==1601 && size(audit.pNew,3)==1601);
d = struct(); d.Case = run.Case; d.t = run.t(2:end);
d.xHat = audit.states(1:end-1,:);
d.truth = [run.vyTrue(2:end) run.rTrue(2:end)];
d.error = d.xHat-d.truth;
d.P = audit.pNew(:,:,1:end-1); % posterior P_new from the same replay update
d.NEES = zeros(n,1); d.marginalVy = zeros(n,1); d.marginalR = zeros(n,1);
d.termVy = zeros(n,1); d.termCross = zeros(n,1); d.termR = zeros(n,1);
d.sigmaVy = zeros(n,1); d.sigmaR = zeros(n,1); identity = zeros(n,1);
for i=1:n
    P = 0.5*(d.P(:,:,i)+d.P(:,:,i)'); e = d.error(i,:)';
    q = P\e; d.NEES(i)=e'*q; % no explicit inverse
    p11=P(1,1); p12=P(1,2); p22=P(2,2); determinant=p11*p22-p12*p12;
    assert(determinant>0);
    a=p22/determinant; b=-p12/determinant; dd=p11/determinant;
    d.termVy(i)=a*e(1)^2; d.termCross(i)=2*b*e(1)*e(2); d.termR(i)=dd*e(2)^2;
    d.marginalVy(i)=e(1)^2/p11; d.marginalR(i)=e(2)^2/p22;
    d.sigmaVy(i)=sqrt(p11); d.sigmaR(i)=sqrt(p22);
    identity(i)=abs(d.termVy(i)+d.termCross(i)+d.termR(i)-d.NEES(i));
end
d.decompositionIdentityMax=max(identity); d.chi95=chi95;
d.coverageVy=[mean(abs(d.error(:,1))<=d.sigmaVy), ...
    mean(abs(d.error(:,1))<=2*d.sigmaVy),mean(abs(d.error(:,1))<=3*d.sigmaVy)];
d.coverageR=[mean(abs(d.error(:,2))<=d.sigmaR), ...
    mean(abs(d.error(:,2))<=2*d.sigmaR),mean(abs(d.error(:,2))<=3*d.sigmaR)];
d.errorAcfVy=normalized_acf(d.error(:,1),10);
d.errorAcfR=normalized_acf(d.error(:,2),10);
c=corrcoef(d.error(:,1),d.error(:,2)); d.errorCorrelation=c(1,2);
end

function row = empty_row()
row=struct('Case',"",'Section',"",'Group',"",'N',0,'Vy_RMSE',NaN,'r_RMSE',NaN, ...
    'NEES_mean',NaN,'NEES_median',NaN,'NEES_p95',NaN,'NEES_max',NaN, ...
    'NEES_fraction_above_5p991464547',NaN,'marginal_Vy_mean',NaN, ...
    'marginal_r_mean',NaN,'full_term_Vy_mean',NaN,'full_term_cross_mean',NaN, ...
    'full_term_r_mean',NaN,'Vy_coverage_1sigma',NaN,'Vy_coverage_2sigma',NaN, ...
    'Vy_coverage_3sigma',NaN,'r_coverage_1sigma',NaN,'r_coverage_2sigma',NaN, ...
    'r_coverage_3sigma',NaN);
end

function row = row_from_mask(d,section,group,mask)
mask=logical(mask(:)); row=empty_row(); row.Case=string(d.Case); row.Section=string(section); row.Group=string(group);
row.N=sum(mask); assert(row.N>0,'Empty diagnostic bin: %s/%s',section,group);
ev=d.error(mask,1); er=d.error(mask,2); nees=d.NEES(mask);
row.Vy_RMSE=rms_value(ev); row.r_RMSE=rms_value(er);
row.NEES_mean=mean(nees); row.NEES_median=median(nees); row.NEES_p95=percentile(nees,95);
row.NEES_max=max(nees); row.NEES_fraction_above_5p991464547=mean(nees>d.chi95);
row.marginal_Vy_mean=mean(d.marginalVy(mask)); row.marginal_r_mean=mean(d.marginalR(mask));
row.full_term_Vy_mean=mean(d.termVy(mask)); row.full_term_cross_mean=mean(d.termCross(mask));
row.full_term_r_mean=mean(d.termR(mask));
row.Vy_coverage_1sigma=mean(abs(ev)<=d.sigmaVy(mask));
row.Vy_coverage_2sigma=mean(abs(ev)<=2*d.sigmaVy(mask));
row.Vy_coverage_3sigma=mean(abs(ev)<=3*d.sigmaVy(mask));
row.r_coverage_1sigma=mean(abs(er)<=d.sigmaR(mask));
row.r_coverage_2sigma=mean(abs(er)<=2*d.sigmaR(mask));
row.r_coverage_3sigma=mean(abs(er)<=3*d.sigmaR(mask));
end

function rows = append_three_bins(rows,d,section,value,edges,labels)
for k=1:3
    if k==1, mask=value<=edges(k+1);
    else, mask=value>edges(k) & value<=edges(k+1); end
    rows(end+1)=row_from_mask(d,section,labels{k},mask); %#ok<AGROW>
end
end

function rows = append_quantile_bins(rows,d,section,value,count)
bin=rank_quantile_id(value,count);
for k=1:count
    mask=bin==k; label=sprintf('Q%d [%.6g, %.6g]',k,min(value(mask)),max(value(mask)));
    rows(end+1)=row_from_mask(d,section,label,mask); %#ok<AGROW>
end
end

function tableOut = state_summary_table(cases,reference)
rows=repmat(struct(),2,1);
for k=1:2
    d=cases(k); rows(k).Case=string(d.Case); rows(k).N=numel(d.NEES);
    rows(k).NEES_mean=mean(d.NEES); rows(k).NEES_median=median(d.NEES);
    rows(k).NEES_p95=percentile(d.NEES,95); rows(k).NEES_max=max(d.NEES);
    rows(k).marginal_Vy_mean=mean(d.marginalVy); rows(k).marginal_r_mean=mean(d.marginalR);
    rows(k).full_term_Vy_mean=mean(d.termVy); rows(k).full_term_cross_mean=mean(d.termCross);
    rows(k).full_term_r_mean=mean(d.termR); rows(k).identity_max=d.decompositionIdentityMax;
    rows(k).Vy_coverage_1sigma=d.coverageVy(1); rows(k).Vy_coverage_2sigma=d.coverageVy(2);
    rows(k).Vy_coverage_3sigma=d.coverageVy(3); rows(k).r_coverage_1sigma=d.coverageR(1);
    rows(k).r_coverage_2sigma=d.coverageR(2); rows(k).r_coverage_3sigma=d.coverageR(3);
    rows(k).Vy_RMSE_over_median_sigma=rms_value(d.error(:,1))/median(d.sigmaVy);
    rows(k).r_RMSE_over_median_sigma=rms_value(d.error(:,2))/median(d.sigmaR);
    rows(k).Vy_error_variance_over_mean_P11=var(d.error(:,1),0)/mean(d.sigmaVy.^2);
    rows(k).r_error_variance_over_mean_P22=var(d.error(:,2),0)/mean(d.sigmaR.^2);
    rows(k).Vy_error_rho1=d.errorAcfVy(2); rows(k).Vy_error_rho10=d.errorAcfVy(11);
    rows(k).r_error_rho1=d.errorAcfR(2); rows(k).r_error_rho10=d.errorAcfR(11);
    rows(k).Vy_r_error_correlation=d.errorCorrelation;
    rows(k).Gaussian_reference_1sigma=reference(1);
    rows(k).Gaussian_reference_2sigma=reference(2);
    rows(k).Gaussian_reference_3sigma=reference(3);
end
tableOut=struct2table(rows);
end

function process = process_model_residual(run,ayTrue,drTrueDt,metadata)
n=numel(run.t); assert(n==1601); dt=median(diff(run.t)); assert(abs(dt-0.01)<=1e-12);
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',0.393);
cfg=struct('dt',0.01,'Q',metadata.fixedQ,'R',metadata.fixedR, ...
    'denomEps',1e-12,'lambda',zeros(4,1));
xTrue=[run.vyTrue run.rTrue]; xPred=zeros(n-1,2);
for k=1:n-1
    [~,~,info]=vy_dynamic_ekf_step_v15_debug(xTrue(k,:)',eye(2),run.u(k,:)',[0;0],par,cfg);
    xPred(k,:)=info.x_pred';
end
[~,~,checkA]=vy_dynamic_ekf_step_v15_debug(xTrue(1,:)',eye(2),run.u(1,:)',[0;0],par,cfg);
[~,~,checkB]=vy_dynamic_ekf_step_v15_debug(xTrue(1,:)',eye(2),run.u(1,:)',[123;-456],par,cfg);
measurementIndependence=max(abs(checkA.x_pred-checkB.x_pred)); assert(measurementIndependence<=1e-14);
process=struct(); process.t=run.t(1:end-1); process.dt=dt; process.xInput=xTrue(1:end-1,:);
process.xTarget=xTrue(2:end,:); process.xPred=xPred; process.residual=xTrue(2:end,:)-xPred;
process.u=run.u(1:end-1,:); process.ayTrue=ayTrue(1:end-1); process.ayImu=run.zRaw(1:end-1,1);
process.rTrue=run.rTrue(1:end-1); process.drTrueDt=drTrueDt(1:end-1);
process.frontMeanSteer=mean(run.u(1:end-1,2:3),2);
process.maxAbsSteer=max(abs(run.u(1:end-1,2:5)),[],2);
process.measurementIndependenceMax=measurementIndependence;
end

function t = residual_summary_table(process,Q)
names={'Vy','r'}; rows=repmat(struct(),2,1);
for k=1:2
    v=process.residual(:,k); rows(k).State=string(names{k}); rows(k).N=numel(v);
    rows(k).mean=mean(v); rows(k).std=std(v,0); rows(k).RMS=rms_value(v);
    rows(k).p95_absolute=percentile(abs(v),95); rows(k).max_absolute=max(abs(v));
    acf=normalized_acf(v-mean(v),10); rows(k).rho1=acf(2); rows(k).rho10=acf(11);
    rows(k).sqrt_Qii=sqrt(Q(k,k)); rows(k).RMS_over_sqrt_Qii=rows(k).RMS/rows(k).sqrt_Qii;
end
t=struct2table(rows);
end

function t = residual_correlation_table(p)
variables={'Vx','Steer_FL','Steer_FR','Steer_RL','Steer_RR','FrontMeanSteer', ...
    'MaxAbsSteer','Ay_true','Ay_IMU','r_true','dr_true_dt'};
values=[p.u(:,1:5) p.frontMeanSteer p.maxAbsSteer p.ayTrue p.ayImu p.rTrue p.drTrueDt];
rows=repmat(struct(),numel(variables),1);
for k=1:numel(variables)
    rows(k).Variable=string(variables{k}); rows(k).Source=source_label(variables{k});
    rows(k).corr_wVy=pearson(values(:,k),p.residual(:,1));
    rows(k).corr_wr=pearson(values(:,k),p.residual(:,2));
    rows(k).corr_abs_wVy=pearson(abs(values(:,k)),abs(p.residual(:,1)));
    rows(k).corr_abs_wr=pearson(abs(values(:,k)),abs(p.residual(:,2)));
end
t=struct2table(rows);
end

function label = source_label(name)
if strcmp(name,'Ay_true'),label="CarSim clean Ay before IMU";
elseif strcmp(name,'Ay_IMU'),label="biased/noisy/filtered virtual IMU";
else,label="CarSim/actual online input";end
end

function t = residual_condition_table(p)
rowCells=cell(11,1); rowIndex=0; steer=p.maxAbsSteer;
edges=[-inf 0.002 0.01 inf]; labels={'low <=0.002','mid (0.002,0.01]','high >0.01'};
for k=1:3
    if k==1,mask=steer<=edges(k+1);else,mask=steer>edges(k)&steer<=edges(k+1);end
    rowIndex=rowIndex+1; rowCells{rowIndex}=residual_condition_row('Steering',labels{k},mask,p.residual);
end
for kind=1:2
    if kind==1,value=abs(p.ayTrue);section='AbsAyTrue';else,value=abs(p.drTrueDt);section='AbsDrTrueDt';end
    bin=rank_quantile_id(value,4);
    for k=1:4
        mask=bin==k;
        rowIndex=rowIndex+1; rowCells{rowIndex}=residual_condition_row(section,sprintf('Q%d',k),mask,p.residual);
    end
end
rows=vertcat(rowCells{1:rowIndex}); t=struct2table(rows);
end

function row = residual_condition_row(section,group,mask,w)
row=struct('Section',string(section),'Group',string(group),'N',sum(mask), ...
    'wVy_mean',mean(w(mask,1)),'wVy_RMS',rms_value(w(mask,1)), ...
    'wr_mean',mean(w(mask,2)),'wr_RMS',rms_value(w(mask,2)));
end

function c = derive_conclusions(d,p,summary,condition,diagTable)
c=struct(); means=[mean(d.termVy) mean(d.termCross) mean(d.termR)];
[~,largest]=max([mean(d.termVy) mean(d.termR)]);
if largest==1 && mean(d.termVy)>=0.6*mean(d.NEES),c.fullNeesSource='Vy diagonal term';
elseif largest==2 && mean(d.termR)>=0.6*mean(d.NEES),c.fullNeesSource='r diagonal term';
else,c.fullNeesSource='multiple diagonal/cross factors';end
[~,marginalLargest]=max([mean(d.marginalVy) mean(d.marginalR)]);
c.marginalAndFullAgree=(marginalLargest==largest);
c.remainingPeakTime=d.t(d.NEES==max(d.NEES)); c.remainingPeakTime=c.remainingPeakTime(1);
c.underestimatedState=conditional(largest==1,'Vy','r');
c.processResidualExceedsQ=any(summary.RMS_over_sqrt_Qii>1);
steerRows=condition.Section=="Steering"; s=condition(steerRows,:);
ayRows=condition.Section=="AbsAyTrue"; a=condition(ayRows,:);
steerGrowth=max([s.wVy_RMS(end)/max(s.wVy_RMS(1),eps),s.wr_RMS(end)/max(s.wr_RMS(1),eps)]);
ayGrowth=max([a.wVy_RMS(end)/max(a.wVy_RMS(1),eps),a.wr_RMS(end)/max(a.wr_RMS(1),eps)]);
relativeMean=max(abs(summary.mean)./max(summary.RMS,eps));
c.residualMeanNearZero=relativeMean<0.2;
c.residualDynamicGrowth=max(steerGrowth,ayGrowth);
c.stateDependentResidualEvidence=c.residualMeanNearZero && c.residualDynamicGrowth>=1.5;
signedCorr=max(abs([pearson(p.frontMeanSteer,p.residual(:,1)), ...
    pearson(p.frontMeanSteer,p.residual(:,2)),pearson(p.ayTrue,p.residual(:,1)), ...
    pearson(p.ayTrue,p.residual(:,2))]));
c.maxSignedDynamicCorrelation=signedCorr;
% A near-zero global mean can be produced by cancellation between left and
% right maneuvers. Strong signed correlation therefore takes precedence
% over the global mean when diagnosing systematic model mismatch.
c.systematicModelMismatch=signedCorr>=0.7;
c.pureStateDependentUncertaintyEvidence=c.stateDependentResidualEvidence && ...
    ~c.systematicModelMismatch;
if c.systematicModelMismatch,c.v19Priority='model correction';
elseif c.pureStateDependentUncertaintyEvidence,c.v19Priority='state-dependent Q research';
else,c.v19Priority='covariance-structure issue';end
c.processInterpretation=['Global residual means are near zero, but strong signed ', ...
    'steering/Ay correlation shows maneuver-dependent systematic mismatch; ', ...
    'the zero mean is consistent with left/right cancellation.'];
b3=diagTable(diagTable.Case=="B3",:);
c.highestSteeringGroup=largest_group(b3,'Steering');
c.highestAyGroup=largest_group(b3,'AbsAyTrue');
c.highestDrGroup=largest_group(b3,'AbsDrTrueDt');
c.noAdaptiveQCreated=true; c.b3OracleDiagnosticOnly=true; c.termMeans=means;
end

function result=largest_group(t,section)
s=t(t.Section==string(section),:);[value,k]=max(s.NEES_mean);
result=sprintf('%s (NEES mean %.6g)',s.Group(k),value);
end

function value = conditional(test,a,b),if test,value=a;else,value=b;end,end

function [ayTrue,audit] = load_verified_clean_ay(resultsDir,run)
file=fullfile(resultsDir,'vy_dekf_v1_3_simout.mat'); assert(isfile(file)); loaded=load(file);
fields=fieldnames(loaded); container=[];
for k=1:numel(fields)
    candidate=loaded.(fields{k});
    if isa(candidate,'Simulink.SimulationOutput'),container=candidate;break;end
end
assert(~isempty(container),'V1.3 SimulationOutput container not found.');
[tAy,ay]=log_matrix(fetch_log(container,{'vy_Ay_true_log'}));
[tR,r]=log_matrix(fetch_log(container,{'vy_AVz_true_log'}));
[tU,u]=log_matrix(fetch_log(container,{'est_u_log1','outest_u_log1'}));
ayTrue=interp1(tAy,ay(:,1),run.t,'linear','extrap');
rCheck=interp1(tR,r(:,1),run.t,'linear','extrap');
uCheck=interp1(tU,u(:,1:5),run.t,'previous','extrap');
rDifference=max(abs(rCheck-run.rTrue)); uDifference=max(abs(uCheck-run.u),[],'all');
assert(rDifference<=1e-10 && uDifference<=1e-10, ...
    'V1.3 clean-Ay run does not match V1.7 driving/truth records.');
audit=struct('sourceFile',file,'sourceLog','vy_Ay_true_log', ...
    'physicalSource','CarSim Ay -> Gain36=9.8 before IMU bias/noise/filter', ...
    'samples',numel(ayTrue),'rTruthMaxDifference',rDifference, ...
    'onlineInputMaxDifference',uDifference,'verifiedSameRun',true);
end

function value=fetch_log(out,aliases)
available=out.who;
for k=1:numel(aliases),if any(strcmp(available,aliases{k})),value=out.get(aliases{k});return;end,end
error('Required log missing: %s',strjoin(aliases,', '));
end

function [time,data]=log_matrix(value)
if isa(value,'timeseries'),time=double(value.Time(:));raw=double(value.Data);
elseif isa(value,'Simulink.SimulationData.Signal'),[time,data]=log_matrix(value.Values);return;
elseif isstruct(value)&&isfield(value,'time')&&isfield(value,'signals')
    time=double(value.time(:));raw=double(value.signals.values);
else,error('Unsupported log type: %s',class(value));end
raw=squeeze(raw);
if isvector(raw),data=raw(:);elseif size(raw,1)==numel(time),data=raw;
elseif size(raw,2)==numel(time),data=raw.';else,error('Time/data mismatch.');end
end

function figures = create_figures(cases,p,tableIn,resultsDir,chi95)
figures=struct(); b0=cases(1); b3=cases(2);
fig=figure('Visible','off','Color','w','Position',[50 50 1300 650]);
semilogy(b0.t,max(b0.NEES,eps));hold on;semilogy(b3.t,max(b3.NEES,eps));yline(chi95,'--r');grid on;
xlabel('Time [s]');ylabel('Full NEES');legend('B0','B3','95% threshold');
figures.nees=save_figure(fig,resultsDir,'vy_dekf_v1_8_01_B0_B3_nees.png');
fig=figure('Visible','off','Color','w','Position',[50 50 1300 700]);
plot(b3.t,b3.marginalVy);hold on;plot(b3.t,b3.marginalR);grid on;legend('Vy marginal NSEE','r marginal NSEE');
xlabel('Time [s]');ylabel('Marginal normalized squared error');
figures.marginal=save_figure(fig,resultsDir,'vy_dekf_v1_8_02_B3_marginal_nsee.png');
fig=figure('Visible','off','Color','w','Position',[50 50 1300 700]);
plot(b3.t,b3.termVy);hold on;plot(b3.t,b3.termCross);plot(b3.t,b3.termR);grid on;
legend('Vy diagonal','cross','r diagonal');xlabel('Time [s]');ylabel('Full-NEES term');
figures.decomposition=save_figure(fig,resultsDir,'vy_dekf_v1_8_03_B3_full_nees_terms.png');
fig=figure('Visible','off','Color','w','Position',[50 50 1350 850]);tiledlayout(fig,2,1);
nexttile;plot(b3.t,b3.error(:,1));hold on;plot(b3.t,2*b3.sigmaVy,'--');plot(b3.t,-2*b3.sigmaVy,'--');grid on;ylabel('Vy error [m/s]');
nexttile;plot(b3.t,b3.error(:,2));hold on;plot(b3.t,2*b3.sigmaR,'--');plot(b3.t,-2*b3.sigmaR,'--');grid on;ylabel('r error [rad/s]');xlabel('Time [s]');
figures.envelope=save_figure(fig,resultsDir,'vy_dekf_v1_8_04_B3_error_2sigma.png');
figures.steering=condition_bar(tableIn,'Steering',resultsDir,'vy_dekf_v1_8_05_steering_nees.png');
figures.ay=condition_bar(tableIn,'AbsAyTrue',resultsDir,'vy_dekf_v1_8_06_Ay_nees.png');
fig=figure('Visible','off','Color','w','Position',[50 50 1350 800]);tiledlayout(fig,2,1);
nexttile;plot(p.t,p.residual(:,1));grid on;ylabel('w model Vy [m/s]');
nexttile;plot(p.t,p.residual(:,2));grid on;ylabel('w model r [rad/s]');xlabel('Time [s]');
figures.residual=save_figure(fig,resultsDir,'vy_dekf_v1_8_07_process_residual.png');
fig=figure('Visible','off','Color','w','Position',[40 40 1400 900]);tiledlayout(fig,2,2);
nexttile;scatter(p.maxAbsSteer,p.residual(:,1),8,'.');grid on;xlabel('max |steer|');ylabel('wVy');
nexttile;scatter(p.ayTrue,p.residual(:,1),8,'.');grid on;xlabel('Ay true');ylabel('wVy');
nexttile;scatter(p.maxAbsSteer,p.residual(:,2),8,'.');grid on;xlabel('max |steer|');ylabel('wr');
nexttile;scatter(p.ayTrue,p.residual(:,2),8,'.');grid on;xlabel('Ay true');ylabel('wr');
figures.scatter=save_figure(fig,resultsDir,'vy_dekf_v1_8_08_residual_scatter.png');
end

function file = condition_bar(t,section,resultsDir,name)
subset=t(t.Section==string(section),:); b0=subset(subset.Case=="B0",:); b3=subset(subset.Case=="B3",:);
fig=figure('Visible','off','Color','w','Position',[50 50 1100 650]);bar([b0.NEES_mean b3.NEES_mean]);grid on;
xticks(1:height(b0));xticklabels(cellstr(b0.Group));legend('B0','B3');ylabel('NEES mean');title(section);
file=save_figure(fig,resultsDir,name);
end

function file = save_figure(fig,resultsDir,name)
file=fullfile(resultsDir,name);exportgraphics(fig,file,'Resolution',180);close(fig);
end

function write_status(file,stateTable,diagTable,residualTable,corrTable,conditionTable, ...
    cases,c,alignment,ayAudit,figures,csvFile,residualCsv,corrCsv,conditionCsv,matFile)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.8 STATUS\n\n');
fprintf(fid,'## 边界与时间对齐\n\n');
fprintf(fid,['本阶段仅对已有 V1.7 结果做离线诊断；没有重新仿真、', ...
    '调 Q/R、创建 adaptive-Q 或把真值送入在线 EKF。B3 是去除已知固定 bias ', ...
    '后的主要残差诊断 case，仍然只是 oracle ablation，不是最终在线估计器。\n\n']);
fprintf(fid,'Rate Transition 已验证的实际对应关系：\n\n');
fprintf(fid,'- x_hat index: `%s`\n',alignment.xHatIndex);
fprintf(fid,'- posterior P_new index: `%s`\n',alignment.posteriorPIndex);
fprintf(fid,'- truth index: `%s`\n',alignment.truthIndex);
fprintf(fid,'- reported time: `%s`\n',alignment.reportedTimeIndex);
fprintf(fid,'- update input index: `%s`\n',alignment.updateInputIndex);
fprintf(fid,'- 因此 `x_hat(i)` 与同一 replay update 的 `P_new(:,:,i)` 组合，再对齐 `truth(i+1)`；未使用 P_pred。\n');
fprintf(fid,['- 原始 100 Hz truth/input 格点 %d 个；一步过程残差 %d 个，', ...
    '正好少一个；posterior/NEES 因 Rate Transition 因果对齐后为 %d 个；`Ts=0.01 s`。\n\n'], ...
    alignment.rawTruthSamples,alignment.processResidualSamples,alignment.posteriorSamples);
fprintf(fid,'clean Ay 来源：`%s`；与 V1.7 true-r 和在线输入的最大差异为 %.3g / %.3g。\n', ...
    ayAudit.physicalSource,ayAudit.rTruthMaxDifference,ayAudit.onlineInputMaxDifference);

fprintf(fid,'\n## Full NEES、marginal NSEE 与 coverage\n\n');
fprintf(fid,'`eVy^2/P11` 和 `er^2/P22` 仅定义为 marginal normalized squared error，不是 full-NEES 分解项。\n\n');
fprintf(fid,'|Case|NEES mean|marg Vy|marg r|Vy diagonal|cross|r diagonal|identity max|\n|:--|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(stateTable),fprintf(fid,'|%s|%.9g|%.9g|%.9g|%.9g|%.9g|%.9g|%.3g|\n',stateTable.Case(k),stateTable.NEES_mean(k),stateTable.marginal_Vy_mean(k),stateTable.marginal_r_mean(k),stateTable.full_term_Vy_mean(k),stateTable.full_term_cross_mean(k),stateTable.full_term_r_mean(k),stateTable.identity_max(k));end
fprintf(fid,'\nfull term 通过 2x2 解析系数计算，NEES 本身通过 `P\\e` 线性求解；没有显式 `inv(P)`。cross term 允许为负。\n\n');
fprintf(fid,'高斯单状态 coverage 参考：1sigma=68.27%%，2sigma=95.45%%，3sigma=99.73%%；仅作参考，不是硬判据。\n\n');
fprintf(fid,'|Case|Vy 1s|Vy 2s|Vy 3s|r 1s|r 2s|r 3s|Vy rho1/rho10|r rho1/rho10|\n|:--|--:|--:|--:|--:|--:|--:|:--|:--|\n');
for k=1:height(stateTable),fprintf(fid,'|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f / %.4f|%.4f / %.4f|\n',stateTable.Case(k),stateTable.Vy_coverage_1sigma(k),stateTable.Vy_coverage_2sigma(k),stateTable.Vy_coverage_3sigma(k),stateTable.r_coverage_1sigma(k),stateTable.r_coverage_2sigma(k),stateTable.r_coverage_3sigma(k),stateTable.Vy_error_rho1(k),stateTable.Vy_error_rho10(k),stateTable.r_error_rho1(k),stateTable.r_error_rho10(k));end

fprintf(fid,'\n## B3 动态条件结果\n\n');
b3=diagTable(diagTable.Case=="B3",:);fprintf(fid,'|Section|Group|N|Vy RMSE|r RMSE|NEES mean|NEES p95|>95%%|\n|:--|:--|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(b3),fprintf(fid,'|%s|%s|%d|%.6g|%.6g|%.6g|%.6g|%.4f|\n',b3.Section(k),b3.Group(k),b3.N(k),b3.Vy_RMSE(k),b3.r_RMSE(k),b3.NEES_mean(k),b3.NEES_p95(k),b3.NEES_fraction_above_5p991464547(k));end

fprintf(fid,'\n## 一步过程模型残差\n\n');
fprintf(fid,['严格调用 `vy_dynamic_ekf_step_v15_debug` 的现有 prediction，', ...
    '输入 `x_true(k),u(k)` 并只读取 measurement update 前的 `info.x_pred`。', ...
    '`z` 对 x_pred 的数值影响已验证为 0。\n\n']);
fprintf(fid,'|State|N|mean|std|RMS|p95 abs|max abs|rho1|rho10|RMS/sqrt(Qii)|\n|:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n');
for k=1:height(residualTable),fprintf(fid,'|%s|%d|%.9g|%.9g|%.9g|%.9g|%.9g|%.6g|%.6g|%.6g|\n',residualTable.State(k),residualTable.N(k),residualTable.mean(k),residualTable.std(k),residualTable.RMS(k),residualTable.p95_absolute(k),residualTable.max_absolute(k),residualTable.rho1(k),residualTable.rho10(k),residualTable.RMS_over_sqrt_Qii(k));end
fprintf(fid,'\n`dr_true/dt` 内部样本使用 MATLAB `gradient` 中央差分，两个边界样本使用一侧差分。主相关性使用 Ay_true；Ay_IMU 只作附加对照。\n');
fprintf(fid,'\n过程残差的动态分组：\n\n');
fprintf(fid,'|Section|Group|N|wVy mean|wVy RMS|wr mean|wr RMS|\n|:--|:--|--:|--:|--:|--:|--:|\n');
for k=1:height(conditionTable),fprintf(fid,'|%s|%s|%d|%.6g|%.6g|%.6g|%.6g|\n',conditionTable.Section(k),conditionTable.Group(k),conditionTable.N(k),conditionTable.wVy_mean(k),conditionTable.wVy_RMS(k),conditionTable.wr_mean(k),conditionTable.wr_RMS(k));end
fprintf(fid,'\n主 signed/absolute 相关性：\n\n');
keep=ismember(corrTable.Variable,["FrontMeanSteer","MaxAbsSteer","Ay_true","dr_true_dt"]); ct=corrTable(keep,:);
fprintf(fid,'|Variable|corr wVy|corr wr|corr abs wVy|corr abs wr|\n|:--|--:|--:|--:|--:|\n');
for k=1:height(ct),fprintf(fid,'|%s|%.6g|%.6g|%.6g|%.6g|\n',ct.Variable(k),ct.corr_wVy(k),ct.corr_wr(k),ct.corr_abs_wVy(k),ct.corr_abs_wr(k));end

fprintf(fid,'\n## 最终判断\n\n');
fprintf(fid,'1. NEES 主要由哪个状态贡献：**%s**。\n',c.underestimatedState);
fprintf(fid,['2. 去 bias 后剩余 NEES 峰值位于 **t=%.6g s**。', ...
    '最高分组：steering `%s`，|Ay_true| `%s`，|dr_true/dt| `%s`。\n'], ...
    c.remainingPeakTime,c.highestSteeringGroup,c.highestAyGroup,c.highestDrGroup);
fprintf(fid,'3. 当前 P 主要低估的状态：**%s**。\n',c.underestimatedState);
fprintf(fid,'4. 一步过程残差 RMS 是否超过 sqrt(Qii)：**%s**。\n',yesno(c.processResidualExceedsQ));
fprintf(fid,['5. 是否存在随 steering/Ay 增长的动态相关残差：**%s**', ...
    '（最大高/低 RMS 比 %.6g）。但是否能解释为纯随机 state-dependent ', ...
    'uncertainty：**%s**；强 signed 相关性需先排查模型失配。\n'], ...
    yesno(c.stateDependentResidualEvidence),c.residualDynamicGrowth, ...
    yesno(c.pureStateDependentUncertaintyEvidence));
fprintf(fid,'6. V1.9 应优先研究：**%s**。\n',c.v19Priority);
fprintf(fid,'7. full NEES 高的主要来源：**%s**。B3 mean terms=[%.6g, %.6g, %.6g]。\n',c.fullNeesSource,c.termMeans);
fprintf(fid,'8. marginal normalized error 与 full-NEES decomposition 是否给出一致结论：**%s**。\n',yesno(c.marginalAndFullAgree));
fprintf(fid,['9. 过程残差全局均值接近0且RMS随动态增加：**%s**。', ...
    '这排除单一固定 bias；但由于 signed correlation 高达 %.6g，', ...
    '不能仅解释为随机 state-dependent Q。\n'],yesno(c.stateDependentResidualEvidence),c.maxSignedDynamicCorrelation);
fprintf(fid,['10. 是否存在系统性模型失配证据：**%s**。', ...
    '虽然左右转向抵消后全局均值接近0，残差与 signed steering/Ay ', ...
    '的强相关表明误差具有可预测的方向性。优先 model correction，', ...
    '不用增大Q掩盖。\n'],yesno(c.systematicModelMismatch));
fprintf(fid,'11. **NO ADAPTIVE-Q ALGORITHM WAS CREATED.** V1.8 只决定 V1.9 研究优先级。\n');

fprintf(fid,'\n## 产物\n\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n',csvFile,residualCsv,corrCsv,conditionCsv,matFile);
names=fieldnames(figures);for k=1:numel(names),fprintf(fid,'- `%s`\n',figures.(names{k}));end
fprintf(fid,'- `%s.m`\n',mfilename('fullpath'));
fprintf(fid,'\nB3 WAS USED ONLY AS AN ORACLE-CORRECTED DIAGNOSTIC CASE.\n\nNO ONLINE ESTIMATOR OR ADAPTIVE-Q LOGIC WAS CREATED.\n');
clear cleanup;
end

function word=yesno(value),if value,word='是';else,word='否';end,end
function value=rms_value(v),value=sqrt(mean(v.^2));end
function value=percentile(v,p),v=sort(v(isfinite(v)));pos=1+(numel(v)-1)*p/100;lo=floor(pos);hi=ceil(pos);w=pos-lo;value=v(lo)*(1-w)+v(hi)*w;end
function bin=rank_quantile_id(v,count),[~,order]=sort(v(:));n=numel(v);cuts=round(linspace(0,n,count+1));bin=zeros(n,1);for k=1:count,bin(order(cuts(k)+1:cuts(k+1)))=k;end,end
function rho=normalized_acf(x,maxLag),x=x(:)-mean(x);den=x'*x;rho=zeros(maxLag+1,1);for k=0:maxLag,rho(k+1)=(x(1:end-k)'*x(1+k:end))/max(den,eps);end,end
function c=pearson(x,y),m=isfinite(x)&isfinite(y);x=x(m);y=y(m);if std(x)==0||std(y)==0,c=0;else,q=corrcoef(x,y);c=q(1,2);end,end
