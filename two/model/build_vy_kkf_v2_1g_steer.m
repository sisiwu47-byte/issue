function build = build_vy_kkf_v2_1g_steer()
%BUILD_VY_KKF_V2_1G_STEER Build the isolated G0 active-steer copy only.
% The only actuator-path changes are a radian sine source into existing
% Gain22 and selection of the already-present CarSim test-input leg.

root = fileparts(fileparts(mfilename('fullpath')));
sourceFile = fullfile(root, 'model', 'vx_vy_kkf_v2_1.slx');
targetFile = fullfile(root, 'model', 'vx_vy_kkf_v2_1g_steer.slx');
runPar = 'D:\carsim\CarSim2021.0_Data\Results\Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517\Run_all.par';
solverDir = 'D:\carsim\CarSim2021.0_Prog\Programs\solvers';
solverSfDir = fullfile(solverDir, 'Matlab84+');
assert(isfile(sourceFile), 'Frozen V2.1 model is missing.');
assert(isfile(runPar), 'Active CarSim Run_all.par is missing.');

build = struct();
build.stage = 'V2.1-G0 active steering injection build';
build.frozenHashBefore = file_sha256(sourceFile);
build.carSimImportOrder = import_order(runPar);
assert(isequal(build.carSimImportOrder, {'IMP_ZGND_L1','IMP_ZGND_R1', ...
    'IMP_ZGND_L2','IMP_ZGND_R2','IMP_MYUSM_L1','IMP_STEER_L1', ...
    'IMP_MYUSM_R1','IMP_STEER_R1','IMP_MYUSM_L2','IMP_STEER_L2', ...
    'IMP_MYUSM_R2','IMP_STEER_R2','IMP_FS_L1','IMP_FS_R1', ...
    'IMP_FS_L2','IMP_FS_R2'}), 'Active CarSim import order is not the audited 16-port order.');

copyfile(sourceFile, targetFile, 'f');
addpath(solverDir); addpath(solverSfDir); addpath(fullfile(root, 'model'));
Simulink.fileGenControl('set', 'CacheFolder', fullfile(tempdir, 'vy_kkf_v2_1g0_cache'), ...
    'CodeGenFolder', fullfile(tempdir, 'vy_kkf_v2_1g0_codegen'), 'createDir', true);
load_system('Solver_SF'); load_system(targetFile);
[~, mdl] = fileparts(targetFile);
cleanup = onCleanup(@() close_loaded(mdl));

gain = [mdl '/Gain22']; mux8 = [mdl '/Mux8']; sw = [mdl '/Manual Switch1'];
mux7 = [mdl '/Mux7']; car = [mdl '/CarSim S-Function'];
assert(strcmp(get_param(gain, 'Gain'), '180/pi'), 'Gain22 is not 180/pi.');
assert(numel(get_param(mux8, 'PortHandles').Inport) == 12, 'Mux8 must have 12 inputs.');
assert(isequal(str2num(get_param(mux7, 'Inputs')), [4 12]), 'Mux7 must be [4,12].'); %#ok<ST2NM>
assert_ports(gain, 1, mux8, [2 4]);
assert_ports(mux8, 1, sw, 2);
assert_ports(sw, 1, mux7, 2);
assert_ports(mux7, 1, car, 1);
assert_constant_zero(mux8, 6); assert_constant_zero(mux8, 8);

% Gain22 has no frozen input branch.  The new source is therefore the sole
% radian command and the only rad-to-deg conversion is Gain22 itself.
gainIn = get_param(gain, 'PortHandles');
assert(get_param(gainIn.Inport(1), 'Line') == -1, ...
    'Gain22 input is unexpectedly already connected in the frozen model.');
src = [mdl '/G0 Steer Cmd Rad'];
add_block('simulink/Sources/Sine Wave', src, 'Position', [1190 1030 1255 1060], ...
    'Amplitude', 'test_steer_amplitude', 'Frequency', '2*pi*test_steer_frequency', ...
    'Phase', '0', 'Bias', '0', 'SampleTime', '0');
connect_blocks(mdl, src, 1, gain, 1);

% Manual Switch1 input 1 is Mux5 and input 2 is Mux8.  Runtime evidence
% from G0 showed sw=1 selected input 1/Mux5, so sw=0 is the deterministic
% selection for input 2/Mux8 -- the audited direct CarSim test-vector leg.
build.manualSwitchBefore = struct('sw', get_param(sw, 'sw'), ...
    'currentSetting', get_param(sw, 'CurrentSetting'));
set_param(sw, 'sw', '0');
build.manualSwitchAfter = struct('sw', get_param(sw, 'sw'), ...
    'currentSetting', get_param(sw, 'CurrentSetting'));
assert(strcmp(build.manualSwitchAfter.sw, '0') && ...
    strcmp(build.manualSwitchAfter.currentSetting, '0'), ...
    'Manual Switch1 did not select input 2/Mux8.');
build.manualSwitchSelectedInput = 2;
build.manualSwitchSelectedSource = mux8;

% Non-invasive logging fan-outs.  The demux sees exactly the same Mux7
% vector that enters the CarSim S-Function; ports 6/8/10/12 are steering.
add_toworkspace(mdl, src, 1, 'steer_cmd_rad', [1090 1000 1170 1025]);
add_toworkspace(mdl, gain, 1, 'steer_to_carsim_deg', [1400 1065 1490 1090]);
demux = [mdl '/G0 CarSim Input Demux'];
add_block('simulink/Signal Routing/Demux', demux, 'Outputs', '16', ...
    'Position', [1710 1030 1715 1235]);
connect_blocks(mdl, mux7, 1, demux, 1);
add_toworkspace(mdl, demux, 6, 'steer_fl_carsim_deg', [1745 1050 1855 1075]);
add_toworkspace(mdl, demux, 8, 'steer_fr_carsim_deg', [1745 1090 1855 1115]);
add_toworkspace(mdl, demux, 10, 'steer_rl_carsim_deg', [1745 1130 1855 1155]);
add_toworkspace(mdl, demux, 12, 'steer_rr_carsim_deg', [1745 1170 1855 1195]);
add_toworkspace(mdl, [mdl '/K-KF Reset First Call'], 1, 'reset_g0', [3580 1380 3670 1405]);
avz = unique_signal_source(mdl, 'AVz_IMU');
add_toworkspace(mdl, avz, 1, 'avz_imu_g0', [3350 900 3440 925]);

save_system(mdl, targetFile); close_system(mdl, 0); close_system('Solver_SF', 0);
clear cleanup
build.frozenHashAfter = file_sha256(sourceFile);
assert(strcmp(build.frozenHashBefore, build.frozenHashAfter), 'Frozen V2.1 model hash changed.');
build.targetFile = targetFile; build.targetHash = file_sha256(targetFile);
build.gain22 = '180/pi'; build.gain22Destinations = {'Mux8/2','Mux8/4'};
build.carsimSteerPorts = struct('FL', 6, 'FR', 8, 'RL', 10, 'RR', 12, ...
    'units', 'deg', 'nearCarSimLogging', true);
build.activeTestPath = {src, gain, 'Mux8/2,4', 'Manual Switch1/input2', 'Mux7', car};
build.onlyRadToDegConversion = true;
build.logVariables = {'steer_cmd_rad','steer_to_carsim_deg','steer_fl_carsim_deg', ...
    'steer_fr_carsim_deg','steer_rl_carsim_deg','steer_rr_carsim_deg', ...
    'avz_imu_g0','reset_g0','kkf_u_log1','kkf_x_log1','kkf_P_log1','kkf_diag_log1'};
end

function assert_ports(src, outNo, dst, expected)
p = get_param(src, 'PortHandles'); l = get_param(p.Outport(outNo), 'Line');
assert(l ~= -1, 'Unconnected required path source: %s', src);
dh = get_param(l, 'DstPortHandle'); got = [];
for k=1:numel(dh), if strcmp(getfullname(get_param(dh(k),'Parent')), dst), got(end+1)=get_param(dh(k),'PortNumber'); end, end %#ok<AGROW>
assert(isequal(sort(got), sort(expected)), 'Required path mismatch: %s -> %s.', src, dst);
end

function assert_constant_zero(mux, port)
p=get_param(mux,'PortHandles'); l=get_param(p.Inport(port),'Line');
assert(l~=-1, 'Required rear steer input is disconnected.');
src=get_param(l,'SrcBlockHandle');
assert(strcmp(get_param(src,'BlockType'),'Constant') && strcmp(strtrim(get_param(src,'Value')),'0'), ...
    'Rear steer test-vector input %d is not frozen zero.', port);
end

function source = unique_signal_source(mdl, name)
lines=find_system(mdl,'FindAll','on','Type','line'); sources={};
for k=1:numel(lines), try, if strcmp(get_param(lines(k),'Name'),name), h=get_param(lines(k),'SrcBlockHandle'); if h>0, sources{end+1}=getfullname(h); end, end, catch, end, end %#ok<AGROW>
sources=unique(sources); assert(numel(sources)==1,'Signal %s must have one source.',name); source=sources{1};
end

function add_toworkspace(mdl, src, port, variable, pos)
blk=[mdl '/' variable]; add_block('simulink/Sinks/To Workspace',blk,'Position',pos, ...
    'VariableName',variable,'SaveFormat','Timeseries','MaxDataPoints','100000');
connect_blocks(mdl,src,port,blk,1);
end

function connect_blocks(mdl, src, srcPort, dst, dstPort)
srcHandles=get_param(src,'PortHandles'); dstHandles=get_param(dst,'PortHandles');
add_line(mdl,srcHandles.Outport(srcPort),dstHandles.Inport(dstPort),'autorouting','on');
end

function order=import_order(file)
t=fileread(file); order=regexp(t,'(?m)^IMPORT\s+(IMP_[A-Z0-9_]+)\s','tokens'); order=cellfun(@(x)x{1},order,'UniformOutput',false);
end

function h=file_sha256(file)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(file)); ds=java.security.DigestInputStream(s,d);
c=onCleanup(@()ds.close()); while ds.read()~=-1,end
b=typecast(d.digest(),'uint8'); h=lower(reshape(dec2hex(b,2).',1,[])); clear c
end

function close_loaded(mdl)
if bdIsLoaded(mdl), close_system(mdl,0); end; if bdIsLoaded('Solver_SF'), close_system('Solver_SF',0); end
end
