function report = build_vy_dekf_v1_3_model()
%BUILD_VY_DEKF_V1_3_MODEL Create the isolated V1.3 characterization model.
%
% The V1 model remains untouched. V1.3 adds only two clean-signal logs and
% redirects the existing 100 Hz estimator block to a diagnostic-only
% wrapper that appends innovation_Ay and innovation_r to diag_out.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoRoot, 'model');
sourceFile = fullfile(modelDir, 'vx_vy_dekf_v1.slx');
copyFile = fullfile(modelDir, 'vx_vy_dekf_v1_3.slx');
assert(isfile(sourceFile), 'V1 source model is missing: %s', sourceFile);

sourceInfoBefore = dir(sourceFile);
copyfile(sourceFile, copyFile, 'f');

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(repoRoot, 'results', 'simulink_cache_vy_v1_3'), ...
    'CodeGenFolder', fullfile(repoRoot, 'results', 'simulink_codegen_vy_v1_3'), ...
    'createDir', true);

load_system('simulink');
load_system('Solver_SF');
load_system(copyFile);
[~, modelName] = fileparts(copyFile);

estimatorBlock = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
assert(getSimulinkBlockHandle(estimatorBlock) > 0, ...
    'The 100 Hz D-EKF wrapper block was not found.');
set_param(estimatorBlock, ...
    'MATLABFcn', 'vy_dynamic_ekf_v1_3(u)', ...
    'OutputDimensions', '15');

diagnosticDemux = [modelName '/Demux12'];
assert(strcmp(get_param(diagnosticDemux, 'BlockType'), 'Demux'), ...
    'Expected diagnostic Demux12 was not found.');
set_param(diagnosticDemux, 'Outputs', '[2 2 11]');

ayLogBlock = [modelName '/Vy Ay true log'];
avzLogBlock = [modelName '/Vy AVz true log'];
assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
    'Name', 'Vy Ay true log')), 'Ay true log block already exists.');
assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
    'Name', 'Vy AVz true log')), 'AVz true log block already exists.');

aySource = [modelName '/Gain36'];
avzSource = [modelName '/Gain10'];
ayPosition = get_param(aySource, 'Position');
avzPosition = get_param(avzSource, 'Position');

add_block('simulink/Sinks/To Workspace', ayLogBlock, ...
    'Position', ayPosition + [160, 80, 250, 100], ...
    'VariableName', 'vy_Ay_true_log', ...
    'SaveFormat', 'Timeseries', ...
    'SampleTime', '0.01', ...
    'MaxDataPoints', 'inf', ...
    'Decimation', '1');
add_block('simulink/Sinks/To Workspace', avzLogBlock, ...
    'Position', avzPosition + [160, 80, 250, 100], ...
    'VariableName', 'vy_AVz_true_log', ...
    'SaveFormat', 'Timeseries', ...
    'SampleTime', '0.01', ...
    'MaxDataPoints', 'inf', ...
    'Decimation', '1');

add_line(modelName, 'Gain36/1', 'Vy Ay true log/1', 'autorouting', 'on');
add_line(modelName, 'Gain10/1', 'Vy AVz true log/1', 'autorouting', 'on');

save_system(modelName, copyFile);
close_system(modelName, 0);
close_system('Solver_SF', 0);

sourceInfoAfter = dir(sourceFile);
assert(sourceInfoBefore.bytes == sourceInfoAfter.bytes && ...
    sourceInfoBefore.datenum == sourceInfoAfter.datenum, ...
    'V1 source model changed unexpectedly.');

report = struct();
report.sourceFile = sourceFile;
report.copyFile = copyFile;
report.estimatorWrapper = 'vy_dynamic_ekf_v1_3(u)';
report.diagWidth = 11;
report.ayTrueSource = 'Gain36 output: CarSim Ay * 9.8 [m/s^2]';
report.avzTrueSource = 'Gain10 output: CarSim AVz * pi/180 [rad/s]';
report.ayTrueLog = 'vy_Ay_true_log';
report.avzTrueLog = 'vy_AVz_true_log';

fprintf('V1_3_BUILD_OK|copy=%s\n', copyFile);
fprintf('DIAG|wrapper=vy_dynamic_ekf_v1_3|width=15|diag=11\n');
fprintf('TRUE_LOG|Ay=Gain36->vy_Ay_true_log|unit=m/s^2|Ts=0.01\n');
fprintf('TRUE_LOG|AVz=Gain10->vy_AVz_true_log|unit=rad/s|Ts=0.01\n');
end
