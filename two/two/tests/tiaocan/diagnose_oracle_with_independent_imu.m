%% =========================================================
% diagnose_oracle_with_independent_imu.m
%
% 判断：
%
% WSS + 真正独立IMU-only
%
% 是否理论上存在优于两个单轨迹的正权重融合
%
% B/C/D/H用于开发诊断，不调kA/kH
% ==========================================================

clc
clear

files = { ...
    'D:\two\two\tests\results_case_B.mat', ...
    'D:\two\two\tests\results_case_C.mat', ...
    'D:\two\two\tests\results_case_D.mat', ...
    'D:\two\two\tests\results_case_H.mat'};

names = {'B','C','D','H'};

% A/E稳态得到的静态bias估计
biasAxCal = 0.02178105;

for ic = 1:numel(files)

    if ~exist(files{ic},'file')
        fprintf('\n%s不存在，跳过。\n',files{ic});
        continue
    end

    S = load(files{ic});
    E = S.E;

    updated = E.est_y_data(:,35) > 0.5;

    t = E.est_y_time(updated);
    Y = E.est_y_data(updated,:);

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t, ...
        'linear', ...
        NaN);

    %% =====================================================
    % 实际IMU输入
    % ======================================================

    tu = E.est_u_time(:);
    U  = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s est_u尺寸异常。',names{ic});
        end

    end

    Ax = interp1( ...
        tu, ...
        U(:,9), ...
        t, ...
        'linear', ...
        NaN);

    %% =====================================================
    % 独立IMU积分
    %
    % 注意：
    % 只在第一个有效时刻使用一次vxTrue作为初始化，
    % 此后绝不读取WSS/Fusion。
    % ======================================================

    good = ...
        t >= 0.6 & ...
        isfinite(vxTrue) & ...
        isfinite(Ax);

    ids = find(good);

    vRaw = nan(size(t));
    vCal = nan(size(t));

    if numel(ids) < 2
        continue
    end

    i0 = ids(1);

    vRaw(i0) = vxTrue(i0);
    vCal(i0) = vxTrue(i0);

    for kk = 2:numel(ids)

        i1 = ids(kk-1);
        i2 = ids(kk);

        dt = t(i2)-t(i1);

        if ~isfinite(dt) || dt <= 0
            continue
        end

        % 原始IMU-only
        vRaw(i2) = ...
            vRaw(i1) + ...
            0.5*dt*(Ax(i1)+Ax(i2));

        % 静态bias校准IMU-only
        a1c = Ax(i1)-biasAxCal;
        a2c = Ax(i2)-biasAxCal;

        vCal(i2) = ...
            vCal(i1) + ...
            0.5*dt*(a1c+a2c);

    end

    %% =====================================================
    % 动态样本
    % ======================================================

    xW = Y(:,3);

    idx = ...
        good & ...
        abs(Ax) > 0.30 & ...
        isfinite(xW) & ...
        isfinite(vRaw) & ...
        isfinite(vCal);

    if sum(idx) < 50
        fprintf('%s动态样本不足。\n',names{ic});
        continue
    end

    fprintf('\n');
    fprintf('=====================================================\n');
    fprintf('%s 独立IMU融合可实现性\n',names{ic});
    fprintf('=====================================================\n');

    %% =====================================================
    % 1. WSS + raw IMU-only
    % ======================================================

    fprintf('\n===== WSS + raw IMU-only =====\n');

    oracle_report( ...
        xW(idx)-vxTrue(idx), ...
        vRaw(idx)-vxTrue(idx));

    %% =====================================================
    % 2. WSS + bias-cal IMU-only
    % ======================================================

    fprintf('\n===== WSS + bias-cal IMU-only =====\n');

    oracle_report( ...
        xW(idx)-vxTrue(idx), ...
        vCal(idx)-vxTrue(idx));

end


%% =========================================================
% 两轨理论oracle
% ==========================================================
function oracle_report(eW,eI)

    Eww = mean(eW.^2);
    Eii = mean(eI.^2);
    Ewi = mean(eW.*eI);

    rmseW = sqrt(Eww);
    rmseI = sqrt(Eii);

    den = ...
        Eww + Eii - 2*Ewi;

    if den > 1e-14
        aW0 = (Eii-Ewi)/den;
    else
        aW0 = 0.5;
    end

    aW = min(max(aW0,0),1);
    aI = 1-aW;

    eF = ...
        aW*eW + ...
        aI*eI;

    rmseOracle = ...
        sqrt(mean(eF.^2));

    C = corrcoef(eW,eI);

    if all(size(C)==[2 2])
        rho = C(1,2);
    else
        rho = NaN;
    end

    fprintf('WSS RMSE        = %.6f m/s\n',rmseW);
    fprintf('IMU-only RMSE   = %.6f m/s\n',rmseI);

    fprintf('error corr       = %.6f\n',rho);

    fprintf('alphaW unconstr. = %.6f\n',aW0);
    fprintf('alphaW convex    = %.6f\n',aW);
    fprintf('alphaI convex    = %.6f\n',aI);

    fprintf('oracle RMSE      = %.6f m/s\n',rmseOracle);

    best = min(rmseW,rmseI);

    fprintf('best single      = %.6f m/s\n',best);

    if rmseOracle < best-1e-6

        fprintf('\n[YES]\n');
        fprintf('存在正权重融合，可理论上同时优于两个单轨迹。\n');

    else

        fprintf('\n[NO]\n');
        fprintf('正权重融合无法优于最佳单轨迹。\n');

    end

end