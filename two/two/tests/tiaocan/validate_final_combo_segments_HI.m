%% =========================================================
% validate_final_combo_segments_HI.m
%
% 最终独立组合工况连续区间验证
%
% Frozen:
%   a0 = 0.10
%   a1 = 2.706246
%   kA = 70
%   kH = 60
%
% 改进：
%   1) 排除0~0.6s启动初始化
%   2) 不再用min~max表示不连续区间
%   3) 自动提取连续加速/减速/稳态/退化段
%   4) 短于指定时间的片段自动忽略
% ==========================================================

clc
clear

files = { ...
    'D:\two\two\tests\results_case_D.mat', ...
    'D:\two\two\tests\results_case_I.mat'};

names = { ...
    'H 高附组合', ...
    'I 低附组合'};

%% =========================================================
% 冻结参数
% ==========================================================

a0 = 0.10;
a1 = 2.706246;
kA = 70;
kH = 60;

%% =========================================================
% 离线报告阈值
% ==========================================================

tStartEval = 0.60;

% 用于划分明显动态
aReport = 0.30;

% 连续阶段至少持续时间
TminSteady = 0.30;
TminDynamic = 0.20;
TminHealth = 0.20;

%% =========================================================
% est_y映射
% ==========================================================

COL_VXFUSED = 1;

COL_XW = 3;
COL_PW = 4;

COL_XI = 5;
COL_PI = 6;

COL_RHO   = 16:19;
COL_VALID = 24:27;

COL_WSSVALID = 28;
COL_IMUVALID = 29;

COL_ALPHAW = 30;
COL_ALPHAI = 31;

COL_UPDATED = 35;

COL_AX_U = 9;


%% =========================================================
% 主循环
% ==========================================================

for ic = 1:numel(files)

    S = load(files{ic});
    E = S.E;

    %% -----------------------------------------------------
    % estimator更新点
    % ------------------------------------------------------

    updated = ...
        E.est_y_data(:,COL_UPDATED) > 0.5;

    t = E.est_y_time(updated);
    Y = E.est_y_data(updated,:);

    %% -----------------------------------------------------
    % true Vx
    % ------------------------------------------------------

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t(:), ...
        'linear', ...
        NaN);

    %% -----------------------------------------------------
    % est_u
    % ------------------------------------------------------

    tu = E.est_u_time(:);
    U  = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s est_u尺寸异常。',files{ic});
        end

    end

    Ax = interp1( ...
        tu, ...
        U(:,COL_AX_U), ...
        t(:), ...
        'linear', ...
        NaN);

    %% -----------------------------------------------------
    % estimator变量
    % ------------------------------------------------------

    vxF = Y(:,COL_VXFUSED);

    xW = Y(:,COL_XW);
    xI = Y(:,COL_XI);

    alphaW = Y(:,COL_ALPHAW);
    alphaI = Y(:,COL_ALPHAI);

    wssValid = ...
        Y(:,COL_WSSVALID) > 0.5;

    imuValid = ...
        Y(:,COL_IMUVALID) > 0.5;

    %% -----------------------------------------------------
    % hW
    % ------------------------------------------------------

    rho4 = Y(:,COL_RHO);

    valid4 = ...
        Y(:,COL_VALID) > 0.5;

    hW = ...
        sum(rho4 .* double(valid4),2)/4;

    hW = min(max(hW,0),1);

    nValid = ...
        sum(valid4,2);

    %% -----------------------------------------------------
    % sA
    % ------------------------------------------------------

    uA = ...
        (abs(Ax)-a0) ./ ...
        (a1-a0);

    uA = min(max(uA,0),1);

    sA = ...
        3*uA.^2 - 2*uA.^3;

    %% -----------------------------------------------------
    % sH和协方差膨胀倍数
    % ------------------------------------------------------

    sH = ...
        (1-hW).^2;

    inflateFactor = ...
        1 + ...
        kA*sA + ...
        kH*sH;

    %% -----------------------------------------------------
    % 基本有效区
    % ------------------------------------------------------

    good = ...
        t >= tStartEval & ...
        isfinite(vxTrue) & ...
        isfinite(Ax) & ...
        isfinite(vxF) & ...
        isfinite(xW) & ...
        isfinite(xI) & ...
        isfinite(alphaW);

    %% =====================================================
    % 状态mask
    % ======================================================

    % 近稳态
    maskSteady = ...
        good & ...
        abs(Ax) <= aReport;

    % 加速
    maskAccel = ...
        good & ...
        Ax > aReport;

    % 减速
    maskDecel = ...
        good & ...
        Ax < -aReport;

    % 健康强动态
    maskHealthyDynamic = ...
        good & ...
        abs(Ax) > aReport & ...
        hW >= 0.95;

    % 一般健康退化
    maskDegraded = ...
        good & ...
        hW < 0.75;

    % 严重退化
    maskSevere = ...
        good & ...
        hW < 0.55;

    %% =====================================================
    % 输出
    % ======================================================

    fprintf('\n');
    fprintf('=====================================================\n');
    fprintf('%s 最终连续区间验证\n',names{ic});
    fprintf('=====================================================\n');

    fprintf('评价起始时间：%.3f s\n',tStartEval);

    %% -----------------------------------------------------
    % 全局（排除启动）
    % ------------------------------------------------------

    fprintf('\n===== 全局（排除启动初始化） =====\n');

    printStats( ...
        good,t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 连续稳态
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续近稳态区间 =====\n');

    printSegments( ...
        maskSteady,TminSteady, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 连续加速
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续加速区间 =====\n');

    printSegments( ...
        maskAccel,TminDynamic, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 连续减速
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续减速区间 =====\n');

    printSegments( ...
        maskDecel,TminDynamic, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 健康强动态
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续健康强动态区间 =====\n');

    printSegments( ...
        maskHealthyDynamic,TminDynamic, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 退化
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续WSS退化区间 hW<0.75 =====\n');

    printSegments( ...
        maskDegraded,TminHealth, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% -----------------------------------------------------
    % 严重退化
    % ------------------------------------------------------

    fprintf('\n');
    fprintf('===== 连续WSS严重退化区间 hW<0.55 =====\n');

    printSegments( ...
        maskSevere,TminHealth, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxF,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

end


%% =========================================================
% 本地函数1：
% 找连续true区间
% ==========================================================
function segs = findSegments(mask,t,Tmin)

    mask = logical(mask(:));
    t = t(:);

    d = diff([false; mask; false]);

    iStart = find(d == 1);
    iEnd   = find(d == -1)-1;

    segs = [];

    for k = 1:numel(iStart)

        ii1 = iStart(k);
        ii2 = iEnd(k);

        duration = ...
            t(ii2)-t(ii1);

        if duration >= Tmin

            segs(end+1,:) = ...
                [ii1 ii2]; %#ok<AGROW>

        end

    end

end


%% =========================================================
% 本地函数2：
% 打印多个连续区间
% ==========================================================
function printSegments( ...
    mask,Tmin, ...
    t,Ax,sA,hW,nValid,inflateFactor, ...
    xW,xI,vxF,vxTrue, ...
    alphaW,alphaI,wssValid,imuValid)

    segs = ...
        findSegments(mask,t,Tmin);

    if isempty(segs)

        fprintf('没有持续时间 >= %.3f s 的有效连续区间。\n', ...
            Tmin);

        return
    end

    fprintf('找到 %d 个连续有效区间。\n', ...
        size(segs,1));

    for k = 1:size(segs,1)

        idx = false(size(t));

        idx(segs(k,1):segs(k,2)) = true;

        fprintf('\n------------------------------------------\n');

        fprintf('Segment %d：%.3f ~ %.3f s，持续 %.3f s\n', ...
            k, ...
            t(segs(k,1)), ...
            t(segs(k,2)), ...
            t(segs(k,2))-t(segs(k,1)));

        fprintf('------------------------------------------\n');

        printStats( ...
            idx,t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxF,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    end

end


%% =========================================================
% 本地函数3：
% 区间指标
% ==========================================================
function printStats( ...
    idx,t,Ax,sA,hW,nValid,inflateFactor, ...
    xW,xI,vxF,vxTrue, ...
    alphaW,alphaI,wssValid,imuValid)

    if ~any(idx)
        fprintf('无有效样本。\n');
        return
    end

    rmseW = sqrt(mean( ...
        (xW(idx)-vxTrue(idx)).^2));

    rmseI = sqrt(mean( ...
        (xI(idx)-vxTrue(idx)).^2));

    rmseF = sqrt(mean( ...
        (vxF(idx)-vxTrue(idx)).^2));

    maeF = ...
        mean(abs(vxF(idx)-vxTrue(idx)));

    fprintf('样本数 = %d\n',sum(idx));

    fprintf('时间 = %.3f ~ %.3f s\n', ...
        min(t(idx)),max(t(idx)));

    fprintf('|Ax| mean = %.6f m/s^2\n', ...
        mean(abs(Ax(idx))));

    fprintf('sA mean = %.6f\n', ...
        mean(sA(idx)));

    fprintf('hW mean = %.6f\n', ...
        mean(hW(idx)));

    fprintf('hW min  = %.6f\n', ...
        min(hW(idx)));

    fprintf('nValid mean = %.3f / 4\n', ...
        mean(nValid(idx)));

    fprintf('nValid min  = %d / 4\n', ...
        min(nValid(idx)));

    fprintf('PW inflation mean = %.3f x\n', ...
        mean(inflateFactor(idx)));

    fprintf('mean alphaW = %.6f\n', ...
        mean(alphaW(idx)));

    fprintf('P95 alphaW = %.6f\n', ...
        prctile(alphaW(idx),95));

    fprintf('mean alphaI = %.6f\n', ...
        mean(alphaI(idx)));

    fprintf('WSS valid = %.6f\n', ...
        mean(double(wssValid(idx))));

    fprintf('IMU valid = %.6f\n', ...
        mean(double(imuValid(idx))));

    fprintf('WSS RMSE   = %.6f m/s\n',rmseW);
    fprintf('IMU RMSE   = %.6f m/s\n',rmseI);
    fprintf('FUSED RMSE = %.6f m/s\n',rmseF);
    fprintf('FUSED MAE  = %.6f m/s\n',maeF);

    fprintf('FUSED vs WSS改善 = %.2f %%\n', ...
        100*(rmseW-rmseF)/max(rmseW,1e-12));

    fprintf('FUSED vs IMU改善 = %.2f %%\n', ...
        100*(rmseI-rmseF)/max(rmseI,1e-12));

end