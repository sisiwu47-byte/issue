function analysis = analyze_vy_feedback_track_v2_4d2_reset_fix()
%ANALYZE_VY_FEEDBACK_TRACK_V2_4D2_RESET_FIX Analyze saved D2 runtime only.

root=fileparts(fileparts(mfilename('fullpath')));
modelDir=fullfile(root,'model');
resultFile=fullfile(root,'results','vy_feedback_track_v2_4d2_reset_fix_validation.mat');
assert(isfile(resultFile),'V2.4-D2 result MAT is missing.');
s=load(resultFile,'runtime');
assert(isfield(s,'runtime'),'V2.4-D2 MAT has no runtime evidence.');
runtime=s.runtime;
assert(runtime.simCalled&&runtime.runtimeAuthorizationConsumed&& ...
    runtime.simulationCompleted&&~runtime.carSimRun, ...
    'Saved D2 simulation completion evidence is invalid.');

params=runtime.parameters;
inputs=runtime.inputs;
t=double(runtime.logs.Vy_F.time(:));
vy=double(runtime.logs.Vy_F.data(:));
p=double(runtime.logs.P_F.data(:));
diagF=double(runtime.logs.diag_F.data);
n=numel(t);
tol=1e-12;

timeStats=struct();
timeStats.sampleCountVy=numel(runtime.logs.Vy_F.time);
timeStats.sampleCountP=numel(runtime.logs.P_F.time);
timeStats.sampleCountDiag=numel(runtime.logs.diag_F.time);
timeStats.start=t(1);
timeStats.end=t(end);
timeStats.dtMin=min(diff(t));
timeStats.dtMean=mean(diff(t));
timeStats.dtMax=max(diff(t));
timeStats.duplicateTimestamps=sum(diff(t)==0);
timeStats.missingHits=max(0,21-n);
timeStats.actualRateHz=1/timeStats.dtMean;
timestampsExact=n==21&&isequal(t,inputs.time)&& ...
    isequal(double(runtime.logs.P_F.time(:)),inputs.time)&& ...
    isequal(double(runtime.logs.diag_F.time(:)),inputs.time);

inputSequenceExact=runtime.alignment.passed&&runtime.alignment.isequal&& ...
    runtime.alignment.maxAbsTimeDiff==0&& ...
    isequal(find(inputs.reset~=0),[1;16])&& ...
    isequal(find(inputs.feedbackValid~=0),[1;9;16])&& ...
    all(inputs.Ay==1)&&all(inputs.AVz==0.1)&&all(inputs.Vx==20)&& ...
    inputs.VyFeedback(1)==2&&inputs.PFeedback(1)==0.8&& ...
    inputs.VyFeedback(9)==1&&inputs.PFeedback(9)==0.25&& ...
    inputs.VyFeedback(16)==5&&inputs.PFeedback(16)==0.75;

vyExpected=zeros(n,1);
pExpected=zeros(n,1);
diagExpected=zeros(n,3);
vyPrev=params.Vy_F0;
pPrev=params.P0_F;
vyFeedbackZ1=params.Vy_F0;
pFeedbackZ1=params.P0_F;
feedbackValidZ1=0;
for k=1:n
    [vyExpected(k),pExpected(k),d]=vy_feedback_propagation_step( ...
        vyPrev,pPrev,inputs.Ay(k),inputs.AVz(k),inputs.Vx(k), ...
        vyFeedbackZ1,pFeedbackZ1,feedbackValidZ1,inputs.reset(k), ...
        params.Ts,params.Vy_F0,params.P0_F,params.Q_F);
    diagExpected(k,:)=d(:).';
    if inputs.reset(k)~=0
        vyPrev=params.Vy_F0;
        pPrev=params.P0_F;
        vyFeedbackZ1=params.Vy_F0;
        pFeedbackZ1=params.P0_F;
        feedbackValidZ1=0;
    else
        vyPrev=vyExpected(k);
        pPrev=pExpected(k);
        vyFeedbackZ1=inputs.VyFeedback(k);
        pFeedbackZ1=inputs.PFeedback(k);
        feedbackValidZ1=inputs.feedbackValid(k);
    end
end

replay=struct();
replay.maxAbsVyDiff=max(abs(vy-vyExpected));
replay.maxAbsPDiff=max(abs(p-pExpected));
replay.maxAbsDiagDiff=max(abs(diagF-diagExpected),[],'all');
replay.tolerance=tol;
replay.sameTimestampSameIndex=true;
replay.artificialShift=false;
replay.passed=replay.maxAbsVyDiff<=tol&&replay.maxAbsPDiff<=tol&& ...
    replay.maxAbsDiagDiff<=tol;

nonReset=inputs.reset==0;
propagation=struct();
propagation.theoreticalPropTerm=-1;
propagation.theoreticalDeltaVy=-0.01;
propagation.maxAbsPropTermError=max(abs(diagF(nonReset,1)+1));
propagation.maxAbsDeltaVyError=max(abs(diagF(nonReset,2)+0.01));
propagation.passed=propagation.maxAbsPropTermError<=tol&& ...
    propagation.maxAbsDeltaVyError<=tol;

eventIndex=[1 2 9 10 11 16 17];
eventTable=table(eventIndex.',t(eventIndex),inputs.reset(eventIndex), ...
    inputs.feedbackValid(eventIndex),inputs.VyFeedback(eventIndex), ...
    inputs.PFeedback(eventIndex),vy(eventIndex),p(eventIndex), ...
    diagF(eventIndex,1),diagF(eventIndex,2),diagF(eventIndex,3), ...
    'VariableNames',{'index','time','reset','currentFeedbackValid', ...
    'currentFeedbackVy','currentFeedbackP','Vy_F','P_F', ...
    'propTerm','deltaVy','feedbackApplied'});

events=struct();
events.initialReset=near(vy(1),params.Vy_F0,tol)&& ...
    near(p(1),params.P0_F,tol)&&all(abs(diagF(1,:))<=tol);
events.postInitialReset=diagF(2,3)==0&& ...
    near(vy(2),params.Vy_F0-0.01,tol)&& ...
    near(p(2),params.P0_F+params.Q_F,tol);
events.currentFeedbackNonDirect=inputs.feedbackValid(9)==1&& ...
    diagF(9,3)==0&&near(vy(9),vy(8)-0.01,tol)&& ...
    near(p(9),p(8)+params.Q_F,tol);
events.delayedFeedbackApplied=inputs.feedbackValid(10)==0&& ...
    diagF(10,3)==1&&near(vy(10),0.99,tol)&& ...
    near(p(10),0.25+params.Q_F,tol)&& ...
    max(abs(diagF(10,:)-[-1 -0.01 1]))<=tol;
events.postFeedbackContinuity=diagF(11,3)==0&& ...
    near(vy(11),0.98,tol)&&near(p(11),0.25+2*params.Q_F,tol);
events.secondReset=inputs.reset(16)==1&&inputs.feedbackValid(16)==1&& ...
    near(vy(16),params.Vy_F0,tol)&&near(p(16),params.P0_F,tol)&& ...
    all(abs(diagF(16,:))<=tol);
events.postSecondResetClear=inputs.reset(17)==0&& ...
    inputs.feedbackValid(17)==0&&diagF(17,3)==0&& ...
    near(vy(17),params.Vy_F0-0.01,tol)&& ...
    near(p(17),params.P0_F+params.Q_F,tol);

dimensions=struct('VyScalar',isequal(size(vy),[21 1]), ...
    'PScalar',isequal(size(p),[21 1]), ...
    'diagThreeByOnePerHit',isequal(size(diagF),[21 3]));
finite=struct('Vy',all(isfinite(vy)),'P',all(isfinite(p)), ...
    'diag',all(isfinite(diagF),'all'),'PNonnegative',all(p>=0));

d0=load(fullfile(root,'results','vy_feedback_track_v2_4d0_interface_gates.mat'),'report');
structureAccepted=d0.report.passed&& ...
    d0.report.estimatorIntegrationStructureUnchanged&& ...
    d0.report.compiledGates.functionCallSampleTime100Hz;
oneHitOneCommit=timestampsExact&&replay.passed&&structureAccepted;
deliveryVerified=runtime.alignment.passed&&events.secondReset&& ...
    events.postSecondResetClear;

modelExpected='B50CCCD648B3324D6503AF5FBC501F998CCDB309A40A016DA6A40B2B7A22C74A';
coreExpected='80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF';
wrapperExpected='2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0';
originalExpected='5B1376DCA2884636E675B5AAAD2266707D136DFF85C804B921E209A49D9A5C8C';
hashes=struct();
hashes.runtimeModel=file_sha256(runtime.modelFile);
hashes.core=file_sha256(fullfile(modelDir,'vy_feedback_propagation_step.m'));
hashes.wrapper=file_sha256(fullfile(modelDir,'vy_feedback_propagation_simulink_sfun.m'));
hashes.originalResult=file_sha256(runtime.originalResultFile);
hashes.runtimeModelUnchanged=strcmp(hashes.runtimeModel,modelExpected)&&runtime.modelUnchanged;
hashes.coreUnchanged=strcmp(hashes.core,coreExpected);
hashes.wrapperUnchanged=strcmp(hashes.wrapper,wrapperExpected);
hashes.originalResultUnchanged=strcmp(hashes.originalResult,originalExpected)&& ...
    runtime.originalResultUnchanged;
hashes.allFrozenUnchanged=runtime.frozenUnchanged;

gates=struct();
gates.correctedTimelineExactMatch=runtime.alignment.passed;
gates.simulationCompleted=runtime.simulationCompleted;
gates.actualTwentyOneHits100Hz=timestampsExact&& ...
    timeStats.duplicateTimestamps==0&&timeStats.missingHits==0&& ...
    max(abs([timeStats.dtMin timeStats.dtMean timeStats.dtMax]-0.01))<=tol;
gates.deterministicInputsExact=inputSequenceExact;
gates.propagationDiagnosticsExact=propagation.passed;
gates.initialReset=events.initialReset;
gates.initialFeedbackRejected=events.postInitialReset;
gates.currentFeedbackNonDirect=events.currentFeedbackNonDirect;
gates.delayedFeedbackApplied=events.delayedFeedbackApplied;
gates.postFeedbackContinuity=events.postFeedbackContinuity;
gates.secondResetDelivered=events.secondReset;
gates.secondResetClearsDelay=events.postSecondResetClear;
gates.secondResetTemporalBehavioralProof=deliveryVerified;
gates.runtimeDimensionsExact=all(cell2mat(struct2cell(dimensions)));
gates.outputsFinite=finite.Vy&&finite.P&&finite.diag;
gates.PNonnegative=finite.PNonnegative;
gates.exactReplay=replay.passed;
gates.oneHitOneCommit=oneHitOneCommit;
gates.noDKFusionLifeSigTrueVyCarSim= ...
    all(cell2mat(struct2cell(runtime.independence)))&&~runtime.carSimRun;
gates.parametersTestOnlyUntunedUnfrozen=runtime.parameters.testOnly&& ...
    ~runtime.parameters.tuned&&~runtime.parameters.frozenForRuntime;
gates.runtimeModelHashUnchanged=hashes.runtimeModelUnchanged;
gates.coreWrapperHashesUnchanged=hashes.coreUnchanged&&hashes.wrapperUnchanged;
gates.originalFailedEvidenceUnchanged=hashes.originalResultUnchanged;
gates.allFrozenHashesUnchanged=hashes.allFrozenUnchanged;
gateValues=cell2mat(struct2cell(gates));

analysis=struct();
analysis.stage='V2.4-D2';
analysis.time=timeStats;
analysis.alignment=runtime.alignment;
analysis.dimensions=dimensions;
analysis.finite=finite;
analysis.propagation=propagation;
analysis.events=events;
analysis.eventTable=eventTable;
analysis.replay=replay;
analysis.expected=struct('Vy',vyExpected,'P',pExpected,'diag',diagExpected);
analysis.hashes=hashes;
analysis.gates=gates;
analysis.gateCount=numel(gateValues);
analysis.gatesTrue=sum(gateValues);
analysis.secondResetDeliveryVerified=deliveryVerified;
analysis.oneSampleFeedbackDelayVerified=events.currentFeedbackNonDirect&& ...
    events.delayedFeedbackApplied;
analysis.oneHitOneCommit=oneHitOneCommit;
analysis.simCalledByAnalyzer=false;
analysis.performanceEvaluationPerformed=false;
analysis.passed=all(gateValues);
save(resultFile,'runtime','analysis','-v7');

fprintf(['V2_4D2_ANALYZE|gates=%d/%d|N=%d|dt=[%.17g %.17g %.17g]|' ...
    'i16=[%.17g %.17g %s]|replay=[%.17g %.17g %.17g]|passed=%d|' ...
    'sim=0|carsim=0\n'],analysis.gatesTrue,analysis.gateCount,n, ...
    timeStats.dtMin,timeStats.dtMean,timeStats.dtMax,t(16),vy(16), ...
    mat2str(diagF(16,:),17),replay.maxAbsVyDiff,replay.maxAbsPDiff, ...
    replay.maxAbsDiagDiff,analysis.passed);
fprintf('V2_4D2_EVENT_TABLE\n');
disp(eventTable);
if ~analysis.passed
    names=fieldnames(gates);
    names=names(~gateValues);
    error('V2_4D2:GateFailed','Failed D2 gates: %s',strjoin(names,', '));
end
end

function tf=near(a,b,tol)
tf=abs(double(a)-double(b))<=tol;
end

function h=file_sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(file));
ds=java.security.DigestInputStream(s,d);
c=onCleanup(@()ds.close());
while ds.read()~=-1, end
b=typecast(d.digest(),'uint8');
h=upper(reshape(dec2hex(b,2).',1,[]));
clear c
end
