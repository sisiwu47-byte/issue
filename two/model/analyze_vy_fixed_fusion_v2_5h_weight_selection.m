function out = analyze_vy_fixed_fusion_v2_5h_weight_selection()
% V2.5-H offline constrained-QP weight solve and identifiability analysis.
% The manifest is the sole data index; no Simulink/runtime action occurs here.
root=fileparts(fileparts(mfilename('fullpath')));
manifest=fullfile(root,'results','vy_fixed_fusion_v2_5g2_calibration_acquisition_manifest.csv');
manifestExpected='8A66D5C90EE7461920323E2376D23D737C3D3ADBCB269AE2B9535F8872C67275';
assert(strcmpi(sha256_file(manifest),manifestExpected),'V25H:ManifestHash','Calibration manifest hash mismatch.');
rows=readtable(manifest,'TextType','string');
ids=["FWCAL_C01R1";"FWCAL_C02";"FWCAL_C03";"FWCAL_C04";"FWCAL_C05"];
assert(height(rows)==5 && all(string(rows.run_id)==ids),'V25H:ManifestRows','Manifest must contain exactly the five registered rows in order.');
assert(all(string(rows.role)=="CALIBRATION_ONLY") && all(string(rows.formal_calibration_eligibility)=="ELIGIBLE"),'V25H:Eligibility','Manifest eligibility/role mismatch.');
M=height(rows); data=cell(M,1); runIds=cellstr(ids);
for j=1:M
    p=char(rows.result_path(j)); assert(isfile(p),'V25H:ResultMissing','Missing registered result: %s',p);
    h=sha256_file(p); assert(strcmpi(h,char(rows.result_sha256(j))),'V25H:ResultHash','Result hash mismatch: %s',p);
    d=dir(p); assert(d.bytes==rows.result_size(j),'V25H:ResultSize','Result size mismatch: %s',p);
    S=load(p,'dataset'); assert(isfield(S,'dataset'),'V25H:Dataset','dataset missing: %s',p); q=S.dataset;
    assert(string(q.run_id)==ids(j) && string(q.role)=="CALIBRATION_ONLY",'V25H:DatasetMeta','Dataset metadata mismatch: %s',p);
    assert(isfield(q,'formalCalibrationEligibility')&&q.formalCalibrationEligibility,'V25H:DatasetEligible','Dataset not eligible: %s',p);
    assert(isfield(q,'truthAlignment')&&contains(string(q.truthAlignment.mode),"DIRECT_SAME_TIMESTAMP_ALIGNMENT"),'V25H:Truth','Truth alignment is not the recorded PASS mode.');
    assert(isfield(q,'evaluationWindow'),'V25H:Window','Evaluation metadata missing.');
    v=[q.Vy_D(:),q.Vy_K(:),q.Vy_F(:),q.Vy_true(:)]; t=q.timestamps.fusion(:);
    assert(size(v,1)==rows.sample_count(j)&&all(isfinite(v),'all')&&all(isfinite(t)),'V25H:Data','Finite/sample integrity failed for %s',p);
    assert(all(diff(t)>0),'V25H:Time','Non-increasing timestamps for %s',p);
    data{j}=struct('id',char(ids(j)),'A',v(:,1:3),'y',v(:,4),'t',t,'N',size(v,1), ...
        'truthAlignment',char(q.truthAlignment.mode),'evaluationWindow',q.evaluationWindow);
end
% Equal maneuver weighting, retaining each maneuver's 1/N normalization.
H=zeros(3); f=zeros(3,1); const=0;
for j=1:M
    [hj,fj,cj]=qp_terms(data{j}); H=H+hj/M; f=f+fj/M; const=const+cj/M;
end
H=(H+H')/2; Aeq=ones(1,3); beq=1; lb=zeros(3,1); ub=[];
[alphaFull,solverFull]=solve_qp(H,f,Aeq,beq,lb,ub);
objectiveFull=mean(cellfun(@(d)mean((d.A*alphaFull-d.y).^2),data));
rankTolerance=max(size(reduced_stack(data)))*eps(max(svd(reduced_stack(data))));
X=reduced_stack(data); [~,sv,~]=svd(X,'econ'); sing=diag(sv); rankX=sum(sing>rankTolerance);
Hr=reduced_hessian(data); Hr=(Hr+Hr')/2; sr=eig(Hr); condX=cond(X); condHr=cond(Hr);
% KKT evidence (lower-bound form alpha>=0).
[kkt,active]=kkt_evidence(H,f,alphaFull,Aeq,beq,lb);
% Five whole-maneuver LOO solutions.
loo=repmat(struct('leftOut','','alpha_D',NaN,'alpha_K',NaN,'alpha_F',NaN,'objective',NaN,'active_constraints','','solver_status',''),M,1);
for j=1:M
    keep=setdiff(1:M,j); [hL,fL]=terms_subset(data,keep); [aL,sL]=solve_qp(hL,fL,Aeq,beq,lb,ub);
    loo(j)=struct('leftOut',data{j}.id,'alpha_D',aL(1),'alpha_K',aL(2),'alpha_F',aL(3), ...
        'objective',mean(cellfun(@(d)mean((d.A*aL-d.y).^2),data(keep))), ...
        'active_constraints',active_text(aL),'solver_status',sL.status);
end
looMat=[[loo.alpha_D]' [loo.alpha_K]' [loo.alpha_F]']; delta=looMat-alphaFull(:)';
looL1=sum(abs(delta),2); looL2=sqrt(sum(delta.^2,2)); looMax=max(abs(delta),[],2);
% Deterministic whole-maneuver bootstrap (1000 resamples with replacement).
rng(20260829,'twister'); B=1000; boot=zeros(B,3); bootObj=zeros(B,1); bootActive=zeros(B,1);
for b=1:B
    draw=randi(M,1,M); [hb,fb]=terms_subset(data,draw); [ab,~]=solve_qp(hb,fb,Aeq,beq,lb,ub); boot(b,:)=ab(:)';
    bootObj(b)=mean(cellfun(@(d)mean((d.A*ab-d.y).^2),data(draw))); bootActive(b)=sum(ab<=1e-10)>0;
end
metrics=repmat(struct('run_id','','RMSE_D',NaN,'RMSE_K',NaN,'RMSE_F',NaN,'RMSE_FW',NaN,'MAE_FW',NaN,'Bias_FW',NaN,'MaxAbs_FW',NaN,'MSE_FW',NaN),M,1);
for j=1:M
    d=data{j}; e=[d.A(:,1)-d.y,d.A(:,2)-d.y,d.A(:,3)-d.y,d.A*alphaFull-d.y];
    metrics(j)=struct('run_id',d.id,'RMSE_D',sqrt(mean(e(:,1).^2)),'RMSE_K',sqrt(mean(e(:,2).^2)), ...
      'RMSE_F',sqrt(mean(e(:,3).^2)),'RMSE_FW',sqrt(mean(e(:,4).^2)),'MAE_FW',mean(abs(e(:,4))), ...
      'Bias_FW',mean(e(:,4)),'MaxAbs_FW',max(abs(e(:,4))),'MSE_FW',mean(e(:,4).^2));
end
% Simplex diagnostic map (diagnostic only, not the solver).
grid=(0:0.01:1)'; simplex=[]; for i=1:numel(grid), for k=1:numel(grid)-i+1, a=[grid(i);grid(k);1-grid(i)-grid(k)]; simplex=[simplex; a' objective_at(data,a)]; end,end %#ok<AGROW>
% Classification uses explicit, predeclared numerical criteria; no regularization.
maxLoo=max(looMax); bootStd=std(boot,0,1); bootCI=prctile(boot,[2.5 97.5]);
conditioningAcceptable=isfinite(condX)&&isfinite(condHr)&&condX<=1e8&&condHr<=1e8;
looAcceptable=maxLoo<=0.25; bootstrapAcceptable=all(bootStd<=0.25);
stable=(rankX==2)&&conditioningAcceptable&&looAcceptable&&bootstrapAcceptable&&kkt.pass&&solverFull.exitflag>0;
if stable, classification='IDENTIFIABLE_AND_STABLE'; freezeEligibility='ELIGIBLE'; alphaStatus='SELECTED_FIXED_WEIGHT_CANDIDATE';
elseif rankX<2, classification='RANK_DEFICIENT_OR_NONUNIQUE'; freezeEligibility='BLOCKED'; alphaStatus='CANDIDATE_ONLY';
elseif ~conditioningAcceptable, classification='ILL_CONDITIONED'; freezeEligibility='BLOCKED'; alphaStatus='CANDIDATE_ONLY';
else, classification='IDENTIFIABLE_BUT_SENSITIVE'; freezeEligibility='BLOCKED'; alphaStatus='CANDIDATE_ONLY'; end
solver=solverFull; solver.objective=objectiveFull; solver.constant=const; solver.constraintResidual=sum(alphaFull)-1; solver.minAlpha=min(alphaFull); solver.iterations=solverFull.iterations;
out=struct('manifest_path',manifest,'manifest_sha256',manifestExpected,'run_ids',{runIds},'M',M,'H',H,'f',f,'Aeq',Aeq,'beq',beq,'lb',lb,'ub',ub, ...
 'alpha_full',alphaFull,'objective_full',objectiveFull,'solver',solver,'kkt',kkt,'rank',rankX,'rank_tolerance',rankTolerance, ...
 'singular_values',sing,'sigma_min',min(sing),'sigma_max',max(sing),'cond_X',condX,'reduced_hessian',Hr,'cond_reduced_hessian',condHr, ...
 'loo',loo,'loo_delta',delta,'loo_L1',looL1,'loo_L2',looL2,'loo_max_abs',looMax,'bootstrap_alpha',boot,'bootstrap_objective',bootObj, ...
 'bootstrap_median',median(boot,1),'bootstrap_mean',mean(boot,1),'bootstrap_std',bootStd,'bootstrap_ci_2p5_97p5',bootCI, ...
 'bootstrap_zero_weight_frequency',mean(boot<=1e-10,1),'bootstrap_boundary_hit_frequency',mean(bootActive), ...
 'per_maneuver_metrics',metrics,'simplex_diagnostic',simplex,'classification',classification,'weight_freeze_eligibility',freezeEligibility, ...
 'alpha_status',alphaStatus,'active_zero_constraints',active,'condition_acceptance',conditioningAcceptable,'loo_acceptance',looAcceptable,'bootstrap_acceptance',bootstrapAcceptable);
save(fullfile(root,'results','vy_fixed_fusion_v2_5h_weight_selection.mat'),'-struct','out','-v7.3');
write_qp_csv(root,out); write_loo_csv(root,out); write_boot_csv(root,out); write_metrics_csv(root,out); write_ident_csv(root,out); write_simplex_csv(root,simplex);
end

function [h,f,c]=qp_terms(d), n=d.N; h=2*(d.A'*d.A)/n; f=-2*(d.A'*d.y)/n; c=(d.y'*d.y)/n; end
function [h,f]=terms_subset(data,idx), h=zeros(3);f=zeros(3,1); for q=idx,[hj,fj]=qp_terms(data{q});h=h+hj/numel(idx);f=f+fj/numel(idx);end,h=(h+h')/2;end
function X=reduced_stack(data), X=[];for j=1:numel(data),d=data{j};X=[X;(d.A(:,1:2)-d.A(:,3))]/sqrt(d.N*numel(data));end,end
function H=reduced_hessian(data), H=zeros(2);M=numel(data);for j=1:M,d=data{j};x=d.A(:,1:2)-d.A(:,3);H=H+2*(x'*x)/d.N/M;end,end
function [a,s]=solve_qp(H,f,Aeq,beq,lb,ub)
if exist('quadprog','file')==2
  opts=optimoptions('quadprog','Display','off','Algorithm','interior-point-convex','MaxIterations',1000,'OptimalityTolerance',1e-12,'ConstraintTolerance',1e-12);
  [a,~,ef,qpout,~]=quadprog(H,f,[],[],Aeq,beq,lb,ub,[],opts); s=struct('solver','quadprog','algorithm','interior-point-convex','exitflag',ef,'iterations',getfield_default(qpout,'iterations',NaN),'status',status_text(ef));
else
  best=Inf;a=[NaN;NaN;NaN]; for i=0:200,for j=0:200-i,x=[i;j;200-i]/200;q=0.5*x'*H*x+f'*x;if q<best,best=q;a=x;end,end,end;s=struct('solver','deterministic_simplex_grid_fallback','algorithm','enumerated simplex','exitflag',1,'iterations',40401,'status','optimal_grid_fallback');
end
end
function [k,active]=kkt_evidence(H,f,a,Aeq,beq,lb), free=find(a>1e-9); g=H*a+f; lam=-(Aeq(free)*Aeq(free)')\(Aeq(free)*g(free)); stat=g+Aeq'*lam; mu=stat; active=active_text(a); k=struct('equalityResidual',Aeq*a-beq,'minAlpha',min(a),'stationarityResidualFree',max(abs(stat(free))), 'activeLowerMultipliers',mu(a<=1e-9),'complementarityResidual',max(abs(mu(a<=1e-9).*a(a<=1e-9))), 'pass',abs(Aeq*a-beq)<=1e-9&&min(a)>=-1e-9&&max(abs(stat(free)))<=1e-7&&all(mu(a<=1e-9)>=-1e-7));end
function t=active_text(a), z=find(a<=1e-9);if isempty(z),t='NONE';else,names={'alpha_D','alpha_K','alpha_F'};t=strjoin(names(z),';');end,end
function y=objective_at(data,a), y=mean(cellfun(@(d)mean((d.A*a-d.y).^2),data));end
function t=status_text(ef),if ef>0,t='optimal';elseif ef==0,t='iteration_limit';else,t='failed';end,end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
function h=sha256_file(file),d=java.security.MessageDigest.getInstance('SHA-256');fid=fopen(file,'rb');assert(fid>0,'V25H:HashIO','Cannot open file for hashing: %s',file);c=onCleanup(@()fclose(fid));b=fread(fid,Inf,'*uint8')';d.update(b);z=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(z,2).',1,[]));end
function write_qp_csv(root,o), T=table(o.alpha_full(1),o.alpha_full(2),o.alpha_full(3),o.alpha_full(1)+o.alpha_full(2)+o.alpha_full(3),o.objective_full,o.solver.exitflag,string(o.solver.status),o.kkt.equalityResidual,o.kkt.stationarityResidualFree,o.kkt.pass,'VariableNames',{'alpha_D','alpha_K','alpha_F','sum_alpha','objective','exitflag','solver_status','equality_residual','stationarity_residual_free','kkt_pass'});writetable(T,fullfile(root,'results','vy_fixed_fusion_v2_5h_qp_solution.csv'));end
function write_loo_csv(root,o), T=table(string({o.loo.leftOut}'),[o.loo.alpha_D]',[o.loo.alpha_K]',[o.loo.alpha_F]',[o.loo.objective]',o.loo_L1,o.loo_L2,o.loo_max_abs,string({o.loo.active_constraints}'),string({o.loo.solver_status}'),'VariableNames',{'left_out','alpha_D','alpha_K','alpha_F','objective','delta_L1','delta_L2','delta_max_abs','active_constraints','solver_status'});writetable(T,fullfile(root,'results','vy_fixed_fusion_v2_5h_loo_sensitivity.csv'));end
function write_boot_csv(root,o), T=table((1:size(o.bootstrap_alpha,1))',o.bootstrap_alpha(:,1),o.bootstrap_alpha(:,2),o.bootstrap_alpha(:,3),o.bootstrap_objective,'VariableNames',{'replicate','alpha_D','alpha_K','alpha_F','objective'});writetable(T,fullfile(root,'results','vy_fixed_fusion_v2_5h_maneuver_bootstrap.csv'));end
function write_metrics_csv(root,o),m=o.per_maneuver_metrics;T=table(string({m.run_id}'),[m.RMSE_D]',[m.RMSE_K]',[m.RMSE_F]',[m.RMSE_FW]',[m.MAE_FW]',[m.Bias_FW]',[m.MaxAbs_FW]','VariableNames',{'run_id','RMSE_D','RMSE_K','RMSE_F','RMSE_FW','MAE_FW','Bias_FW','MaxAbs_FW'});writetable(T,fullfile(root,'results','vy_fixed_fusion_v2_5h_per_maneuver_metrics.csv'));end
function write_ident_csv(root,o),names={'manifest_hash';'rank';'rank_tolerance';'sigma_min';'sigma_max';'cond_X';'cond_reduced_hessian';'classification';'weight_freeze_eligibility';'alpha_status';'bootstrap_std_D';'bootstrap_std_K';'bootstrap_std_F';'max_loo_component_shift'};vals={o.manifest_sha256;o.rank;o.rank_tolerance;o.sigma_min;o.sigma_max;o.cond_X;o.cond_reduced_hessian;o.classification;o.weight_freeze_eligibility;o.alpha_status;o.bootstrap_std(1);o.bootstrap_std(2);o.bootstrap_std(3);max(o.loo_max_abs)};fid=fopen(fullfile(root,'results','vy_fixed_fusion_v2_5h_identifiability.csv'),'w');fprintf(fid,'metric,value\n');for i=1:numel(names),if isnumeric(vals{i}),fprintf(fid,'%s,%.17g\n',names{i},vals{i});else,fprintf(fid,'%s,%s\n',names{i},char(string(vals{i})));end,end;fclose(fid);end
function write_simplex_csv(root,s),writematrix(s,fullfile(root,'results','vy_fixed_fusion_v2_5h_simplex_diagnostic.csv'));end
