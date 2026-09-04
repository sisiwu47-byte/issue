function tests = test_vx_v1_current_contract
%TEST_VX_V1_CURRENT_CONTRACT Static/current-interface gate for VX-V1.
% This replacement gate intentionally does not consume historical A-H MAT
% files and does not load or simulate model/vx.slx.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.projectRoot = projectRoot;
testCase.TestData.estimatorFile = fullfile(projectRoot, 'model', ...
    'longitudinal_velocity_estimator.m');
testCase.TestData.parameterFile = fullfile(projectRoot, 'model', ...
    'estimator_default_params.m');
testCase.TestData.wrapperFile = fullfile(projectRoot, 'model', ...
    'longitudinal_velocity_estimator_simulink.m');
testCase.TestData.estimatorText = fileread(testCase.TestData.estimatorFile);
addpath(fullfile(projectRoot, 'model'));
end

function testCurrentFilesAndHashes(testCase)
verifyTrue(testCase, isfile(testCase.TestData.estimatorFile));
verifyTrue(testCase, isfile(testCase.TestData.parameterFile));
verifyTrue(testCase, isfile(testCase.TestData.wrapperFile));
verifyEqual(testCase, vx_sha256(testCase.TestData.estimatorFile), ...
    '68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107');
verifyEqual(testCase, vx_sha256(testCase.TestData.parameterFile), ...
    '09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4');
verifyEqual(testCase, vx_sha256(testCase.TestData.wrapperFile), ...
    '93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061');
end

function testEffectiveFrozenParameters(testCase)
p = estimator_default_params();
verifyEqual(testCase, p.Ts_est, 0.01, 'AbsTol', eps);
verifyEqual(testCase, p.Twindow, 0.5, 'AbsTol', eps);
verifyEqual(testCase, p.Rw, 0.393, 'AbsTol', eps);
verifyEqual(testCase, p.QW, 1.0e-4, 'AbsTol', eps);
verifyEqual(testCase, p.QI, 2.0e-3, 'AbsTol', eps);
verifyEqual(testCase, p.R_Ax, 1.248708981650e-3, 'RelTol', 1e-14);
verifyEqual(testCase, p.rho_hard, 0.05, 'AbsTol', eps);
verifyEqual(testCase, p.Nrecover, 30);
end

function testHardCodedCurrentParameters(testCase)
txt = testCase.TestData.estimatorText;
verifyNotEmpty(testCase, regexp(txt, 'updateEvery\s*=\s*10\s*;', 'once'));
verifyNotEmpty(testCase, regexp(txt, 'kA_fuse\s*=\s*30\.0\s*;', 'once'));
verifyNotEmpty(testCase, regexp(txt, 'kH_fuse\s*=\s*18\.0\s*;', 'once'));
end

function testActualOutputAssignments(testCase)
txt = testCase.TestData.estimatorText;
requiredPatterns = { ...
    'yHold\(1\)\s*=.*?vx_hat', ...
    'yHold\(3\)\s*=.*?xW', ...
    'yHold\(5\)\s*=.*?xI', ...
    'yHold\(7\)\s*=.*?vxWssTrack', ...
    'yHold\(24:27\)\s*=.*?validWheel', ...
    'yHold\(30\)\s*=.*?alphaW', ...
    'yHold\(31\)\s*=.*?alphaI', ...
    'yHold\(32\)\s*=.*?RwssEquivalent', ...
    'yHold\(34\)\s*=.*?KW', ...
    'yHold\(37\)\s*=.*?p\.QW', ...
    'yHold\(38\)\s*=.*?updateCounter'};
for k = 1:numel(requiredPatterns)
    verifyNotEmpty(testCase, regexp(txt, requiredPatterns{k}, 'once', ...
        'dotall'));
end
verifyNotEmpty(testCase, regexp(txt, 'est_y\s*=\s*yHold\s*;', 'once'));
end

function testWrapperContract(testCase)
txt = fileread(testCase.TestData.wrapperFile);
verifyNotEmpty(testCase, regexp(txt, 'numel\(u\)\s*~=\s*18', 'once'));
verifyNotEmpty(testCase, regexp(txt, 'numel\(yRaw\)\s*~=\s*38', 'once'));
verifyNotEmpty(testCase, regexp(txt, ...
    'longitudinal_velocity_estimator\s*\(\s*u\s*\)', 'once'));
end

function hex = vx_sha256(filePath)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(filePath, 'rb');
assert(fid >= 0, 'Cannot open %s.', filePath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while ~feof(fid)
    md.update(fread(fid, 1024 * 1024, '*uint8'));
end
hex = upper(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2).', 1, []));
end
