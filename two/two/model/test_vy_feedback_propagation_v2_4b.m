function report = test_vy_feedback_propagation_v2_4b()
%TEST_VY_FEEDBACK_PROPAGATION_V2_4B Deterministic mathematical-core tests.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
wrapperText = fileread(fullfile(projectRoot,'model', ...
    'vy_feedback_propagation_simulink_sfun.m'));
assert(contains(wrapperText,'block.NumOutputPorts = 4') && ...
    contains(wrapperText,'propagation_age_steps') && ...
    contains(wrapperText,'ageOut = 0'), ...
    'F reliability diagnostic boundary is missing.');
resultFile = fullfile(projectRoot,'results', ...
    'vy_feedback_track_v2_4b_unit_tests.mat');
coreFile = fullfile(projectRoot,'model','vy_feedback_propagation_step.m');
testFile = [mfilename('fullpath') '.m'];

frozenFiles = {
    fullfile(projectRoot,'model','vx_vy_parallel_dk_v2_3.slx')
    fullfile(projectRoot,'model','vx_vy_dekf_v1_17.slx')
    fullfile(projectRoot,'model','vy_dynamic_ekf_v1_17.m')
    fullfile(projectRoot,'model','vy_dynamic_ekf_step_v17.m')
    fullfile(projectRoot,'model','vy_dynamic_ekf_step_v13.m')
    fullfile(projectRoot,'model','vx_vy_kkf_v2_1.slx')
    fullfile(projectRoot,'model','vx_vy_kkf_v2_1g_steer.slx')
    fullfile(projectRoot,'model','vy_kinematic_kf_step.m')
    fullfile(projectRoot,'model','vy_kinematic_kf.m')
    fullfile(projectRoot,'model','vx_vy_dkekf_v2_2.slx')
    fullfile(projectRoot,'model','vy_dkekf_baseline_step.m')
    fullfile(projectRoot,'model','vy_dkekf_baseline.m')
    fullfile(projectRoot,'model','vy_dkekf_baseline_simulink_sfun.m')};
frozenExpected = {
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
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'Frozen baseline mismatch before V2.4-B tests.');

Ts = 0.01;                 % TEST-ONLY
Vy_F0 = 0.125;             % TEST-ONLY
P0_F = 0.5;                % TEST-ONLY
Q_F = 0.0025;              % TEST-ONLY
tol = 1e-12;
cases = repmat(case_result('',false,[],[],Inf,''),34,1);

% T1-T5: reset is exact and has absolute priority.
[vy,p,d] = step(8,-2,10,0.3,20,-4,-7,true,true,Ts,Vy_F0,P0_F,Q_F);
cases(1) = case_result('T1 Reset exact state',vy==Vy_F0,Vy_F0,vy,abs(vy-Vy_F0),'');
cases(2) = case_result('T2 Reset exact covariance',p==P0_F,P0_F,p,abs(p-P0_F),'');
cases(3) = case_result('T3 Reset diagnostics',isequal(d,[0;0;0]),[0;0;0],d,max(abs(d)),'');
cases(4) = case_result('T4 Reset overrides feedback', ...
    vy==Vy_F0 && p==P0_F,[Vy_F0;P0_F],[vy;p],max(abs([vy-Vy_F0;p-P0_F])),'');
cases(5) = case_result('T5 Reset overrides dynamics', ...
    isequal(d,[0;0;0]),[0;0;0],d,max(abs(d)),'');

% T6-T9: standalone propagation and frozen-K sign regression.
[vy0,p0,d0] = step(0.3,0.2,2,0.1,20,99,8,false,false,Ts,0,P0_F,Q_F);
cases(6) = case_result('T6 Standalone zero dynamics', ...
    vy0==0.3 && p0==0.2+Q_F,[0.3;0.2+Q_F],[vy0;p0], ...
    max(abs([vy0-0.3;p0-(0.2+Q_F)])),'');
[vyPos,~,~] = step(0.3,0.2,3,0.1,20,0,0,false,false,Ts,0,P0_F,Q_F);
cases(7) = case_result('T7 Standalone positive propagation', ...
    abs(vyPos-0.31)<=tol,0.31,vyPos,abs(vyPos-0.31),'');
[vyNeg,~,dNeg] = step(0.3,0.2,1,0.1,20,0,0,false,false,Ts,0,P0_F,Q_F);
cases(8) = case_result('T8 Standalone negative propagation', ...
    abs(vyNeg-0.29)<=tol,0.29,vyNeg,abs(vyNeg-0.29),'');
cases(9) = case_result('T9 Kinematic sign regression', ...
    dNeg(1)==-1 && dNeg(2)==-0.01,[-1;-0.01],dNeg(1:2), ...
    max(abs(dNeg(1:2)-[-1;-0.01])),'');

% T10-T13: state and covariance select the same feedback branch atomically.
[vyFb,pFb,dFb] = step(10,3,0,0,20,-2,0.7,true,false,Ts,0,P0_F,Q_F);
cases(10) = case_result('T10 Feedback state selected',vyFb==-2,-2,vyFb,abs(vyFb+2),'');
cases(11) = case_result('T11 Feedback covariance selected', ...
    pFb==0.7+Q_F,0.7+Q_F,pFb,abs(pFb-(0.7+Q_F)),'');
[vyAtomic,pAtomic,~] = step(10,3,3,0.1,20,-2,0.7,true,false,Ts,0,P0_F,Q_F);
atomicExpected = [-1.99;0.7+Q_F];
cases(12) = case_result('T12 Feedback state/covariance atomicity', ...
    max(abs([vyAtomic;pAtomic]-atomicExpected))<=tol, ...
    atomicExpected,[vyAtomic;pAtomic],max(abs([vyAtomic;pAtomic]-atomicExpected)),'');
[v13a,p13a,d13a] = step(0.4,0.3,2,0.1,20,1,0.9,false,false,Ts,0,P0_F,Q_F);
[v13b,p13b,d13b] = step(0.4,0.3,2,0.1,20,-999,99,false,false,Ts,0,P0_F,Q_F);
cases(13) = case_result('T13 Feedback false ignores feedback values', ...
    isequal([v13a;p13a;d13a],[v13b;p13b;d13b]), ...
    [v13a;p13a;d13a],[v13b;p13b;d13b], ...
    max(abs([v13a;p13a;d13a]-[v13b;p13b;d13b])),'');

% T14-T21: covariance increment, diagnostics, shape, and purity.
[~,p14,~] = step(0.2,0.375,0,0,20,0,0,false,false,Ts,0,P0_F,0);
cases(14) = case_result('T14 Q_F = 0',p14==0.375,0.375,p14,abs(p14-0.375),'');
[~,p15,~] = step(0.2,0.25,0,0,20,0,0,false,false,Ts,0,P0_F,0.125);
cases(15) = case_result('T15 Positive Q_F', ...
    p15-0.25==0.125,0.125,p15-0.25,abs((p15-0.25)-0.125),'');
cases(16) = case_result('T16 diag prop_term exact',dNeg(1)==-1,-1,dNeg(1),abs(dNeg(1)+1),'');
cases(17) = case_result('T17 diag deltaVy exact',dNeg(2)==-0.01,-0.01,dNeg(2),abs(dNeg(2)+0.01),'');
cases(18) = case_result('T18 diag feedbackApplied false = 0',dNeg(3)==0,0,dNeg(3),abs(dNeg(3)),'');
cases(19) = case_result('T19 diag feedbackApplied true = 1',dFb(3)==1,1,dFb(3),abs(dFb(3)-1),'');
cases(20) = case_result('T20 fixed output dimensions', ...
    isscalar(vyFb)&&isscalar(pFb)&&isequal(size(dFb),[3 1])&&isa(dFb,'double'), ...
    'scalar/scalar/3x1 double',sprintf('%s/%s/%s %s', ...
    mat2str(size(vyFb)),mat2str(size(pFb)),mat2str(size(dFb)),class(dFb)),0,'');
[v21a,p21a,d21a] = step(0.4,0.3,1.2,0.04,19.5,0.7,0.6,true,false,Ts,0,P0_F,Q_F);
[v21b,p21b,d21b] = step(0.4,0.3,1.2,0.04,19.5,0.7,0.6,true,false,Ts,0,P0_F,Q_F);
cases(21) = case_result('T21 deterministic purity', ...
    isequal([v21a;p21a;d21a],[v21b;p21b;d21b]), ...
    [v21a;p21a;d21a],[v21b;p21b;d21b],0,'');

% T22-T24: analytical recurrences and post-feedback continuity.
N = 250; v = 0.2; pN = 0.4; qN = 0.001;
for k=1:N
    [v,pN] = step(v,pN,1.5,0.05,10,0,0,false,false,Ts,0,P0_F,qN);
end
vExpected = 0.2 + N*Ts*1.0;
pExpected = 0.4 + N*qN;
err22 = max(abs([v-vExpected;pN-pExpected]));
v22Actual = v;
p22Actual = pN;
cases(22) = case_result('T22 Standalone multi-step analytical recurrence', ...
    err22<=tol,[vExpected;pExpected],[v;pN],err22,'');
v = 0; pN = 0.2;
for k=1:3
    [v,pN] = step(v,pN,1,0,20,0,0,false,false,Ts,0,P0_F,0.001);
end
[v23,p23] = step(v,pN,1,0,20,5,0.4,true,false,Ts,0,P0_F,0.001);
err23 = max(abs([v23-5.01;p23-0.401]));
cases(23) = case_result('T23 Feedback rebase analytical recurrence', ...
    err23<=tol,[5.01;0.401],[v23;p23],err23,'');
[v24,p24] = step(v23,p23,1,0,20,-8,9,false,false,Ts,0,P0_F,0.001);
err24 = max(abs([v24-5.02;p24-0.402]));
cases(24) = case_result('T24 Post-feedback standalone continuity', ...
    err24<=tol,[5.02;0.402],[v24;p24],err24,'');

% T25-T27: source-level isolation gates.
coreText = lower(fileread(coreFile));
noTrueVy = isempty(regexp(coreText,'\<truevy\>|\<true_vy\>|true vy','once'));
cases(25) = case_result('T25 No true-Vy dependency',noTrueVy,true,noTrueVy,0,'');
crossPattern = '\<vy_d\>|\<vy_k\>|\<p_d\>|\<p_k\>|\<r_d\>|\<vx_k\>';
noDK = isempty(regexp(coreText,crossPattern,'once'));
cases(26) = case_result('T26 No D/K dependency',noDK,true,noDK,0,'');
fusionPattern = '\<alpha\w*\>|\<vy_fused\>|\<vy_final\>|lifesig|reliability';
noFusion = isempty(regexp(coreText,fusionPattern,'once'));
cases(27) = case_result('T27 No fusion artifacts',noFusion,true,noFusion,0,'');

% T28: 10000-step bounded numerical sanity and deterministic repeatability.
longN = 10000; qLong = 1e-6; vA = zeros(longN+1,1); pA = zeros(longN+1,1);
vB = zeros(longN+1,1); pB = zeros(longN+1,1); vA(1)=0.1; pA(1)=0.2;
vB(1)=0.1; pB(1)=0.2;
for k=1:longN
    ay = 0.8*sin(0.001*k); r = 0.02*cos(0.0007*k);
    vx = 20 + 0.5*sin(0.0002*k);
    [vA(k+1),pA(k+1)] = step(vA(k),pA(k),ay,r,vx,0,0,false,false,Ts,0,P0_F,qLong);
    [vB(k+1),pB(k+1)] = step(vB(k),pB(k),ay,r,vx,0,0,false,false,Ts,0,P0_F,qLong);
end
longFinite = all(isfinite(vA))&&all(isfinite(pA));
longNonnegative = all(pA>=0);
longDeterministic = isequal(vA,vB)&&isequal(pA,pB);
longMaxStateRepeatDiff = max(abs(vA-vB));
longMaxCovRepeatDiff = max(abs(pA-pB));
cases(28) = case_result('T28 Long deterministic finite propagation', ...
    longFinite&&longNonnegative&&longDeterministic, ...
    'finite/nonnegative/exact repeat', ...
    sprintf('%d/%d/%d',longFinite,longNonnegative,longDeterministic), ...
    max(longMaxStateRepeatDiff,longMaxCovRepeatDiff),'');

% T29-T34: explicit rejection; no clipping or silent correction.
cases(29) = rejection_case('T29 Reject Ts <= 0', ...
    @()step(0,0.1,0,0,20,0,0,false,false,0,0,P0_F,Q_F));
cases(30) = rejection_case('T30 Reject P0_F <= 0 on reset', ...
    @()step(0,0.1,0,0,20,0,0,false,true,Ts,0,0,Q_F));
cases(31) = rejection_case('T31 Reject Q_F < 0', ...
    @()step(0,0.1,0,0,20,0,0,false,false,Ts,0,P0_F,-0.1));
cases(32) = rejection_case('T32 Reject P_prev < 0 standalone', ...
    @()step(0,-0.1,0,0,20,0,0,false,false,Ts,0,P0_F,Q_F));
cases(33) = rejection_case('T33 Reject feedback covariance < 0 when valid', ...
    @()step(0,0.1,0,0,20,0,-0.1,true,false,Ts,0,P0_F,Q_F));
nanRejected = rejects(@()step(0,0.1,NaN,0,20,0,0,false,false,Ts,0,P0_F,Q_F));
infRejected = rejects(@()step(0,0.1,0,0,Inf,0,0,false,false,Ts,0,P0_F,Q_F));
cases(34) = case_result('T34 Reject NaN/Inf active input', ...
    nanRejected&&infRejected,[true;true],[nanRejected;infRejected],0,'');

coreStateless = isempty(regexp(coreText,'\<persistent\>|\<global\>|assignin|evalin','once'));
allPassed = all([cases.passed]) && coreStateless;
frozenAfter = hash_records(frozenFiles);
frozenUnchanged = records_equal(frozenBefore,frozenAfter) && ...
    hashes_match(frozenAfter,frozenExpected);
allPassed = allPassed && frozenUnchanged;

report = struct();
report.stage = 'V2.4-B';
report.testNames = {cases.name}.';
report.passed = [cases.passed].';
report.expected = {cases.expected}.';
report.actual = {cases.actual}.';
report.maxNumericalErrors = [cases.maxError].';
report.messages = {cases.message}.';
report.gateCount = numel(cases);
report.gatesTrue = sum(report.passed);
report.allPassed = allPassed;
report.coreStateless = coreStateless;
report.signRegression = struct('Ay',1,'AVz',0.1,'Vx',20,'Ts',0.01, ...
    'propTerm',dNeg(1),'deltaVy',dNeg(2));
report.longRun = struct('steps',longN,'finite',longFinite, ...
    'covarianceNonnegative',longNonnegative,'deterministic',longDeterministic, ...
    'maxStateRepeatDiff',longMaxStateRepeatDiff, ...
    'maxCovarianceRepeatDiff',longMaxCovRepeatDiff, ...
    'finalVy',vA(end),'finalP',pA(end));
report.multiStep = struct('steps',N,'maxError',err22, ...
    'actual',[v22Actual;p22Actual],'expected',[vExpected;pExpected]);
report.parameterPolicy = struct('Ts_test_only',Ts,'Vy_F0_test_only',Vy_F0, ...
    'P0_F_test_only',P0_F,'Q_F_test_only',Q_F, ...
    'tuned',false,'frozenForRuntime',false);
report.validationPolicy = ['Runtime assertions in the stateless core; ', ...
    'only active branch values require finite/variance checks; ', ...
    'no clipping or silent correction.'];
report.feedbackInputsAlreadyDelayed = true;
report.delayImplemented = false;
report.wrapperImplemented = false;
report.simCalled = false;
report.carSimRun = false;
report.simulinkUsed = false;
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.frozenUnchanged = frozenUnchanged;
report.coreSHA256 = upper(file_sha256(coreFile));
report.testScriptSHA256 = upper(file_sha256(testFile));

save(resultFile,'report','-v7');
fprintf('V2_4B_UNIT_TESTS|passed=%d/%d|all=%d|stateless=%d|frozen=%d\n', ...
    report.gatesTrue,report.gateCount,report.allPassed, ...
    report.coreStateless,report.frozenUnchanged);
fprintf('V2_4B_SIGN|prop=%.17g|delta=%.17g\n', ...
    report.signRegression.propTerm,report.signRegression.deltaVy);
fprintf('V2_4B_LONG|N=%d|finite=%d|nonnegative=%d|repeat=%d|maxDiff=%.17g\n', ...
    report.longRun.steps,report.longRun.finite, ...
    report.longRun.covarianceNonnegative,report.longRun.deterministic, ...
    max(report.longRun.maxStateRepeatDiff,report.longRun.maxCovarianceRepeatDiff));
fprintf('V2_4B_HASH|core=%s|test=%s\n',report.coreSHA256,report.testScriptSHA256);
assert(report.allPassed,'V2.4-B unit-test gate failed.');
end

function [vy,p,d] = step(vyPrev,pPrev,ay,r,vx,vyFb,pFb,fbValid,reset,Ts,vy0,p0,q)
[vy,p,d] = vy_feedback_propagation_step(vyPrev,pPrev,ay,r,vx, ...
    vyFb,pFb,fbValid,reset,Ts,vy0,p0,q);
end

function c = case_result(name,passed,expected,actual,maxError,message)
c = struct('name',name,'passed',logical(passed),'expected',expected, ...
    'actual',actual,'maxError',double(maxError),'message',message);
end

function c = rejection_case(name,fn)
[passed,message] = rejects(fn);
c = case_result(name,passed,'explicit error',message,0,message);
end

function [passed,message] = rejects(fn)
passed = false; message = '';
try
    fn();
catch ME
    passed = true;
    message = sprintf('%s|%s',ME.identifier,ME.message);
end
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
