function p = estimator_default_params()
%ESTIMATOR_DEFAULT_PARAMS
% Return fixed longitudinal speed estimator parameters.
%
% All fields used by the estimator are explicitly defined here so that
% the struct shape is fixed for MATLAB Coder / Simulink blocks.

%% =========================================================
% Timing / window
% ==========================================================

p.Ts_est = 0.01;

p.Twindow = 0.5;

p.Nwindow = 50;

p.accelSanityMax = 50;     % m/s^2

p.TimuOnlyMax = 1.0;


%% =========================================================
% Vehicle geometry
% ==========================================================

p.Rw = 0.393;

p.a = 1.18;

p.b = 1.77;

p.d = 1.575;


%% =========================================================
% Increment-consistency confidence
% ==========================================================

p.e_low = 0.15;

p.e_high = 0.50;

p.rho_hard = 0.05;


%% =========================================================
% Absolute-consistency + lock recovery
% ==========================================================

p.eAbs_low = 0.15;

p.eAbs_high = 0.50;

p.eDelta_recover = 0.12;

p.eAbs_recover = 0.12;

p.Nrecover = 30;


%% =========================================================
% Wheel measurement covariance mapping
% ==========================================================

p.epsilon = 1e-8;

p.R0 = 1e-4;

p.R_min = 1e-6;

p.R_max = 1e4;


%% =========================================================
% Geometry / low-speed protection
% ==========================================================

p.cos_delta_min = 0.20;

p.v_low = 0.30;


%% =========================================================
% Local KF process / initial covariance
% ==========================================================

p.QW = 1.0e-4;

p.QI = 2.0e-3;
p.PW0 = 1.0e-4;

p.PI0 = 1.0e-4;

p.PWI0 = 0.0;


%% =========================================================
% IMU acceleration measurement-noise variance
%
% Current sensor model:
%
% sigmaAxWhite = 0.0392 m/s^2
%
% Therefore:
%
% R_Ax = sigmaAxWhite^2
%      = 0.00153664 (m/s^2)^2
%
% IMPORTANT:
% R_Ax must be defined BEFORE the RAx alias.
% ==========================================================

p.R_Ax = 1.53664e-3;
p.R_Ax = 1.248708981650e-3;

% Compatibility alias.
%
% Keep this only because some existing helper functions/tests may still
% reference p.RAx.
%
% IMPORTANT:
% p.R_Ax must already exist before this line.

p.RAx = p.R_Ax;


%% =========================================================
% IMU local-track measurement covariance protection
% ==========================================================

p.R_imuc_floor = 1.0e-8;

% Temporarily remove the old 1e-3 hard floor so that the
% accumulated independent IMU uncertainty can actually influence
% R_imu_step.

p.R_imuc = 1.0e-8;


%% =========================================================
% Numerical protection
% ==========================================================

p.denomEps = 1e-12;

p.P_min = 1e-12;

p.Pfused_min = 1e-12;

p.pwi_epsilon = 1e-12;


%% =========================================================
% Legacy / fusion parameters
%
% NOTE:
% Your current longitudinal_velocity_estimator.m still hard-codes
%
%   a0 = 0.10
%   a1 = 2.706246
%   kA = 70
%   kH = 60
%
% inside STEP 10B.
%
% Therefore the following fields currently do NOT determine those
% four final fusion parameters unless another helper function uses them.
% They are retained for interface compatibility.
% ==========================================================

p.kD_fuse = 0.08;

p.kH_fuse = 1.00;

p.dWI_cap = 0.50;          % m/s


%% =========================================================
% Consistency checks
% ==========================================================

if ~(isscalar(p.Ts_est) && ...
        isfinite(p.Ts_est) && ...
        p.Ts_est > 0)

    error( ...
        'estimator_default_params:InvalidTs', ...
        'Ts_est must be a finite scalar > 0.');

end


if ~(isscalar(p.Twindow) && ...
        isfinite(p.Twindow) && ...
        p.Twindow > 0)

    error( ...
        'estimator_default_params:InvalidTwindow', ...
        'Twindow must be a finite scalar > 0.');

end


if ~isequal( ...
        p.Nwindow, ...
        round(p.Twindow / p.Ts_est))

    error( ...
        'estimator_default_params:InvalidNwindow', ...
        'Nwindow must equal round(Twindow/Ts_est).');

end


if ~(isscalar(p.accelSanityMax) && ...
        isfinite(p.accelSanityMax) && ...
        p.accelSanityMax > 0)

    error( ...
        'estimator_default_params:InvalidAccelSanityMax', ...
        'accelSanityMax must be a finite scalar > 0.');

end


if ~(isscalar(p.TimuOnlyMax) && ...
        isfinite(p.TimuOnlyMax) && ...
        p.TimuOnlyMax > 0)

    error( ...
        'estimator_default_params:InvalidTimuOnlyMax', ...
        'TimuOnlyMax must be a finite scalar > 0.');

end


%% =========================================================
% Vehicle geometry checks
% ==========================================================

if ~(isscalar(p.Rw) && ...
        isfinite(p.Rw) && ...
        p.Rw > 0)

    error( ...
        'estimator_default_params:InvalidRw', ...
        'Rw must be a finite scalar > 0.');

end


if ~(isscalar(p.a) && ...
        isfinite(p.a) && ...
        p.a > 0)

    error( ...
        'estimator_default_params:InvalidA', ...
        'a must be a finite scalar > 0.');

end


if ~(isscalar(p.b) && ...
        isfinite(p.b) && ...
        p.b > 0)

    error( ...
        'estimator_default_params:InvalidB', ...
        'b must be a finite scalar > 0.');

end


if ~(isscalar(p.d) && ...
        isfinite(p.d) && ...
        p.d > 0)

    error( ...
        'estimator_default_params:InvalidD', ...
        'd must be a finite scalar > 0.');

end


%% =========================================================
% Confidence checks
% ==========================================================

if ~(isscalar(p.e_low) && ...
        isfinite(p.e_low))

    error( ...
        'estimator_default_params:InvalidElow', ...
        'e_low must be finite.');

end


if ~(isscalar(p.e_high) && ...
        isfinite(p.e_high) && ...
        p.e_high > p.e_low)

    error( ...
        'estimator_default_params:InvalidEhigh', ...
        'e_high must be finite and > e_low.');

end


if ~(isscalar(p.rho_hard) && ...
        isfinite(p.rho_hard) && ...
        p.rho_hard >= 0 && ...
        p.rho_hard <= 1)

    error( ...
        'estimator_default_params:InvalidRho', ...
        'rho_hard must be in [0,1].');

end


if ~(isscalar(p.eAbs_low) && ...
        isfinite(p.eAbs_low) && ...
        p.eAbs_low >= 0)

    error( ...
        'estimator_default_params:InvalidEabsLow', ...
        'eAbs_low must be finite and >= 0.');

end


if ~(isscalar(p.eAbs_high) && ...
        isfinite(p.eAbs_high) && ...
        p.eAbs_high > p.eAbs_low)

    error( ...
        'estimator_default_params:InvalidEabsHigh', ...
        'eAbs_high must be finite and > eAbs_low.');

end


if ~(isscalar(p.eDelta_recover) && ...
        isfinite(p.eDelta_recover) && ...
        p.eDelta_recover >= 0)

    error( ...
        'estimator_default_params:InvalidEDeltaRecover', ...
        'eDelta_recover must be finite and >= 0.');

end


if ~(isscalar(p.eAbs_recover) && ...
        isfinite(p.eAbs_recover) && ...
        p.eAbs_recover >= 0)

    error( ...
        'estimator_default_params:InvalidEAbsRecover', ...
        'eAbs_recover must be finite and >= 0.');

end


if ~(isscalar(p.Nrecover) && ...
        isfinite(p.Nrecover) && ...
        p.Nrecover > 0 && ...
        p.Nrecover == round(p.Nrecover))

    error( ...
        'estimator_default_params:InvalidNrecover', ...
        'Nrecover must be a positive integer.');

end


%% =========================================================
% Wheel measurement covariance checks
% ==========================================================

if ~(isscalar(p.epsilon) && ...
        isfinite(p.epsilon) && ...
        p.epsilon > 0)

    error( ...
        'estimator_default_params:InvalidEpsilon', ...
        'epsilon must be a finite scalar > 0.');

end


if ~(isscalar(p.R0) && ...
        isfinite(p.R0) && ...
        p.R0 > 0)

    error( ...
        'estimator_default_params:InvalidR0', ...
        'R0 must be a finite scalar > 0.');

end


if ~(isscalar(p.R_min) && ...
        isfinite(p.R_min) && ...
        p.R_min > 0)

    error( ...
        'estimator_default_params:InvalidRmin', ...
        'R_min must be a finite scalar > 0.');

end


if ~(isscalar(p.R_max) && ...
        isfinite(p.R_max) && ...
        p.R_max >= p.R_min)

    error( ...
        'estimator_default_params:InvalidRmax', ...
        'R_max must be finite and >= R_min.');

end


%% =========================================================
% Geometry protection checks
% ==========================================================

if ~(isscalar(p.cos_delta_min) && ...
        isfinite(p.cos_delta_min) && ...
        p.cos_delta_min >= 0 && ...
        p.cos_delta_min <= 1)

    error( ...
        'estimator_default_params:InvalidCosDeltaMin', ...
        'cos_delta_min must be in [0,1].');

end


if ~(isscalar(p.v_low) && ...
        isfinite(p.v_low) && ...
        p.v_low > 0)

    error( ...
        'estimator_default_params:InvalidVlow', ...
        'v_low must be a finite scalar > 0.');

end


%% =========================================================
% KF covariance checks
% ==========================================================

if ~(isscalar(p.QW) && ...
        isfinite(p.QW) && ...
        p.QW > 0)

    error( ...
        'estimator_default_params:InvalidQW', ...
        'QW must be a finite scalar > 0.');

end


if ~(isscalar(p.QI) && ...
        isfinite(p.QI) && ...
        p.QI > 0)

    error( ...
        'estimator_default_params:InvalidQI', ...
        'QI must be a finite scalar > 0.');

end


if ~(isscalar(p.PW0) && ...
        isfinite(p.PW0) && ...
        p.PW0 > 0)

    error( ...
        'estimator_default_params:InvalidPW0', ...
        'PW0 must be a finite scalar > 0.');

end


if ~(isscalar(p.PI0) && ...
        isfinite(p.PI0) && ...
        p.PI0 > 0)

    error( ...
        'estimator_default_params:InvalidPI0', ...
        'PI0 must be a finite scalar > 0.');

end


if ~(isscalar(p.PWI0) && ...
        isfinite(p.PWI0) && ...
        p.PWI0 >= 0)

    error( ...
        'estimator_default_params:InvalidPWI0', ...
        'PWI0 must be finite and >= 0.');

end


%% =========================================================
% IMU covariance checks
% ==========================================================

if ~(isscalar(p.R_Ax) && ...
        isfinite(p.R_Ax) && ...
        p.R_Ax > 0)

    error( ...
        'estimator_default_params:InvalidRAx', ...
        'R_Ax must be a finite scalar > 0.');

end


if ~(isscalar(p.RAx) && ...
        isfinite(p.RAx) && ...
        p.RAx > 0)

    error( ...
        'estimator_default_params:InvalidRAxAlias', ...
        'RAx must be a finite scalar > 0.');

end


if ~(isscalar(p.R_imuc) && ...
        isfinite(p.R_imuc) && ...
        p.R_imuc > 0)

    error( ...
        'estimator_default_params:InvalidRimuc', ...
        'R_imuc must be a finite scalar > 0.');

end


if ~(isscalar(p.R_imuc_floor) && ...
        isfinite(p.R_imuc_floor) && ...
        p.R_imuc_floor > 0)

    error( ...
        'estimator_default_params:InvalidRimucFloor', ...
        'R_imuc_floor must be a finite scalar > 0.');

end


%% =========================================================
% Numerical checks
% ==========================================================

if ~(isscalar(p.denomEps) && ...
        isfinite(p.denomEps) && ...
        p.denomEps > 0)

    error( ...
        'estimator_default_params:InvalidDenomEps', ...
        'denomEps must be a finite scalar > 0.');

end


if ~(isscalar(p.P_min) && ...
        isfinite(p.P_min) && ...
        p.P_min > 0)

    error( ...
        'estimator_default_params:InvalidPmin', ...
        'P_min must be a finite scalar > 0.');

end


if ~(isscalar(p.Pfused_min) && ...
        isfinite(p.Pfused_min) && ...
        p.Pfused_min > 0)

    error( ...
        'estimator_default_params:InvalidPfusedMin', ...
        'Pfused_min must be a finite scalar > 0.');

end


if ~(isscalar(p.pwi_epsilon) && ...
        isfinite(p.pwi_epsilon) && ...
        p.pwi_epsilon > 0)

    error( ...
        'estimator_default_params:InvalidPwiEpsilon', ...
        'pwi_epsilon must be a finite scalar > 0.');

end


%% =========================================================
% Legacy fusion parameter checks
% ==========================================================

if ~(isscalar(p.kD_fuse) && ...
        isfinite(p.kD_fuse) && ...
        p.kD_fuse >= 0)

    error( ...
        'estimator_default_params:InvalidKDfuse', ...
        'kD_fuse must be finite and >= 0.');

end


if ~(isscalar(p.kH_fuse) && ...
        isfinite(p.kH_fuse) && ...
        p.kH_fuse >= 0)

    error( ...
        'estimator_default_params:InvalidKHfuse', ...
        'kH_fuse must be finite and >= 0.');

end


if ~(isscalar(p.dWI_cap) && ...
        isfinite(p.dWI_cap) && ...
        p.dWI_cap > 0)

    error( ...
        'estimator_default_params:InvalidDWIcap', ...
        'dWI_cap must be a finite scalar > 0.');

end

end