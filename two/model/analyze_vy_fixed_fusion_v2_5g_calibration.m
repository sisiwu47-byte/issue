function report = analyze_vy_fixed_fusion_v2_5g_calibration(runId)
%ANALYZE_VY_FIXED_FUSION_V2_5G_CALIBRATION Analyze one saved run; never simulates.

root=fileparts(fileparts(mfilename('fullpath')));
registryFile=fullfile(root,'results','vy_fixed_fusion_v2_5f_run_registry.csv');
suiteFile=fullfile(root,'results','vy_fixed_fusion_v2_5f_suite_plan.csv');
manifestFile=fullfile(root,'results','vy_fixed_fusion_v2_5g_calibration_acquisition_manifest.csv');
registry=readtable(registryFile,'TextType','string');
suite=readtable(suiteFile,'TextType','string');
runId=upper(string(runId));
reg=registry(registry.run_id==runId,:); row=suite(suite.run_id==runId,:);
assert(height(reg)==1&&height(row)==1&&reg.role=="CALIBRATION_ONLY", ...
    'V25G:Registry','Run is not a unique calibration registration.');
resultFile=fullfile(root,strrep(char(reg.result_path_reserved),'/',filesep));
assert(isfile(resultFile),'V25G:MissingEvidence','Saved runtime MAT is missing.');
S=load(resultFile,'report'); report=S.report;
assert(strcmp(report.runId,runId)&&report.simCalled&& ...
    report.runtimeAuthorizationConsumed&&report.simulationCompleted&&report.carSimRun, ...
    'V25G:RuntimeEvidence','Saved completion evidence is incomplete.');
assert(~isfield(report,'analysis'),'V25G:AlreadyAnalyzed', ...
    'This immutable run has already been analyzed and registered.');

r=report.raw; tol=1e-12; duration=report.runCard.durationS;
expectedN=round(duration/0.01)+1;

% Common 100-Hz output grid.
tD=double(r.fusion_vy_d_log.time(:)); tK=double(r.fusion_vy_k_log.time(:));
tF=double(r.fusion_vy_f_log.time(:)); tFW=double(r.fusion_vy_fw_log.time(:));
nD=numel(tD);nK=numel(tK);nF=numel(tF);nFW=numel(tFW);
dTiming=timing_stats(tD,0.01,duration);kTiming=timing_stats(tK,0.01,duration);
fTiming=timing_stats(tF,0.01,duration);fwTiming=timing_stats(tFW,0.01,duration);
timestamps=struct();timestamps.D=dTiming;timestamps.K=kTiming;timestamps.F=fTiming;
timestamps.fusion=fwTiming;timestamps.DvsKMaxDiff=max_pair_diff(tD,tK);
timestamps.DvsFMaxDiff=max_pair_diff(tD,tF);
timestamps.DvsFusionMaxDiff=max_pair_diff(tD,tFW);
timestamps.exactSameIndex=isequal(tD,tK,tF,tFW);
timestamps.pass=nD==expectedN&&nK==expectedN&&nF==expectedN&&nFW==expectedN&& ...
    dTiming.pass&&kTiming.pass&&fTiming.pass&&fwTiming.pass&&timestamps.exactSameIndex;

vyD=vector(r.fusion_vy_d_log);vyK=vector(r.fusion_vy_k_log);
vyF=vector(r.fusion_vy_f_log);vyFW=vector(r.fusion_vy_fw_log);

% D integrity and frozen exact replay inputs.
dX=sample_rows(r.dekf_x_log.data,nD,2);
dP=covariance_pages(r.dekf_P_log.data,nD,2);
dDiag=sample_rows(r.dekf_diag_log.data,nD,65);
dLogsAligned=isequal(tD,double(r.dekf_x_log.time(:)), ...
    double(r.dekf_P_log.time(:)),double(r.dekf_diag_log.time(:)));
dCov=covariance_stats(dP);dStepIndex=dDiag(:,57);dAyGate=dDiag(:,56)>0.5;
dResetMask=abs(dStepIndex)<tol;
dReset=struct('count',nnz(dResetMask),'timestamps',tD(dResetMask));
dReset.pass=dReset.count==1&&abs(dReset.timestamps(1))<=tol&& ...
    isequal(dStepIndex(:),(0:nD-1).');
expectedAyT=(0:0.05:duration).';
dAy=struct('count',nnz(dAyGate),'expectedCount',numel(expectedAyT), ...
    'timestamps',tD(dAyGate),'expectedTimestamps',expectedAyT);
dAy.pass=dAy.count==dAy.expectedCount&& ...
    max_pair_diff(dAy.timestamps,dAy.expectedTimestamps)<=tol;
dStream=struct('sampleCount',nD,'timing',dTiming,'logsAligned',dLogsAligned, ...
    'selectedVyMatchesState1',max(abs(vyD-dX(:,1)))<=tol, ...
    'xFinite',all(isfinite(dX),'all'),'PFinite',all(isfinite(dP),'all'), ...
    'diagFinite',all(isfinite(dDiag),'all'),'covariance',dCov, ...
    'reset',dReset,'AyUpdate',dAy);
dStream.pass=dStream.sampleCount==expectedN&&dStream.timing.pass&& ...
    dStream.logsAligned&&dStream.selectedVyMatchesState1&&dStream.xFinite&& ...
    dStream.PFinite&&dStream.diagFinite&&dCov.valid&&dReset.pass&&dAy.pass;

% K integrity and process-input consumption.
kU=sample_rows(r.kkf_u_log1.data,nK,4);kX=sample_rows(r.kkf_x_log1.data,nK,2);
kP=covariance_pages(r.kkf_P_log1.data,nK,2);
kDiag=sample_rows(r.kkf_diag_log1.data,nK,5);
kLogsAligned=isequal(tK,double(r.kkf_u_log1.time(:)), ...
    double(r.kkf_x_log1.time(:)),double(r.kkf_P_log1.time(:)), ...
    double(r.kkf_diag_log1.time(:)));
kCov=covariance_stats(kP);kResetRaw=vector(r.reset_g0);kResetTime=double(r.reset_g0.time(:));
kResetMask=kResetRaw>0.5;kReset=struct('count',nnz(kResetMask), ...
    'timestamps',kResetTime(kResetMask));
kReset.pass=kReset.count==1&&abs(kReset.timestamps(1))<=tol;
kInputs=struct('AxCount',size(kU,1),'AyCount',size(kU,1), ...
    'AVzCount',size(kU,1),'VxCount',size(kU,1),'allFinite',all(isfinite(kU),'all'));
kInputs.pass=all([kInputs.AxCount kInputs.AyCount kInputs.AVzCount kInputs.VxCount]==expectedN)&&kInputs.allFinite;
kStream=struct('sampleCount',nK,'timing',kTiming,'logsAligned',kLogsAligned, ...
    'selectedVyMatchesState2',max(abs(vyK-kX(:,2)))<=tol, ...
    'xFinite',all(isfinite(kX),'all'),'PFinite',all(isfinite(kP),'all'), ...
    'diagFinite',all(isfinite(kDiag),'all'),'covariance',kCov, ...
    'reset',kReset,'processInputs',kInputs);
kStream.pass=kStream.sampleCount==expectedN&&kStream.timing.pass&& ...
    kStream.logsAligned&&kStream.selectedVyMatchesState2&&kStream.xFinite&& ...
    kStream.PFinite&&kStream.diagFinite&&kCov.valid&&kReset.pass&&kInputs.pass;

% F standalone integrity.
fP=vector(r.fusion_f_P_log);fDiag=sample_rows(r.fusion_f_diag_log.data,nF,3);
fLogsAligned=isequal(tF,double(r.fusion_f_P_log.time(:)),double(r.fusion_f_diag_log.time(:)));
fFeedbackCount=nnz(fDiag(:,3)>0.5);
fReset=struct('count',1,'timestamps',tF(1), ...
    'sourceSemantics','F Reset First Hit: Before=1, After=0, Time=0.01, Ts=0.01');
fReset.pass=abs(tF(1))<=tol&&abs(vyF(1)-report.fParameters.Vy_F0)<=tol&& ...
    abs(fP(1)-report.fParameters.P0_F)<=tol&&all(abs(fDiag(1,:))<=tol);
fStream=struct('sampleCount',nF,'timing',fTiming,'logsAligned',fLogsAligned, ...
    'VyFinite',all(isfinite(vyF)),'PFinite',all(isfinite(fP)), ...
    'diagFinite',all(isfinite(fDiag),'all'),'PNonnegative',all(fP>=0), ...
    'feedbackAppliedOneCount',fFeedbackCount, ...
    'feedbackAppliedAlwaysZero',fFeedbackCount==0,'reset',fReset);
fStream.pass=fStream.sampleCount==expectedN&&fStream.timing.pass&&fLogsAligned&& ...
    fStream.VyFinite&&fStream.PFinite&&fStream.diagFinite&&fStream.PNonnegative&& ...
    fStream.feedbackAppliedAlwaysZero&&fReset.pass;

% Shared input resolution at exact estimator hits.
tShared=double(r.parallel_input_log.time(:));
[sharedD,alignD]=input_rows_at_hits(r.parallel_input_log.data,tShared,tD,9);
[sharedK,alignK]=input_rows_at_hits(r.parallel_input_log.data,tShared,tK,9);
[sharedF,alignF]=input_rows_at_hits(r.parallel_input_log.data,tShared,tF,9);
kInputVsShared=max(abs(kU-sharedK(:,1:4)),[],'all');
shared=struct();shared.columns={'Ax','Ay','AVz','trueVx','steerFL','steerFR','steerRL','steerRR','Kreset'};
shared.DAlignment=alignD;shared.KAlignment=alignK;shared.FAlignment=alignF;
shared.KInputVsSharedMaxAbsDiff=kInputVsShared;
shared.pass=alignD.allHitsResolved&&alignK.allHitsResolved&&alignF.allHitsResolved&& ...
    ~alignD.ambiguousDuplicate&&~alignK.ambiguousDuplicate&& ...
    ~alignF.ambiguousDuplicate&&kInputVsShared<=tol;

% Frozen D exact replay.
dInput=[sharedD(:,4),sharedD(:,5:8),sharedD(:,2),sharedD(:,3)];
clear vy_dynamic_ekf_v1_17
dXR=zeros(nD,2);dPR=zeros(2,2,nD);dDR=zeros(nD,65);
for k=1:nD
    y=vy_dynamic_ekf_v1_17(dInput(k,:).',20);
    dXR(k,:)=y(1:2).';dPR(:,:,k)=reshape(y(46:49),2,2);dDR(k,:)=y(5:69).';
end
clear vy_dynamic_ekf_v1_17
dReplay=struct('maxStateDiff',max(abs(dXR-dX),[],'all'), ...
    'maxPDiff',max(abs(dPR-dP),[],'all'),'maxDiagDiff',max(abs(dDR-dDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
dReplay.pass=max([dReplay.maxStateDiff dReplay.maxPDiff dReplay.maxDiagDiff])<=tol;

% Frozen K exact replay.
clear vy_kinematic_kf
kXR=zeros(nK,2);kPR=zeros(2,2,nK);kDR=zeros(nK,5);
for k=1:nK
    [xk,pk,dk]=vy_kinematic_kf(kU(k,1:3).',kU(k,4),double(k==1));
    kXR(k,:)=xk(:).';kPR(:,:,k)=pk;kDR(k,:)=dk(:).';
end
clear vy_kinematic_kf
kReplay=struct('maxStateDiff',max(abs(kXR-kX),[],'all'), ...
    'maxPDiff',max(abs(kPR-kP),[],'all'),'maxDiagDiff',max(abs(kDR-kDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
kReplay.pass=max([kReplay.maxStateDiff kReplay.maxPDiff kReplay.maxDiagDiff])<=tol;

% Frozen F exact replay, validity fixed false.
p=report.fParameters;fVyR=zeros(nF,1);fPR=zeros(nF,1);fDR=zeros(nF,3);
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
        vyPrev=fVyR(k);pPrev=fPR(k);vyFeedbackZ1=0;pFeedbackZ1=0.5;validZ1=0;
    end
end
fReplay=struct('maxVyDiff',max(abs(fVyR-vyF)), ...
    'maxPDiff',max(abs(fPR-fP)),'maxDiagDiff',max(abs(fDR-fDiag),[],'all'), ...
    'timestampShiftApplied',false,'indexShiftApplied',false);
fReplay.pass=max([fReplay.maxVyDiff fReplay.maxPDiff fReplay.maxDiagDiff])<=tol;

% Frozen current-sample fixed-weight fusion replay (integrity only, no selection).
w=report.weights.values;vyExpected=zeros(nFW,1);
for k=1:nFW
    vyExpected(k)=vy_fixed_weight_fusion_step(vyD(k),vyK(k),vyF(k),w(1),w(2),w(3));
end
fusionReplay=struct('maxAbsFusionReplayDiff',max(abs(vyExpected-vyFW)), ...
    'RMSEFusionReplayDiff',sqrt(mean((vyExpected-vyFW).^2)), ...
    'meanAbsFusionReplayDiff',mean(abs(vyExpected-vyFW)), ...
    'sameTimestampSameIndex',timestamps.exactSameIndex,'timestampShiftApplied',false, ...
    'indexShiftApplied',false,'interpolationApplied',false);
fusionReplay.pass=fusionReplay.maxAbsFusionReplayDiff<=tol&&timestamps.exactSameIndex;

% Actual runtime steering, checked pointwise against the registered sine.
tSteer=double(r.steer_cmd_rad.time(:));cmd=vector(r.steer_cmd_rad);
deg=vector(r.steer_to_carsim_deg);flDeg=vector(r.steer_fl_carsim_deg);
frDeg=vector(r.steer_fr_carsim_deg);rlDeg=vector(r.steer_rl_carsim_deg);
rrDeg=vector(r.steer_rr_carsim_deg);A=report.runCard.steerAmplitudeRad;
freq=report.runCard.steerFrequencyHz;cmdExpected=A*sin(2*pi*freq*tSteer);
nonzero=abs(cmd)>tol;ratio=deg(nonzero)./cmd(nonzero);
steering=struct();steering.sourceUnit='rad';steering.boundaryUnit='deg';
steering.sampleCount=numel(tSteer);steering.commandMaxAbs=max(abs(cmd));
steering.expectedSampledMaxAbs=max(abs(cmdExpected));
steering.waveformMaxAbsDiff=max(abs(cmd-cmdExpected));
steering.frequencyHz=freq;steering.periodS=1/freq;steering.completedCycles=freq*duration;
steering.convertedMaxAbsDeg=max(abs(deg));steering.degRadRatioMedian=median(ratio);
steering.FLMaxAbsRad=max(abs(flDeg*pi/180));steering.FRMaxAbsRad=max(abs(frDeg*pi/180));
steering.RLMaxAbsRad=max(abs(rlDeg*pi/180));steering.RRMaxAbsRad=max(abs(rrDeg*pi/180));
steering.FLvsConvertedMaxDiffDeg=max(abs(flDeg-deg));
steering.FRvsConvertedMaxDiffDeg=max(abs(frDeg-deg));
steering.FLvsFRMaxDiffRad=max(abs((flDeg-frDeg)*pi/180));
steering.actualRad=struct('time',tSteer,'command',cmd,'FL',flDeg*pi/180, ...
    'FR',frDeg*pi/180,'RL',rlDeg*pi/180,'RR',rrDeg*pi/180);
steering.pass=steering.waveformMaxAbsDiff<=tol&& ...
    abs(steering.commandMaxAbs-steering.expectedSampledMaxAbs)<=tol&& ...
    steering.FLvsConvertedMaxDiffDeg<=tol&&steering.FRvsConvertedMaxDiffDeg<=tol&& ...
    steering.FLvsFRMaxDiffRad<=tol&&steering.RLMaxAbsRad<=tol&& ...
    steering.RRMaxAbsRad<=tol&&abs(steering.degRadRatioMedian-180/pi)<=1e-10;

% Registered truth alignment: direct timestamps, else linear/no extrapolation/no shift.
[vyTrue,truthAlignment]=align_truth(r.vy_true_log1,tFW,duration);
[vxActual,vxAlignment]=align_truth(r.Vx_true_log,tFW,duration);
truth=struct();truth.Vy=vyTrue;truth.Vx=vxActual;truth.VyAlignment=truthAlignment;
truth.VxAlignment=vxAlignment;truth.VxStats=struct('min',min(vxActual), ...
    'mean',mean(vxActual),'max',max(vxActual),'median',median(vxActual));
truth.onlineUse=false;truth.offlineCalibrationOnly=true;
truth.pass=truthAlignment.pass&&vxAlignment.pass&&all(isfinite(vyTrue))&&all(isfinite(vxActual));

evaluation=struct('registeredWindowS',[0 duration],'mask',tFW>=0&tFW<=duration, ...
    'sampleCount',nnz(tFW>=0&tFW<=duration),'transientRemovalApplied',false, ...
    'crossCorrelationShiftApplied',false,'perTrackAlignmentApplied',false);
evaluation.pass=all(evaluation.mask)&&evaluation.sampleCount==expectedN&& ...
    abs(tFW(1))<=tol&&abs(tFW(end)-duration)<=tol;

gates=struct();
gates.runtimeCompleted=report.simulationCompleted&&report.carSimRun;
gates.correctSolverNoG=strcmpi(report.carSim.solverActual,report.carSim.solverExpected)&& ...
    ~report.carSim.gRequestBefore&&~report.carSim.gRequestConsole;
gates.actualManeuverMatchesPreregistration=steering.pass;
gates.commonTiming=timestamps.pass;
gates.dRuntimeIntegrity=dStream.pass;
gates.kRuntimeIntegrity=kStream.pass;
gates.fRuntimeIntegrity=fStream.pass;
gates.fFeedbackAppliedAlwaysZero=fFeedbackCount==0;
gates.sharedInputsAtHits=shared.pass;
gates.dExactReplay=dReplay.pass;
gates.kExactReplay=kReplay.pass;
gates.fExactReplay=fReplay.pass;
gates.fusionExactReplay=fusionReplay.pass;
gates.truthAvailableAndAligned=truth.pass;
gates.registeredEvaluationWindow=evaluation.pass;
gates.targetHashUnchanged=report.targetHashUnchanged;
gates.allFrozenHashesUnchanged=report.allFrozenHashesUnchanged;
gates.preregistrationUnchanged=report.preregistrationUnchanged;
gates.noWeightSelection=true;gates.noHoldoutRuntime=true;
gateValues=cell2mat(struct2cell(gates));

analysis=struct();analysis.stage='V2.5-G';analysis.runId=char(runId);
analysis.timestamps=timestamps;analysis.D=dStream;analysis.K=kStream;analysis.F=fStream;
analysis.sharedInputs=shared;analysis.DReplay=dReplay;analysis.KReplay=kReplay;
analysis.FReplay=fReplay;analysis.fusionReplay=fusionReplay;
analysis.steering=steering;analysis.truth=truth;analysis.evaluation=evaluation;
analysis.gates=gates;analysis.gateCount=numel(gateValues);analysis.gatesTrue=sum(gateValues);
analysis.performanceBasedSelectionPerformed=false;analysis.weightSelectionPerformed=false;
analysis.alpha_D='UNSELECTED';analysis.alpha_K='UNSELECTED';analysis.alpha_F='UNSELECTED';
analysis.eligibleForCalibration=all(gateValues);analysis.passed=all(gateValues);
report.analysis=analysis;

dataset=struct();dataset.run_id=char(runId);dataset.role='CALIBRATION_ONLY';
dataset.preregisteredManeuver=table2struct(row);dataset.actualRuntimeSettings=report.runCard;
dataset.targetSHA256=report.targetHashAfter;
dataset.fusionCoreSHA256=hash_from_records(report.frozenAfter,'vy_fixed_weight_fusion_step.m');
dataset.fusionWrapperSHA256=hash_from_records(report.frozenAfter,'vy_fixed_weight_fusion_simulink_sfun.m');
dataset.carSimSolverPath=report.carSim.solverActual;dataset.activeSimfile=report.carSim.activeSimfile;
dataset.timestamps=struct('D',tD,'K',tK,'F',tF,'fusion',tFW);
dataset.Vy_D=vyD;dataset.Vy_K=vyK;dataset.Vy_F=vyF;dataset.Vy_FW=vyFW;
dataset.Vy_true=vyTrue;dataset.Vx_actual=vxActual;dataset.steeringActual=steering.actualRad;
dataset.resetEvidence=struct('D',dReset,'K',kReset,'F',fReset);
dataset.timingEvidence=timestamps;dataset.replayEvidence=struct('D',dReplay,'K',kReplay, ...
    'F',fReplay,'fusion',fusionReplay);dataset.evaluationWindow=evaluation;
dataset.truthAlignment=truthAlignment;dataset.runtimeCompletion=struct( ...
    'simCalled',report.simCalled,'simulationCompleted',report.simulationCompleted, ...
    'carSimRun',report.carSimRun);dataset.formalCalibrationEligibility=analysis.eligibleForCalibration;
dataset.alphaStatus='UNSELECTED';
save(resultFile,'report','dataset','-v7.3');

if ~analysis.passed
    names=fieldnames(gates);names=names(~gateValues);
    error('V25G:GateFailed','Failed %s gates: %s',runId,strjoin(names,', '));
end

resultHash=sha256(resultFile);
update_manifest(manifestFile,report,resultHash,analysis,reg);
fprintf(['V25G_ANALYSIS_OK|id=%s|gates=%d/%d|N=%d|dt=%.17g|' ...
    'Ay=%d/%d|feedbackApplied=%d|replay=[%.3g %.3g %.3g %.3g]|' ...
    'truth=%s|steerDiff=%.3g|hash=%s|eligible=%d|sim=0\n'], ...
    runId,analysis.gatesTrue,analysis.gateCount,nFW,fwTiming.dtMean, ...
    dAy.count,dAy.expectedCount,fFeedbackCount,dReplay.maxStateDiff, ...
    kReplay.maxStateDiff,fReplay.maxVyDiff,fusionReplay.maxAbsFusionReplayDiff, ...
    truthAlignment.method,steering.waveformMaxAbsDiff,resultHash,analysis.eligibleForCalibration);
end

function update_manifest(file,report,resultHash,a,reg)
row=table(string(report.runId),"CALIBRATION_ONLY",report.runCard.steerAmplitudeRad, ...
    report.runCard.steerFrequencyHz,string(report.runCard.waveform),report.runCard.durationS, ...
    report.runCard.steerAmplitudeRad,report.runCard.steerFrequencyHz, ...
    "COMPLETED","PASS",string(reg.result_path_reserved),string(resultHash), ...
    string(report.targetHashAfter),string(report.carSim.solverActual), ...
    a.timestamps.fusion.sampleCount,a.timestamps.fusion.tEnd,a.timestamps.exactSameIndex, ...
    a.DReplay.pass,a.KReplay.pass,a.FReplay.pass,a.fusionReplay.pass, ...
    a.F.feedbackAppliedOneCount,true,string(sprintf('[%.17g %.17g]', ...
    a.evaluation.registeredWindowS(1),a.evaluation.registeredWindowS(2))), ...
    string(a.truth.VyAlignment.method),string(report.runCard.truthAlignmentRule),"ELIGIBLE", ...
    'VariableNames',{'run_id','role','planned_amplitude_rad','planned_frequency_Hz', ...
    'planned_waveform','planned_duration_s','actual_amplitude_rad','actual_frequency_Hz', ...
    'runtime_status','integrity_status','result_path','result_sha256','target_sha256', ...
    'solver_path','sample_count','duration_s','timestamps_aligned','D_replay_pass', ...
    'K_replay_pass','F_replay_pass','fusion_replay_pass','feedbackApplied_count', ...
    'truth_available','evaluation_window_s','truth_alignment_actual', ...
    'truth_alignment_rule','formal_calibration_eligibility'});
if isfile(file)
    old=readtable(file,'TextType','string');
    assert(~any(old.run_id==string(report.runId)),'Manifest already contains this run.');
    out=[old;row];
else
    out=row;
end
writetable(out,file);
end

function [y,a]=align_truth(rec,tTarget,duration)
t=double(rec.time(:));x=vector(rec);assert(numel(t)==numel(x),'Truth shape mismatch.');
assert(all(isfinite(t))&&all(isfinite(x))&&all(diff(t)>=0),'Truth is nonfinite/nonmonotonic.');
[tu,~,group]=unique(t,'sorted');xu=zeros(numel(tu),1);ambiguous=false;
for k=1:numel(tu)
    v=x(group==k);xu(k)=v(end);ambiguous=ambiguous||(max(v)-min(v)>1e-12);
end
[tf,loc]=ismember(tTarget,tu);
if all(tf)
    y=xu(loc);method='DIRECT SAME-TIMESTAMP ALIGNMENT';interpolated=false;
else
    assert(tTarget(1)>=tu(1)&&tTarget(end)<=tu(end),'Truth extrapolation would be required.');
    y=interp1(tu,xu,tTarget,'linear');method='LINEAR NO-EXTRAPOLATION NO-SHIFT';interpolated=true;
end
a=struct('method',method,'registeredRule', ...
    'TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT', ...
    'rawSampleCount',numel(t),'uniqueSampleCount',numel(tu), ...
    'targetSampleCount',numel(tTarget),'rawStart',t(1),'rawEnd',t(end), ...
    'targetStart',tTarget(1),'targetEnd',tTarget(end),'duplicateCount',numel(t)-numel(tu), ...
    'ambiguousDuplicate',ambiguous,'interpolationApplied',interpolated, ...
    'extrapolationApplied',false,'timestampShiftApplied',false, ...
    'crossCorrelationApplied',false,'fullWindowCovered',t(1)<=0&&t(end)>=duration);
a.pass=all(isfinite(y))&&a.fullWindowCovered&&~a.ambiguousDuplicate&&~a.extrapolationApplied&&~a.timestampShiftApplied;
end

function x=vector(rec),x=double(rec.data(:));end
function a=sample_rows(data,n,w)
a=double(data);sz=size(a);
if ismatrix(a),if isequal(sz,[n w]),return;end;if isequal(sz,[w n]),a=a.';return;end,end
if numel(a)==n*w,a=reshape(a,w,n).';return;end
error('V25G:LogShape','Cannot resolve width %d from %s.',w,mat2str(sz));
end
function p=covariance_pages(data,n,w)
p=double(data);sz=size(p);if ndims(p)==3&&isequal(sz,[w w n]),return;end
if ndims(p)==3&&isequal(sz,[n w w]),p=permute(p,[2 3 1]);return;end
if ismatrix(p)&&isequal(sz,[n w*w]),p=reshape(p.',w,w,n);return;end
if numel(p)==w*w*n,p=reshape(p,w,w,n);return;end
error('V25G:CovShape','Cannot resolve covariance %s.',mat2str(sz));
end
function s=timing_stats(t,Ts,duration)
dt=diff(t);missing=sum(max(round(dt/Ts)-1,0));s=struct('sampleCount',numel(t), ...
    'tStart',t(1),'tEnd',t(end),'dtMin',min(dt),'dtMean',mean(dt), ...
    'dtMax',max(dt),'duplicateTimestamps',nnz(dt<=0),'missingHits',missing);
s.pass=all(abs(dt-Ts)<=1e-12)&&s.duplicateTimestamps==0&&missing==0&& ...
    abs(t(1))<=1e-12&&abs(t(end)-duration)<=1e-12;
end
function s=covariance_stats(P)
n=size(P,3);asym=zeros(n,1);mineig=zeros(n,1);
for k=1:n,asym(k)=max(abs(P(:,:,k)-P(:,:,k).'),[],'all');mineig(k)=min(eig((P(:,:,k)+P(:,:,k).')/2));end
s=struct('maxAsymmetry',max(asym),'minimumEigenvalue',min(mineig));
s.valid=s.maxAsymmetry<=1e-12&&s.minimumEigenvalue>0;
end
function [hits,audit]=input_rows_at_hits(data,inputTime,hitTime,w)
inputTime=double(inputTime(:));a=sample_rows(data,numel(inputTime),w);hits=zeros(numel(hitTime),w);
matchCount=zeros(numel(hitTime),1);nearestDelta=zeros(numel(hitTime),1);ambiguous=false;
for k=1:numel(hitTime)
    delta=abs(inputTime-hitTime(k));nearestDelta(k)=min(delta);ix=find(delta==nearestDelta(k));matchCount(k)=numel(ix);
    etol=32*eps(max(1,abs(hitTime(k))));if nearestDelta(k)>etol,continue;end
    candidates=a(ix,:);if size(candidates,1)>1&&any(max(abs(candidates-candidates(end,:)),[],2)>1e-12),ambiguous=true;end
    hits(k,:)=candidates(end,:);
end
audit=struct('rawInputSampleCount',numel(inputTime),'hitSampleCount',numel(hitTime), ...
    'matchCountPerHit',matchCount,'nearestTimeDelta',nearestDelta, ...
    'allHitsResolved',all(matchCount>=1)&&all(nearestDelta==0), ...
    'duplicateMatchCount',nnz(matchCount>1),'ambiguousDuplicate',ambiguous, ...
    'timestampShiftApplied',false);
end
function d=max_pair_diff(a,b)
if numel(a)~=numel(b),d=Inf;else,d=max(abs(a(:)-b(:)));end
end
function h=hash_from_records(records,suffix)
ix=find(endsWith(string({records.path}),suffix),1);assert(~isempty(ix),'Hash record missing.');h=records(ix).sha256;
end
function h=sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
b=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(b,2).',1,[]));clear c
end
