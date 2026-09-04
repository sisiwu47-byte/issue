function y=vy_dynamic_ekf_v1_13(w)
%VY_DYNAMIC_EKF_V1_13 Online wrapper for the isolated V1.13 model copy.
persistent x P
if isempty(x),x=[0;0];end;if isempty(P),P=0.1*eye(2);end
w=w(:);u=w(1:5);z=w(6:7);
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575, ...
    'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
cfg=struct('dt',0.01,'Q',diag([1e-4,1e-4]), ...
    'R',diag([1e-2,3.365172961808e-4]),'denomEps',1e-12,'lambda',zeros(4,1));
[x,P,info]=vy_dynamic_ekf_step_v13(x,P,u,z,par,cfg);
y=zeros(59,1);y(1:2)=x;y(3:4)=[P(1,1);P(2,2)];y(5)=info.NIS;
y(6:9)=info.Fy;y(10:13)=info.alpha;y(14:15)=info.innovation;
y(16:17)=info.x_pred;y(18:21)=info.F(:);y(22:25)=info.H(:);
y(26:29)=info.P_prior(:);y(30:33)=info.P_noQ(:);y(34:37)=info.P_pred(:);
y(38:41)=info.S(:);y(42:45)=info.K(:);y(46:49)=P(:);y(50:51)=z;
y(52:55)=info.Fy_raw;y(56:59)=info.Fy_corrected;
end
