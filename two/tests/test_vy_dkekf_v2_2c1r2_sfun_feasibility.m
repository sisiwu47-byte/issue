function report = test_vy_dkekf_v2_2c1r2_sfun_feasibility()
%TEST_VY_DKEKF_V2_2C1R2_SFUN_FEASIBILITY Compile-only isolated harness.
% No project model is loaded or saved, and no time-advance simulation runs.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
resultFile = fullfile(root,'results','vy_dkekf_v2_2c1r2_sfun_feasibility.mat');
addpath(modelDir);

core = fullfile(modelDir,'vy_dkekf_baseline_step.m');
wrapper = fullfile(modelDir,'vy_dkekf_baseline.m');
adapter = fullfile(modelDir,'vy_dkekf_baseline_simulink_sfun.m');
target = fullfile(modelDir,'vx_vy_dkekf_v2_2.slx');
expectedCore = '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457';
expectedWrapper = '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973';
expectedTarget = 'de3ddadddad7953640547914e809da7b6a5c3fb261ae211ff255b06a74b09dcf';

before = hash_files({core,wrapper,target});
assert(strcmp(before(1).sha256,expectedCore),'Frozen core hash mismatch.');
assert(strcmp(before(2).sha256,expectedWrapper),'Frozen wrapper hash mismatch.');
assert(strcmp(before(3).sha256,expectedTarget),'Frozen target hash mismatch.');

source = fileread(adapter);
semantics = audit_source(source);
assert(semantics.safe,semantics.reason);

report = struct('stage','V2.2-C1R2','option','OPTION 2', ...
    'passed',false,'compileCalled',false,'simCalled',false, ...
    'carSimRun',false,'algorithmRuntimeCalledDuringCompile',false, ...
    'blockRecognized',false,'inputDimensions',{{}},'inputTypes',{{}}, ...
    'xDimension',[],'pDimension',[],'diagDimension',[], ...
    'xType','','pType','','diagType','','diagLength',7, ...
    'diagOrdering',{{'NIS_Vx','NIS_r','NIS_Ay','AyUpdateApplied', ...
        'innovation_Vx','innovation_r','innovation_Ay'}}, ...
    'executionSemantics',semantics,'compileErrorIdentifier','', ...
    'compileErrorMessage','','compileErrorReport','', ...
    'frozenBefore',before,'adapterBefore',file_record(adapter));

h = 'vy_dkekf_v2_2c1r2_sfun_harness';
if bdIsLoaded(h), close_system(h,0); end
load_system('simulink');
new_system(h);
cleanup = onCleanup(@()close_harness(h));
try
    sub = [h '/Function-Call DK-EKF Boundary'];
    gen = [h '/100 Hz Scheduler'];
    add_block('simulink/Ports & Subsystems/Function-Call Subsystem',sub, ...
        'Position',[260 50 560 340]);
    add_block('simulink/Ports & Subsystems/Function-Call Generator',gen, ...
        'Position',[40 15 180 45],'sample_time','0.01', ...
        'numberOfIterations','1');
    configure_subsystem(sub);

    values = {'0','zeros(4,1)','20','0','0','1','1'};
    for k = 1:7
        b = [h sprintf('/input_%d',k)];
        add_block('simulink/Sources/Constant',b,'Value',values{k}, ...
            'OutDataTypeStr','double','Position',[40 55+35*k 120 75+35*k]);
        add_line(h,sprintf('input_%d/1',k), ...
            sprintf('Function-Call DK-EKF Boundary/%d',k),'autorouting','on');
    end
    for k = 1:3
        b = [h sprintf('/output_%d_term',k)];
        add_block('simulink/Sinks/Terminator',b, ...
            'Position',[640 100+70*k 660 120+70*k]);
        add_line(h,sprintf('Function-Call DK-EKF Boundary/%d',k), ...
            sprintf('output_%d_term/1',k),'autorouting','on');
    end
    gp = get_param(gen,'PortHandles');
    sp = get_param(sub,'PortHandles');
    add_line(h,gp.Outport(1),sp.Trigger(1),'autorouting','on');

    sfun = [sub '/Interpreted Numeric Boundary'];
    report.blockRecognized = strcmp(get_param(sfun,'FunctionName'), ...
        'vy_dkekf_baseline_simulink_sfun');
    report.compileCalled = true;
    feval(h,[],[],[],'compile');

    sfunPorts = get_param(sfun,'PortHandles');
    report.inputDimensions = cell(1,7);
    report.inputTypes = cell(1,7);
    for k = 1:7
        report.inputDimensions{k} = compiled_shape(sfunPorts.Inport(k));
        report.inputTypes{k} = get_param(sfunPorts.Inport(k),'CompiledPortDataType');
    end
    report.xDimension = compiled_shape(sfunPorts.Outport(1));
    report.pDimension = compiled_shape(sfunPorts.Outport(2));
    report.diagDimension = compiled_shape(sfunPorts.Outport(3));
    report.xType = get_param(sfunPorts.Outport(1),'CompiledPortDataType');
    report.pType = get_param(sfunPorts.Outport(2),'CompiledPortDataType');
    report.diagType = get_param(sfunPorts.Outport(3),'CompiledPortDataType');
    expectedInputs = {1,[4 1],1,1,1,1,1};
    report.passed = report.blockRecognized && ...
        shapes_equal(report.inputDimensions,expectedInputs) && ...
        all(strcmp(report.inputTypes,'double')) && ...
        shape_equal(report.xDimension,[3 1]) && ...
        shape_equal(report.pDimension,[3 3]) && ...
        shape_equal(report.diagDimension,[7 1]) && ...
        all(strcmp({report.xType,report.pType,report.diagType},'double')) && ...
        semantics.safe;
    feval(h,[],[],[],'term');
catch ME
    report.compileErrorIdentifier = ME.identifier;
    report.compileErrorMessage = ME.message;
    report.compileErrorReport = getReport(ME,'extended','hyperlinks','off');
end
clear cleanup
close_harness(h);

report.frozenAfter = hash_files({core,wrapper,target});
report.frozenUnchanged = records_equal(report.frozenBefore,report.frozenAfter) && ...
    strcmp(report.frozenAfter(1).sha256,expectedCore) && ...
    strcmp(report.frozenAfter(2).sha256,expectedWrapper) && ...
    strcmp(report.frozenAfter(3).sha256,expectedTarget);
report.adapterAfter = file_record(adapter);
report.adapterUnchangedDuringCompile = records_equal( ...
    report.adapterBefore,report.adapterAfter);
report.adapterHash = report.adapterAfter.sha256;
report.passed = report.passed && report.frozenUnchanged && ...
    report.adapterUnchangedDuringCompile && ~report.simCalled && ...
    ~report.carSimRun && ~report.algorithmRuntimeCalledDuringCompile;
save(resultFile,'report');
fprintf(['V2_2C1R2_SFUN|passed=%d|compileCalled=%d|recognized=%d|' ...
    'x=%s|P=%s|diag=%s|frozenUnchanged=%d|simCalled=%d|' ...
    'carSimRun=%d|error=%s\n'],report.passed,report.compileCalled, ...
    report.blockRecognized,mat2str(report.xDimension), ...
    mat2str(report.pDimension),mat2str(report.diagDimension), ...
    report.frozenUnchanged,report.simCalled,report.carSimRun, ...
    report.compileErrorIdentifier);
end

function configure_subsystem(sub)
contents = find_system(sub,'SearchDepth',1,'Type','Block');
for k = 1:numel(contents)
    if strcmp(contents{k},sub), continue; end
    if strcmp(get_param(contents{k},'BlockType'),'TriggerPort'), continue; end
    delete_block(contents{k});
end

inputNames = {'Ax_IMU','steering','z_Vx','z_r','z_Ay','doAyUpdate','resetFlag'};
for k = 1:7
    add_block('simulink/Ports & Subsystems/In1',[sub '/' inputNames{k}], ...
        'Port',num2str(k),'Position',[30 25+35*k 60 39+35*k]);
end
sfun = [sub '/Interpreted Numeric Boundary'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',sfun, ...
    'FunctionName','vy_dkekf_baseline_simulink_sfun', ...
    'Position',[135 70 340 275]);
outputNames = {'x','P','diag'};
for k = 1:3
    add_block('simulink/Ports & Subsystems/Out1',[sub '/' outputNames{k}], ...
        'Port',num2str(k),'Position',[410 85+65*k 440 99+65*k]);
end
for k = 1:7
    add_line(sub,[inputNames{k} '/1'], ...
        sprintf('Interpreted Numeric Boundary/%d',k),'autorouting','on');
end
for k = 1:3
    add_line(sub,sprintf('Interpreted Numeric Boundary/%d',k), ...
        [outputNames{k} '/1'],'autorouting','on');
end
end

function audit = audit_source(source)
outputsStart = regexp(source,'function outputs\(block\)','once');
updateStart = regexp(source,'function update\(block\)','once');
configStart = regexp(source,'function \[par, cfg, Ts, P0\]','once');
outputsText = source(outputsStart:updateStart-1);
updateText = source(updateStart:configStart-1);
callsFrozenCore = contains(outputsText,'vy_dkekf_baseline_step(');
callsPersistentWrapper = ~isempty(regexp(source, ...
    '(?<!step)\<vy_dkekf_baseline\s*\(','once'));
outputsWritesState = contains(outputsText,'block.Dwork(1).Data =') || ...
    contains(outputsText,'block.Dwork(2).Data =');
updateCommitsState = contains(updateText,'block.Dwork(1).Data =') && ...
    contains(updateText,'block.Dwork(2).Data =');
forbiddenMathTokens = {'dk_dynamics(','dynamics_jacobian(', ...
    'scalar_joseph_update(','ay_value_and_jacobian(','tire_call('};
containsCopiedMath = any(cellfun(@(s)contains(source,s),forbiddenMathTokens));
safe = callsFrozenCore && ~callsPersistentWrapper && ...
    ~outputsWritesState && updateCommitsState && ~containsCopiedMath;
reason = ['Outputs calls the frozen stateless core from a DWork snapshot; ' ...
    'only Update commits x/P, so repeated Outputs evaluations do not ' ...
    'advance committed estimator state.'];
if ~safe
    reason = 'Static execution-semantics audit failed.';
end
audit = struct('safe',safe,'callsFrozenCore',callsFrozenCore, ...
    'callsPersistentWrapper',callsPersistentWrapper, ...
    'outputsWritesState',outputsWritesState, ...
    'updateCommitsState',updateCommitsState, ...
    'containsCopiedEkfMath',containsCopiedMath,'reason',reason);
end

function tf = shapes_equal(actual,expected)
tf = numel(actual)==numel(expected);
for k = 1:numel(expected), tf=tf&&shape_equal(actual{k},expected{k}); end
end
function tf = shape_equal(actual,expected)
tf = isequal(double(actual(:).'),double(expected(:).'));
end
function shape = compiled_shape(port)
d = get_param(port,'CompiledPortDimensions');
if numel(d)>=2 && d(1)==numel(d)-1, shape=d(2:end); else, shape=d; end
if isscalar(shape) && shape==1, shape=1; end
end
function close_harness(h)
if bdIsLoaded(h)
    try, feval(h,[],[],[],'term'); catch, end
    close_system(h,0);
end
end
function r = file_record(path)
d=dir(path);r=struct('path',path,'bytes',d.bytes,'modifiedDatenum',d.datenum, ...
    'sha256',file_sha256(path));
end
function r = hash_files(files)
r=repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''),numel(files),1);
for k=1:numel(files)
    d=dir(files{k});r(k).path=files{k};r(k).bytes=d.bytes;
    r(k).modifiedDatenum=d.datenum;r(k).sha256=file_sha256(files{k});
end
end
function ok = records_equal(a,b)
ok=numel(a)==numel(b);
for k=1:numel(a)
    ok=ok && a(k).bytes==b(k).bytes && strcmp(a(k).sha256,b(k).sha256);
end
end
function hash = file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1, end
bytes=typecast(d.digest(),'uint8');
hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c
end
