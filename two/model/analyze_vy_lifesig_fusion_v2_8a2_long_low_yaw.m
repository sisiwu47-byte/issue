function analysis = analyze_vy_lifesig_fusion_v2_8a2_long_low_yaw()
%ANALYZE... Offline low-yaw partition and D/K error analysis. No sim().

root=fileparts(fileparts(mfilename('fullpath')));
runtimeFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_runtime.mat');
resultFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_analysis.mat');
csvFile=fullfile(root,'results','vy_lifesig_v2_8a2_long_low_yaw_summary.csv');
assert(isfile(runtimeFile),'V28A2:RuntimeMissing','V2.8-A2 runtime MAT is missing.');
S=load(runtimeFile,'runtime');r=S.runtime;
assert(r.simCalled&&r.simInvocationCount==1&&strcmp(r.authorization,'CONSUMED')&& ...
    r.simulationCompleted&&r.carSimRun&&r.hashesUnchanged, ...
    'V28A2:RuntimeIneligible','V2.8-A2 runtime evidence is not eligible.');

time=scalar_log(r.raw.rel_common_time_100hz_log);
steer=scalar_log(r.raw.steer_cmd_rad);yaw=scalar_log(r.raw.long_low_yaw_r_log);
truth=scalar_log(r.raw.rel_vy_true_100hz_log);vyD=scalar_log(r.raw.fusion_vy_d_log);
vyK=scalar_log(r.raw.fusion_vy_k_log);eK=scalar_log(r.raw.long_low_yaw_k_error_log);
eD=scalar_log(r.raw.long_low_yaw_d_error_log);
fl=scalar_log(r.raw.steer_fl_carsim_deg);fr=scalar_log(r.raw.steer_fr_carsim_deg);
rl=scalar_log(r.raw.steer_rl_carsim_deg);rr=scalar_log(r.raw.steer_rr_carsim_deg);
N=numel(time);allVectors={steer,yaw,truth,vyD,vyK,eK,eD,fl,fr,rl,rr};
aligned=all(cellfun(@(x)numel(x)==N,allVectors));
finite=all(isfinite(time))&&all(cellfun(@(x)all(isfinite(x)),allVectors));
dt=diff(time);timeOK=N==2201&&abs(time(1))<1e-12&&abs(time(end)-22)<1e-9&& ...
    max(abs(dt-0.01))<1e-9;
errorReplay=struct('D',max(abs(eD-(vyD-truth))), ...
    'K',max(abs(eK-(vyK-truth))));
steerAfterZero=max(abs(steer(time>=4.5)));
steeringOK=steerAfterZero<=1e-14&&max(abs(steer))>=0.999*0.02&& ...
    max(abs(fl-fr))<=1e-10&&max(abs(rl))<=1e-12&&max(abs(rr))<=1e-12;

analysis=struct();analysis.stage='V2.8-A2';
analysis.role='NON_HOLDOUT_LONG_LOW_YAW_OBSERVABILITY_VALIDATION';
analysis.sampleCount=N;analysis.timeStart=time(1);analysis.timeEnd=time(end);
analysis.dt=struct('min',min(dt),'mean',mean(dt),'max',max(dt));
analysis.aligned=aligned;analysis.finite=finite;analysis.timeOK=timeOK;
analysis.errorReplayMax=errorReplay;analysis.steeringAfter4p5MaxAbs=steerAfterZero;
analysis.steeringOK=steeringOK;

thresholds=[0.005 0.01 0.02];after=time>=4.5;
partitions=repmat(struct('threshold',0,'sampleCount',0,'fraction',0, ...
    'totalDuration',0,'longestDuration',0,'longestStart',NaN,'longestEnd',NaN),3,1);
for i=1:numel(thresholds)
    mask=after & abs(yaw)<thresholds(i);
    [total,longest,startTime,endTime]=durations(time,mask);
    partitions(i).threshold=thresholds(i);partitions(i).sampleCount=sum(mask);
    partitions(i).fraction=sum(mask)/sum(after);partitions(i).totalDuration=total;
    partitions(i).longestDuration=longest;partitions(i).longestStart=startTime;
    partitions(i).longestEnd=endTime;
end
analysis.partitions=partitions;

primary=partitions(2);primaryMask=after & abs(yaw)<0.01;
[~,~,s,e]=durations(time,primaryMask);
if isnan(s)
    windowMask=false(size(time));
else
    windowMask=time>=s-1e-12 & time<=e+1e-12 & primaryMask;
end
analysis.primaryWindow=struct('threshold',0.01,'start',s,'end',e, ...
    'duration',primary.longestDuration,'sampleCount',sum(windowMask));
if any(windowMask)
    analysis.K=window_metrics(time(windowMask),eK(windowMask));
    analysis.D=window_metrics(time(windowMask),eD(windowMask));
    analysis.yaw=struct('meanAbs',mean(abs(yaw(windowMask))), ...
        'medianAbs',median(abs(yaw(windowMask))),'maxAbs',max(abs(yaw(windowMask))));
else
    analysis.K=empty_metrics();analysis.D=empty_metrics();
    analysis.yaw=struct('meanAbs',NaN,'medianAbs',NaN,'maxAbs',NaN);
end
analysis.lowYawRuntimeSufficient=primary.longestDuration>=10;
analysis.relative=struct('rmseRatioKoverD',analysis.K.RMSE/analysis.D.RMSE, ...
    'maeRatioKoverD',analysis.K.MAE/analysis.D.MAE, ...
    'maxAbsRatioKoverD',analysis.K.MaxAbs/analysis.D.MaxAbs, ...
    'absDriftRatioKoverD',abs(analysis.K.drift)/max(abs(analysis.D.drift),eps));
analysis.passed=aligned&&finite&&timeOK&&steeringOK&& ...
    errorReplay.D<=1e-12&&errorReplay.K<=1e-12;
save(resultFile,'analysis','-v7');write_csv(csvFile,analysis);
fprintf(['V28_A2_ANALYSIS|N=%d|passed=%d|lowYaw10=%d|window=[%.17g %.17g]|' ...
    'duration=%.17g|K=[%.17g %.17g %.17g %.17g]|D=[%.17g %.17g %.17g %.17g]\n'], ...
    N,analysis.passed,analysis.lowYawRuntimeSufficient,s,e,primary.longestDuration, ...
    analysis.K.RMSE,analysis.K.MAE,analysis.K.MaxAbs,analysis.K.Bias, ...
    analysis.D.RMSE,analysis.D.MAE,analysis.D.MaxAbs,analysis.D.Bias);
fprintf(['V28_A2_DRIFT|K_start=%.17g|K_end=%.17g|K_drift=%.17g|K_slope=%.17g|' ...
    'D_start=%.17g|D_end=%.17g|D_drift=%.17g|D_slope=%.17g\n'], ...
    analysis.K.start,analysis.K.end,analysis.K.drift,analysis.K.slope, ...
    analysis.D.start,analysis.D.end,analysis.D.drift,analysis.D.slope);
for i=1:3
    p=partitions(i);fprintf(['V28_A2_PARTITION|threshold=%.17g|samples=%d|' ...
        'fraction=%.17g|total=%.17g|longest=%.17g|start=%.17g|end=%.17g\n'], ...
        p.threshold,p.sampleCount,p.fraction,p.totalDuration,p.longestDuration, ...
        p.longestStart,p.longestEnd);
end
assert(analysis.passed,'V28A2:AnalysisIntegrityFailed', ...
    'V2.8-A2 runtime integrity or steering gate failed.');
end

function x=scalar_log(r)
d=double(r.data);N=r.sampleCount;
if isvector(d)&&numel(d)==N,x=d(:);
elseif size(d,1)==N&&size(d,2)==1,x=d;
elseif size(d,2)==N&&size(d,1)==1,x=d(:);
else,error('V28A2:LogShape','Expected scalar log, got %s.',mat2str(size(d)));
end
end

function [total,longest,startTime,endTime]=durations(t,mask)
mask=logical(mask(:));t=t(:);total=sum(diff(t).*double(mask(1:end-1)));
edges=diff([false;mask;false]);starts=find(edges==1);ends=find(edges==-1)-1;
if isempty(starts)
    longest=0;startTime=NaN;endTime=NaN;return
end
span=t(ends)-t(starts);[longest,i]=max(span);
startTime=t(starts(i));endTime=t(ends(i));
end

function m=window_metrics(t,e)
m=struct();m.RMSE=sqrt(mean(e.^2));m.MAE=mean(abs(e));
m.MaxAbs=max(abs(e));m.Bias=mean(e);m.start=e(1);m.end=e(end);
m.drift=m.end-m.start;m.absGrowth=abs(m.end)-abs(m.start);
if numel(t)>1,p=polyfit(t-t(1),e,1);m.slope=p(1);else,m.slope=NaN;end
end

function m=empty_metrics()
m=struct('RMSE',NaN,'MAE',NaN,'MaxAbs',NaN,'Bias',NaN,'start',NaN, ...
    'end',NaN,'drift',NaN,'absGrowth',NaN,'slope',NaN);
end

function write_csv(path,a)
fid=fopen(path,'wt');assert(fid>0,'V28A2:CsvOpen','Cannot open summary CSV.');
c=onCleanup(@()fclose(fid));fprintf(fid,'section,metric,value\n');
fprintf(fid,'integrity,sampleCount,%d\n',a.sampleCount);
fprintf(fid,'integrity,passed,%d\n',a.passed);
fprintf(fid,'integrity,steeringAfter4p5MaxAbs,%.17g\n',a.steeringAfter4p5MaxAbs);
for i=1:numel(a.partitions)
    p=a.partitions(i);tag=sprintf('r_lt_%.3f',p.threshold);
    fprintf(fid,'%s,sampleCount,%d\n',tag,p.sampleCount);
    fprintf(fid,'%s,fraction,%.17g\n',tag,p.fraction);
    fprintf(fid,'%s,totalDuration,%.17g\n',tag,p.totalDuration);
    fprintf(fid,'%s,longestDuration,%.17g\n',tag,p.longestDuration);
    fprintf(fid,'%s,longestStart,%.17g\n',tag,p.longestStart);
    fprintf(fid,'%s,longestEnd,%.17g\n',tag,p.longestEnd);
end
names={'K','D'};
for i=1:2
    m=a.(names{i});fields={'RMSE','MAE','MaxAbs','Bias','start','end','drift','absGrowth','slope'};
    for k=1:numel(fields),fprintf(fid,'%s,%s,%.17g\n',names{i},fields{k},m.(fields{k}));end
end
clear c
end
