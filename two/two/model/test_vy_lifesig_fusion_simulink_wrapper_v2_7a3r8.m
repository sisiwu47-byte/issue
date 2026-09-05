function report = test_vy_lifesig_fusion_simulink_wrapper_v2_7a3r8()
%TEST_VY_LIFESIG_FUSION_SIMULINK_WRAPPER_V2_7A3R8 Compile-only wrapper test.

root=fileparts(fileparts(mfilename('fullpath')));md=fullfile(root,'model');
wrapperFile=fullfile(md,'vy_lifesig_fusion_simulink_sfun.m');
coreFile=fullfile(md,'vy_lifesig_fusion_step.m');
resultFile=fullfile(root,'results','vy_reliability_lifesig_v2_7a3r8_wrapper_test.mat');
expectedCore='3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA';
assert(strcmp(file_sha256(coreFile),expectedCore),'A3R8:CoreHashMismatch', ...
    'LifeSig core differs from the remediated R1 core.');

text=lower(fileread(wrapperFile));
static=struct();
static.inputCount=contains(text,'block.numinputports = 8;');
static.outputCount=contains(text,'block.numoutputports = 9;');
static.dworkCount=contains(text,'block.numdworks = 2;');
static.memoryNames=contains(text,'last_valid_vy_ls')&&contains(text,'has_last_valid');
static.coreDelegation=contains(text,'vy_lifesig_fusion_step(');
static.sampleTime=contains(text,'block.sampletimes = [0.01 0];');
static.noFrozenMath=isempty(regexp(text, ...
    '0\.842618409|0\.146439697|0\.010941893|28\.252990|\<exp\s*\(|\<score\w*\s*=','once'));
static.noSimulation=isempty(regexp(text,'\<sim\s*\(','once'));

harness='vy_lifesig_wrapper_a3r8_compile_harness';
if bdIsLoaded(harness),close_system(harness,0);end
cleanup=onCleanup(@()close_harness(harness));
new_system(harness);
set_param(harness,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','0.01','StartTime','0','StopTime','0.1');
wrapper=[harness '/LifeSig Wrapper'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', ...
    wrapper,'FunctionName','vy_lifesig_fusion_simulink_sfun', ...
    'Position',[400 180 650 430]);
values=[1 1 2 1 3 0 1 0];
for k=1:8
    src=[harness sprintf('/Input %d',k)];
    add_block('simulink/Sources/Constant',src,'Value',num2str(values(k),17), ...
        'SampleTime','0.01','OutDataTypeStr','double', ...
        'Position',[100 40+55*k 220 70+55*k]);
    connect(harness,src,1,wrapper,k);
end
for k=1:9
    sink=[harness sprintf('/Output %d Terminator',k)];
    add_block('simulink/Sinks/Terminator',sink, ...
        'Position',[800 35+45*k 820 55+45*k]);
    connect(harness,wrapper,k,sink,1);
end

report=struct();report.stage='V2.7-A3R8';report.compileCalled=false;
report.compilePassed=false;report.terminationReached=false;
report.firstErrorIdentifier='';report.firstErrorMessage='';
try
    report.compileCalled=true;
    feval(harness,[],[],[],'compile');
    report.compilePassed=true;
    report.compiledDimensions=get_param(wrapper,'CompiledPortDimensions');
    report.compiledDataTypes=get_param(wrapper,'CompiledPortDataTypes');
    report.compiledSampleTime=get_param(wrapper,'CompiledSampleTime');
    feval(harness,[],[],[],'term');
    report.terminationReached=true;
catch ME
    report.firstErrorIdentifier=ME.identifier;
    report.firstErrorMessage=ME.message;
    try,feval(harness,[],[],[],'term');report.terminationReached=true;catch,end
end
report.static=static;
report.staticPassed=all(structfun(@(x)logical(x),static));
report.wrapperSHA256=file_sha256(wrapperFile);
report.coreSHA256=file_sha256(coreFile);
report.simCalled=false;report.carSimRun=false;
report.passed=report.staticPassed&&report.compilePassed&& ...
    report.terminationReached&&~report.simCalled&&~report.carSimRun;
save(resultFile,'report','-v7');
fprintf('A3R8_WRAPPER|static=%d|compile=%d|term=%d|passed=%d|sim=0|carsim=0\n', ...
    report.staticPassed,report.compilePassed,report.terminationReached,report.passed);
if ~report.passed
    fprintf('A3R8_WRAPPER_ERROR|%s|%s\n', ...
        report.firstErrorIdentifier,report.firstErrorMessage);
end
assert(report.passed,'A3R8:WrapperTestFailed','LifeSig wrapper test failed.');
clear cleanup
end

function connect(m,s,o,d,i)
sp=get_param(s,'PortHandles');dp=get_param(d,'PortHandles');
add_line(m,sp.Outport(o),dp.Inport(i),'autorouting','on');
end
function close_harness(m)
if bdIsLoaded(m),try,close_system(m,0);catch,end,end
end
function hash=file_sha256(path)
d=java.security.MessageDigest.getInstance('SHA-256');
s=java.io.FileInputStream(java.io.File(path));
ds=java.security.DigestInputStream(s,d);c=onCleanup(@()ds.close());
while ds.read()~=-1,end
bytes=typecast(d.digest(),'uint8');
hash=upper(reshape(dec2hex(bytes,2).',1,[]));clear c
end
