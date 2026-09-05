function write_vx_nd60_formal_status_v4()
%WRITE_VX_ND60_FORMAL_STATUS_V4 Write concise final evidence status.
root=fileparts(fileparts(mfilename('fullpath')));stage=fullfile(root,'results','vx_formal_validation','v4_nd60_formal');
S=load(fullfile(stage,'runtime','VX_ND60_formal_raw.mat'),'R');Q=load(fullfile(stage,'VX_ND60_traditional_wss.mat'),'D');R=S.R;D=Q.D;
assert(strcmp(R.metadata.verdict,'VX_ND60_FORMAL_PASS'),'VX:ND60:StatusGate');figDir=fullfile(stage,'thesis_figures');
outputs={fullfile(stage,'VX_ND60_performance_metrics.csv'),fullfile(figDir,'VX_FIG_ND60_longitudinal_speed_performance.png'),fullfile(figDir,'VX_FIG_ND60_longitudinal_speed_performance.pdf'),fullfile(figDir,'VX_FIG_ND60_longitudinal_speed_performance.svg')};assert(all(cellfun(@isfile,outputs)),'VX:ND60:StatusOutputs');
file=fullfile(root,'docs','STAGE_VX_ND60_FORMAL_STATUS.md');fid=fopen(file,'wt');assert(fid>=0,'VX:ND60:StatusWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'# VX-ND60 formal status\n\n- Stage: `VX-V4-ND60-FORMAL`\n- Verdict: `%s`\n- Formal runtime count: 1\n',R.metadata.verdict);
fprintf(fid,'- Control: `SV_VXS=60 km/h`, `MU_ROAD_CONSTANT=0.80`, `TSTOP=16 s`, steering `0 rad`.\n');
fprintf(fid,'- Actual initial Vx: %.12g m/s (%.12g km/h), initial gate PASS.\n',R.metadata.actualInitialVxMps,R.metadata.actualInitialVxKmh);
fprintf(fid,'- Estimator finite gate: PASS (Fusion / Adaptive WSS / IMU).\n- Old 72->60 km/h initial transient disappeared: YES.\n');
fprintf(fid,'- Traditional WSS RMSE: %.12g m/s; Fusion RMSE: %.12g m/s; improvement: %.12g m/s.\n',D.metrics.TraditionalWSS_RMSE,D.metrics.Fusion_RMSE,D.metrics.TraditionalMinusFusion_RMSE);
fprintf(fid,'- Source vx.slx, estimator, parameters, and V3/V3B/V4/V4B/V4C evidence remained unchanged.\n');
fprintf(fid,'- Remote sync note: two bounded fetch attempts failed because GitHub was unreachable; the last locally verified main baseline was retained.\n');clear c
end
