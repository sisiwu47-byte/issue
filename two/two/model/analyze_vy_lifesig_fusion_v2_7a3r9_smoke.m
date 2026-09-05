function analysis = analyze_vy_lifesig_fusion_v2_7a3r9_smoke()
%ANALYZE_VY_LIFESIG_FUSION_V2_7A3R9_SMOKE Offline frozen-formula replay.

root=fileparts(fileparts(mfilename('fullpath')));
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r9_smoke.mat');
csvFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r9_smoke_evidence.csv');
R=load(resultFile,'smoke');smoke=R.smoke;
assert(smoke.simCalled&&smoke.simInvocationCount==1&& ...
    smoke.simulationCompleted&&smoke.carSimRun&&smoke.hashesUnchanged, ...
    'A3R9:RuntimeEvidenceInvalid','A3R9 runtime evidence is not eligible.');

required100={'lifesig_vy_ls_log','lifesig_alpha_d_log', ...
    'lifesig_alpha_k_log','lifesig_alpha_f_log','lifesig_h_d_log', ...
    'lifesig_h_k_log','lifesig_h_f_log','lifesig_fusion_valid_log', ...
    'lifesig_fallback_active_log','fusion_vy_d_log','rel_d_valid_log', ...
    'fusion_vy_k_log','kkf_diag_log1','fusion_vy_f_log', ...
    'rel_f_reliability_log','rel_common_time_100hz_log', ...
    'rel_vy_true_100hz_log','reset_g0'};
t=smoke.raw.rel_common_time_100hz_log.time(:);N=numel(t);
analysis=struct();analysis.stage='V2.7-A3R9';analysis.sampleCount=N;
analysis.tStart=t(1);analysis.tEnd=t(end);analysis.dt=diff(t);
analysis.time100Hz=N==21&&abs(t(1))<=1e-14&&abs(t(end)-0.20)<=1e-12&& ...
    all(abs(analysis.dt-0.01)<=1e-12);
analysis.allAligned=true;
for k=1:numel(required100)
    r=smoke.raw.(required100{k});
    analysis.allAligned=analysis.allAligned&&numel(r.time)==N&& ...
        all(abs(r.time(:)-t)<=1e-12);
end

vyLS=column(smoke.raw.lifesig_vy_ls_log,N);
aD=column(smoke.raw.lifesig_alpha_d_log,N);
aK=column(smoke.raw.lifesig_alpha_k_log,N);
aF=column(smoke.raw.lifesig_alpha_f_log,N);
hD=column(smoke.raw.lifesig_h_d_log,N);
hK=column(smoke.raw.lifesig_h_k_log,N);
hF=column(smoke.raw.lifesig_h_f_log,N);
fusionValid=column(smoke.raw.lifesig_fusion_valid_log,N);
fallback=column(smoke.raw.lifesig_fallback_active_log,N);
vyD=column(smoke.raw.fusion_vy_d_log,N);
dValid=sample_matrix(smoke.raw.rel_d_valid_log,N);
vyK=column(smoke.raw.fusion_vy_k_log,N);
kDiag=sample_matrix(smoke.raw.kkf_diag_log1,N);
vyF=column(smoke.raw.fusion_vy_f_log,N);
fRel=sample_matrix(smoke.raw.rel_f_reliability_log,N);
vyTrue=column(smoke.raw.rel_vy_true_100hz_log,N); %#ok<NASGU>
reset=column(smoke.raw.reset_g0,N);
assert(size(dValid,2)>=2&&size(kDiag,2)>=7&&size(fRel,2)>=3, ...
    'A3R9:DiagnosticWidth','D/K/F diagnostic vector width is insufficient.');
updateD=dValid(:,1);updateK=kDiag(:,6);age=fRel(:,1);ageValid=fRel(:,2);

allNumeric=[vyLS aD aK aF hD hK hF fusionValid fallback vyD dValid ...
    vyK kDiag vyF fRel vyTrue reset];
analysis.allFinite=all(isfinite(allNumeric),'all');
normal=fusionValid~=0;
analysis.normalCount=nnz(normal);analysis.fallbackCount=nnz(fallback~=0);
analysis.alphaMin=min([aD;aK;aF]);
analysis.alphaSumMaxError=max_abs(aD(normal)+aK(normal)+aF(normal)-1);
analysis.alphaInvariant=all(aD(normal)>=-1e-14)&&all(aK(normal)>=-1e-14)&& ...
    all(aF(normal)>=-1e-14)&&analysis.alphaSumMaxError<=1e-12;
analysis.fallbackSemantics=all((fallback~=0)==~normal)&& ...
    all(aD(~normal)==0)&&all(aK(~normal)==0)&&all(aF(~normal)==0);

hDExpected=double(updateD~=0 & isfinite(vyD));
hKExpected=double(updateK~=0 & isfinite(vyK));
hFExpected=zeros(N,1);activeF=ageValid~=0 & isfinite(age) & age>=0 & isfinite(vyF);
hFExpected(activeF)=exp(-(age(activeF)*0.01)/28.252990189369939);
analysis.healthErrors=struct('D',max_abs(hD-hDExpected), ...
    'K',max_abs(hK-hKExpected),'F',max_abs(hF-hFExpected));
analysis.healthSemantics=max([analysis.healthErrors.D analysis.healthErrors.K ...
    analysis.healthErrors.F])<=1e-12;

replay=zeros(N,9);last=0;hasLast=0;
for k=1:N
    [replay(k,1),replay(k,2),replay(k,3),replay(k,4), ...
        replay(k,8),replay(k,9),last,hasLast,replay(k,5), ...
        replay(k,6),replay(k,7)]=vy_lifesig_fusion_step( ...
        vyD(k),updateD(k),vyK(k),updateK(k),vyF(k),age(k), ...
        ageValid(k),reset(k),last,hasLast);
end
runtime=[vyLS aD aK aF hD hK hF fusionValid fallback];
names={'Vy_LS','alpha_D','alpha_K','alpha_F','H_D','H_K','H_F', ...
    'fusion_valid','fallback_active'};
analysis.replayMaxAbsError=struct();errs=zeros(1,9);
for k=1:9
    errs(k)=max_abs(runtime(:,k)-replay(:,k));
    analysis.replayMaxAbsError.(names{k})=errs(k);
end
analysis.replayMax=max(errs);analysis.replayPassed=analysis.replayMax<=1e-12;
analysis.ageSequence=struct('first',age(1),'last',age(end), ...
    'incrementsByOne',all(abs(diff(age)-1)<=1e-12), ...
    'validCount',nnz(ageValid~=0),'resetValidCount',nnz(fRel(:,3)~=0));

analysis.passed=analysis.time100Hz&&analysis.allAligned&&analysis.allFinite&& ...
    analysis.alphaInvariant&&analysis.fallbackSemantics&& ...
    analysis.healthSemantics&&analysis.replayPassed;
smoke.analysis=analysis;smoke.passed=analysis.passed;
save(resultFile,'smoke','-v7.3');write_csv(csvFile,analysis,smoke);
fprintf(['A3R9_ANALYSIS|N=%d|t=[%.17g %.17g]|dt=%.17g|finite=%d|' ...
    'aligned=%d|normal=%d|fallback=%d|alphaErr=%.3g|healthErr=%.3g|' ...
    'replayErr=%.3g|passed=%d\n'],N,t(1),t(end),mean(diff(t)), ...
    analysis.allFinite,analysis.allAligned,analysis.normalCount, ...
    analysis.fallbackCount,analysis.alphaSumMaxError, ...
    max([analysis.healthErrors.D analysis.healthErrors.K analysis.healthErrors.F]), ...
    analysis.replayMax,analysis.passed);
assert(analysis.passed,'A3R9:AnalysisFailed', ...
    'LifeSig integration smoke gates did not pass.');
end

function x=column(r,N)
x=sample_matrix(r,N);assert(size(x,2)==1,'A3R9:ExpectedScalar','Expected scalar log.');
end
function x=sample_matrix(r,N)
d=double(r.data);
if isvector(d)&&numel(d)==N
    x=reshape(d,N,1);
elseif size(d,1)==N
    x=reshape(d,N,[]);
elseif size(d,ndims(d))==N
    order=[ndims(d) 1:ndims(d)-1];x=reshape(permute(d,order),N,[]);
else
    error('A3R9:SampleDimension','Cannot map log data size %s to %d samples.', ...
        mat2str(size(d)),N);
end
end
function v=max_abs(x)
if isempty(x),v=0;else,v=max(abs(double(x(:))));end
end
function write_csv(path,a,s)
fid=fopen(path,'wt');assert(fid>0,'A3R9:EvidenceOpen','Cannot open evidence CSV.');
c=onCleanup(@()fclose(fid));
fprintf(fid,'stage,check,value\n');
fprintf(fid,'V2.7-A3R9,role,%s\n',s.role);
fprintf(fid,'V2.7-A3R9,simulationCompleted,%d\n',s.simulationCompleted);
fprintf(fid,'V2.7-A3R9,carSimRun,%d\n',s.carSimRun);
fprintf(fid,'V2.7-A3R9,simInvocationCount,%d\n',s.simInvocationCount);
fprintf(fid,'V2.7-A3R9,sampleCount,%d\n',a.sampleCount);
fprintf(fid,'V2.7-A3R9,time100Hz,%d\n',a.time100Hz);
fprintf(fid,'V2.7-A3R9,allAligned,%d\n',a.allAligned);
fprintf(fid,'V2.7-A3R9,allFinite,%d\n',a.allFinite);
fprintf(fid,'V2.7-A3R9,normalCount,%d\n',a.normalCount);
fprintf(fid,'V2.7-A3R9,fallbackCount,%d\n',a.fallbackCount);
fprintf(fid,'V2.7-A3R9,alphaSumMaxError,%.17g\n',a.alphaSumMaxError);
fprintf(fid,'V2.7-A3R9,healthMaxError,%.17g\n', ...
    max([a.healthErrors.D a.healthErrors.K a.healthErrors.F]));
fprintf(fid,'V2.7-A3R9,replayMaxError,%.17g\n',a.replayMax);
fprintf(fid,'V2.7-A3R9,passed,%d\n',a.passed);
clear c
end
