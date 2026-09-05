function report = analyze_vy_kkf_v2_1g0_steer_smoke()
%ANALYZE_VY_KKF_V2_1G0_STEER_SMOKE Evaluate only the G0 excitation gates.
root=fileparts(fileparts(mfilename('fullpath'))); f=fullfile(root,'results','vy_kkf_v2_1g0_steer_smoke.mat'); c1f=fullfile(root,'results','vy_kkf_v2_1c1_nominal.mat'); S=load(f,'report'); report=S.report; assert(report.simulationCompleted,'Simulation was incomplete.'); r=report.raw;
cmd=vec(r.steer_cmd_rad); deg=vec(r.steer_to_carsim_deg); fl=vec(r.steer_fl_carsim_deg); fr=vec(r.steer_fr_carsim_deg); rl=vec(r.steer_rl_carsim_deg); rr=vec(r.steer_rr_carsim_deg);
ratio=deg(abs(cmd)>1e-10)./cmd(abs(cmd)>1e-10); x=rows(r.kkf_x_log1.data,r.kkf_x_log1.sampleCount); p=double(r.kkf_P_log1.data); d=double(r.kkf_diag_log1.data);
kt={r.kkf_u_log1.time(:),r.kkf_x_log1.time(:),r.kkf_P_log1.time(:),r.kkf_diag_log1.time(:)};
g=struct(); g.simulationCompleted=report.simulationCompleted; g.carSimRun=report.carSimRun;
g.kkfLogSampleCounts=cellfun(@numel,kt); g.kkfFourLogsAligned=isequal(kt{1},kt{2},kt{3},kt{4});
g.kkfDt_s=cellfun(@(t)median(diff(t)),kt); g.kkf100Hz=g.kkfFourLogsAligned&&all(abs(g.kkfDt_s-0.01)<1e-12);
reset=vec(r.reset_g0); ix=reset>0.5; g.resetHighCount=nnz(ix); g.resetHighAtT0=g.resetHighCount==1 && abs(r.reset_g0.time(find(ix,1))-0)<1e-12;
g.steerCmdNonzero=any(abs(cmd)>1e-8); g.steerCmdMaxAbs_rad=max(abs(cmd)); g.steerCmdAmplitudeOK=abs(g.steerCmdMaxAbs_rad-0.04)<1e-9;
g.radToDegRatioMedian=median(ratio); g.radToDegRatioMaxError=max(abs(ratio-180/pi)); g.radToDegOK=g.radToDegRatioMaxError<1e-10; g.onlyOneRadToDegConversion=report.build.onlyRadToDegConversion;
g.flFrMaxAbsDiff=max(abs(fl-fr)); g.flFrEqual=g.flFrMaxAbsDiff<1e-12;
g.flVsConvertedMaxAbsDiff=max(abs(fl-deg)); g.frVsConvertedMaxAbsDiff=max(abs(fr-deg));
g.frontMaxAbs_deg=[max(abs(fl)),max(abs(fr))];
g.frontCommandApplied=g.flFrEqual&&g.flVsConvertedMaxAbsDiff<1e-12&&g.frVsConvertedMaxAbsDiff<1e-12&&all(g.frontMaxAbs_deg>1e-8);
g.rlMaxAbs_deg=max(abs(rl));g.rrMaxAbs_deg=max(abs(rr));g.rearZero=g.rlMaxAbs_deg<1e-12 && g.rrMaxAbs_deg<1e-12;
g.frequency_Hz=fit_frequency(r.steer_cmd_rad.time,cmd);g.frequencyOK=abs(g.frequency_Hz-0.4)<1e-5;g.finite=all(isfinite(x(:)))&&all(isfinite(p(:)))&&all(isfinite(d(:)));
assert(isfile(c1f),'C1 evidence MAT is missing.'); C=load(c1f,'report'); cu=rows(C.report.raw.kkf_u_log1.data,C.report.raw.kkf_u_log1.sampleCount); ct=C.report.raw.kkf_u_log1.time(:); keep=ct>=0 & ct<=2; cg=interp1(r.avz_imu_g0.time,vec(r.avz_imu_g0),ct(keep),'linear'); c1avz=cu(keep,3);cdif=cg-c1avz;
g.avzVsC1=struct('maxAbsDiff',max(abs(cdif)),'rmsDifference',sqrt(mean(cdif.^2)), ...
    'newMaxAbs',max(abs(cg)),'c1MaxAbs',max(abs(c1avz)),'exactEqual',isequaln(cg,c1avz));
g.avzNumericalNoiseFloor=100*eps(max([1;abs(cg);abs(c1avz)]));
g.avzPhysicalResponse=g.avzVsC1.maxAbsDiff>g.avzNumericalNoiseFloor;
g.frozenHashUnchanged=report.frozenHashUnchanged;g.newModelHash=report.newModelHash;g.pass=g.simulationCompleted&&g.carSimRun&&g.kkf100Hz&&g.resetHighAtT0&&g.steerCmdNonzero&&g.steerCmdAmplitudeOK&&g.radToDegOK&&g.onlyOneRadToDegConversion&&g.frontCommandApplied&&g.rearZero&&g.frequencyOK&&g.avzPhysicalResponse&&g.finite&&g.frozenHashUnchanged;
report.g0=g;save(f,'report','-v7.3');fprintf('V2_1G0_ANALYSIS|pass=%d|maxCmd=%.15g|ratioErr=%.3g|freq=%.15g|AVzDiff=%.15g|reset=%d|finite=%d\n',g.pass,g.steerCmdMaxAbs_rad,g.radToDegRatioMaxError,g.frequency_Hz,g.avzVsC1.maxAbsDiff,g.resetHighCount,g.finite);
end
function v=vec(r),v=double(r.data(:));end
function a=rows(a,n),a=double(a);if size(a,1)~=n&&size(a,2)==n,a=a.';end;assert(size(a,1)==n,'Unexpected log orientation.');end
function f=fit_frequency(t,y), fun=@(q)err(q,t,y);f=fminbnd(fun,0.1,1.0);end
function e=err(f,t,y),A=[sin(2*pi*f*t(:)),cos(2*pi*f*t(:))];z=A\y(:);e=norm(A*z-y(:))^2;end
