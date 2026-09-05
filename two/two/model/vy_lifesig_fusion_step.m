function [Vy_LS, alpha_D, alpha_K, alpha_F, fusion_valid, ...
    fallback_active, last_valid_Vy_LS_next, has_last_valid_next, ...
    H_D, H_K, H_F] = ...
    vy_lifesig_fusion_step(Vy_D, update_valid_D, Vy_K, update_valid_K, ...
    Vy_F, propagation_age_steps, age_valid_F, reset, ...
    last_valid_Vy_LS, has_last_valid)
%VY_LIFESIG_FUSION_STEP Pure 100-Hz LifeSig fusion state transition.
% The caller owns the two memory values and feeds the returned next values
% into the following hit.  The mathematical transition is stateless.
%#codegen

assert_scalar_numeric(Vy_D,'Vy_D');
assert_flag(update_valid_D,'update_valid_D');
assert_scalar_numeric(Vy_K,'Vy_K');
assert_flag(update_valid_K,'update_valid_K');
assert_scalar_numeric(Vy_F,'Vy_F');
assert_scalar_numeric(propagation_age_steps,'propagation_age_steps');
assert_flag(age_valid_F,'age_valid_F');
assert_flag(reset,'reset');
assert_scalar_finite(last_valid_Vy_LS,'last_valid_Vy_LS');
assert_flag(has_last_valid,'has_last_valid');

Vy_D = double(Vy_D);
Vy_K = double(Vy_K);
Vy_F = double(Vy_F);
ageSteps = double(propagation_age_steps);

qD = 0.8426184093257221;
qK = 0.14643969744669255;
qF = 0.010941893227585452;
tauF = 28.252990189369939;
Ts = 0.01;

if double(reset) ~= 0
    memoryValue = 0;
    memoryValid = false;
else
    memoryValue = double(last_valid_Vy_LS);
    memoryValid = double(has_last_valid) ~= 0;
end

activeD = (double(update_valid_D) ~= 0) && isfinite(Vy_D);
activeK = (double(update_valid_K) ~= 0) && isfinite(Vy_K);
activeF = (double(age_valid_F) ~= 0) && isfinite(ageSteps) && ...
    ageSteps >= 0 && isfinite(Vy_F);

H_D = double(activeD);
H_K = double(activeK);
H_F = 0;
if activeF
    H_F = exp(-(ageSteps * Ts) / tauF);
end

scoreD = qD * H_D;
scoreK = qK * H_K;
scoreF = qF * H_F;
termD = 0;
termK = 0;
termF = 0;

if activeD
    termD = scoreD * Vy_D;
end
if activeK
    termK = scoreK * Vy_K;
end
if activeF
    termF = scoreF * Vy_F;
end

scoreSum = scoreD + scoreK + scoreF;
if isfinite(scoreSum) && scoreSum > 0
    alpha_D = scoreD / scoreSum;
    alpha_K = scoreK / scoreSum;
    alpha_F = scoreF / scoreSum;
    Vy_LS = (termD + termK + termF) / scoreSum;
    fusion_valid = 1;
    fallback_active = 0;
    last_valid_Vy_LS_next = Vy_LS;
    has_last_valid_next = 1;
else
    alpha_D = 0;
    alpha_K = 0;
    alpha_F = 0;
    if memoryValid
        Vy_LS = memoryValue;
    else
        Vy_LS = 0;
    end
    fusion_valid = 0;
    fallback_active = 1;
    last_valid_Vy_LS_next = memoryValue;
    has_last_valid_next = double(memoryValid);
end
end

function assert_scalar_numeric(value,name)
assert(isnumeric(value) && isreal(value) && isscalar(value), ...
    'vy_lifesig_fusion_step:InvalidScalar', ...
    '%s must be a real numeric scalar.',name);
end

function assert_scalar_finite(value,name)
assert_scalar_numeric(value,name);
assert(isfinite(value), ...
    'vy_lifesig_fusion_step:NonfiniteMemory', ...
    '%s must be finite.',name);
end

function assert_flag(value,name)
assert((isnumeric(value) || islogical(value)) && isreal(value) && ...
    isscalar(value) && isfinite(double(value)), ...
    'vy_lifesig_fusion_step:InvalidFlag', ...
    '%s must be a finite real logical-compatible scalar.',name);
end
