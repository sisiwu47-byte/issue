function run_vy_dekf_v1_17_online_multirate()
%RUN_VY_DEKF_V1_17_ONLINE_MULTIRATE Run 7 cases x A100/A50/A20 online.
root=fileparts(fileparts(mfilename('fullpath')));res=fullfile(root,'results');
addpath(fullfile(root,'matlab'));addpath(fullfile(root,'tests'));
testReport=test_vy_dynamic_ekf_v17_multirate();assert(testReport.passed);
buildReport=build_vy_dekf_v1_17_model();modelFile=buildReport.copyFile;
defs=[mk('N',20,.02,.4);mk('V15',15,.02,.4);mk('V25',25,.02,.4); ...
    mk('A10',20,.01,.4);mk('A30',20,.03,.4);mk('F20',20,.02,.2);mk('F60',20,.02,.6)];
modes=[100 50 20];modeNames={ 'A100','A50','A20'};
old=pwd;cd(fileparts(modelFile));folderClean=onCleanup(@()cd(old));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(res,'simulink_cache_vy_v1_17'), ...
    'CodeGenFolder',fullfile(res,'simulink_codegen_vy_v1_17'),'createDir',true);
load_system('simulink');load_system('Solver_SF');load_system(modelFile);[~,m]=fileparts(modelFile);
modelClean=onCleanup(@()close_models(m));wks=get_param(m,'ModelWorkspace');runs=repmat(empty_run(),21,1);q=0;
archive=fullfile(res,'vy_dekf_v1_17_online_multirate_runs.mat');
for ci=1:7
    d=defs(ci);assignin(wks,'test_speed',d.VxTarget);assignin(wks,'test_steer_amplitude',d.SteerAmplitude);assignin(wks,'test_steer_frequency',d.Frequency);
    assignin('base','test_speed',d.VxTarget);assignin('base','test_steer_amplitude',d.SteerAmplitude);assignin('base','test_steer_frequency',d.Frequency);
    for mi=1:3
        q=q+1;assignin(wks,'vy_v17_mode_code',modes(mi));assignin('base','vy_v17_mode_code',modes(mi));
        clear('vy_dynamic_ekf_v1_17');fprintf('V1_17_CASE_START|%s|%s\n',d.Case,modeNames{mi});timer=tic;
        out=sim(m,'StopTime','16','ReturnWorkspaceOutputs','on','FastRestart','off');
        runs(q)=extract(out,d,modeNames{mi},modes(mi));
        fprintf('V1_17_CASE_DONE|%s|%s|updates=%d|AyLogged=%d|elapsed=%.3f\n',d.Case,modeNames{mi},numel(runs(q).t),sum(runs(q).diagnostics(2:end,56)>0.5),toc(timer));
        metadata=make_metadata(modelFile,buildReport,defs,modes,modeNames,testReport,q);save(archive,'runs','metadata','-v7.3');
    end
end
metadata=make_metadata(modelFile,buildReport,defs,modes,modeNames,testReport,21);save(archive,'runs','metadata','-v7.3');
close_system(m,0);close_system('Solver_SF',0);clear modelClean folderClean;
analyze_vy_dekf_v1_17_online_multirate(archive);
evalin('base','clear test_speed test_steer_amplitude test_steer_frequency vy_v17_mode_code');
end

function d=mk(c,v,a,f),d=struct('Case',c,'VxTarget',v,'SteerAmplitude',a,'Frequency',f);end
function r=empty_run(),r=struct('Case','','Mode','','ModeCode',0,'VxTarget',0,'SteerAmplitude',0,'Frequency',0,'t',[],'u',[],'zRaw',[],'y',[],'pDiag',[],'diagnostics',[],'vyTrue',[],'rTrue',[],'ayTrue',[]);end
function m=make_metadata(modelFile,b,defs,modes,names,testReport,completed)
m=struct('modelFile',modelFile,'sourceModel',b.sourceFile,'definitions',defs,'modes',modes,'modeNames',{names}, ...
    'fixedQ',b.fixedQ,'fixedR',b.fixedR,'k_f',b.k_f,'k_r',b.k_r,'predictionHz',100,'yawUpdateHz',100, ...
    'updatesPerCase',1601,'Ts',.01,'testReport',testReport,'completedRuns',completed,'onlyAyRateChanged',true);
end
function r=extract(out,d,modeName,modeCode)
[tu,u]=logm(fetch(out,{'est_u_log1','outest_u_log1'}));[tz,z]=logm(fetch(out,{'est_z_log1','out_est_z_log1'}));
[ty,y]=logm(fetch(out,{'est_y_log1','outest_y_log1'}));[tp,p]=logm(fetch(out,{'est_P_log1','outest_P_log1'}));
[td,g]=logm(fetch(out,{'est_diag_log1','outest_diag_log1'}));[tv,vy]=logm(fetch(out,{'vy_true_log1','Vy_true_log','vy_true_log'}));
[tr,rr]=logm(fetch(out,{'vy_AVz_true_log'}));[ta,ay]=logm(fetch(out,{'vy_Ay_true_log'}));
t=tz(:);r=empty_run();r.Case=d.Case;r.Mode=modeName;r.ModeCode=modeCode;r.VxTarget=d.VxTarget;r.SteerAmplitude=d.SteerAmplitude;r.Frequency=d.Frequency;r.t=t;
r.u=prev(tu,u(:,1:5),t);r.zRaw=z(:,1:2);r.y=prev(ty,y(:,1:2),t);r.pDiag=prev(tp,p(:,1:2),t);r.diagnostics=prev(td,g(:,1:65),t);
r.vyTrue=lin(tv,vy(:,1),t);r.rTrue=lin(tr,rr(:,1),t);r.ayTrue=lin(ta,ay(:,1),t);
assert(numel(t)==1601&&abs(median(diff(t))-.01)<=1e-12&&size(r.diagnostics,2)==65);assert(all(isfinite([r.u r.zRaw r.y r.pDiag r.diagnostics r.vyTrue r.rTrue r.ayTrue]),'all'));
end
function v=fetch(o,a),w=o.who;for i=1:numel(a),if any(strcmp(w,a{i})),v=o.get(a{i});return;end;end;error('Missing log');end
function [t,d]=logm(v),if isa(v,'timeseries'),t=double(v.Time(:));q=double(v.Data);elseif isa(v,'Simulink.SimulationData.Signal'),[t,d]=logm(v.Values);return;else,error('Unsupported log');end;q=squeeze(q);if isvector(q),d=q(:);elseif size(q,1)==numel(t),d=q;else,d=q.';end;end
function v=prev(t,x,q),v=interp1(t(:),x,q(:),'previous','extrap');end
function v=lin(t,x,q),v=interp1(t(:),x,q(:),'linear','extrap');end
function close_models(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end;end
