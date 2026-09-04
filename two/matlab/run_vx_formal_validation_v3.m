function R = run_vx_formal_validation_v3(caseId)
%RUN_VX_FORMAL_VALIDATION_V3 Execute exactly one preregistered V3 runtime.

arguments
    caseId (1,1) string
end
caseId = upper(strrep(strtrim(caseId), '_', '-'));
assert(any(caseId == ["VX-ND","VX-ST","VX-DR"]), ...
    'VX:V3:UnknownCase', 'Only VX-ND, VX-ST and VX-DR are supported.');

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'matlab'));
addpath(fullfile(root, 'model'));
[simIn, cfg] = configure_vx_formal_case_v3(caseId);

runtimeDir = fullfile(root, 'results', 'vx_formal_validation', 'v3', 'runtime');
if ~isfolder(runtimeDir), mkdir(runtimeDir); end
stem = strrep(char(caseId), '-', '_');
rawFile = fullfile(runtimeDir, [stem '_formal_raw.mat']);
metadataFile = fullfile(runtimeDir, [stem '_metadata.json']);
commitFile = fullfile(runtimeDir, [stem '_runtime_commit.txt']);
consoleFile = fullfile(runtimeDir, [stem '_runtime_console.log']);
assert(~isfile(rawFile) && ~isfile(commitFile), ...
    'VX:V3:RuntimeExists', '%s formal runtime already exists.', caseId);

solverDir = 'D:\carsim\CarSim2021.0_Prog\Programs\solvers';
solverSfDir = fullfile(solverDir, 'Matlab84+');
solverLibrary = fullfile(solverSfDir, 'Solver_SF.slx');
solverDll = fullfile(solverDir, 'carsim_64.dll');
assert(isfile(solverLibrary) && isfile(solverDll), ...
    'VX:V3:CarSimSolverMissing', 'CarSim solver files are missing.');
addpath(solverDir); addpath(solverSfDir);

oldPwd = pwd;
oldPath = path;
[~, modelName] = fileparts(cfg.generatedModel);
cleanupObject = onCleanup(@()cleanup_runtime(modelName, oldPwd, oldPath));
load_system(solverLibrary);
load_system(cfg.generatedModel);
cd(cfg.runtimeWorkingDirectory);

pre = current_hashes(root, cfg);
assert(isequal(pre.source, cfg.frozenSourceHashes), ...
    'VX:V3:PreHash', 'Frozen source hashes changed before runtime.');
provenance = struct('stage','VX-V3','caseId',char(caseId), ...
    'formalRuntime',true,'simInvocationCommitted',true, ...
    'commitTimeLocal',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')), ...
    'profile',cfg.speedReference,'steeringProfile',cfg.steeringProfile, ...
    'sourceHashes',pre.source,'generatedHashes',pre.generated, ...
    'runtimeWorkingDirectory',cfg.runtimeWorkingDirectory);
write_commit(commitFile, provenance);

clear longitudinal_velocity_estimator longitudinal_velocity_estimator_simulink
consoleText = '';
try
    consoleText = evalc("simOut = sim(simIn);");
catch ME
    write_console(consoleFile, consoleText, ME);
    rethrow(ME);
end

names = {'Vx_true_log','est_u_log','est_y_log','vx_v3_steer_command_log'};
logs = struct();
for k = 1:numel(names)
    try
        logs.(names{k}) = simOut.get(names{k});
    catch
        error('VX:V3:MissingSignal', ...
            'SimulationOutput is missing required signal %s.', names{k});
    end
    assert(isa(logs.(names{k}), 'timeseries'), ...
        'VX:V3:SignalType', '%s must be a timeseries.', names{k});
end

t = double(logs.est_y_log.Time(:));
estY = orient_data(double(logs.est_y_log.Data), numel(t), 38, 'est_y_log');
estU0 = orient_data(double(logs.est_u_log.Data), ...
    numel(logs.est_u_log.Time), 18, 'est_u_log');
estU = interp1(double(logs.est_u_log.Time(:)), estU0, t, 'linear', NaN);
vxTrue = interp1(double(logs.Vx_true_log.Time(:)), ...
    double(logs.Vx_true_log.Data(:)), t, 'linear', NaN);
steerCommand = align_scalar_log(logs.vx_v3_steer_command_log, t, 'previous');
assert(size(estU,2)==18 && size(estY,2)==38, ...
    'VX:V3:Interface', 'Aligned estimator interfaces are invalid.');

post = current_hashes(root, cfg);
assert(isequal(pre, post), 'VX:V3:PostHash', ...
    'Source or generated configuration changed during runtime.');

R = struct();
R.metadata = struct('stage','VX-V3','formalRuntime',true, ...
    'caseId',char(caseId),'formalRuntimeCountContribution',1, ...
    'simulationCompleted',true,'simInvocationCommitted',true, ...
    'sourceHashes',pre.source,'generatedHashes',pre.generated, ...
    'postRunHashes',post,'savedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
R.time = t;
R.vxTrue = vxTrue;
R.estU = estU;
R.estY = estY;
R.Ax = estU(:,9);
R.steerCommand = steerCommand;
R.configuration = cfg;
save(rawFile, 'R', '-v7.3');
write_json(metadataFile, R.metadata);
write_console(consoleFile, consoleText, []);

analysis = analyze_vx_formal_validation_v3(caseId); %#ok<NASGU>
fprintf('VX_V3_RUNTIME_PASS|case=%s|raw=%s\n', caseId, rawFile);
clear cleanupObject
cleanup_runtime(modelName, oldPwd, oldPath);
end

function X = orient_data(X, n, width, name)
X = squeeze(X);
if size(X,1) ~= n && size(X,2) == n, X = X.'; end
assert(size(X,1)==n && size(X,2)==width, ...
    'VX:V3:SignalShape', '%s must be N-by-%d.', name, width);
end

function y = align_scalar_log(ts, t, method)
t0=double(ts.Time(:));y0=double(ts.Data(:));
assert(~isempty(y0),'VX:V3:EmptySignal','Required scalar log is empty.');
if numel(t0)==1
    y=repmat(y0(1),size(t));
else
    y=interp1(t0,y0,t,method,'extrap');
end
end

function H = current_hashes(root, cfg)
H.source = struct('model',sha256_file(fullfile(root,'model','vx.slx')), ...
    'estimator',sha256_file(fullfile(root,'model','longitudinal_velocity_estimator.m')), ...
    'parameter',sha256_file(fullfile(root,'model','estimator_default_params.m')), ...
    'wrapper',sha256_file(fullfile(root,'model','longitudinal_velocity_estimator_simulink.m')));
H.generated = struct('model',sha256_file(cfg.generatedModel), ...
    'simfile',sha256_file(cfg.simfile),'runAll',sha256_file(cfg.runAll));
end

function write_commit(file, p)
fid=fopen(file,'wt'); assert(fid>=0,'VX:V3:CommitWrite','Cannot write commit.');
c=onCleanup(@()fclose(fid));
fprintf(fid,'STAGE=VX-V3\nCASE=%s\nSIM_INVOCATION_COMMITTED=YES\n',p.caseId);
fprintf(fid,'FORMAL_RUNTIME_COUNT_CONTRIBUTION=1\nTIME_LOCAL=%s\n',p.commitTimeLocal);
fprintf(fid,'SOURCE_MODEL_SHA256=%s\nESTIMATOR_SHA256=%s\nPARAMETER_SHA256=%s\n', ...
    p.sourceHashes.model,p.sourceHashes.estimator,p.sourceHashes.parameter);
fprintf(fid,'GENERATED_MODEL_SHA256=%s\nRUN_ALL_SHA256=%s\nSIMFILE_SHA256=%s\n', ...
    p.generatedHashes.model,p.generatedHashes.runAll,p.generatedHashes.simfile);
fprintf(fid,'SPEED_TIME_S=%s\nSPEED_REFERENCE_KMH=%s\nREFERENCE_UNIT=km/h\n', ...
    mat2str(p.profile.speedTime_s(:).'),mat2str(p.profile.speed_kmh(:).'));
clear c
end

function write_console(file, text, failure)
if numel(text)>20000, text=text(end-19999:end); end
fid=fopen(file,'wt'); assert(fid>=0,'VX:V3:ConsoleWrite','Cannot write console log.');
c=onCleanup(@()fclose(fid)); fwrite(fid,text);
if ~isempty(failure), fprintf(fid,'\nERROR|%s|%s\n',failure.identifier,failure.message); end
clear c
end

function write_json(file, value)
fid=fopen(file,'wt'); assert(fid>=0,'VX:V3:JsonWrite','Cannot write JSON.');
c=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true)); clear c
end

function hash=sha256_file(file)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(file)); q=java.security.DigestInputStream(s,d);
c=onCleanup(@()q.close()); while q.read()~=-1,end
hash=upper(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[])); clear c
end

function cleanup_runtime(modelName, oldPwd, oldPath)
if bdIsLoaded(modelName), close_system(modelName,0); end
if bdIsLoaded('Solver_SF'), close_system('Solver_SF',0); end
cd(oldPwd); path(oldPath);
end
