function build = build_vy_fixed_fusion_v2_5c()
%BUILD_VY_FIXED_FUSION_V2_5C Build static target and estimator-only harness.
% This builder never compiles a model and never calls sim().

root = fileparts(fileparts(mfilename('fullpath')));
md = fullfile(root,'model');
resultFile = fullfile(root,'results','vy_fixed_fusion_v2_5c_integration_gates.mat');
sourceFile = fullfile(md,'vx_vy_parallel_dk_v2_3.slx');
fDonorFile = fullfile(md,'vx_vy_feedback_track_v2_4.slx');
targetFile = fullfile(md,'vx_vy_fixed_fusion_v2_5.slx');
harnessFile = fullfile(md,'vx_vy_fixed_fusion_v2_5c_compile_harness.slx');
sourceExpected = '98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0';

[frozenFiles,expectedHashes] = frozen_manifest(root);
frozenBefore = snapshot(frozenFiles);
assert(records_match(frozenBefore,expectedHashes), ...
    'A frozen V2.5-C dependency hash differs before build.');
assert(strcmp(file_sha256(sourceFile),sourceExpected), ...
    'Frozen parallel D/K target hash mismatch before build.');

copyfile(sourceFile,targetFile,'f');
addpath(md);
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers');
addpath('D:\carsim\CarSim2021.0_Prog\Programs\solvers\Matlab84+');
Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(tempdir,'vy_fixed_fusion_v2_5c_cache'), ...
    'CodeGenFolder',fullfile(tempdir,'vy_fixed_fusion_v2_5c_codegen'), ...
    'createDir',true);
load_system('simulink');
load_system('Solver_SF');
load_system(fDonorFile);
load_system(targetFile);

target = 'vx_vy_fixed_fusion_v2_5';
fDonor = 'vx_vy_feedback_track_v2_4';
harness = 'vx_vy_fixed_fusion_v2_5c_compile_harness';
if bdIsLoaded(harness), close_system(harness,0); end
cleanup = onCleanup(@()close_models(target,fDonor,harness));

% Add an exact copy of the accepted standalone F execution boundary.
fSub = [target '/F-Track 100Hz'];
fScheduler = [target '/F-Track 100Hz Scheduler'];
assert(getSimulinkBlockHandle(fSub)<0&&getSimulinkBlockHandle(fScheduler)<0, ...
    'F-track blocks unexpectedly exist in the new target copy.');
add_block([fDonor '/F-Track 100Hz'],fSub,'Position',[5200 520 5450 760]);
add_block([fDonor '/F-Track 100Hz Scheduler'],fScheduler, ...
    'Position',[4920 455 5100 490]);

% Shared physical signals fan out to F without estimator-to-estimator paths.
aySource = unique_signal_source(target,'Ay_IMU');
avzSource = unique_signal_source(target,'AVz_IMU');
vxSource = [target '/Gain38'];
assert(getSimulinkBlockHandle(vxSource)>0&& ...
    strcmp(strtrim(get_param(vxSource,'Gain')),'1/3.6'), ...
    'Audited physical Vx isolation source Gain38 is missing or changed.');
fVyPlaceholder = add_const(target,'F Vy Feedback Placeholder',0,0.01,[4700 625 4810 655]);
fPPlaceholder = add_const(target,'F P Feedback Placeholder',0.5,0.01,[4700 675 4810 705]);
fFeedbackValid = add_const(target,'F Feedback Valid Disabled',0,0.01,[4700 725 4810 755]);
fReset = add_step(target,'F Reset First Hit',0.01,1,0,0.01,[4700 775 4810 805]);

connect_trigger(target,fScheduler,fSub);
connect(target,aySource,1,fSub,1);
connect(target,avzSource,1,fSub,2);
connect(target,vxSource,1,fSub,3);
connect(target,fVyPlaceholder,1,fSub,4);
connect(target,fPPlaceholder,1,fSub,5);
connect(target,fFeedbackValid,1,fSub,6);
connect(target,fReset,1,fSub,7);

% Extract only the documented state elements for fixed-weight state fusion.
dSub = [target '/Parallel D-EKF 100Hz'];
dScheduler = [target '/Parallel D-EKF 100Hz Scheduler'];
dOutputDemux = [target '/Parallel D Output Demux'];
kSub = [target '/K-KF 100Hz'];
kScheduler = [target '/K-KF 100Hz Scheduler'];
dSelect = [target '/Fusion D State Select Vy'];
kSelect = [target '/Fusion K State Select Vy'];
fusion = [target '/Fixed Weight D K F Fusion'];
add_block('simulink/Signal Routing/Demux',dSelect,'Outputs','2', ...
    'Position',[5580 140 5585 205]);
add_block('simulink/Signal Routing/Demux',kSelect,'Outputs','2', ...
    'Position',[5580 300 5585 365]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',fusion, ...
    'FunctionName','vy_fixed_weight_fusion_simulink_sfun', ...
    'Parameters','1/3,1/3,1/3','Position',[5840 285 6090 405]);
connect(target,dOutputDemux,1,dSelect,1);
connect(target,kSub,1,kSelect,1);
connect(target,dSelect,1,fusion,1);
connect(target,kSelect,2,fusion,2);
connect(target,fSub,1,fusion,3);

% Explicit observation-only logging boundaries for future same-run validation.
dVyLog = add_ws(target,dSelect,1,'fusion_vy_d_log',[6180 120 6350 150]);
kVyLog = add_ws(target,kSelect,2,'fusion_vy_k_log',[6180 180 6350 210]);
fVyLog = add_ws(target,fSub,1,'fusion_vy_f_log',[6180 240 6350 270]);
fPLog = add_ws(target,fSub,2,'fusion_f_P_log',[6180 440 6350 470]);
fDiagLog = add_ws(target,fSub,3,'fusion_f_diag_log',[6180 500 6350 530]);
fwLog = add_ws(target,fusion,1,'fusion_vy_fw_log',[6180 330 6350 360]);
add_term(target,dSelect,2,'Fusion D r Terminator',[5700 195 5720 215]);
add_term(target,kSelect,1,'Fusion K Vx Terminator',[5700 300 5720 320]);

description = sprintf([get_param(target,'Description') '\n' ...
    'V2.5 FIXED-WEIGHT INTEGRATION TARGET. Fusion weights [1/3 1/3 1/3] are TEST-ONLY, ' ...
    'NOT SELECTED BASELINE WEIGHTS, NOT TUNED, and NOT FROZEN. ' ...
    'F P0_F=0.5 and Q_F=0.0025 remain TEST-ONLY, UNTUNED, and UNFROZEN. ' ...
    'F feedback_valid_current is fixed false; Vy_FW is observation-only and is not fed back.']);
set_param(target,'Description',description);
save_system(target,targetFile);

% Estimator-only harness: exact estimator boundaries copied from the newly
% built target; no vehicle plant, CarSim, or vs_sf is present.
new_system(harness);
set_param(harness,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','0.001','StartTime','0','StopTime','0.1');
copies = { ...
    'Parallel D-EKF 100Hz',          [760 120 990 270]; ...
    'Parallel D-EKF 100Hz Scheduler',[500 45 675 80]; ...
    'Parallel D-EKF Input RT 100Hz', [530 210 700 245]; ...
    'Parallel D Control Mux',        [390 150 395 220]; ...
    'Parallel D Measurement Mux',    [390 280 395 340]; ...
    'Parallel D Input Mux',          [455 160 460 330]; ...
    'Parallel D Output Demux',       [1060 120 1065 270]; ...
    'Parallel D Full P Extract',     [1060 315 1065 415]; ...
    'Parallel D P 2x2',              [1170 350 1280 385]; ...
    'K-KF 100Hz',                    [760 520 990 680]; ...
    'K-KF 100Hz Scheduler',          [500 450 675 485]; ...
    'K-KF IMU Mux',                  [500 535 505 620]; ...
    'K-KF Vx RT 100Hz',              [520 650 690 685]; ...
    'K-KF Reset First Call',         [530 715 610 745]; ...
    'F-Track 100Hz',                 [760 835 990 1075]; ...
    'F-Track 100Hz Scheduler',       [500 785 675 820]; ...
    'Fixed Weight D K F Fusion',     [1420 600 1670 720]};
for k=1:size(copies,1)
    add_block([target '/' copies{k,1}],[harness '/' copies{k,1}], ...
        'Position',copies{k,2});
end
ws = get_param(harness,'ModelWorkspace');
assignin(ws,'vy_v17_mode_code',20);

ax = add_const(harness,'Harness Ax IMU',0.1,0.01,[70 505 180 535]);
ay = add_const(harness,'Harness Ay IMU',0.2,0.01,[70 570 180 600]);
avz = add_const(harness,'Harness AVz IMU',0.01,0.01,[70 635 180 665]);
vx = add_const(harness,'Harness True Vx',20,0.001,[70 175 180 205]);
steer = add_const(harness,'Harness Steering Rad','[0.01;0.01;0;0]',0.01,[70 230 180 260]);
hFVy = add_const(harness,'Harness F Vy Placeholder',0,0.01,[70 890 180 920]);
hFP = add_const(harness,'Harness F P Placeholder',0.5,0.01,[70 940 180 970]);
hFValid = add_const(harness,'Harness F Feedback Valid Disabled',0,0.01,[70 990 180 1020]);
hFReset = add_step(harness,'Harness F Reset First Hit',0.01,1,0,0.01,[70 1040 180 1070]);

hdSub=[harness '/Parallel D-EKF 100Hz']; hdSched=[harness '/Parallel D-EKF 100Hz Scheduler'];
hdRt=[harness '/Parallel D-EKF Input RT 100Hz']; hdControl=[harness '/Parallel D Control Mux'];
hdMeas=[harness '/Parallel D Measurement Mux']; hdInput=[harness '/Parallel D Input Mux'];
hdDemux=[harness '/Parallel D Output Demux']; hdPExtract=[harness '/Parallel D Full P Extract'];
hdP=[harness '/Parallel D P 2x2'];
hkSub=[harness '/K-KF 100Hz']; hkSched=[harness '/K-KF 100Hz Scheduler'];
hkImu=[harness '/K-KF IMU Mux']; hkVxRt=[harness '/K-KF Vx RT 100Hz'];
hkReset=[harness '/K-KF Reset First Call'];
hfSub=[harness '/F-Track 100Hz']; hfSched=[harness '/F-Track 100Hz Scheduler'];
hFusion=[harness '/Fixed Weight D K F Fusion'];

connect(harness,vx,1,hdControl,1); connect(harness,steer,1,hdControl,2);
connect(harness,ay,1,hdMeas,1); connect(harness,avz,1,hdMeas,2);
connect(harness,hdControl,1,hdInput,1); connect(harness,hdMeas,1,hdInput,2);
connect(harness,hdInput,1,hdRt,1); connect(harness,hdRt,1,hdSub,1);
connect_trigger(harness,hdSched,hdSub);
connect(harness,hdSub,1,hdDemux,1); connect(harness,hdSub,1,hdPExtract,1);
connect(harness,hdPExtract,2,hdP,1);

connect(harness,ax,1,hkImu,1); connect(harness,ay,1,hkImu,2);
connect(harness,avz,1,hkImu,3); connect(harness,hkImu,1,hkSub,1);
connect(harness,vx,1,hkVxRt,1); connect(harness,hkVxRt,1,hkSub,2);
connect(harness,hkReset,1,hkSub,3); connect_trigger(harness,hkSched,hkSub);

connect(harness,ay,1,hfSub,1); connect(harness,avz,1,hfSub,2);
connect(harness,vx,1,hfSub,3); connect(harness,hFVy,1,hfSub,4);
connect(harness,hFP,1,hfSub,5); connect(harness,hFValid,1,hfSub,6);
connect(harness,hFReset,1,hfSub,7); connect_trigger(harness,hfSched,hfSub);

hdSelect=[harness '/Fusion D State Select Vy'];
hkSelect=[harness '/Fusion K State Select Vy'];
add_block('simulink/Signal Routing/Demux',hdSelect,'Outputs','2','Position',[1250 120 1255 185]);
add_block('simulink/Signal Routing/Demux',hkSelect,'Outputs','2','Position',[1120 520 1125 585]);
connect(harness,hdDemux,1,hdSelect,1); connect(harness,hkSub,1,hkSelect,1);
connect(harness,hdSelect,1,hFusion,1); connect(harness,hkSelect,2,hFusion,2);
connect(harness,hfSub,1,hFusion,3);

hdXLog=add_ws(harness,hdDemux,1,'harness_dekf_x_log',[1770 120 1940 150]);
hdPLog=add_ws(harness,hdP,1,'harness_dekf_P_log',[1370 350 1540 380]);
hkXLog=add_ws(harness,hkSub,1,'harness_kkf_x_log',[1770 480 1940 510]);
hkPLog=add_ws(harness,hkSub,2,'harness_kkf_P_log',[1120 625 1290 655]);
hfVyLog=add_ws(harness,hfSub,1,'harness_f_vy_log',[1120 870 1290 900]);
hfPLog=add_ws(harness,hfSub,2,'harness_f_P_log',[1120 930 1290 960]);
hfDiagLog=add_ws(harness,hfSub,3,'harness_f_diag_log',[1120 990 1290 1020]);
hFwLog=add_ws(harness,hFusion,1,'harness_vy_fw_log',[1770 630 1940 660]);
add_term(harness,hdDemux,2,'Harness D Pdiag Term',[1160 205 1180 225]);
add_term(harness,hdDemux,3,'Harness D diag Term',[1160 255 1180 275]);
add_term(harness,hdPExtract,1,'Harness D P Head Term',[1160 310 1180 330]);
add_term(harness,hdPExtract,3,'Harness D P Tail Term',[1160 410 1180 430]);
add_term(harness,hdSelect,2,'Harness D r Term',[1360 175 1380 195]);
add_term(harness,hkSelect,1,'Harness K Vx Term',[1230 520 1250 540]);
add_term(harness,hkSub,3,'Harness K diag Term',[1080 680 1100 700]);

set_param(harness,'Description',[ ...
    'V2.5-C estimator-only compile harness. No CarSim or plant. ' ...
    'Fusion weights [1/3 1/3 1/3] are TEST-ONLY, NOT SELECTED, NOT TUNED, NOT FROZEN. ' ...
    'F feedback valid is fixed false and Vy_FW is not fed back.']);
assert(isempty(find_system(harness,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','S-Function','FunctionName','vs_sf')), ...
    'Estimator-only harness unexpectedly contains vs_sf.');
save_system(harness,harnessFile);

targetHash = file_sha256(targetFile);
harnessHash = file_sha256(harnessFile);
close_system(harness,0); close_system(target,0); close_system(fDonor,0);
frozenAfter = snapshot(frozenFiles);
assert(records_equal(frozenBefore,frozenAfter)&&records_match(frozenAfter,expectedHashes), ...
    'A frozen dependency changed during V2.5-C build.');
assert(strcmp(file_sha256(sourceFile),sourceExpected), ...
    'Frozen parallel source changed during V2.5-C build.');

build = struct();
build.stage='V2.5-C'; build.sourceFile=sourceFile; build.sourceHash=sourceExpected;
build.targetFile=targetFile; build.targetModel=target; build.targetHash=targetHash;
build.harnessFile=harnessFile; build.harnessModel=harness; build.harnessHash=harnessHash;
build.fDonorFile=fDonorFile; build.wrapperFile=fullfile(md,'vy_fixed_weight_fusion_simulink_sfun.m');
build.fusionCoreFile=fullfile(md,'vy_fixed_weight_fusion_step.m');
build.testWeights=[1/3 1/3 1/3];
build.fParameters=struct('P0_F',0.5,'Q_F',0.0025,'testOnly',true,'tuned',false,'frozen',false);
build.main=struct('dSubsystem',dSub,'dScheduler',dScheduler,'dOutputDemux',dOutputDemux, ...
    'kSubsystem',kSub,'kScheduler',kScheduler,'fSubsystem',fSub,'fScheduler',fScheduler, ...
    'fValid',fFeedbackValid,'fVyPlaceholder',fVyPlaceholder,'fPPlaceholder',fPPlaceholder, ...
    'fReset',fReset,'dSelect',dSelect,'kSelect',kSelect,'fusion',fusion, ...
    'dVyLog',dVyLog,'kVyLog',kVyLog,'fVyLog',fVyLog,'fPLog',fPLog, ...
    'fDiagLog',fDiagLog,'fwLog',fwLog,'aySource',aySource,'avzSource',avzSource,'vxSource',vxSource);
build.harness=struct('dSubsystem',hdSub,'dScheduler',hdSched,'dInputRateTransition',hdRt, ...
    'dControlMux',hdControl,'dMeasurementMux',hdMeas,'dInputMux',hdInput, ...
    'dOutputDemux',hdDemux,'dPExtract',hdPExtract,'dP',hdP, ...
    'kSubsystem',hkSub,'kScheduler',hkSched,'kImuMux',hkImu,'kVxRateTransition',hkVxRt, ...
    'kReset',hkReset,'fSubsystem',hfSub,'fScheduler',hfSched,'fusion',hFusion, ...
    'dSelect',hdSelect,'kSelect',hkSelect,'axSource',ax,'aySource',ay, ...
    'avzSource',avz,'vxSource',vx,'steeringSource',steer,'fValid',hFValid, ...
    'fVyPlaceholder',hFVy,'fPPlaceholder',hFP,'fReset',hFReset, ...
    'logs',{{hdXLog,hdPLog,hkXLog,hkPLog,hfVyLog,hfPLog,hfDiagLog,hFwLog}});
build.frozenBefore=frozenBefore; build.frozenAfter=frozenAfter;
build.simCalled=false; build.carSimRun=false; build.fullTargetCompileCalled=false;
save(resultFile,'build','-v7');
clear cleanup
fprintf('V2_5C_BUILD_OK|target=%s|harness=%s|sim=0|carsim=0|compile=0\n', ...
    targetHash,harnessHash);
end

function p=add_const(m,name,value,sampleTime,pos)
p=[m '/' name]; if isnumeric(value),value=mat2str(value);end
add_block('simulink/Sources/Constant',p,'Value',value, ...
    'SampleTime',num2str(sampleTime,17),'OutDataTypeStr','double','Position',pos);
end
function p=add_step(m,name,time,before,after,sampleTime,pos)
p=[m '/' name]; add_block('simulink/Sources/Step',p, ...
    'Time',num2str(time,17),'Before',num2str(before,17),'After',num2str(after,17), ...
    'SampleTime',num2str(sampleTime,17),'OutDataTypeStr','double','Position',pos);
end
function connect(m,s,o,d,i)
sp=get_param(s,'PortHandles'); dp=get_param(d,'PortHandles');
add_line(m,sp.Outport(o),dp.Inport(i),'autorouting','on');
end
function connect_trigger(m,s,d)
sp=get_param(s,'PortHandles'); dp=get_param(d,'PortHandles');
add_line(m,sp.Outport(1),dp.Trigger(1),'autorouting','on');
end
function p=add_ws(m,s,o,name,pos)
p=[m '/' name]; add_block('simulink/Sinks/To Workspace',p, ...
    'VariableName',name,'SaveFormat','Timeseries','Position',pos); connect(m,s,o,p,1);
end
function p=add_term(m,s,o,name,pos)
p=[m '/' name]; add_block('simulink/Sinks/Terminator',p,'Position',pos); connect(m,s,o,p,1);
end
function sourcePath=unique_signal_source(modelName,signalName)
lines=find_system(modelName,'FindAll','on','Type','line'); sources={};
for k=1:numel(lines)
    try
        if strcmp(get_param(lines(k),'Name'),signalName)
            h=get_param(lines(k),'SrcBlockHandle');
            if isscalar(h)&&h>0,sources{end+1}=getfullname(h);end %#ok<AGROW>
        end
    catch
    end
end
sources=unique(sources); assert(numel(sources)==1, ...
    'Expected one physical source for signal %s.',signalName); sourcePath=sources{1};
end
function [files,hashes]=frozen_manifest(root)
files={fullfile(root,'model','vx_vy_parallel_dk_v2_3.slx'); ...
 fullfile(root,'model','vx_vy_dekf_v1_17.slx'); fullfile(root,'model','vy_dynamic_ekf_v1_17.m'); ...
 fullfile(root,'model','vy_dynamic_ekf_step_v17.m'); fullfile(root,'model','vy_dynamic_ekf_step_v13.m'); ...
 fullfile(root,'model','vx_vy_kkf_v2_1.slx'); fullfile(root,'model','vx_vy_kkf_v2_1g_steer.slx'); ...
 fullfile(root,'model','vy_kinematic_kf_step.m'); fullfile(root,'model','vy_kinematic_kf.m'); ...
 fullfile(root,'model','vx_vy_dkekf_v2_2.slx'); fullfile(root,'model','vy_dkekf_baseline_step.m'); ...
 fullfile(root,'model','vy_dkekf_baseline.m'); fullfile(root,'model','vy_dkekf_baseline_simulink_sfun.m'); ...
 fullfile(root,'model','vy_feedback_propagation_step.m'); ...
 fullfile(root,'model','vy_feedback_propagation_simulink_sfun.m'); ...
 fullfile(root,'model','vx_vy_feedback_track_v2_4.slx'); ...
 fullfile(root,'model','vy_fixed_weight_fusion_step.m')};
hashes={'98461DB290723A5CCDF62398CE5063DE0C9B6C7586334D479B159A771EB128C0'; ...
 '108F819DCD1B71FD6D795D7148CBF32FE1A888AE9878908E894A07626ED003AE'; ...
 '5550D0389FC4D1DCF7F65B0E00B4C51A949F2B9ADD33C2D78D1122A31291A1A0'; ...
 '4010F6A4BD669AC048297C2F416F0B8826F729F4552D73445703184F052C4A4F'; ...
 '498A446E13E654387E3D36BF4694A336E75B2100E765DAC0414A01367531CDE4'; ...
 'B67A98A6080374304E2D3424F85589C913E6EC4DB25BC9912CBFD2BC441C2712'; ...
 '59B25C5E350140AB0EAFD8345D5A9145D6981B96481023537A3BD01A787F728E'; ...
 '3786646EE5163D231DD8964614A8875217DFA496EB593B455E4E029E26DA2244'; ...
 'F242CB75BA08D22CB1EED87731746CF80D54FD39C1899B45E9980A40576414D4'; ...
 'E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15'; ...
 '6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457'; ...
 '7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973'; ...
 '12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1'; ...
 '80C21D2CDC74F23C964DC50EAC48F2C026AD27027B160BB851B491E301D0E5FF'; ...
 '2FF7E488CC60DD729EC4948066714A95DAC15BBDB08BA45004EF6A7C8E1234B0'; ...
 '951A0D6E454F9C4C8ECD90EB4AD0372270F7D5EDCC15203B68D877C2ED27BF84'; ...
 '4DE407D651FD3366357BFFF181FDB8474273E769982A18EFB96426FC05CC254C'};
end
function r=snapshot(f)
r=repmat(struct('path','','bytes',0,'sha256',''),numel(f),1);
for k=1:numel(f),d=dir(f{k});r(k)=struct('path',f{k},'bytes',d.bytes,'sha256',file_sha256(f{k}));end
end
function ok=records_match(r,h)
ok=numel(r)==numel(h);for k=1:numel(r),ok=ok&&strcmp(r(k).sha256,h{k});end
end
function ok=records_equal(a,b)
ok=numel(a)==numel(b);for k=1:numel(a),ok=ok&&a(k).bytes==b(k).bytes&&strcmp(a(k).sha256,b(k).sha256);end
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
function close_models(target,donor,harness)
for n={harness,target,donor,'Solver_SF'}
    if bdIsLoaded(n{1}),try,close_system(n{1},0);catch,end,end
end
end
