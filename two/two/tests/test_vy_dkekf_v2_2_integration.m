function report=test_vy_dkekf_v2_2_integration(compileEvidence)
%TEST_VY_DKEKF_V2_2_INTEGRATION Default no-write C1 acceptance path.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'model'));
resultFile=fullfile(root,'results','vy_dkekf_v2_2c1_integration.mat');
assert(isfile(resultFile),['Existing build report is required. Run ' ...
    'build_vy_dkekf_v2_2 explicitly, then run this integration test.']);
s=load(resultFile,'buildReport');assert(isfield(s,'buildReport'), ...
    'Existing C1 result does not contain buildReport.');buildReport=s.buildReport;
before=file_record(buildReport.targetFile);
if nargin<1||isempty(compileEvidence)
    validation=validate_vy_dkekf_v2_2_integration(buildReport);
else
    validation=validate_vy_dkekf_v2_2_integration(buildReport,compileEvidence);
end
after=file_record(buildReport.targetFile);

testText=lower(fileread(which('test_vy_dkekf_v2_2_integration')));
validatorText=lower(fileread(which('validate_vy_dkekf_v2_2_integration')));
defaultNoBuilder=no_function_call(testText,'build_vy_dkekf_v2_2')&& ...
    no_function_call(validatorText,'build_vy_dkekf_v2_2');
defaultNoCopy=no_function_call(testText,'copyfile')&& ...
    no_function_call(validatorText,'copyfile');
defaultNoSaveModel=no_function_call(testText,'save_system')&& ...
    no_function_call(validatorText,'save_system');
targetNoWrite=before.bytes==after.bytes&&before.modifiedDatenum==after.modifiedDatenum&& ...
    strcmp(before.sha256,after.sha256);

gates=validation.gates;gates.defaultNoBuilder=defaultNoBuilder;
gates.defaultNoCopy=defaultNoCopy;gates.defaultNoSaveModel=defaultNoSaveModel;
gates.testTargetNoWrite=targetNoWrite;
values=struct2cell(gates);v=cellfun(@(x)logical(x),values);
report=struct('stage','V2.2-C1','passed',all(v), ...
    'gateCount',numel(v),'gatesTrue',sum(v),'gates',gates, ...
    'validation',validation,'targetBefore',before,'targetAfter',after, ...
    'simCalled',false,'carSimRun',false);
save(resultFile,'buildReport','validation','report');
assert(report.passed,'One or more V2.2-C1 integration gates failed.');
fprintf('V2_2C1_INTEGRATION_OK|gates=%d/%d|targetNoWrite=%d|hash=%s\n', ...
    report.gatesTrue,report.gateCount,targetNoWrite,after.sha256);
end
function r=file_record(path),d=dir(path);r=struct('path',path,'bytes',d.bytes,'modifiedDatenum',d.datenum,'sha256',file_sha256(path));end
function hash=file_sha256(path),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c,end
function ok=no_function_call(text,name)
code=regexprep(text,'''(?:''''|[^''])*''','''string''');
code=regexprep(code,'(?m)%.*$','');
ok=isempty(regexp(code,['\<' name '\s*\('],'once'));
end
