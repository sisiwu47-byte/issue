function analysis = analyze_vy_lifesig_fusion_v2_7a3r10_nominal()
%ANALYZE_VY_LIFESIG_FUSION_V2_7A3R10_NOMINAL Offline replay and metrics.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r10_nominal.mat');
csvFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r10_nominal_evidence.csv');
R=load(resultFile,'runtime');runtime=R.runtime;
assert(runtime.simCalled&&runtime.simInvocationCount==1&& ...
    runtime.simulationCompleted&&runtime.carSimRun&&runtime.hashesUnchanged, ...
    'A3R10:RuntimeEvidenceInvalid','A3R10 runtime evidence is not eligible.');

required100={'lifesig_vy_ls_log','lifesig_alpha_d_log', ...
    'lifesig_alpha_k_log','lifesig_alpha_f_log','lifesig_h_d_log', ...
    'lifesig_h_k_log','lifesig_h_f_log','lifesig_fusion_valid_log', ...
    'lifesig_fallback_active_log','fusion_vy_d_log','rel_d_valid_log', ...
    'fusion_vy_k_log','kkf_diag_log1','fusion_vy_f_log', ...
    'rel_f_reliability_log','rel_common_time_100hz_log', ...
    'rel_vy_true_100hz_log','reset_g0'};
t=runtime.raw.rel_common_time_100hz_log.time(:);N=numel(t);
analysis=struct();analysis.stage='V2.7-A3R10';analysis.role=runtime.role;
analysis.sampleCount=N;analysis.tStart=t(1);analysis.tEnd=t(end);
analysis.dt=diff(t);analysis.time100Hz=N==1601&&abs(t(1))<=1e-14&& ...
    abs(t(end)-16)<=1e-11&&all(abs(analysis.dt-0.01)<=1e-11);
analysis.allAligned=true;
for k=1:numel(required100)
    r=runtime.raw.(required100{k});
    analysis.allAligned=analysis.allAligned&&numel(r.time)==N&& ...
        all(abs(r.time(:)-t)<=1e-11);
end
commonData=column(runtime.raw.rel_common_time_100hz_log,N);
analysis.commonIdentityError=max_abs(commonData-t);
analysis.commonIdentity=analysis.commonIdentityError<=1e-11;

vyLS=column(runtime.raw.lifesig_vy_ls_log,N);
aD=column(runtime.raw.lifesig_alpha_d_log,N);
aK=column(runtime.raw.lifesig_alpha_k_log,N);
aF=column(runtime.raw.lifesig_alpha_f_log,N);
hD=column(runtime.raw.lifesig_h_d_log,N);
hK=column(runtime.raw.lifesig_h_k_log,N);
hF=column(runtime.raw.lifesig_h_f_log,N);
fusionValid=column(runtime.raw.lifesig_fusion_valid_log,N);
fallback=column(runtime.raw.lifesig_fallback_active_log,N);
vyD=column(runtime.raw.fusion_vy_d_log,N);
dValid=sample_matrix(runtime.raw.rel_d_valid_log,N);
vyK=column(runtime.raw.fusion_vy_k_log,N);
kDiag=sample_matrix(runtime.raw.kkf_diag_log1,N);
vyF=column(runtime.raw.fusion_vy_f_log,N);
fRel=sample_matrix(runtime.raw.rel_f_reliability_log,N);
vyTrue=column(runtime.raw.rel_vy_true_100hz_log,N);
reset=column(runtime.raw.reset_g0,N);
assert(size(dValid,2)>=2&&size(kDiag,2)>=7&&size(fRel,2)>=3, ...
    'A3R10:DiagnosticWidth','D/K/F diagnostic vector width is insufficient.');
updateD=dValid(:,1);updateK=kDiag(:,6);age=fRel(:,1);ageValid=fRel(:,2);

allNumeric=[vyLS aD aK aF hD hK hF fusionValid fallback vyD dValid ...
    vyK kDiag vyF fRel vyTrue reset];
analysis.allFinite=all(isfinite(allNumeric),'all');
normal=fusionValid~=0;fallbackMask=fallback~=0;
analysis.normalCount=nnz(normal);analysis.fallbackCount=nnz(fallbackMask);
analysis.alphaSumMaxError=max_abs(aD(normal)+aK(normal)+aF(normal)-1);
analysis.alphaInvariant=all(aD(normal)>=-1e-14)&&all(aK(normal)>=-1e-14)&& ...
    all(aF(normal)>=-1e-14)&&analysis.alphaSumMaxError<=1e-12;
analysis.fallbackSemantics=all(fallbackMask==~normal)&& ...
    all(aD(~normal)==0)&&all(aK(~normal)==0)&&all(aF(~normal)==0);

hDExpected=double(updateD~=0 & isfinite(vyD));
hKExpected=double(updateK~=0 & isfinite(vyK));
hFExpected=zeros(N,1);activeF=ageValid~=0 & isfinite(age) & age>=0 & isfinite(vyF);
hFExpected(activeF)=exp(-(age(activeF)*0.01)/28.252990189369939);
analysis.healthErrors=struct('D',max_abs(hD-hDExpected), ...
    'K',max_abs(hK-hKExpected),'F',max_abs(hF-hFExpected));
analysis.healthSemantics=max([analysis.healthErrors.D analysis.healthErrors.K ...
    analysis.healthErrors.F])<=1e-12;

qD=0.8426184093257221;qK=0.14643969744669255;qF=0.010941893227585452;
scoreD=qD*hDExpected;scoreK=qK*hKExpected;scoreF=qF*hFExpected;
scoreSum=scoreD+scoreK+scoreF;analysis.minimumScoreSum=min(scoreSum);
analysis.availabilityDropCount=struct('D',nnz(~(updateD~=0 & isfinite(vyD))), ...
    'K',nnz(~(updateK~=0 & isfinite(vyK))), ...
    'F',nnz(~activeF),'any',nnz(~(hDExpected~=0 & hKExpected~=0 & activeF)));
analysis.fallbackReasons=struct( ...
    'noActiveTrack',nnz(fallbackMask & (hDExpected==0) & (hKExpected==0) & (hFExpected==0)), ...
    'nonfiniteOrNonpositiveScore',nnz(fallbackMask & ~(isfinite(scoreSum)&(scoreSum>0))), ...
    'other',nnz(fallbackMask & isfinite(scoreSum)&(scoreSum>0)));

replay=zeros(N,9);last=0;hasLast=0;
for k=1:N
    [replay(k,1),replay(k,2),replay(k,3),replay(k,4), ...
        replay(k,8),replay(k,9),last,hasLast,replay(k,5), ...
        replay(k,6),replay(k,7)]=vy_lifesig_fusion_step( ...
        vyD(k),updateD(k),vyK(k),updateK(k),vyF(k),age(k), ...
        ageValid(k),reset(k),last,hasLast);
end
runtimeOutputs=[vyLS aD aK aF hD hK hF fusionValid fallback];
names={'Vy_LS','alpha_D','alpha_K','alpha_F','H_D','H_K','H_F', ...
    'fusion_valid','fallback_active'};
analysis.replayMaxAbsError=struct();errs=zeros(1,9);
for k=1:9
    errs(k)=max_abs(runtimeOutputs(:,k)-replay(:,k));
    analysis.replayMaxAbsError.(names{k})=errs(k);
end
analysis.replayMax=max(errs);analysis.replayPassed=analysis.replayMax<=1e-12;

analysis.alphaStats=struct('D',stats(aD),'K',stats(aK),'F',stats(aF));
analysis.HF=struct('start',hF(1),'end',hF(end),'min',min(hF),'max',max(hF));
analysis.alphaF=struct('start',aF(1),'end',aF(end));
vyQ=qD*vyD+qK*vyK+qF*vyF;
fwD=0.9004680917645591;fwK=0.09953190823544089;
vyFW=fwD*vyD+fwK*vyK;
analysis.metricsRole='DESCRIPTIVE_ONLY';
analysis.metrics=struct('LifeSig',metrics(vyLS,vyTrue), ...
    'D',metrics(vyD,vyTrue),'K',metrics(vyK,vyTrue), ...
    'F',metrics(vyF,vyTrue),'StaticPrior',metrics(vyQ,vyTrue), ...
    'V25Fixed',metrics(vyFW,vyTrue));

analysis.passed=analysis.time100Hz&&analysis.allAligned&& ...
    analysis.commonIdentity&&analysis.allFinite&&analysis.alphaInvariant&& ...
    analysis.fallbackSemantics&&analysis.healthSemantics&&analysis.replayPassed;
runtime.analysis=analysis;runtime.passed=analysis.passed;
save(resultFile,'runtime','-v7.3');write_csv(csvFile,analysis,runtime);
fprintf(['A3R10_ANALYSIS|N=%d|t=[%.17g %.17g]|dt=%.17g|finite=%d|' ...
    'aligned=%d|normal=%d|fallback=%d|alphaErr=%.3g|healthErr=%.3g|' ...
    'replayErr=%.3g|minScore=%.17g|passed=%d\n'],N,t(1),t(end),mean(diff(t)), ...
    analysis.allFinite,analysis.allAligned,analysis.normalCount, ...
    analysis.fallbackCount,analysis.alphaSumMaxError, ...
    max([analysis.healthErrors.D analysis.healthErrors.K analysis.healthErrors.F]), ...
    analysis.replayMax,analysis.minimumScoreSum,analysis.passed);
fprintf(['A3R10_WEIGHTS|D=%s|K=%s|F=%s|HF=[%.17g %.17g]|' ...
    'alphaF=[%.17g %.17g]|drops=[%d %d %d]\n'], ...
    stat_text(analysis.alphaStats.D),stat_text(analysis.alphaStats.K), ...
    stat_text(analysis.alphaStats.F),analysis.HF.start,analysis.HF.end, ...
    analysis.alphaF.start,analysis.alphaF.end, ...
    analysis.availabilityDropCount.D,analysis.availabilityDropCount.K, ...
    analysis.availabilityDropCount.F);
fprintf(['A3R10_METRICS|LS=%s|D=%s|K=%s|F=%s|Q=%s|FW=%s|' ...
    'role=DESCRIPTIVE_ONLY\n'],metric_text(analysis.metrics.LifeSig), ...
    metric_text(analysis.metrics.D),metric_text(analysis.metrics.K), ...
    metric_text(analysis.metrics.F),metric_text(analysis.metrics.StaticPrior), ...
    metric_text(analysis.metrics.V25Fixed));
assert(analysis.passed,'A3R10:AnalysisFailed', ...
    'LifeSig 16-s nominal validation gates did not pass.');
end

function s=stats(x)
s=struct('min',min(x),'max',max(x),'mean',mean(x),'std',std(x));
end
function m=metrics(y,truth)
e=y-truth;m=struct('RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)), ...
    'MaxAbs',max(abs(e)),'Bias',mean(e));
end
function x=column(r,N)
x=sample_matrix(r,N);assert(size(x,2)==1,'A3R10:ExpectedScalar','Expected scalar log.');
end
function x=sample_matrix(r,N)
d=double(r.data);
if isvector(d)&&numel(d)==N,x=reshape(d,N,1);
elseif size(d,1)==N,x=reshape(d,N,[]);
elseif size(d,ndims(d))==N
    order=[ndims(d) 1:ndims(d)-1];x=reshape(permute(d,order),N,[]);
else,error('A3R10:SampleDimension','Cannot map log size %s to %d samples.',mat2str(size(d)),N);
end
end
function v=max_abs(x)
if isempty(x),v=0;else,v=max(abs(double(x(:))));end
end
function t=stat_text(s)
t=sprintf('[min=%.9g max=%.9g mean=%.9g std=%.9g]',s.min,s.max,s.mean,s.std);
end
function t=metric_text(m)
t=sprintf('[RMSE=%.9g MAE=%.9g MaxAbs=%.9g Bias=%.9g]',m.RMSE,m.MAE,m.MaxAbs,m.Bias);
end
function write_csv(path,a,r)
fid=fopen(path,'wt');assert(fid>0,'A3R10:EvidenceOpen','Cannot open evidence CSV.');
c=onCleanup(@()fclose(fid));
fprintf(fid,'stage,check,value\n');
fprintf(fid,'V2.7-A3R10,role,%s\n',r.role);
fprintf(fid,'V2.7-A3R10,simulationCompleted,%d\n',r.simulationCompleted);
fprintf(fid,'V2.7-A3R10,carSimRun,%d\n',r.carSimRun);
fprintf(fid,'V2.7-A3R10,simInvocationCount,%d\n',r.simInvocationCount);
fprintf(fid,'V2.7-A3R10,sampleCount,%d\n',a.sampleCount);
fprintf(fid,'V2.7-A3R10,time100Hz,%d\n',a.time100Hz);
fprintf(fid,'V2.7-A3R10,allAligned,%d\n',a.allAligned);
fprintf(fid,'V2.7-A3R10,allFinite,%d\n',a.allFinite);
fprintf(fid,'V2.7-A3R10,normalCount,%d\n',a.normalCount);
fprintf(fid,'V2.7-A3R10,fallbackCount,%d\n',a.fallbackCount);
fprintf(fid,'V2.7-A3R10,alphaSumMaxError,%.17g\n',a.alphaSumMaxError);
fprintf(fid,'V2.7-A3R10,healthMaxError,%.17g\n',max([a.healthErrors.D a.healthErrors.K a.healthErrors.F]));
fprintf(fid,'V2.7-A3R10,replayMaxError,%.17g\n',a.replayMax);
fprintf(fid,'V2.7-A3R10,minimumScoreSum,%.17g\n',a.minimumScoreSum);
fprintf(fid,'V2.7-A3R10,availabilityDrops_D,%d\n',a.availabilityDropCount.D);
fprintf(fid,'V2.7-A3R10,availabilityDrops_K,%d\n',a.availabilityDropCount.K);
fprintf(fid,'V2.7-A3R10,availabilityDrops_F,%d\n',a.availabilityDropCount.F);
for n={'D','K','F'}
    s=a.alphaStats.(n{1});fprintf(fid,'V2.7-A3R10,alpha_%s,"min=%.17g;max=%.17g;mean=%.17g;std=%.17g"\n',n{1},s.min,s.max,s.mean,s.std);
end
fprintf(fid,'V2.7-A3R10,H_F_start,%.17g\n',a.HF.start);
fprintf(fid,'V2.7-A3R10,H_F_end,%.17g\n',a.HF.end);
fprintf(fid,'V2.7-A3R10,alpha_F_start,%.17g\n',a.alphaF.start);
fprintf(fid,'V2.7-A3R10,alpha_F_end,%.17g\n',a.alphaF.end);
for n={'LifeSig','D','K','F','StaticPrior','V25Fixed'}
    m=a.metrics.(n{1});fprintf(fid,'V2.7-A3R10,metrics_%s,"RMSE=%.17g;MAE=%.17g;MaxAbs=%.17g;Bias=%.17g;DESCRIPTIVE_ONLY"\n',n{1},m.RMSE,m.MAE,m.MaxAbs,m.Bias);
end
fprintf(fid,'V2.7-A3R10,passed,%d\n',a.passed);clear c
end
