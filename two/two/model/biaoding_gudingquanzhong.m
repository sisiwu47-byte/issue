%% =========================================================
% E-main：离线求真实MSE意义下最优WSS/IMU常值权重
%求carsim运行时真实的误差应当对应的权重
% 仅用于标定，不进入在线算法
% ==========================================================

clc
clear

S = load('D:\two\two\tests\results_case_G.mat');
E = S.E;

updated = E.est_y_data(:,35) > 0.5;

t = E.est_y_time(updated);
Y = E.est_y_data(updated,:);

vxTrue = interp1( ...
    E.Vx_true_time(:), ...
    E.Vx_true_data(:), ...
    t(:), ...
    'linear');

ok = isfinite(vxTrue) & ...
     isfinite(Y(:,3)) & ...
     isfinite(Y(:,5));

t = t(ok);
Y = Y(ok,:);
vxTrue = vxTrue(ok);

eW = Y(:,3)-vxTrue;
eI = Y(:,5)-vxTrue;

idxSet = {
    t >= 0.6 & t < 3.0,              % 减速前正常稳态
    t >= 3.0 & t < 4.709,            % 减速开始 ~ 后轮锁定前（纯动态，无锁定）
    t >= 4.709 & t < 9.175,          % 后轮锁定/严重滑移区间
    t >= 9.175 & t < 11.175          % 恢复后（取恢复后2秒）
};
names = {
    '减速前稳态 0.6~3.0s',
    '减速动态 3.0~4.709s（无锁定）',
    '后轮锁定 idxSet4.709~9.175s',
    '恢复后 9.175~11.175s'
};
fprintf('\n=====================================================\n');
fprintf('       E-main 真实误差最优融合权重诊断\n');
fprintf('=====================================================\n');

for k = 1:numel(idxSet)

    idx = idxSet{k};

    ew = eW(idx);
    ei = eI(idx);

    Eww = mean(ew.^2);
    Eii = mean(ei.^2);
    Ewi = mean(ew.*ei);

    den = Eww + Eii - 2*Ewi;

    if den > 1e-12
        alphaWopt = (Eii-Ewi)/den;
    else
        alphaWopt = 0.5;
    end

    alphaWclip = min(max(alphaWopt,0),1);
    alphaIclip = 1-alphaWclip;

    eOpt = alphaWclip*ew + alphaIclip*ei;

    rmseW = sqrt(Eww);
    rmseI = sqrt(Eii);
    rmseOpt = sqrt(mean(eOpt.^2));

    C = corrcoef(ew,ei);

    if all(size(C)==[2 2])
        corrErr = C(1,2);
    else
        corrErr = NaN;
    end

    fprintf('\n------------------------------------------\n');
    fprintf('%s\n',names{k});
    fprintf('------------------------------------------\n');

    fprintf('WSS RMSE = %.6f m/s\n',rmseW);
    fprintf('IMU RMSE = %.6f m/s\n',rmseI);

    fprintf('\nE[eW^2]   = %.6e\n',Eww);
    fprintf('E[eI^2]   = %.6e\n',Eii);
    fprintf('E[eW*eI]  = %.6e\n',Ewi);

    fprintf('误差相关系数 = %.6f\n',corrErr);

    fprintf('\n理论无约束alphaW = %.6f\n',alphaWopt);

    fprintf('限制到[0,1]后：\n');
    fprintf('alphaW_opt = %.6f\n',alphaWclip);
    fprintf('alphaI_opt = %.6f\n',alphaIclip);

    fprintf('对应RMSE   = %.6f m/s\n',rmseOpt);

    fprintf('\n当前平均alphaW = %.6f\n',mean(Y(idx,30)));
    fprintf('当前平均alphaI = %.6f\n',mean(Y(idx,31)));

end