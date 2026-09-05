function tests = test_wheel_lock_recovery
%TEST_WHEEL_LOCK_RECOVERY
% Targeted tests for absolute consistency + lock/recovery state machine.
%
% Covers:
%   - dual-condition recovery gating (eDelta and eAbs)
%   - lock state lockout during high eAbs
%   - Nrecover consecutive-good-cycle release
%   - count reset on failed recovery condition
%   - reset clearing lock/recovery state
%   - non-update hold-cycle stability

tests = functiontests(localfunctions);

end


%% ========================================================================
% Setup
% ========================================================================

function setupOnce(testCase)
testDir = fileparts(mfilename('fullpath'));
matlabDir = fullfile(testDir, '..', 'matlab');
testCase.applyFixture(...
    matlab.unittest.fixtures.PathFixture(matlabDir));
end


%% ========================================================================
% TEST 1
% ========================================================================

function test_lock_recovery_count_release(testCase)
% Target wheel should remain locked for 29 good cycles and unlock on 30th.

p = estimator_default_params();

baseOmega = ones(4,1) * (12 / p.Rw);
baseAngle = zeros(4,1);

Nbase = 70;
Nramp = 50;
NhighAbs = 30;
% Phase D length:
% first flush eDelta window, then accumulate Nrecover good cycles
% Number of recovery updates:
% eDelta window washout + recovery counter accumulation
Nrecov = p.Nwindow + p.Nrecover + 5;

% Build per-update candidate profiles.
updateOmega = repmat(baseOmega, ...
    1, ...
    Nbase + Nramp + NhighAbs + Nrecov);
updateAngle = repmat(baseAngle, 1, size(updateOmega, 2));
updateAx = zeros(1, size(updateOmega, 2));
updateAvz = zeros(1, size(updateOmega, 2));
updateReset = zeros(1, size(updateOmega, 2));
updateReset(1) = 1;

% Phase B: ramp wheel-1 to force persistent eDelta severity.
targetWindowError = p.e_high + 0.30;
slipAccel = targetWindowError / p.Twindow;
rampStart = Nbase + 1;
rampIdx = rampStart:(rampStart + Nramp - 1);
for k = rampIdx
    dt = (k - rampStart) * p.Ts_est;
    extra = slipAccel * dt;
    updateOmega(1,k) = baseOmega(1) + extra / p.Rw;
end

% Phase C: keep wheel 1 biased by +1.0 m/s -> low eDelta, high eAbs.
highAbsStart = rampStart + Nramp;
for k = highAbsStart:(highAbsStart + NhighAbs - 1)
    updateOmega(1,k) = baseOmega(1) + 1 / p.Rw;
end

% Phase D: back to baseline; recovery counters should reach 30.
recoveryStart = highAbsStart + NhighAbs;


%% Expand to 1 kHz simulation stream and run

[omega1k, angle1k, ax1k, avz1k, reset1k] = ...
    expand_update_profile(updateOmega, updateAngle, updateAx, updateAvz, updateReset);

Y = run_full_sequence(omega1k, angle1k, ax1k, avz1k, reset1k);
updateIdx = find(logical(Y(35,:)));
Yupd = Y(:, updateIdx);

% Y1k is 1 kHz output stream, Yupd is output sampled at estimator update
% events only (100 Hz logical updates). Column index in Yupd means "n-th
% true update point", never 1 ms sample index.

%% Find recovery interval in TRUE 100 Hz update domain

wi = 1;

samplesPerLogicalUpdate = 10;

% recoveryStart is the logical input profile index at which
% wheel input is returned to baseline.
recoveryStart1k = ...
    (recoveryStart - 1) * samplesPerLogicalUpdate + 1;

% Find first TRUE 100 Hz estimator update after baseline recovery begins.
idxPhaseDStart = find( ...
    updateIdx >= recoveryStart1k, ...
    1, ...
    'first');

testCase.verifyNotEmpty( ...
    idxPhaseDStart, ...
    'TEST1: no true estimator update found after Phase D begins.');

testCase.verifyGreaterThan( ...
    idxPhaseDStart, ...
    1, ...
    'TEST1: Phase D must have a preceding locked update.');

%% Confirm wheel is locked when Phase D begins

testCase.verifyFalse( ...
    logical(Yupd(24 + wi - 1, idxPhaseDStart - 1)), ...
    'TEST1: target wheel should already be invalid before Phase D.');

%% ---------------------------------------------------------
% Locate first update where eDelta recovery condition is met.
%
% During Phase D, eAbs is intentionally returned to the
% baseline condition by the test profile. Therefore the delayed
% condition is the window-based eSlip/eDelta.
% ----------------------------------------------------------

eDeltaWheel = Yupd(12 + wi - 1, :);

searchRange = idxPhaseDStart:size(Yupd,2);

idxRel = find( ...
    eDeltaWheel(searchRange) < p.eDelta_recover, ...
    1, ...
    'first');

testCase.verifyNotEmpty( ...
    idxRel, ...
    ['TEST1: eDelta never fell below recovery threshold; ', ...
     'recovery profile is too short.']);

idxGoodStart = ...
    searchRange(1) + idxRel - 1;

%% Need Nrecover consecutive genuinely good 100 Hz updates

idxReleaseExpected = ...
    idxGoodStart + p.Nrecover - 1;

testCase.verifyLessThanOrEqual( ...
    idxReleaseExpected, ...
    size(Yupd,2), ...
    ['TEST1: insufficient true 100Hz updates after eDelta ', ...
     'first satisfies recovery condition.']);

%% Wheel must remain locked for first Nrecover-1 good updates

if p.Nrecover > 1

    holdRange = ...
        idxGoodStart:(idxReleaseExpected - 1);

    testCase.verifyFalse( ...
        any(logical(Yupd(24 + wi - 1, holdRange))), ...
        ['TEST1: wheel must remain invalid during first ', ...
         'Nrecover-1 genuinely good recovery updates.']);
end

%% Wheel unlocks on Nrecover-th consecutive genuinely good update

testCase.verifyTrue( ...
    logical(Yupd(24 + wi - 1, idxReleaseExpected)), ...
    ['TEST1: target wheel should recover on the Nrecover-th ', ...
     'consecutive genuinely good recovery update.']);
end


%% ========================================================================
% TEST 2
% ========================================================================

function test_recovery_requires_dual_low_conditions(testCase)
% High eAbs must prevent unlock even if eDelta is low.

p = estimator_default_params();

baseOmega = ones(4,1) * (12 / p.Rw);

Nbase = 60;
Nramp = 50;
NhighAbs = 1;
Ngood = 40;

updateOmega = repmat(baseOmega,1,Nbase+Nramp+NhighAbs+Ngood);
updateAngle = zeros(4, Nbase+Nramp+NhighAbs+Ngood);
updateAx = zeros(1, size(updateOmega,2));
updateAvz = zeros(1, size(updateOmega,2));
updateReset = zeros(1,size(updateOmega,2));
updateReset(1) = 1;

% force sustained severe eDelta
targetWindowError = p.e_high + 0.30;
slipAccel = targetWindowError / p.Twindow;
rampStart = Nbase + 1;
for k = rampStart:(rampStart+Nramp-1)
    dt = (k - rampStart) * p.Ts_est;
    extra = slipAccel * dt;
    updateOmega(1,k) = baseOmega(1) + extra / p.Rw;
end

% keep wheel-1 at +1.0 m/s. eDelta low but eAbs high.
highAbsStart = rampStart + Nramp;
updateOmega(1,highAbsStart) = baseOmega(1) + 1 / p.Rw;

% then return to baseline; should still fail recovery in the first cycle.
% keep baseline afterwards.

[omega1k, angle1k, ax1k, avz1k, reset1k] = ...
    expand_update_profile(updateOmega, updateAngle, updateAx, updateAvz, updateReset);
Y = run_full_sequence(omega1k, angle1k, ax1k, avz1k, reset1k);
updateIdx = find(logical(Y(35,:)));
Yupd = Y(:, updateIdx);

wi = 1;
idxAfterHighAbs = Nbase + Nramp + NhighAbs;

testCase.verifyFalse( ...
    logical(Yupd(24 + wi - 1, idxAfterHighAbs)), ...
    ['TEST2: target wheel must stay invalid when eDelta low but eAbs ', ...
     'is above recovery threshold.']);

end


%% ========================================================================
% TEST 3
% ========================================================================

function test_recovery_count_reset_on_fail(testCase)
% A failed recovery condition must reset the consecutive count.

p = estimator_default_params();
baseOmega = ones(4,1) * (12 / p.Rw);
Nbase = 60;
Nramp = 50;
NrecoverTotal = 41;

updateOmega = repmat(baseOmega,1,Nbase+Nramp+NrecoverTotal);
updateAngle = zeros(4, Nbase+Nramp+NrecoverTotal);
updateAx = zeros(1,size(updateOmega,2));
updateAvz = zeros(1,size(updateOmega,2));
updateReset = zeros(1,size(updateOmega,2));
updateReset(1) = 1;

targetWindowError = p.e_high + 0.30;
slipAccel = targetWindowError / p.Twindow;
rampStart = Nbase + 1;
for k = rampStart:(rampStart+Nramp-1)
    dt = (k - rampStart) * p.Ts_est;
    extra = slipAccel * dt;
    updateOmega(1,k) = baseOmega(1) + extra / p.Rw;
end

% recovery attempt: 10 good cycles then 1 invalid (geometry fail), then 30 good cycles
recStart = rampStart + Nramp;
for k = recStart:(recStart+9)
    updateOmega(1,k) = baseOmega(1);
end
failIdx = recStart + 10;
updateAngle(1, failIdx) = 1.5; % invalid steering geometry -> residual invalid.
for k = (failIdx+1):(failIdx+30)
    updateAngle(1,k) = 0;
    updateOmega(1,k) = baseOmega(1);
end

Nu = size(updateOmega, 2);
testCase.verifySize(updateOmega, [4, Nu], ...
    'TEST3: updateOmega must remain 4xNu logical-update grid.');
testCase.verifySize(updateAngle, [4, Nu], ...
    'TEST3: updateAngle must remain 4xNu logical-update grid.');
testCase.verifyEqual(numel(updateAx), Nu, ...
    'TEST3: updateAx must share logical-update length.');
testCase.verifyEqual(numel(updateAvz), Nu, ...
    'TEST3: updateAvz must share logical-update length.');
testCase.verifyEqual(numel(updateReset), Nu, ...
    'TEST3: updateReset must share logical-update length.');

[omega1k, angle1k, ax1k, avz1k, reset1k] = ...
    expand_update_profile(updateOmega, updateAngle, updateAx, updateAvz, updateReset);
Y = run_full_sequence(omega1k, angle1k, ax1k, avz1k, reset1k);
updateIdx = find(logical(Y(35,:)));
Yupd = Y(:, updateIdx);

wi = 1;
idxToCheck = recStart + 30;
% if count is cleared on fail, wheel should still be invalid by end of sequence
% despite 30+ recovery cycles after failure.
testCase.verifyLessThanOrEqual( ...
    idxToCheck, ...
    size(Yupd, 2), ...
    'TEST3: check index exceeds available 100Hz updates.');
testCase.verifyFalse( ...
    logical(Yupd(24 + wi - 1, idxToCheck)), ...
    'TEST3: a single failed recovery step should reset count and prevent unlock.');

end


%% ========================================================================
% TEST 4
% ========================================================================

function test_reset_clears_lock_state(testCase)
% Reset should clear wheel lock and recovery counters.

p = estimator_default_params();
baseOmega = ones(4,1) * (12 / p.Rw);
baseAngle = zeros(4,1);

Nbase = 70;
Nramp = 50;
Npost = p.Nwindow + 20;

Nupdates = Nbase + Nramp + 1 + p.Nwindow + Npost + 10;
updateOmega = repmat(baseOmega,1,Nupdates);
updateAngle = repmat(baseAngle,1,Nupdates);
updateAx = zeros(1,Nupdates);
updateAvz = zeros(1,Nupdates);
updateReset = zeros(1,Nupdates);

updateReset(1) = 1;

% Create severe slip and lock before reset.
targetWindowError = p.e_high + 0.30;
slipAccel = targetWindowError / p.Twindow;
rampStart = Nbase + 1;
for k = rampStart:(rampStart+Nramp-1)
    dt = (k - rampStart) * p.Ts_est;
    extra = slipAccel * dt;
    updateOmega(1,k) = baseOmega(1) + extra / p.Rw;
end

% Issue reset while wheels still likely locked.
updateReset(rampStart + 5) = 1;

% After reset, hold long enough baseline for fresh windows.
% (values already baseline).

[omega1k, angle1k, ax1k, avz1k, reset1k] = ...
    expand_update_profile(updateOmega, updateAngle, updateAx, updateAvz, updateReset);
Y = run_full_sequence(omega1k, angle1k, ax1k, avz1k, reset1k);

% Find first index after the second reset update sequence.
updateIdx = find(logical(Y(35,:)));
Yupd = Y(:, updateIdx);

% Choose final steady-state window after reset and fresh data.
% Since Yupd is aligned to true update ticks (100 Hz), check tail update
% samples directly and require all 4 wheels valid.
wi = 1;
validTail = logical(Yupd(24:27, end-p.Nwindow:end));
testCase.verifyTrue( ...
    all(validTail(:)), ...
    'TEST4: reset should clear lock state and allow wheels to recover validity.');

end


%% ========================================================================
% TEST 5
% ========================================================================

%% ========================================================================
% TEST 5
% ========================================================================

function test_non_update_hold_cycle_stable(testCase)
% TEST5
% Verify that 1 ms non-update calls do not advance estimator state.
%
% Simulink call rate : 1 kHz
% Estimator update   : 100 Hz
%
% On a non-update tick:
%   estimatorUpdated = 0
%   updateCounter must remain unchanged
%   confidence / wheelValid / degradedMode must hold.

p = estimator_default_params();

N = 40;

% Constant physically valid wheel speed
pulse = ones(4,1) * (12 / p.Rw);

omega = repmat(pulse,1,N);
angle = zeros(4,N);
ax    = zeros(N,1);
avz   = zeros(N,1);
reset = zeros(N,1);

% First call resets estimator
reset(1) = 1;

Y = run_full_sequence(omega, angle, ax, avz, reset);

testCase.verifyEqual(size(Y,1),38, ...
    'TEST5: estimator output must remain 38xN.');

updated = logical(Y(35,:));

updateIdx = find(updated);
holdIdx   = find(~updated);

testCase.verifyNotEmpty(updateIdx, ...
    'TEST5: sequence must contain estimator updates.');

testCase.verifyNotEmpty(holdIdx, ...
    'TEST5: sequence must contain non-update hold cycles.');

%% Check 100 Hz spacing

% Ignore any special reset-related location and check spacing
% between genuine estimator update events.
if numel(updateIdx) >= 2
    dUpdate = diff(updateIdx);

    testCase.verifyEqual( ...
        dUpdate, ...
        10*ones(size(dUpdate)), ...
        'TEST5: estimator updates must remain 10 samples apart.');
end

%% Check updateCounter on hold ticks

for k = 2:size(Y,2)

    if ~updated(k)

        testCase.verifyEqual( ...
            Y(38,k), ...
            Y(38,k-1), ...
            'TEST5: updateCounter should hold during non-update cycles.');

    end
end

%% Confidence / wheelValid / degradedMode must hold

for k = 2:size(Y,2)

    if ~updated(k)

        % confidence
        testCase.verifyEqual( ...
            Y(16:19,k), ...
            Y(16:19,k-1), ...
            'TEST5: confidence changed on a non-update tick.');

        % wheelValid
        testCase.verifyEqual( ...
            Y(24:27,k), ...
            Y(24:27,k-1), ...
            'TEST5: wheelValid changed on a non-update tick.');

        % degradedMode
        testCase.verifyEqual( ...
            Y(34,k), ...
            Y(34,k-1), ...
            'TEST5: degradedMode changed on a non-update tick.');

    end
end

end
%% ========================================================================
% TEST 6
% ========================================================================

function test_update_ticks_remain_100hz(testCase)
% Update ticks in a 1ms stream should be spaced at 10-sample intervals.

p = estimator_default_params();

Nsec = 3;
N = Nsec * 1000;

omega = repmat(12 / p.Rw, 4, N);
angle = zeros(4, N);
ax = zeros(N, 1);
avz = zeros(N, 1);
reset = zeros(N, 1);
reset(1) = 1;

Y = run_full_sequence(omega, angle, ax, avz, reset);
updateIdx = find(logical(Y(35,:)));

testCase.verifyGreaterThan(numel(updateIdx), 0, 'TEST6: should have at least one update index.');
testCase.verifyTrue( ...
    all(diff(updateIdx) == 10), ...
    'TEST6: update ticks should remain every 10 samples at 100 Hz.');

end


%% ========================================================================
% TEST 7
% ========================================================================

function test_est_y_length_is_38x1(testCase)
% Output vector remains 38x1 even during hold cycles.

p = estimator_default_params();

N = 20;
omega = ones(4,1) * (12 / p.Rw);
angle = zeros(4,1);
ax = zeros(N,1);
avz = zeros(N,1);
reset = zeros(N,1);
reset(1) = 1;

for k = 1:N
    y = run_step(omega, angle, 0, 0, reset(k));
    testCase.verifySize(y, [38,1]);
    testCase.verifyClass(y, 'double');
end
end


%% ========================================================================
% Helper: expand per-update profiles to 1kHz stream
% ========================================================================

function [omega1k, angle1k, ax1k, avz1k, reset1k] = ...
    expand_update_profile(updateOmega, updateAngle, updateAx, updateAvz, updateReset)

Nu = size(updateOmega, 2);
N = Nu * 10;

omega1k = zeros(4,N);
angle1k = zeros(4,N);
ax1k = zeros(N,1);
avz1k = zeros(N,1);
reset1k = zeros(N,1);

for k = 1:Nu
    idx = (k-1)*10 + (1:10);
    omega1k(:, idx) = repmat(updateOmega(:, k), 1, numel(idx));
    angle1k(:, idx) = repmat(updateAngle(:, k), 1, numel(idx));
    ax1k(idx) = repmat(updateAx(k), 1, numel(idx));
    avz1k(idx) = repmat(updateAvz(k), 1, numel(idx));
    reset1k(idx) = repmat(updateReset(k), 1, numel(idx));
end
end


%% ========================================================================
% Helper: run full 1kHz sequence, keep both update and hold ticks.
% ========================================================================

function Y = run_full_sequence(omega, angle, ax, avz, reset)
% Y1k: estimator output at every 1 ms call.
% updated: 1xN logical = Y1k(35,:)==1.
% Yupd: filtered outputs Y1k(:, updated), indexed by real 100Hz update points.

N = size(omega,2);
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

function y = run_step(wheelOmega, wheelAngle, ax, avz, resetFlag)
u = zeros(18,1);
u(1:4) = wheelOmega(:);
u(5:8) = wheelAngle(:);
u(9:11) = [ax; 0; 0];
u(12:14) = [0; 0; avz];
u(15:17) = 0;
u(18) = resetFlag;
y = longitudinal_velocity_estimator(u);
end



