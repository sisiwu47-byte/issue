function report=test_vy_dynamic_ekf_v13_equivalence()
%TEST_VY_DYNAMIC_EKF_V13_EQUIVALENCE Mandatory pre-simulation gate.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));rng(1313,'twister');
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575,'Rw',0.393);
cfg=struct('dt',0.01,'Q',diag([1e-4,1e-4]),'R',diag([1e-2,3.365172961808e-4]), ...
    'denomEps',1e-12,'lambda',zeros(4,1));
fields={'x_new','P_new','innovation','NIS','S','K'};mx=zeros(1,numel(fields));
forceScaleMax=0;measurementMax=0;n=120;
for i=1:n
    x=[0.15*randn;0.12*randn];A=randn(2);P=1e-4*eye(2)+0.08*(A*A');
    u=[15+10*rand;0.03*randn(4,1)];z=[1.5*randn;0.15*randn];
    parUnity=par;parUnity.k_f=1;parUnity.k_r=1;
    [xo,Po,io]=vy_dynamic_ekf_step(x,P,u,z,par,cfg);
    [xu,Pu,iu]=vy_dynamic_ekf_step_v13(x,P,u,z,parUnity,cfg);
    vals={xo-xu,Po-Pu,io.innovation-iu.innovation,io.NIS-iu.NIS,io.S-iu.S,io.K-iu.K};
    for j=1:numel(vals),mx(j)=max(mx(j),max(abs(vals{j}),[],'all'));end
    parScaled=par;parScaled.k_f=0.78181;parScaled.k_r=1.09186;
    [~,~,is]=vy_dynamic_ekf_step_v13(x,P,u,z,parScaled,cfg);
    forceScaleMax=max(forceScaleMax,max(abs(is.Fy_corrected-is.Fy_raw.*[parScaled.k_f;parScaled.k_f;parScaled.k_r;parScaled.k_r])));
    ayForce=(is.frontFy+is.rearFy)/par.m;
    measurementMax=max(measurementMax,abs(is.h_pred(1)-ayForce));
end
fprintf('UNITY_FIELDS|x=%.17g|P=%.17g|innovation=%.17g|NIS=%.17g|S=%.17g|K=%.17g\n',mx);
assert(max(mx)<=1e-12,'Unity-gain equivalence failed: %.17g',max(mx));
assert(forceScaleMax<=1e-12,'Force scale identity failed: %.17g',forceScaleMax);
assert(measurementMax<=1e-12,'Measurement force identity failed: %.17g',measurementMax);
report=struct('passed',true,'testCount',n,'tolerance',1e-12, ...
    'maxDifference',cell2struct(num2cell(mx),fields,2), ...
    'forceScaleMax',forceScaleMax,'measurementConsistencyMax',measurementMax);
fprintf('V1_13_TEST_PASS|N=%d|unity=%.3g|force=%.3g|measurement=%.3g\n',n,max(mx),forceScaleMax,measurementMax);
end
