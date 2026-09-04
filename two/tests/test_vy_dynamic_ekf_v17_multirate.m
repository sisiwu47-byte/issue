function report=test_vy_dynamic_ekf_v17_multirate()
%TEST_VY_DYNAMIC_EKF_V17_MULTIRATE Mandatory V1.17 pre-simulation gate.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));rng(1717,'twister');
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',.393,'k_f',.78181,'k_r',1.09186);
cfg=struct('dt',.01,'Q',diag([1e-4,1e-4]),'R',diag([1e-2,3.365172961808e-4]),'denomEps',1e-12,'lambda',zeros(4,1));
names={'x_new','P_new','innovation','S','K','NIS'};mx=zeros(1,numel(names));predMax=0;n=120;
for i=1:n
    x=[.15*randn;.12*randn];A=randn(2);P=1e-4*eye(2)+.08*(A*A');
    u=[15+10*rand;.03*randn(4,1)];z=[1.5*randn;.15*randn];
    [x13,P13,i13]=vy_dynamic_ekf_step_v13(x,P,u,z,par,cfg);
    [x17,P17,i17]=vy_dynamic_ekf_step_v17(x,P,u,z,par,cfg,true);
    assert(isfield(i17,'updateValid') && i17.updateValid, ...
        'Full D update-valid diagnostic was not asserted.');
    vals={x17-x13,P17-P13,i17.innovation-i13.innovation,i17.S-i13.S,i17.K-i13.K,i17.NIS-i13.NIS};
    for j=1:numel(vals),mx(j)=max(mx(j),max(abs(vals{j}),[],'all'));end
    [~,~,ir]=vy_dynamic_ekf_step_v17(x,P,u,z,par,cfg,false);
    assert(isfield(ir,'updateValid') && ir.updateValid, ...
        'Yaw-only D update-valid diagnostic was not asserted.');
    predMax=max(predMax,max(abs([ir.x_pred-i13.x_pred;ir.P_pred(:)-i13.P_pred(:);ir.F(:)-i13.F(:);ir.H(:)-i13.H(:)])));
    assert(ir.measurementDimension==1&&size(ir.K,2)==1&&isscalar(ir.S));
end
assert(max(mx)<=1e-12,'A100 single-step equivalence failed: %.17g',max(mx));
assert(predMax<=1e-12,'Prediction equality failed: %.17g',predMax);
[~,~,seedZero]=vy_dynamic_ekf_step_v13([0;0],eye(2),[20;zeros(4,1)], [0;0],par,cfg);
[~,~,zeroInfo]=vy_dynamic_ekf_step_v13([0;0],eye(2),[20;zeros(4,1)], seedZero.h_pred,par,cfg);
assert(abs(zeroInfo.NIS)<=1e-12 && zeroInfo.updateValid, ...
    'Zero innovation was not retained as a valid D update.');
w=[20;zeros(4,1);0;0];clear('vy_dynamic_ekf_v1_17');f50=false(11,1);for i=1:11,[y,rd]=vy_dynamic_ekf_v1_17(w,50);f50(i)=logical(y(60));assert(rd.update_valid_D&&rd.nis_valid_D);end
clear('vy_dynamic_ekf_v1_17');f20=false(21,1);for i=1:21,y=vy_dynamic_ekf_v1_17(w,20);f20(i)=logical(y(60));end
assert(isequal(find(f50)',1:2:11)&&isequal(find(f20)',1:5:21),'Deterministic schedule/reset failed.');
report=struct('passed',true,'testCount',n,'tolerance',1e-12,'maxA100Difference',cell2struct(num2cell(mx),names,2), ...
    'predictionMaxDifference',predMax,'A50First11Count',sum(f50),'A20First21Count',sum(f20));
fprintf('V1_17_TEST_PASS|N=%d|A100=%.3g|prediction=%.3g|A50=%d/11|A20=%d/21\n',n,max(mx),predMax,sum(f50),sum(f20));
end
