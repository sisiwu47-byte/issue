function Vy_FW = vy_fixed_weight_fusion_step( ...
    Vy_D, Vy_K, Vy_F, alpha_D, alpha_K, alpha_F)
%VY_FIXED_WEIGHT_FUSION_STEP Stateless three-track state combination.
%#codegen

weightSumTolerance = 1e-12;

assert_state(Vy_D,'Vy_D');
assert_state(Vy_K,'Vy_K');
assert_state(Vy_F,'Vy_F');
assert_weight(alpha_D,'alpha_D');
assert_weight(alpha_K,'alpha_K');
assert_weight(alpha_F,'alpha_F');

Vy_D = double(Vy_D);
Vy_K = double(Vy_K);
Vy_F = double(Vy_F);
alpha_D = double(alpha_D);
alpha_K = double(alpha_K);
alpha_F = double(alpha_F);

assert(alpha_D >= 0 && alpha_K >= 0 && alpha_F >= 0, ...
    'vy_fixed_weight_fusion_step:NegativeWeight', ...
    'alpha_D, alpha_K, and alpha_F must be nonnegative.');

alphaSum = alpha_D + alpha_K + alpha_F;
assert(abs(alphaSum-1) <= weightSumTolerance, ...
    'vy_fixed_weight_fusion_step:InvalidWeightSum', ...
    'alpha_D + alpha_K + alpha_F must equal one within 1e-12.');

Vy_FW = alpha_D*Vy_D + alpha_K*Vy_K + alpha_F*Vy_F;
assert(isfinite(Vy_FW), ...
    'vy_fixed_weight_fusion_step:NonfiniteOutput', ...
    'The fixed-weight state combination must be finite.');
end

function assert_state(value,name)
assert(isnumeric(value) && isreal(value) && isscalar(value), ...
    'vy_fixed_weight_fusion_step:InvalidState', ...
    '%s must be a real numeric scalar.',name);
assert(isfinite(value), ...
    'vy_fixed_weight_fusion_step:NonfiniteState', ...
    '%s must be finite.',name);
end

function assert_weight(value,name)
assert(isnumeric(value) && isreal(value) && isscalar(value), ...
    'vy_fixed_weight_fusion_step:InvalidWeight', ...
    '%s must be a real numeric scalar.',name);
assert(isfinite(value), ...
    'vy_fixed_weight_fusion_step:NonfiniteWeight', ...
    '%s must be finite.',name);
end
