function A = analyze_vx_formal_validation_v3b(caseId)
%ANALYZE_VX_FORMAL_VALIDATION_V3B Analyze the one fresh formal VX-CS run.
arguments
    caseId (1,1) string = "VX-CS"
end
caseId=upper(strrep(strtrim(caseId),'_','-'));assert(caseId=="VX-CS",'VX:V3B:Case');
root=fileparts(fileparts(mfilename('fullpath')));runtimeDir=fullfile(root,'results','vx_formal_validation','v3b','runtime');
S=load(fullfile(runtimeDir,'VX_CS_formal_raw.mat'),'R');R=S.R;
assert(R.metadata.formalRuntime&&strcmp(R.metadata.stage,'VX-V3B')&&strcmp(R.metadata.caseId,'VX-CS'),'VX:V3B:Evidence');
t=double(R.time(:));Y=double(R.estY);U=double(R.estU);v=double(R.vxTrue(:));
assert(size(Y,2)==38&&size(U,2)==18&&numel(t)==size(Y,1),'VX:V3B:Interface');
updated=Y(:,35)>0.5&isfinite(v);freeze=jsondecode(fileread(R.configuration.freezeFile));
brakeEnd=double(freeze.brakeAnalysisEnd_s);kappa=(0.393.*U(:,1:4)-v)./max(abs(v),1);
A=struct('stage','VX-V3B','caseId','VX-CS','rawFile',fullfile(runtimeDir,'VX_CS_formal_raw.mat'));
A.overall=metric_set(t,Y,v,updated,[0.6 16],true);
A.windows=struct('baseline',[0.6 3],'driveSlip',[3 7], ...
    'interPhaseRecovery',[7 9],'brakeSlip',[9 brakeEnd],'finalRecovery',[brakeEnd 16]);
A.drive=degradation_phase(t,Y,v,updated,kappa,[3 7],[7 9],true);
A.brake=degradation_phase(t,Y,v,updated,kappa,[9 brakeEnd],[brakeEnd 16],false);
A.physicalGatePass=A.drive.physicalGatePass&&A.brake.physicalGatePass;
A.freezeFileSha256=R.metadata.freezeFileSha256;
save(fullfile(runtimeDir,'VX_CS_analysis.mat'),'A');write_json(fullfile(runtimeDir,'VX_CS_analysis.json'),A);
if A.physicalGatePass,write_final_tables(root,A);end
fprintf('VX_V3B_FORMAL_ANALYSIS|physical=%d|drive=[%.6f %.6f]|brake=[%.6f %.6f]|fusion_rmse=%.9g\n', ...
    A.physicalGatePass,A.drive.rearSustainedDuration_s,A.brake.rearSustainedDuration_s,A.overall.Fusion.RMSE);
end

function M=metric_set(t,Y,v,updated,w,includeEnd)
idx=updated&t>=w(1)&(t<w(2)|(includeEnd&t<=w(2)));assert(any(idx),'VX:V3B:EmptyWindow');
M.WSS=metrics(Y(idx,3)-v(idx));M.IMU=metrics(Y(idx,5)-v(idx));M.Fusion=metrics(Y(idx,1)-v(idx));M.sampleCount=sum(idx);
end
function m=metrics(e)
e=e(isfinite(e));assert(~isempty(e),'VX:V3B:NoFiniteMetric');
m=struct('RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)),'MaxAbs',max(abs(e)),'Bias',mean(e));
end
function D=degradation_phase(t,Y,v,updated,kappa,deg,recovery,isAccel)
if isAccel,cond=kappa(:,3:4)>=0.10;else,cond=kappa(:,3:4)<=-0.10;end
in=t>=deg(1)&t<deg(2)&all(isfinite(kappa(:,3:4)),2);
dur=[max_sustained(t,in&cond(:,1)),max_sustained(t,in&cond(:,2))];
M=metric_set(t,Y,v,updated,deg,false);idx=updated&t>=deg(1)&t<deg(2);
base=updated&t>=0.6&t<3;baseAlpha=mean(Y(base,30),'omitnan');
D=struct('window_s',deg,'recoveryWindow_s',recovery,'rearSustainedDuration_s',dur, ...
    'physicalGatePass',all(dur>=0.10-1e-9),'WSS_RMSE',M.WSS.RMSE, ...
    'IMU_RMSE',M.IMU.RMSE,'Fusion_RMSE',M.Fusion.RMSE, ...
    'meanAlphaW',mean(Y(idx,30),'omitnan'),'meanAlphaI',mean(Y(idx,31),'omitnan'));
det=updated&t>=deg(1)&t<deg(2)&((Y(:,26)<0.5&Y(:,27)<0.5)|(Y(:,18)<=0.05&Y(:,19)<=0.05));
valid=updated&t>=recovery(1)&t<=recovery(2)&Y(:,26)>0.5&Y(:,27)>0.5;
a90=updated&t>=recovery(1)&t<=recovery(2)&Y(:,30)>=0.90*baseAlpha;
a95=updated&t>=recovery(1)&t<=recovery(2)&Y(:,30)>=0.95*baseAlpha;
D.detectionResponse_s=event_value(t,det,deg(1),1);
D.wheelRecovery_s=event_value(t,valid,recovery(1),30);
D.alphaWRecovery90_s=event_value(t,a90,recovery(1),30);
D.alphaWRecovery95_s=event_value(t,a95,recovery(1),30);
end
function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end;b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end,end
end
function value=event_value(t,mask,startTime,nRequired)
idx=find(mask);value=NaN;if nRequired==1&&~isempty(idx),value=t(idx(1))-startTime;return,end
if isempty(idx),return,end;b=[1;find(diff(t(idx))>0.011)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>=nRequired,value=t(run(1))-startTime;return,end,end
end
function write_final_tables(root,A)
v3=fullfile(root,'results','vx_formal_validation','v3','runtime');out=fullfile(root,'results','vx_formal_validation','v3b','runtime');
ids={'VX-ND';'VX-ST';'VX-CS'};data=nan(3,5);
for k=1:2,S=load(fullfile(v3,[strrep(ids{k},'-','_') '_analysis.mat']),'A');q=S.A.overall;data(k,:)=[q.WSS.RMSE q.IMU.RMSE q.Fusion.RMSE q.Fusion.MAE q.Fusion.MaxAbs];end
q=A.overall;data(3,:)=[q.WSS.RMSE q.IMU.RMSE q.Fusion.RMSE q.Fusion.MAE q.Fusion.MaxAbs];
T=table(ids,data(:,1),data(:,2),data(:,3),data(:,4),data(:,5),'VariableNames', ...
    {'CaseId','WSS_RMSE','IMU_RMSE','Fusion_RMSE','Fusion_MAE','Fusion_MaxAbs'});
writetable(T,fullfile(out,'VX_TABLE_01_FINAL_representative_condition_performance.csv'));
phase={'DRIVE_SLIP';'BRAKE_SLIP'};x={A.drive;A.brake};n=2;
WSS=zeros(n,1);IMU=WSS;Fusion=WSS;AlphaW=WSS;AlphaI=WSS;DurRL=WSS;DurRR=WSS;Gate=false(n,1);
Detection=WSS;WheelRecovery=WSS;Alpha90=WSS;Alpha95=WSS;
for k=1:n,z=x{k};WSS(k)=z.WSS_RMSE;IMU(k)=z.IMU_RMSE;Fusion(k)=z.Fusion_RMSE;AlphaW(k)=z.meanAlphaW;AlphaI(k)=z.meanAlphaI;DurRL(k)=z.rearSustainedDuration_s(1);DurRR(k)=z.rearSustainedDuration_s(2);Gate(k)=z.physicalGatePass;Detection(k)=z.detectionResponse_s;WheelRecovery(k)=z.wheelRecovery_s;Alpha90(k)=z.alphaWRecovery90_s;Alpha95(k)=z.alphaWRecovery95_s;end
T2=table(phase,WSS,IMU,Fusion,AlphaW,AlphaI,DurRL,DurRR,Gate,Detection,WheelRecovery,Alpha90,Alpha95, ...
    'VariableNames',{'Phase','WSS_RMSE','IMU_RMSE','Fusion_RMSE','MeanAlphaW','MeanAlphaI','SustainedRL_s','SustainedRR_s','PhysicalGatePass','DetectionResponse_s','WheelRecovery_s','AlphaWRecovery90_s','AlphaWRecovery95_s'});
writetable(T2,fullfile(out,'VX_TABLE_02_FINAL_combined_slip_recovery.csv'));
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:JsonWrite');c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
end
