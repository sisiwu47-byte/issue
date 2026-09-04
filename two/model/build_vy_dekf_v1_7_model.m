function report = build_vy_dekf_v1_7_model()
%BUILD_VY_DEKF_V1_7_MODEL Create the isolated oracle-bias V1.7 model copy.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_6.slx');
copyFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_7.slx');
assert(isfile(sourceFile),'V1.6 source model missing: %s',sourceFile);
sourceInfoBefore = dir(sourceFile);
copyfile(sourceFile,copyFile,'f');

addpath(fullfile(repoRoot,'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(repoRoot,'results','simulink_cache_vy_v1_7'), ...
    'CodeGenFolder',fullfile(repoRoot,'results','simulink_codegen_vy_v1_7'), ...
    'createDir',true);
load_system('simulink');
load_system('Solver_SF');
load_system(copyFile);
[~,modelName] = fileparts(copyFile);
estimatorBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(estimatorBlock, ...
    'MATLABFcn','vy_dynamic_ekf_v1_7(u,Ay_bias_v17,AVz_bias_v17)', ...
    'OutputDimensions','51');
set_param([modelName '/Demux12'],'Outputs','[2 2 47]');
modelWks = get_param(modelName,'ModelWorkspace');
assignin(modelWks,'Ay_bias_v17',0);
assignin(modelWks,'AVz_bias_v17',0);
save_system(modelName,copyFile);

report = struct('sourceFile',sourceFile,'copyFile',copyFile, ...
    'wrapperExpression',get_param(estimatorBlock,'MATLABFcn'), ...
    'outputWidth',51,'diagnosticWidth',47, ...
    'fixedQ',diag([1e-4,1e-4]), ...
    'fixedR',diag([1e-2,3.365172961808e-4]));
close_system(modelName,0);
close_system('Solver_SF',0);
sourceInfoAfter = dir(sourceFile);
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes && ...
    sourceInfoBefore.datenum == sourceInfoAfter.datenum, ...
    'V1.6 source model changed unexpectedly.');
fprintf('V1_7_BUILD_OK|copy=%s|output=51|diag=47\n',copyFile);
end
