function y=vy_dynamic_ekf_v1_15(w)
%VY_DYNAMIC_EKF_V1_15 V1.13 deterministic EKF with run-scoped diagonal Q/R.
% Q/R are the only calibrated quantities.  The V1.13 core and axle gains
% remain frozen.  Globals are assigned by the V1.15 batch runner before
% every simulation, followed by a clear of this function to reset x/P.
global VY_DEKF_V15_Q VY_DEKF_V15_R
persistent x P
if isempty(x),x=[0;0];end
if isempty(P),P=0.1*eye(2);end
assert(isequal(size(VY_DEKF_V15_Q),[2 2])&&isequal(size(VY_DEKF_V15_R),[2 2]), ...
    'V1.15 Q/R globals were not initialized.');
assert(all(VY_DEKF_V15_Q([2 3])==0)&&all(VY_DEKF_V15_R([2 3])==0), ...
    'V1.15 permits diagonal Q/R only.');
w=w(:);u=w(1:5);z=w(6:7);
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575, ...
    'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
cfg=struct('dt',0.01,'Q',VY_DEKF_V15_Q,'R',VY_DEKF_V15_R, ...
    'denomEps',1e-12,'lambda',zeros(4,1));
[x,P,info]=vy_dynamic_ekf_step_v13(x,P,u,z,par,cfg);
y=zeros(59,1);y(1:2)=x;y(3:4)=[P(1,1);P(2,2)];y(5)=info.NIS;
y(6:9)=info.Fy;y(10:13)=info.alpha;y(14:15)=info.innovation;
y(16:17)=info.x_pred;y(18:21)=info.F(:);y(22:25)=info.H(:);
y(26:29)=info.P_prior(:);y(30:33)=info.P_noQ(:);y(34:37)=info.P_pred(:);
y(38:41)=info.S(:);y(42:45)=info.K(:);y(46:49)=P(:);y(50:51)=z;
y(52:55)=info.Fy_raw;y(56:59)=info.Fy_corrected;
end
