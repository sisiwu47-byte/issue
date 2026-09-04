function audit = audit_historical_fg_physical_excitation_v3b()
%AUDIT_HISTORICAL_FG_PHYSICAL_EXCITATION_V3B Physical-only Tier-2 audit.
% Historical F/G are behavior templates, never formal V3B evidence.
% Run this function only if every Tier-1 reference-only candidate fails.

root=fileparts(fileparts(mfilename('fullpath')));
outDir=fullfile(root,'results','vx_formal_validation','v3b','calibration');
if ~isfolder(outDir),mkdir(outDir);end
ids={'F','G'};windows={[5.778 7.999],[4.709 9.175]};
rows=cell(0,10);audit=struct('stage','VX-V3B-HISTORICAL-PHYSICAL-AUDIT', ...
    'classification','HISTORICAL_BEHAVIOR_TEMPLATE','cases',struct());
for c=1:2
    file=fullfile(root,'tests',['results_case_' ids{c} '.mat']);
    listing=whos('-file',file);assert(any(strcmp({listing.name},'E')),'VX:V3B:HistoricalE');
    S=load(file,'E');E=S.E;w=windows{c};
    t=double(E.est_u_time(:));U=double(E.est_u_data);
    if size(U,1)~=numel(t)&&size(U,2)==numel(t),U=U.';end
    assert(size(U,2)>=4,'VX:V3B:HistoricalOmega');
    vx=interp1(double(E.Vx_true_time(:)),double(E.Vx_true_data(:)),t,'linear',NaN);
    kappa=(0.393.*U(:,1:4)-vx)./max(abs(vx),1);idx=t>=w(1)&t<w(2)&isfinite(vx);
    rear=kappa(idx,3:4);caseResult=struct('window_s',w, ...
        'rearKappaMin',min(rear,[],1),'rearKappaMax',max(rear,[],1), ...
        'rearPositiveSlipDuration_s',[max_sustained(t,idx&kappa(:,3)>=0.10),max_sustained(t,idx&kappa(:,4)>=0.10)], ...
        'rearNegativeSlipDuration_s',[max_sustained(t,idx&kappa(:,3)<=-0.10),max_sustained(t,idx&kappa(:,4)<=-0.10)]);
    torqueNames={'T_L1','T_L2','T_R1','T_R2','T_total'};negative=false(1,numel(torqueNames));
    for q=1:numel(torqueNames)
        name=torqueNames{q};stats=nan(1,5);
        if isfield(E,name)&&isfield(E,'T_time')
            torqueValue=E.(name);tq=double(torqueValue(:));tt=double(E.T_time(:));n=min(numel(tq),numel(tt));tq=tq(1:n);tt=tt(1:n);
            use=tt>=w(1)&tt<w(2)&isfinite(tq);assert(any(use),'VX:V3B:HistoricalTorqueWindow');
            values=tq(use);stats=[min(values) max(values) median(values) prctile(values,5) prctile(values,95)];
            negative(q)=max_sustained(tt,use&tq<=-1)>=0.10;
        end
        rows(end+1,:)={ids{c},w(1),w(2),name,stats(1),stats(2),stats(3),stats(4),stats(5),negative(q)}; %#ok<AGROW>
        caseResult.torque.(name)=struct('min',stats(1),'max',stats(2),'median',stats(3), ...
            'p05',stats(4),'p95',stats(5),'sustainedNegativeSignature',negative(q));
    end
    caseResult.anyClearNegativeTorqueSignature=any(negative);
    audit.cases.(ids{c})=caseResult;
end
T=cell2table(rows,'VariableNames',{'CaseId','WindowStart_s','WindowEnd_s','TorqueChannel', ...
    'Min_Nm','Max_Nm','Median_Nm','P05_Nm','P95_Nm','SustainedNegativeSignature'});
writetable(T,fullfile(outDir,'historical_FG_physical_audit.csv'));
write_json(fullfile(outDir,'historical_FG_physical_audit.json'),audit);
end

function d=max_sustained(t,mask)
idx=find(mask);d=0;if isempty(idx),return,end;b=[1;find(diff(idx)>1)+1;numel(idx)+1];
for k=1:numel(b)-1,run=idx(b(k):b(k+1)-1);if numel(run)>1,d=max(d,t(run(end))-t(run(1))+median(diff(t(run))));end,end
end
function write_json(file,value)
fid=fopen(file,'wt');assert(fid>=0,'VX:V3B:JsonWrite');c=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true));clear c
end
