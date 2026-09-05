function [analysis,dataset] = analyze_vy_fixed_fusion_v2_5g1d_C01R1(varargin)
%ANALYZE_VY_FIXED_FUSION_V2_5G1D_C01R1 Analyze C01R1 without simulation.
% With (report,registryRow), performs in-memory analysis before the one-time
% immutable MAT save. With no inputs, reads that MAT and prints evidence only.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_fixed_fusion_v2_5g_FWCAL_C01R1.mat');
if nargin==0
    S=load(resultFile,'report','dataset');
    report=S.report;dataset=S.dataset;analysis=report.analysis;
    assert(strcmp(report.runId,'FWCAL_C01R1')&&analysis.passed&& ...
        dataset.formalCalibrationEligibility,'V25G1D:Evidence', ...
        'Immutable C01R1 evidence is incomplete or ineligible.');
    resultHash=sha256(resultFile);info=dir(resultFile);
    fprintf(['G1D_POST_ANALYSIS|id=%s|gates=%d/%d|N=[%d %d %d %d]|' ...
        't=[%.17g %.17g]|dt=[%.17g %.17g %.17g]|timeDiff=[%.17g %.17g %.17g]|' ...
        'Ay=%d/%d|Kinputs=[%d %d %d]|feedback=%d|replayD=[%.17g %.17g %.17g]|' ...
        'replayK=[%.17g %.17g %.17g]|replayF=[%.17g %.17g %.17g]|fusion=%.17g|' ...
        'truth=%s|truthN=[%d %d]|evalN=%d|steer=[%.17g %.17g %.17g %.17g]|' ...
        'Vx=[%.17g %.17g %.17g]|hash=%s|bytes=%d|eligible=%d|sim=0\n'], ...
        report.runId,analysis.gatesTrue,analysis.gateCount, ...
        analysis.timestamps.D.sampleCount,analysis.timestamps.K.sampleCount, ...
        analysis.timestamps.F.sampleCount,analysis.timestamps.fusion.sampleCount, ...
        analysis.timestamps.fusion.tStart,analysis.timestamps.fusion.tEnd, ...
        analysis.timestamps.fusion.dtMin,analysis.timestamps.fusion.dtMean, ...
        analysis.timestamps.fusion.dtMax,analysis.timestamps.DvsKMaxDiff, ...
        analysis.timestamps.DvsFMaxDiff,analysis.timestamps.DvsFusionMaxDiff, ...
        analysis.D.AyUpdate.count,analysis.D.AyUpdate.expectedCount, ...
        analysis.K.processInputs.AxCount,analysis.K.processInputs.AyCount, ...
        analysis.K.processInputs.AVzCount,analysis.F.feedbackAppliedOneCount, ...
        analysis.DReplay.maxStateDiff,analysis.DReplay.maxPDiff,analysis.DReplay.maxDiagDiff, ...
        analysis.KReplay.maxStateDiff,analysis.KReplay.maxPDiff,analysis.KReplay.maxDiagDiff, ...
        analysis.FReplay.maxVyDiff,analysis.FReplay.maxPDiff,analysis.FReplay.maxDiagDiff, ...
        analysis.fusionReplay.maxAbsFusionReplayDiff,analysis.truth.VyAlignment.mode, ...
        analysis.truth.VyAlignment.truthOriginalSampleCount, ...
        analysis.truth.VyAlignment.truthAlignedSampleCount,analysis.evaluation.sampleCount, ...
        analysis.steering.commandMaxAbs,analysis.steering.frequencyHz, ...
        analysis.steering.RLMaxAbsRad,analysis.steering.RRMaxAbsRad, ...
        analysis.truth.VxStats.min,analysis.truth.VxStats.mean,analysis.truth.VxStats.max, ...
        resultHash,info.bytes,analysis.eligibleForCalibration);
    fprintf(['G1D_COVARIANCE|D_asym=%.17g|D_mineig=%.17g|' ...
        'K_asym=%.17g|K_mineig=%.17g|F_minP=%.17g|F_finite=%d\n'], ...
        analysis.D.covariance.maxAsymmetry,analysis.D.covariance.minimumEigenvalue, ...
        analysis.K.covariance.maxAsymmetry,analysis.K.covariance.minimumEigenvalue, ...
        analysis.F.minimumP,analysis.F.PFinite);
    return
elseif nargin~=2
    error('V25G1D:Usage','Use no inputs or (report,remediationRegistryRow).');
end

report=varargin{1};reg=varargin{2};r=report.raw;tol=1e-12;
duration=report.runCard.plannedDurationS;Ts=1/report.runCard.plannedEstimatorRateHz;
expectedN=round(duration/Ts)+1;

% Common exact 100-Hz output grid.
tD=double(r.fusion_vy_d_log.time(:));tK=double(r.fusion_vy_k_log.time(:));
tF=double(r.fusion_vy_f_log.time(:));tFW=double(r.fusion_vy_fw_log.time(:));
nD=numel(tD);nK=numel(tK);nF=numel(tF);nFW=numel(tFW);
dTiming=timing_stats(tD,Ts,duration);kTiming=timing_stats(tK,Ts,duration);
fTiming=timing_stats(tF,Ts,duration);fwTiming=timing_stats(tFW,Ts,duration);
timestamps=struct('D',dTiming,'K',kTiming,'F',fTiming,'fusion',fwTiming, ...
    'DvsKMaxDiff',max_pair_diff(tD,tK),'DvsFMaxDiff',max_pair_diff(tD,tF), ...
    'DvsFusionMaxDiff',max_pair_diff(tD,tFW),'exactSameIndex',isequal(tD,tK,tF,tFW));
timestamps.pass=all([nD nK nF nFW]==expectedN)&&dTiming.pass&&kTiming.pass&& ...
    fTiming.pass&&fwTiming.pass&&timestamps.exactSameIndex&& ...
    timestamps.DvsKMaxDiff==0&&timestamps.DvsFMaxDiff==0&&timestamps.DvsFusionMaxDiff==0;
vyD=vector(r.fusion_vy_d_log);vyK=vector(r.fusion_vy_k_log);
vyF=vector(r.fusion_vy_f_log);vyFW=vector(r.fusion_vy_fw_log);

% D integrity and scheduler semantics.
dX=sample_rows(r.dekf_x_log.data,nD,2);dP=covariance_pages(r.dekf_P_log.data,nD,2);
dDiag=sample_rows(r.dekf_diag_log.data,nD,65);dCov=covariance_stats(dP);
dLogsAligned=isequal(tD,double(r.dekf_x_log.time(:)),double(r.dekf_P_log.time(:)), ...
    double(r.dekf_diag_log.time(:)));dStep=dDiag(:,57);dAyGate=dDiag(:,56)>0.5;
dResetMask=abs(dStep)<tol;dReset=struct('count',nnz(dResetMask),'timestamps',tD(dResetMask));
dReset.pass=dReset.count==1&&abs(dReset.timestamps(1))<=tol&&isequal(dStep(:),(0:nD-1).');
expectedAyT=(0:0.05:duration).';
dAy=struct('count',nnz(dAyGate),'expectedCount',numel(expectedAyT), ...
    'timestamps',tD(dAyGate),'expectedTimestamps',expectedAyT);
dAy.pass=dAy.count==dAy.expectedCount&&max_pair_diff(dAy.timestamps,expectedAyT)<=tol;
dStream=struct('sampleCount',nD,'timing',dTiming,'logsAligned',dLogsAligned, ...
    'selectedVyMatchesState1',max(abs(vyD-dX(:,1)))<=tol,'xFinite',all(isfinite(dX),'all'), ...
    'PFinite',all(isfinite(dP),'all'),'diagFinite',all(isfinite(dDiag),'all'), ...
    'covariance',dCov,'reset',dReset,'AyUpdate',dAy);
dStream.pass=nD==expectedN&&dTiming.pass&&dLogsAligned&&dStream.selectedVyMatchesState1&& ...
    dStream.xFinite&&dStream.PFinite&&dStream.diagFinite&&dCov.valid&&dReset.pass&&dAy.pass;

% K integrity and actual process input consumption.
kU=sample_rows(r.kkf_u_log1.data,nK,4);kX=sample_rows(r.kkf_x_log1.data,nK,2);
kP=covariance_pages(r.kkf_P_log1.data,nK,2);kDiag=sample_rows(r.kkf_diag_log1.data,nK,5);
kCov=covariance_stats(kP);kLogsAligned=isequal(tK,double(r.kkf_u_log1.time(:)), ...
    double(r.kkf_x_log1.time(:)),double(r.kkf_P_log1.time(:)),double(r.kkf_diag_log1.time(:)));
kResetRaw=vector(r.reset_g0);kResetTime=double(r.reset_g0.time(:));kResetMask=kResetRaw>0.5;
kReset=struct('count',nnz(kResetMask),'timestamps',kResetTime(kResetMask));
kReset.pass=kReset.count==1&&abs(kReset.timestamps(1))<=tol;
kInputs=struct('AxCount',size(kU,1),'AyCount',size(kU,1),'AVzCount',size(kU,1), ...
    'VxCount',size(kU,1),'allFinite',all(isfinite(kU),'all'));
kInputs.pass=all([kInputs.AxCount kInputs.AyCount kInputs.AVzCount kInputs.VxCount]==expectedN)&&kInputs.allFinite;
kStream=struct('sampleCount',nK,'timing',kTiming,'logsAligned',kLogsAligned, ...
    'selectedVyMatchesState2',max(abs(vyK-kX(:,2)))<=tol,'xFinite',all(isfinite(kX),'all'), ...
    'PFinite',all(isfinite(kP),'all'),'diagFinite',all(isfinite(kDiag),'all'), ...
    'covariance',kCov,'reset',kReset,'processInputs',kInputs);
kStream.pass=nK==expectedN&&kTiming.pass&&kLogsAligned&&kStream.selectedVyMatchesState2&& ...
    kStream.xFinite&&kStream.PFinite&&kStream.diagFinite&&kCov.valid&&kReset.pass&&kInputs.pass;

% F standalone integrity.
fP=vector(r.fusion_f_P_log);fDiag=sample_rows(r.fusion_f_diag_log.data,nF,3);
fLogsAligned=isequal(tF,double(r.fusion_f_P_log.time(:)),double(r.fusion_f_diag_log.time(:)));
fFeedbackCount=nnz(fDiag(:,3)>0.5);
fReset=struct('count',1,'timestamps',tF(1));
fReset.pass=abs(tF(1))<=tol&&abs(vyF(1)-report.fParameters.Vy_F0)<=tol&& ...
    abs(fP(1)-report.fParameters.P0_F)<=tol&&all(abs(fDiag(1,:))<=tol);
fStream=struct('sampleCount',nF,'timing',fTiming,'logsAligned',fLogsAligned, ...
    'VyFinite',all(isfinite(vyF)),'PFinite',all(isfinite(fP)), ...
    'diagFinite',all(isfinite(fDiag),'all'),'PNonnegative',all(fP>=0), ...
    'minimumP',min(fP),'feedbackAppliedOneCount',fFeedbackCount,'reset',fReset);
fStream.pass=nF==expectedN&&fTiming.pass&&fLogsAligned&&fStream.VyFinite&& ...
    fStream.PFinite&&fStream.diagFinite&&fStream.PNonnegative&&fFeedbackCount==0&&fReset.pass;

% Resolve common runtime inputs exactly at estimator hits.
tShared=double(r.parallel_input_log.time(:));
[sharedD,aD]=input_rows_at_hits(r.parallel_input_log.data,tShared,tD,9);
[sharedK,aK]=input_rows_at_hits(r.parallel_input_log.data,tShared,tK,9);
[sharedF,aF]=input_rows_at_hits(r.parallel_input_log.data,tShared,tF,9);
kInputDiff=max(abs(kU-sharedK(:,1:4)),[],'all');
shared=struct('columns',{{'Ax','Ay','AVz','trueVx','steerFL','steerFR','steerRL','steerRR','Kreset'}}, ...
    'DAlignment',aD,'KAlignment',aK,'FAlignment',aF,'KInputVsSharedMaxAbsDiff',kInputDiff);
shared.pass=aD.pass&&aK.pass&&aF.pass&&kInputDiff<=tol;

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

% Frozen F exact replay with feedback validity fixed false.
p=report.fParameters;fVyR=zeros(nF,1);fPR=zeros(nF,1);fDR=zeros(nF,3);
vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
for k=1:nF
    reset=double(k==1);
    [fVyR(k),fPR(k),dk]=vy_feedback_propagation_step(vyPrev,pPrev,sharedF(k,2), ...
        sharedF(k,3),sharedF(k,4),vyFeedbackZ1,pFeedbackZ1,validZ1,reset, ...
        p.Ts,p.Vy_F0,p.P0_F,p.Q_F);fDR(k,:)=dk(:).';
    if reset
        vyPrev=p.Vy_F0;pPrev=p.P0_F;vyFeedbackZ1=p.Vy_F0;pFeedbackZ1=p.P0_F;validZ1=0;
    else
        vyPrev=fVyR(k);pPrev=fPR(k);vyFeedbackZ1=0;pFeedbackZ1=0.5;validZ1=0;
    end
end
fReplay=struct('maxVyDiff',max(abs(fVyR-vyF)),'maxPDiff',max(abs(fPR-fP)), ...
    'maxDiagDiff',max(abs(fDR-fDiag),[],'all'),'timestampShiftApplied',false,'indexShiftApplied',false);
fReplay.pass=max([fReplay.maxVyDiff fReplay.maxPDiff fReplay.maxDiagDiff])<=tol;

% Frozen current-sample fusion replay; weights remain TEST-ONLY.
w=report.weights.values;vyExpected=zeros(nFW,1);
for k=1:nFW
    vyExpected(k)=vy_fixed_weight_fusion_step(vyD(k),vyK(k),vyF(k),w(1),w(2),w(3));
end
fusionReplay=struct('maxAbsFusionReplayDiff',max(abs(vyExpected-vyFW)), ...
    'sameTimestampSameIndex',timestamps.exactSameIndex,'interpolationApplied',false, ...
    'timestampShiftApplied',false,'P_FW_Generated',false);
fusionReplay.pass=fusionReplay.maxAbsFusionReplayDiff<=tol&&timestamps.exactSameIndex;

% Actual steering pointwise against the registered sine command.
tSteer=double(r.steer_cmd_rad.time(:));cmd=vector(r.steer_cmd_rad);
deg=vector(r.steer_to_carsim_deg);fl=vector(r.steer_fl_carsim_deg);
fr=vector(r.steer_fr_carsim_deg);rl=vector(r.steer_rl_carsim_deg);rr=vector(r.steer_rr_carsim_deg);
A=report.runCard.plannedAmplitudeRad;freq=report.runCard.plannedFrequencyHz;
cmdExpected=A*sin(2*pi*freq*tSteer);nz=abs(cmd)>tol;ratio=deg(nz)./cmd(nz);
steering=struct('configuredAmplitudeRad',A,'frequencyHz',freq,'commandMaxAbs',max(abs(cmd)), ...
    'expectedSampledMaxAbs',max(abs(cmdExpected)),'waveformMaxAbsDiff',max(abs(cmd-cmdExpected)), ...
    'degRadRatioMedian',median(ratio),'FLMaxAbsRad',max(abs(fl*pi/180)), ...
    'FRMaxAbsRad',max(abs(fr*pi/180)),'RLMaxAbsRad',max(abs(rl*pi/180)), ...
    'RRMaxAbsRad',max(abs(rr*pi/180)),'FLFRMaxDiffRad',max(abs((fl-fr)*pi/180)), ...
    'FLConvertedMaxDiffDeg',max(abs(fl-deg)),'FRConvertedMaxDiffDeg',max(abs(fr-deg)));
steering.actualRad=struct('time',tSteer,'command',cmd,'FL',fl*pi/180,'FR',fr*pi/180, ...
    'RL',rl*pi/180,'RR',rr*pi/180);
steering.pass=steering.waveformMaxAbsDiff<=tol&& ...
    abs(steering.commandMaxAbs-steering.expectedSampledMaxAbs)<=tol&& ...
    abs(steering.commandMaxAbs-A)<=2e-6&&steering.FLConvertedMaxDiffDeg<=tol&& ...
    steering.FRConvertedMaxDiffDeg<=tol&&steering.FLFRMaxDiffRad<=tol&& ...
    steering.RLMaxAbsRad<=tol&&steering.RRMaxAbsRad<=tol&& ...
    abs(steering.degRadRatioMedian-180/pi)<=1e-10;

% Frozen truth alignment rule; use direct timestamps when exact.
[vyTrue,vyAlign]=align_truth(r.vy_true_log1,tFW,duration,report.runCard.truthAlignmentRule);
[vxTrue,vxAlign]=align_truth(r.Vx_true_log,tFW,duration,report.runCard.truthAlignmentRule);
truth=struct('Vy',vyTrue,'Vx',vxTrue,'VyAlignment',vyAlign,'VxAlignment',vxAlign, ...
    'VxStats',struct('min',min(vxTrue),'mean',mean(vxTrue),'max',max(vxTrue), ...
    'median',median(vxTrue)),'onlineUse',false,'offlineCalibrationOnly',true);
truth.pass=vyAlign.pass&&vxAlign.pass&&all(isfinite(vyTrue))&&all(isfinite(vxTrue));

evaluation=struct('rule',report.runCard.evaluationWindowRule,'startTime',0, ...
    'endTime',duration,'mask',tFW>=0&tFW<=duration,'sampleCount',nnz(tFW>=0&tFW<=duration), ...
    'transientRemovalApplied',false,'crossCorrelationShiftApplied',false, ...
    'perTrackAlignmentApplied',false);
evaluation.pass=all(evaluation.mask)&&evaluation.sampleCount==expectedN&& ...
    abs(tFW(1))<=tol&&abs(tFW(end)-duration)<=tol;

gates=struct();
gates.runtimeCompleted=report.simulationCompleted&&report.carSimRun;
gates.actualManeuverMatchesPreregistration=steering.pass;
gates.commonTiming=timestamps.pass;gates.dRuntimeIntegrity=dStream.pass;
gates.kRuntimeIntegrity=kStream.pass;gates.fRuntimeIntegrity=fStream.pass;
gates.fFeedbackAppliedAlwaysZero=fFeedbackCount==0;gates.sharedInputsAtHits=shared.pass;
gates.dExactReplay=dReplay.pass;gates.kExactReplay=kReplay.pass;gates.fExactReplay=fReplay.pass;
gates.fusionExactReplay=fusionReplay.pass;gates.truthAvailableAndAligned=truth.pass;
gates.registeredEvaluationWindow=evaluation.pass;gates.noOnlineTrueVy=report.static.noOnlineTrueVy;
gates.noP_FW=report.static.noP_FW;gates.noCovarianceFusion=report.static.noCovarianceFusion;
gates.noFeedbackClosure=report.static.noFeedbackClosure;
gates.targetHashUnchanged=report.targetHashUnchanged;
gates.allFrozenHashesUnchanged=report.allFrozenHashesUnchanged;
gates.preregistrationUnchanged=report.preregistrationUnchanged;
gates.noWeightSelection=true;gates.noOtherRuntime=true;
vals=cell2mat(struct2cell(gates));

analysis=struct('stage','V2.5-G1D','runId','FWCAL_C01R1','timestamps',timestamps, ...
    'D',dStream,'K',kStream,'F',fStream,'sharedInputs',shared,'DReplay',dReplay, ...
    'KReplay',kReplay,'FReplay',fReplay,'fusionReplay',fusionReplay, ...
    'steering',steering,'truth',truth,'evaluation',evaluation,'gates',gates, ...
    'gateCount',numel(vals),'gatesTrue',sum(vals),'performanceBasedSelectionPerformed',false, ...
    'weightSelectionPerformed',false,'alpha_D','UNSELECTED','alpha_K','UNSELECTED', ...
    'alpha_F','UNSELECTED','eligibleForCalibration',all(vals),'passed',all(vals));

dataset=struct();dataset.run_id='FWCAL_C01R1';dataset.role='CALIBRATION_ONLY';
dataset.replaces_run_id='FWCAL_C01';dataset.replacement_generation=1;
dataset.preregisteredManeuver=table2struct(reg);dataset.actualRuntimeSettings=report.runCard;
dataset.environment=struct('MATLABVersion',report.matlabStartup.version, ...
    'activePREFDIR',report.matlabPrefdir.activeValue,'MATLAB_PREFDIR',report.matlabPrefdir.environmentValue);
dataset.targetPath=report.runCard.targetPath;dataset.targetSHA256=report.targetHashAfter;
dataset.fusionCoreSHA256=hash_from_records(report.frozenAfter,'vy_fixed_weight_fusion_step.m');
dataset.fusionWrapperSHA256=hash_from_records(report.frozenAfter,'vy_fixed_weight_fusion_simulink_sfun.m');
dataset.FCoreSHA256=hash_from_records(report.frozenAfter,'vy_feedback_propagation_step.m');
dataset.carSim=report.carSim;dataset.timestamps=struct('D',tD,'K',tK,'F',tF,'fusion',tFW);
dataset.Vy_D=vyD;dataset.Vy_K=vyK;dataset.Vy_F=vyF;dataset.Vy_FW=vyFW;
dataset.Vy_true=vyTrue;dataset.Vx_actual=vxTrue;dataset.steeringActual=steering.actualRad;
dataset.D=struct('state',dX,'P',dP,'diag',dDiag);dataset.K=struct('inputs',kU,'state',kX,'P',kP,'diag',kDiag);
dataset.F=struct('Vy',vyF,'P',fP,'diag',fDiag,'feedbackAppliedCount',fFeedbackCount);
dataset.replayEvidence=struct('D',dReplay,'K',kReplay,'F',fReplay,'fusion',fusionReplay);
dataset.truthAlignment=vyAlign;dataset.evaluationWindow=evaluation;
dataset.runtimeCompletion=struct('simCalled',report.simCalled,'simCallCount',1, ...
    'simulationCompleted',report.simulationCompleted,'carSimRun',report.carSimRun);
dataset.formalCalibrationEligibility=analysis.eligibleForCalibration;
dataset.alphaStatus='UNSELECTED';dataset.P_FW_Generated=false;
end

function [y,a]=align_truth(rec,tTarget,duration,rule)
t=double(rec.time(:));x=vector(rec);assert(numel(t)==numel(x),'Truth shape mismatch.');
assert(all(isfinite(t))&&all(isfinite(x))&&all(diff(t)>=0),'Truth is nonfinite/nonmonotonic.');
[tu,~,g]=unique(t,'sorted');xu=zeros(numel(tu),1);ambiguous=false;
for k=1:numel(tu),v=x(g==k);xu(k)=v(end);ambiguous=ambiguous||(max(v)-min(v)>1e-12);end
[tf,loc]=ismember(tTarget,tu);
if all(tf)
    y=xu(loc);mode='DIRECT_SAME_TIMESTAMP_ALIGNMENT';interp=false;maxDisc=0;
else
    assert(tTarget(1)>=tu(1)&&tTarget(end)<=tu(end),'Truth extrapolation required.');
    y=interp1(tu,xu,tTarget,'linear');mode='DETERMINISTIC_LINEAR_NO_EXTRAPOLATION_NO_SHIFT';
    interp=true;maxDisc=max(arrayfun(@(q)min(abs(tu-q)),tTarget));
end
a=struct('truthAlignmentRule',rule,'mode',mode,'truthOriginalSampleCount',numel(t), ...
    'truthUniqueSampleCount',numel(tu),'truthAlignedSampleCount',numel(tTarget), ...
    'truthTimestampStart',t(1),'truthTimestampEnd',t(end), ...
    'commonTimestampStart',tTarget(1),'commonTimestampEnd',tTarget(end), ...
    'maxTruthCommonGridTimestampDiscrepancy',maxDisc,'duplicateCount',numel(t)-numel(tu), ...
    'ambiguousDuplicate',ambiguous,'interpolationApplied',interp,'extrapolationApplied',false, ...
    'timestampShiftApplied',false,'crossCorrelationApplied',false, ...
    'fullWindowCovered',t(1)<=0&&t(end)>=duration);
a.pass=all(isfinite(y))&&a.fullWindowCovered&&~ambiguous&&~a.extrapolationApplied&& ...
    ~a.timestampShiftApplied&&strcmp(rule,'TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT');
end

function x=vector(rec),x=double(rec.data(:));end
function a=sample_rows(data,n,w)
a=double(data);sz=size(a);
if ismatrix(a),if isequal(sz,[n w]),return;end;if isequal(sz,[w n]),a=a.';return;end,end
if numel(a)==n*w,a=reshape(a,w,n).';return;end
error('V25G1D:Shape','Cannot resolve width %d from %s.',w,mat2str(sz));
end
function p=covariance_pages(data,n,w)
p=double(data);sz=size(p);if ndims(p)==3&&isequal(sz,[w w n]),return;end
if ndims(p)==3&&isequal(sz,[n w w]),p=permute(p,[2 3 1]);return;end
if ismatrix(p)&&isequal(sz,[n w*w]),p=reshape(p.',w,w,n);return;end
if numel(p)==w*w*n,p=reshape(p,w,w,n);return;end
error('V25G1D:CovShape','Cannot resolve covariance %s.',mat2str(sz));
end
function s=timing_stats(t,Ts,duration)
dt=diff(t);s=struct('sampleCount',numel(t),'tStart',t(1),'tEnd',t(end), ...
    'dtMin',min(dt),'dtMean',mean(dt),'dtMax',max(dt),'duplicates',nnz(dt<=0), ...
    'missingHits',sum(max(round(dt/Ts)-1,0)));
s.pass=all(abs(dt-Ts)<=1e-12)&&s.duplicates==0&&s.missingHits==0&& ...
    abs(t(1))<=1e-12&&abs(t(end)-duration)<=1e-12;
end
function s=covariance_stats(P)
n=size(P,3);a=zeros(n,1);e=zeros(n,1);
for k=1:n,a(k)=max(abs(P(:,:,k)-P(:,:,k).'),[],'all');e(k)=min(eig((P(:,:,k)+P(:,:,k).')/2));end
s=struct('maxAsymmetry',max(a),'minimumEigenvalue',min(e));
s.valid=s.maxAsymmetry<=1e-12&&s.minimumEigenvalue>0;
end
function [hits,a]=input_rows_at_hits(data,tIn,tHit,w)
tIn=double(tIn(:));rows=sample_rows(data,numel(tIn),w);hits=zeros(numel(tHit),w);
counts=zeros(numel(tHit),1);deltas=zeros(numel(tHit),1);ambiguous=false;
for k=1:numel(tHit)
    d=abs(tIn-tHit(k));deltas(k)=min(d);ix=find(d==deltas(k));counts(k)=numel(ix);
    if deltas(k)>32*eps(max(1,abs(tHit(k)))),continue;end
    c=rows(ix,:);if size(c,1)>1&&any(max(abs(c-c(end,:)),[],2)>1e-12),ambiguous=true;end
    hits(k,:)=c(end,:);
end
a=struct('matchCountPerHit',counts,'nearestDelta',deltas,'ambiguousDuplicate',ambiguous, ...
    'pass',all(counts>=1)&&all(deltas==0)&&~ambiguous,'timestampShiftApplied',false);
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
