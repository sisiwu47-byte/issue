%% =========================================================
% validate_final_ABCE.m
%
% 最终冻结参数：
%   a0 = 0.10
%   a1 = 2.706246
%   kA = 70
%   kH = 60
%
% 用途：
%   对最终在线版本在 A/B/C/E 工况下进行回归验证。
%
% 注意：
%   本脚本只读取 results_case_*.mat 中已经保存的在线结果，
%   并不会在离线重新施加 a0/a1/kA/kH。
%
%   因此必须确保 A/B/C/E 的 MAT 文件是使用
%   a0=0.10, a1=2.706246, kA=70, kH=60
%   的最终在线算法重新仿真得到的。
% ==========================================================

clc;
clear;

%% =========================================================
% 0. 文件
% ==========================================================

files = { ...
    'D:\two\two\tests\results_case_A.mat', ...
    'D:\two\two\tests\results_case_B.mat', ...
    'D:\two\two\tests\results_case_C.mat', ...
    'D:\two\two\tests\results_case_E.mat'};

names = { ...
    'A 高附匀速', ...
    'B 高附加速', ...
    'C 高附减速', ...
    'E 低附匀速'};

%% =========================================================
% 1. est_y 列定义
% ==========================================================

COL_VXFUSED = 1;

COL_XW = 3;
COL_XI = 5;

COL_RHO   = 16:19;
COL_VALID = 24:27;

COL_WSSVALID = 28;
COL_IMUVALID = 29;

COL_ALPHAW = 30;
COL_ALPHAI = 31;

COL_UPDATED = 35;

%% =========================================================
% 2. 输出标题
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('          最终参数 A/B/C/E 回归验证\n');
fprintf('=====================================================\n');

fprintf('a0 = 0.100000 m/s^2\n');
fprintf('a1 = 2.706246 m/s^2\n');
fprintf('kA = 70\n');
fprintf('kH = 60\n');

%% =========================================================
% 3. 逐工况验证
% ==========================================================

for ic = 1:numel(files)

    %% -----------------------------------------------------
    % 文件检查
    % ------------------------------------------------------

    if ~isfile(files{ic})
        error('找不到文件：%s', files{ic});
    end

    S = load(files{ic});

    if ~isfield(S, 'E')
        error('%s 中不存在结构体 E。', files{ic});
    end

    E = S.E;

    %% -----------------------------------------------------
    % 必要字段检查
    % ------------------------------------------------------

    requiredFields = { ...
        'est_y_data', ...
        'est_y_time', ...
        'Vx_true_time', ...
        'Vx_true_data'};

    for jf = 1:numel(requiredFields)

        if ~isfield(E, requiredFields{jf})
            error('%s 中缺少 E.%s。', ...
                files{ic}, requiredFields{jf});
        end

    end

    %% -----------------------------------------------------
    % est_y 尺寸检查
    % ------------------------------------------------------

    if size(E.est_y_data, 2) < COL_UPDATED
        error('%s 的 est_y_data 只有 %d 列，至少需要 %d 列。', ...
            files{ic}, ...
            size(E.est_y_data, 2), ...
            COL_UPDATED);
    end

    %% -----------------------------------------------------
    % 提取真实100 Hz更新点
    % ------------------------------------------------------

    updated = ...
        E.est_y_data(:, COL_UPDATED) > 0.5;

    if ~any(updated)
        error('%s 中没有检测到 estimatorUpdated > 0.5 的样本。', ...
            files{ic});
    end

    t = E.est_y_time(updated);
    Y = E.est_y_data(updated, :);

    t = t(:);

    %% -----------------------------------------------------
    % 真值插值到估计器100 Hz时间轴
    % ------------------------------------------------------

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t, ...
        'linear', ...
        NaN);

    vxTrue = vxTrue(:);

    %% =====================================================
    % 4. 统一评价窗口
    %
    % 原代码：
    %
    % if ic == 1 || ic == 4
    %     idx = t >= 3 & t < 8;
    % else
    %     idx = t >= 3 & t < 8;
    % end
    %
    % 两个分支完全相同，因此直接删除条件判断。
    % ======================================================

    idx = ...
        t >= 3.0 & ...
        t < 8.0 & ...
        isfinite(vxTrue);

    if ~any(idx)
        error('%s 在3~8 s评价窗口内没有有效数据。', ...
            names{ic});
    end

    %% =====================================================
    % 5. 提取估计结果
    % ======================================================

    vxF = Y(:, COL_VXFUSED);

    xW = Y(:, COL_XW);
    xI = Y(:, COL_XI);

    alphaW = Y(:, COL_ALPHAW);
    alphaI = Y(:, COL_ALPHAI);

    rho4 = Y(:, COL_RHO);

    valid4 = ...
        Y(:, COL_VALID) > 0.5;

    wssValid = ...
        Y(:, COL_WSSVALID) > 0.5;

    imuValid = ...
        Y(:, COL_IMUVALID) > 0.5;

    %% =====================================================
    % 6. WSS健康度
    %
    % 当前定义：
    %
    % hW = sum(rho_i * valid_i) / 4
    %
    % 注意这里除数始终为4，因此失效轮本身也会使hW下降。
    % 这与kH健康项的设计是一致的。
    % ======================================================

    hW = ...
        sum( ...
            rho4 .* double(valid4), ...
            2) / 4;

    hW = ...
        min(max(hW, 0), 1);

    %% =====================================================
    % 7. 进一步保证评价样本有限
    % ======================================================

    idxW = ...
        idx & ...
        isfinite(xW);

    idxI = ...
        idx & ...
        isfinite(xI);

    idxF = ...
        idx & ...
        isfinite(vxF);

    idxAlpha = ...
        idx & ...
        isfinite(alphaW) & ...
        isfinite(alphaI);

    idxH = ...
        idx & ...
        isfinite(hW);

    if ~any(idxW)
        error('%s 没有有效WSS估计样本。', names{ic});
    end

    if ~any(idxI)
        error('%s 没有有效IMU估计样本。', names{ic});
    end

    if ~any(idxF)
        error('%s 没有有效FUSED估计样本。', names{ic});
    end

    %% =====================================================
    % 8. RMSE
    % ======================================================

    rmseW = ...
        sqrt(mean( ...
            (xW(idxW) - vxTrue(idxW)).^2));

    rmseI = ...
        sqrt(mean( ...
            (xI(idxI) - vxTrue(idxI)).^2));

    rmseF = ...
        sqrt(mean( ...
            (vxF(idxF) - vxTrue(idxF)).^2));

    %% =====================================================
    % 9. 输出
    % ======================================================

    fprintf('\n');
    fprintf('------------------------------------------\n');
    fprintf('%s\n', names{ic});
    fprintf('------------------------------------------\n');

    fprintf('评价窗口 = 3.000 ~ 8.000 s\n');
    fprintf('有效样本数 = %d\n', sum(idx));

    fprintf('\n');

    fprintf('WSS RMSE   = %.6f m/s\n', rmseW);
    fprintf('IMU RMSE   = %.6f m/s\n', rmseI);
    fprintf('FUSED RMSE = %.6f m/s\n', rmseF);

    fprintf('\n');

    if any(idxAlpha)

        fprintf('mean alphaW = %.6f\n', ...
            mean(alphaW(idxAlpha)));

        fprintf('mean alphaI = %.6f\n', ...
            mean(alphaI(idxAlpha)));

        fprintf('min alphaW  = %.6f\n', ...
            min(alphaW(idxAlpha)));

        fprintf('max alphaW  = %.6f\n', ...
            max(alphaW(idxAlpha)));

    else

        fprintf('alphaW / alphaI 无有效样本。\n');

    end

    fprintf('\n');

    if any(idxH)

        fprintf('mean hW     = %.6f\n', ...
            mean(hW(idxH)));

        fprintf('min hW      = %.6f\n', ...
            min(hW(idxH)));

        fprintf('max hW      = %.6f\n', ...
            max(hW(idxH)));

    else

        fprintf('hW 无有效样本。\n');

    end

    fprintf('\n');

    fprintf('WSS valid ratio = %.6f\n', ...
        mean(double(wssValid(idx))));

    fprintf('IMU valid ratio = %.6f\n', ...
        mean(double(imuValid(idx))));

end

%% =========================================================
% 10. 第一阶段参考值
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('参考第一阶段 kH=0 在线结果：\n');
fprintf('-----------------------------------------------------\n');

fprintf('A : alphaW ~= 0.975610, RMSE ~= 0.002829\n');
fprintf('B : alphaW ~= 0.274248, RMSE ~= 0.155896\n');
fprintf('C : alphaW ~= 0.296226, RMSE ~= 0.166861\n');
fprintf('E : alphaW ~= 0.975610, RMSE ~= 0.000864\n');

fprintf('=====================================================\n');