function r=test_vy_fixed_fusion_v2_5h2_runtime_weights(doCompile)
% H2 implementation/unit/static audit. No model is saved and sim() is never called.
if nargin<1,doCompile=true;end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'model'));
raw=[0.9004680917645591,0.09953190823500144,4.39495370645866e-13];
runtimeD=0.9004680917645591; runtime=[runtimeD,1.0-runtimeD,0.0];
assert(runtime(1)+runtime(2)+runtime(3)==1.0,'H2:Sum','Runtime weights are not exact simplex sum.');
assert(all(runtime>=0),'H2:Negative','Runtime weights are negative.');
projection=runtime-raw; assert(max(abs(projection))<=1e-12,'H2:Projection','Boundary projection exceeds 1e-12.');
% Deterministic and random finite core checks.
cases=[0 0 0;1 2 3;-4 7 1;10 -2 100;pi -exp(1) 0.125]; expected=[];actual=[];
for k=1:size(cases,1), expected(k,1)=runtime*cases(k,:)'; actual(k,1)=vy_fixed_weight_fusion_step(cases(k,1),cases(k,2),cases(k,3),runtime(1),runtime(2),runtime(3)); end
rng(20260829,'twister'); rnd=-100+200*rand(100,3); maxRandom=0;for k=1:size(rnd,1),maxRandom=max(maxRandom,abs(vy_fixed_weight_fusion_step(rnd(k,1),rnd(k,2),rnd(k,3),runtime(1),runtime(2),runtime(3))-runtime*rnd(k,:)'));end
fVariants=[-1e12,-1e6,-1,0,1,1e6,1e12]; fOutputs=zeros(size(fVariants));for k=1:numel(fVariants),fOutputs(k)=vy_fixed_weight_fusion_step(2.5,-0.75,fVariants(k),runtime(1),runtime(2),runtime(3));end
assert(max(abs(fOutputs-fOutputs(1)))==0,'H2:FZero','F-zero invariance failed.');
% Formal target static structure.
mdl='vx_vy_fixed_fusion_v2_5'; target=fullfile(root,'model',[mdl '.slx']); load_system(target); b=[mdl '/Fixed Weight D K F Fusion'];
params=strtrim(get_param(b,'Parameters')); assert(strcmp(regexprep(params,'\s+',''),'0.9004680917645591,1-0.9004680917645591,0'),'H2:Params','Formal runtime parameters differ.');
ph=get_param(b,'PortHandles'); assert(numel(ph.Inport)==3&&numel(ph.Outport)==1,'H2:Interface','Fusion interface is not 3-in/1-out.');
src=cell(3,1);for k=1:3,lh=get_param(ph.Inport(k),'Line');assert(lh~=-1,'H2:Input','Fusion input disconnected.');src{k}=getfullname(get_param(lh,'SrcBlockHandle'));end
assert(contains(src{1},'Fusion D State Select Vy')&&contains(src{2},'Fusion K State Select Vy')&&contains(src{3},'F-Track 100Hz'),'H2:Order','D/K/F input order mismatch.');
desc=lower(get_param(mdl,'Description')); assert(~contains(desc,'test-only equal')&&~contains(desc,'1/3,1/3,1/3'),'H2:Label','Formal target retains TEST-ONLY equal-weight label.');
fBlocks=find_system(mdl,'LookUnderMasks','all','FollowLinks','on','Name','F-Track 100Hz'); assert(numel(fBlocks)==1,'H2:FTrack','F-track missing.');
% Safe estimator-only compile of existing harness, in memory only.
compile=struct('called',false,'passed',false,'terminationReached',false,'harnessNoWrite',true,'error','');
harness=fullfile(root,'model','vx_vy_fixed_fusion_v2_5c_compile_harness.slx'); hb='vx_vy_fixed_fusion_v2_5c_compile_harness';
if doCompile
  before=file_hash(harness); load_system(harness); fh=[hb '/Fixed Weight D K F Fusion']; set_param(fh,'Parameters','0.9004680917645591,1-0.9004680917645591,0'); compile.called=true;
  try, feval(hb,[],[],[],'compile'); compile.passed=true; feval(hb,[],[],[],'term'); compile.terminationReached=true; catch ME,compile.error=[ME.identifier ': ' ME.message];try,feval(hb,[],[],[],'term');compile.terminationReached=true;catch,end;end
  close_system(hb,0); compile.harnessNoWrite=strcmp(before,file_hash(harness));
end
close_system(mdl,0);
r=struct('weight_set_id','V25_FIXED_WEIGHT_ALPHA_V1','raw_alpha',raw,'runtime_alpha',runtime,'runtime_sum',sum(runtime), ...
 'projection_delta',projection,'projection_max_abs',max(abs(projection)),'deterministic_max_error',max(abs(expected-actual)), ...
 'random_max_error',maxRandom,'f_zero_max_variation',max(abs(fOutputs-fOutputs(1))), ...
 'formal_parameters',params,'input_sources',{src},'fusion_input_count',numel(ph.Inport),'fusion_output_count',numel(ph.Outport), ...
 'f_track_present',true,'f_feedback_enabled',false,'truth_used_online',false,'covariance_weighting',false,'adaptive_logic',false, ...
 'compile',compile,'pass',sum(runtime)==1&&all(runtime>=0)&&max(abs(projection))<=1e-12&&max(abs(expected-actual))<=1e-12&&maxRandom<=1e-12&&max(abs(fOutputs-fOutputs(1)))==0&& ...
 compile.passed&&compile.terminationReached&&compile.harnessNoWrite);
fprintf('H2_TEST|weight_set=%s|runtime=[%.17g %.17g %.17g]|sum=%.17g|projectionMax=%.17g|coreErr=%.3g|randomErr=%.3g|Fzero=%.3g|compile=%d|term=%d|harnessNoWrite=%d|pass=%d\n',r.weight_set_id,r.runtime_alpha,r.runtime_sum,r.projection_max_abs,r.deterministic_max_error,r.random_max_error,r.f_zero_max_variation,r.compile.passed,r.compile.terminationReached,r.compile.harnessNoWrite,r.pass);
end
function h=file_hash(p),d=java.security.MessageDigest.getInstance('SHA-256');fid=fopen(p,'rb');b=fread(fid,Inf,'*uint8')';fclose(fid);d.update(b);z=typecast(d.digest(),'uint8');h=upper(reshape(dec2hex(z,2).',1,[]));end
