%% =========================================================
% E工况 eAbs + wheelLocked 专项验证
% 独立运行版
% 有 E 工况专项验证（含 wheelLocked）
%  有三通道性能对比（FUSED / WSS / IMU，包含 RMSE、MAX、误差日志）
% ==========================================================

clc

fprintf('\n=====================================================\n');
fprintf('开始运行 E工况 eAbs + wheelLocked 专项验证\n');
fprintf('=====================================================\n');

cd('D:\two\two\tests\');

caseName = 'E';

%% =========================================================
% 0. 自动加载E工况数据
% ==========================================================

fileName = 'results_case_E4DSAXZmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm';

fprintf('\n正在读取：%s\n',fileName);

if ~exist(fileName,'file')
    error('找不到 %s，请先保存最新E工况仿真结果。',fileName);
end

S = load(fileName);

if ~isfield(S,'E')
    error('%s 中没有结构体变量 E。',fileName);
end

E = S.E;

%% =========================================================
% 0.1 检查必要字段
% ==========================================================

requiredFields = { ...
    'est_y_time', ...
    'est_y_data', ...
    'Vx_true_time', ...
    'Vx_true_data'};

for k = 1:numel(requiredFields)

    if ~isfield(E,requiredFields{k})
        error('E结构体缺少字段：%s',requiredFields{k});
    end

end

%% =========================================================
% 0.2 从MAT文件重新构造100Hz数据
% ==========================================================

est_y_time = E.est_y_time(:);
est_y_data = E.est_y_data;

Vx_true_time = E.Vx_true_time(:);
Vx_true_data = E.Vx_true_data(:);

if size(est_y_data,2) < 38
    error('est_y_data只有%d列，应至少为38列。', ...
        size(est_y_data,2));
end

updated = est_y_data(:,35) > 0.5;

fprintf('原始est_y点数 = %d\n',size(est_y_data,1));
fprintf('检测到100Hz更新点 = %d\n',sum(updated));

if ~any(updated)
    error('没有检测到est_y(:,35)>0.5的真实更新点。');
end

t_est = est_y_time(updated);
Y100  = est_y_data(updated,:);

vx_true = interp1( ...
    Vx_true_time, ...
    Vx_true_data, ...
    t_est, ...
    'linear');

%% =========================================================
% 0.3 严格统一长度
% ==========================================================

N = min([ ...
    numel(t_est), ...
    size(Y100,1), ...
    numel(vx_true)]);

t_est   = t_est(1:N);
Y100    = Y100(1:N,:);
vx_true = vx_true(1:N);

fprintf('最终统一分析点数 = %d\n',N);
fprintf('分析时间范围 = %.3f ~ %.3f s\n', ...
    t_est(1),t_est(end));

fprintf('\n数据加载完成，开始专项检查。\n');
%% =========================================================
% E工况专项验证：
% eAbs + wheelLocked 持续滑移重新增信修复验证
%
% 注意：
% 注意：
% 1. 当前38维输出没有直接记录在线eAbs。
%
% 在线估计器实际使用：
%       eAbs_i = abs(vxWheel_i - vxImuTrack_i)
%
% 本脚本采用：
%       eAbsProxy_i = abs(vxWheel_i - xI)
%
% 其中 est_y(:,5)=xI。
% 因此下面由输出重构的eAbs仅作为离线一致性代理，
% 不能用于精确重构内部wheelRecoverCount。
%
% 2. wheelLocked没有直接放进38维输出，
%    因此这里通过：
%       eAbs / eSlip
%       rhoWheel
%       wheelValid
%       WSS/IMU权重
%       恢复重入时序
%    对锁定行为进行回归验证。
% ==========================================================

fprintf('\n=====================================================\n');
fprintf('开始运行 E工况 eAbs + wheelLocked 专项验证\n');
fprintf('=====================================================\n');

caseName = 'E';

p = estimator_default_params();
    fprintf('\n');
    fprintf('=====================================================\n');
    fprintf('     E工况 eAbs + wheelLocked 专项验证\n');
    fprintf('=====================================================\n');


    %% =====================================================
% 1. 计算eAbs离线代理
% 注意：不是在线eAbs的逐点精确值
% ======================================================

    vxImuLocal = Y100(:,5);       % xI
    vxWheel4   = Y100(:,8:11);    % FL FR RL RR

    eAbs4 = abs(vxWheel4 - vxImuLocal);

    eDelta4 = Y100(:,12:15);      % 原eSlip
    rho4    = Y100(:,16:19);      % 最终rhoWheel
    valid4  = Y100(:,24:27) > 0.5;

    wWss = Y100(:,30);
    wImu = Y100(:,31);

    allWheelInvalid = Y100(:,32) > 0.5;


    %% =====================================================
    % 2. 打印eAbs统计
    % ======================================================

    idxBefore = t_est >= 0.6 & t_est < 3;
    idxSlip   = t_est >= 3.0 & t_est < 7;
    idxAfter  = t_est >= 7.0 & t_est <= 16;

    fprintf('\n===== eAbs统计 =====\n');

    for i = 1:4

        fprintf('\nWheel %d\n',i);

        fprintf('加速前 max eAbs = %.6f m/s\n', ...
            max(eAbs4(idxBefore,i)));

        fprintf('3~7s max eAbs = %.6f m/s\n', ...
            max(eAbs4(idxSlip,i)));

        fprintf('7s后 max eAbs = %.6f m/s\n', ...
            max(eAbs4(idxAfter,i)));
    end


    %% =====================================================
    % 3. 最关键检查：
    %
    % eAbs >= eAbs_high时，
    % rhoAbs理论上已经等于0。
    %
    % 因此绝对不能出现：
    % eAbs严重异常，但wheelValid仍然=1
    % ======================================================

    severeAbs = eAbs4 >= p.eAbs_high;

    violationValid = ...
        severeAbs & valid4;

    violationRho = ...
        severeAbs & (rho4 > 1e-12);

    fprintf('\n============================================\n');
  fprintf(' 检查1：严重eAbs离线代理下是否出现错误重新增信\n');    fprintf('============================================\n');

    for i = 1:4

        fprintf(['Wheel %d: eAbs>=%.3f m/s点数=%d, ' ...
                 '其中错误valid点数=%d, ' ...
                 '错误非零confidence点数=%d\n'], ...
            i, ...
            p.eAbs_high, ...
            sum(severeAbs(:,i)), ...
            sum(violationValid(:,i)), ...
            sum(violationRho(:,i)));
    end

    totalViolationValid = sum(violationValid,'all');
    totalViolationRho   = sum(violationRho,'all');

    fprintf('\n严重eAbs却仍valid 总点数 = %d\n', ...
        totalViolationValid);

    fprintf('严重eAbs却confidence非零 总点数 = %d\n', ...
        totalViolationRho);

    if totalViolationValid == 0 && totalViolationRho == 0

        fprintf('\n[PASS] eAbs离线代理下未发现错误重新增信。\n');
    else

        fprintf('\n[WARNING] 严重eAbs离线代理下仍出现valid或非零confidence，请进一步检查。\n');
    end


    %% =====================================================
    % 4. 根据rho_hard反推出真正的“严重滑移锁定阈值”
    %
    % rho <= rho_hard 时才触发 severeSlip。
    %
    % rho =
    % (high-e)/(high-low)
    %
    % 因此：
    % eSevere = high-rho_hard*(high-low)
    % ======================================================

    eDeltaSevere = ...
        p.e_high - ...
        p.rho_hard * ...
        (p.e_high - p.e_low);

    eAbsSevere = ...
        p.eAbs_high - ...
        p.rho_hard * ...
        (p.eAbs_high - p.eAbs_low);

    fprintf('\n===== 理论锁定阈值 =====\n');

    fprintf('eDelta严重阈值 = %.6f m/s\n', ...
        eDeltaSevere);

    fprintf('eAbs严重阈值   = %.6f m/s\n', ...
        eAbsSevere);
%% =====================================================
% 4.1 统计3~7s eDelta距离锁定阈值
% 用于判断当前E工况到底离真正触发wheelLocked还有多远
% ======================================================

fprintf('\n===== 3~7s eDelta距离锁定阈值 =====\n');

% idxSlip前面已经定义：
% idxSlip = t_est >= 3.0 & t_est < 7;

for i = 1:4

    maxDelta = max(eDelta4(idxSlip,i));

    fprintf(['Wheel%d: max eDelta = %.6f m/s, ' ...
             '锁定阈值 = %.6f m/s, ' ...
             '差值 = %+.6f m/s\n'], ...
        i, ...
        maxDelta, ...
        eDeltaSevere, ...
        maxDelta-eDeltaSevere);

end
    %% =====================================================
% 5. 实际工况 wheelLocked 恢复端到端验证
%
% 目的：
% 检查实际CarSim工况中是否真正出现：
%
% valid = 1
%    ↓
% valid = 0
%    ↓
% 保持一段时间
%    ↓
% valid = 1
%
% 即实际观察到“失效 -> 恢复”。
%
% 注意：
% wheelLocked和wheelRecoverCount没有直接输出，
% 因此这里不能精确重构内部30点计数。
% 精确Nrecover逻辑由test_wheel_lock_recovery验证。
% ======================================================

fprintf('\n============================================\n');
fprintf(' 检查2：实际工况 wheelLocked 恢复行为\n');
fprintf('============================================\n');

Nrecover = round(p.Nrecover);
Trecover = Nrecover * p.Ts_est;

fprintf('Nrecover = %d 点\n',Nrecover);
fprintf('理论最短恢复确认时间 = %.3f s\n',Trecover);

% 每个车轮三个状态
recoveryTriggered = false(4,1);
recoveryObserved  = false(4,1);
recoveryStable    = false(4,1);
recoveryDelayOK   = false(4,1);

invalidTime = NaN(4,1);
reentryTime = NaN(4,1);

% 离线eAbs代理，仅用于辅助观察
eAbsProxy4 = eAbs4;
%% -----------------------------------------------------
% 保证所有恢复验证信号长度完全一致
% ------------------------------------------------------

Ndata = min([ ...
    numel(t_est), ...
    size(valid4,1), ...
    size(eDelta4,1), ...
    size(eAbsProxy4,1), ...
    numel(wWss), ...
    numel(wImu)]);

fprintf('\n恢复验证统一数据长度 = %d 点\n',Ndata);

t_rec         = t_est(1:Ndata);
valid_rec     = valid4(1:Ndata,:);
eDelta_rec    = eDelta4(1:Ndata,:);
eAbsProxy_rec = eAbsProxy4(1:Ndata,:);
wWss_rec      = wWss(1:Ndata);
wImu_rec      = wImu(1:Ndata);

for i = 1:4

    fprintf('\n----------------------------------------\n');
    fprintf('Wheel %d\n',i);

    %% -----------------------------------------------------
    % A. 从3s以后寻找第一次 valid -> invalid
    % ------------------------------------------------------

    kStart = find(t_est >= 3.0,1,'first');

    if isempty(kStart)

        fprintf('[NOT TESTED] 没有3s以后的数据。\n');
        continue;

    end

    kInvalid = [];

    for k = max(kStart+1,2):Ndata

        if valid_rec(k-1,i) && ~valid_rec(k,i)

            kInvalid = k;
            break;

        end

    end


    %% -----------------------------------------------------
    % B. 如果整个工况都没失效
    % ------------------------------------------------------

    if isempty(kInvalid)

        fprintf('[NOT TRIGGERED] 没有出现 valid -> invalid。\n');
        fprintf('该轮没有实际触发失效，因此不能验证恢复。\n');

        continue;

    end

    recoveryTriggered(i) = true;

    invalidTime(i) = t_rec(kInvalid);

    fprintf('第一次 valid -> invalid 时间 = %.3f s\n', ...
        invalidTime(i));


    %% -----------------------------------------------------
    % C. 从失效以后寻找第一次 invalid -> valid
    % ------------------------------------------------------

    kReentry = [];


    for k = (kInvalid+1):Ndata

        if ~valid_rec(k-1,i) && valid_rec(k,i)
            kReentry = k;
            break;

        end

    end


    %% -----------------------------------------------------
    % D. 如果直到仿真结束都没有恢复
    % ------------------------------------------------------

    if isempty(kReentry)

        fprintf('[NOT RECOVERED]\n');
        fprintf('失效后直到仿真结束仍未重新valid。\n');
        fprintf('该轮不能算完成恢复验证。\n');

        continue;

    end


    %% -----------------------------------------------------
    % E. 确实出现 invalid -> valid
    % ------------------------------------------------------

    recoveryObserved(i) = true;

    reentryTime(i) = t_rec(kReentry);

    fprintf('第一次 invalid -> valid 时间 = %.3f s\n', ...
        reentryTime(i));

    invalidDuration = ...
        reentryTime(i) - invalidTime(i);

    fprintf('失效持续时间 = %.3f s\n', ...
        invalidDuration);


    %% -----------------------------------------------------
    % F. 检查有没有明显早于Nrecover恢复
    %
    % 内部Nrecover=30，对应0.30s。
    % 如果连0.30s都没有就重新valid，显然存在问题。
    % ------------------------------------------------------

    delayOK = ...
        invalidDuration >= ...
        (Trecover - 0.5*p.Ts_est);

    recoveryDelayOK(i) = delayOK;

    fprintf('失效持续时间 >= %.3f s = %d\n', ...
        Trecover,delayOK);


    %% -----------------------------------------------------
    % G. 查看重入前Nrecover点
    %
    % eDelta是真正在线输出；
    % eAbsProxy只是辅助，不作为严格PASS条件。
    % ------------------------------------------------------

    if kReentry-Nrecover+1 >= 1

        idxRecover = ...
            (kReentry-Nrecover+1):kReentry;

        maxDeltaRecover = ...
        max(eDelta_rec(idxRecover,i));

        maxAbsProxyRecover = ...
        max(eAbsProxy_rec(idxRecover,i));

        fprintf('重入前%d点最大eDelta = %.6f m/s\n', ...
            Nrecover,maxDeltaRecover);

        fprintf('重入前%d点最大eAbsProxy = %.6f m/s\n', ...
            Nrecover,maxAbsProxyRecover);

        fprintf('eDelta_recover阈值 = %.6f m/s\n', ...
            p.eDelta_recover);

        fprintf('eAbs_recover阈值   = %.6f m/s\n', ...
            p.eAbs_recover);

        fprintf('重入前eDelta辅助检查 = %d\n', ...
            maxDeltaRecover < p.eDelta_recover);

        fprintf(['重入前eAbsProxy辅助检查 = %d ', ...
                 '(非在线eAbs，不作为硬PASS条件)\n'], ...
            maxAbsProxyRecover < p.eAbs_recover);

    else

        fprintf('重入前不足%d个100Hz采样点。\n', ...
            Nrecover);

    end


    %% -----------------------------------------------------
    % H. 检查恢复后是否马上再次掉线
    %
    % 要求恢复后至少约0.20s保持valid
    % ------------------------------------------------------

    Nstable = round(0.20/p.Ts_est);

    kStableEnd = ...
    min(Ndata, ...
        kReentry + Nstable - 1);

    stableOK = ...
    all(valid_rec(kReentry:kStableEnd,i));

    recoveryStable(i) = stableOK;

    fprintf('重新valid后约0.20s持续有效 = %d\n', ...
        stableOK);


    %% -----------------------------------------------------
    % I. 查看恢复后WSS是否重新参与
    % ------------------------------------------------------

    idxBeforeEntry = ...
    max(1,kReentry-10):(kReentry-1);

    idxAfterEntry = ...
    kReentry:min(Ndata,kReentry+20);

    if ~isempty(idxBeforeEntry)

        fprintf('重入前WSS平均权重 = %.6f\n', ...
            mean(wWss_rec(idxBeforeEntry)));

    end

    fprintf('重入后WSS平均权重 = %.6f\n', ...
        mean(wWss_rec(idxAfterEntry)));


    %% -----------------------------------------------------
    % J. 单轮结论
    % ------------------------------------------------------

    if delayOK && stableOK

        fprintf('[OBSERVED PASS] Wheel %d实际发生稳定恢复。\n',i);

    else

        fprintf('[OBSERVED FAIL] Wheel %d恢复行为存在异常。\n',i);

    end

end


%% =====================================================
% 实际恢复汇总
% ======================================================

fprintf('\n============================================\n');
fprintf('            实际恢复验证汇总\n');
fprintf('============================================\n');

for i = 1:4

    fprintf(['Wheel%d: 触发失效=%d, ' ...
             '观察到重入=%d, ' ...
             '恢复时间检查=%d, ' ...
             '恢复后稳定=%d\n'], ...
        i, ...
        recoveryTriggered(i), ...
        recoveryObserved(i), ...
        recoveryDelayOK(i), ...
        recoveryStable(i));

end


%% 至少必须实际观察到一次 invalid -> valid
anyRecoveryObserved = any(recoveryObserved);

%% 至少必须有一个车轮真正触发失效
anyRecoveryTriggered = any(recoveryTriggered);

%% 至少必须观察到一次恢复
anyRecoveryObserved = any(recoveryObserved);

%% COMPLETE PASS要求：
% 所有真正触发失效的车轮最终都恢复，
% 且恢复时间和稳定性都通过

if anyRecoveryTriggered

    idxTriggered = recoveryTriggered;

    allTriggeredRecovered = ...
        all(recoveryObserved(idxTriggered));

    if allTriggeredRecovered

        recoveryEndToEndPass = ...
            all(recoveryDelayOK(idxTriggered)) && ...
            all(recoveryStable(idxTriggered));

    else

        recoveryEndToEndPass = false;

    end

else

    allTriggeredRecovered = false;
    recoveryEndToEndPass = false;

end

fprintf('\n实际触发至少一个车轮失效 = %d\n', ...
    anyRecoveryTriggered);

fprintf('实际观察到至少一次恢复 = %d\n', ...
    anyRecoveryObserved);

fprintf('所有触发失效车轮最终恢复 = %d\n', ...
    allTriggeredRecovered);

fprintf('实际恢复端到端验证通过 = %d\n', ...
    recoveryEndToEndPass);


fprintf('\n实际观察到至少一次恢复 = %d\n', ...
    anyRecoveryObserved);

fprintf('实际恢复端到端验证通过 = %d\n', ...
    recoveryEndToEndPass);


if ~any(recoveryTriggered)

    fprintf('\n[NOT TESTED]\n');
    fprintf('本工况没有任何车轮发生失效，无法验证恢复。\n');

elseif ~anyRecoveryObserved

    fprintf('\n[NOT RECOVERED]\n');
    fprintf('发生了车轮失效，但仿真结束前没有恢复。\n');
    fprintf('不能宣称本工况验证了恢复机制。\n');

elseif recoveryEndToEndPass

    fprintf('\n[PASS]\n');
    fprintf('实际工况观察到了 invalid -> valid 的稳定恢复过程。\n');

else

    fprintf('\n[FAIL]\n');
    fprintf('观察到重新valid，但恢复时间或恢复稳定性异常。\n');

end
    %% =====================================================
    % 6. 四轮全部失效时，检查是否真正切换IMU
    % ======================================================

    fprintf('\n============================================\n');
    fprintf(' 检查3：四轮全部失效时的融合行为\n');
    fprintf('============================================\n');

   idxInvalid = allWheelInvalid & (t_est >= 0.6);
    fprintf('allWheelInvalid点数 = %d\n', ...
        sum(idxInvalid));

    if any(idxInvalid)

        fprintf('allWheelInvalid期间：\n');

        fprintf('WSS权重范围 = %.6f ~ %.6f\n', ...
            min(wWss(idxInvalid)), ...
            max(wWss(idxInvalid)));

        fprintf('IMU权重范围 = %.6f ~ %.6f\n', ...
            min(wImu(idxInvalid)), ...
            max(wImu(idxInvalid)));

    else

        fprintf('本次工况没有四轮同时失效。\n');
    end


    %% =====================================================
    % 7. 最重要的性能回归：
    % 原来7.321s发生24.560985 m/s巨大融合误差
    % ======================================================

    fprintf('\n============================================\n');
    fprintf(' 检查4：原7.321s巨大误差是否消失\n');
    fprintf('============================================\n');

    eFused = Y100(:,1) - vx_true;
    eWss   = Y100(:,3) - vx_true;
    eImu   = Y100(:,5) - vx_true;

    idxPost = t_est >= 7;

    postIndex = find(idxPost);

    [maxPostError,kLocal] = ...
        max(abs(eFused(idxPost)));

    kMax = postIndex(kLocal);

    fprintf('修改后7s以后最大误差发生时间 = %.3f s\n', ...
        t_est(kMax));

    fprintf('Vx_true = %.6f m/s\n', ...
        vx_true(kMax));

    fprintf('FUSED = %.6f m/s, error = %.6f m/s\n', ...
        Y100(kMax,1), ...
        eFused(kMax));

    fprintf('WSS   = %.6f m/s, error = %.6f m/s\n', ...
        Y100(kMax,3), ...
        eWss(kMax));

    fprintf('IMU   = %.6f m/s, error = %.6f m/s\n', ...
        Y100(kMax,5), ...
        eImu(kMax));

    fprintf('WSS weight = %.6f\n', ...
        Y100(kMax,30));

    fprintf('IMU weight = %.6f\n', ...
        Y100(kMax,31));


    %% 同时检查原7.321s附近
    [~,kOld] = min(abs(t_est-7.321));

    fprintf('\n----- 原故障时刻7.321s附近 -----\n');

    fprintf('当前采样时间 = %.3f s\n', ...
        t_est(kOld));

    fprintf('Vx_true = %.6f m/s\n', ...
        vx_true(kOld));

    fprintf('FUSED = %.6f m/s\n', ...
        Y100(kOld,1));

    fprintf('FUSED误差 = %.6f m/s\n', ...
        eFused(kOld));

    fprintf('WSS误差 = %.6f m/s\n', ...
        eWss(kOld));

    fprintf('IMU误差 = %.6f m/s\n', ...
        eImu(kOld));

    fprintf('WSS weight = %.6f\n', ...
        Y100(kOld,30));

    fprintf('IMU weight = %.6f\n', ...
        Y100(kOld,31));

    for i = 1:4

        fprintf(['Wheel%d: eDelta=%.6f, eAbs=%.6f, ' ...
                 'rho=%.6f, valid=%d\n'], ...
            i, ...
            eDelta4(kOld,i), ...
            eAbs4(kOld,i), ...
            rho4(kOld,i), ...
            valid4(kOld,i));
    end


    %% =====================================================
    % 8. 与修改前的已知基线比较
    % 仅当E工况完全相同时这个比较才有意义
    % ======================================================

    oldMaxError = 24.560985;

    fprintf('\n===== 与修改前E工况比较 =====\n');

    fprintf('修改前7s以后已知最大误差 = %.6f m/s\n', ...
        oldMaxError);

    fprintf('修改后7s以后最大误差 = %.6f m/s\n', ...
        maxPostError);

    improvePct = ...
        100 * ...
        (oldMaxError-maxPostError) / ...
        oldMaxError;

    fprintf('最大误差降低比例 = %.2f %%\n', ...
        improvePct);


    %% =====================================================
% 9. 最终专项判定
%
% 注意：
% eAbs4为基于xI重构的离线代理，
% 因此严重eAbs代理检查作为辅助诊断；
%
% 实际恢复是否发生，以：
%   valid: 1 -> 0 -> 1
%   恢复时间
%   恢复后稳定性
% 为主要端到端依据。
% ======================================================

fprintf('\n=====================================================\n');
fprintf('             E工况专项验证结论\n');
fprintf('=====================================================\n');

fprintf('严重eAbs代理下错误valid点数 = %d\n', ...
    totalViolationValid);

fprintf('严重eAbs代理下错误增信点数 = %d\n', ...
    totalViolationRho);

fprintf('实际触发车轮失效 = %d\n', ...
    any(recoveryTriggered));

fprintf('实际观察到恢复 = %d\n', ...
    anyRecoveryObserved);

fprintf('恢复端到端检查 = %d\n', ...
    recoveryEndToEndPass);


%% -----------------------------------------------------
% A. 防止持续滑移错误重新增信辅助检查
% ------------------------------------------------------

antiFalseRecoveryProxyPass = ...
    (totalViolationValid == 0) && ...
    (totalViolationRho == 0);


%% -----------------------------------------------------
% B. 最终分类
% ------------------------------------------------------

if antiFalseRecoveryProxyPass && ...
        recoveryEndToEndPass

    fprintf('\n=====================================================\n');
    fprintf('[COMPLETE PASS]\n');
    fprintf('=====================================================\n');

    fprintf('1. 严重eAbs代理下没有发现错误valid或错误增信；\n');
    fprintf('2. 实际工况出现了车轮失效；\n');
    fprintf('3. 随后实际观察到了 invalid -> valid；\n');
    fprintf('4. 恢复没有明显早于Nrecover要求；\n');
    fprintf('5. 恢复后能够保持稳定有效。\n');

    fprintf('\n结论：\n');
    fprintf('本E工况实际完成了“失效 -> 锁定/隔离 -> 恢复 -> 重新参与WSS”的端到端验证。\n');


elseif antiFalseRecoveryProxyPass && ...
        any(recoveryTriggered) && ...
        ~anyRecoveryObserved

    fprintf('\n=====================================================\n');
    fprintf('[PARTIAL PASS - NOT RECOVERED]\n');
    fprintf('=====================================================\n');

    fprintf('严重滑移错误重新增信抑制未发现异常；\n');
    fprintf('车轮确实发生了失效；\n');
    fprintf('但直到仿真结束仍未重新valid。\n');

    fprintf('\n结论：\n');
    fprintf('本工况可以证明锁定/隔离有效，\n');
    fprintf('但不能证明实际恢复机制已经在CarSim工况中触发完成。\n');


elseif antiFalseRecoveryProxyPass && ...
        ~any(recoveryTriggered)

    fprintf('\n=====================================================\n');
    fprintf('[PARTIAL PASS - NOT TRIGGERED]\n');
    fprintf('=====================================================\n');

    fprintf('没有发现错误重新增信现象；\n');
    fprintf('但本工况没有出现 valid -> invalid。\n');

    fprintf('\n结论：\n');
    fprintf('本次工况过轻，无法实际验证wheelLocked恢复过程。\n');


elseif anyRecoveryObserved && ...
        ~recoveryEndToEndPass

    fprintf('\n=====================================================\n');
    fprintf('[FAIL - RECOVERY ABNORMAL]\n');
    fprintf('=====================================================\n');

    fprintf('虽然观察到了 invalid -> valid，\n');
    fprintf('但恢复时间或恢复后的稳定性检查未通过。\n');

    fprintf('\n结论：\n');
    fprintf('需要检查恢复条件、Nrecover或工况数据。\n');


else

    fprintf('\n=====================================================\n');
    fprintf('[FAIL]\n');
    fprintf('=====================================================\n');

    fprintf('专项验证存在异常，请检查前面的详细输出。\n');

end
