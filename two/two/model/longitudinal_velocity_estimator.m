function est_y = longitudinal_velocity_estimator(est_u)
%LONGITUDINAL_VELOCITY_ESTIMATOR
%
% Top-level longitudinal velocity estimator.
%
% External invocation:
%   1 kHz
%
% True estimator update:
%   100 Hz, Ts_est = 0.01 s
%
% Input:
%   est_u(18)
%
% Output:
%   est_y(38,1)
%
% IMPORTANT ARCHITECTURE
%
% 1) Detection IMU track:
%
%       vxImuTrackDetect
%
%    still uses the old architecture:
%
%       previous baseline fused speed + one-step IMU increment
%
%    and is used ONLY for:
%
%       eAbs
%       rhoWheel
%       wheelLocked
%
%
% 2) Fusion IMU track:
%
%       vxImuTrackFusion
%
%    is initialized ONCE from an available absolute-speed
%    reference and then propagated independently using
%    bias-corrected IMU acceleration.
%
%    It NEVER uses vxFusedPrev again after initialization.
%
%
% 3) kA/kH only modify the FINAL fusion effective WSS
%    covariance PW_fuse.
%
%    They do NOT modify:
%
%       WSS local KF
%       IMU local KF
%       wheel-slip detector
%

%% =========================================================
% 0. Input check
% ==========================================================

if nargin ~= 1
    error('longitudinal_velocity_estimator:InvalidInputCount', ...
        'Expected one input argument est_u.');
end

est_u = est_u(:);

if numel(est_u) < 18
    error('longitudinal_velocity_estimator:InvalidInputSize', ...
        'est_u must contain at least 18 elements.');
end


%% =========================================================
% Persistent parameters / states
% ==========================================================

persistent initialized
persistent pCfg

% Baseline fusion recursion
persistent vxFusedPrev
persistent PfusedPrev

% WSS local KF
persistent xWPrev
persistent PWPrev

% IMU local KF
persistent xIPrev
persistent PIPrev

% Local-track cross covariance
persistent PWI_prev

% Detection-only IMU acceleration memory
persistent axCorrPrev

% ---------------------------------------------------------
% Independent IMU fusion track
% ---------------------------------------------------------

persistent vxImuFusionPrev
persistent axImuFusionPrev
persistent PimuTrackPrev
persistent imuFusionInitialized

% ---------------------------------------------------------

persistent lastFiniteVx

persistent allWheelInvalidDuration
persistent updateCounter
persistent degradedMode
persistent updatePhase

persistent yHold

persistent wheelLocked
persistent wheelRecoverCount


%% =========================================================
% Parameters
% ==========================================================

if isempty(pCfg)
    pCfg = estimator_default_params();
end

p = pCfg;


%% =========================================================
% STEP 1: input unpacking
% ==========================================================

wheelOmega = est_u(1:4);
wheelAngle = est_u(5:8);

Ax = est_u(9);

Ay = est_u(10); %#ok<NASGU>
Az = est_u(11); %#ok<NASGU>

AVx = est_u(12); %#ok<NASGU>
AVy = est_u(13); %#ok<NASGU>

yawRateZ = est_u(14);

resetFlag = est_u(18);

resetRequested = ...
    isfinite(resetFlag) && ...
    (resetFlag ~= 0);

% Current longitudinal-only stage.
vyPrior = 0;


%% =========================================================
% One-time persistent initialization
% ==========================================================

if isempty(initialized)
    initialized = false;
end

if isempty(vxFusedPrev)
    vxFusedPrev = 0;
end

if isempty(PfusedPrev)
    PfusedPrev = max([p.PW0, p.PI0, 1e-12]);
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

% ---------------------------------------------------------
% Independent IMU states
% ---------------------------------------------------------

if isempty(vxImuFusionPrev)
    vxImuFusionPrev = 0;
end

if isempty(axImuFusionPrev)
    axImuFusionPrev = 0;
end

if isempty(PimuTrackPrev)
    PimuTrackPrev = max([p.PI0, 1e-12]);
end

if isempty(imuFusionInitialized)
    imuFusionInitialized = false;
end

% ---------------------------------------------------------

if isempty(lastFiniteVx)
    lastFiniteVx = 0;
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
    yHold = zeros(38,1);
end

if isempty(wheelLocked)
    wheelLocked = false(4,1);
end

if isempty(wheelRecoverCount)
    wheelRecoverCount = zeros(4,1);
end


%% =========================================================
% Reset / initialization
% ==========================================================

% =========================================================
% Reset request
% =========================================================

needReset = ...
    (~initialized) || ...
    resetRequested;


% =========================================================
% Reload parameters on reset
%
% IMPORTANT:
% During development/tuning, estimator_default_params.m may
% be modified between simulations.
%
% pCfg is persistent, so without this reload it can retain
% the parameter values from the previous simulation.
%
% Reload ONLY when reset occurs; do not reload every 1-kHz
% invocation.
% =========================================================

if needReset

    pCfg = ...
        estimator_default_params();

    p = ...
        pCfg;

end


% =========================================================
% Reset / initialization
% =========================================================

if needReset

    % Initial vehicle speed from wheel speed.
    %
    % p.Rw is wheel rolling radius.
    wheelSpeedInit = ...
        p.Rw * wheelOmega(:);

    finiteInit = ...
        wheelSpeedInit(isfinite(wheelSpeedInit));

    if ~isempty(finiteInit)

        vx0 = ...
            median(finiteInit);

    else

        vx0 = 0;

    end

    vx0 = ...
        finite_or_default( ...
            vx0, ...
            0);


    % -----------------------------------------------------
    % Baseline recursion
    % -----------------------------------------------------

    vxFusedPrev = ...
        vx0;

    PfusedPrev = ...
        max([ ...
            p.PW0, ...
            p.PI0, ...
            1e-12]);


    % -----------------------------------------------------
    % WSS local KF
    % -----------------------------------------------------

    xWPrev = ...
        vx0;

    PWPrev = ...
        p.PW0;


    % -----------------------------------------------------
    % IMU local KF
    % -----------------------------------------------------

    xIPrev = ...
        vx0;

    PIPrev = ...
        p.PI0;


    % -----------------------------------------------------
    % Cross covariance
    % -----------------------------------------------------

    PWI_prev = ...
        p.PWI0;


    % -----------------------------------------------------
    % Detection IMU memory
    % -----------------------------------------------------

    if isfinite(Ax) && ...
            isfinite(yawRateZ) && ...
            isfinite(vyPrior)

        axCorrPrev = ...
            Ax + ...
            yawRateZ * vyPrior;

    else

        axCorrPrev = 0;

    end


    % -----------------------------------------------------
    % Independent IMU track
    % -----------------------------------------------------

    vxImuFusionPrev = 0;

    axImuFusionPrev = 0;

    PimuTrackPrev = ...
        max([ ...
            p.PI0, ...
            1e-12]);

    imuFusionInitialized = ...
        false;


    % -----------------------------------------------------
    % Other states
    % -----------------------------------------------------

    lastFiniteVx = ...
        vx0;

    allWheelInvalidDuration = ...
        0;

    updateCounter = ...
        0;

    degradedMode = ...
        false;

    updatePhase = ...
        0;

    wheelLocked = ...
        false(4,1);

    wheelRecoverCount = ...
        zeros(4,1);

    yHold = ...
        zeros(38,1);

    initialized = ...
        true;

end


%% =========================================================
% 1 kHz -> 100 Hz update gate
% ==========================================================

updateEvery = 10;

if ~isfinite(updatePhase) || ...
        updatePhase < 0

    updatePhase = 0;

end

doResetWork = needReset;

doScheduledUpdate = ...
    (~needReset) && ...
    (updatePhase == 0);

doEstimatorStep = ...
    doResetWork || ...
    doScheduledUpdate;


% After reset refresh, wait full estimator period.

if doResetWork

    updatePhase = ...
        updateEvery - 1;

elseif doScheduledUpdate

    updatePhase = ...
        updateEvery - 1;

else

    updatePhase = ...
        updatePhase - 1;

    if updatePhase < 0

        updatePhase = ...
            updateEvery - 1;

    end

end


%% =========================================================
% True estimator 100-Hz step
% ==========================================================

if doEstimatorStep


    %% =====================================================
    % STEP 2: four-wheel kinematic speed
    % ======================================================

    [vxWheel, validGeom] = ...
        four_wheel_kinematic_speed( ...
            wheelOmega, ...
            wheelAngle, ...
            yawRateZ, ...
            vyPrior, ...
            p);


    %% =====================================================
    % STEP 3:
    % finite-window WSS/IMU consistency indicator
    % ======================================================

    [eSlip, ...
        ~, ...
        ~, ...
        ~, ...
        slipReady, ...
        residualValid, ...
        LifeSig_IMU, ...
        ~, ...
        ~] = ...
        window_delta_velocity_indicator( ...
            Ax, ...
            yawRateZ, ...
            vyPrior, ...
            vxWheel, ...
            validGeom, ...
            needReset, ...
            p);


    %% =====================================================
    % STEP 4:
    % detection-only IMU track
    % ======================================================

    imuAccelValid = ...
        isfinite(Ax) && ...
        isfinite(yawRateZ) && ...
        isfinite(vyPrior);

    if imuAccelValid

        axCorrCurrent = ...
            Ax + yawRateZ*vyPrior;

    else

        axCorrCurrent = 0;

    end


    if needReset || ...
            (~imuAccelValid)

        dvImuDetect = 0;

    else

        dvImuDetect = ...
            0.5 * p.Ts_est * ...
            (axCorrPrev + axCorrCurrent);

    end


    % Only for wheel-health detection.
    vxImuTrackDetect = ...
        vxFusedPrev + ...
        dvImuDetect;


    % Keep detector acceleration recursion.
    axCorrPrev = ...
        axCorrCurrent;


    %% =====================================================
    % STEP 5:
    % wheel confidence and measurement variance
    % ======================================================

    eAbs = ...
        abs(vxWheel - vxImuTrackDetect);


    [rhoRaw, ...
        Rwheel, ...
        validWheel, ...
        rhoDelta, ...
        rhoAbs] = ...
        slip_confidence_mapping( ...
            eSlip, ...
            residualValid, ...
            validGeom, ...
            p, ...
            eAbs);


    wheelRecoverN = ...
        round(p.Nrecover);

    if ~isfinite(wheelRecoverN) || ...
            wheelRecoverN <= 0

        wheelRecoverN = 1;

    end


    severeSlip = ...
        (rhoDelta <= p.rho_hard) | ...
        (rhoAbs   <= p.rho_hard);


    % -----------------------------------------------------
    % Hard lock + hysteresis recovery
    % -----------------------------------------------------

    if ~doResetWork

        for i = 1:4

            if residualValid(i) && ...
                    validGeom(i) && ...
                    severeSlip(i)

                wheelLocked(i) = true;

                wheelRecoverCount(i) = 0;

            end


            if wheelLocked(i)

                recoverCondition = ...
                    residualValid(i) && ...
                    validGeom(i) && ...
                    isfinite(eSlip(i)) && ...
                    isfinite(eAbs(i)) && ...
                    (eSlip(i) < p.eDelta_recover) && ...
                    (eAbs(i)  < p.eAbs_recover);

                if recoverCondition

                    wheelRecoverCount(i) = ...
                        wheelRecoverCount(i) + 1;

                    if wheelRecoverCount(i) >= ...
                            wheelRecoverN

                        wheelLocked(i) = false;

                        wheelRecoverCount(i) = 0;

                    end

                else

                    wheelRecoverCount(i) = 0;

                end

            end

        end

    end


    % -----------------------------------------------------
    % Apply final hard-lock state
    % -----------------------------------------------------

    rhoWheel = rhoRaw;

    for i = 1:4

        if wheelLocked(i)

            rhoWheel(i) = 0;

            Rwheel(i) = p.R_max;

            validWheel(i) = false;

        end

    end


    validWheel = ...
        validWheel & ...
        (rhoWheel > p.rho_hard);


    %% =====================================================
    % STEP 6:
    % WSS track builder
    %
    % zW = vxWssTrack
    % ======================================================

    [vxWssTrack, ...
        RwssEquivalent, ...
        ~, ...
        wssValid] = ...
        wss_track_builder( ...
            vxWheel, ...
            Rwheel, ...
            validWheel);


    %% =====================================================
    % STEP 6B:
    % independent bias-calibrated IMU track
    % ======================================================

    % A/E calibration result.
    %
    % If the IMU sensor model is changed, this value
    % must be recalibrated.

    biasAxCal = ...
        0.02178105;      % m/s^2


    if imuAccelValid

        axImuFusionCurrent = ...
            axCorrCurrent - ...
            biasAxCal;

    else

        axImuFusionCurrent = 0;

    end


    % -----------------------------------------------------
    % Actual acceleration-noise variance
    % -----------------------------------------------------

    R_Ax_used = p.R_Ax;

    if ~isfinite(R_Ax_used) || ...
            R_Ax_used <= 0

        R_Ax_used = 1e-6;

    end


    % -----------------------------------------------------
    % One-time absolute-speed initialization
    % -----------------------------------------------------

    if needReset || ...
            (~imuFusionInitialized)

        if wssValid && ...
                isfinite(vxWssTrack)

            vxImuTrackFusion = ...
                vxWssTrack;

            PimuTrack = ...
                max([ ...
                    RwssEquivalent, ...
                    p.PI0, ...
                    1e-12]);

            imuFusionInitialized = true;


        elseif isfinite(vxFusedPrev)

            % Initialization fallback only.
            %
            % After this initialization it will no longer
            % use vxFusedPrev.

            vxImuTrackFusion = ...
                vxFusedPrev;

            PimuTrack = ...
                max([ ...
                    PfusedPrev, ...
                    p.PI0, ...
                    1e-12]);

            imuFusionInitialized = true;


        else

            vxImuTrackFusion = 0;

            PimuTrack = ...
                max([p.PI0,1e-12]);

            imuFusionInitialized = false;

        end


        axImuFusionPrev = ...
            axImuFusionCurrent;


    else

        % -------------------------------------------------
        % Independent propagation
        % -------------------------------------------------

        if imuAccelValid

            dvImuFusion = ...
                0.5 * p.Ts_est * ...
                ( ...
                axImuFusionPrev + ...
                axImuFusionCurrent ...
                );


            vxImuTrackFusion = ...
                vxImuFusionPrev + ...
                dvImuFusion;


            % ---------------------------------------------
            % Approximate accumulated speed uncertainty.
            %
            % This preserves your current first-order
            % formulation:
            %
            % Var[dv]
            % ~= 0.5*Ts^2*R_Ax
            %
            % See discussion below: this should later be
            % refined if covariance accuracy is important.
            % ---------------------------------------------

            PimuTrack = ...
                PimuTrackPrev + ...
                0.5 * ...
                p.Ts_est^2 * ...
                R_Ax_used;


            axImuFusionPrev = ...
                axImuFusionCurrent;


        else

            % Invalid IMU sample:
            % do not propagate speed using fabricated Ax.

            vxImuTrackFusion = ...
                vxImuFusionPrev;

            PimuTrack = ...
                PimuTrackPrev;

            axImuFusionPrev = 0;

        end


        if ~isfinite(PimuTrack) || ...
                PimuTrack <= 0

            PimuTrack = ...
                max([ ...
                    PimuTrackPrev, ...
                    p.PI0, ...
                    1e-12]);

        end

    end


    %% =====================================================
    % STEP 7:
    % independent IMU validity / variance
    % ======================================================

    R_imu_step = ...
        max([ ...
            p.R_imuc_floor, ...
            p.R_imuc, ...
            PimuTrack]);


    % IMPORTANT:
    % There must be only ONE imuValid definition.
    %
    % Do NOT use the old vxImuTrack variable here.

    imuValid = ...
        LifeSig_IMU && ...
        imuAccelValid && ...
        imuFusionInitialized && ...
        isfinite(vxImuTrackFusion) && ...
        isfinite(R_imu_step) && ...
        (R_imu_step > 0);


    %% =====================================================
    % STEP 8:
    % WSS local KF
    % ======================================================

    [xW, ...
        PW, ...
        ~, ...
        ~, ...
        KW] = ...
        local_scalar_kf_step( ...
            xWPrev, ...
            PWPrev, ...
            vxWssTrack, ...
            RwssEquivalent, ...
            p.QW, ...
            wssValid, ...
            p);


    %% =====================================================
    % STEP 9:
    % independent IMU local KF
    % ======================================================

    [xI, ...
        PI, ...
        ~, ...
        ~, ...
        KI] = ...
        local_scalar_kf_step( ...
            xIPrev, ...
            PIPrev, ...
            vxImuTrackFusion, ...
            R_imu_step, ...
            p.QI, ...
            imuValid, ...
            p);


    %% =====================================================
    % STEP 10A:
    % baseline/internal correlated fusion
    % ======================================================

    [vxFusedInternal, ...
        PfusedInternal, ...
        ~, ...
        ~, ...
        ~, ...
        PWI_plus_internal, ...
        ~, ...
        ~, ...
        ~] = ...
        correlated_two_track_fusion( ...
            xW, ...
            PW, ...
            KW, ...
            xI, ...
            PI, ...
            KI, ...
            PWI_prev, ...
            wssValid, ...
            imuValid, ...
            p);


    %% =====================================================
    % STEP 10B:
    % fusion-only WSS effective-covariance adaptation
    %
    % Frozen values:
    %
    % a0 = 0.10
    % a1 = 2.706246
    % kA = 70
    % kH = 60
    % ======================================================

    PW_fuse = PW;

    a0_fuse = 0.10;
    a1_fuse = 2.706246;
    
    kA_fuse = 30.0;
    kH_fuse = 18.0;
    if wssValid && ...
            imuValid && ...
            isfinite(PW) && ...
            PW >= 0 && ...
            isfinite(PI) && ...
            PI >= 0


        % -------------------------------------------------
        % Dynamic term
        % -------------------------------------------------

        axFuse = axCorrCurrent;

        if ~isfinite(axFuse)
            axFuse = 0;
        end


        denA = ...
            a1_fuse - ...
            a0_fuse;


        if denA > 1e-12

            uA = ...
                (abs(axFuse)-a0_fuse) / ...
                denA;

            if uA < 0

                uA = 0;

            elseif uA > 1

                uA = 1;

            end

        else

            uA = 0;

        end


        sA = ...
            3*uA*uA - ...
            2*uA*uA*uA;


        % -------------------------------------------------
        % Wheel-health term
        % -------------------------------------------------

        hSum = 0;

        for i = 1:4

            if validWheel(i) && ...
                    isfinite(rhoWheel(i))

                rho_i = ...
                    rhoWheel(i);

                if rho_i < 0

                    rho_i = 0;

                elseif rho_i > 1

                    rho_i = 1;

                end

                hSum = ...
                    hSum + rho_i;

            end

        end


        hW = ...
            hSum / 4;


        if hW < 0

            hW = 0;

        elseif hW > 1

            hW = 1;

        end


        sH = ...
            (1-hW) * ...
            (1-hW);


        % -------------------------------------------------
        % Final WSS effective covariance
        % -------------------------------------------------

        inflateFactor = ...
            1 + ...
            kA_fuse*sA + ...
            kH_fuse*sH;


        PW_fuse_candidate = ...
            PW * ...
            inflateFactor;


        if isfinite(PW_fuse_candidate) && ...
                PW_fuse_candidate >= PW

            PW_fuse = ...
                PW_fuse_candidate;

        else

            PW_fuse = PW;

        end

    end


    %% =====================================================
    % STEP 10C:
    % final/output correlated fusion
    % ======================================================

    [vxFused, ...
        Pfused, ...
        alphaW, ...
        alphaI, ...
        ~, ...
        ~, ...
        ~, ...
        condPhi, ...
        ~] = ...
        correlated_two_track_fusion( ...
            xW, ...
            PW_fuse, ...
            KW, ...
            xI, ...
            PI, ...
            KI, ...
            PWI_prev, ...
            wssValid, ...
            imuValid, ...
            p);


    %% =====================================================
    % STEP 11:
    % final fallback
    % ======================================================

    allWheelInvalid = ...
        ~wssValid;


    if wssValid && imuValid

        vx_hat = vxFused;

        P_fused = Pfused;

        estimatorUpdated = 1;


    elseif (~wssValid) && imuValid

        vx_hat = xI;

        P_fused = PI;

        estimatorUpdated = 1;


    elseif wssValid && (~imuValid)

        vx_hat = xW;

        P_fused = PW;

        estimatorUpdated = 1;


    else

        vx_hat = ...
            lastFiniteVx;

        P_fused = ...
            finite_or_default( ...
                PfusedPrev, ...
                max([ ...
                    PWPrev, ...
                    PIPrev, ...
                    p.PW0, ...
                    p.PI0]));

        estimatorUpdated = 1;

    end


    if doResetWork

        estimatorUpdated = 0;

    end


    if ~isfinite(vx_hat)

        vx_hat = ...
            lastFiniteVx;

    end


    if ~isfinite(P_fused)

        P_fused = ...
            finite_or_default( ...
                PfusedPrev, ...
                max([ ...
                    PWPrev, ...
                    PIPrev, ...
                    p.PW0, ...
                    p.PI0]));

    end


    if isfinite(vx_hat)

        lastFiniteVx = ...
            vx_hat;

    end


    %% =====================================================
    % All-wheel-invalid duration
    % ======================================================

    if doResetWork

        allWheelInvalidDuration = 0;

    elseif wssValid

        allWheelInvalidDuration = 0;

    elseif imuValid

        allWheelInvalidDuration = ...
            allWheelInvalidDuration + ...
            p.Ts_est;

    else

        % keep previous duration

    end


    %% =====================================================
    % Degraded mode
    % ======================================================

    if needReset

        degradedMode = false;

    else

        if allWheelInvalid && ...
                imuValid

            degradedMode = ...
                allWheelInvalidDuration > ...
                p.TimuOnlyMax;

        elseif allWheelInvalid && ...
                (~imuValid)

            degradedMode = true;

        else

            degradedMode = false;

        end

    end


    %% =====================================================
    % STEP 12:
    % persist cross-cycle states
    % ======================================================

    P_fused = ...
        finite_or_default( ...
            P_fused, ...
            max([ ...
                p.PW0, ...
                p.PI0, ...
                1e-12]));


    % -----------------------------------------------------
    % Baseline fusion recursion
    % -----------------------------------------------------

    vxFusedPrev = ...
        finite_or_default( ...
            vxFusedInternal, ...
            finite_or_default( ...
                vxFusedPrev, ...
                0));


    PfusedPrev = ...
        finite_or_default( ...
            PfusedInternal, ...
            finite_or_default( ...
                PfusedPrev, ...
                max([ ...
                    p.PW0, ...
                    p.PI0, ...
                    1e-12])));


    % -----------------------------------------------------
    % WSS local KF
    % -----------------------------------------------------

    xWPrev = ...
        finite_or_default( ...
            xW, ...
            finite_or_default( ...
                xWPrev, ...
                vxFusedPrev));


    PWPrev = ...
        finite_or_default( ...
            PW, ...
            max([ ...
                p.PW0, ...
                1e-12]));


    % -----------------------------------------------------
    % IMU local KF
    %
    % IMPORTANT:
    % fallback no longer injects vxFusedPrev into the
    % independent IMU local track.
    % -----------------------------------------------------

    xIPrev = ...
        finite_or_default( ...
            xI, ...
            finite_or_default( ...
                xIPrev, ...
                vxImuTrackFusion));


    PIPrev = ...
        finite_or_default( ...
            PI, ...
            max([ ...
                p.PI0, ...
                1e-12]));


    % -----------------------------------------------------
    % Independent raw IMU track
    %
    % THIS is where current-cycle local variables must be
    % persisted.
    % -----------------------------------------------------

    if imuFusionInitialized && ...
            isfinite(vxImuTrackFusion)

        vxImuFusionPrev = ...
            vxImuTrackFusion;

    end


    if isfinite(PimuTrack) && ...
            PimuTrack > 0

        PimuTrackPrev = ...
            PimuTrack;

    end


    % -----------------------------------------------------
    % Local-track cross covariance
    % -----------------------------------------------------

    PWI_prev = ...
        finite_or_default( ...
            PWI_plus_internal, ...
            p.PWI0);


    if doScheduledUpdate

        updateCounter = ...
            updateCounter + 1;

    end


    %% =====================================================
    % STEP 13:
    % fixed 38-element output vector
    %
    % Temporary diagnostic mapping:
    %
    % y(7)  = zW
    % y(32) = RwssEquivalent
    % y(34) = KW
    % y(37) = QW
    % ======================================================

    yHold(1) = ...
        finite_or_default( ...
            vx_hat, ...
            0);


    yHold(2) = ...
        finite_or_default( ...
            P_fused, ...
            max([ ...
                p.PW0, ...
                p.PI0]));


    yHold(3) = ...
        finite_or_default( ...
            xW, ...
            vx_hat);


    yHold(4) = ...
        finite_or_default( ...
            PW, ...
            p.PW0);


    yHold(5) = ...
        finite_or_default( ...
            xI, ...
            vx_hat);


    yHold(6) = ...
        finite_or_default( ...
            PI, ...
            p.PI0);


    % zW
    yHold(7) = ...
        finite_or_default( ...
            vxWssTrack, ...
            xW);


    % wheel-speed candidates
    for i = 1:4

        yHold(7+i) = ...
            finite_or_default( ...
                vxWheel(i), ...
                0);

    end


    % slip indicators
    for i = 1:4

        yHold(11+i) = ...
            finite_or_default( ...
                eSlip(i), ...
                0);

    end


    % wheel confidence
    for i = 1:4

        yHold(15+i) = ...
            finite_or_default( ...
                rhoWheel(i), ...
                0);

    end


    % per-wheel R
    for i = 1:4

        yHold(19+i) = ...
            finite_or_default( ...
                Rwheel(i), ...
                p.R_max);

    end


    yHold(24:27) = ...
        double(validWheel(:));


    yHold(28) = ...
        double(wssValid);


    yHold(29) = ...
        double(imuValid);


    yHold(30) = ...
        finite_or_default( ...
            alphaW, ...
            0);


    yHold(31) = ...
        finite_or_default( ...
            alphaI, ...
            0);


    % actual WSS local-KF measurement variance
    yHold(32) = ...
        finite_or_default( ...
            RwssEquivalent, ...
            p.R_max);


    yHold(33) = ...
        finite_or_default( ...
            allWheelInvalidDuration, ...
            0);


    % WSS KF gain
    yHold(34) = ...
        finite_or_default( ...
            KW, ...
            0);


    % true 100-Hz update marker
    yHold(35) = ...
        double(estimatorUpdated);


    yHold(36) = ...
        double(slipReady);


    % WSS KF Q
    yHold(37) = ...
        finite_or_default( ...
            p.QW, ...
            0);


    yHold(38) = ...
        finite_or_default( ...
            updateCounter, ...
            0);


    % Must remain exactly 38 elements.
    est_y = yHold;


%% =========================================================
% Non-update 1-kHz hold cycle
% ==========================================================

else

    yHold(35) = 0;

    yHold(38) = ...
        finite_or_default( ...
            updateCounter, ...
            0);

    est_y = yHold;

end

end


%% =========================================================
% Local helper
% ==========================================================

function x = finite_or_default(v,x_default)

if isfinite(v)

    x = v;

else

    x = x_default;

end

end