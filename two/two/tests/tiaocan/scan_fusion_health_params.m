%% =========================================================
% scan_fusion_health_params.m
%
% WSS/IMU顶层融合健康度离线参数扫描
%
% 候选修正：
%
%   hW = mean(rhoWheel .* wheelValid)
%
%   dWI = min(abs(xW - xI), dWI_cap)
%
%   PW_fuse = PW ...
%           + kD * dWI^2 ...
%           + kH * (1-hW)^2 * PI
%
% 只用于离线重新计算顶层融合：
%   不修改WSS局部KF
%   不修改IMU局部KF
%   不修改eAbs
%   不修改wheelLocked
%   不修改18输入/38输出
%   不重新运行CarSim
%
% 扫描目标：
%   A：稳态不明显恶化
%   B：动态阶段RMSE改善
%   C：正常减速不明显恶化
%   E：动态/后轮锁定阶段明显改善
%   E：恢复后重新回到WSS主导
% ==========================================================

clc
clear
close all

rootDir = 'D:\two\two';

fprintf('\n');
fprintf('=====================================================\n');
fprintf('       WSS/IMU 顶层融合离线参数扫描\n');
fprintf('=====================================================\n');


%% =========================================================
% 1. 扫描参数
% ==========================================================

kD_list = [ ...
    0.02 ...
    0.04 ...
    0.06 ...
    0.08 ...
    0.10];

kH_list = [ ...
    0.0 ...
    0.5 ...
    1.0 ...
    1.5 ...
    2.0];

% 双轨迹分歧上限
dWI_cap = 0.50;       % m/s

fprintf('\nkD扫描：\n');
disp(kD_list);

fprintf('kH扫描：\n');
disp(kH_list);

fprintf('dWI_cap = %.3f m/s\n',dWI_cap);

fprintf('总组合数 = %d\n', ...
    numel(kD_list)*numel(kH_list));


%% =========================================================
% 2. 验收标准
%
% 注意：
% 这些不是算法参数，只是离线筛选标准。
% ==========================================================

criteria.A_max_ratio = 1.02;      % A RMSE最多恶化2%
criteria.C_max_ratio = 1.02;      % C RMSE最多恶化2%

criteria.B_min_improve_pct = 3.0; % B至少改善3%

criteria.E_dyn_min_improve_pct  = 3.0;
criteria.E_lock_min_improve_pct = 5.0;

criteria.E_rec_max_ratio = 1.05;  % E恢复后最多恶化5%

% 稳态/恢复后要求重新偏向WSS
criteria.A_min_WSS_weight = 0.90;
criteria.E_rec_min_WSS_weight = 0.90;


%% =========================================================
% 3. 自动定位A/B/C/E结果文件
%
% 优先：
%   D:\two\two\tests\
%   D:\two\two\
%   D:\two\two\results\
%
% 如果发现多个同名文件会直接报错，避免再次读到旧结果。
% ==========================================================

caseNames = {'A','B','C','E'};

D = struct();

for iCase = 1:numel(caseNames)

    c = caseNames{iCase};

    filePath = resolve_case_file(rootDir,c);

    fprintf('\n------------------------------------------\n');
    fprintf('读取工况 %s\n',c);
    fprintf('文件：%s\n',filePath);

    D.(c) = load_case_data(filePath,c);

    fprintf('100Hz更新点 = %d\n', ...
        numel(D.(c).t));

    fprintf('分析时间 = %.3f ~ %.3f s\n', ...
        D.(c).t(1), ...
        D.(c).t(end));

end


%% =========================================================
% 4. 自动识别E-main后轮锁定和恢复时间
% ==========================================================

[tLockStart,tLockEnd] = ...
    detect_rear_lock_window(D.E);

fprintf('\n=====================================================\n');
fprintf('             E-main锁定区间识别\n');
fprintf('=====================================================\n');

fprintf('后轮第一次 valid -> invalid = %.3f s\n', ...
    tLockStart);

fprintf('后轮第一次 invalid -> valid = %.3f s\n', ...
    tLockEnd);

fprintf('后轮失效持续时间 = %.3f s\n', ...
    tLockEnd-tLockStart);


%% =========================================================
% 5. 定义各工况评价区间
% ==========================================================

idxA = ...
    D.A.t >= 3.0 & ...
    D.A.t < 8.0;

idxB = ...
    D.B.t >= 3.0 & ...
    D.B.t < 8.0;

idxC = ...
    D.C.t >= 3.0 & ...
    D.C.t < 8.0;

idxE_dyn = ...
    D.E.t >= 3.0 & ...
    D.E.t < 8.0;

idxE_lock = ...
    D.E.t >= tLockStart & ...
    D.E.t < tLockEnd;

% 恢复后取2s
tRecEnd = min(tLockEnd+2.0,D.E.t(end));

idxE_rec = ...
    D.E.t >= tLockEnd & ...
    D.E.t < tRecEnd;


%% =========================================================
% 6. 先检查离线公式能不能重构当前在线融合
%
% kD=0,kH=0时应该：
%   vxCandidate ≈ 当前est_y(:,1)
%   alphaW      ≈ 当前est_y(:,30)
%   alphaI      ≈ 当前est_y(:,31)
%
% 如果不一致，后面的扫描不能使用。
% ==========================================================

fprintf('\n=====================================================\n');
fprintf('       当前融合公式离线重构一致性检查\n');
fprintf('=====================================================\n');

reconstructOK = true;

for iCase = 1:numel(caseNames)

    c = caseNames{iCase};
    d = D.(c);

    [x0,wW0,wI0,~] = ...
        candidate_fusion(d,0,0,dWI_cap);

    idxCheck = d.t >= 0.6;

    dx = max(abs( ...
        x0(idxCheck) - ...
        d.xFused(idxCheck)));

    dw = max(abs( ...
        wW0(idxCheck) - ...
        d.wWss(idxCheck)));

    di = max(abs( ...
        wI0(idxCheck) - ...
        d.wImu(idxCheck)));

    fprintf('\n工况 %s\n',c);
    fprintf('max |FUSED重构-原FUSED| = %.12e\n',dx);
    fprintf('max |alphaW重构-原alphaW| = %.12e\n',dw);
    fprintf('max |alphaI重构-原alphaI| = %.12e\n',di);

    if dx > 1e-6 || dw > 1e-6 || di > 1e-6
        reconstructOK = false;
        fprintf('[FAIL] 重构不一致。\n');
    else
        fprintf('[PASS] 重构一致。\n');
    end

end

if ~reconstructOK

    error(['离线公式无法重构当前融合结果。' ...
           '请先停止参数扫描，检查PWI/权重数据定义。']);

end


%% =========================================================
% 7. 当前版本基线
% ==========================================================

base.A = perf_metric( ...
    D.A.xFused, ...
    D.A.vxTrue, ...
    idxA);

base.B = perf_metric( ...
    D.B.xFused, ...
    D.B.vxTrue, ...
    idxB);

base.C = perf_metric( ...
    D.C.xFused, ...
    D.C.vxTrue, ...
    idxC);

base.E_dyn = perf_metric( ...
    D.E.xFused, ...
    D.E.vxTrue, ...
    idxE_dyn);

base.E_lock = perf_metric( ...
    D.E.xFused, ...
    D.E.vxTrue, ...
    idxE_lock);

base.E_rec = perf_metric( ...
    D.E.xFused, ...
    D.E.vxTrue, ...
    idxE_rec);

fprintf('\n=====================================================\n');
fprintf('             当前在线版本基线\n');
fprintf('=====================================================\n');

fprintf('A 3~8s RMSE = %.6f m/s\n',base.A.rmse);
fprintf('B 3~8s RMSE = %.6f m/s\n',base.B.rmse);
fprintf('C 3~8s RMSE = %.6f m/s\n',base.C.rmse);

fprintf('\nE 3~8s RMSE = %.6f m/s\n', ...
    base.E_dyn.rmse);

fprintf('E锁定阶段RMSE = %.6f m/s\n', ...
    base.E_lock.rmse);

fprintf('E恢复后RMSE = %.6f m/s\n', ...
    base.E_rec.rmse);

fprintf('\n当前平均WSS权重：\n');
fprintf('A = %.6f\n',mean(D.A.wWss(idxA)));
fprintf('B = %.6f\n',mean(D.B.wWss(idxB)));
fprintf('C = %.6f\n',mean(D.C.wWss(idxC)));

fprintf('E动态 = %.6f\n', ...
    mean(D.E.wWss(idxE_dyn)));

fprintf('E锁定 = %.6f\n', ...
    mean(D.E.wWss(idxE_lock)));

fprintf('E恢复 = %.6f\n', ...
    mean(D.E.wWss(idxE_rec)));


%% =========================================================
% 8. 建立结果数组
% ==========================================================

N = numel(kD_list)*numel(kH_list);

kD_result = zeros(N,1);
kH_result = zeros(N,1);

A_RMSE = zeros(N,1);
A_ratio = zeros(N,1);
A_WSS = zeros(N,1);

B_RMSE = zeros(N,1);
B_improve = zeros(N,1);
B_WSS = zeros(N,1);

C_RMSE = zeros(N,1);
C_ratio = zeros(N,1);
C_WSS = zeros(N,1);

E_dyn_RMSE = zeros(N,1);
E_dyn_improve = zeros(N,1);
E_dyn_WSS = zeros(N,1);

E_lock_RMSE = zeros(N,1);
E_lock_MAE = zeros(N,1);
E_lock_MAX = zeros(N,1);
E_lock_improve = zeros(N,1);
E_lock_WSS = zeros(N,1);
E_lock_IMU = zeros(N,1);

E_rec_RMSE = zeros(N,1);
E_rec_ratio = zeros(N,1);
E_rec_WSS = zeros(N,1);

weightSafe = false(N,1);
Pass = false(N,1);
Score = zeros(N,1);

row = 0;


%% =========================================================
% 9. 开始25组扫描
% ==========================================================

fprintf('\n=====================================================\n');
fprintf('               开始25组扫描\n');
fprintf('=====================================================\n');

for iD = 1:numel(kD_list)

    for iH = 1:numel(kH_list)

        row = row + 1;

        kD = kD_list(iD);
        kH = kH_list(iH);

        %% -----------------------------------------------
        % A
        % -----------------------------------------------

        [xA,wWA,~,~] = ...
            candidate_fusion( ...
            D.A,kD,kH,dWI_cap);

        mA = perf_metric( ...
            xA,D.A.vxTrue,idxA);

        %% -----------------------------------------------
        % B
        % -----------------------------------------------

        [xB,wWB,~,~] = ...
            candidate_fusion( ...
            D.B,kD,kH,dWI_cap);

        mB = perf_metric( ...
            xB,D.B.vxTrue,idxB);

        %% -----------------------------------------------
        % C
        % -----------------------------------------------

        [xC,wWC,~,~] = ...
            candidate_fusion( ...
            D.C,kD,kH,dWI_cap);

        mC = perf_metric( ...
            xC,D.C.vxTrue,idxC);

        %% -----------------------------------------------
        % E
        % -----------------------------------------------

        [xE,wWE,wIE,~] = ...
            candidate_fusion( ...
            D.E,kD,kH,dWI_cap);

        mEdyn = perf_metric( ...
            xE,D.E.vxTrue,idxE_dyn);

        mElock = perf_metric( ...
            xE,D.E.vxTrue,idxE_lock);

        mErec = perf_metric( ...
            xE,D.E.vxTrue,idxE_rec);


        %% -----------------------------------------------
        % 保存
        % -----------------------------------------------

        kD_result(row) = kD;
        kH_result(row) = kH;

        A_RMSE(row) = mA.rmse;

        A_ratio(row) = ...
            mA.rmse / base.A.rmse;

        A_WSS(row) = ...
            mean(wWA(idxA));


        B_RMSE(row) = ...
            mB.rmse;

        B_improve(row) = ...
            100 * ...
            (base.B.rmse-mB.rmse) / ...
            base.B.rmse;

        B_WSS(row) = ...
            mean(wWB(idxB));


        C_RMSE(row) = ...
            mC.rmse;

        C_ratio(row) = ...
            mC.rmse / base.C.rmse;

        C_WSS(row) = ...
            mean(wWC(idxC));


        E_dyn_RMSE(row) = ...
            mEdyn.rmse;

        E_dyn_improve(row) = ...
            100 * ...
            (base.E_dyn.rmse-mEdyn.rmse) / ...
            base.E_dyn.rmse;

        E_dyn_WSS(row) = ...
            mean(wWE(idxE_dyn));


        E_lock_RMSE(row) = ...
            mElock.rmse;

        E_lock_MAE(row) = ...
            mElock.mae;

        E_lock_MAX(row) = ...
            mElock.maxabs;

        E_lock_improve(row) = ...
            100 * ...
            (base.E_lock.rmse-mElock.rmse) / ...
            base.E_lock.rmse;

        E_lock_WSS(row) = ...
            mean(wWE(idxE_lock));

        E_lock_IMU(row) = ...
            mean(wIE(idxE_lock));


        E_rec_RMSE(row) = ...
            mErec.rmse;

        E_rec_ratio(row) = ...
            mErec.rmse / base.E_rec.rmse;

        E_rec_WSS(row) = ...
            mean(wWE(idxE_rec));


        %% -----------------------------------------------
        % 权重安全检查
        % -----------------------------------------------

        relevantWeights = [ ...
            wWA(idxA); ...
            wWB(idxB); ...
            wWC(idxC); ...
            wWE(idxE_dyn); ...
            wWE(idxE_rec)];

        weightSafe(row) = ...
            all(isfinite(relevantWeights)) && ...
            all(relevantWeights >= -1e-9) && ...
            all(relevantWeights <= 1+1e-9);


        %% -----------------------------------------------
        % PASS筛选
        % -----------------------------------------------

        passA = ...
            A_ratio(row) <= ...
            criteria.A_max_ratio;

        passB = ...
            B_improve(row) >= ...
            criteria.B_min_improve_pct;

        passC = ...
            C_ratio(row) <= ...
            criteria.C_max_ratio;

        passEdyn = ...
            E_dyn_improve(row) >= ...
            criteria.E_dyn_min_improve_pct;

        passElock = ...
            E_lock_improve(row) >= ...
            criteria.E_lock_min_improve_pct;

        passErec = ...
            E_rec_ratio(row) <= ...
            criteria.E_rec_max_ratio;

        passStableWeight = ...
            A_WSS(row) >= ...
            criteria.A_min_WSS_weight && ...
            E_rec_WSS(row) >= ...
            criteria.E_rec_min_WSS_weight;

        Pass(row) = ...
            passA && ...
            passB && ...
            passC && ...
            passEdyn && ...
            passElock && ...
            passErec && ...
            passStableWeight && ...
            weightSafe(row);


        %% -----------------------------------------------
        % 综合评分
        %
        % 越小越好。
        %
        % E锁定阶段权重最高，
        % B动态和E动态次之，
        % A/C/恢复后主要起回归约束作用。
        % -----------------------------------------------

        rA = A_ratio(row);

        rB = ...
            B_RMSE(row) / ...
            base.B.rmse;

        rC = C_ratio(row);

        rEd = ...
            E_dyn_RMSE(row) / ...
            base.E_dyn.rmse;

        rEl = ...
            E_lock_RMSE(row) / ...
            base.E_lock.rmse;

        rEr = ...
            E_rec_ratio(row);

        Score(row) = ...
            0.50*rA + ...
            1.50*rB + ...
            0.50*rC + ...
            1.00*rEd + ...
            2.00*rEl + ...
            0.50*rEr;

        % 违反基本约束时增加惩罚
        if ~weightSafe(row)
            Score(row) = Score(row)+100;
        end

        if A_WSS(row) < 0.90
            Score(row) = ...
                Score(row) + ...
                10*(0.90-A_WSS(row));
        end

        if E_rec_WSS(row) < 0.90
            Score(row) = ...
                Score(row) + ...
                10*(0.90-E_rec_WSS(row));
        end


        fprintf(['kD=%5.3f, kH=%4.1f | ' ...
                 'B改善=%6.2f%% | ' ...
                 'E锁定改善=%6.2f%% | ' ...
                 'A比=%.4f | C比=%.4f | ' ...
                 'PASS=%d\n'], ...
            kD, ...
            kH, ...
            B_improve(row), ...
            E_lock_improve(row), ...
            A_ratio(row), ...
            C_ratio(row), ...
            Pass(row));

    end

end


%% =========================================================
% 10. 建立总表
% ==========================================================

T = table( ...
    kD_result, ...
    kH_result, ...
    Pass, ...
    Score, ...
    A_RMSE, ...
    A_ratio, ...
    A_WSS, ...
    B_RMSE, ...
    B_improve, ...
    B_WSS, ...
    C_RMSE, ...
    C_ratio, ...
    C_WSS, ...
    E_dyn_RMSE, ...
    E_dyn_improve, ...
    E_dyn_WSS, ...
    E_lock_RMSE, ...
    E_lock_MAE, ...
    E_lock_MAX, ...
    E_lock_improve, ...
    E_lock_WSS, ...
    E_lock_IMU, ...
    E_rec_RMSE, ...
    E_rec_ratio, ...
    E_rec_WSS, ...
    weightSafe, ...
    'VariableNames',{ ...
        'kD', ...
        'kH', ...
        'PASS', ...
        'Score', ...
        'A_RMSE', ...
        'A_ratio', ...
        'A_WSS', ...
        'B_RMSE', ...
        'B_improve_pct', ...
        'B_WSS', ...
        'C_RMSE', ...
        'C_ratio', ...
        'C_WSS', ...
        'E_dyn_RMSE', ...
        'E_dyn_improve_pct', ...
        'E_dyn_WSS', ...
        'E_lock_RMSE', ...
        'E_lock_MAE', ...
        'E_lock_MAX', ...
        'E_lock_improve_pct', ...
        'E_lock_WSS', ...
        'E_lock_IMU', ...
        'E_rec_RMSE', ...
        'E_rec_ratio', ...
        'E_rec_WSS', ...
        'weightSafe'});


%% =========================================================
% 11. 排序
%
% PASS优先；
% PASS内部Score越低越好；
% 性能接近时，kD/kH更小的参数排前。
% ==========================================================

T.PassSort = -double(T.PASS);

T = sortrows( ...
    T, ...
    {'PassSort','Score','kD','kH'}, ...
    {'ascend','ascend','ascend','ascend'});

T.PassSort = [];


%% =========================================================
% 12. 打印TOP 10
% ==========================================================

fprintf('\n\n');
fprintf('=====================================================\n');
fprintf('                  TOP 10 参数\n');
fprintf('=====================================================\n');

nShow = min(10,height(T));

Top10 = T(1:nShow,{ ...
    'kD', ...
    'kH', ...
    'PASS', ...
    'Score', ...
    'A_ratio', ...
    'A_WSS', ...
    'B_RMSE', ...
    'B_improve_pct', ...
    'B_WSS', ...
    'C_ratio', ...
    'E_dyn_RMSE', ...
    'E_dyn_improve_pct', ...
    'E_lock_RMSE', ...
    'E_lock_improve_pct', ...
    'E_lock_WSS', ...
    'E_lock_IMU', ...
    'E_rec_ratio', ...
    'E_rec_WSS'});

disp(Top10);


%% =========================================================
% 13. 自动寻找“偏保守推荐值”
%
% 先找到PASS中的最好Score。
%
% 再允许Score最多比最优差2%，
% 从这些近似最优结果中选更温和的参数。
% ==========================================================

idxPass = find(T.PASS);

fprintf('\n=====================================================\n');
fprintf('                 自动推荐结果\n');
fprintf('=====================================================\n');

if isempty(idxPass)

    fprintf('\n[NO PASS]\n');
    fprintf('当前25组参数没有一组满足全部筛选条件。\n');
    fprintf('先不要修改在线估计器。\n');
    fprintf('请把TOP10表发出来继续分析。\n');

else

    Tpass = T(idxPass,:);

    bestScore = min(Tpass.Score);

    nearBest = ...
        Tpass.Score <= ...
        1.02*bestScore;

    Tnear = Tpass(nearBest,:);

    % 归一化攻击性：
    % kD最大值算1
    % kH最大值算1
    aggressiveness = ...
        Tnear.kD/max(kD_list) + ...
        Tnear.kH/max(kH_list);

    [~,kRec] = min(aggressiveness);

    R = Tnear(kRec,:);

    fprintf('\n推荐偏保守参数：\n');

    fprintf('kD = %.4f\n',R.kD);
    fprintf('kH = %.4f\n',R.kH);
    fprintf('dWI_cap = %.3f m/s\n',dWI_cap);

    fprintf('\n------ A ------\n');
    fprintf('RMSE变化比例 = %.4f\n',R.A_ratio);
    fprintf('平均WSS权重  = %.4f\n',R.A_WSS);

    fprintf('\n------ B ------\n');
    fprintf('RMSE = %.6f m/s\n',R.B_RMSE);
    fprintf('相比当前改善 = %.2f %%\n',R.B_improve_pct);
    fprintf('平均WSS权重  = %.4f\n',R.B_WSS);

    fprintf('\n------ C ------\n');
    fprintf('RMSE变化比例 = %.4f\n',R.C_ratio);
    fprintf('平均WSS权重  = %.4f\n',R.C_WSS);

    fprintf('\n------ E 3~8s ------\n');
    fprintf('RMSE = %.6f m/s\n',R.E_dyn_RMSE);
    fprintf('相比当前改善 = %.2f %%\n',R.E_dyn_improve_pct);
    fprintf('平均WSS权重  = %.4f\n',R.E_dyn_WSS);

    fprintf('\n------ E锁定阶段 ------\n');
    fprintf('RMSE = %.6f m/s\n',R.E_lock_RMSE);
    fprintf('MAE  = %.6f m/s\n',R.E_lock_MAE);
    fprintf('MAX  = %.6f m/s\n',R.E_lock_MAX);
    fprintf('相比当前RMSE改善 = %.2f %%\n', ...
        R.E_lock_improve_pct);

    fprintf('WSS平均权重 = %.4f\n',R.E_lock_WSS);
    fprintf('IMU平均权重 = %.4f\n',R.E_lock_IMU);

    fprintf('\n------ E恢复后 ------\n');
    fprintf('RMSE变化比例 = %.4f\n',R.E_rec_ratio);
    fprintf('平均WSS权重  = %.4f\n',R.E_rec_WSS);

    fprintf('\n[RECOMMENDED]\n');
    fprintf('该参数属于当前扫描范围内兼顾性能和改动幅度的候选值。\n');

end


%% =========================================================
% 14. 检查最优值是否撞到扫描边界
% ==========================================================

if ~isempty(idxPass)

    bestRow = T(idxPass(1),:);

    fprintf('\n=====================================================\n');
    fprintf('                扫描边界检查\n');
    fprintf('=====================================================\n');

    if abs(bestRow.kD-max(kD_list)) < 1e-12

        fprintf(['[WARNING] 最佳Score的kD位于扫描上边界 %.3f。\n' ...
                 '下一轮可能需要扩大kD范围。\n'], ...
            max(kD_list));

    else

        fprintf('最佳Score的kD没有撞上上边界。\n');

    end

    if abs(bestRow.kH-max(kH_list)) < 1e-12

        fprintf(['[WARNING] 最佳Score的kH位于扫描上边界 %.3f。\n' ...
                 '下一轮可能需要扩大kH范围。\n'], ...
            max(kH_list));

    else

        fprintf('最佳Score的kH没有撞上上边界。\n');

    end

end


%% =========================================================
% 15. 保存扫描结果
% ==========================================================

savePath = fullfile( ...
    rootDir, ...
    'tests', ...
    'fusion_health_scan_results.mat');

csvPath = fullfile( ...
    rootDir, ...
    'tests', ...
    'fusion_health_scan_results.csv');

save( ...
    savePath, ...
    'T', ...
    'Top10', ...
    'criteria', ...
    'kD_list', ...
    'kH_list', ...
    'dWI_cap', ...
    'tLockStart', ...
    'tLockEnd');

writetable(T,csvPath);

fprintf('\n=====================================================\n');
fprintf('                扫描完成\n');
fprintf('=====================================================\n');

fprintf('MAT结果：%s\n',savePath);
fprintf('CSV结果：%s\n',csvPath);

fprintf('\n注意：\n');
fprintf('本扫描仅使用历史结果离线重构顶层融合，\n');
fprintf('尚未修改在线估计器，也没有重新运行CarSim。\n');


%% =========================================================
%                     LOCAL FUNCTIONS
% ==========================================================

function filePath = resolve_case_file(rootDir,caseName)

fileName = sprintf( ...
    'results_case_%s.mat', ...
    caseName);

candidate = { ...
    fullfile(rootDir,'tests',fileName), ...
    fullfile(rootDir,fileName), ...
    fullfile(rootDir,'results',fileName)};

found = {};

for i = 1:numel(candidate)

    if exist(candidate{i},'file') == 2
        found{end+1,1} = candidate{i}; %#ok<AGROW>
    end

end

% 上面没找到才递归搜索
if isempty(found)

    tmp = dir( ...
        fullfile(rootDir,'**',fileName));

    for i = 1:numel(tmp)

        found{end+1,1} = ...
            fullfile(tmp(i).folder,tmp(i).name); %#ok<AGROW>

    end

end

found = unique(found);

if isempty(found)

    error('找不到文件：%s',fileName);

end

if numel(found) > 1

    fprintf('\n发现多个%s：\n',fileName);

    for i = 1:numel(found)
        fprintf('%d. %s\n',i,found{i});
    end

    error(['存在多个同名工况文件。' ...
           '请删除/改名旧文件，避免误读取。']);

end

filePath = found{1};

end


function d = load_case_data(filePath, caseName)
    % caseName 只用于显示，实际加载时统一用 'E'
    
    S = load(filePath);
    
    % 所有文件都使用 'E' 结构体
    structName = 'E';
    
    if ~isfield(S, structName)
        error('%s 中没有结构体变量 %s。', filePath, structName);
    end
    
    X = S.(structName);  % 统一用 E
    
    % 其余代码不变...
    required = { ...
        'est_y_time', ...
        'est_y_data', ...
        'Vx_true_time', ...
        'Vx_true_data'};
    
    for i = 1:numel(required)
        if ~isfield(X, required{i})
            error('%s 缺少字段 %s。', structName, required{i});
        end
    end
    
    if size(X.est_y_data,2) < 38
        error('%s.est_y_data 少于38列。', structName);
    end
    
    updated = X.est_y_data(:,35) > 0.5;
    t = X.est_y_time(updated);
    Y = X.est_y_data(updated,:);
    t = t(:);
    
    vxTrue = interp1( ...
        X.Vx_true_time(:), ...
        X.Vx_true_data(:), ...
        t, ...
        'linear');
    
    ok = ...
        isfinite(t) & ...
        isfinite(vxTrue) & ...
        isfinite(Y(:,1)) & ...
        isfinite(Y(:,3)) & ...
        isfinite(Y(:,4)) & ...
        isfinite(Y(:,5)) & ...
        isfinite(Y(:,6)) & ...
        isfinite(Y(:,7));
    
    t = t(ok);
    Y = Y(ok,:);
    vxTrue = vxTrue(ok);
    
    d.t = t;
    d.Y = Y;
    d.vxTrue = vxTrue;
    
    d.xFused = Y(:,1);
    d.xW = Y(:,3);
    d.PW = Y(:,4);
    d.xI = Y(:,5);
    d.PI = Y(:,6);
    d.PWI = Y(:,7);
    
    d.rho4 = Y(:,16:19);
    d.valid4 = Y(:,24:27) > 0.5;
    
    d.wWss = Y(:,30);
    d.wImu = Y(:,31);
end
function [xFuse,alphaW,alphaI,PWfuse] = ...
    candidate_fusion(d,kD,kH,dWI_cap)

% ---------------------------------------------------------
% WSS整体健康度
%
% invalid轮直接不贡献健康度
% ---------------------------------------------------------

rho = d.rho4;

rho(~isfinite(rho)) = 0;

rho = min(max(rho,0),1);

healthWheel = ...
    rho .* double(d.valid4);

hW = mean(healthWheel,2);

hW = min(max(hW,0),1);


% ---------------------------------------------------------
% WSS/IMU双轨迹分歧
% ---------------------------------------------------------

dWI = abs(d.xW-d.xI);

dWI(~isfinite(dWI)) = dWI_cap;

dWIeff = min(dWI,dWI_cap);


% ---------------------------------------------------------
% 顶层融合专用WSS协方差
% ---------------------------------------------------------

PWfuse = ...
    d.PW + ...
    kD .* dWIeff.^2 + ...
    kH .* (1-hW).^2 .* d.PI;

PWfuse = max(PWfuse,1e-12);


% ---------------------------------------------------------
% 保持当前相关融合公式
% ---------------------------------------------------------

PI = max(d.PI,1e-12);
PWI = d.PWI;

N = numel(d.t);

xFuse = NaN(N,1);
alphaW = zeros(N,1);
alphaI = zeros(N,1);

wssValid = ...
    any(d.valid4,2) & ...
    isfinite(d.xW) & ...
    isfinite(PWfuse);

imuValid = ...
    isfinite(d.xI) & ...
    isfinite(PI);

both = wssValid & imuValid;

den = ...
    PWfuse + ...
    PI - ...
    2*PWI;

goodDen = ...
    isfinite(den) & ...
    den > 1e-12;

idxBoth = both & goodDen;

alphaW(idxBoth) = ...
    (PI(idxBoth)-PWI(idxBoth)) ./ ...
    den(idxBoth);

alphaI(idxBoth) = ...
    (PWfuse(idxBoth)-PWI(idxBoth)) ./ ...
    den(idxBoth);

% 和在线代码一样重新归一化
s = alphaW + alphaI;

idxNorm = ...
    idxBoth & ...
    isfinite(s) & ...
    abs(s) > 1e-12;

alphaW(idxNorm) = ...
    alphaW(idxNorm) ./ ...
    s(idxNorm);

alphaI(idxNorm) = ...
    alphaI(idxNorm) ./ ...
    s(idxNorm);

% 病态情况沿用当前代码fallback
idxBadBoth = ...
    both & ~idxNorm;

alphaW(idxBadBoth) = 1;
alphaI(idxBadBoth) = 0;


% ---------------------------------------------------------
% 单通道情况
% ---------------------------------------------------------

onlyW = ...
    wssValid & ...
    ~imuValid;

onlyI = ...
    ~wssValid & ...
    imuValid;

alphaW(onlyW) = 1;
alphaI(onlyW) = 0;

alphaW(onlyI) = 0;
alphaI(onlyI) = 1;


% ---------------------------------------------------------
% 候选融合速度
% ---------------------------------------------------------

validFusion = ...
    wssValid | imuValid;

xFuse(validFusion) = ...
    alphaW(validFusion).*d.xW(validFusion) + ...
    alphaI(validFusion).*d.xI(validFusion);

end


function m = perf_metric(x,vxTrue,idx)

idx = ...
    idx(:) & ...
    isfinite(x) & ...
    isfinite(vxTrue);

if ~any(idx)

    error('性能评价区间没有有效数据。');

end

e = x(idx)-vxTrue(idx);

m.rmse = sqrt(mean(e.^2));
m.mae = mean(abs(e));
m.maxabs = max(abs(e));
m.bias = mean(e);

end


function [tStart,tEnd] = ...
    detect_rear_lock_window(d)

rearValid = ...
    all(d.valid4(:,3:4),2);

% 只在3s以后寻找
transitionDown = ...
    rearValid(1:end-1) & ...
    ~rearValid(2:end) & ...
    d.t(2:end) >= 3.0;

kDown0 = find( ...
    transitionDown, ...
    1, ...
    'first');

if isempty(kDown0)

    error(['E工况3s以后没有检测到后轮' ...
           'valid -> invalid，无法定义锁定区间。']);

end

kStart = kDown0+1;

transitionUp = ...
    ~rearValid(kStart:end-1) & ...
    rearValid(kStart+1:end);

kUpRel = find( ...
    transitionUp, ...
    1, ...
    'first');

if isempty(kUpRel)

    error(['E工况后轮失效后没有重新valid，' ...
           '无法定义恢复区间。']);

end

kEnd = kStart+kUpRel;

tStart = d.t(kStart);
tEnd = d.t(kEnd);

end