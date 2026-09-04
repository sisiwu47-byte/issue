%% =========================================================
% scan_kA_after_QI_fixed_BCDH.m
%
% 当前已冻结候选：
%   QI = 2e-3
%
% 本轮只扫描：
%   kA
%
% 固定：
%   QW = 1e-4
%   a0 = 0.10
%   a1 = 2.706246
%   kH = 60
%   Q/R/PWI模型均不变
%
% 原理：
%
% 当前最终融合：
%
% PW_fuse = PW*(1+kA*sA+kH*sH)
%
% PWI不受最终PW_fuse反馈，因此可以根据当前
% kA=70运行结果反解PWI，再离线重放不同kA。
%
% ==========================================================

clc
clear

files = { ...
    'D:\two\two\tests\results_case_B.mat', ...
    'D:\two\two\tests\results_case_C.mat', ...
    'D:\two\two\tests\results_case_D.mat', ...
    'D:\two\two\tests\results_case_H.mat'};

names = {'B','C','D','H'};

%% 当前线上参数
a0 = 0.10;
a1 = 2.706246;

kA_current = 70;
kH = 60;

%% 扫描范围

kAGrid = 20:1:40;
nK = numel(kAGrid);
nC = numel(files);

rmseCandidate = nan(nK,nC);
meanAlpha     = nan(nK,nC);
p05Alpha      = nan(nK,nC);
p95Alpha      = nan(nK,nC);

outsideConvex = nan(nK,nC);

rmseCurrentRebuild = nan(nC,1);
rmseCurrentOnline  = nan(nC,1);

rmseW = nan(nC,1);
rmseI = nan(nC,1);
rmseRaw = nan(nC,1);

oracleRMSE  = nan(nC,1);
oracleAlpha = nan(nC,1);


fprintf('\n');
fprintf('=====================================================\n');
fprintf('       QI=2e-3固定后的最终融合 kA 离线扫描\n');
fprintf('=====================================================\n');


for ic = 1:nC

    %% =====================================================
    % 1. Load
    % ======================================================

    S = load(files{ic});
    E = S.E;

    tAll = E.est_y_time(:);
    YAll = E.est_y_data;

    counter = YAll(:,38);

    updated = false(size(counter));

    for k = 2:numel(counter)

        if isfinite(counter(k)) && ...
           isfinite(counter(k-1))

            updated(k) = ...
                counter(k) > counter(k-1);

        end

    end

    t = tAll(updated);
    Y = YAll(updated,:);


    %% =====================================================
    % 2. Truth
    % ======================================================

    vxTrue = interp1( ...
        E.Vx_true_time(:), ...
        E.Vx_true_data(:), ...
        t, ...
        'linear', ...
        NaN);


    %% =====================================================
    % 3. Ax
    % ======================================================

    tu = E.est_u_time(:);
    U = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s est_u尺寸异常。',names{ic});
        end

    end

    Ax = interp1( ...
        tu,U(:,9),t, ...
        'linear',NaN);


    %% =====================================================
    % 4. Current estimator outputs
    % ======================================================

    fusedOnline = Y(:,1);

    xW = Y(:,3);
    PW = Y(:,4);

    xI = Y(:,5);
    PI = Y(:,6);

    rho = Y(:,16:19);

    validWheel = ...
        Y(:,24:27) > 0.5;

    wssValid = ...
        Y(:,28) > 0.5;

    imuValid = ...
        Y(:,29) > 0.5;

    alphaCurrent = ...
        Y(:,30);


    %% =====================================================
    % 5. sA
    % ======================================================

    denA = a1-a0;

    uA = ...
        (abs(Ax)-a0)/denA;

    uA = ...
        min(1,max(0,uA));

    sA = ...
        3*uA.^2 - ...
        2*uA.^3;


    %% =====================================================
    % 6. sH
    %
    % 与production代码保持一致：
    %
    % hW = sum(rho_i for valid wheels)/4
    %
    % ======================================================

    hW = zeros(size(t));

    for i = 1:4

        rr = rho(:,i);

        rr = ...
            min(1,max(0,rr));

        contribution = ...
            rr .* double(validWheel(:,i));

        hW = ...
            hW + contribution;

    end

    hW = hW/4;

    hW = min(1,max(0,hW));

    sH = ...
        (1-hW).^2;


    %% =====================================================
    % 7. 当前PW_fuse
    % ======================================================

    inflateCurrent = ...
        1 + ...
        kA_current*sA + ...
        kH*sH;

    PWfCurrent = ...
        PW .* inflateCurrent;


    %% =====================================================
    % 8. 根据当前alphaW反解PWI
    %
    % alphaW =
    %
    % (PI-PWI) /
    % (PWf+PI-2*PWI)
    %
    %
    % 所以：
    %
    % PWI =
    %
    % [PI*(1-alpha)-alpha*PWf] /
    % [1-2*alpha]
    %
    % ======================================================

    PWI = nan(size(t));

    for k = 1:numel(t)

        a = alphaCurrent(k);

        if ~isfinite(a) || ...
           ~isfinite(PWfCurrent(k)) || ...
           ~isfinite(PI(k))

            continue
        end

        den = ...
            1-2*a;

        if abs(den) < 1e-8
            continue
        end

        c = ...
            ( ...
            PI(k)*(1-a) - ...
            a*PWfCurrent(k) ...
            ) / den;

        if isfinite(c)

            PWI(k) = c;

        end

    end


    %% =====================================================
    % 9. Evaluation region
    % ======================================================

    useBase = ...
        t >= 0.6 & ...
        abs(Ax) > 0.30 & ...
        wssValid & ...
        imuValid & ...
        isfinite(vxTrue) & ...
        isfinite(xW) & ...
        isfinite(PW) & ...
        isfinite(xI) & ...
        isfinite(PI) & ...
        isfinite(PWI) & ...
        isfinite(fusedOnline);


    %% =====================================================
    % 10. Current reconstruction verification
    %
    % 这一步必须先PASS。
    % ======================================================

    denCurrent = ...
        PWfCurrent + ...
        PI - ...
        2*PWI;

    aWrebuild = ...
        (PI-PWI) ./ ...
        denCurrent;

    aIrebuild = ...
        (PWfCurrent-PWI) ./ ...
        denCurrent;

    sumA = ...
        aWrebuild+aIrebuild;

    aWrebuild = ...
        aWrebuild./sumA;

    aIrebuild = ...
        aIrebuild./sumA;

    fusedRebuild = ...
        aWrebuild.*xW + ...
        aIrebuild.*xI;

    rebuildDiff = ...
        fusedRebuild(useBase) - ...
        fusedOnline(useBase);

    rebuildRMS = ...
        sqrt(mean(rebuildDiff.^2));

    fprintf('\n');
    fprintf('---------------------------------------------\n');
    fprintf('%s 当前kA=70回代检查\n',names{ic});
    fprintf('---------------------------------------------\n');

    fprintf('回代Fusion RMS差 = %.12e m/s\n', ...
        rebuildRMS);

    fprintf('回代alphaW RMS差 = %.12e\n', ...
        sqrt(mean( ...
        (aWrebuild(useBase)- ...
         alphaCurrent(useBase)).^2)));

    if rebuildRMS > 1e-6

        error([ ...
            '%s当前fusion回代不通过。' ...
            '先不要使用本扫描结果。'], ...
            names{ic});

    end


    %% =====================================================
    % 11. Current local / oracle
    % ======================================================

    eW = ...
        xW(useBase)-vxTrue(useBase);

    eI = ...
        xI(useBase)-vxTrue(useBase);

    eF = ...
        fusedOnline(useBase)-vxTrue(useBase);

    rmseW(ic) = ...
        sqrt(mean(eW.^2));

    rmseI(ic) = ...
        sqrt(mean(eI.^2));

    rmseCurrentOnline(ic) = ...
        sqrt(mean(eF.^2));


    %% Oracle
    d = eW-eI;

    denOracle = ...
        sum(d.^2);

    if denOracle > 1e-15

        aOrRaw = ...
            -sum(d.*eI)/ ...
            denOracle;

    else

        aOrRaw = 0.5;

    end

    aOr = ...
        min(1,max(0,aOrRaw));

    eOr = ...
        aOr*eW + ...
        (1-aOr)*eI;

    oracleAlpha(ic) = ...
        aOr;

    oracleRMSE(ic) = ...
        sqrt(mean(eOr.^2));


    %% =====================================================
    % 12. Scan kA
    % ======================================================

    for ik = 1:nK

        kA = ...
            kAGrid(ik);


        inflateCandidate = ...
            1 + ...
            kA*sA + ...
            kH*sH;


        PWf = ...
            PW .* ...
            inflateCandidate;


        denPhi = ...
            PWf + ...
            PI - ...
            2*PWI;


        aW = nan(size(t));
        aI = nan(size(t));

        good = ...
            useBase & ...
            isfinite(denPhi) & ...
            abs(denPhi) > 1e-12;


        aW(good) = ...
            (PI(good)-PWI(good)) ./ ...
            denPhi(good);


        aI(good) = ...
            (PWf(good)-PWI(good)) ./ ...
            denPhi(good);


        %% normalize
        s = ...
            aW+aI;

        good = ...
            good & ...
            isfinite(s) & ...
            abs(s) > 1e-12;


        aW(good) = ...
            aW(good)./s(good);

        aI(good) = ...
            aI(good)./s(good);


        %% candidate fusion
        f = nan(size(t));

        f(good) = ...
            aW(good).*xW(good) + ...
            aI(good).*xI(good);


        use = ...
            good & ...
            isfinite(f);


        if sum(use) < 30
            continue
        end


        err = ...
            f(use)-vxTrue(use);


        rmseCandidate(ik,ic) = ...
            sqrt(mean(err.^2));


        aa = ...
            aW(use);


        meanAlpha(ik,ic) = ...
            mean(aa);

        p05Alpha(ik,ic) = ...
            prctile(aa,5);

        p95Alpha(ik,ic) = ...
            prctile(aa,95);


        outsideConvex(ik,ic) = ...
            mean( ...
            aa < 0 | ...
            aa > 1);

    end

end


%% =========================================================
% 13. Summary
% ==========================================================

fprintf('\n');
fprintf('\n');
fprintf('=====================================================\n');
fprintf('                   kA扫描汇总\n');
fprintf('=====================================================\n');

fprintf('\n当前local xI RMSE：\n');
fprintf('B/C/D/H = [');
fprintf(' %.6f',rmseI);
fprintf(' ]\n');

fprintf('\n当前kA=70 online Fusion：\n');
fprintf('B/C/D/H = [');
fprintf(' %.6f',rmseCurrentOnline);
fprintf(' ]\n');

fprintf('\nOracle alphaW：\n');
fprintf('B/C/D/H = [');
fprintf(' %.3f',oracleAlpha);
fprintf(' ]\n');

fprintf('\nOracle RMSE：\n');
fprintf('B/C/D/H = [');
fprintf(' %.6f',oracleRMSE);
fprintf(' ]\n');


for ik = 1:nK

    fprintf('\n');
    fprintf('---------------------------------------------\n');

    fprintf('kA = %.1f\n', ...
        kAGrid(ik));

    fprintf('Fusion RMSE B/C/D/H = [');
    fprintf(' %.6f', ...
        rmseCandidate(ik,:));
    fprintf(' ]\n');

    fprintf('mean alphaW          = [');
    fprintf(' %.3f', ...
        meanAlpha(ik,:));
    fprintf(' ]\n');

    fprintf('P05 alphaW           = [');
    fprintf(' %.3f', ...
        p05Alpha(ik,:));
    fprintf(' ]\n');

    fprintf('P95 alphaW           = [');
    fprintf(' %.3f', ...
        p95Alpha(ik,:));
    fprintf(' ]\n');

    fprintf('outside[0,1] ratio   = [');
    fprintf(' %.4f', ...
        outsideConvex(ik,:));
    fprintf(' ]\n');

    %% -----------------------------------------------------
    % normalized score
    %
    % 每个工况相对当前kA=70性能，
    % 防止某个工况绝对RMSE较大而独占评分。
    % ------------------------------------------------------

    ratio = ...
        rmseCandidate(ik,:) ./ ...
        rmseCurrentOnline.';

    score = ...
        mean(ratio,'omitnan');

    fprintf('normalized score = %.6f\n', ...
        score);

end


%% =========================================================
% 14. Fine-grid robust selection
% ==========================================================

scoreMean  = nan(nK,1);
scoreWorst = nan(nK,1);
scoreRobust = nan(nK,1);

for ik = 1:nK

    ratio = ...
        rmseCandidate(ik,:) ./ ...
        rmseCurrentOnline.';

    % 平均改善
    scoreMean(ik) = ...
        mean(ratio,'omitnan');

    % 最坏工况
    scoreWorst(ik) = ...
        max(ratio);

    % 稳健综合：
    % 70%平均性能 + 30%最坏工况
    scoreRobust(ik) = ...
        0.7*scoreMean(ik) + ...
        0.3*scoreWorst(ik);

end


[bestMean,bestMeanIdx] = ...
    min(scoreMean);

[bestWorst,bestWorstIdx] = ...
    min(scoreWorst);

[bestRobust,bestRobustIdx] = ...
    min(scoreRobust);


fprintf('\n');
fprintf('=====================================================\n');
fprintf('               kA细扫描最终比较\n');
fprintf('=====================================================\n');

fprintf('\n--- 平均RMSE最优 ---\n');

fprintf('kA = %.1f\n', ...
    kAGrid(bestMeanIdx));

fprintf('mean score = %.6f\n', ...
    bestMean);

fprintf('RMSE B/C/D/H = [');
fprintf(' %.6f', ...
    rmseCandidate(bestMeanIdx,:));
fprintf(' ]\n');

fprintf('mean alphaW = [');
fprintf(' %.3f', ...
    meanAlpha(bestMeanIdx,:));
fprintf(' ]\n');


fprintf('\n--- 最坏工况最优 ---\n');

fprintf('kA = %.1f\n', ...
    kAGrid(bestWorstIdx));

fprintf('worst score = %.6f\n', ...
    bestWorst);

fprintf('RMSE B/C/D/H = [');
fprintf(' %.6f', ...
    rmseCandidate(bestWorstIdx,:));
fprintf(' ]\n');


fprintf('\n--- 稳健综合最优 ---\n');

fprintf('kA = %.1f\n', ...
    kAGrid(bestRobustIdx));

fprintf('robust score = %.6f\n', ...
    bestRobust);

fprintf('mean score   = %.6f\n', ...
    scoreMean(bestRobustIdx));

fprintf('worst score  = %.6f\n', ...
    scoreWorst(bestRobustIdx));

fprintf('\n');

fprintf('Fusion RMSE B/C/D/H = [');
fprintf(' %.6f', ...
    rmseCandidate(bestRobustIdx,:));
fprintf(' ]\n');

fprintf('mean alphaW B/C/D/H = [');
fprintf(' %.3f', ...
    meanAlpha(bestRobustIdx,:));
fprintf(' ]\n');

fprintf('P05 alphaW B/C/D/H = [');
fprintf(' %.3f', ...
    p05Alpha(bestRobustIdx,:));
fprintf(' ]\n');

fprintf('P95 alphaW B/C/D/H = [');
fprintf(' %.3f', ...
    p95Alpha(bestRobustIdx,:));
fprintf(' ]\n');

fprintf('\n');

fprintf('Oracle alphaW = [');
fprintf(' %.3f',oracleAlpha);
fprintf(' ]\n');

fprintf('Oracle RMSE = [');
fprintf(' %.6f',oracleRMSE);
fprintf(' ]\n');


fprintf('\n=====================================================\n');
fprintf('              全部细扫描结果\n');
fprintf('=====================================================\n');

fprintf('\n');
fprintf(' kA     meanScore    worstScore   robustScore\n');
fprintf('---------------------------------------------\n');

for ik = 1:nK

    fprintf('%4.0f    %.6f     %.6f     %.6f\n', ...
        kAGrid(ik), ...
        scoreMean(ik), ...
        scoreWorst(ik), ...
        scoreRobust(ik));

end

fprintf('=====================================================\n');