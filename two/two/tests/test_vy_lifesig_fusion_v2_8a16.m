function report = test_vy_lifesig_fusion_v2_8a16()
%TEST_VY_LIFESIG_FUSION_V2_8A16 Offline core/wrapper regression only.

root = fileparts(fileparts(mfilename('fullpath')));
implDir = fullfile(root,'matlab');
modelDir = fullfile(root,'model');
outDir = fullfile(root,'results', ...
    'vy_lifesig_v2_8a16_k_health_integration');
if ~exist(outDir,'dir'), mkdir(outDir); end
addpath(implDir,modelDir);

coreFile = fullfile(implDir,'vy_lifesig_fusion_v2_8_step.m');
wrapperFile = fullfile(implDir,'vy_lifesig_fusion_v2_8_simulink_sfun.m');
testFile = [mfilename('fullpath') '.m'];
referenceFile = fullfile(root,'results', ...
    'vy_lifesig_v2_8a14_k_health_ablation','timeseries.csv');
sampleFile = fullfile(outDir,'samplewise_comparison.csv');
summaryFile = fullfile(outDir,'regression_summary.csv');
matFile = fullfile(outDir,'regression_evidence.mat');

v27Files = {
    fullfile(modelDir,'vy_lifesig_fusion_step.m')
    fullfile(modelDir,'vy_lifesig_fusion_simulink_sfun.m')
    fullfile(modelDir,'vx_vy_lifesig_fusion_v2_7.slx')};
v27Expected = {
    '3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA'
    'E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445'
    '65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0'};
v27Before = hash_files(v27Files);
assert(isequal(v27Before,v27Expected), ...
    'A16:FrozenV27Mismatch','Frozen V2.7 lineage mismatch before test.');

tol = 1e-12;
cases = repmat(case_result('',false,''),8,1);

% T1: independently replay all A15/A14 low-yaw samples through V2.8 core.
T = readtable(referenceFile,'VariableNamingRule','preserve');
N = height(T);
qD = 0.8426184093257221;
qF = 0.010941893227585452;
tauF = 28.252990189369939;
Ts = 0.01;

hf = (T.alphaF_C ./ T.alphaD_C) * (qD/qF);
hf = min(max(hf,realmin('double')),1);
ageSteps = -log(hf) * tauF / Ts;

actualVy = zeros(N,1); actualAD = zeros(N,1); actualAK = zeros(N,1);
actualAF = zeros(N,1); actualI = zeros(N,1); actualG = zeros(N,1);
actualHD = zeros(N,1); actualHK = zeros(N,1); actualHF = zeros(N,1);
actualValid = zeros(N,1); actualFallback = zeros(N,1);
lastValue = 0; hasLast = 0; stateI = 0;
for k=1:N
    reset = double(k==1);
    [actualVy(k),actualAD(k),actualAK(k),actualAF(k), ...
        actualValid(k),actualFallback(k),lastValue,hasLast,stateI, ...
        actualHD(k),actualHK(k),actualHF(k),actualG(k)] = ...
        vy_lifesig_fusion_v2_8_step( ...
        T.Vy_D_mps(k),1,T.Vy_K_mps(k),1,T.Vy_F_mps(k), ...
        ageSteps(k),1,reset,lastValue,hasLast,stateI);
    actualI(k) = stateI;
end

diffVy = actualVy - T.Vy_C_mps;
diffI = actualI - T.I_K_C_m;
diffG = actualG - T.G_K_C;
diffAD = actualAD - T.alphaD_C;
diffAK = actualAK - T.alphaK_C;
diffAF = actualAF - T.alphaF_C;
maxReplay = max(abs([diffVy;diffI;diffG;diffAD;diffAK;diffAF]));
ok = N==1731 && maxReplay<=tol && all(actualValid==1) && ...
    all(actualFallback==0);
cases(1) = case_result('T1 A15 samplewise replay',ok,sprintf( ...
    'N=%d maxDiff=%.17g valid=%d fallback=%d',N,maxReplay, ...
    sum(actualValid),sum(actualFallback)));

samplewise = table(T.time_s,T.Vy_C_mps,actualVy,diffVy, ...
    T.I_K_C_m,actualI,diffI,T.G_K_C,actualG,diffG, ...
    T.alphaD_C,actualAD,diffAD,T.alphaK_C,actualAK,diffAK, ...
    T.alphaF_C,actualAF,diffAF, ...
    'VariableNames',{'time_s','Vy_LS_reference','Vy_LS_implementation', ...
    'Vy_LS_difference','I_K_reference','I_K_implementation','I_K_difference', ...
    'G_K_reference','G_K_implementation','G_K_difference', ...
    'alphaD_reference','alphaD_implementation','alphaD_difference', ...
    'alphaK_reference','alphaK_implementation','alphaK_difference', ...
    'alphaF_reference','alphaF_implementation','alphaF_difference'});
writetable(samplewise,sampleFile);

% T2: I=0 and sub-threshold disagreement reproduces frozen V2.7 behavior.
old = cell(1,11); fresh = cell(1,13);
[old{:}] = vy_lifesig_fusion_step(1,1,1.1,1,2,100,1,0,3,1);
[fresh{:}] = vy_lifesig_fusion_v2_8_step( ...
    1,1,1.1,1,2,100,1,0,3,1,0);
oldComparable = [old{1:8} old{9:11}];
newComparable = [fresh{1:8} fresh{10:12}];
ok = isequaln(oldComparable,newComparable) && fresh{9}==0 && fresh{13}==1;
cases(2) = case_result('T2 zero-state V2.7 exact equivalence',ok,sprintf( ...
    'mainEqual=%d I=%.17g G=%.17g', ...
    isequaln(oldComparable,newComparable),fresh{9},fresh{13}));

% T3: exact frozen recurrence and gate for a supra-threshold sample.
d0 = 0.3467656927489074; rho = 0.995; lambda = 10;
priorI = 0.25; d = 0.8;
[~,~,~,~,~,~,~,~,nextI,~,hK,~,gK] = ...
    vy_lifesig_fusion_v2_8_step(0,1,d,1,0,0,0,0,0,0,priorI);
expectedI = rho*priorI + Ts*max(0,d-d0);
expectedG = exp(-lambda*expectedI);
ok = abs(nextI-expectedI)<=tol && abs(gK-expectedG)<=tol && ...
    abs(hK-expectedG)<=tol;
cases(3) = case_result('T3 frozen K-health recurrence',ok,sprintf( ...
    'I=%.17g expected=%.17g G=%.17g',nextI,expectedI,gK));

% T4: reset clears K history before evaluating the current hit.
[~,~,~,~,~,~,~,~,resetI,~,~,~,resetG] = ...
    vy_lifesig_fusion_v2_8_step(0,1,0,1,0,0,0,1,9,1,5);
ok = resetI==0 && resetG==1;
cases(4) = case_result('T4 reset clears K-health state',ok,sprintf( ...
    'I=%.17g G=%.17g',resetI,resetG));

% T5: nonfinite K follows existing exclusion semantics and cannot poison I.
[y,aD,aK,aF,v,fb,~,~,nonfiniteI,hD,hK,hF,gK] = ...
    vy_lifesig_fusion_v2_8_step(2,1,NaN,1,4,0,1,0,0,0,0.4);
ok = isfinite(y) && aD>0 && aK==0 && aF>0 && v==1 && fb==0 && ...
    nonfiniteI==0.4 && hD==1 && hK==0 && hF==1 && isfinite(gK);
cases(5) = case_result('T5 nonfinite K safety and state preservation',ok, ...
    sprintf('y=%.17g alpha=%s I=%.17g H=%s G=%.17g',y, ...
    mat2str([aD aK aF],17),nonfiniteI,mat2str([hD hK hF],17),gK));

% T6: all-invalid fallback and last-valid memory remain V2.7-compatible.
[y,aD,aK,aF,v,fb,last,has,nextI] = ...
    vy_lifesig_fusion_v2_8_step(NaN,0,NaN,0,NaN,NaN,0,0,7,1,0.3);
ok = y==7 && isequal([aD aK aF],[0 0 0]) && v==0 && fb==1 && ...
    last==7 && has==1 && nextI==0.3;
cases(6) = case_result('T6 fallback compatibility',ok,sprintf( ...
    'y=%.17g valid=%g fallback=%g I=%.17g',y,v,fb,nextI));

% T7: wrapper is a three-DWork boundary and does not duplicate math.
wrapperText = lower(fileread(wrapperFile));
static = contains(wrapperText,'block.numinputports = 8;') && ...
    contains(wrapperText,'block.numoutputports = 11;') && ...
    contains(wrapperText,'block.numdworks = 3;') && ...
    contains(wrapperText,"block.dwork(3).name = 'i_k';") && ...
    contains(wrapperText,'vy_lifesig_fusion_v2_8_step(') && ...
    contains(wrapperText,'block.sampletimes = [0.01 0];') && ...
    isempty(regexp(wrapperText, ...
    '0\.842618409|0\.146439697|0\.010941893|28\.252990|0\.346765692|0\.995|\<exp\s*\(', ...
    'once'));
cases(7) = case_result('T7 wrapper state/delegation static contract',static, ...
    sprintf('static=%d',static));

% T8: frozen V2.7 core/wrapper/model are unchanged.
v27After = hash_files(v27Files);
frozenUnchanged = isequal(v27Before,v27After) && isequal(v27After,v27Expected);
cases(8) = case_result('T8 frozen V2.7 lineage unchanged',frozenUnchanged, ...
    sprintf('unchanged=%d',frozenUnchanged));

allPassed = all([cases.passed]);
summary = table(string({cases.name}).',logical([cases.passed]).', ...
    string({cases.details}).','VariableNames',{'gate','passed','details'});
writetable(summary,summaryFile);

report = struct();
report.stage = 'V2.8-A16';
report.verdict = ternary(allPassed,'IMPLEMENTATION_REGRESSION_PASS', ...
    'IMPLEMENTATION_REGRESSION_FAIL');
report.gateCount = numel(cases);
report.gatesPassed = sum([cases.passed]);
report.allPassed = allPassed;
report.referenceSampleCount = N;
report.referenceWindow = [T.time_s(1) T.time_s(end)];
report.maxReplayDifference = maxReplay;
report.maxVyDifference = max(abs(diffVy));
report.maxIDifference = max(abs(diffI));
report.maxGDifference = max(abs(diffG));
report.maxAlphaDifference = max(abs([diffAD;diffAK;diffAF]));
report.coreSHA256 = file_sha256(coreFile);
report.wrapperSHA256 = file_sha256(wrapperFile);
report.testSHA256 = file_sha256(testFile);
report.referenceSHA256 = file_sha256(referenceFile);
report.frozenV27Before = v27Before;
report.frozenV27After = v27After;
report.frozenV27Unchanged = frozenUnchanged;
report.matlabUsed = true;
report.simulinkUsed = false;
report.simCalled = false;
report.carSimRun = false;
report.formalTargetCreated = false;
report.readyForSingleRuntimeRecoveryValidation = false;
report.nextRequiredGate = ...
    'INDEPENDENT_V2_8_TARGET_BINDING_AND_COMPILE_PREFLIGHT';
save(matFile,'report','-v7');

fprintf('A16_REGRESSION|passed=%d/%d|all=%d|maxDiff=%.17g\n', ...
    report.gatesPassed,report.gateCount,report.allPassed,maxReplay);
fprintf('A16_HASH|core=%s|wrapper=%s|test=%s\n', ...
    report.coreSHA256,report.wrapperSHA256,report.testSHA256);
fprintf('A16_RUNTIME|simulink=0|sim=0|carsim=0\n');
assert(allPassed,'A16:RegressionFailed', ...
    'V2.8-A16 implementation regression failed.');
end

function result = case_result(name,passed,details)
result = struct('name',name,'passed',logical(passed),'details',details);
end

function hashes = hash_files(files)
hashes = cell(size(files));
for k=1:numel(files), hashes{k}=file_sha256(files{k}); end
end

function hash = file_sha256(path)
d = java.security.MessageDigest.getInstance('SHA-256');
s = java.io.FileInputStream(java.io.File(path));
ds = java.security.DigestInputStream(s,d);
cleanup = onCleanup(@()ds.close());
while ds.read()~=-1, end
bytes = typecast(d.digest(),'uint8');
hash = upper(reshape(dec2hex(bytes,2).',1,[]));
clear cleanup
end

function value = ternary(condition,yes,no)
if condition, value=yes; else, value=no; end
end
