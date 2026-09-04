%% =========================================================
% diagnose_estimator_timing_BCDH.m
%
% 目的：
% 1. 检查est_y(:,35)筛出来的点是否真的100Hz
% 2. 检查est_y(:,38)=updateCounter是否严格10ms递增
% 3. 判断IMU跳变到底来自：
%       A. 离线时间轴筛选错误
%       B. estimator真实发生了非10ms更新
% 4. 比较：
%       固定Ts=0.01递推残差
%       实际timestamp递推残差
%
% 此脚本只诊断，不调任何参数。
% ==========================================================

clc
clear

files = { ...
    'D:\two\two\tests\results_case_B.mat', ...
    'D:\two\two\tests\results_case_C.mat', ...
    'D:\two\two\tests\results_case_D.mat', ...
    'D:\two\two\tests\results_case_H.mat'};

names = {'B','C','D','H'};

COL_UPDATED = 35;
COL_COUNTER = 38;

COL_XI = 5;
COL_PI = 6;

QI = 1e-4;

TsEst = 0.01;

biasAxCal = 0.02178105;

for ic = 1:numel(files)

    S = load(files{ic});
    E = S.E;

    tAll = E.est_y_time(:);
    YAll = E.est_y_data;

    %% =====================================================
    % 1. col35筛选
    % ======================================================

    flag35 = ...
        YAll(:,COL_UPDATED) > 0.5;

    t35 = ...
        tAll(flag35);

    Y35 = ...
        YAll(flag35,:);

    %% =====================================================
    % 2. updateCounter检查
    %
    % counter发生变化才视为新的真实更新
    % ======================================================

    counter = ...
        YAll(:,COL_COUNTER);

    counterFinite = ...
        isfinite(counter);

    counterChange = false(size(counter));

    for k = 2:numel(counter)

        if counterFinite(k) && ...
           counterFinite(k-1)

            counterChange(k) = ...
                counter(k) > counter(k-1);

        end

    end

    tCtr = ...
        tAll(counterChange);

    YCtr = ...
        YAll(counterChange,:);

    counterCtr = ...
        counter(counterChange);

    %% =====================================================
    % 3. 更新时间统计
    % ======================================================

    dt35 = diff(t35);
    dtCtr = diff(tCtr);

    fprintf('\n');
    fprintf('=====================================================\n');
    fprintf('%s estimator更新时间诊断\n',names{ic});
    fprintf('=====================================================\n');

    fprintf('\n===== 样本数量 =====\n');

    fprintf('原始log样本数 = %d\n', ...
        numel(tAll));

    fprintf('col35>0.5样本数 = %d\n', ...
        numel(t35));

    fprintf('counter真实变化次数 = %d\n', ...
        numel(tCtr));

    %% -----------------------------------------------------
    % col35
    % ------------------------------------------------------

    fprintf('\n===== col35时间间隔 =====\n');

    print_dt_stats(dt35);

    %% -----------------------------------------------------
    % counter
    % ------------------------------------------------------

    fprintf('\n===== updateCounter时间间隔 =====\n');

    print_dt_stats(dtCtr);

    %% =====================================================
    % 4. counter增长量
    % ======================================================

    if numel(counterCtr) >= 2

        dc = ...
            diff(counterCtr);

        fprintf('\n===== updateCounter增长 =====\n');

        fprintf('median deltaCounter = %.6f\n', ...
            median(dc));

        fprintf('min deltaCounter    = %.6f\n', ...
            min(dc));

        fprintf('max deltaCounter    = %.6f\n', ...
            max(dc));

        fprintf('deltaCounter ~= 1 数量 = %d\n', ...
            sum(abs(dc-1)>1e-9));

    end

    %% =====================================================
    % 5. col35是否包含同一个counter的重复点
    % ======================================================

    counter35 = ...
        Y35(:,COL_COUNTER);

    if numel(counter35) >= 2

        sameCounter = ...
            abs(diff(counter35)) < 1e-9;

        fprintf('\n===== col35重复检查 =====\n');

        fprintf('相邻col35样本counter不变数量 = %d\n', ...
            sum(sameCounter));

        fprintf('比例 = %.3f %%\n', ...
            100*mean(sameCounter));

    end

    %% =====================================================
    % 6. 列出异常updateCounter时间间隔
    % ======================================================

    fprintf('\n===== counter异常更新时间 =====\n');

    badDt = ...
        find( ...
        dtCtr < 0.0075 | ...
        dtCtr > 0.0125);

    fprintf('偏离10ms超过2.5ms的次数 = %d\n', ...
        numel(badDt));

    if ~isempty(badDt)

        Nshow = min(20,numel(badDt));

        fprintf('\n前%d个异常：\n',Nshow);

        for j = 1:Nshow

            ii = badDt(j);

            fprintf([ ...
                'counter %.0f -> %.0f, ' ...
                't %.9f -> %.9f, ' ...
                'dt = %.9f s\n'], ...
                counterCtr(ii), ...
                counterCtr(ii+1), ...
                tCtr(ii), ...
                tCtr(ii+1), ...
                dtCtr(ii));

        end

    end

    %% =====================================================
    % 7. 用counter真实更新点重新反解z
    % ======================================================

    if numel(tCtr) < 20

        fprintf('\ncounter样本不足，跳过IMU轨迹诊断。\n');
        continue

    end

    t = tCtr;
    Y = YCtr;

    xI = Y(:,COL_XI);
    PI = Y(:,COL_PI);

    imuValid = ...
        Y(:,29) > 0.5;

    %% Ax映射
    tu = E.est_u_time(:);
    U = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s est_u尺寸异常',names{ic});
        end

    end

    Ax = interp1( ...
        tu,U(:,9),t, ...
        'linear',NaN);

    aCal = ...
        Ax-biasAxCal;

    N = numel(t);

    z = nan(N,1);
    Karr = nan(N,1);

    for k = 2:N

        if ~imuValid(k)
            continue
        end

        if ~all(isfinite([ ...
                xI(k-1), ...
                xI(k), ...
                PI(k-1), ...
                PI(k)]))

            continue
        end

        Pminus = ...
            PI(k-1)+QI;

        if Pminus <= 0
            continue
        end

        K = ...
            1-PI(k)/Pminus;

        if ~isfinite(K) || ...
                K <= 1e-6 || ...
                K >= 1

            continue
        end

        z(k) = ...
            xI(k-1) + ...
            (xI(k)-xI(k-1))/K;

        Karr(k) = K;

    end

    %% =====================================================
    % 8. 对比两种时间基准
    %
    % fixed:
    %   estimator真正使用的0.01
    %
    % timestamp:
    %   Simulink日志实际时间差
    % ======================================================

    rFixed = nan(N,1);
    rTime  = nan(N,1);

    for k = 2:N

        if ~all(isfinite([ ...
                z(k-1),z(k), ...
                aCal(k-1),aCal(k)]))

            continue
        end

        dvActual = ...
            z(k)-z(k-1);

        dvFixed = ...
            0.5*TsEst* ...
            (aCal(k-1)+aCal(k));

        dtReal = ...
            t(k)-t(k-1);

        dvTime = ...
            0.5*dtReal* ...
            (aCal(k-1)+aCal(k));

        rFixed(k) = ...
            dvActual-dvFixed;

        rTime(k) = ...
            dvActual-dvTime;

    end

    rf = ...
        rFixed(isfinite(rFixed));

    rt = ...
        rTime(isfinite(rTime));

    fprintf('\n');
    fprintf('===== IMU递推时间基准比较 =====\n');

    fprintf('\n--- 固定Ts=0.01 ---\n');

    fprintf('RMS  = %.12e m/s\n', ...
        sqrt(mean(rf.^2)));

    fprintf('P95  = %.12e m/s\n', ...
        prctile(abs(rf),95));

    fprintf('MAX  = %.12e m/s\n', ...
        max(abs(rf)));

    fprintf('\n--- 使用实际timestamp dt ---\n');

    fprintf('RMS  = %.12e m/s\n', ...
        sqrt(mean(rt.^2)));

    fprintf('P95  = %.12e m/s\n', ...
        prctile(abs(rt),95));

    fprintf('MAX  = %.12e m/s\n', ...
        max(abs(rt)));

    %% =====================================================
    % 9. 自动判断
    % ======================================================

    medDt = median(dtCtr);

    minDt = min(dtCtr);
    maxDt = max(dtCtr);

    rmsFixed = sqrt(mean(rf.^2));
    rmsTime  = sqrt(mean(rt.^2));

    fprintf('\n===== 自动判断 =====\n');

    if minDt > 0.0075 && ...
       maxDt < 0.0125 && ...
       rmsFixed < 1e-5

        fprintf('[TIMING PASS]\n');

        fprintf([ ...
            'updateCounter显示估计器基本严格100Hz，\n' ...
            '且固定Ts递推成立。\n' ...
            '之前TRACK CHECK主要属于离线取点/时间轴问题。\n']);

    elseif (minDt < 0.0075 || maxDt > 0.0125) && ...
            rmsFixed < rmsTime

        fprintf('[TIMING PROBLEM]\n');

        fprintf([ ...
            '估计器真实更新时间存在明显非10ms间隔，\n' ...
            '但内部仍按固定Ts=0.01积分。\n' ...
            '这会直接造成独立IMU速度累计偏差。\n']);

    else

        fprintf('[NEED CHECK]\n');

        fprintf([ ...
            '时间问题和轨迹递推问题尚未完全分离，\n' ...
            '先查看上面的异常counter时间点。\n']);

    end

end


%% =========================================================
% local function
% ==========================================================
function print_dt_stats(dt)

    if isempty(dt)

        fprintf('没有足够样本。\n');
        return
    end

    fprintf('mean   = %.9f s\n',mean(dt));
    fprintf('median = %.9f s\n',median(dt));

    fprintf('min    = %.9f s\n',min(dt));
    fprintf('P01    = %.9f s\n',prctile(dt,1));
    fprintf('P05    = %.9f s\n',prctile(dt,5));

    fprintf('P95    = %.9f s\n',prctile(dt,95));
    fprintf('P99    = %.9f s\n',prctile(dt,99));
    fprintf('max    = %.9f s\n',max(dt));

    fprintf('dt < 5 ms 数量  = %d\n', ...
        sum(dt<0.005));

    fprintf('dt < 7.5 ms 数量= %d\n', ...
        sum(dt<0.0075));

    fprintf('dt > 12.5ms数量 = %d\n', ...
        sum(dt>0.0125));

    fprintf('dt > 15ms 数量  = %d\n', ...
        sum(dt>0.015));

end