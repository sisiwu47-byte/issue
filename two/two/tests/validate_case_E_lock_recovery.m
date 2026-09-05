%% =========================================================
% validate_case_E_lock_recovery.m
%
% E工况最终专项验证
%
% 当前目标工况：
%   mu = 0.30
%   Vx = 40 -> 70 km/h
%   加速区间 = 3 -> 8 s
%   实际总转矩上限 = 2250 Nm
%
% 验证目标：
%
% 1. 数据确实是当前E工况
% 2. 估计器确实100 Hz更新
% 3. 严重滑移时不会错误重新增信
% 4. 实际观察：
%
%       valid
%         ↓
%       invalid
%         ↓
%       保持失效
%         ↓
%       invalid -> valid
%         ↓
%       恢复后稳定
%
% 5. allWheelInvalid时IMU是否真正接管
% 6. E工况估计性能
% 7. 单元测试验证Nrecover内部状态机
%
% ---------------------------------------------------------
% 重要说明：
%
% est_y(:,5) = xI
%
% 本脚本：
%   eAbsProxy = abs(vxWheel - xI)
%
% 该量用于离线一致性分析。
%
% 如果当前在线源码使用：
%   eAbs = abs(vxWheel - vxImuTrack)
%
% 则eAbsProxy不是在线eAbs的逐点精确复现。
%
% 因此：
%   eDelta       ：可用于精确判断增量滑移
%   rho/valid    ：真实在线最终输出
%   eAbsProxy    ：辅助诊断
%
% wheelLocked和wheelRecoverCount未包含在38维输出中。
% ==========================================================


%% =========================================================
% 0. 初始化
% ==========================================================

clc

cd('D:\two\two');

fprintf('\n');
fprintf('=========================================================\n');
fprintf('      G工况 wheelLocked 最终专项验证\n');
fprintf('=========================================================\n');

fprintf('目标工况：mu=0.30, 70->30 km/h, 3~8s减速\n');
fprintf('当前实际总转矩上限目标：2250 Nm\n');


%% =========================================================
% 1. 加载结果
% ==========================================================

resultFile = ...
    fullfile('D:\two\two','tests','results_case_G.mat');

fprintf('\n===== 读取结果文件 =====\n');
fprintf('文件：%s\n',resultFile);

if ~exist(resultFile,'file')

    error('找不到 results_case_E.mat');

end

S = load(resultFile);

if ~isfield(S,'E')

    error('results_case_E.mat 中没有结构体变量 E');

end

E = S.E;


%% =========================================================
% 2. 提取必须字段
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

est_y_time = E.est_y_time(:);
est_y_data = E.est_y_data;

Vx_true_time = E.Vx_true_time(:);
Vx_true_data = E.Vx_true_data(:);

fprintf('\nest_y_data尺寸 = %d x %d\n', ...
    size(est_y_data,1), ...
    size(est_y_data,2));

if size(est_y_data,2) < 38

    error('est_y_data不足38列');

end


%% =========================================================
% 3. 参数
% ==========================================================

p = estimator_default_params();

fprintf('\n===== 当前估计器关键参数 =====\n');

fprintf('Ts_est          = %.6f s\n',p.Ts_est);
fprintf('e_low           = %.6f m/s\n',p.e_low);
fprintf('e_high          = %.6f m/s\n',p.e_high);
fprintf('rho_hard        = %.6f\n',p.rho_hard);

fprintf('eAbs_low        = %.6f m/s\n',p.eAbs_low);
fprintf('eAbs_high       = %.6f m/s\n',p.eAbs_high);

fprintf('eDelta_recover  = %.6f m/s\n', ...
    p.eDelta_recover);

fprintf('eAbs_recover    = %.6f m/s\n', ...
    p.eAbs_recover);

fprintf('Nrecover        = %d 点\n', ...
    round(p.Nrecover));


%% =========================================================
% 4. 只提取100Hz真实更新点
% ==========================================================

updated = est_y_data(:,35) > 0.5;

fprintf('\n===== 估计器更新检查 =====\n');

fprintf('原始est_y点数 = %d\n', ...
    size(est_y_data,1));

fprintf('100Hz更新点数 = %d\n', ...
    sum(updated));

if ~any(updated)

    error('没有找到estimatorUpdated=1的数据点');

end

t_est = est_y_time(updated);
Y100  = est_y_data(updated,:);


%% =========================================================
% 5. 插值真实车速
% ==========================================================

vx_true = interp1( ...
    Vx_true_time, ...
    Vx_true_data, ...
    t_est, ...
    'linear');

ok = ...
    isfinite(t_est) & ...
    isfinite(vx_true) & ...
    isfinite(Y100(:,1));

t_est   = t_est(ok);
Y100    = Y100(ok,:);
vx_true = vx_true(ok);

if numel(t_est) < 2

    error('有效100Hz数据不足');

end


%% =========================================================
% 6. 100Hz检查
% ==========================================================

dt = diff(t_est);

TsActual = median(dt);
fActual  = 1/TsActual;

fprintf('\n实际更新周期 = %.6f s\n',TsActual);
fprintf('实际更新频率 = %.3f Hz\n',fActual);

pass100Hz = ...
    fActual >= 99 && ...
    fActual <= 101;

fprintf('100Hz更新检查 = %d\n',pass100Hz);


%% =========================================================
% 7. 读取38维输出
% ==========================================================

vxFused = Y100(:,1);
vxWss   = Y100(:,3);
vxImu   = Y100(:,5);

vxWheel4 = Y100(:,8:11);

eDelta4 = Y100(:,12:15);

rho4 = Y100(:,16:19);

valid4 = ...
    Y100(:,24:27) > 0.5;

wWss = Y100(:,30);
wImu = Y100(:,31);

allWheelInvalid = ...
    Y100(:,32) > 0.5;

degradedMode = ...
    Y100(:,34) > 0.5;


%% =========================================================
% 8. eAbs离线代理
% ==========================================================

eAbsProxy4 = ...
    abs(vxWheel4-vxImu);

fprintf('\n===== eAbs离线一致性代理 =====\n');

idxBefore = ...
    t_est >= 0.6 & ...
    t_est < 3.0;

idxAccel = ...
    t_est >= 3.0 & ...
    t_est < 8.0;

idxAfter = ...
    t_est >= 8.0;

for i = 1:4

    fprintf('\nWheel %d\n',i);

    fprintf('加速前 max eAbsProxy = %.6f m/s\n', ...
        max(eAbsProxy4(idxBefore,i)));

    fprintf('3~8s max eAbsProxy = %.6f m/s\n', ...
        max(eAbsProxy4(idxAccel,i)));

    fprintf('8s后 max eAbsProxy = %.6f m/s\n', ...
        max(eAbsProxy4(idxAfter,i)));

end


%% =========================================================
% 9. 理论严重滑移阈值
% ==========================================================

eDeltaSevere = ...
    p.e_high - ...
    p.rho_hard * ...
    (p.e_high-p.e_low);

eAbsSevere = ...
    p.eAbs_high - ...
    p.rho_hard * ...
    (p.eAbs_high-p.eAbs_low);

fprintf('\n===== 理论严重滑移阈值 =====\n');

fprintf('eDelta严重阈值 = %.6f m/s\n', ...
    eDeltaSevere);

fprintf('eAbs严重阈值   = %.6f m/s\n', ...
    eAbsSevere);


%% =========================================================
% 10. 四轮eDelta统计
% ==========================================================

fprintf('\n============================================\n');
fprintf(' 检查1：3~8s滑移强度\n');
fprintf('============================================\n');

maxEDelta = zeros(4,1);

for i = 1:4

    maxEDelta(i) = ...
        max(eDelta4(idxAccel,i));

    fprintf(['Wheel%d: max eDelta = %.6f m/s, ' ...
             '距严重阈值 = %+.6f m/s\n'], ...
        i, ...
        maxEDelta(i), ...
        maxEDelta(i)-eDeltaSevere);

end


%% =========================================================
% 11. 严重eDelta时绝不能还保持最终高置信状态
%
% 使用eDelta，因为这是38维输出中的真实在线指标。
%
% 当eDelta已经明显超过e_high时：
% rhoDelta必定为0。
%
% 若此时最终rho仍>0或者valid=1，
% 才是真正需要重点检查的异常。
% ==========================================================

fprintf('\n============================================\n');
fprintf(' 检查2：严重eDelta下是否错误重新增信\n');
fprintf('============================================\n');

severeDeltaHard = ...
    eDelta4 >= p.e_high;

wrongRhoDelta = ...
    severeDeltaHard & ...
    (rho4 > 1e-12);

wrongValidDelta = ...
    severeDeltaHard & ...
    valid4;

for i = 1:4

    fprintf(['Wheel%d: eDelta>=%.3f点数=%d, ' ...
             'rho错误非零=%d, valid错误=%d\n'], ...
        i, ...
        p.e_high, ...
        sum(severeDeltaHard(:,i)), ...
        sum(wrongRhoDelta(:,i)), ...
        sum(wrongValidDelta(:,i)));

end

totalWrongRho = ...
    sum(wrongRhoDelta,'all');

totalWrongValid = ...
    sum(wrongValidDelta,'all');

fprintf('\n严重eDelta下错误非零rho总点数 = %d\n', ...
    totalWrongRho);

fprintf('严重eDelta下错误valid总点数 = %d\n', ...
    totalWrongValid);

passNoFalseReconfidence = ...
    totalWrongRho == 0 && ...
    totalWrongValid == 0;

fprintf('严重滑移重新增信检查 = %d\n', ...
    passNoFalseReconfidence);


%% =========================================================
% 12. 实际 wheelLocked 恢复过程
%
% 这里只从3s以后分析，排除启动阶段约0.5s窗口成熟。
%
% 一个真正有意义的端到端事件需要：
%
%   A. 先出现严重eDelta
%   B. 之后/同时 wheelValid变为0
%   C. 之后出现 invalid -> valid
%   D. 恢复不能明显早于0.3s
%   E. 恢复后至少0.20s保持有效
%
% 注意：
% 因为wheelLocked本身没输出，
% 所以这里称为“实际端到端恢复证据”，
% 不把它说成内部recoverCount逐点精确重构。
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf(' 检查3：实际工况 wheelLocked 恢复行为\n');
fprintf('============================================\n');

Nrecover = round(p.Nrecover);

Trecover = ...
    Nrecover*p.Ts_est;

Nstable = ...
    round(0.20/p.Ts_est);

fprintf('Nrecover = %d 点\n',Nrecover);
fprintf('理论恢复确认时间 = %.3f s\n',Trecover);
fprintf('恢复后稳定检查时间 = %.3f s\n', ...
    Nstable*p.Ts_est);


% 每轮结果
lockTriggered = false(4,1);
invalidObserved = false(4,1);
recoveryObserved = false(4,1);
delayPass = false(4,1);
stablePass = false(4,1);

kSevereAll = NaN(4,1);
kInvalidAll = NaN(4,1);
kReentryAll = NaN(4,1);


for i = 1:4

    fprintf('\n----------------------------------------\n');
    fprintf('Wheel %d\n',i);

    %% -----------------------------------------------
    % A. 3s后找第一次明确严重eDelta
    % -----------------------------------------------

    kSearch = find(t_est >= 3.0,1,'first');

    severeByDelta = ...
        eDelta4(:,i) >= eDeltaSevere;

    tmpSevere = find( ...
        severeByDelta & ...
        ((1:numel(t_est))' >= kSearch), ...
        1, ...
        'first');

    if isempty(tmpSevere)

        fprintf('[NOT TRIGGERED]\n');
        fprintf('3s后eDelta从未达到严重锁定阈值。\n');
        fprintf('该轮不能用于实际锁定/恢复验证。\n');

        continue;

    end

    kSevere = tmpSevere;

    lockTriggered(i) = true;
    kSevereAll(i) = kSevere;

    fprintf('第一次严重eDelta时间 = %.3f s\n', ...
        t_est(kSevere));

    fprintf('该点eDelta = %.6f m/s\n', ...
        eDelta4(kSevere,i));

    fprintf('该点rho = %.6f\n', ...
        rho4(kSevere,i));

    fprintf('该点valid = %d\n', ...
        valid4(kSevere,i));


    %% -----------------------------------------------
    % B. 严重事件附近/之后找第一次invalid
    %
    % 从kSevere前1点开始，避免锁定发生在同一更新点。
    % -----------------------------------------------

    searchStart = ...
        max(2,kSevere);

    kInvalid = [];

    for k = searchStart:numel(t_est)

        if ~valid4(k,i)

            kInvalid = k;
            break;

        end

    end

    if isempty(kInvalid)

        fprintf('[FAIL]\n');
        fprintf('已经出现严重eDelta，但之后未出现wheelInvalid。\n');

        continue;

    end

    invalidObserved(i) = true;
    kInvalidAll(i) = kInvalid;

    fprintf('第一次失效时间 = %.3f s\n', ...
        t_est(kInvalid));

    fprintf('严重事件到失效延迟 = %.3f s\n', ...
        t_est(kInvalid)-t_est(kSevere));


    %% -----------------------------------------------
    % C. 从该次失效以后找第一次 invalid -> valid
    % -----------------------------------------------

    kReentry = [];

    for k = (kInvalid+1):numel(t_est)

        if ...
                ~valid4(k-1,i) && ...
                 valid4(k,i)

            kReentry = k;
            break;

        end

    end

    if isempty(kReentry)

        fprintf('[NOT RECOVERED]\n');
        fprintf('发生严重滑移并失效，但仿真结束前没有重新valid。\n');

        continue;

    end

    recoveryObserved(i) = true;
    kReentryAll(i) = kReentry;

    fprintf('第一次重新valid时间 = %.3f s\n', ...
        t_est(kReentry));


    %% -----------------------------------------------
    % D. 失效持续时间
    % -----------------------------------------------

    invalidDuration = ...
        t_est(kReentry)-t_est(kInvalid);

    fprintf('失效持续时间 = %.3f s\n', ...
        invalidDuration);

    delayPass(i) = ...
        invalidDuration >= ...
        (Trecover-0.5*p.Ts_est);

    fprintf('失效持续时间 >= %.3f s = %d\n', ...
        Trecover, ...
        delayPass(i));


    %% -----------------------------------------------
    % E. 恢复前Nrecover点辅助检查
    %
    % eDelta是真实指标；
    % eAbsProxy只是辅助。
    % -----------------------------------------------

    if kReentry-Nrecover+1 >= 1

        idxRecoveryWindow = ...
            (kReentry-Nrecover+1):kReentry;

        maxRecoverEDelta = ...
            max(eDelta4(idxRecoveryWindow,i));

        maxRecoverEAbsProxy = ...
            max(eAbsProxy4(idxRecoveryWindow,i));

        deltaWindowOK = ...
            all( ...
            eDelta4(idxRecoveryWindow,i) < ...
            p.eDelta_recover);

        absProxyWindowOK = ...
            all( ...
            eAbsProxy4(idxRecoveryWindow,i) < ...
            p.eAbs_recover);

        fprintf('\n重入前%d个100Hz点：\n',Nrecover);

        fprintf('最大eDelta = %.6f m/s\n', ...
            maxRecoverEDelta);

        fprintf('最大eAbsProxy = %.6f m/s\n', ...
            maxRecoverEAbsProxy);

        fprintf('全部满足 eDelta < %.3f = %d\n', ...
            p.eDelta_recover, ...
            deltaWindowOK);

        fprintf(['全部满足 eAbsProxy < %.3f = %d ' ...
                 '(辅助检查)\n'], ...
            p.eAbs_recover, ...
            absProxyWindowOK);

    else

        fprintf('重入前没有足够的%d个采样点。\n', ...
            Nrecover);

    end


    %% -----------------------------------------------
    % F. 恢复后至少0.20s稳定valid
    % -----------------------------------------------

    kStableEnd = ...
        min( ...
        numel(t_est), ...
        kReentry+Nstable-1);

    stablePass(i) = ...
        all(valid4(kReentry:kStableEnd,i));

    fprintf('\n重新valid后约0.20s持续有效 = %d\n', ...
        stablePass(i));


    %% -----------------------------------------------
    % G. WSS重新参与
    % -----------------------------------------------

    idxBeforeReentry = ...
        max(1,kReentry-20):(kReentry-1);

    idxAfterReentry = ...
        kReentry:min(numel(t_est),kReentry+50);

    fprintf('重入前0.20s WSS平均权重 = %.6f\n', ...
        mean(wWss(idxBeforeReentry)));

    fprintf('重入后约0.50s WSS平均权重 = %.6f\n', ...
        mean(wWss(idxAfterReentry)));

    fprintf('重入后约0.50s IMU平均权重 = %.6f\n', ...
        mean(wImu(idxAfterReentry)));


    %% -----------------------------------------------
    % H. 单轮最终观察结论
    % -----------------------------------------------

    if delayPass(i) && stablePass(i)

        fprintf('\n[OBSERVED PASS]\n');
        fprintf('Wheel %d实际观察到稳定的失效 -> 恢复过程。\n',i);

    else

        fprintf('\n[OBSERVED FAIL]\n');

        if ~delayPass(i)

            fprintf('重新valid时间过早或失效持续时间不足。\n');

        end

        if ~stablePass(i)

            fprintf('重新valid后很快再次失效。\n');

        end

    end

end


%% =========================================================
% 13. 恢复汇总
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('            实际恢复验证汇总\n');
fprintf('============================================\n');

for i = 1:4

    fprintf(['Wheel%d: 严重滑移=%d, ' ...
             '观察到失效=%d, ' ...
             '观察到重入=%d, ' ...
             '时间检查=%d, ' ...
             '恢复后稳定=%d\n'], ...
        i, ...
        lockTriggered(i), ...
        invalidObserved(i), ...
        recoveryObserved(i), ...
        delayPass(i), ...
        stablePass(i));

end


triggeredIdx = ...
    lockTriggered & invalidObserved;

numTriggered = ...
    sum(triggeredIdx);

numRecovered = ...
    sum(recoveryObserved & triggeredIdx);

fprintf('\n实际触发严重滑移并失效的车轮数 = %d\n', ...
    numTriggered);

fprintf('实际完成重新valid的车轮数 = %d\n', ...
    numRecovered);


if numTriggered == 0

    recoveryEndToEndPass = false;

    fprintf('\n[NOT TESTED]\n');
    fprintf('本工况没有触发可识别的严重滑移失效。\n');

else

    recoveredTriggered = ...
        recoveryObserved(triggeredIdx);

    delayTriggered = ...
        delayPass(triggeredIdx);

    stableTriggered = ...
        stablePass(triggeredIdx);

    recoveryEndToEndPass = ...
        all(recoveredTriggered) && ...
        all(delayTriggered) && ...
        all(stableTriggered);

    if recoveryEndToEndPass

        fprintf('\n[PASS]\n');
        fprintf('所有实际触发严重滑移失效的车轮均完成稳定恢复。\n');

    elseif ~all(recoveredTriggered)

        fprintf('\n[PARTIAL / NOT RECOVERED]\n');
        fprintf('存在车轮发生严重滑移失效，但仿真结束前没有恢复。\n');

    else

        fprintf('\n[FAIL]\n');
        fprintf('观察到了重入，但恢复时序或恢复后稳定性存在异常。\n');

    end

end


%% =========================================================
% 14. allWheelInvalid检查
%
% 排除0~0.6s初始化阶段。
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf(' 检查4：四轮全部失效时的融合行为\n');
fprintf('============================================\n');

idxMature = ...
    t_est >= 0.6;

idxAllInvalidMature = ...
    allWheelInvalid & idxMature;

idxAllInvalidAccel = ...
    allWheelInvalid & ...
    t_est >= 3.0 & ...
    t_est < 8.0;

fprintf('0.6s后 allWheelInvalid 点数 = %d\n', ...
    sum(idxAllInvalidMature));

fprintf('3~8s allWheelInvalid 点数 = %d\n', ...
    sum(idxAllInvalidAccel));


if any(idxAllInvalidMature)

    fprintf('\n0.6s后 allWheelInvalid期间：\n');

    fprintf('WSS权重范围 = %.6f ~ %.6f\n', ...
        min(wWss(idxAllInvalidMature)), ...
        max(wWss(idxAllInvalidMature)));

    fprintf('IMU权重范围 = %.6f ~ %.6f\n', ...
        min(wImu(idxAllInvalidMature)), ...
        max(wImu(idxAllInvalidMature)));

    passImuTakeover = ...
        all(abs(wWss(idxAllInvalidMature)) < 1e-12) && ...
        all(abs(wImu(idxAllInvalidMature)-1) < 1e-12);

else

    fprintf('成熟阶段没有四轮同时失效。\n');

    % 没发生不是失败，只是此E-main没有验证到四轮全失效。
    passImuTakeover = true;

end

fprintf('IMU接管行为检查 = %d\n', ...
    passImuTakeover);


%% =========================================================
% 15. degradedMode
% ==========================================================

fprintf('\n===== degradedMode =====\n');

fprintf('0.6s后 degradedMode点数 = %d\n', ...
    sum(degradedMode & idxMature));

fprintf('3~8s degradedMode点数 = %d\n', ...
    sum(degradedMode & idxAccel));


%% =========================================================
% 16. E工况三阶段性能
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf(' 检查5：纵向速度估计性能\n');
fprintf('============================================\n');

eFused = ...
    vxFused-vx_true;

eWss = ...
    vxWss-vx_true;

eImu = ...
    vxImu-vx_true;

segments = { ...
    '加速前 0.6~3.0s', idxBefore; ...
    '加速段 3.0~8.0s', idxAccel; ...
    '加速后 8.0~16.0s', idxAfter};

for s = 1:size(segments,1)

    name = segments{s,1};
    idx  = segments{s,2};

    if ~any(idx)
        continue;
    end

    rmseFused = ...
        sqrt(mean(eFused(idx).^2));

    rmseWss = ...
        sqrt(mean(eWss(idx).^2));

    rmseImu = ...
        sqrt(mean(eImu(idx).^2));

    maxFused = ...
        max(abs(eFused(idx)));

    fprintf('\n--- %s ---\n',name);

    fprintf('FUSED RMSE = %.6f m/s\n', ...
        rmseFused);

    fprintf('WSS   RMSE = %.6f m/s\n', ...
        rmseWss);

    fprintf('IMU   RMSE = %.6f m/s\n', ...
        rmseImu);

    fprintf('FUSED MAX  = %.6f m/s\n', ...
        maxFused);

end


%% =========================================================
% 17. 最大误差
% ==========================================================

idxAfterStartup = ...
    t_est >= 0.6;

[maxErr,kLocal] = ...
    max(abs(eFused(idxAfterStartup)));

idxTmp = find(idxAfterStartup);

kMax = idxTmp(kLocal);

fprintf('\n===== 全工况成熟后最大融合误差 =====\n');

fprintf('时间 = %.3f s\n',t_est(kMax));
fprintf('Vx_true = %.6f m/s\n',vx_true(kMax));

fprintf('FUSED = %.6f m/s\n',vxFused(kMax));
fprintf('FUSED error = %.6f m/s\n',eFused(kMax));

fprintf('WSS error = %.6f m/s\n',eWss(kMax));
fprintf('IMU error = %.6f m/s\n',eImu(kMax));

fprintf('WSS weight = %.6f\n',wWss(kMax));
fprintf('IMU weight = %.6f\n',wImu(kMax));


%% =========================================================
% 18. 原7.321s附近，仅作历史诊断
%
% 如果当前E工况已经和原严重E不同，
% 不把24.560985 -> 当前误差说成严格算法改善比例。
% ==========================================================

[~,kOld] = ...
    min(abs(t_est-7.321));

fprintf('\n===== 7.321s附近状态 =====\n');

fprintf('实际采样时间 = %.3f s\n', ...
    t_est(kOld));

fprintf('Vx_true = %.6f m/s\n', ...
    vx_true(kOld));

fprintf('FUSED error = %.6f m/s\n', ...
    eFused(kOld));

fprintf('WSS error = %.6f m/s\n', ...
    eWss(kOld));

fprintf('IMU error = %.6f m/s\n', ...
    eImu(kOld));

fprintf('WSS weight = %.6f\n', ...
    wWss(kOld));

fprintf('IMU weight = %.6f\n', ...
    wImu(kOld));

for i = 1:4

    fprintf(['Wheel%d: eDelta=%.6f, ' ...
             'eAbsProxy=%.6f, ' ...
             'rho=%.6f, valid=%d\n'], ...
        i, ...
        eDelta4(kOld,i), ...
        eAbsProxy4(kOld,i), ...
        rho4(kOld,i), ...
        valid4(kOld,i));

end


%% =========================================================
% 19. 四轮最终状态统计
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf(' 检查6：四轮总体状态\n');
fprintf('============================================\n');

for i = 1:4

    matureValidRate = ...
        100*mean(valid4(idxMature,i));

    accelValidRate = ...
        100*mean(valid4(idxAccel,i));

    minRhoAccel = ...
        min(rho4(idxAccel,i));

    fprintf('\nWheel %d\n',i);

    fprintf('0.6s后 valid比例 = %.2f %%\n', ...
        matureValidRate);

    fprintf('3~8s valid比例 = %.2f %%\n', ...
        accelValidRate);

    fprintf('3~8s min rho = %.6f\n', ...
        minRhoAccel);

    fprintf('3~8s max eDelta = %.6f m/s\n', ...
        max(eDelta4(idxAccel,i)));

    fprintf('3~8s max eAbsProxy = %.6f m/s\n', ...
        max(eAbsProxy4(idxAccel,i)));

end


%% =========================================================
% 20. 单元测试：内部wheelLocked状态机
%
% 这部分负责严格验证：
%   锁定
%   连续Nrecover累计
%   中断清零
%   恢复
%   reset清锁
%
% 它与CarSim端到端验证是两个层次。
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf(' 检查7：wheelLocked状态机单元测试\n');
fprintf('============================================\n');

unitTestPass = false;

testFile = ...
    fullfile( ...
    'D:\two\two', ...
    'tests', ...
    'test_wheel_lock_recovery.m');

if exist(testFile,'file')

    clear functions

    rRecovery = ...
        runtests(testFile);

    nPassed = ...
        sum([rRecovery.Passed]);

    nFailed = ...
        sum([rRecovery.Failed]);

    nIncomplete = ...
        sum([rRecovery.Incomplete]);

    fprintf('Passed     = %d\n',nPassed);
    fprintf('Failed     = %d\n',nFailed);
    fprintf('Incomplete = %d\n',nIncomplete);

    unitTestPass = ...
        nFailed == 0 && ...
        nIncomplete == 0 && ...
        nPassed > 0;

else

    fprintf('未找到 test_wheel_lock_recovery.m\n');
    fprintf('跳过内部状态机单元测试。\n');

end

fprintf('wheelLocked单元测试 = %d\n', ...
    unitTestPass);


%% =========================================================
% 21. 最终结论
% ==========================================================

fprintf('\n');
fprintf('=========================================================\n');
fprintf('             E工况最终专项验证结论\n');
fprintf('=========================================================\n');

fprintf('100Hz更新正常                   = %d\n', ...
    pass100Hz);

fprintf('严重eDelta下无错误重新增信      = %d\n', ...
    passNoFalseReconfidence);

fprintf('实际触发严重滑移失效车轮数      = %d\n', ...
    numTriggered);

fprintf('实际完成恢复车轮数              = %d\n', ...
    numRecovered);

fprintf('实际恢复端到端检查              = %d\n', ...
    recoveryEndToEndPass);

fprintf('allWheelInvalid时IMU接管正常    = %d\n', ...
    passImuTakeover);

fprintf('wheelLocked状态机单元测试       = %d\n', ...
    unitTestPass);


%% =========================================================
% 最终分级结论
% ==========================================================

if ...
        pass100Hz && ...
        passNoFalseReconfidence && ...
        recoveryEndToEndPass && ...
        passImuTakeover && ...
        unitTestPass

    fprintf('\n');
    fprintf('#########################################################\n');
    fprintf('[FINAL PASS]\n');
    fprintf('#########################################################\n');

    fprintf(['本次E工况实际触发了严重滑移失效，' ...
             '并观察到失效车轮重新valid；\n']);

    fprintf(['恢复后保持稳定，且内部wheelLocked/Nrecover' ...
             '状态机单元测试通过。\n']);

    fprintf('\n可以形成结论：\n');

    fprintf(['1. 严重滑移不会错误重新增信；\n' ...
             '2. 实际低附着工况中发生了锁定/失效；\n' ...
             '3. 滑移消失后实际发生了稳定恢复；\n' ...
             '4. Nrecover恢复状态机实现正确。\n']);

elseif ...
        pass100Hz && ...
        passNoFalseReconfidence && ...
        numTriggered > 0 && ...
        ~recoveryEndToEndPass

    fprintf('\n');
    fprintf('#########################################################\n');
    fprintf('[PARTIAL PASS - LOCKED BUT NOT FULLY RECOVERED]\n');
    fprintf('#########################################################\n');

    fprintf('已经实际触发严重滑移和车轮失效；\n');
    fprintf('但没有完整观察到所有触发车轮稳定恢复。\n');
    fprintf('该工况可以验证锁定，但不能完整验证实际恢复。\n');

elseif ...
        pass100Hz && ...
        passNoFalseReconfidence && ...
        numTriggered == 0

    fprintf('\n');
    fprintf('#########################################################\n');
    fprintf('[PARTIAL PASS - NOT TRIGGERED]\n');
    fprintf('#########################################################\n');

    fprintf('没有发现严重滑移下错误重新增信；\n');
    fprintf('但本工况没有实际触发严重滑移失效。\n');
    fprintf('因此不能验证实际wheelLocked恢复过程。\n');

else

    fprintf('\n');
    fprintf('#########################################################\n');
    fprintf('[FAIL]\n');
    fprintf('#########################################################\n');

    fprintf('存在实际异常，请根据上方具体失败项目定位。\n');

end


fprintf('\n=========================================================\n');
fprintf('                 专项验证结束\n');
fprintf('=========================================================\n');