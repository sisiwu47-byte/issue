function report = build_vy_dekf_v1_5_model()
%BUILD_VY_DEKF_V1_5_MODEL Create an isolated diagnostic V1.5 model copy.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1_4.slx');
copyFile = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1_5.slx');
assert(isfile(sourceFile), 'V1.4 source model missing: %s', sourceFile);
sourceInfoBefore = dir(sourceFile);
copyfile(sourceFile, copyFile, 'f');

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(repoRoot, 'results', 'simulink_cache_vy_v1_5'), ...
    'CodeGenFolder', fullfile(repoRoot, 'results', 'simulink_codegen_vy_v1_5'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(copyFile);
[~, modelName] = fileparts(copyFile);
estimatorBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(estimatorBlock, ...
    'MATLABFcn', 'vy_dynamic_ekf_v1_5(u,R_Ay_v15,R_r_v15)', ...
    'OutputDimensions', '45');
diagnosticDemux = [modelName '/Demux12'];
set_param(diagnosticDemux, 'Outputs', '[2 2 41]');
modelWks = get_param(modelName, 'ModelWorkspace');
assignin(modelWks, 'R_Ay_v15', 1e-2);
assignin(modelWks, 'R_r_v15', 1e-2);
save_system(modelName, copyFile);

report = struct('sourceFile', sourceFile, 'copyFile', copyFile, ...
    'wrapperExpression', get_param(estimatorBlock, 'MATLABFcn'), ...
    'outputWidth', 45, 'diagnosticWidth', 41);
close_system(modelName, 0);
close_system('Solver_SF', 0);
sourceInfoAfter = dir(sourceFile);
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes && ...
    sourceInfoBefore.datenum == sourceInfoAfter.datenum, ...
    'V1.4 source model changed unexpectedly.');
fprintf('V1_5_BUILD_OK|copy=%s|output=45|diag=41\n', copyFile);
end
