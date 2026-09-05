function test_wss_track_builder()
% STAGE 3C2 TESTS - wss_track_builder
% STATUS: WRITTEN, NOT EXECUTED, PENDING MATLAB VALIDATION

tol = 1e-12;

% TEST 1: all valid, equal R
vxWheel = [10; 10; 10; 10];
Rwheel  = [2; 2; 2; 2];
validWheel = true(4, 1);
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST1: all wheels valid must set wssValid=true.');
assert(norm(alphaWheel - [0.25; 0.25; 0.25; 0.25], Inf) <= tol, 'TEST1: equal-R fusion weights mismatch.');
assert(abs(vxWssTrack - 10) <= tol, 'TEST1: vxWssTrack mismatch for equal velocities.');
assert(abs(RwssEquivalent - 0.5) <= tol, 'TEST1: equivalent variance mismatch.');

% TEST 2: all R equal, different vx -> arithmetic mean
vxWheel = [8; 10; 12; 14];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, 3 * ones(4, 1), validWheel);
assert(wssValid, 'TEST2: all wheels valid must set wssValid=true.');
assert(norm(alphaWheel - [0.25; 0.25; 0.25; 0.25], Inf) <= tol, 'TEST2: equal-R should still share equal weights.');
assert(abs(vxWssTrack - mean(vxWheel)) <= tol, 'TEST2: mean fusion mismatch.');
assert(abs(RwssEquivalent - (3 / 4)) <= tol, 'TEST2: equivalent variance mismatch.');

% TEST 3: different R
vxWheel = [8; 10; 12; 14];
Rwheel = [1; 2; 4; 8];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
q = 1 ./ Rwheel;
expectedAlpha = q / sum(q);
expectedTrack = sum(expectedAlpha .* vxWheel);
expectedR = 1 / sum(q);
assert(wssValid, 'TEST3: all wheels valid must set wssValid=true.');
assert(norm(alphaWheel - expectedAlpha, Inf) <= tol, 'TEST3: alpha mismatch for unequal R.');
assert(abs(vxWssTrack - expectedTrack) <= tol, 'TEST3: vxWssTrack mismatch.');
assert(abs(RwssEquivalent - expectedR) <= tol, 'TEST3: RwssEquivalent mismatch.');

% TEST 4: only FL valid
vxWheel = [15; 10; 20; 30];
Rwheel = [1; 2; 3; 4];
validWheel = [true; false; false; false];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST4: only FL valid should still be valid.');
assert(norm(alphaWheel - [1; 0; 0; 0], Inf) <= tol, 'TEST4: only FL should have unit weight.');
assert(abs(vxWssTrack - vxWheel(1)) <= tol, 'TEST4: vxWssTrack should equal FL.');
assert(abs(RwssEquivalent - 1 / (1 / Rwheel(1))) <= tol, 'TEST4: equivalent variance mismatch.');

% TEST 5: only FR valid
validWheel = [false; true; false; false];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST5: only FR valid should still be valid.');
assert(norm(alphaWheel - [0; 1; 0; 0], Inf) <= tol, 'TEST5: only FR should have unit weight.');
assert(abs(vxWssTrack - vxWheel(2)) <= tol, 'TEST5: vxWssTrack should equal FR.');
assert(abs(RwssEquivalent - Rwheel(2)) <= tol, 'TEST5: equivalent variance mismatch.');

% TEST 6: only RL valid
validWheel = [false; false; true; false];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST6: only RL valid should still be valid.');
assert(norm(alphaWheel - [0; 0; 1; 0], Inf) <= tol, 'TEST6: only RL should have unit weight.');
assert(abs(vxWssTrack - vxWheel(3)) <= tol, 'TEST6: vxWssTrack should equal RL.');
assert(abs(RwssEquivalent - Rwheel(3)) <= tol, 'TEST6: equivalent variance mismatch.');

% TEST 7: only RR valid
validWheel = [false; false; false; true];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST7: only RR valid should still be valid.');
assert(norm(alphaWheel - [0; 0; 0; 1], Inf) <= tol, 'TEST7: only RR should have unit weight.');
assert(abs(vxWssTrack - vxWheel(4)) <= tol, 'TEST7: vxWssTrack should equal RR.');
assert(abs(RwssEquivalent - Rwheel(4)) <= tol, 'TEST7: equivalent variance mismatch.');

% TEST 8: one invalid wheel, others renormalize
validWheel = [true; false; true; true];
vxWheel = [8; 12; 14; 18];
Rwheel = [1; 2; 4; 8];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
fusionMask = [true; false; true; true];
q = 1 ./ Rwheel(fusionMask);
expectedAlpha = zeros(4, 1);
expectedAlpha(fusionMask) = q / sum(q);
expectedTrack = sum(expectedAlpha(fusionMask) .* vxWheel(fusionMask));
expectedR = 1 / sum(q);
assert(wssValid, 'TEST8: with one invalid wheel should still be valid.');
assert(abs(alphaWheel(2)) <= tol, 'TEST8: FR invalid should have alpha=0.');
assert(norm(alphaWheel - expectedAlpha, Inf) <= tol, 'TEST8: remaining valid wheels should renormalize.');
assert(abs(vxWssTrack - expectedTrack) <= tol, 'TEST8: vxWssTrack mismatch.');
assert(abs(sum(alphaWheel(fusionMask)) - 1) <= tol, 'TEST8: normalized weight sum mismatch.');
assert(abs(RwssEquivalent - expectedR) <= tol, 'TEST8: equivalent variance mismatch.');

% TEST 9: vxWheel NaN should be treated invalid despite validWheel=true
vxWheel = [NaN; 20; 30; 40];
Rwheel = [1; 2; 3; 4];
validWheel = true(4, 1);
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
expectedMask = [false; true; true; true];
q = 1 ./ Rwheel(expectedMask);
expectedAlpha = zeros(4, 1);
expectedAlpha(expectedMask) = q / sum(q);
expectedTrack = sum(expectedAlpha(expectedMask) .* vxWheel(expectedMask));
expectedR = 1 / sum(q);
assert(wssValid, 'TEST9: NaN vxWheel should be filtered but still valid with other wheels.');
assert(alphaWheel(1) == 0, 'TEST9: NaN vxWheel must have zero alpha.');
assert(norm(alphaWheel - expectedAlpha, Inf) <= tol, 'TEST9: remaining weights mismatch.');
assert(abs(vxWssTrack - expectedTrack) <= tol, 'TEST9: vxWssTrack should ignore NaN vxWheel.');
assert(abs(RwssEquivalent - expectedR) <= tol, 'TEST9: equivalent variance mismatch.');

% TEST 10: Rwheel NaN/Inf invalidates its own wheel
% case A: NaN variance
vxWheel = [10; 20; 30; 40];
Rwheel = [1; NaN; 3; Inf];
validWheel = true(4, 1);
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
expectedMask = [true; false; true; false];
q = 1 ./ Rwheel(expectedMask);
expectedAlpha = zeros(4, 1);
expectedAlpha(expectedMask) = q / sum(q);
expectedTrack = sum(expectedAlpha(expectedMask) .* vxWheel(expectedMask));
expectedR = 1 / sum(q);
assert(wssValid, 'TEST10A: NaN/Inf Rwheel should not invalidate finite wheels.');
assert(alphaWheel(2) == 0 && alphaWheel(4) == 0, 'TEST10A: invalid-R wheels should have zero alpha.');
assert(norm(alphaWheel - expectedAlpha, Inf) <= tol, 'TEST10A: remaining weight mismatch.');
assert(abs(vxWssTrack - expectedTrack) <= tol, 'TEST10A: vxWssTrack mismatch.');
assert(abs(RwssEquivalent - expectedR) <= tol, 'TEST10A: equivalent variance mismatch.');

% TEST 11: all four invalid -> no forced fusion
vxWheel = [10; 20; 30; 40];
Rwheel = [4; 5; 6; 7];
validWheel = false(4, 1);
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(~wssValid, 'TEST11: all invalid must set wssValid=false.');
assert(isnan(vxWssTrack), 'TEST11: all invalid must return vxWssTrack=NaN.');
assert(all(alphaWheel == 0), 'TEST11: all invalid must have zero alpha.');
assert(RwssEquivalent == max(Rwheel), 'TEST11: fallback R must be bounded finite fallback value.');

% TEST 12: alpha sum check by validity branch
% 12a: valid branch sum 1
vxWheel = [10; 10; 10; 10];
Rwheel = [1; 2; 3; 4];
validWheel = [true; false; true; true];
[~, ~, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'TEST12a: valid branch should remain true.');
assert(abs(sum(alphaWheel) - 1) <= tol, 'TEST12a: alpha sum must be 1 when valid.');
% 12b: invalid branch sum 0
vxWheel = [10; 10; 10; 10];
Rwheel = [1; 2; 3; 4];
validWheel = false(4, 1);
[~, ~, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(~wssValid, 'TEST12b: invalid branch should be false.');
assert(sum(alphaWheel) == 0, 'TEST12b: alpha sum must be 0 when invalid.');

% Interface combo: FL invalid severe slip, three valid remain.
% This demonstrates residual-to-confidence-to-wss path and downstream gating.
p = make_test_params();
eSlip = [p.e_high; 0.02; 0.02; 0.02];
residualValid = true(4, 1);
validGeom = true(4, 1);
[rhoWheel, Rwheel, validWheel] = slip_confidence_mapping(eSlip, residualValid, validGeom, p);
assert(~validWheel(1), 'Combo1: FL hard-invalidated.');
assert(all(validWheel(2:4)), 'Combo1: remaining wheels valid.');
vxWheel = [30; 32; 34; 36];
[vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel);
assert(wssValid, 'Combo1: three-wheel valid set should keep wssValid=true.');
assert(alphaWheel(1) == 0, 'Combo1: FL alpha must be zero after hard isolation.');
assert(abs(sum(alphaWheel(2:4)) - 1) <= tol, 'Combo1: remaining alpha must renormalize to 1.');
assert(RwssEquivalent >= p.R_min && isfinite(RwssEquivalent), 'Combo1: RwssEquivalent should be finite and bounded.');

% Interface combo: all severely abnormal -> all invalid, downstream must gate.
eSlip = p.e_high * ones(4, 1);
[rhoWheel, ~, validWheel] = slip_confidence_mapping(eSlip, residualValid, validGeom, p);
[vxWssTrack, ~, alphaWheel, wssValid] = wss_track_builder([10; 10; 10; 10], 0.1 * ones(4, 1), validWheel);
assert(~any(validWheel), 'Combo2: all wheels should be invalid at e_high.');
assert(~wssValid, 'Combo2: all wheels invalid -> wssValid=false.');
assert(isnan(vxWssTrack), 'Combo2: do not use invalid vxWssTrack downstream.');
assert(sum(alphaWheel) == 0, 'Combo2: all alpha should be zero.');

% Explicitly document downstream gating requirement:
% when wssValid=false, vxWssTrack must not be sent into WSS measurement update.

end

function p = make_test_params()
p = estimator_default_params();
p.epsilon = 1e-8;
end
