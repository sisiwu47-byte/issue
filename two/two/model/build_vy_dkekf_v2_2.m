function buildReport = build_vy_dkekf_v2_2()
%BUILD_VY_DKEKF_V2_2 Explicitly build the isolated V2.2-C target model.
% This builder copies a frozen source, edits only the new target, and saves
% it. It does not update/compile the diagram and does not run simulation.

root = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(root,'model');
sourceFile = fullfile(modelDir,'vx_vy_kkf_v2_1.slx');
targetFile = fullfile(modelDir,'vx_vy_dkekf_v2_2.slx');
resultFile = fullfile(root,'results','vy_dkekf_v2_2c1_integration.mat');
adapterFile = fullfile(modelDir,'vy_dkekf_baseline_simulink_sfun.m');
adapterExpectedHash = ...
    '12f0d82643d65aa5098ed20c0655234f3a2e7ef6d6f5e7dee5b80bc1a201bda1';

[frozenFiles, expectedHashes] = frozen_manifest(root);
for k = 1:numel(frozenFiles)
    assert(isfile(frozenFiles{k}), 'Required frozen file missing: %s', frozenFiles{k});
end
before = snapshot(frozenFiles);
assert_expected(before, expectedHashes);
adapterBefore = file_record(adapterFile);
assert(strcmp(adapterBefore.sha256,adapterExpectedHash), ...
    'Accepted Level-2 S-function adapter hash mismatch.');

copyfile(sourceFile,targetFile,'f');
addpath(modelDir);
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set','CacheFolder', ...
    fullfile(tempdir,'vy_dkekf_v2_2c_build_cache'),'CodeGenFolder', ...
    fullfile(tempdir,'vy_dkekf_v2_2c_build_codegen'),'createDir',true);
load_system('simulink');
load_system('Solver_SF');
load_system(targetFile);
[~,modelName] = fileparts(targetFile);

axSource = unique_signal_source(modelName,'Ax_IMU');
aySource = unique_signal_source(modelName,'Ay_IMU');
avzSource = unique_signal_source(modelName,'AVz_IMU');
vxSource = [modelName '/Gain38'];
steeringSource = [modelName '/Mux11'];
assert(getSimulinkBlockHandle(vxSource)>0 && ...
    strcmp(get_param(vxSource,'Gain'),'1/3.6'), ...
    'Frozen true-Vx measurement source Gain38 is unresolved.');
assert(getSimulinkBlockHandle(steeringSource)>0, ...
    'Frozen D-EKF four-wheel steering source Mux11 is unresolved.');
steerPorts = get_param(steeringSource,'PortHandles');
assert(numel(steerPorts.Inport)==4, 'Mux11 must contain four steering inputs.');
steeringInputSources = cell(4,1);
steeringGotoTags = cell(4,1);
for k = 1:4
    steeringInputSources{k} = source_of_port(steerPorts.Inport(k));
    if strcmp(get_param(steeringInputSources{k},'BlockType'),'From')
        steeringGotoTags{k} = get_param(steeringInputSources{k},'GotoTag');
    else
        steeringGotoTags{k} = '';
    end
end

names = {'DK-EKF Baseline','DK-EKF 100Hz Scheduler', ...
    'DK-EKF Vx RT 100Hz','DK-EKF Steering RT 100Hz', ...
    'DK-EKF Steering Demux','DK-EKF Ay 20Hz Pulse', ...
    'DK-EKF Reset First Call','DK-EKF Input Log Mux', ...
    'DK-EKF u Log','DK-EKF x Log','DK-EKF P Log','DK-EKF diag Log'};
for k = 1:numel(names)
    assert(isempty(find_system(modelName,'SearchDepth',1,'Name',names{k})), ...
        'Target integration block already exists: %s',names{k});
end

subPath = [modelName '/DK-EKF Baseline'];
schedulerPath = [modelName '/DK-EKF 100Hz Scheduler'];
vxRtPath = [modelName '/DK-EKF Vx RT 100Hz'];
steerRtPath = [modelName '/DK-EKF Steering RT 100Hz'];
steerDemuxPath = [modelName '/DK-EKF Steering Demux'];
ayPulsePath = [modelName '/DK-EKF Ay 20Hz Pulse'];
resetPath = [modelName '/DK-EKF Reset First Call'];
inputLogMuxPath = [modelName '/DK-EKF Input Log Mux'];
uLogPath = [modelName '/DK-EKF u Log'];
xLogPath = [modelName '/DK-EKF x Log'];
pLogPath = [modelName '/DK-EKF P Log'];
diagLogPath = [modelName '/DK-EKF diag Log'];

add_block('simulink/Ports & Subsystems/Function-Call Subsystem',subPath, ...
    'Position',[4200 1080 4410 1320]);
add_block('simulink/Ports & Subsystems/Function-Call Generator',schedulerPath, ...
    'Position',[3940 1010 4070 1045],'sample_time','0.01', ...
    'numberOfIterations','1');
add_block('simulink/Signal Attributes/Rate Transition',vxRtPath, ...
    'Position',[3840 1195 3970 1225],'OutPortSampleTime','0.01', ...
    'Integrity','on','Deterministic','on','InitialCondition','0');
add_block('simulink/Signal Attributes/Rate Transition',steerRtPath, ...
    'Position',[3840 1125 3970 1155],'OutPortSampleTime','0.01', ...
    'Integrity','on','Deterministic','on','InitialCondition','0');
add_block('simulink/Signal Routing/Demux',steerDemuxPath, ...
    'Position',[4000 1110 4005 1170],'Outputs','4');
add_block('simulink/Sources/Pulse Generator',ayPulsePath, ...
    'Position',[3910 1270 3980 1300],'Amplitude','1', ...
    'Period','0.05','PulseWidth','20','PhaseDelay','0','SampleTime','0.01');
add_block('simulink/Sources/Step',resetPath, ...
    'Position',[3910 1330 3980 1360],'Time','0.01', ...
    'Before','1','After','0','SampleTime','0.01');
add_block('simulink/Signal Routing/Mux',inputLogMuxPath, ...
    'Position',[4470 1070 4475 1290],'Inputs','10');
add_block('simulink/Sinks/To Workspace',uLogPath, ...
    'Position',[4550 1080 4680 1110], ...
    'VariableName','dkekf_u_log1','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',xLogPath, ...
    'Position',[4550 1180 4680 1210], ...
    'VariableName','dkekf_x_log1','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',pLogPath, ...
    'Position',[4550 1220 4680 1250], ...
    'VariableName','dkekf_P_log1','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',diagLogPath, ...
    'Position',[4550 1260 4680 1290], ...
    'VariableName','dkekf_diag_log1','SaveFormat','Timeseries');

internalLines = find_system(subPath,'FindAll','on','SearchDepth',1,'Type','line');
for k = 1:numel(internalLines), delete_line(internalLines(k)); end
set_param([subPath '/In1'],'Name','Ax_IMU','Port','1','Position',[25 65 55 81]);
set_param([subPath '/Out1'],'Name','x_hat','Port','1','Position',[440 70 470 90]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/steering'], ...
    'Port','2','Position',[25 100 55 116]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/z_Vx'], ...
    'Port','3','Position',[25 135 55 151]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/z_r'], ...
    'Port','4','Position',[25 170 55 186]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/z_Ay'], ...
    'Port','5','Position',[25 205 55 221]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/doAyUpdate'], ...
    'Port','6','Position',[25 240 55 256]);
add_block('simulink/Ports & Subsystems/In1',[subPath '/resetFlag'], ...
    'Port','7','Position',[25 275 55 291]);
add_block('simulink/Ports & Subsystems/Out1',[subPath '/P'], ...
    'Port','2','Position',[440 125 470 145]);
add_block('simulink/Ports & Subsystems/Out1',[subPath '/diag_out'], ...
    'Port','3','Position',[440 180 470 200]);
set_param([subPath '/function'],'Position',[205 15 275 45]);

wrapperBlock = [subPath '/DK-EKF Numeric Boundary'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', ...
    wrapperBlock,'FunctionName','vy_dkekf_baseline_simulink_sfun', ...
    'Position',[140 65 350 295]);

add_line(subPath,'Ax_IMU/1','DK-EKF Numeric Boundary/1','autorouting','on');
add_line(subPath,'steering/1','DK-EKF Numeric Boundary/2','autorouting','on');
add_line(subPath,'z_Vx/1','DK-EKF Numeric Boundary/3','autorouting','on');
add_line(subPath,'z_r/1','DK-EKF Numeric Boundary/4','autorouting','on');
add_line(subPath,'z_Ay/1','DK-EKF Numeric Boundary/5','autorouting','on');
add_line(subPath,'doAyUpdate/1','DK-EKF Numeric Boundary/6','autorouting','on');
add_line(subPath,'resetFlag/1','DK-EKF Numeric Boundary/7','autorouting','on');
add_line(subPath,'DK-EKF Numeric Boundary/1','x_hat/1','autorouting','on');
add_line(subPath,'DK-EKF Numeric Boundary/2','P/1','autorouting','on');
add_line(subPath,'DK-EKF Numeric Boundary/3','diag_out/1','autorouting','on');

axPort=get_param(axSource,'PortHandles');ayPort=get_param(aySource,'PortHandles');
avzPort=get_param(avzSource,'PortHandles');vxPort=get_param(vxSource,'PortHandles');
steerSourcePort=get_param(steeringSource,'PortHandles');
vxRtPort=get_param(vxRtPath,'PortHandles');steerRtPort=get_param(steerRtPath,'PortHandles');
steerDemuxPort=get_param(steerDemuxPath,'PortHandles');
ayPulsePort=get_param(ayPulsePath,'PortHandles');resetPort=get_param(resetPath,'PortHandles');
subPort=get_param(subPath,'PortHandles');schedulerPort=get_param(schedulerPath,'PortHandles');
logMuxPort=get_param(inputLogMuxPath,'PortHandles');
uLogPort=get_param(uLogPath,'PortHandles');xLogPort=get_param(xLogPath,'PortHandles');
pLogPort=get_param(pLogPath,'PortHandles');diagLogPort=get_param(diagLogPath,'PortHandles');

add_line(modelName,steerSourcePort.Outport(1),steerRtPort.Inport(1),'autorouting','on');
add_line(modelName,steerRtPort.Outport(1),steerDemuxPort.Inport(1),'autorouting','on');
add_line(modelName,vxPort.Outport(1),vxRtPort.Inport(1),'autorouting','on');
add_line(modelName,axPort.Outport(1),subPort.Inport(1),'autorouting','on');
add_line(modelName,steerRtPort.Outport(1),subPort.Inport(2),'autorouting','on');
add_line(modelName,vxRtPort.Outport(1),subPort.Inport(3),'autorouting','on');
add_line(modelName,avzPort.Outport(1),subPort.Inport(4),'autorouting','on');
add_line(modelName,ayPort.Outport(1),subPort.Inport(5),'autorouting','on');
add_line(modelName,ayPulsePort.Outport(1),subPort.Inport(6),'autorouting','on');
add_line(modelName,resetPort.Outport(1),subPort.Inport(7),'autorouting','on');
add_line(modelName,schedulerPort.Outport(1),subPort.Trigger(1),'autorouting','on');

add_line(modelName,axPort.Outport(1),logMuxPort.Inport(1),'autorouting','on');
add_line(modelName,ayPort.Outport(1),logMuxPort.Inport(2),'autorouting','on');
add_line(modelName,avzPort.Outport(1),logMuxPort.Inport(3),'autorouting','on');
add_line(modelName,vxRtPort.Outport(1),logMuxPort.Inport(4),'autorouting','on');
add_line(modelName,ayPulsePort.Outport(1),logMuxPort.Inport(5),'autorouting','on');
add_line(modelName,resetPort.Outport(1),logMuxPort.Inport(6),'autorouting','on');
for k=1:4
    add_line(modelName,steerDemuxPort.Outport(k),logMuxPort.Inport(6+k),'autorouting','on');
end
add_line(modelName,logMuxPort.Outport(1),uLogPort.Inport(1),'autorouting','on');
add_line(modelName,subPort.Outport(1),xLogPort.Inport(1),'autorouting','on');
add_line(modelName,subPort.Outport(2),pLogPort.Inport(1),'autorouting','on');
add_line(modelName,subPort.Outport(3),diagLogPort.Inport(1),'autorouting','on');

save_system(modelName,targetFile);
close_system(modelName,0);close_system('Solver_SF',0);

after=snapshot(frozenFiles);assert_snapshots_equal(before,after);assert_expected(after,expectedHashes);
adapterAfter=file_record(adapterFile);
assert(adapterBefore.bytes==adapterAfter.bytes&& ...
    strcmp(adapterBefore.sha256,adapterAfter.sha256)&& ...
    strcmp(adapterAfter.sha256,adapterExpectedHash), ...
    'Accepted Level-2 S-function adapter changed during build.');
targetRecord=file_record(targetFile);
buildReport=struct('sourceFile',sourceFile,'targetFile',targetFile, ...
    'modelName',modelName,'subsystem',subPath,'wrapperBlock',wrapperBlock, ...
    'scheduler',schedulerPath,'vxRateTransition',vxRtPath, ...
    'steeringRateTransition',steerRtPath,'steeringDemux',steerDemuxPath, ...
    'ayPulse',ayPulsePath,'reset',resetPath,'inputLogMux',inputLogMuxPath, ...
    'axSource',axSource,'aySource',aySource,'avzSource',avzSource, ...
    'vxSource',vxSource,'steeringSource',steeringSource, ...
    'steeringInputSources',{steeringInputSources}, ...
    'steeringGotoTags',{steeringGotoTags}, ...
    'logVariables',{{'dkekf_u_log1','dkekf_x_log1','dkekf_P_log1','dkekf_diag_log1'}}, ...
    'adapterFile',adapterFile,'adapterFunction','vy_dkekf_baseline_simulink_sfun', ...
    'adapterBefore',adapterBefore,'adapterAfter',adapterAfter, ...
    'diagOrdering',{{'NIS_Vx','NIS_r','NIS_Ay','AyUpdateApplied', ...
        'innovation_Vx','innovation_r','innovation_Ay'}}, ...
    'diagWidth',7,'schedulerSampleTime',0.01,'ayPeriod',0.05, ...
    'ayPulseWidthPercent',20,'sourceSteeringUnit','rad', ...
    'frozenBefore',before,'frozenAfter',after,'targetRecord',targetRecord, ...
    'simCalled',false,'carSimRun',false);
save(resultFile,'buildReport');
fprintf('V2_2C_BUILD_OK|source=%s|target=%s|hash=%s\n', ...
    sourceFile,targetFile,targetRecord.sha256);
end

function sourcePath=unique_signal_source(modelName,signalName)
lines=find_system(modelName,'FindAll','on','Type','line');sources={};
for k=1:numel(lines)
    try
        if strcmp(get_param(lines(k),'Name'),signalName)
            h=get_param(lines(k),'SrcBlockHandle');
            if isscalar(h)&&h>0,sources{end+1}=getfullname(h);end %#ok<AGROW>
        end
    catch
    end
end
sources=unique(sources);assert(numel(sources)==1, ...
    'Signal %s must have one unique source.',signalName);sourcePath=sources{1};
end
function source=source_of_port(port)
line=get_param(port,'Line');assert(line>0,'Input port is unconnected.');
source=getfullname(get_param(line,'SrcBlockHandle'));
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx.slx');fullfile(root,'model','vx_ax_imu_prereq_v2_1.slx'); ...
    fullfile(root,'model','vx_vy_dekf_v1_17.slx');fullfile(root,'model','vx_vy_kkf_v2_1.slx'); ...
    fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx');fullfile(root,'model','vy_kinematic_kf_step.m'); ...
    fullfile(root,'model','vy_kinematic_kf.m');fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
    fullfile(root,'model','vy_dkekf_baseline.m')};
hashes={'754a94d85bd50f89ae453c544903dea90b7f9d57d6e7706869f9f674fb0464eb'; ...
    '226238301763460f4b609b0249d61b720c6510dd561923c5d066c33e5967f439'; ...
    '108f819dcd1b71fd6d795d7148cbf32fe1a888ae9878908e894a07626ed003ae'; ...
    'b67a98a6080374304e2d3424f85589c913e6ec4db25bc9912cbfd2bc441c2712'; ...
    '59b25c5e350140ab0eafd8345d5a9145d6981b96481023537a3bd01a787f728e'; ...
    '3786646ee5163d231dd8964614a8875217dfa496eb593b455e4e029e26da2244'; ...
    'f242cb75ba08d22cb1eed87731746cf80d54fd39c1899b45e9980a40576414d4'; ...
    '6475b9dbc93eb6e25c2bb9fad81ca11b2e08c26e7f2ae6a33c50e35b2790b457'; ...
    '7e731d7df0bb2ca4455e3aa16e7513114e04472d38c62f1f453b631056306973'};
end
function s=snapshot(paths)
s=repmat(struct('path','','bytes',0,'modifiedDatenum',0,'sha256',''),numel(paths),1);
for k=1:numel(paths),s(k)=file_record(paths{k});end
end
function r=file_record(path)
d=dir(path);r=struct('path',path,'bytes',d.bytes, ...
    'modifiedDatenum',d.datenum,'sha256',file_sha256(path));
end
function assert_expected(records,expected)
for k=1:numel(records),assert(strcmp(records(k).sha256,expected{k}), ...
    'Frozen hash mismatch: %s',records(k).path);end
end
function assert_snapshots_equal(a,b)
for k=1:numel(a),assert(a(k).bytes==b(k).bytes&& ...
    strcmp(a(k).sha256,b(k).sha256),'Frozen file changed: %s',a(k).path);end
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=lower(reshape(dec2hex(bytes,2).',1,[]));clear c
end
