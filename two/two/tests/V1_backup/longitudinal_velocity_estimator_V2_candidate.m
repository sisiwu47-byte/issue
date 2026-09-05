function est_y = longitudinal_velocity_estimator(est_u)
%LONGITUDINAL_VELOCITY_ESTIMATOR Top-level 100-Hz longitudinal speed estimator.
%   STAGE-2 freeze interface (est_u(18)):
%     [wheelOmega(4); wheelAngle(4); Ax, Ay, Az, AVx, AVy, AVz; ...; reset]
%     Output est_y(38,1) follows STAGE_2_FORMULA_MAP and signal_interface.
%
%   Persistent state keeps cross-cycle recursion only; no duplicate wheel FIFO
%   or WSS confidence FIFO logic is reimplemented here.

if nargin ~= 1
    error('longitudinal_velocity_estimator:InvalidInputCount', ...
        'Expected one input argument est_u.');
end

est_u = est_u(:);
if numel(est_u) < 18
    error('longitudinal_velocity_estimator:InvalidInputSize', ...
        'est_u must contain at least 18 elements.');
end

persistent initialized
persistent pCfg

persistent vxFusedPrev
persistent xWPrev
persistent PWPrev
persistent xIPrev
persistent PIPrev
persistent PWI_prev
persistent axCorrPrev
persistent lastFiniteVx
persistent PfusedPrev
persistent allWheelInvalidDuration
persistent updateCounter
persistent degradedMode
persistent updatePhase
persistent yHold
persistent wheelLocked
persistent wheelRecoverCount

if isempty(pCfg)
    % All parameters are explicitly defined in estimator_default_params().
    % Keeping the struct shape fixed avoids MATLAB Coder errors caused by
    % adding fields after a struct has already been created/used.
    pCfg = estimator_default_params();
end
p = pCfg;

% Stage-2 fixed inputs.
wheelOmega = est_u(1:4);
wheelAngle = est_u(5:8);

Ax  = est_u(9);
Ay  = est_u(10); %#ok<NASGU>
Az  = est_u(11); %#ok<NASGU>
AVx = est_u(12); %#ok<NASGU>
AVy = est_u(13); %#ok<NASGU>
yawRateZ = est_u(14);   % AVz

resetFlag = est_u(18);
resetRequested = isfinite(resetFlag) && (resetFlag ~= 0);

vyPrior = 0;            % Stage 1 fixed in this phase

% Initialize one-time persistent states.
if isempty(initialized)
    initialized = false;
end
if isempty(vxFusedPrev)
    vxFusedPrev = 0;
end
if isempty(xWPrev)
    xWPrev = 0;
end
if isempty(PWPrev)
    PWPrev = p.PW0;
end
if isempty(xIPrev)
    xIPrev = 0;
end
if isempty(PIPrev)
    PIPrev = p.PI0;
end
if isempty(PWI_prev)
    PWI_prev = p.PWI0;
end
if isempty(axCorrPrev)
    axCorrPrev = 0;
end
if isempty(lastFiniteVx)
    lastFiniteVx = 0;
end
if isempty(PfusedPrev)
    PfusedPrev = max([p.PW0, p.PI0, 1e-12]);
end
if isempty(allWheelInvalidDuration)
    allWheelInvalidDuration = 0;
end
if isempty(updateCounter)
    updateCounter = 0;
end
if isempty(degradedMode)
    degradedMode = false;
end
if isempty(updatePhase)
    updatePhase = 0;
end
if isempty(yHold)
    yHold = NaN(38, 1);
end
if isempty(wheelLocked)
    wheelLocked = false(4, 1);
end
if isempty(wheelRecoverCount)
    wheelRecoverCount = zeros(4, 1);
end

% ----- Reset/initialization -----
% A non-finite reset flag (NaN/Inf) should not repeatedly force reinitialization.
needReset = (~initialized) || resetRequested;
if needReset
    wheelSpeedInit = p.Rw * wheelOmega(:);
    finiteInit = wheelSpeedInit(isfinite(wheelSpeedInit));
    if ~isempty(finiteInit)
        vx0 = median(finiteInit);
    else
        % Stage-2 protection when wheel-only initialization is unavailable.
        vx0 = 0;
    end

    vxFusedPrev = finite_or_default(vx0, 0);
    xWPrev = vxFusedPrev;
    xIPrev = vxFusedPrev;
    PWPrev = p.PW0;
    PIPrev = p.PI0;
    PWI_prev = p.PWI0;
    lastFiniteVx = finite_or_default(vxFusedPrev, 0);
    allWheelInvalidDuration = 0;
    degradedMode = false;
    initialized = true;
    updateCounter = 0;
    updatePhase = 0;
    yHold = NaN(38, 1);
    PfusedPrev = max([p.PW0, p.PI0, 1e-12]);
    PWI_prev = p.PWI0;
    wheelLocked = false(4, 1);
    wheelRecoverCount = zeros(4, 1);

    if isfinite(Ax) && isfinite(yawRateZ)
        axCorrPrev = Ax + yawRateZ * vyPrior;
    else
        axCorrPrev = 0;
    end
end

% Gate every 10 ms = 100 Hz when estimator is invoked at 1 kHz.
updateEvery = 10;
if updatePhase < 0 || ~isfinite(updatePhase)
    updatePhase = 0;
end

% Reset calls run a single refresh step but are not counted as updates.
doResetWork = needReset;
doScheduledUpdate = (~needReset) && (updatePhase == 0);
doEstimatorStep = doResetWork || doScheduledUpdate;

if doResetWork
    updatePhase = 0;
elseif doScheduledUpdate
    % After a true update, wait 9 more 1ms ticks before next update.
    updatePhase = updateEvery - 1;
else
    updatePhase = updatePhase - 1;
    if updatePhase < 0
        updatePhase = updateEvery - 1;
    end
end

if doEstimatorStep

    % ----- STEP 2: wheel candidate ----
    [vxWheel, validGeom] = four_wheel_kinematic_speed(wheelOmega, wheelAngle, yawRateZ, vyPrior, p);

    % ----- STEP 3: finite window IMU/WSS consistency ----
    [eSlip, ~, ~, ~, slipReady, residualValid, ...
        LifeSig_IMU, ~, ~] = ...
        window_delta_velocity_indicator(Ax, yawRateZ, vyPrior, vxWheel, validGeom, needReset, p);

    % ----- STEP 4: IMU local speed candidate (pure 100Hz-cycle computation) ----
    if isfinite(Ax) && isfinite(yawRateZ) && isfinite(vyPrior)
        axCorrCurrent = Ax + yawRateZ * vyPrior;
    else
        axCorrCurrent = 0;
    end

    if needReset
        dvImuStep = 0;
    else
        dvImuStep = 0.5 * p.Ts_est * (axCorrPrev + axCorrCurrent);
    end

    vxImuTrack = vxFusedPrev + dvImuStep;
    axCorrPrev = axCorrCurrent;

    % ----- STEP 5: confidence / measurement variance ----
    eAbs = abs(vxWheel - vxImuTrack);
    [rhoRaw, Rwheel, validWheel, rhoDelta, rhoAbs] = ...
        slip_confidence_mapping( ...
            eSlip, ...
            residualValid, ...
            validGeom, ...
            p, ...
            eAbs);

    wheelRecoverN = round(p.Nrecover);
    if ~isfinite(wheelRecoverN) || wheelRecoverN <= 0
        wheelRecoverN = 1;
    end

    severeSlip = (rhoDelta <= p.rho_hard) | (rhoAbs <= p.rho_hard);
    if doEstimatorStep && ~doResetWork
        for i = 1:4
            if residualValid(i) && validGeom(i) && severeSlip(i)
                wheelLocked(i) = true;
                wheelRecoverCount(i) = 0;
            end

            if wheelLocked(i)
                if residualValid(i) && validGeom(i) && ...
                        isfinite(eSlip(i)) && ...
                        isfinite(eAbs(i)) && ...
                        (eSlip(i) < p.eDelta_recover) && ...
                        (eAbs(i) < p.eAbs_recover)
                    wheelRecoverCount(i) = wheelRecoverCount(i) + 1;
                    if wheelRecoverCount(i) >= wheelRecoverN
                        wheelLocked(i) = false;
                        wheelRecoverCount(i) = 0;
                    end
                else
                    wheelRecoverCount(i) = 0;
                end
            end
        end
    end

    rhoWheel = rhoRaw;
    if doEstimatorStep
        for i = 1:4
            if wheelLocked(i)
                rhoWheel(i) = 0;
                Rwheel(i) = p.R_max;
                validWheel(i) = false;
            end
        end
    end

    % Keep rhoWheel/Rwheel/validWheel synchronized with final lock state.
    validWheel = validWheel & (rhoWheel > p.rho_hard);

    % ----- STEP 6: WSS internal fusion ----
    [vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = ...
        wss_track_builder(vxWheel, Rwheel, validWheel);

    % ----- STEP 7: IMU validity ----
    R_Ax_used = p.R_Ax;
    if ~isfinite(R_Ax_used) || R_Ax_used <= 0
        R_Ax_used = 1e-6;
    end

    R_imu_step = max([p.R_imuc_floor, Pfused_dynamic_noise_estimate(PfusedPrev, p.Ts_est, R_Ax_used)]);
    R_imu_step = max(R_imu_step, p.R_imuc);

    imuValid = LifeSig_IMU && isfinite(vxImuTrack) && isfinite(R_imu_step);

    % ----- STEP 8 / 9: local KFs ----
    [xW, PW, ~, ~, KW] = local_scalar_kf_step(xWPrev, PWPrev, vxWssTrack, RwssEquivalent, p.QW, wssValid, p);
    [xI, PI, ~, ~, KI] = local_scalar_kf_step(xIPrev, PIPrev, vxImuTrack, R_imu_step, p.QI, imuValid, p);

    % ----- STEP 10A: baseline/internal correlated fusion ----
    %
    % IMPORTANT:
    % vxFusedPrev is used on the NEXT estimator update to construct
    % vxImuTrack, which then participates in eAbs / confidence / wheelLocked.
    % Therefore the new top-level weight adaptation must NOT be fed back into
    % vxFusedPrev, otherwise changing the output fusion weights also changes
    % the slip detector itself.
    %
    % This baseline fusion is exactly the original V1 fusion and is used only
    % for internal recursion (vxFusedPrev, PfusedPrev, PWI_prev).
    [vxFusedInternal, PfusedInternal, ~, ~, ~, PWI_plus_internal, ~, ~, fusionValidInternal] = ...
        correlated_two_track_fusion( ...
            xW, PW, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p); %#ok<NASGU>

    % ----- STEP 10B: fusion-only WSS covariance adaptation ----
    %
    % PW remains the WSS local-KF covariance.
    % PW_fuse is used ONLY for the externally reported top-level fusion.
    % It is never fed back into:
    %   vxFusedPrev / PfusedPrev / PWI_prev / PWPrev / PIPrev.
    %
    % This makes the online implementation consistent with the previous
    % offline scan, where xW, xI, PW, PI and PWI were held fixed.
    PW_fuse = PW;

    if wssValid && imuValid && ...
            isfinite(PW) && (PW >= 0) && ...
            isfinite(PI) && (PI >= 0) && ...
            isfinite(xW) && isfinite(xI)

        % Overall WSS health. Invalid wheels contribute zero health.
        hWSum = 0;
        for i = 1:4
            rhoHealth_i = rhoWheel(i);

            if ~validWheel(i) || ~isfinite(rhoHealth_i)
                rhoHealth_i = 0;
            elseif rhoHealth_i < 0
                rhoHealth_i = 0;
            elseif rhoHealth_i > 1
                rhoHealth_i = 1;
            end

            hWSum = hWSum + rhoHealth_i;
        end

        hW = 0.25 * hWSum;
        if ~isfinite(hW)
            hW = 0;
        elseif hW < 0
            hW = 0;
        elseif hW > 1
            hW = 1;
        end

        % Disagreement between the two local speed tracks.
        dWIeff = abs(xW - xI);
        if ~isfinite(dWIeff)
            dWIeff = 0;
        elseif dWIeff > p.dWI_cap
            dWIeff = p.dWI_cap;
        end

        % Fusion-only WSS covariance:
        %   PW_fuse = PW
        %           + kD_fuse * dWIeff^2
        %           + kH_fuse * (1-hW)^2 * PI
        PW_candidate = ...
            PW + ...
            p.kD_fuse * dWIeff * dWIeff + ...
            p.kH_fuse * (1 - hW) * (1 - hW) * PI;

        % Numerical protection. Never make the fusion covariance smaller
        % than the original WSS local covariance.
        if isfinite(PW_candidate) && (PW_candidate >= PW)
            PW_fuse = PW_candidate;
        else
            PW_fuse = PW;
        end
    end

    % ----- STEP 10C: adapted top-level/output fusion ----
    [vxFused, Pfused, alphaW, alphaI, ~, ~, ~, condPhi, fusionValid] = ...
        correlated_two_track_fusion( ...
            xW, PW_fuse, KW, xI, PI, KI, PWI_prev, wssValid, imuValid, p);

    % ----- STEP 11: top-level fallback and degraded mode state ----
    allWheelInvalid = ~wssValid;

    if wssValid && imuValid
        % Case A
        vx_hat = vxFused;
        P_fused = Pfused;
        estimatorUpdated = 1;
    elseif (~wssValid) && imuValid
        % Case B
        vx_hat = xI;
        P_fused = PI;
        estimatorUpdated = 1;
    elseif wssValid && (~imuValid)
        % Case C
        vx_hat = xW;
        P_fused = PW;
        estimatorUpdated = 1;
    else
        % Case D: both channels invalid
        vx_hat = lastFiniteVx;
        P_fused = finite_or_default(PfusedPrev, max([PWPrev, PIPrev, p.PW0, p.PI0]));
        estimatorUpdated = 1;
    end
    if doResetWork
        estimatorUpdated = 0;
    end

    if ~isfinite(vx_hat)
        vx_hat = lastFiniteVx;
    end
    if ~isfinite(P_fused)
        P_fused = finite_or_default(PfusedPrev, max([PWPrev, PIPrev, p.PW0, p.PI0]));
    end

    if isfinite(vx_hat)
        lastFiniteVx = vx_hat;
    end

    if wssValid
        allWheelInvalidDuration = 0;
    elseif imuValid
        allWheelInvalidDuration = allWheelInvalidDuration + p.Ts_est;
    else
        % keep existing duration when both invalid
    end

    if needReset
        degradedMode = false;
    else
        if allWheelInvalid && imuValid
            degradedMode = allWheelInvalidDuration > p.TimuOnlyMax;
        elseif allWheelInvalid && (~imuValid)
            degradedMode = true;
        else
            degradedMode = false;
        end
    end

    % ----- STEP 12: persist cross-cycle state ----
    %
    % External/output estimate:
    %   vx_hat / P_fused use the adapted top-level fusion.
    %
    % Internal recursion:
    %   keep the ORIGINAL V1 fusion so that the new output weighting cannot
    %   feed back into vxImuTrack -> eAbs -> rhoWheel -> wheelLocked.
    P_fused = finite_or_default(P_fused, max([p.PW0, p.PI0, 1e-12]));

    vxFusedPrev = finite_or_default( ...
        vxFusedInternal, ...
        finite_or_default(vxFusedPrev, 0));

    PfusedPrev = finite_or_default( ...
        PfusedInternal, ...
        finite_or_default(PfusedPrev, max([p.PW0, p.PI0, 1e-12])));

    xWPrev = finite_or_default(xW, finite_or_default(xWPrev, vxFusedPrev));
    PWPrev = finite_or_default(PW, max([p.PW0, 1e-12]));
    xIPrev = finite_or_default(xI, finite_or_default(xIPrev, vxFusedPrev));
    PIPrev = finite_or_default(PI, max([p.PI0, 1e-12]));

    % PWI is the cross-covariance of the two LOCAL tracks, so persist the
    % baseline/local-track value, not an effective-covariance variant.
    PWI_prev = finite_or_default(PWI_plus_internal, p.PWI0);

    if doScheduledUpdate
        updateCounter = updateCounter + 1;
    end

    % ----- Build fixed-stage output vector ----
    yHold(1)  = finite_or_default(vx_hat, 0);
    yHold(2)  = finite_or_default(P_fused, max([p.PW0, p.PI0]));
    yHold(3)  = xW;
    yHold(4)  = PW;
    yHold(5)  = xI;
    yHold(6)  = PI;
    yHold(7)  = finite_or_default(PWI_plus_internal, 0);
    yHold(8:11)  = vxWheel;
    yHold(12:15) = eSlip;
    yHold(16:19) = rhoWheel;
    yHold(20:23) = Rwheel;
    yHold(24:27) = double(validWheel);
    yHold(28) = double(wssValid);
    yHold(29) = double(imuValid);
    yHold(30:31) = [alphaW; alphaI];
    yHold(32) = double(allWheelInvalid);
    yHold(33) = allWheelInvalidDuration;
    yHold(34) = double(degradedMode);
    yHold(35) = double(estimatorUpdated);
    yHold(36) = double(slipReady);
    yHold(37) = condPhi;
    yHold(38) = updateCounter;
    est_y = yHold;

else
    % Hold non-update cycles with explicit keep-alive flags.
    yHold(35) = 0;
    yHold(38) = updateCounter;
    est_y = yHold;
end

end



function x = finite_or_default(v, x_default)
%FINITE_OR_DEFAULT finite-safe fallback.
if isfinite(v)
    x = v;
else
    x = x_default;
end
end


function R_imu = Pfused_dynamic_noise_estimate(Pfused_prev, Ts, R_Ax)
%PFAUSED_DYNAMIC_NOISE_ESTIMATE top-level dynamic IMU noise term.
if ~isfinite(Pfused_prev)
    Pfused_prev = 0;
end
if ~isfinite(Ts) || Ts <= 0
    Ts = 0.01;
end
if ~isfinite(R_Ax) || R_Ax <= 0
    R_Ax = 1e-6;
end
R_imu = Pfused_prev + (Ts^2 / 2) * R_Ax;
end
