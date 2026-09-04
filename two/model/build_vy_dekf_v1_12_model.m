function report = build_vy_dekf_v1_12_model()
%BUILD_VY_DEKF_V1_12_MODEL Create an isolated parameterized model copy.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_7.slx');
copyFile = fullfile(repoRoot,'model','vx_vy_dekf_v1_12.slx');
assert(isfile(sourceFile),'Stable V1.7 source model missing: %s',sourceFile);
sourceBefore = dir(sourceFile);
copyfile(sourceFile,copyFile,'f');

addpath(fullfile(repoRoot,'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder',fullfile(repoRoot,'results','simulink_cache_vy_v1_12'), ...
    'CodeGenFolder',fullfile(repoRoot,'results','simulink_codegen_vy_v1_12'),'createDir',true);
load_system('simulink'); load_system('Solver_SF'); load_system(copyFile);
[~,modelName] = fileparts(copyFile);

profileBlock = [modelName '/D-EKF Lateral Profile'];
speedBlock = [modelName '/Repeating Sequence Interpolated2'];
estimatorBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
set_param(profileBlock,'MATLABFcn', ...
    'vy_dekf_v1_12_steer_profile(u,test_steer_amplitude,test_steer_frequency)');
set_param(speedBlock,'OutValues','test_speed*3.6*ones(4,1)');

wks = get_param(modelName,'ModelWorkspace');
assignin(wks,'test_speed',20);
assignin(wks,'test_steer_amplitude',0.02);
assignin(wks,'test_steer_frequency',0.4);
assignin(wks,'Ay_bias_v17',0);
assignin(wks,'AVz_bias_v17',0);
save_system(modelName,copyFile);

report = struct('sourceFile',sourceFile,'copyFile',copyFile, ...
    'profileExpression',get_param(profileBlock,'MATLABFcn'), ...
    'speedExpression',get_param(speedBlock,'OutValues'), ...
    'estimatorExpression',get_param(estimatorBlock,'MATLABFcn'), ...
    'fixedQ',diag([1e-4,1e-4]), ...
    'fixedR',diag([1e-2,3.365172961808e-4]), ...
    'onlineAxleScalingApplied',false,'onlineRelaxationApplied',false);
assert(strcmp(strrep(report.estimatorExpression,' ',''), ...
    'vy_dynamic_ekf_v1_7(u,Ay_bias_v17,AVz_bias_v17)'), ...
    'Online D-EKF expression changed unexpectedly.');
close_system(modelName,0); close_system('Solver_SF',0);
sourceAfter = dir(sourceFile);
assert(sourceBefore.bytes==sourceAfter.bytes && sourceBefore.datenum==sourceAfter.datenum, ...
    'Source model changed while creating V1.12 copy.');
fprintf('V1_12_BUILD_OK|copy=%s\n',copyFile);
end
