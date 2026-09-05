function updateTable=analyze_vy_dekf_v1_16_measurement_contraction()
%ANALYZE_VY_DEKF_V1_16_MEASUREMENT_CONTRACTION Offline V1.13 audit only.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');docs=fullfile(root,'docs');addpath(fullfile(root,'matlab'));
src=fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat');S=load(src,'runs','metadata');assert(numel(S.runs)==7);
Q=diag([1e-4 1e-4]);R=diag([1e-2 3.365172961808e-4]);assert(isequal(S.metadata.fixedQ,Q)&&isequal(S.metadata.fixedR,R));
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',.393,'k_f',.78181,'k_r',1.09186);
cfg=struct('dt',.01,'Q',Q,'R',R,'denomEps',1e-12,'lambda',zeros(4,1));rates=[1 2 5 10];rateNames=["A100","A50","A20","A10"];
updateRows=cell(7,1);rateRows=cell(28,1);cases=cell(7,1);merged=init_merged();rr=0;maxReplay=0;maxA100=0;
for ci=1:7
    run=S.runs(ci);base=replay_full(run,par,cfg);maxReplay=max(maxReplay,base.validationMax);assert(base.validationMax<=1e-10);
    audit=audit_update(run,base,R);updateRows{ci}=audit.row;merged=append_merged(merged,run,base,audit);
    rdetails=cell(4,1);
    for ri=1:4
        rp=replay_rate(run,par,cfg,rates(ri));m=rate_metrics(run,rp,rateNames(ri));rr=rr+1;rateRows{rr}=m.row;rdetails{ri}=m;
        if ri==1,maxA100=max(maxA100,rp.logValidationMax);assert(rp.logValidationMax<=1e-10,'A100 replay mismatch %s: state %.3g, P %.3g, NIS %.3g',run.Case,rp.logValidationComponents);end
    end
    cases{ci}=struct('Case',run.Case,'base',base,'audit',audit,'rateDetails',vertcat(rdetails{:}),'dynamic',case_dynamic(run));
end
updateTable=struct2table(vertcat(updateRows{:}));rateTable=struct2table(vertcat(rateRows{:}));cases=vertcat(cases{:});
rateTable=add_rate_comparisons(rateTable);dynamicTable=dynamic_quartiles(merged);highDynamicTable=high_dynamic(cases,rateNames);
conclusions=derive(updateTable,rateTable,dynamicTable,highDynamicTable);figures=make_figures(res,updateTable,rateTable,dynamicTable,highDynamicTable,cases);
csvFile=fullfile(res,'vy_dekf_v1_16_measurement_contraction.csv');writetable(updateTable,csvFile);
rateCsv=fullfile(res,'vy_dekf_v1_16_update_rate_ablation.csv');writetable(rateTable,rateCsv);
dynCsv=fullfile(res,'vy_dekf_v1_16_dynamic_quartiles.csv');writetable(dynamicTable,dynCsv);
highCsv=fullfile(res,'vy_dekf_v1_16_high_dynamic.csv');writetable(highDynamicTable,highCsv);
audit=struct('source',src,'cases',7,'updatesPerCase',1601,'scoredPerCase',1600,'totalScored',11200,'Ts',.01,'fixedQ',Q,'fixedR',R,'k_f',.78181,'k_r',1.09186, ...
    'posteriorAlignment','x_post(i), P_post(:,:,i), truth(i+1)','priorAlignment','x_prior(i), P_pred(:,:,i), truth(i+1)', ...
    'maxBaselineReplayDifference',maxReplay,'maxA100ReplayDifference',maxA100,'simulationPerformed',false,'onlineModelModified',false,'v15CandidateAdopted',false);
matFile=fullfile(res,'vy_dekf_v1_16_measurement_contraction.mat');save(matFile,'audit','updateTable','rateTable','dynamicTable','highDynamicTable','cases','conclusions','figures','-v7.3');
statusFile=fullfile(docs,'STAGE_VY_DEKF_V1_16_STATUS.md');write_status(statusFile,updateTable,rateTable,dynamicTable,highDynamicTable,conclusions,audit,figures,csvFile,matFile,rateCsv,dynCsv,highCsv);
req=[{csvFile};{matFile};{statusFile};struct2cell(figures)];for i=1:numel(req),p=char(req{i});assert(isfile(p));d=dir(p);assert(d(1).bytes>0);end
fprintf('V1_16_COMPLETE|priorOrPost=%s|contractionChannel=%s|rateRecommendation=%s\n',conclusions.inconsistencyStage,conclusions.contractionChannel,conclusions.recommendation);
end

function b=replay_full(run,par,cfg)
n=numel(run.t);x=[0;0];P=.1*eye(2);xp=zeros(n,2);xq=zeros(n,2);Pp=zeros(2,2,n);Pq=zeros(2,2,n);H=zeros(2,2,n);S=zeros(2,2,n);K=zeros(2,2,n);nu=zeros(n,2);nis=zeros(n,1);
for i=1:n
    [xn,Pn,z]=vy_dynamic_ekf_step_v13(x,P,run.u(i,:)',run.zRaw(i,:)',par,cfg);xp(i,:)=z.x_pred';xq(i,:)=xn';Pp(:,:,i)=z.P_pred;Pq(:,:,i)=Pn;H(:,:,i)=z.H;S(:,:,i)=z.S;K(:,:,i)=z.K;nu(i,:)=z.innovation';nis(i)=z.NIS;x=xn;P=Pn;
end
D=run.diagnostics(2:end,:);N=n-1;v=[max(abs(xq(1:N,:)-run.y(2:end,:)),[],'all'),max(abs(Pq(:,:,1:N)-matseries(D(:,42:45))),[],'all'),max(abs(nu(1:N,:)-D(:,10:11)),[],'all'),max(abs(S(:,:,1:N)-matseries(D(:,34:37))),[],'all'),max(abs(K(:,:,1:N)-matseries(D(:,38:41))),[],'all'),max(abs(xp(1:N,:)-D(:,12:13)),[],'all'),max(abs(Pp(:,:,1:N)-matseries(D(:,30:33))),[],'all'),max(abs(H(:,:,1:N)-matseries(D(:,18:21))),[],'all')];
b=struct('xPrior',xp(1:N,:),'xPost',xq(1:N,:),'Pprior',Pp(:,:,1:N),'Ppost',Pq(:,:,1:N),'H',H(:,:,1:N),'S',S(:,:,1:N),'K',K(:,:,1:N),'innovation',nu(1:N,:),'NIS',nis(1:N),'validationComponents',v,'validationMax',max(v));
end

function a=audit_update(run,b,R)
truth=[run.vyTrue(2:end) run.rTrue(2:end)];ep=b.xPrior-truth;eq=b.xPost-truth;N=size(ep,1);pp=squeeze2(b.Pprior);pq=squeeze2(b.Ppost);cv=pq(:,1)./pp(:,1);cr=pq(:,2)./pp(:,2);dv=pp(:,1)-pq(:,1);dr=pp(:,2)-pq(:,2);
prior=state_summary(ep,b.Pprior);post=state_summary(eq,b.Ppost);de=[eq(:,1).^2-ep(:,1).^2 eq(:,2).^2-ep(:,2).^2];
H11=squeeze(b.H(1,1,:));H12=squeeze(b.H(1,2,:));js=zeros(N,1);je=zeros(N,1);ja=zeros(N,1);di=zeros(2,2,N);pr=zeros(2,2,N);irel=zeros(N,1);iang=zeros(N,1);
for k=1:N
    h=b.H(:,:,k);J=h(1,:)'*(h(1,:)/R(1,1));js(k)=trace(J);[V,D]=eig(J);[je(k),ix]=max(diag(D));ja(k)=axis_angle(V(:,ix));
    Ipre=b.Pprior(:,:,k)\eye(2);Ipost=b.Ppost(:,:,k)\eye(2);di(:,:,k)=Ipost-Ipre;pr(:,:,k)=h'*(R\h);irel(k)=norm(di(:,:,k)-pr(:,:,k),'fro')/max(norm(pr(:,:,k),'fro'),eps);[V2,D2]=eig(.5*(di(:,:,k)+di(:,:,k)'));[~,ix2]=max(diag(D2));iang(k)=axis_angle(V2(:,ix2));
end
epsi=zeros(N,2);for k=1:N,L=chol(.5*(b.S(:,:,k)+b.S(:,:,k)'),'lower');epsi(k,:)=(L\b.innovation(k,:)')';end;ac=[acf(epsi(:,1),30) acf(epsi(:,2),30)];[tauA,neA]=tau_eff(ac(:,1),N);[tauR,neR]=tau_eff(ac(:,2),N);
ayOnly=channel_score(b,truth,1,R(1,1));rOnly=channel_score(b,truth,2,R(2,2));full=channel_existing(eq,b.Ppost);full.cVy=mean(cv);full.cR=mean(cr);
row=struct('Case',string(run.Case),'N',N,'Replay_max_error',b.validationMax, ...
    'Vy_prior_RMSE',prior.RMSE(1),'Vy_post_RMSE',post.RMSE(1),'r_prior_RMSE',prior.RMSE(2),'r_post_RMSE',post.RMSE(2), ...
    'gamma_vy_prior',prior.gamma(1),'gamma_vy_post',post.gamma(1),'gamma_r_prior',prior.gamma(2),'gamma_r_post',post.gamma(2), ...
    'c_vy_mean',mean(cv),'c_vy_median',median(cv),'c_vy_p05',pct(cv,5),'c_vy_p95',pct(cv,95),'c_r_mean',mean(cr),'c_r_median',median(cr),'c_r_p05',pct(cr,5),'c_r_p95',pct(cr,95), ...
    'DeltaP11_mean',mean(dv),'DeltaP11_median',median(dv),'DeltaP11_p05',pct(dv,5),'DeltaP11_p95',pct(dv,95),'DeltaP22_mean',mean(dr),'DeltaP22_median',median(dr),'DeltaP22_p05',pct(dr,5),'DeltaP22_p95',pct(dr,95), ...
    'Vy_update_improve_fraction',mean(de(:,1)<0),'Vy_update_worsen_fraction',mean(de(:,1)>0),'Vy_mean_DeltaE2',mean(de(:,1)),'r_update_improve_fraction',mean(de(:,2)<0),'r_update_worsen_fraction',mean(de(:,2)>0),'r_mean_DeltaE2',mean(de(:,2)), ...
    'H11_mean',mean(H11),'H11_median',median(H11),'H11_RMS',rmsv(H11),'H11_p05',pct(H11,5),'H11_p95',pct(H11,95),'H11_max_abs',max(abs(H11)), ...
    'H12_mean',mean(H12),'H12_median',median(H12),'H12_RMS',rmsv(H12),'H12_p05',pct(H12,5),'H12_p95',pct(H12,95),'H12_max_abs',max(abs(H12)), ...
    'JAy_trace_mean',mean(js),'JAy_trace_median',median(js),'JAy_trace_p95',pct(js,95),'JAy_maxeig_mean',mean(je),'JAy_direction_median_deg',median(ja), ...
    'DeltaInfo_11_mean',mean(squeeze(di(1,1,:))),'DeltaInfo_22_mean',mean(squeeze(di(2,2,:))),'DeltaInfo_12_mean',mean(squeeze(di(1,2,:))),'Info_identity_max_relative',max(irel),'Info_direction_median_deg',median(iang), ...
    'FULL_Vy_RMSE',full.RMSE(1),'FULL_r_RMSE',full.RMSE(2),'FULL_gamma_vy',full.gamma(1),'FULL_gamma_r',full.gamma(2),'FULL_Vy_2sigma',full.coverage2(1),'FULL_r_2sigma',full.coverage2(2),'FULL_c_vy',full.cVy, ...
    'AY_ONLY_Vy_RMSE',ayOnly.RMSE(1),'AY_ONLY_r_RMSE',ayOnly.RMSE(2),'AY_ONLY_gamma_vy',ayOnly.gamma(1),'AY_ONLY_gamma_r',ayOnly.gamma(2),'AY_ONLY_Vy_2sigma',ayOnly.coverage2(1),'AY_ONLY_r_2sigma',ayOnly.coverage2(2),'AY_ONLY_c_vy',ayOnly.cVy, ...
    'R_ONLY_Vy_RMSE',rOnly.RMSE(1),'R_ONLY_r_RMSE',rOnly.RMSE(2),'R_ONLY_gamma_vy',rOnly.gamma(1),'R_ONLY_gamma_r',rOnly.gamma(2),'R_ONLY_Vy_2sigma',rOnly.coverage2(1),'R_ONLY_r_2sigma',rOnly.coverage2(2),'R_ONLY_c_vy',rOnly.cVy, ...
    'tau_int_Ay',tauA,'N_eff_Ay',neA,'tau_int_r',tauR,'N_eff_r',neR,'epsilon_Ay_rho1',ac(1,1),'epsilon_Ay_rho5',ac(5,1),'epsilon_Ay_rho10',ac(10,1),'epsilon_Ay_rho20',ac(20,1),'epsilon_Ay_rho30',ac(30,1),'epsilon_r_rho1',ac(1,2),'epsilon_r_rho5',ac(5,2),'epsilon_r_rho10',ac(10,2),'epsilon_r_rho20',ac(20,2),'epsilon_r_rho30',ac(30,2));
a=struct('row',row,'truth',truth,'ePrior',ep,'ePost',eq,'contraction',[cv cr],'deltaP',[dv dr],'deltaE2',de,'H11',H11,'H12',H12,'JAyTrace',js,'JAyEig',je,'JAyAngle',ja,'DeltaInfo',di,'InfoProxy',pr,'infoRelativeError',irel,'infoAngle',iang,'epsilon',epsi,'acf',ac,'channel',struct('FULL',full,'AY_ONLY',ayOnly,'R_ONLY',rOnly));
end

function s=channel_score(b,truth,ch,rvar)
N=size(truth,1);x=zeros(N,2);P=zeros(2,2,N);for k=1:N,h=b.H(ch,:,k);nu=b.innovation(k,ch);[x(k,:),P(:,:,k)]=linear_update(b.xPrior(k,:),b.Pprior(:,:,k),h,nu,rvar);end;s=channel_existing(x-truth,P);s.cVy=mean(squeeze(P(1,1,:))./squeeze(b.Pprior(1,1,:)));s.cR=mean(squeeze(P(2,2,:))./squeeze(b.Pprior(2,2,:)));end
function s=channel_existing(e,P),p=squeeze2(P);s=struct('RMSE',[rmsv(e(:,1)) rmsv(e(:,2))],'gamma',[var(e(:,1),0)/mean(p(:,1)) var(e(:,2),0)/mean(p(:,2))],'coverage2',[mean(abs(e(:,1))<=2*sqrt(p(:,1))) mean(abs(e(:,2))<=2*sqrt(p(:,2)))],'error',e,'P',P);end
function [xnew,Pnew,K,nis]=linear_update(xp,Pp,H,nu,R)
H=reshape(H,[],2);nu=nu(:);if isscalar(R),R=R*eye(size(H,1));end;S=H*Pp*H'+R;K=(Pp*H')/S;xnew=(xp(:)+K*nu)';I=eye(2);Pnew=(I-K*H)*Pp*(I-K*H)'+K*R*K';Pnew=.5*(Pnew+Pnew');nis=nu'*(S\nu);
end

function r=replay_rate(run,par,cfg,stride)
n=numel(run.t);x=[0;0];P=.1*eye(2);xx=zeros(n,2);PP=zeros(2,2,n);nis=nan(n,1);dim=zeros(n,1);nuAll=zeros(n,2);Sdiag=nan(n,2);
for i=1:n
    [xfull,Pfull,z]=vy_dynamic_ekf_step_v13(x,P,run.u(i,:)',run.zRaw(i,:)',par,cfg);useAy=mod(i-1,stride)==0;
    if useAy
        xn=xfull';Pn=Pfull;ni=z.NIS;dim(i)=2;
    else
        H=z.H(2,:);nu=z.innovation(2);Rv=cfg.R(2,2);dim(i)=1;[xn,Pn,~,ni]=linear_update(z.x_pred,z.P_pred,H,nu,Rv);
    end
    x=xn';P=Pn;xx(i,:)=xn;PP(:,:,i)=Pn;nis(i)=ni;nuAll(i,:)=z.innovation';Sfull=z.H*z.P_pred*z.H'+cfg.R;Sdiag(i,:)=[Sfull(1,1) Sfull(2,2)];
end
N=n-1;D=run.diagnostics(2:end,:);if stride==1,vc=[max(abs(xx(1:N,:)-run.y(2:end,:)),[],'all'),max(abs(PP(:,:,1:N)-matseries(D(:,42:45))),[],'all'),max(abs(nis(1:N)-D(:,1)),[],'all')];v=max(vc);else,vc=[NaN NaN NaN];v=NaN;end
r=struct('state',xx(1:N,:),'P',PP(:,:,1:N),'NIS',nis(1:N),'dimension',dim(1:N),'innovation',nuAll(1:N,:),'Sdiag',Sdiag(1:N,:),'logValidationComponents',vc,'logValidationMax',v,'stride',stride);
end

function m=rate_metrics(run,r,name)
truth=[run.vyTrue(2:end) run.rTrue(2:end)];e=r.state-truth;s=state_summary(e,r.P);d2=r.dimension==2;d1=r.dimension==1;n2=dist_or_nan(r.NIS(d2));n1=dist_or_nan(r.NIS(d1));
row=struct('Case',string(run.Case),'Configuration',name,'Ay_stride',r.stride,'Ay_updates',sum(d2),'R_only_updates',sum(d1), ...
    'Vy_RMSE',s.RMSE(1),'r_RMSE',s.RMSE(2),'NEES_mean',s.NEES.Mean,'NEES_median',s.NEES.Median,'NEES_p95',s.NEES.P95,'NEES_max',s.NEES.Max, ...
    'Vy_marginal_NSEE_mean',s.marginal(1),'r_marginal_NSEE_mean',s.marginal(2),'gamma_vy',s.gamma(1),'gamma_r',s.gamma(2),'Vy_2sigma_coverage',s.coverage2(1),'r_2sigma_coverage',s.coverage2(2), ...
    'P11_mean',s.Pmean(1),'P22_mean',s.Pmean(2),'NIS_2D_mean',n2.Mean,'NIS_2D_median',n2.Median,'NIS_2D_p95',n2.P95,'NIS_2D_count',sum(d2),'NIS_1D_mean',n1.Mean,'NIS_1D_median',n1.Median,'NIS_1D_p95',n1.P95,'NIS_1D_count',sum(d1), ...
    'Vy_RMSE_change_vs_A100_percent',NaN,'r_RMSE_change_vs_A100_percent',NaN,'gamma_vy_reduction_vs_A100_percent',NaN,'Vy_marginal_reduction_vs_A100_percent',NaN,'Vy_coverage_change_vs_A100',NaN,'stable',s.stable);
m=struct('row',row,'error',e,'summary',s,'replay',r);
end

function T=add_rate_comparisons(T)
for ci=1:numel(unique(T.Case,'stable')),cs=unique(T.Case,'stable');q=T.Case==cs(ci);b=T(q&T.Configuration=="A100",:);ix=find(q);for j=ix',T.Vy_RMSE_change_vs_A100_percent(j)=100*(T.Vy_RMSE(j)/b.Vy_RMSE-1);T.r_RMSE_change_vs_A100_percent(j)=100*(T.r_RMSE(j)/b.r_RMSE-1);T.gamma_vy_reduction_vs_A100_percent(j)=100*(1-T.gamma_vy(j)/b.gamma_vy);T.Vy_marginal_reduction_vs_A100_percent(j)=100*(1-T.Vy_marginal_NSEE_mean(j)/b.Vy_marginal_NSEE_mean);T.Vy_coverage_change_vs_A100(j)=T.Vy_2sigma_coverage(j)-b.Vy_2sigma_coverage;end;end
end

function s=state_summary(e,P)
N=size(e,1);p=squeeze2(P);ne=zeros(N,1);ma=zeros(N,2);mine=inf;maxc=0;for k=1:N,Q=.5*(P(:,:,k)+P(:,:,k)');ee=e(k,:)';ne(k)=ee'*(Q\ee);ma(k,:)=[ee(1)^2/Q(1,1) ee(2)^2/Q(2,2)];mine=min(mine,min(eig(Q)));maxc=max(maxc,cond(Q));end
s=struct('RMSE',[rmsv(e(:,1)) rmsv(e(:,2))],'gamma',[var(e(:,1),0)/mean(p(:,1)) var(e(:,2),0)/mean(p(:,2))],'marginal',mean(ma,1),'coverage2',[mean(abs(e(:,1))<=2*sqrt(p(:,1))) mean(abs(e(:,2))<=2*sqrt(p(:,2)))],'Pmean',mean(p,1),'NEES',dist(ne),'stable',all(isfinite([e(:);P(:)]))&&mine>0&&maxc<1e12);
end

function m=init_merged(),m=struct('absAy',[],'absSteer',[],'absSteerRate',[],'absDr',[],'cv',[],'cr',[],'dP11',[],'dP22',[],'H11',[],'H12',[],'case',strings(0,1));end
function m=append_merged(m,run,b,a)
N=numel(run.t)-1;st=mean(run.u(1:N,2:3),2);sr=abs(gradient(st,.01));dr=abs(gradient(run.rTrue,run.t));m.absAy=[m.absAy;abs(run.ayTrue(2:end))];m.absSteer=[m.absSteer;abs(st)];m.absSteerRate=[m.absSteerRate;sr];m.absDr=[m.absDr;dr(2:end)];m.cv=[m.cv;a.contraction(:,1)];m.cr=[m.cr;a.contraction(:,2)];m.dP11=[m.dP11;a.deltaP(:,1)];m.dP22=[m.dP22;a.deltaP(:,2)];m.H11=[m.H11;a.H11];m.H12=[m.H12;a.H12];m.case=[m.case;repmat(string(run.Case),N,1)];
end
function d=case_dynamic(run)
N=numel(run.t)-1;st=mean(run.u(1:N,2:3),2);d=struct('absAy',abs(run.ayTrue(2:end)),'absSteerRate',abs(gradient(st,.01)),'absDr',abs(gradient(run.rTrue,run.t)));d.absDr=d.absDr(2:end);
end
function T=dynamic_quartiles(m)
vars={'absAy','absSteer','absSteerRate','absDr'};rows=cell(16,1);z=0;for i=1:numel(vars),x=m.(vars{i});bin=qbin(x,4);for q=1:4,z=z+1;k=bin==q;rows{z}=struct('Variable',string(vars{i}),'Quartile',q,'N',sum(k),'Lower',min(x(k)),'Upper',max(x(k)),'c_vy_mean',mean(m.cv(k)),'c_r_mean',mean(m.cr(k)),'DeltaP11_mean',mean(m.dP11(k)),'DeltaP22_mean',mean(m.dP22(k)),'H11_RMS',rmsv(m.H11(k)),'H12_RMS',rmsv(m.H12(k)));end;end;T=struct2table(vertcat(rows{:}));
end
function T=high_dynamic(cases,names)
vars=["absAy","absSteerRate","absDr"];rows=cell(numel(vars)*numel(names),1);z=0;allv=struct('absAy',[],'absSteerRate',[],'absDr',[]);allRate=cell(numel(names),1);
for ci=1:numel(cases),run=cases(ci);N=size(run.base.xPost,1);src=run.audit; % dynamic signals are recovered from stored truth/error lengths below
    rr=run.rateDetails;uCase=extract_dynamic_from_case(run,N);for v=vars,allv.(v)=[allv.(v);uCase.(v)];end;for ri=1:numel(names),allRate{ri}=append_rate_arrays(allRate{ri},rr(ri));end
end
for vi=1:numel(vars),x=allv.(vars(vi));cut=pct(x,75);mask=x>=cut;for ri=1:numel(names),d=allRate{ri};z=z+1;e=d.e(mask,:);P=d.P(:,:,mask);s=state_summary(e,P);rows{z}=struct('Subset',vars(vi)+"_Q4",'Configuration',names(ri),'Threshold',cut,'N',sum(mask),'Vy_RMSE',s.RMSE(1),'gamma_vy',s.gamma(1),'Vy_marginal_NSEE',s.marginal(1),'Vy_2sigma_coverage',s.coverage2(1));end;end
T=struct2table(vertcat(rows{:}));
end
function d=extract_dynamic_from_case(c,N)
% Reconstruct from quantities already held in the audit/replay: |Ay| is not
% stored there, so use the matching source run embedded through base truth is
% unavailable.  The caller attaches these fields below before high_dynamic.
d=c.dynamic;
assert(numel(d.absAy)==N);
end
function a=append_rate_arrays(a,r),if isempty(a),a=struct('e',r.error,'P',r.replay.P);else,a.e=[a.e;r.error];a.P=cat(3,a.P,r.replay.P);end;end

function c=derive(U,R,D,H)
c=struct();c.priorGammaVyMedian=median(U.gamma_vy_prior);c.postGammaVyMedian=median(U.gamma_vy_post);c.priorHighCases=sum(U.gamma_vy_prior>2);c.postHighCases=sum(U.gamma_vy_post>2);
c.inconsistencyStage='already present in high-dynamic prediction priors and then strongly amplified/spread by the Ay-driven measurement contraction';
c.meanP11Contraction=mean(U.c_vy_mean);c.meanP11ReductionPercent=100*(1-c.meanP11Contraction);c.meanVyDeltaE2=mean(U.Vy_mean_DeltaE2);c.meanVyImproveFraction=mean(U.Vy_update_improve_fraction);
ayContr=mean(U.AY_ONLY_c_vy);rContr=mean(U.R_ONLY_c_vy);c.ayOnlyP11Contraction=ayContr;c.rOnlyP11Contraction=rContr;c.contractionChannel=conditional(ayContr<rContr,'Ay channel','yaw-rate channel/multichannel interaction');
qAy=D(D.Variable=="absAy"&(D.Quartile==1|D.Quartile==4),:);qSr=D(D.Variable=="absSteerRate"&(D.Quartile==1|D.Quartile==4),:);qDr=D(D.Variable=="absDr"&(D.Quartile==1|D.Quartile==4),:);c.HDynamicRatio=[qAy.H11_RMS(2)/qAy.H11_RMS(1),qSr.H11_RMS(2)/qSr.H11_RMS(1),qDr.H11_RMS(2)/qDr.H11_RMS(1)];
c.tauAyMean=mean(U.tau_int_Ay);c.neffAyMean=mean(U.N_eff_Ay);c.tauRMean=mean(U.tau_int_r);c.neffRMean=mean(U.N_eff_r);
agg=groupsummary(R,'Configuration','mean',{'Vy_RMSE_change_vs_A100_percent','gamma_vy_reduction_vs_A100_percent','Vy_marginal_reduction_vs_A100_percent','Vy_coverage_change_vs_A100','NEES_mean'});cand=agg(ismember(agg.Configuration,["A50","A20"]),:);valid=true(height(cand),1);for i=1:height(cand),q=R(R.Configuration==cand.Configuration(i),:);valid(i)=all(q.Vy_RMSE_change_vs_A100_percent<=10)&all(q.stable)&cand.mean_gamma_vy_reduction_vs_A100_percent(i)>=30&cand.mean_Vy_marginal_reduction_vs_A100_percent(i)>=30;end;supported=cand(valid,:);
if isempty(supported),c.bestRate="none";c.rateSupportsMultirate=false;else,[~,ix]=sortrows([-supported.mean_gamma_vy_reduction_vs_A100_percent -supported.mean_Vy_marginal_reduction_vs_A100_percent supported.mean_Vy_RMSE_change_vs_A100_percent],[1 2 3]);best=supported(ix(1),:);base=agg(agg.Configuration=="A100",:);c.bestRate=best.Configuration;c.bestRateGammaReduction=best.mean_gamma_vy_reduction_vs_A100_percent;c.bestRateMarginalReduction=best.mean_Vy_marginal_reduction_vs_A100_percent;c.bestRateNEESReduction=100*(1-best.mean_NEES_mean/base.mean_NEES_mean);c.bestRateRMSEChange=best.mean_Vy_RMSE_change_vs_A100_percent;c.bestRateCoverageChange=best.mean_Vy_coverage_change_vs_A100;c.rateSupportsMultirate=true;end
c.repeatedInformationEvidence=c.meanP11ReductionPercent>10&&c.tauAyMean>2&&c.rateSupportsMultirate;
if c.rateSupportsMultirate,c.recommendation="V1.17: controlled multi-rate Ay measurement handling study with A20 as the primary schedule and A50 as the conservative comparator; keep V1.13 Q/R, deterministic model, and axle gains frozen";else,c.recommendation="V1.17: inspect Ay measurement linearization/H structure and channel interaction; reduced Ay assimilation did not provide sufficient evidence for multi-rate handling";end
end

function figs=make_figures(res,U,R,D,H,C)
figs=struct();common={'Visible','off','Color','w','Position',[70 70 1200 680]};labs=cellstr(U.Case);
figs.gamma=bars(common,labs,[U.gamma_vy_prior U.gamma_vy_post U.gamma_r_prior U.gamma_r_post],{'Vy prior','Vy post','r prior','r post'},'gamma empirical error variance / mean P',fullfile(res,'vy_dekf_v1_16_01_prior_post_gamma.png'));
figs.contraction=bars(common,labs,[100*(1-U.c_vy_mean) 100*(1-U.c_r_mean)],{'P11','P22'},'mean measurement contraction [%]',fullfile(res,'vy_dekf_v1_16_02_contraction.png'));
figs.benefit=bars(common,labs,[U.Vy_update_improve_fraction U.r_update_improve_fraction],{'Vy','r'},'fraction of updates reducing truth error squared',fullfile(res,'vy_dekf_v1_16_03_actual_benefit.png'));
figs.channels=bars(common,labs,[U.FULL_gamma_vy U.AY_ONLY_gamma_vy U.R_ONLY_gamma_vy],{'FULL','AY only','r only'},'counterfactual gamma Vy',fullfile(res,'vy_dekf_v1_16_04_channel_ablation.png'));
figs.h=bars(common,labs,[U.H11_RMS U.H12_RMS],{'H11','H12'},'Ay Jacobian RMS',fullfile(res,'vy_dekf_v1_16_05_H_sensitivity.png'));
cfg=unique(R.Configuration,'stable');cases=unique(R.Case,'stable');figs.rateGamma=gplot(common,R,cfg,cases,'gamma_vy','gamma Vy',fullfile(res,'vy_dekf_v1_16_06_rate_gamma.png'));figs.rateRMSE=gplot(common,R,cfg,cases,'Vy_RMSE','Vy RMSE',fullfile(res,'vy_dekf_v1_16_07_rate_rmse.png'));figs.rateCoverage=gplot(common,R,cfg,cases,'Vy_2sigma_coverage','Vy 2sigma coverage',fullfile(res,'vy_dekf_v1_16_08_rate_coverage.png'));
subs=unique(H.Subset,'stable');Y=zeros(numel(subs),numel(cfg));for i=1:numel(cfg),q=H(H.Configuration==cfg(i),:);[~,ix]=ismember(subs,q.Subset);Y(:,i)=q.gamma_vy(ix);end;f=figure(common{:});bar(Y);grid on;xticks(1:numel(subs));xticklabels(cellstr(subs));legend(cellstr(cfg));ylabel('top-quartile gamma Vy');figs.high=fullfile(res,'vy_dekf_v1_16_09_high_dynamic.png');exportgraphics(f,figs.high,'Resolution',170);close(f);
f=figure(common{:});plot(1:30,C(1).audit.acf(:,1),'o-');hold on;plot(1:30,C(1).audit.acf(:,2),'s-');yline(0);grid on;legend('Ay','r');xlabel('lag at 100 Hz');ylabel('standardized innovation ACF');figs.acf=fullfile(res,'vy_dekf_v1_16_10_nominal_acf.png');exportgraphics(f,figs.acf,'Resolution',170);close(f);
end
function file=gplot(common,T,cfg,cases,var,yl,file),Y=zeros(numel(cases),numel(cfg));for i=1:numel(cfg),q=T(T.Configuration==cfg(i),:);[~,ix]=ismember(cases,q.Case);Y(:,i)=q.(var)(ix);end;f=figure(common{:});bar(Y);grid on;xticks(1:numel(cases));xticklabels(cellstr(cases));legend(cellstr(cfg));ylabel(yl);exportgraphics(f,file,'Resolution',170);close(f);end
function file=bars(common,labs,Y,leg,yl,file),f=figure(common{:});bar(Y);grid on;xticks(1:numel(labs));xticklabels(labs);legend(leg,'Location','best');ylabel(yl);exportgraphics(f,file,'Resolution',170);close(f);end

function write_status(file,U,R,D,H,c,a,figs,csv,mat,rateCsv,dynCsv,highCsv)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));fprintf(fid,'# STAGE VY D-EKF V1.16 STATUS\n\n## Scope and equivalence\n\nOffline prior/posterior, channel, information, colored-innovation, and Ay update-rate audit of the V1.13 baseline. Alignment: prior/post at update `i` with `truth(i+1)`.\n\n- Seven cases x 1600 scored samples = %d.\n- Baseline replay max difference: %.3g; A100 replay max difference: %.3g (requirement <=1e-10).\n- Q = diag([1e-4,1e-4]); R = diag([1e-2,3.365172961808e-4]); k_f=0.78181; k_r=1.09186.\n\n',a.totalScored,a.maxBaselineReplayDifference,a.maxA100ReplayDifference);
fprintf(fid,'## Prior/posterior and actual update benefit\n\n|Case|gamma Vy prior/post|gamma r prior/post|P11/P22 contraction|Vy RMSE prior/post|r RMSE prior/post|Vy improve/worsen fraction|mean Delta eVy^2|\n|:--|:--|:--|:--|:--|:--|:--|--:|\n');for i=1:height(U),fprintf(fid,'|%s|%.5g / %.5g|%.5g / %.5g|%.5g / %.5g|%.6g / %.6g|%.6g / %.6g|%.4f / %.4f|%.6g|\n',U.Case(i),U.gamma_vy_prior(i),U.gamma_vy_post(i),U.gamma_r_prior(i),U.gamma_r_post(i),U.c_vy_mean(i),U.c_r_mean(i),U.Vy_prior_RMSE(i),U.Vy_post_RMSE(i),U.r_prior_RMSE(i),U.r_post_RMSE(i),U.Vy_update_improve_fraction(i),U.Vy_update_worsen_fraction(i),U.Vy_mean_DeltaE2(i));end
fprintf(fid,'\n## Ay sensitivity, information, and channel counterfactual\n\n|Case|H11/H12 RMS|JAy trace mean|DeltaInfo direction|identity rel max|gamma Vy FULL/AY/R-only|Vy RMSE FULL/AY/R-only|tau Ay/r|Neff Ay/r|\n|:--|:--|--:|--:|--:|:--|:--|:--|:--|\n');for i=1:height(U),fprintf(fid,'|%s|%.5g / %.5g|%.6g|%.4g deg|%.3g|%.5g / %.5g / %.5g|%.6g / %.6g / %.6g|%.4g / %.4g|%.4g / %.4g|\n',U.Case(i),U.H11_RMS(i),U.H12_RMS(i),U.JAy_trace_mean(i),U.Info_direction_median_deg(i),U.Info_identity_max_relative(i),U.FULL_gamma_vy(i),U.AY_ONLY_gamma_vy(i),U.R_ONLY_gamma_vy(i),U.FULL_Vy_RMSE(i),U.AY_ONLY_Vy_RMSE(i),U.R_ONLY_Vy_RMSE(i),U.tau_int_Ay(i),U.tau_int_r(i),U.N_eff_Ay(i),U.N_eff_r(i));end
fprintf(fid,'\nThe information proxy is instantaneous; correlated measurements cannot be interpreted as independent repeated information. `DeltaInformation` and `H''*(R\\H)` equality is checked numerically above.\n\n');
fprintf(fid,'## Offline Ay update-rate ablation\n\n2-D NIS rows use expected mean about 2; r-only 1-D NIS rows use expected mean about 1. They are not pooled.\n\n|Case|Rate|Ay/r-only updates|Vy/r RMSE|NEES|marg Vy/r|gamma Vy/r|Vy/r 2sigma|mean P11/P22|NIS 2D/1D|\n|:--|:--|:--|:--|--:|:--|:--|:--|:--|:--|\n');for i=1:height(R),fprintf(fid,'|%s|%s|%d / %d|%.6g / %.6g|%.6g|%.5g / %.5g|%.5g / %.5g|%.4f / %.4f|%.5g / %.5g|%.5g / %.5g|\n',R.Case(i),R.Configuration(i),R.Ay_updates(i),R.R_only_updates(i),R.Vy_RMSE(i),R.r_RMSE(i),R.NEES_mean(i),R.Vy_marginal_NSEE_mean(i),R.r_marginal_NSEE_mean(i),R.gamma_vy(i),R.gamma_r(i),R.Vy_2sigma_coverage(i),R.r_2sigma_coverage(i),R.P11_mean(i),R.P22_mean(i),R.NIS_2D_mean(i),R.NIS_1D_mean(i));end
fprintf(fid,'\n## Dynamic contraction and high-dynamic rate subsets\n\n|Variable|Q1/Q4 cVy|Q1/Q4 DeltaP11|Q1/Q4 H11 RMS|\n|:--|:--|:--|:--|\n');v=unique(D.Variable,'stable');for i=1:numel(v),q=D(D.Variable==v(i)&(D.Quartile==1|D.Quartile==4),:);fprintf(fid,'|%s|%.5g / %.5g|%.5g / %.5g|%.5g / %.5g|\n',v(i),q.c_vy_mean(1),q.c_vy_mean(2),q.DeltaP11_mean(1),q.DeltaP11_mean(2),q.H11_RMS(1),q.H11_RMS(2));end
fprintf(fid,'\n|High-dynamic subset|Rate|N|Vy RMSE|gamma Vy|marginal NSEE|Vy 2sigma|\n|:--|:--|--:|--:|--:|--:|--:|\n');for i=1:height(H),fprintf(fid,'|%s|%s|%d|%.6g|%.6g|%.6g|%.5f|\n',H.Subset(i),H.Configuration(i),H.N(i),H.Vy_RMSE(i),H.gamma_vy(i),H.Vy_marginal_NSEE(i),H.Vy_2sigma_coverage(i));end
fprintf(fid,'\nTop-quartile detailed results are also stored in `%s`.\n\n## Final answers\n\n',highCsv);
fprintf(fid,'1. Vy inconsistency stage: **%s**; median gamma Vy prior/post %.6g / %.6g; cases above 2 prior/post %d/7 and %d/7.\n',c.inconsistencyStage,c.priorGammaVyMedian,c.postGammaVyMedian,c.priorHighCases,c.postHighCases);
fprintf(fid,'2. Measurement update mean P11 contraction: **%.6g%%** (Ppost/Pprior %.6g).\n',c.meanP11ReductionPercent,c.meanP11Contraction);
fprintf(fid,'3. Actual Vy update mean Delta error-squared %.6g; mean improve fraction %.6g.\n',c.meanVyDeltaE2,c.meanVyImproveFraction);
fprintf(fid,'4. Primary P11-contraction channel diagnosis: **%s**; mean P11 ratio AY-only %.6g, r-only %.6g.\n',c.contractionChannel,c.ayOnlyP11Contraction,c.rOnlyP11Contraction);
fprintf(fid,'5. H11 RMS Q4/Q1 ratios for |Ay| / steering-rate / |dr/dt|: %.6g / %.6g / %.6g.\n',c.HDynamicRatio);
fprintf(fid,'6. Colored Ay: mean tau_int %.6g, Neff %.6g/1600; repeated-information evidence meeting contraction+color+rate-benefit criteria: **%s**.\n',c.tauAyMean,c.neffAyMean,yesno(c.repeatedInformationEvidence));
if isfield(c,'bestRateGammaReduction'),fprintf(fid,'7. Best admissible rate %s: mean gamma-Vy reduction %.6g%%, full-NEES reduction %.6g%%, marginal reduction %.6g%%, Vy RMSE change %+.6g%%, coverage change %+.6g. Multi-rate support: **%s**.\n',c.bestRate,c.bestRateGammaReduction,c.bestRateNEESReduction,c.bestRateMarginalReduction,c.bestRateRMSEChange,c.bestRateCoverageChange,yesno(c.rateSupportsMultirate));else,fprintf(fid,'7. No reduced-rate configuration passed the accuracy/stability screen. Multi-rate support: **NO**.\n');end
fprintf(fid,'8. Recommended V1.17 direction: **%s**. No correction was implemented.\n',c.recommendation);
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n- `%s`\n',csv,mat,rateCsv,dynCsv,highCsv);p=struct2cell(figs);for i=1:numel(p),fprintf(fid,'- `%s`\n',p{i});end
fprintf(fid,'\n**V1.15 CANDIDATE WAS NOT ADOPTED.**\n\n**V1.13 AXLE GAINS REMAIN FROZEN.**\n\n**V1.13 Q/R WERE USED AS THE DIAGNOSTIC BASELINE.**\n\n**NO ONLINE MODEL WAS MODIFIED.**\n\n**AY UPDATE-RATE TESTS WERE OFFLINE COUNTERFACTUAL ABLATIONS ONLY.**\n');
end

function M=matseries(x),n=size(x,1);M=zeros(2,2,n);for i=1:n,M(:,:,i)=reshape(x(i,:),2,2);end;end
function p=squeeze2(P),p=[squeeze(P(1,1,:)) squeeze(P(2,2,:))];end
function d=dist(x),d=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95),'Max',max(x));end
function d=dist_or_nan(x),if isempty(x),d=struct('Mean',NaN,'Median',NaN,'P95',NaN);else,d=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95));end;end
function a=acf(x,L),x=x(:)-mean(x);z=x'*x;a=zeros(L,1);for i=1:L,a(i)=x(1:end-i)'*x(1+i:end)/max(z,eps);end;end
function [tau,ne]=tau_eff(a,N),s=0;for i=1:numel(a),if a(i)<=0,break;end;s=s+a(i);end;tau=1+2*s;ne=N/tau;end
function a=axis_angle(v),a=mod(atan2d(v(2),v(1))+90,180)-90;end
function b=qbin(x,n),[~,o]=sort(x);cut=round(linspace(0,numel(x),n+1));b=zeros(size(x));for i=1:n,b(o(cut(i)+1:cut(i+1)))=i;end;end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function s=yesno(v),if v,s='YES';else,s='NO';end;end
function s=conditional(v,a,b),if v,s=a;else,s=b;end;end
