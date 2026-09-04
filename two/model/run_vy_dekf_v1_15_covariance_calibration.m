function run_vy_dekf_v1_15_covariance_calibration()
%RUN_VY_DEKF_V1_15_COVARIANCE_CALIBRATION Fixed 9-point Q/R calibration.
% The first screen is exactly 9 configurations x 4 cases.  At most two
% Pareto candidates then join C0 in a new full seven-case validation.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');
addpath(fullfile(root,'matlab'));
v14=load(fullfile(res,'vy_dekf_v1_14_corrected_covariance.mat'),'caseTable');
[anchors,configs]=make_configs(v14.caseTable);print_anchors(anchors);
defs=[mk('N',20,.02,.4);mk('V15',15,.02,.4);mk('V25',25,.02,.4); ...
    mk('A10',20,.01,.4);mk('A30',20,.03,.4);mk('F20',20,.02,.2);mk('F60',20,.02,.6)];
calNames={'N','V25','A30','F60'};calDefs=defs(ismember({defs.Case},calNames));
unit=wrapper_equivalence(configs(1));assert(unit.maxOutputDifference<=1e-12);
[modelFile,buildAudit]=build_model(root,res);source13=load(fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat'),'runs','metadata');

old=pwd;cd(fileparts(modelFile));folderClean=onCleanup(@()cd(old));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(res,'simulink_cache_vy_v1_15'), ...
    'CodeGenFolder',fullfile(res,'simulink_codegen_vy_v1_15'),'createDir',true);
load_system('simulink');load_system('Solver_SF');load_system(modelFile);[~,mdl]=fileparts(modelFile);
modelClean=onCleanup(@()close_models(mdl));wks=get_param(mdl,'ModelWorkspace');

calibrationRuns=repmat(empty_run(),numel(configs)*numel(calDefs),1);nrun=0;
for ci=1:numel(configs)
    for di=1:numel(calDefs)
        nrun=nrun+1;calibrationRuns(nrun)=simulate_one(mdl,wks,configs(ci),calDefs(di));
        fprintf('V1_15_CAL_PROGRESS|%d/%d|%s|%s\n',nrun,numel(calibrationRuns),configs(ci).Name,calDefs(di).Case);
    end
end
calibrationInputMax=check_same_vehicle(calibrationRuns,configs,calDefs);
[baselineArchiveMax,baselineOutputMax]=check_against_v13(calibrationRuns(strcmp({calibrationRuns.Configuration},'C0')),source13.runs);
calFile=fullfile(res,'vy_dekf_v1_15_calibration_runs.mat');
metadata=struct('stage','V1.15','anchors',anchors,'configs',configs,'calibrationCases',{calNames}, ...
    'unit',unit,'buildAudit',buildAudit,'calibrationInputMax',calibrationInputMax, ...
    'baselineArchiveMax',baselineArchiveMax,'baselineOutputMax',baselineOutputMax,'updatesPerRun',1601,'Ts',.01);
save(calFile,'calibrationRuns','metadata','-v7.3');

[selectedNames,screenTable,paretoTable]=analyze_vy_dekf_v1_15_covariance_calibration('select',calFile);
assert(numel(selectedNames)<=2&&~isempty(selectedNames));
fullNames=["C0";selectedNames(:)];fullConfigs=configs(ismember(string({configs.Name}),fullNames));
% Preserve requested order: C0 followed by selected Pareto candidates.
[~,ord]=ismember(fullNames,string({fullConfigs.Name}));fullConfigs=fullConfigs(ord);
fullRuns=repmat(empty_run(),numel(fullConfigs)*numel(defs),1);nrun=0;
for ci=1:numel(fullConfigs)
    for di=1:numel(defs)
        nrun=nrun+1;fullRuns(nrun)=simulate_one(mdl,wks,fullConfigs(ci),defs(di));
        fprintf('V1_15_FULL_PROGRESS|%d/%d|%s|%s\n',nrun,numel(fullRuns),fullConfigs(ci).Name,defs(di).Case);
    end
end
fullInputMax=check_same_vehicle(fullRuns,fullConfigs,defs);
[fullBaselineMax,fullBaselineOutputMax]=check_against_v13(fullRuns(strcmp({fullRuns.Configuration},'C0')),source13.runs);
metadata.selectedNames=selectedNames;metadata.fullConfigs=fullConfigs;metadata.fullInputMax=fullInputMax;
metadata.fullBaselineArchiveMax=fullBaselineMax;metadata.fullBaselineOutputMax=fullBaselineOutputMax;metadata.simulationCounts=struct('calibration',36,'full',numel(fullRuns),'total',36+numel(fullRuns));
runArchive=fullfile(res,'vy_dekf_v1_15_covariance_calibration_runs.mat');
save(runArchive,'calibrationRuns','fullRuns','metadata','screenTable','paretoTable','-v7.3');
close_system(mdl,0);close_system('Solver_SF',0);clear modelClean folderClean;
analyze_vy_dekf_v1_15_covariance_calibration('final',runArchive);
evalin('base','clear global VY_DEKF_V15_Q VY_DEKF_V15_R; clear test_speed test_steer_amplitude test_steer_frequency');
end

function [a,c]=make_configs(T)
va=T.sensor_Ay_var(:);vr=T.sensor_r_var(:);a=struct();a.caseNames=T.Case;a.varAy=va;a.varR=vr;
a.R_emp_Ay=median(va);a.R_emp_r=median(vr);a.R_cons_Ay=max(3*a.R_emp_Ay,max(va));a.R_cons_r=max(3*a.R_emp_r,max(vr));
c=repmat(struct('Name','','Q',zeros(2),'R',zeros(2),'Q_vy',0,'Q_r',0,'R_Ay',0,'R_r',0,'RLevel',''),9,1);
c(1)=cfg('C0',1e-4,1e-4,1e-2,3.365172961808e-4,'Baseline');k=1;
for qv=[3e-4 1e-3]
    for qr=[1e-5 3e-5]
        for lev={'E','C'}
            k=k+1;
            if lev{1}=='E'
                ra=a.R_emp_Ay;rr=a.R_emp_r;
            else
                ra=a.R_cons_Ay;rr=a.R_cons_r;
            end
            c(k)=cfg(sprintf('Qv%g_Qr%g_R%s',qv,qr,lev{1}),qv,qr,ra,rr,lev{1});
        end
    end
end
end
function c=cfg(n,qv,qr,ra,rr,l),c=struct('Name',n,'Q',diag([qv qr]),'R',diag([ra rr]),'Q_vy',qv,'Q_r',qr,'R_Ay',ra,'R_r',rr,'RLevel',l);end
function print_anchors(a)
for i=1:numel(a.varAy),fprintf('V1_15_SENSOR_VAR|%s|Ay=%.17g|r=%.17g\n',a.caseNames(i),a.varAy(i),a.varR(i));end
fprintf('V1_15_R_ANCHOR|empAy=%.17g|empR=%.17g|consAy=%.17g|consR=%.17g\n',a.R_emp_Ay,a.R_emp_r,a.R_cons_Ay,a.R_cons_r);
end
function d=mk(c,v,a,f),d=struct('Case',c,'VxTarget',v,'SteerAmplitude',a,'Frequency',f);end

function u=wrapper_equivalence(c)
global VY_DEKF_V15_Q VY_DEKF_V15_R
VY_DEKF_V15_Q=c.Q;VY_DEKF_V15_R=c.R;clear('vy_dynamic_ekf_v1_13','vy_dynamic_ekf_v1_15');rng(1515);mx=0;
for i=1:120
    w=[5+25*rand;-.03+.06*rand(4,1);-3+6*rand;-.2+.4*rand];
    y13=vy_dynamic_ekf_v1_13(w);y15=vy_dynamic_ekf_v1_15(w);mx=max(mx,max(abs(y13-y15)));
end
u=struct('samples',120,'maxOutputDifference',mx,'passed',mx<=1e-12);fprintf('V1_15_C0_EQUIVALENCE|max=%.17g\n',mx);
end

function [target,a]=build_model(root,res)
source=fullfile(root,'model','vx_vy_dekf_v1_13.slx');target=fullfile(root,'model','vx_vy_dekf_v1_15.slx');assert(isfile(source));before=dir(source);copyfile(source,target,'f');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(res,'simulink_cache_vy_v1_15'),'CodeGenFolder',fullfile(res,'simulink_codegen_vy_v1_15'),'createDir',true);
load_system('simulink');load_system('Solver_SF');load_system(target);[~,m]=fileparts(target);block=[m '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(block,'MATLABFcn','vy_dynamic_ekf_v1_15(u)','OutputDimensions','59');save_system(m,target);expr=get_param(block,'MATLABFcn');close_system(m,0);close_system('Solver_SF',0);after=dir(source);
assert(before.bytes==after.bytes&&before.datenum==after.datenum);a=struct('source',source,'target',target,'wrapperExpression',expr,'sourceBytes',before.bytes,'sourceDatenum',before.datenum,'k_f',.78181,'k_r',1.09186);
fprintf('V1_15_BUILD_OK|%s\n',target);
end

function r=simulate_one(m,wks,c,d)
global VY_DEKF_V15_Q VY_DEKF_V15_R
VY_DEKF_V15_Q=c.Q;VY_DEKF_V15_R=c.R;
assignin(wks,'test_speed',d.VxTarget);assignin(wks,'test_steer_amplitude',d.SteerAmplitude);assignin(wks,'test_steer_frequency',d.Frequency);
assignin('base','test_speed',d.VxTarget);assignin('base','test_steer_amplitude',d.SteerAmplitude);assignin('base','test_steer_frequency',d.Frequency);
clear('vy_dynamic_ekf_v1_15');fprintf('V1_15_RUN_START|%s|%s\n',c.Name,d.Case);timer=tic;
out=sim(m,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');r=extract(out,c,d);
fprintf('V1_15_RUN_DONE|%s|%s|updates=%d|elapsed=%.3f\n',c.Name,d.Case,numel(r.t),toc(timer));
end
function r=empty_run(),r=struct('Configuration','','Case','','Q',zeros(2),'R',zeros(2),'VxTarget',0,'SteerAmplitude',0,'Frequency',0,'t',[],'u',[],'zRaw',[],'y',[],'pDiag',[],'diagnostics',[],'vyTrue',[],'rTrue',[],'ayTrue',[]);end
function r=extract(out,c,d)
[tu,u]=logm(fetch(out,{'est_u_log1','outest_u_log1'}));[tz,z]=logm(fetch(out,{'est_z_log1','out_est_z_log1'}));[ty,y]=logm(fetch(out,{'est_y_log1','outest_y_log1'}));[tp,p]=logm(fetch(out,{'est_P_log1','outest_P_log1'}));[td,g]=logm(fetch(out,{'est_diag_log1','outest_diag_log1'}));[tv,vy]=logm(fetch(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));[tr,rr]=logm(fetch(out,{'vy_AVz_true_log'}));[ta,ay]=logm(fetch(out,{'vy_Ay_true_log'}));
t=tz(:);r=empty_run();r.Configuration=c.Name;r.Case=d.Case;r.Q=c.Q;r.R=c.R;r.VxTarget=d.VxTarget;r.SteerAmplitude=d.SteerAmplitude;r.Frequency=d.Frequency;r.t=t;r.u=prev(tu,u(:,1:5),t);r.zRaw=z(:,1:2);r.y=prev(ty,y(:,1:2),t);r.pDiag=prev(tp,p(:,1:2),t);r.diagnostics=prev(td,g(:,1:55),t);r.vyTrue=lin(tv,vy(:,1),t);r.rTrue=lin(tr,rr(:,1),t);r.ayTrue=lin(ta,ay(:,1),t);
assert(numel(t)==1601&&abs(median(diff(t))-.01)<=1e-12&&size(r.diagnostics,2)==55);assert(all(isfinite([r.u r.zRaw r.y r.pDiag r.diagnostics r.vyTrue r.rTrue r.ayTrue]),'all'));
end
function mx=check_same_vehicle(runs,configs,defs)
mx=0;for di=1:numel(defs),q=runs(strcmp({runs.Case},defs(di).Case));ref=q(1);for i=2:numel(q),mx=max(mx,input_difference(ref,q(i)));end;end
assert(mx<=1e-10,'Vehicle/log inputs changed across covariance configurations: %.17g',mx);fprintf('V1_15_CONFIG_INPUT_EQUAL|max=%.17g\n',mx);
end
function [mx,outMx]=check_against_v13(runs,v13)
mx=0;outMx=0;for i=1:numel(runs),j=find(strcmp({v13.Case},runs(i).Case),1);assert(~isempty(j));mx=max(mx,input_difference(runs(i),v13(j)));outMx=max(outMx,max(abs([runs(i).y-v13(j).y runs(i).pDiag-v13(j).pDiag runs(i).diagnostics-v13(j).diagnostics]),[],'all'));end
assert(mx<=1e-10,'C0 vehicle data differs from V1.13 archive: %.17g',mx);assert(outMx<=1e-10,'C0 estimator output differs from V1.13 archive: %.17g',outMx);fprintf('V1_15_C0_V13_EQUAL|input=%.17g|output=%.17g\n',mx,outMx);
end
function d=input_difference(a,b),d=max(abs([a.t-b.t a.u-b.u a.zRaw-b.zRaw a.vyTrue-b.vyTrue a.rTrue-b.rTrue a.ayTrue-b.ayTrue]),[],'all');end
function v=fetch(o,a),w=o.who;for i=1:numel(a),if any(strcmp(w,a{i})),v=o.get(a{i});return;end;end;error('Missing log');end
function [t,d]=logm(v),if isa(v,'timeseries'),t=double(v.Time(:));q=double(v.Data);elseif isa(v,'Simulink.SimulationData.Signal'),[t,d]=logm(v.Values);return;else,error('Unsupported log');end;q=squeeze(q);if isvector(q),d=q(:);elseif size(q,1)==numel(t),d=q;else,d=q.';end;end
function v=prev(t,x,q),v=interp1(t(:),x,q(:),'previous','extrap');end
function v=lin(t,x,q),v=interp1(t(:),x,q(:),'linear','extrap');end
function close_models(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;end
