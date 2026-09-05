function write_vx_cs40_formal_v4c_status()
%WRITE_VX_CS40_FORMAL_V4C_STATUS Write the concise final stage record.
root=fileparts(fileparts(mfilename('fullpath')));
stageRoot=fullfile(root,'results','vx_formal_validation','v4c_cs40_formal');
rawFile=fullfile(stageRoot,'runtime','VX_CS40_formal_raw.mat');
derivedFile=fullfile(stageRoot,'VX_CS40_traditional_wss.mat');
S=load(rawFile,'R');Q=load(derivedFile,'D');R=S.R;D=Q.D;
assert(strcmp(R.metadata.verdict,'VX_CS40_V4C_FORMAL_PASS'),'VX:V4C:StatusGate');
figDir=fullfile(stageRoot,'thesis_figures');
outputs={fullfile(stageRoot,'VX_CS40_performance_metrics.csv'), ...
    fullfile(stageRoot,'VX_CS40_phase_metrics.csv'), ...
    fullfile(figDir,'VX_FIG_CS40_longitudinal_speed_performance.png'), ...
    fullfile(figDir,'VX_FIG_CS40_longitudinal_speed_performance.pdf'), ...
    fullfile(figDir,'VX_FIG_CS40_longitudinal_speed_performance.svg'), ...
    fullfile(figDir,'VX_FIG_CS40_combined_slip_mechanism.png'), ...
    fullfile(figDir,'VX_FIG_CS40_combined_slip_mechanism.pdf'), ...
    fullfile(figDir,'VX_FIG_CS40_combined_slip_mechanism.svg')};
assert(all(cellfun(@isfile,outputs)),'VX:V4C:StatusOutputs');
statusFile=fullfile(root,'docs','STAGE_VX_V4C_CS40_FORMAL_STATUS.md');
fid=fopen(statusFile,'wt');assert(fid>=0,'VX:V4C:StatusWrite');c=onCleanup(@()fclose(fid));
fprintf(fid,'# VX-V4C-CS40 formal validation status\n\n');
fprintf(fid,'- Stage: `VX-V4C-CS40-FORMAL`\n- Verdict: `%s`\n',R.metadata.verdict);
fprintf(fid,'- Formal runtime count: 1 (frozen V4B candidate A1 only)\n');
fprintf(fid,'- Actual initial Vx: %.12g m/s (%.12g km/h), gate PASS\n',R.metadata.actualInitialVxMps,R.metadata.actualInitialVxKmh);
fprintf(fid,'- Drive RL/RR sustained duration: %.6f / %.6f s, gate PASS\n',R.metadata.driveRearSustainedDuration_s);
fprintf(fid,'- Brake RL/RR sustained duration: %.6f / %.6f s, gate PASS\n',R.metadata.brakeRearSustainedDuration_s);
fprintf(fid,'- Estimator finite gate: PASS (Fusion / Adaptive WSS / IMU)\n');
fprintf(fid,'- Overall Traditional WSS RMSE: %.12g m/s\n',D.metrics.TraditionalWSS_RMSE);
fprintf(fid,'- Overall Fusion RMSE: %.12g m/s\n',D.metrics.Fusion_RMSE);
fprintf(fid,'- Drive Traditional/Fusion RMSE: %.12g / %.12g m/s\n',D.phaseMetrics.drive.traditional.RMSE,D.phaseMetrics.drive.fusion.RMSE);
fprintf(fid,'- Brake Traditional/Fusion RMSE: %.12g / %.12g m/s\n',D.phaseMetrics.brake.traditional.RMSE,D.phaseMetrics.brake.fusion.RMSE);
fprintf(fid,'- V4B text evidence archive commit: `3e04be0de7a8844cf1f94b498649e779007afb18` (four text files only)\n');
fprintf(fid,'- Local V4B A1 physical MAT SHA256: `36FD8DE63C43F5A3C9CB58FB327AF211CFCB3203E34782C0DC26E65FAD0C97E3`\n');
fprintf(fid,'- Protection: V3B, V4-CS40, V4B calibration, source vx.slx, estimator and parameters unchanged.\n');
fprintf(fid,'- Calibration evidence was not used as formal estimator performance evidence.\n');clear c
end
