function report = build_vy_dekf_v1_4_model()
%BUILD_VY_DEKF_V1_4_MODEL Create the isolated V1.4 R-sweep model.
%
% The V1.3 model remains untouched. The copy differs only in the dedicated
% wrapper expression and two model-workspace R variables.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoRoot, 'model');
sourceFile = fullfile(modelDir, 'vx_vy_dekf_v1_3.slx');
copyFile = fullfile(modelDir, 'vx_vy_dekf_v1_4.slx');
assert(isfile(sourceFile), 'V1.3 source model is missing: %s', sourceFile);

sourceInfoBefore = dir(sourceFile);
copyfile(sourceFile, copyFile, 'f');

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(repoRoot, 'results', 'simulink_cache_vy_v1_4'), ...
    'CodeGenFolder', fullfile(repoRoot, 'results', 'simulink_codegen_vy_v1_4'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(copyFile);
[~, modelName] = fileparts(copyFile);

estimatorBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
assert(getSimulinkBlockHandle(estimatorBlock) > 0, ...
    'The 100 Hz D-EKF wrapper block was not found.');
set_param(estimatorBlock, ...
    'MATLABFcn', 'vy_dynamic_ekf_v1_4(u,R_Ay_v14,R_r_v14)', ...
    'OutputDimensions', '15');

modelWks = get_param(modelName, 'ModelWorkspace');
assignin(modelWks, 'R_Ay_v14', 1e-2);
assignin(modelWks, 'R_r_v14', 1e-2);

save_system(modelName, copyFile);

report = struct();
report.sourceFile = sourceFile;
report.copyFile = copyFile;
report.wrapperExpression = get_param(estimatorBlock, 'MATLABFcn');
report.R_Ay_v14 = evalin(modelWks, 'R_Ay_v14');
report.R_r_v14 = evalin(modelWks, 'R_r_v14');

close_system(modelName, 0);
close_system('Solver_SF', 0);

sourceInfoAfter = dir(sourceFile);
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes && ...
    sourceInfoBefore.datenum == sourceInfoAfter.datenum, ...
    'V1.3 source model changed unexpectedly.');

fprintf('V1_4_BUILD_OK|copy=%s\n', copyFile);
fprintf('WRAPPER|%s\n', report.wrapperExpression);
fprintf('MODEL_WORKSPACE|R_Ay_v14=%.15g|R_r_v14=%.15g\n', ...
    report.R_Ay_v14, report.R_r_v14);
end
