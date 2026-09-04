function report = build_vy_dekf_v1_6_model()
%BUILD_VY_DEKF_V1_6_MODEL Create isolated V1.6 discrete-Q sweep model.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_5.slx');
copyFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_6.slx');
assert(isfile(sourceFile),'V1.5 source model missing.');
sourceInfoBefore = dir(sourceFile);
copyfile(sourceFile,copyFile,'f');
addpath(fullfile(repoRoot,'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(repoRoot,'results','simulink_cache_vy_v1_6'), ...
    'CodeGenFolder',fullfile(repoRoot,'results','simulink_codegen_vy_v1_6'), ...
    'createDir',true);
load_system('simulink'); load_system('Solver_SF'); load_system(copyFile);
[~,modelName] = fileparts(copyFile);
block = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(block,'MATLABFcn','vy_dynamic_ekf_v1_6(u,Q_vy_v16,Q_r_v16)', ...
    'OutputDimensions','49');
set_param([modelName '/Demux12'],'Outputs','[2 2 45]');
modelWks = get_param(modelName,'ModelWorkspace');
assignin(modelWks,'Q_vy_v16',1e-4);
assignin(modelWks,'Q_r_v16',1e-3);
save_system(modelName,copyFile);
report = struct('sourceFile',sourceFile,'copyFile',copyFile, ...
    'wrapper',get_param(block,'MATLABFcn'),'outputWidth',49, ...
    'diagnosticWidth',45,'fixedR',diag([1e-2,3.365172961808e-4]));
close_system(modelName,0); close_system('Solver_SF',0);
sourceInfoAfter=dir(sourceFile);
assert(sourceInfoBefore.bytes==sourceInfoAfter.bytes && ...
    sourceInfoBefore.datenum==sourceInfoAfter.datenum, ...
    'V1.5 source model changed unexpectedly.');
fprintf('V1_6_BUILD_OK|copy=%s|output=49|diag=45|R=[0.01 %.15g]\n', ...
    copyFile,3.365172961808e-4);
end
