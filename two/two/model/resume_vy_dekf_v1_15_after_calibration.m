function resume_vy_dekf_v1_15_after_calibration()
%RESUME_VY_DEKF_V1_15_AFTER_CALIBRATION Continue after saved 36-run screen.
% This recovery path does not repeat or add calibration points.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');addpath(fullfile(root,'matlab'));
calFile=fullfile(res,'vy_dekf_v1_15_calibration_runs.mat');assert(isfile(calFile));C=load(calFile,'calibrationRuns','metadata');
[selectedNames,screenTable,paretoTable]=analyze_vy_dekf_v1_15_covariance_calibration('select',calFile);assert(numel(selectedNames)<=2&&~isempty(selectedNames));
defs=[mk('N',20,.02,.4);mk('V15',15,.02,.4);mk('V25',25,.02,.4);mk('A10',20,.01,.4);mk('A30',20,.03,.4);mk('F20',20,.02,.2);mk('F60',20,.02,.6)];
configs=C.metadata.configs;fullNames=["C0";selectedNames(:)];fullConfigs=configs(ismember(string({configs.Name}),fullNames));[~,ord]=ismember(fullNames,string({fullConfigs.Name}));fullConfigs=fullConfigs(ord);
modelFile=C.metadata.buildAudit.target;assert(isfile(modelFile));source13=load(fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat'),'runs');
old=pwd;cd(fileparts(modelFile));folderClean=onCleanup(@()cd(old));addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(res,'simulink_cache_vy_v1_15'),'CodeGenFolder',fullfile(res,'simulink_codegen_vy_v1_15'),'createDir',true);load_system('simulink');load_system('Solver_SF');load_system(modelFile);[~,mdl]=fileparts(modelFile);modelClean=onCleanup(@()close_models(mdl));wks=get_param(mdl,'ModelWorkspace');
fullRuns=repmat(empty_run(),numel(fullConfigs)*numel(defs),1);nrun=0;
for ci=1:numel(fullConfigs),for di=1:numel(defs),nrun=nrun+1;fullRuns(nrun)=simulate_one(mdl,wks,fullConfigs(ci),defs(di));fprintf('V1_15_FULL_PROGRESS|%d/%d|%s|%s\n',nrun,numel(fullRuns),fullConfigs(ci).Name,defs(di).Case);end,end
fullInputMax=check_same_vehicle(fullRuns,defs);[fullBaselineMax,fullBaselineOutputMax]=check_against_v13(fullRuns(strcmp({fullRuns.Configuration},'C0')),source13.runs);
metadata=C.metadata;metadata.selectedNames=selectedNames;metadata.fullConfigs=fullConfigs;metadata.fullInputMax=fullInputMax;metadata.fullBaselineArchiveMax=fullBaselineMax;metadata.fullBaselineOutputMax=fullBaselineOutputMax;metadata.simulationCounts=struct('calibration',36,'full',numel(fullRuns),'total',36+numel(fullRuns));
calibrationRuns=C.calibrationRuns;runArchive=fullfile(res,'vy_dekf_v1_15_covariance_calibration_runs.mat');save(runArchive,'calibrationRuns','fullRuns','metadata','screenTable','paretoTable','-v7.3');close_system(mdl,0);close_system('Solver_SF',0);clear modelClean folderClean;
analyze_vy_dekf_v1_15_covariance_calibration('final',runArchive);evalin('base','clear global VY_DEKF_V15_Q VY_DEKF_V15_R; clear test_speed test_steer_amplitude test_steer_frequency');
end
function d=mk(c,v,a,f),d=struct('Case',c,'VxTarget',v,'SteerAmplitude',a,'Frequency',f);end
function r=empty_run(),r=struct('Configuration','','Case','','Q',zeros(2),'R',zeros(2),'VxTarget',0,'SteerAmplitude',0,'Frequency',0,'t',[],'u',[],'zRaw',[],'y',[],'pDiag',[],'diagnostics',[],'vyTrue',[],'rTrue',[],'ayTrue',[]);end
function r=simulate_one(m,wks,c,d)
global VY_DEKF_V15_Q VY_DEKF_V15_R
VY_DEKF_V15_Q=c.Q;VY_DEKF_V15_R=c.R;assignin(wks,'test_speed',d.VxTarget);assignin(wks,'test_steer_amplitude',d.SteerAmplitude);assignin(wks,'test_steer_frequency',d.Frequency);assignin('base','test_speed',d.VxTarget);assignin('base','test_steer_amplitude',d.SteerAmplitude);assignin('base','test_steer_frequency',d.Frequency);clear('vy_dynamic_ekf_v1_15');fprintf('V1_15_RUN_START|%s|%s\n',c.Name,d.Case);timer=tic;out=sim(m,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');r=extract(out,c,d);fprintf('V1_15_RUN_DONE|%s|%s|updates=%d|elapsed=%.3f\n',c.Name,d.Case,numel(r.t),toc(timer));
end
function r=extract(out,c,d)
[tu,u]=logm(fetch(out,{'est_u_log1','outest_u_log1'}));[tz,z]=logm(fetch(out,{'est_z_log1','out_est_z_log1'}));[ty,y]=logm(fetch(out,{'est_y_log1','outest_y_log1'}));[tp,p]=logm(fetch(out,{'est_P_log1','outest_P_log1'}));[td,g]=logm(fetch(out,{'est_diag_log1','outest_diag_log1'}));[tv,vy]=logm(fetch(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));[tr,rr]=logm(fetch(out,{'vy_AVz_true_log'}));[ta,ay]=logm(fetch(out,{'vy_Ay_true_log'}));t=tz(:);r=empty_run();r.Configuration=c.Name;r.Case=d.Case;r.Q=c.Q;r.R=c.R;r.VxTarget=d.VxTarget;r.SteerAmplitude=d.SteerAmplitude;r.Frequency=d.Frequency;r.t=t;r.u=prev(tu,u(:,1:5),t);r.zRaw=z(:,1:2);r.y=prev(ty,y(:,1:2),t);r.pDiag=prev(tp,p(:,1:2),t);r.diagnostics=prev(td,g(:,1:55),t);r.vyTrue=lin(tv,vy(:,1),t);r.rTrue=lin(tr,rr(:,1),t);r.ayTrue=lin(ta,ay(:,1),t);assert(numel(t)==1601&&abs(median(diff(t))-.01)<=1e-12&&all(isfinite([r.u r.zRaw r.y r.pDiag r.diagnostics r.vyTrue r.rTrue r.ayTrue]),'all'));
end
function mx=check_same_vehicle(runs,defs),mx=0;for di=1:numel(defs),q=runs(strcmp({runs.Case},defs(di).Case));ref=q(1);for i=2:numel(q),mx=max(mx,idiff(ref,q(i)));end;end;assert(mx<=1e-10);fprintf('V1_15_FULL_INPUT_EQUAL|max=%.17g\n',mx);end
function [mx,om]=check_against_v13(runs,v13),mx=0;om=0;for i=1:numel(runs),j=find(strcmp({v13.Case},runs(i).Case),1);mx=max(mx,idiff(runs(i),v13(j)));om=max(om,max(abs([runs(i).y-v13(j).y runs(i).pDiag-v13(j).pDiag runs(i).diagnostics-v13(j).diagnostics]),[],'all'));end;assert(mx<=1e-10&&om<=1e-10);fprintf('V1_15_FULL_C0_V13_EQUAL|input=%.17g|output=%.17g\n',mx,om);end
function d=idiff(a,b),d=max(abs([a.t-b.t a.u-b.u a.zRaw-b.zRaw a.vyTrue-b.vyTrue a.rTrue-b.rTrue a.ayTrue-b.ayTrue]),[],'all');end
function v=fetch(o,a),w=o.who;for i=1:numel(a),if any(strcmp(w,a{i})),v=o.get(a{i});return;end;end;error('Missing log');end
function [t,d]=logm(v),if isa(v,'timeseries'),t=double(v.Time(:));q=double(v.Data);elseif isa(v,'Simulink.SimulationData.Signal'),[t,d]=logm(v.Values);return;else,error('Unsupported log');end;q=squeeze(q);if isvector(q),d=q(:);elseif size(q,1)==numel(t),d=q;else,d=q.';end;end
function v=prev(t,x,q),v=interp1(t(:),x,q(:),'previous','extrap');end
function v=lin(t,x,q),v=interp1(t(:),x,q(:),'linear','extrap');end
function close_models(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;end
