% =========================================================
% save_case_E.m
%
% E工况：
% 从“当前最新一次Simulink仿真的out”提取数据
% -> 数据真实性检查
% -> 保存results_case_E.mat
% -> 清空
% -> 重新读取
% -> 核对保存文件
%
% 重要：
% 必须在E工况最新一次仿真刚结束后运行
% ==========================================================

clc
cd('D:\two\two\tests\');
fprintf('\n');
fprintf('=====================================================\n');
fprintf('        E工况 当前out提取 + 保存 + 核验\n');
fprintf('=====================================================\n');


%% =========================================================
% 0. 基本安全检查
% ==========================================================

if ~exist('out','var')
    error(['工作区中不存在 out。' ...
           '请先完成一次E工况Simulink仿真，再运行本脚本。']);
end

if ~isprop(out,'est_y_log') && ...
        ~isfield(out,'est_y_log')
    error('当前out中找不到 est_y_log。');
end

if ~isprop(out,'Vx_true_log') && ...
        ~isfield(out,'Vx_true_log')
    error('当前out中找不到 Vx_true_log。');
end

if ~isprop(out,'logsout') && ...
        ~isfield(out,'logsout')
    error('当前out中找不到 logsout。');
end


%% =========================================================
% 1. 清除旧E结构体
% 注意：这里只clear E，绝对不要clear out
% ==========================================================

clear E


%% =========================================================
% 2. 从“当前out”重新提取估计器输出和真实Vx
% ==========================================================

est_y_time = out.est_y_log.Time(:);
est_y_data = out.est_y_log.Data;

Vx_true_time = out.Vx_true_log.Time(:);
Vx_true_data = out.Vx_true_log.Data(:);

%% =========================================================
% 提取估计器完整输入 est_u
% est_u(:,9) = Ax
% ==========================================================

if ~isprop(out,'est_u_log') && ...
        ~isfield(out,'est_u_log')

    error('当前out中找不到 est_u_log。');

end

est_u_time = out.est_u_log.Time(:);

est_u_data = out.est_u_log.Data;

fprintf('\n===== est_u输入日志 =====\n');

fprintf('est_u_data尺寸 = %d x %d\n', ...
    size(est_u_data,1), ...
    size(est_u_data,2));

if size(est_u_data,2) < 18
    error('est_u_data不足18列，不是当前估计器完整输入。');
end

fprintf('Ax = est_u(:,9)\n');

fprintf('Ax范围 = %.6f ~ %.6f m/s^2\n', ...
    min(est_u_data(:,9)), ...
    max(est_u_data(:,9)));
%% 基本尺寸检查

fprintf('\n===== 当前out尺寸检查 =====\n');

fprintf('est_y_data尺寸 = %d x %d\n', ...
    size(est_y_data,1), ...
    size(est_y_data,2));

fprintf('Vx_true点数 = %d\n', ...
    numel(Vx_true_data));

if size(est_y_data,2) < 38
    error('est_y_data不足38列，不是当前版本估计器输出。');
end


%% =========================================================
% 3. 当前logsout中的四轮转矩
%
% 当前模型已确认：
% 75~78 = 四轮驱动转矩
% ==========================================================

logsout = out.logsout;

if numElements(logsout) < 78
    error('logsout不足78个信号，请重新确认转矩信号索引。');
end

sig_TL1 = logsout{75}.Values;
sig_TL2 = logsout{76}.Values;
sig_TR1 = logsout{77}.Values;
sig_TR2 = logsout{78}.Values;

tT = sig_TL1.Time(:);

TL1 = squeeze(sig_TL1.Data);
TL2 = squeeze(sig_TL2.Data);
TR1 = squeeze(sig_TR1.Data);
TR2 = squeeze(sig_TR2.Data);

TL1 = TL1(:);
TL2 = TL2(:);
TR1 = TR1(:);
TR2 = TR2(:);

% 防止四个信号长度不一致
Ntorque = min([ ...
    numel(tT), ...
    numel(TL1), ...
    numel(TL2), ...
    numel(TR1), ...
    numel(TR2)]);

tT  = tT(1:Ntorque);

TL1 = TL1(1:Ntorque);
TL2 = TL2(1:Ntorque);
TR1 = TR1(1:Ntorque);
TR2 = TR2(1:Ntorque);

Ttotal = TL1 + TL2 + TR1 + TR2;


%% =========================================================
% 4. 只提取估计器100Hz真实更新点
% est_y(:,35) = estimatorUpdated
% ==========================================================

updated = est_y_data(:,35) > 0.5;

fprintf('\n===== 估计器更新检查 =====\n');

fprintf('原始est_y点数 = %d\n', ...
    size(est_y_data,1));

fprintf('100Hz更新点数 = %d\n', ...
    sum(updated));

if ~any(updated)
    error('当前out没有任何estimatorUpdated=1的点。');
end

t_est = est_y_time(updated);
Y100  = est_y_data(updated,:);

vx_true = interp1( ...
    Vx_true_time, ...
    Vx_true_data, ...
    t_est, ...
    'linear');

good = isfinite(vx_true) & ...
       isfinite(Y100(:,1));

t_est  = t_est(good);
Y100   = Y100(good,:);
vx_true = vx_true(good);


%% =========================================================
% 5. 当前out数据真实性检查
% ==========================================================

fprintf('\n');
fprintf('========================================\n');
fprintf('        当前 out 数据真实性检查\n');
fprintf('========================================\n');

fprintf('仿真有效结束时间 = %.3f s\n', ...
    t_est(end));

fprintf('真实初始速度 = %.2f km/h\n', ...
    vx_true(1)*3.6);

fprintf('真实最大速度 = %.2f km/h\n', ...
    max(vx_true)*3.6);

fprintf('真实最终速度 = %.2f km/h\n', ...
    vx_true(end)*3.6);

fprintf('估计器更新次数 = %d\n', ...
    numel(t_est));

fprintf('最终updateCounter = %.0f\n', ...
    Y100(end,38));

if numel(t_est) > 1

    TsActual = median(diff(t_est));

    fprintf('实际更新周期 = %.6f s\n', ...
        TsActual);

    fprintf('实际更新频率 = %.3f Hz\n', ...
        1/TsActual);

end


%% =========================================================
% 6. 当前四轮转矩真实性检查
% ==========================================================

idxT = tT >= 3;

if ~any(idxT)
    error('转矩数据中没有t>=3s的数据。');
end

fprintf('\n===== 当前仿真四轮转矩 =====\n');

fprintf('L1最大正转矩 = %.2f Nm\n', ...
    max(TL1(idxT)));

fprintf('L2最大正转矩 = %.2f Nm\n', ...
    max(TL2(idxT)));

fprintf('R1最大正转矩 = %.2f Nm\n', ...
    max(TR1(idxT)));

fprintf('R2最大正转矩 = %.2f Nm\n', ...
    max(TR2(idxT)));

fprintf('\n单轮最大正转矩 = %.2f Nm\n', ...
    max([ ...
        TL1(idxT); ...
        TL2(idxT); ...
        TR1(idxT); ...
        TR2(idxT)]));

fprintf('单轮最小转矩 = %.2f Nm\n', ...
    min([ ...
        TL1(idxT); ...
        TL2(idxT); ...
        TR1(idxT); ...
        TR2(idxT)]));

fprintf('总转矩最大值 = %.2f Nm\n', ...
    max(Ttotal(idxT)));

fprintf('总转矩最小值 = %.2f Nm\n', ...
    min(Ttotal(idxT)));


%% =========================================================
% 7. 当前轮周速度检查
% est_y(:,8:11)
% ==========================================================

fprintf('\n===== 当前轮周速度 =====\n');

fprintf('真实Vx最大 = %.2f km/h\n', ...
    max(vx_true)*3.6);

for i = 1:4

    vxWheel = Y100(:,7+i);

    fprintf('Wheel %d最大轮周速度 = %.2f km/h\n', ...
        i, ...
        max(vxWheel)*3.6);

end


%% =========================================================
% 8. 再打印当前估计器滑移相关指标
% 可快速判断这真的是不是低附着E
% ==========================================================

fprintf('\n===== 当前滑移判据快速检查 =====\n');

eDelta4 = Y100(:,12:15);
rho4    = Y100(:,16:19);
valid4  = Y100(:,24:27) > 0.5;

for i = 1:4

    fprintf(['Wheel%d: max eDelta=%.6f, ' ...
             'min rho=%.6f, valid比例=%.2f%%\n'], ...
        i, ...
        max(eDelta4(:,i)), ...
        min(rho4(:,i)), ...
        100*mean(valid4(:,i)));

end


%% =========================================================
% 9. 建立本次E结构体
% ==========================================================

E.est_y_time = est_y_time;
E.est_y_data = est_y_data;

E.est_u_time = est_u_time;
E.est_u_data = est_u_data;

E.Vx_true_time = Vx_true_time;
E.Vx_true_data = Vx_true_data;

E.T_time  = tT;

E.T_L1 = TL1;
E.T_L2 = TL2;
E.T_R1 = TR1;
E.T_R2 = TR2;

E.T_total = Ttotal;


%% =========================================================
% 10. 工况说明
%
% 注意：
% 这些是“实验计划/设置记录”，
% 不能单独证明模型实际用了这些参数。
% ==========================================================

E.caseName = 'E';

E.mu_commanded = 0.3;

E.v0_commanded_kmh = 40;
E.v1_commanded_kmh = 70;

E.t_acc_start = 3;
E.t_acc_end   = 8;

% 本次模型中人为设置的总转矩限幅
E.Tlimit_total_commanded = 2800;


%% =========================================================
% 11. 保存由实际输出得到的指纹
% ==========================================================

E.simEndTime = t_est(end);

E.Vx0_kmh = ...
    vx_true(1)*3.6;

E.VxMax_kmh = ...
    max(vx_true)*3.6;

E.VxEnd_kmh = ...
    vx_true(end)*3.6;

E.Tmax_total = ...
    max(Ttotal(idxT));

E.Tmin_total = ...
    min(Ttotal(idxT));

E.updateCount = ...
    numel(t_est);

E.updateCounterEnd = ...
    Y100(end,38);

E.maxEDelta4 = ...
    max(eDelta4,[],1);

E.minRho4 = ...
    min(rho4,[],1);

E.validRate4 = ...
    mean(valid4,1);


%% =========================================================
% 12. 保存时间戳
% ==========================================================

E.savedAt = ...
    char(datetime('now', ...
    'Format','yyyy-MM-dd HH:mm:ss'));


%% =========================================================
% 13. 真正保存E
% ==========================================================

saveFile = ...
    fullfile('D:\two\two\tests\', ...
    'results_case_C.mat');

fprintf('\n===== 保存E =====\n');

fprintf('目标文件：%s\n', ...
    saveFile);

% 真正覆盖旧E
save(saveFile,'E');

fprintf('保存完成。\n');


%% =========================================================
% 14. 检查文件真的刚刚被覆盖
% ==========================================================

d = dir(saveFile);

fprintf('\n===== 文件系统检查 =====\n');

fprintf('文件大小 = %.1f KB\n', ...
    d.bytes/1024);

fprintf('文件修改时间 = %s\n', ...
    d.date);


%% =========================================================
% 15. 保存前留一份当前out指纹
% 用于和重新load后的MAT比较
% ==========================================================

currentFingerprint.Vx0 = E.Vx0_kmh;
currentFingerprint.VxMax = E.VxMax_kmh;
currentFingerprint.VxEnd = E.VxEnd_kmh;

currentFingerprint.Tmax = E.Tmax_total;

currentFingerprint.Nupdate = E.updateCount;

currentFingerprint.maxEDelta4 = ...
    E.maxEDelta4;


%% =========================================================
% 16. 清掉E，再从硬盘重新读取
% ==========================================================

clear E

Scheck = load(saveFile,'E');

if ~isfield(Scheck,'E')
    error('保存文件中没有结构体E！');
end

E = Scheck.E;


%% =========================================================
% 17. MAT文件内容核验
% ==========================================================

fprintf('\n');
fprintf('========================================\n');
fprintf('          MAT文件重新读取核验\n');
fprintf('========================================\n');

fprintf('caseName = %s\n', ...
    E.caseName);

fprintf('计划mu = %.2f\n', ...
    E.mu_commanded);

fprintf('计划参考速度 = %.0f -> %.0f km/h\n', ...
    E.v0_commanded_kmh, ...
    E.v1_commanded_kmh);

fprintf('计划加速区间 = %.1f -> %.1f s\n', ...
    E.t_acc_start, ...
    E.t_acc_end);

fprintf('计划总转矩限幅 = %.1f Nm\n', ...
    E.Tlimit_total_commanded);

fprintf('\n实际真实初始速度 = %.2f km/h\n', ...
    E.Vx0_kmh);

fprintf('实际真实最大速度 = %.2f km/h\n', ...
    E.VxMax_kmh);

fprintf('实际真实最终速度 = %.2f km/h\n', ...
    E.VxEnd_kmh);

fprintf('实际总转矩最大值 = %.2f Nm\n', ...
    E.Tmax_total);

fprintf('实际总转矩最小值 = %.2f Nm\n', ...
    E.Tmin_total);

fprintf('估计器更新点 = %d\n', ...
    E.updateCount);

fprintf('保存时间 = %s\n', ...
    E.savedAt);


%% =========================================================
% 18. 判断“保存后的文件”是否确实就是当前out
% ==========================================================

fingerprintPass = true;

fingerprintPass = fingerprintPass && ...
    abs(E.Vx0_kmh-currentFingerprint.Vx0) < 1e-10;

fingerprintPass = fingerprintPass && ...
    abs(E.VxMax_kmh-currentFingerprint.VxMax) < 1e-10;

fingerprintPass = fingerprintPass && ...
    abs(E.VxEnd_kmh-currentFingerprint.VxEnd) < 1e-10;

fingerprintPass = fingerprintPass && ...
    abs(E.Tmax_total-currentFingerprint.Tmax) < 1e-10;

fingerprintPass = fingerprintPass && ...
    E.updateCount == currentFingerprint.Nupdate;

fingerprintPass = fingerprintPass && ...
    max(abs( ...
        E.maxEDelta4 - ...
        currentFingerprint.maxEDelta4)) < 1e-10;


fprintf('\n===== 当前out ↔ MAT一致性检查 =====\n');

fprintf('指纹完全一致 = %d\n', ...
    fingerprintPass);

if fingerprintPass

    fprintf('\n[PASS]\n');
    fprintf('results_case_E.mat确认来自当前这一次out。\n');

else

    fprintf('\n[FAIL]\n');
    fprintf('重新读取的MAT与当前out不一致，禁止继续分析。\n');

end




fprintf('\n');
fprintf('=====================================================\n');

if fingerprintPass

    fprintf('E数据提取、保存、重新加载核验完成。\n');
    fprintf('现在可以运行E专项验证脚本。\n');

else

    fprintf('E数据保存核验失败，不要运行E专项验证。\n');

end

fprintf('=====================================================\n');