function [simIn, cfg] = configure_vx_formal_case_v3(caseId)
%CONFIGURE_VX_FORMAL_CASE_V3 Prepare a V3 case without running simulation.
%
%   [simIn,cfg] = configure_vx_formal_case_v3("VX-ND")
%   [simIn,cfg] = configure_vx_formal_case_v3("VX-ST")
%   [simIn,cfg] = configure_vx_formal_case_v3("VX-DR")
%
% This function never calls sim(), never saves model/vx.slx, and never
% changes the Vx estimator or frozen parameters. It creates a case-specific
% validation copy under results/vx_formal_validation/v3/configured/.
% Controller reference values are in km/h. Do not divide them by 3.6 here;
% the source model's existing Gain15 performs that conversion downstream.

arguments
    caseId (1,1) string
end

caseId = upper(strrep(strtrim(caseId), '_', '-'));
assert(any(caseId == ["VX-ND","VX-ST","VX-DR"]), ...
    'VX:V3:UnknownCase', 'Supported case IDs: VX-ND, VX-ST, VX-DR.');

root = fileparts(fileparts(mfilename('fullpath')));
sourceModel = fullfile(root, 'model', 'vx.slx');
estimatorFile = fullfile(root, 'model', 'longitudinal_velocity_estimator.m');
parameterFile = fullfile(root, 'model', 'estimator_default_params.m');
wrapperFile = fullfile(root, 'model', 'longitudinal_velocity_estimator_simulink.m');

frozen = struct( ...
    'model', '7D01E24D44903C836B4738FBAC480ED039B2188C3C96C4B3218274446F50D516', ...
    'estimator', '68AF9BEABFC44FDFC477E0E3F2296117BB57634C8B45223450C4DB0A1B8E8107', ...
    'parameter', '09B10F2848798785E14D5B370AB02ED23FDEF93BF9F7801BF496142C94CF9DE4', ...
    'wrapper', '93B95A0DF538DB04D66258CC09C8AC852C5154D06030A5BEB08799DAB6113061');
assert(strcmp(sha256_file(sourceModel), frozen.model), ...
    'VX:V3:ModelHash', 'Current model hash differs from the V3 handoff.');
assert(strcmp(sha256_file(estimatorFile), frozen.estimator), ...
    'VX:V3:EstimatorHash', 'Estimator hash differs from the V3 handoff.');
assert(strcmp(sha256_file(parameterFile), frozen.parameter), ...
    'VX:V3:ParameterHash', 'Parameter hash differs from the V3 handoff.');
assert(strcmp(sha256_file(wrapperFile), frozen.wrapper), ...
    'VX:V3:WrapperHash', 'Wrapper hash differs from the V3 handoff.');

profile = case_profile(caseId);
configuredRoot = fullfile(root, 'results', 'vx_formal_validation', ...
    'v3', 'configured', strrep(char(caseId), '-', '_'));
modelDir = fullfile(configuredRoot, 'model');
controlDir = fullfile(configuredRoot, 'carsim_control');
if ~isfolder(modelDir), mkdir(modelDir); end
if ~isfolder(controlDir), mkdir(controlDir); end

caseModelName = ['vx_formal_v3_' strrep(char(caseId), '-', '_')];
caseModelFile = fullfile(modelDir, [caseModelName '.slx']);
if bdIsLoaded(caseModelName), close_system(caseModelName, 0); end
copyfile(sourceModel, caseModelFile, 'f');
load_system(caseModelFile);
cleanupObject = onCleanup(@()close_if_loaded(caseModelName));

% SID 438 is the active km/h reference; the source block may be renamed.
referenceBlock = Simulink.ID.getFullName(sprintf('%s:438', caseModelName));
set_param(referenceBlock, ...
    'TimeValues', mat2str(profile.speedTime_s(:), 17), ...
    'OutValues', mat2str(profile.speed_kmh(:), 17), ...
    'tsamp', '0.001');
set_param(caseModelName, 'StopTime', '16');

% SID 79 is the saved model's unresolved driver_steering source. Replace it
% only in the validation copy and preserve its downstream connection.
steerSource = Simulink.ID.getFullName(sprintf('%s:79', caseModelName));
steerProfile = steering_profile(caseId);
steerSource = replace_steering_source(caseModelName, steerSource, ...
    caseId == "VX-ST");
add_steering_log(caseModelName, steerSource);

[controlSource, expectedMu, sourceHashes] = control_source(root, caseId);
copyfile(fullfile(controlSource, 'simfile.sim'), ...
    fullfile(controlDir, 'simfile.sim'), 'f');
copyfile(fullfile(controlSource, 'Run_all.par'), ...
    fullfile(controlDir, 'Run_all.par'), 'f');
assert(strcmp(sha256_file(fullfile(controlSource, 'simfile.sim')), ...
    sourceHashes.simfile), 'VX:V3:ControlHash', ...
    'Source simfile hash differs from preregistration.');
assert(strcmp(sha256_file(fullfile(controlSource, 'Run_all.par')), ...
    sourceHashes.runAll), 'VX:V3:ControlHash', ...
    'Source Run_all hash differs from preregistration.');

runAllFile = fullfile(controlDir, 'Run_all.par');
controlText = fileread(runAllFile);
actualMu = token_number(controlText, ...
    '(?m)^MU_ROAD_CONSTANT[ \t]+([0-9.]+)[ \t]*(?=\r?$)');
assert(abs(actualMu-expectedMu) < 1e-12, 'VX:V3:MuToken', ...
    'Copied CarSim control has the wrong MU_ROAD_CONSTANT.');
controlText = regexprep(controlText, ...
    '(?m)^TSTOP[ \t]+[^\r\n]+', 'TSTOP 16');
write_text(runAllFile, controlText);

save_system(caseModelName);

simIn = Simulink.SimulationInput(caseModelName);
simIn = simIn.setModelParameter('StopTime', '16', ...
    'ReturnWorkspaceOutputs', 'on');
simIn = simIn.setVariable('vx_v3_steer_profile', steerProfile);

cfg = struct();
cfg.stage = 'VX-V3';
cfg.caseId = char(caseId);
cfg.formalRuntimeCount = 0;
cfg.configurationOnly = true;
cfg.simulationInvoked = false;
cfg.referenceUnit = 'km/h';
cfg.referenceWasDividedBy3p6 = false;
cfg.speedReference = profile;
cfg.steeringProfile = steerProfile;
cfg.sourceModel = sourceModel;
cfg.generatedModel = caseModelFile;
cfg.runtimeWorkingDirectory = controlDir;
cfg.simfile = fullfile(controlDir, 'simfile.sim');
cfg.runAll = runAllFile;
cfg.muRoadConstant = expectedMu;
cfg.frozenSourceHashes = frozen;
cfg.generatedHashes = struct('model', sha256_file(caseModelFile), ...
    'simfile', sha256_file(cfg.simfile), ...
    'runAll', sha256_file(cfg.runAll));
cfg.requiredRuntimeSignals = {'Vx_true_log','est_u_log','est_y_log', ...
    'vx_v3_steer_command_log'};
cfg.runtimeContract = fullfile(root, 'results', 'vx_formal_validation', ...
    'v3', 'runtime_contract.md');
if caseId == "VX-ST"
    cfg.claimCeilingBeforeRuntime = 'STEERING_DYNAMIC_VALIDATION';
    cfg.rearSteeringPhysicalGate = 'NOT_VALIDATED_UNTIL_RUNTIME';
end
save(fullfile(configuredRoot, 'case_configuration.mat'), 'cfg');

fprintf('VX_V3_CONFIGURATION_READY|case=%s|runtime_count=0|model=%s\n', ...
    caseId, caseModelFile);
clear cleanupObject
close_if_loaded(caseModelName);
end

function p = case_profile(caseId)
switch caseId
    case "VX-ND"
        p = struct('speedTime_s',[0;3;7;9;13;16], ...
            'speed_kmh',[60;60;100;100;60;60]);
    case "VX-ST"
        p = struct('speedTime_s',[0;16], 'speed_kmh',[72;72]);
    case "VX-DR"
        p = struct('speedTime_s',[0;3;7;9;13;16], ...
            'speed_kmh',[40;40;70;70;40;40]);
end
end

function p = steering_profile(caseId)
t = (0:0.01:16).';
u = zeros(size(t));
if caseId == "VX-ST"
    localTime = t - 3;
    edges = [0 1.1 2.3 3.6 5.0];
    peaks = [0.025 -0.025 0.022 -0.022];
    for k = 1:4
        idx = localTime >= edges(k) & localTime < edges(k+1);
        u(idx) = peaks(k) .* sin(pi .* (localTime(idx)-edges(k)) ./ ...
            (edges(k+1)-edges(k)));
    end
end
p = [t u];
end

function blockPath = replace_steering_source(modelName, oldBlock, useProfile)
pos = get_param(oldBlock, 'Position');
oldPorts = get_param(oldBlock, 'PortHandles');
lineHandle = get_param(oldPorts.Outport(1), 'Line');
assert(lineHandle ~= -1, 'VX:V3:SteeringRoute', ...
    'SID 79 has no downstream steering route.');
dstPorts = get_param(lineHandle, 'DstPortHandle');
assert(~isempty(dstPorts), 'VX:V3:SteeringRoute', ...
    'SID 79 destination is missing.');
blockName = get_param(oldBlock, 'Name');
delete_line(lineHandle);
delete_block(oldBlock);
blockPath = [modelName '/' blockName];
if useProfile
    add_block('simulink/Sources/From Workspace', blockPath, ...
        'Position', pos, 'VariableName', 'vx_v3_steer_profile');
else
    add_block('simulink/Sources/Constant', blockPath, ...
        'Position', pos, 'Value', '0');
end
newPorts = get_param(blockPath, 'PortHandles');
add_line(modelName, newPorts.Outport(1), dstPorts(1), 'autorouting', 'on');
end

function add_steering_log(modelName, sourceBlock)
logBlock = [modelName '/VX V3 Steer Command Log'];
if getSimulinkBlockHandle(logBlock) ~= -1, delete_block(logBlock); end
pos = get_param(sourceBlock, 'Position');
logPos = [pos(1)+130 pos(2)+45 pos(1)+260 pos(2)+75];
add_block('simulink/Sinks/To Workspace', logBlock, ...
    'Position', logPos, 'VariableName', 'vx_v3_steer_command_log', ...
    'SaveFormat', 'Timeseries');
srcPorts = get_param(sourceBlock, 'PortHandles');
logPorts = get_param(logBlock, 'PortHandles');
add_line(modelName, srcPorts.Outport(1), logPorts.Inport(1), ...
    'autorouting', 'on');
end

function [sourceDir, mu, hashes] = control_source(root, caseId)
hashes.simfile = 'D090D80F3DE31276BE2D4B2FD650EB7A3BFB3507D06BCAAA4BF3D6881ADAAE3A';
if caseId == "VX-DR"
    sourceDir = fullfile(root, 'results', ...
        'vy_lifesig_v2_8a20b_mu03_diagnostic', 'carsim_control_MU03');
    mu = 0.30;
    hashes.runAll = '8C6B8519CF60167A06FB88DE015142F344F062302EEF870BE9B8B4943C7035D8';
else
    sourceDir = fullfile(root, 'results', ...
        'vy_lifesig_v2_8a20_limited_cross_condition', 'carsim_control_C1');
    mu = 0.80;
    hashes.runAll = '1E3F016EEB9D79AA06A013A359C74B32AC94550F07145DA93ED1C698F9AA4BBB';
end
end

function value = token_number(text, expression)
token = regexp(text, expression, 'tokens', 'once');
assert(~isempty(token), 'VX:V3:MissingToken', ...
    'Required CarSim token was not found.');
value = str2double(token{1});
end

function write_text(path, text)
fid = fopen(path, 'wb');
assert(fid >= 0, 'VX:V3:WriteControl', ...
    'Cannot write copied CarSim control: %s', path);
c = onCleanup(@()fclose(fid));
fwrite(fid, unicode2native(text, 'UTF-8'), 'uint8');
clear c
end

function hash = sha256_file(path)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(path));
digestStream = java.security.DigestInputStream(stream, digest);
c = onCleanup(@()digestStream.close());
while digestStream.read() ~= -1, end
hash = upper(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2).', 1, []));
clear c
end

function close_if_loaded(modelName)
if bdIsLoaded(modelName), close_system(modelName, 0); end
end
