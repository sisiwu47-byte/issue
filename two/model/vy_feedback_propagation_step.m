function [Vy_F, P_F, diag_F] = vy_feedback_propagation_step( ...
    Vy_prev, P_prev, Ay_IMU, AVz_IMU, Vx_source, ...
    Vy_feedback_delayed, P_feedback_delayed, ...
    feedback_valid_delayed, reset, Ts, Vy_F0, P0_F, Q_F)
%VY_FEEDBACK_PROPAGATION_STEP Stateless scalar lateral-speed propagation.
%#codegen
%
% The feedback state, covariance, and valid flag supplied here have already
% passed through the mandatory one-sample delay at the integration boundary.
%
% diag_F ordering:
%   1: prop_term         [m/s^2]
%   2: deltaVy          [m/s]
%   3: feedbackApplied  [0 or 1]

assert_scalar_numeric(Vy_prev, 'Vy_prev');
assert_scalar_numeric(P_prev, 'P_prev');
assert_scalar_numeric(Ay_IMU, 'Ay_IMU');
assert_scalar_numeric(AVz_IMU, 'AVz_IMU');
assert_scalar_numeric(Vx_source, 'Vx_source');
assert_scalar_numeric(Vy_feedback_delayed, 'Vy_feedback_delayed');
assert_scalar_numeric(P_feedback_delayed, 'P_feedback_delayed');
assert_flag(feedback_valid_delayed, 'feedback_valid_delayed');
assert_flag(reset, 'reset');
assert_scalar_finite(Ts, 'Ts');
assert_scalar_finite(Vy_F0, 'Vy_F0');
assert_scalar_finite(P0_F, 'P0_F');
assert_scalar_finite(Q_F, 'Q_F');

Ts = double(Ts);
Vy_F0 = double(Vy_F0);
P0_F = double(P0_F);
Q_F = double(Q_F);

assert(Ts > 0, 'vy_feedback_propagation_step:InvalidTs', ...
    'Ts must be positive.');
assert(P0_F > 0, 'vy_feedback_propagation_step:InvalidP0', ...
    'P0_F must be positive.');
assert(Q_F >= 0, 'vy_feedback_propagation_step:InvalidQ', ...
    'Q_F must be nonnegative.');

resetActive = double(reset) ~= 0;
if resetActive
    Vy_F = Vy_F0;
    P_F = P0_F;
    diag_F = zeros(3,1);
    return
end

assert_scalar_finite(Ay_IMU, 'Ay_IMU');
assert_scalar_finite(AVz_IMU, 'AVz_IMU');
assert_scalar_finite(Vx_source, 'Vx_source');

feedbackApplied = double(feedback_valid_delayed) ~= 0;
if feedbackApplied
    assert_scalar_finite(Vy_feedback_delayed, 'Vy_feedback_delayed');
    assert_scalar_finite(P_feedback_delayed, 'P_feedback_delayed');
    assert(double(P_feedback_delayed) >= 0, ...
        'vy_feedback_propagation_step:InvalidFeedbackCovariance', ...
        'P_feedback_delayed must be nonnegative when feedback is valid.');
    Vy_base = double(Vy_feedback_delayed);
    P_base = double(P_feedback_delayed);
else
    assert_scalar_finite(Vy_prev, 'Vy_prev');
    assert_scalar_finite(P_prev, 'P_prev');
    assert(double(P_prev) >= 0, ...
        'vy_feedback_propagation_step:InvalidPreviousCovariance', ...
        'P_prev must be nonnegative in standalone propagation.');
    Vy_base = double(Vy_prev);
    P_base = double(P_prev);
end

prop_term = double(Ay_IMU) - double(AVz_IMU)*double(Vx_source);
deltaVy = Ts*prop_term;

Vy_F = Vy_base + deltaVy;
P_F = P_base + Q_F;
diag_F = [prop_term; deltaVy; double(feedbackApplied)];
end

function assert_scalar_numeric(value, name)
assert(isnumeric(value) && isreal(value) && isscalar(value), ...
    'vy_feedback_propagation_step:InvalidScalar', ...
    '%s must be a real numeric scalar.', name);
end

function assert_scalar_finite(value, name)
assert_scalar_numeric(value, name);
assert(isfinite(value), ...
    'vy_feedback_propagation_step:NonfiniteInput', ...
    '%s must be finite when used.', name);
end

function assert_flag(value, name)
assert((isnumeric(value) || islogical(value)) && isreal(value) && ...
    isscalar(value) && isfinite(double(value)), ...
    'vy_feedback_propagation_step:InvalidFlag', ...
    '%s must be a finite scalar flag.', name);
end
