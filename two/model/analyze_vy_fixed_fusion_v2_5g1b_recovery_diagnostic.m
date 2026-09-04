function report = analyze_vy_fixed_fusion_v2_5g1b_recovery_diagnostic()
%ANALYZE_VY_FIXED_FUSION_V2_5G1B_RECOVERY_DIAGNOSTIC Saved evidence only.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_fixed_fusion_v2_5g1b_recovery_diagnostic.mat');
S=load(resultFile,'report');report=S.report;tol=1e-12;
assert(strcmp(report.role,'RUNTIME_RECOVERY_DIAGNOSTIC')&& ...
    ~report.calibrationEligible&&~report.holdoutEligible&& ...
    report.simCalled&&report.runtimeAuthorizationConsumed&& ...
    report.simulationCompleted&&report.carSimRun,'V25G1B:Evidence', ...
    'Saved diagnostic completion/role evidence is incomplete.');
r=report.raw;

tD=double(r.fusion_vy_d_log.time(:));tK=double(r.fusion_vy_k_log.time(:));
tF=double(r.fusion_vy_f_log.time(:));tFW=double(r.fusion_vy_fw_log.time(:));
nD=numel(tD);nK=numel(tK);nF=numel(tF);nFW=numel(tFW);
dTiming=timing_stats(tD);kTiming=timing_stats(tK);
fTiming=timing_stats(tF);fwTiming=timing_stats(tFW);
timestamps=struct('D',dTiming,'K',kTiming,'F',fTiming,'fusion',fwTiming, ...
    'DvsKMaxDiff',max_pair_diff(tD,tK),'DvsFMaxDiff',max_pair_diff(tD,tF), ...
    'DvsFusionMaxDiff',max_pair_diff(tD,tFW),'exactSameIndex',isequal(tD,tK,tF,tFW));
timestamps.pass=all([nD nK nF nFW]==21)&&dTiming.pass&&kTiming.pass&& ...
    fTiming.pass&&fwTiming.pass&&timestamps.exactSameIndex;

vyD=vector(r.fusion_vy_d_log);vyK=vector(r.fusion_vy_k_log);
vyF=vector(r.fusion_vy_f_log);vyFW=vector(r.fusion_vy_fw_log);

dX=sample_rows(r.dekf_x_log.data,nD,2);dP=cov_pages(r.dekf_P_log.data,nD,2);
dDiag=sample_rows(r.dekf_diag_log.data,nD,65);dCov=cov_stats(dP);
dAy=dDiag(:,56)>0.5;dStep=dDiag(:,57);
dIntegrity=struct('finite',all(isfinite(dX),'all')&&all(isfinite(dP),'all')&& ...
    all(isfinite(dDiag),'all'),'covariance',dCov,'AyUpdateCount',nnz(dAy), ...
    'resetCount',nnz(abs(dStep)<tol),'VySelectDiff',max(abs(vyD-dX(:,1))));
dIntegrity.pass=dIntegrity.finite&&dCov.valid&&dIntegrity.AyUpdateCount==5&& ...
    dIntegrity.resetCount==1&&dIntegrity.VySelectDiff<=tol&& ...
    isequal(dStep(:),(0:20).');

kU=sample_rows(r.kkf_u_log1.data,nK,4);kX=sample_rows(r.kkf_x_log1.data,nK,2);
kP=cov_pages(r.kkf_P_log1.data,nK,2);kDiag=sample_rows(r.kkf_diag_log1.data,nK,5);
kCov=cov_stats(kP);reset=vector(r.reset_g0);
kIntegrity=struct('finite',all(isfinite(kU),'all')&&all(isfinite(kX),'all')&& ...
    all(isfinite(kP),'all')&&all(isfinite(kDiag),'all'),'covariance',kCov, ...
    'AxAyAVzVxCounts',[size(kU,1) size(kU,1) size(kU,1) size(kU,1)], ...
    'resetHighCount',nnz(reset>0.5),'VySelectDiff',max(abs(vyK-kX(:,2))));
kIntegrity.pass=kIntegrity.finite&&kCov.valid&& ...
    isequal(kIntegrity.AxAyAVzVxCounts,[21 21 21 21])&& ...
    kIntegrity.resetHighCount==1&&kIntegrity.VySelectDiff<=tol;

fP=vector(r.fusion_f_P_log);fDiag=sample_rows(r.fusion_f_diag_log.data,nF,3);
fFeedbackCount=nnz(fDiag(:,3)>0.5);
fIntegrity=struct('finite',all(isfinite(vyF))&&all(isfinite(fP))&& ...
    all(isfinite(fDiag),'all'),'PNonnegative',all(fP>=0), ...
    'feedbackAppliedOneCount',fFeedbackCount,'resetAtFirstHit', ...
    abs(vyF(1)-report.fParameters.Vy_F0)<=tol&& ...
    abs(fP(1)-report.fParameters.P0_F)<=tol&&all(abs(fDiag(1,:))<=tol));
fIntegrity.pass=fIntegrity.finite&&fIntegrity.PNonnegative&& ...
    fFeedbackCount==0&&fIntegrity.resetAtFirstHit;

tShared=double(r.parallel_input_log.time(:));
[sharedD,aD]=inputs_at_hits(r.parallel_input_log.data,tShared,tD,9);
[sharedK,aK]=inputs_at_hits(r.parallel_input_log.data,tShared,tK,9);
[sharedF,aF]=inputs_at_hits(r.parallel_input_log.data,tShared,tF,9);
shared=struct('D',aD,'K',aK,'F',aF, ...
    'KInputMaxDiff',max(abs(kU-sharedK(:,1:4)),[],'all'));
shared.pass=aD.pass&&aK.pass&&aF.pass&&shared.KInputMaxDiff<=tol;

clear vy_dynamic_ekf_v1_17
dInput=[sharedD(:,4),sharedD(:,5:8),sharedD(:,2),sharedD(:,3)];
dXR=zeros(nD,2);dPR=zeros(2,2,nD);dDR=zeros(nD,65);
for k=1:nD
    y=vy_dynamic_ekf_v1_17(dInput(k,:).',20);
    dXR(k,:)=y(1:2).';dPR(:,:,k)=reshape(y(46:49),2,2);dDR(k,:)=y(5:69).';
end
clear vy_dynamic_ekf_v1_17
dReplay=struct('maxStateDiff',max(abs(dXR-dX),[],'all'), ...
    'maxPDiff',max(abs(dPR-dP),[],'all'),'maxDiagDiff',max(abs(dDR-dDiag),[],'all'));
dReplay.pass=max([dReplay.maxStateDiff dReplay.maxPDiff dReplay.maxDiagDiff])<=tol;

clear vy_kinematic_kf
kXR=zeros(nK,2);kPR=zeros(2,2,nK);kDR=zeros(nK,5);
for k=1:nK
    [xk,pk,dk]=vy_kinematic_kf(kU(k,1:3).',kU(k,4),double(k==1));
    kXR(k,:)=xk(:).';kPR(:,:,k)=pk;kDR(k,:)=dk(:).';
end
clear vy_kinematic_kf
kReplay=struct('maxStateDiff',max(abs(kXR-kX),[],'all'), ...
    'maxPDiff',max(abs(kPR-kP),[],'all'),'maxDiagDiff',max(abs(kDR-kDiag),[],'all'));
kReplay.pass=max([kReplay.maxStateDiff kReplay.maxPDiff kReplay.maxDiagDiff])<=tol;

p=report.fParameters;fVyR=zeros(nF,1);fPR=zeros(nF,1);fDR=zeros(nF,3);
vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
for k=1:nF
    resetF=double(k==1);
    [fVyR(k),fPR(k),diagk]=vy_feedback_propagation_step( ...
        vyPrev,pPrev,sharedF(k,2),sharedF(k,3),sharedF(k,4), ...
        vyFeedbackZ1,pFeedbackZ1,validZ1,resetF,p.Ts,p.Vy_F0,p.P0_F,p.Q_F);
    fDR(k,:)=diagk(:).';
    if resetF
        vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
    else
        vyPrev=fVyR(k);pPrev=fPR(k);vyFeedbackZ1=0;pFeedbackZ1=0.5;validZ1=0;
    end
end
fReplay=struct('maxVyDiff',max(abs(fVyR-vyF)),'maxPDiff',max(abs(fPR-fP)), ...
    'maxDiagDiff',max(abs(fDR-fDiag),[],'all'));
fReplay.pass=max([fReplay.maxVyDiff fReplay.maxPDiff fReplay.maxDiagDiff])<=tol;

w=report.weights.values;expected=zeros(nFW,1);
for k=1:nFW
    expected(k)=vy_fixed_weight_fusion_step(vyD(k),vyK(k),vyF(k),w(1),w(2),w(3));
end
fusionReplay=struct('maxAbsDiff',max(abs(expected-vyFW)), ...
    'sameTimestampSameIndex',timestamps.exactSameIndex);
fusionReplay.pass=fusionReplay.maxAbsDiff<=tol&&timestamps.exactSameIndex;

tSteer=double(r.steer_cmd_rad.time(:));cmd=vector(r.steer_cmd_rad);
deg=vector(r.steer_to_carsim_deg);fl=vector(r.steer_fl_carsim_deg);
fr=vector(r.steer_fr_carsim_deg);rl=vector(r.steer_rl_carsim_deg);rr=vector(r.steer_rr_carsim_deg);
expectedCmd=0.02*sin(2*pi*0.40*tSteer);nz=abs(cmd)>tol;
steering=struct('commandMaxAbs',max(abs(cmd)),'waveformMaxDiff',max(abs(cmd-expectedCmd)), ...
    'convertedMaxAbs',max(abs(deg)),'ratioMedian',median(deg(nz)./cmd(nz)), ...
    'FLDiff',max(abs(fl-deg)),'FRDiff',max(abs(fr-deg)), ...
    'RLMaxAbs',max(abs(rl)),'RRMaxAbs',max(abs(rr)));
steering.pass=steering.waveformMaxDiff<=tol&&steering.FLDiff<=tol&& ...
    steering.FRDiff<=tol&&steering.RLMaxAbs<=tol&&steering.RRMaxAbs<=tol&& ...
    abs(steering.ratioMedian-180/pi)<=1e-10;

gates=struct();gates.runtimeCompleted=report.simulationCompleted&&report.carSimRun;
gates.correctDSolverNoG=strcmpi(report.carSim.solverActual,report.carSim.solverExpected)&& ...
    ~report.carSim.gRequestBefore&&~report.carSim.gRequestConsole;
gates.controlConditionExact=steering.pass;
gates.twentyOneSamplesAndTiming=timestamps.pass;
gates.DIntegrity=dIntegrity.pass;gates.KIntegrity=kIntegrity.pass;
gates.FIntegrity=fIntegrity.pass;gates.FFeedbackAlwaysZero=fFeedbackCount==0;
gates.sharedInputs=shared.pass;gates.DReplay=dReplay.pass;gates.KReplay=kReplay.pass;
gates.FReplay=fReplay.pass;gates.fusionReplay=fusionReplay.pass;
gates.diagnosticRoleOnly=strcmp(report.role,'RUNTIME_RECOVERY_DIAGNOSTIC')&& ...
    ~report.calibrationEligible&&~report.holdoutEligible;
gates.prefdirPolicyExact=report.matlabPrefdir.environmentUnset&& ...
    report.matlabPrefdir.activeExact&&report.matlabPrefdir.notR2Clean&& ...
    report.matlabPrefdir.notForensicBackup&& ...
    isempty(report.immediatePreSim.matlabPrefdirEnvironment)&& ...
    strcmpi(report.immediatePreSim.activePrefdir, ...
    report.matlabPrefdir.expectedFreshValue);
gates.cwdAndSimfileExact=strcmpi(report.immediatePreSim.pwd,fullfile(root,'model'))&& ...
    strcmpi(report.immediatePreSim.activeSimfile,fullfile(root,'model','simfile.sim'));
gates.frozenHashesUnchanged=report.targetHashUnchanged&&report.allFrozenHashesUnchanged;
values=cell2mat(struct2cell(gates));
analysis=struct('stage','V2.5-G1B','role',report.role,'timestamps',timestamps, ...
    'D',dIntegrity,'K',kIntegrity,'F',fIntegrity,'sharedInputs',shared, ...
    'DReplay',dReplay,'KReplay',kReplay,'FReplay',fReplay, ...
    'fusionReplay',fusionReplay,'steering',steering,'gates',gates, ...
    'gateCount',numel(values),'gatesTrue',sum(values),'performanceEvaluationPerformed',false, ...
    'weightSelectionPerformed',false,'calibrationUseAuthorized',false, ...
    'passed',all(values));
report.analysis=analysis;
save(resultFile,'report','-v7.3');
fprintf(['V25G1B_ANALYSIS|gates=%d/%d|N=[%d %d %d %d]|dt=%.17g|' ...
    'feedbackApplied=%d|replay=[%.3g %.3g %.3g %.3g]|role=%s|passed=%d|sim=0\n'], ...
    analysis.gatesTrue,analysis.gateCount,nD,nK,nF,nFW,fwTiming.dtMean, ...
    fFeedbackCount,dReplay.maxStateDiff,kReplay.maxStateDiff, ...
    fReplay.maxVyDiff,fusionReplay.maxAbsDiff,report.role,analysis.passed);
if ~analysis.passed
    names=fieldnames(gates);names=names(~values);
    error('V25G1B:GateFailed','Failed diagnostic gates: %s',strjoin(names,', '));
end
end

function x=vector(r),x=double(r.data(:));end
function a=sample_rows(data,n,w)
a=double(data);s=size(a);if ismatrix(a),if isequal(s,[n w]),return;end;if isequal(s,[w n]),a=a.';return;end,end
if numel(a)==n*w,a=reshape(a,w,n).';return;end
error('V25G1B:Shape','Cannot resolve width %d from %s.',w,mat2str(s));
end
function p=cov_pages(data,n,w)
p=double(data);s=size(p);if ndims(p)==3&&isequal(s,[w w n]),return;end
if ndims(p)==3&&isequal(s,[n w w]),p=permute(p,[2 3 1]);return;end
if ismatrix(p)&&isequal(s,[n w*w]),p=reshape(p.',w,w,n);return;end
if numel(p)==w*w*n,p=reshape(p,w,w,n);return;end
error('V25G1B:Shape','Cannot resolve covariance %s.',mat2str(s));
end
function s=timing_stats(t)
dt=diff(t);s=struct('sampleCount',numel(t),'tStart',t(1),'tEnd',t(end), ...
    'dtMin',min(dt),'dtMean',mean(dt),'dtMax',max(dt), ...
    'duplicates',nnz(dt<=0),'missingHits',sum(max(round(dt/0.01)-1,0)));
s.pass=numel(t)==21&&abs(t(1))<=1e-12&&abs(t(end)-0.2)<=1e-12&& ...
    all(abs(dt-0.01)<=1e-12)&&s.duplicates==0&&s.missingHits==0;
end
function s=cov_stats(P)
n=size(P,3);a=zeros(n,1);e=zeros(n,1);
for k=1:n,a(k)=max(abs(P(:,:,k)-P(:,:,k).'),[],'all');e(k)=min(eig((P(:,:,k)+P(:,:,k).')/2));end
s=struct('maxAsymmetry',max(a),'minimumEigenvalue',min(e));
s.valid=s.maxAsymmetry<=1e-12&&s.minimumEigenvalue>0;
end
function [hits,a]=inputs_at_hits(data,tIn,tHit,w)
tIn=double(tIn(:));rows=sample_rows(data,numel(tIn),w);hits=zeros(numel(tHit),w);
counts=zeros(numel(tHit),1);deltas=zeros(numel(tHit),1);ambiguous=false;
for k=1:numel(tHit)
    d=abs(tIn-tHit(k));deltas(k)=min(d);ix=find(d==deltas(k));counts(k)=numel(ix);
    if deltas(k)>32*eps(max(1,abs(tHit(k)))),continue;end
    c=rows(ix,:);if size(c,1)>1&&any(max(abs(c-c(end,:)),[],2)>1e-12),ambiguous=true;end
    hits(k,:)=c(end,:);
end
a=struct('matchCountPerHit',counts,'nearestDelta',deltas,'ambiguousDuplicate',ambiguous);
a.pass=all(counts>=1)&&all(deltas==0)&&~ambiguous;
end
function d=max_pair_diff(a,b)
if numel(a)~=numel(b),d=Inf;else,d=max(abs(a(:)-b(:)));end
end
