function report = test_vy_fixed_weight_fusion_v2_5b()
%TEST_VY_FIXED_WEIGHT_FUSION_V2_5B Pure MATLAB mathematical-core tests.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
coreFile = fullfile(projectRoot,'model','vy_fixed_weight_fusion_step.m');
testFile = [mfilename('fullpath') '.m'];
resultFile = fullfile(projectRoot,'results', ...
    'vy_fixed_fusion_v2_5b_unit_tests.mat');
architectureFile = fullfile(projectRoot,'docs', ...
    'STAGE_VY_FIXED_FUSION_V2_5A_ARCHITECTURE_AUDIT.md');
architectureExpected = ...
    '16C97B60772D56BD4F32D2D9C75D2E5CEB9D0E37CFCD4C8E226C332B1720B122';

[frozenFiles,frozenExpected] = frozen_manifest(projectRoot,architectureFile, ...
    architectureExpected);
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'Frozen dependency mismatch before V2.5-B tests.');

tol = 1e-12;
randomSeed = 2505;
randomCaseCount = 1000;
cases = repmat(case_result('',false,[],[],Inf,''),34,1);
coreText = lower(fileread(coreFile));
noSilentNormalization = isempty(regexp(coreText, ...
    'alpha_[dkf]\s*=\s*alpha_[dkf]\s*/|alpha\s*=\s*alpha\s*/', ...
    'once'));

% T1-T3: exact legal degenerate cases.
y = fuse([3;-7;11],[1;0;0]);
cases(1) = case_result('T1 D-only identity',isequal(y,3),3,y,abs(y-3),'');
y = fuse([3;-7;11],[0;1;0]);
cases(2) = case_result('T2 K-only identity',isequal(y,-7),-7,y,abs(y+7),'');
y = fuse([3;-7;11],[0;0;1]);
cases(3) = case_result('T3 F-only identity',isequal(y,11),11,y,abs(y-11),'');

% T4-T9: deterministic analytical convex combinations.
y = fuse([4;4;4],[0.5;0.25;0.25]);
cases(4) = case_result('T4 Equal-input invariance',isequal(y,4),4,y,abs(y-4),'');
y = fuse([1;2;3],[0.5;0.3;0.2]);
cases(5) = case_result('T5 General analytical convex combination', ...
    abs(y-1.7)<=tol,1.7,y,abs(y-1.7),'');
y = fuse([-1;-2;-3],[0.2;0.3;0.5]);
cases(6) = case_result('T6 Negative state values', ...
    abs(y+2.3)<=tol,-2.3,y,abs(y+2.3),'');
y = fuse([-4;2;8],[0.25;0.5;0.25]);
cases(7) = case_result('T7 Mixed-sign state values', ...
    abs(y-2)<=tol,2,y,abs(y-2),'');
y = fuse([0;0;0],[0.1;0.2;0.7]);
cases(8) = case_result('T8 Zero states',isequal(y,0),0,y,abs(y),'');
y = fuse([-3;6;9],[1/3;1/3;1/3]);
cases(9) = case_result('T9 Equal TEST-ONLY weights', ...
    abs(y-4)<=tol,4,y,abs(y-4),'TEST-ONLY; not selected, tuned, or frozen.');

% T10-T14: convex bounds, purity, statelessness, and legal zero weight.
states = [-4;2;8]; weights = [0.25;0.5;0.25];
y = fuse(states,weights);
lowerViolation = max(min(states)-y,0);
upperViolation = max(y-max(states),0);
cases(10) = case_result('T10 Convex-hull lower bound', ...
    lowerViolation<=tol,min(states),y,lowerViolation,'');
cases(11) = case_result('T11 Convex-hull upper bound', ...
    upperViolation<=tol,max(states),y,upperViolation,'');
y1 = fuse([0.125;-3.5;9.25],[0.2;0.3;0.5]);
y2 = fuse([0.125;-3.5;9.25],[0.2;0.3;0.5]);
cases(12) = case_result('T12 Deterministic purity', ...
    isequal(y1,y2),y1,y2,abs(y1-y2),'');
yReference = fuse([1;5;-2],[0.4;0.1;0.5]);
fuse([100;-200;300],[0;1;0]);
yAfter = fuse([1;5;-2],[0.4;0.1;0.5]);
cases(13) = case_result('T13 Stateless sequence', ...
    isequal(yReference,yAfter),yReference,yAfter,abs(yReference-yAfter),'');
y = fuse([100;2;4],[0;0.4;0.6]);
cases(14) = case_result('T14 Legitimate zero weight', ...
    abs(y-3.2)<=tol,3.2,y,abs(y-3.2),'');

% T15-T24: explicit invalid-input rejection and no repair.
cases(15) = rejection_case('T15 Negative alpha_D rejected', ...
    @()fuse([1;2;3],[-0.1;0.5;0.6]), ...
    'vy_fixed_weight_fusion_step:NegativeWeight');
cases(16) = rejection_case('T16 Negative alpha_K rejected', ...
    @()fuse([1;2;3],[0.5;-0.1;0.6]), ...
    'vy_fixed_weight_fusion_step:NegativeWeight');
cases(17) = rejection_case('T17 Negative alpha_F rejected', ...
    @()fuse([1;2;3],[0.5;0.6;-0.1]), ...
    'vy_fixed_weight_fusion_step:NegativeWeight');
cases(18) = rejection_case('T18 Sum below one rejected', ...
    @()fuse([1;2;3],[0.2;0.2;0.2]), ...
    'vy_fixed_weight_fusion_step:InvalidWeightSum');
cases(19) = rejection_case('T19 Sum above one rejected', ...
    @()fuse([1;2;3],[0.5;0.5;0.5]), ...
    'vy_fixed_weight_fusion_step:InvalidWeightSum');
cases(20) = rejection_case('T20 NaN weight rejected', ...
    @()fuse([1;2;3],[NaN;0.4;0.6]), ...
    'vy_fixed_weight_fusion_step:NonfiniteWeight');
cases(21) = rejection_case('T21 Inf weight rejected', ...
    @()fuse([1;2;3],[Inf;0;0]), ...
    'vy_fixed_weight_fusion_step:NonfiniteWeight');
cases(22) = rejection_case('T22 NaN state rejected', ...
    @()fuse([NaN;2;3],[0.2;0.3;0.5]), ...
    'vy_fixed_weight_fusion_step:NonfiniteState');
cases(23) = rejection_case('T23 Inf state rejected', ...
    @()fuse([1;Inf;3],[0.2;0.3;0.5]), ...
    'vy_fixed_weight_fusion_step:NonfiniteState');
reject24 = rejection_case('T24 No silent normalization', ...
    @()fuse([1;2;3],[0.2;0.2;0.2]), ...
    'vy_fixed_weight_fusion_step:InvalidWeightSum');
reject24.passed = reject24.passed && noSilentNormalization;
reject24.actual = sprintf('%s|coreNormalizationPattern=%d', ...
    reject24.actual,~noSilentNormalization);
cases(24) = reject24;

% T25-T27: output contract, ordering/permutation, and random convex tests.
y = vy_fixed_weight_fusion_step(single(4),single(-2),single(8), ...
    single(0.5),single(0.25),single(0.25));
cases(25) = case_result('T25 Scalar double output dimension', ...
    isscalar(y)&&isa(y,'double'), ...
    'scalar double',sprintf('%s %s',mat2str(size(y)),class(y)),0,'');
s = [1;4;-2]; w = [0.2;0.3;0.5];
yOriginal = fuse(s,w);
yPermuted = fuse([s(2);s(1);s(3)],[w(2);w(1);w(3)]);
yExpected = w(1)*s(1)+w(2)*s(2)+w(3)*s(3);
err26 = max(abs([yOriginal-yExpected;yPermuted-yExpected]));
cases(26) = case_result('T26 D/K/F permutation analytical mapping', ...
    err26<=tol,[yExpected;yExpected],[yOriginal;yPermuted],err26,'');

rng(randomSeed,'twister');
maxRandomAnalyticalError = 0;
maxRandomConvexViolation = 0;
randomFinite = true;
for k=1:randomCaseCount
    randomStates = 40*randn(3,1);
    rawWeights = rand(3,1);
    testWeights = rawWeights/sum(rawWeights); % TEST DATA GENERATION ONLY.
    actual = fuse(randomStates,testWeights);
    expected = testWeights(1)*randomStates(1) + ...
        testWeights(2)*randomStates(2) + ...
        testWeights(3)*randomStates(3);
    maxRandomAnalyticalError = max(maxRandomAnalyticalError,abs(actual-expected));
    violation = max([min(randomStates)-actual; ...
        actual-max(randomStates);0]);
    maxRandomConvexViolation = max(maxRandomConvexViolation,violation);
    randomFinite = randomFinite && isfinite(actual);
end
cases(27) = case_result('T27 Repeated randomized convex tests', ...
    maxRandomAnalyticalError<=tol && maxRandomConvexViolation<=tol && ...
    randomFinite, ...
    '1000 finite analytical convex cases', ...
    sprintf('seed=%d|maxAnalytical=%.17g|maxConvexViolation=%.17g|finite=%d', ...
    randomSeed,maxRandomAnalyticalError,maxRandomConvexViolation,randomFinite), ...
    max(maxRandomAnalyticalError,maxRandomConvexViolation), ...
    'Weights normalized only in test-data generation; core does not normalize.');

% T28-T34: source-level isolation and exact one-output contract.
covariancePattern = '\<p_d\>|\<p_k\>|\<p_f\>|\<p_fw\>|covariance';
noCovariance = isempty(regexp(coreText,covariancePattern,'once'));
cases(28) = case_result('T28 No covariance dependency', ...
    noCovariance,true,noCovariance,0,'');
adaptivePattern = 'lifesig|\<nis\>|observability|reliability|adaptive|\<switch\>|winner|fallback';
noAdaptive = isempty(regexp(coreText,adaptivePattern,'once'));
cases(29) = case_result('T29 No adaptive dependency', ...
    noAdaptive,true,noAdaptive,0,'');
truthPattern = '\<truevy\>|\<true_vy\>|true vy|vy_true';
noTruth = isempty(regexp(coreText,truthPattern,'once'));
cases(30) = case_result('T30 No truth dependency',noTruth,true,noTruth,0,'');
noDKEKF = isempty(regexp(coreText,'dk[-_ ]?ekf|dkekf','once'));
cases(31) = case_result('T31 No DK-EKF dependency', ...
    noDKEKF,true,noDKEKF,0,'');
feedbackPattern = 'vy_feedback|p_feedback|feedback_valid|feedback logic';
noFeedback = isempty(regexp(coreText,feedbackPattern,'once'));
cases(32) = case_result('T32 No feedback dependency', ...
    noFeedback,true,noFeedback,0,'');
coreStateless = isempty(regexp(coreText, ...
    '\<persistent\>|\<global\>|assignin|evalin|\<memory\>','once'));
cases(33) = case_result('T33 No persistent/global/memory', ...
    coreStateless,true,coreStateless,0,'');
oneOutput = nargout('vy_fixed_weight_fusion_step')==1 && ...
    ~isempty(regexp(coreText, ...
    'function\s+vy_fw\s*=\s*vy_fixed_weight_fusion_step','once')) && ...
    isempty(regexp(coreText,'\<p_fw\>|confidence|diag_fw','once'));
cases(34) = case_result('T34 Fixed single-output contract', ...
    oneOutput,'Vy_FW only',oneOutput,0,'');

frozenAfter = hash_records(frozenFiles);
frozenUnchanged = records_equal(frozenBefore,frozenAfter) && ...
    hashes_match(frozenAfter,frozenExpected);
allPassed = all([cases.passed]) && frozenUnchanged;

report = struct();
report.stage = 'V2.5-B';
report.equation = 'Vy_FW=alpha_D*Vy_D+alpha_K*Vy_K+alpha_F*Vy_F';
report.inputOrdering = {'Vy_D';'Vy_K';'Vy_F';'alpha_D';'alpha_K';'alpha_F'};
report.output = 'Vy_FW scalar double [m/s]';
report.testNames = {cases.name}.';
report.passed = [cases.passed].';
report.expected = {cases.expected}.';
report.actual = {cases.actual}.';
report.maxNumericalErrors = [cases.maxError].';
report.messages = {cases.message}.';
report.gateCount = numel(cases);
report.gatesTrue = sum(report.passed);
report.allPassed = allPassed;
report.weightSumTolerance = tol;
report.noSilentNormalization = noSilentNormalization;
report.coreStateless = coreStateless;
report.staticGates = struct('noCovariance',noCovariance, ...
    'noFusedCovariance',noCovariance,'noAdaptive',noAdaptive, ...
    'noLifeSig',noAdaptive,'noTruthOnline',noTruth, ...
    'noDKEKF',noDKEKF,'noFeedback',noFeedback, ...
    'singleOutput',oneOutput);
report.random = struct('seed',randomSeed,'caseCount',randomCaseCount, ...
    'maxAnalyticalError',maxRandomAnalyticalError, ...
    'maxConvexBoundViolation',maxRandomConvexViolation, ...
    'allFinite',randomFinite, ...
    'normalizationLocation','TEST SCRIPT DATA GENERATION ONLY');
report.testOnlyWeights = [1 0 0;0 1 0;0 0 1;0.5 0.3 0.2; ...
    1/3 1/3 1/3;0 0.4 0.6];
report.weightPolicy = struct('alpha_D','NOT SELECTED / NOT TUNED / NOT FROZEN', ...
    'alpha_K','NOT SELECTED / NOT TUNED / NOT FROZEN', ...
    'alpha_F','NOT SELECTED / NOT TUNED / NOT FROZEN', ...
    'testValuesOnly',true,'tuningPerformed',false, ...
    'selectedBaselineWeights',[]);
report.stateOnly = true;
report.fusedCovarianceGenerated = false;
report.trackIndependenceAssumed = false;
report.feedbackClosed = false;
report.simulinkUsed = false;
report.simCalled = false;
report.carSimRun = false;
report.architectureSHA256 = upper(file_sha256(architectureFile));
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.frozenUnchanged = frozenUnchanged;
report.coreSHA256 = upper(file_sha256(coreFile));
report.testScriptSHA256 = upper(file_sha256(testFile));

save(resultFile,'report','-v7');
fprintf(['V2_5B_UNIT_TESTS|passed=%d/%d|all=%d|stateless=%d|', ...
    'noNormalize=%d|frozen=%d\n'],report.gatesTrue,report.gateCount, ...
    report.allPassed,report.coreStateless,report.noSilentNormalization, ...
    report.frozenUnchanged);
fprintf(['V2_5B_RANDOM|seed=%d|N=%d|maxAnalytical=%.17g|', ...
    'maxConvexViolation=%.17g|finite=%d\n'], ...
    report.random.seed,report.random.caseCount, ...
    report.random.maxAnalyticalError, ...
    report.random.maxConvexBoundViolation,report.random.allFinite);
fprintf('V2_5B_HASH|core=%s|test=%s|architecture=%s\n', ...
    report.coreSHA256,report.testScriptSHA256,report.architectureSHA256);
assert(report.allPassed,'V2.5-B unit-test gate failed.');
end

function y = fuse(states,weights)
y = vy_fixed_weight_fusion_step(states(1),states(2),states(3), ...
    weights(1),weights(2),weights(3));
end

function c = case_result(name,passed,expected,actual,maxError,message)
c = struct('name',name,'passed',logical(passed),'expected',expected, ...
    'actual',actual,'maxError',double(maxError),'message',message);
end

function c = rejection_case(name,fn,expectedIdentifier)
[passed,identifier,message] = rejects(fn,expectedIdentifier);
c = case_result(name,passed,expectedIdentifier,identifier,0,message);
end

function [passed,identifier,message] = rejects(fn,expectedIdentifier)
passed = false; identifier = ''; message = '';
try
    fn();
catch ME
    identifier = ME.identifier;
    message = ME.message;
    passed = strcmp(ME.identifier,expectedIdentifier);
end
end

function [files,expected] = frozen_manifest(root,architectureFile,architectureHash)
files = {
    architectureFile
    fullfile(root,'model','vy_feedback_propagation_step.m')
    fullfile(root,'model','vy_feedback_propagation_simulink_sfun.m')
    fullfile(root,'model','vx_vy_feedback_track_v2_4.slx')
    fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx')
    fullfile(root,'model','vx_vy_dekf_v1_17.slx')
    fullfile(root,'model','vy_dynamic_ekf_v1_17.m')
    fullfile(root,'model','vy_dynamic_ekf_step_v17.m')
    fullfile(root,'model','vy_dynamic_ekf_step_v13.m')
    fullfile(root,'model','vx_vy_kkf_v2_1.slx')
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx')
    fullfile(root,'model','vy_kinematic_kf_step.m')
    fullfile(root,'model','vy_kinematic_kf.m')
    fullfile(root,'model','vx_vy_dkekf_v2_2.slx')
    fullfile(root,'model','vy_dkekf_baseline_step.m')
    fullfile(root,'model','vy_dkekf_baseline.m')
    fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m')};
expected = {
    architectureHash
    '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'
    '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0'
    '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84'
    '98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0'
    '108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE'
    '5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0'
    '4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F'
    '498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4'
    'B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712'
    '59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E'
    '3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244'
    'F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4'
    'E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15'
    '6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457'
    '7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973'
    '12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1'};
end

function records = hash_records(files)
records = repmat(struct('path','','sha256',''),numel(files),1);
for k=1:numel(files)
    records(k).path = files{k};
    records(k).sha256 = upper(file_sha256(files{k}));
end
end

function ok = hashes_match(records,expected)
ok = numel(records)==numel(expected);
for k=1:numel(records)
    ok = ok && strcmp(records(k).sha256,expected{k});
end
end

function ok = records_equal(a,b)
ok = numel(a)==numel(b);
for k=1:numel(a)
    ok = ok && strcmp(a(k).path,b(k).path) && ...
        strcmp(a(k).sha256,b(k).sha256);
end
end

function h = file_sha256(file)
d = java.security.MessageDigest.getInstance('SHA-256');
s = java.io.FileInputStream(java.io.File(file));
ds = java.security.DigestInputStream(s,d);
c = onCleanup(@()ds.close());
while ds.read()~=-1
end
b = typecast(d.digest(),'uint8');
h = lower(reshape(dec2hex(b,2).',1,[]));
clear c
end
