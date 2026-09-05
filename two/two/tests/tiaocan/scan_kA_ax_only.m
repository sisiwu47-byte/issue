%% =========================================================
% scan_kA_ax_only.m
%
% 第一阶段：只标定动态融合修正 kA
%
% 候选公式：
%
%   PW_fuse = PW * (1 + kA*sA + kH*sH)
%
% 本阶段强制：
%
%   kH = 0
%
% 因此：
%
%   PW_fuse = PW * (1 + kA*sA)
%
% 局部KF完全冻结：
%   xW / PW / xI / PI 均不改变
%
% A：高附匀速
% B：高附加速
% C：高附减速
% E：低附匀速
%
% 注意：
% 当前 ax 由 Vx_true 数值微分，仅用于离线参数标定。
% 最终在线实现必须使用实际可获得的 IMU 纵向加速度。
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
% 1. est_y列定义
% ==========================================================

COL_VXFUSED = 1;

COL_XW = 3;
COL_PW = 4;

COL_XI = 5;
COL_PI = 6;

% 已确认改成最终融合对应PWI_plus
COL_PWI = 7;

COL_ALPHAW = 30;
COL_ALPHAI = 31;

COL_UPDATED = 35;

%% =========================================================
% 2. 第一阶段参数
% ==========================================================

% ---------------------------------------------------------
% 关键：
% 第一阶段禁用健康项
% ---------------------------------------------------------

kH = 0;

fprintf('\n第一阶段固定 kH = %.1f\n',kH);

% ---------------------------------------------------------
% kA扫描范围
%
% 你现在B/C反解得到旧PW_fuse/PW约23~26，
% 因此新的kA很可能落在几十量级附近。
%
% 第一遍故意扫得稍宽。
% ---------------------------------------------------------

kAGrid = [ ...
     0 ...
     1 2 3 4 5 ...
     7.5 10 12.5 15 ...
     17.5 20 22.5 25 ...
     27.5 30 35 40 ...
     50 60 80 100];

%% =========================================================
% 3. 读取四个工况
% ==========================================================

D = struct([]);

for ic = 1:numel(files)

    S = load(files{ic});

    if ~isfield(S,'E')
        error('%s 中不存在结构体E。',files{ic});
    end

    X = S.E;

    updated = ...
        X.est_y_data(:,COL_UPDATED) > 0.5;

    t = X.est_y_time(updated);

    Y = X.est_y_data(updated,:);

    vxTrue = interp1( ...
        X.Vx_true_time(:), ...
        X.Vx_true_data(:), ...
        t(:), ...
        'linear');

    good = ...
        isfinite(vxTrue) & ...
        isfinite(Y(:,COL_XW)) & ...
        isfinite(Y(:,COL_PW)) & ...
        isfinite(Y(:,COL_XI)) & ...
        isfinite(Y(:,COL_PI)) & ...
        isfinite(Y(:,COL_PWI));

    t      = t(good);
    Y      = Y(good,:);
    vxTrue = vxTrue(good);

    D(ic).name = names{ic};

    D(ic).t  = t;
    D(ic).Y  = Y;
    D(ic).vx = vxTrue;

    D(ic).xW  = Y(:,COL_XW);
    D(ic).PW  = Y(:,COL_PW);

    D(ic).xI  = Y(:,COL_XI);
    D(ic).PI  = Y(:,COL_PI);

    D(ic).PWI = Y(:,COL_PWI);

    D(ic).vxOld = Y(:,COL_VXFUSED);

    D(ic).alphaWOld = ...
        Y(:,COL_ALPHAW);

    D(ic).alphaIOld = ...
        Y(:,COL_ALPHAI);

    %% -----------------------------------------------------
    % 离线真实纵向加速度
    %
    % gradient后用约0.11 s移动平均抑制数值微分噪声
    % ------------------------------------------------------

    axRaw = gradient(vxTrue,t);

    axFilt = movmean(axRaw,11);

    D(ic).ax = axFilt;

    %% -----------------------------------------------------
    % 所有工况统一比较3~8s
    %
    % A/E是稳态对照
    % B/C是真正动态阶段
    % ------------------------------------------------------

    D(ic).idx = ...
        t >= 3.0 & ...
        t < 8.0;

end

%% =========================================================
% 4. 先看四个工况的|ax|分布
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('              |ax| 分布检查\n');
fprintf('=====================================================\n');

for ic = 1:numel(D)

    aa = ...
        abs(D(ic).ax(D(ic).idx));

    fprintf('\n%s\n',D(ic).name);

    fprintf('|ax| mean = %.6f m/s^2\n', ...
        mean(aa));

    fprintf('|ax| P50  = %.6f m/s^2\n', ...
        prctile(aa,50));

    fprintf('|ax| P95  = %.6f m/s^2\n', ...
        prctile(aa,95));

    fprintf('|ax| P99  = %.6f m/s^2\n', ...
        prctile(aa,99));

    fprintf('|ax| max  = %.6f m/s^2\n', ...
        max(aa));

end

%% =========================================================
% 5. 自动确定动态项两个阈值 a0 / a1
%
% a0：
% A/E稳态99%样本以下不触发动态修正
%
% a1：
% B/C动态绝对加速度中位数处达到完全动态状态
% ==========================================================

steadyAx = [ ...
    abs(D(1).ax(D(1).idx)); ...
    abs(D(4).ax(D(4).idx))];

dynamicAx = [ ...
    abs(D(2).ax(D(2).idx)); ...
    abs(D(3).ax(D(3).idx))];

a0 = prctile(steadyAx,99);

% 给一个很小的数值下限
a0 = max(a0,0.02);

a1 = prctile(dynamicAx,50);

fprintf('\n');
fprintf('=====================================================\n');
fprintf('             自动动态阈值\n');
fprintf('=====================================================\n');

fprintf('a0 = %.6f m/s^2\n',a0);
fprintf('a1 = %.6f m/s^2\n',a1);

if ~isfinite(a0) || ...
   ~isfinite(a1) || ...
   a1 <= a0

    error([ ...
        'A/E稳态与B/C动态的ax无法正确分离。' ...
        '此时不要继续扫描kA。']);

end

%% =========================================================
% 6. 构造平滑动态指标 sA
%
%       0                  |ax| <= a0
%
% u = (|ax|-a0)/(a1-a0)
%
%       1                  |ax| >= a1
%
% 再：
%
% sA = 3u^2 - 2u^3
%
% 因此：
%
% 0 <= sA <= 1
% ==========================================================

for ic = 1:numel(D)

    u = ...
        (abs(D(ic).ax)-a0) ./ ...
        (a1-a0);

    u = min(max(u,0),1);

    D(ic).sA = ...
        3*u.^2 - 2*u.^3;

end

fprintf('\n');
fprintf('===== sA检查 =====\n');

for ic = 1:numel(D)

    ss = D(ic).sA(D(ic).idx);

    fprintf('%s: mean(sA)=%.6f, P95=%.6f\n', ...
        D(ic).name, ...
        mean(ss), ...
        prctile(ss,95));

end

%% =========================================================
% 7. 当前在线结果作为基线
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('              当前在线基线\n');
fprintf('=====================================================\n');

oldRMSE  = nan(1,4);
oldAlpha = nan(1,4);

for ic = 1:4

    idx = D(ic).idx;

    oldRMSE(ic) = ...
        sqrt(mean( ...
        (D(ic).vxOld(idx)-D(ic).vx(idx)).^2));

    oldAlpha(ic) = ...
        mean(D(ic).alphaWOld(idx));

    fprintf('\n%s\n',D(ic).name);

    fprintf('当前融合RMSE   = %.6f m/s\n', ...
        oldRMSE(ic));

    fprintf('当前平均alphaW = %.6f\n', ...
        oldAlpha(ic));

end

%% =========================================================
% 8. 扫描kA
%
% 第一阶段明确：
%
% kH = 0
%
% 所以：
%
% PWfuse = PW*(1 + kA*sA)
%
% 注意：
% 这里从局部原始PW重新构造候选PW_fuse，
% 不是在旧PW_fuse基础上继续乘。
% ==========================================================

R = [];

row = 0;

for ik = 1:numel(kAGrid)

    kA = kAGrid(ik);

    meanAlphaW = nan(1,4);
    minAlphaW  = nan(1,4);
    maxAlphaW  = nan(1,4);

    rmseNew = nan(1,4);

    ratioPW = nan(1,4);

    candidateOK = true;

    for ic = 1:4

        idx = D(ic).idx;

        PW  = D(ic).PW;
        PI  = D(ic).PI;
        PWI = D(ic).PWI;

        sA = D(ic).sA;

        %% -------------------------------------------------
        % 第一阶段kH=0
        %
        % 完整理论式：
        %
        % PWf = PW*(1+kA*sA+kH*sH)
        %
        % 因为kH=0，本阶段简化：
        % --------------------------------------------------

        PWf = ...
            PW .* (1 + kA*sA);

        %% -------------------------------------------------
        % 检查候选Phi
        % --------------------------------------------------

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

        %% -------------------------------------------------
        % 两轨相关融合权重
        % --------------------------------------------------

        alphaW = nan(size(PW));
        alphaI = nan(size(PW));

        alphaW(valid) = ...
            (PI(valid)-PWI(valid)) ./ ...
            den(valid);

        alphaI(valid) = ...
            (PWf(valid)-PWI(valid)) ./ ...
            den(valid);

        % 与现有算法逻辑一致：
        % 不进行[0,1]硬截断，仅做和归一化
        s = alphaW + alphaI;

        valid2 = ...
            valid & ...
            isfinite(s) & ...
            abs(s) > 1e-14;

        alphaW(valid2) = ...
            alphaW(valid2) ./ s(valid2);

        alphaI(valid2) = ...
            alphaI(valid2) ./ s(valid2);

        %% -------------------------------------------------
        % 候选融合速度
        % --------------------------------------------------

        vxCand = nan(size(PW));

        vxCand(valid2) = ...
            alphaW(valid2).*D(ic).xW(valid2) + ...
            alphaI(valid2).*D(ic).xI(valid2);

        %% -------------------------------------------------
        % 统计
        % --------------------------------------------------

        use = valid2;

        rmseNew(ic) = ...
            sqrt(mean( ...
            (vxCand(use)-D(ic).vx(use)).^2));

        meanAlphaW(ic) = ...
            mean(alphaW(use));

        minAlphaW(ic) = ...
            min(alphaW(use));

        maxAlphaW(ic) = ...
            max(alphaW(use));

        ratioPW(ic) = ...
            median(PWf(use) ./ ...
            max(PW(use),1e-15));

    end

    if ~candidateOK
        continue
    end

    %% -----------------------------------------------------
    % 第一轮保护条件
    %
    % 1. A/E健康稳态必须仍由WSS主导
    % 2. B/C不能出现明显失控权重
    % ------------------------------------------------------

    if meanAlphaW(1) < 0.90 || ...
       meanAlphaW(4) < 0.90

        continue
    end

    % 第一轮不要求精确命中某个理论权重，
    % 但先避免平均权重跑到过度极端区。
    if meanAlphaW(2) < 0.05 || ...
       meanAlphaW(2) > 0.60 || ...
       meanAlphaW(3) < 0.05 || ...
       meanAlphaW(3) > 0.60

        continue
    end

    %% -----------------------------------------------------
    % 稳态性能不能明显恶化
    %
    % 允许：
    % 5%或5e-5 m/s，两者取较大
    % ------------------------------------------------------

    tolA = max(0.05*oldRMSE(1),5e-5);
    tolE = max(0.05*oldRMSE(4),5e-5);

    if rmseNew(1) > oldRMSE(1)+tolA
        continue
    end

    if rmseNew(4) > oldRMSE(4)+tolE
        continue
    end

    %% -----------------------------------------------------
    % 评分：
    %
    % B/C是本轮主要标定目标
    % A/E只作为保护
    % ------------------------------------------------------

    score = ...
        0.45*rmseNew(2) + ...
        0.45*rmseNew(3) + ...
        0.05*rmseNew(1) + ...
        0.05*rmseNew(4);

    row = row + 1;

    R(row,:) = [ ...
        score, ...
        kA, ...
        meanAlphaW, ...
        rmseNew, ...
        ratioPW]; %#ok<SAGROW>

end

%% =========================================================
% 9. 输出结果
%
% R列：
%
% 1  score
% 2  kA
%
% 3~6   A/B/C/E平均alphaW
% 7~10  A/B/C/E RMSE
% 11~14 A/B/C/E PWfuse/PW中位数
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('              kA扫描结果\n');
fprintf('=====================================================\n');

if isempty(R)

    fprintf('\n没有找到满足第一轮约束的kA。\n');
    fprintf('不要立即扩大kA范围。\n');
    fprintf('先检查上面的a0/a1、sA以及当前RMSE。\n');

else

    R = sortrows(R,1);

    best = R(1,:);

    fprintf('\n最佳候选：\n');

    fprintf('kH = %.1f（本轮固定）\n',kH);
    fprintf('kA = %.6f\n',best(2));

    fprintf('\n平均alphaW：\n');

    fprintf('A = %.6f\n',best(3));
    fprintf('B = %.6f\n',best(4));
    fprintf('C = %.6f\n',best(5));
    fprintf('E = %.6f\n',best(6));

    fprintf('\n候选融合RMSE：\n');

    fprintf('A = %.6f m/s\n',best(7));
    fprintf('B = %.6f m/s\n',best(8));
    fprintf('C = %.6f m/s\n',best(9));
    fprintf('E = %.6f m/s\n',best(10));

    fprintf('\nPW_fuse/PW中位数：\n');

    fprintf('A = %.3f\n',best(11));
    fprintf('B = %.3f\n',best(12));
    fprintf('C = %.3f\n',best(13));
    fprintf('E = %.3f\n',best(14));

    fprintf('\n当前在线 vs 新候选RMSE：\n');

    fprintf('A: %.6f -> %.6f\n', ...
        oldRMSE(1),best(7));

    fprintf('B: %.6f -> %.6f\n', ...
        oldRMSE(2),best(8));

    fprintf('C: %.6f -> %.6f\n', ...
        oldRMSE(3),best(9));

    fprintf('E: %.6f -> %.6f\n', ...
        oldRMSE(4),best(10));

    fprintf('\n前10个候选：\n');

    Nshow = min(10,size(R,1));

    for i = 1:Nshow

        fprintf([ ...
            '%2d) kA=%6.2f | ' ...
            'alphaW=[%.3f %.3f %.3f %.3f] | ' ...
            'RMSE=[%.6f %.6f %.6f %.6f] | ' ...
            'PWratio=[%.2f %.2f %.2f %.2f]\n'], ...
            i, ...
            R(i,2), ...
            R(i,3),R(i,4),R(i,5),R(i,6), ...
            R(i,7),R(i,8),R(i,9),R(i,10), ...
            R(i,11),R(i,12),R(i,13),R(i,14));

    end

end

fprintf('\n=====================================================\n');