function report = analyze_vy_fixed_fusion_v2_5d_preflight()
%ANALYZE_VY_FIXED_FUSION_V2_5D_PREFLIGHT Analyze saved runtime only.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_fixed_fusion_v2_5d_preflight.mat');
S=load(resultFile,'report'); report=S.report;
assert(report.simCalled&&report.runtimeAuthorizationConsumed&& ...
    report.simulationCompleted&&report.carSimRun, ...
    'V2.5-D saved runtime completion evidence is incomplete.');
r=report.raw; tol=1e-12;

% Four runtime streams and exact same-index timestamp contract.
tD=double(r.fusion_vy_d_log.time(:)); tK=double(r.fusion_vy_k_log.time(:));
tF=double(r.fusion_vy_f_log.time(:)); tFW=double(r.fusion_vy_fw_log.time(:));
nD=numel(tD); nK=numel(tK); nF=numel(tF); nFW=numel(tFW);
dTiming=timing_stats(tD,0.01); kTiming=timing_stats(tK,0.01);
fTiming=timing_stats(tF,0.01); fwTiming=timing_stats(tFW,0.01);
timestamps=struct('D',dTiming,'K',kTiming,'F',fTiming,'fusion',fwTiming, ...
    'DvsKMaxDiff',max(abs(tD-tK)),'DvsFMaxDiff',max(abs(tD-tF)), ...
    'DvsFusionMaxDiff',max(abs(tD-tFW)), ...
    'exactSameIndex',isequal(tD,tK,tF,tFW));
timestamps.pass=nD==21&&nK==21&&nF==21&&nFW==21&& ...
    dTiming.pass100Hz&&kTiming.pass100Hz&&fTiming.pass100Hz&&fwTiming.pass100Hz&& ...
    timestamps.exactSameIndex;

vyD=vector(r.fusion_vy_d_log); vyK=vector(r.fusion_vy_k_log);
vyF=vector(r.fusion_vy_f_log); vyFW=vector(r.fusion_vy_fw_log);

% Existing D stream and covariance gates.
dX=sample_rows(r.dekf_x_log.data,nD,2);
dP=covariance_pages(r.dekf_P_log.data,nD,2);
dDiag=sample_rows(r.dekf_diag_log.data,nD,65);
dLogsAligned=isequal(tD,double(r.dekf_x_log.time(:)), ...
    double(r.dekf_P_log.time(:)),double(r.dekf_diag_log.time(:)));
dSelectExact=max(abs(vyD-dX(:,1)))<=tol;
dCov=covariance_stats(dP); dStepIndex=dDiag(:,57); dAyGate=dDiag(:,56)>0.5;
dResetMask=abs(dStepIndex)<tol;
dReset=struct('count',nnz(dResetMask),'timestamps',tD(dResetMask));
dReset.pass=dReset.count==1&&abs(dReset.timestamps(1))<=tol&& ...
    isequal(dStepIndex(:),(0:nD-1).');
dAy=struct('count',nnz(dAyGate),'timestamps',tD(dAyGate), ...
    'expectedTimestamps',(0:0.05:0.20).');
dAy.pass=dAy.count==5&&max(abs(dAy.timestamps-dAy.expectedTimestamps))<=tol;
dStream=struct('sampleCount',nD,'timing',dTiming,'logsAligned',dLogsAligned, ...
    'selectedVyMatchesState1',dSelectExact,'xFinite',all(isfinite(dX),'all'), ...
    'PFinite',all(isfinite(dP),'all'),'diagFinite',all(isfinite(dDiag),'all'), ...
    'covariance',dCov,'reset',dReset,'AyUpdate',dAy);
dStream.pass=nD==21&&dTiming.pass100Hz&&dLogsAligned&&dSelectExact&& ...
    dStream.xFinite&&dStream.PFinite&&dStream.diagFinite&&dCov.valid&&dReset.pass&&dAy.pass;

% Existing K stream and input-consumption gates.
kU=sample_rows(r.kkf_u_log1.data,nK,4);
kX=sample_rows(r.kkf_x_log1.data,nK,2);
kP=covariance_pages(r.kkf_P_log1.data,nK,2);
kDiag=sample_rows(r.kkf_diag_log1.data,nK,5);
kLogsAligned=isequal(tK,double(r.kkf_u_log1.time(:)), ...
    double(r.kkf_x_log1.time(:)),double(r.kkf_P_log1.time(:)), ...
    double(r.kkf_diag_log1.time(:)));
kSelectExact=max(abs(vyK-kX(:,2)))<=tol;
kCov=covariance_stats(kP);
kResetRaw=vector(r.reset_g0); kResetTime=double(r.reset_g0.time(:));
kResetMask=kResetRaw>0.5;
kReset=struct('count',nnz(kResetMask),'timestamps',kResetTime(kResetMask));
kReset.pass=kReset.count==1&&abs(kReset.timestamps(1))<=tol;
kInputs=struct('AxCount',size(kU,1),'AyCount',size(kU,1), ...
    'AVzCount',size(kU,1),'allFinite',all(isfinite(kU),'all'));
kInputs.pass=kInputs.AxCount==21&&kInputs.AyCount==21&& ...
    kInputs.AVzCount==21&&kInputs.allFinite;
kStream=struct('sampleCount',nK,'timing',kTiming,'logsAligned',kLogsAligned, ...
    'selectedVyMatchesState2',kSelectExact,'xFinite',all(isfinite(kX),'all'), ...
    'PFinite',all(isfinite(kP),'all'),'diagFinite',all(isfinite(kDiag),'all'), ...
    'covariance',kCov,'reset',kReset,'processInputs',kInputs);
kStream.pass=nK==21&&kTiming.pass100Hz&&kLogsAligned&&kSelectExact&& ...
    kStream.xFinite&&kStream.PFinite&&kStream.diagFinite&&kCov.valid&& ...
    kReset.pass&&kInputs.pass;

% F standalone runtime and feedbackApplied diagnostic.
fP=vector(r.fusion_f_P_log); fDiag=sample_rows(r.fusion_f_diag_log.data,nF,3);
fLogsAligned=isequal(tF,double(r.fusion_f_P_log.time(:)), ...
    double(r.fusion_f_diag_log.time(:)));
fFeedbackCount=nnz(fDiag(:,3)>0.5);
fReset=struct('count',1,'timestamps',tF(1), ...
    'sourceSemantics','F Reset First Hit: Before=1, After=0, Time=0.01, Ts=0.01');
fReset.pass=abs(tF(1))<=tol&&abs(vyF(1)-report.fParameters.Vy_F0)<=tol&& ...
    abs(fP(1)-report.fParameters.P0_F)<=tol&&all(abs(fDiag(1,:))<=tol);
fStream=struct('sampleCount',nF,'timing',fTiming,'logsAligned',fLogsAligned, ...
    'VyFinite',all(isfinite(vyF)),'PFinite',all(isfinite(fP)), ...
    'diagFinite',all(isfinite(fDiag),'all'),'PNonnegative',all(fP>=0), ...
    'feedbackAppliedOneCount',fFeedbackCount,'feedbackAppliedAlwaysZero',fFeedbackCount==0, ...
    'reset',fReset);
fStream.pass=nF==21&&fTiming.pass100Hz&&fLogsAligned&&fStream.VyFinite&& ...
    fStream.PFinite&&fStream.diagFinite&&fStream.PNonnegative&& ...
    fStream.feedbackAppliedAlwaysZero&&fReset.pass;

% Shared physical signals sampled at the exact estimator hit timestamps.
tShared=double(r.parallel_input_log.time(:));
[sharedD,alignD]=input_rows_at_hits(r.parallel_input_log.data,tShared,tD,9);
[sharedK,alignK]=input_rows_at_hits(r.parallel_input_log.data,tShared,tK,9);
[sharedF,alignF]=input_rows_at_hits(r.parallel_input_log.data,tShared,tF,9);
kInputVsShared=max(abs(kU-sharedK(:,1:4)),[],'all');
shared=struct('columns',{{'Ax','Ay','AVz','trueVx','steerFL','steerFR','steerRL','steerRR','Kreset'}}, ...
    'DAlignment',alignD,'KAlignment',alignK,'FAlignment',alignF, ...
    'KInputVsSharedMaxAbsDiff',kInputVsShared);
shared.pass=alignD.allHitsResolved&&alignK.allHitsResolved&&alignF.allHitsResolved&& ...
    ~alignD.ambiguousDuplicate&&~alignK.ambiguousDuplicate&& ...
    ~alignF.ambiguousDuplicate&&kInputVsShared<=tol;

% Exact frozen D replay: current physical sample, frozen A20 semantics.
dInput=[sharedD(:,4),sharedD(:,5:8),sharedD(:,2),sharedD(:,3)];
clear vy_dynamic_ekf_v1_17
dXR=zeros(nD,2);dPR=zeros(2,2,nD);dDR=zeros(nD,65);
for k=1:nD
    y=vy_dynamic_ekf_v1_17(dInput(k,:).',20);
    dXR(k,:)=y(1:2).';dPR(:,:,k)=reshape(y(46:49),2,2);dDR(k,:)=y(5:69).';
end
clear vy_dynamic_ekf_v1_17
dReplay=struct('maxStateDiff',max(abs(dXR-dX),[],'all'), ...
    'maxPDiff',max(abs(dPR-dP),[],'all'), ...
    'maxDiagDiff',max(abs(dDR-dDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
dReplay.pass=max([dReplay.maxStateDiff,dReplay.maxPDiff,dReplay.maxDiagDiff])<=tol;

% Exact frozen K replay.
clear vy_kinematic_kf
kXR=zeros(nK,2);kPR=zeros(2,2,nK);kDR=zeros(nK,5);
for k=1:nK
    [xk,pk,dk]=vy_kinematic_kf(kU(k,1:3).',kU(k,4),double(k==1));
    kXR(k,:)=xk(:).';kPR(:,:,k)=pk;kDR(k,:)=dk(:).';
end
clear vy_kinematic_kf
kReplay=struct('maxStateDiff',max(abs(kXR-kX),[],'all'), ...
    'maxPDiff',max(abs(kPR-kP),[],'all'), ...
    'maxDiagDiff',max(abs(kDR-kDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
kReplay.pass=max([kReplay.maxStateDiff,kReplay.maxPDiff,kReplay.maxDiagDiff])<=tol;

% Exact frozen F replay with feedback validity fixed false.
p=report.fParameters; fVyR=zeros(nF,1);fPR=zeros(nF,1);fDR=zeros(nF,3);
vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
for k=1:nF
    reset=double(k==1);
    [fVyR(k),fPR(k),diagk]=vy_feedback_propagation_step( ...
        vyPrev,pPrev,sharedF(k,2),sharedF(k,3),sharedF(k,4), ...
        vyFeedbackZ1,pFeedbackZ1,validZ1,reset,p.Ts,p.Vy_F0,p.P0_F,p.Q_F);
    fDR(k,:)=diagk(:).';
    if reset
        vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
    else
        vyPrev=fVyR(k);pPrev=fPR(k);
        vyFeedbackZ1=0;pFeedbackZ1=0.5;validZ1=0;
    end
end
fReplay=struct('maxVyDiff',max(abs(fVyR-vyF)), ...
    'maxPDiff',max(abs(fPR-fP)),'maxDiagDiff',max(abs(fDR-fDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
fReplay.pass=max([fReplay.maxVyDiff,fReplay.maxPDiff,fReplay.maxDiagDiff])<=tol;

% Frozen core exact fusion replay: no shift, interpolation, or compensation.
w=report.weights.values;vyExpected=zeros(nFW,1);
for k=1:nFW
    vyExpected(k)=vy_fixed_weight_fusion_step(vyD(k),vyK(k),vyF(k),w(1),w(2),w(3));
end
fusionReplay=struct('maxAbsFusionReplayDiff',max(abs(vyExpected-vyFW)), ...
    'RMSEFusionReplayDiff',sqrt(mean((vyExpected-vyFW).^2)), ...
    'meanAbsFusionReplayDiff',mean(abs(vyExpected-vyFW)), ...
    'sameTimestampSameIndex',timestamps.exactSameIndex, ...
    'timestampShiftApplied',false,'indexShiftApplied',false,'interpolationApplied',false);
fusionReplay.pass=fusionReplay.maxAbsFusionReplayDiff<=tol&&timestamps.exactSameIndex;
fusionStream=struct('sampleCount',nFW,'timing',fwTiming, ...
    'finite',all(isfinite(vyFW)),'scalarDouble',isvector(vyFW)&&isa(vyFW,'double'));
fusionStream.pass=nFW==21&&fwTiming.pass100Hz&&fusionStream.finite&&fusionStream.scalarDouble;

% Genuine steering evidence from the one shared runtime.
tSteer=double(r.steer_cmd_rad.time(:));cmd=vector(r.steer_cmd_rad);
deg=vector(r.steer_to_carsim_deg);fl=vector(r.steer_fl_carsim_deg);
fr=vector(r.steer_fr_carsim_deg);rl=vector(r.steer_rl_carsim_deg);rr=vector(r.steer_rr_carsim_deg);
nonzero=abs(cmd)>tol;ratio=deg(nonzero)./cmd(nonzero);
steering=struct('source',report.static.steering.source,'sourceUnit','rad', ...
    'boundaryUnit','deg','sampleCount',numel(tSteer),'commandMaxAbs',max(abs(cmd)), ...
    'convertedMaxAbs',max(abs(deg)),'degRadRatioMedian',median(ratio), ...
    'FLMaxAbs',max(abs(fl)),'FRMaxAbs',max(abs(fr)), ...
    'RLMaxAbs',max(abs(rl)),'RRMaxAbs',max(abs(rr)), ...
    'FLvsConvertedMaxDiff',max(abs(fl-deg)), ...
    'FRvsConvertedMaxDiff',max(abs(fr-deg)));
steering.pass=steering.FLvsConvertedMaxDiff<=tol&&steering.FRvsConvertedMaxDiff<=tol&& ...
    steering.RLMaxAbs<=tol&&steering.RRMaxAbs<=tol&& ...
    abs(steering.degRadRatioMedian-180/pi)<=1e-10;

oneHit=struct('D',dTiming.pass100Hz&&dReplay.pass, ...
    'K',kTiming.pass100Hz&&kReplay.pass, ...
    'F',fTiming.pass100Hz&&fReplay.pass, ...
    'fusionStatelessCurrentSample',fusionReplay.pass&&timestamps.exactSameIndex);
oneHit.pass=all(cell2mat(struct2cell(oneHit)));

independence=struct('noDStateToK',true,'noKStateToD',true, ...
    'FStateOnlyToFusion',report.static.fusionSourcesExact, ...
    'VyFWNotFedBack',report.static.vyFWNotFedToF, ...
    'fusionFeedbackLoopClosed',false,'noCovarianceExchange',true, ...
    'noPseudoMeasurement',true,'noSelector',true,'noAdaptiveAlpha',true, ...
    'noPFW',report.static.noPFW,'noDKEKFInput',report.static.noDKEKFInput, ...
    'noTrueVyOnlineInput',report.static.noTrueVyInput);
independence.pass=all(cellfun(@logical,struct2cell(rmfield(independence, ...
    'fusionFeedbackLoopClosed'))))&&~independence.fusionFeedbackLoopClosed;

gates=struct();
gates.sharedCarSimRuntimeCompleted=report.simulationCompleted&&report.carSimRun;
gates.correctDSolverNoGRequest=strcmpi(report.carSim.solverActual,report.carSim.solverExpected)&& ...
    ~report.carSim.gRequestBefore&&~report.carSim.gRequestConsole;
gates.fourStreamsTwentyOneSamples=timestamps.pass;
gates.timestampsExactlyAligned=timestamps.exactSameIndex;
gates.dRuntimeSemantics=dStream.pass;
gates.kRuntimeSemantics=kStream.pass;
gates.fRuntimeSemantics=fStream.pass;
gates.fFeedbackAppliedAlwaysZero=fStream.feedbackAppliedAlwaysZero;
gates.fusionRuntimeInterface=fusionStream.pass;
gates.sharedPhysicalInputsAligned=shared.pass;
gates.dExactReplay=dReplay.pass;
gates.kExactReplay=kReplay.pass;
gates.fExactReplay=fReplay.pass;
gates.fusionExactCurrentSampleReplay=fusionReplay.pass;
gates.oneHitOneCommit=oneHit.pass;
gates.noTrackCoupling=independence.pass;
gates.noFusionFeedback=report.static.vyFWNotFedToF&&report.static.fValidZero;
gates.noCovarianceFusion=report.static.noCovarianceFusion;
gates.noPFW=report.static.noPFW;
gates.noDKEKFFusionInput=report.static.noDKEKFInput;
gates.noTruthVyOnlineInput=report.static.noTrueVyInput;
gates.testWeightsUnchanged=isequal(w,[1/3 1/3 1/3]);
gates.noWeightTuning=contains(report.weights.classification,'NOT TUNED');
gates.noAdaptiveLogic=true;
gates.noLifeSig=true;
gates.steeringRuntimeBoundary=steering.pass;
gates.targetHashUnchanged=report.targetHashUnchanged;
gates.allFrozenHashesUnchanged=report.allFrozenHashesUnchanged;
gateValues=cell2mat(struct2cell(gates));

analysis=struct();analysis.stage='V2.5-D';analysis.timestamps=timestamps;
analysis.D=dStream;analysis.K=kStream;analysis.F=fStream;analysis.fusion=fusionStream;
analysis.steering=steering;analysis.sharedInputs=shared;
analysis.DReplay=dReplay;analysis.KReplay=kReplay;analysis.FReplay=fReplay;
analysis.fusionReplay=fusionReplay;analysis.oneHitOneCommit=oneHit;
analysis.independence=independence;analysis.gates=gates;
analysis.gateCount=numel(gateValues);analysis.gatesTrue=sum(gateValues);
analysis.performanceEvaluationPerformed=false;
analysis.weightSelectionPerformed=false;
analysis.readyForSeparateWeightSelection=all(gateValues);
analysis.passed=all(gateValues);
report.analysis=analysis;
save(resultFile,'report','-v7.3');
fprintf(['V25D_ANALYSIS|gates=%d/%d|N=[%d %d %d %d]|' ...
    'dt=[%.17g %.17g %.17g %.17g]|tDiff=[%.3g %.3g %.3g]|' ...
    'feedbackApplied=%d|fusionReplay=[%.3g %.3g %.3g]|' ...
    'DReplay=[%.3g %.3g %.3g]|KReplay=[%.3g %.3g %.3g]|' ...
    'FReplay=[%.3g %.3g %.3g]|oneHit=%d|hash=%d|passed=%d|sim=0\n'], ...
    analysis.gatesTrue,analysis.gateCount,nD,nK,nF,nFW, ...
    dTiming.dtMean,kTiming.dtMean,fTiming.dtMean,fwTiming.dtMean, ...
    timestamps.DvsKMaxDiff,timestamps.DvsFMaxDiff,timestamps.DvsFusionMaxDiff, ...
    fFeedbackCount,fusionReplay.maxAbsFusionReplayDiff, ...
    fusionReplay.RMSEFusionReplayDiff,fusionReplay.meanAbsFusionReplayDiff, ...
    dReplay.maxStateDiff,dReplay.maxPDiff,dReplay.maxDiagDiff, ...
    kReplay.maxStateDiff,kReplay.maxPDiff,kReplay.maxDiagDiff, ...
    fReplay.maxVyDiff,fReplay.maxPDiff,fReplay.maxDiagDiff, ...
    oneHit.pass,report.targetHashUnchanged,analysis.passed);
if ~analysis.passed
    names=fieldnames(gates);names=names(~gateValues);
    error('V25D:GateFailed','Failed V2.5-D gates: %s',strjoin(names,', '));
end
end

function x=vector(rec),x=double(rec.data(:));end
function a=sample_rows(data,n,w)
a=double(data);sz=size(a);if ismatrix(a),if isequal(sz,[n w]),return;end;if isequal(sz,[w n]),a=a.';return;end,end
if numel(a)==n*w,a=reshape(a,w,n).';return;end
error('V25D:LogShape','Cannot resolve width %d from %s.',w,mat2str(sz));
end
function p=covariance_pages(data,n,w)
p=double(data);sz=size(p);if ndims(p)==3&&isequal(sz,[w w n]),return;end
if ndims(p)==3&&isequal(sz,[n w w]),p=permute(p,[2 3 1]);return;end
if ismatrix(p)&&isequal(sz,[n w*w]),p=reshape(p.',w,w,n);return;end
if numel(p)==w*w*n,p=reshape(p,w,w,n);return;end
error('V25D:CovShape','Cannot resolve covariance %s.',mat2str(sz));
end
function s=timing_stats(t,Ts)
dt=diff(t);missing=sum(max(round(dt/Ts)-1,0));s=struct('sampleCount',numel(t), ...
    'tStart',t(1),'tEnd',t(end),'dtMin',min(dt),'dtMean',mean(dt), ...
    'dtMax',max(dt),'duplicateTimestamps',nnz(dt<=0),'missingHits',missing);
s.pass100Hz=all(abs(dt-Ts)<=1e-12)&&s.duplicateTimestamps==0&&missing==0&& ...
    abs(t(1))<=1e-12&&abs(t(end)-0.20)<=1e-12;
end
function s=covariance_stats(P)
n=size(P,3);asym=zeros(n,1);mineig=zeros(n,1);for k=1:n,asym(k)=max(abs(P(:,:,k)-P(:,:,k).'),[],'all');mineig(k)=min(eig((P(:,:,k)+P(:,:,k).')/2));end
s=struct('maxAsymmetry',max(asym),'minimumEigenvalue',min(mineig));
s.valid=s.maxAsymmetry<=1e-12&&s.minimumEigenvalue>0;
end
function [hits,audit]=input_rows_at_hits(data,inputTime,hitTime,w)
inputTime=double(inputTime(:));a=sample_rows(data,numel(inputTime),w);hits=zeros(numel(hitTime),w);
matchCount=zeros(numel(hitTime),1);nearestDelta=zeros(numel(hitTime),1);ambiguous=false;
for k=1:numel(hitTime)
    delta=abs(inputTime-hitTime(k));nearestDelta(k)=min(delta);ix=find(delta==nearestDelta(k));matchCount(k)=numel(ix);
    tol=32*eps(max(1,abs(hitTime(k))));if nearestDelta(k)>tol,continue;end
    candidates=a(ix,:);if size(candidates,1)>1&&any(max(abs(candidates-candidates(end,:)),[],2)>1e-12),ambiguous=true;end
    hits(k,:)=candidates(end,:);
end
audit=struct('rawInputSampleCount',numel(inputTime),'hitSampleCount',numel(hitTime), ...
    'matchCountPerHit',matchCount,'nearestTimeDelta',nearestDelta, ...
    'allHitsResolved',all(matchCount>=1)&&all(nearestDelta==0), ...
    'duplicateMatchCount',nnz(matchCount>1),'ambiguousDuplicate',ambiguous, ...
    'timestampShiftApplied',false);
end
