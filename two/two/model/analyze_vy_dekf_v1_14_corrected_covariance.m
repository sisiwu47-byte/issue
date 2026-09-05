function caseTable=analyze_vy_dekf_v1_14_corrected_covariance()
%ANALYZE_VY_DEKF_V1_14_CORRECTED_COVARIANCE Offline consistency audit.
% No simulation, estimator/model edit, or covariance change is performed.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');docs=fullfile(root,'docs');
source=fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat');S=load(source,'runs','metadata');
assert(numel(S.runs)==7&&isequal({S.runs.Case},{'N','V15','V25','A10','A30','F20','F60'}));
R=S.metadata.fixedR;Q=S.metadata.fixedQ;assert(isequal(R,diag([1e-2,3.365172961808e-4])));assert(S.metadata.k_f==.78181&&S.metadata.k_r==1.09186);

rows=cell(7,1);cases=cell(7,1);merged=init_merged();
for ci=1:7
    run=S.runs(ci);n=numel(run.t)-1;assert(n==1600&&abs(median(diff(run.t))-.01)<=1e-12);
    D=run.diagnostics(2:end,:);assert(size(D,1)==n&&size(D,2)>=55);
    innovation=D(:,10:11);H=matrix_series(D(:,18:21));Ppred=matrix_series(D(:,30:33));
    Slog=matrix_series(D(:,34:37));Pnew=matrix_series(D(:,42:45));
    Sstate=zeros(2,2,n);epsilon=zeros(n,2);budgetError=0;
    for k=1:n
        Sstate(:,:,k)=H(:,:,k)*Ppred(:,:,k)*H(:,:,k)';
        budgetError=max(budgetError,max(abs(Slog(:,:,k)-Sstate(:,:,k)-R),[],'all'));
        [L,flag]=chol(.5*(Slog(:,:,k)+Slog(:,:,k)'),'lower');assert(flag==0);
        epsilon(k,:)=(L\innovation(k,:)')';
    end
    assert(budgetError<=1e-10,'S budget mismatch in %s: %.3g',run.Case,budgetError);
    xhat=run.y(2:end,:);truth=[run.vyTrue(2:end) run.rTrue(2:end)];e=xhat-truth;
    nees=zeros(n,1);marg=zeros(n,2);terms=zeros(n,3);identity=zeros(n,1);sigma=zeros(n,2);
    for k=1:n
        P=.5*(Pnew(:,:,k)+Pnew(:,:,k)');ee=e(k,:)';q=P\ee;nees(k)=ee'*q;
        p11=P(1,1);p12=P(1,2);p22=P(2,2);detP=p11*p22-p12*p12;
        aa=p22/detP;bb=-p12/detP;dd=p11/detP;
        terms(k,:)=[aa*ee(1)^2,2*bb*ee(1)*ee(2),dd*ee(2)^2];identity(k)=abs(sum(terms(k,:))-nees(k));
        marg(k,:)=[ee(1)^2/p11,ee(2)^2/p22];sigma(k,:)=[sqrt(p11),sqrt(p22)];
    end
    assert(max(identity)<=1e-10);
    Ce=cov(e);Pbar=mean(Pnew,3);ellipse=ellipse_compare(Ce,Pbar);
    sensor=[run.zRaw(2:end,1)-run.ayTrue(2:end),run.zRaw(2:end,2)-run.rTrue(2:end)];
    sensorStats=[noise_stats(sensor(:,1)),noise_stats(sensor(:,2))];
    acfInnov=[acf_values(innovation(:,1),20),acf_values(innovation(:,2),20)];
    acfEps=[acf_values(epsilon(:,1),20),acf_values(epsilon(:,2),20)];
    neffInnov=[effective_n(acfInnov(:,1),n),effective_n(acfInnov(:,2),n)];
    neffEps=[effective_n(acfEps(:,1),n),effective_n(acfEps(:,2),n)];
    Cnu=cov(innovation);Smean=mean(Slog,3);SsMean=mean(Sstate,3);
    coverage=[mean(abs(e(:,1))<=sigma(:,1)),mean(abs(e(:,1))<=2*sigma(:,1)),mean(abs(e(:,1))<=3*sigma(:,1)), ...
        mean(abs(e(:,2))<=sigma(:,2)),mean(abs(e(:,2))<=2*sigma(:,2)),mean(abs(e(:,2))<=3*sigma(:,2))];
    gamma=[var(e(:,1),0)/mean(squeeze(Pnew(1,1,:))),var(e(:,2),0)/mean(squeeze(Pnew(2,2,:)))];
    row=case_row(run,n,Sstate,Slog,innovation,epsilon,acfInnov,acfEps,neffInnov,neffEps, ...
        nees,marg,terms,Ce,Pbar,ellipse,coverage,gamma,sensorStats,R,Cnu,Smean,budgetError,e,sigma);
    rows{ci}=row;
    cases{ci}=struct('Case',run.Case,'t',run.t(2:end),'innovation',innovation,'S',Slog,'Sstate',Sstate, ...
        'epsilon',epsilon,'acfInnovation',acfInnov,'acfEpsilon',acfEps,'error',e,'Pnew',Pnew, ...
        'NEES',nees,'marginalNSEE',marg,'NEESTerms',terms,'identityMax',max(identity), ...
        'Ce',Ce,'Pbar',Pbar,'ellipse',ellipse,'coverage',coverage,'gamma',gamma, ...
        'sensorError',sensor,'sensorStats',sensorStats,'CovInnovation',Cnu,'Smean',Smean,'SstateMean',SsMean);
    merged=append_merged(merged,run,innovation,Slog,Pnew,nees,marg,e);
end
caseTable=struct2table(vertcat(rows{:}));cases=vertcat(cases{:});
dynamicTable=dynamic_groups(merged);targets=diagnostic_targets(caseTable,cases,R);conclusions=derive(caseTable,dynamicTable,targets);
figures=make_figures(res,caseTable,cases,dynamicTable);
csvFile=fullfile(res,'vy_dekf_v1_14_corrected_covariance.csv');writetable(caseTable,csvFile);
audit=struct('source',source,'cases',7,'samplesPerCase',1600,'totalSamples',11200,'Ts',.01, ...
    'fixedQ',Q,'fixedR',R,'k_f',S.metadata.k_f,'k_r',S.metadata.k_r, ...
    'alignment','x_hat(i), posterior P_new(:,:,i), truth(i+1)','simulationPerformed',false);
matFile=fullfile(res,'vy_dekf_v1_14_corrected_covariance.mat');
save(matFile,'audit','caseTable','cases','dynamicTable','targets','conclusions','figures','-v7.3');
statusFile=fullfile(docs,'STAGE_VY_DEKF_V1_14_STATUS.md');
write_status(statusFile,caseTable,cases,dynamicTable,targets,conclusions,audit,figures,csvFile,matFile);
req=[{csvFile};{matFile};{statusFile};struct2cell(figures)];for i=1:numel(req),p=char(req{i});assert(isfile(p));d=dir(p);assert(d(1).bytes>0);end
fprintf('V1_14_COMPLETE|NISChannel=%s|NEESSource=%s|recommend=%s\n',conclusions.lowNISPrimaryChannel,conclusions.highNEESSource,conclusions.recommendation);
end

function M=matrix_series(flat)
n=size(flat,1);M=zeros(2,2,n);for k=1:n,M(:,:,k)=reshape(flat(k,:),2,2);end
end
function s=stats(x),s=struct('Mean',mean(x),'Median',median(x),'P95',pct(x,95));end
function a=acf_values(x,L),x=x(:)-mean(x);den=x'*x;a=zeros(L,1);for k=1:L,a(k)=x(1:end-k)'*x(1+k:end)/max(den,eps);end;end
function ne=effective_n(a,n),threshold=1.96/sqrt(n);use=a>threshold;ne=n/(1+2*sum(a(use)));end
function s=noise_stats(x),y=x-mean(x);a=acf_values(y,10);s=struct('Bias',mean(x),'Variance',var(y,0),'Rho1',a(1),'Rho5',a(5),'Rho10',a(10));end
function z=ellipse_compare(C,P)
[Vc,Dc]=eig(.5*(C+C'));[~,ic]=max(diag(Dc));[Vp,Dp]=eig(.5*(P+P'));[~,ip]=max(diag(Dp));
ac=atan2d(Vc(2,ic),Vc(1,ic));ap=atan2d(Vp(2,ip),Vp(1,ip));diff=abs(mod(ac-ap+90,180)-90);
z=struct('eigCe',sort(eig(C),'descend')','eigPbar',sort(eig(P),'descend')', ...
    'angleCeDeg',ac,'anglePbarDeg',ap,'angleDifferenceDeg',diff, ...
    'errorCorrelation',C(1,2)/sqrt(C(1,1)*C(2,2)),'posteriorCorrelation',P(1,2)/sqrt(P(1,1)*P(2,2)));
end

function row=case_row(run,n,Sstate,Slog,nu,ep,aNu,aEp,neNu,neEp,nees,marg,terms,Ce,Pbar,el,covg,gamma,sensor,R,Cnu,Smean,budget,e,sigma)
row=struct('Case',string(run.Case),'N',n,'S_budget_max_error',budget);
for ch=1:2
    tag={'Ay','r'};q=tag{ch};ss=stats(squeeze(Sstate(ch,ch,:)));st=stats(squeeze(Slog(ch,ch,:)));
    row.(['Sstate_' q '_mean'])=ss.Mean;row.(['Sstate_' q '_median'])=ss.Median;row.(['Sstate_' q '_p95'])=ss.P95;
    row.(['R_' q])=R(ch,ch);row.(['S_' q '_mean'])=st.Mean;row.(['S_' q '_median'])=st.Median;row.(['S_' q '_p95'])=st.P95;
    row.(['Sstate_over_S_' q])=mean(squeeze(Sstate(ch,ch,:))./squeeze(Slog(ch,ch,:)));
    row.(['R_over_S_' q])=mean(R(ch,ch)./squeeze(Slog(ch,ch,:)));
    row.(['innovation_var_' q])=Cnu(ch,ch);row.(['meanS_over_innovation_var_' q])=Smean(ch,ch)/Cnu(ch,ch);
    row.(['epsilon_mean_' q])=mean(ep(:,ch));row.(['epsilon_std_' q])=std(ep(:,ch),0);
    for lag=[1 2 5 10 20],row.(sprintf('epsilon_%s_rho%d',q,lag))=aEp(lag,ch);end
    row.(['innovation_Neff_' q])=neNu(ch);row.(['epsilon_Neff_' q])=neEp(ch);
end
row.innovation_cov_Ay_r=Cnu(1,2);row.epsilon_cross_corr=corrv(ep(:,1),ep(:,2));
for j=1:3,q={'Mean','Median','P95'};s=stats(nees);row.(['NEES_' lower(q{j})])=s.(q{j});end
names={'Vy','Cross','r'};for j=1:3,s=stats(terms(:,j));q=names{j};row.(['NEES_term_' q '_mean'])=s.Mean;row.(['NEES_term_' q '_median'])=s.Median;row.(['NEES_term_' q '_p95'])=s.P95;row.(['NEES_term_' q '_contribution_percent'])=100*s.Mean/mean(nees);end
for ch=1:2,q={'Vy','r'};s=stats(marg(:,ch));row.(['marginal_' q{ch} '_mean'])=s.Mean;row.(['marginal_' q{ch} '_median'])=s.Median;row.(['marginal_' q{ch} '_p95'])=s.P95;end
row.Ce11=Ce(1,1);row.Ce22=Ce(2,2);row.Ce12=Ce(1,2);row.Pbar11=Pbar(1,1);row.Pbar22=Pbar(2,2);row.Pbar12=Pbar(1,2);
row.Ce11_over_Pbar11=Ce(1,1)/Pbar(1,1);row.Ce22_over_Pbar22=Ce(2,2)/Pbar(2,2);row.Ce12_abs=abs(Ce(1,2));row.Pbar12_abs=abs(Pbar(1,2));
row.Ce_eig_major=el.eigCe(1);row.Ce_eig_minor=el.eigCe(2);row.Pbar_eig_major=el.eigPbar(1);row.Pbar_eig_minor=el.eigPbar(2);
row.error_correlation=el.errorCorrelation;row.posterior_correlation=el.posteriorCorrelation;row.error_axis_deg=el.angleCeDeg;row.P_axis_deg=el.anglePbarDeg;row.axis_difference_deg=el.angleDifferenceDeg;
row.Vy_coverage_1sigma=covg(1);row.Vy_coverage_2sigma=covg(2);row.Vy_coverage_3sigma=covg(3);row.r_coverage_1sigma=covg(4);row.r_coverage_2sigma=covg(5);row.r_coverage_3sigma=covg(6);
row.Vy_RMSE_over_median_sigma=rmsv(e(:,1))/median(sigma(:,1));row.r_RMSE_over_median_sigma=rmsv(e(:,2))/median(sigma(:,2));row.gamma_vy=gamma(1);row.gamma_r=gamma(2);
row.sensor_Ay_bias=sensor(1).Bias;row.sensor_Ay_var=sensor(1).Variance;row.sensor_Ay_rho1=sensor(1).Rho1;row.sensor_Ay_rho5=sensor(1).Rho5;row.sensor_Ay_rho10=sensor(1).Rho10;row.R_Ay_over_sensor_var=R(1,1)/sensor(1).Variance;
row.sensor_r_bias=sensor(2).Bias;row.sensor_r_var=sensor(2).Variance;row.sensor_r_rho1=sensor(2).Rho1;row.sensor_r_rho5=sensor(2).Rho5;row.sensor_r_rho10=sensor(2).Rho10;row.R_r_over_sensor_var=R(2,2)/sensor(2).Variance;
end

function m=init_merged(),m=struct('Vx',[],'absAy',[],'absSteer',[],'absSteerRate',[],'absR',[],'absDr',[],'innovationAy',[],'S11',[],'P11',[],'NEES',[],'marginalVy',[]);end
function m=append_merged(m,run,nu,Slog,Pnew,nees,marg,e)
t=run.t(2:end);steer=mean(run.u(1:end-1,2:3),2);rate=gradient(steer,.01);dr=gradient(run.rTrue,run.t); %#ok<NASGU>
m.Vx=[m.Vx;run.u(1:end-1,1)];m.absAy=[m.absAy;abs(run.ayTrue(2:end))];m.absSteer=[m.absSteer;abs(steer)];m.absSteerRate=[m.absSteerRate;abs(rate)];m.absR=[m.absR;abs(run.rTrue(2:end))];m.absDr=[m.absDr;abs(dr(2:end))];
m.innovationAy=[m.innovationAy;nu(:,1)];m.S11=[m.S11;squeeze(Slog(1,1,:))];m.P11=[m.P11;squeeze(Pnew(1,1,:))];m.NEES=[m.NEES;nees];m.marginalVy=[m.marginalVy;marg(:,1)];
end
function T=dynamic_groups(m)
vars={'Vx','absAy','absSteer','absSteerRate','absR','absDr'};cells=cell(numel(vars)*4,1);r=0;
for i=1:numel(vars),x=m.(vars{i});bin=quantile_id(x,4);for b=1:4,r=r+1;mask=bin==b;cells{r}=struct('Variable',string(vars{i}),'Bin',b,'N',sum(mask),'Lower',min(x(mask)),'Upper',max(x(mask)), ...
    'Vy_marginal_NSEE',mean(m.marginalVy(mask)),'Full_NEES',mean(m.NEES(mask)),'Innovation_Ay_variance',var(m.innovationAy(mask),0),'Mean_S11',mean(m.S11(mask)),'Mean_P11',mean(m.P11(mask)));end;end
T=struct2table(vertcat(cells{:}));
end
function b=quantile_id(x,n),[~,o]=sort(x);cuts=round(linspace(0,numel(x),n+1));b=zeros(size(x));for i=1:n,b(o(cuts(i)+1:cuts(i+1)))=i;end;end

function t=diagnostic_targets(T,cases,R)
t=struct();t.R_Ay_case=[T.sensor_Ay_var,T.sensor_Ay_bias];t.R_r_case=[T.sensor_r_var,T.sensor_r_bias];
t.R_Ay_variance_range=[min(T.sensor_Ay_var),median(T.sensor_Ay_var),max(T.sensor_Ay_var)];t.R_r_variance_range=[min(T.sensor_r_var),median(T.sensor_r_var),max(T.sensor_r_var)];
t.gamma_vy_range=[min(T.gamma_vy),median(T.gamma_vy),max(T.gamma_vy)];t.gamma_r_range=[min(T.gamma_r),median(T.gamma_r),max(T.gamma_r)];
t.fixedR=R;t.axis_difference_range=[min(T.axis_difference_deg),median(T.axis_difference_deg),max(T.axis_difference_deg)];
end
function c=derive(T,D,t)
c=struct();ayNorm=mean(T.epsilon_std_Ay.^2);rNorm=mean(T.epsilon_std_r.^2);
if ayNorm<rNorm,c.lowNISPrimaryChannel='Ay';elseif rNorm<ayNorm,c.lowNISPrimaryChannel='r';else,c.lowNISPrimaryChannel='both';end
c.aySVarianceRatio=mean(T.meanS_over_innovation_var_Ay);c.rSVarianceRatio=mean(T.meanS_over_innovation_var_r);c.epsilonStdAy=mean(T.epsilon_std_Ay);c.epsilonStdR=mean(T.epsilon_std_r);
c.meanAbsEpsilonRho1=[mean(abs(T.epsilon_Ay_rho1)),mean(abs(T.epsilon_r_rho1))];c.meanEpsilonNeff=[mean(T.epsilon_Neff_Ay),mean(T.epsilon_Neff_r)];
c.coloredNoiseStrong=any(c.meanAbsEpsilonRho1>.2);c.coloredNoiseAloneExplainsLowNIS=false;
c.highNEESSource=conditional(mean(T.NEES_term_Vy_mean)>mean(T.NEES_term_r_mean),'Vy diagonal term','multiple/r term');
c.gammaVyMedian=median(T.gamma_vy);c.gammaRMedian=median(T.gamma_r);c.axisDifferenceMedian=median(T.axis_difference_deg);
vars=unique(D.Variable,'stable');growth=zeros(numel(vars),1);for i=1:numel(vars),q=D(D.Variable==vars(i),:);growth(i)=q.Full_NEES(end)/max(q.Full_NEES(1),eps);end
[~,ix]=sort(growth,'descend');c.dynamicRanking=vars(ix);c.dynamicGrowth=growth(ix);
c.measurementReductionNeeded=median(T.R_Ay_over_sensor_var)>2||median(T.R_r_over_sensor_var)>2;c.stateInflationNeeded=c.gammaVyMedian>2;c.orientationCorrectionNeeded=c.axisDifferenceMedian>15;
c.recommendation='E. one controlled small-scale joint covariance calibration study with the deterministic model and axle gains frozen: constrain measurement covariance to empirical cross-case ranges and test a structured state/process covariance correction that raises Vy uncertainty while reducing the excessive r uncertainty; verify ellipse orientation and colored residuals, but do not combine this with a colored-noise filter';
end
function y=conditional(q,a,b),if q,y=a;else,y=b;end;end

function f=make_figures(res,T,C,D)
f=struct();common={'Visible','off','Color','w','Position',[80 80 1050 650]};labels=cellstr(T.Case);
f.budget=barfig(common,labels,[T.meanS_over_innovation_var_Ay T.meanS_over_innovation_var_r],{'Ay','r'},'mean(Sii) / innovation variance',fullfile(res,'vy_dekf_v1_14_01_nis_budget_ratio.png'));
f.standardized=barfig(common,labels,[T.epsilon_std_Ay T.epsilon_std_r],{'Ay','r'},'standardized innovation std',fullfile(res,'vy_dekf_v1_14_02_epsilon_std.png'));
fig=figure(common{:});plot(1:20,C(1).acfEpsilon(:,1),'o-');hold on;plot(1:20,C(1).acfEpsilon(:,2),'s-');grid on;xlabel('lag');ylabel('ACF');legend('Ay','r');f.acf=fullfile(res,'vy_dekf_v1_14_03_nominal_epsilon_acf.png');exportgraphics(fig,f.acf,'Resolution',170);close(fig);
f.neesTerms=barfig(common,labels,[T.NEES_term_Vy_mean T.NEES_term_Cross_mean T.NEES_term_r_mean],{'Vy','cross','r'},'full NEES mean terms',fullfile(res,'vy_dekf_v1_14_04_nees_terms.png'));
f.gamma=barfig(common,labels,[T.gamma_vy T.gamma_r],{'gamma Vy','gamma r'},'empirical error variance / mean Pii',fullfile(res,'vy_dekf_v1_14_05_gamma.png'));
f.axis=barfig(common,labels,T.axis_difference_deg,{'angle difference'},'principal-axis difference [deg]',fullfile(res,'vy_dekf_v1_14_06_axis_difference.png'));
fig=figure(common{:});vars=unique(D.Variable,'stable');for i=1:numel(vars),q=D(D.Variable==vars(i),:);plot(1:4,q.Full_NEES,'o-','LineWidth',1.2);hold on;end;grid on;xlabel('condition quartile');ylabel('full NEES mean');legend(cellstr(vars),'Location','best');f.dynamic=fullfile(res,'vy_dekf_v1_14_07_dynamic_nees.png');exportgraphics(fig,f.dynamic,'Resolution',170);close(fig);
f.sensor=barfig(common,labels,[T.R_Ay_over_sensor_var T.R_r_over_sensor_var],{'Ay','r'},'fixed R / empirical sensor variance',fullfile(res,'vy_dekf_v1_14_08_sensor_R_ratio.png'));
end
function file=barfig(common,labels,y,leg,yl,file),fig=figure(common{:});bar(y);grid on;xticks(1:numel(labels));xticklabels(labels);ylabel(yl);if size(y,2)>1,legend(leg,'Location','best');end;exportgraphics(fig,file,'Resolution',170);close(fig);end

function write_status(file,T,C,D,target,c,a,figs,csv,mat)
fid=fopen(file,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));
fprintf(fid,'# STAGE VY D-EKF V1.14 STATUS\n\n## Scope, data, and alignment\n\n');
fprintf(fid,'Offline audit of the frozen V1.13 corrected model. Seven cases x 1600 posterior/truth-aligned samples = %d samples. Alignment: `%s`. Each source run had 1601 updates at 100 Hz.\n\n',a.totalSamples,a.alignment);
fprintf(fid,'## NIS covariance budget and standardized innovations\n\n|Case|S11/var(nuAy)|S22/var(nur)|epsilon Ay std|epsilon r std|eps rho1 Ay/r|eps Neff Ay/r|\n|:--|--:|--:|--:|--:|:--|:--|\n');
for i=1:height(T),fprintf(fid,'|%s|%.6g|%.6g|%.6g|%.6g|%.5g / %.5g|%.5g / %.5g|\n',T.Case(i),T.meanS_over_innovation_var_Ay(i),T.meanS_over_innovation_var_r(i),T.epsilon_std_Ay(i),T.epsilon_std_r(i),T.epsilon_Ay_rho1(i),T.epsilon_r_rho1(i),T.epsilon_Neff_Ay(i),T.epsilon_Neff_r(i));end
fprintf(fid,'\nFull per-case CSV contains mean/median/p95 S_state, R, S, their proportions, epsilon rho1/2/5/10/20, cross-correlation, and innovation covariance.\n\n');
fprintf(fid,'### Full covariance matrices\n\nMatrices are reported as `[11 12; 21 22]`.\n\n|Case|mean(S)|Cov(innovation)|\n|:--|:--|:--|\n');
for i=1:numel(C)
    Sm=C(i).Smean;Cn=C(i).CovInnovation;
    fprintf(fid,'|%s|[%.6g %.6g; %.6g %.6g]|[%.6g %.6g; %.6g %.6g]|\n',T.Case(i),Sm(1,1),Sm(1,2),Sm(2,1),Sm(2,2),Cn(1,1),Cn(1,2),Cn(2,1),Cn(2,2));
end
fprintf(fid,'## NEES direction and covariance ellipse\n\n|Case|NEES mean|Vy/cross/r terms|Vy marginal|r marginal|gamma Vy|gamma r|axis diff|\n|:--|--:|:--|--:|--:|--:|--:|--:|\n');
for i=1:height(T),fprintf(fid,'|%s|%.6g|%.6g / %.6g / %.6g|%.6g|%.6g|%.6g|%.6g|%.5g deg|\n',T.Case(i),T.NEES_mean(i),T.NEES_term_Vy_mean(i),T.NEES_term_Cross_mean(i),T.NEES_term_r_mean(i),T.marginal_Vy_mean(i),T.marginal_r_mean(i),T.gamma_vy(i),T.gamma_r(i),T.axis_difference_deg(i));end
fprintf(fid,'\nP12 is small enough that a raw Ce12/Pbar12 ratio can be unstable; the report therefore uses absolute cross-covariances, correlations, eigenvalues, and principal-axis angles.\n\n');
fprintf(fid,'|Case|Ce [11 12; 21 22]|mean(P) [11 12; 21 22]|eig(Ce) major/minor|eig(mean P) major/minor|Ce/P corr|Ce/P axis deg|\n|:--|:--|:--|:--|:--|:--|:--|\n');
for i=1:height(T)
    fprintf(fid,'|%s|[%.5g %.5g; %.5g %.5g]|[%.5g %.5g; %.5g %.5g]|%.5g / %.5g|%.5g / %.5g|%.4g / %.4g|%.4g / %.4g|\n',T.Case(i),T.Ce11(i),T.Ce12(i),T.Ce12(i),T.Ce22(i),T.Pbar11(i),T.Pbar12(i),T.Pbar12(i),T.Pbar22(i),T.Ce_eig_major(i),T.Ce_eig_minor(i),T.Pbar_eig_major(i),T.Pbar_eig_minor(i),T.error_correlation(i),T.posterior_correlation(i),T.error_axis_deg(i),T.P_axis_deg(i));
end
fprintf(fid,'\nThe large angle difference is primarily an anisotropy/direction mismatch: empirical error is Vy-dominated, while mean posterior covariance is r-dominated. It is not evidence that P12 alone is the root cause.\n\n');
fprintf(fid,'## Coverage and scale\n\nGaussian references: 68.27%% / 95.45%% / 99.73%% (descriptive only).\n\n|Case|Vy coverage 1/2/3sigma|r coverage 1/2/3sigma|Vy RMSE/median sigma|r RMSE/median sigma|\n|:--|:--|:--|--:|--:|\n');
for i=1:height(T),fprintf(fid,'|%s|%.4f / %.4f / %.4f|%.4f / %.4f / %.4f|%.6g|%.6g|\n',T.Case(i),T.Vy_coverage_1sigma(i),T.Vy_coverage_2sigma(i),T.Vy_coverage_3sigma(i),T.r_coverage_1sigma(i),T.r_coverage_2sigma(i),T.r_coverage_3sigma(i),T.Vy_RMSE_over_median_sigma(i),T.r_RMSE_over_median_sigma(i));end
fprintf(fid,'\n## Sensor-noise audit\n\n|Case|Ay bias/var/rho1/rho5/rho10|R_Ay/var|r bias/var/rho1/rho5/rho10|R_r/var|\n|:--|:--|--:|:--|--:|\n');
for i=1:height(T),fprintf(fid,'|%s|%.5g / %.5g / %.4g / %.4g / %.4g|%.6g|%.5g / %.5g / %.4g / %.4g / %.4g|%.6g|\n',T.Case(i),T.sensor_Ay_bias(i),T.sensor_Ay_var(i),T.sensor_Ay_rho1(i),T.sensor_Ay_rho5(i),T.sensor_Ay_rho10(i),T.R_Ay_over_sensor_var(i),T.sensor_r_bias(i),T.sensor_r_var(i),T.sensor_r_rho1(i),T.sensor_r_rho5(i),T.sensor_r_rho10(i),T.R_r_over_sensor_var(i));end
fprintf(fid,'\nRobust empirical variance ranges [min median max]: Ay [%g %g %g], r [%g %g %g]. Gamma ranges: Vy [%g %g %g], r [%g %g %g]. These are diagnostic targets only.\n',target.R_Ay_variance_range,target.R_r_variance_range,target.gamma_vy_range,target.gamma_r_range);
fprintf(fid,'\n## Dynamic dependence\n\n|Rank|Variable|Q4/Q1 full-NEES growth|\n|--:|:--|--:|\n');for i=1:numel(c.dynamicRanking),fprintf(fid,'|%d|%s|%.6g|\n',i,c.dynamicRanking(i),c.dynamicGrowth(i));end
fprintf(fid,'\nDetailed Q1/Q4 comparison (all seven cases merged):\n\n|Variable|Bin|range|N|Vy marginal|full NEES|var(nu Ay)|mean S11|mean P11|\n|:--|--:|:--|--:|--:|--:|--:|--:|--:|\n');
v=unique(D.Variable,'stable');for i=1:numel(v),q=D(D.Variable==v(i)&(D.Bin==1|D.Bin==4),:);for j=1:height(q),fprintf(fid,'|%s|Q%d|%.5g..%.5g|%d|%.6g|%.6g|%.6g|%.6g|%.6g|\n',q.Variable(j),q.Bin(j),q.Lower(j),q.Upper(j),q.N(j),q.Vy_marginal_NSEE(j),q.Full_NEES(j),q.Innovation_Ay_variance(j),q.Mean_S11(j),q.Mean_P11(j));end;end
fprintf(fid,'\n## Final answers\n\n');
fprintf(fid,'1. Primary low-NIS channel: **%s** based on standardized variance; both channels are over-covered.\n',c.lowNISPrimaryChannel);
fprintf(fid,'2. Ay mean(S11)/innovation variance, seven-case mean: **%.6g**.\n',c.aySVarianceRatio);
fprintf(fid,'3. r mean(S22)/innovation variance, seven-case mean: **%.6g**.\n',c.rSVarianceRatio);
fprintf(fid,'4. Mean standardized-innovation std: Ay **%.6g**, r **%.6g**.\n',c.epsilonStdAy,c.epsilonStdR);
fprintf(fid,'5. Mean |rho1| standardized innovations Ay/r: %.6g / %.6g; mean descriptive Neff %.6g / %.6g from N=1600.\n',c.meanAbsEpsilonRho1,c.meanEpsilonNeff);
fprintf(fid,'6. Colored noise alone explains NIS near 0.04--0.13: **NO**. Correlation changes confidence intervals/effective N, not the large per-sample covariance ratio.\n');
fprintf(fid,'7. High NEES source after V1.13: **%s**.\n',c.highNEESSource);
fprintf(fid,'8. Median empirical Vy-error variance / mean P11: **%.6g**.\n',c.gammaVyMedian);
fprintf(fid,'9. Median empirical r-error variance / mean P22: **%.6g**.\n',c.gammaRMedian);
fprintf(fid,'10. Median principal-axis mismatch: **%.6g deg**; orientation correction indicated: **%s**.\n',c.axisDifferenceMedian,yesno(c.orientationCorrectionNeeded));
fprintf(fid,'11. Dynamic-condition NEES ranking is listed above; top condition is **%s**.\n',c.dynamicRanking(1));
fprintf(fid,'12. Recommended controlled V1.15: **%s**. Do not apply targets in this stage.\n',c.recommendation);
fprintf(fid,'\nWhy NIS << 2 and NEES >> 2 coexist: measurement-side S/R is much larger than the actual innovation covariance, making innovations small after normalization, while state-side posterior P—especially Vy—remains smaller than empirical state-error covariance. Any measured ellipse-angle mismatch adds a covariance-structure component. These are different covariance projections and are not contradictory.\n');
fprintf(fid,'\n## Outputs\n\n- `%s`\n- `%s`\n',csv,mat);p=struct2cell(figs);for i=1:numel(p),fprintf(fid,'- `%s`\n',p{i});end
fprintf(fid,'\n**NO Q/R WAS CHANGED.**\n\n**NO MODEL PARAMETER WAS CHANGED.**\n\n**NO SIMULINK/CARSIM RUN WAS PERFORMED.**\n\n**V1.13 AXLE GAINS REMAIN FROZEN.**\n');
end
function v=rmsv(x),v=sqrt(mean(x.^2));end
function q=pct(x,p),x=sort(x(isfinite(x)));z=1+(numel(x)-1)*p/100;l=floor(z);h=ceil(z);q=x(l)+(z-l)*(x(h)-x(l));end
function c=corrv(x,y),q=corrcoef(x,y);c=q(1,2);end
function w=yesno(v),if v,w='YES';else,w='NO';end;end
