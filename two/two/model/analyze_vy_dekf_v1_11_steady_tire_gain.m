function analyze_vy_dekf_v1_11_steady_tire_gain()
% V1.11 steady-state tire gain/shape attribution.
% Offline diagnostics only. No estimator, tire parameter, Q/R, Fz, or model
% file is changed by this analysis.

rootDir = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(rootDir, 'results');
docDir = fullfile(rootDir, 'docs');
if ~exist(resultDir, 'dir'), mkdir(resultDir); end
if ~exist(docDir, 'dir'), mkdir(docDir); end

S9 = load(fullfile(resultDir, 'vy_dekf_v1_9_model_mismatch.mat'));
S10 = load(fullfile(resultDir, 'vy_dekf_v1_10_tire_transient.mat'));

Ts = 0.01;
m = 1860;
Iz = 2687.1;
a = 1.18;
b = 1.77;
N = size(S9.mechanics.alpha, 1);
assert(N == 1600, 'V1.11 expected exactly 1600 one-step samples.');
t = (0:N-1)' * Ts;
trainMask = t >= 3 & t < 8;
validationMask = t >= 8 & t <= 13;

% Baseline quantities are reconstructed only from archived V1.9 mechanics.
M = S9.mechanics;
FyfModel = sum(M.FybCurrent(:,1:2), 2);
FyrModel = sum(M.FybCurrent(:,3:4), 2);
FyfEquivArchive = S9.FyfEquiv;
FyrEquivArchive = S9.FyrEquiv;
AyTrue = (FyfEquivArchive + FyrEquivArchive) / m;
drTrueDt = (a*FyfEquivArchive - b*FyrEquivArchive) / Iz;
FyfEquiv = (Iz*drTrueDt + b*m*AyTrue) / (a+b);
FyrEquiv = (a*m*AyTrue - Iz*drTrueDt) / (a+b);
deltaFyfCurrent = FyfEquiv - FyfModel;
deltaFyrCurrent = FyrEquiv - FyrModel;
deltaFyCurrent = (FyfEquiv + FyrEquiv) - (FyfModel + FyrModel);
deltaMzCurrent = (a*FyfEquiv - b*FyrEquiv) - (a*FyfModel - b*FyrModel);

baselineCase = S10.candidateData{1};
baselineErrors = struct();
baselineErrors.FyfModel = max(abs(FyfModel - S9.FyfModel));
baselineErrors.FyrModel = max(abs(FyrModel - S9.FyrModel));
baselineErrors.FyfEquiv = max(abs(FyfEquiv - S9.FyfEquiv));
baselineErrors.FyrEquiv = max(abs(FyrEquiv - S9.FyrEquiv));
baselineErrors.DeltaFyf = max(abs(deltaFyfCurrent - S9.deltaFyf));
baselineErrors.DeltaFyr = max(abs(deltaFyrCurrent - S9.deltaFyr));
baselineErrors.DeltaFy = max(abs(deltaFyCurrent - S9.deltaFyCurrent));
baselineErrors.DeltaMz = max(abs(deltaMzCurrent - S9.deltaMzCurrent));
baselineErrors.V110ZeroSigmaXPred = max(abs(baselineCase.xPred - M.xPredCurrent), [], 'all');
baselineErrors.V110ZeroSigmaResidual = max(abs(baselineCase.residual - S9.wCurrent), [], 'all');
baselineMaxError = max(struct2array(baselineErrors));
assert(baselineMaxError <= 1e-10, ...
    'Baseline reconstruction failed: max error %.17g.', baselineMaxError);

% Recover aligned state/input proxies from archived prediction mechanics.
xTrue = M.xPredCurrent - Ts*[M.vyDotCurrent M.rDotCurrent];
rTrue = xTrue(:,2);
Vx = mean(baselineCase.wheelSpeed, 2);
xWheel = [a a -b -b];
kinematicAngle = zeros(N,4);
for wheel = 1:4
    kinematicAngle(:,wheel) = atan2(xTrue(:,1) + xWheel(wheel)*rTrue, ...
                                    baselineCase.wheelSpeed(:,wheel));
end
deltaWheel = M.alpha + kinematicAngle;
frontSteer = mean(deltaWheel(:,1:2), 2);
frontSteerRate = gradient(frontSteer, Ts);
turnMask = abs(frontSteer) > 0.005;
% Reuse the archived V1.10 numerical threshold so the exact same 216-point
% subset is retained. Re-estimating a percentile from rounded archived
% signals can move samples that lie on the threshold boundary.
rateThreshold = S10.quasi.rateThreshold;
quasiMask = turnMask & abs(frontSteerRate) <= rateThreshold;
assert(sum(quasiMask) == S10.quasi.N, ...
    'Quasi-steady sample count differs from V1.10 (%d vs %d).', ...
    sum(quasiMask), S10.quasi.N);

trainQuasi = trainMask & quasiMask;
validationQuasi = validationMask & quasiMask;
assert(any(trainQuasi) && any(validationQuasi), ...
    'TRAIN or VALIDATION quasi-steady subset is empty.');

alphaF = mean(M.alpha(:,1:2), 2);
alphaR = mean(M.alpha(:,3:4), 2);

% Through-origin correction gains use TRAIN quasi-steady data only.
kFront = origin_gain(FyfModel(trainQuasi), FyfEquiv(trainQuasi));
kRear = origin_gain(FyrModel(trainQuasi), FyrEquiv(trainQuasi));
gFrontModelOverEquiv = origin_gain(FyfEquiv(trainQuasi), FyfModel(trainQuasi));
gRearModelOverEquiv = origin_gain(FyrEquiv(trainQuasi), FyrModel(trainQuasi));

FyfGain = kFront * FyfModel;
FyrGain = kRear * FyrModel;

% Even gain-shape law: y = [Fmodel, alpha^2*Fmodel]*[c0;c2].
Xf = [FyfModel(trainQuasi), alphaF(trainQuasi).^2 .* FyfModel(trainQuasi)];
Xr = [FyrModel(trainQuasi), alphaR(trainQuasi).^2 .* FyrModel(trainQuasi)];
cFront = Xf \ FyfEquiv(trainQuasi);
cRear = Xr \ FyrEquiv(trainQuasi);
gainLawFront = cFront(1) + cFront(2)*alphaF.^2;
gainLawRear = cRear(1) + cRear(2)*alphaR.^2;
FyfShape = gainLawFront .* FyfModel;
FyrShape = gainLawRear .* FyrModel;

models = struct();
models.Current = make_candidate(FyfModel, FyrModel, FyfEquiv, FyrEquiv, ...
    M.xPredCurrent, S9.wCurrent, M.FyTotalCurrent, M.MzCurrent, m, Iz, a, b, Ts);
models.ConstantGain = make_candidate(FyfGain, FyrGain, FyfEquiv, FyrEquiv, ...
    M.xPredCurrent, S9.wCurrent, M.FyTotalCurrent, M.MzCurrent, m, Iz, a, b, Ts);
models.GainShape = make_candidate(FyfShape, FyrShape, FyfEquiv, FyrEquiv, ...
    M.xPredCurrent, S9.wCurrent, M.FyTotalCurrent, M.MzCurrent, m, Iz, a, b, Ts);

% Long-format output records.
records = empty_records();
records = add_record(records,'AUDIT','FULL','Baseline','ALL','baseline','all','Both', ...
    'MaxReconstructionError',baselineMaxError,'mixed',N);
records = add_record(records,'AUDIT','FULL','Baseline','ALL','time','all','Both', ...
    'Ts',Ts,'s',N);
records = add_record(records,'AUDIT','TRAIN','Definition','QUASI','mask','all','Both', ...
    'N',sum(trainQuasi),'count',sum(trainQuasi));
records = add_record(records,'AUDIT','VALIDATION','Definition','QUASI','mask','all','Both', ...
    'N',sum(validationQuasi),'count',sum(validationQuasi));
records = add_record(records,'AUDIT','FULL','Definition','QUASI','steering_rate','all','Both', ...
    'Threshold',rateThreshold,'rad/s',sum(quasiMask));

gainSummary = table( ...
    [kFront;kRear], [gFrontModelOverEquiv;gRearModelOverEquiv], ...
    [1/kFront;1/kRear], ...
    'VariableNames',{'kCorrection_EquivOverModel','G_ModelOverEquiv_LS','ReciprocalOfCorrection'}, ...
    'RowNames',{'Front','Rear'});
for axle = {'Front','Rear'}
    ax = axle{1};
    if strcmp(ax,'Front')
        vals = [kFront gFrontModelOverEquiv 1/kFront];
    else
        vals = [kRear gRearModelOverEquiv 1/kRear];
    end
    records = add_record(records,'GAIN_FIT','TRAIN','ConstantGain','QUASI','axle','all',ax, ...
        'kCorrection_EquivOverModel',vals(1),'1',sum(trainQuasi));
    records = add_record(records,'GAIN_FIT','TRAIN','ConstantGain','QUASI','axle','all',ax, ...
        'G_ModelOverEquiv_LS',vals(2),'1',sum(trainQuasi));
    records = add_record(records,'GAIN_FIT','TRAIN','ConstantGain','QUASI','axle','all',ax, ...
        'ReciprocalOfCorrection',vals(3),'1',sum(trainQuasi));
end

% Candidate residual statistics in all requested time/scope combinations.
scopeNames = {'TRAIN_ALL','TRAIN_QUASI','VALIDATION_ALL','VALIDATION_QUASI'};
scopeMasks = {trainMask,trainQuasi,validationMask,validationQuasi};
modelNames = fieldnames(models);
metricNames = {'DeltaFyf','DeltaFyr','DeltaFy','DeltaMz','wVy','wr'};
units = {'N','N','N','N*m','m/s','rad/s'};
for si = 1:numel(scopeNames)
    mask = scopeMasks{si};
    dataset = strtok(scopeNames{si},'_');
    scope = extractAfter(scopeNames{si},'_');
    for mi = 1:numel(modelNames)
        modelName = modelNames{mi};
        for qi = 1:numel(metricNames)
            metric = metricNames{qi};
            values = models.(modelName).(metric)(mask);
            st = signal_stats(values);
            statFields = {'Mean','RMS','P95Abs','MaxAbs'};
            % Temporal correlation is meaningful only for a contiguous time
            % window. Do not concatenate separated quasi-steady samples and
            % label their sample-order correlation as rho1/rho10.
            if strcmp(scope,'ALL')
                statFields = [statFields {'Rho1','Rho10'}];
            end
            for sj = 1:numel(statFields)
                sf = statFields{sj};
                unit = units{qi};
                if startsWith(sf,'Rho'), unit = '1'; end
                records = add_record(records,'MODEL_COMPARISON',dataset,modelName,scope, ...
                    metric,'all','Both',sf,st.(sf),unit,sum(mask));
            end
            if ~strcmp(modelName,'Current')
                baseRms = signal_stats(models.Current.(metric)(mask));
                reduction = 100*(1-st.RMS/baseRms.RMS);
                records = add_record(records,'MODEL_COMPARISON',dataset,modelName,scope, ...
                    metric,'all','Both','RMSReductionPercent',reduction,'percent',sum(mask));
            end
        end
    end
end

% Gain stability: four quantile bins for every continuous conditioning variable.
conditioning = struct('AbsAlphaF',abs(alphaF),'AbsAlphaR',abs(alphaR), ...
    'AbsFrontSteer',abs(frontSteer),'AbsAy',abs(AyTrue),'AbsR',abs(rTrue), ...
    'SignedFrontSteer',frontSteer);
conditioningNames = fieldnames(conditioning);
gainBinRows = table();
gainStability = table();
for vi = 1:numel(conditioningNames)
    varName = conditioningNames{vi};
    [binId, edges] = quantile_bins(conditioning.(varName), trainQuasi, 4);
    localRows = table();
    for bi = 1:4
        mask = trainQuasi & binId == bi;
        row = table(string(varName),bi,edges(bi),edges(bi+1),sum(mask), ...
            origin_gain(FyfModel(mask),FyfEquiv(mask)), ...
            origin_gain(FyrModel(mask),FyrEquiv(mask)), ...
            'VariableNames',{'Variable','Bin','Lower','Upper','N','kFront','kRear'});
        localRows = [localRows; row]; %#ok<AGROW>
        gainBinRows = [gainBinRows; row]; %#ok<AGROW>
        records = add_record(records,'GAIN_STABILITY','TRAIN','EffectiveGain','QUASI', ...
            varName,sprintf('Q%d',bi),'Front','kCorrection',row.kFront,'1',row.N);
        records = add_record(records,'GAIN_STABILITY','TRAIN','EffectiveGain','QUASI', ...
            varName,sprintf('Q%d',bi),'Rear','kCorrection',row.kRear,'1',row.N);
    end
    for axleName = {'Front','Rear'}
        ax = axleName{1};
        vals = localRows.(['k' ax]);
        summary = [mean(vals) std(vals,0) std(vals,0)/abs(mean(vals)) min(vals) max(vals)];
        gainStability = [gainStability; table(string(varName),string(ax),summary(1),summary(2), ...
            summary(3),summary(4),summary(5), ...
            'VariableNames',{'Variable','Axle','Mean','Std','CV','Min','Max'})]; %#ok<AGROW>
        names = {'Mean','Std','CV','Min','Max'};
        for jj=1:numel(names)
            records = add_record(records,'GAIN_STABILITY_SUMMARY','TRAIN','EffectiveGain','QUASI', ...
                varName,'all',ax,names{jj},summary(jj),'1',sum(trainQuasi));
        end
    end
end

% Shape bins: local model/equivalent gain and local slopes versus signed alpha.
shapeBins = table();
for axleName = {'Front','Rear'}
    ax = axleName{1};
    if strcmp(ax,'Front')
        alpha = alphaF; fModel = FyfModel; fEquiv = FyfEquiv;
    else
        alpha = alphaR; fModel = FyrModel; fEquiv = FyrEquiv;
    end
    [binId,edges] = quantile_bins(abs(alpha),trainQuasi,4);
    for bi=1:4
        mask = trainQuasi & binId==bi;
        slopeModel = local_slope(alpha(mask),fModel(mask));
        slopeEquiv = local_slope(alpha(mask),fEquiv(mask));
        gME = origin_gain(fEquiv(mask),fModel(mask));
        kEM = origin_gain(fModel(mask),fEquiv(mask));
        shapeBins = [shapeBins; table(string(ax),bi,edges(bi),edges(bi+1),sum(mask), ...
            gME,kEM,slopeEquiv,slopeModel, ...
            'VariableNames',{'Axle','Bin','LowerAbsAlpha','UpperAbsAlpha','N', ...
            'G_ModelOverEquiv','kCorrection','EquivalentSlope','ModelSlope'})]; %#ok<AGROW>
        vals = [gME kEM slopeEquiv slopeModel];
        mets = {'G_ModelOverEquiv','kCorrection','EquivalentSlope','ModelSlope'};
        for jj=1:numel(mets)
            unit='1'; if contains(mets{jj},'Slope'), unit='N/rad'; end
            records = add_record(records,'SHAPE_BINS','TRAIN','LocalLinear','QUASI', ...
                ['AbsAlpha' ax],sprintf('Q%d',bi),ax,mets{jj},vals(jj),unit,sum(mask));
        end
    end
end

shapeCoefficients = table([cFront(1);cRear(1)],[cFront(2);cRear(2)], ...
    'VariableNames',{'c0','c2'},'RowNames',{'Front','Rear'});
for ax = {'Front','Rear'}
    if strcmp(ax{1},'Front'), c=cFront; else, c=cRear; end
    records = add_record(records,'SHAPE_FIT','TRAIN','GainShape','QUASI','alpha2','all',ax{1},'c0',c(1),'1',sum(trainQuasi));
    records = add_record(records,'SHAPE_FIT','TRAIN','GainShape','QUASI','alpha2','all',ax{1},'c2',c(2),'1/rad^2',sum(trainQuasi));
end

% Validation improvement of gain-shape relative to constant gain.
shapeExtra = struct();
for qi=1:numel(metricNames)
    metric=metricNames{qi};
    rmsConst = signal_stats(models.ConstantGain.(metric)(validationQuasi));
    rmsShape = signal_stats(models.GainShape.(metric)(validationQuasi));
    shapeExtra.(metric) = 100*(1-rmsShape.RMS/rmsConst.RMS);
    records = add_record(records,'SHAPE_EXTRA','VALIDATION','GainShape','QUASI',metric,'all','Both', ...
        'RMSReductionVsConstantPercent',shapeExtra.(metric),'percent',sum(validationQuasi));
end

% Load-related proxy correlations after constant-gain correction.
proxyTable = table();
proxy = struct('AbsAy',abs(AyTrue),'SignedAy',AyTrue,'Vx',Vx, ...
    'FrontSteer',frontSteer,'AlphaF',alphaF,'AlphaR',alphaR);
proxyNames = fieldnames(proxy);
for datasetName = {'TRAIN','VALIDATION'}
    ds = datasetName{1};
    if strcmp(ds,'TRAIN'), mask=trainQuasi; else, mask=validationQuasi; end
    for pi=1:numel(proxyNames)
        pn=proxyNames{pi};
        cf=local_corr(models.ConstantGain.DeltaFyf(mask),proxy.(pn)(mask));
        cr=local_corr(models.ConstantGain.DeltaFyr(mask),proxy.(pn)(mask));
        proxyTable=[proxyTable;table(string(ds),string(pn),cf,cr, ...
            'VariableNames',{'Dataset','Proxy','FrontCorrelation','RearCorrelation'})]; %#ok<AGROW>
        records = add_record(records,'PROXY_CORRELATION',ds,'ConstantGain','QUASI',pn,'all','Front','Correlation',cf,'1',sum(mask));
        records = add_record(records,'PROXY_CORRELATION',ds,'ConstantGain','QUASI',pn,'all','Rear','Correlation',cr,'1',sum(mask));
    end
end

ayQuartiles = table();
for datasetName = {'TRAIN','VALIDATION'}
    ds=datasetName{1};
    if strcmp(ds,'TRAIN'), baseMask=trainQuasi; else, baseMask=validationQuasi; end
    [binId,edges]=quantile_bins(abs(AyTrue),baseMask,4);
    for bi=1:4
        mask=baseMask & binId==bi;
        row=table(string(ds),bi,edges(bi),edges(bi+1),sum(mask), ...
            rms_value(models.ConstantGain.DeltaFyf(mask)),rms_value(models.ConstantGain.DeltaFyr(mask)), ...
            origin_gain(FyfModel(mask),FyfEquiv(mask)),origin_gain(FyrModel(mask),FyrEquiv(mask)), ...
            'VariableNames',{'Dataset','Bin','LowerAbsAy','UpperAbsAy','N','FrontResidualRMS', ...
            'RearResidualRMS','kFront','kRear'});
        ayQuartiles=[ayQuartiles;row]; %#ok<AGROW>
        values=[row.FrontResidualRMS row.RearResidualRMS row.kFront row.kRear];
        metrics={'ResidualRMS','ResidualRMS','kCorrection','kCorrection'};
        axles={'Front','Rear','Front','Rear'};
        units2={'N','N','1','1'};
        for jj=1:4
            records=add_record(records,'AY_QUARTILES',ds,'ConstantGain','QUASI','AbsAy', ...
                sprintf('Q%d',bi),axles{jj},metrics{jj},values(jj),units2{jj},sum(mask));
        end
    end
end

% Left/right symmetry with the fixed +/-0.002 rad definitions.
symmetryTable=table();
for datasetName={'TRAIN','VALIDATION'}
    ds=datasetName{1};
    if strcmp(ds,'TRAIN'), baseMask=trainQuasi; else, baseMask=validationQuasi; end
    for direction={'Left','Right'}
        dir=direction{1};
        if strcmp(dir,'Left'), mask=baseMask & frontSteer>0.002;
        else, mask=baseMask & frontSteer<-0.002; end
        row=table(string(ds),string(dir),sum(mask), ...
            origin_gain(FyfModel(mask),FyfEquiv(mask)),origin_gain(FyrModel(mask),FyrEquiv(mask)), ...
            mean(models.ConstantGain.DeltaFyf(mask)),mean(models.ConstantGain.DeltaFyr(mask)), ...
            mean(models.ConstantGain.DeltaMz(mask)), ...
            'VariableNames',{'Dataset','Direction','N','kFront','kRear','DeltaFyfMeanAfterGain', ...
            'DeltaFyrMeanAfterGain','DeltaMzMeanAfterGain'});
        symmetryTable=[symmetryTable;row]; %#ok<AGROW>
        values=[row.kFront row.kRear row.DeltaFyfMeanAfterGain row.DeltaFyrMeanAfterGain row.DeltaMzMeanAfterGain];
        metrics={'kCorrection','kCorrection','MeanAfterGain','MeanAfterGain','MeanAfterGain'};
        axles={'Front','Rear','Front','Rear','Both'};
        units2={'1','1','N','N','N*m'};
        for jj=1:5
            records=add_record(records,'LEFT_RIGHT',ds,'ConstantGain','QUASI','FrontSteer',dir, ...
                axles{jj},metrics{jj},values(jj),units2{jj},sum(mask));
        end
    end
end

% Existing V1.10 front-only transient candidate; sigma is not re-fitted.
transientCase = S10.candidateData{13};
assert(abs(transientCase.sigmaF-1)<=eps && abs(transientCase.sigmaR)<=eps, ...
    'V1.10 Case 13 is not sigma_f=1, sigma_r=0.');
transientGain = table();
for datasetName={'TRAIN','VALIDATION'}
    ds=datasetName{1};
    if strcmp(ds,'TRAIN'), mask=trainQuasi; else, mask=validationQuasi; end
    ktf=origin_gain(transientCase.FyfModel(mask),FyfEquiv(mask));
    ktr=origin_gain(transientCase.FyrModel(mask),FyrEquiv(mask));
    gtf=origin_gain(FyfEquiv(mask),transientCase.FyfModel(mask));
    gtr=origin_gain(FyrEquiv(mask),transientCase.FyrModel(mask));
    transientGain=[transientGain;table(string(ds),sum(mask),ktf,ktr,gtf,gtr, ...
        'VariableNames',{'Dataset','N','kFront','kRear','GFrontModelOverEquiv','GRearModelOverEquiv'})]; %#ok<AGROW>
    vals=[ktf ktr gtf gtr]; mets={'kCorrection','kCorrection','G_ModelOverEquiv','G_ModelOverEquiv'};
    axs={'Front','Rear','Front','Rear'};
    for jj=1:4
        records=add_record(records,'TRANSIENT_INTERACTION',ds,'SigmaF1_SigmaR0','QUASI','axle','all',axs{jj},mets{jj},vals(jj),'1',sum(mask));
    end
end

% Generalization audit (validation effective gain is diagnostic only, never fitted into a candidate).
kFrontValidation = origin_gain(FyfModel(validationQuasi),FyfEquiv(validationQuasi));
kRearValidation = origin_gain(FyrModel(validationQuasi),FyrEquiv(validationQuasi));
generalization = table([kFront;kRear],[kFrontValidation;kRearValidation], ...
    100*abs(([kFrontValidation;kRearValidation]-[kFront;kRear])./[kFront;kRear]), ...
    'VariableNames',{'TrainCorrectionGain','ValidationEffectiveGain','AbsoluteDriftPercent'}, ...
    'RowNames',{'Front','Rear'});

% Produce the required plots.
figures = make_plots(resultDir,t,trainQuasi,validationQuasi,alphaF,alphaR,AyTrue, ...
    FyfModel,FyrModel,FyfEquiv,FyrEquiv,gainBinRows,ayQuartiles,models, ...
    frontSteer,kFront,kRear,kFrontValidation,kRearValidation);

resultTable = struct2table(records);
csvPath = fullfile(resultDir,'vy_dekf_v1_11_steady_tire_gain.csv');
writetable(resultTable,csvPath);

audit = struct('sourceV19',fullfile(resultDir,'vy_dekf_v1_9_model_mismatch.mat'), ...
    'sourceV110',fullfile(resultDir,'vy_dekf_v1_10_tire_transient.mat'), ...
    'samples',N,'Ts',Ts,'trainDefinition','3 <= t < 8 s', ...
    'validationDefinition','8 <= t <= 13 s','trainN',sum(trainMask), ...
    'validationN',sum(validationMask),'trainQuasiN',sum(trainQuasi), ...
    'validationQuasiN',sum(validationQuasi),'quasiRateThreshold',rateThreshold, ...
    'baselineErrors',baselineErrors,'baselineMaxError',baselineMaxError, ...
    'trainOnlyFitEnforced',true,'equivalentForceNotCarSimTireForce',true, ...
    'fixedQ',diag([1e-4 1e-4]),'fixedR',diag([1e-2 3.365172961808e-4]));

interpretation = build_interpretation(models,validationMask,validationQuasi,shapeExtra, ...
    generalization,gainStability,ayQuartiles,symmetryTable,transientGain,kFront,kRear);

matPath = fullfile(resultDir,'vy_dekf_v1_11_steady_tire_gain.mat');
save(matPath,'audit','t','trainMask','validationMask','quasiMask','trainQuasi', ...
    'validationQuasi','AyTrue','drTrueDt','rTrue','Vx','deltaWheel','frontSteer', ...
    'frontSteerRate','alphaF','alphaR','FyfEquiv','FyrEquiv','FyfModel','FyrModel', ...
    'gainSummary','shapeCoefficients','models','gainBinRows','gainStability','shapeBins', ...
    'proxyTable','ayQuartiles','symmetryTable','transientGain','generalization', ...
    'shapeExtra','interpretation','resultTable','figures','-v7.3');

statusPath = fullfile(docDir,'STAGE_VY_DEKF_V1_11_STATUS.md');
write_status(statusPath,audit,gainSummary,shapeCoefficients,models,shapeExtra, ...
    generalization,gainStability,ayQuartiles,symmetryTable,transientGain,interpretation, ...
    validationMask,validationQuasi,figures,csvPath,matPath);

figurePaths = struct2cell(figures);
required = [{csvPath}; {matPath}; {statusPath}; figurePaths(:)];
for i=1:numel(required)
    outputPath = char(required{i});
    assert(isfile(outputPath),'Missing output: %s',outputPath);
    info=builtin('dir',outputPath);
    assert(info(1).bytes>0,'Empty output: %s',outputPath);
end
fprintf('V1.11 complete | baseline=%.3g | trainQ=%d | valQ=%d | kF=%.8g | kR=%.8g\n', ...
    baselineMaxError,sum(trainQuasi),sum(validationQuasi),kFront,kRear);
fprintf('Status: %s\n',statusPath);
end

function candidate=make_candidate(Ff,Fr,FfEq,FrEq,xPredCurrent,wCurrent,FyCurrent,MzCurrent,m,Iz,a,b,Ts)
Fy=Ff+Fr; Mz=a*Ff-b*Fr;
deltaPrediction=Ts*[(Fy-FyCurrent)/m,(Mz-MzCurrent)/Iz];
candidate=struct('Fyf',Ff,'Fyr',Fr,'Fy',Fy,'Mz',Mz, ...
    'DeltaFyf',FfEq-Ff,'DeltaFyr',FrEq-Fr, ...
    'DeltaFy',(FfEq+FrEq)-Fy,'DeltaMz',(a*FfEq-b*FrEq)-Mz, ...
    'xPred',xPredCurrent+deltaPrediction,'w',wCurrent-deltaPrediction);
candidate.wVy=candidate.w(:,1); candidate.wr=candidate.w(:,2);
end

function k=origin_gain(x,y)
den=sum(x.^2);
assert(isfinite(den) && den>0,'Degenerate through-origin gain fit.');
k=sum(x.*y)/den;
end

function st=signal_stats(x)
x=x(isfinite(x));
st=struct('Mean',mean(x),'RMS',rms_value(x),'P95Abs',local_percentile(abs(x),95), ...
    'MaxAbs',max(abs(x)),'Rho1',lag_corr(x,1),'Rho10',lag_corr(x,10));
end

function v=rms_value(x)
v=sqrt(mean(x.^2));
end

function r=lag_corr(x,lag)
if numel(x)<=lag, r=NaN; else, r=local_corr(x(1:end-lag),x(1+lag:end)); end
end

function r=local_corr(x,y)
x=x(:);y=y(:);valid=isfinite(x)&isfinite(y);x=x(valid);y=y(valid);
if numel(x)<3 || std(x)==0 || std(y)==0, r=NaN; return; end
C=corrcoef(x,y);r=C(1,2);
end

function q=local_percentile(x,p)
x=sort(x(:)); n=numel(x); pos=1+(n-1)*p/100; lo=floor(pos); hi=ceil(pos);
if lo==hi, q=x(lo); else, q=x(lo)+(pos-lo)*(x(hi)-x(lo)); end
end

function [binId,edges]=quantile_bins(x,mask,nBins)
v=sort(x(mask)); edges=zeros(1,nBins+1);
for i=0:nBins, edges(i+1)=local_percentile(v,100*i/nBins); end
edges(1)=-inf; edges(end)=inf; binId=zeros(size(x));
for i=1:nBins
    if i<nBins, idx=x>=edges(i)&x<edges(i+1); else, idx=x>=edges(i)&x<=edges(i+1); end
    binId(idx)=i;
end
for i=1:nBins, assert(sum(mask&binId==i)>=5,'Insufficient samples in quantile bin %d.',i); end
end

function slope=local_slope(x,y)
p=polyfit(x(:),y(:),1); slope=p(1);
end

function records=empty_records()
records=struct('Section',{},'Dataset',{},'Model',{},'Scope',{},'Variable',{}, ...
    'Bin',{},'Axle',{},'Metric',{},'Value',{},'Unit',{},'N',{});
end

function records=add_record(records,section,dataset,model,scope,variable,bin,axle,metric,value,unit,n)
records(end+1)=struct('Section',string(section),'Dataset',string(dataset),'Model',string(model), ...
    'Scope',string(scope),'Variable',string(variable),'Bin',string(bin),'Axle',string(axle), ...
    'Metric',string(metric),'Value',double(value),'Unit',string(unit),'N',double(n));
end

function figures=make_plots(resultDir,t,trainQ,valQ,alphaF,alphaR,Ay,Ff,Fr,FfEq,FrEq,gainBins,ayBins,models,steer,kF,kR,kFv,kRv)
figures=struct(); common={'Color','w','Visible','off','Position',[100 100 1000 650]};
figures.frontScatter=fullfile(resultDir,'vy_dekf_v1_11_01_Fyf_equiv_vs_model.png');
f=figure(common{:}); scatter(Ff(trainQ),FfEq(trainQ),18,'filled'); hold on; scatter(Ff(valQ),FfEq(valQ),18,'filled');
xl=xlim; plot(xl,kF*xl,'k--','LineWidth',1.5); grid on; xlabel('Fyf model [N]');ylabel('Fyf equivalent [N]');legend('TRAIN quasi','VALIDATION quasi','TRAIN correction','Location','best');title('Front axle equivalent vs model force');exportgraphics(f,figures.frontScatter,'Resolution',160);close(f);
figures.rearScatter=fullfile(resultDir,'vy_dekf_v1_11_02_Fyr_equiv_vs_model.png');
f=figure(common{:}); scatter(Fr(trainQ),FrEq(trainQ),18,'filled'); hold on; scatter(Fr(valQ),FrEq(valQ),18,'filled');
xl=xlim; plot(xl,kR*xl,'k--','LineWidth',1.5); grid on;xlabel('Fyr model [N]');ylabel('Fyr equivalent [N]');legend('TRAIN quasi','VALIDATION quasi','TRAIN correction','Location','best');title('Rear axle equivalent vs model force');exportgraphics(f,figures.rearScatter,'Resolution',160);close(f);
figures.frontAlpha=fullfile(resultDir,'vy_dekf_v1_11_03_Fyf_vs_alpha_f.png');
f=figure(common{:});scatter(alphaF(trainQ),Ff(trainQ),16,'filled');hold on;scatter(alphaF(trainQ),FfEq(trainQ),16,'filled');grid on;xlabel('\alpha_f [rad]');ylabel('force [N]');legend('model','equivalent','Location','best');title('Front force shape, TRAIN quasi');exportgraphics(f,figures.frontAlpha,'Resolution',160);close(f);
figures.rearAlpha=fullfile(resultDir,'vy_dekf_v1_11_04_Fyr_vs_alpha_r.png');
f=figure(common{:});scatter(alphaR(trainQ),Fr(trainQ),16,'filled');hold on;scatter(alphaR(trainQ),FrEq(trainQ),16,'filled');grid on;xlabel('\alpha_r [rad]');ylabel('force [N]');legend('model','equivalent','Location','best');title('Rear force shape, TRAIN quasi');exportgraphics(f,figures.rearAlpha,'Resolution',160);close(f);
for axle={'Front','Rear'}
    ax=axle{1}; var=['AbsAlpha' ax(1)]; rows=gainBins(gainBins.Variable==var,:);
    path=fullfile(resultDir,sprintf('vy_dekf_v1_11_0%d_effective_k_%s_vs_alpha.png',4+strcmp(ax,'Front')+2*strcmp(ax,'Rear'),lower(ax(1))));
    f=figure(common{:}); centers=(rows.Lower+rows.Upper)/2; centers(1)=rows.Upper(1); centers(end)=rows.Lower(end);
    plot(centers,rows.(['k' ax]),'o-','LineWidth',1.5);grid on;xlabel(['|\alpha_' lower(ax(1)) '| [rad]']);ylabel('k correction = equivalent/model');title([ax ' effective correction gain by alpha bin']);exportgraphics(f,path,'Resolution',160);close(f);
    if strcmp(ax,'Front'),figures.frontGainAlpha=path;else,figures.rearGainAlpha=path;end
end
figures.gainAy=fullfile(resultDir,'vy_dekf_v1_11_07_effective_gain_vs_Ay.png');
f=figure(common{:}); hold on; for ds={'TRAIN','VALIDATION'}, rows=ayBins(ayBins.Dataset==ds{1},:); c=(rows.LowerAbsAy+rows.UpperAbsAy)/2;c(1)=rows.UpperAbsAy(1);c(end)=rows.LowerAbsAy(end);plot(c,rows.kFront,'o-','LineWidth',1.4);plot(c,rows.kRear,'s--','LineWidth',1.4);end;grid on;xlabel('|Ay| [m/s^2]');ylabel('k correction');legend('front TRAIN','rear TRAIN','front VALIDATION','rear VALIDATION','Location','best');title('Effective axle gain versus |Ay| quartile');exportgraphics(f,figures.gainAy,'Resolution',160);close(f);
figures.constantTime=fullfile(resultDir,'vy_dekf_v1_11_08_current_vs_constant_deltaFy_deltaMz.png');
mask=t>=8&t<=13;f=figure(common{:});subplot(2,1,1);plot(t(mask),models.Current.DeltaFy(mask));hold on;plot(t(mask),models.ConstantGain.DeltaFy(mask));grid on;ylabel('\DeltaFy [N]');legend('Current','Constant gain');subplot(2,1,2);plot(t(mask),models.Current.DeltaMz(mask));hold on;plot(t(mask),models.ConstantGain.DeltaMz(mask));grid on;ylabel('\DeltaMz [Nm]');xlabel('t [s]');exportgraphics(f,figures.constantTime,'Resolution',160);close(f);
figures.shapeTime=fullfile(resultDir,'vy_dekf_v1_11_09_current_vs_shape_deltaFy_deltaMz.png');
f=figure(common{:});subplot(2,1,1);plot(t(mask),models.Current.DeltaFy(mask));hold on;plot(t(mask),models.GainShape.DeltaFy(mask));grid on;ylabel('\DeltaFy [N]');legend('Current','Gain-shape');subplot(2,1,2);plot(t(mask),models.Current.DeltaMz(mask));hold on;plot(t(mask),models.GainShape.DeltaMz(mask));grid on;ylabel('\DeltaMz [Nm]');xlabel('t [s]');exportgraphics(f,figures.shapeTime,'Resolution',160);close(f);
figures.trainValidation=fullfile(resultDir,'vy_dekf_v1_11_10_train_vs_validation_gain.png');
f=figure(common{:});bar([kF kFv;kR kRv]);grid on;set(gca,'XTickLabel',{'Front','Rear'});ylabel('k correction = equivalent/model');legend('TRAIN fitted','VALIDATION effective','Location','best');title('TRAIN/VALIDATION gain stability');exportgraphics(f,figures.trainValidation,'Resolution',160);close(f);
end

function interpretation=build_interpretation(models,valMask,valQ,shapeExtra,generalization,gainStability,ayQuartiles,symmetry,transient,kF,kR)
metrics={'DeltaFy','DeltaMz','wVy','wr'};
for i=1:numel(metrics)
    q=metrics{i};
    interpretation.ConstantReductionValidationAll.(q)=100*(1-rms_value(models.ConstantGain.(q)(valMask))/rms_value(models.Current.(q)(valMask)));
    interpretation.ConstantReductionValidationQuasi.(q)=100*(1-rms_value(models.ConstantGain.(q)(valQ))/rms_value(models.Current.(q)(valQ)));
    interpretation.ShapeExtraValidationQuasi.(q)=shapeExtra.(q);
end
interpretation.FrontGainTrain=kF;interpretation.RearGainTrain=kR;
interpretation.FrontGainValidation=generalization.ValidationEffectiveGain(1);
interpretation.RearGainValidation=generalization.ValidationEffectiveGain(2);
interpretation.FrontGainDriftPercent=generalization.AbsoluteDriftPercent(1);
interpretation.RearGainDriftPercent=generalization.AbsoluteDriftPercent(2);
af=gainStability(gainStability.Variable=="AbsAlphaF" & gainStability.Axle=="Front",:);
ar=gainStability(gainStability.Variable=="AbsAlphaR" & gainStability.Axle=="Rear",:);
interpretation.FrontAlphaGainCV=af.CV;interpretation.RearAlphaGainCV=ar.CV;
for ds={'TRAIN','VALIDATION'}
    rows=ayQuartiles(ayQuartiles.Dataset==ds{1},:);
    interpretation.([ds{1} 'AyFrontGainRange'])=max(rows.kFront)-min(rows.kFront);
    interpretation.([ds{1} 'AyRearGainRange'])=max(rows.kRear)-min(rows.kRear);
end
tr=transient(transient.Dataset=="TRAIN",:);va=transient(transient.Dataset=="VALIDATION",:);
interpretation.TransientFrontCorrectionTrain=tr.kFront;
interpretation.TransientFrontCorrectionValidation=va.kFront;
interpretation.TransientRearCorrectionTrain=tr.kRear;
left=symmetry(symmetry.Dataset=="VALIDATION"&symmetry.Direction=="Left",:);
right=symmetry(symmetry.Dataset=="VALIDATION"&symmetry.Direction=="Right",:);
interpretation.ValidationLeftRightFrontGainDifferencePercent=100*abs(left.kFront-right.kFront)/mean(abs([left.kFront right.kFront]));
interpretation.ValidationLeftRightRearGainDifferencePercent=100*abs(left.kRear-right.kRear)/mean(abs([left.kRear right.kRear]));
end

function write_status(path,audit,gainSummary,shapeCoefficients,models,shapeExtra,generalization,gainStability,ayQuartiles,symmetry,transient,interp,valMask,valQ,figures,csvPath,matPath)
fid=fopen(path,'w','n','UTF-8');assert(fid>0,'Cannot open status file.');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.11 STATUS\n\n');
fprintf(fid,'## Scope and audit\n\n');
fprintf(fid,'V1.11 used only archived V1.9/V1.10 data. The axle-equivalent forces are offline bicycle-equivalent diagnostics, not CarSim true tire forces.\n\n');
fprintf(fid,'- Samples: %d, Ts=%.12g s.\n',audit.samples,audit.Ts);
fprintf(fid,'- TRAIN: 3 <= t < 8 s; VALIDATION: 8 <= t <= 13 s.\n');
fprintf(fid,'- Quasi-steady threshold: |steer|>0.005 rad and |steer rate|<=%.12g rad/s.\n',audit.quasiRateThreshold);
fprintf(fid,'- TRAIN quasi N=%d; VALIDATION quasi N=%d.\n',audit.trainQuasiN,audit.validationQuasiN);
fprintf(fid,'- Baseline maximum reconstruction error: %.17g (requirement <=1e-10).\n\n',audit.baselineMaxError);
fprintf(fid,'## Gain definition and TRAIN-only fit\n\n');
fprintf(fid,'`k_correction = equivalent/model` is the applied correction direction. `G_model_over_equiv` is separately fitted in the reverse direction; because both are least-squares fits with residuals, it need not be the exact reciprocal.\n\n');
fprintf(fid,'|Axle|k correction (equiv/model)|G model/equiv LS|1/k correction|VALIDATION effective k|drift|\n|:--|--:|--:|--:|--:|--:|\n');
for i=1:2
    fprintf(fid,'|%s|%.9g|%.9g|%.9g|%.9g|%.6g%%|\n',gainSummary.Properties.RowNames{i},gainSummary.kCorrection_EquivOverModel(i),gainSummary.G_ModelOverEquiv_LS(i),gainSummary.ReciprocalOfCorrection(i),generalization.ValidationEffectiveGain(i),generalization.AbsoluteDriftPercent(i));
end
fprintf(fid,'\n## Constant-gain implication\n\n');
fprintf(fid,'Primary steady-state interpretation uses VALIDATION quasi; VALIDATION all is also shown to expose transient contamination.\n\n');
fprintf(fid,'|Metric|Current RMS quasi|Constant RMS quasi|reduction quasi|reduction all|\n|:--|--:|--:|--:|--:|\n');
for q={'DeltaFy','DeltaMz','wVy','wr'}
    n=q{1};u='';if strcmp(n,'DeltaFy'),u=' N';elseif strcmp(n,'DeltaMz'),u=' Nm';elseif strcmp(n,'wVy'),u=' m/s';else,u=' rad/s';end
    rc=rms_value(models.Current.(n)(valQ));rg=rms_value(models.ConstantGain.(n)(valQ));
fprintf(fid,'|%s|%.9g%s|%.9g%s|%.6g%%|%.6g%%|\n',n,rc,u,rg,u,interp.ConstantReductionValidationQuasi.(n),interp.ConstantReductionValidationAll.(n));
end
fprintf(fid,'\nContinuous VALIDATION residual color (501 contiguous samples):\n\n');
fprintf(fid,'|Model|Vy rho1|Vy rho10|r rho1|r rho10|\n|:--|--:|--:|--:|--:|\n');
for modelName={'Current','ConstantGain','GainShape'}
    mn=modelName{1}; sv=signal_stats(models.(mn).wVy(valMask)); sr=signal_stats(models.(mn).wr(valMask));
    fprintf(fid,'|%s|%.9g|%.9g|%.9g|%.9g|\n',mn,sv.Rho1,sv.Rho10,sr.Rho1,sr.Rho10);
end
fprintf(fid,'\n## Gain-shape fit and incremental value\n\n');
fprintf(fid,'`g(alpha)=c0+c2*alpha^2`; coefficients use TRAIN quasi only. This is diagnostic-only, not a tire model or identified tire parameter.\n\n');
fprintf(fid,'|Axle|c0|c2 [1/rad^2]|alpha-bin gain CV|\n|:--|--:|--:|--:|\n');
af=gainStability(gainStability.Variable=="AbsAlphaF"&gainStability.Axle=="Front",:);ar=gainStability(gainStability.Variable=="AbsAlphaR"&gainStability.Axle=="Rear",:);
fprintf(fid,'|Front|%.9g|%.9g|%.6g|\n',shapeCoefficients.c0(1),shapeCoefficients.c2(1),af.CV);
fprintf(fid,'|Rear|%.9g|%.9g|%.6g|\n\n',shapeCoefficients.c0(2),shapeCoefficients.c2(2),ar.CV);
fprintf(fid,'|Metric|Gain-shape extra reduction vs constant, VALIDATION quasi|\n|:--|--:|\n');
for q={'DeltaFyf','DeltaFyr','DeltaFy','DeltaMz','wVy','wr'},n=q{1};fprintf(fid,'|%s|%.6g%%|\n',n,shapeExtra.(n));end
fprintf(fid,'\n## |Ay| dependence and left/right symmetry\n\n');
for ds={'TRAIN','VALIDATION'}
    rows=ayQuartiles(ayQuartiles.Dataset==ds{1},:);
    fprintf(fid,'- %s |Ay| quartile k ranges: front %.9g..%.9g; rear %.9g..%.9g.\n',ds{1},min(rows.kFront),max(rows.kFront),min(rows.kRear),max(rows.kRear));
end
fprintf(fid,'\n|Dataset|Direction|N|k front|k rear|post-gain DeltaFyf mean|DeltaFyr mean|DeltaMz mean|\n|:--|:--|--:|--:|--:|--:|--:|--:|\n');
for i=1:height(symmetry),fprintf(fid,'|%s|%s|%d|%.9g|%.9g|%.9g|%.9g|%.9g|\n',symmetry.Dataset(i),symmetry.Direction(i),symmetry.N(i),symmetry.kFront(i),symmetry.kRear(i),symmetry.DeltaFyfMeanAfterGain(i),symmetry.DeltaFyrMeanAfterGain(i),symmetry.DeltaMzMeanAfterGain(i));end
fprintf(fid,'\n## Interaction with existing sigma_f=1 m, sigma_r=0 candidate\n\n');
fprintf(fid,'|Dataset|front k correction after transient|rear k correction|front G model/equiv|rear G model/equiv|\n|:--|--:|--:|--:|--:|\n');
for i=1:height(transient),fprintf(fid,'|%s|%.9g|%.9g|%.9g|%.9g|\n',transient.Dataset(i),transient.kFront(i),transient.kRear(i),transient.GFrontModelOverEquiv(i),transient.GRearModelOverEquiv(i));end
fprintf(fid,'\n## Final answers\n\n');
fprintf(fid,'1. Front steady-state mismatch: see constant-gain reduction and gain-shape incremental reduction above; classification: **%s**.\n',classify_axle(shapeExtra.DeltaFyf,interp.FrontAlphaGainCV));
fprintf(fid,'2. Rear steady-state mismatch: **%s**.\n',classify_axle(shapeExtra.DeltaFyr,interp.RearAlphaGainCV));
fprintf(fid,'3. TRAIN-to-VALIDATION generalization drift is front %.6g%%, rear %.6g%%.\n',interp.FrontGainDriftPercent,interp.RearGainDriftPercent);
fprintf(fid,'4. Constant gain VALIDATION quasi reductions: DeltaFy %.6g%%, DeltaMz %.6g%%, Vy %.6g%%, r %.6g%%.\n',interp.ConstantReductionValidationQuasi.DeltaFy,interp.ConstantReductionValidationQuasi.DeltaMz,interp.ConstantReductionValidationQuasi.wVy,interp.ConstantReductionValidationQuasi.wr);
fprintf(fid,'5. Gain-shape extra VALIDATION quasi reductions: DeltaFy %.6g%%, DeltaMz %.6g%%, Vy %.6g%%, r %.6g%%.\n',shapeExtra.DeltaFy,shapeExtra.DeltaMz,shapeExtra.wVy,shapeExtra.wr);
fprintf(fid,'6. Alpha-bin correction-gain CV: front %.6g, rear %.6g.\n',interp.FrontAlphaGainCV,interp.RearAlphaGainCV);
fprintf(fid,'7. VALIDATION |Ay| quartile correction-gain range: front %.6g, rear %.6g. Reported only as possible load/load-sensitivity dependence, not proof of load transfer.\n',interp.VALIDATIONAyFrontGainRange,interp.VALIDATIONAyRearGainRange);
fprintf(fid,'8. VALIDATION left/right gain difference: front %.6g%%, rear %.6g%%.\n',interp.ValidationLeftRightFrontGainDifferencePercent,interp.ValidationLeftRightRearGainDifferencePercent);
fprintf(fid,'9. After sigma_f=1 m, TRAIN quasi front k=%.9g and VALIDATION quasi front k=%.9g; deviation from 1 remains a separately measured steady-state issue.\n',interp.TransientFrontCorrectionTrain,interp.TransientFrontCorrectionValidation);
fprintf(fid,'10. Recommended V1.12 direction from the numerical classification: **%s**. No correction is implemented here.\n',recommend_direction(interp,shapeExtra));
fprintf(fid,'\nHighly colored residual assessment is retained in the MAT/CSV rho1/rho10 records; constant/shape fits are not treated as online-ready models.\n\n');
fprintf(fid,'## Outputs\n\n- `%s`\n- `%s`\n',csvPath,matPath);
paths=struct2cell(figures);for i=1:numel(paths),fprintf(fid,'- `%s`\n',paths{i});end
fprintf(fid,'\n**NO STEADY-STATE TIRE CORRECTION WAS APPLIED ONLINE.**\n\n');
fprintf(fid,'**NO TIRE PARAMETER WAS IDENTIFIED OR CHANGED.**\n\n');
fprintf(fid,'**THIS WAS AN OFFLINE STEADY-STATE GAIN/SHAPE ATTRIBUTION ONLY.**\n');
end

function s=classify_axle(extraReduction,cv)
if extraReduction>10 && cv>0.1, s='shape dependence materially exceeds a pure constant scale';
elseif extraReduction>5, s='constant scaling helps, with a secondary shape contribution';
else, s='predominantly constant axle scaling within this ablation';end
end

function s=recommend_direction(interp,shapeExtra)
stableScale = interp.FrontGainDriftPercent<5 && interp.RearGainDriftPercent<5 && ...
    interp.ValidationLeftRightFrontGainDifferencePercent<5 && ...
    interp.ValidationLeftRightRearGainDifferencePercent<5;
strongConstant = interp.ConstantReductionValidationQuasi.DeltaFy>50 && ...
    interp.ConstantReductionValidationQuasi.DeltaMz>50;
coherentShape = shapeExtra.DeltaFy>10 && shapeExtra.DeltaMz>10 && ...
    shapeExtra.wVy>10 && shapeExtra.wr>10;
if strongConstant && stableScale
    s='A. axle-wise steady-state force scaling has the strongest current support; alpha-shape dependence is secondary and not yet moment-consistent';
elseif coherentShape
    s='B. tire curve shape correction should be diagnosed next';
elseif interp.VALIDATIONAyFrontGainRange>0.1 || interp.VALIDATIONAyRearGainRange>0.1
    s='C. Fz/load-sensitivity/load-transfer diagnostics should be prioritized';
else
    s='D. return to other dynamics/model terms';
end
end
