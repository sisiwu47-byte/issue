%% =========================================================
% scan_a0_kA_realAx_ABCE.m
%
% 使用真正在线输入：
%       Ax = est_u(:,9)
%
% 第一阶段：
%       kH = 0
%
% 动态顶层融合修正：
%
%   uA = sat((|Ax|-a0)/(a1-a0),0,1)
%   sA = 3*uA^2 - 2*uA^3
%
%   PW_fuse = PW * (1 + kA*sA)
%
% 本脚本联合检查：
%       a0敏感性 + kA标定
%
% a1由B/C正常动态数据自动确定。
%
% 注意：
% 不使用gradient(Vx_true)
% 不使用movmean(Ax)
% 不改变局部KF
% ==========================================================

clc
clear

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
% 1. est_y / est_u映射
% ==========================================================

COL_VXFUSED = 1;

COL_XW = 3;
COL_PW = 4;

COL_XI = 5;
COL_PI = 6;

% 当前已保存为最终融合对应的PWI_plus
COL_PWI = 7;

COL_ALPHAW = 30;
COL_ALPHAI = 31;

COL_UPDATED = 35;

% longitudinal_velocity_estimator.m:
% Ax = est_u(9)
COL_AX_U = 9;

%% =========================================================
% 2. 本轮固定
% ==========================================================

kH = 0;

fprintf('\n');
fprintf('第一阶段固定 kH = %.1f\n',kH);

%% =========================================================
% 3. 搜索范围
%
% a0：
% 当前仿真稳态Ax过于理想，因此不用自动P99=2e-6。
% 做工程死区敏感性检查。
%
% kA：
% 上一轮结果显示60~100附近已经进入合理区域。
% ==========================================================

a0Grid = [ ...
    0.05 ...
    0.10 ...
    0.15 ...
    0.20 ...
    0.30];

kAGrid = 40:5:120;

%% =========================================================
% 4. 读取A/B/C/E
% ==========================================================

D = struct([]);

for ic = 1:numel(files)

    S = load(files{ic});

    if ~isfield(S,'E')
        error('%s中不存在结构体E。',files{ic});
    end

    E = S.E;

    %% -----------------------------------------------------
    % est_u检查
    % ------------------------------------------------------

    if ~isfield(E,'est_u_time') || ...
       ~isfield(E,'est_u_data')

        error('%s没有保存est_u_time/est_u_data。', ...
            files{ic});

    end

    Utime = E.est_u_time(:);
    U     = E.est_u_data;

    if size(U,1) ~= numel(Utime)

        if size(U,2) == numel(Utime)
            U = U.';
        else
            error('%s的est_u尺寸无法与时间对应。', ...
                files{ic});
        end

    end

    if size(U,2) < 18
        error('%s的est_u不足18列。',files{ic});
    end

    %% -----------------------------------------------------
    % estimator真实更新时间
    % ------------------------------------------------------

    updated = ...
        E.est_y_data(:,COL_UPDATED) > 0.5;

    t = E.est_y_time(updated);
    Y = E.est_y_data(updated,:);

    %% -----------------------------------------------------
    % 真值仅用于评价RMSE
    % ------------------------------------------------------

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t(:), ...
        'linear', ...
        NaN);

    %% -----------------------------------------------------
    % 真正在线Ax = est_u(:,9)
    % ------------------------------------------------------

    Ax = interp1( ...
        Utime, ...
        U(:,COL_AX_U), ...
        t(:), ...
        'linear', ...
        NaN);

    good = ...
        isfinite(t) & ...
        isfinite(vxTrue) & ...
        isfinite(Ax) & ...
        isfinite(Y(:,COL_XW)) & ...
        isfinite(Y(:,COL_PW)) & ...
        isfinite(Y(:,COL_XI)) & ...
        isfinite(Y(:,COL_PI)) & ...
        isfinite(Y(:,COL_PWI));

    t      = t(good);
    Y      = Y(good,:);
    vxTrue = vxTrue(good);
    Ax     = Ax(good);

    D(ic).name = names{ic};

    D(ic).t  = t;
    D(ic).vx = vxTrue;

    % 不平滑，直接用在线Ax
    D(ic).Ax = Ax;

    D(ic).xW = Y(:,COL_XW);
    D(ic).PW = Y(:,COL_PW);

    D(ic).xI = Y(:,COL_XI);
    D(ic).PI = Y(:,COL_PI);

    D(ic).PWI = Y(:,COL_PWI);

    D(ic).vxOld = Y(:,COL_VXFUSED);

    D(ic).alphaWOld = Y(:,COL_ALPHAW);
    D(ic).alphaIOld = Y(:,COL_ALPHAI);

    % 本轮统一3~8s
    D(ic).idx = ...
        t >= 3.0 & ...
        t < 8.0;

end

%% =========================================================
% 5. 用真实Ax重新确定a1
%
% B/C正常动态联合P50
% ==========================================================

dynamicAx = [ ...
    abs(D(2).Ax(D(2).idx)); ...
    abs(D(3).Ax(D(3).idx))];

a1 = prctile(dynamicAx,50);

fprintf('\n');
fprintf('=====================================================\n');
fprintf('       动态上阈值 a1\n');
fprintf('=====================================================\n');

fprintf('a1 = %.6f m/s^2\n',a1);

if ~isfinite(a1) || a1 <= max(a0Grid)

    error('a1异常或小于a0扫描范围。');

end

%% =========================================================
% 6. 当前在线基线
% ==========================================================

oldRMSE  = nan(1,4);
oldAlpha = nan(1,4);

fprintf('\n');
fprintf('=====================================================\n');
fprintf('             当前在线基线\n');
fprintf('=====================================================\n');

for ic = 1:4

    idx = D(ic).idx;

    oldRMSE(ic) = sqrt(mean( ...
        (D(ic).vxOld(idx)-D(ic).vx(idx)).^2));

    oldAlpha(ic) = ...
        mean(D(ic).alphaWOld(idx));

    fprintf('\n%s\n',D(ic).name);

    fprintf('RMSE   = %.6f m/s\n',oldRMSE(ic));
    fprintf('alphaW = %.6f\n',oldAlpha(ic));

end

%% =========================================================
% 7. 联合扫描 a0 × kA
% ==========================================================

R = [];
row = 0;

for ia0 = 1:numel(a0Grid)

    a0 = a0Grid(ia0);

    %% -----------------------------------------------------
    % 先为这个a0计算四个工况sA
    % ------------------------------------------------------

    SA = cell(1,4);

    for ic = 1:4

        u = ...
            (abs(D(ic).Ax)-a0) ./ ...
            (a1-a0);

        u = min(max(u,0),1);

        SA{ic} = ...
            3*u.^2 - 2*u.^3;

    end

    for ik = 1:numel(kAGrid)

        kA = kAGrid(ik);

        meanAlpha = nan(1,4);
        rmseNew   = nan(1,4);
        pwRatio   = nan(1,4);
        meanSA    = nan(1,4);

        candidateOK = true;

        for ic = 1:4

            idx = D(ic).idx;

            PW  = D(ic).PW;
            PI  = D(ic).PI;
            PWI = D(ic).PWI;

            sA = SA{ic};

            %% ---------------------------------------------
            % kH=0
            % ----------------------------------------------

            PWf = ...
                PW .* (1 + kA*sA);

            %% ---------------------------------------------
            % 候选相关融合
            % ----------------------------------------------

            den = ...
                PWf + PI - 2*PWI;

            detPhi = ...
                PWf .* PI - PWI.^2;

            valid = ...
                idx & ...
                isfinite(PWf) & ...
                isfinite(PI) & ...
                isfinite(PWI) & ...
                isfinite(den) & ...
                den > 1e-14 & ...
                detPhi >= -1e-14;

            if sum(valid) < 0.99*sum(idx)

                candidateOK = false;
                break

            end

            alphaW = nan(size(PW));
            alphaI = nan(size(PW));

            alphaW(valid) = ...
                (PI(valid)-PWI(valid)) ./ ...
                den(valid);

            alphaI(valid) = ...
                (PWf(valid)-PWI(valid)) ./ ...
                den(valid);

            %% ---------------------------------------------
            % 与当前相关融合函数一致：
            % 不做[0,1] clip，只进行和归一化
            % ----------------------------------------------

            sumAlpha = ...
                alphaW + alphaI;

            valid2 = ...
                valid & ...
                isfinite(sumAlpha) & ...
                abs(sumAlpha) > 1e-14;

            alphaW(valid2) = ...
                alphaW(valid2) ./ ...
                sumAlpha(valid2);

            alphaI(valid2) = ...
                alphaI(valid2) ./ ...
                sumAlpha(valid2);

            %% ---------------------------------------------
            % 融合速度
            % ----------------------------------------------

            vxCand = nan(size(PW));

            vxCand(valid2) = ...
                alphaW(valid2).*D(ic).xW(valid2) + ...
                alphaI(valid2).*D(ic).xI(valid2);

            use = valid2;

            meanAlpha(ic) = ...
                mean(alphaW(use));

            rmseNew(ic) = ...
                sqrt(mean( ...
                (vxCand(use)-D(ic).vx(use)).^2));

            pwRatio(ic) = ...
                median(PWf(use) ./ ...
                max(PW(use),1e-15));

            meanSA(ic) = ...
                mean(sA(use));

        end

        if ~candidateOK
            continue
        end

        %% =================================================
        % 8. 约束
        % ==================================================

        % A/E健康稳态仍然WSS主导
        if meanAlpha(1) < 0.90 || ...
           meanAlpha(4) < 0.90

            continue
        end

        % B/C：
        % 第一版目标范围20~30% WSS
        if meanAlpha(2) < 0.20 || ...
           meanAlpha(2) > 0.30 || ...
           meanAlpha(3) < 0.20 || ...
           meanAlpha(3) > 0.30

            continue
        end

        % A/E稳态性能保护
        tolA = max(0.05*oldRMSE(1),5e-5);
        tolE = max(0.05*oldRMSE(4),5e-5);

        if rmseNew(1) > oldRMSE(1)+tolA || ...
           rmseNew(4) > oldRMSE(4)+tolE

            continue
        end

        %% -------------------------------------------------
        % 记录
        %
        % 不把RMSE作为唯一排序条件。
        % --------------------------------------------------

        row = row + 1;

        R(row,:) = [ ...
            a0, ...
            a1, ...
            kA, ...
            meanAlpha, ...
            rmseNew, ...
            pwRatio, ...
            meanSA]; %#ok<SAGROW>

    end

end

%% =========================================================
% 9. 输出所有可行候选
%
% R:
%
% 1    a0
% 2    a1
% 3    kA
%
% 4:7   alpha A/B/C/E
% 8:11  RMSE A/B/C/E
% 12:15 PWratio
% 16:19 mean sA
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('             a0 × kA 可行候选\n');
fprintf('=====================================================\n');

if isempty(R)

    fprintf('\n没有满足当前约束的候选。\n');
    fprintf('此时不要直接扩大kA。\n');

else

    %% -----------------------------------------------------
    % 排序原则：
    %
    % 先按kA从小到大，
    % 相同kA下再按B/C平均RMSE。
    %
    % 即优先使用较小的协方差膨胀。
    % ------------------------------------------------------

    dynamicRMSE = ...
        0.5*(R(:,9)+R(:,10));

    Rsort = [R dynamicRMSE];

    Rsort = sortrows(Rsort,[3 20]);

    fprintf('\n共找到 %d 个可行候选。\n', ...
        size(Rsort,1));

    Nshow = min(20,size(Rsort,1));

    fprintf('\n前%d个（优先较小kA）：\n\n',Nshow);

    for i = 1:Nshow

        fprintf([ ...
            '%2d) a0=%.2f, a1=%.4f, kA=%5.1f | ' ...
            'alpha=[%.3f %.3f %.3f %.3f] | ' ...
            'RMSE=[%.6f %.6f %.6f %.6f] | ' ...
            'PWratio=[%.1f %.1f %.1f %.1f] | ' ...
            'sA=[%.3f %.3f %.3f %.3f]\n'], ...
            i, ...
            Rsort(i,1), ...
            Rsort(i,2), ...
            Rsort(i,3), ...
            Rsort(i,4),Rsort(i,5), ...
            Rsort(i,6),Rsort(i,7), ...
            Rsort(i,8),Rsort(i,9), ...
            Rsort(i,10),Rsort(i,11), ...
            Rsort(i,12),Rsort(i,13), ...
            Rsort(i,14),Rsort(i,15), ...
            Rsort(i,16),Rsort(i,17), ...
            Rsort(i,18),Rsort(i,19));

    end

    %% -----------------------------------------------------
    % 再找动态RMSE最好的候选，仅作为参考
    % ------------------------------------------------------

    [~,ibest] = min(dynamicRMSE);

    bestRMSE = R(ibest,:);

    fprintf('\n----------------------------------------\n');
    fprintf('动态RMSE最低的可行候选，仅作参考：\n');

    fprintf('a0 = %.3f\n',bestRMSE(1));
    fprintf('a1 = %.6f\n',bestRMSE(2));
    fprintf('kA = %.3f\n',bestRMSE(3));

    fprintf('B alphaW = %.6f\n',bestRMSE(5));
    fprintf('C alphaW = %.6f\n',bestRMSE(6));

    fprintf('B RMSE = %.6f m/s\n',bestRMSE(9));
    fprintf('C RMSE = %.6f m/s\n',bestRMSE(10));

end

fprintf('\n=====================================================\n');