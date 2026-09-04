function analysis = analyze_vy_fixed_fusion_v2_5i1_H01_holdout()
%ANALYZE_VY_FIXED_FUSION_V2_5I1_H01_HOLDOUT Read-only H01 analyzer.
% Phase 1 establishes integrity/eligibility before Phase 2 computes metrics.

root=fileparts(fileparts(mfilename('fullpath')));
preFile=fullfile(root,'results','vy_fixed_fusion_v2_5i_holdout_preexecution_registry.csv');
weightFile=fullfile(root,'results','vy_fixed_fusion_v2_5h2_runtime_weight_manifest.csv');
gateFile=fullfile(root,'results','vy_fixed_fusion_v2_5i1_H01_integrity_gates.csv');
metricFile=fullfile(root,'results','vy_fixed_fusion_v2_5i1_H01_metrics.csv');
acqFile=fullfile(root,'results','vy_fixed_fusion_v2_5i1_H01_acquisition_record.csv');
targetExpected='AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B';
tol=1e-12;
assert(isfile(preFile)&&isfile(weightFile),'V25I1A:Lineage','Frozen H01 preregistration or H2 weight evidence is missing.');
pre=readtable(preFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string'); h01=pre(pre.execution_order==1,:);
assert(height(h01)==1,'V25I1A:Identity','Execution order 1 does not identify exactly one frozen H01 row.');
runId=string(h01.run_id); resultFile=fullfile(root,strrep(char(h01.formal_result_path),'/',filesep));
assert(isfile(resultFile),'V25I1A:MissingRuntime','H01 formal runtime MAT is missing.');
S=load(resultFile,'report'); report=S.report;
assert(strcmp(string(report.runId),runId),'V25I1A:Identity','Formal MAT run ID differs from frozen H01 ID.');
assert(isfield(report,'simCalled')&&isfield(report,'simCallCount')&&isfield(report,'simulationCompleted')&&isfield(report,'carSimRun'), ...
    'V25I1A:RuntimeEvidence','Runtime completion fields are missing.');
assert(~isfield(report,'analysis'),'V25I1A:Immutable','Runtime MAT already contains analysis; analyzer will not overwrite it.');

% ---------------- Phase 1: integrity and eligibility ----------------
duration=double(h01.duration); rate=double(h01.estimator_rate); Ts=1/rate; expectedN=round(duration*rate)+1;
g=struct(); g.formalMatExists=isfile(resultFile); g.runIdExact=strcmp(string(report.runId),runId); g.roleExact=strcmp(string(report.role),'HOLDOUT_VALIDATION');
g.simCalled=logical(report.simCalled)&&double(report.simCallCount)==1; g.runtimeCompleted=logical(report.simulationCompleted)&&logical(report.carSimRun);
g.targetHashExact=isfield(report,'targetHashAfter')&&strcmpi(string(report.targetHashAfter),targetExpected);
w=readtable(weightFile,'Delimiter',',','VariableNamingRule','preserve','TextType','string'); alpha=[double(w.runtime_alpha_D),double(w.runtime_alpha_K),double(w.runtime_alpha_F)];
g.runtimeAlphaExact=isequal(alpha,[0.9004680917645591 0.09953190823544089 0])&&sum(alpha)==1&&w.weight_set_id=="V25_FIXED_WEIGHT_ALPHA_V1";
if g.runtimeCompleted && isfield(report,'carSim')
    g.carSimEnvironment=strcmpi(string(report.carSim.pwd),fullfile(root,'model'))&&strcmpi(string(report.carSim.activeSimfile),fullfile(root,'model','simfile.sim'))&& ...
        strcmpi(string(report.carSim.progDir),'D:\carsim\CarSim2021.0_Prog\')&&strcmpi(string(report.carSim.dataDir),'D:\carsim\CarSim2021.0_Data\')&& ...
        ~logical(report.carSim.gRequestBefore)&&~logical(report.carSim.gRequestConsole);
else, g.carSimEnvironment=false; end
r=report.raw; names={'fusion_vy_d_log','fusion_vy_k_log','fusion_vy_f_log','fusion_vy_fw_log','dekf_x_log','dekf_P_log','dekf_diag_log','kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1','fusion_f_P_log','fusion_f_diag_log','parallel_input_log','reset_g0','steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg','steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg','vy_true_log1','Vx_true_log'};
g.requiredLogsPresent=all(cellfun(@(n)isfield(r,n),names));
if g.requiredLogsPresent
    tD=double(r.fusion_vy_d_log.time(:));tK=double(r.fusion_vy_k_log.time(:));tF=double(r.fusion_vy_f_log.time(:));tFW=double(r.fusion_vy_fw_log.time(:));
    n=[numel(tD) numel(tK) numel(tF) numel(tFW)]; ts=struct('D',timing_stats(tD,Ts,duration),'K',timing_stats(tK,Ts,duration),'F',timing_stats(tF,Ts,duration),'fusion',timing_stats(tFW,Ts,duration));
    ts.DvsKMaxDiff=max_pair_diff(tD,tK);ts.DvsFMaxDiff=max_pair_diff(tD,tF);ts.DvsFusionMaxDiff=max_pair_diff(tD,tFW);ts.exactSameIndex=isequal(tD,tK,tF,tFW);
    g.commonTiming=all([ts.D.pass ts.K.pass ts.F.pass ts.fusion.pass])&&all(n==expectedN)&&ts.exactSameIndex&&max([ts.DvsKMaxDiff ts.DvsFMaxDiff ts.DvsFusionMaxDiff])<=tol;
    dX=sample_rows(r.dekf_x_log.data,expectedN,2);dP=covariance_pages(r.dekf_P_log.data,expectedN,2);dDiag=sample_rows(r.dekf_diag_log.data,expectedN,65); dCov=covariance_stats(dP);
    dAligned=isequal(tD,double(r.dekf_x_log.time(:)),double(r.dekf_P_log.time(:)),double(r.dekf_diag_log.time(:))); dStep=dDiag(:,57);dAy=dDiag(:,56)>0.5; expectedAyN=round(duration/0.05)+1;
    g.dIntegrity=dAligned&&all(isfinite(dX),'all')&&all(isfinite(dP),'all')&&all(isfinite(dDiag),'all')&&dCov.valid&& ...
        nnz(abs(dStep)<=tol)==1&&abs(tD(find(abs(dStep)<=tol,1)))<=tol&&isequal(dStep(:),(0:expectedN-1).')&&nnz(dAy)==expectedAyN;
    kU=sample_rows(r.kkf_u_log1.data,expectedN,4);kX=sample_rows(r.kkf_x_log1.data,expectedN,2);kP=covariance_pages(r.kkf_P_log1.data,expectedN,2);kDiag=sample_rows(r.kkf_diag_log1.data,expectedN,5);kCov=covariance_stats(kP);kAligned=isequal(tK,double(r.kkf_u_log1.time(:)),double(r.kkf_x_log1.time(:)),double(r.kkf_P_log1.time(:)),double(r.kkf_diag_log1.time(:)));
    reset=vector(r.reset_g0);g.kIntegrity=kAligned&&all(isfinite(kU),'all')&&all(isfinite(kX),'all')&&all(isfinite(kP),'all')&&all(isfinite(kDiag),'all')&&kCov.valid&&nnz(reset>0.5)==1&&abs(double(r.reset_g0.time(find(reset>0.5,1))))<=tol;
    fVy=vector(r.fusion_vy_f_log);fP=vector(r.fusion_f_P_log);fDiag=sample_rows(r.fusion_f_diag_log.data,expectedN,3);fAligned=isequal(tF,double(r.fusion_f_P_log.time(:)),double(r.fusion_f_diag_log.time(:)));g.fIntegrity=fAligned&&all(isfinite(fVy))&&all(isfinite(fP))&&all(isfinite(fDiag),'all')&&all(fP>=0)&&nnz(fDiag(:,3)>0.5)==0;
    vD=vector(r.fusion_vy_d_log);vK=vector(r.fusion_vy_k_log);vFW=vector(r.fusion_vy_fw_log);sharedT=double(r.parallel_input_log.time(:));[sharedD,aD]=input_rows_at_hits(r.parallel_input_log.data,sharedT,tD,9);[sharedK,aK]=input_rows_at_hits(r.parallel_input_log.data,sharedT,tK,9);[sharedF,aF]=input_rows_at_hits(r.parallel_input_log.data,sharedT,tF,9);g.sharedInputs=aD.allHitsResolved&&aK.allHitsResolved&&aF.allHitsResolved&&max(abs(kU-sharedK(:,1:4)),[],'all')<=tol;
    dReplay=replay_d(sharedD,dX,dP,dDiag);kReplay=replay_k(kU,kX,kP,kDiag);fReplay=replay_f(sharedF,fVy,fP,fDiag,report);wAlpha=alpha;fwR=zeros(expectedN,1);for q=1:expectedN,fwR(q)=vy_fixed_weight_fusion_step(vD(q),vK(q),fVy(q),wAlpha(1),wAlpha(2),wAlpha(3));end;fusionReplay=struct('maxAbs',max(abs(fwR-vFW)));fusionReplay.pass=fusionReplay.maxAbs<=tol;
    g.dReplay=dReplay.pass;g.kReplay=kReplay.pass;g.fReplay=fReplay.pass;g.fusionReplay=fusionReplay.pass;
    st=steering_evidence(r,h01,duration,tFW,tol);g.steering=st.pass;
    [vyTrue,truth]=align_truth(r.vy_true_log1,tFW,duration,char(h01.truth_alignment_rule));[~,vxTruth]=align_truth(r.Vx_true_log,tFW,duration,char(h01.truth_alignment_rule));g.truth=truth.pass&&all(isfinite(vyTrue))&&all(isfinite(vxTruth));g.evaluation=all(tFW>=0&tFW<=duration)&&abs(tFW(1))<=tol&&abs(tFW(end)-duration)<=tol&&numel(tFW)==expectedN;
    g.alphaFZero=alpha(3)==0; g.noAggregate=true;
else
    ts=struct();dX=[];dP=[];dDiag=[];kU=[];kX=[];kP=[];kDiag=[];fVy=[];fP=[];fDiag=[];vD=[];vK=[];vFW=[];vyTrue=[];vxTruth=[];truth=struct('pass',false);st=struct('pass',false);dReplay=struct('pass',false);kReplay=struct('pass',false);fReplay=struct('pass',false);fusionReplay=struct('pass',false);g.commonTiming=false;g.dIntegrity=false;g.kIntegrity=false;g.fIntegrity=false;g.sharedInputs=false;g.dReplay=false;g.kReplay=false;g.fReplay=false;g.fusionReplay=false;g.steering=false;g.truth=false;g.evaluation=false;g.alphaFZero=false;g.noAggregate=true;
end
critical=logical([g.formalMatExists g.runIdExact g.roleExact g.simCalled g.runtimeCompleted g.targetHashExact g.runtimeAlphaExact g.carSimEnvironment g.requiredLogsPresent g.commonTiming g.dIntegrity g.kIntegrity g.fIntegrity g.sharedInputs g.dReplay g.kReplay g.fReplay g.fusionReplay g.steering g.truth g.evaluation g.alphaFZero g.noAggregate]);
write_gates(gateFile,g,critical); analysis=struct('stage','V2.5-I1','runId',char(runId),'phase1','INTEGRITY / ELIGIBILITY','gates',g,'gateCount',numel(critical),'gatesTrue',nnz(critical),'eligibility','INELIGIBLE');
if ~all(critical), error('V25I1A:IntegrityFailed','H01 Phase 1 integrity/eligibility failed; no performance metrics calculated.'); end
analysis.eligibility='ELIGIBLE_HOLDOUT_DATA';
% ---------------- Phase 2: frozen H01-only performance ----------------
metrics=struct();metrics.D=metric_row(vD,vyTrue);metrics.K=metric_row(vK,vyTrue);metrics.F=metric_row(fVy,vyTrue);metrics.FW=metric_row(vFW,vyTrue);best=min([metrics.D.MSE metrics.K.MSE metrics.F.MSE]);ratio=metrics.FW.MSE/best;gain=(metrics.D.MSE-metrics.FW.MSE)/metrics.D.MSE; tieTol=1e-12;if metrics.FW.MSE<best-tieTol,diagLabel='FW_BETTER';elseif abs(metrics.FW.MSE-best)<=tieTol,diagLabel='FW_TIE';else,diagLabel='FW_WORSE';end
write_metrics(metricFile,metrics,best,ratio,gain,diagLabel);record=table(string(runId),"HOLDOUT_VALIDATION",true,true,true,analysis.gatesTrue,analysis.gateCount,string(h01.formal_result_path),string(sha256(resultFile)),string(report.targetHashAfter),expectedN,ts.fusion.dtMean,st.commandMaxAbs,st.frequencyHz,metrics.D.MSE,metrics.K.MSE,metrics.F.MSE,metrics.FW.MSE,ratio,gain,"ELIGIBLE_HOLDOUT_DATA",'VariableNames',{'run_id','phase1_integrity_pass','simulation_completed','carSim_run','truth_alignment_pass','gates_true','gate_count','result_path','result_sha256','target_sha256','sample_count','mean_dt','steering_max_abs_rad','steering_frequency_Hz','MSE_D','MSE_K','MSE_F','MSE_FW','ratio_H01','gain_vs_D_H01','formal_eligibility'});writetable(record,acqFile);
analysis.phase2='PERFORMANCE';analysis.metrics=metrics;analysis.best_single_MSE_H01=best;analysis.ratio_H01=ratio;analysis.gain_vs_D_H01=gain;analysis.perRunDiagnostic=diagLabel;analysis.aggregateComputed=false;fprintf('V25I1A_ANALYSIS_OK|id=%s|eligibility=%s|gates=%d/%d|MSE_FW=%.17g|ratio=%.17g\n',runId,analysis.eligibility,analysis.gatesTrue,analysis.gateCount,metrics.FW.MSE,ratio);
end

function write_gates(file,g,vals),f=fieldnames(g);id=string(f);actual=string(cellfun(@(x)logical(g.(x)),f));pass=string(vals(:));T=table(id,actual,pass,'VariableNames',{'gate_id','actual','PASS_FAIL'});writetable(T,file);end
function m=metric_row(x,y),e=x-y;m=struct('MSE',mean(e.^2),'RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)),'Bias',mean(e),'MaxAbs',max(abs(e)));end
function write_metrics(file,m,best,ratio,gain,label),ids={'D','K','F','FW'};rows=cell(0,4);for k=1:4,n=ids{k};rows(end+1,:)={n,m.(n).MSE,m.(n).RMSE,m.(n).MAE};end;rows(end+1,:)={'best_single_MSE_H01',best,NaN,NaN};rows(end+1,:)={'ratio_H01',ratio,NaN,NaN};rows(end+1,:)={'gain_vs_D_H01',gain,NaN,NaN};rows(end+1,:)={'per_run_diagnostic',label,NaN,NaN};T=cell2table(rows,'VariableNames',{'metric_id','value','secondary','tertiary'});writetable(T,file);end
function [y,a]=align_truth(rec,tTarget,duration,rule),t=double(rec.time(:));x=double(rec.data(:));assert(all(isfinite(t))&&all(isfinite(x))&&all(diff(t)>=0),'V25I1A:Truth','Truth is invalid.');[tu,~,grp]=unique(t,'sorted');xu=accumarray(grp,x,[],@last);if all(ismember(tTarget,tu)),[~,loc]=ismember(tTarget,tu);y=xu(loc);method='DIRECT_SAME_TIMESTAMP_ALIGNMENT';else,assert(tTarget(1)>=tu(1)&&tTarget(end)<=tu(end),'V25I1A:Truth','Truth extrapolation required.');y=interp1(tu,xu,tTarget,'linear');method='LINEAR_NO_EXTRAPOLATION_NO_SHIFT';end;a=struct('method',method,'registeredRule',rule,'pass',all(isfinite(y))&&t(1)<=0&&t(end)>=duration&&strcmp(rule,'TRUTH_TO_COMMON_100HZ_GRID_LINEAR_NO_EXTRAPOLATION_NO_SHIFT'));end
function s=steering_evidence(r,h01,duration,tTarget,tol),t=double(r.steer_cmd_rad.time(:));cmd=double(r.steer_cmd_rad.data(:));deg=double(r.steer_to_carsim_deg.data(:));fl=double(r.steer_fl_carsim_deg.data(:));fr=double(r.steer_fr_carsim_deg.data(:));rl=double(r.steer_rl_carsim_deg.data(:));rr=double(r.steer_rr_carsim_deg.data(:));A=double(h01.steering_amplitude);f=double(h01.steering_frequency);expv=A*sin(2*pi*f*t);nz=abs(cmd)>tol;s=struct('commandMaxAbs',max(abs(cmd)),'frequencyHz',f,'convertedMaxAbsDeg',max(abs(deg)),'FLMaxAbsRad',max(abs(fl*pi/180)),'FRMaxAbsRad',max(abs(fr*pi/180)),'RLMaxAbsRad',max(abs(rl*pi/180)),'RRMaxAbsRad',max(abs(rr*pi/180)),'pass',max(abs(cmd-expv))<=tol&&max(abs(fl-deg))<=tol&&max(abs(fr-deg))<=tol&&max(abs(fl-fr))<=tol&&max(abs(rl))<=tol&&max(abs(rr))<=tol&&(~any(nz)||max(abs(deg(nz)./cmd(nz)-180/pi))<=1e-10));end
function o=replay_d(shared,x,p,diag),n=size(x,1);xr=zeros(n,2);pr=zeros(2,2,n);dr=zeros(n,65);u=[shared(:,4),shared(:,5:8),shared(:,2),shared(:,3)];clear vy_dynamic_ekf_v1_17;for k=1:n,y=vy_dynamic_ekf_v1_17(u(k,:).',20);xr(k,:)=y(1:2).';pr(:,:,k)=reshape(y(46:49),2,2);dr(k,:)=y(5:69).';end;o=struct('maxStateDiff',max(abs(xr-x),[],'all'),'maxPDiff',max(abs(pr-p),[],'all'),'maxDiagDiff',max(abs(dr-diag),[],'all'));o.pass=max([o.maxStateDiff o.maxPDiff o.maxDiagDiff])<=1e-12;end
function o=replay_k(u,x,p,diag),n=size(x,1);xr=zeros(n,2);pr=zeros(2,2,n);dr=zeros(n,5);clear vy_kinematic_kf;for k=1:n,[xr(k,:),pr(:,:,k),dr(k,:)]=one_k(u(k,:),k);end;o=struct('maxStateDiff',max(abs(xr-x),[],'all'),'maxPDiff',max(abs(pr-p),[],'all'),'maxDiagDiff',max(abs(dr-diag),[],'all'));o.pass=max([o.maxStateDiff o.maxPDiff o.maxDiagDiff])<=1e-12;end
function [x,p,d]=one_k(u,k),[x,p,d]=vy_kinematic_kf(u(1:3).',u(4),double(k==1));x=x(:).';d=d(:).';end
function o=replay_f(shared,vy,p,diag,report),n=numel(vy);q=report.fParameters;vr=zeros(n,1);pr=zeros(n,1);dr=zeros(n,3);vp=q.Vy_F0;pp=q.P0_F;for k=1:n,[vr(k),pr(k),dd]=vy_feedback_propagation_step(vp,pp,shared(k,2),shared(k,3),shared(k,4),q.Vy_F0,q.P0_F,0,double(k==1),q.Ts,q.Vy_F0,q.P0_F,q.Q_F);dr(k,:)=dd(:).';vp=vr(k);pp=pr(k);end;o=struct('maxVyDiff',max(abs(vr-vy)),'maxPDiff',max(abs(pr-p)),'maxDiagDiff',max(abs(dr-diag),[],'all'));o.pass=max([o.maxVyDiff o.maxPDiff o.maxDiagDiff])<=1e-12;end
function s=timing_stats(t,Ts,duration),d=diff(t);s=struct('sampleCount',numel(t),'tStart',t(1),'tEnd',t(end),'dtMin',min(d),'dtMean',mean(d),'dtMax',max(d),'duplicates',nnz(d<=0),'missingHits',sum(max(round(d/Ts)-1,0)));s.pass=numel(t)==round(duration/Ts)+1&&abs(t(1))<=1e-12&&abs(t(end)-duration)<=1e-12&&all(abs(d-Ts)<=1e-12)&&s.duplicates==0&&s.missingHits==0;end
function d=max_pair_diff(a,b),if numel(a)~=numel(b),d=Inf;else,d=max(abs(a-b));end,end
function x=vector(r),x=double(r.data(:));end
function a=sample_rows(data,n,w),a=double(data);sz=size(a);if isequal(sz,[n w]),return;elseif isequal(sz,[w n]),a=a.';return;elseif numel(a)==n*w,a=reshape(a,w,n).';return;end;error('V25I1A:Shape','Cannot resolve sample rows.');end
function p=covariance_pages(data,n,w),p=double(data);sz=size(p);if ndims(p)==3&&isequal(sz,[w w n]),return;elseif ndims(p)==3&&isequal(sz,[n w w]),p=permute(p,[2 3 1]);return;elseif ismatrix(p)&&isequal(sz,[n w*w]),p=reshape(p.',w,w,n);return;end;error('V25I1A:Covariance','Cannot resolve covariance pages.');end
function c=covariance_stats(p),n=size(p,3);as=zeros(n,1);ev=zeros(n,1);for k=1:n,A=p(:,:,k);as(k)=max(abs(A-A.'));ev(k)=min(eig((A+A')/2));end;c.maxAsymmetry=max(as);c.minEigenvalue=min(ev);c.valid=all(isfinite(p),'all')&&c.maxAsymmetry<=1e-12&&c.minEigenvalue>0;end
function [rows,ok]=input_rows_at_hits(data,ts,target,w),rows=zeros(numel(target),w);ok=struct('allHitsResolved',true);for k=1:numel(target),ix=find(abs(ts-target(k))<=1e-12);if numel(ix)~=1,ok.allHitsResolved=false;else,rows(k,:)=sample_rows(data(ix,:),1,w);end,end,end
function h=sha256(file),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(file));ds=java.io.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(b,2).',1,[]));clear c;end
