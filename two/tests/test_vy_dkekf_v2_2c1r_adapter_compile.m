function report = test_vy_dkekf_v2_2c1r_adapter_compile(caseName)
%TEST_VY_DKEKF_V2_2C1R_ADAPTER_COMPILE Isolated compile-only experiments.
% No project model is loaded or saved. Supported initial experiment: A.

if nargin < 1, caseName = 'A'; end
caseName = upper(char(caseName));
assert(strcmp(caseName,'A'),'Only isolated CASE A is enabled in this revision.');
root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
resultFile = fullfile(root,'results','vy_dkekf_v2_2c1r_adapter_compile.mat');
addpath(modelDir);

frozen = {fullfile(modelDir,'vy_dkekf_baseline_step.m'), ...
    fullfile(modelDir,'vy_dkekf_baseline.m')};
expected = {'6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457', ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'};
target = fullfile(modelDir,'vx_vy_dkekf_v2_2.slx');
beforeFrozen = hash_files(frozen);
assert(all(strcmp({beforeFrozen.sha256},expected)),'Frozen core/wrapper hash mismatch.');
beforeTarget = file_record(target);

report = struct('stage','V2.2-C1R','caseName',caseName,'passed',false, ...
    'requestedOutputs',{{'x','P'}},'infoRequested',false, ...
    'compileCalled',false,'simCalled',false,'carSimRun',false, ...
    'xResolvedDimension',[],'pResolvedDimension',[], ...
    'xResolvedType','','pResolvedType','','errorIdentifier','', ...
    'errorMessage','','errorReport','','frozenBefore',beforeFrozen, ...
    'targetBefore',beforeTarget);

h = 'vy_dkekf_v2_2c1r_case_a_harness';
if bdIsLoaded(h), close_system(h,0); end
load_system('simulink');
new_system(h);
cleanup = onCleanup(@()close_harness(h));
try
    block = [h '/Frozen Wrapper xP Only'];
    add_block('simulink/User-Defined Functions/MATLAB Function',block, ...
        'Position',[260 80 500 300]);
    chart = chart_for_path(block);
    chart.Script = sprintf([ ...
        'function [x_new,P_new] = wrapper_xp_only(Ax_IMU,steering,z_Vx,z_r,z_Ay,doAyUpdate,resetFlag)\n' ...
        '%%#codegen\n' ...
        '[x_new,P_new] = vy_dkekf_baseline(Ax_IMU,steering,z_Vx,z_r,z_Ay,doAyUpdate,resetFlag);\n' ...
        'end\n']);
    set_chart_size(chart,'Ax_IMU','1');
    set_chart_size(chart,'steering','[4 1]');
    set_chart_size(chart,'z_Vx','1');
    set_chart_size(chart,'z_r','1');
    set_chart_size(chart,'z_Ay','1');
    set_chart_size(chart,'doAyUpdate','1');
    set_chart_size(chart,'resetFlag','1');
    set_chart_size(chart,'x_new','[3 1]');
    set_chart_size(chart,'P_new','[3 3]');

    values = {'0','zeros(4,1)','20','0','0','1','1'};
    for k=1:7
        add_block('simulink/Sources/Constant',[h sprintf('/in%d',k)], ...
            'Value',values{k},'Position',[40 50+35*k 110 70+35*k]);
        add_line(h,sprintf('in%d/1',k),sprintf('Frozen Wrapper xP Only/%d',k), ...
            'autorouting','on');
    end
    add_block('simulink/Sinks/Terminator',[h '/x term'], ...
        'Position',[570 130 590 150]);
    add_block('simulink/Sinks/Terminator',[h '/P term'], ...
        'Position',[570 210 590 230]);
    add_line(h,'Frozen Wrapper xP Only/1','x term/1','autorouting','on');
    add_line(h,'Frozen Wrapper xP Only/2','P term/1','autorouting','on');
    clear vy_dkekf_baseline
    report.compileCalled = true;
    feval(h,[],[],[],'compile');
    ports = get_param(block,'PortHandles');
    report.xResolvedDimension = compiled_shape(ports.Outport(1));
    report.pResolvedDimension = compiled_shape(ports.Outport(2));
    report.xResolvedType = get_param(ports.Outport(1),'CompiledPortDataType');
    report.pResolvedType = get_param(ports.Outport(2),'CompiledPortDataType');
    report.passed = isequal(report.xResolvedDimension,3) && ...
        isequal(report.pResolvedDimension,[3 3]) && ...
        strcmp(report.xResolvedType,'double') && strcmp(report.pResolvedType,'double');
    feval(h,[],[],[],'term');
catch ME
    report.errorIdentifier = ME.identifier;
    report.errorMessage = ME.message;
    report.errorReport = getReport(ME,'extended','hyperlinks','off');
end
clear cleanup
close_harness(h);
report.frozenAfter = hash_files(frozen);
report.targetAfter = file_record(target);
report.frozenUnchanged = records_equal(report.frozenBefore,report.frozenAfter) && ...
    all(strcmp({report.frozenAfter.sha256},expected));
report.targetUnchanged = records_equal(report.targetBefore,report.targetAfter);
save(resultFile,'report');
fprintf(['V2_2C1R_CASE_A|passed=%d|compileCalled=%d|x=%s|P=%s|' ...
    'frozenUnchanged=%d|targetUnchanged=%d|error=%s\n'], ...
    report.passed,report.compileCalled,mat2str(report.xResolvedDimension), ...
    mat2str(report.pResolvedDimension),report.frozenUnchanged, ...
    report.targetUnchanged,report.errorIdentifier);
end

function chart=chart_for_path(path)
rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');chart=[];
for k=1:numel(charts),if strcmp(charts(k).Path,path),chart=charts(k);break;end,end
assert(~isempty(chart),'Isolated MATLAB Function chart was not created.');
end
function set_chart_size(chart,name,sizeText)
d=chart.find('-isa','Stateflow.Data','Name',name);
assert(numel(d)==1,'Chart data unresolved: %s',name);d.Props.Array.Size=sizeText;
end
function shape=compiled_shape(port)
d=get_param(port,'CompiledPortDimensions');
if numel(d)>=2&&d(1)==numel(d)-1,shape=d(2:end);else,shape=d;end
end
function close_harness(h)
if bdIsLoaded(h),try,feval(h,[],[],[],'term');catch,end;close_system(h,0);end
end
function r=file_record(path)
d=dir(path);r=struct('path',path,'bytes',d.bytes,'modifiedDatenum',d.datenum, ...
    'sha256',file_sha256(path));
end
function r=hash_files(files)
r=repmat(struct('path','','bytes',0,'sha256',''),numel(files),1);
for k=1:numel(files)
    d=dir(files{k});r(k).path=files{k};r(k).bytes=d.bytes;
    r(k).sha256=file_sha256(files{k});
end
end
function ok=records_equal(a,b)
ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&& ...
    strcmp(a(k).sha256,b(k).sha256);end
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c
end
