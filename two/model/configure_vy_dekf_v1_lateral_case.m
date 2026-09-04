function report = configure_vy_dekf_v1_lateral_case()
%CONFIGURE_VY_DEKF_V1_LATERAL_CASE Add a real CarSim steering test to the V1 copy.
%
% Only model/vx_vy_dekf_v1.slx is changed. The active CarSim import branch
% remains selected and its existing wheel-torque/force channels are kept.
% Four steering entries in Mux8 are replaced by the smooth profile output,
% converted from radians to the degree interface expected by CarSim.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(repoRoot, 'model', 'vx_vy_dekf_v1.slx');
assert(isfile(modelFile), ...
    'Run build_vy_dekf_v1_model before configuring the lateral case.');

addpath(fullfile(repoRoot, 'matlab'));
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');

load_system('simulink');
load_system('Solver_SF');
load_system(modelFile);
[~, modelName] = fileparts(modelFile);

manualSwitch = [modelName '/Manual Switch1'];
assert(strcmp(get_param(manualSwitch, 'sw'), '0'), ...
    'Expected Manual Switch1 sw=0 for the active Mux8 CarSim input branch.');

importMux = [modelName '/Mux8'];
importPorts = get_param(importMux, 'PortHandles');
assert(numel(importPorts.Inport) == 12, ...
    'Mux8 must contain the 12 CarSim import channels after road-height inputs.');

newNames = {'D-EKF Test Time', 'D-EKF Lateral Profile', ...
    'D-EKF Steer rad2deg', 'D-EKF Steer Demux'};
for k = 1:numel(newNames)
    assert(isempty(find_system(modelName, 'SearchDepth', 1, ...
        'Name', newNames{k})), ...
        'Lateral-case block already exists: %s', newNames{k});
end

muxPosition = get_param(importMux, 'Position');
x = muxPosition(1);
y = muxPosition(2);
clockPath = [modelName '/D-EKF Test Time'];
profilePath = [modelName '/D-EKF Lateral Profile'];
gainPath = [modelName '/D-EKF Steer rad2deg'];
demuxPath = [modelName '/D-EKF Steer Demux'];

add_block('simulink/Sources/Digital Clock', clockPath, ...
    'Position', [x-520, y+180, x-470, y+210], ...
    'SampleTime', '0.001');
estimatorTemplate = [modelName '/Vy D-EKF 100Hz/vy_dynamic_ekf'];
add_block(estimatorTemplate, profilePath, ...
    'Position', [x-430, y+165, x-300, y+225], ...
    'MATLABFcn', 'vy_dekf_v1_steer_profile(u)', ...
    'OutputDimensions', '4', ...
    'SampleTime', '0.001');
add_block('simulink/Math Operations/Gain', gainPath, ...
    'Position', [x-260, y+175, x-180, y+215], ...
    'Gain', '180/pi', ...
    'Multiplication', 'Element-wise(K.*u)');
add_block('simulink/Signal Routing/Demux', demuxPath, ...
    'Position', [x-135, y+150, x-130, y+240], ...
    'Outputs', '4');

add_line(modelName, 'D-EKF Test Time/1', 'D-EKF Lateral Profile/1', ...
    'autorouting', 'on');
add_line(modelName, 'D-EKF Lateral Profile/1', ...
    'D-EKF Steer rad2deg/1', 'autorouting', 'on');
add_line(modelName, 'D-EKF Steer rad2deg/1', ...
    'D-EKF Steer Demux/1', 'autorouting', 'on');

steeringImportPorts = [2, 4, 6, 8];
incomingLines = zeros(size(steeringImportPorts));
for k = 1:numel(steeringImportPorts)
    incomingLines(k) = get_param(importPorts.Inport(steeringImportPorts(k)), ...
        'Line');
end
incomingLines = unique(incomingLines(incomingLines >= 0));
for k = 1:numel(incomingLines)
    delete_line(incomingLines(k));
end

for k = 1:4
    add_line(modelName, sprintf('D-EKF Steer Demux/%d', k), ...
        sprintf('Mux8/%d', steeringImportPorts(k)), 'autorouting', 'on');
end

save_system(modelName, modelFile);
close_system(modelName, 0);
close_system('Solver_SF', 0);

report = struct();
report.modelFile = modelFile;
report.activeImportBranch = 'Mux8 via Manual Switch1 sw=0';
report.steeringImportPorts = steeringImportPorts;
report.profile = '0.02 rad, 0.4 Hz, 3-13 s, 0.5 s raised-cosine ramps';
report.commandOrder = {'FL', 'FR', 'RL', 'RR'};
report.commandUnitsBeforeGain = 'rad';
report.carSimImportUnitsAfterGain = 'deg';

fprintf('LATERAL_CASE_OK|model=%s\n', modelFile);
fprintf('ACTIVE_BRANCH|Mux8|switch=0\n');
fprintf('STEER_PROFILE|amp=0.02 rad|freq=0.4 Hz|window=[3 13] s\n');
fprintf('IMPORT_PORTS|FL=2|FR=4|RL=6|RR=8|gain=180/pi\n');
end
