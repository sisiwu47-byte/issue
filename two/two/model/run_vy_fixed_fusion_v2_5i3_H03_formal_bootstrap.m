% FWHOLD_H03 execution-entry bootstrap. Created and frozen; not executed in R0.
projectModelDir='D:\UsersData\桌面\two\model';
phaseFile='D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv';
commitFile='D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i3_H03_sim_authorization_committed.csv';
assert(~isfile(phaseFile)&&~isfile(commitFile),'V25I3B:ExistingEvidence','H03 R0 phase/authorization evidence already exists.');
append_phase(phaseFile,'BOOTSTRAP_ENTERED','FWHOLD_H03','FWHOLD_H03 execution-entry bootstrap');
cd(projectModelDir);
assert(strcmp(pwd,projectModelDir),'V25I3B:ProjectCD','Unexpected project model directory.');
append_phase(phaseFile,'PROJECT_CD_OK','FWHOLD_H03','FWHOLD_H03');
report=run_vy_fixed_fusion_v2_5i3_H03_holdout();

function append_phase(file,phase,runId,detail)
isNew=~isfile(file);fid=fopen(file,'a');assert(fid>=0,'V25I3B:PhaseWrite','Cannot append phase marker.');
if isNew,fprintf(fid,'timestamp,phase,run_id,detail\n');end
fprintf(fid,'%s,%s,%s,"%s"\n',datestr(now,30),phase,runId,strrep(char(detail),'"','""'));
assert(fclose(fid)==0,'V25I3B:PhaseClose','Phase marker close failed.');d=dir(file);assert(isfile(file)&&d.bytes>0,'V25I3B:PhaseDurability','Phase marker did not persist.');
end
