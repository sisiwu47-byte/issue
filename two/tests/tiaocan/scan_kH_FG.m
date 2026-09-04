%% =========================================================
% scan_kH_FG.m
%
% 当前固定：
%   QI = 2e-3
%   kA = 30
%   a0 = 0.10
%   a1 = 2.706246
%
% 本轮只扫描：
%   kH
%
% 当前在线：
%   kH = 60
%
% 重点评价：
%   F/G degraded / locked阶段
%
% 对wssValid=false的点保持在线fallback=xI，
% 因为kH本身无法改变这些点。
% ==========================================================

clc
clear

files = { ...
    'D:\two\two\tests\results_case_F.mat', ...
    'D:\two\two\tests\results_case_G.mat'};

names = {'F','G'};

a0 = 0.10;
a1 = 2.706246;

kA = 30;
kH_current = 60;

kHGrid = 10:1:30;
nH = numel(kHGrid);
nC = numel(files);

rmseDeg = nan(nH,nC);
rmseDyn = nan(nH,nC);

meanAlphaDeg = nan(nH,nC);
p05AlphaDeg  = nan(nH,nC);
p95AlphaDeg  = nan(nH,nC);

oracleAlphaDeg = nan(nC,1);
oracleRMSEDeg  = nan(nC,1);

currentDeg = nan(nC,1);
currentDyn = nan(nC,1);

rebuildRMS = nan(nC,1);

fprintf('\n');
fprintf('=====================================================\n');
fprintf('          QI=2e-3, kA=30 后 kH 离线扫描\n');
fprintf('=====================================================\n');

for ic = 1:nC

    S = load(files{ic});
    E = S.E;

    %% =====================================================
    % 1. 真实100Hz点
    % ======================================================

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
        t,'linear',NaN);

    %% =====================================================
    % 3. Ax
    % ======================================================

    tu = E.est_u_time(:);
    U  = E.est_u_data;

    if size(U,1) ~= numel(tu)

        if size(U,2) == numel(tu)
            U = U.';
        else
            error('%s est_u尺寸异常。',names{ic});
        end
    end

    Ax = interp1( ...
        tu,U(:,9),t,'linear',NaN);

    %% =====================================================
    % 4. Estimator outputs
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

    N = numel(t);

    %% =====================================================
    % 5. sA
    % ======================================================

    uA = ...
        (abs(Ax)-a0)/(a1-a0);

    uA = min(1,max(0,uA));

    sA = ...
        3*uA.^2 - ...
        2*uA.^3;

    %% =====================================================
    % 6. hW / sH
    %
    % 与production STEP10B一致
    % ======================================================

    hW = zeros(N,1);

    for i = 1:4

        rr = rho(:,i);

        rr(~isfinite(rr)) = 0;

        rr = ...
            min(1,max(0,rr));

        hW = ...
            hW + ...
            rr .* double(validWheel(:,i));
    end

    hW = hW/4;

    hW = ...
        min(1,max(0,hW));

    sH = ...
        (1-hW).^2;

    nValidWheel = ...
        sum(validWheel,2);

    healthy = ...
        nValidWheel == 4 & ...
        hW > 0.95;

    degraded = ...
        nValidWheel < 4 | ...
        hW < 0.90;

    %% =====================================================
    % 7. 当前PW_fuse
    % ======================================================

    inflateCurrent = ...
        1 + ...
        kA*sA + ...
        kH_current*sH;

    PWfCurrent = ...
        PW .* inflateCurrent;

    %% =====================================================
    % 8. 从当前alphaW反解PWI
    %
    % alphaW =
    % (PI-PWI)/(PWf+PI-2PWI)
    % ======================================================

    PWI = nan(N,1);

    bothValid = ...
        wssValid & ...
        imuValid;

    for k = 1:N

        if ~bothValid(k)
            continue
        end

        a = alphaCurrent(k);

        if ~all(isfinite([ ...
                a, ...
                PWfCurrent(k), ...
                PI(k)]))
            continue
        end

        den = ...
            1-2*a;

        if abs(den) < 1e-10
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
    % 9. 当前kH=60在线回代
    % ======================================================

    fRebuild = fusedOnline;

    good = ...
        bothValid & ...
        isfinite(PWI) & ...
        isfinite(PWfCurrent) & ...
        isfinite(PI);

    denPhi = ...
        PWfCurrent + ...
        PI - ...
        2*PWI;

    good = ...
        good & ...
        isfinite(denPhi) & ...
        abs(denPhi)>1e-12;

    aW = nan(N,1);
    aI = nan(N,1);

    aW(good) = ...
        (PI(good)-PWI(good)) ./ ...
        denPhi(good);

    aI(good) = ...
        (PWfCurrent(good)-PWI(good)) ./ ...
        denPhi(good);

    ss = aW+aI;

    good = ...
        good & ...
        isfinite(ss) & ...
        abs(ss)>1e-12;

    aW(good) = aW(good)./ss(good);
    aI(good) = aI(good)./ss(good);

    fRebuild(good) = ...
        aW(good).*xW(good) + ...
        aI(good).*xI(good);

    check = ...
        t>=0.6 & ...
        isfinite(fusedOnline) & ...
        isfinite(fRebuild);

    rebuildRMS(ic) = ...
        sqrt(mean( ...
        (fRebuild(check)- ...
         fusedOnline(check)).^2));

    fprintf('\n');
    fprintf('---------------------------------------------\n');
    fprintf('%s 当前kH=60回代检查\n',names{ic});
    fprintf('---------------------------------------------\n');

    fprintf('Fusion RMS回代差 = %.12e m/s\n', ...
        rebuildRMS(ic));

    if rebuildRMS(ic) > 1e-6
        error('%s回代失败，停止kH扫描。',names{ic});
    end

    %% =====================================================
    % 10. Evaluation masks
    % ======================================================

    base = ...
        t>=0.6 & ...
        imuValid & ...
        isfinite(vxTrue) & ...
        isfinite(xW) & ...
        isfinite(xI) & ...
        isfinite(fusedOnline);

    useDeg = ...
        base & ...
        degraded;

    useDyn = ...
        base & ...
        abs(Ax)>0.30;

    %% =====================================================
    % 11. 当前在线性能
    % ======================================================

    currentDeg(ic) = ...
        sqrt(mean( ...
        (fusedOnline(useDeg)- ...
         vxTrue(useDeg)).^2));

    currentDyn(ic) = ...
        sqrt(mean( ...
        (fusedOnline(useDyn)- ...
         vxTrue(useDyn)).^2));

    %% =====================================================
    % 12. degraded constant-weight oracle
    %
    % 仅供观察，不能作为kH唯一标定指标
    % ======================================================

    oracleUse = ...
        useDeg & ...
        wssValid & ...
        isfinite(xW) & ...
        isfinite(xI);

    eW = ...
        xW(oracleUse)-vxTrue(oracleUse);

    eI = ...
        xI(oracleUse)-vxTrue(oracleUse);

    d = eW-eI;

    denOr = sum(d.^2);

    if denOr > 1e-15

        aOrRaw = ...
            -sum(d.*eI)/denOr;

    else

        aOrRaw = 0.5;
    end

    aOr = ...
        min(1,max(0,aOrRaw));

    oracleAlphaDeg(ic) = aOr;

    eOr = ...
        aOr*eW + ...
        (1-aOr)*eI;

    oracleRMSEDeg(ic) = ...
        sqrt(mean(eOr.^2));

    %% =====================================================
    % 13. kH scan
    % ======================================================

    for ih = 1:nH

        kH = kHGrid(ih);

        inflate = ...
            1 + ...
            kA*sA + ...
            kH*sH;

        PWf = ...
            PW .* inflate;

        % 默认保持实际online fallback。
        %
        % 只有wssValid && imuValid时
        % kH才真正改变相关融合。
        fCandidate = ...
            fusedOnline;

        aWCandidate = ...
            alphaCurrent;

        denPhi = ...
            PWf + ...
            PI - ...
            2*PWI;

        g = ...
            bothValid & ...
            isfinite(PWI) & ...
            isfinite(PWf) & ...
            isfinite(PI) & ...
            isfinite(denPhi) & ...
            abs(denPhi)>1e-12;

        aw = nan(N,1);
        ai = nan(N,1);

        aw(g) = ...
            (PI(g)-PWI(g)) ./ ...
            denPhi(g);

        ai(g) = ...
            (PWf(g)-PWI(g)) ./ ...
            denPhi(g);

        s = aw+ai;

        g = ...
            g & ...
            isfinite(s) & ...
            abs(s)>1e-12;

        aw(g) = aw(g)./s(g);
        ai(g) = ai(g)./s(g);

        fCandidate(g) = ...
            aw(g).*xW(g) + ...
            ai(g).*xI(g);

        aWCandidate(g) = ...
            aw(g);

        %% degraded RMSE
        ud = ...
            useDeg & ...
            isfinite(fCandidate);

        rmseDeg(ih,ic) = ...
            sqrt(mean( ...
            (fCandidate(ud)- ...
             vxTrue(ud)).^2));

        aa = ...
            aWCandidate(ud);

        aa = aa(isfinite(aa));

        meanAlphaDeg(ih,ic) = ...
            mean(aa);

        p05AlphaDeg(ih,ic) = ...
            prctile(aa,5);

        p95AlphaDeg(ih,ic) = ...
            prctile(aa,95);

        %% overall dynamic RMSE
        uy = ...
            useDyn & ...
            isfinite(fCandidate);

        rmseDyn(ih,ic) = ...
            sqrt(mean( ...
            (fCandidate(uy)- ...
             vxTrue(uy)).^2));

    end
end

%% =========================================================
% 14. Summary
% ==========================================================

fprintf('\n');
fprintf('=====================================================\n');
fprintf('                   kH扫描汇总\n');
fprintf('=====================================================\n');

fprintf('当前kH=60 degraded RMSE F/G = [');
fprintf(' %.6f',currentDeg);
fprintf(' ]\n');

fprintf('当前kH=60 dynamic RMSE F/G  = [');
fprintf(' %.6f',currentDyn);
fprintf(' ]\n');

fprintf('\nDegraded oracle alphaW F/G = [');
fprintf(' %.3f',oracleAlphaDeg);
fprintf(' ]\n');

fprintf('Degraded oracle RMSE F/G = [');
fprintf(' %.6f',oracleRMSEDeg);
fprintf(' ]\n');

scoreMean = nan(nH,1);
scoreWorst = nan(nH,1);
scoreRobust = nan(nH,1);

for ih = 1:nH

    ratio = ...
        rmseDeg(ih,:) ./ ...
        currentDeg.';

    scoreMean(ih) = ...
        mean(ratio,'omitnan');

    scoreWorst(ih) = ...
        max(ratio);

    scoreRobust(ih) = ...
        0.7*scoreMean(ih) + ...
        0.3*scoreWorst(ih);

    fprintf('\n');
    fprintf('---------------------------------------------\n');

    fprintf('kH = %.1f\n',kHGrid(ih));

    fprintf('Degraded RMSE F/G = [');
    fprintf(' %.6f',rmseDeg(ih,:));
    fprintf(' ]\n');

    fprintf('Dynamic RMSE F/G  = [');
    fprintf(' %.6f',rmseDyn(ih,:));
    fprintf(' ]\n');

    fprintf('mean alphaW degraded = [');
    fprintf(' %.3f',meanAlphaDeg(ih,:));
    fprintf(' ]\n');

    fprintf('P05 alphaW degraded = [');
    fprintf(' %.3f',p05AlphaDeg(ih,:));
    fprintf(' ]\n');

    fprintf('P95 alphaW degraded = [');
    fprintf(' %.3f',p95AlphaDeg(ih,:));
    fprintf(' ]\n');

    fprintf('mean score   = %.6f\n',scoreMean(ih));
    fprintf('worst score  = %.6f\n',scoreWorst(ih));
    fprintf('robust score = %.6f\n',scoreRobust(ih));
end

%% =========================================================
% 15. Best candidates
% ==========================================================

[bestMean,idxMean] = ...
    min(scoreMean);

[bestWorst,idxWorst] = ...
    min(scoreWorst);

[bestRobust,idxRobust] = ...
    min(scoreRobust);

fprintf('\n');
fprintf('=====================================================\n');
fprintf('                kH候选结果\n');
fprintf('=====================================================\n');

fprintf('\n平均最优：\n');
fprintf('kH = %.1f\n',kHGrid(idxMean));
fprintf('score = %.6f\n',bestMean);
fprintf('degraded RMSE F/G = [');
fprintf(' %.6f',rmseDeg(idxMean,:));
fprintf(' ]\n');

fprintf('\n最坏工况最优：\n');
fprintf('kH = %.1f\n',kHGrid(idxWorst));
fprintf('score = %.6f\n',bestWorst);

fprintf('\n稳健综合最优：\n');
fprintf('kH = %.1f\n',kHGrid(idxRobust));
fprintf('robust score = %.6f\n',bestRobust);

fprintf('degraded RMSE F/G = [');
fprintf(' %.6f',rmseDeg(idxRobust,:));
fprintf(' ]\n');

fprintf('dynamic RMSE F/G = [');
fprintf(' %.6f',rmseDyn(idxRobust,:));
fprintf(' ]\n');

fprintf('mean alphaW degraded F/G = [');
fprintf(' %.3f',meanAlphaDeg(idxRobust,:));
fprintf(' ]\n');

fprintf('=====================================================\n');