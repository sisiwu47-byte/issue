function report = validate_vy_fixed_fusion_v2_5c_integration(build,doCompile)
%VALIDATE_VY_FIXED_FUSION_V2_5C_INTEGRATION Static/harness compile audit.
% The formal CarSim target is never compiled and sim() is never called.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_fixed_fusion_v2_5c_integration_gates.mat');
if nargin<1||isempty(build)
    s=load(resultFile,'build'); assert(isfield(s,'build'), ...
        'Existing V2.5-C build evidence is missing. Run the builder explicitly.');
    build=s.build;
end
if nargin<2,doCompile=false;end
doCompile=logical(doCompile);
assert(isfile(build.targetFile)&&isfile(build.harnessFile), ...
    'V2.5-C target or estimator-only harness is missing.');

[frozenFiles,expectedHashes]=frozen_manifest(root);
frozenBefore=snapshot(frozenFiles);
targetBefore=file_record(build.targetFile);
harnessBefore=file_record(build.harnessFile);
wrapperBefore=file_record(build.wrapperFile);
addpath(fullfile(root,'model'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(tempdir,'vy_fixed_fusion_v2_5c_validate_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_fixed_fusion_v2_5c_validate_codegen'), ...
    'createDir',true);
load_system('simulink'); load_system('Solver_SF');
load_system(build.targetFile); load_system(build.harnessFile);
cleanup=onCleanup(@()close_models(build.targetModel,build.harnessModel));

wrapperSource=regexprep(fileread(build.wrapperFile),'%[^\r\n]*','');
wrapperText=lower(regexprep(wrapperSource,'\s+',''));
wrapperCallsCore=count_token(wrapperText,'vy_fixed_weight_fusion_step(')==2;
wrapperNoCopiedMath=isempty(regexp(wrapperText, ...
    'alpha_d\*vy_d|alpha_k\*vy_k|alpha_f\*vy_f','once'));
wrapperNoDWork=~contains(wrapperText,'dwork');
wrapperNoPersistent=~contains(wrapperText,'persistent');
wrapperNoGlobal=isempty(regexp(wrapperText,'\<global\>','once'));
wrapperNoUpdate=~contains(wrapperText,"regblockmethod('update'")&& ...
    isempty(regexp(wrapperText,'functionupdate\(','once'));
wrapperThreeInputs=contains(wrapperText,'block.numinputports=3');
wrapperOneOutput=contains(wrapperText,'block.numoutputports=1');
wrapperThreeDialog=contains(wrapperText,'block.numdialogprms=3');
wrapperInputScalar=count_token(wrapperText,'.dimensions=1')==2&&contains(wrapperText,'fork=1:3');
wrapperDouble=count_token(wrapperText,'.datatypeid=0')==2&&contains(wrapperText,'fork=1:3');
wrapperDirect=count_token(wrapperText,'.directfeedthrough=true')==1&& ...
    contains(wrapperText,'fork=1:3');
wrapper100=contains(wrapperText,'block.sampletimes=[0.010]');
wrapperStateless=wrapperNoDWork&&wrapperNoPersistent&&wrapperNoGlobal&&wrapperNoUpdate;

main=build.main; hm=build.harness;
mainAudit=audit_model(build.targetModel,main,build.testWeights);
harnessAudit=audit_model(build.harnessModel,hm,build.testWeights);

frozenOK=records_match(frozenBefore,expectedHashes);
mainGates=struct();
mainGates.targetExists=isfile(build.targetFile);
mainGates.sourceParallelHashExact=frozenOK&&strcmp(frozenBefore(1).sha256,expectedHashes{1});
mainGates.frozenDObjectsExact=all_hash_subset(frozenBefore,expectedHashes,2:5);
mainGates.frozenKObjectsExact=all_hash_subset(frozenBefore,expectedHashes,6:9);
mainGates.frozenDKObjectsExact=all_hash_subset(frozenBefore,expectedHashes,10:13);
mainGates.frozenFCoreExact=all_hash_subset(frozenBefore,expectedHashes,14);
mainGates.frozenFSFunctionExact=all_hash_subset(frozenBefore,expectedHashes,15);
mainGates.acceptedFTargetExact=all_hash_subset(frozenBefore,expectedHashes,16);
mainGates.frozenFusionCoreExact=all_hash_subset(frozenBefore,expectedHashes,17);
mainGates.fusionWrapperExists=isfile(build.wrapperFile);
mainGates.wrapperCallsFrozenCore=wrapperCallsCore;
mainGates.wrapperHasNoCopiedFusionMath=wrapperNoCopiedMath;
mainGates.wrapperHasNoDWork=wrapperNoDWork;
mainGates.wrapperHasNoPersistent=wrapperNoPersistent;
mainGates.wrapperHasNoGlobal=wrapperNoGlobal;
mainGates.wrapperHasNoUpdateStateLogic=wrapperNoUpdate;
mainGates.wrapperIsStateless=wrapperStateless;
mainGates.wrapperHasThreeDialogParameters=wrapperThreeDialog;
mainGates.wrapperDefinesThreeInputs=wrapperThreeInputs;
mainGates.wrapperDefinesOneOutput=wrapperOneOutput;
mainGates.wrapperPortsScalar=wrapperInputScalar;
mainGates.wrapperPortsDouble=wrapperDouble;
mainGates.wrapperInputsDirectFeedthrough=wrapperDirect;
mainGates.wrapperConfigured100Hz=wrapper100;
mainGates.fusionBlockCorrect=mainAudit.fusionBlockCorrect;
mainGates.fusionDialogParametersExact=mainAudit.fusionDialogExact;
mainGates.testWeightsFinite=all(isfinite(build.testWeights));
mainGates.testWeightsNonnegative=all(build.testWeights>=0);
mainGates.testWeightsSumToOne=abs(sum(build.testWeights)-1)<=1e-12;
mainGates.testWeightsMarkedOnly=mainAudit.testOnlyMarked;
mainGates.formalWeightsUnselected=mainAudit.weightsUnselected;
mainGates.formalWeightsUntuned=mainAudit.weightsUntuned;
mainGates.formalWeightsUnfrozen=mainAudit.weightsUnfrozen;
mainGates.dStateInputExact=mainAudit.dSelectInputExact;
mainGates.dVyIsStateElementOne=mainAudit.dVyPortExact;
mainGates.kStateInputExact=mainAudit.kSelectInputExact;
mainGates.kVyIsStateElementTwo=mainAudit.kVyPortExact;
mainGates.fVyScalarFeedsPortThree=mainAudit.fVyPortExact;
mainGates.fusionHasExactlyThreeInputs=mainAudit.fusionInputCountExact;
mainGates.fusionSourcesAreExactlyDKF=mainAudit.fusionSourcesExact;
mainGates.noRDMapped=mainAudit.noRD;
mainGates.noVxKMapped=mainAudit.noVxK;
mainGates.noCovarianceMapped=mainAudit.noCovariance;
mainGates.noPFW=mainAudit.noPFW;
mainGates.noDKEKFInput=mainAudit.noDK;
mainGates.noTruthVyInput=mainAudit.noTruthVy;
mainGates.fFeedbackValidFixedFalse=mainAudit.fValidFalse;
mainGates.fFeedbackPlaceholdersFinite=mainAudit.fPlaceholdersFinite;
mainGates.vyFWNotRoutedToF=mainAudit.noFwToF;
mainGates.noFusionFeedbackLoop=mainAudit.noLoop;
mainGates.noAlphaRuntimeAdaptation=mainAudit.noAdaptive;
mainGates.noLifeSig=mainAudit.noLifeSig;
mainGates.noNISLogic=mainAudit.noNIS;
mainGates.noObservabilityLogic=mainAudit.noObservability;
mainGates.noReliabilityLogic=mainAudit.noReliability;
mainGates.noFusionSwitch=mainAudit.noFusionSwitch;
mainGates.noWinnerSelector=mainAudit.noWinner;
mainGates.dBase100Hz=mainAudit.d100;
mainGates.kBase100Hz=mainAudit.k100;
mainGates.fBase100Hz=mainAudit.f100;
mainGates.independentEstimatorSchedulers=mainAudit.independentSchedulers;
mainGates.independentEstimatorMemories=mainAudit.independentSubsystems;
mainGates.sameSampleDirectRouting=mainAudit.directRouting;
mainGates.vyFWLoggingExists=mainAudit.fwLogExists;
mainGates.threeTrackVyLogsExist=mainAudit.trackLogsExist;
mainGates.targetClassifiedIntegrationOnly=mainAudit.integrationClassification;
mainGates.noFullTargetCompileCalled=~build.fullTargetCompileCalled;
mainGates.noSimulationCalled=~build.simCalled;
mainGates.noCarSimRuntime=~build.carSimRun;

harnessGates=struct();
harnessGates.harnessExists=isfile(build.harnessFile);
harnessGates.noCarSimVsSf=harnessAudit.noVsSf;
harnessGates.noVehiclePlant=harnessAudit.noVehiclePlant;
harnessGates.dSubsystemExists=harnessAudit.dExists;
harnessGates.kSubsystemExists=harnessAudit.kExists;
harnessGates.fSubsystemExists=harnessAudit.fExists;
harnessGates.fusionBlockCorrect=harnessAudit.fusionBlockCorrect;
harnessGates.wrapperCallsFrozenCore=wrapperCallsCore;
harnessGates.wrapperStateless=wrapperStateless;
harnessGates.wrapperThreeInputs=wrapperThreeInputs;
harnessGates.wrapperOneOutput=wrapperOneOutput;
harnessGates.wrapperScalarPorts=wrapperInputScalar;
harnessGates.wrapperDoublePorts=wrapperDouble;
harnessGates.wrapperDirectFeedthrough=wrapperDirect;
harnessGates.dStateInputExact=harnessAudit.dSelectInputExact;
harnessGates.dVyElementOne=harnessAudit.dVyPortExact;
harnessGates.kStateInputExact=harnessAudit.kSelectInputExact;
harnessGates.kVyElementTwo=harnessAudit.kVyPortExact;
harnessGates.fVyPortThree=harnessAudit.fVyPortExact;
harnessGates.exactlyThreeFusionInputs=harnessAudit.fusionInputCountExact;
harnessGates.sourcesExactlyDKF=harnessAudit.fusionSourcesExact;
harnessGates.noRD=harnessAudit.noRD;
harnessGates.noVxK=harnessAudit.noVxK;
harnessGates.noCovariance=harnessAudit.noCovariance;
harnessGates.noPFW=harnessAudit.noPFW;
harnessGates.noDKInput=harnessAudit.noDK;
harnessGates.noTruthVy=harnessAudit.noTruthVy;
harnessGates.fValidFixedFalse=harnessAudit.fValidFalse;
harnessGates.fPlaceholdersFinite=harnessAudit.fPlaceholdersFinite;
harnessGates.noFwToF=harnessAudit.noFwToF;
harnessGates.noLoop=harnessAudit.noLoop;
harnessGates.noAdaptive=harnessAudit.noAdaptive;
harnessGates.noLifeSig=harnessAudit.noLifeSig;
harnessGates.noNIS=harnessAudit.noNIS;
harnessGates.noObservability=harnessAudit.noObservability;
harnessGates.noReliability=harnessAudit.noReliability;
harnessGates.noFusionSwitch=harnessAudit.noFusionSwitch;
harnessGates.noWinner=harnessAudit.noWinner;
harnessGates.testWeightsExact=harnessAudit.fusionDialogExact;
harnessGates.testWeightsMarked=harnessAudit.testOnlyMarked;
harnessGates.weightsUnselected=harnessAudit.weightsUnselected;
harnessGates.weightsUntuned=harnessAudit.weightsUntuned;
harnessGates.weightsUnfrozen=harnessAudit.weightsUnfrozen;
harnessGates.dScheduler100Hz=harnessAudit.d100;
harnessGates.kScheduler100Hz=harnessAudit.k100;
harnessGates.fScheduler100Hz=harnessAudit.f100;
harnessGates.schedulersIndependent=harnessAudit.independentSchedulers;
harnessGates.subsystemsIndependent=harnessAudit.independentSubsystems;
harnessGates.sameSampleDirectRouting=harnessAudit.directRouting;
harnessGates.deterministicAxBoundary=harnessAudit.axBoundary;
harnessGates.deterministicAyBoundary=harnessAudit.ayBoundary;
harnessGates.deterministicAVzBoundary=harnessAudit.avzBoundary;
harnessGates.deterministicVxBoundary=harnessAudit.vxBoundary;
harnessGates.deterministicSteeringBoundary=harnessAudit.steeringBoundary;
harnessGates.independentKReset=harnessAudit.kResetBoundary;
harnessGates.independentFReset=harnessAudit.fResetBoundary;
harnessGates.fourTrackOutputsLogged=harnessAudit.trackLogsExist;
harnessGates.noSimulationCalled=~build.simCalled;
harnessGates.noCarSimRuntime=~build.carSimRun;
harnessGates.noFullTargetCompileCalled=~build.fullTargetCompileCalled;

mainValues=cellfun(@logical,struct2cell(mainGates));
harnessValues=cellfun(@logical,struct2cell(harnessGates));
mainStaticPassed=all(mainValues); harnessStaticPassed=all(harnessValues);

compile=empty_compile(); compiledGates=empty_compiled_gates(doCompile);
if doCompile
    assert(mainStaticPassed&&harnessStaticPassed, ...
        'Static gates failed; estimator-only harness compile is prohibited.');
    compile.called=true; lastwarn('');
    try
        feval(build.harnessModel,[],[],[],'compile');
        compile.interfaces=compiled_interfaces(build.harness);
        compile.sampleTimes=compiled_sample_times(build.harness);
        compile.evidenceCaptured=true;
        [compile.warningMessage,compile.warningIdentifier]=lastwarn;
        compile.passed=true;
        feval(build.harnessModel,[],[],[],'term');
        compile.terminationReached=true;
    catch ME
        try,feval(build.harnessModel,[],[],[],'term');compile.terminationReached=true;catch,end
        compile.errorIdentifier=ME.identifier; compile.errorMessage=ME.message;
        compile.errorReport=getReport(ME,'extended','hyperlinks','off');
    end
    if compile.evidenceCaptured
        ci=compile.interfaces; st=compile.sampleTimes;
        compiledGates.compileCalled=compile.called;
        compiledGates.compilePassed=compile.passed;
        compiledGates.terminationReached=compile.terminationReached;
        compiledGates.compiledEvidenceCaptured=compile.evidenceCaptured;
        compiledGates.dState2=vector_shape(ci.dX.shape,2)&&strcmp(ci.dX.type,'double');
        compiledGates.dP2x2=shape_equal(ci.dP.shape,[2 2])&&strcmp(ci.dP.type,'double');
        compiledGates.kState2=vector_shape(ci.kX.shape,2)&&strcmp(ci.kX.type,'double');
        compiledGates.kP2x2=shape_equal(ci.kP.shape,[2 2])&&strcmp(ci.kP.type,'double');
        compiledGates.fVyScalar=ci.fVy.width==1&&strcmp(ci.fVy.type,'double');
        compiledGates.fPScalar=ci.fP.width==1&&strcmp(ci.fP.type,'double');
        compiledGates.fDiag3=ci.fDiag.width==3&&strcmp(ci.fDiag.type,'double');
        compiledGates.dVyScalar=ci.dVy.width==1&&strcmp(ci.dVy.type,'double');
        compiledGates.kVyScalar=ci.kVy.width==1&&strcmp(ci.kVy.type,'double');
        compiledGates.fusionInput1ScalarDouble=ci.fusionIn(1).width==1&&strcmp(ci.fusionIn(1).type,'double');
        compiledGates.fusionInput2ScalarDouble=ci.fusionIn(2).width==1&&strcmp(ci.fusionIn(2).type,'double');
        compiledGates.fusionInput3ScalarDouble=ci.fusionIn(3).width==1&&strcmp(ci.fusionIn(3).type,'double');
        compiledGates.fusionOutputScalarDouble=ci.fusionOut.width==1&&strcmp(ci.fusionOut.type,'double');
        compiledGates.dBase100Hz=contains_period(st.dParent,0.01);
        compiledGates.kBase100Hz=contains_period(st.kParent,0.01);
        compiledGates.fBase100Hz=contains_period(st.fParent,0.01);
        compiledGates.fusion100Hz=contains_period(st.fusion,0.01);
        compiledGates.noSampleTimeConflict=compile.passed;
        compiledGates.sameSampleStructuralContract=all([mainAudit.directRouting, ...
            harnessAudit.directRouting,compile.passed]);
        compiledGates.noEstimatorSideCompileError=compile.passed;
    end
end
compiledValues=cellfun(@logical,struct2cell(compiledGates));

close_system(build.harnessModel,0); close_system(build.targetModel,0);
frozenAfter=snapshot(frozenFiles); targetAfter=file_record(build.targetFile);
harnessAfter=file_record(build.harnessFile); wrapperAfter=file_record(build.wrapperFile);
frozenUnchanged=records_equal(frozenBefore,frozenAfter)&&records_match(frozenAfter,expectedHashes);
targetNoWrite=record_equal(targetBefore,targetAfter);
harnessNoWrite=record_equal(harnessBefore,harnessAfter);
wrapperNoWrite=record_equal(wrapperBefore,wrapperAfter);

report=struct(); report.stage='V2.5-C';
report.mainGates=mainGates; report.mainGateCount=numel(mainValues);
report.mainGatesTrue=sum(mainValues); report.mainStaticPassed=mainStaticPassed;
report.harnessGates=harnessGates; report.harnessGateCount=numel(harnessValues);
report.harnessGatesTrue=sum(harnessValues); report.harnessStaticPassed=harnessStaticPassed;
report.compileRequested=doCompile; report.compile=compile;
report.compiledGates=compiledGates; report.compiledGateCount=numel(compiledValues);
report.compiledGatesTrue=sum(compiledValues);
report.passed=mainStaticPassed&&harnessStaticPassed&&frozenUnchanged&& ...
    targetNoWrite&&harnessNoWrite&&wrapperNoWrite&&all(compiledValues)&& ...
    (~doCompile||(compile.passed&&compile.terminationReached&&compile.evidenceCaptured));
report.mainAudit=mainAudit; report.harnessAudit=harnessAudit;
report.sameSampleContract=['Vy_FW(k) uses Vy_D(k), Vy_K(k), and Vy_F(k) at the same ' ...
    'logical 100-Hz sample; runtime timestamp equality remains a V2.5-D gate.'];
report.fusionFeedbackLoopClosed=false; report.fFeedbackValid=false;
report.weights=struct('values',build.testWeights,'classification','TEST-ONLY', ...
    'selected',false,'tuned',false,'frozen',false);
report.targetBefore=targetBefore;report.targetAfter=targetAfter;report.targetNoWrite=targetNoWrite;
report.harnessBefore=harnessBefore;report.harnessAfter=harnessAfter;report.harnessNoWrite=harnessNoWrite;
report.wrapperBefore=wrapperBefore;report.wrapperAfter=wrapperAfter;report.wrapperNoWrite=wrapperNoWrite;
report.frozenBefore=frozenBefore;report.frozenAfter=frozenAfter;report.frozenUnchanged=frozenUnchanged;
report.simCalled=false;report.carSimRun=false;report.fullTargetCompileCalled=false;
save(resultFile,'build','report','-v7');
clear cleanup
fprintf(['V2_5C_VALIDATE|main=%d/%d|harness=%d/%d|compileCalled=%d|' ...
    'compilePassed=%d|compiled=%d/%d|term=%d|evidence=%d|passed=%d|' ...
    'fullTargetCompile=0|sim=0|carsim=0\n'],report.mainGatesTrue,report.mainGateCount, ...
    report.harnessGatesTrue,report.harnessGateCount,compile.called,compile.passed, ...
    report.compiledGatesTrue,report.compiledGateCount,compile.terminationReached, ...
    compile.evidenceCaptured,report.passed);
if compile.called&&~compile.passed
    fprintf('V2_5C_COMPILE_ERROR|%s|%s\n',compile.errorIdentifier,compile.errorMessage);
end
end

function a=audit_model(model,b,w)
fp=get_param(b.fusion,'PortHandles'); dp=get_param(b.dSelect,'PortHandles');
kp=get_param(b.kSelect,'PortHandles'); fsp=get_param(b.fSubsystem,'PortHandles');
dop=get_param(b.dOutputDemux,'PortHandles'); ksp=get_param(b.kSubsystem,'PortHandles');
fSources=arrayfun(@source_of_port,fp.Inport,'UniformOutput',false);
desc=lower(get_param(model,'Description'));
allBlocks=find_system(model,'Type','Block'); blockNames=lower(string(allBlocks));
localNames=cellfun(@(x)get_param(x,'Name'),allBlocks,'UniformOutput',false);
fusionRelated=allBlocks(contains(lower(string(localNames)),'fusion'));
fusionTypes=cellfun(@(x)get_param(x,'BlockType'),fusionRelated,'UniformOutput',false);
fn={}; for k=1:numel(allBlocks),try,v=get_param(allBlocks{k},'FunctionName');if ~isempty(v),fn{end+1}=v;end,catch,end,end %#ok<AGROW>
a=struct();
a.dExists=getSimulinkBlockHandle(b.dSubsystem)>0;
a.kExists=getSimulinkBlockHandle(b.kSubsystem)>0;
a.fExists=getSimulinkBlockHandle(b.fSubsystem)>0;
a.fusionBlockCorrect=strcmp(get_param(b.fusion,'BlockType'),'M-S-Function')&& ...
    strcmp(get_param(b.fusion,'FunctionName'),'vy_fixed_weight_fusion_simulink_sfun');
a.fusionDialogExact=strcmp(regexprep(get_param(b.fusion,'Parameters'),'\s+',''),'1/3,1/3,1/3')&& ...
    all(abs(w-[1/3 1/3 1/3])<eps);
a.testOnlyMarked=contains(desc,'test-only');
a.weightsUnselected=contains(desc,'not selected');
a.weightsUntuned=contains(desc,'not tuned');
a.weightsUnfrozen=contains(desc,'not frozen');
a.dSelectInputExact=strcmp(source_of_port(dp.Inport(1)),b.dOutputDemux);
a.dVyPortExact=strcmp(source_of_port(fp.Inport(1)),b.dSelect)&& ...
    strcmp(get_param(b.dSelect,'Outputs'),'2')&&strcmp(source_of_port(dp.Inport(1)),b.dOutputDemux);
a.kSelectInputExact=strcmp(source_of_port(kp.Inport(1)),b.kSubsystem);
a.kVyPortExact=strcmp(source_of_port(fp.Inport(2)),b.kSelect)&& ...
    strcmp(get_param(b.kSelect,'Outputs'),'2')&&strcmp(source_of_port(kp.Inport(1)),b.kSubsystem);
a.fVyPortExact=strcmp(source_of_port(fp.Inport(3)),b.fSubsystem);
a.fusionInputCountExact=numel(fp.Inport)==3&&numel(fp.Outport)==1;
a.fusionSourcesExact=isequal(fSources(:),{b.dSelect;b.kSelect;b.fSubsystem});
a.noRD=~strcmp(source_of_port(fp.Inport(1)),b.dSubsystem)&& ...
    ~strcmp(source_of_port(fp.Inport(1)),b.dOutputDemux);
a.noVxK=strcmp(source_of_port(fp.Inport(2)),b.kSelect);
a.noCovariance=a.fusionSourcesExact&&~any(contains(lower(string(fSources)),'p 2x2'))&& ...
    ~any(contains(lower(string(fSources)),'covariance'));
a.noPFW=~any(contains(blockNames,'p_fw'));
a.noDK=~any(contains(lower(string(fSources)),'dkekf'))&& ...
    ~any(contains(lower(string(fSources)),'dk-ekf'));
a.noTruthVy=~any(contains(lower(string(fSources)),'true vy'))&& ...
    ~any(contains(lower(string(fSources)),'vy_true'));
a.fValidFalse=strcmp(strtrim(get_param(b.fValid,'Value')),'0')&& ...
    strcmp(source_of_port(fsp.Inport(6)),b.fValid);
a.fPlaceholdersFinite=isfinite(str2double(get_param(b.fVyPlaceholder,'Value')))&& ...
    isfinite(str2double(get_param(b.fPPlaceholder,'Value')))&& ...
    strcmp(source_of_port(fsp.Inport(4)),b.fVyPlaceholder)&& ...
    strcmp(source_of_port(fsp.Inport(5)),b.fPPlaceholder);
fwDest=destinations_of_port(fp.Outport(1));
a.noFwToF=~any(strcmp(fwDest,b.fSubsystem))&& ...
    ~any(startsWith(string(fwDest),string([b.fSubsystem '/'])));
a.noLoop=a.noFwToF&&a.fValidFalse;
a.noAdaptive=~any(contains(blockNames,'adaptive'))&&~any(contains(blockNames,'alpha runtime'));
a.noLifeSig=~any(contains(lower(string(fusionRelated)),'lifesig'));
a.noNIS=~any(contains(lower(string(fusionRelated)),'nis'));
a.noObservability=~any(contains(lower(string(fusionRelated)),'observability'));
a.noReliability=~any(contains(lower(string(fusionRelated)),'reliability'));
a.noFusionSwitch=~any(ismember(fusionTypes,{'Switch','ManualSwitch','MultiPortSwitch'}));
a.noWinner=~any(contains(lower(string(fusionRelated)),'winner'))&& ...
    ~any(contains(lower(string(fusionRelated)),'selector'));
a.d100=scheduler100(b.dScheduler);
a.k100=scheduler100(b.kScheduler);
a.f100=scheduler100(b.fScheduler);
a.independentSchedulers=numel(unique({b.dScheduler,b.kScheduler,b.fScheduler}))==3;
a.independentSubsystems=numel(unique({b.dSubsystem,b.kSubsystem,b.fSubsystem}))==3;
a.directRouting=a.fusionSourcesExact&&a.dSelectInputExact&&a.kSelectInputExact;
a.fwLogExists=isfield(b,'fwLog')&&getSimulinkBlockHandle(b.fwLog)>0&& ...
    any(strcmp(destinations_of_port(fp.Outport(1)),b.fwLog));
a.trackLogsExist=isfield(b,'logs')|| ...
    (isfield(b,'dVyLog')&&isfield(b,'kVyLog')&&isfield(b,'fVyLog'));
a.integrationClassification=contains(desc,'integration target')||contains(desc,'compile harness');
a.noVsSf=~any(strcmp(fn,'vs_sf'));
a.noVehiclePlant=a.noVsSf&&~any(contains(blockNames,'vehicle plant'));
a.axBoundary=~isfield(b,'axSource')||constant_double(b.axSource);
a.ayBoundary=~isfield(b,'aySource')||constant_double(b.aySource);
a.avzBoundary=~isfield(b,'avzSource')||constant_double(b.avzSource);
a.vxBoundary=~isfield(b,'vxSource')||constant_double(b.vxSource);
a.steeringBoundary=~isfield(b,'steeringSource')||constant_double(b.steeringSource);
a.kResetBoundary=~isfield(b,'kReset')||strcmp(get_param(b.kReset,'BlockType'),'Step');
a.fResetBoundary=~isfield(b,'fReset')||strcmp(get_param(b.fReset,'BlockType'),'Step');
% Proven state conventions at the exact frozen boundaries used above.
a.dStateConvention='[Vy;r], select output 1';
a.kStateConvention='[Vx;Vy], select output 2';
a.fStateConvention='scalar Vy_F output 1';
end
function tf=scheduler100(p)
tf=strcmp(get_param(p,'MaskType'),'Function-Call Generator')&& ...
    abs(str2double(get_param(p,'sample_time'))-0.01)<1e-15&& ...
    str2double(get_param(p,'numberOfIterations'))==1;
end
function tf=constant_double(p)
tf=getSimulinkBlockHandle(p)>0&&strcmp(get_param(p,'BlockType'),'Constant')&& ...
    strcmp(get_param(p,'OutDataTypeStr'),'double');
end
function ci=compiled_interfaces(b)
dp=get_param(b.dOutputDemux,'PortHandles'); dpp=get_param(b.dP,'PortHandles');
kp=get_param(b.kSubsystem,'PortHandles'); fp=get_param(b.fSubsystem,'PortHandles');
dsp=get_param(b.dSelect,'PortHandles'); ksp=get_param(b.kSelect,'PortHandles');
fup=get_param(b.fusion,'PortHandles');
ci=struct(); ci.dX=port_record(dp.Outport(1)); ci.dP=port_record(dpp.Outport(1));
ci.kX=port_record(kp.Outport(1)); ci.kP=port_record(kp.Outport(2));
ci.fVy=port_record(fp.Outport(1)); ci.fP=port_record(fp.Outport(2)); ci.fDiag=port_record(fp.Outport(3));
ci.dVy=port_record(dsp.Outport(1)); ci.kVy=port_record(ksp.Outport(2));
ci.fusionIn=repmat(struct('shape',[],'width',0,'type',''),3,1);
for k=1:3,ci.fusionIn(k)=port_record(fup.Inport(k));end
ci.fusionOut=port_record(fup.Outport(1));
end
function st=compiled_sample_times(b)
st=struct(); st.dParent=get_param(b.dSubsystem,'CompiledSampleTime');
st.kParent=get_param(b.kSubsystem,'CompiledSampleTime');
st.fParent=get_param(b.fSubsystem,'CompiledSampleTime');
st.fusion=get_param(b.fusion,'CompiledSampleTime');
st.configured=struct('D',[0.01 0],'K',[0.01 0],'F',[0.01 0]);
end
function r=port_record(p)
r=struct('shape',compiled_shape(p),'width',double(get_param(p,'CompiledPortWidth')), ...
    'type',get_param(p,'CompiledPortDataType'));
end
function s=compiled_shape(p)
d=double(get_param(p,'CompiledPortDimensions'));if numel(d)>=2&&d(1)==numel(d)-1,s=d(2:end);else,s=d;end
end
function tf=shape_equal(a,e),tf=isequal(double(a(:).'),double(e(:).'));end
function tf=vector_shape(a,w),a=double(a(:).');tf=(isscalar(a)&&a==w)||(prod(a)==w&&any(a==1));end
function tf=contains_period(v,p)
tf=false;if isnumeric(v),tf=size(v,2)>=1&&any(abs(v(:,1)-p)<1e-12,'all');elseif iscell(v),for k=1:numel(v),tf=tf||contains_period(v{k},p);end,end
end
function c=empty_compile()
c=struct('called',false,'passed',false,'terminationReached',false,'evidenceCaptured',false, ...
    'interfaces',struct(),'sampleTimes',struct(),'warningMessage','','warningIdentifier','', ...
    'errorIdentifier','','errorMessage','','errorReport','');
end
function g=empty_compiled_gates(doCompile)
v=~doCompile;g=struct('compileCalled',v,'compilePassed',v,'terminationReached',v, ...
    'compiledEvidenceCaptured',v,'dState2',v,'dP2x2',v,'kState2',v,'kP2x2',v, ...
    'fVyScalar',v,'fPScalar',v,'fDiag3',v,'dVyScalar',v,'kVyScalar',v, ...
    'fusionInput1ScalarDouble',v,'fusionInput2ScalarDouble',v, ...
    'fusionInput3ScalarDouble',v,'fusionOutputScalarDouble',v, ...
    'dBase100Hz',v,'kBase100Hz',v,'fBase100Hz',v,'fusion100Hz',v, ...
    'noSampleTimeConflict',v,'sameSampleStructuralContract',v,'noEstimatorSideCompileError',v);
end
function n=count_token(t,x),n=numel(strfind(t,x));end
function s=source_of_port(p)
l=get_param(p,'Line');assert(l>0,'Expected connected input port.');s=getfullname(get_param(l,'SrcBlockHandle'));
end
function d=destinations_of_port(p)
l=get_param(p,'Line');if l<0,d={};return,end;h=get_param(l,'DstBlockHandle');d=arrayfun(@getfullname,h,'UniformOutput',false);d=d(:);
end
function tf=all_hash_subset(r,h,idx)
tf=true;for k=idx,tf=tf&&strcmp(r(k).sha256,h{k});end
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx'); ...
 fullfile(root,'model','vx_vy_dekf_v1_17.slx'); fullfile(root,'model','vy_dynamic_ekf_v1_17.m'); ...
 fullfile(root,'model','vy_dynamic_ekf_step_v17.m'); fullfile(root,'model','vy_dynamic_ekf_step_v13.m'); ...
 fullfile(root,'model','vx_vy_kkf_v2_1.slx'); fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx'); ...
 fullfile(root,'model','vy_kinematic_kf_step.m'); fullfile(root,'model','vy_kinematic_kf.m'); ...
 fullfile(root,'model','vx_vy_dkekf_v2_2.slx'); fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
 fullfile(root,'model','vy_dkekf_baseline.m'); fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m'); ...
 fullfile(root,'model','vy_feedback_propagation_step.m'); ...
 fullfile(root,'model','vy_feedback_propagation_simulink_sfun.m'); ...
 fullfile(root,'model','vx_vy_feedback_track_v2_4.slx'); ...
 fullfile(root,'model','vy_fixed_weight_fusion_step.m')};
hashes={'98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0'; ...
 '108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE'; ...
 '5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0'; ...
 '4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F'; ...
 '498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4'; ...
 'B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712'; ...
 '59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E'; ...
 '3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244'; ...
 'F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4'; ...
 'E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15'; ...
 '6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457'; ...
 '7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973'; ...
 '12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1'; ...
 '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'; ...
 '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0'; ...
 '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84'; ...
 '4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C'};
end
function r=file_record(p),d=dir(p);r=struct('path',p,'bytes',d.bytes,'modifiedDatenum',d.datenum,'sha256',file_sha256(p));end
function r=snapshot(f),r=repmat(struct('path','','bytes',0,'sha256',''),numel(f),1);for k=1:numel(f),d=dir(f{k});r(k)=struct('path',f{k},'bytes',d.bytes,'sha256',file_sha256(f{k}));end,end
function ok=records_match(r,h),ok=numel(r)==numel(h);for k=1:numel(r),ok=ok&&strcmp(r(k).sha256,h{k});end,end
function ok=records_equal(a,b),ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&&strcmp(a(k).sha256,b(k).sha256);end,end
function ok=record_equal(a,b),ok=a.bytes==b.bytes&&a.modifiedDatenum==b.modifiedDatenum&&strcmp(a.sha256,b.sha256);end
function h=file_sha256(p),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(p));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(b,2).',1,[]));clear c,end
function close_models(target,harness)
for n={harness,target,'Solver_SF'},if bdIsLoaded(n{1}),try,feval(n{1},[],[],[],'term');catch,end;try,close_system(n{1},0);catch,end,end,end
end
