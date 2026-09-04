function report=build_vy_dekf_v1_17_model()
%BUILD_VY_DEKF_V1_17_MODEL Create the isolated multi-rate model copy.
root=fileparts(fileparts(mfilename('fullpath')));
source=fullfile(root,'model','vx_vy_dekf_v1_13.slx');target=fullfile(root,'model','vx_vy_dekf_v1_17.slx');
assert(isfile(source));before=dir(source);copyfile(source,target,'f');
addpath(fullfile(root,'matlab'));addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(root,'results','simulink_cache_vy_v1_17'), ...
    'CodeGenFolder',fullfile(root,'results','simulink_codegen_vy_v1_17'),'createDir',true);
load_system('simulink');load_system('Solver_SF');load_system(target);[~,m]=fileparts(target);
block=[m '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(block,'MATLABFcn','vy_dynamic_ekf_v1_17(u,vy_v17_mode_code)','OutputDimensions','69');
set_param([m '/Demux12'],'Outputs','[2 2 65]');
wks=get_param(m,'ModelWorkspace');assignin(wks,'vy_v17_mode_code',100);save_system(m,target);
report=struct('sourceFile',source,'copyFile',target,'wrapperExpression',get_param(block,'MATLABFcn'), ...
    'outputWidth',69,'diagnosticWidth',65,'modes',[100 50 20],'predictionHz',100,'yawUpdateHz',100, ...
    'fixedQ',diag([1e-4,1e-4]),'fixedR',diag([1e-2,3.365172961808e-4]),'k_f',.78181,'k_r',1.09186);
close_system(m,0);close_system('Solver_SF',0);after=dir(source);
assert(before.bytes==after.bytes&&before.datenum==after.datenum,'V1.13 source model changed.');
fprintf('V1_17_BUILD_OK|copy=%s|out=69|diag=65\n',target);
end
