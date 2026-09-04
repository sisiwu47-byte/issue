function tests = test_slip_confidence_mapping
%TEST_SLIP_CONFIDENCE_MAPPING
% Stage 3C2 unit tests for slip_confidence_mapping.
%
% Covers:
%   TEST 1  - full confidence below e_low
%   TEST 2  - eSlip = e_low boundary
%   TEST 3  - middle linear interval
%   TEST 4  - eSlip = e_high boundary
%   TEST 5  - eSlip > e_high
%   TEST 6  - rho_hard strict boundary semantics
%   TEST 7  - residualValid isolation
%   TEST 8  - validGeom isolation
%   TEST 9  - NaN eSlip isolation
%   TEST 10 - Inf eSlip isolation
%   TEST 11 - rho bounds / linear mapping
%   TEST 12 - Rwheel finite and bounded
%
% VALIDATION state: PENDING MATLAB VALIDATION
%
% Run:
%   r = runtests('tests/test_slip_confidence_mapping.m');
%   table(r)

tests = functiontests(localfunctions);

end


%% ========================================================================
% Setup
% ========================================================================

function setupOnce(testCase)
% Allow independent execution from the tests directory.

testDir = fileparts(mfilename('fullpath'));
matlabDir = fullfile(testDir, '..', 'matlab');

testCase.verifyTrue( ...
    isfolder(matlabDir), ...
    'Cannot find ../matlab source directory.');

testCase.applyFixture( ...
    matlab.unittest.fixtures.PathFixture(matlabDir));

end


%% ========================================================================
% TEST 1
% ========================================================================

function test_full_confidence(testCase)
% TEST 1:
% |eSlip| below e_low with valid residual and geometry.
%
% Expected:
%   rhoWheel = 1
%   validWheel = true
%   Rwheel = R0/(1+epsilon), clipped to [R_min,R_max]

tol = 1e-12;

p = make_test_params();

e_low = p.e_low;

residualValid = true(4,1);
validGeom = true(4,1);

eSlip = ...
    0.5 * e_low * ones(4,1);


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);


%% Expected values

rhoExpected = ones(4,1);

RExpected = ...
    R0_from_rho(1,p) * ones(4,1);


%% Verify confidence

testCase.verifyEqual( ...
    rhoWheel, ...
    rhoExpected, ...
    'AbsTol', tol, ...
    'TEST1: rhoWheel should equal 1.');


%% Verify measurement covariance

testCase.verifyEqual( ...
    Rwheel, ...
    RExpected, ...
    'AbsTol', tol, ...
    'TEST1: Rwheel mismatch at full confidence.');


%% Verify validity

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST1: all wheels should be valid.');

end


%% ========================================================================
% TEST 2
% ========================================================================

function test_e_low_boundary(testCase)
% TEST 2:
% eSlip = e_low must still give rho = 1.

tol = 1e-12;

p = make_test_params();

eSlip = ...
    p.e_low * ones(4,1);

residualValid = true(4,1);
validGeom = true(4,1);


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);


%% Expected R

RExpected = ...
    R0_from_rho(1,p) * ones(4,1);


%% Verify

testCase.verifyEqual( ...
    rhoWheel, ...
    ones(4,1), ...
    'AbsTol', tol, ...
    'TEST2: rho at e_low should equal 1.');

testCase.verifyEqual( ...
    Rwheel, ...
    RExpected, ...
    'AbsTol', tol, ...
    'TEST2: Rwheel mismatch at e_low.');

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST2: rho=1 should keep all wheels valid.');

end


%% ========================================================================
% TEST 3
% ========================================================================

function test_middle_interval(testCase)
% TEST 3:
% At the midpoint between e_low and e_high:
%
%   rho = 0.5

tol = 1e-12;

p = make_test_params();

eMid = ...
    0.5 * ...
    (p.e_low + p.e_high);

eSlip = ...
    eMid * ones(4,1);

residualValid = true(4,1);
validGeom = true(4,1);


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);


%% Expected

rhoExpected = ...
    0.5 * ones(4,1);

RExpected = ...
    R0_from_rho(0.5,p) * ones(4,1);


%% Verify rho

testCase.verifyEqual( ...
    rhoWheel, ...
    rhoExpected, ...
    'AbsTol', tol, ...
    'TEST3: rho should equal 0.5 at midpoint.');


%% Verify R

testCase.verifyEqual( ...
    Rwheel, ...
    RExpected, ...
    'AbsTol', tol, ...
    'TEST3: Rwheel mismatch at midpoint.');


%% Assuming Stage-2 rho_hard < 0.5

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST3: midpoint confidence should keep wheels valid.');

end


%% ========================================================================
% TEST 4
% ========================================================================

function test_e_high_boundary(testCase)
% TEST 4:
% eSlip = e_high must produce rho = 0.

tol = 1e-12;

p = make_test_params();

eSlip = ...
    p.e_high * ones(4,1);


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% Expected

RExpected = ...
    R0_from_rho(0,p) * ones(4,1);


%% Verify rho

testCase.verifyEqual( ...
    rhoWheel, ...
    zeros(4,1), ...
    'AbsTol', tol, ...
    'TEST4: rho at e_high should equal zero.');


%% R remains finite even when confidence is zero

testCase.verifyEqual( ...
    Rwheel, ...
    RExpected, ...
    'AbsTol', tol, ...
    'TEST4: Rwheel mismatch for rho=0.');

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST4: Rwheel must remain finite.');


%% Invalid wheels

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST4: rho=0 should invalidate all wheels.');

end


%% ========================================================================
% TEST 5
% ========================================================================

function test_above_e_high(testCase)
% TEST 5:
% Slip above e_high should remain saturated at rho = 0.

tol = 1e-12;

p = make_test_params();

eSlip = ...
    (p.e_high + 0.01) * ones(4,1);


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% Verify saturation

testCase.verifyEqual( ...
    rhoWheel, ...
    zeros(4,1), ...
    'AbsTol', tol, ...
    'TEST5: rho above e_high should saturate to zero.');

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST5: zero confidence should invalidate all wheels.');

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST5: Rwheel should remain finite.');

end


%% ========================================================================
% TEST 6
% ========================================================================

function test_rho_hard_boundary(testCase)
% TEST 6:
% Verify strict validity rule:
%
%   validWheel = rhoWheel > rho_hard
%
% Therefore:
%
%   rho < rho_hard  -> invalid
%   rho = rho_hard  -> invalid
%   rho > rho_hard  -> valid

tol = 1e-12;

p = make_test_params();

residualValid = true(4,1);
validGeom = true(4,1);


%% ------------------------------------------------------------------------
% Slightly below rho_hard
% -------------------------------------------------------------------------

rhoBelow = ...
    p.rho_hard - 1e-3;

testCase.verifyGreaterThan( ...
    rhoBelow, ...
    0, ...
    'TEST6 prerequisite: rhoBelow must remain positive.');

eBelow = ...
    p.e_high - ...
    rhoBelow * ...
    (p.e_high - p.e_low);

eSlip = ...
    eBelow * ones(4,1);

[rhoWheel, ~, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);

testCase.verifyEqual( ...
    rhoWheel, ...
    rhoBelow * ones(4,1), ...
    'AbsTol', tol, ...
    'TEST6a: constructed rho below rho_hard mismatch.');

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST6a: rho < rho_hard should be invalid.');


%% ------------------------------------------------------------------------
% Exactly rho_hard
% -------------------------------------------------------------------------

pEq = p;
pEq.e_low = 0;
pEq.e_high = 1;
pEq.rho_hard = 0.25;

eSlip = 0.75 * ones(4,1);

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        pEq);

testCase.verifyEqual( ...
    rhoWheel, ...
    0.25 * ones(4,1), ...
    'AbsTol', tol, ...
    'TEST6b: exact rho_hard should remain exactly 0.25 in this local parameter set.');

testCase.verifyFalse( ...
    any(validWheel), ...
    ['TEST6b: rho=rho_hard must be invalid ', ...
     'under strict > rule.']);

%% Adaptive variance should still follow the rho mapping.
% Hard isolation and adaptive variance are separate operations:
% rho == rho_hard makes validWheel false, but Rwheel is still calculated
% from R0/(rho+epsilon) and then saturated to [R_min,R_max].

R0eq = pEq.R0;

if isscalar(R0eq)
    R0eq = repmat(R0eq,4,1);
else
    R0eq = R0eq(:);
end

expectedR = R0eq ./ (pEq.rho_hard + pEq.epsilon);
expectedR = min(max(expectedR,pEq.R_min),pEq.R_max);

testCase.verifyEqual( ...
    Rwheel, ...
    expectedR, ...
    'AbsTol', 1e-12, ...
    ['TEST6b: Rwheel should follow the adaptive variance ', ...
     'mapping even when rho equals rho_hard.']);

%% ------------------------------------------------------------------------
% Slightly above rho_hard
% -------------------------------------------------------------------------

rhoAbove = ...
    p.rho_hard + 1e-3;

testCase.verifyLessThan( ...
    rhoAbove, ...
    1, ...
    'TEST6 prerequisite: rhoAbove must remain below one.');

eAbove = ...
    p.e_high - ...
    rhoAbove * ...
    (p.e_high - p.e_low);

eSlip = ...
    eAbove * ones(4,1);

[rhoWheel, ~, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);

testCase.verifyEqual( ...
    rhoWheel, ...
    rhoAbove * ones(4,1), ...
    'AbsTol', tol, ...
    'TEST6c: constructed rho above rho_hard mismatch.');

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST6c: rho > rho_hard should be valid.');

end


%% ========================================================================
% TEST 7
% ========================================================================

function test_residual_invalid_isolation(testCase)
% TEST 7:
% residualValid=false must invalidate only that wheel.
%
% IMPORTANT:
% slip_confidence_mapping returns:
%
%   [rhoWheel, Rwheel, validWheel]
%
% Therefore validWheel is the THIRD output.

tol = 1e-12;

p = make_test_params();

eSlip = ...
    0.5 * (p.e_low + p.e_high) * ones(4,1);

residualValid = true(4,1);

residualValid(1) = false;

validGeom = true(4,1);


%% Execute
% Fixed from original two-output bug.

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);


%% Invalid wheel should be forced to zero confidence
testCase.verifyEqual( ...
    rhoWheel(1), ...
    0, ...
    'AbsTol', tol, ...
    'TEST7: residualValid=false should force FL confidence to zero.');

testCase.verifyEqual( ...
    Rwheel(1), ...
    p.R_max, ...
    'TEST7: residual invalid wheel must keep Rwheel at R_max.');


%% But residual validity must invalidate FL

testCase.verifyFalse( ...
    validWheel(1), ...
    'TEST7: residualValid=false must invalidate FL.');


%% Remaining wheels stay valid

testCase.verifyTrue( ...
    all(validWheel(2:4)), ...
    'TEST7: unaffected wheels should remain valid.');


%% Covariances remain safe

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST7: Rwheel should remain finite.');

end


%% ========================================================================
% TEST 8
% ========================================================================

function test_geometry_invalid_isolation(testCase)
% TEST 8:
% validGeom=false must invalidate only the corresponding wheel.

tol = 1e-12;

p = make_test_params();

eSlip = ...
    0.5 * (p.e_low + p.e_high) * ones(4,1);

residualValid = true(4,1);

validGeom = true(4,1);

validGeom(2) = false;


%% Execute
% Fixed from original two-output bug.

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        residualValid, ...
        validGeom, ...
        p);


%% Invalid wheel should be forced to zero confidence

testCase.verifyEqual( ...
    rhoWheel(2), ...
    0, ...
    'AbsTol', tol, ...
    'TEST8: validGeom=false should force FR confidence to zero.');

testCase.verifyEqual( ...
    Rwheel(2), ...
    p.R_max, ...
    'TEST8: geometry-invalid wheel must keep Rwheel at R_max.');


%% But geometry validity must reject FR

testCase.verifyFalse( ...
    validWheel(2), ...
    'TEST8: validGeom=false must invalidate FR.');


%% Other wheels stay valid

testCase.verifyTrue( ...
    all(validWheel([1,3,4])), ...
    'TEST8: other wheels should remain valid.');


%% R remains finite

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST8: Rwheel should remain finite.');

end


%% ========================================================================
% TEST 9
% ========================================================================

function test_nan_eslip_isolation(testCase)
% TEST 9:
% A NaN slip residual should invalidate only that wheel.

tol = 1e-12;

p = make_test_params();

eHealthy = ...
    0.5 * p.e_low;

eSlip = [ ...
    NaN;
    eHealthy;
    eHealthy;
    eHealthy ...
];


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% NaN wheel follows zero-confidence protection path

testCase.verifyEqual( ...
    rhoWheel(1), ...
    0, ...
    'AbsTol', tol, ...
    'TEST9: NaN eSlip should produce zero confidence.');

testCase.verifyFalse( ...
    validWheel(1), ...
    'TEST9: NaN eSlip must invalidate the affected wheel.');


%% Other wheels unaffected

testCase.verifyTrue( ...
    all(validWheel(2:4)), ...
    'TEST9: unaffected wheels should remain valid.');


%% Safety property

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST9: NaN eSlip must not produce non-finite Rwheel.');

testCase.verifyTrue( ...
    all(Rwheel > 0), ...
    'TEST9: all Rwheel values should remain positive.');

end


%% ========================================================================
% TEST 10
% ========================================================================

function test_inf_eslip_isolation(testCase)
% TEST 10:
% An Inf slip residual should invalidate only that wheel.

tol = 1e-12;

p = make_test_params();

eHealthy = ...
    0.5 * p.e_low;

eSlip = [ ...
    Inf;
    eHealthy;
    eHealthy;
    eHealthy ...
];


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% Inf wheel becomes zero-confidence

testCase.verifyEqual( ...
    rhoWheel(1), ...
    0, ...
    'AbsTol', tol, ...
    'TEST10: Inf eSlip should produce zero confidence.');

testCase.verifyFalse( ...
    validWheel(1), ...
    'TEST10: Inf eSlip must invalidate the wheel.');


%% Other wheels unaffected

testCase.verifyTrue( ...
    all(validWheel(2:4)), ...
    'TEST10: unaffected wheels should remain valid.');


%% Safe covariance

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST10: Inf input must not make Rwheel non-finite.');

testCase.verifyTrue( ...
    all(Rwheel > 0), ...
    'TEST10: Rwheel must remain positive.');

end


%% ========================================================================
% TEST 11
% ========================================================================

function test_rho_bounds_and_linear_formula(testCase)
% TEST 11:
% Verify:
%
%   0 <= rho <= 1
%
% including NaN/Inf inputs, and independently check one point in
% the actual linear interpolation region.
%
% ORIGINAL TEST BUG FIXED:
%   e_low*0.4 lies BELOW e_low, so it is not a linear-region point.
%
% Use:
%
%   e = e_low + 0.4*(e_high-e_low)
%
% which gives expected rho = 0.6.

tol = 1e-12;

p = make_test_params();


%% Point genuinely inside the transition interval

eMiddle = ...
    p.e_low + ...
    0.4 * (p.e_high - p.e_low);

expectedMiddleRho = ...
    1 - ...
    (eMiddle - p.e_low) / ...
    (p.e_high - p.e_low);


%% Mixed input vector

eSlip = [ ...
    NaN;
    Inf;
    eMiddle;
    1.1 * p.e_high ...
];


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% All rho outputs should be finite under protection logic

testCase.verifyTrue( ...
    all(isfinite(rhoWheel)), ...
    'TEST11: rhoWheel should remain finite.');


%% Lower bound

testCase.verifyGreaterThanOrEqual( ...
    min(rhoWheel), ...
    0, ...
    'TEST11: rho lower bound violated.');


%% Upper bound

testCase.verifyLessThanOrEqual( ...
    max(rhoWheel), ...
    1, ...
    'TEST11: rho upper bound violated.');


%% Linear interpolation formula

testCase.verifyEqual( ...
    rhoWheel(3), ...
    expectedMiddleRho, ...
    'AbsTol', tol, ...
    'TEST11: middle-region linear formula mismatch.');


%% Here expectedMiddleRho = 0.6

testCase.verifyEqual( ...
    expectedMiddleRho, ...
    0.6, ...
    'AbsTol', tol, ...
    'TEST11: test construction itself is incorrect.');


%% Safety outputs

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST11: Rwheel should remain finite.');

testCase.verifySize( ...
    validWheel, ...
    [4,1]);

end


%% ========================================================================
% TEST 12
% ========================================================================

function test_Rwheel_finite_and_bounded(testCase)
% TEST 12:
% Verify Rwheel remains:
%
%   finite
%   positive
%   >= R_min
%   <= R_max
%
% Use parameter-relative eSlip values rather than hard-coded values so
% this test remains valid if e_low/e_high are later tuned.

tol = 1e-12;

p = make_test_params();


%% Construct representative points:
%  1. below e_low
%  2. lower transition region
%  3. upper transition region
%  4. above e_high

eSlip = [ ...
    0.5 * p.e_low;
    p.e_low + 0.25 * (p.e_high - p.e_low);
    p.e_low + 0.75 * (p.e_high - p.e_low);
    1.1 * p.e_high ...
];


%% Execute

[rhoWheel, Rwheel, validWheel] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4,1), ...
        true(4,1), ...
        p);


%% Finite

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST12: Rwheel must remain finite.');


%% Positive

testCase.verifyTrue( ...
    all(Rwheel > 0), ...
    'TEST12: Rwheel must remain positive.');


%% Lower covariance bound

testCase.verifyGreaterThanOrEqual( ...
    min(Rwheel), ...
    p.R_min - tol, ...
    'TEST12: Rwheel is below R_min.');


%% Upper covariance bound

testCase.verifyLessThanOrEqual( ...
    max(Rwheel), ...
    p.R_max + tol, ...
    'TEST12: Rwheel exceeds R_max.');


%% Confidence safety bounds

testCase.verifyGreaterThanOrEqual( ...
    min(rhoWheel), ...
    0);

testCase.verifyLessThanOrEqual( ...
    max(rhoWheel), ...
    1);


%% Output dimensions

testCase.verifySize(rhoWheel,[4,1]);

testCase.verifySize(Rwheel,[4,1]);

testCase.verifySize(validWheel,[4,1]);

end


%% ========================================================================
% TEST 13
% ========================================================================

function test_eabs_below_threshold_has_full_weight(testCase)
% TEST 13:
% Absolute consistency should be full when eAbs <= eAbs_low.

tol = 1e-12;
p = make_test_params();

eSlip = zeros(4, 1) + 0.05;
eAbs = zeros(4, 1) + 0.1436;


%% Execute

[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify absolute criterion

testCase.verifyEqual( ...
    rhoAbs, ...
    ones(4, 1), ...
    'AbsTol', tol, ...
    'TEST13: rhoAbs should be 1 when eAbs <= eAbs_low.');


%% Verify raw confidence equals delta confidence for low eAbs

testCase.verifyEqual( ...
    rhoRaw, ...
    rhoDelta, ...
    'AbsTol', tol, ...
    'TEST13: low eAbs should not reduce rhoRaw.');


%% Verify all wheels remain valid

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST13: all wheels should remain valid.');

end


%% ========================================================================
% TEST 14
% ========================================================================

function test_eabs_linear_region(testCase)
% TEST 14:
% Absolute consistency follows linear transition on (eAbs_low, eAbs_high).

tol = 1e-12;
p = make_test_params();

eSlip = zeros(4, 1) + 0.05;

% 取eAbs线性过渡区正中间
eAbsMid = ...
    0.5 * (p.eAbs_low + p.eAbs_high);

eAbs = ...
    eAbsMid * ones(4, 1);

expectedRhoAbs = ...
    (p.eAbs_high - eAbsMid) / ...
    (p.eAbs_high - p.eAbs_low);


%% Execute

[rhoRaw, ~, ~, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify linear formula

testCase.verifyEqual( ...
    rhoAbs, ...
    expectedRhoAbs * ones(4, 1), ...
    'AbsTol', tol, ...
    'TEST14: rhoAbs should be linear in transition interval.');

testCase.verifyEqual( ...
    rhoRaw, ...
    min(rhoDelta, rhoAbs), ...
    'AbsTol', tol, ...
    'TEST14: rhoRaw should be min(rhoDelta, rhoAbs).');

end


%% ========================================================================
% TEST 15
% ========================================================================

function test_eabs_above_threshold_zero(testCase)
% TEST 15:
% Absolute consistency should force zero confidence at or above eAbs_high.

tol = 1e-12;
p = make_test_params();

eSlip = zeros(4, 1) + 0.05;
eAbs = zeros(4, 1) + 1.0;


%% Execute

[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify hard absolute rejection

testCase.verifyEqual( ...
    rhoAbs, ...
    zeros(4, 1), ...
    'AbsTol', tol, ...
    'TEST15: rhoAbs should be 0 when eAbs >= eAbs_high.');

testCase.verifyEqual( ...
    rhoRaw, ...
    zeros(4, 1), ...
    'AbsTol', tol, ...
    'TEST15: rhoRaw should be 0 when rhoAbs is 0.');

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST15: all wheels should be invalid when rhoRaw is zero.');

testCase.verifyTrue( ...
    all(Rwheel > 0), ...
    'TEST15: Rwheel remains positive.');

end


%% ========================================================================
% TEST 16
% ========================================================================

function test_eabs_recovery_case_rejects_high_delta_low_abs(testCase)
% TEST 16:
% Reproduces the provided failure pattern:
% eDelta small but eAbs large should still invalidate.

tol = 1e-12;
p = make_test_params();

eSlip = 0.01173 * ones(4, 1);
eAbs  = 26 * ones(4, 1);


%% Execute

[rhoRaw, ~, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify that the added criterion resolves the false recovery case

testCase.verifyEqual( ...
    rhoDelta, ...
    ones(4, 1), ...
    'AbsTol', tol, ...
    'TEST16: small eDelta should keep rhoDelta near one.');

testCase.verifyEqual( ...
    rhoAbs, ...
    zeros(4, 1), ...
    'AbsTol', tol, ...
    'TEST16: high eAbs should make rhoAbs zero.');

testCase.verifyEqual( ...
    rhoRaw, ...
    zeros(4, 1), ...
    'AbsTol', tol, ...
    'TEST16: rhoRaw should be zero with high eAbs.');

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST16: both eAbs criterion and rhoRaw zero should invalidate all wheels.');

end


%% ========================================================================
% TEST 17
% ========================================================================

function test_eabs_at_low_boundary_is_full_weight(testCase)
% TEST 17:
% rhoAbs should remain full when eAbs equals eAbs_low.

tol = 1e-12;
p = make_test_params();

eSlip = zeros(4, 1) + 0.05;
eAbs  = zeros(4, 1) + p.eAbs_low;


%% Execute

[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify

testCase.verifyEqual( ...
    rhoAbs, ...
    ones(4, 1), ...
    'AbsTol', tol, ...
    'TEST17: rhoAbs should be 1 at eAbs_low boundary.');

testCase.verifyEqual( ...
    rhoRaw, ...
    rhoDelta, ...
    'AbsTol', tol, ...
    'TEST17: rhoRaw should equal rhoDelta at eAbs_low.');

testCase.verifyTrue( ...
    all(validWheel), ...
    'TEST17: all wheels should remain valid at eAbs_low.');

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST17: Rwheel should remain finite.');

end


%% ========================================================================
% TEST 18
% ========================================================================

function test_high_delta_low_abs_still_invalid(testCase)
% TEST 18:
% High eDelta should fail even when eAbs is low (good absolute consistency).

tol = 1e-12;
p = make_test_params();

eSlip = ones(4, 1) * (p.e_high + 0.20);
eAbs  = ones(4, 1) * 0.05;


%% Execute

[rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
    slip_confidence_mapping( ...
        eSlip, ...
        true(4, 1), ...
        true(4, 1), ...
        p, ...
        eAbs);


%% Verify

testCase.verifyLessThan( ...
    max(rhoDelta), ...
    p.rho_hard, ...
    'TEST18: high eDelta should map rhoDelta below rho_hard.');

testCase.verifyEqual( ...
    rhoAbs, ...
    ones(4, 1), ...
    'AbsTol', tol, ...
    'TEST18: low eAbs should map rhoAbs to 1.');

testCase.verifyEqual( ...
    rhoRaw, ...
    zeros(4, 1), ...
    'AbsTol', tol, ...
    'TEST18: rhoRaw should stay zero when rhoDelta fails.');

testCase.verifyFalse( ...
    any(validWheel), ...
    'TEST18: high eDelta should invalidate wheels even with low eAbs.');

testCase.verifyTrue( ...
    all(isfinite(Rwheel)), ...
    'TEST18: Rwheel should remain finite.');

end


%% ========================================================================
% Helper: test parameters
% ========================================================================

function p = make_test_params()
% Build Stage-2 parameter set with required numerical epsilon.

p = estimator_default_params();

p.epsilon = 1e-8;

end


%% ========================================================================
% Helper: expected R from confidence
% ========================================================================

function R = R0_from_rho(rho,p)
% Expected Stage-2 confidence-to-covariance mapping:
%
%   R = R0/(rho+epsilon)
%
% followed by clipping to [R_min,R_max].

R = ...
    p.R0 / ...
    (rho + p.epsilon);

R = ...
    min( ...
        max(R,p.R_min), ...
        p.R_max);

end
