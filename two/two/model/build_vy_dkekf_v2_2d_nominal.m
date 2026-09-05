function build = build_vy_dkekf_v2_2d_nominal()
%BUILD_VY_DKEKF_V2_2D_NOMINAL Create the isolated D1 nominal-steer copy.
root=fileparts(fileparts(mfilename('fullpath'))); md=fullfile(root,'model');
srcFile=fullfile(md,'vx_vy_dkekf_v2_2.slx'); dstFile=fullfile(md,'vx_vy_dkekf_v2_2d_nominal.slx');
solver='D:\carsim\CarSim2021.0_Prog\Programs\solvers'; parFile='D:\carsim\CarSim2021.0_Data\Results\Run_60ed91d9-d198-4454-aa7a-bbf27fe3b517\Run_all.par';
expected='e768fb2ad33a6eeaabde2fb7c40be660b78f350a90c752327dc9b423f50f2e15';
assert(isfile(srcFile)&&isfile(parFile),'Required accepted target or active import file is missing.');
build=struct('sourceFile',srcFile,'targetFile',dstFile,'frozenHashBefore',sha(srcFile));
assert(strcmp(build.frozenHashBefore,expected),'Accepted target hash mismatch before D1 build.');
actualImports=import_order(parFile);
expectedImports={'IMP_ZGND_L1','IMP_ZGND_R1','IMP_ZGND_L2','IMP_ZGND_R2','IMP_MYUSM_L1','IMP_STEER_L1','IMP_MYUSM_R1','IMP_STEER_R1','IMP_MYUSM_L2','IMP_STEER_L2','IMP_MYUSM_R2','IMP_STEER_R2','IMP_FS_L1','IMP_FS_R1','IMP_FS_L2','IMP_FS_R2'};
actualNorm=string(actualImports(:));expectedNorm=string(expectedImports(:));
assert(isequal(actualNorm,expectedNorm),'Active CarSim import order differs from audited order.');
build.importOrderGate=true;build.actualImports=cellstr(actualNorm);build.expectedImports=cellstr(expectedNorm);build.actualNormalizedSize=size(actualNorm);build.expectedNormalizedSize=size(expectedNorm);
copyfile(srcFile,dstFile,'f'); addpath(md);addpath(solver);addpath(fullfile(solver,'Matlab84+'));
Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,'vy_dkekf_v2_2d_cache'),'CodeGenFolder',fullfile(tempdir,'vy_dkekf_v2_2d_codegen'),'createDir',true);
load_system('Solver_SF');load_system(dstFile);[~,m]=fileparts(dstFile);clean=onCleanup(@()close_loaded(m));
gain=[m '/Gain22'];mux5=[m '/Mux5'];mux8=[m '/Mux8'];sw=[m '/Manual Switch1'];mux7=[m '/Mux7'];car=[m '/CarSim S-Function'];
assert(strcmp(get_param(gain,'Gain'),'180/pi'),'Gain22 is not 180/pi.');
assert(strcmp(source_of_port(get_param(sw,'PortHandles').Inport(1)),mux5),'Manual Switch1 input1 is not Mux5.');
assert(strcmp(source_of_port(get_param(sw,'PortHandles').Inport(2)),mux8),'Manual Switch1 input2 is not Mux8.');
assert(strcmp(get_param(sw,'CurrentSetting'),'0'),'Accepted target Manual Switch1 is not setting 0.');
assert_dest(gain,1,mux8,[2 4]);assert_dest(mux8,1,sw,2);assert_dest(sw,1,mux7,2);assert_dest(mux7,1,car,1);
assert_zero(mux8,6);assert_zero(mux8,8);
gin=get_param(gain,'PortHandles');assert(get_param(gin.Inport(1),'Line')==-1,'Gain22 input unexpectedly has a frozen source.');
cmd=[m '/D1 Steer Cmd Rad'];add_block('simulink/Sources/Sine Wave',cmd,'Position',[1190 1030 1255 1060],'Amplitude','test_steer_amplitude','Frequency','2*pi*test_steer_frequency','Phase','0','Bias','0','SampleTime','0');cmdPH=get_param(cmd,'PortHandles');add_line(m,cmdPH.Outport(1),gin.Inport(1),'autorouting','on');
% D1 is nominal: retain accepted setting 0, which selects input2/Mux8.
build.switchBefore=struct('sw',get_param(sw,'sw'),'currentSetting',get_param(sw,'CurrentSetting'));set_param(sw,'sw','0');build.switchAfter=struct('sw',get_param(sw,'sw'),'currentSetting',get_param(sw,'CurrentSetting'));assert(strcmp(build.switchAfter.currentSetting,'0'),'D1 did not retain Manual Switch setting 0.');
add_ws(m,cmd,1,'d1_steer_cmd_rad',[1080 995 1170 1020]);add_ws(m,gain,1,'d1_steer_to_carsim_deg',[1400 1065 1500 1090]);
demux=[m '/D1 CarSim Input Demux'];add_block('simulink/Signal Routing/Demux',demux,'Outputs','16','Position',[1710 1030 1715 1235]);mux7PH=get_param(mux7,'PortHandles');demuxPH=get_param(demux,'PortHandles');add_line(m,mux7PH.Outport(1),demuxPH.Inport(1),'autorouting','on');
add_ws(m,demux,6,'d1_steer_fl_boundary_deg',[1745 1050 1870 1075]);add_ws(m,demux,8,'d1_steer_fr_boundary_deg',[1745 1090 1870 1115]);add_ws(m,demux,10,'d1_steer_rl_boundary_deg',[1745 1130 1870 1155]);add_ws(m,demux,12,'d1_steer_rr_boundary_deg',[1745 1170 1870 1195]);
add_ws(m,[m '/DK-EKF Reset First Call'],1,'d1_reset',[4000 1370 4090 1395]);avz=unique_source(m,'AVz_IMU');add_ws(m,avz,1,'d1_avz_imu',[3800 900 3900 925]);
save_system(m,dstFile);close_system(m,0);close_system('Solver_SF',0);clear clean
build.frozenHashAfter=sha(srcFile);assert(strcmp(build.frozenHashBefore,build.frozenHashAfter),'Accepted target changed in D1 build.');build.targetHash=sha(dstFile);build.modelName=m;build.gain22='180/pi';build.switchInputSources={mux5,mux8};build.selectedSource=mux8;build.mux8SteerPorts=struct('FL',2,'FR',4,'RL',6,'RR',8,'units','deg');build.boundaryPorts=struct('FL',6,'FR',8,'RL',10,'RR',12,'units','deg');build.onlyOneRadToDeg=true;build.logVariables={'d1_steer_cmd_rad','d1_steer_to_carsim_deg','d1_steer_fl_boundary_deg','d1_steer_fr_boundary_deg','d1_steer_rl_boundary_deg','d1_steer_rr_boundary_deg','d1_avz_imu','d1_reset','dkekf_u_log1','dkekf_x_log1','dkekf_P_log1','dkekf_diag_log1'};
end
function assert_dest(src,o,dst,ports),p=get_param(src,'PortHandles');l=get_param(p.Outport(o),'Line');assert(l~=-1,'Required source unconnected: %s',src);h=get_param(l,'DstPortHandle');got=[];for k=1:numel(h),if strcmp(getfullname(get_param(h(k),'Parent')),dst),got(end+1)=get_param(h(k),'PortNumber');end,end;assert(isequal(sort(got),sort(ports)),'Path mismatch %s -> %s.',src,dst);end
function assert_zero(mux,n),p=get_param(mux,'PortHandles');l=get_param(p.Inport(n),'Line');h=get_param(l,'SrcBlockHandle');assert(l~=-1&&strcmp(get_param(h,'BlockType'),'Constant')&&strcmp(strtrim(get_param(h,'Value')),'0'),'Mux8 port %d is not zero.',n);end
function s=source_of_port(p),l=get_param(p,'Line');assert(l>0,'Input unconnected.');s=getfullname(get_param(l,'SrcBlockHandle'));end
function s=unique_source(m,name),ls=find_system(m,'FindAll','on','Type','line');x={};for k=1:numel(ls),try,if strcmp(get_param(ls(k),'Name'),name),h=get_param(ls(k),'SrcBlockHandle');if h>0,x{end+1}=getfullname(h);end,end,catch,end,end;x=unique(x);assert(numel(x)==1,'Unique source missing for %s.',name);s=x{1};end
function add_ws(m,src,p,name,pos),b=[m '/' name];add_block('simulink/Sinks/To Workspace',b,'Position',pos,'VariableName',name,'SaveFormat','Timeseries','MaxDataPoints','100000');srcPH=get_param(src,'PortHandles');dstPH=get_param(b,'PortHandles');add_line(m,srcPH.Outport(p),dstPH.Inport(1),'autorouting','on');end
function o=import_order(f),t=fileread(f);o=regexp(t,'(?m)^IMPORT\s+(IMP_[A-Z0-9_]+)\s','tokens');o=cellfun(@(x)x{1},o,'UniformOutput',false)';end
function h=sha(f),d=java.security.MessageDigest.getInstance('SHA-256');s=java.io.FileInputStream(java.io.File(f));ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());while ds.read()~=-1,end;b=typecast(d.digest(),'uint8');h=lower(reshape(dec2hex(b,2).',1,[]));clear c,end
function close_loaded(m),if bdIsLoaded(m),close_system(m,0);end;if bdIsLoaded('Solver_SF'),close_system('Solver_SF',0);end,end
