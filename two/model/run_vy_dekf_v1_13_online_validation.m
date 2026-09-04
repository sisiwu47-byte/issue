function run_vy_dekf_v1_13_online_validation()
%RUN_VY_DEKF_V1_13_ONLINE_VALIDATION Seven independent online cases.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');
addpath(fullfile(root,'matlab'));addpath(fullfile(root,'tests'));
testReport=test_vy_dynamic_ekf_v13_equivalence();assert(testReport.passed);
buildReport=build_vy_dekf_v1_13_model();modelFile=buildReport.copyFile;
defs=[mk('N',20,.02,.4);mk('V15',15,.02,.4);mk('V25',25,.02,.4); ...
    mk('A10',20,.01,.4);mk('A30',20,.03,.4);mk('F20',20,.02,.2);mk('F60',20,.02,.6)];
old=pwd;cd(fileparts(modelFile));folderClean=onCleanup(@()cd(old));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(res,'simulink_cache_vy_v1_13'), ...
    'CodeGenFolder',fullfile(res,'simulink_codegen_vy_v1_13'),'createDir',true);
load_system('simulink');load_system('Solver_SF');load_system(modelFile);[~,m]=fileparts(modelFile);
modelClean=onCleanup(@()close_models(m));wks=get_param(m,'ModelWorkspace');runs=repmat(empty_run(),7,1);
for i=1:7
    d=defs(i);assignin(wks,'test_speed',d.VxTarget);assignin(wks,'test_steer_amplitude',d.SteerAmplitude);assignin(wks,'test_steer_frequency',d.Frequency);
    assignin('base','test_speed',d.VxTarget);assignin('base','test_steer_amplitude',d.SteerAmplitude);assignin('base','test_steer_frequency',d.Frequency);
    clear('vy_dynamic_ekf_v1_13');fprintf('V1_13_CASE_START|%s\n',d.Case);timer=tic;
    out=sim(m,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');runs(i)=extract(out,d);
    run=runs(i);save(fullfile(res,sprintf('vy_dekf_v1_13_run_%s.mat',d.Case)),'run','d','-v7.3');
    fprintf('V1_13_CASE_DONE|%s|updates=%d|elapsed=%.3f\n',d.Case,numel(run.t),toc(timer));
end
metadata=struct('modelFile',modelFile,'sourceModel',buildReport.sourceFile,'definitions',defs, ...
    'fixedQ',buildReport.fixedQ,'fixedR',buildReport.fixedR,'k_f',buildReport.k_f,'k_r',buildReport.k_r, ...
    'updatesPerCase',1601,'Ts',.01,'testReport',testReport,'onlineAxleScalingApplied',true, ...
    'otherModelChangesApplied',false);
archive=fullfile(res,'vy_dekf_v1_13_online_validation_runs.mat');save(archive,'runs','metadata','-v7.3');
close_system(m,0);close_system('Solver_SF',0);clear modelClean folderClean;
analyze_vy_dekf_v1_13_online_validation(archive);evalin('base','clear test_speed test_steer_amplitude test_steer_frequency');
end
function d=mk(c,v,a,f),d=struct('Case',c,'VxTarget',v,'SteerAmplitude',a,'Frequency',f);end
function r=empty_run(),r=struct('Case','','VxTarget',0,'SteerAmplitude',0,'Frequency',0,'t',[],'u',[],'zRaw',[],'y',[],'pDiag',[],'diagnostics',[],'vyTrue',[],'rTrue',[],'ayTrue',[]);end
function r=extract(out,d)
[tu,u]=logm(fetch(out,{'est_u_log1','outest_u_log1'}));[tz,z]=logm(fetch(out,{'est_z_log1','out_est_z_log1'}));
[ty,y]=logm(fetch(out,{'est_y_log1','outest_y_log1'}));[tp,p]=logm(fetch(out,{'est_P_log1','outest_P_log1'}));
[td,g]=logm(fetch(out,{'est_diag_log1','outest_diag_log1'}));[tv,vy]=logm(fetch(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));
[tr,rr]=logm(fetch(out,{'vy_AVz_true_log'}));[ta,ay]=logm(fetch(out,{'vy_Ay_true_log'}));
t=tz(:);r=empty_run();r.Case=d.Case;r.VxTarget=d.VxTarget;r.SteerAmplitude=d.SteerAmplitude;r.Frequency=d.Frequency;r.t=t;
r.u=prev(tu,u(:,1:5),t);r.zRaw=z(:,1:2);r.y=prev(ty,y(:,1:2),t);r.pDiag=prev(tp,p(:,1:2),t);r.diagnostics=prev(td,g(:,1:55),t);
r.vyTrue=lin(tv,vy(:,1),t);r.rTrue=lin(tr,rr(:,1),t);r.ayTrue=lin(ta,ay(:,1),t);
assert(numel(t)==1601&&abs(median(diff(t))-.01)<=1e-12&&size(r.diagnostics,2)==55);assert(all(isfinite([r.u r.zRaw r.y r.pDiag r.diagnostics r.vyTrue r.rTrue r.ayTrue]),'all'));
end
function v=fetch(o,a),w=o.who;for i=1:numel(a),if any(strcmp(w,a{i})),v=o.get(a{i});return;end;end;error('Missing log');end
function [t,d]=logm(v),if isa(v,'timeseries'),t=double(v.Time(:));q=double(v.Data);elseif isa(v,'Simulink.SimulationData.Signal'),[t,d]=logm(v.Values);return;else,error('Unsupported log');end;q=squeeze(q);if isvector(q),d=q(:);elseif size(q,1)==numel(t),d=q;else,d=q.';end;end
function v=prev(t,x,q),v=interp1(t(:),x,q(:),'previous','extrap');end
function v=lin(t,x,q),v=interp1(t(:),x,q(:),'linear','extrap');end
function close_models(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;end
