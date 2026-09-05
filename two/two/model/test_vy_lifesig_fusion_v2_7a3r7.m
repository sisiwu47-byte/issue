function report = test_vy_lifesig_fusion_v2_7a3r7()
%TEST_VY_LIFESIG_FUSION_V2_7A3R7 Pure MATLAB core unit tests.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
coreFile = fullfile(projectRoot,'model','vy_lifesig_fusion_step.m');
testFile = [mfilename('fullpath') '.m'];
resultFile = fullfile(projectRoot,'results', ...
    'vy_reliability_lifesig_v2_7a3r7_unit_tests.mat');

[frozenFiles,frozenExpected] = frozen_manifest(projectRoot);
frozenBefore = hash_records(frozenFiles);
assert(hashes_match(frozenBefore,frozenExpected), ...
    'A3R7:FrozenDependencyMismatch', ...
    'Frozen dependency mismatch before A3R7 tests.');

q = [0.8426184093257221; 0.14643969744669255; ...
    0.010941893227585452];
tauF = 28.252990189369939;
Ts = 0.01;
tol = 1e-12;
cases = repmat(case_result('',false,''),24,1);

% T1: all tracks available.
[y,aD,aK,aF,v,fb,last,has] = step(1,1,2,1,3,0,1,0,0,0);
expectedAlpha = q/sum(q);
expectedY = expectedAlpha.'*[1;2;3];
ok = max(abs([aD;aK;aF]-expectedAlpha)) <= tol && ...
    abs(y-expectedY) <= tol && v==1 && fb==0 && ...
    abs(last-y)<=tol && has==1;
cases(1) = case_result('T1 all tracks valid exact formula',ok, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));

% T2-T4: one-track identity.
[y,aD,aK,aF,v,fb] = step(4,1,NaN,0,NaN,NaN,0,0,0,0);
cases(2) = case_result('T2 D-only identity', ...
    y==4 && isequal([aD aK aF],[1 0 0]) && v==1 && fb==0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));
[y,aD,aK,aF,v,fb] = step(NaN,0,-5,1,NaN,NaN,0,0,0,0);
cases(3) = case_result('T3 K-only identity', ...
    y==-5 && isequal([aD aK aF],[0 1 0]) && v==1 && fb==0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));
[y,aD,aK,aF,v,fb] = step(NaN,0,NaN,0,6,0,1,0,0,0);
cases(4) = case_result('T4 F-only identity', ...
    y==6 && isequal([aD aK aF],[0 0 1]) && v==1 && fb==0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));

% T5: exact F age-health behavior at reset age, first increment, and later.
ages = [0 1 1000];
actualAF = zeros(size(ages));
expectedAF = zeros(size(ages));
for k=1:numel(ages)
    [~,~,~,actualAF(k)] = step(1,1,2,1,3,ages(k),1,0,0,0);
    scoreF = q(3)*exp(-(ages(k)*Ts)/tauF);
    expectedAF(k) = scoreF/(q(1)+q(2)+scoreF);
end
ok = max(abs(actualAF-expectedAF))<=tol && ...
    actualAF(1)>actualAF(2) && actualAF(2)>actualAF(3);
cases(5) = case_result('T5 F age exponential decay',ok, ...
    sprintf('actual=%s expected=%s',mat2str(actualAF,17), ...
    mat2str(expectedAF,17)));

% T6-T9: inactive terms are literal zero and cannot pollute output.
[y,aD,aK,aF] = step(NaN,0,2,1,3,0,1,0,0,0);
cases(6) = case_result('T6 inactive D NaN protection', ...
    isfinite(y) && aD==0 && aK>0 && aF>0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));
[y,aD,aK,aF] = step(1,1,NaN,0,3,0,1,0,0,0);
cases(7) = case_result('T7 inactive K NaN protection', ...
    isfinite(y) && aD>0 && aK==0 && aF>0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));
[y,aD,aK,aF] = step(1,1,2,1,NaN,0,1,0,0,0);
cases(8) = case_result('T8 inactive F NaN protection', ...
    isfinite(y) && aD>0 && aK>0 && aF==0, ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));
[y,aD,aK,aF] = step(9,1,2,0,3,NaN,1,0,0,0);
cases(9) = case_result('T9 invalid F age protection', ...
    y==9 && isequal([aD aK aF],[1 0 0]), ...
    sprintf('y=%.17g alpha=%s',y,mat2str([aD aK aF],17)));

% T10: no-history fallback.
[y,aD,aK,aF,v,fb,last,has] = step(NaN,0,NaN,0,NaN,NaN,0,0,0,0);
ok = y==0 && isequal([aD aK aF],[0 0 0]) && v==0 && fb==1 && ...
    last==0 && has==0;
cases(10) = case_result('T10 all invalid no-history fallback',ok, ...
    sprintf('y=%.17g valid=%g fallback=%g last=%.17g has=%g', ...
    y,v,fb,last,has));

% T11-T12: hold-last fallback and repeated-fallback memory stability.
[y0,~,~,~,~,~,last0,has0] = step(7,1,0,0,0,0,0,0,0,0);
[y1,aD,aK,aF,v,fb,last1,has1] = ...
    step(NaN,0,NaN,0,NaN,NaN,0,0,last0,has0);
ok = abs(y0-7)<=tol && abs(y1-y0)<=tol && ...
    isequal([aD aK aF],[0 0 0]) && ...
    v==0 && fb==1 && abs(last1-y0)<=tol && has1==1;
cases(11) = case_result('T11 hold-last fallback',ok, ...
    sprintf('initial=%.17g held=%.17g last=%.17g',y0,y1,last1));
[y2,~,~,~,v2,fb2,last2,has2] = ...
    step(NaN,0,NaN,0,NaN,NaN,0,0,last1,has1);
cases(12) = case_result('T12 repeated fallback leaves memory unchanged', ...
    abs(y2-y1)<=tol && v2==0 && fb2==1 && ...
    last2==last1 && has2==has1, ...
    sprintf('held=%.17g last=%.17g has=%g',y2,last2,has2));

% T13-T14: reset clears stale history before evaluating the current hit.
[y,aD,aK,aF,v,fb,last,has] = ...
    step(NaN,0,NaN,0,NaN,NaN,0,1,77,1);
ok = y==0 && isequal([aD aK aF],[0 0 0]) && v==0 && fb==1 && ...
    last==0 && has==0;
cases(13) = case_result('T13 reset invalid-current clears history',ok, ...
    sprintf('y=%.17g last=%.17g has=%g',y,last,has));
[y,aD,aK,aF,v,fb,last,has] = step(8,1,NaN,0,NaN,0,0,1,77,1);
ok = y==8 && isequal([aD aK aF],[1 0 0]) && v==1 && fb==0 && ...
    last==8 && has==1;
cases(14) = case_result('T14 reset valid-current re-establishes history',ok, ...
    sprintf('y=%.17g last=%.17g has=%g',y,last,has));

% T15: normal-path invariants over deterministic randomized inputs.
rng(270307,'twister');
normalCount = 0;
maxSumError = 0;
minAlpha = Inf;
allFinite = true;
for k=1:1000
    states = 20*randn(3,1);
    flags = rand(3,1)>0.35;
    age = randi([0 3000]);
    [y,aD,aK,aF,v,fb] = step(states(1),flags(1),states(2),flags(2), ...
        states(3),age,flags(3),0,0,0);
    if v==1
        normalCount = normalCount + 1;
        alpha = [aD;aK;aF];
        maxSumError = max(maxSumError,abs(sum(alpha)-1));
        minAlpha = min(minAlpha,min(alpha));
        allFinite = allFinite && isfinite(y) && all(isfinite(alpha)) && fb==0;
    else
        allFinite = allFinite && y==0 && fb==1;
    end
end
ok = normalCount>0 && minAlpha>=0 && maxSumError<=tol && allFinite;
cases(15) = case_result('T15 randomized weight invariants',ok, ...
    sprintf('Nnormal=%d minAlpha=%.17g maxSumError=%.17g finite=%d', ...
    normalCount,minAlpha,maxSumError,allFinite));

% T16-T17: type/shape and memory-update rules.
out = cell(1,8);
[out{:}] = step(single(1),true,single(2),true,single(3),single(1), ...
    true,false,single(0),false);
isScalarDouble = all(cellfun(@(x)isscalar(x)&&isa(x,'double'),out));
cases(16) = case_result('T16 scalar-double output contract',isScalarDouble, ...
    strjoin(cellfun(@class,out,'UniformOutput',false),','));
[~,~,~,~,~,~,lastA,hasA] = step(3,1,0,0,0,0,0,0,0,0);
[~,~,~,~,~,~,lastB,hasB] = step(NaN,0,NaN,0,NaN,NaN,0,0,lastA,hasA);
cases(17) = case_result('T17 last-valid updates only on normal path', ...
    lastA==3 && hasA==1 && lastB==lastA && hasB==hasA, ...
    sprintf('normalLast=%.17g fallbackLast=%.17g',lastA,lastB));

% T18-T20: source-level frozen-boundary checks.
coreText = lower(fileread(coreFile));
noPersistent = isempty(regexp(coreText,'\<persistent\>|\<global\>','once'));
cases(18) = case_result('T18 pure core has no persistent/global state', ...
    noPersistent,sprintf('noPersistent=%d',noPersistent));
noArbitraryFloor = isempty(regexp(coreText,'\<epsilon\>|\<eps\s*\(','once'));
cases(19) = case_result('T19 no arbitrary normalization floor', ...
    noArbitraryFloor,sprintf('noFloor=%d',noArbitraryFloor));
forbiddenPattern = '\<nis\>|abs_r|disagreement|covariance|vy_true';
formalIsolation = isempty(regexp(coreText,forbiddenPattern,'once')) && ...
    nargin('vy_lifesig_fusion_step')==10 && ...
    nargout('vy_lifesig_fusion_step')==11;
cases(20) = case_result('T20 formal-input isolation and fixed signature', ...
    formalIsolation,sprintf('isolated=%d nargin=%d nargout=%d', ...
    formalIsolation,nargin('vy_lifesig_fusion_step'), ...
    nargout('vy_lifesig_fusion_step')));

% T21-T23: health outputs are the exact values used by the score path.
[~,~,~,~,~,~,~,~,hD,hK,hF] = step(1,1,2,1,3,0,1,0,0,0);
cases(21) = case_result('T21 all-valid health outputs', ...
    isequal([hD hK hF],[1 1 1]), ...
    sprintf('H=%s',mat2str([hD hK hF],17)));
[~,~,~,~,~,~,~,~,hD,hK,hF] = step(NaN,1,2,0,3,-1,1,0,0,0);
cases(22) = case_result('T22 invalid health semantics', ...
    isequal([hD hK hF],[0 0 0]), ...
    sprintf('H=%s',mat2str([hD hK hF],17)));
ageCheck = 123;
[~,~,~,~,~,~,~,~,hD,hK,hF] = step(1,0,2,0,3,ageCheck,1,0,0,0);
expectedHF = exp(-(ageCheck*Ts)/tauF);
cases(23) = case_result('T23 exact F health value', ...
    hD==0 && hK==0 && abs(hF-expectedHF)<=tol, ...
    sprintf('H=%s expectedHF=%.17g',mat2str([hD hK hF],17),expectedHF));

% T24: all original eight outputs remain bitwise-equivalent to A3R7.
rng(270308,'twister');
legacyEquivalent = true;
firstMismatch = 0;
for k=1:1000
    states = 20*randn(3,1);
    if mod(k,7)==0, states(1)=NaN; end
    if mod(k,11)==0, states(2)=NaN; end
    if mod(k,13)==0, states(3)=NaN; end
    flags = rand(3,1)>0.35;
    age = randi([-2 3000]);
    if mod(k,17)==0, age=NaN; end
    resetCase = rand()>0.9;
    lastCase = 10*randn();
    hasCase = rand()>0.5;
    newOut = cell(1,8); oldOut = cell(1,8);
    [newOut{:}] = step(states(1),flags(1),states(2),flags(2), ...
        states(3),age,flags(3),resetCase,lastCase,hasCase);
    [oldOut{:}] = legacy_reference(states(1),flags(1),states(2),flags(2), ...
        states(3),age,flags(3),resetCase,lastCase,hasCase);
    if ~isequaln([newOut{:}],[oldOut{:}])
        legacyEquivalent = false;
        firstMismatch = k;
        break
    end
end
cases(24) = case_result('T24 A3R7 main-output regression equivalence', ...
    legacyEquivalent,sprintf('N=1000 firstMismatch=%d',firstMismatch));

frozenAfter = hash_records(frozenFiles);
frozenUnchanged = records_equal(frozenBefore,frozenAfter) && ...
    hashes_match(frozenAfter,frozenExpected);
allPassed = all([cases.passed]) && frozenUnchanged;

report = struct();
report.stage = 'V2.7-A3R7';
report.classification = 'LIFESIG_FUSION_CORE_UNIT_TEST';
report.inputOrder = {'Vy_D';'update_valid_D';'Vy_K';'update_valid_K'; ...
    'Vy_F';'propagation_age_steps';'age_valid_F';'reset'; ...
    'last_valid_Vy_LS';'has_last_valid'};
report.outputOrder = {'Vy_LS';'alpha_D';'alpha_K';'alpha_F'; ...
    'fusion_valid';'fallback_active';'last_valid_Vy_LS_next'; ...
    'has_last_valid_next';'H_D';'H_K';'H_F'};
report.parameters = struct('q_D',q(1),'q_K',q(2),'q_F',q(3), ...
    'tau_F',tauF,'Ts',Ts);
report.testNames = {cases.name}.';
report.passed = [cases.passed].';
report.details = {cases.details}.';
report.gateCount = numel(cases);
report.gatesTrue = sum(report.passed);
report.allPassed = allPassed;
report.frozenBefore = frozenBefore;
report.frozenAfter = frozenAfter;
report.frozenUnchanged = frozenUnchanged;
report.simulinkUsed = false;
report.simCalled = false;
report.carSimRun = false;
report.coreSHA256 = upper(file_sha256(coreFile));
report.testSHA256 = upper(file_sha256(testFile));

save(resultFile,'report','-v7');
fprintf('A3R7_UNIT|passed=%d/%d|all=%d|frozen=%d\n', ...
    report.gatesTrue,report.gateCount,report.allPassed,report.frozenUnchanged);
for k=1:numel(cases)
    if ~cases(k).passed
        fprintf('A3R7_FAIL|%s|%s\n',cases(k).name,cases(k).details);
    end
end
fprintf('A3R7_HASH|core=%s|test=%s\n', ...
    report.coreSHA256,report.testSHA256);
assert(report.allPassed,'A3R7:UnitTestFailed', ...
    'V2.7-A3R7 LifeSig fusion core unit-test gate failed.');
end

function varargout = step(varargin)
[varargout{1:nargout}] = vy_lifesig_fusion_step(varargin{:});
end

function [Vy_LS, alpha_D, alpha_K, alpha_F, fusion_valid, ...
    fallback_active, last_next, has_next] = legacy_reference( ...
    Vy_D, update_valid_D, Vy_K, update_valid_K, Vy_F, ageSteps, ...
    age_valid_F, reset, last_value, has_last)
qD=0.8426184093257221;qK=0.14643969744669255;
qF=0.010941893227585452;tauF=28.252990189369939;Ts=0.01;
if double(reset)~=0,memoryValue=0;memoryValid=false;
else,memoryValue=double(last_value);memoryValid=double(has_last)~=0;end
activeD=double(update_valid_D)~=0&&isfinite(Vy_D);
activeK=double(update_valid_K)~=0&&isfinite(Vy_K);
activeF=double(age_valid_F)~=0&&isfinite(ageSteps)&&ageSteps>=0&&isfinite(Vy_F);
scoreD=0;scoreK=0;scoreF=0;termD=0;termK=0;termF=0;
if activeD,scoreD=qD;termD=scoreD*double(Vy_D);end
if activeK,scoreK=qK;termK=scoreK*double(Vy_K);end
if activeF,healthF=exp(-(double(ageSteps)*Ts)/tauF);scoreF=qF*healthF;termF=scoreF*double(Vy_F);end
S=scoreD+scoreK+scoreF;
if isfinite(S)&&S>0
    alpha_D=scoreD/S;alpha_K=scoreK/S;alpha_F=scoreF/S;
    Vy_LS=(termD+termK+termF)/S;fusion_valid=1;fallback_active=0;
    last_next=Vy_LS;has_next=1;
else
    alpha_D=0;alpha_K=0;alpha_F=0;
    if memoryValid,Vy_LS=memoryValue;else,Vy_LS=0;end
    fusion_valid=0;fallback_active=1;last_next=memoryValue;
    has_next=double(memoryValid);
end
end

function c = case_result(name,passed,details)
c = struct('name',name,'passed',logical(passed),'details',details);
end

function [files,expected] = frozen_manifest(root)
files = {
    fullfile(root,'model','vy_fixed_weight_fusion_step.m')
    fullfile(root,'model','vy_fixed_weight_fusion_simulink_sfun.m')
    fullfile(root,'model','vy_feedback_propagation_step.m')
    fullfile(root,'model','vy_feedback_propagation_simulink_sfun.m')
    fullfile(root,'docs','STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R1_STATIC_QUALITY_PRIOR.md')
    fullfile(root,'docs','STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R4_MINIMAL_HEALTH_GATE_REVISION.md')
    fullfile(root,'docs','STAGE_VY_RELIABILITY_LIFESIG_V2_7A3R6_NUMERICAL_IMPLEMENTATION_CONTRACT.md')};
expected = {
    '4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C'
    'B7185A2E26B2874D792266D6CBAEC26A8DED6FDFBDFC862ACC394DE01F94F30A'
    '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'
    'AA3E9E79D81D1C3D8155D4FF04ED952357B0294E09DF868FEBC7E05753E64FD8'
    'EF6E0278EF0CD2F6EB2F41C480B295FFB23AC22905392F2A6B0FCDEC7E6C581E'
    '3F3B1233F5974ECDAC5048767D4EBBDB5B8D69C431293C7CC032106E76FB8EFB'
    '6EF8134E162B61F3E4DB494DEEFDC6D3465DB7EC9CB025095D44C423BAAE90CF'};
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
