function report = validate_vy_lifesig_fusion_v2_7a3r8()
%VALIDATE_VY_LIFESIG_FUSION_V2_7A3R8 Static and compile-only validation.
% This validator never calls sim() and never saves a model.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
sourceFile=fullfile(md,'vx_vy_reliability_diagnostic_v2_7.slx');
targetFile=fullfile(md,'vx_vy_lifesig_fusion_v2_7.slx');
buildFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r8_build.mat');
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r8_compile.mat');
sourceExpected='2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F';
assert(isfile(targetFile)&&isfile(buildFile),'A3R8:BuildMissing', ...
    'A3R8 target or build evidence is missing.');
B=load(buildFile,'build');expectedTarget=B.build.targetHash;
assert(strcmp(file_sha256(sourceFile),sourceExpected),'A3R8:SourceHashMismatch', ...
    'Reliability diagnostic source target hash mismatch.');
assert(strcmp(file_sha256(targetFile),expectedTarget),'A3R8:TargetHashMismatch', ...
    'LifeSig target differs from build evidence.');

addpath(md);addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
load_system('simulink');load_system('Solver_SF');load_system(targetFile);
m='vx_vy_lifesig_fusion_v2_7';cleanup=onCleanup(@()close_all(m));
fusion=[m '/LifeSig D K F Fusion'];
report=struct();report.stage='V2.7-A3R8';report.modelLoaded=true;
report.compileCalled=false;report.compilePassed=false;
report.terminationReached=false;report.compiledEvidenceCaptured=false;
report.simCalled=false;report.carSimRun=false;
report.firstErrorIdentifier='';report.firstErrorMessage='';
report.sourceHashBefore=file_sha256(sourceFile);
report.targetHashBefore=file_sha256(targetFile);

ph=get_param(fusion,'PortHandles');
report.static=struct();
report.static.wrapperBlockType=get_param(fusion,'BlockType');
report.static.wrapperFunction=get_param(fusion,'FunctionName');
report.static.inputCount=numel(ph.Inport);report.static.outputCount=numel(ph.Outport);
report.static.dDemux=get_param([m '/D LifeSig Valid Demux'],'Outputs');
report.static.kDemux=get_param([m '/K LifeSig Diagnostic Demux'],'Outputs');
report.static.fDemux=get_param([m '/F LifeSig Reliability Demux'],'Outputs');
report.static.actualInputs=cell(8,1);
for k=1:8,report.static.actualInputs{k}=source_identity(ph.Inport(k));end
report.static.expectedInputs={ ...
    [m '/Fusion D State Select Vy#1'];[m '/D LifeSig Valid Demux#1']; ...
    [m '/Fusion K State Select Vy#2'];[m '/K LifeSig Diagnostic Demux#6']; ...
    [m '/F-Track 100Hz#1'];[m '/F LifeSig Reliability Demux#1']; ...
    [m '/F LifeSig Reliability Demux#2'];[m '/K-KF Reset First Call#1']};
report.static.inputMappingOK=isequal(report.static.actualInputs, ...
    report.static.expectedInputs);
report.static.wrapperOK=strcmp(report.static.wrapperBlockType,'M-S-Function')&& ...
    strcmp(report.static.wrapperFunction,'vy_lifesig_fusion_simulink_sfun')&& ...
    report.static.inputCount==8&&report.static.outputCount==9;
report.static.demuxOK=strcmp(regexprep(report.static.dDemux,'\s+',''),'[11]')&& ...
    strcmp(regexprep(report.static.kDemux,'\s+',''),'[1111111]')&& ...
    strcmp(regexprep(report.static.fDemux,'\s+',''),'[111]');

newLogs={'lifesig_vy_ls_log';'lifesig_alpha_d_log';'lifesig_alpha_k_log'; ...
    'lifesig_alpha_f_log';'lifesig_h_d_log';'lifesig_h_k_log'; ...
    'lifesig_h_f_log';'lifesig_fusion_valid_log'; ...
    'lifesig_fallback_active_log'};
existingLogs={'fusion_vy_d_log';'rel_d_valid_log';'fusion_vy_k_log'; ...
    'kkf_diag_log1';'fusion_vy_f_log';'rel_f_reliability_log'; ...
    'rel_vy_true_100hz_log';'rel_common_time_100hz_log'};
allWs=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace');vars=get_param(allWs,'VariableName');
if ischar(vars),vars={vars};end
report.static.newLogsPresent=all(ismember(newLogs,vars));
report.static.existingLogsPreserved=all(ismember(existingLogs,vars));
report.static.logMappings=cell(9,1);logMapOK=true;
for k=1:9
    b=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
        'BlockType','ToWorkspace','VariableName',newLogs{k});
    if numel(b)~=1,logMapOK=false;report.static.logMappings{k}='MISSING';continue,end
    p=get_param(b{1},'PortHandles');report.static.logMappings{k}=source_identity(p.Inport(1));
    logMapOK=logMapOK&&strcmp(report.static.logMappings{k},[fusion '#' num2str(k)]);
end
report.static.logMappingOK=logMapOK;
inputNames=lower(string(report.static.actualInputs));
report.static.formalInputExclusions= ...
    ~any(contains(inputNames,'nis'))&& ...
    ~any(contains(inputNames,'abs(r)'))&& ...
    ~any(contains(inputNames,'disagreement'))&& ...
    ~any(contains(inputNames,'covariance'))&& ...
    ~any(contains(inputNames,'true'));
report.static.fParameters=get_param([m '/F-Track 100Hz/F-Track Stateful Boundary'],'Parameters');
report.static.fParametersUnchanged=strcmp(strtrim(report.static.fParameters),'0.01,0,0.5,0.0025');

try
    report.compileCalled=true;
    feval(m,[],[],[],'compile');report.compilePassed=true;
    report.compiled=struct();
    report.compiled.dimensions=get_param(fusion,'CompiledPortDimensions');
    report.compiled.dataTypes=get_param(fusion,'CompiledPortDataTypes');
    report.compiled.sampleTime=get_param(fusion,'CompiledSampleTime');
    report.compiled.scalarDimensions=all_scalar(report.compiled.dimensions.Inport)&& ...
        all_scalar(report.compiled.dimensions.Outport);
    report.compiled.allDouble=all(strcmp(report.compiled.dataTypes.Inport,'double'))&& ...
        all(strcmp(report.compiled.dataTypes.Outport,'double'));
    report.compiled.sampleTime100Hz=sample_is_100hz(report.compiled.sampleTime);
    report.compiledEvidenceCaptured=true;
    feval(m,[],[],[],'term');report.terminationReached=true;
catch ME
    report.firstErrorIdentifier=ME.identifier;report.firstErrorMessage=ME.message;
    try,feval(m,[],[],[],'term');report.terminationReached=true;catch,end
end

report.sourceHashAfter=file_sha256(sourceFile);
report.targetHashAfter=file_sha256(targetFile);
report.sourceUnchanged=strcmp(report.sourceHashBefore,report.sourceHashAfter)&& ...
    strcmp(report.sourceHashAfter,sourceExpected);
report.targetUnchanged=strcmp(report.targetHashBefore,report.targetHashAfter)&& ...
    strcmp(report.targetHashAfter,expectedTarget);
staticFields={'wrapperOK','demuxOK','inputMappingOK','newLogsPresent', ...
    'existingLogsPreserved','logMappingOK','formalInputExclusions', ...
    'fParametersUnchanged'};
report.staticPassed=all(cellfun(@(f)report.static.(f),staticFields));
compiledOK=report.compiledEvidenceCaptured&&report.compiled.scalarDimensions&& ...
    report.compiled.allDouble&&report.compiled.sampleTime100Hz;
report.passed=report.modelLoaded&&report.staticPassed&&report.compilePassed&& ...
    report.terminationReached&&compiledOK&&report.sourceUnchanged&& ...
    report.targetUnchanged&&~report.simCalled&&~report.carSimRun;
save(resultFile,'report','-v7');
fprintf(['A3R8_COMPILE|static=%d|compile=%d|term=%d|compiled=%d|' ...
    'dims=%d|types=%d|rate=%d|source=%d|target=%d|passed=%d|sim=0|carsim=0\n'], ...
    report.staticPassed,report.compilePassed,report.terminationReached, ...
    report.compiledEvidenceCaptured,compiled_field(report,'scalarDimensions'), ...
    compiled_field(report,'allDouble'),compiled_field(report,'sampleTime100Hz'), ...
    report.sourceUnchanged,report.targetUnchanged,report.passed);
if ~report.passed
    fprintf('A3R8_ERROR|%s|%s\n',report.firstErrorIdentifier,report.firstErrorMessage);
end
assert(report.passed,'A3R8:CompileFailed','LifeSig integration compile gate failed.');
clear cleanup
end

function id=source_identity(inputPort)
line=get_param(inputPort,'Line');assert(isscalar(line)&&line>0,'Input is disconnected.');
sp=get_param(line,'SrcPortHandle');b=get_param(sp,'Parent');n=get_param(sp,'PortNumber');
if isnumeric(n),n=num2str(n);end
id=[b '#' n];
end
function ok=all_scalar(c)
if ~iscell(c),c={c};end
ok=true;
for k=1:numel(c),d=double(c{k});ok=ok&&~isempty(d)&&prod(d)==1;end
end
function ok=sample_is_100hz(x)
if iscell(x),x=x{1};end
x=double(x);ok=numel(x)>=2&&abs(x(1)-0.01)<=1e-12&&abs(x(2))<=1e-12;
end
function v=compiled_field(report,name)
v=false;if isfield(report,'compiled')&&isfield(report.compiled,name),v=report.compiled.(name);end
end
function close_all(m)
if bdIsLoaded(m),try,close_system(m,0);catch,end,end
if bdIsLoaded('Solver_SF'),try,close_system('Solver_SF',0);catch,end,end
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');
hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
