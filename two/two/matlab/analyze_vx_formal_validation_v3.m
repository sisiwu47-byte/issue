function A = analyze_vx_formal_validation_v3(caseId)
%ANALYZE_VX_FORMAL_VALIDATION_V3 Analyze one accepted V3 runtime.

arguments
    caseId (1,1) string
end
caseId=upper(strrep(strtrim(caseId),'_','-'));
assert(any(caseId==["VX-ND","VX-ST","VX-DR"]),'VX:V3:UnknownCase');
root=fileparts(fileparts(mfilename('fullpath')));
runtimeDir=fullfile(root,'results','vx_formal_validation','v3','runtime');
stem=strrep(char(caseId),'-','_');
rawFile=fullfile(runtimeDir,[stem '_formal_raw.mat']);
S=load(rawFile,'R'); R=S.R;
assert(isscalar(R)&&R.metadata.formalRuntime&&strcmp(R.metadata.caseId,caseId), ...
    'VX:V3:Evidence','Formal result identity failed.');
t=double(R.time(:));Y=double(R.estY);U=double(R.estU);v=double(R.vxTrue(:));
assert(size(Y,2)==38&&size(U,2)==18&&numel(t)==size(Y,1)&&numel(t)==size(U,1), ...
    'VX:V3:Interface','Formal arrays violate the frozen interface.');
updated=Y(:,35)>0.5 & isfinite(v);

A=struct('stage','VX-V3','caseId',char(caseId),'rawFile',rawFile);
A.overall=metric_set(t,Y,v,updated,[0.6 16],true);
A.windows=frozen_windows(caseId);
fields=fieldnames(A.windows);
for k=1:numel(fields)
    w=A.windows.(fields{k});
    A.phase.(fields{k})=metric_set(t,Y,v,updated,w,w(2)==16);
end

if caseId=="VX-ST"
    idx=t>=3&t<8&all(isfinite(U(:,5:8)),2);
    peak=max(abs(U(idx,5:8)),[],1);
    spread=std(U(idx,5:8),0,1);
    rear=all(peak(3:4)>=1e-4)&all(spread(3:4)>=1e-5);
    A.steeringGate=struct('peakAbsRad',peak,'stdRad',spread, ...
        'rearSteeringPass',rear,'claim',ternary(rear, ...
        '4WIS_REAR_STEERING_VALIDATION','STEERING_DYNAMIC_VALIDATION'));
end

if caseId=="VX-DR"
    kappa=(0.393.*U(:,1:4)-v)./max(abs(v),1);
    A.dr=struct();
    A.dr.accel=degradation_phase(t,Y,v,updated,kappa,[3 7],[7 9],true);
    A.dr.brake=degradation_phase(t,Y,v,updated,kappa,[9 13],[13 16],false);
    A.dr.physicalGatePass=A.dr.accel.physicalGatePass&&A.dr.brake.physicalGatePass;
    A.dr.fallback=ternary(A.dr.physicalGatePass,'NOT_REQUIRED','NEEDS_CONFIGURATION');
end

analysisFile=fullfile(runtimeDir,[stem '_analysis.mat']);
jsonFile=fullfile(runtimeDir,[stem '_analysis.json']);
save(analysisFile,'A'); write_json(jsonFile,A);
write_tables_if_available(root);
fprintf('VX_V3_ANALYSIS|case=%s|fusion_rmse=%.9g\n',caseId,A.overall.Fusion.RMSE);
end

function windows=frozen_windows(caseId)
switch caseId
    case "VX-ND"
        windows=struct('baseline',[0.6 3],'acceleration',[3 7], ...
            'highSpeedPlateau',[7 9],'braking',[9 13],'finalPlateau',[13 16]);
    case "VX-ST"
        windows=struct('baseline',[0.6 3],'steering',[3 8],'recovery',[8 16]);
    case "VX-DR"
        windows=struct('baseline',[0.6 3],'accelDegradation',[3 7], ...
            'accelRecovery',[7 9],'brakeDegradation',[9 13],'brakeRecovery',[13 16]);
end
end

function M=metric_set(t,Y,v,updated,w,includeEnd)
idx=updated&t>=w(1)&(t<w(2)|(includeEnd&t<=w(2)));
assert(any(idx),'VX:V3:EmptyWindow','No estimator updates in frozen window.');
M.WSS=metrics(Y(idx,3)-v(idx));
M.IMU=metrics(Y(idx,5)-v(idx));
M.Fusion=metrics(Y(idx,1)-v(idx));
M.sampleCount=sum(idx);
end

function m=metrics(e)
e=e(isfinite(e));assert(~isempty(e),'VX:V3:NoFiniteMetric');
m=struct('RMSE',sqrt(mean(e.^2)),'MAE',mean(abs(e)), ...
    'MaxAbs',max(abs(e)),'Bias',mean(e));
end

function D=degradation_phase(t,Y,v,updated,kappa,deg,recovery,isAccel)
if isAccel,cond=kappa(:,3:4)>=0.10;else,cond=kappa(:,3:4)<=-0.10;end
inDeg=t>=deg(1)&t<deg(2)&all(isfinite(kappa(:,3:4)),2);
dur=[max_sustained(t,inDeg&cond(:,1)),max_sustained(t,inDeg&cond(:,2))];
D=struct();D.window_s=deg;D.recoveryWindow_s=recovery;
D.rearSustainedDuration_s=dur;
D.physicalGatePass=all(dur>=0.10-1e-9);
M=metric_set(t,Y,v,updated,deg,false);
D.WSS_RMSE=M.WSS.RMSE;D.IMU_RMSE=M.IMU.RMSE;D.Fusion_RMSE=M.Fusion.RMSE;
idx=updated&t>=deg(1)&t<deg(2);
D.meanAlphaW=mean(Y(idx,30),'omitnan');D.meanAlphaI=mean(Y(idx,31),'omitnan');
base=updated&t>=0.6&t<3;baseAlpha=mean(Y(base,30),'omitnan');
det=updated&t>=deg(1)&t<deg(2)&((Y(:,26)<0.5&Y(:,27)<0.5)| ...
    (Y(:,18)<=0.05&Y(:,19)<=0.05));
D.detectionResponse=event_string(t,det,deg(1),'NOT_DETECTED',1);
valid=updated&t>=recovery(1)&t<=recovery(2)&Y(:,26)>0.5&Y(:,27)>0.5;
D.wheelRecovery=event_string(t,valid,recovery(1),'NOT_REACHED',30);
a90=updated&t>=recovery(1)&t<=recovery(2)&Y(:,30)>=0.90*baseAlpha;
a95=updated&t>=recovery(1)&t<=recovery(2)&Y(:,30)>=0.95*baseAlpha;
D.alphaWRecovery90=event_string(t,a90,recovery(1),'NOT_REACHED',30);
D.alphaWRecovery95=event_string(t,a95,recovery(1),'NOT_REACHED',30);
end

function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end
breaks=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(breaks)-1
    run=idx(breaks(k):breaks(k+1)-1);
    if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end
end
end

function s=event_string(t,mask,startTime,missing,nRequired)
idx=find(mask);found=NaN;
if nRequired==1&&~isempty(idx),found=t(idx(1))-startTime;end
if nRequired>1&&~isempty(idx)
    % Estimator updates occur every 0.01 s on the 1 kHz logged timeline;
    % group consecutive update events by time rather than raw row adjacency.
    b=[1;find(diff(t(idx))>0.011)+1;numel(idx)+1];
    for k=1:numel(b)-1
        run=idx(b(k):b(k+1)-1);
        if numel(run)>=nRequired,found=t(run(1))-startTime;break,end
    end
end
if isnan(found),s=missing;else,s=sprintf('%.6f',found);end
end

function write_tables_if_available(root)
d=fullfile(root,'results','vx_formal_validation','v3','runtime');
ids={"VX-ND","VX-ST","VX-DR"};rows=cell(0,6);
for k=1:3
    f=fullfile(d,[strrep(char(ids{k}),'-','_') '_analysis.mat']);
    if isfile(f),S=load(f,'A');a=S.A.overall;rows(end+1,:)={ids{k},a.WSS.RMSE,a.IMU.RMSE,a.Fusion.RMSE,a.Fusion.MAE,a.Fusion.MaxAbs};end %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',{'CaseId','WSS_RMSE','IMU_RMSE','Fusion_RMSE','Fusion_MAE','Fusion_MaxAbs'});
writetable(T,fullfile(d,'VX_TABLE_01_representative_condition_performance.csv'));
f=fullfile(d,'VX_DR_analysis.mat');if ~isfile(f),return,end
S=load(f,'A');a=S.A.dr;phase={"ACCEL";"BRAKE"};x={a.accel;a.brake};
WSS=zeros(2,1);IMU=WSS;Fusion=WSS;AlphaW=WSS;AlphaI=WSS;DurRL=WSS;DurRR=WSS;
Gate=false(2,1);Detection=strings(2,1);WheelRecovery=Detection;Alpha90=Detection;Alpha95=Detection;
for k=1:2,q=x{k};WSS(k)=q.WSS_RMSE;IMU(k)=q.IMU_RMSE;Fusion(k)=q.Fusion_RMSE;AlphaW(k)=q.meanAlphaW;AlphaI(k)=q.meanAlphaI;DurRL(k)=q.rearSustainedDuration_s(1);DurRR(k)=q.rearSustainedDuration_s(2);Gate(k)=q.physicalGatePass;Detection(k)=q.detectionResponse;WheelRecovery(k)=q.wheelRecovery;Alpha90(k)=q.alphaWRecovery90;Alpha95(k)=q.alphaWRecovery95;end
T2=table(phase,WSS,IMU,Fusion,AlphaW,AlphaI,DurRL,DurRR,Gate,Detection,WheelRecovery,Alpha90,Alpha95, ...
    'VariableNames',{'Phase','WSS_RMSE','IMU_RMSE','Fusion_RMSE','MeanAlphaW','MeanAlphaI','SustainedRL_s','SustainedRR_s','PhysicalGatePass','DetectionResponse_s','WheelRecovery_s','AlphaWRecovery90_s','AlphaWRecovery95_s'});
writetable(T2,fullfile(d,'VX_TABLE_02_degradation_recovery_dynamics.csv'));
end

function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3:JsonWrite');c=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
end

function out=ternary(condition,a,b)
if condition,out=a;else,out=b;end
end
