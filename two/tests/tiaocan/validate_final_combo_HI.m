%% =========================================================
% validate_final_combo_HI.m
%
% 最终冻结参数的独立组合工况验证
%
% 冻结参数：
%   a0 = 0.10 m/s^2
%   a1 = 2.706246 m/s^2
%   kA = 70
%   kH = 60
%
% 推荐工况：
%
% H：高附着
%    匀速 -> 加速 -> 减速 -> 恢复
%
% I：低附着
%    匀速 -> 加速 -> 减速 -> 恢复
%
% 注意：
% 1. H/I不能参与参数重新标定；
% 2. 本脚本只做最终泛化性能评价；
% 3. 加减速阶段根据实际Ax自动识别；
% 4. 健康退化阶段根据hW自动识别。
% ==========================================================

clc
clear

%% =========================================================
% 0. 文件
%
% 如果你的实际文件名不同，只改这里
% ==========================================================

files = { ...
    'D:\two\two\tests\results_case_D.mat', ...
    'D:\two\two\tests\results_case_H.mat'};

names = { ...
    'H 高附加速-减速组合', ...
    'I 低附加速-减速组合'};

%% =========================================================
% 1. 最终冻结参数
% ==========================================================

a0 = 0.10;
a1 = 2.706246;
kA = 70.0;
kH = 60.0;

fprintf('\n');
fprintf('=====================================================\n');
fprintf('        最终参数独立组合工况验证\n');
fprintf('=====================================================\n');

fprintf('a0 = %.6f m/s^2\n',a0);
fprintf('a1 = %.6f m/s^2\n',a1);
fprintf('kA = %.1f\n',kA);
fprintf('kH = %.1f\n',kH);

fprintf('\n注意：H/I仅用于独立验证，不再参与调参。\n');

%% =========================================================
% 2. est_y列定义
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

% longitudinal_velocity_estimator.m:
% Ax = est_u(9)
COL_AX_U = 9;

%% =========================================================
% 3. 仅用于“报告阶段划分”的阈值
%
% 注意：
% 这个阈值不进入估计器，只用于离线把数据分成
% 加速 / 减速 / 近稳态。
%
% a0=0.1是算法死区。
% 报告阶段取0.3避免把很小的过渡Ax算成强动态。
% ==========================================================

aReport = 0.30;

%% =========================================================
% 4. 分析H/I
% ==========================================================

for ic = 1:numel(files)

    %% -----------------------------------------------------
    % 读取
    % ------------------------------------------------------

    S = load(files{ic});

    if ~isfield(S,'E')
        error('%s 中不存在结构体E。',files{ic});
    end

    E = S.E;

    if ~isfield(E,'est_u_time') || ...
       ~isfield(E,'est_u_data')

        error('%s没有est_u_time/est_u_data。',files{ic});

    end

    %% =====================================================
    % 5. 取估计器100Hz真实更新点
    % ======================================================

    updated = ...
        E.est_y_data(:,COL_UPDATED) > 0.5;

    t = E.est_y_time(updated);
    Y = E.est_y_data(updated,:);

    %% =====================================================
    % 6. 真值
    % ======================================================

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t(:), ...
        'linear', ...
        NaN);

    %% =====================================================
    % 7. 真正在线Ax = est_u(:,9)
    % ======================================================

    tu = E.est_u_time(:);
    U  = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s的est_u尺寸异常。',files{ic});
        end

    end

    Ax = interp1( ...
        tu, ...
        U(:,COL_AX_U), ...
        t(:), ...
        'linear', ...
        NaN);

    %% =====================================================
    % 8. estimator输出
    % ======================================================

    vxFused = Y(:,COL_VXFUSED);

    xW = Y(:,COL_XW);
    PW = Y(:,COL_PW);

    xI = Y(:,COL_XI);
    PI = Y(:,COL_PI);

    alphaW = Y(:,COL_ALPHAW);
    alphaI = Y(:,COL_ALPHAI);

    wssValid = ...
        Y(:,COL_WSSVALID) > 0.5;

    imuValid = ...
        Y(:,COL_IMUVALID) > 0.5;

    %% =====================================================
    % 9. hW
    %
    % hW = 1/4 sum rho_i I(valid_i)
    % ======================================================

    rho4 = Y(:,COL_RHO);

    valid4 = ...
        Y(:,COL_VALID) > 0.5;

    hW = ...
        sum(rho4 .* double(valid4),2) / 4;

    hW = min(max(hW,0),1);

    nValid = ...
        sum(valid4,2);

    %% =====================================================
    % 10. 最终sA
    % ======================================================

    uA = ...
        (abs(Ax)-a0) ./ ...
        (a1-a0);

    uA = min(max(uA,0),1);

    sA = ...
        3*uA.^2 - 2*uA.^3;

    %% =====================================================
    % 11. 最终sH
    % ======================================================

    sH = ...
        (1-hW).^2;

    %% =====================================================
    % 12. 理论PW膨胀倍数
    %
    % 只用于诊断，不参与重新计算输出
    % ======================================================

    inflateFactor = ...
        1 + ...
        kA*sA + ...
        kH*sH;

    %% =====================================================
    % 13. 有效数据
    % ======================================================

    good = ...
        isfinite(t) & ...
        isfinite(vxTrue) & ...
        isfinite(Ax) & ...
        isfinite(vxFused) & ...
        isfinite(xW) & ...
        isfinite(xI) & ...
        isfinite(alphaW) & ...
        isfinite(hW);

    %% =====================================================
    % 14. 自动划分状态
    %
    % steady：
    %   |Ax| <= 0.3
    %
    % accel：
    %   Ax > +0.3
    %
    % decel：
    %   Ax < -0.3
    %
    % degraded：
    %   hW < 0.75
    %
    % severe：
    %   hW < 0.55
    %
    % healthyDynamic：
    %   强动态但hW仍接近1
    % ======================================================

    idxSteady = ...
        good & ...
        abs(Ax) <= aReport;

    idxAccel = ...
        good & ...
        Ax > aReport;

    idxDecel = ...
        good & ...
        Ax < -aReport;

    idxDegraded = ...
        good & ...
        hW < 0.75;

    idxSevere = ...
        good & ...
        hW < 0.55;

    idxHealthyDynamic = ...
        good & ...
        abs(Ax) > aReport & ...
        hW >= 0.95;

    %% =====================================================
    % 15. 总体输出
    % ======================================================

    fprintf('\n');
    fprintf('=====================================================\n');
    fprintf('%s\n',names{ic});
    fprintf('=====================================================\n');

    fprintf('\n===== 全局 =====\n');

    report_window( ...
        '全局', ...
        good, ...
        t,Ax,sA,hW,nValid,inflateFactor, ...
        xW,xI,vxFused,vxTrue, ...
        alphaW,alphaI,wssValid,imuValid);

    %% =====================================================
    % 16. 近稳态
    % ======================================================

    if any(idxSteady)

        fprintf('\n===== 近稳态 =====\n');

        report_window( ...
            '近稳态', ...
            idxSteady, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    end

    %% =====================================================
    % 17. 加速
    % ======================================================

    if any(idxAccel)

        fprintf('\n===== 加速阶段 =====\n');

        report_window( ...
            '加速', ...
            idxAccel, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    else

        fprintf('\n未识别到明显加速阶段。\n');

    end

    %% =====================================================
    % 18. 减速
    % ======================================================

    if any(idxDecel)

        fprintf('\n===== 减速阶段 =====\n');

        report_window( ...
            '减速', ...
            idxDecel, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    else

        fprintf('\n未识别到明显减速阶段。\n');

    end

    %% =====================================================
    % 19. 健康动态
    %
    % 用来验证：
    % 正常强动态时，主要是Ax项发挥作用。
    % ======================================================

    if any(idxHealthyDynamic)

        fprintf('\n===== 健康强动态 =====\n');

        report_window( ...
            '健康强动态', ...
            idxHealthyDynamic, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    end

    %% =====================================================
    % 20. WSS健康退化
    %
    % hW < 0.75
    % ======================================================

    if any(idxDegraded)

        fprintf('\n===== WSS健康退化 hW<0.75 =====\n');

        report_window( ...
            '健康退化', ...
            idxDegraded, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    else

        fprintf('\n未出现 hW<0.75 的轮速明显退化阶段。\n');

    end

    %% =====================================================
    % 21. 严重退化
    %
    % hW < 0.55
    % ======================================================

    if any(idxSevere)

        fprintf('\n===== WSS严重退化 hW<0.55 =====\n');

        report_window( ...
            '严重退化', ...
            idxSevere, ...
            t,Ax,sA,hW,nValid,inflateFactor, ...
            xW,xI,vxFused,vxTrue, ...
            alphaW,alphaI,wssValid,imuValid);

    else

        fprintf('\n未出现 hW<0.55 的严重退化阶段。\n');

    end

    %% =====================================================
    % 22. 极值/恢复能力
    % ======================================================

    fprintf('\n===== 权重与健康度极值 =====\n');

    fprintf('alphaW min = %.6f\n', ...
        min(alphaW(good)));

    fprintf('alphaW max = %.6f\n', ...
        max(alphaW(good)));

    fprintf('hW min     = %.6f\n', ...
        min(hW(good)));

    fprintf('hW max     = %.6f\n', ...
        max(hW(good)));

    fprintf('nValid min = %d / 4\n', ...
        min(nValid(good)));

    fprintf('PW inflation max = %.3f x\n', ...
        max(inflateFactor(good)));

    %% =====================================================
    % 23. 自动给出加减速时间范围
    % ======================================================

    fprintf('\n===== 自动识别时间范围 =====\n');

    if any(idxAccel)

        fprintf('加速样本时间范围：%.3f ~ %.3f s\n', ...
            min(t(idxAccel)), ...
            max(t(idxAccel)));

    end

    if any(idxDecel)

        fprintf('减速样本时间范围：%.3f ~ %.3f s\n', ...
            min(t(idxDecel)), ...
            max(t(idxDecel)));

    end

    if any(idxDegraded)

        fprintf('hW<0.75时间范围：%.3f ~ %.3f s\n', ...
            min(t(idxDegraded)), ...
            max(t(idxDegraded)));

    end

    if any(idxSevere)

        fprintf('hW<0.55时间范围：%.3f ~ %.3f s\n', ...
            min(t(idxSevere)), ...
            max(t(idxSevere)));

    end

end

fprintf('\n');
fprintf('=====================================================\n');
fprintf('              最终判断原则\n');
fprintf('=====================================================\n');

fprintf(['1. H/I不允许再用于调a0/a1/kA/kH；\n' ...
         '2. 健康稳态应恢复WSS主导；\n' ...
         '3. 健康强动态应由Ax项降低WSS权重；\n' ...
         '4. hW下降时应进一步降低WSS权重；\n' ...
         '5. hW恢复至1后，健康项应自动退出；\n' ...
         '6. FUSED在动态/退化阶段应明显优于坏的WSS轨迹；\n' ...
         '7. 如果某一阶段效果异常，先诊断原因，不重新调参。\n']);

fprintf('=====================================================\n');


%% =========================================================
% 本地函数
% ==========================================================
function report_window( ...
    label,idx, ...
    t,Ax,sA,hW,nValid,inflateFactor, ...
    xW,xI,vxFused,vxTrue, ...
    alphaW,alphaI,wssValid,imuValid)

    if ~any(idx)
        fprintf('%s：无有效样本。\n',label);
        return
    end

    n = sum(idx);

    rmseW = sqrt(mean( ...
        (xW(idx)-vxTrue(idx)).^2));

    rmseI = sqrt(mean( ...
        (xI(idx)-vxTrue(idx)).^2));

    rmseF = sqrt(mean( ...
        (vxFused(idx)-vxTrue(idx)).^2));

    maeF = mean(abs( ...
        vxFused(idx)-vxTrue(idx)));

    maxAbsF = max(abs( ...
        vxFused(idx)-vxTrue(idx)));

    fprintf('%s\n',label);

    fprintf('样本数 = %d\n',n);

    fprintf('时间范围 = %.3f ~ %.3f s\n', ...
        min(t(idx)), ...
        max(t(idx)));

    fprintf('\n');

    fprintf('|Ax| mean = %.6f m/s^2\n', ...
        mean(abs(Ax(idx))));

    fprintf('sA mean   = %.6f\n', ...
        mean(sA(idx)));

    fprintf('hW mean   = %.6f\n', ...
        mean(hW(idx)));

    fprintf('hW min    = %.6f\n', ...
        min(hW(idx)));

    fprintf('nValid mean = %.3f / 4\n', ...
        mean(nValid(idx)));

    fprintf('nValid min  = %d / 4\n', ...
        min(nValid(idx)));

    fprintf('\n');

    fprintf('PW inflation mean = %.3f x\n', ...
        mean(inflateFactor(idx)));

    fprintf('PW inflation P95  = %.3f x\n', ...
        prctile(inflateFactor(idx),95));

    fprintf('\n');

    fprintf('mean alphaW = %.6f\n', ...
        mean(alphaW(idx)));

    fprintf('P95 alphaW  = %.6f\n', ...
        prctile(alphaW(idx),95));

    fprintf('mean alphaI = %.6f\n', ...
        mean(alphaI(idx)));

    fprintf('\n');

    fprintf('WSS valid ratio = %.6f\n', ...
        mean(double(wssValid(idx))));

    fprintf('IMU valid ratio = %.6f\n', ...
        mean(double(imuValid(idx))));

    fprintf('\n');

    fprintf('WSS RMSE   = %.6f m/s\n',rmseW);
    fprintf('IMU RMSE   = %.6f m/s\n',rmseI);
    fprintf('FUSED RMSE = %.6f m/s\n',rmseF);

    fprintf('FUSED MAE  = %.6f m/s\n',maeF);

    fprintf('FUSED MaxAE= %.6f m/s\n',maxAbsF);

    fprintf('\n');

    if rmseF < rmseW

        improveW = ...
            100*(rmseW-rmseF) / max(rmseW,1e-12);

        fprintf('相对WSS RMSE改善 = %.2f %%\n', ...
            improveW);

    else

        fprintf('FUSED没有优于WSS。\n');

    end

    if rmseF < rmseI

        improveI = ...
            100*(rmseI-rmseF) / max(rmseI,1e-12);

        fprintf('相对IMU RMSE改善 = %.2f %%\n', ...
            improveI);

    else

        fprintf('FUSED没有优于IMU；这是允许的，需结合权重判断。\n');

    end

end