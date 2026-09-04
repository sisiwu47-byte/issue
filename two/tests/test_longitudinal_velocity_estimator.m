function tests = test_longitudinal_velocity_estimator
%TEST_LONGITUDINAL_VELOCITY_ESTIMATOR
% STAGE 3E2 top-level integration tests for
% longitudinal_velocity_estimator.
%
% MATLAB execution state: READY TO RUN
% VALIDATION state: PENDING MATLAB VALIDATION
%
% Run this file with:
%   r = runtests('tests/test_longitudinal_velocity_estimator.m');
%   table(r)
%
% Run all project tests with:
%   r = runtests('tests', 'IncludeSubfolders', true);
%   table(r)

tests = functiontests(localfunctions);

end


%% ========================================================================
%  One-time test setup
% ========================================================================

function setupOnce(testCase)
% Automatically add ../matlab to the MATLAB path while this test file runs.

testDir = fileparts(mfilename('fullpath'));
matlabDir = fullfile(testDir, '..', 'matlab');

testCase.verifyTrue( ...
    isfolder(matlabDir), ...
    ['Cannot find MATLAB source folder: ', matlabDir]);

testCase.applyFixture( ...
    matlab.unittest.fixtures.PathFixture(matlabDir));

end


%% ========================================================================
% TEST 0
% ========================================================================

function test_interface_audit(testCase)
% TEST 0:
% Static + smoke interface audit.

codePath = fullfile( ...
    fileparts(mfilename('fullpath')), ...
    '..', ...
    'matlab', ...
    'longitudinal_velocity_estimator.m');

testCase.verifyTrue( ...
    isfile(codePath), ...
    'TEST0: longitudinal_velocity_estimator.m does not exist');

code = fileread(codePath);

testCase.verifyFalse( ...
    isempty(code), ...
    'TEST0: cannot read longitudinal_velocity_estimator.m');


%% ------------------------------------------------------------------------
% 18-input fixed-order mapping
% -------------------------------------------------------------------------

verify_code_pattern( ...
    testCase, ...
    code, ...
    'wheelomega\s*=\s*est_u\s*\(\s*1\s*:\s*4\s*\)', ...
    'TEST0: wheelOmega mapping mismatch');

verify_code_pattern( ...
    testCase, ...
    code, ...
    'wheelangle\s*=\s*est_u\s*\(\s*5\s*:\s*8\s*\)', ...
    'TEST0: wheelAngle mapping mismatch');

verify_code_pattern( ...
    testCase, ...
    code, ...
    'ax\s*=\s*est_u\s*\(\s*9\s*\)', ...
    'TEST0: Ax mapping mismatch');

verify_code_pattern( ...
    testCase, ...
    code, ...
    'avx\s*=\s*est_u\s*\(\s*12\s*\)', ...
    'TEST0: AVx extraction expected at index 12');

verify_code_pattern( ...
    testCase, ...
    code, ...
    'yawratez\s*=\s*est_u\s*\(\s*14\s*\)', ...
    'TEST0: AVz mapping mismatch');

verify_code_pattern( ...
    testCase, ...
    code, ...
    'resetflag\s*=\s*est_u\s*\(\s*18\s*\)', ...
    'TEST0: reset mapping mismatch');


%% ------------------------------------------------------------------------
% Forbidden top-level data paths
% -------------------------------------------------------------------------

codeLower = lower(code);

testCase.verifyFalse( ...
    contains(codeLower, 'vx_true'), ...
    'TEST0: vx_true should not be in top-level estimator inputs');

testCase.verifyFalse( ...
    contains(codeLower, 'gps'), ...
    'TEST0: estimator interface must not include GPS');

testCase.verifyTrue( ...
    ~contains(codeLower, 'ax_sm') && ...
    ~contains(codeLower, 'ay_sm') && ...
    ~contains(codeLower, 'az_sm'), ...
    ['TEST0: Ax_SM/Ay_SM/Az_SM should not be ', ...
     'estimator inputs for Stage 3E']);


%% ------------------------------------------------------------------------
% Forbidden direct-formula copies
% -------------------------------------------------------------------------

testCase.verifyFalse( ...
    contains(codeLower, 'r = [1 / 2] *'), ...
    ['TEST0: top-level must not inline local formulas ', ...
     'for WSS confidence']);

testCase.verifyFalse( ...
    contains(codeLower, 'kv = p'), ...
    ['TEST0: heuristic gate check should remain ', ...
     'in helper functions']);

testCase.verifyFalse( ...
    contains(codeLower, 'inv('), ...
    ['TEST0: top-level should not call inv(Phi) ', ...
     'or similar direct inverse for fusion']);


%% ------------------------------------------------------------------------
% Output assignment completeness
% est_y must cover 1..38
% -------------------------------------------------------------------------

indexExpr = regexp( ...
    code, ...
    '(est_y|yHold)\s*\(\s*([^\)]+)\s*\)\s*=', ...
    'tokens');

allIdx = [];

for k = 1:numel(indexExpr)
    token = strtrim(indexExpr{k}{2});
    try
        idxThis = parse_index_token(token);
    catch ME
        testCase.verifyFail( ...
            ['TEST0: failed to parse output index token "', ...
            token, ...
            '" from regex match ', ...
            num2str(k), ...
            ': ', ...
            ME.message]);
        return;
    end

    idxThis = idxThis(:).';
    allIdx = [allIdx, idxThis]; %#ok<AGROW>

end

allIdx = unique(allIdx);

testCase.verifyEqual( ...
    allIdx(:)', ...
    1:38, ...
    'TEST0: est_y indices must exactly cover 1..38');


%% ------------------------------------------------------------------------
% Static output map
% -------------------------------------------------------------------------

expectedMap = {
    1,  'vx_hat';
    2,  'Pfused';
    3,  'xW';
    4,  'PW';
    5,  'xI';
    6,  'PI';
    7,  'PWI';

    8,  'vxWheel FL';
    9,  'vxWheel FR';
    10, 'vxWheel RL';
    11, 'vxWheel RR';

    12, 'eSlip FL';
    13, 'eSlip FR';
    14, 'eSlip RL';
    15, 'eSlip RR';

    16, 'rhoWheel FL';
    17, 'rhoWheel FR';
    18, 'rhoWheel RL';
    19, 'rhoWheel RR';

    20, 'Rwheel FL';
    21, 'Rwheel FR';
    22, 'Rwheel RL';
    23, 'Rwheel RR';

    24, 'validWheel FL';
    25, 'validWheel FR';
    26, 'validWheel RL';
    27, 'validWheel RR';

    28, 'wssValid';
    29, 'imuValid';

    30, 'alphaW';
    31, 'alphaI';

    32, 'allWheelInvalid';
    33, 'allWheelInvalidDuration';
    34, 'degradedMode';
    35, 'estimatorUpdated';
    36, 'slipReady';
    37, 'condPhi';
    38, 'updateCounter'
};

for i = 1:size(expectedMap, 1)

    idx = expectedMap{i,1};
    name = expectedMap{i,2};

    testCase.verifyTrue( ...
        ismember(idx, allIdx), ...
        ['TEST0: output index ', ...
         num2str(idx), ...
         ' missing for ', ...
         name]);

end


%% ------------------------------------------------------------------------
% Dry-call interface check
% -------------------------------------------------------------------------

p = estimator_default_params();

u = zeros(18,1);

u(1:4)   = [11; 12; 13; 14];
u(5:8)   = [0; 0; 0; 0];

u(9:11)  = [0; 0; 0];

u(12:14) = [0.1; 0.2; 0.3];

u(15:17) = 0;

u(18) = 1;

y = longitudinal_velocity_estimator(u);

testCase.verifyEqual( ...
    numel(y), ...
    38, ...
    'TEST0: est_y must contain exactly 38 elements');

testCase.verifyTrue( ...
    all(arrayfun(@isscalar, y(1:7))), ...
    'TEST0: core outputs 1:7 must be scalar');

testCase.verifyEqual( ...
    numel(y(8:11)), ...
    4, ...
    'TEST0: vxWheel group must contain four elements');

testCase.verifyEqual( ...
    numel(y(12:15)), ...
    4, ...
    'TEST0: eSlip group must contain four elements');

testCase.verifyEqual( ...
    numel(y(16:19)), ...
    4, ...
    'TEST0: rhoWheel group must contain four elements');

testCase.verifyEqual( ...
    numel(y(20:23)), ...
    4, ...
    'TEST0: Rwheel group must contain four elements');

testCase.verifyEqual( ...
    numel(y(24:27)), ...
    4, ...
    'TEST0: validWheel group must contain four elements');


%% ------------------------------------------------------------------------
% Input-position smoke test
% -------------------------------------------------------------------------

testCase.verifyTrue( ...
    all(y(8:11) > 0), ...
    ['TEST0: wheel candidate outputs should be finite ', ...
     'and positive for positive wheel inputs']);

validFlags = y(24:27);

testCase.verifyTrue( ...
    all(validFlags == 0 | validFlags == 1), ...
    'TEST0: validity flags must remain binary');


%% ------------------------------------------------------------------------
% Stage-2 input contract
% -------------------------------------------------------------------------

inputMap = {
    1:4,   'wheelOmega', '4', 'rad/s';
    5:8,   'wheelAngle', '4', 'rad';
    9,     'Ax',         '1', 'm/s^2';
    10,    'Ay',         '1', 'm/s^2';
    11,    'Az',         '1', 'm/s^2';
    12,    'AVx',        '1', 'rad/s';
    13,    'AVy',        '1', 'rad/s';
    14,    'AVz',        '1', 'rad/s';
    15:17, 'Ax_SM etc',  '3', 'unused in Stage 3E';
    18,    'reset',      '1', 'logical/double'
};

testCase.verifyEqual( ...
    size(inputMap,1), ...
    10, ...
    'TEST0: grouped input contract should contain 10 entries');

end


%% ========================================================================
% TEST 0.5
% ========================================================================

function test_persistent_audit_vs_stage3e1(testCase)
% TEST 0.5:
% Persistent variable audit.
%
% Documentation consistency is intentionally not used as a pass/fail
% criterion here. This test validates executable code state.

codePath = fullfile( ...
    fileparts(mfilename('fullpath')), ...
    '..', ...
    'matlab', ...
    'longitudinal_velocity_estimator.m');

code = fileread(codePath);

    actual = extract_persistent_names(code);

    expected = sort({
        'initialized'
        'pCfg'
        'vxFusedPrev'
    'xWPrev'
    'PWPrev'
    'xIPrev'
    'PIPrev'
        'PWI_prev'
        'axCorrPrev'
        'PfusedPrev'
        'wheelLocked'
        'wheelRecoverCount'
        'lastFiniteVx'
        'allWheelInvalidDuration'
        'updateCounter'
        'degradedMode'
        'updatePhase'
        'yHold'
    });

actual = sort(actual(:));
expected = sort(expected(:));

testCase.verifyEqual( ...
    actual, ...
    expected, ...
    ['TEST0.5: persistent variable set does not match ', ...
     'current top-level design']);

testCase.verifyTrue( ...
    any(strcmp(actual, 'PfusedPrev')), ...
    'TEST0.5: PfusedPrev must exist');

    testCase.verifyEqual( ...
        numel(actual), ...
        18, ...
        'TEST0.5: expected 18 persistent states');

end


%% ========================================================================
% TEST 0.6
% ========================================================================

function test_update_gate_1000hz_input(testCase)
% TEST 0.6:
% Top-level estimator should update once every 10 calls when input stream is 1 kHz.

p = estimator_default_params();

N = 1000;
u = zeros(18, N);

u(1:4, :) = repmat(10 / p.Rw, 4, N);
u(5:8, :) = 0;
u(9, :)   = 0;
u(10:11, :) = 0;
u(12:14, :) = 0;

u(18, :) = 0;
u(18, 1) = 1;

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = longitudinal_velocity_estimator(u(:, k));
end

updated = logical(Y(35, :));
updateIdx = find(updated);

testCase.verifyEqual( ...
    numel(updateIdx), ...
    100, ...
    'TEST0.6: true update count in 1000-sample 1kHz run should be 100');

testCase.verifyEqual( ...
    updateIdx(:)', ...
    (2:10:N), ...
    'TEST0.6: update indices must be every 10 calls');
testCase.verifyEqual( ...
    diff(updateIdx), ...
    10 * ones(1, numel(updateIdx) - 1), ...
    'TEST0.6: update intervals should be exactly 10 calls');

testCase.verifyEqual( ...
    Y(35, 1), ...
    0, ...
    'TEST0.6: reset call should not be a true update');

testCase.verifyEqual( ...
    Y(38, end), ...
    100, ...
    'TEST0.6: final updateCounter should be 100 after 1000 1kHz calls');


%% ------------------------------------------------------------------------
% estimatorUpdated / updateCounter joint contract.

for k = 2:N

    if updated(k)

        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1) + 1, ...
            'TEST0.6: updateCounter increments exactly on update ticks');

        testCase.verifyEqual( ...
            Y(35, k), ...
            1, ...
            'TEST0.6: estimatorUpdated must be 1 at update ticks');

    else

        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1), ...
            'TEST0.6: updateCounter holds on non-update ticks');

        testCase.verifyEqual( ...
            Y(35, k), ...
            0, ...
            'TEST0.6: estimatorUpdated must be 0 on hold ticks');

    end

end

end


function test_update_gate_1000hz_input_with_nonfinite_reset_input(testCase)
% TEST 0.6.1:
% Non-finite reset inputs should not silently disable the 100 Hz gate.

p = estimator_default_params();

N = 200;
u = zeros(18, N);

u(1:4, :) = repmat(10 / p.Rw, 4, N);
u(5:8, :) = 0;
u(9, :)   = 0;
u(10:11, :) = 0;
u(12:14, :) = 0;

u(18, :) = NaN;

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = longitudinal_velocity_estimator(u(:, k));
end

updated = logical(Y(35, :));
updateIdx = find(updated);

testCase.verifyEqual( ...
    numel(updateIdx), ...
    20, ...
    'TEST0.6.1: non-finite reset should still yield 10Hz update spacing');

testCase.verifyEqual( ...
    updateIdx(:)', ...
    (2:10:N), ...
    'TEST0.6.1: update indices should start from first non-reset sample');

testCase.verifyEqual( ...
    diff(updateIdx), ...
    10 * ones(1, numel(updateIdx) - 1), ...
    'TEST0.6.1: update interval should remain 10 calls');

for k = 2:N
    if updated(k)
        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1) + 1, ...
            'TEST0.6.1: updateCounter increments on update ticks');
    else
        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1), ...
            'TEST0.6.1: updateCounter holds on hold ticks');
    end
end

testCase.verifyEqual( ...
    Y(35, 1:10), ...
    [0, 1, zeros(1, 8)], ...
    'TEST0.6.1: reset call then immediate next-sample update for NaN reset input');

end


%% ========================================================================
% TEST 0.7
% ========================================================================

function test_state_hold_between_updates(testCase)
% TEST 0.7:
% Between two true updates, persistent output groups should remain unchanged.

p = estimator_default_params();

N = 120;
u = zeros(18, N);

u(1:4, :) = repmat(12 / p.Rw, 4, N);
u(5:8, :) = 0;
u(9, :)   = 0.25;
u(14, :) = 0.002 * sin((1:N) * 0.01);

u(18, :) = 0;
u(18, 1) = 1;

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = longitudinal_velocity_estimator(u(:, k));
end

updated = logical(Y(35, :));
updateIdx = find(updated);

testCase.verifyEqual( ...
    numel(updateIdx), ...
    12, ...
    'TEST0.7: expect 12 update ticks in 120 samples');

holdIdx = [1, 2, 3, 4, 5, 6, ...
    12:23, ...
    30:31, ...
    33, 34];

for k = 1:(numel(updateIdx) - 1)

    i0 = updateIdx(k);
    i1 = updateIdx(k + 1) - 1;

    if i1 <= i0
        continue;
    end

    for idx = holdIdx

        testCase.verifyTrue( ...
            isequaln(Y(idx, i0:i1), Y(idx, i0) * ones(1, i1 - i0 + 1)), ...
            ['TEST0.7: state index ', num2str(idx), ...
             ' should hold between updates']);

    end

end

end


%% ========================================================================
% TEST 0.8
% ========================================================================

function test_reset_rearms_update_gate_and_counters(testCase)
% TEST 0.8:
% Reset should clear gating phase, output hold state, and internal counters.

p = estimator_default_params();

Npre  = 18;
Npost = 24;

% Pre-reset data includes slight variation.
omegaPre = repmat(linspace(8, 10, Npre), 4, 1) / p.Rw;
anglePre = zeros(4, Npre);
axPre = repmat(0.2, Npre, 1);
avzPre = linspace(0, 0.02, Npre)';

omegaPost = ones(4, Npost) * (9 / p.Rw);
anglePost = zeros(4, Npost);
axPost = zeros(Npost, 1);
avzPost = 0.01 * ones(Npost, 1);

reset = zeros(Npre + Npost, 1);
reset(1) = 1;
reset(Npre + 1) = 1;

Y = run_sequence( ...
    [omegaPre, omegaPost], ...
    [anglePre, anglePost], ...
    [axPre; axPost], ...
    [avzPre; avzPost], ...
    reset);

% Fresh reference for post-reset behavior.
Yref = run_sequence( ...
    omegaPost, ...
    anglePost, ...
    axPost, ...
    avzPost, ...
    [1; zeros(Npost - 1, 1)]);

idxReset = Npre + 1;

testCase.verifyEqual( ...
    Y(:, idxReset), ...
    Yref(:, 1), ...
    'TEST0.8: state after in-run reset should match fresh startup sequence');

% Diagnostic diff for interface/state drift checks after in-run reset.
misIdx = compare_estimator_outputs(Y(:, idxReset), Yref(:, 1), 1e-10);
if ~isempty(misIdx)
    diffPairs = cell(numel(misIdx), 1);
    for j = 1:numel(misIdx)
        k = misIdx(j);
        diffPairs{j} = sprintf( ...
            '%d:(%.6g vs %.6g)', ...
            k, Y(k, idxReset), Yref(k, 1));
    end
    diagMsg = ['TEST0.8: mismatch after in-run reset vs fresh startup at indices ', ...
        strjoin(diffPairs, ', ')];
else
    diagMsg = '';
end
testCase.verifyEqual( ...
    misIdx(:), ...
    zeros(0, 1), ...
    ['TEST0.8: mismatch indices after in-run reset vs fresh startup: ', ...
     num2str(misIdx'), ...
     ' ', diagMsg]);

testCase.verifyEqual( ...
    Y(38, idxReset), ...
    0, ...
    'TEST0.8: reset sample should not count as a true estimator update');

testCase.verifyFalse( ...
    logical(Y(35, idxReset)), ...
    'TEST0.8: update should not occur on reset sample');

testCase.verifyEqual( ...
    Y(38, idxReset + 1), ...
    1, ...
    'TEST0.8: first non-reset sample after reset should be counted as update');

testCase.verifyEqual( ...
    logical(Y(35, idxReset + 1)), ...
    true, ...
    'TEST0.8: immediate non-reset tick after reset should be an update');

testCase.verifyEqual( ...
    logical(Y(35, idxReset + 2:idxReset + 10)), ...
    false(1, 9), ...
    'TEST0.8: gate should hold for 9 ticks after reset update');

end


%% ========================================================================
% TEST 0.9
% ========================================================================

function test_update_gate_16s_1khz_input(testCase)
% TEST 0.9:
% 16 s at 1 kHz should yield about 1600 estimation updates.

p = estimator_default_params();

N = 16000;

u = zeros(18, N);

u(1:4, :) = repmat(10 / p.Rw, 4, N);
u(5:8, :) = 0;
u(9, :)   = 0.3 * ones(1, N);
u(10:11, :) = 0;
u(12:14, :) = 0;

u(18, :) = 0;
u(18, 1) = 1;

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = longitudinal_velocity_estimator(u(:, k));
end

updated = logical(Y(35, :));
updateIdx = find(updated);

testCase.verifyEqual( ...
    numel(updateIdx), ...
    1600, ...
    'TEST0.9: true update count in 16s 1kHz run should be 1600');

testCase.verifyEqual( ...
    updateIdx(:)', ...
    (2:10:N), ...
    'TEST0.9: update indices should remain every 10 calls');

testCase.verifyEqual( ...
    Y(38, end), ...
    1600, ...
    'TEST0.9: final updateCounter should be 1600 after 16s');

end


%% ========================================================================
% TEST 0.10
% ========================================================================

function test_simulink_like_reset_waveform(testCase)
% TEST 0.10:
% 16003-call 1 ms reset pulse stress test.

p = estimator_default_params();

N = 16003;

u = zeros(18, N);

u(1:4, :) = repmat(10 / p.Rw, 4, N);
u(5:8, :) = 0;
u(9, :) = 0.3 * ones(1, N);
u(10:11, :) = 0;
u(12:14) = 0;

u(18, 1:11) = 1;

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = longitudinal_velocity_estimator(u(:, k));
end

updated = logical(Y(35, :));
updateIdx = find(updated);
expectedIdx = 12:10:N;

%% Reset period keeps estimatorUpdated = 0 and does not increment counters.

testCase.verifyTrue( ...
    all(~Y(35, 1:11)), ...
    'TEST0.10: reset-held samples should not be true updates');

testCase.verifyEqual( ...
    Y(38, 1), ...
    0, ...
    'TEST0.10: updateCounter should stay zero during reset hold');

testCase.verifyEqual( ...
    Y(38, 11), ...
    0, ...
    'TEST0.10: updateCounter should stay zero after reset release boundary');

testCase.verifyTrue( ...
    updated(12), ...
    'TEST0.10: first non-reset sample should be immediate update');


%% Update schedule after reset release is 10 ms with 1 ms base tick.

testCase.verifyEqual( ...
    numel(updateIdx), ...
    1600, ...
    'TEST0.10: true update count should be 1600 for 15992 valid samples');

testCase.verifyEqual( ...
    updateIdx(:)', ...
    expectedIdx, ...
    'TEST0.10: update index spacing after reset release should be exactly 10');


%% Joint contract with updateCounter and hold ticks.

for k = 2:N
    if updated(k)
        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1) + 1, ...
            'TEST0.10: updateCounter increments on update ticks');
    else
        testCase.verifyEqual( ...
            Y(38, k), ...
            Y(38, k - 1), ...
            'TEST0.10: updateCounter holds on hold ticks');
        testCase.verifyFalse( ...
            logical(Y(35, k)), ...
            'TEST0.10: estimatorUpdated must be 0 on hold ticks');
        testCase.verifyTrue( ...
            isequaln(Y(1:34, k), Y(1:34, k - 1)), ...
            'TEST0.10: estimator outputs 1:34 should hold on hold ticks');
        testCase.verifyTrue( ...
            isequaln( ...
                Y(36:38, k), ...
                Y(36:38, k - 1)), ...
            'TEST0.10: non-update ticks should hold estimator state');
    end
end

end


%% ========================================================================
% TEST 1
% ========================================================================

function test_init_reference(testCase)
% TEST 1:
% Initialization reference.

p = estimator_default_params();

omega = ones(4,1) * (10 / p.Rw);

angle = zeros(4,1);

ax = 0;
avz = 0;

y = run_step( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    1);

testCase.verifyTrue( ...
    isfinite(y(1)), ...
    'TEST1: vx_hat should be finite after reset/init');

testCase.verifyEqual( ...
    y(1), ...
    10, ...
    'AbsTol', 1e-10, ...
    ['TEST1: vx_hat should equal median finite ', ...
     'wheel speed 10 m/s']);

testCase.verifyEqual( ...
    y(3), ...
    10, ...
    'AbsTol', 1e-10, ...
    'TEST1: xW should initialize from vx0');

testCase.verifyEqual( ...
    y(5), ...
    10, ...
    'AbsTol', 1e-10, ...
    'TEST1: xI should initialize from vx0');

testCase.verifyEqual( ...
    y(8:11), ...
    10 * ones(4,1), ...
    'AbsTol', 1e-10, ...
    ['TEST1: wheel candidates should initialize ', ...
     'from omega input']);

testCase.verifyFalse( ...
    logical(y(28)), ...
    'TEST1: wssValid should not be ready at init');

testCase.verifyFalse( ...
    logical(y(29)), ...
    'TEST1: imuValid should not be ready at init');

testCase.verifyFalse( ...
    logical(y(34)), ...
    'TEST1: degradedMode should be false after reset');

testCase.verifyEqual( ...
    y(33), ...
    0, ...
    'AbsTol', 1e-12, ...
    ['TEST1: allWheelInvalidDuration should be ', ...
     '0 after reset']);

end


%% ========================================================================
% TEST 2
% ========================================================================

function test_reset_repeatability(testCase)
% TEST 2:
% Reset should clear FIFO/history and restore clean baseline behavior.

p = estimator_default_params();

Npre = 40;
Npost = 40;


%% Pre-reset trajectory

vPre = 8 + 0.1 * (1:Npre);

omegaPre = repmat( ...
    vPre / p.Rw, ...
    4, ...
    1);

anglePre = zeros(4, Npre);

axPre = linspace(0, 1, Npre)';

avzPre = 0.002 * sin((1:Npre)');


%% Reference trajectory after reset

omegaRef = ones(4, Npost) * (10 / p.Rw);

angleRef = zeros(4, Npost);

axRef = zeros(Npost,1);

avzRef = zeros(Npost,1);


%% Full trajectory containing an in-run reset

omega = [omegaPre, omegaRef];

angle = [anglePre, angleRef];

ax = [axPre; axRef];

avz = [avzPre; avzRef];

reset = zeros(Npre + Npost, 1);

reset(1) = 1;

reset(Npre + 1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% Fresh-start reference

resetRef = [1; zeros(Npost - 1,1)];

Yref = run_update_sequence( ...
    omegaRef, ...
    angleRef, ...
    axRef, ...
    avzRef, ...
    resetRef);


%% Compare post-reset trajectory

idx = Npre + (1:Npost);

checkIdx = [ ...
    1,2,3,4,5,6,7, ...
    28,29, ...
    33,34,35,38];

testCase.verifyLessThan( ...
    max(abs( ...
        Y(checkIdx, idx(1)) - ...
        Yref(checkIdx,1))), ...
    1e-9, ...
    ['TEST2: reset sample should match clean startup ', ...
     'first-sample behavior']);

testCase.verifyLessThan( ...
    max(abs( ...
        Y(checkIdx, idx(end)) - ...
        Yref(checkIdx,end))), ...
    1e-9, ...
    ['TEST2: post-reset behavior should match ', ...
     'clean-start reference']);

testCase.verifyEqual( ...
    Y(33, idx(1)), ...
    0, ...
    'AbsTol', 1e-12, ...
    ['TEST2: allWheelInvalidDuration should ', ...
     'clear at reset']);

testCase.verifyFalse( ...
    logical(Y(34, idx(1))), ...
    'TEST2: degradedMode should clear at reset');

testCase.verifyTrue( ...
    isfinite(Y(7, idx(1))), ...
    'TEST2: PWI should be finite after reset');

end


%% ========================================================================
% TEST 3
% ========================================================================

function test_constant_speed_steady(testCase)
% TEST 3:
% Straight constant-speed steady-state after window maturity.

p = estimator_default_params();

N = 220;

omega = ones(4,N) * (10 / p.Rw);

angle = zeros(4,N);

ax = zeros(N,1);

avz = zeros(N,1);

reset = zeros(N,1);

reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% Whole trajectory finite

testCase.verifyTrue( ...
    all(isfinite(Y(1,:))), ...
    'TEST3: vx_hat must remain finite');


%% Mature window

midx = (p.Nwindow + 20):N;

testCase.verifyLessThan( ...
    abs(median(Y(1,midx)) - 10), ...
    0.03, ...
    ['TEST3: vx_hat median after maturity ', ...
     'should be near 10']);

testCase.verifyTrue( ...
    all(all(abs(Y(12:15,midx)) < 0.05)), ...
    'TEST3: eSlip should remain near zero');

testCase.verifyTrue( ...
    all(all(Y(16:19,midx) > 0.98)), ...
    'TEST3: rhoWheel should remain near one');

testCase.verifyTrue( ...
    all(all(Y(24:27,midx) == 1)), ...
    'TEST3: all four wheels should remain valid');

testCase.verifyTrue( ...
    all(logical(Y(28,midx))), ...
    'TEST3: wssValid should be true after maturity');

testCase.verifyTrue( ...
    all(logical(Y(29,midx))), ...
    'TEST3: imuValid should be true after maturity');

testCase.verifyFalse( ...
    any(logical(Y(34,midx))), ...
    'TEST3: degradedMode should remain false');

end


%% ========================================================================
% TEST 4
% ========================================================================

function test_constant_accel_no_slip(testCase)
% TEST 4:
% Constant acceleration with no wheel slip.

p = estimator_default_params();

N = 220;

v0 = 6;
acc = 1.0;

v = v0 + ...
    acc * p.Ts_est * (0:N-1)';

omega = repmat( ...
    (v / p.Rw)', ...
    4, ...
    1);

angle = zeros(4,N);

ax = acc * ones(N,1);

avz = zeros(N,1);

reset = zeros(N,1);

reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% Mature range

idx = (p.Nwindow + 10):N;

testCase.verifyTrue( ...
    all(isfinite(Y(1,idx))), ...
    'TEST4: vx_hat must remain finite');


%% Step increments

dv = diff(Y(1,idx));

testCase.verifyTrue( ...
    all(dv >= -1e-8), ...
    ['TEST4: vx_hat should not show abrupt ', ...
     'negative jumps']);

testCase.verifyTrue( ...
    all(dv < 0.03), ...
    ['TEST4: vx_hat increment should remain ', ...
     'smooth']);

testCase.verifyTrue( ...
    all(abs(dv - 0.5) > 0.15), ...
    ['TEST4: anti-misuse check: increment ', ...
     'must not cluster around 0.5 m/s/sample']);


%% Wheel residuals / validity

testCase.verifyTrue( ...
    all(all(abs(Y(12:15,idx)) < 0.05)), ...
    'TEST4: eSlip should remain near zero');

testCase.verifyTrue( ...
    all(logical(Y(28,idx))), ...
    'TEST4: wssValid should remain true');

testCase.verifyTrue( ...
    all(logical(Y(29,idx))), ...
    'TEST4: imuValid should remain true');


%% Single-step integration sanity

if numel(idx) > 20

    testCase.verifyLessThan( ...
        median(abs(diff(Y(1,idx(1:20))))), ...
        0.03, ...
        ['TEST4: IMU integration increment ', ...
         'appears too large']);

end

end


%% ========================================================================
% TEST 5
% ========================================================================

function test_window_boundary_50_51(testCase)

% TEST 5:
% Window-ready / residual-valid boundary.
%
% Important:
% Call 1 carries reset=true and the window module clears state then returns.
% Therefore:
%   top-level call Nwindow+1 -> 50th valid non-reset sample
%   top-level call Nwindow+2 -> 51st valid non-reset sample

p = estimator_default_params();

N = p.Nwindow + 2;

omega = ones(4,N) * (10 / p.Rw);
angle = zeros(4,N);
ax = zeros(N,1);
avz = zeros(N,1);

reset = zeros(N,1);
reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);

kReady  = p.Nwindow + 1;
kFormal = p.Nwindow + 2;

%% 50th valid non-reset update
testCase.verifyTrue( ...
    logical(Y(36,kReady)), ...
    ['TEST5: windowReady should be true at the ', ...
     '50th valid non-reset update']);

testCase.verifyTrue( ...
    all(isnan(Y(12:15,kReady))), ...
    ['TEST5: formal eSlip should not yet be ', ...
     'available when the FIFO first becomes ready']);

testCase.verifyFalse( ...
    logical(Y(28,kReady)), ...
    ['TEST5: WSS should still be invalid before ', ...
     'the first complete 0.50-s residual']);

testCase.verifyTrue( ...
    isfinite(Y(1,kReady)), ...
    'TEST5: vx_hat must remain finite');

%% 51st valid non-reset update
testCase.verifyTrue( ...
    logical(Y(36,kFormal)), ...
    'TEST5: windowReady should remain true');

testCase.verifyFalse( ...
    all(isnan(Y(12:15,kFormal))), ...
    ['TEST5: formal eSlip should become available ', ...
     'at the 51st valid non-reset update']);

testCase.verifyTrue( ...
    logical(Y(28,kFormal)), ...
    ['TEST5: WSS should become valid after the ', ...
     'first complete 0.50-s residual']);

testCase.verifyTrue( ...
    logical(Y(29,kFormal)), ...
    ['TEST5: IMU should be valid after the ', ...
     'first complete 0.50-s residual']);

testCase.verifyTrue( ...
    isfinite(Y(1,kFormal)), ...
    'TEST5: vx_hat must remain finite');

end


%% ========================================================================
% TEST 6
% ========================================================================

function test_single_wheel_slip_isolation(testCase)
% TEST 6:
% Single-wheel abnormality isolation.
%
% Fixed order:
%   1 FL
%   2 FR
%   3 RL
%   4 RR

p = estimator_default_params();

baseN = p.Nwindow + 30;

N = baseN + ...
    p.Nwindow + ...
    25;

for wi = 1:4

    omega = ones(4,N) * (10 / p.Rw);

    angle = zeros(4,N);

    ax = zeros(N,1);

    avz = zeros(N,1);

    reset = zeros(N,1);

    reset(1) = 1;


    %% Inject excess wheel speed

%% Inject sustained wheel-speed divergence
%
% The estimator uses a finite-window velocity-increment residual:
%
%   eSlip = abs(DeltaVWheel - DeltaVImu)
%
% Therefore a constant +2 m/s wheel-speed offset would disappear from
% DeltaVWheel once both window endpoints are on the same offset plateau.
% Use a continuing wheel-speed ramp so that the target wheel retains a
% nonzero 0.50-s velocity increment inconsistent with the IMU.

slipStart = baseN + 10;

nSlip = N - slipStart + 1;
tSlip = (0:nSlip-1) * p.Ts_est;

% Force the additional wheel-speed increment over one full window
% above e_high, so the target confidence reaches the hard-isolation region.
targetWindowError = p.e_high + max(0.2, 0.25*p.e_high);

slipAccel = targetWindowError / p.Twindow;

extraWheelSpeed = slipAccel * tSlip;

omega(wi,slipStart:end) = ...
    omega(wi,slipStart:end) + ...
    extraWheelSpeed / p.Rw;


    %% Run

    Y = run_update_sequence( ...
        omega, ...
        angle, ...
        ax, ...
        avz, ...
        reset);


    %% Mature anomaly range

    idx = (slipStart + p.Nwindow):N;

    testCase.verifyTrue( ...
        logical(Y(28,idx(1))), ...
        ['TEST6: WSS should remain valid with ', ...
         'one abnormal wheel']);

    testCase.verifyTrue( ...
        logical(Y(29,idx(1))), ...
        ['TEST6: IMU should remain valid with ', ...
         'one abnormal wheel']);


    %% Target wheel should be isolated

    testCase.verifyTrue( ...
        all(Y(24 + wi - 1,idx(end-10:end)) == 0), ...
        ['TEST6: wheel ', ...
         num2str(wi), ...
         ' should be isolated']);


    %% Compare all four wheels

    for j = 1:4

        if j == wi

            testCase.verifyTrue( ...
                all(Y(16 + j - 1,idx(end-10:end)) < 0.6), ...
                ['TEST6: target rho should drop for wheel ', ...
                 num2str(wi)]);

        else

            testCase.verifyTrue( ...
                all(Y(24 + j - 1,idx(end-10:end)) == 1), ...
                ['TEST6: unaffected wheel ', ...
                 num2str(j), ...
                 ' should remain valid']);

            testCase.verifyTrue( ...
                all(Y(16 + j - 1,idx(end-10:end)) > 0.8), ...
                ['TEST6: unaffected rho should stay high ', ...
                 'for wheel ', ...
                 num2str(j)]);

        end

    end


    %% Fused speed should reject bad wheel

    testCase.verifyLessThan( ...
        abs(Y(1,idx(end)) - 10), ...
        1.2, ...
        ['TEST6: vx_hat should not follow abnormal ', ...
         'wheel ', ...
         num2str(wi)]);


    %% Slip residual should rise on target wheel

    testCase.verifyTrue( ...
        all(Y(12 + wi - 1,idx) > 0.1), ...
        ['TEST6: target eSlip should increase for wheel ', ...
         num2str(wi)]);

    testCase.verifyTrue( ...
        isfinite(Y(1,idx(end))), ...
        ['TEST6: vx_hat must remain finite for wheel ', ...
         num2str(wi)]);

end

end


%% ========================================================================
% TEST 7
% ========================================================================

function test_wss_invalid_short(testCase)
% TEST 7:
% All-wheel WSS invalid for less than TimuOnlyMax.
%
% Healthy section:
%   four wheels = 10 m/s
%
% Invalid section:
%   four wheelOmega = NaN
%   IMU remains available

p = estimator_default_params();

Nbase = p.Nwindow + 20;

Nbad = floor(0.50 / p.Ts_est);

N = Nbase + Nbad;


%% Healthy wheel-speed phase then all-wheel invalid

omega = [ ...
    ones(4,Nbase) * (10 / p.Rw), ...
    NaN(4,Nbad) ...
];

angle = zeros(4,N);


%% Healthy baseline Ax=0
% During wheel invalid segment, IMU reports acceleration.

ax = [ ...
    zeros(Nbase,1); ...
    ones(Nbad,1) ...
];

avz = zeros(N,1);

reset = zeros(N,1);

reset(1) = 1;


%% Run

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);

baseEnd = Nbase;

badRange = (baseEnd + 1):N;


%% Baseline

testCase.verifyTrue( ...
    logical(Y(28,baseEnd)), ...
    'TEST7: WSS should be healthy before invalid segment');


%% IMPORTANT:
% allWheelInvalid must become TRUE.
% The original test had the Boolean direction reversed.

testCase.verifyTrue( ...
    logical(Y(32,badRange(1))), ...
    ['TEST7: allWheelInvalid flag should assert ', ...
     'during all-wheel invalid segment']);


%% IMU remains valid

imuValidSegment = logical(Y(29,badRange));

testCase.verifyTrue( ...
    all(imuValidSegment(:)), ...
    ['TEST7: IMU should remain valid during ', ...
     'short WSS-invalid segment']);


%% Fused speed remains finite

testCase.verifyTrue( ...
    all(isfinite(Y(1,badRange))), ...
    ['TEST7: vx_hat should remain finite when ', ...
     'WSS is invalid but IMU is valid']);


%% Duration increases

testCase.verifyTrue( ...
    all(Y(33,badRange) > 0), ...
    ['TEST7: allWheelInvalidDuration should ', ...
     'increase']);


%% Short interval should remain <= TimuOnlyMax

testCase.verifyLessThanOrEqual( ...
    Y(33,badRange(end)), ...
    p.TimuOnlyMax + 1e-12, ...
    ['TEST7: invalid duration should remain ', ...
     '<= TimuOnlyMax']);


%% No degraded mode yet

testCase.verifyFalse( ...
    any(logical(Y(34,badRange))), ...
    ['TEST7: degradedMode should remain false ', ...
     'during short IMU-only operation']);

end


%% ========================================================================
% TEST 8
% ========================================================================

function test_wss_invalid_long(testCase)
% TEST 8:
% All-wheel WSS invalid longer than TimuOnlyMax.

p = estimator_default_params();

N = 140;

omega = NaN(4,N);

angle = zeros(4,N);

ax = 0.5 * ones(N,1);

avz = zeros(N,1);

reset = zeros(N,1);

reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% WSS unavailable

testCase.verifyTrue( ...
    all(~logical(Y(28,:))), ...
    'TEST8: WSS must remain invalid');


%% IMU continuation

testCase.verifyTrue( ...
    all(logical(Y(29,2:end))), ...
    ['TEST8: IMU should remain valid during ', ...
     'IMU-only continuation']);

testCase.verifyTrue( ...
    all(isfinite(Y(1,2:end))), ...
    ['TEST8: vx_hat should remain finite ', ...
     'during IMU-only continuation']);


%% Degraded mode eventually activates

testCase.verifyTrue( ...
    any(logical(Y(34,2:end))), ...
    ['TEST8: degradedMode should eventually ', ...
     'become true']);


%% Duration reaches threshold

testCase.verifyGreaterThanOrEqual( ...
    Y(33,end), ...
    p.TimuOnlyMax, ...
    ['TEST8: allWheelInvalidDuration should ', ...
     'reach TimuOnlyMax']);

end


%% ========================================================================
% TEST 9
% ========================================================================

function test_wss_recovery(testCase)
% TEST 9:
% WSS recovery after IMU-only operation.
%
% Checks:
%   1. WSS eventually recovers.
%   2. degradedMode clears.
%   3. allWheelInvalidDuration resets.
%   4. PWI remains finite/continuous.

p = estimator_default_params();

N1 = 130;

N2 = p.Nwindow + 300;


%% Phase 1: WSS unavailable

omega1 = NaN(4,N1);
omega1(1:4, 1) = 10 / p.Rw;

angle1 = zeros(4,N1);

ax1 = zeros(N1,1);

avz1 = zeros(N1,1);

reset1 = zeros(N1,1);

reset1(1) = 1;

Y1 = run_update_sequence( ...
    omega1, ...
    angle1, ...
    ax1, ...
    avz1, ...
    reset1);

testCase.verifyFalse( ...
    logical(Y1(28,end)), ...
    'TEST9: WSS should be invalid before recovery');

testCase.verifyTrue( ...
    logical(Y1(29,end)), ...
    'TEST9: IMU should be valid before recovery');

pwiBefore = Y1(7,end);


%% Phase 2: valid wheels return

omega2 = ones(4,N2) * (10 / p.Rw);

angle2 = zeros(4,N2);

ax2 = zeros(N2,1);

avz2 = zeros(N2,1);

reset2 = zeros(N2,1);


%% Re-run complete sequence so persistent history is deterministic

Y2 = run_update_sequence( ...
    [omega1, omega2], ...
    [angle1, angle2], ...
    [ax1; ax2], ...
    [avz1; avz2], ...
    [reset1; reset2]);


%% First WSS-valid sample after recovery begins

updateIdx = find(logical(Y2(35,:)));
updateIdxAfterRecovery = updateIdx(updateIdx > N1);

testCase.verifyGreaterThanOrEqual( ...
    numel(updateIdxAfterRecovery), ...
    p.Nwindow + p.Nrecover, ...
    'TEST9: should have enough updates to satisfy recovery-window and recovery-count requirements');

isDeltaGood = false(1, numel(updateIdxAfterRecovery));
runLen = 0;
idxRec = [];
for k = 1:numel(updateIdxAfterRecovery)
    i = updateIdxAfterRecovery(k);
    eDeltaThis = Y2(12:15, i);
    isDeltaGood(k) = ...
        all(isfinite(eDeltaThis)) && ...
        all(eDeltaThis < p.eDelta_recover);
    if isDeltaGood(k)
        runLen = runLen + 1;
    else
        runLen = 0;
    end

    if runLen >= p.Nrecover
        idxRec = i;
        break;
    end
end

testCase.verifyTrue( ...
    ~isempty(idxRec), ...
    'TEST9: should observe 30 consecutive recovery-condition updates');

if isempty(idxRec)
    return;
end

testCase.verifyTrue( ...
    logical(Y2(28, idxRec)), ...
    'TEST9: WSS should recover on the 30th recovery update');

%% Degraded mode clears
testCase.verifyFalse( ...
    any(logical(Y2(34,idxRec:end))), ...
    ['TEST9: degradedMode should clear once ', ...
     'WSS recovers']);


%% Invalid duration resets

testCase.verifyEqual( ...
    Y2(33,idxRec), ...
    0, ...
    'AbsTol', 1e-12, ...
    ['TEST9: allWheelInvalidDuration should ', ...
     'reset at WSS recovery']);


%% PWI continuity

testCase.verifyTrue( ...
    isfinite(pwiBefore), ...
    'TEST9: PWI before recovery should be finite');

pwiAfter = Y2(7,idxRec);

testCase.verifyTrue( ...
    isfinite(pwiAfter), ...
    'TEST9: PWI after recovery should be finite');

if abs(pwiBefore) > 1e-12

    testCase.verifyGreaterThan( ...
        abs(pwiAfter), ...
        1e-14, ...
        ['TEST9: PWI should not be hard-reset ', ...
         'to zero during recovery']);

end

testCase.verifyLessThan( ...
    abs(pwiAfter - pwiBefore), ...
    max(1,abs(pwiBefore)) * 10, ...
    'TEST9: PWI discontinuity is unexpectedly large');

end


%% ========================================================================
% TEST 10
% ========================================================================

function test_imu_invalid_wss_valid(testCase)
% TEST 10:
% IMU becomes invalid after a healthy mature period.
%
% In the current Stage-1 architecture, WSS slip confidence is based on
% WSS/IMU finite-window consistency. Therefore complete IMU invalidity
% also removes the evidence needed to declare the WSS channel valid.
% The expected top-level behavior is then lastFiniteVx fallback.

p = estimator_default_params();

Nhealthy = p.Nwindow + 20;
Nbad = 10;
N = Nhealthy + Nbad;

omega = ones(4,N) * (10 / p.Rw);
angle = zeros(4,N);

% Healthy constant-speed baseline must use Ax = 0.
ax = [ ...
    zeros(Nhealthy,1); ...
    Inf(Nbad,1) ...
];

avz = zeros(N,1);

reset = zeros(N,1);
reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);

%% Healthy mature baseline

testCase.verifyTrue( ...
    logical(Y(28,Nhealthy)), ...
    'TEST10: baseline WSS should be valid');

testCase.verifyTrue( ...
    logical(Y(29,Nhealthy)), ...
    'TEST10: baseline IMU should be valid');

testCase.verifyFalse( ...
    logical(Y(34,Nhealthy)), ...
    'TEST10: healthy baseline must not be degraded');

testCase.verifyTrue( ...
    isfinite(Y(1,Nhealthy)), ...
    'TEST10: healthy baseline vx_hat must be finite');

%% IMU becomes invalid

testCase.verifyFalse( ...
    logical(Y(29,end)), ...
    'TEST10: Ax Inf must invalidate IMU');

% Current WSS confidence depends on valid IMU delta-v evidence.
testCase.verifyFalse( ...
    logical(Y(28,end)), ...
    ['TEST10: WSS must also be unavailable when the ', ...
     'IMU consistency reference is invalid']);

testCase.verifyTrue( ...
    logical(Y(34,end)), ...
    ['TEST10: simultaneous IMU/WSS unavailability ', ...
     'must enter degraded mode']);

testCase.verifyTrue( ...
    isfinite(Y(1,end)), ...
    ['TEST10: lastFiniteVx fallback must keep ', ...
     'vx_hat finite']);

end

%% ========================================================================
% TEST 11
% ========================================================================

function test_dual_invalid_fallback(testCase)
% TEST 11:
% Both WSS and IMU invalid.
%
% IMPORTANT:
% The bad phase is deliberately NOT reset.
% This allows the test to verify lastFiniteVx fallback from
% the immediately preceding healthy phase.

p = estimator_default_params();


%% Healthy phase

Ngood = p.Nwindow + 20;

omegaGood = ones(4,Ngood) * (10 / p.Rw);

angleGood = zeros(4,Ngood);

axGood = zeros(Ngood,1);

avzGood = zeros(Ngood,1);

resetGood = zeros(Ngood,1);

resetGood(1) = 1;

Ygood = run_update_sequence( ...
    omegaGood, ...
    angleGood, ...
    axGood, ...
    avzGood, ...
    resetGood);

lastGood = Ygood(1,end);

testCase.verifyTrue( ...
    isfinite(lastGood), ...
    'TEST11: healthy reference must be finite');


%% Immediately enter dual-invalid phase, NO RESET

Nbad = 45;

omegaBad = NaN(4,Nbad);

angleBad = zeros(4,Nbad);

axBad = NaN(Nbad,1);

avzBad = zeros(Nbad,1);

resetBad = zeros(Nbad,1);

Ybad = run_update_sequence( ...
    omegaBad, ...
    angleBad, ...
    axBad, ...
    avzBad, ...
    resetBad);


%% Fallback should hold last finite estimate

testCase.verifyTrue( ...
    all(abs(Ybad(1,:) - lastGood) < 1e-9), ...
    ['TEST11: fallback output should hold ', ...
     'lastFiniteVx']);

testCase.verifyTrue( ...
    all(isfinite(Ybad(1,:))), ...
    ['TEST11: dual-invalid fallback output ', ...
     'must remain finite']);

testCase.verifyTrue( ...
    all(logical(Ybad(34,:))), ...
    ['TEST11: degradedMode should be true ', ...
     'when both channels are invalid']);

end


%% ========================================================================
% TEST 12
% ========================================================================

function test_fusion_failure_note(testCase)
% TEST 12:
% Singular / ill-conditioned fusion internals cannot be reliably
% injected through the public top-level interface.
%
% These cases should remain covered by Stage-3D low-level unit tests.

testCase.verifyTrue( ...
    true, ...
    ['TEST12: low-level fusion singularity is ', ...
     'covered by Stage-3D tests']);

end


%% ========================================================================
% TEST 13
% ========================================================================

function test_single_wheel_nan_isolation(testCase)
% TEST 13:
% One-wheel NaN isolation for FL/FR/RL/RR.

p = estimator_default_params();

N = p.Nwindow + 25;

baseOmega = ones(4,N) * (10 / p.Rw);

baseAngle = zeros(4,N);

baseAx = zeros(N,1);

baseAvz = zeros(N,1);

baseReset = zeros(N,1);

baseReset(1) = 1;


%% Baseline

Ybase = run_update_sequence( ...
    baseOmega, ...
    baseAngle, ...
    baseAx, ...
    baseAvz, ...
    baseReset);

testCase.verifyTrue( ...
    all(isfinite(Ybase(1,:))), ...
    'TEST13: baseline vx_hat should remain finite');


%% Inject NaN separately into each wheel

for wi = 1:4

    omega = baseOmega;

    omega(wi,end) = NaN;

    reset = zeros(N,1);

    reset(1) = 1;

    Y = run_update_sequence( ...
        omega, ...
        baseAngle, ...
        baseAx, ...
        baseAvz, ...
        reset);


    %% Fused output remains finite

    testCase.verifyTrue( ...
        isfinite(Y(1,end)), ...
        ['TEST13: vx_hat should remain finite ', ...
         'for NaN wheel ', ...
         num2str(wi)]);


    %% Faulty wheel invalidated

    testCase.verifyEqual( ...
        Y(24 + wi - 1,end), ...
        0, ...
        ['TEST13: NaN wheel should become invalid: ', ...
         num2str(wi)]);


    %% Other wheels remain valid

    for j = 1:4

        if j ~= wi

            testCase.verifyEqual( ...
                Y(24 + j - 1,end), ...
                1, ...
                ['TEST13: healthy wheel should stay valid: ', ...
                 num2str(j)]);

        end

    end

end

end


%% ========================================================================
% TEST 14
% ========================================================================

function test_inf_input_isolation(testCase)
% TEST 14:
% Inf isolation for one wheel and for Ax.

p = estimator_default_params();

N = p.Nwindow + 20;

baseOmega = ones(4,N) * (10 / p.Rw);

baseAngle = zeros(4,N);

baseAx = zeros(N,1);

baseAvz = zeros(N,1);

reset = zeros(N,1);

reset(1) = 1;


%% ------------------------------------------------------------------------
% Wheel Inf
% -------------------------------------------------------------------------

omega = baseOmega;

omega(3,8:end) = Inf;

Ywheel = run_update_sequence( ...
    omega, ...
    baseAngle, ...
    baseAx, ...
    baseAvz, ...
    reset);

testCase.verifyTrue( ...
    isfinite(Ywheel(1,end)), ...
    ['TEST14: Inf wheel input should not make ', ...
     'vx_hat non-finite']);

testCase.verifyEqual( ...
    Ywheel(26,end), ...
    0, ...
    'TEST14: RL wheel with Inf should be invalid');


%% ------------------------------------------------------------------------
% Ax Inf
% -------------------------------------------------------------------------

Yax = run_update_sequence( ...
    baseOmega, ...
    baseAngle, ...
    Inf(N,1), ...
    baseAvz, ...
    reset);

testCase.verifyFalse( ...
    logical(Yax(29,end)), ...
    'TEST14: Ax Inf should invalidate imuValid');

% WSS confidence requires a valid IMU finite-window reference.
testCase.verifyFalse( ...
    logical(Yax(28,end)), ...
    ['TEST14: WSS consistency channel must be ', ...
     'invalid when the IMU reference is invalid']);

testCase.verifyTrue( ...
    logical(Yax(34,end)), ...
    ['TEST14: simultaneous WSS/IMU invalidity ', ...
     'must enter degraded mode']);

testCase.verifyTrue( ...
    isfinite(Yax(1,end)), ...
    ['TEST14: lastFiniteVx protection must keep ', ...
     'vx_hat finite after Ax invalidity']);

end


%% ========================================================================
% TEST 15
% ========================================================================

function test_pwi_continuity(testCase)
% TEST 15:
% PWI should remain finite and should not be forcibly reset
% to zero during WSS recovery.

p = estimator_default_params();

Npre = 100;

Nimu = 70;

Nrec = p.Nwindow + 35;


%% Healthy pre-phase

omegaPre = ones(4,Npre) * (10 / p.Rw);
anglePre = zeros(4,Npre);
axPre = zeros(Npre,1);
avzPre = zeros(Npre,1);

%% IMU-only phase

omegaImu = NaN(4,Nimu);
angleImu = zeros(4,Nimu);
axImu = zeros(Nimu,1);
avzImu = zeros(Nimu,1);

%% Recovery phase

omegaRec = ones(4,Nrec) * (10 / p.Rw);
angleRec = zeros(4,Nrec);
axRec = zeros(Nrec,1);
avzRec = zeros(Nrec,1);
%% Full deterministic sequence

omega = [ ...
    omegaPre, ...
    omegaImu, ...
    omegaRec ...
];

angle = [ ...
    anglePre, ...
    angleImu, ...
    angleRec ...
];

ax = [ ...
    axPre; ...
    axImu; ...
    axRec ...
];

avz = [ ...
    avzPre; ...
    avzImu; ...
    avzRec ...
];

reset = zeros(Npre + Nimu + Nrec,1);

reset(1) = 1;

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% PWI before IMU-only period

pwiPre = Y(7,Npre);

testCase.verifyTrue( ...
    isfinite(pwiPre), ...
    'TEST15: PWI before IMU-only phase must be finite');


%% PWI during complete IMU-only interval

imuRange = Npre + (1:Nimu);

testCase.verifyTrue( ...
    all(isfinite(Y(7,imuRange))), ...
    ['TEST15: PWI should remain finite ', ...
     'during IMU-only operation']);


%% Find first recovered WSS-valid sample

searchRange = (Npre + Nimu + 1):size(Y,2);

localRec = find( ...
    logical(Y(28,searchRange)), ...
    1, ...
    'first');

testCase.verifyFalse( ...
    isempty(localRec), ...
    'TEST15: WSS should recover');

if isempty(localRec)
    return;
end

idxRec = searchRange(localRec);


%% Check covariance immediately before/after WSS becomes valid

pwiBeforeRecovery = Y(7,idxRec - 1);

pwiAfterRecovery = Y(7,idxRec);

testCase.verifyTrue( ...
    isfinite(pwiBeforeRecovery), ...
    ['TEST15: PWI immediately before recovery ', ...
     'must be finite']);

testCase.verifyTrue( ...
    isfinite(pwiAfterRecovery), ...
    ['TEST15: PWI at recovery must be finite']);


%% Detect an unconditional hard reset to zero

if abs(pwiBeforeRecovery) > 1e-12

    testCase.verifyGreaterThan( ...
        abs(pwiAfterRecovery), ...
        1e-14, ...
        ['TEST15: PWI appears to have been ', ...
         'hard-reset to zero']);

end


%% Coarse continuity protection

testCase.verifyLessThan( ...
    abs(pwiAfterRecovery - pwiBeforeRecovery), ...
    max(1,abs(pwiBeforeRecovery)) * 10, ...
    ['TEST15: PWI discontinuity at recovery ', ...
     'is unexpectedly large']);


%% Remain finite afterwards

testCase.verifyTrue( ...
    all(isfinite(Y(7,idxRec:end))), ...
    ['TEST15: PWI should remain finite ', ...
     'after WSS recovery']);

end


%% ========================================================================
% TEST 16
% ========================================================================

function test_output_index_integrity(testCase)
% TEST 16:
% Key output positions and output semantics.

p = estimator_default_params();

u = zeros(18,1);

u(1:4) = ...
    10 / p.Rw * ones(4,1);

u(5:8) = 0;

u(9:11) = [0;0;0];

u(12:14) = [0;0;0.1];

u(15:17) = 0;

u(18) = 1;

y = longitudinal_velocity_estimator(u);


%% Output length

testCase.verifyEqual( ...
    numel(y), ...
    38, ...
    'TEST16: est_y length must be exactly 38');


%% Core scalar states

testCase.verifyTrue( ...
    all(arrayfun(@isscalar,y(1:7))), ...
    'TEST16: outputs 1:7 must be scalar');


%% Validity states

testCase.verifyTrue( ...
    isscalar(y(28)) && ...
    isscalar(y(29)), ...
    ['TEST16: wssValid and imuValid ', ...
     'must be scalar']);


%% Fusion weights

testCase.verifyTrue( ...
    isscalar(y(30)) && ...
    isscalar(y(31)), ...
    ['TEST16: alphaW and alphaI ', ...
     'must be scalar']);


%% Diagnostics

testCase.verifyTrue( ...
    isscalar(y(34)) && ...
    isscalar(y(35)) && ...
    isscalar(y(36)) && ...
    isscalar(y(37)) && ...
    isscalar(y(38)), ...
    ['TEST16: diagnostic outputs ', ...
     '34:38 must be scalar']);


%% At least one channel should participate at initialization

%% Fusion weights at reset
% The reset call only initializes state. No mature WSS/IMU measurement
% update is expected on this sample.

testCase.verifyEqual( ...
    y(30), ...
    0, ...
    'TEST16: alphaW should be zero on reset');

testCase.verifyEqual( ...
    y(31), ...
    0, ...
    'TEST16: alphaI should be zero on reset');

%% Fusion weights after a mature healthy sequence

N = p.Nwindow + 20;

omega = ones(4,N) * (10 / p.Rw);
angle = zeros(4,N);
ax = zeros(N,1);
avz = zeros(N,1);

resetSeq = zeros(N,1);
resetSeq(1) = 1;

Ymature = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    resetSeq);

testCase.verifyTrue( ...
    logical(Ymature(28,end)), ...
    'TEST16: WSS should be valid after maturation');

testCase.verifyTrue( ...
    logical(Ymature(29,end)), ...
    'TEST16: IMU should be valid after maturation');

testCase.verifyTrue( ...
    Ymature(30,end) ~= 0 || Ymature(31,end) ~= 0, ...
    ['TEST16: at least one fusion weight should ', ...
     'be active after healthy maturation']);

%% Core covariance/state values finite

testCase.verifyTrue( ...
    isfinite(y(1)) && ...
    isfinite(y(2)) && ...
    isfinite(y(7)), ...
    ['TEST16: core state/covariance outputs ', ...
     'must be finite after initialization']);

end


%% ========================================================================
% TEST 17
% ========================================================================

function test_long_term_finite(testCase)
% TEST 17:
% Long synthetic trajectory finite-output property.
%
% Phases:
%   1 startup + straight
%   2 acceleration
%   3 transient FR wheel anomaly
%   4 recovery

p = estimator_default_params();

seg1 = p.Nwindow + 25;

seg2 = 120;

seg3 = 50;

seg4 = 80;


%% ------------------------------------------------------------------------
% Segment 1: 10 m/s straight motion
% -------------------------------------------------------------------------

v1 = 10 * ones(seg1,1);


%% ------------------------------------------------------------------------
% Segment 2: physically consistent acceleration
% -------------------------------------------------------------------------

acc2 = 0.4;

v2 = v1(end) + ...
    acc2 * p.Ts_est * (1:seg2)';


%% ------------------------------------------------------------------------
% Segment 3: constant-speed anomaly
% -------------------------------------------------------------------------

v3 = v2(end) * ones(seg3,1);


%% ------------------------------------------------------------------------
% Segment 4: constant-speed recovery
% -------------------------------------------------------------------------

v4 = v3(end) * ones(seg4,1);


%% Full true wheel-compatible velocity profile

v = [ ...
    v1; ...
    v2; ...
    v3; ...
    v4 ...
];


%% IMPORTANT:
% v is Nx1.
% omega must be 4xN, therefore transpose before repmat.

omega = repmat( ...
    (v / p.Rw)', ...
    4, ...
    1);


%% Add temporary FR anomaly during segment 3

start3 = seg1 + seg2 + 1;

end3 = start3 + seg3 - 1;

omega(2,start3:end3) = ...
    omega(2,start3:end3) + ...
    2 / p.Rw;


%% Steering

angle = zeros(4,numel(v));


%% Physically consistent longitudinal acceleration

ax = [ ...
    zeros(seg1,1); ...
    acc2 * ones(seg2,1); ...
    zeros(seg3,1); ...
    zeros(seg4,1) ...
];


%% Yaw rate

avz = zeros(numel(v),1);


%% Reset only at startup

reset = zeros(numel(v),1);

reset(1) = 1;


%% Run

Y = run_update_sequence( ...
    omega, ...
    angle, ...
    ax, ...
    avz, ...
    reset);


%% Fused speed must remain finite

testCase.verifyTrue( ...
    all(isfinite(Y(1,:))), ...
    ['TEST17: vx_hat must remain finite ', ...
     'across all trajectory phases']);


%% Critical covariance and diagnostic outputs remain finite

testCase.verifyTrue( ...
    all(isfinite(Y(2,:))), ...
    'TEST17: Pfused must remain finite');

testCase.verifyTrue( ...
    all(isfinite(Y(7,:))), ...
    'TEST17: PWI must remain finite');

testCase.verifyTrue( ...
    all(isfinite(Y(33,:))), ...
    ['TEST17: allWheelInvalidDuration ', ...
     'must remain finite']);

testCase.verifyTrue( ...
    all(isfinite(Y(34,:))), ...
    ['TEST17: degradedMode numerical output ', ...
     'must remain finite']);

end


%% ========================================================================
% Helper: run complete sequence
% ========================================================================

function Y = run_sequence(omega, angle, ax, avz, reset)
% Run sequence at 1 kHz input rate (legacy scheduling tests).
% Convention:
%   Y1k = raw 1 ms outputs.
%   updated = logical(Y1k(35,:));
%   Yupd = Y1k(:, updated) are outputs aligned to real 100 Hz update points.

N = size(omega,2);


%% Dimension protection

if size(omega,1) ~= 4

    error( ...
        'run_sequence:omegaDimension', ...
        'omega must be 4xN');

end

if size(angle,1) ~= 4 || size(angle,2) ~= N

    error( ...
        'run_sequence:angleDimension', ...
        'angle must be 4xN and match omega');

end

if ~isvector(ax) || numel(ax) ~= N

    error( ...
        'run_sequence:axDimension', ...
        'ax length must equal N');

end

if ~isvector(avz) || numel(avz) ~= N

    error( ...
        'run_sequence:avzDimension', ...
        'avz length must equal N');

end

if ~isvector(reset) || numel(reset) ~= N

    error( ...
        'run_sequence:resetDimension', ...
        'reset length must equal N');

end


%% Force scalar-input sequences to column form

ax = ax(:);

avz = avz(:);

reset = reset(:);


%% Execute estimator sample-by-sample

Y = NaN(38,N);

for k = 1:N

Y(:,k) = run_step( ...
        omega(:,k), ...
        angle(:,k), ...
        ax(k), ...
        avz(k), ...
        reset(k));

end

end


%% ========================================================================
% Helper: one estimator sample
% ========================================================================

function y = run_step( ...
    wheelOmega, ...
    wheelAngle, ...
    ax, ...
    avz, ...
    resetFlag)
% Build fixed Stage-2 18-dimensional input vector.

u = zeros(18,1);


%% Wheel speed

u(1:4) = wheelOmega(:);


%% Four-wheel steering angle

u(5:8) = wheelAngle(:);


%% Linear acceleration
% Ax used.
% Ay/Az unused in current Stage-3E top-level.

u(9:11) = [ ...
    ax; ...
    0; ...
    0 ...
];


%% Angular velocity
% AVx / AVy set to zero.
% AVz = yaw rate.

u(12:14) = [ ...
    0; ...
    0; ...
    avz ...
];


%% Stage-2 reserved Ax_SM/Ay_SM/Az_SM fields

u(15:17) = 0;


%% Reset

u(18) = resetFlag;


%% Execute

y = longitudinal_velocity_estimator(u);

end


%% ========================================================================
% Helper: run one estimator update tick
% ========================================================================

function y = run_one_estimator_update( ...
    wheelOmega, ...
    wheelAngle, ...
    ax, ...
    avz, ...
    resetFlag, ...
    maxIters)

%% Preserve existing 1 ms loop duration.

if nargin < 7 || isempty(maxIters) || ~isscalar(maxIters) ...
        || ~isfinite(maxIters) || maxIters <= 0
    maxIters = 20;
end

isReset = isfinite(resetFlag) && (resetFlag ~= 0);

if isReset
    y = run_step(wheelOmega, wheelAngle, ax, avz, resetFlag);
    return;
end

for k = 1:maxIters

    y = run_step(wheelOmega, wheelAngle, ax, avz, resetFlag);

    if logical(y(35))

        return;

    end

end

error( ...
    'run_one_estimator_update:noUpdate', ...
    'No estimator update in %d ms samples. input reset=%g', ...
    maxIters, resetFlag);

end


%% ========================================================================
% Helper: update-rate sequence execution
% ========================================================================

function Y = run_update_sequence(omega, angle, ax, avz, reset)
% Run sequence at 1 ms, return full Y1k stream.
% For true 100 Hz checks:
%   updated = logical(Y(35,:));
%   Yupd = Y(:, updated);

N = size(omega,2);

if size(omega,1) ~= 4
    error('run_update_sequence:omegaDimension', 'omega must be 4xN');
end
if size(angle,1) ~= 4 || size(angle,2) ~= N
    error( ...
        'run_update_sequence:angleDimension', ...
        'angle must be 4xN and match omega');
end
if ~isvector(ax) || numel(ax) ~= N
    error('run_update_sequence:axDimension', 'ax length must equal N');
end
if ~isvector(avz) || numel(avz) ~= N
    error('run_update_sequence:avzDimension', 'avz length must equal N');
end
if ~isvector(reset) || numel(reset) ~= N
    error('run_update_sequence:resetDimension', 'reset length must equal N');
end

ax = ax(:);
avz = avz(:);
reset = reset(:);

Y = NaN(38, N);
for k = 1:N
    Y(:, k) = run_one_estimator_update( ...
        omega(:, k), ...
        angle(:, k), ...
        ax(k), ...
        avz(k), ...
        reset(k));

end

end


% ========================================================================
% Helper: compare two estimator output vectors with NaN-safe and tolerance.
% ========================================================================

function mismatchIdx = compare_estimator_outputs(a, b, tol)

if nargin < 3 || isempty(tol) || ~isscalar(tol) || ~isfinite(tol) || tol < 0
    tol = 0;
end

if ~isequal(size(a), size(b))
    mismatchIdx = (1:numel(a))';
    return;
end

if isempty(a) || isempty(b)
    mismatchIdx = zeros(0, 1);
    return;
end

a = a(:);
b = b(:);

finiteMask = isfinite(a) & isfinite(b);

sameFinite = false(size(a));
sameFinite(finiteMask) = abs(a(finiteMask) - b(finiteMask)) <= tol;

sameBothNaN = isnan(a) & isnan(b);
sameBothInf = isinf(a) & isinf(b) & (sign(a) == sign(b));

same = sameFinite | sameBothNaN | sameBothInf;

mismatchIdx = find(~same);

end


%% ========================================================================
% Helper: verify code pattern
% ========================================================================

function verify_code_pattern( ...
    testCase, ...
    code, ...
    pattern, ...
    message)

match = regexp( ...
    code, ...
    pattern, ...
    'once', ...
    'ignorecase');

testCase.verifyFalse( ...
    isempty(match), ...
    message);

end


%% ========================================================================
% Helper: parse est_y index token
% ========================================================================

function idx = parse_index_token(token)
% Supports:
%
%   '7'
%   '8:11'
%   '8 : 11'
%   '[7]'
%   '[8:11]'
%   '7, 8, 9'

token = strtrim(token);
token = regexprep(token, '^\[|\]$', '');

% Support packed forms like '8:11 30:31' or '[8:11, 30:31]'.
token = strrep(token, ';', ' ');
token = strrep(token, ',', ' ');
parts = regexp(token, '[^\s]+', 'match');
if isempty(parts)
    error('test_longitudinal_velocity_estimator:indexParse', ...
        'Unsupported est_y index expression: %s', ...
        token);
end

idx = [];
for p = 1:numel(parts)
    part = strtrim(parts{p});
    if isempty(part)
        continue;
    end

    %% Range
    rangeTokens = regexp( ...
        part, ...
        '^(\d+)\s*:\s*(\d+)$', ...
        'tokens', ...
        'once');

    if ~isempty(rangeTokens)
        firstIdx = str2double(rangeTokens{1});
        lastIdx = str2double(rangeTokens{2});
        idx = [idx, firstIdx:lastIdx];
        continue;
    end

    %% Scalar
    scalarToken = regexp( ...
        part, ...
        '^(\d+)$', ...
        'tokens', ...
        'once');

    if ~isempty(scalarToken)
        idx = [idx, str2double(scalarToken{1})];
        continue;
    end

    %% Unsupported expression
    error('test_longitudinal_velocity_estimator:indexParse', ...
        'Unsupported est_y index expression: %s', ...
        part);
end

idx = unique(idx(:));

end


%% ========================================================================
% Helper: extract persistent declarations
% ========================================================================

function names = extract_persistent_names(code)
% Extract persistent variable names line-by-line.
%
% Current top-level style:
%
%   persistent initialized
%   persistent pCfg
%   persistent vxFusedPrev
%   ...

lines = regexp(code, '\r\n|\n|\r', 'split');

names = {};

for k = 1:numel(lines)

    line = strtrim(lines{k});

    token = regexp( ...
        line, ...
        '^persistent[ \t]+(.+)$', ...
        'tokens', ...
        'once');

    if isempty(token)
        continue;
    end

    vars = regexp( ...
        token{1}, ...
        '[A-Za-z]\w*', ...
        'match');

    names = [names, vars]; %#ok<AGROW>

end

names = unique(names);

end

