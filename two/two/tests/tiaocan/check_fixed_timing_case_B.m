%% =========================================================
% check_fixed_timing_case_B.m
%
% 目的：
% 验证：
%
%   Interpreted MATLAB Function SampleTime = 0.001
%   ode4 FixedStep = 0.001
%   estimator内部 updateEvery = 10
%
% 是否真正得到严格100 Hz estimator更新：
%
%   dt = 0.010 s
%
% 注意：
% 必须先重新仿真B工况并重新保存 results_case_B.mat
% ==========================================================

clc
clear

file = 'D:\two\two\tests\results_case_B.mat';

%% =========================================================
% 1. 读取结果
% ==========================================================

if ~exist(file,'file')
    error('找不到文件：%s',file);
end

S = load(file);

if ~isfield(S,'E')
    error('MAT文件中找不到结构体 E。');
end

E = S.E;

if ~isfield(E,'est_y_time') || ...
        ~isfield(E,'est_y_data')

    error('E中缺少 est_y_time 或 est_y_data。');
end

tAll = E.est_y_time(:);
YAll = E.est_y_data;

if size(YAll,1) ~= numel(tAll)

    if size(YAll,2) == numel(tAll)
        YAll = YAll.';
    else
        error('est_y_time与est_y_data尺寸不匹配。');
    end
end

if size(YAll,2) < 38
    error('est_y_data不足38列。');
end


%% =========================================================
% 2. 当前输出映射
%
% y(:,35) = estimatorUpdated
% y(:,38) = updateCounter
% ==========================================================

updateFlag = ...
    YAll(:,35) > 0.5;

counter = ...
    YAll(:,38);


%% =========================================================
% 3. 用updateCounter变化检测真正100Hz更新
%
% reset阶段counter=0，不计入正常100Hz更新。
% ==========================================================

counterUpdate = false(size(counter));

for k = 2:numel(counter)

    if isfinite(counter(k)) && ...
            isfinite(counter(k-1))

        counterUpdate(k) = ...
            counter(k) > counter(k-1);

    end
end

tUpdate = ...
    tAll(counterUpdate);

counterValue = ...
    counter(counterUpdate);

flagAtUpdate = ...
    updateFlag(counterUpdate);


%% =========================================================
% 4. 基本数量检查
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('             修复后100Hz时序验收\n');
fprintf('=====================================================\n');

fprintf('原始log样本数 = %d\n', ...
    numel(tAll));

fprintf('仿真时间 = %.6f ~ %.6f s\n', ...
    tAll(1),tAll(end));

fprintf('estimatorUpdated=1样本数 = %d\n', ...
    sum(updateFlag));

fprintf('updateCounter真实更新数 = %d\n', ...
    sum(counterUpdate));


if numel(tUpdate) < 2

    error('检测到的真实更新点不足2个，无法检查时序。');
end


%% =========================================================
% 5. 时间间隔
% ==========================================================

dt = diff(tUpdate);

dc = diff(counterValue);

fprintf('\n');
fprintf('===== 更新时间统计 =====\n');

fprintf('首个正常更新时刻 = %.12f s\n', ...
    tUpdate(1));

fprintf('最后更新时刻     = %.12f s\n', ...
    tUpdate(end));

fprintf('\n');

fprintf('mean dt   = %.12f s\n', ...
    mean(dt));

fprintf('median dt = %.12f s\n', ...
    median(dt));

fprintf('min dt    = %.12f s\n', ...
    min(dt));

fprintf('max dt    = %.12f s\n', ...
    max(dt));

fprintf('\n');

fprintf('P01 dt = %.12f s\n', ...
    prctile(dt,1));

fprintf('P99 dt = %.12f s\n', ...
    prctile(dt,99));

fprintf('\n');

fprintf('max |dt-0.01| = %.12e s\n', ...
    max(abs(dt-0.01)));

fprintf('dt < 0.0099 数量 = %d\n', ...
    sum(dt < 0.0099));

fprintf('dt > 0.0101 数量 = %d\n', ...
    sum(dt > 0.0101));


%% =========================================================
% 6. Counter本身检查
% ==========================================================

fprintf('\n');
fprintf('===== updateCounter检查 =====\n');

fprintf('counter首值 = %.0f\n', ...
    counterValue(1));

fprintf('counter末值 = %.0f\n', ...
    counterValue(end));

fprintf('deltaCounter min = %.0f\n', ...
    min(dc));

fprintf('deltaCounter max = %.0f\n', ...
    max(dc));

fprintf('deltaCounter ~= 1 数量 = %d\n', ...
    sum(abs(dc-1) > 1e-12));


%% =========================================================
% 7. col35和counter的一致性
% ==========================================================

fprintf('\n');
fprintf('===== estimatorUpdated一致性 =====\n');

fprintf('counter变化点中 col35=1 比例 = %.6f\n', ...
    mean(flagAtUpdate));

extraFlag = ...
    updateFlag & ...
    (~counterUpdate);

fprintf('col35=1但counter没有增长的样本数 = %d\n', ...
    sum(extraFlag));


%% =========================================================
% 8. 原始1ms主时间轴检查
% ==========================================================

dtRaw = diff(tAll);

fprintf('\n');
fprintf('===== Simulink主时间轴 =====\n');

fprintf('mean raw dt   = %.12f s\n', ...
    mean(dtRaw));

fprintf('median raw dt = %.12f s\n', ...
    median(dtRaw));

fprintf('min raw dt    = %.12f s\n', ...
    min(dtRaw));

fprintf('max raw dt    = %.12f s\n', ...
    max(dtRaw));

fprintf('max |raw dt-0.001| = %.12e s\n', ...
    max(abs(dtRaw-0.001)));


%% =========================================================
% 9. 最终PASS/FAIL判定
% ==========================================================

tolEstimator = 1e-9;
tolBase      = 1e-9;

passDt = ...
    max(abs(dt-0.01)) < tolEstimator;

passCounter = ...
    all(abs(dc-1) < 1e-12);

passFlag = ...
    all(flagAtUpdate);

passBase = ...
    max(abs(dtRaw-0.001)) < tolBase;

fprintf('\n');
fprintf('=====================================================\n');
fprintf('                  最终判定\n');
fprintf('=====================================================\n');

fprintf('1ms主时间轴       : %s\n', ...
    pass_fail(passBase));

fprintf('10ms estimator周期: %s\n', ...
    pass_fail(passDt));

fprintf('updateCounter步长 : %s\n', ...
    pass_fail(passCounter));

fprintf('col35更新标记     : %s\n', ...
    pass_fail(passFlag));


if passBase && ...
        passDt && ...
        passCounter && ...
        passFlag

    fprintf('\n[TIMING PASS]\n');

    fprintf([ ...
        'Estimator现在已经严格按照：\n\n' ...
        '    1 kHz外部调用\n' ...
        '          ↓\n' ...
        '    updateEvery = 10\n' ...
        '          ↓\n' ...
        '    100 Hz真实更新\n\n' ...
        '运行。\n']);

    fprintf('\n下一步可以重新检查独立IMU轨迹。\n');

else

    fprintf('\n[TIMING FAIL]\n');

    fprintf([ ...
        '仍然存在时序问题。\n' ...
        '暂时不要重新调QI/QW或融合参数。\n']);

end

fprintf('=====================================================\n');


%% =========================================================
% local function
% ==========================================================
function s = pass_fail(tf)

if tf
    s = 'PASS';
else
    s = 'FAIL';
end

end