function comparison = analyze_vy_kkf_v2_1g1_ab_validation()
%ANALYZE_VY_KKF_V2_1G1_AB_VALIDATION Online A/B and offline B0/B3 evidence.

root=fileparts(fileparts(mfilename('fullpath')));
fileA=fullfile(root,'results','vy_kkf_v2_1g1_nominal_002.mat');
fileB=fullfile(root,'results','vy_kkf_v2_1g1_highyaw_004.mat');
comparisonFile=fullfile(root,'results','vy_kkf_v2_1g1_comparison.mat');
SA=load(fileA,'report'); SB=load(fileB,'report'); runA=SA.report; runB=SB.report;
assert(runA.steeringGate.pass&&runB.steeringGate.pass,'Both genuine-steering gates must pass before comparison.');
assert(runA.modelFilesUnchanged&&runB.modelFilesUnchanged,'A model hash changed during G1 runtime.');

[A,ctxA]=online_analysis(runA); [B,ctxB]=online_analysis(runB);
[A.b0,b0A]=b0_replay(ctxA); [B.b0,b0B]=b0_replay(ctxB);
replayThreshold=1e-12;
A.b0.pass=A.b0.maxAbsXDiff<=replayThreshold&&A.b0.maxAbsPDiff<=replayThreshold&&A.b0.maxAbsDiagDiff<=replayThreshold;
B.b0.pass=B.b0.maxAbsXDiff<=replayThreshold&&B.b0.maxAbsPDiff<=replayThreshold&&B.b0.maxAbsDiagDiff<=replayThreshold;

comparison=struct('stage','V2.1-G1 Genuine Steering 16 s A/B Observability Validation', ...
    'caseA',A,'caseB',B,'b0Threshold',replayThreshold,'b0BothPassed',A.b0.pass&&B.b0.pass, ...
    'scope',struct('runtimeCount',2,'trueVyOnlineUsed',false,'trueVyOfflineValidationOnly',true, ...
    'qrP0TuningPerformed',false,'onlineBiasCorrectionImplemented',false, ...
    'fusionPerformed',false,'v2_2Started',false));
if ~comparison.b0BothPassed
    save(comparisonFile,'comparison','-v7.3');
    error('VY_KKF:G1B0ReplayFailed','G1 B0 exact replay failed; B3 was not evaluated.');
end

A.b3=b3_replay(ctxA); B.b3=b3_replay(ctxB);
comparison.caseA=A; comparison.caseB=B;
comparison.ab=ab_comparison(A,B);
comparison.b3=b3_comparison(A.b3,B.b3);
comparison.excitationBothValid=A.steering.pass&&B.steering.pass;
comparison.hashGatePassed=runA.modelFilesUnchanged&&runB.modelFilesUnchanged;
comparison.rawContext=struct('A',ctxA,'B',ctxB,'b0A',b0A,'b0B',b0B);

runA.analysis=A; runB.analysis=B; report=runA; save(fileA,'report','-v7.3');
report=runB; save(fileB,'report','-v7.3'); save(comparisonFile,'comparison','-v7.3');
fprintf(['V2_1G1_ANALYSIS_OK|Asteer=%d|Bsteer=%d|AmeanR=%.17g|BmeanR=%.17g|' ...
    'AK21=%.17g|BK21=%.17g|AP22=%.17g|BP22=%.17g|AVy=%.17g|BVy=%.17g|' ...
    'AB3=%.17g|BB3=%.17g\n'],A.steering.pass,B.steering.pass,A.yaw.meanAbs, ...
    B.yaw.meanAbs,A.k21.all.meanAbs,B.k21.all.meanAbs,A.p22.final,B.p22.final, ...
    A.performance.Vy.RMSE,B.performance.Vy.RMSE,A.b3.RMSE,B.b3.RMSE);
end

function [a,c]=online_analysis(run)
r=run.raw; names={'kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
times=cellfun(@(n)r.(n).time(:),names,'UniformOutput',false); counts=cellfun(@numel,times);
t=times{2}; u=sample_matrix(r.kkf_u_log1.data,counts(1)); x=sample_matrix(r.kkf_x_log1.data,counts(2));
P=covariance_samples(r.kkf_P_log1.data,counts(3)); d=sample_matrix(r.kkf_diag_log1.data,counts(4));
assert(isequal(times{:}),'Four K-KF logs are not aligned.');
vx=truth_at(r.vx_true_offline,t); vy=truth_at(r.vy_true_offline,t);
reset=double(r.reset_g0.data(:)); resetTime=r.reset_g0.time(:); hi=reset>0.5;
dt=diff(t); asym=squeeze(abs(P(1,2,:)-P(2,1,:))); minEig=inf;
for k=1:numel(t),minEig=min(minEig,min(eig((P(:,:,k)+P(:,:,k).')/2)));end
rabs=abs(u(:,3)); low=rabs<=0.01; higher=~low; k21abs=abs(d(:,5)); p22=squeeze(P(2,2,:));
cm=corrcoef(rabs,k21abs); if numel(cm)<4||~isfinite(cm(1,2)),corrRK=NaN;else,corrRK=cm(1,2);end
vxErr=x(:,1)-vx; vyErr=x(:,2)-vy; nis=d(:,1);
a=struct(); a.steering=run.steeringGate;
a.integrity=struct('simulationCompleted',run.simulationCompleted,'carSimRun',run.carSimRun, ...
    'sampleCounts',counts,'tStart',t(1),'tEnd',t(end),'dtMin',min(dt),'dtMean',mean(dt), ...
    'dtMax',max(dt),'fourLogsAligned',true,'resetHighCount',nnz(hi), ...
    'resetHighTimes',resetTime(hi),'xFinite',all(isfinite(x(:))), ...
    'PFinite',all(isfinite(P(:))),'diagFinite',all(isfinite(d(:))), ...
    'maxCovarianceAsymmetry',max(asym),'minimumCovarianceEigenvalue',minEig);
a.yaw=struct('meanAbs',mean(rabs),'medianAbs',median(rabs),'p95Abs',pct(rabs,95), ...
    'maxAbs',max(rabs),'lowCount',nnz(low),'lowFraction',mean(low), ...
    'higherCount',nnz(higher),'higherFraction',mean(higher));
a.k21=struct('all',stats(k21abs),'correlationAbsRAbsK21',corrRK, ...
    'low',partition_stats(k21abs,low),'higher',partition_stats(k21abs,higher));
a.p22=struct('initial',p22(1),'final',p22(end),'min',min(p22),'max',max(p22), ...
    'mean',mean(p22),'secondHalfMean',mean(p22(t>=t(1)+(t(end)-t(1))/2)));
a.performance=struct('Vx',error_metrics(vxErr),'Vy',error_metrics(vyErr), ...
    'VyLowR',partition_error(vyErr,low),'VyHigherR',partition_error(vyErr,higher));
a.nis=struct('mean',mean(nis),'median',median(nis),'p95',pct(nis,95), ...
    'max',max(nis),'fractionLE_3_8414588',mean(nis<=3.8414588));
c=struct('t',t,'u',u,'x',x,'P',P,'diag',d,'vxTrue',vx,'vyTrue',vy, ...
    'lowR',low,'higherR',higher,'vxError',vxErr,'vyError',vyErr);
end

function [g,replay]=b0_replay(c)
[xr,Pr,dr]=replay_case(c.u(:,1:3),c.u(:,4));
g=struct('maxAbsXDiff',max(abs(xr(:)-c.x(:))),'maxAbsPDiff',max(abs(Pr(:)-c.P(:))), ...
    'maxAbsDiagDiff',max(abs(dr(:)-c.diag(:)))); replay=struct('x',xr,'P',Pr,'diag',dr);
end
function g=b3_replay(c)
u=c.u(:,1:3);u(:,2)=u(:,2)-0.02;u(:,3)=u(:,3)-0.005;
[x,P,d]=replay_case(u,c.u(:,4));e=x(:,2)-c.vyTrue;p22=squeeze(P(2,2,:));
g=error_metrics(e);g.finalVyError=e(end);g.P22Final=p22(end);g.P22Max=max(p22);g.P22Mean=mean(p22);
g.x=x;g.P=P;g.diag=d;g.vyError=e;
end
function ab=ab_comparison(A,B)
ab=struct();ab.meanAbsRRatio=B.yaw.meanAbs/A.yaw.meanAbs;ab.p95AbsRRatio=B.yaw.p95Abs/A.yaw.p95Abs;
ab.maxAbsRRatio=B.yaw.maxAbs/A.yaw.maxAbs;ab.higherRFractionDelta=B.yaw.higherFraction-A.yaw.higherFraction;
ab.meanAbsK21Ratio=B.k21.all.meanAbs/A.k21.all.meanAbs;ab.medianAbsK21Ratio=B.k21.all.medianAbs/A.k21.all.medianAbs;
ab.maxAbsK21Ratio=B.k21.all.maxAbs/A.k21.all.maxAbs;ab.P22FinalDelta=B.p22.final-A.p22.final;
ab.P22MeanDelta=B.p22.mean-A.p22.mean;ab.VyRMSEDelta=B.performance.Vy.RMSE-A.performance.Vy.RMSE;
ab.VyFinalErrorDelta=B.performance.Vy.FinalError-A.performance.Vy.FinalError;
end
function b=b3_comparison(A,B)
b=struct('VyRMSEDelta',B.RMSE-A.RMSE,'VyMAEDelta',B.MAE-A.MAE,'VyBiasDelta',B.Bias-A.Bias, ...
    'VyMaxAbsDelta',B.MaxAbsError-A.MaxAbsError,'VyFinalErrorDelta',B.finalVyError-A.finalVyError, ...
    'P22FinalDelta',B.P22Final-A.P22Final,'P22MaxDelta',B.P22Max-A.P22Max,'P22MeanDelta',B.P22Mean-A.P22Mean);
end

function [xLog,PLog,dLog]=replay_case(u,z)
clear vy_kinematic_kf
n=size(u,1);xLog=zeros(n,2);PLog=zeros(2,2,n);dLog=zeros(n,5);
for k=1:n,[xk,Pk,dk]=vy_kinematic_kf(u(k,:).',z(k),double(k==1));xLog(k,:)=xk(:).';PLog(:,:,k)=Pk;dLog(k,:)=dk(:).';end
clear vy_kinematic_kf
end
function s=stats(v),s=struct('meanAbs',mean(v),'medianAbs',median(v),'p95Abs',pct(v,95),'maxAbs',max(v));end
function s=partition_stats(v,m),s=struct('sampleCount',nnz(m),'meanAbs',mean(v(m)),'medianAbs',median(v(m)));end
function m=error_metrics(e),m=struct('RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)),'Bias',mean(e),'MaxAbsError',max(abs(e)),'FinalError',e(end));end
function m=partition_error(e,mask),m=struct('sampleCount',nnz(mask),'RMSE',sqrt(mean(e(mask).^2)),'MAE',mean(abs(e(mask))),'Bias',mean(e(mask)));end
function q=pct(v,p),v=sort(v(:));x=1+(numel(v)-1)*p/100;i=floor(x);j=ceil(x);if i==j,q=v(i);else,q=v(i)+(x-i)*(v(j)-v(i));end,end
function y=truth_at(rec,t),x=sample_matrix(rec.data,rec.sampleCount);assert(size(x,2)==1,'Truth log must be scalar.');y=interp1(rec.time(:),x(:,1),t,'linear');end
function x=sample_matrix(x,n),x=double(x);if size(x,1)~=n&&size(x,2)==n,x=x.';end;assert(size(x,1)==n,'Unexpected sample orientation.');end
function P=covariance_samples(P,n),P=double(P);if isequal(size(P),[2 2 n]),return;end;if isequal(size(P),[n 2 2]),P=permute(P,[2 3 1]);return;end;error('Unexpected covariance orientation: %s',mat2str(size(P)));end
